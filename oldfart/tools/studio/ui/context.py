from PySide6.QtCore import QObject, Signal
from ..core import gizmo as gizmo_math
from ..core import scene as scene_mod
from ..core import snap as snap_mod
from ..core import textures, theme
from .renderer import InstanceCache
class StudioContext(QObject):
    piecesChanged = Signal(object)
    markersChanged = Signal()
    selectionChanged = Signal(object)
    markerSelectionChanged = Signal(object)
    hoverChanged = Signal(object)
    highlightChanged = Signal(object)
    picked = Signal(object, object, object)
    cursorMoved = Signal(object)
    gizmoDragged = Signal(object, str)
    gizmoModeChanged = Signal(str)
    viewOptionsChanged = Signal()
    status = Signal(str)
    def __init__(self, settings, registry=None):
        super().__init__()
        self.settings = settings
        self.scene = scene_mod.Scene()
        self.registry = registry or textures.Registry()
        self.cache = InstanceCache(self.scene, self.registry)
        self.snap = snap_mod.Snap(settings["grid.step"], settings["grid.vertical"],
                                  settings["grid.snap"])
        self.gizmo_mode = "none"
        self.tokens = theme.tokens(settings["ui.accent"], settings["ui.background"])
        self.pick_handler = default_pick
        self.gizmo_handler = None
        self.sun_tool = None
        self.sun_preview = None
        self.views = []
        self.painters = []
        self.scene.listen(self._relay)
        settings.listen(self._setting)
    def _relay(self, event, payload):
        if event == "pieces":
            self.piecesChanged.emit(payload)
        elif event == "markers":
            self.markersChanged.emit()
        elif event == "selection":
            self.selectionChanged.emit(payload)
        elif event == "marker_selection":
            self.markerSelectionChanged.emit(payload)
        elif event == "hover":
            self.hoverChanged.emit(payload)
        elif event == "highlight":
            self.highlightChanged.emit(payload)
        self.redraw()
    def _setting(self, key, value):
        if key == "grid.step":
            self.snap.step = float(value)
        elif key == "grid.vertical":
            self.snap.vertical = float(value)
        elif key == "grid.snap":
            self.snap.enabled = bool(value)
        elif key in ("ui.accent", "ui.background"):
            self.tokens = theme.tokens(self.settings["ui.accent"], self.settings["ui.background"])
        self.viewOptionsChanged.emit()
        self.redraw()
    def set_gizmo_mode(self, mode):
        if mode not in ("none", "move", "rotate"):
            raise ValueError(mode)
        if mode != self.gizmo_mode:
            self.gizmo_mode = mode
            self.gizmoModeChanged.emit(mode)
            self.redraw()
    def gizmo(self):
        if self.gizmo_mode == "none" or not self.scene.selection:
            return None
        pivot = self.scene.selection_pivot()
        if pivot is None:
            return None
        return gizmo_math.Gizmo(self.gizmo_mode, pivot, self.settings["gizmo.size"])
    def sun_gizmo(self):
        tool = self.sun_tool
        if tool is None or not tool.shown():
            return None
        from ..core import sungizmo
        centre, radius = sungizmo.place(self.scene.bounds())
        return sungizmo.SunGizmo(centre, radius, self.sun_preview or tool.sun())
    def set_sun_preview(self, sun):
        self.sun_preview = sun
        self.viewOptionsChanged.emit()
        self.redraw()
    def redraw(self):
        for v in self.views:
            v.update()
            watch = getattr(v, "flames_watch", None)
            if watch is not None:
                watch()
def default_pick(hit, mods, view):
    scene = view.ctx.scene
    if mods.get("shift"):
        mode = "toggle"
    elif mods.get("ctrl"):
        mode = "remove"
    else:
        mode = "set"
    if hit and hit.kind == "piece":
        scene.select({hit.index}, mode)
        if mode == "set":
            scene.set_marker_selection(())
    elif hit and hit.kind == "marker":
        cur = scene.marker_selection
        if mode == "toggle":
            new = cur ^ {hit.index}
        elif mode == "remove":
            new = cur - {hit.index}
        else:
            new = {hit.index}
            scene.set_selection(())
        scene.set_marker_selection(new)
    elif mode == "set":
        scene.set_selection(())
        scene.set_marker_selection(())
    return True
