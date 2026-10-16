from PySide6.QtCore import QPoint, QRect, QSize, Qt
from PySide6.QtWidgets import (QFileDialog, QFrame, QInputDialog, QLayout, QMenu, QMessageBox,
                               QScrollArea, QSizePolicy, QToolButton, QWidget)
from .. import chips as chipsmod
STYLE = {
    "understood": "",
    "taught": "font-weight: bold;",
    "assumed": "font-style: italic;",
    "unread": "text-decoration: underline;",
    "question": "font-weight: bold;",
}
PREFIX = {"understood": "", "taught": "", "assumed": "assumed: ", "unread": "? ",
          "question": "? "}
class FlowLayout(QLayout):
    def __init__(self, parent=None, spacing=4):
        super().__init__(parent)
        self._items = []
        self.setSpacing(spacing)
        self.setContentsMargins(0, 0, 0, 0)
    def addItem(self, item):
        self._items.append(item)
    def count(self):
        return len(self._items)
    def itemAt(self, i):
        return self._items[i] if 0 <= i < len(self._items) else None
    def takeAt(self, i):
        return self._items.pop(i) if 0 <= i < len(self._items) else None
    def expandingDirections(self):
        return Qt.Orientation(0)
    def hasHeightForWidth(self):
        return True
    def heightForWidth(self, width):
        return self._place(QRect(0, 0, width, 0), True)
    def setGeometry(self, rect):
        super().setGeometry(rect)
        self._place(rect, False)
    def sizeHint(self):
        return self.minimumSize()
    def minimumSize(self):
        size = QSize()
        for it in self._items:
            size = size.expandedTo(it.minimumSize())
        return size
    def _place(self, rect, test):
        x, y, row = rect.x(), rect.y(), 0
        for it in self._items:
            hint = it.sizeHint()
            if x + hint.width() > rect.right() and row > 0:
                x, y, row = rect.x(), y + row + self.spacing(), 0
            if not test:
                it.setGeometry(QRect(QPoint(x, y), hint))
            x += hint.width() + self.spacing()
            row = max(row, hint.height())
        return y + row - rect.y()
class WishChips(QWidget):
    def __init__(self, on_text, on_control, on_reread):
        super().__init__()
        self.on_text, self.on_control, self.on_reread = on_text, on_control, on_reread
        self.flow = FlowLayout(self)
        self.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Minimum)
        self.items = []
        self.text = ""
    def show_reading(self, reading, text):
        self.text = text or ""
        while self.flow.count():
            it = self.flow.takeAt(0)
            if it.widget():
                it.widget().deleteLater()
        self.items = chipsmod.chips(reading)
        for chip in self.items:
            b = QToolButton()
            b.setText(PREFIX[chip.kind] + chip.text)
            b.setStyleSheet(STYLE[chip.kind])
            b.setToolTip({"assumed": "assumed - click for the alternatives",
                          "unread": "not understood - click for suggestions or to teach it",
                          "question": "the wish says both - pick one",
                          "taught": "a word you taught"}.get(chip.kind, "understood"))
            b.setAutoRaise(True)
            if chip.options:
                menu = QMenu(b)
                for opt in chip.options:
                    act = menu.addAction(opt)
                    act.triggered.connect(lambda _=False, c=chip, o=opt: self.pick(c, o))
                b.setMenu(menu)
                b.setPopupMode(QToolButton.InstantPopup)
            self.flow.addWidget(b)
        self.setVisible(bool(self.items))
        self.updateGeometry()
        box = getattr(self, "box", None)
        if box is not None:
            box.fit()
    def pick(self, chip, option, meaning=None):
        if chip.kind == "unread" and option.startswith("teach "):
            return self.teach(chip.word, meaning)
        got = chipsmod.apply_choice(chip, option, self.text)
        if got and got[0] == "text":
            self.on_text(got[1])
        elif got and got[0] == "control":
            self.on_control(got[1], got[2])
        return got
    def teach(self, word, meaning=None):
        if meaning is None:
            meaning, ok = QInputDialog.getText(
                self, "Teach a word", "What does '%s' mean? Say it with words the reader "
                "knows (e.g. 'small, slow and with a garden'):" % word)
            if not ok or not meaning.strip():
                return None
        try:
            reads = chipsmod.teach(word, meaning)
        except ValueError as why:
            QMessageBox.information(self, "Teach a word", str(why))
            return None
        self.on_reread()
        return reads
    def export_taught(self, path=None):
        if path is None:
            path, _ = QFileDialog.getSaveFileName(self, "Export taught words",
                                                  "taught-words.json", "JSON (*.json)")
            if not path:
                return None
        return chipsmod.export_taught(path)
class ChipsBox(QScrollArea):
    CAP_LINES = 7
    def __init__(self, chips, holder=None):
        super().__init__()
        self.chips = chips
        self.holder = holder if holder is not None else chips
        chips.box = self
        self.setWidget(self.holder)
        self.setWidgetResizable(True)
        self.setFrameShape(QFrame.NoFrame)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Fixed)
        self.setObjectName("understood")
        self.fit()
    def cap(self):
        return self.CAP_LINES * (self.fontMetrics().lineSpacing() + 4)
    def need(self):
        width = max(60, self.viewport().width())
        lay = self.holder.layout()
        if lay is not None and lay.hasHeightForWidth():
            return lay.totalHeightForWidth(width)
        return self.holder.sizeHint().height()
    def fit(self):
        self.setFixedHeight(max(0, min(self.need(), self.cap())) + 2)
        return self.height()
    def resizeEvent(self, ev):
        super().resizeEvent(ev)
        want = max(0, min(self.need(), self.cap())) + 2
        if want != self.height():
            from PySide6.QtCore import QTimer
            QTimer.singleShot(0, self, self.fit)
