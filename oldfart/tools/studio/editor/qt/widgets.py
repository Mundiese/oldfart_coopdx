from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QIcon, QImage, QPainter, QPainterPath, QPen, QPixmap, QPolygonF
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QSizePolicy, QToolButton, QVBoxLayout
from .. import palette as palmod
_swatches = {}
def swatch_image(slug):
    key = (slug, "image")
    if key not in _swatches:
        try:
            img = QImage(palmod.swatch_path(slug))
        except Exception:
            img = QImage()
        if img.isNull():
            w, h, data = palmod.swatch_rgba(slug)
            img = QImage(bytes(data), w, h, 4 * w, QImage.Format_RGBA8888).copy()
        _swatches[key] = img
    return _swatches[key]
def swatch_pixmap(slug, size=40):
    key = (slug, size)
    if key not in _swatches:
        try:
            pm = QPixmap.fromImage(swatch_image(slug)).scaled(
                size, size, Qt.IgnoreAspectRatio, Qt.FastTransformation)
        except Exception:
            pm = QPixmap(size, size)
            pm.fill(QColor("#555"))
        _swatches[key] = pm
    return _swatches[key]
_average = {}
def _kit_colours():
    from mapgen import kit, v1
    if kit._colours is None:
        from studio.core import pixcache
        m = v1.arenas_module()
        out = {}
        for slug, t in kit.textures().items():
            path = kit._repo_path(t["source"])
            got = pixcache.get(path, "average", lambda path=path: list(
                m.average_colour(m.blocks.read_texture(path))))
            out[slug] = tuple(got)
        kit._colours = out
        pixcache.save()
    return kit._colours
def average_colour(slug):
    got = _average.get(slug)
    if got is None:
        try:
            r, g, b = _kit_colours()[slug]
            got = (int(r), int(g), int(b))
        except Exception:
            got = None
        if got is not None:
            _average[slug] = got
    return QColor(*got) if got is not None else QColor("#8a8f98")
PROFILES = {
    "box": [(0.1, 0.1), (0.9, 0.1), (0.9, 0.9), (0.1, 0.9)],
    "ramp": [(0.08, 0.15), (0.92, 0.15), (0.92, 0.75)],
    "stairs": [(0.08, 0.15), (0.92, 0.15), (0.92, 0.85), (0.75, 0.85), (0.75, 0.68),
               (0.58, 0.68), (0.58, 0.5), (0.41, 0.5), (0.41, 0.33), (0.24, 0.33),
               (0.24, 0.15)],
    "outer": [(0.1, 0.15), (0.9, 0.15), (0.9, 0.75), (0.5, 0.45)],
    "inner": [(0.1, 0.15), (0.9, 0.15), (0.9, 0.75), (0.1, 0.75), (0.5, 0.45)],
    "outerstairs": [(0.1, 0.15), (0.9, 0.15), (0.9, 0.8), (0.7, 0.8), (0.7, 0.6), (0.5, 0.6),
                    (0.5, 0.4), (0.3, 0.4)],
    "innerstairs": [(0.1, 0.15), (0.9, 0.15), (0.9, 0.8), (0.1, 0.8), (0.1, 0.6), (0.3, 0.6),
                    (0.3, 0.4), (0.5, 0.4)],
    "pillar": [(0.35, 0.1), (0.65, 0.1), (0.7, 0.2), (0.7, 0.85), (0.3, 0.85), (0.3, 0.2)],
    "prism": [(0.1, 0.15), (0.9, 0.15), (0.1, 0.85)],
    "bank": [(0.1, 0.15), (0.9, 0.15), (0.9, 0.6), (0.1, 0.35)],
}
def drawing_pixmap(drawing, colour, size=40, supersample=4):
    big = size * supersample
    pm = QPixmap(big, big)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    base = QColor(colour)
    for pts, light in drawing.polys:
        c = QColor(int(base.red() * light), int(base.green() * light), int(base.blue() * light))
        p.setBrush(c)
        p.setPen(QPen(c, 1.0))
        p.drawPolygon(QPolygonF([QPointF(x * big, y * big) for x, y in pts]))
    edge = QColor(int(base.red() * 0.25), int(base.green() * 0.25), int(base.blue() * 0.25), 200)
    p.setPen(QPen(edge, max(1.0, supersample * 0.55)))
    for a, b in drawing.creases:
        p.drawLine(QPointF(a[0] * big, a[1] * big), QPointF(b[0] * big, b[1] * big))
    p.end()
    return pm.scaled(size, size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
def entry_drawing(entry, texture="stone1"):
    from studio.core import shapeicon
    key = ("entry", entry.section, entry.key)
    if key not in _drawings:
        disk = drawing_cache()
        flat = "%s/%s" % (entry.section, entry.key)
        if flat in disk:
            row = disk[flat]
            _drawings[key] = None if row is None else shapeicon.Drawing(
                [([tuple(p) for p in pts], light) for pts, light in row[0]],
                [(tuple(a), tuple(b)) for a, b in row[1]])
            return _drawings[key]
        try:
            if callable(entry.data.get("preview")):
                pieces = list(entry.data["preview"]())
            else:
                pieces = [i for kind, i in entry.make(texture, None) if kind == "piece"]
            _drawings[key] = shapeicon.drawing(shapeicon.piece_faces(pieces),
                                               creases=len(pieces) <= 4) if pieces else None
        except Exception:
            _drawings[key] = None
            return None
        d = _drawings[key]
        if d is None:
            disk[flat] = None
        else:
            polys = [[[[round(x, 4), round(y, 4)] for x, y in pts], round(light, 4)]
                     for pts, light in d.polys]
            creases = [[[round(a[0], 4), round(a[1], 4)], [round(b[0], 4), round(b[1], 4)]]
                       for a, b in d.creases]
            disk[flat] = [polys, creases]
        _cache_state["dirty"] = True
    return _drawings[key]
_drawings = {}
_cache_state = {"data": None, "path": None, "dirty": False}
_ICON_SOURCES = ("mapgen", "studio/editor/palette.py", "studio/core/shapeicon.py", "prefabs.py")
def _icon_stamp():
    import hashlib
    import os
    tools = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__)))))
    h = hashlib.sha1(b"icons-1")
    for rel in _ICON_SOURCES:
        path = os.path.join(tools, rel)
        files = [path] if os.path.isfile(path) else sorted(
            os.path.join(path, n) for n in os.listdir(path) if n.endswith((".py", ".json"))) \
            if os.path.isdir(path) else []
        for f in files:
            try:
                st = os.stat(f)
            except OSError:
                continue
            h.update(("%s|%d|%d;" % (os.path.basename(f), st.st_size, int(st.st_mtime))).encode())
    return h.hexdigest()[:16]
def drawing_cache():
    if _cache_state["data"] is not None:
        return _cache_state["data"]
    import json
    import os
    data = {}
    try:
        base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local",
                                                               "share")
        path = os.path.join(base, "oldfart-studio", "cache", "icons-%s.json" % _icon_stamp())
        _cache_state["path"] = path
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as fh:
                loaded = json.load(fh)
            if isinstance(loaded, dict):
                data = loaded
    except (OSError, ValueError):
        data = {}
    _cache_state["data"] = data
    return data
def save_drawing_cache():
    import json
    import os
    path = _cache_state.get("path")
    if not _cache_state.get("dirty") or not path:
        return False
    try:
        folder = os.path.dirname(path)
        os.makedirs(folder, exist_ok=True)
        for name in os.listdir(folder):
            if name.startswith("icons-") and os.path.join(folder, name) != path:
                try:
                    os.remove(os.path.join(folder, name))
                except OSError:
                    pass
        tmp = path + ".part"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(_cache_state["data"], fh)
        os.replace(tmp, path)
        _cache_state["dirty"] = False
        return True
    except OSError:
        return False
_shape_pixmaps = {}
def shape_pixmap(entry, colour, size=40):
    key = (entry.section, entry.key, colour.rgba(), size)
    pm = _shape_pixmaps.get(key)
    if pm is None:
        d = entry_drawing(entry)
        if d is not None and d.polys:
            pm = drawing_pixmap(d, colour, size)
        else:
            pm = profile_pixmap(entry, colour, size)
        _shape_pixmaps[key] = pm
    return pm
def profile_pixmap(entry, colour, size=40):
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    p.setPen(QPen(colour.lighter(140), 1.2))
    p.setBrush(colour)
    s = float(size)
    key = entry.key
    kind = entry.data.get("kind", key)
    def poly(pts):
        p.drawPolygon(QPolygonF([QPointF(x * s, (1 - y) * s) for x, y in pts]))
    if key == "floor":
        poly([(0.05, 0.3), (0.95, 0.3), (0.95, 0.5), (0.05, 0.5)])
    elif key == "slab":
        poly([(0.2, 0.3), (0.8, 0.3), (0.8, 0.42), (0.2, 0.42)])
    elif key == "wall":
        poly([(0.05, 0.15), (0.95, 0.15), (0.95, 0.75), (0.05, 0.75)])
    elif kind == "rail":
        p.setBrush(Qt.NoBrush)
        p.setPen(QPen(colour, 3))
        p.drawLine(QPointF(0.08 * s, 0.45 * s), QPointF(0.92 * s, 0.45 * s))
        for x in (0.15, 0.5, 0.85):
            p.drawLine(QPointF(x * s, 0.45 * s), QPointF(x * s, 0.85 * s))
    elif kind == "arch":
        path = QPainterPath()
        path.addRect(QRectF(0.08 * s, 0.25 * s, 0.84 * s, 0.6 * s))
        hole = QPainterPath()
        hole.addEllipse(QRectF(0.25 * s, 0.45 * s, 0.5 * s, 0.8 * s))
        p.drawPath(path.subtracted(hole))
    elif kind in ("curve", "arcwall"):
        path = QPainterPath()
        path.moveTo(0.1 * s, 0.9 * s)
        path.arcTo(QRectF(-0.7 * s, 0.1 * s, 1.6 * s, 1.6 * s), 90, -90)
        path.lineTo(0.1 * s, 0.9 * s)
        if kind == "arcwall":
            hole = QPainterPath()
            hole.addEllipse(QRectF(-0.55 * s, 0.25 * s, 1.3 * s, 1.3 * s))
            path = path.subtracted(hole)
        p.drawPath(path)
    else:
        poly(PROFILES.get(kind, PROFILES["box"]))
    p.end()
    return pm
def marker_pixmap(entry, tokens, size=40):
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    colour = QColor(tokens.get("accent", "#5b8cff")) if entry.key == "spawn" else \
        QColor(tokens.get("warn", "#f5b041"))
    p.setPen(QPen(colour, 2))
    p.setBrush(colour.darker(160))
    s = float(size)
    p.drawEllipse(QRectF(0.3 * s, 0.12 * s, 0.4 * s, 0.4 * s))
    p.drawLine(QPointF(0.5 * s, 0.52 * s), QPointF(0.5 * s, 0.9 * s))
    if entry.key != "spawn":
        p.setPen(QPen(QColor(tokens.get("text", "#ddd")), 1))
        f = p.font()
        f.setPixelSize(int(s * 0.28))
        f.setBold(True)
        p.setFont(f)
        p.drawText(QRectF(0.3 * s, 0.12 * s, 0.4 * s, 0.4 * s), Qt.AlignCenter,
                   entry.label[:1].upper())
    p.end()
    return pm
SHELF_COLOURS = {"Enemies": "#e5534b", "Bosses": "#a371f7", "Fliers and ghosts": "#9aa4b2",
                 "In the water": "#3fa7d6", "Friends and scenery": "#57ab5a",
                 "Coins and pickups": "#f5c518", "Things to carry": "#c69026",
                 "Fire and hazards": "#f0883e", "Crushers and traps": "#8b949e",
                 "Platforms": "#5b8cff", "Lifts": "#39c5bb", "Clockwork": "#d4a72c",
                 "Switches and posts": "#db61a2", "Shell Racer track": "#2ea043"}
def forge_pixmap(entry, size=40):
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    colour = QColor(SHELF_COLOURS.get(entry.data.get("shelf"), "#8a8f98"))
    s = float(size)
    p.setPen(QPen(colour.lighter(130), 2))
    p.setBrush(colour.darker(140))
    p.drawRoundedRect(QRectF(0.12 * s, 0.12 * s, 0.76 * s, 0.76 * s), 0.18 * s, 0.18 * s)
    p.setPen(QPen(QColor("#ffffff"), 1))
    f = p.font()
    f.setPixelSize(int(s * 0.36))
    f.setBold(True)
    p.setFont(f)
    p.drawText(QRectF(0.12 * s, 0.12 * s, 0.76 * s, 0.76 * s), Qt.AlignCenter,
               entry.label[:2])
    p.end()
    return pm
def icon_for(entry, texture, tokens):
    if entry.section == "textures":
        return QIcon(swatch_pixmap(entry.key))
    if entry.section == "forge":
        return QIcon(forge_pixmap(entry))
    if entry.section == "markers":
        return QIcon(marker_pixmap(entry, tokens))
    if entry.section == "prefabs":
        roles = entry.data.get("roles") or {}
        slug = roles.get("wall") or next(iter(roles.values()), texture)
        return QIcon(shape_pixmap(entry, average_colour(slug)))
    return QIcon(shape_pixmap(entry, average_colour(texture)))
def header(text, tip=None):
    lab = QLabel(text)
    lab.setObjectName("dim")
    f = lab.font()
    f.setBold(True)
    lab.setFont(f)
    if tip:
        lab.setToolTip(tip)
    return lab
def caption(text):
    lab = QLabel(text)
    lab.setObjectName("caption")
    lab.setWordWrap(True)
    return lab
def chip(text, colour, tip=None):
    lab = QLabel(text)
    lab.setStyleSheet("QLabel { background: %s; color: #0e1116; border-radius: 9px; "
                      "padding: 1px 8px; font-weight: 600; }" % colour)
    lab.setSizePolicy(QSizePolicy.Maximum, QSizePolicy.Fixed)
    if tip:
        lab.setToolTip(tip)
    return lab
class Banner(QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("banner")
        self.setWordWrap(True)
        self.setTextInteractionFlags(Qt.TextSelectableByMouse | Qt.LinksAccessibleByMouse)
        self.setOpenExternalLinks(False)
        self.linkActivated.connect(self._link)
        self.state = None
        self.opener = None
        self.player = None
        self.hide()
    def _link(self, href):
        if href == "play" and self.player is not None:
            self.player()
        elif self.opener is not None:
            self.opener()
    def _paint(self, good, title, line):
        colour = "#2e9d5b" if good else "#c8453b"
        mark = "\u2714" if good else "\u2716"
        self.setStyleSheet("QLabel#banner { background: %s; color: white; border-radius: 8px; "
                           "padding: 8px 12px; font-weight: 600; }" % colour)
        link = ""
        if good and self.player is not None:
            link += ("&nbsp;&nbsp;<a href='play' style='color: white'>\u25b6 Play now</a>")
        if good and self.opener is not None:
            link += "&nbsp;&nbsp;<a href='open' style='color: white'>Open folder</a>"
        self.setText("<span style='font-size: 15px'>%s&nbsp;&nbsp;%s</span>%s%s"
                     % (mark, title, ("<br><span style='font-weight: 400'>%s</span>" % line)
                        if line else "", link))
        self.state = "ok" if good else "fail"
        self.show()
    def ok(self, title, line="", ux=None, opener=None, player=None):
        self.opener = opener
        self.player = player
        self._paint(True, title, line)
        if ux is not None:
            try:
                ux.sound("fanfare")
            except Exception:
                pass
        try:
            from PySide6.QtWidgets import QApplication
            QApplication.alert(self.window(), 3000)
        except Exception:
            pass
        return self.state
    def fail(self, title, line=""):
        self._paint(False, title, line)
        return self.state
    def clear(self):
        self.state = None
        self.hide()
class Collapsible(QFrame):
    def __init__(self, title, body, open_=False):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(4)
        self.button = QToolButton()
        self.button.setText(title)
        self.button.setCheckable(True)
        self.button.setChecked(open_)
        self.button.setToolButtonStyle(Qt.ToolButtonTextBesideIcon)
        self.button.setArrowType(Qt.DownArrow if open_ else Qt.RightArrow)
        self.button.toggled.connect(self._toggle)
        row = QHBoxLayout()
        row.addWidget(self.button)
        row.addStretch(1)
        lay.addLayout(row)
        self.body = body
        lay.addWidget(body)
        body.setVisible(open_)
    def _toggle(self, on):
        self.button.setArrowType(Qt.DownArrow if on else Qt.RightArrow)
        self.body.setVisible(on)
