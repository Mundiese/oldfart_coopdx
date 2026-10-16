import copy
import json
import os
from . import REPO
FORMAT_VERSION = 1
KINDS = ("piece", "spawn", "object", "mover", "star", "spot", "anchor")
LISTS = {"piece": "pieces", "spawn": "spawns", "object": "objects", "mover": "movers",
         "star": "stars"}
PREFIX = {"piece": "p", "spawn": "s", "object": "o", "mover": "m", "star": "b", "spot": "w"}
WORLD = "world"
MODEL_PREFIX = "of_ak_"
class DocumentError(ValueError):
    pass
def model_name(piece):
    def n(v):
        return str(int(round(v)))
    return "%s%s_%s_%s_%s_%s_geo" % (MODEL_PREFIX, piece["tex"], piece["kind"], n(piece["w"]),
                                     n(piece["h"]), n(piece["d"]))
def _same(a, b):
    return json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)
class Document:
    def __init__(self, brief=None, layout=None, ids=None, meta=None):
        self.brief = copy.deepcopy(brief) if brief is not None else {}
        self.recoded = 0
        layout = copy.deepcopy(layout) if layout is not None else empty_layout()
        from mapgen import mood as _mood
        _mood.drop_object_rains(layout)
        self.rest = {k: v for k, v in layout.items() if k not in LISTS.values()}
        self._had = {k: k in layout for k in LISTS.values()}
        self.items = {kind: [] for kind in list(LISTS) + ["spot"]}
        self._next = {kind: 1 for kind in list(LISTS) + ["spot"]}
        ids = ids or {}
        for kind, key in LISTS.items():
            given = ids.get(key) or []
            have = set()
            for i, item in enumerate(layout.get(key) or []):
                iid = self._claim(kind, given[i] if i < len(given) else None, have)
                have.add(iid)
                self.items[kind].append((iid, item))
        given = ids.get("spots") or []
        have = set()
        for i, item in enumerate(read_spots(self.rest)):
            iid = self._claim("spot", given[i] if i < len(given) else None, have)
            have.add(iid)
            self.items["spot"].append((iid, item))
        survey = (self.rest.get("survey") or {}).get("points")
        spawns = [s for _, s in self.items["spawn"]]
        self.survey_follows = isinstance(survey, list) and (
            _same(survey[:len(spawns)], spawns) if spawns else not survey)
        self._spawn_copies = len(spawns) if self.survey_follows else 0
        self.meta = dict(meta or {})
        self.revision = 0
        self.listeners = []
        self._ensure_anchor_ids()
    def _claim(self, kind, iid=None, have=None):
        if have is None:
            have = set(i for i, _ in self.items[kind])
        if iid is None or iid in have:
            while True:
                iid = "%s%d" % (PREFIX[kind], self._next[kind])
                self._next[kind] += 1
                if iid not in have:
                    break
        else:
            digits = iid[len(PREFIX[kind]):]
            if iid.startswith(PREFIX[kind]) and digits.isdigit():
                self._next[kind] = max(self._next[kind], int(digits) + 1)
        return iid
    def new_id(self, kind):
        if kind == "anchor":
            have = set(a.get("id") for a in self.anchors())
            n = len(have) + 1
            while "a%d" % n in have:
                n += 1
            return "a%d" % n
        return self._claim(kind)
    def _ensure_anchor_ids(self):
        anchors = self.brief.get("anchors")
        if not isinstance(anchors, list):
            return
        seen = set()
        for i, a in enumerate(anchors):
            if isinstance(a, dict) and (not a.get("id") or a["id"] in seen):
                a["id"] = "%s%d" % (a.get("what", "anchor"), i + 1)
            if isinstance(a, dict):
                seen.add(a["id"])
    def anchors(self):
        return [a for a in (self.brief.get("anchors") or []) if isinstance(a, dict)]
    def refs(self, kind=None):
        out = []
        for k in (KINDS if kind is None else (kind,)):
            if k == "anchor":
                out += [("anchor", a["id"]) for a in self.anchors()]
            else:
                out += [(k, i) for i, _ in self.items[k]]
        return out
    def get(self, ref):
        kind, iid = ref
        if kind == "anchor":
            for a in self.anchors():
                if a.get("id") == iid:
                    return a
            return None
        for i, item in self.items[kind]:
            if i == iid:
                return item
        return None
    def index_of(self, ref):
        kind, iid = ref
        seq = self.anchors() if kind == "anchor" else [i for i, _ in self.items[kind]]
        for n, x in enumerate(seq):
            if (x.get("id") if kind == "anchor" else x) == iid:
                return n
        return None
    def __contains__(self, ref):
        return self.get(ref) is not None
    def pieces(self):
        return [p for _, p in self.items["piece"]]
    def spawns(self):
        return [s for _, s in self.items["spawn"]]
    def anchor_view(self, anchor):
        a = dict(anchor)
        where = a.get("where") or {}
        if "x" in where and "z" in where:
            return a
        solved = ((self.rest.get("report") or {}).get("anchors_solved") or {}).get(a.get("id"))
        if solved:
            a["_at"] = (solved[0].get("x", 0), solved[0].get("z", 0))
        else:
            a["_at"] = (0, 0)
        return a
    def view_item(self, ref):
        item = self.get(ref)
        if item is None:
            return None
        return self.anchor_view(item) if ref[0] == "anchor" else item
    def _changed(self, what, refs):
        self.revision += 1
        for fn in list(self.listeners):
            fn(what, refs)
    def insert(self, ref, item, index=None):
        kind, iid = ref
        if kind == "anchor":
            anchors = self.brief.setdefault("anchors", [])
            item = dict(item)
            item["id"] = iid
            anchors.insert(len(anchors) if index is None else index, item)
            self._undefault("anchors")
        else:
            iid = self._claim(kind, iid)
            seq = self.items[kind]
            seq.insert(len(seq) if index is None else index, (iid, item))
            ref = (kind, iid)
        self._changed("insert", [ref])
        return ref
    def remove(self, ref):
        kind, iid = ref
        index = self.index_of(ref)
        if index is None:
            raise DocumentError("no %s %s" % (kind, iid))
        if kind == "anchor":
            anchors = self.brief["anchors"]
            real = [n for n, a in enumerate(anchors) if isinstance(a, dict) and a.get("id") == iid]
            item = anchors.pop(real[0])
        else:
            _, item = self.items[kind].pop(index)
        self._changed("remove", [ref])
        return index, item
    def replace(self, ref, item):
        kind, iid = ref
        if kind == "anchor":
            anchors = self.brief["anchors"]
            for n, a in enumerate(anchors):
                if isinstance(a, dict) and a.get("id") == iid:
                    item = dict(item)
                    item["id"] = iid
                    item.pop("_at", None)
                    anchors[n] = item
                    break
            else:
                raise DocumentError("no anchor %s" % iid)
        else:
            seq = self.items[kind]
            for n, (i, _) in enumerate(seq):
                if i == iid:
                    seq[n] = (iid, item)
                    break
            else:
                raise DocumentError("no %s %s" % (kind, iid))
        self._changed("replace", [ref])
    def set_brief(self, brief):
        self.brief = copy.deepcopy(brief)
        self._ensure_anchor_ids()
        self._changed("brief", [])
    def set_rest(self, key, value):
        if value is None:
            self.rest.pop(key, None)
        else:
            self.rest[key] = copy.deepcopy(value)
        self._changed("rest", [])
    def set_meta(self, key, value):
        if value is None:
            self.meta.pop(key, None)
        else:
            self.meta[key] = copy.deepcopy(value)
        self._changed("meta", [])
    def _undefault(self, field):
        d = self.brief.get("defaulted")
        if isinstance(d, list) and field in d:
            d.remove(field)
    def state(self):
        return {"brief": copy.deepcopy(self.brief), "layout": self.to_layout(models=False),
                "ids": self.ids(), "meta": copy.deepcopy(self.meta),
                "follows": self.survey_follows}
    def restore(self, state):
        other = Document(state["brief"], state["layout"], state["ids"], state["meta"])
        self.brief, self.rest, self.items = other.brief, other.rest, other.items
        self._had, self._next, self.meta = other._had, other._next, other.meta
        self.survey_follows = state.get("follows", other.survey_follows)
        self._spawn_copies = len(other.items["spawn"]) if self.survey_follows else 0
        self._changed("all", [])
    def ids(self):
        out = {LISTS[k]: [i for i, _ in self.items[k]] for k in LISTS}
        if self.items["spot"]:
            out["spots"] = [i for i, _ in self.items["spot"]]
        return out
    def spots(self, name=None):
        return [(("spot", i), s) for i, s in self.items["spot"]
                if name is None or s.get("_name") == name]
    def world(self):
        got = self.spots(WORLD)
        return got[0] if got else (None, None)
    def to_layout(self, models=True):
        out = copy.deepcopy(self.rest)
        for kind, key in LISTS.items():
            seq = [copy.deepcopy(item) for _, item in self.items[kind]]
            if seq or self._had[key]:
                out[key] = seq
        if models:
            for p in out.get("pieces", []):
                if "model" in p:
                    p["model"] = model_name(p)
        if self.survey_follows:
            survey = out.setdefault("survey", {})
            old = list(survey.get("points") or [])
            survey["points"] = copy.deepcopy(out.get("spawns", [])) + old[self._spawn_copies:]
        write_spots(out, [s for _, s in self.items["spot"]])
        return out
    def to_json(self):
        data = {"studio": FORMAT_VERSION, "brief": self.brief,
                "layout": self.to_layout(models=False), "ids": self.ids(), "meta": self.meta}
        return json.dumps(data, indent=1, sort_keys=True) + "\n"
    @classmethod
    def from_json(cls, text):
        try:
            data = json.loads(text)
        except ValueError as why:
            raise DocumentError("not an Oldfart Studio map file: %s" % why)
        return cls.from_data(data)
    @classmethod
    def from_data(cls, data):
        data = migrate(data)
        doc = cls(data.get("brief") or {}, data.get("layout") or empty_layout(),
                  data.get("ids"), data.get("meta"))
        return doc
    def save(self, path):
        write_atomic(path, self.to_json())
        self.meta["path"] = os.path.abspath(path)
    @classmethod
    def load(cls, path):
        if os.path.isdir(path):
            return cls.from_out_folder(path)
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        data = json.loads(text)
        recoded = recode_old_keys(data)
        doc = cls._load_data(data, path)
        doc.recoded = recoded
        return doc
    @classmethod
    def _load_data(cls, data, path):
        if "studio" in data:
            doc = cls.from_data(data)
        elif "pieces" in data:
            brief_path = os.path.join(os.path.dirname(path), "brief.json")
            brief = _read_json(brief_path) if os.path.exists(brief_path) else {}
            doc = cls(brief, data)
        elif "brief" in data or "family" in data:
            doc = cls(data, empty_layout())
        else:
            raise DocumentError("%s: neither an Oldfart Studio map, a layout nor a brief" % path)
        doc.meta["path"] = os.path.abspath(path) if path.endswith(".ofmap") else None
        return doc
    @classmethod
    def from_out_folder(cls, folder):
        lpath = os.path.join(folder, "layout.json")
        bpath = os.path.join(folder, "brief.json")
        if not os.path.exists(lpath) and not os.path.exists(bpath):
            raise DocumentError("%s has no layout.json or brief.json" % folder)
        layout = _read_json(lpath) if os.path.exists(lpath) else empty_layout()
        brief = _read_json(bpath) if os.path.exists(bpath) else {}
        recoded = recode_old_keys(layout) + recode_old_keys(brief)
        doc = cls(brief, layout)
        doc.recoded = recoded
        return doc
    def write_out_folder(self, folder):
        os.makedirs(folder, exist_ok=True)
        write_atomic(os.path.join(folder, "brief.json"), json.dumps(self.brief, indent=2) + "\n")
        write_atomic(os.path.join(folder, "layout.json"),
                     json.dumps(self.to_layout(), indent=1, sort_keys=True) + "\n")
        return [os.path.join(folder, "brief.json"), os.path.join(folder, "layout.json")]
def _is_point(p):
    return isinstance(p, dict) and isinstance(p.get("x"), (int, float)) \
        and isinstance(p.get("z"), (int, float))
def read_spots(rest):
    out = []
    world = rest.get(WORLD)
    if _is_point(world):
        out.append(dict(world, _name=WORLD))
        rest.pop(WORLD)
    survey = rest.get("survey")
    if isinstance(survey, dict):
        for name in sorted(k for k in survey if k != "points"):
            value = survey[name]
            if _is_point(value):
                out.append(dict(value, _name=name))
                survey.pop(name)
            elif isinstance(value, list) and value and all(_is_point(p) for p in value):
                out += [dict(p, _name=name, _slot=j) for j, p in enumerate(value)]
                survey.pop(name)
    return out
def write_spots(layout, spots):
    named = {}
    for s in spots:
        named.setdefault(s.get("_name"), []).append(s)
    for name, group in named.items():
        clean = [{k: v for k, v in s.items() if k not in ("_name", "_slot")} for s in group]
        if name == WORLD:
            layout[WORLD] = clean[0]
            continue
        survey = layout.setdefault("survey", {})
        if any("_slot" in s for s in group):
            order = sorted(range(len(group)), key=lambda i: group[i].get("_slot", 1 << 30))
            survey[name] = [clean[i] for i in order]
        else:
            survey[name] = clean[0]
def empty_layout():
    return {"name": "Untitled map", "key": "generated", "level": "empty", "budget": 120,
            "family": "shooter", "pieces": [], "spawns": [], "survey": {"points": []},
            "look": {}}
def migrate(data):
    version = data.get("studio")
    if not isinstance(version, int):
        raise DocumentError("not an Oldfart Studio map file (no format version)")
    if version > FORMAT_VERSION:
        raise DocumentError("this map was saved by a newer Oldfart Studio (format %d; this one reads "
                            "up to %d) - update Oldfart Studio to open it" % (version, FORMAT_VERSION))
    return data
_old_keys = {"stamp": None, "map": {}}
def old_keys():
    import blockrecode
    path = os.path.join(REPO, "tools", "blocks-manifest.txt")
    try:
        stamp = os.path.getmtime(path)
    except OSError:
        return {}
    if stamp != _old_keys["stamp"]:
        _old_keys["map"] = blockrecode.was_map()
        _old_keys["stamp"] = stamp
    return _old_keys["map"]
def recode_old_keys(data):
    try:
        mapping = old_keys()
    except Exception:
        return 0
    if not mapping:
        return 0
    import blockrecode
    return blockrecode.recode_layout(data, mapping)
def _read_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)
def write_atomic(path, text):
    folder = os.path.dirname(os.path.abspath(path))
    os.makedirs(folder, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)
