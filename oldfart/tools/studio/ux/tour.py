from dataclasses import dataclass, field
WHO = ("kid", "large", "pro")
@dataclass(frozen=True)
class Step:
    id: str
    target: str
    title: str
    simple: str
    full: str
    events: tuple = ()
    title_simple: str = ""
    def words(self, simple):
        return self.simple if simple else self.full
    def heading(self, simple):
        return (self.title_simple or self.title) if simple else self.title
STEPS = {s.id: s for s in (
    Step("wish", "wish", "Make a map from a wish",
         "Write what you want here - like \"a snowy castle with towers\" - then press "
         "Generate.",
         "Say what you want in the Wish box (\"16 players, a castle on a lake\") and press "
         "Ctrl+Enter - or click \"Your first map\" for a few friendly steps.",
         ("wish",), "Make a whole map from a wish"),
    Step("look", "view", "Look around",
         "Hold the right mouse button and move the mouse to look. W A S D flies, the wheel "
         "zooms.",
         "Middle-drag orbits, Shift+middle-drag pans, the wheel zooms; hold the right button "
         "and fly with W A S D (Q / E down / up).",
         ("look",)),
    Step("place", "palette", "Put something down",
         "Click a shape here, then click in the world to put it down. Esc lets go.",
         "Click a palette item (or press 1-9 for the hotbar), then click in a view to place "
         "it; drag to lay a row. Esc lets go, Ctrl+Z takes it back.",
         ("place",)),
    Step("change", "view", "Change its shape",
         "Click your piece, then press Tab: it turns into the next shape of its kind.",
         "Select a piece and press Tab (Shift+Tab back) to cycle its variants - a ramp becomes "
         "a steeper ramp, stairs a corner flight.",
         ("variant",)),
    Step("paint", "palette", "Make it yours",
         "Pick a colour in Textures, click a piece, then press P to paint it.",
         "Pick a texture in the palette's Textures tab, select pieces and press P (Shift+click "
         "with the paint pen fills a whole surface).",
         ("paint",)),
    Step("find", "window", "Find any command",
         "",
         "F3 (or Ctrl+Shift+P) finds every command by its name, in English or German - and "
         "runs it. Nothing is hidden from it.",
         ("find",)),
    Step("grade", "face", "How good is it?",
         "This face is the critic: it smiles when the map is good. Click it to hear one thing "
         "that makes it better.",
         "The critic grades the map while you build (A to E). Click the face for the one thing "
         "to do next, Show me and Fix it; the report card has every row.",
         ("grade",)),
    Step("play", "play", "Play it in the game",
         "When you like it, press Play in the game: it starts Super Mario 64 with your map!",
         "F6 exports the map into the mod and starts Coop DX with it (Map > Play in the "
         "game).",
         ("play",)),
)}
PLANS = {
    "kid": ("look", "place", "change", "paint", "grade", "wish", "play"),
    "large": ("look", "place", "change", "paint", "grade", "wish", "play"),
    "pro": ("wish", "look", "place", "change", "paint", "find", "grade", "play"),
}
def plan(who, has_map=False):
    ids = list(PLANS.get(who) or PLANS["pro"])
    if who == "pro" and has_map and "wish" in ids:
        ids.remove("wish")
    return ids
@dataclass
class State:
    who: str = "pro"
    steps: list = field(default_factory=list)
    at: int = 0
    done: list = field(default_factory=list)
    ended: bool = False
    finished: bool = False
    @classmethod
    def load(cls, d):
        if not isinstance(d, dict):
            return None
        try:
            s = cls(who=str(d.get("who") or "pro"), steps=[str(x) for x in d.get("steps") or []],
                    at=int(d.get("at") or 0), done=[str(x) for x in d.get("done") or []],
                    ended=bool(d.get("ended")), finished=bool(d.get("finished")))
        except (TypeError, ValueError):
            return None
        s.steps = [x for x in s.steps if x in STEPS]
        s.at = max(0, min(s.at, len(s.steps)))
        return s
    def dump(self):
        return {"who": self.who, "steps": list(self.steps), "at": self.at,
                "done": list(self.done), "ended": self.ended, "finished": self.finished}
    def step(self):
        if self.finished or self.at >= len(self.steps):
            return None
        return STEPS[self.steps[self.at]]
    def resumable(self):
        return bool(self.steps) and not self.finished and self.at < len(self.steps)
    def advance(self, mark_done=True):
        st = self.step()
        if st is None:
            return None
        if mark_done and st.id not in self.done:
            self.done.append(st.id)
        self.at += 1
        if self.at >= len(self.steps):
            self.finished = True
            return None
        return self.step()
    def back(self):
        if self.at > 0:
            self.at -= 1
        self.finished = False
        return self.step()
    def event(self, what):
        st = self.step()
        if st is None:
            return None
        if what in st.events:
            return st
        for sid in self.steps[self.at + 1:]:
            if what in STEPS[sid].events and sid not in self.done:
                self.done.append(sid)
        return None
def start(who, has_map=False):
    return State(who=who if who in WHO else "pro", steps=plan(who, has_map))
