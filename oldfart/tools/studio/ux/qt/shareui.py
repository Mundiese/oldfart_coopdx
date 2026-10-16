import base64
import json
import os
from PySide6.QtCore import QBuffer, QByteArray, QIODevice, QObject, QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QFont, QIcon, QImage, QLinearGradient, QPainter, QPen, \
    QPixmap, QPolygonF
from PySide6.QtWidgets import (QApplication, QDialog, QFileDialog, QHBoxLayout,
                               QLabel, QLineEdit, QPushButton, QVBoxLayout)
from studio.ux import mapcode, thumb
from . import action
action("file.share", ["Ctrl+Shift+E"], "Share…", "File",
       "The map's picture to post, its map code (anyone can build the same map from it) "
       "and the map file")
action("file.open_code", ["Ctrl+K"], "Open a map code…", "File",
       "Type or paste a map code (OF-...): the same map is built again")
THUMB = (320, 180)
SHARE = (1280, 720)
def _read(wish):
    from studio.editor import engine
    return engine.brief_from(wish=wish)[0]
def colour_of(piece):
    try:
        from studio.editor.qt import widgets
        return QColor(widgets.average_colour(piece.get("tex", "stone1")))
    except Exception:
        return QColor("#9a948a")
def render(doc, width, height):
    img = QImage(width, height, QImage.Format_ARGB32)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    sky = QLinearGradient(0, 0, 0, height)
    sky.setColorAt(0.0, QColor("#7fb7e8"))
    sky.setColorAt(1.0, QColor("#dfeefa"))
    p.fillRect(0, 0, width, height, sky)
    pieces = [doc.get(r) for r in doc.refs("piece")]
    cache = {}
    for pts, shade, piece in thumb.faces(pieces, width, height):
        tex = piece.get("tex", "stone1")
        if tex not in cache:
            cache[tex] = colour_of(piece)
        c = cache[tex]
        col = QColor.fromRgbF(min(1.0, c.redF() * shade), min(1.0, c.greenF() * shade),
                              min(1.0, c.blueF() * shade))
        p.setPen(QPen(col.darker(125), 0.6))
        p.setBrush(col)
        p.drawPolygon(QPolygonF([QPointF(x, y) for x, y in pts]))
    if not pieces:
        p.setPen(QColor("#4a6a8a"))
        p.drawText(QRectF(0, 0, width, height), Qt.AlignCenter, "An empty map")
    p.end()
    return img
def png_b64(img):
    data = QByteArray()
    buf = QBuffer(data)
    buf.open(QIODevice.WriteOnly)
    img.save(buf, "PNG")
    return base64.b64encode(bytes(data)).decode("ascii")
def image_b64(text):
    img = QImage()
    img.loadFromData(base64.b64decode(text), "PNG")
    return img
def thumb_of_file(path):
    if not path or not path.endswith(".ofmap") or not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as h:
            meta = json.load(h).get("meta") or {}
    except (OSError, ValueError):
        return None
    return image_b64(meta["thumb"]) if meta.get("thumb") else None
class ShareDialog(QDialog):
    def __init__(self, part):
        super().__init__(part.ux.window)
        self.part = part
        self.setWindowTitle("Share your map")
        lay = QVBoxLayout(self)
        self.picture = QLabel()
        self.picture.setAlignment(Qt.AlignCenter)
        lay.addWidget(self.picture)
        self.credit = QLabel("")
        self.credit.setObjectName("dim")
        lay.addWidget(self.credit)
        row = QHBoxLayout()
        row.addWidget(QLabel("Your name"))
        self.author = QLineEdit(part.author())
        self.author.setPlaceholderText("so others know who made it")
        self.author.textChanged.connect(part.set_author)
        row.addWidget(self.author)
        lay.addLayout(row)
        crow = QHBoxLayout()
        self.code = QLineEdit()
        self.code.setReadOnly(True)
        crow.addWidget(QLabel("Map code"))
        crow.addWidget(self.code, 1)
        self.copy = QPushButton("Copy map code")
        self.copy.setObjectName("primary")
        self.copy.clicked.connect(self.copy_code)
        crow.addWidget(self.copy)
        lay.addLayout(crow)
        self.note = QLabel("")
        self.note.setWordWrap(True)
        lay.addWidget(self.note)
        brow = QHBoxLayout()
        self.save_pic = QPushButton("Save share picture…")
        self.save_pic.setToolTip("The map's picture with its name, maker, theme, players, "
                                 "grade and code at the bottom - the one to post")
        self.save_pic.clicked.connect(lambda: self.part.save_picture())
        self.save_map = QPushButton("Save map file…")
        self.save_map.setToolTip("The .ofmap itself: your version, every hand edit in it")
        self.save_map.clicked.connect(lambda: self.part.ux.ed.save(as_=True))
        close = QPushButton("Close")
        close.clicked.connect(self.close)
        for b in (self.save_pic, self.save_map):
            brow.addWidget(b)
        brow.addStretch(1)
        brow.addWidget(close)
        lay.addLayout(brow)
        self.fill()
    def fill(self):
        part = self.part
        img = part.share_image()
        self.picture.setPixmap(QPixmap.fromImage(img).scaled(640, 360, Qt.KeepAspectRatio,
                                                             Qt.SmoothTransformation))
        code, edited = part.code()
        self.code.setText(code or "")
        self.copy.setEnabled(bool(code))
        if not code:
            self.note.setText("This map was made by hand, so it has no map code - share the "
                              "map file (Save map file...) or the picture.")
        elif edited:
            self.note.setText("Edited by hand - the code makes the original map; share the "
                              "file for your version.")
        else:
            self.note.setText("Anyone can type this code (Ctrl+K, or paste it on an empty "
                              "map) and get exactly this map.")
        self.credit.setText(mapcode.credit(part.ux.ed.session.doc.meta) or
                            "Made by %s" % (part.author() or "you"))
    def copy_code(self):
        QApplication.clipboard().setText(self.code.text())
        self.part.ux.hint("Map code copied: %s" % self.code.text())
class ShareUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.last_raw = None
        f = ux.menu("&File")
        ux.add_action("file.share", self.share, menu=f)
        ux.add_action("file.open_code", self.ask_code, menu=f)
        wp = self.ed.wish_panel
        original_brief = wp.brief
        def brief():
            got = original_brief()
            self.last_raw = dict(got[0]) if got and isinstance(got[0], dict) else None
            return got
        wp.brief = brief
        original_generated = self.ed._generated
        def generated(gen, record=True):
            out = original_generated(gen, record)
            self.after_generate(gen)
            return out
        self.ed._generated = generated
        original_generate = self.ed.generate
        def generate():
            text = wp.wish_text() if hasattr(wp, "wish_text") else ""
            if mapcode.looks_like(text):
                return self.open_code(text)
            return original_generate()
        self.ed.generate = generate
        self.ed.run_action_handlers = getattr(self.ed, "run_action_handlers", {})
        session = self.ed.session
        self._session_save = None
        self._wrap_save()
        original_open = self.ed.open_source
        def open_source(source, frame=True, recent=True):
            ok = original_open(source, frame, recent)
            if ok:
                self.after_open(source, recent)
            return ok
        self.ed.open_source = open_source
        self.ux.window.open = open_source
        paste = ux.window.actions.get("edit.paste")
        if paste is not None:
            paste.triggered.connect(self._paste_code)
        _ = session
    def author(self):
        st = self.ed.settings_get("author")
        if st is None:
            st = os.environ.get("USER") or ""
        return st
    def set_author(self, name):
        self.ed.settings_set("author", name.strip())
    def code(self):
        doc = self.ed.session.doc
        info = doc.meta.get("code")
        if isinstance(info, dict) and info.get("code"):
            return info["code"], mapcode.edited(doc)
        payload = mapcode.payload_of(doc.brief, _read)
        if payload is None:
            return None, True
        return mapcode.encode(payload), True
    def after_generate(self, gen):
        seed = gen.brief.get("seed")
        if seed is None:
            return None
        raw = self.last_raw
        payload = (mapcode.payload_from_raw(raw, seed, _read) if raw is not None
                   else mapcode.payload_of(gen.brief, _read))
        code = mapcode.encode(payload)
        mapcode.stamp(self.ed.session.doc, code)
        return code
    def _wrap_save(self):
        session = self.ed.session
        original = session.save
        def save(path=None):
            doc = session.doc
            try:
                doc.meta["thumb"] = png_b64(render(doc, *THUMB))
            except Exception:
                pass
            if not doc.meta.get("author") and self.author():
                doc.meta["author"] = self.author()
            return original(path)
        session.save = save
    def after_open(self, source, recent):
        doc = self.ed.session.doc
        name = doc.rest.get("name") or os.path.basename(str(source).rstrip("/"))
        me = self.author()
        if not recent:
            mapcode.remix(doc.meta, name, doc.meta.get("author") or "Oldfart Studio")
            doc.meta["author"] = me
        elif doc.meta.get("author") and doc.meta.get("author") != me:
            mapcode.remix(doc.meta, name, doc.meta["author"],
                          digest=mapcode.layout_hash(doc.to_layout(models=False)))
            doc.meta["author"] = me
    def code_dialog(self):
        from PySide6.QtWidgets import QDialogButtonBox, QLabel, QLineEdit, QVBoxLayout
        d = QDialog(self.ux.window)
        d.setWindowTitle("Open a map code")
        lay = QVBoxLayout(d)
        lay.addWidget(QLabel("A map code someone shared builds their map here, ready to "
                             "change."))
        field = QLineEdit()
        field.setMinimumWidth(460)
        field.setPlaceholderText("OF-\u2026 (paste it here)")
        clip = QApplication.clipboard().text()
        if mapcode.looks_like(clip):
            field.setText(clip.strip())
        lay.addWidget(field)
        said = QLabel("")
        said.setObjectName("caption")
        said.setWordWrap(True)
        lay.addWidget(said)
        buttons = QDialogButtonBox(QDialogButtonBox.Cancel)
        go = buttons.addButton("Build it", QDialogButtonBox.AcceptRole)
        go.setObjectName("primary")
        buttons.accepted.connect(d.accept)
        buttons.rejected.connect(d.reject)
        lay.addWidget(buttons)
        def check(text):
            text = text.strip()
            if not text:
                said.setText("")
                go.setEnabled(False)
                return
            try:
                payload = mapcode.decode(text)
                wish = (payload.get("wish") if isinstance(payload, dict) else "") or ""
                said.setText("A map code%s." % (": \u201c%s\u201d" % wish if wish else ""))
                go.setEnabled(True)
            except mapcode.CodeError as why:
                said.setText("Not a map code yet: %s" % why)
                go.setEnabled(False)
        field.textChanged.connect(check)
        check(field.text())
        d.field = field
        d.go = go
        return d
    def ask_code(self):
        d = self.code_dialog()
        if d.exec() == QDialog.Accepted and d.field.text().strip():
            return self.open_code(d.field.text())
        return None
    def open_code(self, code, wait=False):
        try:
            payload = mapcode.decode(code)
        except mapcode.CodeError as why:
            self.ux.hint("Map code: %s" % why)
            return None
        raw, seed = mapcode.raw_of(payload, _read)
        ed = self.ed
        if ed._engine_busy():
            return None
        from studio.editor import engine
        clean = mapcode.normalise(code)
        def job(progress, cancelled):
            return engine.generate(raw, seed=seed, progress=progress, cancel=cancelled,
                                   wish=raw.get("wish"), history=False)
        def done(gen):
            self.last_raw = dict(raw)
            ed._generated(gen)
            doc = ed.session.doc
            mapcode.remix(doc.meta, gen.brief.get("wish") or "a map code", "", code=clean)
            self.ux.hint("Built from the map code - the same map, ready to change")
        ed.jobs.run("Building the map code", job, done)
        return payload
    def _paste_code(self, *_):
        text = QApplication.clipboard().text()
        doc = self.ed.session.doc
        if mapcode.looks_like(text) and not doc.refs("piece"):
            self.open_code(text)
    def share_image(self):
        doc = self.ed.session.doc
        w, h = SHARE
        img = render(doc, w, h - 90)
        out = QImage(w, h, QImage.Format_ARGB32)
        out.fill(QColor("#14171c"))
        p = QPainter(out)
        p.setRenderHint(QPainter.Antialiasing)
        p.drawImage(0, 0, img)
        name = doc.rest.get("name") or doc.brief.get("name") or "Untitled map"
        code, edited = self.code()
        grade = ""
        card = getattr(self.ed, "last_card", None)
        try:
            grade = (card.get("critic") or {}).get("grade") or ""
        except AttributeError:
            grade = ""
        f = QFont(p.font())
        f.setPixelSize(34)
        f.setBold(True)
        p.setFont(f)
        p.setPen(QColor("#ffffff"))
        p.drawText(QRectF(28, h - 86, w - 56, 44), Qt.AlignLeft | Qt.AlignVCenter, name)
        f.setPixelSize(20)
        f.setBold(False)
        p.setFont(f)
        p.setPen(QColor("#c8ccd2"))
        bits = ["by %s" % self.author()] if self.author() else []
        if doc.brief.get("theme"):
            bits.append(str(doc.brief["theme"]))
        if doc.brief.get("players"):
            bits.append("%s players" % doc.brief["players"])
        if grade:
            bits.append("grade %s" % grade)
        p.drawText(QRectF(28, h - 44, w * 0.55, 34), Qt.AlignLeft | Qt.AlignVCenter,
                   "  ·  ".join(bits))
        if code and not edited:
            f.setFamily("monospace")
            p.setFont(f)
            p.setPen(QColor("#ffd27a"))
            p.drawText(QRectF(w * 0.4, h - 44, w * 0.6 - 28, 34), Qt.AlignRight | Qt.AlignVCenter,
                       code)
        p.end()
        return out
    def save_picture(self, path=None):
        if path is None:
            name = (self.ed.session.doc.rest.get("name") or "my-map").replace(" ", "-")
            path, _ = QFileDialog.getSaveFileName(self.ux.window, "Save the share picture",
                                                  os.path.join(self.ed.settings_get(
                                                      "dir", os.getcwd()), name + ".png"),
                                                  "PNG (*.png)")
        if not path:
            return None
        self.share_image().save(path)
        self.ux.hint("Saved the share picture: %s" % path)
        return path
    def share(self):
        dlg = ShareDialog(self)
        self.dialog = dlg
        dlg.show()
        return dlg
def thumbnail_icon(path):
    img = thumb_of_file(path)
    return QIcon(QPixmap.fromImage(img)) if img is not None and not img.isNull() else None
def install(ux):
    part = ShareUI(ux)
    lib = getattr(ux.studio, "library", None)
    cards = getattr(lib, "cards", None)
    if cards is not None and hasattr(cards, "fill_maps"):
        original = cards.fill_maps
        def fill_maps():
            n = original()
            from PySide6.QtCore import QSize
            cards.maps.setIconSize(QSize(64, 36))
            for i in range(cards.maps.count()):
                item = cards.maps.item(i)
                icon = thumbnail_icon(item.data(Qt.UserRole))
                if icon is not None:
                    item.setIcon(icon)
            return n
        cards.fill_maps = fill_maps
    return part
