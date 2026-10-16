import json
import math
import re
import os
from . import modes as modesmod
HERE = os.path.dirname(os.path.abspath(__file__))
MEASURED = os.path.join(HERE, "modeknow_measured.json")
SOURCE = "measured, harness, 16 players"
CATEGORIES = ("enemies", "hazards", "movers", "items", "scenery")
BURST_LIFE_S = 0.5
ROUND_S = 40
MARGIN = 10
FAMILY_RULES = {
    "shooter": {
        "needs": {"spawns": 16, "field_spots": 12},
        "bans": {"enemies": "an enemy steals kills and hides who shot whom",
                 "hazards": "a hazard kills without a shooter: the score stops meaning skill",
                 "items": "power-ups unbalance the duel (the mode deals its own)"},
        "size": "medium", "verticality": "high",
        "likes": ["perches", "cover_walls", "loops", "ramps", "second_floor"]},
    "objective": {
        "needs": {"spawns": 16, "flags": 2, "points": 3},
        "bans": {"enemies": "a carrier killed by a Goomba is a run nobody stopped",
                 "hazards": "a hazard on a flag road decides captures by luck",
                 "items": "power-ups make a carrier unstoppable"},
        "size": "large", "verticality": "medium",
        "likes": ["lanes", "bridge", "loops", "shortcut", "side_colours"]},
    "knockoff": {
        "needs": {"spawns": 16, "ring": 1},
        "bans": {"enemies": "the board is the fight; an enemy is a third player nobody controls",
                 "hazards": "falling off is the mode's own hazard",
                 "movers": "a moving floor under a pushing match decides it",
                 "items": "the mode deals its own"},
        "size": "small", "verticality": "flat", "likes": ["plaza", "rails"]},
    "race": {
        "needs": {"spawns": 16, "start": 1, "goal": 1},
        "bans": {"enemies": "racers bump into the room's own players already",
                 "items": "the race deals its own items"},
        "size": "large", "verticality": "low",
        "likes": ["curves", "shortcut", "jumps", "loops", "chicane"]},
    "hide": {
        "needs": {"spawns": 16, "hiding_cells": 40},
        "bans": {"enemies": "an enemy hunts the hiders and gives them away",
                 "hazards": "a hider killed by a hazard is a seeker's free point",
                 "items": "a power-up glints across the map"},
        "size": "large", "verticality": "high",
        "likes": ["buildings", "nooks", "tunnel", "second_floor", "undercroft"]},
    "party": {
        "needs": {"spawns": 16, "board": 1},
        "bans": {c: "the mode builds its own board on a flat plate" for c in CATEGORIES},
        "size": "tiny", "verticality": "flat", "likes": ["plaza"]},
    "course": {
        "needs": {"spawns": 16, "start": 1, "goal": 1, "rests": 3},
        "bans": {},
        "size": "medium", "verticality": "high",
        "likes": ["jumps", "moving_platforms", "trampolines", "spiral", "pillars"]},
    "explore": {
        "needs": {"spawns": 16, "bonus_stars": 6},
        "bans": {},
        "size": "huge", "verticality": "medium",
        "likes": ["terrain", "water", "buildings", "islands", "river", "roads"]},
}
SPAWN_NEEDS = {
    "team": {"flank_min": 1500},
    "domination": {"points": 3, "point_gap_min": 3000},
    "ffa_shooter": {"spawn_points": 16, "spawn_gap_ideal": 3000, "cover_between": True},
}
TEAM_FAMILIES = ("objective",)
def spawn_needs(key=None, family=None):
    fam = modesmod.family_of(key) if key else family
    out = {}
    row = measured().get("modes", {}).get(key or "", {})
    teams = str(row.get("teams") or "")
    if fam in TEAM_FAMILIES or teams in ("always", "true"):
        out.update(SPAWN_NEEDS["team"])
    if key == "domination":
        out.update(SPAWN_NEEDS["domination"])
    if fam == "shooter" and teams != "always":
        out.update(SPAWN_NEEDS["ffa_shooter"])
    return out
def spawn_needs_for(mode_keys=(), family=None):
    keys = list(mode_keys or ()) or list(modesmod.FAMILY.get(family or "", ()))
    out = {}
    for k in keys or [None]:
        for name, v in spawn_needs(k, family).items():
            if isinstance(v, bool):
                out[name] = out.get(name, False) or v
            else:
                out[name] = max(out.get(name, v), v)
    return out
MODE_RULES = {
    "coinrush": {"bans": {"items": "coins are the score - a placed coin is a free point"}},
    "bank": {"bans": {"items": "coins are the score - a placed coin is a free point"}},
    "greendemon": {"bans": {"items": "a placed 1-up is mistaken for the demon"}},
    "rocketarena": {"verticality": "high", "likes": ["perches", "jump_pads", "second_floor"]},
    "oitc": {"size": "small"},
    "koth": {"needs": {"spawns": 16, "hill": 1, "points": 3}, "likes": ["crown", "ramps"]},
    "domination": {"needs": {"spawns": 16, "points": 3}},
    "ctf": {"needs": {"spawns": 16, "flags": 2}},
    "oneflag": {"needs": {"spawns": 16, "flags": 2}},
    "flood": {"bans": {"movers": "a lift beats the rising water by itself"},
              "verticality": "high", "needs": {"spawns": 16, "start": 1, "goal": 1}},
    "line": {"needs": {"spawns": 16, "start": 1, "goal": 1}},
    "downhill": {"verticality": "high"},
    "onoffclimb": {"verticality": "high", "bans": {"enemies": "the climb is the opponent"}},
    "silverfive": {"bans": {"items": "the silver stars are the goal; a placed star confuses them"}},
    "manhunt": {"bans": {"movers": "a lift is an escape the hunter cannot follow"}},
    "prophunt": {"likes": ["buildings", "columns", "nooks"]},
}
_cache = {}
REPO = os.path.dirname(os.path.dirname(HERE))
PROFILES = os.path.join(REPO, "tools", "mode-profiles.json")
CATALOGUE = os.path.join(REPO, "docs", "learned", "levels", "catalogue.json")
SIZE_WORDS = {"tiny": ("tiny", "tiny"), "tiny-small": ("tiny", "small"),
              "small": ("small", "small"), "small-medium": ("small", "medium"),
              "medium": ("medium", "medium"), "medium-large": ("medium", "large"),
              "large": ("large", "large")}
TIERS = ("tiny", "small", "medium", "large", "huge", "gigantic")
def profiles():
    if "p" not in _cache:
        try:
            with open(PROFILES, encoding="utf-8") as handle:
                _cache["p"] = {k: v for k, v in json.load(handle).items()
                               if not k.startswith("_")}
        except (OSError, ValueError):
            _cache["p"] = {}
    return _cache["p"]
def places():
    if "c" not in _cache:
        try:
            with open(CATALOGUE, encoding="utf-8") as handle:
                _cache["c"] = json.load(handle).get("places") or []
        except (OSError, ValueError):
            _cache["c"] = []
    return _cache["c"]
def size_range(key, players=16):
    prof = profiles().get(key) or {}
    for span, word in (prof.get("size") or {}).items():
        try:
            lo, hi = (int(x) for x in str(span).split("-"))
        except ValueError:
            continue
        if lo <= int(players or 16) <= hi:
            return SIZE_WORDS.get(re.match(r"\s*([a-z-]*)", str(word).lower()).group(1))
    return None
def ideal_size(key, players=16, current=None):
    rng = size_range(key, players)
    if rng is None:
        return None
    lo, hi = TIERS.index(rng[0]), TIERS.index(rng[1])
    if current in TIERS:
        c = TIERS.index(current)
        return TIERS[min(max(c, lo), hi)]
    return rng[1]
def reference_floor_m2(key):
    areas = sorted(p["measured"]["main_area_m2"] for p in places()
                   if key in (p.get("only_for") or []) and (p.get("measured") or {})
                   .get("main_area_m2"))
    return areas[len(areas) // 2] if areas else None
def measured():
    if "m" not in _cache:
        try:
            with open(MEASURED, encoding="utf-8") as handle:
                _cache["m"] = json.load(handle)
        except (OSError, ValueError):
            _cache["m"] = {"modes": {}}
    return _cache["m"]
def _merge(base, top):
    out = dict(base)
    for k, v in top.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict) and k != "needs":
            merged = dict(out[k])
            merged.update(v)
            out[k] = merged
        else:
            out[k] = v
    return out
def reserve_of(row):
    live = int(row.get("peakSync", 0)) + int(row.get("peakLocal", 0))
    bursts = int(math.ceil(row.get("bursts", 0) / float(ROUND_S) * BURST_LIFE_S))
    need = live + int(row.get("activity", 0)) + bursts
    return int(math.ceil(need / 10.0)) * 10 + MARGIN
def knowledge(key):
    fam = modesmod.family_of(key)
    k = _merge(FAMILY_RULES.get(fam, {"needs": {"spawns": 16}, "bans": {}, "size": "medium",
                                      "verticality": "medium", "likes": []}),
               MODE_RULES.get(key, {}))
    row = measured().get("modes", {}).get(key)
    k = dict(k, key=key, family=fam, measured=row, spawn_needs=spawn_needs(key))
    prof = profiles().get(key)
    if prof:
        k["profile"] = prof
        k["size"] = ideal_size(key) or k.get("size")
        spacing = (prof.get("spawns") or {}).get("spacing_m")
        if spacing:
            k["spawn_needs"] = dict(k["spawn_needs"], spacing=int(spacing) * 100)
        k["hiding"] = prof.get("hiding")
        k["reference_floor_m2"] = reference_floor_m2(key)
    driven = bool(row and row.get("started") and row.get("activeFrames", 0) >= ROUND_S * 30 // 2)
    if row:
        k["survey_keys"] = list(row.get("surveyKeys", []))
        k["maps"] = list(row.get("maps", []))
        k["teams"] = row.get("teams", "")
        k["min_players"] = row.get("minPlayers", 0)
    if driven:
        k["reserve"] = reserve_of(row)
        k["reserve_source"] = "%s (peak %d synced + %d local, %d by playing, %d bursts)" % (
            SOURCE, row.get("peakSync", 0), row.get("peakLocal", 0), row.get("activity", 0),
            row.get("bursts", 0))
    else:
        k["reserve"] = FALLBACK.get(key, FALLBACK_FAMILY.get(fam, 60))
        why = (row or {}).get("ended") or "not driven"
        k["reserve_source"] = "read off the source (the harness could not drive a round: %s)" % (
            why.strip() or "not driven")
    return k
FALLBACK = {"hexheat": 120,
            "logroll": 30,
            "booksquirm": 60,
            "murder": 40, "spots": 60}
FALLBACK_FAMILY = {"shooter": 60, "objective": 30, "knockoff": 30, "race": 90, "hide": 30,
                   "party": 200, "course": 60, "explore": 20}
def reserve(key):
    return knowledge(key)["reserve"]
def family_reserve(family):
    keys = modesmod.FAMILY.get(family, ())
    if not keys:
        return FALLBACK_FAMILY.get(family, 60)
    return max(reserve(k) for k in keys)
def allows(mode_keys, category, family=None):
    keys = list(mode_keys or ()) or list(modesmod.FAMILY.get(family or "", ()))
    if not keys:
        rules = FAMILY_RULES.get(family or "explore", {})
        why = rules.get("bans", {}).get(category)
        return (why is None), why or "free roam allows it"
    for key in keys:
        why = knowledge(key)["bans"].get(category)
        if why:
            return False, "%s: %s" % (key, why)
    return True, "every mode of this map allows %s" % category
def table():
    rows = []
    for key in sorted(modesmod.all() or modesmod.FAMILY_OF):
        k = knowledge(key)
        rows.append({"key": key, "family": k["family"], "reserve": k["reserve"],
                     "source": k["reserve_source"], "needs": k["needs"],
                     "bans": sorted(k["bans"]), "size": k["size"],
                     "verticality": k["verticality"], "likes": k["likes"],
                     "maps": k.get("maps", []), "survey_keys": k.get("survey_keys", []),
                     "spawn_needs": k.get("spawn_needs", {}),
                     "hiding": k.get("hiding"),
                     "reference_floor_m2": k.get("reference_floor_m2")})
    return rows
