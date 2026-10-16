import json
import os
from . import kitbridge
from .scene import Marker
PIECE_FIELDS = ("kind", "tex", "x", "y", "z", "w", "h", "d")
META_FIELDS = ("name", "key", "family", "level", "look", "budget", "report", "onlyFor",
               "blurb", "note", "generator")
RACE_KINDS = {1: "start", 3: "info", 16: "gate", 18: "respawn", 32: "box", 80: "out zone"}
class LoadError(Exception):
    pass
class Loaded:
    def __init__(self, pieces, markers, meta):
        self.pieces, self.markers, self.meta = pieces, markers, meta
def sources():
    out = [("venue:%s" % k, venue_name(k)) for k in kitbridge.venue_keys()]
    gen = kitbridge.repo_path(os.path.join("tools", "venues-generated"))
    if os.path.isdir(gen):
        for name in sorted(os.listdir(gen)):
            if name.endswith(".json"):
                out.append((os.path.join(gen, name), name[:-5]))
    return out
def venue_name(key):
    for k, fn in kitbridge.venues():
        if k == key:
            return fn.replace("_", " ").title()
    return key
def venue_layout(key):
    try:
        return kitbridge.venue(key)
    except KeyError as exc:
        missing = str(exc)
    path = kitbridge.repo_path(os.path.join("tools", "venues-generated", "%s.json" % key))
    if not os.path.isfile(path):
        raise LoadError("%s, and no generated venue tools/venues-generated/%s.json"
                        % (missing.strip("'\""), key))
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except ValueError as why:
        raise LoadError("%s: not JSON (%s)" % (path, why))
    if isinstance(data, dict) and "pieces" not in data and "layout" in data:
        data = data["layout"]
    if not isinstance(data, dict) or "pieces" not in data:
        raise LoadError("%s: no pieces - is it a layout?" % path)
    return data
def load(source):
    if isinstance(source, dict):
        return from_arena(source, "<arena>")
    if source.startswith("venue:"):
        key = source.split(":", 1)[1]
        arena = venue_layout(key)
        arena.setdefault("name", venue_name(key))
        return from_arena(arena, source)
    path = source
    if os.path.isdir(path):
        path = os.path.join(path, "layout.json")
    if not os.path.isfile(path):
        raise LoadError("%s: no such file (a mapgen --out folder holds layout.json)" % source)
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except ValueError as exc:
        raise LoadError("%s: not JSON (%s)" % (path, exc))
    if isinstance(data, dict) and "pieces" not in data and "layout" in data:
        data = data["layout"]
    if not isinstance(data, dict) or "pieces" not in data:
        raise LoadError("%s: no pieces - is it a layout?" % path)
    return from_arena(data, path)
def from_arena(arena, source):
    pieces, problems = [], []
    known = kitbridge.arenas().KINDS
    for i, p in enumerate(arena.get("pieces") or []):
        if not all(f in p for f in PIECE_FIELDS):
            problems.append("piece %d lacks %s" % (i, [f for f in PIECE_FIELDS if f not in p]))
            continue
        if p["kind"] not in known:
            problems.append("piece %d: unknown kind %r" % (i, p["kind"]))
            continue
        q = dict(p)
        q.setdefault("yaw", 0)
        pieces.append(q)
    meta = {k: arena[k] for k in META_FIELDS if k in arena}
    meta["source"] = source
    meta["problems"] = problems
    return Loaded(pieces, markers_of(arena), meta)
def _point(d):
    return isinstance(d, dict) and "x" in d and "z" in d
def markers_of(arena):
    out = []
    for i, s in enumerate(arena.get("spawns") or []):
        if _point(s):
            out.append(Marker("spawn", s["x"], s.get("y", 0), s["z"], s.get("yaw", 0),
                              str(i + 1), s))
    spawn_spots = {(m.x, m.y, m.z) for m in out}
    survey = arena.get("survey") or {}
    for name, value in sorted(survey.items()):
        items = value if isinstance(value, list) else [value]
        for j, pt in enumerate(items):
            if not _point(pt):
                continue
            if name == "points" and (float(pt["x"]), float(pt.get("y", 0)), float(pt["z"])) in spawn_spots:
                continue
            label = name if len(items) == 1 else "%s %d" % (name, j + 1)
            out.append(Marker("survey", pt["x"], pt.get("y", 0), pt["z"], pt.get("yaw", 0), label, pt))
    for m in arena.get("markers") or []:
        if _point(m):
            label = m.get("label") or RACE_KINDS.get(m.get("kind"), "marker")
            if m.get("kind") in (3, 80):
                continue
            out.append(Marker("race", m["x"], m.get("y", 0), m["z"], m.get("yaw", 0), label, m))
    for o in arena.get("objects") or []:
        if _point(o):
            out.append(Marker("object", o["x"], o.get("y", 0), o["z"], o.get("yaw", 0),
                              o.get("what") or o.get("key") or "object", o))
    return out
