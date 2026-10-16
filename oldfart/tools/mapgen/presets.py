import json
import os
import re
HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "presets.json")
_data = None
def all_presets():
    global _data
    if _data is None:
        with open(PATH, encoding="utf-8") as handle:
            _data = json.load(handle)["list"]
    return _data
def get(key):
    if not isinstance(key, str):
        return None
    k = key.strip().lower()
    for p in all_presets():
        if p["key"] == k or p["name"].lower() == k or k in p.get("words", []):
            return p
    return None
def find_in(low):
    best = None
    for p in all_presets():
        for w in sorted(p.get("words", []) + [p["name"].lower()], key=len, reverse=True):
            m = re.search(r"(?<![a-z0-9])%s(?![a-z0-9])" % re.escape(w), low)
            if m and (best is None or m.start() < best[1].start()):
                best = (p["key"], m)
                break
    return best
def table():
    return [(p["key"], p["name"], p.get("about", "")) for p in all_presets()]
def apply(raw):
    p = get(raw.get("preset"))
    notes = []
    if p is None:
        return raw, notes
    out = dict(raw)
    out["preset"] = p["key"]
    pb = p.get("brief", {})
    from .brief import FAMILY_DEFAULTS, FAMILY_ALIASES
    for field, value in pb.items():
        if field == "dna":
            dna = dict(value)
            dna.update(out.get("dna") or {})
            out["dna"] = dna
        elif field == "features":
            have = out.get("features") or {"want": [], "avoid": []}
            want = list(have.get("want", []))
            avoid = list(have.get("avoid", []))
            for f in value.get("want", []):
                if f not in want and f not in avoid:
                    want.append(f)
            for f in value.get("avoid", []):
                if f not in avoid and f not in want:
                    avoid.append(f)
            out["features"] = {"want": want, "avoid": avoid}
        elif field == "prefabs":
            have = list(out.get("prefabs") or [])
            out["prefabs"] = have + [k for k in value if k not in have]
        elif field == "visuals":
            if not out.get("visuals"):
                out["visuals"] = list(value)
        elif field not in out or out.get(field) in (None, "auto"):
            out[field] = value
    fam = FAMILY_ALIASES.get(str(out.get("family", "shooter")), out.get("family", "shooter"))
    level = out.get("level")
    if level in (None, "auto"):
        level = FAMILY_DEFAULTS.get(fam, {}).get("level")
    if out.get("ground") not in (None, "auto", "tiles") and level != "empty" \
            and "ground" not in raw:
        out.pop("ground", None)
    notes.append("preset %s: %s" % (p["name"], p.get("about", "")))
    return out, notes
