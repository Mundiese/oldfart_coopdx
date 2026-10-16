from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QColor, QFont
from PySide6.QtWidgets import (QHBoxLayout, QLabel, QListWidget, QListWidgetItem, QMessageBox,
                               QPushButton, QTreeWidget, QTreeWidgetItem, QVBoxLayout, QWidget)
from . import widgets
STATUS = {"pass": ("ok", "pass"), "warn": ("warn", "warn"), "fail": ("bad", "fail"),
          "n/a": ("text_off", "-")}
def grade(q):
    if q is None:
        return "-"
    for cut, word in ((0.9, "excellent"), (0.8, "good"), (0.65, "fair"), (0.0, "weak")):
        if q >= cut:
            return word
    return "weak"
class ReportPanel(QWidget):
    def __init__(self, ed):
        super().__init__()
        self.ed = ed
        t = ed.tokens
        lay = QVBoxLayout(self)
        lay.setContentsMargins(10, 10, 10, 10)
        lay.setSpacing(8)
        top = QHBoxLayout()
        self.quality = QLabel("-")
        self.quality.setStyleSheet("font-size: 30px; font-weight: 700;")
        self.quality.setToolTip("Quality: every metric scored against its family's target band "
                                "(the Sky Keep is the bar), weighted")
        self.grade = QLabel("")
        self.grade.setObjectName("dim")
        top.addWidget(self.quality)
        top.addWidget(self.grade)
        top.addStretch(1)
        self.gate = QLabel("")
        top.addWidget(self.gate)
        lay.addLayout(top)
        self.counts = QHBoxLayout()
        lay.addLayout(self.counts)
        self.measure_btn = QPushButton("Measure")
        self.measure_btn.setToolTip("Measure now (F4) - it also runs by itself after edits")
        self.measure_btn.clicked.connect(lambda: self.ed.measure(full=False))
        self.full_btn = QPushButton("Full check")
        self.full_btn.setToolTip("Sightlines, spawn exposure and the 16-bot run (a few seconds)")
        self.full_btn.clicked.connect(lambda: self.ed.measure(full=True))
        self.account_btn = QPushButton("How it was made")
        self.account_btn.setToolTip("The generator's account: what it read, chose and fixed")
        self.account_btn.clicked.connect(self._account)
        from studio.ui.reflow import ReflowGrid
        lay.addWidget(ReflowGrid((self.measure_btn, self.full_btn, self.account_btn),
                                 max_cols=3, min_cols=2))
        self.note = widgets.caption("")
        lay.addWidget(self.note)
        lay.addWidget(widgets.header("Problems", "the safety gate: an export is refused while "
                                     "any stands. Click one to select its piece."))
        self.problems = QListWidget()
        self.problems.setMaximumHeight(120)
        self.problems.itemClicked.connect(self._problem_clicked)
        self.problems.itemActivated.connect(self._problem_framed)
        lay.addWidget(self.problems)
        lay.addWidget(widgets.header("Metrics", "value, target band and status per metric"))
        self.tree = QTreeWidget()
        self.tree.setHeaderLabels(["Metric", "Value", "Target", "", ""])
        self.tree.setRootIsDecorated(True)
        self.tree.setColumnWidth(0, 190)
        self.tree.setColumnWidth(1, 70)
        self.tree.setColumnWidth(2, 90)
        self.tree.setColumnWidth(3, 40)
        self.fix_buttons = {}
        self.warning = QLabel("")
        self.warning.setWordWrap(True)
        self.warning.setVisible(False)
        lay.addWidget(self.warning)
        lay.addWidget(self.tree, 2)
        lay.addWidget(widgets.header("What the generator says"))
        self.account = QListWidget()
        self.account.setWordWrap(True)
        lay.addWidget(self.account, 1)
        self.cost = widgets.caption("")
        lay.addWidget(self.cost)
        self._colours = {k: QColor(t[v]) for k, (v, _) in STATUS.items()}
        self.show_result(None)
    def busy(self, on):
        self.measure_btn.setEnabled(not on)
        self.full_btn.setEnabled(not on)
        if on:
            self.note.setText("Measuring...")
    def show_result(self, res):
        t = self.ed.tokens
        while self.counts.count():
            w = self.counts.takeAt(0).widget()
            if w is not None:
                w.deleteLater()
        self.problems.clear()
        self.tree.clear()
        self.fix_buttons = {}
        self.account.clear()
        self.warning.setVisible(False)
        if res is None:
            self.quality.setText("-")
            self.grade.setText("")
            self.gate.setText("")
            self.note.setText("Generate a map or build one - the report card follows every "
                              "change.")
            self.cost.setText("")
            return
        if res["ok"]:
            self.gate.setText("Ready to export")
            self.gate.setStyleSheet("color: %s; font-weight: 600;" % t["ok"])
        else:
            self.gate.setText("%d problem%s" % (len(res["gate"]), "" if len(res["gate"]) == 1
                                                 else "s"))
            self.gate.setStyleSheet("color: %s; font-weight: 600;" % t["bad"])
        for f in res["gate"]:
            item = QListWidgetItem(f)
            item.setForeground(QColor(t["bad"]))
            item.setToolTip(f)
            self.problems.addItem(item)
        if not res["gate"]:
            self.problems.addItem("None - the safety gate passes.")
        card = res.get("card")
        if card is None:
            self.quality.setText("-")
            self.grade.setText("")
            self.note.setText(res.get("why_no_card", ""))
            self.cost.setText("")
            return
        q = card.get("quality")
        self.quality.setText("-" if q is None else "%d%%" % round(100 * q))
        self.grade.setText("%s %s map%s" % (grade(q), card.get("family", ""),
                                             (" (bar: %s)" % card["reference"])
                                             if card.get("reference") else ""))
        for key in ("pass", "warn", "fail"):
            n = card["counts"].get(key, 0)
            self.counts.addWidget(widgets.chip("%d %s" % (n, key),
                                               t[STATUS[key][0]] if n else t["raised"]))
        cr = res.get("critic")
        if cr:
            chip = widgets.chip("critic %.0f" % cr["score"], t["ok"] if cr["pass"] else t["warn"])
            chip.setToolTip("The critic: emptiness, prop clutter, overlaps, floating objects, "
                            "texture variety and composition (line %d). Weakest: %s"
                            % (cr["line"], cr["rows"][cr["worst"]]["note"]))
            self.counts.addWidget(chip)
            if cr.get("warnings"):
                self.warning.setText("\n".join(cr["warnings"]))
                self.warning.setStyleSheet("color: %s; font-weight: 600;" % t["warn"])
                self.warning.setVisible(True)
        self.counts.addStretch(1)
        self.note.setText("Measured: %s tier%s." % (card.get("tier"), ", bots run" if card.get(
            "bots") else ""))
        if res.get("course_line"):
            self.note.setText("%s\n%s" % (res["course_line"], self.note.text()))
        pending = []
        for group in card.get("metrics", []):
            g = QTreeWidgetItem([group["group"], "", "", "", ""])
            g.setFirstColumnSpanned(True)
            fails = 0
            for row in group["rows"]:
                status = row.get("status", "n/a")
                fails += status == "fail"
                value = row.get("value")
                if isinstance(value, float):
                    value = "%.2f" % value
                item = QTreeWidgetItem([row.get("label", row.get("metric")), str(value),
                                        str(row.get("band", "")), STATUS[status][1], ""])
                item.setForeground(3, self._colours[status])
                tip = row_tip(row)
                item.setToolTip(0, tip)
                item.setToolTip(1, "%s\n\n%s" % (value, tip) if tip else str(value))
                g.addChild(item)
                pending.append((item, row))
            self.tree.addTopLevelItem(g)
            g.setExpanded(fails > 0 or group["group"] in ("Why this map won", "Game modes")
                          or any(r.get("status") == "warn" and r.get("one_click")
                                 for r in group["rows"]))
        for item, row in pending:
            self._add_button(item, row)
        for d in card.get("done") or []:
            self.account.addItem("[%s] %s: %s" % (d.get("status"), d.get("id", d.get("what")),
                                                  d.get("note", "")))
        for n in card.get("not_possible") or []:
            item = QListWidgetItem("not possible: %s" % n)
            item.setForeground(QColor(t["warn"]))
            self.account.addItem(item)
        for n in card.get("not_understood") or []:
            item = QListWidgetItem("not understood: %s" % n)
            item.setForeground(QColor(t["warn"]))
            self.account.addItem(item)
        for m in card.get("missed_targets") or []:
            self.account.addItem("missed: %s %s (target %s)" % (m["label"], m["value"], m["band"]))
        if not self.account.count():
            self.account.addItem("Nothing to say: no wish asked for anything special.")
        c = card.get("cost") or {}
        self.cost.setText("%s pieces of a %s budget - %s new pictures, about %s KB more for "
                          "every joiner" % (c.get("objects", c.get("pieces")), c.get("budget"),
                                            c.get("distinct_pictures"), c.get("new_pictures_kb")))
    def _add_button(self, item, row):
        status = row.get("status", "n/a")
        if status not in ("warn", "fail"):
            return None
        metric = row.get("metric", "")
        if row.get("mode_fix"):
            mf = row["mode_fix"]
            b = QPushButton(mf.get("fix_label") or "Fix it")
            b.setToolTip(mode_fix_tip(mf))
            b.clicked.connect(lambda *_, m=mf: QTimer.singleShot(0, self, lambda: self.fix_mode(m)))
        elif row.get("one_click") and row.get("row"):
            b = QPushButton("Fix it")
            b.setToolTip("%s.\nShows you what changes first; Ctrl+Z takes it back."
                         % (row.get("fix") or "Let the critic mend it"))
            b.clicked.connect(lambda *_, k=row["row"], lab=row.get("label"):
                              QTimer.singleShot(0, self, lambda: self.fix_row(k, lab)))
        elif row.get("where") and row.get("row"):
            b = QPushButton("Show me")
            b.setToolTip("Frames where the critic saw it. %s" % (row.get("fix") or ""))
            b.clicked.connect(lambda *_, r=row: self.show_where(r))
        else:
            return None
        b.setAutoDefault(False)
        b.setFlat(False)
        self.tree.setItemWidget(item, 4, b)
        self.fix_buttons[metric] = b
        return b
    def ask(self, title, text):
        box = QMessageBox(self)
        box.setWindowTitle(title)
        box.setText(text)
        yes = box.addButton("Fix it", QMessageBox.AcceptRole)
        box.addButton("Not now", QMessageBox.RejectRole)
        box.setDefaultButton(yes)
        box.exec()
        return box.clickedButton() is yes
    def fix_row(self, key, label=None):
        from .. import criticfix
        doc = self.ed.session.doc
        pv = criticfix.preview(doc, key)
        if pv is None:
            self.ed.hint("%s: nothing the critic can mend by itself right now"
                         % (label or key))
            return None
        touched = criticfix.refs(doc, pv)
        if touched:
            self.ed.session.selection.set(touched)
            try:
                self.ed.studio.views.active.view.frame_selected()
            except AttributeError:
                pass
        text = preview_text(pv)
        if not self.ask("Fix: %s" % pv["label"], text):
            self.ed.hint("Nothing changed")
            return pv
        self.ed.push(criticfix.change_for(doc, pv))
        self.ed.hint("Fixed: %s - Ctrl+Z takes it back" % pv["label"])
        return pv
    def fix_mode(self, mf):
        from .. import gamemodes as gm
        doc = self.ed.session.doc
        fix = mf.get("fix") or {}
        if fix.get("do") == "spot":
            self.ed.push(gm.spot_change(doc, fix["name"]))
            self.ed.hint("Placed - move it where you like; Ctrl+Z takes it back")
        elif fix.get("do") == "place":
            if self.ed.arm(fix["entry"]):
                self.ed.hint("%s - click in a view to place it, Esc stops"
                             % (mf.get("fix_label") or "Place it"))
        elif fix.get("do") == "drop":
            pick = gm.current(doc)
            keys = [k for k in pick.keys if k != mf["key"]] if pick.how == gm.ONLY \
                else pick.keys + [mf["key"]]
            self.ed.push(gm.store(doc, pick.how, keys))
            self.ed.hint("%s taken off the map's modes - Ctrl+Z puts it back"
                         % gm.name_of(mf["key"]))
        return fix.get("do")
    def show_where(self, row):
        from studio.toolbox.issues import Issue
        from .. import critic_live
        doc = self.ed.session.doc
        pts = [(w[0], critic_live.ground_at(doc, w[0], w[1]), w[1]) for w in row["where"]]
        iss = Issue("warn", "critic", "%s: %s. %s" % (row.get("label"), row.get("value"),
                                                       row.get("fix") or ""),
                    points=pts, data={"critic": row.get("row")})
        tools = getattr(self.ed.studio, "tools", None)
        if tools is not None:
            tools.show_issue(iss)
        else:
            self.ed.hint(iss.text)
        return iss
    def _problem_framed(self, item):
        self._problem_clicked(item)
        try:
            self.ed.studio.views.active.view.frame_selected()
        except AttributeError:
            pass
    def _problem_clicked(self, item):
        self.ed.select_fault(item.text())
    def _account(self):
        text = self.ed.report_text or "No generator account for this map (it was built by " \
                                      "hand, or opened without its report.md)."
        self.ed.show_text("The generator's account", text)
def row_tip(row):
    bits = []
    if row.get("explain"):
        bits.append(row["explain"])
    if row.get("fix") and row.get("status") in ("warn", "fail"):
        bits.append("What helps: %s" % row["fix"])
    if row.get("advisory"):
        bits.append("(A hint for now: the bake's light decides most of it.)")
    return "\n".join(bits) or row.get("metric", "")
def preview_text(pv):
    lines = ["This will:"] + ["  - %s" % s for s in pv.get("says") or []]
    if pv.get("before") is not None and pv.get("after") is not None:
        lines.append("")
        lines.append("Critic score: %.0f -> %.0f" % (pv["before"], pv["after"]))
    lines.append("")
    lines.append("You can take it back with Ctrl+Z.")
    return "\n".join(lines)
def mode_fix_tip(mf):
    fix = mf.get("fix") or {}
    if fix.get("do") == "spot":
        return "Puts it at a sensible place now (Ctrl+Z takes it back); move it after."
    if fix.get("do") == "place":
        return "Puts the tool in your hand: click in a view to place it (Esc stops)."
    return "Takes this mode off the map's list."
