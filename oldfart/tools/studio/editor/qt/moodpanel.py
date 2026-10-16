from mapgen import mood as moodmod
ICONS = {
    "clear": ((110, 170, 235), (190, 225, 250), "sun"),
    "rain": ((95, 110, 130), (150, 160, 175), "rain"),
    "storm": ((45, 50, 70), (90, 95, 115), "bolt"),
    "snow": ((160, 185, 215), (225, 235, 245), "snow"),
    "blizzard": ((185, 195, 210), (235, 240, 245), "blizzard"),
    "foggy": ((150, 155, 160), (200, 202, 205), "fog"),
    "spooky": ((30, 45, 35), (70, 100, 75), "moon"),
    "sunset": ((235, 120, 90), (250, 190, 150), "sunset"),
    "sunny": ((80, 160, 240), (170, 215, 250), "sun"),
    "night": ((15, 20, 45), (45, 55, 95), "moon"),
    "underwater": ((20, 70, 95), (60, 130, 140), "bubbles"),
    "spring": ((150, 200, 240), (215, 235, 250), "petals"),
    "desert": ((215, 180, 100), (240, 215, 150), "sun"),
    "volcano": ((110, 30, 25), (190, 80, 40), "flame"),
    "oldfilm": ((150, 120, 85), (210, 185, 145), "film"),
    "dusk": ((60, 55, 100), (215, 130, 105), "sunset"),
    "purple": ((55, 35, 95), (165, 115, 200), "moon"),
}
def icon_spec(key):
    return ICONS.get(key, ((120, 130, 140), (180, 185, 190), "sun"))
def _paint_icon(key, size=36):
    from PySide6.QtCore import QPointF, QRectF, Qt
    from PySide6.QtGui import QColor, QLinearGradient, QPainter, QPen, QPixmap, QPolygonF
    top, bottom, glyph = icon_spec(key)
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    g = QLinearGradient(0, 0, 0, size)
    g.setColorAt(0, QColor(*top))
    g.setColorAt(1, QColor(*bottom))
    p.setBrush(g)
    p.setPen(Qt.NoPen)
    p.drawRoundedRect(QRectF(0, 0, size, size), 6, 6)
    s = size / 36.0
    def at(x, y):
        return QPointF(x * s, y * s)
    def cloud(col):
        p.setBrush(QColor(*col))
        p.setPen(Qt.NoPen)
        p.drawEllipse(at(13, 13), 7 * s, 6 * s)
        p.drawEllipse(at(22, 12), 8 * s, 7 * s)
        p.drawRoundedRect(QRectF(6 * s, 12 * s, 24 * s, 8 * s), 4 * s, 4 * s)
    if glyph in ("sun", "sunset"):
        p.setBrush(QColor(255, 220, 90) if glyph == "sun" else QColor(255, 170, 80))
        c = at(18, 18) if glyph == "sun" else at(18, 26)
        p.drawEllipse(c, 7 * s, 7 * s)
        if glyph == "sunset":
            p.setBrush(QColor(110, 70, 90))
            p.drawRect(QRectF(0, 27 * s, size, 9 * s))
    elif glyph in ("rain", "bolt"):
        cloud((225, 228, 235) if glyph == "rain" else (120, 125, 145))
        pen = QPen(QColor(170, 200, 255))
        pen.setWidthF(1.6 * s)
        p.setPen(pen)
        for x in (11, 17, 23, 29):
            p.drawLine(at(x, 23), at(x - 2, 30))
        if glyph == "bolt":
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(255, 225, 80))
            p.drawPolygon(QPolygonF([at(19, 18), at(14, 27), at(18, 27), at(15, 34),
                                     at(24, 24), at(20, 24), at(23, 18)]))
    elif glyph in ("snow", "blizzard"):
        p.setBrush(QColor(255, 255, 255))
        dots = [(8, 8), (20, 6), (29, 11), (12, 18), (24, 20), (7, 28), (18, 29), (30, 27)]
        if glyph == "blizzard":
            dots += [(14, 10), (26, 15), (9, 22), (31, 20), (22, 26), (13, 32)]
        for x, y in dots:
            p.drawEllipse(at(x, y), 1.8 * s, 1.8 * s)
    elif glyph == "fog":
        pen = QPen(QColor(245, 245, 245, 220))
        pen.setWidthF(3 * s)
        pen.setCapStyle(Qt.RoundCap)
        p.setPen(pen)
        for y, x0, x1 in ((11, 6, 28), (18, 10, 31), (25, 5, 26)):
            p.drawLine(at(x0, y), at(x1, y))
    elif glyph == "moon":
        p.setBrush(QColor(235, 235, 210))
        p.drawEllipse(at(17, 16), 8 * s, 8 * s)
        p.setBrush(QColor(*top))
        p.drawEllipse(at(21, 13), 7 * s, 7 * s)
        p.setBrush(QColor(255, 255, 230))
        for x, y in ((28, 7), (8, 9), (29, 26)):
            p.drawEllipse(at(x, y), 1.0 * s, 1.0 * s)
    elif glyph == "bubbles":
        pen = QPen(QColor(200, 235, 255))
        pen.setWidthF(1.4 * s)
        p.setPen(pen)
        p.setBrush(Qt.NoBrush)
        for x, y, r in ((12, 26, 4), (21, 17, 3), (26, 8, 2.5), (14, 11, 2)):
            p.drawEllipse(at(x, y), r * s, r * s)
    elif glyph == "petals":
        p.setBrush(QColor(255, 160, 200))
        for x, y in ((9, 9), (22, 7), (28, 18), (14, 20), (21, 28), (8, 29)):
            p.drawEllipse(at(x, y), 2.6 * s, 1.6 * s)
    elif glyph == "flame":
        p.setBrush(QColor(255, 170, 60))
        p.drawPolygon(QPolygonF([at(18, 6), at(26, 22), at(22, 30), at(14, 30), at(10, 22)]))
        p.setBrush(QColor(255, 235, 120))
        p.drawPolygon(QPolygonF([at(18, 16), at(22, 25), at(18, 30), at(14, 25)]))
    elif glyph == "film":
        p.setBrush(QColor(60, 45, 30))
        p.drawRect(QRectF(6 * s, 8 * s, 24 * s, 20 * s))
        p.setBrush(QColor(220, 200, 160))
        p.drawRect(QRectF(10 * s, 12 * s, 16 * s, 12 * s))
    p.end()
    return pm
def _plain(stop):
    return stop[:1].upper() + stop[1:] if stop else stop
FIELD_TIPS = {
    "weather": "What falls from the sky while you play here - for example rain over a harbour",
    "hour": "Where the light comes from, so the shading turns - for example late from the west "
            "for a long-shadow evening",
    "darkness": "How much light the world has - for example night for a hide-and-seek map",
    "fog": "Air that hides the far side - for example thick fog on a moor",
    "light": "The colour of the light and the shadow - for example a sunset's orange",
    "colour": "A colour laid over the whole level - for example sepia for an old western town",
}
def MoodSection(ed, parent=None):
    return _make(ed, parent)
def _make(ed, parent=None):
    from PySide6.QtCore import QSize, Qt
    from PySide6.QtGui import QIcon
    from PySide6.QtWidgets import (QCheckBox, QComboBox, QDoubleSpinBox, QFormLayout,
                                   QGridLayout, QHBoxLayout, QPushButton, QToolButton,
                                   QVBoxLayout, QWidget)
    from .. import ops
    from . import widgets
    class _Mood(QWidget):
        def __init__(self):
            super().__init__(parent)
            self.ed = ed
            self._loading = False
            lay = QVBoxLayout(self)
            lay.setContentsMargins(0, 0, 0, 0)
            lay.setSpacing(4)
            from studio.ui.reflow import ReflowGrid
            grid = ReflowGrid(max_cols=4, min_cols=2, spacing=3)
            self.presets = {}
            for n, (key, label, tip, _m) in enumerate(moodmod.PRESETS):
                b = QToolButton()
                b.setText(label)
                b.setIcon(QIcon(_paint_icon(key)))
                b.setIconSize(QSize(36, 36))
                b.setToolButtonStyle(Qt.ToolButtonTextUnderIcon)
                b.setCheckable(True)
                b.setAutoRaise(True)
                b.setStyleSheet("QToolButton { min-width: 70px; min-height: 58px; }")
                b.setToolTip("%s.\nOne click: the whole mood. Undo puts it back." % tip)
                b.clicked.connect(lambda *_, k=key: self.pick(k))
                grid.add(b)
                self.presets[key] = b
            lay.addWidget(grid)
            self.show_box = QCheckBox("Show the weather in the view")
            self.show_box.setChecked(True)
            self.show_box.setToolTip("Draw the fog, the colours and the falling weather over "
                                     "the map here. The game shows the real thing.")
            self.show_box.toggled.connect(self._shown)
            lay.addWidget(self.show_box)
            self.now = widgets.caption("")
            lay.addWidget(self.now)
            more = QWidget()
            mf = QFormLayout(more)
            mf.setContentsMargins(0, 0, 0, 0)
            self.combos = {}
            for field in moodmod.FIELD_ORDER:
                _row, name, stops = moodmod.FIELDS[field]
                c = QComboBox()
                c.addItem(moodmod.NONE_LABEL, None)
                for stop in stops:
                    c.addItem(_plain(stop), stop)
                c.setToolTip(FIELD_TIPS[field])
                c.currentIndexChanged.connect(lambda *_, f=field: self._field(f))
                mf.addRow(name, c)
                self.combos[field] = c
            self.look = QComboBox()
            self.look.addItem(moodmod.NONE_LABEL, None)
            for name in moodmod.LOOK_ORDER:
                self.look.addItem(_plain(name), name)
            self.look.setToolTip("A whole picture style, as on the game's Visuals page - "
                                 "for example black and white for a silent-film map")
            self.look.currentIndexChanged.connect(lambda *_: self._field("vision"))
            mf.addRow("Picture look", self.look)
            self.dials = {}
            for name, lo, hi, step, rest in moodmod.DIALS:
                d = QDoubleSpinBox()
                d.setRange(lo, hi)
                d.setSingleStep(step)
                d.setDecimals(2)
                d.setKeyboardTracking(False)
                d.setValue(rest)
                d.setToolTip("%s: %s is how the game draws it" % (name.capitalize(), rest))
                d.valueChanged.connect(lambda *_: self._dials())
                mf.addRow(name.capitalize(), d)
                self.dials[name] = d
            row = QHBoxLayout()
            self.reset_dials = QPushButton("Dials back")
            self.reset_dials.setToolTip("Every dial back to how the game draws it")
            self.reset_dials.clicked.connect(lambda *_: self.commit(
                dict(self.mood(), dials={}), "Weather: dials back"))
            self.clear = QPushButton("No weather")
            self.clear.setToolTip("Forget this map's weather and mood: it is drawn as it is "
                                  "and wears the lobby's look")
            self.clear.clicked.connect(lambda *_: self.commit({}, "Weather: none"))
            row.addWidget(self.reset_dials)
            row.addWidget(self.clear)
            mf.addRow("", row)
            mf.addRow(widgets.caption(
                "In game the map wears these while you are in it. The lobby's own Visuals "
                "choices win over them, a round that sets the look keeps its own, and the "
                "lobby rule \"A map's own weather\" can switch them off for everybody."))
            self.more = widgets.Collapsible("More", more, open_=False)
            lay.addWidget(self.more)
            self.fill()
        def doc(self):
            return self.ed.session.doc
        def mood(self):
            return moodmod.clean((self.doc().rest.get("look") or {}).get("mood"))
        def commit(self, mood, label=None):
            self.ed.push(ops.set_mood(self.doc(), mood, label))
            self.fill()
        def pick(self, key):
            label = "Weather: %s" % moodmod.PRESET_BY_KEY[key][1]
            self.commit(moodmod.of_preset(key), label)
        def _field(self, field):
            if self._loading:
                return
            m = self.mood()
            m.pop("preset", None)
            box = self.look if field == "vision" else self.combos[field]
            value = box.currentData()
            if value is None:
                m.pop(field, None)
            else:
                m[field] = value
            self.commit(m)
        def _dials(self):
            if self._loading:
                return
            m = self.mood()
            m.pop("preset", None)
            dials = {}
            for name, _lo, _hi, _step, rest in moodmod.DIALS:
                v = round(self.dials[name].value(), 3)
                base = moodmod.look_dials({"vision": m.get("vision")})[name]
                if abs(v - base) > 1e-6:
                    dials[name] = v
            m["dials"] = dials
            self.commit(m)
        def _shown(self, on):
            ctx = getattr(self.ed, "ctx", None)
            if ctx is not None:
                ctx.mood_shown = bool(on)
                ctx.redraw()
        def fill(self):
            self._loading = True
            try:
                m = self.mood()
                key = moodmod.which_preset(m)
                for k, b in self.presets.items():
                    b.setChecked(k == key or (k == "clear" and not m))
                for field, c in self.combos.items():
                    i = c.findData(m.get(field))
                    c.setCurrentIndex(i if i >= 0 else 0)
                i = self.look.findData(m.get("vision"))
                self.look.setCurrentIndex(i if i >= 0 else 0)
                at = moodmod.look_dials(m)
                for name, d in self.dials.items():
                    d.setValue(at[name])
                pv = moodmod.preview(m)
                text = "Now: %s." % moodmod.label(m)
                if pv["unshown"]:
                    text += " Shows in game: %s." % "; ".join(pv["unshown"])
                self.now.setText(text)
                self.reset_dials.setEnabled(bool(m.get("dials")))
                self.clear.setEnabled(bool(m))
            finally:
                self._loading = False
    return _Mood()
