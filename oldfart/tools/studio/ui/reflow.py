from PySide6.QtCore import QSize
from PySide6.QtWidgets import QGridLayout, QLabel, QPushButton, QSizePolicy, QWidget
class ReflowGrid(QWidget):
    def __init__(self, widgets=(), max_cols=4, min_cols=2, spacing=6, parent=None):
        super().__init__(parent)
        self.max_cols = max(1, max_cols)
        self.min_cols = max(1, min(min_cols, self.max_cols))
        self.items = []
        self.cols = 0
        self.grid = QGridLayout(self)
        self.grid.setContentsMargins(0, 0, 0, 0)
        self.grid.setSpacing(spacing)
        self.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Minimum)
        for w in widgets:
            self.add(w)
    def add(self, widget):
        widget.setParent(self)
        widget.setSizePolicy(QSizePolicy.Expanding, widget.sizePolicy().verticalPolicy())
        self.items.append(widget)
        self._lay(self._cols_for(self.width()) if self.width() > 0 else self.max_cols, force=True)
        return widget
    def _cell(self):
        shown = [w for w in self.items if not w.isHidden()] or self.items
        return max((w.sizeHint().width() for w in shown), default=0)
    def _cols_for(self, width):
        cell, gap = self._cell(), self.grid.spacing()
        if cell <= 0:
            return self.max_cols
        fit = (width + gap) // (cell + gap)
        return int(max(self.min_cols, min(self.max_cols, fit, max(1, len(self.items)))))
    def _lay(self, cols, force=False):
        if cols == self.cols and not force:
            return False
        for w in self.items:
            self.grid.removeWidget(w)
        for c in range(max(self.cols, cols) + 1):
            self.grid.setColumnStretch(c, 0)
        n = 0
        for w in self.items:
            if w.isHidden() and w.testAttribute(_explicit_hide()):
                continue
            self.grid.addWidget(w, n // cols, n % cols)
            n += 1
        for c in range(cols):
            self.grid.setColumnStretch(c, 1)
        self.cols = cols
        self.updateGeometry()
        return True
    def needed_width(self):
        cell, gap = self._cell(), self.grid.spacing()
        m = self.grid.contentsMargins()
        k = min(self.min_cols, max(1, len(self.items)))
        return k * cell + (k - 1) * gap + m.left() + m.right()
    def minimumSizeHint(self):
        base = super().minimumSizeHint()
        return QSize(self.needed_width(), base.height())
    def hasHeightForWidth(self):
        return True
    def heightForWidth(self, width):
        cols = self._cols_for(width)
        shown = [w for w in self.items if not (w.isHidden() and w.testAttribute(_explicit_hide()))]
        rows = (len(shown) + cols - 1) // cols if shown else 0
        h = max((w.sizeHint().height() for w in shown), default=0)
        return rows * h + max(0, rows - 1) * self.grid.spacing()
    def resizeEvent(self, ev):
        self._lay(self._cols_for(ev.size().width()))
        super().resizeEvent(ev)
def _explicit_hide():
    from PySide6.QtCore import Qt
    return Qt.WA_WState_ExplicitShowHide
class ElideLabel(QLabel):
    def minimumSizeHint(self):
        return QSize(24, super().minimumSizeHint().height())
    def sizeHint(self):
        return QSize(min(super().sizeHint().width(), 240), super().sizeHint().height())
    def setText(self, text):
        super().setText(text)
        self.setToolTip(text or "")
    def paintEvent(self, _ev):
        from PySide6.QtCore import Qt
        from PySide6.QtGui import QPainter
        p = QPainter(self)
        r = self.contentsRect()
        p.setPen(self.palette().color(self.foregroundRole()))
        p.drawText(r, int(Qt.AlignLeft | Qt.AlignVCenter),
                   self.fontMetrics().elidedText(self.text(), Qt.ElideRight, r.width()))
        p.end()
class ElideButton(QPushButton):
    def __init__(self, text="", parent=None):
        super().__init__(parent)
        self._full = ""
        self.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Fixed)
        self.setText(text)
    def setText(self, text):
        self._full = text or ""
        self.updateGeometry()
        self._fit()
    def text(self):
        return self._full
    def minimumSizeHint(self):
        base = super().minimumSizeHint()
        return QSize(min(base.width(), self.fontMetrics().horizontalAdvance("M" * 8)),
                     base.height())
    def sizeHint(self):
        shown = QPushButton.text(self)
        QPushButton.setText(self, self._full)
        hint = super().sizeHint()
        QPushButton.setText(self, shown)
        return hint
    def resizeEvent(self, ev):
        super().resizeEvent(ev)
        self._fit()
    def _fit(self):
        from PySide6.QtCore import Qt
        room = max(0, self.width() - self.fontMetrics().horizontalAdvance("MM"))
        full = self._full
        shown = full if self.width() <= 0 or self.fontMetrics().horizontalAdvance(full) <= room \
            else self.fontMetrics().elidedText(full, Qt.ElideRight, room)
        if QPushButton.text(self) != shown:
            QPushButton.setText(self, shown)
def fit_to_screen(window, width, height, share=0.88):
    from PySide6.QtGui import QGuiApplication
    scr = None
    parent = window.parentWidget()
    if parent is not None and parent.screen() is not None:
        scr = parent.screen()
    scr = scr or QGuiApplication.primaryScreen()
    if scr is not None:
        geo = scr.availableGeometry()
        width = min(width, int(geo.width() * share))
        height = min(height, int(geo.height() * share))
    window.resize(width, height)
    return width, height
