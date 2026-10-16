from PySide6.QtCore import Qt
from PySide6.QtGui import QColor, QKeySequence
from PySide6.QtWidgets import (QCheckBox, QColorDialog, QComboBox, QDialog, QDialogButtonBox,
                               QDoubleSpinBox, QFormLayout, QHBoxLayout, QKeySequenceEdit, QLabel,
                               QLineEdit, QListWidget, QPushButton, QScrollArea, QSpinBox,
                               QStackedWidget, QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget)
from ..core import keymap, settings as smod
PAGE_EXTRAS = {}
class Preferences(QDialog):
    def __init__(self, settings, parent=None, on_keys=None):
        super().__init__(parent)
        self.setWindowTitle("Preferences")
        self.resize(760, 560)
        self.s = settings
        self.on_keys = on_keys
        self._editors = {}
        self._built = set()
        self._building = False
        outer = QHBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)
        left = QVBoxLayout()
        left.setContentsMargins(8, 10, 0, 8)
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search settings")
        self.search.setClearButtonEnabled(True)
        self.search.textChanged.connect(self.filter)
        left.addWidget(self.search)
        self.nav = QListWidget()
        self.nav.setFixedWidth(170)
        left.addWidget(self.nav, 1)
        self.stack = QStackedWidget()
        self.rows = {}
        outer.addLayout(left)
        right = QVBoxLayout()
        right.setContentsMargins(16, 14, 16, 12)
        right.addWidget(self.stack, 1)
        buttons = QDialogButtonBox(QDialogButtonBox.Close)
        reset = QPushButton("Reset page\u2026")
        reset.setAutoDefault(False)
        reset.setDefault(False)
        reset.setToolTip("This page's settings back to their defaults (asks first)")
        buttons.addButton(reset, QDialogButtonBox.ResetRole)
        reset.clicked.connect(self.ask_reset)
        self.reset_btn = reset
        buttons.rejected.connect(self.accept)
        right.addWidget(buttons)
        outer.addLayout(right, 1)
        for section in smod.SECTIONS:
            self.nav.addItem(section)
            self.stack.addWidget(QWidget())
        self.keys = None
        self.nav.currentRowChanged.connect(self._show_page)
        self.nav.setCurrentRow(0)
        from PySide6.QtCore import QTimer
        self._later = QTimer(self)
        self._later.setInterval(0)
        self._later.timeout.connect(self._build_next)
        self._later.start()
    @property
    def editors(self):
        self._ensure_all()
        return self._editors
    def _ensure(self, i):
        section = smod.SECTIONS[i]
        if i in self._built or self._building:
            return
        if section == "Keys":
            return
        self._building = True
        try:
            self._built.add(i)
            old = self.stack.widget(i)
            cur = self.stack.currentIndex()
            self.stack.insertWidget(i, self._page(section))
            self.stack.removeWidget(old)
            old.deleteLater()
            self.stack.setCurrentIndex(cur)
        finally:
            self._building = False
    def _ensure_all(self):
        for i in range(len(smod.SECTIONS)):
            self._ensure(i)
    def _build_next(self):
        for i, section in enumerate(smod.SECTIONS):
            if section != "Keys" and i not in self._built:
                self._ensure(i)
                return
        self._later.stop()
    def _show_page(self, i):
        if i < 0:
            return
        if smod.SECTIONS[i] == "Keys" and self.keys is None:
            old = self.stack.widget(i)
            self.stack.insertWidget(i, self._keys_page())
            self.stack.removeWidget(old)
            old.deleteLater()
        else:
            self._ensure(i)
        self.stack.setCurrentIndex(i)
    def filter(self, text):
        words = [w for w in (text or "").lower().split() if w]
        self._ensure_all()
        shown = []
        for i, section in enumerate(smod.SECTIONS):
            hits = 0
            for form, row, hay in self.rows.get(section, []):
                ok = all(w in hay for w in words)
                form.setRowVisible(row, ok)
                hits += ok
            keep = not words or hits > 0 or (section == "Keys" and all(
                w in "keys shortcuts keyboard" for w in words))
            self.nav.item(i).setHidden(not keep)
            if keep:
                shown.append(section)
        cur = self.nav.currentRow()
        if shown and (cur < 0 or self.nav.item(cur).isHidden()):
            self.nav.setCurrentRow(smod.SECTIONS.index(shown[0]))
        return shown
    def _page(self, section):
        inner = QWidget()
        form = QFormLayout(inner)
        form.setHorizontalSpacing(18)
        form.setVerticalSpacing(10)
        title = QLabel(section)
        title.setObjectName("title")
        form.addRow(title)
        for key, (default, kind, extra, sec, label, help_text) in smod.SCHEMA.items():
            if sec != section:
                continue
            ed = self._editor(key, kind, extra)
            ed.setToolTip(help_text)
            self._editors[key] = ed
            box = QVBoxLayout()
            box.setSpacing(2)
            box.addWidget(ed)
            if help_text:
                h = QLabel(help_text)
                h.setObjectName("caption")
                h.setWordWrap(True)
                box.addWidget(h)
            form.addRow(label, box)
            self.rows.setdefault(section, []).append(
                (form, form.rowCount() - 1, ("%s %s %s" % (label, help_text, key)).lower()))
        for extra in PAGE_EXTRAS.get(section, []):
            extra(self, form)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setWidget(inner)
        scroll.setProperty("section", section)
        return scroll
    def _editor(self, key, kind, extra):
        v = self.s[key]
        if kind == "bool":
            ed = QCheckBox()
            ed.setChecked(bool(v))
            ed.toggled.connect(lambda val, k=key: self.s.set(k, bool(val)))
        elif kind == "int":
            ed = QSpinBox()
            ed.setKeyboardTracking(False)
            ed.setRange(*extra)
            ed.setValue(int(v))
            ed.setMaximumWidth(140)
            ed.valueChanged.connect(lambda val, k=key: self.s.set(k, int(val)))
        elif kind == "float":
            ed = QDoubleSpinBox()
            ed.setKeyboardTracking(False)
            ed.setRange(*extra)
            ed.setDecimals(2)
            ed.setSingleStep((extra[1] - extra[0]) / 40.0)
            ed.setValue(float(v))
            ed.setMaximumWidth(140)
            ed.valueChanged.connect(lambda val, k=key: self.s.set(k, float(val)))
        elif kind == "choice":
            ed = QComboBox()
            for c in extra:
                ed.addItem(str(c), c)
            ed.setCurrentIndex(list(extra).index(v))
            ed.currentIndexChanged.connect(lambda i, k=key, e=ed: self.s.set(k, e.itemData(i)))
        elif kind == "colour":
            ed = QPushButton(v)
            self._paint_colour(ed, v)
            ed.clicked.connect(lambda _=False, k=key, e=ed: self._pick_colour(k, e))
        else:
            ed = QLineEdit(str(v))
            ed.editingFinished.connect(lambda k=key, e=ed: self.s.set(k, e.text()))
        return ed
    def _paint_colour(self, button, value):
        button.setText(value)
        button.setStyleSheet("background: %s; color: %s;" % (
            value, "#000" if QColor(value).lightness() > 140 else "#fff"))
    def _pick_colour(self, key, button):
        c = QColorDialog.getColor(QColor(self.s[key]), self, "Colour")
        if c.isValid():
            v = self.s.set(key, c.name())
            self._paint_colour(button, v)
    def _keys_page(self):
        page = QWidget()
        lay = QVBoxLayout(page)
        title = QLabel("Keys")
        title.setObjectName("title")
        lay.addWidget(title)
        note = QLabel("Click a key cell and press the new key. Numpad keys show as Num+. "
                      "Mouse navigation is on the Navigation page.")
        note.setObjectName("caption")
        note.setWordWrap(True)
        lay.addWidget(note)
        self.keys = QTableWidget(0, 3)
        self.keys.setHorizontalHeaderLabels(["Action", "Key", "Second key"])
        self.keys.verticalHeader().setVisible(False)
        self.keys.horizontalHeader().setStretchLastSection(True)
        self.keys.setColumnWidth(0, 230)
        self.keys.setColumnWidth(1, 160)
        lay.addWidget(self.keys, 1)
        self.conflict = QLabel("")
        self.conflict.setObjectName("caption")
        lay.addWidget(self.conflict)
        self._fill_keys()
        return page
    def _fill_keys(self):
        km = self.s.keys
        actions = sorted(keymap.ACTIONS.items(), key=lambda kv: (kv[1][2], kv[1][1]))
        self.keys.setRowCount(len(actions))
        for row, (action, (_, label, group)) in enumerate(actions):
            item = QTableWidgetItem("%s - %s" % (group, label))
            item.setFlags(item.flags() & ~Qt.ItemIsEditable)
            self.keys.setItem(row, 0, item)
            current = km.keys(action) + ["", ""]
            for col in (1, 2):
                ed = QKeySequenceEdit(QKeySequence(current[col - 1]))
                ed.setMaximumSequenceLength(1)
                ed.editingFinished.connect(lambda a=action, r=row: self._key_changed(a, r))
                self.keys.setCellWidget(row, col, ed)
            self.keys.setRowHeight(row, 30)
        self._conflicts()
    def _key_changed(self, action, row):
        keys = []
        for col in (1, 2):
            text = self.keys.cellWidget(row, col).keySequence().toString(QKeySequence.PortableText)
            if text:
                keys.append(text)
        self.s.keys.set(action, keys)
        self._conflicts()
        if self.on_keys:
            self.on_keys()
    def _conflicts(self):
        c = self.s.keys.conflicts()
        if c:
            self.conflict.setText("Conflicts: " + "; ".join("%s: %s" % (k, ", ".join(v))
                                                         for k, v in sorted(c.items())))
            self.conflict.setStyleSheet("color: #ef5350;")
        else:
            self.conflict.setText("No conflicts.")
            self.conflict.setStyleSheet("")
    def ask_reset(self):
        from PySide6.QtWidgets import QMessageBox
        section = smod.SECTIONS[self.stack.currentIndex()]
        if QMessageBox.question(self, "Reset page", "Put every setting on the %s page back "
                                "to its default?" % section) != QMessageBox.Yes:
            return False
        self.reset_page()
        return True
    def reset_page(self):
        w = self.stack.currentWidget()
        section = smod.SECTIONS[self.stack.currentIndex()]
        if section == "Keys":
            self.s.keys.reset()
            self._fill_keys()
            if self.on_keys:
                self.on_keys()
            return
        for key, row in smod.SCHEMA.items():
            if row[3] == section:
                self.s.set(key, row[0])
                ed = self.editors[key]
                v = self.s[key]
                if isinstance(ed, QCheckBox):
                    ed.setChecked(v)
                elif isinstance(ed, (QSpinBox, QDoubleSpinBox)):
                    ed.setValue(v)
                elif isinstance(ed, QComboBox):
                    ed.setCurrentIndex(ed.findData(v))
                elif isinstance(ed, QPushButton):
                    self._paint_colour(ed, v)
                elif isinstance(ed, QLineEdit):
                    ed.setText(v)
        del w
