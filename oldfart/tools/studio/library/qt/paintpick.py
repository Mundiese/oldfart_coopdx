from PySide6.QtCore import QSize, Qt, QTimer, Signal
from PySide6.QtGui import QColor, QIcon, QPixmap
from PySide6.QtWidgets import (QDialog, QDialogButtonBox, QGridLayout, QHBoxLayout, QLabel,
                               QToolButton, QVBoxLayout, QWidget)
from .paintbuilder import to_pixmap
THUMB = QSize(256, 252)
POLL_MS = 40
def _pick():
    from mapgen import paintpick
    return paintpick
def blank(size=THUMB):
    pix = QPixmap(size)
    pix.fill(QColor(0, 0, 0, 0))
    return pix
def thumb_for(window, share=0.88):
    from PySide6.QtGui import QGuiApplication
    scr = QGuiApplication.primaryScreen()
    if scr is None:
        return THUMB
    room = int(scr.availableGeometry().height() * share) - 180
    h = max(120, min(THUMB.height(), room // 2 - 68))
    return QSize(int(round(h * THUMB.width() / float(THUMB.height()))), h)
def unique_labels(labels):
    seen, out = {}, []
    for label in labels:
        seen[label] = seen.get(label, 0) + 1
        out.append(label if seen[label] == 1 else "%s (%d)" % (label, seen[label]))
    return out
class Tile(QToolButton):
    def __init__(self, index, thumb=THUMB):
        super().__init__()
        self.index = index
        self.thumb = thumb
        self.candidate = None
        self.setCheckable(True)
        self.setAutoExclusive(True)
        self.setToolButtonStyle(Qt.ToolButtonTextUnderIcon)
        self.setIconSize(thumb)
        self.setFixedSize(thumb.width() + 16, thumb.height() + 56)
        self.setIcon(QIcon(blank(thumb)))
        self.setText("Looking for a view…")
        self.setEnabled(False)
    def show_candidate(self, cand, label=None):
        self.candidate = cand
        label = label or cand.label
        self.setText(label)
        self.setToolTip("%s\nClick to choose it" % label)
    def show_face(self, preview):
        pix = to_pixmap(preview, 2)
        if pix.width() > self.thumb.width():
            pix = pix.scaled(self.thumb, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        self.setIcon(QIcon(pix))
        self.setEnabled(True)
class PaintPicker(QDialog):
    picked = Signal(object)
    def __init__(self, layout, apply=None, lib=None, parent=None, seed=None, key="map"):
        super().__init__(parent)
        self.setWindowTitle("Choose the map's painting")
        self.layout_ = layout
        self.apply = apply
        self.lib = lib
        self.seed = seed
        self.key = key
        self.picker = None
        self.page_no = -1
        self.jobs = []
        self.current = _pick().chosen(layout)
        self.faces = {}
        lay = QVBoxLayout(self)
        from studio.editor.qt import widgets
        self.banner = widgets.Banner()
        lay.addWidget(self.banner)
        intro = widgets.caption("Pick the view for this map's painting. Every export uses it.")
        lay.addWidget(intro)
        grid = QGridLayout()
        grid.setSpacing(8)
        self.thumb = thumb_for(self)
        self.tiles = []
        for i in range(_pick().PAGE):
            t = Tile(i, self.thumb)
            t.toggled.connect(lambda on, t=t: on and self._chosen(t))
            grid.addWidget(t, i // 3, i % 3)
            self.tiles.append(t)
        holder = QWidget()
        holder.setLayout(grid)
        lay.addWidget(holder, 1)
        row = QHBoxLayout()
        self.status = QLabel("")
        self.status.setObjectName("hint")
        row.addWidget(self.status, 1)
        lay.addLayout(row)
        buttons = QDialogButtonBox()
        self.reroll_btn = buttons.addButton("Reroll", QDialogButtonBox.ActionRole)
        self.reroll_btn.setToolTip("Six new viewpoints (never one shown before)")
        self.reroll_btn.clicked.connect(self.reroll)
        self.adjust_btn = buttons.addButton("Adjust…", QDialogButtonBox.ActionRole)
        self.adjust_btn.setToolTip("Open the chosen painting in the Painting Builder: move it, "
                                   "scale it, change its frame")
        self.adjust_btn.clicked.connect(self.adjust)
        self.adjust_btn.setEnabled(False)
        self.use_btn = buttons.addButton("Use this painting", QDialogButtonBox.AcceptRole)
        self.use_btn.setObjectName("primary")
        self.use_btn.setToolTip("Keep it with the map - every export uses it (Ctrl+Z takes it "
                                "back)")
        self.use_btn.setEnabled(False)
        self.use_btn.clicked.connect(self.use)
        cancel = buttons.addButton(QDialogButtonBox.Cancel)
        cancel.clicked.connect(self.reject)
        lay.addWidget(buttons)
        from concurrent.futures import ThreadPoolExecutor
        self._pool = ThreadPoolExecutor(max_workers=1)
        self._poll = QTimer(self)
        self._poll.setInterval(POLL_MS)
        self._poll.timeout.connect(self._collect)
        from studio.ui.reflow import fit_to_screen
        fit_to_screen(self, 3 * (self.thumb.width() + 24) + 24,
                      2 * (self.thumb.height() + 68) + 170)
        self.reroll()
    def _make_picker(self):
        pk = _pick()
        if self.picker is None:
            self.picker = pk.Picker(self.layout_, self.seed, key=self.key,
                                    name=str(self.layout_.get("name") or "Map"))
        return self.picker
    def _page_job(self, n):
        picker = self._make_picker()
        page = list(picker.page(n))
        if n == 0 and self.current is not None:
            pk = _pick()
            cid = self.current.get("id")
            if not any(c.id == cid for c in page):
                cam = pk.camera_of(self.current)
                mine = pk.Candidate(cid or "yours", "Your painting now", cam,
                                    pk.evaluate(picker.ctx, cam))
                page = page[:1] + [mine] + page[1:pk.PAGE - 1]
        return page
    def _face_job(self, cand):
        return _pick().face(self.picker.ctx, cand.cam)
    def reroll(self):
        self.page_no += 1
        self.candidates = []
        for t in self.tiles:
            t.setAutoExclusive(False)
            t.setChecked(False)
            t.setAutoExclusive(True)
            t.candidate = None
            t.setIcon(QIcon(blank(self.thumb)))
            t.setText("Looking for a view…")
            t.setEnabled(False)
        self.use_btn.setEnabled(False)
        self.adjust_btn.setEnabled(False)
        self.reroll_btn.setEnabled(False)
        self.status.setText("Looking for good views of the level…")
        self.jobs = [("page", self.page_no, None, self._pool.submit(self._page_job, self.page_no))]
        self._poll.start()
    def _collect(self):
        while self.jobs and self.jobs[0][3].done():
            kind, page, i, fut = self.jobs.pop(0)
            if page != self.page_no:
                continue
            try:
                res = fut.result()
            except Exception as exc:
                self.banner.fail("The level could not be drawn", str(exc))
                self.status.setText("")
                self.reroll_btn.setEnabled(True)
                self.jobs = []
                break
            if kind == "page":
                self._got_page(res)
            else:
                self.faces[self.candidates[i].id] = res
                self.tiles[i].show_face(res[2])
                if self.selected() is None and self._wanted(i):
                    self.tiles[i].setChecked(True)
                elif self.tiles[i].isChecked():
                    self._chosen(self.tiles[i])
                done = sum(1 for c in self.candidates if c.id in self.faces)
                self.status.setText("Painting %d of %d…" % (done + 1, len(self.candidates))
                                    if done < len(self.candidates) else
                                    "Pick the one you like. Reroll shows six more.")
        if not self.jobs:
            self._poll.stop()
    def _got_page(self, page):
        self.candidates = page
        for t, c, label in zip(self.tiles, page, unique_labels([c.label for c in page])):
            t.show_candidate(c, label)
        for t in self.tiles[len(page):]:
            t.setText("No other good view")
        self.reroll_btn.setEnabled(True)
        if not page:
            self.status.setText("No good view found")
            return
        self.status.setText("Painting 1 of %d…" % len(page))
        for i, c in enumerate(page):
            if c.id in self.faces:
                self.tiles[i].show_face(self.faces[c.id][2])
                continue
            self.jobs.append(("face", self.page_no, i, self._pool.submit(self._face_job, c)))
        for i, c in enumerate(page):
            if c.id in self.faces and self.selected() is None and self._wanted(i):
                self.tiles[i].setChecked(True)
    def _wanted(self, i):
        cand = self.candidates[i]
        mine = (self.current or {}).get("id")
        if mine and any(c.id == mine for c in self.candidates):
            return cand.id == mine
        return i == 0
    def selected(self):
        for t in self.tiles:
            if t.isChecked() and t.candidate is not None:
                return t.candidate
        return None
    def _chosen(self, tile):
        ok = tile.candidate is not None
        self.use_btn.setEnabled(ok)
        self.adjust_btn.setEnabled(ok and tile.candidate.id in self.faces)
    def choose(self, index):
        self.tiles[index].setChecked(True)
        return self.tiles[index].candidate
    def wait(self, timeout=120.0):
        import time
        from PySide6.QtWidgets import QApplication
        end = time.time() + timeout
        while self.jobs and time.time() < end:
            QApplication.processEvents()
            time.sleep(0.02)
            self._collect()
        QApplication.processEvents()
        return not self.jobs
    def use(self):
        cand = self.selected()
        if cand is None:
            return None
        view = cand.view
        if self.apply is not None:
            self.apply(view)
        self.picked.emit(view)
        self.accept()
        return view
    def adjust(self):
        cand = self.selected()
        if cand is None or self.lib is None:
            if self.lib is None:
                self.banner.fail("The Painting Builder is not open here",
                                 "Open it from Library > Painting Builder")
            return None
        from .paintbuilder import open_builder
        dlg = open_builder(self.lib)
        try:
            dlg.set_picture(_pick().picture(self.picker.ctx, cand.cam, size=384))
        except Exception as exc:
            self.banner.fail("The view could not be drawn", str(exc))
            return None
        i = dlg.frame.findData(self.picker.ctx.frame)
        if i >= 0:
            dlg.frame.setCurrentIndex(i)
        if not dlg.name.text():
            dlg.name.setText(str(self.layout_.get("name") or "my map"))
        return dlg
    def done(self, result):
        self._poll.stop()
        self._pool.shutdown(wait=False, cancel_futures=True)
        super().done(result)
def apply_to(ed):
    def apply(view):
        from studio.editor import ops
        doc = ed.session.doc
        ed.push(ops.set_rest(doc, _pick().FIELD, view, "Choose the painting"))
    return apply
def open_picker(ed, parent=None):
    doc = ed.session.doc
    layout = doc.to_layout()
    lib = getattr(getattr(ed, "studio", None), "library", None)
    from studio.editor import engine
    key = engine.key_for(doc.rest.get("name") or "map") or "map"
    dlg = PaintPicker(layout, apply_to(ed), lib, parent or ed.window, key=key)
    dlg.show()
    ed._paint_picker = dlg
    return dlg
