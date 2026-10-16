def install(studio):
    from PySide6.QtGui import QCursor
    from PySide6.QtWidgets import (QCheckBox, QHBoxLayout, QLabel, QListWidget, QMenu,
                                   QPushButton, QSpinBox, QVBoxLayout, QWidget)
    from studio.toolbox import logic
    from studio.toolbox.qt import paint
    ed = studio.editor
    ctx = studio.ctx
    tool = logic.LogicTool(ed.session)
    state = {"wiring": False}
    def push(change, msg=None):
        if change:
            ed.push(change)
        panel.refresh()
        ctx.redraw()
        if msg:
            ed.hint(msg)
    def guarded(fn):
        def run(*a):
            try:
                return fn(*a)
            except logic.LogicError as why:
                ed.hint(str(why))
        return run
    def cursor():
        p = ed.session.cursor
        if p is None:
            raise logic.LogicError("aim at the map first")
        return tuple(p)
    class LogicPanel(QWidget):
        def __init__(self):
            super().__init__()
            lay = QVBoxLayout(self)
            lay.setContentsMargins(10, 10, 10, 10)
            lay.addWidget(QLabel("Ready-made, one click:"))
            for key, (name, says, _, _) in logic.RECIPES.items():
                b = QPushButton(name)
                b.setToolTip("Put down %s at the cursor, already wired" % says)
                b.clicked.connect(guarded(lambda _=False, k=key: push(
                    tool.recipe(k, cursor()), "%s is in - try it in game" % logic.RECIPES[k][0])))
                lay.addWidget(b)
            fill = QPushButton("Fill target spots")
            fill.setToolTip("A pop-up target on every target spot the rooms left along "
                            "the route, all raised by one start button")
            fill.clicked.connect(guarded(lambda: push(tool.fill_target_spots(),
                                                      "Targets on every spot")))
            lay.addWidget(fill)
            self.course = QPushButton("Make it a course")
            self.course.setToolTip("On a Killhouse: a pop-up target on every target spot, a "
                                   "start button in the start room, the clock - and the last "
                                   "target down finishes the run")
            self.course.clicked.connect(guarded(lambda: push(
                tool.make_course(), "A course: press the start button in game to run it")))
            lay.addWidget(self.course)
            lay.addWidget(QLabel("One piece at the cursor:"))
            row = QHBoxLayout()
            for label, kind, tip in (("Target", "target", "a pop-up target"),
                                     ("Button", "button", "a button to stand on"),
                                     ("Zone", "zone", "a zone to walk into")):
                b = QPushButton(label)
                b.setToolTip("Put %s at the cursor" % tip)
                b.clicked.connect(guarded(lambda _=False, k=kind: push(
                    tool.place(k, cursor(), self.number.value() or None))))
                row.addWidget(b)
            lay.addLayout(row)
            nrow = QHBoxLayout()
            nrow.addWidget(QLabel("Number"))
            self.number = QSpinBox()
            self.number.setRange(0, logic.MAX_LINK)
            self.number.setSpecialValueText("next free")
            self.number.setToolTip("The number a new piece gets: targets with the same "
                                   "number stand up together")
            nrow.addWidget(self.number)
            lay.addLayout(nrow)
            self.wire = QCheckBox("Draw a wire")
            self.wire.setToolTip("Draw a wire: click a source, then what it acts on.\n"
                                 "Click near a button, a zone or a target; then click near a "
                                 "target, a door (a mover) or empty floor, and pick what "
                                 "should happen")
            self.wire.toggled.connect(self.wiring)
            lay.addWidget(self.wire)
            self.wires = QListWidget()
            self.wires.setToolTip("Every wire in this map, in words")
            lay.addWidget(self.wires, 1)
            take = QPushButton("Take the wire out")
            take.clicked.connect(guarded(lambda: push(tool.delete_wire(self.wires.currentRow()))))
            lay.addWidget(take)
        def wiring(self, on):
            state["wiring"] = on
            tool.source = None
            ed.hint("Click near the source" if on else "")
            ctx.redraw()
        def refresh(self):
            self.wires.clear()
            for w in logic.wires_of(ed.session.doc):
                self.wires.addItem(logic.wire_text(w))
    def menu_choice(options):
        menu = QMenu(studio.window)
        for i, (label, _w) in enumerate(options):
            menu.addAction(label).setData(i)
        chosen = menu.exec(QCursor.pos())
        return chosen.data() if chosen is not None else None
    def choose(options):
        return (state.get("choose") or menu_choice)(options)
    previous_pick = ctx.pick_handler
    def pick(hit, mods, view):
        if not state["wiring"] or hit is None or hit.point is None:
            return previous_pick(hit, mods, view)
        ref = tool.nearest(hit.point)
        if tool.source is None:
            if ref is None or ref[0] != "object":
                ed.hint("Start on a button, a zone or a target")
                return True
            tool.source = ref
            ed.hint("Now click what it should act on (or empty floor)")
            ctx.redraw()
            return True
        try:
            options = tool.choices(tool.source, ref if ref != tool.source else None)
        except logic.LogicError as why:
            ed.hint(str(why))
            return True
        index = choose(options)
        if index is not None:
            guarded(lambda: push(tool.connect(tool.source, ref if ref != tool.source else None,
                                              index), "Wired"))()
        tool.source = None
        ctx.redraw()
        return True
    ctx.pick_handler = pick
    def painter(view, p, w, h):
        layer = tool.layer(ed.session.doc)
        if len(layer):
            paint.paint_layer(p, view, layer, w, h)
    ctx.painters.append(painter)
    panel = LogicPanel()
    studio.docks.add("right", "logic", "Logic", panel)
    ed.changed.connect(panel.refresh)
    panel.refresh()
    studio.logic = tool
    tool.panel, tool.state = panel, state
    return tool
