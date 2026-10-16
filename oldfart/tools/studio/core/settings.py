import json
import os
from . import keymap
APP = "oldfart-studio"
SCHEMA = {
    "nav.orbit_speed": (0.4, "float", (0.05, 2.0), "Navigation", "Orbit speed",
                        "Degrees per pixel of a middle-drag orbit."),
    "nav.invert_orbit_y": (False, "bool", None, "Navigation", "Invert orbit up/down",
                           "Dragging up looks from above instead of from below."),
    "nav.zoom_factor": (1.2, "float", (1.02, 2.0), "Navigation", "Zoom step",
                        "How much one wheel notch zooms."),
    "nav.invert_zoom": (False, "bool", None, "Navigation", "Invert wheel zoom", ""),
    "nav.zoom_to_mouse": (True, "bool", None, "Navigation", "Zoom to mouse position",
                          "The point under the mouse stays put while zooming (Blender's option)."),
    "nav.orbit_around_selection": (False, "bool", None, "Navigation", "Orbit around selection",
                                   "A middle-drag orbits the selection's centre."),
    "nav.auto_perspective": (True, "bool", None, "Navigation", "Auto perspective",
                             "Side views turn orthographic; orbiting off them turns perspective again."),
    "nav.numpad_step": (15.0, "float", (1.0, 90.0), "Navigation", "Numpad orbit step",
                        "Degrees for numpad 2/4/6/8."),
    "nav.emulate_3button": (False, "bool", None, "Navigation", "Emulate 3-button mouse",
                            "Alt + left drag acts as the middle button (laptops)."),
    "nav.emulate_numpad": (False, "bool", None, "Navigation", "Emulate numpad",
                           "The number row acts as the numpad (laptops)."),
    "nav.smooth_views": (True, "bool", None, "Navigation", "Smooth view changes",
                         "Animate numpad views and framing (off = reduce motion)."),
    "nav.smooth_ms": (180, "int", (0, 1000), "Navigation", "View change time (ms)", ""),
    "nav.fov": (50.0, "float", (20.0, 110.0), "Navigation", "Field of view",
                "Vertical field of view of perspective views, degrees."),
    "nav.right_drag": ("fly", "choice", ("fly", "pan", "off"), "Navigation",
                       "Right-button drag",
                       "fly: hold the right button to look, WASD to move, Q/E down/up, Shift "
                       "faster, the wheel sets the speed. A right click without a drag opens "
                       "the menu either way."),
    "nav.fly_speed": (1500.0, "float", (100.0, 20000.0), "Navigation", "Fly speed",
                      "Units a second while flying (Mario runs about 600)."),
    "nav.trackpad_pans": (True, "bool", None, "Navigation", "Trackpad pans",
                          "Two fingers on a trackpad pan the view; Ctrl + two fingers or a "
                          "pinch zooms."),
    "view.layout": ("single", "choice", ("single", "quad"), "Viewport", "Layout",
                    "One view or four (Ctrl+Alt+Q)."),
    "view.quad": ("top,user,front,right", "text", None, "Viewport", "Quad views",
                  "Four views left to right, top to bottom: top, bottom, front, back, left, right, "
                  "user. Takes effect on restart."),
    "view.link_ortho": (True, "bool", None, "Viewport", "Link orthographic panes",
                        "Ortho panes share pan and zoom (TrenchBroom)."),
    "view.shading": ("textured", "choice", ("textured", "flat", "height", "game light",
                                            "baked"),
                     "Viewport", "Shading",
                     "Textured, flat colour per texture, colour by height, game light: "
                     "the game's own shade (the Forge cube's light, which follows the camera), or "
                     "baked: the world sun and sky a generated map's pieces are drawn with."),
    "view.hour": ("as made", "choice", ("as made", "day", "dusk", "night"), "Viewport",
                  "Preview hour",
                  "The baked preview at another hour: day, dusk or night - the lamps, the "
                  "fires and the windows as the game lights them. The map itself does not "
                  "change."),
    "view.lightmap": (False, "bool", None, "Viewport", "Light map",
                      "Baked shading shows where the map is too dark (blue) or too bright "
                      "(red) to see."),
    "view.filter": ("nearest", "choice", ("nearest", "linear"), "Viewport", "Texture filter",
                    "Nearest is the game's crisp look; linear is smoother."),
    "view.edges": (True, "bool", None, "Viewport", "Show piece edges",
                   "Outline every piece faintly (selected ones always)."),
    "view.grid": (True, "bool", None, "Viewport", "Show grid", ""),
    "view.markers": (True, "bool", None, "Viewport", "Show markers",
                     "Spawns, survey points, race markers, Forge objects."),
    "view.axes": (True, "bool", None, "Viewport", "Show navigation gizmo", ""),
    "view.fog": (0.35, "float", (0.0, 1.0), "Viewport", "Depth fog",
                 "Far pieces fade towards the background, for depth."),
    "view.msaa": (4, "choice", (0, 2, 4, 8), "Viewport", "Anti-aliasing (samples)",
                  "Multisampling; takes effect on restart."),
    "view.vsync": (True, "bool", None, "Viewport", "Vertical sync", "Takes effect on restart."),
    "view.show_fps": (False, "bool", None, "Viewport", "Show frame time", ""),
    "view.light_from_venue": (True, "bool", None, "Viewport", "Venue light",
                              "Light from the venue's own light direction (its look) when it has one."),
    "grid.step": (200, "choice", (25, 50, 100, 200, 400, 800, 1000), "Grid and snap",
                  "Grid step", "The kit's cell is 200."),
    "grid.vertical": (50, "choice", (25, 50, 100, 200), "Grid and snap", "Vertical step",
                      "The cell model's vertical step is 50."),
    "grid.snap": (True, "bool", None, "Grid and snap", "Snap", "Ctrl inverts while dragging."),
    "grid.height": (0, "int", (-20000, 20000), "Grid and snap", "Working height",
                    "Height of the grid plane in perspective and top/bottom views."),
    "gizmo.size": (96, "int", (40, 240), "Grid and snap", "Gizmo size (px)", ""),
    "ui.accent": ("#5b8cff", "colour", None, "Look", "Accent colour",
                  "Selection and the primary button."),
    "ui.background": ("#1d1f23", "colour", None, "Look", "Viewport background", ""),
    "ui.scale": (100, "int", (75, 200), "Look", "Interface scale (%)",
                 "Text, buttons and panels larger or smaller - it applies at once."),
    "ui.font": ("", "text", None, "Look", "Interface font",
                "Family name; empty = the system's sans-serif."),
    "ui.font_size": (13, "int", (9, 20), "Look", "Font size (px)", ""),
    "ui.reduce_motion": (False, "bool", None, "Look", "Reduce motion", "No animations anywhere."),
    "ui.sounds": ("full", "choice", ("off", "quiet", "full"), "Look", "Sounds",
                  "A short sound for each kind of action - place (higher the higher it "
                  "goes, on the map's music key), lay a row, delete, paint, undo, a soft "
                  "bonk when something cannot go there - and a little pop on placing."),
    "ui.controller": (False, "bool", None, "Tools", "Build with a controller",
                      "Read a game pad (pygame or PySDL2) while the Studio's window is in "
                      "front: the Forge's buttons place, take out, undo and orbit (Help > "
                      "Controller). Off: the pad is never read."),
    "ui.context_bar": (True, "bool", None, "Look", "Context bar",
                       "Big buttons with words beside the selection (Move, Turn, Paint...), "
                       "each saying its key."),
    "ui.hints": (True, "bool", None, "Look", "Faster-way tips",
                 "When you do something the slow way (four blocks in a row, one at a time), "
                 "a small tip says the faster way - once each, never what you already do."),
    "ui.colour_vision": ("safe", "choice", ("safe", "classic", "blue-yellow", "high contrast"),
                         "Look", "Colour vision",
                         "safe: the Okabe-Ito colours (blue good, orange careful, vermillion "
                         "no) that most colour-blind eyes tell apart; classic: green, amber, "
                         "red; blue-yellow; high contrast. Every overlay also marks its "
                         "meaning with a shape: a tick, a !, a cross or a hatch."),
    "wish.backend": ("auto", "choice", ("auto", "offline", "claude", "ollama"), "Wish backends",
                     "Backend", "Who reads a free-text wish. auto (the default): the Claude API "
                     "when its key is set and it answers, else a local Ollama model that "
                     "runs, else the offline rules. Or pin one: the offline rules (always "
                     "there), the Claude API (your key) or Ollama. Without network or key the "
                     "offline rules read it, and the Wish panel says so."),
    "wish.claude_model": ("claude-opus-5-5", "choice",
                          ("claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-4-5-20251001"),
                          "Wish backends", "Claude model",
                          "Opus reads best; Sonnet is faster and cheaper; Haiku the fastest."),
    "wish.ollama_url": ("http://localhost:11434", "text", None, "Wish backends", "Ollama address",
                        "Where Ollama listens (ollama serve)."),
    "wish.ollama_model": ("", "text", None, "Wish backends", "Ollama model",
                          "An installed model (ollama list); empty = the first installed one."),
    "wish.timeout": (60, "int", (5, 600), "Wish backends", "Answer time limit (s)",
                     "After this the offline reading is used."),
    "wish.ask_first": ("ask", "choice", ("ask", "always", "never"), "Wish backends",
                       "Read the wish before Generate",
                       "With Claude or Ollama reading, Generate can first let it read a "
                       "changed wish. ask: Generate asks you, with \"Remember my choice\"; "
                       "always / never: your remembered answer - set it back to ask (or press "
                       "Forget my choice) to be asked again."),
    "wish.history": (True, "bool", None, "Wish backends", "Remember the maps made",
                     "A generation history in your own file, so 'surprise me', 'something "
                     "different' and 'we had that formation' know what came before."),
    "taste.use": (True, "bool", None, "Taste", "Use my taste when generating",
                  "After 50 A-or-B choices in a map family, the score weights fitted to "
                  "them rank that family's candidates (Library > A or B? shows how often "
                  "today's score agrees with you). Off: today's score."),
    "tools.snapshot_cap": (20, "int", (2, 200), "Tools", "Snapshots kept",
                           "Versions a map keeps (stored as changes against the one before). "
                           "Past this the oldest are thinned; the first stays."),
    "tools.overlay_idle_ms": (600, "int", (100, 5000), "Tools", "Overlays: measure after (ms)",
                              "Reachability, sightlines and spawn safety measure again this "
                              "long after your last edit; the bot heatmap only on Measure "
                              "again."),
    "play.game_path": ("", "text", None, "Tools", "Coop DX program",
                       "The sm64coopdx program F6 starts after the export (empty: looked for "
                       "on the PATH and in the usual folders)."),
    "app.desktop_entry": ("ask", "choice", ("ask", "yes", "no"), "Tools",
                          "Desktop icon and menu entry",
                          "AppImage only: yes puts Oldfart Studio on the desktop and in the "
                          "app menu (and .ofmap maps open in it); no removes them again; ask "
                          "asks on the next start. The Windows installer makes its own."),
}
LEGACY = {
    "wish.auto_ask": ("wish.ask_first", {True: "always", False: "never"}),
    "ui.place_sound": ("ui.sounds", {True: "full", False: "off"}),
}
SECTIONS = ("Navigation", "Viewport", "Grid and snap", "Look", "Wish backends", "Taste", "Tools",
            "Keys")
def config_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, APP)
def default_path():
    return os.path.join(config_dir(), "settings.json")
def validate(key, value):
    default, kind, extra, *_ = SCHEMA[key]
    try:
        if kind == "bool":
            return value if isinstance(value, bool) else default
        if kind == "int":
            v = int(value)
            return v if extra is None or extra[0] <= v <= extra[1] else default
        if kind == "float":
            v = float(value)
            return v if extra is None or extra[0] <= v <= extra[1] else default
        if kind == "choice":
            return value if value in extra else default
        if kind == "colour":
            ok = isinstance(value, str) and len(value) == 7 and value[0] == "#"
            int(value[1:], 16)
            return value if ok else default
        if kind == "text":
            return value if isinstance(value, str) else default
    except (TypeError, ValueError):
        return default
    return default
class Settings:
    def __init__(self, path=None):
        self.path = path or default_path()
        self.values = {k: row[0] for k, row in SCHEMA.items()}
        self.keys = keymap.Keymap()
        self.recent = []
        self.state = {}
        self._listeners = []
    def listen(self, fn):
        self._listeners.append(fn)
    def get(self, key):
        return self.values[key]
    def __getitem__(self, key):
        return self.values[key]
    def set(self, key, value):
        v = validate(key, value)
        if v != self.values.get(key):
            self.values[key] = v
            for fn in list(self._listeners):
                fn(key, v)
        return v
    def reset(self, key=None):
        for k in ([key] if key else list(SCHEMA)):
            self.set(k, SCHEMA[k][0])
    def add_recent(self, path, limit=10):
        path = os.path.abspath(path)
        self.recent = [path] + [p for p in self.recent if p != path][:limit - 1]
    def load(self):
        try:
            with open(self.path, encoding="utf-8") as handle:
                raw = json.load(handle)
        except (OSError, ValueError):
            return self
        values = raw.get("values") or {}
        for k, v in values.items():
            if k in SCHEMA:
                self.values[k] = validate(k, v)
            elif k in LEGACY and LEGACY[k][0] not in values:
                new, table = LEGACY[k]
                if v in table:
                    self.values[new] = validate(new, table[v])
        self.keys.load(raw.get("keys") or {})
        self.recent = [p for p in raw.get("recent") or [] if isinstance(p, str)]
        self.state = raw.get("state") or {}
        return self
    def save(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        changed = {k: v for k, v in self.values.items() if v != SCHEMA[k][0]}
        data = {"values": changed, "keys": self.keys.overrides(), "recent": self.recent,
                "state": self.state}
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=1, sort_keys=True)
        os.replace(tmp, self.path)
