from PySide6.QtCore import QEvent, QObject, QTimer
from PySide6.QtWidgets import QWidget
class HeaderFit(QObject):
    def __init__(self, toolbar):
        super().__init__(toolbar)
        self.tb = toolbar
        self.steps = []
        self.level = 0
        self._busy = False
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.setInterval(0)
        self._timer.timeout.connect(self.fit)
        toolbar.installEventFilter(self)
    def add_step(self, name, fn, order=50):
        self.steps = [s for s in self.steps if s[1] != name]
        self.steps.append((order, name, fn))
        self.steps.sort(key=lambda s: s[0])
        self.later()
        return name
    def applied(self):
        return [name for _, name, _ in self.steps[:self.level]]
    def later(self):
        self._timer.start()
    def eventFilter(self, obj, ev):
        if obj is self.tb and not self._busy and ev.type() in (
                QEvent.Resize, QEvent.StyleChange, QEvent.FontChange, QEvent.Show):
            self.later()
        return False
    def _widgets(self):
        out = []
        for a in self.tb.actions():
            w = self.tb.widgetForAction(a)
            if w is not None and isinstance(w, QWidget) and a.isVisible():
                out.append(w)
        return out
    def _needed(self):
        lay = self.tb.layout()
        if lay is not None:
            lay.invalidate()
        return self.tb.sizeHint().width()
    def fit(self):
        if self._busy:
            return self.level
        self._busy = True
        try:
            widgets = self._widgets()
            for w in widgets:
                if w.minimumWidth():
                    w.setMinimumWidth(0)
            for _, _, fn in reversed(self.steps[:self.level]):
                fn(False)
            self.level = 0
            room = self.tb.width()
            if room > 0:
                while self.level < len(self.steps) and self._needed() > room:
                    self.steps[self.level][2](True)
                    self.level += 1
            for w in self._widgets():
                hint = w.sizeHint().width()
                if hint > 0 and not _stretches(w):
                    w.setMinimumWidth(hint)
        finally:
            self._busy = False
        return self.level
    def squeezed(self):
        out = []
        for w in self._widgets():
            if not w.isVisible() or _stretches(w):
                continue
            if w.width() + 1 < w.sizeHint().width():
                out.append(w)
        return out
def _stretches(w):
    from PySide6.QtWidgets import QSizePolicy
    return w.sizePolicy().horizontalPolicy() == QSizePolicy.Expanding and w.sizeHint().width() <= 0
