from PySide6.QtGui import QGuiApplication
from PySide6.QtWidgets import QHBoxLayout, QToolButton, QWidget
class SeedBar(QWidget):
    def __init__(self, ed):
        super().__init__()
        self.ed = ed
        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(4)
        self.back = QToolButton()
        self.back.setText("<")
        self.back.setToolTip("The map before (Alt+Left) - its seed and its result")
        self.back.clicked.connect(lambda: ed.run_action("map.seed_back"))
        from studio.ui.reflow import ElideLabel
        self.label = ElideLabel()
        self.label.setObjectName("dim")
        self.label.setStatusTip("The seed this map was built with - the same wish and seed "
                              "build the same map again")
        self.copy = QToolButton()
        self.copy.setText("Copy")
        self.copy.setToolTip("Copy the seed")
        self.copy.clicked.connect(self.copy_seed)
        self.lock = QToolButton()
        self.lock.setText("Lock")
        self.lock.setCheckable(True)
        self.lock.setToolTip("Keep this seed: Generate builds with it again (change the wish "
                             "and see what it does to the same map). Off: every Generate "
                             "rolls a new one (Ctrl+Alt+L)")
        self.lock.toggled.connect(self._locked)
        self.fwd = QToolButton()
        self.fwd.setText(">")
        self.fwd.setToolTip("The map after (Alt+Right)")
        self.fwd.clicked.connect(lambda: ed.run_action("map.seed_forward"))
        row.addWidget(self.back)
        row.addWidget(self.label, 1)
        row.addWidget(self.copy)
        row.addWidget(self.lock)
        row.addWidget(self.fwd)
        self.refresh()
    def copy_seed(self):
        seed = self.ed.seeds.current_seed()
        if seed is not None:
            QGuiApplication.clipboard().setText(str(seed))
            self.ed.hint("Seed %d copied" % seed)
    def _locked(self, on):
        if self.ed.seeds.locked != on:
            self.ed.run_action("map.seed_lock")
    def refresh(self):
        book = self.ed.seeds
        self.label.setText(book.line())
        self.back.setEnabled(book.can_back())
        self.fwd.setEnabled(book.can_forward())
        self.copy.setEnabled(book.current_seed() is not None)
        self.lock.blockSignals(True)
        self.lock.setChecked(book.locked)
        self.lock.blockSignals(False)
