import re
from studio.editor.palette import GERMAN as PALETTE_GERMAN, _fold
GERMAN = {
    "undo": "rueckgaengig zurueck", "redo": "wiederholen", "copy": "kopieren",
    "cut": "ausschneiden", "paste": "einfuegen", "delete": "loeschen entfernen",
    "duplicate": "duplizieren verdoppeln", "stack": "stapeln reihe", "turn": "drehen",
    "mirror": "spiegeln", "nudge": "schieben verschieben", "paint": "malen anmalen faerben",
    "texture": "textur", "eyedropper": "pipette", "select": "auswaehlen markieren auswahl",
    "selection": "auswahl", "all": "alles", "none": "nichts", "invert": "umkehren",
    "similar": "aehnlich", "connected": "verbunden", "new": "neu", "open": "oeffnen",
    "save": "speichern sichern", "map": "karte map", "generate": "generieren erzeugen bauen",
    "refine": "verfeinern aendern", "variety": "vielfalt varianten auswahl",
    "measure": "messen bewerten zeugnis", "export": "exportieren", "play": "spielen",
    "view": "ansicht", "front": "vorne vorderansicht", "back": "hinten rueckansicht",
    "right": "rechts", "left": "links", "top": "oben draufsicht", "bottom": "unten",
    "perspective": "perspektive", "orthographic": "orthografisch", "zoom": "zoomen",
    "frame": "einpassen zeigen", "quad": "vier ansichten", "grid": "raster gitter",
    "snap": "einrasten", "gizmo": "anfasser", "move": "bewegen verschieben",
    "rotate": "drehen rotieren", "shading": "schattierung", "edges": "kanten",
    "markers": "marker", "preferences": "einstellungen optionen", "shortcuts": "tasten",
    "screenshot": "bildschirmfoto bild", "seed": "seed zufall", "lock": "sperren festhalten",
    "folder": "ordner", "music": "musik lied track", "prefab": "fertigteil bauwerk vorlage",
    "prefabs": "fertigteile bauwerke vorlagen", "wizard": "assistent erste karte",
    "textures": "texturen", "manager": "verwaltung", "library": "bibliothek",
    "command": "befehl", "palette": "palette", "import": "importieren laden",
    "shapes": "formen", "help": "hilfe", "history": "verlauf", "report": "zeugnis bericht",
    "wish": "wunsch", "spawn": "spawn startpunkt", "anchor": "anker", "theme": "thema",
    "size": "groesse", "download": "download groesse",
    "brush": "pinsel", "raise": "anheben erhoehen hoeher", "lower": "absenken senken",
    "ground": "boden gelaende", "scatter": "streuen verteilen", "fill": "fuellen",
    "ruler": "lineal messen", "path": "weg pfad", "symmetry": "symmetrie spiegeln",
    "auto-dress": "schmuecken dekorieren verschoenern", "region": "bereich gebiet",
    "regenerate": "neu generieren", "snapshot": "momentaufnahme version stand",
    "compare": "vergleichen", "issue": "problem fehler", "overlay": "ueberlagerung ebene",
    "reachability": "erreichbarkeit", "sightlines": "sichtlinien", "heatmap": "hitzekarte",
    "deaths": "tode", "tool": "werkzeug", "centre": "mitte zentrum", "seconds": "sekunden",
}
class Item:
    def __init__(self, ident, label, group="", keys=(), hint="", run=None, words=""):
        self.id = ident
        self.label = label
        self.group = group
        self.keys = list(keys or [])
        self.hint = hint
        self.run = run
        self.words = words
    def haystack(self):
        own = _fold(self.label)
        german = " ".join(GERMAN.get(w, "") for w in re.findall(r"[a-z]+", own))
        tail = re.split(r"[:.]", self.id)[-1]
        return " ".join([own, _fold(self.id.replace(".", " ")), _fold(german),
                         _fold(PALETTE_GERMAN.get(tail, "")), _fold(self.words),
                         _fold(self.group)])
    def __repr__(self):
        return "<Item %s>" % self.id
def score(query, text, fuzzy=True):
    words = [w for w in query.split() if w]
    if not words:
        return 1.0
    total = 0.0
    for w in words:
        s = _word_score(w, text, fuzzy)
        if s <= 0:
            return 0.0
        total += s
    return total / len(words)
def _word_score(w, text, fuzzy=True):
    whole = re.search(r"(^|[^a-z0-9])%s($|[^a-z0-9])" % re.escape(w), text)
    if whole:
        return 6.0 + min(1.0, len(w) / 6.0)
    at = text.find(w)
    if at >= 0:
        start = at == 0 or not text[at - 1].isalnum()
        return 3.0 + (2.0 if start else 0.0) + min(1.0, len(w) / 6.0)
    if not fuzzy:
        return 0.0
    i, run, best, starts = 0, 0, 0, 0
    last = -2
    for j, ch in enumerate(text):
        if i < len(w) and ch == w[i]:
            run = run + 1 if j == last + 1 else 1
            best = max(best, run)
            if j == 0 or not text[j - 1].isalnum():
                starts += 1
            last = j
            i += 1
    if i < len(w):
        return 0.0
    return 0.5 + 0.3 * starts + 0.2 * best
class Palette:
    def __init__(self, recent_max=8):
        self.items = {}
        self.recent = []
        self.recent_max = recent_max
    def add(self, ident, label, group="", keys=(), hint="", run=None, words=""):
        self.items[ident] = Item(ident, label, group, keys, hint, run, words)
        return self.items[ident]
    def remove_prefix(self, prefix):
        for k in [k for k in self.items if k.startswith(prefix)]:
            del self.items[k]
    def search(self, text, limit=40):
        q = _fold((text or "").strip())
        rank = {ident: n for n, ident in enumerate(self.recent)}
        hits = []
        for item in self.items.values():
            label = score(q, _fold(item.label))
            s = max(score(q, item.haystack(), fuzzy=False), label)
            if s > 0:
                s += 0.5 * label
                if q == _fold(item.label):
                    s += 5.0
                hits.append((s, item))
        if not q:
            hits.sort(key=lambda h: (h[1].id not in rank, rank.get(h[1].id, 0), h[1].group,
                                     h[1].label))
        else:
            hits.sort(key=lambda h: (-(h[0] + (0.75 if h[1].id in rank else 0.0)),
                                     h[1].label))
        return [item for _, item in hits[:limit]]
    def used(self, ident):
        if ident in self.recent:
            self.recent.remove(ident)
        self.recent.insert(0, ident)
        del self.recent[self.recent_max:]
    def state(self):
        return {"recent": list(self.recent)}
    def restore(self, state):
        self.recent = [r for r in (state or {}).get("recent", []) if isinstance(r, str)]
