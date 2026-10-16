import threading
from PySide6.QtCore import QObject, QTimer, Signal
PAUSE_MS = 450
class BakePreview(QObject):
    done = Signal(object, int)
    def __init__(self, ctx):
        super().__init__()
        self.ctx = ctx
        ctx.baked_mesh = None
        self.serial = 0
        self.busy = False
        self.error = None
        self.timer = QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.setInterval(PAUSE_MS)
        self.timer.timeout.connect(self.start)
        self.done.connect(self._done)
        ctx.scene.listen(self._scene)
        ctx.settings.listen(self._setting)
        if self.wanted():
            self.timer.start()
    def wanted(self):
        return self.ctx.settings["view.shading"] == "baked"
    def _scene(self, event, _payload):
        if event in ("pieces", "hidden", "meta") or event == "all":
            self.stale()
    def _setting(self, key, value):
        if key in ("view.shading", "view.hour", "view.lightmap"):
            self.stale()
    def hour(self):
        h = self.ctx.settings["view.hour"]
        return h if h in ("day", "dusk", "night") else None
    def stale(self):
        self.serial += 1
        self.ctx.baked_mesh = None
        if self.wanted():
            self.timer.start()
    def layout(self):
        from ..core import bakeview
        sc = self.ctx.scene
        hidden = set(getattr(sc, "hidden", ()) or ())
        pieces = [p for i, p in enumerate(sc.pieces) if i not in hidden]
        meta = dict(sc.meta or {})
        return bakeview.level_layout(meta, pieces, meta.get("theme"), hour=self.hour())
    def start(self):
        if not self.wanted():
            return False
        if self.busy:
            self.timer.start()
            return False
        from ..core import bakeview
        layout = self.layout()
        layer_of = bakeview.registry_layer(self.ctx.registry)
        heat = bool(self.ctx.settings["view.lightmap"])
        serial = self.serial
        self.busy = True
        def work():
            try:
                m = bakeview.mesh(layout, layer_of, lightmap=heat)
            except Exception as why:
                m = why
            self.done.emit(m, serial)
        threading.Thread(target=work, daemon=True).start()
        return True
    def build_now(self):
        from ..core import bakeview
        m = bakeview.mesh(self.layout(), bakeview.registry_layer(self.ctx.registry),
                          lightmap=bool(self.ctx.settings["view.lightmap"]))
        self.ctx.baked_mesh = m
        return m
    def _done(self, m, serial):
        self.busy = False
        if isinstance(m, Exception):
            self.error = str(m)
            self.ctx.status.emit("Baked preview: %s - the formula is drawn" % m)
            return
        if serial != self.serial:
            self.timer.start()
            return
        self.ctx.baked_mesh = m
        self.ctx.redraw()
