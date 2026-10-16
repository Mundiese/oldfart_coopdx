from PySide6.QtCore import QEvent, QObject, Qt
from PySide6.QtWidgets import (QAbstractItemView, QAbstractSlider, QAbstractSpinBox, QApplication,
                               QComboBox, QLineEdit, QPlainTextEdit, QTextEdit)
OWN_KEYS = {
    Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_PageUp, Qt.Key_PageDown,
    Qt.Key_Home, Qt.Key_End, Qt.Key_Delete, Qt.Key_Backspace, Qt.Key_Return, Qt.Key_Enter,
    Qt.Key_Space, Qt.Key_F2,
}
TEXT_CHORDS = {Qt.Key_A, Qt.Key_Z, Qt.Key_Y, Qt.Key_C, Qt.Key_X, Qt.Key_V}
TEXT_STANDARD = ("SelectAll", "Copy", "Cut", "Paste", "Undo", "Redo", "Delete", "Backspace",
                 "DeleteStartOfWord", "DeleteEndOfWord", "DeleteEndOfLine", "DeleteCompleteLine",
                 "MoveToNextWord", "MoveToPreviousWord", "SelectNextWord", "SelectPreviousWord",
                 "MoveToStartOfLine", "MoveToEndOfLine", "SelectStartOfLine", "SelectEndOfLine",
                 "MoveToStartOfDocument", "MoveToEndOfDocument", "SelectStartOfDocument",
                 "SelectEndOfDocument", "MoveToNextLine", "MoveToPreviousLine", "SelectNextLine",
                 "SelectPreviousLine", "MoveToNextChar", "MoveToPreviousChar", "SelectNextChar",
                 "SelectPreviousChar", "MoveToStartOfBlock", "MoveToEndOfBlock",
                 "SelectStartOfBlock", "SelectEndOfBlock", "InsertLineSeparator")
_text_keys = None
def text_standard_keys():
    global _text_keys
    if _text_keys is None:
        from PySide6.QtGui import QKeySequence
        out = set()
        for name in TEXT_STANDARD:
            std = getattr(QKeySequence.StandardKey, name, None)
            if std is None:
                continue
            for seq in QKeySequence.keyBindings(std):
                if seq.count() != 1:
                    continue
                combo = seq[0]
                out.add((int(combo.key()), int(combo.keyboardModifiers().value)
                         if hasattr(combo.keyboardModifiers(), "value")
                         else int(combo.keyboardModifiers())))
        _text_keys = out
    return _text_keys
WINDOW_CHORDS = {(Qt.Key_S, 0), (Qt.Key_S, 1), (Qt.Key_O, 0), (Qt.Key_N, 0), (Qt.Key_Q, 0),
                 (Qt.Key_W, 0), (Qt.Key_Return, 0), (Qt.Key_Enter, 0), (Qt.Key_P, 1),
                 (Qt.Key_Comma, 0), (Qt.Key_F, 1)}
def _window_chord(key, rest):
    extra = 1 if rest == Qt.ShiftModifier else (0 if rest in (Qt.NoModifier, 0) else 2)
    return (key, extra) in WINDOW_CHORDS
def _mods_int(mods):
    return int(mods.value) if hasattr(mods, "value") else int(mods)
ITEM_VIEWS = (QAbstractItemView,)
TEXT = (QLineEdit, QTextEdit, QPlainTextEdit, QAbstractSpinBox)
OTHER = (QComboBox, QAbstractSlider)
def claimer(widget):
    w = widget
    while w is not None:
        if isinstance(w, ITEM_VIEWS + TEXT + OTHER):
            return w
        if w.isWindow():
            return None
        w = w.parentWidget()
    return None
def keeps(widget, key, mods, text=""):
    w = claimer(widget)
    if w is None:
        return False
    mods = mods & ~Qt.KeypadModifier
    plain = mods in (Qt.NoModifier, Qt.ShiftModifier)
    if plain and (key in OWN_KEYS or (text and text.isprintable() and not text.isspace())):
        return True
    if isinstance(w, TEXT) and mods == Qt.ControlModifier and key in TEXT_CHORDS:
        return True
    if isinstance(w, TEXT) and (int(key), _mods_int(mods)) in text_standard_keys():
        return True
    if isinstance(w, TEXT) and (mods & Qt.ControlModifier) and \
            not _window_chord(key, mods & ~Qt.ControlModifier):
        return True
    if isinstance(w, ITEM_VIEWS) and mods == Qt.ControlModifier and key == Qt.Key_A:
        return True
    return False
class KeyGuard(QObject):
    def eventFilter(self, obj, ev):
        if ev.type() == QEvent.ShortcutOverride:
            focus = QApplication.focusWidget()
            if focus is not None and obj is focus and keeps(focus, ev.key(), ev.modifiers(),
                                                            ev.text()):
                ev.accept()
                return True
        return False
class _Keys(QObject):
    def __init__(self, widget, table):
        super().__init__(widget)
        self.table = table
    def eventFilter(self, obj, ev):
        if ev.type() == QEvent.KeyPress and ev.modifiers() in (Qt.NoModifier,
                                                               Qt.KeypadModifier):
            fn = self.table.get(ev.key())
            if fn is not None:
                fn()
                return True
        return False
def list_keys(widget, table):
    f = _Keys(widget, table)
    widget.installEventFilter(f)
    return f
def install(app=None):
    app = app or QApplication.instance()
    guard = getattr(app, "_studio_keyguard", None)
    if guard is None:
        guard = KeyGuard(app)
        from . import appfilters
        appfilters.install(guard, app)
        app._studio_keyguard = guard
    return guard
