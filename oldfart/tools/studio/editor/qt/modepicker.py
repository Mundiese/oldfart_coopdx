from PySide6.QtCore import QEvent, QPointF, QRectF, QSize, Qt, QTimer, Signal
from PySide6.QtGui import QColor, QFont, QIcon, QPainter, QPen, QPixmap
from PySide6.QtWidgets import (QAbstractItemView, QButtonGroup, QCheckBox, QHBoxLayout, QLabel,
                               QLineEdit, QPushButton, QRadioButton, QTreeWidget,
                               QTreeWidgetItem, QVBoxLayout, QWidget)
from .. import gamemodes as gm
KEY_ROLE = Qt.UserRole
ISSUE_ROLE = Qt.UserRole + 1
def _tokens():
    try:
        from studio.core import theme
        return theme.tokens()
    except Exception:
        return {"ok": "#5cc879", "warn": "#f5b041", "bad": "#ef5350"}
class ElidedLabel(QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(text, parent)
        self._full = text
        self.setToolTip(text)
        self.setMinimumWidth(40)
    def setText(self, text):
        self._full = text
        super().setText(text)
    def full(self):
        return self._full
    def shown(self, width=None):
        w = self.contentsRect().width() if width is None else width
        return self.fontMetrics().elidedText(self._full, Qt.ElideRight, max(0, w))
    def minimumSizeHint(self):
        return QSize(40, super().minimumSizeHint().height())
    def paintEvent(self, ev):
        p = QPainter(self)
        p.setPen(self.palette().color(self.foregroundRole()))
        r = self.contentsRect()
        p.drawText(r, int(self.alignment() | Qt.AlignVCenter), self.shown(r.width()))
        p.end()
def row_height():
    b = QPushButton("Fix")
    return max(b.sizeHint().height(), QLabel("Ag").sizeHint().height() + 6)
def status_icon(level, size=14):
    colours = _tokens()
    colour = QColor({"ok": colours.get("ok", "#5cc879"), "warn": colours.get("warn", "#f5b041"),
                     "block": colours.get("bad", "#ef5350")}.get(level, "#8a8f98"))
    pm = QPixmap(size * 2, size * 2)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    s = float(size * 2)
    p.setPen(Qt.NoPen)
    p.setBrush(colour)
    p.drawEllipse(QRectF(0.08 * s, 0.08 * s, 0.84 * s, 0.84 * s))
    p.setPen(QPen(QColor("#0e1116"), 0.12 * s, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin))
    if level == "ok":
        p.drawPolyline([QPointF(0.3 * s, 0.52 * s), QPointF(0.45 * s, 0.67 * s),
                        QPointF(0.72 * s, 0.36 * s)])
    elif level == "warn":
        p.drawLine(QPointF(0.5 * s, 0.28 * s), QPointF(0.5 * s, 0.56 * s))
        p.drawPoint(QPointF(0.5 * s, 0.72 * s))
    else:
        p.drawLine(QPointF(0.34 * s, 0.34 * s), QPointF(0.66 * s, 0.66 * s))
        p.drawLine(QPointF(0.66 * s, 0.34 * s), QPointF(0.34 * s, 0.66 * s))
    p.end()
    pm.setDevicePixelRatio(2.0)
    return QIcon(pm)
class ModeTree(QTreeWidget):
    activated_fix = Signal(object)
    def keyPressEvent(self, ev):
        if ev.key() in (Qt.Key_Return, Qt.Key_Enter):
            item = self.currentItem()
            if item is not None and item.data(0, ISSUE_ROLE):
                self.activated_fix.emit(item)
                return
            if item is not None and item.data(0, KEY_ROLE):
                item.setCheckState(0, Qt.Unchecked if item.checkState(0) == Qt.Checked
                                   else Qt.Checked)
                return
        super().keyPressEvent(ev)
class ModePicker(QWidget):
    changed = Signal(object)
    fix = Signal(str, object)
    def __init__(self, readiness=False, compact=False, parent=None):
        super().__init__(parent)
        self.readiness = readiness
        self._layout = {}
        self._family = "shooter"
        self._players = 16
        self._size = None
        self._pick = gm.Pick()
        self._filling = False
        self.fix_buttons = {}
        self.reasons = {}
        self._row_h = 24
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(6)
        row = QHBoxLayout()
        self.only_btn = QRadioButton("Only the ticked")
        self.only_btn.setToolTip("The map is offered to the modes you tick, nothing else.\n"
                                 "Example: tick Capture the Flag and King of the Hill - "
                                 "only those two offer it.")
        self.except_btn = QRadioButton("All except the ticked")
        self.except_btn.setToolTip("The map is offered to every mode that fits it, except the "
                                   "ones you tick.\nExample: tick Sumo - every other fitting "
                                   "mode offers it.")
        self.how = QButtonGroup(self)
        self.how.addButton(self.only_btn)
        self.how.addButton(self.except_btn)
        self.only_btn.setChecked(True)
        self.only_btn.toggled.connect(self._how_changed)
        row.addWidget(self.only_btn)
        row.addWidget(self.except_btn)
        row.addStretch(1)
        lay.addLayout(row)
        row = QHBoxLayout()
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search modes - e.g. flag, race, king")
        self.search.setClearButtonEnabled(True)
        self.search.setToolTip("Type part of a mode's name or kind; Down goes into the list")
        self.search.textChanged.connect(lambda *_: self.refill())
        self.search.installEventFilter(self)
        row.addWidget(self.search, 1)
        self.reset_btn = QPushButton("Defaults")
        self.reset_btn.setAutoDefault(False)
        self.reset_btn.setToolTip("Tick the map kind's own modes that work on this map again")
        self.reset_btn.clicked.connect(self.use_defaults)
        row.addWidget(self.reset_btn)
        lay.addLayout(row)
        self.tree = ModeTree()
        self.tree.setHeaderHidden(True)
        self.tree.setColumnCount(2 if readiness else 1)
        self.tree.setRootIsDecorated(False)
        self.tree.setIndentation(12)
        self.tree.setSelectionMode(QAbstractItemView.SingleSelection)
        self.tree.setMinimumHeight(140 if compact else 250)
        self.tree.setAccessibleName("Game modes")
        self.tree.itemChanged.connect(self._ticked)
        self.tree.activated_fix.connect(self._fix_item)
        lay.addWidget(self.tree, 1)
        self.more = QCheckBox("Show modes for other map kinds too")
        self.more.setToolTip("Off: only the modes that fit this kind of map. On: every mode "
                             "that can take a map made here (they may need more points placed).")
        self.more.toggled.connect(lambda *_: self.refill())
        lay.addWidget(self.more)
        self.said = QLabel("")
        self.said.setObjectName("caption")
        self.said.setWordWrap(True)
        lay.addWidget(self.said)
    def set_context(self, layout=None, family=None, players=16, size=None):
        self._layout = layout or {}
        self._family = family or self._family
        self._players = players or 16
        self._size = size
        self.refill()
    def set_pick(self, pick):
        self._pick = gm.Pick(pick.how, pick.keys, pick.explicit)
        self._filling = True
        try:
            (self.except_btn if pick.how == gm.EXCEPT else self.only_btn).setChecked(True)
        finally:
            self._filling = False
        self.refill()
    def pick(self):
        return gm.Pick(self._pick.how, self._pick.keys, self._pick.explicit)
    def resolved(self):
        return gm.resolve(self._pick, self._layout, self._family)
    def value(self):
        if not self._pick.explicit:
            return None
        return self.resolved()[0]
    def use_defaults(self):
        self._pick = gm.Pick(gm.ONLY, gm.defaults(self._layout, self._family), False)
        self.set_pick(self._pick)
        self.changed.emit(self.pick())
    def offered(self):
        return self.resolved()[0]
    def refill(self):
        self._filling = True
        try:
            keep = self.tree.currentItem().data(0, KEY_ROLE) if self.tree.currentItem() else None
            self.tree.clear()
            self.fix_buttons = {}
            self.reasons = {}
            chosen = set(self._pick.keys)
            offered = set(self.offered())
            ready = {}
            if self.readiness:
                ready = {k: issues for k, _, issues in
                         gm.status(self._layout, sorted(offered), self._players, self._size)}
            self._row_h = row_height()
            bold = QFont(self.tree.font())
            bold.setBold(True)
            current = None
            for fam, label, keys in gm.groups(self._layout, self._family, list(chosen),
                                              self.more.isChecked(), self.search.text()):
                top = QTreeWidgetItem(["%s - %s" % (label, gm.FAMILY_WORDS.get(fam, ""))
                                       if gm.FAMILY_WORDS.get(fam) else label])
                top.setFlags(Qt.ItemIsEnabled)
                top.setFont(0, bold)
                top.setToolTip(0, "%s maps" % label)
                self.tree.addTopLevelItem(top)
                for k in keys:
                    item = QTreeWidgetItem([gm.name_of(k)])
                    if self.readiness:
                        item.setSizeHint(1, QSize(1, self._row_h))
                    item.setData(0, KEY_ROLE, k)
                    item.setFlags(Qt.ItemIsEnabled | Qt.ItemIsSelectable |
                                  Qt.ItemIsUserCheckable)
                    item.setCheckState(0, Qt.Checked if k in chosen else Qt.Unchecked)
                    item.setToolTip(0, gm.tip(k))
                    top.addChild(item)
                    if k in offered and self.readiness:
                        self._mark(item, k, ready.get(k) or [])
                    if k == keep:
                        current = item
                top.setExpanded(True)
            if current is not None:
                self.tree.setCurrentItem(current)
            self.tree.resizeColumnToContents(0)
        finally:
            self._filling = False
        self._say()
    def _mark(self, item, key, issues):
        if not issues:
            item.setIcon(0, status_icon("ok"))
            item.setText(1, "Ready")
            item.setToolTip(1, "The map has everything %s reads." % gm.name_of(key))
            item.setSizeHint(1, QSize(self.tree.fontMetrics().horizontalAdvance("Ready") + 12,
                                      self._row_h))
            return
        worst = issues[0]
        item.setIcon(0, status_icon(worst.level))
        item.setData(0, ISSUE_ROLE, dict(worst))
        more = len(issues) - 1
        item.setToolTip(1, "\n".join(i.text for i in issues))
        holder = QWidget()
        row = QHBoxLayout(holder)
        row.setContentsMargins(4, 0, 0, 0)
        row.setSpacing(6)
        lab = ElidedLabel(worst.get("short", worst.text) + (" (+%d more)" % more if more else ""))
        lab.setToolTip("\n".join(i.text for i in issues))
        row.addWidget(lab, 1)
        if worst.get("fix"):
            b = QPushButton(worst.get("fix_label") or "Fix")
            b.setAutoDefault(False)
            b.setToolTip(self._fix_tip(worst))
            b.clicked.connect(lambda *_, k=key, i=worst: QTimer.singleShot(
                0, lambda: self._do_fix(k, i)))
            row.addWidget(b)
            self.fix_buttons[key] = b
        holder.setFixedHeight(self._row_h)
        self.tree.setItemWidget(item, 1, holder)
        item.setSizeHint(1, QSize(holder.sizeHint().width(), self._row_h))
        self.reasons[key] = lab
    @staticmethod
    def _fix_tip(issue):
        fix = issue.get("fix") or {}
        if fix.get("do") == "spot":
            return "Puts it at a sensible place now (Ctrl+Z takes it back); move it after."
        if fix.get("do") == "place":
            return "Puts the tool in your hand: click in a view to place it (Esc stops)."
        return "Takes this mode off the map's list."
    def _fix_item(self, item):
        issue = item.data(0, ISSUE_ROLE)
        if issue and issue.get("fix"):
            key = item.data(0, KEY_ROLE)
            QTimer.singleShot(0, self, lambda: self._do_fix(key, gm.modeready.Issue(issue)))
    def _do_fix(self, key, issue):
        fix = issue.get("fix") or {}
        if fix.get("do") == "drop":
            self._set_ticked(key, self._pick.how == gm.EXCEPT)
            return
        self.fix.emit(key, issue)
    def _set_ticked(self, key, on):
        keys = [k for k in self._pick.keys if k != key] + ([key] if on else [])
        self._pick = gm.Pick(self._pick.how, keys, True)
        self.changed.emit(self.pick())
        QTimer.singleShot(0, self, self.refill)
    def _ticked(self, item, column):
        if self._filling or column != 0 or not item.data(0, KEY_ROLE):
            return
        self._set_ticked(item.data(0, KEY_ROLE), item.checkState(0) == Qt.Checked)
    def _how_changed(self, *_):
        if self._filling:
            return
        how = gm.ONLY if self.only_btn.isChecked() else gm.EXCEPT
        if how == self._pick.how:
            return
        only, _ = self.resolved()
        shown = gm.modeready.shown(self._layout, self._family, only)
        if how == gm.EXCEPT:
            keys = [k for k in shown if k not in only] if self._pick.explicit else []
        else:
            keys = list(only)
        self._pick = gm.Pick(how, keys, True)
        self.refill()
        self.changed.emit(self.pick())
    def _say(self):
        only, nf = self.resolved()
        if not only:
            text = "Offered to no mode - the map is for free roam (Travel) only."
        else:
            names = [gm.name_of(k) for k in only]
            text = "Offered to %d mode%s: %s." % (len(names), "" if len(names) == 1 else "s",
                                                 ", ".join(names[:6]) +
                                                 (" and %d more" % (len(names) - 6)
                                                  if len(names) > 6 else ""))
        if not self._pick.explicit:
            text += " (The map kind's own - change any tick to choose.)"
        if self.readiness and only:
            ready = gm.status(self._layout, only, self._players, self._size)
            blocked = [n for _, n, issues in ready if any(i.level == "block" for i in issues)]
            if blocked:
                text += " Not playable yet: %s - press the button next to it." % ", ".join(
                    blocked)
        self.said.setText(text)
    def eventFilter(self, obj, ev):
        if obj is self.search and ev.type() == QEvent.KeyPress and ev.key() == Qt.Key_Down:
            self.tree.setFocus()
            first = self.tree.topLevelItem(0)
            if first is not None and first.childCount():
                self.tree.setCurrentItem(first.child(0))
            return True
        return super().eventFilter(obj, ev)
