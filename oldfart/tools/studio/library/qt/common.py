import os
from PySide6.QtCore import QPointF, QSize, Qt
from PySide6.QtGui import QColor, QImage, QPainter, QPen, QPixmap, QPolygonF
from PySide6.QtWidgets import QFrame, QLabel, QSizePolicy, QVBoxLayout
from .. import texman
LEVEL_COLOURS = {"ok": "ok", "note": "warn", "fail": "bad"}
def tokens(studio):
    return studio.ctx.tokens
def shape_pixmap(tag, colour, size=44):
    from studio.editor.qt.widgets import drawing_pixmap
    try:
        d = texman.shape_icon(tag)
    except Exception:
        pm = QPixmap(size, size)
        pm.fill(Qt.transparent)
        return pm
    return drawing_pixmap(d, QColor(colour), size)
def chip(text, level, tok, tip=None):
    lab = QLabel(text)
    colour = tok.get(LEVEL_COLOURS.get(level, level), tok["text_dim"])
    lab.setStyleSheet("QLabel { background: %s; color: #0e1116; border-radius: 9px; "
                      "padding: 1px 8px; font-weight: 600; }" % colour)
    lab.setSizePolicy(QSizePolicy.Maximum, QSizePolicy.Fixed)
    if tip:
        lab.setToolTip(tip)
    return lab
def card():
    f = QFrame()
    f.setObjectName("card")
    return f
def empty_state(title, text):
    w = QFrame()
    lay = QVBoxLayout(w)
    lay.addStretch(1)
    a = QLabel(title)
    a.setObjectName("title")
    a.setAlignment(Qt.AlignCenter)
    b = QLabel(text)
    b.setObjectName("caption")
    b.setWordWrap(True)
    b.setAlignment(Qt.AlignCenter)
    lay.addWidget(a)
    lay.addWidget(b)
    lay.addStretch(1)
    return w
def pil_to_pixmap(im):
    im = im.convert("RGBA")
    data = im.tobytes("raw", "RGBA")
    img = QImage(data, im.width, im.height, 4 * im.width, QImage.Format_RGBA8888).copy()
    return QPixmap.fromImage(img)
def png_pixmap(png_bytes, size=None):
    img = QImage.fromData(png_bytes, "PNG")
    pm = QPixmap.fromImage(img)
    if size:
        pm = pm.scaled(size, size, Qt.IgnoreAspectRatio, Qt.FastTransformation)
    return pm
def tiled_pixmap(png_bytes, size=96, times=2):
    one = png_pixmap(png_bytes)
    pm = QPixmap(size, size)
    p = QPainter(pm)
    step = size / float(times)
    for i in range(times):
        for j in range(times):
            p.drawPixmap(int(i * step), int(j * step), int(step), int(step), one)
    p.end()
    return pm
class Thumbnailer:
    def __init__(self, studio, size=176):
        self.studio = studio
        self.size = size
        self.view = None
        self.ctx = None
        self.failed = None
        self.cache = {}
    def _ensure(self):
        if self.view is not None or self.failed:
            return self.view
        try:
            from studio.ui.context import StudioContext
            from studio.ui.viewport import Viewport
            self.ctx = StudioContext(self.studio.settings, self.studio.ctx.registry)
            self.ctx.tokens = self.studio.ctx.tokens
            class ThumbView(Viewport):
                def _overlay(self):
                    pass
                def options(self):
                    o = super().options()
                    o["grid"] = False
                    o["markers"] = False
                    return o
            self.view = ThumbView(self.ctx)
            self.view.setAttribute(Qt.WA_DontShowOnScreen, True)
            self.view.setAttribute(Qt.WA_QuitOnClose, False)
            self.view.resize(QSize(self.size, self.size))
            self.view.show()
        except Exception as why:
            self.failed = str(why)
            self.view = None
        return self.view
    def render(self, key, pieces, yaw=35.0, pitch=28.0):
        if key in self.cache:
            return self.cache[key]
        view = self._ensure()
        if view is None:
            return None
        sc = self.ctx.scene
        sc.set_pieces([dict(p) for p in pieces], meta={})
        sc.set_markers([])
        try:
            cam = view.camera
            cam.yaw, cam.pitch, cam.side = yaw, pitch, "user"
            cam.set_ortho(False)
            view.frame_all(animate=False)
            view.camera.zoom(1.4)
            img = view.grabFramebuffer()
        except Exception as why:
            self.failed = str(why)
            return None
        if view.renderer is None or not getattr(view.renderer, "ready", False) or img.isNull():
            self.failed = view.gl_error or "no OpenGL"
            return None
        pm = QPixmap.fromImage(img)
        self.cache[key] = pm
        return pm
    def iso_fallback(self, key, pieces, size=None):
        k = ("iso", key)
        if k in self.cache:
            return self.cache[k]
        try:
            from mapgen.render import views
            im = views.iso({"pieces": pieces, "spawns": [], "key": "thumb"},
                           size=size or self.size)
            pm = pil_to_pixmap(im)
        except Exception:
            pm = QPixmap(size or self.size, size or self.size)
            pm.fill(QColor("#2e3238"))
        self.cache[k] = pm
        return pm
    def picture(self, key, pieces):
        return self.render(key, pieces) or self.iso_fallback(key, pieces)
def mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0
