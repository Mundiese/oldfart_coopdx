import math
import os
POOL = 1200
THIN_AT = 750
CEILING = 1050
RESERVE = 300
LEVEL_WITH_16 = 50
SAFETY = 50
FREE_FOR_VENUE = CEILING - RESERVE - LEVEL_WITH_16
HATS_PETS = 32
PARTICLE_PEAK = 16 * (2 + 6 + 7)
VENUE_LINE = POOL - HATS_PETS - PARTICLE_PEAK - SAFETY
MAP_LINE = VENUE_LINE - LEVEL_WITH_16
from . import modeknow as _modeknow
FAMILIES = ("shooter", "objective", "knockoff", "race", "party", "hide", "course", "explore")
MODE_RESERVE = {fam: _modeknow.family_reserve(fam) for fam in FAMILIES}
MODE_RESERVE_SOURCE = _modeknow.SOURCE
DISTINCT_PICTURES_MAX = 300
PICTURES_WAS = 60
PICTURE_KB = 2.5
MOD_SIZE_MAX_KB = 35 * 1024
_ARENAS = []
def _arenas():
    if not _ARENAS:
        from . import v1
        _ARENAS.append(v1.arenas_module())
    return _ARENAS[0]
def drawn(pieces):
    m = _arenas()
    pics, keys = set(), set()
    for p in pieces:
        if p.get("tex") == "invisible":
            continue
        token = m.runtime_token(p) if hasattr(m, "runtime_token") else None
        if token is not None:
            keys.add(token)
        else:
            pics.add((p["kind"], p.get("tex"), int(p["w"]), int(p["h"]), int(p["d"])))
    return pics, keys
MERGE_FROM = 150
MERGED_VERTICES = 3600
BOX_VERTICES = 24
BOX_BYTES = (0, 46, 47)
TOP_SPLIT = 8
TOP_SPLITS = 4
_SHAPE_VERTICES = {}
def shape_vertices(byte):
    if byte in BOX_BYTES:
        return BOX_VERTICES
    if not _SHAPE_VERTICES:
        import re
        here = os.path.dirname(os.path.abspath(__file__))
        text = open(os.path.join(here, "..", "..", "of_stretch.lua")).read()
        for m in re.finditer(r"^    \[(\d+)\] = \{ tag = .*? f = \{(.*)\} \},?$", text, re.M):
            faces = re.findall(r"\{([-\d,]+)\}", m.group(2))
            _SHAPE_VERTICES[int(m.group(1))] = sum((len(f.split(",")) - 4) // 7 for f in faces)
    return _SHAPE_VERTICES.get(byte, 64)
def box_vertices(byte, w, d):
    if byte != 0:
        return BOX_VERTICES
    a = min(TOP_SPLITS, max(1, int(math.ceil(w / float(TOP_SPLIT)))))
    b = min(TOP_SPLITS, max(1, int(math.ceil(d / float(TOP_SPLIT)))))
    return BOX_VERTICES + 4 * (a * b - 1)
def objects(pieces):
    pieces = list(pieces)
    if len(pieces) <= MERGE_FROM:
        return len(pieces)
    m = _arenas()
    singles, floors = 0, 0
    groups = {}
    for p in pieces:
        quarter = int(round(p.get("yaw", 0) or 0)) % 90 == 0
        if p.get("tex") == "invisible":
            if quarter:
                floors += 1
            else:
                singles += 1
            continue
        token = m.runtime_token(p) if hasattr(m, "runtime_token") else None
        parts = token[1:].split(":") if token else []
        if not quarter or not parts or not parts[0].isdigit():
            singles += 1
            continue
        byte = int(parts[0])
        from . import kit
        name = ("b:" if byte in BOX_BYTES and not kit.layered(parts[1]) else "s:") + parts[1]
        count = shape_vertices(byte)
        if byte in BOX_BYTES and len(parts) >= 5:
            count = box_vertices(byte, float(parts[2]), float(parts[4]))
        have = groups.get(name)
        if have is None or have[-1] + count > MERGED_VERTICES:
            groups.setdefault(name, []).append(0)
        groups[name][-1] += count
        floors += 1
    batches = sum(len(g) for g in groups.values())
    return singles + batches + (1 if floors else 0)
def pictures_line(pictures):
    if pictures <= DISTINCT_PICTURES_MAX:
        return None
    return ("pictures: %d distinct pictures, over the %d line (~%d KB for every joiner, "
            "who downloads the whole mod - %d KB more than the line; said, not refused)"
            % (pictures, DISTINCT_PICTURES_MAX, round(pictures * PICTURE_KB),
               round((pictures - DISTINCT_PICTURES_MAX) * PICTURE_KB)))
SURVEY_MAX = 28
BOUNDARY = 32767
DRAW_REACH = 20000
PARTITION_CELL = 1024
TRIANGLES = {"box": 12, "ramp": 8, "stairs": 16, "outer": 6, "inner": 10, "rail": 12,
             "pillar": 28, "arch": 44, "prism": 8, "outerstairs": 18, "innerstairs": 18,
             "curve": 36, "bank": 68, "arcwall": 68, "ridge": 8, "pyramid": 6,
             "roundcorner": 28, "uslope": 8, "uouter": 6, "uinner": 10, "wedgetip": 12,
             "wedgetipouter": 12, "wedgetipinner": 12, "pole": 12, "doorway": 44,
             "window": 64}
TIER_SHARE = {"tiny": 0.0, "small": 0.0, "medium": 0.0, "large": 0.75, "huge": 0.9,
              "gigantic": 1.0}
TIER_FLOOR = {"tiny": 100, "small": 100, "medium": 120, "large": 300, "huge": 420,
              "gigantic": 500}
def reserve_for(family=None, modes=()):
    named = [m for m in (modes or ()) if m]
    if named:
        return max(_modeknow.reserve(m) for m in named)
    return MODE_RESERVE.get(family or "", 60)
def _family_of(mode):
    try:
        from .brief import FAMILY_MODES
        for fam, keys in FAMILY_MODES.items():
            if mode in keys:
                return fam
    except Exception:
        pass
    return None
SINGLE_SHARE_MEASURED = 0.475
SINGLE_SHARE = 0.55
PIECE_MAX = 1600
def object_ceiling(family=None, modes=()):
    return int(MAP_LINE - reserve_for(family, modes))
def pieces_for(objects_line):
    if objects_line <= MERGE_FROM:
        return int(objects_line)
    return int(min(PIECE_MAX, max(objects_line, objects_line / SINGLE_SHARE)))
def ceiling(family=None, modes=(), baked=False):
    if baked:
        return BAKED_PIECE_MAX
    return pieces_for(object_ceiling(family, modes))
TIER_ACROSS = (("tiny", 5000), ("small", 6500), ("medium", 9000), ("large", 12000),
               ("huge", 16000))
def tier_of(size):
    if isinstance(size, str):
        return size if size in TIER_SHARE else "medium"
    if isinstance(size, dict):
        if size.get("tier") in TIER_SHARE and "across" not in size:
            return size["tier"]
        if isinstance(size.get("across"), (int, float)):
            across = float(size["across"])
        elif isinstance(size.get("across_s"), (int, float)):
            across = (float(size["across_s"]) - 0.6) * 960.0
        else:
            return "medium"
        for name, top in TIER_ACROSS:
            if across <= top:
                return name
        return "gigantic"
    return "medium"
def budget_max(baked=False):
    if baked:
        return BAKED_PIECE_MAX
    least = min(list(MODE_RESERVE.values()) + [r["reserve"] for r in _modeknow.table()])
    return pieces_for(MAP_LINE - least)
def tier_budget(size, family=None, modes=(), baked=False):
    name = tier_of(size)
    top = ceiling(family, modes)
    share = TIER_SHARE.get(name, 0.0)
    out = int(min(top, max(TIER_FLOOR.get(name, 120), share * top)))
    if baked and family in BAKED_TIER_FAMILIES:
        out = max(out, BAKED_TIER.get(name, 0))
    if baked and family == "explore":
        out = max(out, EXPLORE_BAKED_TIER.get(name, 0))
    return out
def report(arena, family=None, modes=()):
    pieces = arena.get("pieces", [])
    tris = sum(TRIANGLES.get(p["kind"], 12) for p in pieces)
    pics, keys = drawn(pieces)
    reach = 0
    for p in pieces:
        reach = max(reach, abs(p["x"]) + p["w"] / 2.0, abs(p["z"]) + p["d"] / 2.0)
    top = ceiling(family, modes)
    cost = objects(pieces) + len(arena.get("markers", []) or []) \
        + len(arena.get("objects", []) or []) + len(arena.get("movers") or [])
    return {"pieces": len(pieces), "ceiling": top,
            "objects": cost, "object_ceiling": object_ceiling(family, modes),
            "pool_after": LEVEL_WITH_16 + cost + reserve_for(family, modes),
            "pool_line": VENUE_LINE,
            "forge_room_left": max(0, min(FREE_FOR_VENUE, MAP_LINE - cost)),
            "triangles": tris, "pictures": len(pics), "runtime_keys": len(keys),
            "download_kb": round(len(pics) * PICTURE_KB, 1),
            "pictures_max": DISTINCT_PICTURES_MAX,
            "pictures_over": len(pics) > DISTINCT_PICTURES_MAX,
            "survey": len((arena.get("survey") or {}).get("points", [])),
            "survey_max": SURVEY_MAX, "reach": int(reach), "draw_reach": DRAW_REACH}
def table():
    rows = [("object pool", POOL, "object_list_processor.h:26"),
            ("particles thinned above", THIN_AT, "object_helpers.c:2688"),
            ("particles refused above (the build line)", CEILING, "object_helpers.c:2695"),
            ("reserve under the line", RESERVE, "of_spawner.lua RESERVE"),
            ("blank level + 16 players", LEVEL_WITH_16, "of_spawner.lua header (~700 free)"),
            ("free for a venue", FREE_FOR_VENUE, "the three above"),
            ("safety for bursts", SAFETY, "budget.py"),
            ("hats and pets of players arriving", HATS_PETS, "of_spawner.lua header"),
            ("sixteen players' particles at the peak", PARTICLE_PEAK,
             "16 x the dust chain 2+6+7 frames (behavior_data.c:2782-2815, white_puff.inc.c:13)"),
            ("the pool a venue may stand to", VENUE_LINE,
             "pool 1200 - hats - particles - bursts"),
            ("the map's line, less its modes'", MAP_LINE, "venue line - level and players"),
            ("new pictures per map", DISTINCT_PICTURES_MAX,
             "~750 KB at ~2.5 KB, a soft line"),
            ("the whole mod, KB", MOD_SIZE_MAX_KB, "mods.h MAX_MOD_SIZE: over it the mod vanishes"),
            ("survey points", SURVEY_MAX, "sync string 256 / 9"),
            ("coordinates", BOUNDARY, "s16, extended_bounds.h mode 3"),
            ("draw reach", DRAW_REACH, "of_venues.lua venues.REACH")]
    rows.append(("pieces merged above", MERGE_FROM, "of_venues.lua venues.MERGE_FROM"))
    rows.append(("objects per piece above it (measured worst)", SINGLE_SHARE_MEASURED,
                 "budget.objects on the gallery's big maps (P-explore-w1)"))
    rows.append(("objects per piece above it (held)", SINGLE_SHARE,
                 "the measured worst plus a margin"))
    rows.append(("pieces at most", PIECE_MAX,
                 "draw and floor-load cost, about twice a full world before (estimate)"))
    for fam in sorted(MODE_RESERVE):
        rows.append(("object ceiling for %s maps" % fam, object_ceiling(fam),
                     "free %d - %s reserve %d (%s) - safety %d"
                     % (FREE_FOR_VENUE, fam, MODE_RESERVE[fam], MODE_RESERVE_SOURCE, SAFETY)))
        rows.append(("ceiling for %s maps (pieces)" % fam, ceiling(fam),
                     "object ceiling %d / %.2f objects a piece, at most %d"
                     % (object_ceiling(fam), SINGLE_SHARE, PIECE_MAX)))
    for row in _modeknow.table():
        rows.append(("reserve of %s" % row["key"], row["reserve"], row["source"]))
    return rows
BAKED_PIECE_MAX = 3000
BAKED_TIER_FAMILIES = ("explore", "hide")
BAKED_TIER = {"large": 1400, "huge": 1450, "gigantic": 1500}
EXPLORE_BAKED_TIER = {"tiny": 600, "small": 800, "medium": 1100}
BAKED_METERS = {
    "view": (25000, 50000),
    "draw_triangles": (60000, 120000),
    "cell_walls": (100, 250),
    "cell_floors": (60, 150),
    "collision_triangles": (20000, 50000),
    "lvl_kb": (200, 600),
    "levels_mb": (3.0, 6.0),
    "textures": (32, 64),
    "reach": (30000, 32000),
}
BAKED_LVL_RED_KB = 1024
def baked_level(value, key):
    green, yellow = BAKED_METERS[key]
    if value is None:
        return "ok"
    if value <= green:
        return "ok"
    if value <= yellow:
        return "warn"
    return "fail"
def levels_bytes(levels=None):
    levels = levels or os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__)))), "levels")
    if not os.path.isdir(levels):
        return 0
    return sum(os.path.getsize(os.path.join(levels, n)) for n in os.listdir(levels)
               if n.endswith(".lvl"))
FIT_KB = (("scatter", 0.5), ("detail", 0.25), ("tree", 0.18))
FIT_MOST = 0.75
FIT_PASSES = 2
FIT_SPARE = 12
FIT_FROM = 600
def _hash01(x, z):
    h = (int(x) * 73856093) ^ (int(z) * 19349663)
    return (h & 0xffff) / 65535.0
def fit_level(arena, family=None, modes=(), measure=None):
    pieces = arena.get("pieces") or []
    if len(pieces) < FIT_FROM:
        return None
    measure = measure or (lambda a: baked_report(a, family, modes, shade=True)["lvl_kb"][0])
    before = measure(arena)
    target = BAKED_METERS["lvl_kb"][1] - FIT_SPARE
    if before is None or before <= BAKED_METERS["lvl_kb"][1]:
        return None
    kinds = {}
    for word, _ in FIT_KB:
        kind = [i for i, p in enumerate(pieces) if (p.get("tag") or "").split(".")[0] == word]
        kind.sort(key=lambda i: (_hash01(pieces[i]["x"], pieces[i]["z"]), i))
        kinds[word] = kind
    take = set()
    after = before
    base = None
    rate = 1.0
    for _ in range(FIT_PASSES):
        over = after - target
        if over <= 0:
            break
        more = 0
        for word, kb in FIT_KB:
            if over <= 0:
                break
            kind = kinds[word]
            done = sum(1 for i in kind if i in take)
            room = int(len(kind) * FIT_MOST) - done
            n = max(0, min(room, int(math.ceil(over / (kb * rate)))))
            take.update(kind[done:done + n])
            over -= n * kb * rate
            more += n
        if not more:
            break
        from . import checks, flora
        ids = dict((id(p), i) for i, p in enumerate(pieces))
        for g in flora.groups(pieces):
            gi = [ids[id(p)] for p in g if id(p) in ids]
            if any(i in take for i in gi):
                take.update(gi)
        kept = arena["pieces"]
        arena["pieces"] = [p for i, p in enumerate(pieces) if i not in take]
        if base is None:
            arena["pieces"], was_ = kept, arena["pieces"]
            base = set(checks.run(arena).faults)
            arena["pieces"] = was_
        if not set(checks.run(arena).faults) <= base:
            arena["pieces"] = kept
            take = set(i for i, p in enumerate(pieces) if all(p is not q for q in kept))
            break
        was = after
        after = measure(arena)
        est = sum(kb for word, kb in FIT_KB for i in kinds[word] if i in take) or 1.0
        rate = max(0.2, (before - after) / est)
        if after >= was:
            break
    return (before, after, len(take))
def baked_report(arena, family=None, modes=(), levels=None, shade=True):
    import sys
    tools = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import venuebake
    m = venuebake.measure(arena, levels=levels, shade=shade)
    walls, wall_at = m["worst_walls"]
    floors, floor_at = m["worst_floors"]
    view, view_at = m["view"]
    kb = None if m.get("lvl_bytes") is None else m["lvl_bytes"] / 1024.0
    total_mb = (levels_bytes(levels) + (m.get("lvl_bytes") or 0)) / 1048576.0
    out = {
        "view": (view, baked_level(view, "view"), view_at),
        "draw_triangles": (m["draw_triangles"], baked_level(m["draw_triangles"], "draw_triangles"),
                           None),
        "cell_walls": (walls, baked_level(walls, "cell_walls"), wall_at),
        "cell_floors": (floors, baked_level(floors, "cell_floors"), floor_at),
        "collision_triangles": (m["collision_triangles"],
                                baked_level(m["collision_triangles"], "collision_triangles"), None),
        "lvl_kb": (kb, "fail" if kb is not None and kb > BAKED_LVL_RED_KB
                   else baked_level(kb, "lvl_kb"), None),
        "levels_mb": (total_mb, baked_level(total_mb, "levels_mb"), None),
        "textures": (m["textures"], baked_level(m["textures"], "textures"), None),
        "reach": (m["reach"], baked_level(m["reach"], "reach"), None),
    }
    cost = len(arena.get("markers", []) or []) + len(arena.get("objects", []) or []) \
        + len(arena.get("movers") or []) + len(arena.get("stars") or [])
    line = object_ceiling(family, modes)
    out["objects"] = (cost, "fail" if cost > line else ("warn" if cost >= 0.85 * line else "ok"),
                      None)
    n_open, open_at = m.get("liquid_open") or (0, None)
    out["liquid_rims"] = (n_open, "fail" if n_open else "ok", open_at)
    out["object_ceiling"] = line
    out["draw_vertices"] = m["draw_vertices"]
    out["chunks"] = m["chunks"]
    out["lvl_bytes"] = m.get("lvl_bytes")
    return out
