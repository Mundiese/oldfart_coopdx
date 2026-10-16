import time
from PySide6.QtCore import Qt
from PySide6.QtWidgets import (QDialog, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
                               QPushButton, QVBoxLayout)
from .. import trash
KIND_WORDS = {"texture": "texture", "music": "music track", "prefab": "prefab"}
class TrashDialog(QDialog):
    def __init__(self, lib):
        super().__init__(lib.window)
        self.lib = lib
        self.setWindowTitle("Recently removed")
        self.resize(520, 380)
        lay = QVBoxLayout(self)
        lay.addWidget(QLabel("Textures, music and prefabs removed lately - Restore puts one "
                             "back as it was."))
        self.list = QListWidget()
        self.list.setToolTip("Double-click or Enter restores one")
        self.list.itemActivated.connect(lambda *_: self.restore())
        lay.addWidget(self.list, 1)
        row = QHBoxLayout()
        self.restore_btn = QPushButton("Restore")
        self.restore_btn.setToolTip("Put the files back as they were before the removal, then "
                                    "rebuild what is built from them")
        self.restore_btn.clicked.connect(self.restore)
        forget = QPushButton("Forget")
        forget.setToolTip("Drop the kept copy (the removal stays)")
        forget.clicked.connect(self.forget)
        self.forget_btn = forget
        close = QPushButton("Close")
        close.setToolTip("Close this window")
        close.clicked.connect(self.close)
        row.addWidget(self.restore_btn)
        row.addWidget(forget)
        row.addStretch(1)
        row.addWidget(close)
        lay.addLayout(row)
        self.said = QLabel("")
        self.said.setObjectName("caption")
        self.said.setWordWrap(True)
        lay.addWidget(self.said)
        self.fill()
    def fill(self):
        self.list.clear()
        self.entries = trash.entries()
        for e in self.entries:
            item = QListWidgetItem("%s  (%s, %s)" % (
                e.label, KIND_WORDS.get(e.kind, e.kind),
                time.strftime("%d.%m. %H:%M", time.localtime(e.when))))
            item.setData(Qt.UserRole, e.path)
            self.list.addItem(item)
        if self.entries:
            self.list.setCurrentRow(0)
        self.restore_btn.setEnabled(bool(self.entries))
        self.forget_btn.setEnabled(bool(self.entries))
        if not self.entries:
            item = QListWidgetItem("Nothing removed lately - a texture, track or prefab you "
                                   "remove waits here to be restored.")
            item.setFlags(Qt.NoItemFlags)
            self.list.addItem(item)
        return len(self.entries)
    def current(self):
        item = self.list.currentItem()
        if item is None:
            return None
        return next((e for e in self.entries if e.path == item.data(Qt.UserRole)), None)
    def restore(self, entry=None):
        e = entry or self.current()
        if e is None:
            return None
        trash.restore(e)
        lib = self.lib
        if e.kind == "prefab":
            from .. import prefablib
            prefablib.rebuild()
            lib.prefabs.changed()
        elif e.kind == "music":
            lib.music.reload()
        elif e.kind == "texture":
            from .. import texman
            def job(progress, cancelled):
                progress(0, 0, "Rebuilding the blocks")
                return texman.rebuild()
            def done(res):
                ok, text = res
                self.said.setText(("Back: %s" % e.label) if ok else text)
                lib.reload_textures()
            if not lib.ed.jobs.run("Rebuilding the blocks", job, done,
                                   lambda why: self.said.setText(str(why))):
                self.said.setText("Oldfart Studio is busy - rebuild with Library > Textures > "
                                  "Rebuild")
        self.said.setText("Back: %s" % e.label)
        lib.ed.hint("Back: %s" % e.label)
        self.fill()
        return e
    def forget(self):
        e = self.current()
        if e is not None:
            trash.forget(e)
            self.fill()
