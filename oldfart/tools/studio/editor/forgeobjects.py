import os
import re
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
FLOAT_SHELVES = ("Platforms", "Lifts", "Clockwork")
FLOAT_KEYS = ("triblock", "onoff", "amp", "homingamp", "boo", "flyguy", "lakitu", "swoop",
              "snufit", "klepto", "bulletbill", "redcoin", "coin", "bluecoin", "coins",
              "1up", "heart", "firebar")
_CACHE = {}
class Forge:
    __slots__ = ("key", "name", "shelf", "variants", "floats")
    def __init__(self, key, name, shelf, variants=(), floats=False):
        self.key, self.name, self.shelf = key, name, shelf
        self.variants = list(variants)
        self.floats = floats
    def __repr__(self):
        return "Forge(%s %r on %s, %d variants)" % (self.key, self.name, self.shelf,
                                                    len(self.variants))
def _read(name):
    path = os.path.join(REPO, name)
    if not os.path.exists(path):
        return ""
    with open(path, encoding="utf-8") as handle:
        return handle.read()
def _constants(text):
    out = {}
    for m in re.finditer(r"^(spawner\.[A-Z_]+(?:\s*,\s*spawner\.[A-Z_]+)*)\s*=\s*([0-9x, ]+)$",
                         text, re.M):
        names = [n.strip() for n in m.group(1).split(",")]
        values = [v.strip() for v in m.group(2).split(",")]
        for n, v in zip(names, values):
            try:
                out[n] = int(v, 0)
            except ValueError:
                pass
    return out
def _number(text, consts):
    text = text.strip()
    if text in consts:
        return consts[text]
    try:
        return int(text, 0)
    except ValueError:
        return None
def rows(text=None):
    text = _read("of_spawner.lua") if text is None else text
    consts = _constants(text)
    code = "\n".join(line.split("--", 1)[0] for line in text.splitlines())
    starts = [m for m in re.finditer(r'\{\s*key\s*=\s*"([A-Za-z0-9_]+)"\s*,\s*name\s*=\s*"([^"]*)"',
                                     code)]
    out = {}
    for i, m in enumerate(starts):
        end = starts[i + 1].start() if i + 1 < len(starts) else len(code)
        body = code[m.end():end]
        variants = []
        vb = body.find("variants")
        if vb >= 0:
            for v in re.finditer(r'\{\s*name\s*=\s*"([^"]*)"\s*,\s*value\s*=\s*([A-Za-z0-9_.x]+)',
                                 body[vb:]):
                n = _number(v.group(2), consts)
                if n is not None:
                    variants.append((n, v.group(1)))
        out.setdefault(m.group(1), (m.group(2), variants))
    return out
def roster():
    if "roster" in _CACHE:
        return _CACHE["roster"]
    try:
        from mapgen import kit
        shelves = kit.forge_shelves()
    except Exception:
        shelves = {}
    order = []
    text = _read("of_forge.lua")
    start = text.find("forge.CATEGORIES = {")
    if start >= 0:
        body = text[start:]
        end = re.search(r"\n}\n", body)
        body = body[:end.start()] if end else body
        names = set(re.findall(r'name = "([^"]+)"', body))
        for line in body.splitlines():
            line = line.split("--", 1)[0]
            for k in re.findall(r'"([A-Za-z0-9_]+)"', line):
                if k not in names and k not in order:
                    order.append(k)
    named = rows()
    out = []
    for key in order:
        name, variants = named.get(key, (key, []))
        shelf = shelves.get(key, "")
        out.append(Forge(key, name, shelf, variants,
                         floats=shelf in FLOAT_SHELVES or key in FLOAT_KEYS))
    _CACHE["roster"] = out
    return out
def get(key):
    return next((f for f in roster() if f.key == key), None)
def variant_names(key):
    f = get(key)
    return list(f.variants) if f is not None else []
def known_keys():
    return set(f.key for f in roster()) | {"onoffswitch", "onoffred", "onoffblue",
                                           "lgtarget", "lgbutton", "lgzone"}
def forget():
    _CACHE.clear()
PIPE_NONE, PIPE_LEVEL, PIPE_PAIR = 0, 1, 2
LEVELS = (
    (16, "Castle grounds"), (6, "Inside the castle"), (26, "Castle courtyard"),
    (9, "Bob-omb Battlefield"), (24, "Whomp's Fortress"), (12, "Jolly Roger Bay"),
    (5, "Cool, Cool Mountain"), (4, "Big Boo's Haunt"), (7, "Hazy Maze Cave"),
    (22, "Lethal Lava Land"), (8, "Shifting Sand Land"), (23, "Dire, Dire Docks"),
    (10, "Snowman's Land"), (11, "Wet-Dry World"), (36, "Tall, Tall Mountain"),
    (13, "Tiny-Huge Island"), (14, "Tick Tock Clock"), (15, "Rainbow Ride"),
    (17, "Bowser in the Dark World"), (19, "Bowser in the Fire Sea"),
    (21, "Bowser in the Sky"), (27, "Peach's Secret Slide"), (20, "Secret Aquarium"),
    (29, "Tower of the Wing Cap"), (18, "Cavern of the Metal Cap"),
    (28, "Vanish Cap under the Moat"), (31, "Wing Mario over the Rainbow"),
)
def pipe_tags(doc):
    out = {}
    for ref in doc.refs("object"):
        o = doc.get(ref)
        if o.get("key") == "warppipe" and isinstance(o.get("pipe"), dict):
            t = o["pipe"].get("tag")
            if isinstance(t, int) and t > 0:
                out[t] = ref
    return out
def free_tag(doc):
    have = pipe_tags(doc)
    n = 1
    while n in have:
        n += 1
    return n
def pipe_issues(doc):
    tags = pipe_tags(doc)
    out = []
    for ref in doc.refs("object"):
        o = doc.get(ref)
        pipe = o.get("pipe") if o.get("key") == "warppipe" else None
        if isinstance(pipe, dict) and pipe.get("kind") == PIPE_PAIR \
                and pipe.get("pair") not in tags:
            out.append((ref, "this pipe leads to pipe %s, and no pipe here carries it"
                        % pipe.get("pair")))
    return out
