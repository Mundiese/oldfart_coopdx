ACTIONS = {
    "view.front": (["Num+1"], "Front view", "View"),
    "view.back": (["Ctrl+Num+1"], "Back view", "View"),
    "view.right": (["Num+3"], "Right view", "View"),
    "view.left": (["Ctrl+Num+3"], "Left view", "View"),
    "view.top": (["Num+7"], "Top view", "View"),
    "view.bottom": (["Ctrl+Num+7"], "Bottom view", "View"),
    "view.toggle_ortho": (["Num+5"], "Perspective / orthographic", "View"),
    "view.opposite": (["Num+9"], "Opposite side", "View"),
    "view.orbit_up": (["Num+8"], "Orbit up", "View"),
    "view.orbit_down": (["Num+2"], "Orbit down", "View"),
    "view.orbit_left": (["Num+4"], "Orbit left", "View"),
    "view.orbit_right": (["Num+6"], "Orbit right", "View"),
    "view.zoom_in": (["Num++", "Ctrl+="], "Zoom in", "View"),
    "view.zoom_out": (["Num+-", "Ctrl+-"], "Zoom out", "View"),
    "view.frame_selected": (["Num+.", "F"], "Frame selected", "View"),
    "view.frame_all": (["Home"], "Frame all", "View"),
    "view.quad": (["Ctrl+Alt+Q"], "Quad view", "View"),
    "view.maximize": (["Ctrl+Space"], "Maximise pane", "View"),
    "view.pie": (["`"], "View menu at the cursor", "View"),
    "view.shading_cycle": (["Z"], "Cycle shading", "View"),
    "view.edges": (["Alt+E"], "Piece edges", "View"),
    "view.grid": (["Alt+Shift+G"], "Grid", "View"),
    "view.markers": (["Alt+M"], "Markers", "View"),
    "snap.toggle": (["Shift+Tab"], "Snap on/off", "Grid and snap"),
    "snap.finer": (["["], "Finer grid", "Grid and snap"),
    "snap.coarser": (["]"], "Coarser grid", "Grid and snap"),
    "gizmo.none": (["Alt+G"], "Select (no gizmo)", "Gizmo"),
    "gizmo.move": (["G"], "Move gizmo", "Gizmo"),
    "gizmo.rotate": (["R"], "Rotate gizmo", "Gizmo"),
    "select.all": (["A"], "Select all", "Select"),
    "select.none": (["Alt+A", "Escape"], "Select none", "Select"),
    "select.invert": (["Ctrl+I"], "Invert selection", "Select"),
    "file.open": (["Ctrl+O"], "Open", "File"),
    "file.screenshot": (["F12"], "Screenshot of the view", "File"),
    "app.preferences": (["Ctrl+,"], "Preferences", "App"),
    "app.shortcuts": (["?", "F1"], "Shortcuts", "App"),
}
EMULATED = {"1": "Num+1", "3": "Num+3", "7": "Num+7", "5": "Num+5", "9": "Num+9",
            "Ctrl+1": "Ctrl+Num+1", "Ctrl+3": "Ctrl+Num+3", "Ctrl+7": "Ctrl+Num+7",
            "2": "Num+2", "4": "Num+4", "6": "Num+6", "8": "Num+8"}
def register(action, keys, label, group):
    if action in ACTIONS:
        return False
    ACTIONS[action] = (list(keys), label, group)
    return True
def normalise(text):
    if not text:
        return ""
    parts = text.replace(" ", "").split("+")
    if text.endswith("++"):
        parts = parts[:-2] + ["+"]
    key = parts[-1]
    mods = set(p.lower() for p in parts[:-1])
    order = [("ctrl", "Ctrl"), ("alt", "Alt"), ("shift", "Shift"), ("meta", "Meta"),
             ("num", "Num")]
    out = [name for low, name in order if low in mods]
    if len(key) == 1:
        key = key.upper()
    return "+".join(out + [key])
class Keymap:
    def __init__(self):
        self._over = {}
    def keys(self, action):
        if action in self._over:
            return list(self._over[action])
        return list(ACTIONS[action][0])
    def set(self, action, keys):
        keys = [normalise(k) for k in keys if k]
        if keys == [normalise(k) for k in ACTIONS[action][0]]:
            self._over.pop(action, None)
        else:
            self._over[action] = keys
    def reset(self, action=None):
        if action is None:
            self._over = {}
        else:
            self._over.pop(action, None)
    def overrides(self):
        return {a: list(k) for a, k in self._over.items()}
    def load(self, data):
        self._over = {a: [normalise(k) for k in ks] for a, ks in data.items()
                      if a in ACTIONS and isinstance(ks, list)}
    def table(self, emulate_numpad=False):
        out = {}
        for action in ACTIONS:
            for k in self.keys(action):
                out[normalise(k)] = action
        if emulate_numpad:
            for row, num in EMULATED.items():
                act = out.get(normalise(num))
                if act:
                    out[normalise(row)] = act
        return out
    def conflicts(self):
        seen = {}
        for action in ACTIONS:
            for k in self.keys(action):
                seen.setdefault(normalise(k), []).append(action)
        return {k: v for k, v in seen.items() if len(v) > 1}
