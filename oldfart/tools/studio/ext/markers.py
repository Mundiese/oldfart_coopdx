def install(studio):
    from PySide6.QtCore import QPointF, Qt
    from PySide6.QtGui import QBrush, QColor, QFont
    from PySide6.QtWidgets import (QAbstractItemView, QLabel, QTreeWidget, QTreeWidgetItem,
                                   QVBoxLayout, QWidget)
    from studio.toolbox import markerlist as ML
    ed = getattr(studio, "editor", None)
    ctx = studio.ctx
    SETTING = "marker_labels"
    ROLE_INDEX = Qt.UserRole
    ROLE_GROUP = Qt.UserRole + 1
    ROLE_ISSUE = Qt.UserRole + 2
    def doc():
        return ed.session.doc if ed is not None else None
    def stored_shown():
        if ed is None:
            return set(ML.DEFAULT_SHOWN)
        return ML.shown_from(ed.settings_get(SETTING, sorted(ML.DEFAULT_SHOWN)))
    state = {"groups": [], "shown": stored_shown()}
    class MarkersPanel(QWidget):
        def __init__(self):
            super().__init__()
            lay = QVBoxLayout(self)
            lay.setContentsMargins(10, 10, 10, 10)
            self.summary = QLabel("")
            self.summary.setWordWrap(True)
            self.summary.setToolTip("How many markers the map has, and how many issues")
            lay.addWidget(self.summary)
            self.tree = QTreeWidget()
            self.tree.setHeaderHidden(True)
            self.tree.setColumnCount(1)
            self.tree.setSelectionMode(QAbstractItemView.SingleSelection)
            self.tree.setEditTriggers(QAbstractItemView.NoEditTriggers)
            self.tree.setToolTip("Every marker by kind. Click one to select it and frame it; "
                                 "tick a kind to float its labels over the views; "
                                 "double-click a bonus star to renumber or rename it")
            self.tree.itemClicked.connect(self.clicked)
            self.tree.itemDoubleClicked.connect(self.double_clicked)
            from studio.ui import keyguard
            keyguard.list_keys(self.tree, {Qt.Key_F2: self.rename_current,
                                           Qt.Key_Delete: self.delete_current})
            self.tree.itemChanged.connect(self.changed)
            lay.addWidget(self.tree, 1)
            self._filling = False
            self._editing = None
        def refresh(self, force=False):
            d = doc()
            try:
                sig = (id(d), getattr(d, "revision", None), id(ctx.scene.markers),
                       tuple((getattr(m, "x", 0), getattr(m, "y", 0), getattr(m, "z", 0),
                              getattr(m, "kind", None)) for m in ctx.scene.markers))
            except Exception:
                sig = None
            if not force and sig is not None and sig == getattr(self, "_built", None):
                return
            self._built = sig
            groups = ML.build(ctx.scene.markers, d)
            state["groups"] = groups
            self._filling = True
            try:
                self.tree.clear()
                bad_colour = QColor(ctx.tokens.get("bad", "#e5534b"))
                total = issues = 0
                for g in groups:
                    top = QTreeWidgetItem(["%s (%d)" % (g.title, len(g.rows))])
                    top.setData(0, ROLE_GROUP, g.key)
                    top.setFlags((top.flags() | Qt.ItemIsUserCheckable) & ~Qt.ItemIsSelectable)
                    top.setCheckState(0, Qt.Checked if g.key in state["shown"] else Qt.Unchecked)
                    top.setToolTip(0, "Tick: float the %s' labels over the views"
                                   % g.title.lower())
                    f = top.font(0)
                    f.setBold(True)
                    top.setFont(0, f)
                    self.tree.addTopLevelItem(top)
                    for r in g.rows:
                        total += 1
                        item = QTreeWidgetItem([r.text])
                        item.setData(0, ROLE_INDEX, r.index)
                        tip = "Click: select it and frame it"
                        if r.editable():
                            tip += "; double-click: its number and name (\"4 Over the Moat\")"
                        item.setToolTip(0, tip)
                        top.addChild(item)
                        for text in r.issues:
                            issues += 1
                            child = QTreeWidgetItem(["  " + text])
                            child.setData(0, ROLE_INDEX, r.index)
                            child.setData(0, ROLE_ISSUE, True)
                            child.setForeground(0, QBrush(bad_colour))
                            child.setToolTip(0, "An issue with this marker (the issue browser, "
                                                "F7, has its fixes)")
                            item.addChild(child)
                        if r.issues:
                            item.setForeground(0, QBrush(bad_colour))
                            item.setExpanded(True)
                    top.setExpanded(True)
                self.summary.setText("%d markers%s" % (total, (", %d issue%s" % (
                    issues, "" if issues == 1 else "s")) if issues else ""))
            finally:
                self._filling = False
        def row_of(self, item):
            index = item.data(0, ROLE_INDEX) if item is not None else None
            if index is None:
                return None
            return ML.find_row(state["groups"], index)
        def clicked(self, item, _col=0):
            if self._filling:
                return
            key = item.data(0, ROLE_GROUP)
            if key is not None:
                self.toggle_labels(key, item.checkState(0) == Qt.Checked)
                return
            row = self.row_of(item)
            if row is not None:
                select_and_frame(row)
        def toggle_labels(self, key, on):
            shown = set(state["shown"])
            (shown.add if on else shown.discard)(key)
            state["shown"] = shown
            if ed is not None:
                ed.settings_set(SETTING, sorted(shown))
            ctx.redraw()
        def double_clicked(self, item, _col=0):
            row = self.row_of(item)
            if row is None or item.data(0, ROLE_ISSUE) or not row.editable():
                return
            self._editing = row
            self._filling = True
            item.setFlags(item.flags() | Qt.ItemIsEditable)
            item.setText(0, ML.edit_text(row))
            self._filling = False
            self.tree.editItem(item, 0)
        def rename_current(self):
            item = self.tree.currentItem()
            if item is not None:
                self.double_clicked(item)
        def delete_current(self):
            row = self.row_of(self.tree.currentItem())
            if row is None or ed is None or row.ref is None:
                return False
            ed.session.selection.set([row.ref])
            ed.run_action("edit.delete")
            return True
        def changed(self, item, _col=0):
            if self._filling:
                return
            key = item.data(0, ROLE_GROUP)
            if key is not None:
                self.toggle_labels(key, item.checkState(0) == Qt.Checked)
                return
            row, self._editing = self._editing, None
            if row is None or self.row_of(item) is not row:
                return
            self.apply_edit(row, item.text(0))
        def apply_edit(self, row, text):
            if ed is None:
                return False
            try:
                made = ML.edit_apply(doc(), row, text, ed.push)
            except ValueError as why:
                ed.hint(str(why))
                self.refresh(force=True)
                return False
            self.refresh(force=True)
            ctx.redraw()
            return made > 0
    def select_and_frame(row):
        if ed is not None and row.ref is not None:
            ed.session.selection.set([row.ref])
        else:
            ctx.scene.set_selection([])
            ctx.scene.set_marker_selection([row.index])
        view = studio.views.active.view
        view.frame_selected()
        ctx.redraw()
    COLOURS = {"star": "#ffd75e", "spawn": "#8fd3ff", "flank": "#ff9f6b", "flag": "#ff7a90",
               "race": "#b9f27c"}
    def painter(view, p, w, h):
        if not state["shown"]:
            return
        markers = ctx.scene.markers
        cam = view.camera
        bad = QColor(ctx.tokens.get("bad", "#e5534b"))
        f = QFont(p.font())
        f.setBold(True)
        p.setFont(f)
        for index, text, key, has_issue in ML.labels(state["groups"], state["shown"]):
            if index >= len(markers):
                continue
            m = markers[index]
            q = cam.to_pixel((m.x, m.y + 140.0, m.z), w, h)
            if q is None or not (0.0 <= q[2] <= 1.0):
                continue
            x, y = q[0], q[1]
            if x < -50 or y < -20 or x > w + 50 or y > h + 20:
                continue
            width = p.fontMetrics().horizontalAdvance(text)
            p.setPen(QColor(0, 0, 0, 190))
            p.drawText(QPointF(x - width / 2.0 + 1, y + 1), text)
            p.setPen(bad if has_issue else QColor(COLOURS.get(key, "#e8e8e8")))
            p.drawText(QPointF(x - width / 2.0, y), text)
    ctx.painters.append(painter)
    panel = MarkersPanel()
    studio.docks.add("right", "markers", "Markers", panel)
    if ed is not None:
        ed.changed.connect(panel.refresh)
    if hasattr(ctx, "markersChanged"):
        ctx.markersChanged.connect(panel.refresh)
    panel.refresh()
    studio.markers = panel
    return panel
