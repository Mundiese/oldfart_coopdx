import importlib
import os
import pkgutil
import sys
from PySide6.QtCore import Qt
from PySide6.QtGui import QColor, QFont, QPalette, QSurfaceFormat
from PySide6.QtWidgets import QApplication
from ..core import theme
from .context import StudioContext
from .mainwindow import StudioWindow
_EXTENSIONS = []
def register_extension(fn):
    _EXTENSIONS.append(fn)
    return fn
from .glprobe import (FORMAT_LADDER, SOFTWARE, _probe, decide,
                      pick_surface_format, pyopengl_software, software_dll,
                      surface_format, use_software_gl)
def make_app(settings, argv=None):
    app = QApplication.instance()
    if app is not None:
        return app
    QApplication.setAttribute(Qt.AA_ShareOpenGLContexts)
    fmt, platform, step = decide(settings)
    QSurfaceFormat.setDefaultFormat(fmt)
    app = QApplication(argv if argv is not None else sys.argv[:1])
    app.setApplicationName("Studio")
    app.setOrganizationName("oldfart")
    app.setDesktopFileName("oldfart-studio")
    icon = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "packaging", "oldfart-studio.png")
    if os.path.exists(icon):
        from PySide6.QtGui import QIcon
        app.setWindowIcon(QIcon(icon))
    app.setStyle("Fusion")
    return app
def palette(t):
    p = QPalette()
    c = QColor
    p.setColor(QPalette.Window, c(t["window"]))
    p.setColor(QPalette.WindowText, c(t["text"]))
    p.setColor(QPalette.Base, c(t["window"]))
    p.setColor(QPalette.AlternateBase, c(t["panel"]))
    p.setColor(QPalette.ToolTipBase, c(t["raised"]))
    p.setColor(QPalette.ToolTipText, c(t["text"]))
    p.setColor(QPalette.Text, c(t["text"]))
    p.setColor(QPalette.Button, c(t["raised"]))
    p.setColor(QPalette.ButtonText, c(t["text"]))
    p.setColor(QPalette.BrightText, c(t["bad"]))
    p.setColor(QPalette.Highlight, c(t["accent"]))
    p.setColor(QPalette.HighlightedText, c(t["accent_text"]))
    p.setColor(QPalette.Link, c(t["accent"]))
    p.setColor(QPalette.PlaceholderText, c(t["text_off"]))
    for role in (QPalette.Text, QPalette.ButtonText, QPalette.WindowText):
        p.setColor(QPalette.Disabled, role, c(t["text_off"]))
    return p
def apply_look(ctx, defer=False):
    app = QApplication.instance()
    s = ctx.settings
    vision = s["ui.colour_vision"] if "ui.colour_vision" in s.values else None
    ctx.tokens = theme.tokens(s["ui.accent"], s["ui.background"], vision)
    try:
        from ..toolbox.qt import paint
        paint.VISION = vision or "safe"
    except Exception:
        pass
    pal = palette(ctx.tokens)
    if pal != app.palette():
        app.setPalette(pal)
    if s["ui.font"] and QFont(s["ui.font"]) != app.font():
        app.setFont(QFont(s["ui.font"]))
    scale = s["ui.scale"] / 100.0
    win = getattr(ctx, "window", None)
    tb = getattr(win, "toolbar", None) if win is not None else None
    if tb is not None:
        from PySide6.QtCore import QSize
        side = int(round(20 * scale))
        tb.setIconSize(QSize(side, side))
    if defer:
        if not getattr(ctx, "_look_pending", False):
            ctx._look_pending = True
            from PySide6.QtCore import QTimer
            QTimer.singleShot(0, lambda: flush_look(ctx))
    else:
        flush_look(ctx, force=True)
    ctx.redraw()
def flush_look(ctx, force=False):
    if not force and not getattr(ctx, "_look_pending", False):
        return False
    ctx._look_pending = False
    app = QApplication.instance()
    s = ctx.settings
    sheet = theme.stylesheet(ctx.tokens, s["ui.font_size"], s["ui.font"], s["ui.scale"] / 100.0)
    if sheet == app.styleSheet():
        return False
    from . import appfilters
    with appfilters.suspended(app):
        if app.styleSheet():
            app.setStyleSheet("")
        app.setStyleSheet(sheet)
    return True
LAYOUT_VERSION = 2
class Studio:
    def __init__(self, ctx, window):
        self.ctx = ctx
        self.window = window
        self.settings = ctx.settings
        self.scene = ctx.scene
        self.docks = window.docks
        self.views = window.views
    @classmethod
    def create(cls, settings, extensions=True):
        ctx = StudioContext(settings)
        apply_look(ctx)
        window = StudioWindow(ctx)
        studio = cls(ctx, window)
        if extensions:
            studio.install_extensions()
            from . import menutidy
            try:
                menutidy.tidy(window)
            except Exception as exc:
                window.hint("The menus were left as they are: %s" % exc)
        state = settings.state if isinstance(settings.state, dict) else {}
        if state.get("layout_version") != LAYOUT_VERSION:
            for k in ("docks", "workspaces", "layout_full"):
                state.pop(k, None)
            state["layout_version"] = LAYOUT_VERSION
            settings.state = state
        if not state.get("docks"):
            window.workspaces.switch(state.get("workspace") or "build")
        else:
            window.workspaces.current = state.get("workspace") or "build"
        return studio
    def open(self, source):
        return self.window.open(source)
    def show_arena(self, arena, name=None):
        from ..core import loader
        got = loader.from_arena(arena, name or "<generated>")
        self.scene.set_pieces(got.pieces, meta=got.meta)
        self.scene.set_markers(got.markers)
        self.views.frame_all(animate=False)
    def install_extensions(self):
        here = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ext")
        found = []
        if os.path.isdir(here):
            for info in sorted(pkgutil.iter_modules([here]), key=lambda m: m.name):
                try:
                    mod = importlib.import_module("studio.ext.%s" % info.name)
                except Exception as exc:
                    self.window.hint("Extension %s failed to load: %s" % (info.name, exc))
                    continue
                if hasattr(mod, "install"):
                    found.append(mod.install)
        for fn in found + list(_EXTENSIONS):
            try:
                fn(self)
            except Exception as exc:
                self.window.hint("Extension %s failed: %s" % (getattr(fn, "__module__", fn), exc))
        return len(found) + len(_EXTENSIONS)
