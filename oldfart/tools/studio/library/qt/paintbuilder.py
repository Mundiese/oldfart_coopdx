import os
from PySide6.QtCore import Qt, QTimer, Signal
from PySide6.QtGui import QImage, QPixmap
from PySide6.QtWidgets import (QCheckBox, QComboBox, QDialog, QFileDialog, QFormLayout,
                               QHBoxLayout, QLabel, QLineEdit, QPushButton, QSlider,
                               QVBoxLayout)
from studio.library import paintbuilder as pb
SETTLE_MS = 350
VIEW = 4
IMAGES = "Pictures (*.png *.jpg *.jpeg *.webp *.bmp)"
def to_pixmap(img, scale=1):
    img = img.convert("RGB")
    if scale != 1:
        from PIL import Image
        img = img.resize((img.size[0] * scale, img.size[1] * scale), Image.NEAREST)
    data = img.tobytes("raw", "RGB")
    q = QImage(data, img.size[0], img.size[1], 3 * img.size[0], QImage.Format_RGB888)
    return QPixmap.fromImage(q.copy())
class FaceView(QLabel):
    moved = Signal(float, float)
    wheeled = Signal(int)
    def __init__(self):
        super().__init__()
        self.setAlignment(Qt.AlignCenter)
        self.setMinimumSize(64 * VIEW // 2 + 8, 63 * VIEW // 2 + 8)
        self.setCursor(Qt.OpenHandCursor)
        self.setToolTip("Drag to move the picture in the frame; the wheel scales it")
        self._at = None
    def mousePressEvent(self, ev):
        if ev.button() == Qt.LeftButton:
            self._at = ev.position().toPoint()
            self.setCursor(Qt.ClosedHandCursor)
    def mouseMoveEvent(self, ev):
        if self._at is None:
            return
        p = ev.position().toPoint()
        d = p - self._at
        self._at = p
        side = max(1, min(self.width(), self.height()))
        self.moved.emit(-d.x() / float(side), -d.y() / float(side))
    def mouseReleaseEvent(self, ev):
        self._at = None
        self.setCursor(Qt.OpenHandCursor)
    def wheelEvent(self, ev):
        self.wheeled.emit(1 if ev.angleDelta().y() > 0 else -1)
class PaintingBuilder(QDialog):
    def __init__(self, lib=None, parent=None):
        super().__init__(parent or (lib.window if lib is not None else None))
        self.lib = lib
        self.setWindowTitle("Painting Builder")
        self.src = None
        self.placement = pb.Placement()
        self.top = self.bottom = None
        self.painted_for = None
        lay = QVBoxLayout(self)
        from studio.editor.qt import widgets
        self.banner = widgets.Banner()
        lay.addWidget(self.banner)
        row = QHBoxLayout()
        self.load_btn = QPushButton("Load picture...")
        self.load_btn.clicked.connect(self.choose_picture)
        self.map_btn = QPushButton("Use the open map")
        self.map_btn.setToolTip("The map in the editor, drawn as the game draws it")
        self.map_btn.clicked.connect(self.use_map)
        self.map_btn.setEnabled(lib is not None)
        row.addWidget(self.load_btn)
        row.addWidget(self.map_btn)
        row.addStretch(1)
        lay.addLayout(row)
        self.view = FaceView()
        self.view.moved.connect(self._drag)
        self.view.wheeled.connect(self._wheel)
        self.view.setText("Load a picture, or use the open map")
        lay.addWidget(self.view, 1)
        form = QFormLayout()
        self.zoom = QSlider(Qt.Horizontal)
        self.zoom.setRange(int(pb.ZOOM_MIN * 100), int(pb.ZOOM_MAX * 100))
        self.zoom.setValue(100)
        self.zoom.valueChanged.connect(lambda v: self._place(self.placement.zoomed(v / 100.0)))
        form.addRow("Scale", self.zoom)
        self.frame = QComboBox()
        for key, label in pb.FRAMES:
            self.frame.addItem(label, key)
        self.frame.currentIndexChanged.connect(lambda _i: self._changed())
        form.addRow("Frame", self.frame)
        self.painted = QCheckBox("Paint it in the game's paintings' style")
        self.painted.setChecked(True)
        self.painted.toggled.connect(lambda _b: self._changed())
        form.addRow("", self.painted)
        self.name = QLineEdit()
        self.name.setPlaceholderText("my painting")
        form.addRow("Name", self.name)
        lay.addLayout(form)
        row = QHBoxLayout()
        self.status = QLabel("")
        self.status.setObjectName("hint")
        row.addWidget(self.status, 1)
        self.save_btn = QPushButton("Save into a mod...")
        self.save_btn.setEnabled(False)
        self.save_btn.clicked.connect(self.choose_and_save)
        row.addWidget(self.save_btn)
        close = QPushButton("Close")
        close.clicked.connect(self.close)
        row.addWidget(close)
        lay.addLayout(row)
        self.settle = QTimer(self)
        self.settle.setSingleShot(True)
        self.settle.timeout.connect(self.paint_now)
        self.resize(460, 560)
    def set_picture(self, img):
        self.src = img.convert("RGB")
        self.placement = pb.Placement()
        self.zoom.blockSignals(True)
        self.zoom.setValue(100)
        self.zoom.blockSignals(False)
        self.banner.clear()
        self._changed()
    def load_file(self, path):
        from PIL import Image
        try:
            with Image.open(path) as im:
                self.set_picture(im.convert("RGB"))
        except OSError as exc:
            self.banner.fail("That picture could not be read", str(exc))
            return False
        if not self.name.text():
            self.name.setText(os.path.splitext(os.path.basename(path))[0])
        return True
    def choose_picture(self):
        path, _ = QFileDialog.getOpenFileName(self, "A picture for the painting",
                                              os.path.expanduser("~"), IMAGES)
        if path:
            self.load_file(path)
    def use_map(self):
        from mapgen import painting
        try:
            doc = self.lib.ed.session.doc
            layout = doc.to_layout()
            self.set_picture(painting.source(layout, size=384))
        except Exception as exc:
            self.banner.fail("The open map could not be drawn", str(exc))
            return False
        look = layout.get("look") if isinstance(layout.get("look"), dict) else {}
        frame = painting.frame_for(look.get("theme") or layout.get("theme"))
        i = self.frame.findData(frame)
        if i >= 0:
            self.frame.setCurrentIndex(i)
        if not self.name.text():
            self.name.setText(str(layout.get("name") or "my map"))
        return True
    def _drag(self, ddx, ddy):
        if self.src is not None:
            self._place(self.placement.moved(ddx / self.placement.zoom, ddy / self.placement.zoom))
    def _wheel(self, step):
        z = self.placement.zoom * (1.1 if step > 0 else 1 / 1.1)
        self.zoom.setValue(int(round(max(pb.ZOOM_MIN, min(pb.ZOOM_MAX, z)) * 100)))
    def _place(self, placement):
        if placement == self.placement:
            return
        self.placement = placement
        self._changed()
    def _key(self):
        return (repr(self.placement), self.frame.currentData(), self.painted.isChecked())
    def _changed(self):
        if self.src is None:
            return
        prev = pb.quick_preview(self.src, self.placement, self.frame.currentData(), width=256)
        self.view.setPixmap(to_pixmap(prev))
        self.top = self.bottom = None
        self.painted_for = None
        self.save_btn.setEnabled(False)
        self.status.setText("Painting..." if self.painted.isChecked() else "Cutting...")
        self.settle.start(SETTLE_MS)
    def paint_now(self, wait=False):
        if self.src is None:
            return
        key = self._key()
        args = (self.src, self.placement, self.frame.currentData(), self.painted.isChecked())
        if wait:
            self._done(key, pb.build(*args[:3], painted=args[3]))
            return
        from concurrent.futures import ThreadPoolExecutor
        if getattr(self, "_pool", None) is None:
            self._pool = ThreadPoolExecutor(max_workers=1)
            self._poll = QTimer(self)
            self._poll.setInterval(40)
            self._poll.timeout.connect(self._collect)
        self._job = (key, self._pool.submit(pb.build, *args[:3], painted=args[3]))
        self._poll.start()
    def _collect(self):
        job = getattr(self, "_job", None)
        if job is None or not job[1].done():
            return
        self._poll.stop()
        self._job = None
        key, fut = job
        try:
            res = fut.result()
        except Exception as exc:
            self.banner.fail("The painting could not be made", str(exc))
            return
        self._done(key, res)
    def _done(self, key, res):
        if key != self._key():
            return
        self.top, self.bottom, prev = res
        self.view.setPixmap(to_pixmap(prev, max(1, VIEW // 2)))
        self._ready()
    def _ready(self):
        self.painted_for = self._key()
        self.status.setText("128 x 64 a half, as the mod's own paintings")
        self.save_btn.setEnabled(True)
    def done_waiting(self):
        if self.settle.isActive():
            self.settle.stop()
        if self.painted_for != self._key():
            self.paint_now(wait=True)
    def closeEvent(self, ev):
        pool = getattr(self, "_pool", None)
        if pool is not None:
            pool.shutdown(wait=False, cancel_futures=True)
            self._pool = None
        super().closeEvent(ev)
    def default_folder(self):
        try:
            from studio.library import musiclib
            return musiclib.target(self.lib.ed if self.lib else None) or os.path.expanduser("~")
        except Exception:
            return os.path.expanduser("~")
    def choose_and_save(self):
        folder = QFileDialog.getExistingDirectory(self, "The mod folder to save it into",
                                                  self.default_folder())
        if folder:
            self.save_into(folder)
    def save_into(self, folder):
        if self.src is None:
            return []
        self.done_waiting()
        try:
            written = pb.save(folder, self.name.text() or "painting", self.top, self.bottom)
        except OSError as exc:
            self.banner.fail("The painting could not be saved", str(exc))
            return []
        stem = pb.tex_name(self.name.text() or "painting")
        self.banner.ok("Painting saved", "%s_top / _bottom in %s" % (stem, folder),
                       ux=getattr(getattr(self.lib, "studio", None), "ux", None),
                       opener=lambda: self._open(folder))
        return written
    def _open(self, folder):
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QDesktopServices
        QDesktopServices.openUrl(QUrl.fromLocalFile(folder))
def open_builder(lib):
    dlg = getattr(lib, "_paintbuilder", None)
    if dlg is None:
        dlg = PaintingBuilder(lib)
        lib._paintbuilder = dlg
    dlg.show()
    dlg.raise_()
    return dlg
