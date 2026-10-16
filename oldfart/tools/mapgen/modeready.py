import math
import os
import re
from . import modeknow
from . import modes as modesmod
BLOCK, WARN = "block", "warn"
SPOTS = {
    "ctfRed": ("Red flag", "the red team's flag and base"),
    "ctfBlue": ("Blue flag", "the blue team's flag and base"),
    "floodStart": ("Race start", "where the climb or the race starts"),
    "floodGoal": ("Race goal", "the top the water chases everybody to, or the race's goal"),
    "lineStart": ("Line start", "where Red Light, Green Light lines up"),
    "lineFinish": ("Line finish", "the line Red Light, Green Light runs to"),
    "musicalSpot": ("Musical spot", "the spot Musical Spots plays round"),
    "hill": ("Hill", "King of the Hill's hill (else the middle of the map)"),
}
PAIRS = {"ctfRed": "ctfBlue", "ctfBlue": "ctfRed", "floodStart": "floodGoal",
         "floodGoal": "floodStart", "lineStart": "lineFinish", "lineFinish": "lineStart"}
UPHILL = {"floodGoal": True, "floodStart": False}
OPTIONAL = {"koth": ("hill",)}
OWN_ROOM = {"football": "plays only on a pitch drawn for it (The Stadium)",
            "volleyball": "plays only on the court drawn in The Sand Court"}
TRACK_START = 1
TIERS = modeknow.TIERS
_kinds = {}
class Issue(dict):
    @property
    def level(self):
        return self["level"]
    @property
    def text(self):
        return self["text"]
def _issue(level, text, fix=None, fix_label=""):
    short = text.split(": ", 1)[1] if ": " in text else text
    return Issue(level=level, text=text, fix=fix, fix_label=fix_label,
                 short=short[:1].upper() + short[1:])
_texts = {}
def mode_file_text(key, repo=None):
    name = modesmod.file_of(key, repo)
    if not name:
        return ""
    path = os.path.join(repo or modesmod.v1.REPO, name)
    try:
        mtime = os.path.getmtime(path)
        got = _texts.get(path)
        if got is not None and got[0] == mtime:
            return got[1]
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return ""
    _texts[path] = (mtime, text)
    return text
def map_kind(key, repo=None):
    if key in _kinds:
        return _kinds[key]
    text = mode_file_text(key, repo)
    at = text.find("\nlocal mode = {")
    body = text[at:] if at >= 0 else ""
    m = re.search(r'\n    maps = ("([a-z]+)"|\{\s*"([a-z_0-9]+)")?', body)
    kind = "anywhere"
    if m and m.group(2):
        kind = m.group(2) if m.group(2) in ("own", "none", "surveyed", "arenas") else "anywhere"
    elif m and m.group(3):
        kind = m.group(3) if m.group(3) in ("own", "none", "surveyed", "arenas") else "arenas"
    elif m:
        kind = "arenas"
    _kinds[key] = kind
    return kind
def studio_tracks_only(key, repo=None):
    return "\n    studioTracksOnly = " in mode_file_text(key, repo)
def venue_ok(key, repo=None):
    kind = map_kind(key, repo)
    if kind in ("own", "none"):
        return False, "plays on its own maps; no venue is ever offered to it"
    if key in OWN_ROOM:
        return False, OWN_ROOM[key]
    return True, ""
def venue_keys(family, repo=None):
    have = modesmod.all(repo)
    return [k for k in modesmod.FAMILY.get(family, ())
            if (k in have or not have) and venue_ok(k, repo)[0]]
def name_of(key):
    return modesmod.all().get(key) or key
def _survey(layout):
    return (layout or {}).get("survey") or {}
def has_spot(layout, name):
    v = _survey(layout).get(name)
    return isinstance(v, dict) or (isinstance(v, list) and len(v) > 0)
def points(layout):
    return [p for p in _survey(layout).get("points") or [] if isinstance(p, dict)]
def spawns(layout):
    return [p for p in (layout or {}).get("spawns") or [] if isinstance(p, dict)]
def has_track_start(layout):
    if any(isinstance(m, dict) and m.get("kind") == TRACK_START
           for m in (layout or {}).get("markers") or []):
        return True
    return any(isinstance(o, dict) and o.get("key") == "racestart"
               for o in (layout or {}).get("objects") or [])
def survey_keys(key):
    return list((modeknow.measured().get("modes", {}).get(key) or {}).get("surveyKeys") or [])
def issues(layout, key, players=16, size=None):
    name = name_of(key)
    out = []
    ok, why = venue_ok(key)
    if not ok:
        return [_issue(BLOCK, "%s: %s." % (name, why), {"do": "drop"}, "Take it off")]
    row = modeknow.measured().get("modes", {}).get(key) or {}
    need_players = int(row.get("minPlayers") or 2)
    n_spawns = len(spawns(layout))
    if n_spawns < need_players:
        out.append(_issue(BLOCK, "%s: needs at least %d spawn points; the map has %d." % (
            name, need_players, n_spawns), {"do": "place", "entry": "markers:spawn"},
            "Place spawns"))
    elif n_spawns < min(16, int(players or 16)):
        out.append(_issue(WARN, "%s: %d spawn points for %d players - some players share one." % (
            name, n_spawns, min(16, int(players or 16))),
            {"do": "place", "entry": "markers:spawn"}, "Place spawns"))
    if studio_tracks_only(key):
        if not has_track_start(layout):
            out.append(_issue(BLOCK, "%s: runs on built tracks only - place a start gate." % name,
                              {"do": "place", "entry": "forge:racestart"}, "Place a start gate"))
    else:
        for sk in survey_keys(key):
            if sk == "points":
                continue
            if not has_spot(layout, sk):
                label = SPOTS.get(sk, (sk, ""))[0].lower()
                out.append(_issue(BLOCK, "%s: place the %s." % (name, label),
                                  {"do": "spot", "name": sk}, "Place it"))
    for sk in OPTIONAL.get(key, ()):
        if not has_spot(layout, sk):
            label = SPOTS.get(sk, (sk, ""))[0].lower()
            out.append(_issue(WARN, "%s: place the %s (without it, the middle of the map)." % (
                name, label), {"do": "spot", "name": sk}, "Place it"))
    want = (modeknow.knowledge(key).get("needs") or {}).get("points") \
        if "points" in survey_keys(key) else None
    have = len(points(layout))
    if want and have < want:
        out.append(_issue(WARN, "%s: wants %d points to hold; the map has %d (the mod makes up "
                          "the rest)." % (name, want, have),
                          {"do": "place", "entry": "markers:spawn"}, "Place spawns"))
    rng = modeknow.size_range(key, players) if size in TIERS else None
    if rng is not None:
        lo, hi = TIERS.index(rng[0]), TIERS.index(rng[1])
        at = TIERS.index(size)
        if not lo <= at <= hi:
            want_words = rng[0] if lo == hi else "%s to %s" % rng
            out.append(_issue(WARN, "%s: plays best on a %s map; this one is %s." % (
                name, want_words, size), {"do": "drop"}, "Take it off"))
    out.sort(key=lambda i: i.level != BLOCK)
    return out
def readiness(layout, keys, players=16, size=None):
    return {k: issues(layout, k, players, size) for k in keys}
def blocking(layout, keys, players=16, size=None):
    out = {}
    for k in keys:
        why = [i.text for i in issues(layout, k, players, size) if i.level == BLOCK]
        if why:
            out[k] = why
    return out
def usable(layout, keys, players=16, size=None):
    bad = blocking(layout, keys, players, size)
    return [k for k in keys if k not in bad]
def shown(layout, family, chosen=()):
    have = modesmod.all()
    out = []
    for fam, keys in modesmod.FAMILY.items():
        for k in keys:
            if k not in have or not venue_ok(k)[0]:
                continue
            sks = [s for s in survey_keys(k) if s != "points"]
            if (fam == family or k in chosen or map_kind(k) == "anywhere"
                    or (sks and all(has_spot(layout, s) for s in sks))
                    or (studio_tracks_only(k) and has_track_start(layout))):
                out.append(k)
    return out
def _xyz(p):
    return (float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
def _candidates(layout):
    pts = [_xyz(p) for p in spawns(layout)] or [_xyz(p) for p in points(layout)]
    if not pts:
        for p in (layout or {}).get("pieces") or []:
            if isinstance(p, dict) and "h" in p:
                pts.append((float(p.get("x", 0)), float(p.get("y", 0)) + float(p["h"]),
                            float(p.get("z", 0))))
    return pts or [(0.0, 0.0, 0.0)]
def _d2(a, b):
    return (a[0] - b[0]) ** 2 + (a[2] - b[2]) ** 2
def _facing(at, towards):
    dx, dz = towards[0] - at[0], towards[2] - at[2]
    if not dx and not dz:
        return 0
    return int(round(math.degrees(math.atan2(dx, -dz)))) % 360
def default_spot(layout, name):
    pts = _candidates(layout)
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    centre = (cx, 0.0, cz)
    partner = PAIRS.get(name)
    if partner and has_spot(layout, partner):
        other = _survey(layout)[partner]
        other = _xyz(other[0] if isinstance(other, list) else other)
        best = max(pts, key=lambda p: _d2(p, other))
    elif name in UPHILL:
        best = (max if UPHILL[name] else min)(pts, key=lambda p: (p[1], -_d2(p, centre)))
    elif partner:
        pair = max(((a, b) for i, a in enumerate(pts) for b in pts[i:]),
                   key=lambda ab: _d2(*ab))
        a, b = sorted(pair, key=lambda p: (p[0], p[2]))
        first = name in ("ctfRed", "lineStart")
        best = a if first else b
    else:
        best = min(pts, key=lambda p: _d2(p, centre))
    return {"x": int(round(best[0])), "y": int(round(best[1])), "z": int(round(best[2])),
            "yaw": _facing(best, centre)}
