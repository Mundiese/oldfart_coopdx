from PySide6.QtCore import QSize, Qt
from PySide6.QtWidgets import (QFormLayout, QFrame, QLabel, QListWidget, QListWidgetItem,
                               QSizePolicy, QVBoxLayout, QWidget)
from . import icons
HIGHLIGHT = "texture"
class SceneInfoPanel(QWidget):
    def __init__(self, ctx, parent=None):
        super().__init__(parent)
        self.ctx = ctx
        lay = QVBoxLayout(self)
        lay.setContentsMargins(12, 10, 12, 10)
        lay.setSpacing(6)
        self.title = QLabel("Nothing open")
        self.title.setObjectName("title")
        self.title.setWordWrap(True)
        self.source = QLabel("")
        self.source.setObjectName("caption")
        self.source.setWordWrap(True)
        self.source.setTextInteractionFlags(Qt.TextSelectableByMouse)
        lay.addWidget(self.title)
        lay.addWidget(self.source)
        self.facts = QFormLayout()
        self.facts.setLabelAlignment(Qt.AlignLeft)
        self.facts.setHorizontalSpacing(14)
        self.facts.setVerticalSpacing(3)
        lay.addLayout(self.facts)
        lay.addWidget(self._heading("Textures"))
        self.textures = QListWidget()
        self.textures.setIconSize(QSize(18, 18))
        self.textures.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self.textures.itemClicked.connect(self._texture_clicked)
        lay.addWidget(self.textures, 2)
        lay.addWidget(self._heading("Selection"))
        self.sel = QFormLayout()
        self.sel.setHorizontalSpacing(14)
        self.sel.setVerticalSpacing(3)
        box = QFrame()
        box.setLayout(self.sel)
        lay.addWidget(box)
        lay.addStretch(1)
        self._swatches = {}
        ctx.piecesChanged.connect(lambda *_: self.refresh())
        ctx.markersChanged.connect(self.refresh)
        ctx.selectionChanged.connect(lambda *_: self._selection())
        ctx.markerSelectionChanged.connect(lambda *_: self._selection())
        self.refresh()
    def _heading(self, text):
        h = QLabel(text.upper())
        h.setObjectName("caption")
        h.setContentsMargins(0, 8, 0, 0)
        return h
    def _swatch(self, slug):
        if slug not in self._swatches:
            reg = self.ctx.registry
            top = reg.slugs.get(slug, (0,))[0]
            self._swatches[slug] = icons.swatch(reg.layers[top][1], 18)
        return self._swatches[slug]
    @staticmethod
    def _clear(form):
        while form.rowCount():
            form.removeRow(0)
    def refresh(self):
        sc = self.ctx.scene
        meta = sc.meta
        self.title.setText(meta.get("name") or meta.get("key") or ("Nothing open" if not sc.pieces else "Untitled"))
        self.source.setText(meta.get("source", ""))
        self._clear(self.facts)
        st = sc.stats()
        rows = []
        if meta.get("family"):
            rows.append(("Family", meta["family"]))
        if meta.get("level"):
            rows.append(("Level", meta["level"]))
        budget = meta.get("budget")
        rows.append(("Pieces", "%d%s" % (st["pieces"], " of %d" % budget if budget else "")))
        kinds = ", ".join("%s %d" % (k, n) for k, n in sorted(st["kinds"].items(), key=lambda kv: -kv[1]))
        if kinds:
            rows.append(("Kinds", kinds))
        counts = {}
        for m in sc.markers:
            counts[m.kind] = counts.get(m.kind, 0) + 1
        if counts:
            rows.append(("Markers", ", ".join("%s %d" % kv for kv in sorted(counts.items()))))
        look = meta.get("look") or {}
        if look.get("sky"):
            rows.append(("Sky", str(look["sky"]).replace("BACKGROUND_", "").replace("_", " ").title()))
        if look.get("music"):
            rows.append(("Music", str(look["music"]).replace("SEQ_", "").replace("_", " ").title()))
        for problem in meta.get("problems") or []:
            rows.append(("Skipped", problem))
        for k, v in rows:
            val = QLabel(v)
            val.setWordWrap(True)
            lab = QLabel(k)
            lab.setObjectName("dim")
            self.facts.addRow(lab, val)
        self.textures.clear()
        for slug, n in sorted(st["textures"].items(), key=lambda kv: -kv[1]):
            name = self.ctx.registry.names.get(slug, "%s (unknown)" % slug)
            item = QListWidgetItem(self._swatch(slug), "%s  ·  %d" % (name, n))
            item.setData(Qt.UserRole, slug)
            item.setToolTip("Click: show where %s is used" % name)
            self.textures.addItem(item)
        self._selection()
    def _texture_clicked(self, item):
        slug = item.data(Qt.UserRole)
        sc = self.ctx.scene
        ids = {i for i, p in enumerate(sc.pieces) if p.get("tex") == slug}
        current = sc.highlights.get(HIGHLIGHT)
        if current and current[0] == frozenset(ids):
            sc.clear_highlight(HIGHLIGHT)
            self.textures.clearSelection()
        else:
            sc.set_highlight(HIGHLIGHT, ids, (0.98, 0.84, 0.30))
    def _selection(self):
        self._clear(self.sel)
        sc = self.ctx.scene
        rows = []
        if len(sc.selection) == 1:
            i = next(iter(sc.selection))
            p = sc.pieces[i]
            rows = [("Piece", "#%d  %s" % (i, p["kind"])),
                    ("Texture", self.ctx.registry.names.get(p.get("tex"), p.get("tex"))),
                    ("Size", "%d x %d x %d" % (p["w"], p["h"], p["d"])),
                    ("At", "%d, %d, %d" % (p["x"], p["y"], p["z"])),
                    ("Turn", "%d" % p.get("yaw", 0))]
            if p.get("tag"):
                rows.append(("Tag", p["tag"]))
        elif sc.selection:
            kinds = {}
            for i in sc.selection:
                kinds[sc.pieces[i]["kind"]] = kinds.get(sc.pieces[i]["kind"], 0) + 1
            rows = [("Pieces", str(len(sc.selection))),
                    ("Kinds", ", ".join("%s %d" % kv for kv in sorted(kinds.items())))]
            b = sc.bounds(sc.selection)
            if b:
                rows.append(("Box", "%d x %d x %d" % tuple(b[1][k] - b[0][k] for k in range(3))))
        for i in sorted(sc.marker_selection):
            m = sc.markers[i]
            rows.append((m.kind.title(), "%s at %d, %d, %d, facing %d" % (m.label, m.x, m.y, m.z, m.yaw)))
        if not rows:
            rows = [("", "Click a piece or a marker")]
        for k, v in rows:
            lab = QLabel(k)
            lab.setObjectName("dim")
            val = QLabel(v)
            val.setWordWrap(True)
            val.setTextInteractionFlags(Qt.TextSelectableByMouse)
            self.sel.addRow(lab, val)
