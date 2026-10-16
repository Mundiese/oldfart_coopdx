import argparse
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
from studio import packaged
packaged.bootstrap()
def choose_platform(env=None, gpu=None, platform=None):
    from studio import glchoice
    real = env is None
    env = os.environ if env is None else env
    if gpu is None and real:
        gpu = glchoice.detect_gpu()
    d = glchoice.apply(glchoice.decide(env, gpu, platform), env)
    if real:
        glchoice.log("start %s; GPU %s; %s" % (sys.platform, d.gpu, d.why))
    return env.get("QT_QPA_PLATFORM"), env.get("PYOPENGL_PLATFORM")
def activate_claude_venv():
    try:
        from mapgen.backends import sdkenv
        return sdkenv.activate()
    except Exception:
        return False
def main(argv):
    ap = argparse.ArgumentParser(prog="python3 tools/studio",
                                 description="Oldfart Studio: build, edit and export the mod's maps.")
    ap.add_argument("source", nargs="?", help="a mapgen --out folder, a layout .json or venue:<key>")
    ap.add_argument("--selftest", action="store_true", help="run the checks headless and exit")
    ap.add_argument("--shots", metavar="DIR", help="render every view of the map into DIR and exit")
    ap.add_argument("--quad", action="store_true", help="start in the quad view")
    ap.add_argument("--settings", metavar="FILE", help="use this settings file")
    ap.add_argument("--version", action="store_true")
    args = ap.parse_args(argv)
    choose_platform()
    activate_claude_venv()
    from studio import VERSION
    if args.version:
        print("Oldfart Studio %s" % VERSION)
        return 0
    if args.selftest or args.shots:
        from studio import selftest
        return selftest.main(args)
    try:
        import PySide6
        import OpenGL
    except ImportError as exc:
        from studio import PIP_HINT
        print("studio: %s.\nInstall the requirements:\n"
              "  CachyOS/Arch:  sudo pacman -S pyside6 python-opengl\n"
              "  or a venv:     python3 -m venv ~/.venvs/studio && "
              "~/.venvs/studio/bin/%s" % (exc, PIP_HINT))
        return 2
    from studio.core import settings as smod
    settings = smod.Settings(args.settings).load()
    from studio.ui import glprobe
    glprobe.decide(settings)
    from studio.ui import app as appmod
    if args.quad:
        settings.set("view.layout", "quad")
    qapp = appmod.make_app(settings, sys.argv[:1])
    card = splash(settings)
    studio = appmod.Studio.create(settings)
    source = args.source
    if source is None and settings.recent and os.path.exists(settings.recent[0]):
        source = settings.recent[0]
    start_up(studio, settings, source, card=card)
    return qapp.exec()
def splash(settings):
    try:
        from PySide6.QtCore import QRect, Qt
        from PySide6.QtGui import QColor, QFont, QPainter, QPixmap
        from PySide6.QtWidgets import QApplication, QSplashScreen
        from studio import APP_NAME, VERSION
        from studio.core import theme
        try:
            t = theme.tokens(settings["ui.accent"], settings["ui.background"])
        except Exception:
            t = {}
        w, h = 420, 150
        pm = QPixmap(w, h)
        pm.fill(QColor(t.get("window", "#1d2026")))
        p = QPainter(pm)
        p.setRenderHint(QPainter.Antialiasing)
        icon = os.path.join(HERE, "packaging", "oldfart-studio.png")
        if os.path.exists(icon):
            p.drawPixmap(QRect(24, 35, 80, 80), QPixmap(icon))
        p.setPen(QColor(t.get("text", "#e6e6e6")))
        f = QFont()
        f.setPixelSize(24)
        f.setBold(True)
        p.setFont(f)
        p.drawText(QRect(124, 38, w - 140, 34), Qt.AlignLeft | Qt.AlignVCenter, APP_NAME)
        f.setPixelSize(14)
        f.setBold(False)
        p.setFont(f)
        p.setPen(QColor(t.get("text_off", "#9aa0a6")))
        p.drawText(QRect(124, 76, w - 140, 24), Qt.AlignLeft | Qt.AlignVCenter,
                   "Getting your workshop ready...  (%s)" % VERSION)
        p.setPen(QColor(t.get("accent", "#5b8cff")))
        p.drawRect(0, 0, w - 1, h - 1)
        p.end()
        card = QSplashScreen(pm)
        card.show()
        QApplication.processEvents()
        return card
    except Exception:
        return None
def start_up(studio, settings, source, paint_ms=60, card=None):
    from PySide6.QtCore import QTimer
    from PySide6.QtWidgets import QApplication
    studio.startup_owned = True
    studio.starting = True
    studio.window.show()
    if card is not None:
        card.close()
        card.deleteLater()
    from studio.ui import firstrun
    firstrun.after_show(studio, settings)
    if source:
        studio.window.statusBar().showMessage(
            "Opening %s..." % os.path.basename(str(source).rstrip("/\\")))
    def step():
        if source:
            QApplication.processEvents()
            try:
                studio.open(source)
                studio.window.statusBar().clearMessage()
            except Exception as exc:
                studio.window.statusBar().showMessage("Could not open %s: %s" % (source, exc))
        try:
            ed = getattr(studio, "editor", None)
            if ed is not None and hasattr(ed, "offer_recovery_once"):
                ed.offer_recovery_once()
        finally:
            studio.starting = False
    QTimer.singleShot(paint_ms, step)
    return step
def leave(rc):
    if sys.platform.startswith("win") and os.environ.get("OLDFART_PACKAGED"):
        import atexit
        atexit._run_exitfuncs()
        for stream in (sys.stdout, sys.stderr):
            try:
                stream.flush()
            except Exception:
                pass
        os._exit(int(rc or 0))
    return rc
if __name__ == "__main__":
    sys.exit(leave(main(sys.argv[1:])))
