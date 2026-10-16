import os
import sys
from .. import packaged
KEY = "app.desktop_entry"
QUESTION = ("Put Oldfart Studio on your desktop and in your app menu?\n\n"
            "Then it starts with a double-click like any other program, and .ofmap "
            "maps open in it. You can change this later in Preferences > Tools.")
def appimage(env=None):
    env = os.environ if env is None else env
    path = env.get("APPIMAGE")
    return path if path and sys.platform.startswith("linux") and os.path.isfile(path) else None
def apply(choice, path, env=None):
    if choice == "yes":
        if not packaged.integrated(env) or packaged.stale(path, env):
            return packaged.integrate(path, env), []
        return [], []
    if choice == "no":
        return [], packaged.unintegrate(env)
    return [], []
def gl_notice(studio, env=None):
    env = os.environ if env is None else env
    text = env.get("OF_STUDIO_GL_NOTICE")
    if text:
        try:
            studio.window.statusBar().showMessage(text, 20000)
        except (AttributeError, RuntimeError):
            pass
    return text
def dark_title_bar(window, dark=True):
    if not sys.platform.startswith("win"):
        return False
    try:
        from PySide6.QtCore import Qt
        from PySide6.QtGui import QGuiApplication
        QGuiApplication.styleHints().setColorScheme(
            Qt.ColorScheme.Dark if dark else Qt.ColorScheme.Light)
    except Exception:
        pass
    try:
        import ctypes
        value = ctypes.c_int(1 if dark else 0)
        hwnd = int(window.winId())
        for attribute in (20, 19):
            if ctypes.windll.dwmapi.DwmSetWindowAttribute(
                    hwnd, attribute, ctypes.byref(value), ctypes.sizeof(value)) == 0:
                return True
    except Exception:
        return False
    return False
def _is_dark(colour):
    try:
        c = colour.lstrip("#")
        r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    except (ValueError, AttributeError, IndexError):
        return True
    return (0.299 * r + 0.587 * g + 0.114 * b) < 128
def after_show(studio, settings, env=None, ask=None):
    gl_notice(studio, env)
    try:
        dark_title_bar(studio.window, _is_dark(settings["ui.background"]))
    except (KeyError, AttributeError):
        pass
    path = appimage(env)
    if path is None or KEY not in settings.values:
        return None
    def changed(key, value):
        if key == KEY:
            try:
                apply(value, path, env)
            except OSError as exc:
                sys.stderr.write("studio: desktop entry: %s\n" % exc)
    settings.listen(changed)
    if settings[KEY] != "ask":
        changed(KEY, settings[KEY])
        return settings[KEY]
    def question():
        if ask is not None:
            yes = ask(QUESTION)
        else:
            from PySide6.QtWidgets import QMessageBox
            box = QMessageBox(studio.window)
            box.setWindowTitle("Oldfart Studio")
            box.setIcon(QMessageBox.Question)
            box.setText(QUESTION)
            yes_button = box.addButton("Yes, add the icon", QMessageBox.YesRole)
            box.addButton("No, thanks", QMessageBox.NoRole)
            box.exec()
            yes = box.clickedButton() is yes_button
        settings.set(KEY, "yes" if yes else "no")
        try:
            settings.save()
        except OSError:
            pass
        return settings[KEY]
    if ask is not None:
        return question()
    from PySide6.QtCore import QTimer
    QTimer.singleShot(700, question)
    return "ask"
