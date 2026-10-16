import math
from . import v1
BLOCK, WARN = "block", "warn"
FFA = ("shooter", "oitc", "rocketarena", "wanted", "assassins", "laststanding", "crown",
       "coinrush", "greendemon", "bank", "murder", "bounty")
TEAM = ("ctf", "oneflag", "domination", "koth", "copsandrobbers", "snd")
OWN_ROOM = {"football": "plays on its own pitch (The Stadium)",
            "volleyball": "plays on its own court (The Stadium)",
            "hideseek": "plays on the game's own levels (maps = own)",
            "sardines": "plays on the game's own levels (maps = own)",
            "manhunt": "a whole-game hunt across the game's courses",
            "downhill": "rides the game's own slides (maps = own)",
            "bossrush": "fights the game's own bosses",
            "onoffclimb": "builds its own spiral (maps = empty)"}
RING_WIDEST = {"sumo": 3200, "bumperballs": 2800, "chompfever": 2000, "lavaleave": 1900,
               "bombxing": 1800, "hotrope": 1800, "firesweep": 3400, "blizzard": 1600,
               "bombsaway": 1400, "deflect": 1600, "hotpotato": 1600, "logroll": 2048,
               "megarampage": 2400, "smash": 4000, "booksquirm": 1600, "spots": 1600,
               "blast": 1600, "glassbridge": 1600, "hexheat": 1800, "hexagone": 1800,
               "turf": 2400, "simon": 1600, "frenzy": 1600, "blastgrid": 1800,
               "bombsort": 1600, "flyguy": 1600, "lakitu": 1600}
RING_MARGIN = 800
FLAT_PLATE = ("firesweep", "turf", "simon", "blastgrid")
TALL_ON_PLATE = 50
RACE = ("shellrace", "shellbattle", "line", "flood")
HIDE = ("prophunt", "zombies", "rabbitchase", "hideballoon")
COURSE = ("silverfive",)
ALL_MODES = tuple(sorted(set(FFA + TEAM + tuple(OWN_ROOM) + tuple(RING_WIDEST) + RACE + HIDE
                             + COURSE)))
RUN = 960.0
SHELL = 1920.0
FFA_POINTS = 16
FFA_GAP_BLOCK, FFA_GAP_WANT = 800, 2000
SPAWNS = 16
DOM_GAP = 3000
CTF_FLAGS = (9600, 14400)
SD_ATTACK_S = (12.0, 18.0)
SD_DEFEND_S = (4.0, 7.0)
SD_SITE_SHARE = 0.10
SD_ROTATE_SHARE = 0.70
SD_KEYS = {"sdDefend": 8, "sdAttack": 8, "sdSiteA": 1, "sdSiteB": 1}
RING_SPAWN_GAP = 300
CENTRE_OFF = 200
CHASE_GAP = 1000
RLGL_FAIR = 0.10
RLGL_SEEN = 0.8
RLGL_START_ROW = 16
RLGL_RING = 400
FLOOD_SLACK, FLOOD_GRACE, FLOOD_BELOW = 1.1, 8, 400
FLOOD_ROUTE_SHARE = 1.1
GATE_GAP_MOST = 4500
LAPS = 3
class Rule(object):
    def __init__(self, name, measure, level, band=""):
        self.name, self.measure, self.level, self.band = name, measure, level, band
def _m():
    return v1.arenas_module()
def _survey(a):
    return a.get("survey") or {}
def _spots(a, key):
    s = _survey(a).get(key)
    if s is None:
        return []
    return [s] if isinstance(s, dict) else [x for x in s if isinstance(x, dict)]
def _d(a, b):
    return math.hypot(a["x"] - b["x"], a["z"] - b["z"])
def _nn(spots):
    out = []
    for i, s in enumerate(spots):
        d = [_d(s, t) for j, t in enumerate(spots) if j != i]
        if d:
            out.append(min(d))
    return out
class Floor(object):
    B = 1000.0
    def __init__(self, pieces):
        m = _m()
        self.m = m
        self.book = {}
        for p in pieces:
            try:
                x0, x1, z0, z1, _ = m.footprint(p)
            except Exception:
                continue
            for bi in range(int(math.floor(x0 / self.B)), int(math.floor(x1 / self.B)) + 1):
                for bj in range(int(math.floor(z0 / self.B)), int(math.floor(z1 / self.B)) + 1):
                    self.book.setdefault((bi, bj), []).append((x0, x1, z0, z1, p))
    def tops(self, x, z):
        out = []
        for x0, x1, z0, z1, p in self.book.get((int(math.floor(x / self.B)),
                                                int(math.floor(z / self.B))), ()):
            if x0 <= x <= x1 and z0 <= z <= z1:
                try:
                    if not self.m.covers(p, x, z):
                        continue
                    t = self.m.top_at(p, x, z)
                except Exception:
                    t = p["y"] + p["h"]
                if t is not None:
                    out.append(t)
        return out
    def near(self, x, y, z, below=300, above=300):
        ts = [t for t in self.tops(x, z) if y - below <= t <= y + above]
        return max(ts) if ts else None
def plate(a):
    sp = (a.get("spawns") or [None])[0]
    if sp is None:
        return None
    fl = Floor(a.get("pieces") or [])
    y = sp["y"]
    reach = []
    for k in range(16):
        ang = 2 * math.pi * k / 16.0
        r = 0
        for d in range(100, 12001, 100):
            if fl.near(sp["x"] + math.sin(ang) * d, y, sp["z"] + math.cos(ang) * d, 60, 60) is None:
                break
            r = d
        reach.append(r)
    cx = sp["x"] + sum(math.sin(2 * math.pi * k / 16.0) * reach[k] for k in range(16)) / 16.0
    cz = sp["z"] + sum(math.cos(2 * math.pi * k / 16.0) * reach[k] for k in range(16)) / 16.0
    return cx, cz, min(reach), y
def m_spawns(a, mode, ctx):
    n = len(a.get("spawns") or [])
    return n, n >= SPAWNS, "%d spawns (%d players)" % (n, SPAWNS)
def m_own(a, mode, ctx):
    return None, False, "%s - never on a generated map" % OWN_ROOM[mode]
def m_ffa_points(a, mode, ctx):
    pts = _spots(a, "points") or (a.get("spawns") or [])
    nn = _nn(pts)
    lo = min(nn) if nn else 0
    ok = len(pts) >= FFA_POINTS and lo >= FFA_GAP_BLOCK
    return round(lo), ok, "%d free-for-all points, the nearest two %d apart (want %d+ points, " \
        "%d+ apart; %d ideal)" % (len(pts), lo, FFA_POINTS, FFA_GAP_BLOCK, FFA_GAP_WANT)
def m_ffa_spread(a, mode, ctx):
    pts = _spots(a, "points") or (a.get("spawns") or [])
    nn = sorted(_nn(pts))
    med = nn[len(nn) // 2] if nn else 0
    return round(med), med >= FFA_GAP_WANT, "median nearest point %d (want %d)" % (med, FFA_GAP_WANT)
def m_ctf(a, mode, ctx):
    r, b = _spots(a, "ctfRed"), _spots(a, "ctfBlue")
    if not r or not b:
        return None, False, "no ctfRed / ctfBlue flag spots"
    d = _d(r[0], b[0])
    return round(d), True, "flags %d apart" % d
def m_ctf_span(a, mode, ctx):
    r, b = _spots(a, "ctfRed"), _spots(a, "ctfBlue")
    if not r or not b:
        return None, False, "no flags"
    d = _d(r[0], b[0])
    return round(d), CTF_FLAGS[0] * 0.7 <= d <= CTF_FLAGS[1] * 1.15, \
        "flags %d apart (want %d-%d on the ground)" % (d, CTF_FLAGS[0], CTF_FLAGS[1])
def m_flanks(a, mode, ctx):
    ok = bool(_spots(a, "flankRed")) and bool(_spots(a, "flankBlue"))
    return ok, ok, "flank zones %s" % ("present" if ok else "missing")
def m_domination(a, mode, ctx):
    pts = _spots(a, "points")
    if len(pts) < 3:
        return len(pts), False, "%d points (needs 3)" % len(pts)
    p3 = pts[:3]
    gaps = [_d(p3[i], p3[j]) for i in range(3) for j in range(i + 1, 3)]
    lo = min(gaps)
    return round(lo), lo >= DOM_GAP, "points A, B, C, the nearest two %d apart (want %d)" % (lo, DOM_GAP)
def m_domination_min(a, mode, ctx):
    v, _, note = m_domination(a, mode, ctx)
    return v, v is not None and v >= DOM_GAP / 2, note
def m_koth(a, mode, ctx):
    ok = bool(_spots(a, "hill") or _spots(a, "points"))
    return ok, ok, "a hill" if ok else "no hill and no points"
def m_cops_cell(a, mode, ctx):
    pts = _spots(a, "points")
    if not pts:
        return None, False, "no points (the cell is points[1])"
    cx = sum(p["x"] for p in pts) / float(len(pts))
    cz = sum(p["z"] for p in pts) / float(len(pts))
    far = max(math.hypot(p["x"] - cx, p["z"] - cz) for p in pts) or 1.0
    off = math.hypot(pts[0]["x"] - cx, pts[0]["z"] - cz) / far
    return round(off, 2), off <= 0.4, "the cell %.0f %% of the way from the middle to the edge" % (100 * off)
def _route_s(a, p, q, ctx):
    try:
        from . import movers
        s = movers.route_s(a, (p["x"], p["y"], p["z"]), (q["x"], q["y"], q["z"]))
        if s is not None:
            return s
    except Exception:
        pass
    return 1.3 * _d(p, q) / RUN
def m_sd_keys(a, mode, ctx):
    miss = ["%s (%d)" % (k, n) for k, n in SD_KEYS.items() if len(_spots(a, k)) < n]
    return not miss, not miss, ("missing " + ", ".join(miss)) if miss else "sdDefend, sdAttack, " \
        "sdSiteA, sdSiteB all present"
def _centre(spots):
    return {"x": sum(s["x"] for s in spots) / len(spots), "y": spots[0]["y"],
            "z": sum(s["z"] for s in spots) / len(spots)}
def m_sd_times(a, mode, ctx):
    if not m_sd_keys(a, mode, ctx)[1]:
        return None, False, "no S&D spots"
    att, dfn = _spots(a, "sdAttack"), _spots(a, "sdDefend")
    A, B = _spots(a, "sdSiteA")[0], _spots(a, "sdSiteB")[0]
    ta, tb = _route_s(a, att[0], A, ctx), _route_s(a, att[0], B, ctx)
    da, db = _route_s(a, dfn[0], A, ctx), _route_s(a, dfn[0], B, ctx)
    rot = _route_s(a, A, B, ctx)
    ok = (SD_ATTACK_S[0] * 0.8 <= min(ta, tb) and max(ta, tb) <= SD_ATTACK_S[1] * 1.2
          and abs(ta - tb) <= SD_SITE_SHARE * max(ta, tb) * 2
          and max(da, db) <= SD_DEFEND_S[1] * 1.3 and rot <= SD_ROTATE_SHARE * min(ta, tb) * 1.2)
    return [round(ta, 1), round(tb, 1), round(da, 1), round(db, 1)], ok, \
        "attackers to A / B %.1f / %.1f s (want %d-%d), defenders %.1f / %.1f s (want %d-%d), " \
        "A to B %.1f s" % (ta, tb, SD_ATTACK_S[0], SD_ATTACK_S[1], da, db, SD_DEFEND_S[0],
                           SD_DEFEND_S[1], rot)
def m_ring(a, mode, ctx):
    pl = ctx.get("plate")
    if pl is None:
        pl = ctx["plate"] = plate(a)
    if pl is None:
        return None, False, "no spawn"
    want = (RING_WIDEST[mode] + RING_MARGIN) / 2.0
    r = pl[2] + 100
    return round(r), r >= want, "the plate reaches %d from spawn 1 (the ring at its widest " \
        "wants %d)" % (r, want)
def m_ring_min(a, mode, ctx):
    v, _, note = m_ring(a, mode, ctx)
    return v, v is not None and v >= RING_WIDEST[mode] / 4.0, note
def m_centre(a, mode, ctx):
    pl = ctx.get("plate") or plate(a)
    ctx["plate"] = pl
    sp = (a.get("spawns") or [None])[0]
    if pl is None or sp is None:
        return None, False, "no spawn"
    off = math.hypot(pl[0] - sp["x"], pl[1] - sp["z"])
    return round(off), off <= CENTRE_OFF, "spawn 1 %d from the plate's middle (the ring is " \
        "pinned where the host stands)" % off
def m_ring_spawns(a, mode, ctx):
    nn = _nn(a.get("spawns") or [])
    lo = min(nn) if nn else 0
    return round(lo), lo >= RING_SPAWN_GAP, "starts %d apart (want %d)" % (lo, RING_SPAWN_GAP)
def m_flat_plate(a, mode, ctx):
    pl = ctx.get("plate") or plate(a)
    ctx["plate"] = pl
    if pl is None:
        return None, False, "no spawn"
    cx, cz, r, y = pl
    tall = [p for p in a.get("pieces") or [] if math.hypot(p["x"] - cx, p["z"] - cz) < r - 100
            and p["y"] >= y - 5 and p["y"] + p["h"] > y + TALL_ON_PLATE]
    return len(tall), not tall, "%d things standing on the plate" % len(tall)
def m_smash_stage(a, mode, ctx):
    pl = ctx.get("plate") or plate(a)
    ctx["plate"] = pl
    if pl is None:
        return None, False, "no stage"
    return round(2 * pl[2]), 2 * pl[2] >= 3000, "the main stage %d across (want 4000-6000)" % (2 * pl[2])
def m_points(n):
    def f(a, mode, ctx):
        k = len(_spots(a, "points"))
        return k, k >= n, "%d points (needs %d)" % (k, n)
    return f
def m_chase_spread(a, mode, ctx):
    nn = _nn(a.get("spawns") or [])
    lo = min(nn) if nn else 0
    return round(lo), lo >= CHASE_GAP, "starts %d apart (want %d: time to contact)" % (lo, CHASE_GAP)
def m_marker_start(a, mode, ctx):
    k = _m().KIND
    starts = [x for x in a.get("markers") or [] if x.get("kind") == k["START"]]
    gates = [x for x in a.get("markers") or [] if x.get("kind") == k["GATE"]]
    ok = len(starts) == 1 and len(gates) >= 8
    return len(gates), ok, "%d START, %d gates (needs 1 and 8+)" % (len(starts), len(gates))
def m_race_drive(a, mode, ctx):
    r = ctx.get("drive")
    if r is None:
        r = ctx["drive"] = race_drive(a)
    if r is None:
        return None, False, "no road line to drive (arena['track'])"
    bad = [n for n, x in r["lines"].items() if x["laps"] != LAPS or x["flashes"] or x["back"]]
    return bad, not bad, "; ".join("%s %d/%d laps, %d WRONG WAY, %d taken back" % (
        n, x["laps"], LAPS, x["flashes"], x["back"]) for n, x in sorted(r["lines"].items()))
def m_gate_gap(a, mode, ctx):
    r = ctx.get("drive")
    if r is None:
        r = ctx["drive"] = race_drive(a)
    if r is None:
        return None, False, "no road line"
    return round(r["gap_max"]), r["gap_max"] <= GATE_GAP_MOST, \
        "gates at most %d apart (want %d)" % (r["gap_max"], GATE_GAP_MOST)
def m_line_keys(a, mode, ctx):
    ok = bool(_spots(a, "lineStart")) and bool(_spots(a, "lineFinish"))
    return ok, ok, "lineStart and lineFinish %s" % ("present" if ok else "missing")
def m_rlgl(a, mode, ctx):
    s, f = _spots(a, "lineStart"), _spots(a, "lineFinish")
    if not s or not f:
        return None, False, "no start or finish"
    starts = (a.get("spawns") or [])[:RLGL_START_ROW]
    def run_s(p):
        lane = dict(f[0], x=p["x"])
        across = max(0.0, abs(p["x"] - f[0]["x"]) - RLGL_RING)
        along = abs(f[0]["z"] - p["z"]) or 1.0
        return _route_s(a, p, lane, ctx) + (math.hypot(along, across) - along) / RUN
    times = [run_s(p) for p in starts]
    lo, hi = min(times), max(times)
    fair = (hi - lo) <= RLGL_FAIR * hi
    from . import critic
    grid = critic.HeightGrid(a)
    eye = (f[0]["x"], f[0]["y"] + 300, f[0]["z"])
    route = a.get("track", {}).get("loop") if isinstance(a.get("track"), dict) else None
    pts = [(p[0], p[1] + 120, p[2]) for p in route] if route else \
        [(p["x"], p["y"] + 120, p["z"]) for p in starts]
    seen = sum(1 for p in pts if critic.sees(grid, eye, p)) / float(max(1, len(pts)))
    ok = fair and seen >= RLGL_SEEN
    return [round(lo, 1), round(hi, 1), round(seen, 2)], ok, \
        "starts reach the finish in %.1f-%.1f s (fair within %d %%), the caller sees %d %% of " \
        "the route" % (lo, hi, 100 * RLGL_FAIR, 100 * seen)
def m_flood(a, mode, ctx):
    s, g = _spots(a, "floodStart"), _spots(a, "floodGoal")
    if not s or not g:
        return None, False, "no floodStart / floodGoal"
    s, g = s[0], g[0]
    dy = g["y"] - s["y"]
    if dy <= 0:
        return dy, False, "the goal is not above the start"
    route = a.get("routeTime") or _route_s(a, s, g, ctx)
    flat = _d(s, g)
    travel = (flat * 1.6 + dy * 2.5) / 600.0
    seconds = max(travel * FLOOD_SLACK + FLOOD_GRACE, (a.get("routeTime") or 0) * FLOOD_SLACK
                  + FLOOD_GRACE)
    ok = route * FLOOD_ROUTE_SHARE <= seconds
    return [round(route, 1), round(seconds, 1)], ok, \
        "a clean climb %.1f s, the water at the goal at %.1f s%s" % (
            route, seconds, "" if a.get("routeTime") else " (no routeTime published)")
def m_battle_arena(a, mode, ctx):
    pts = _spots(a, "points")
    nn = _nn(pts)
    lo = min(nn) if nn else 0
    ok = len(pts) >= 8 and lo >= 1500
    return [len(pts), round(lo)], ok, "%d battle points, %d apart (want 8+, 1500+)" % (len(pts), lo)
def _rules_for(mode):
    if mode in OWN_ROOM:
        return [Rule("venue_possible", m_own, BLOCK)]
    rules = [Rule("spawns", m_spawns, BLOCK, ">= 16")]
    if mode in FFA:
        rules += [Rule("ffa_points", m_ffa_points, BLOCK, ">= 16 points >= 800 apart"),
                  Rule("ffa_spread", m_ffa_spread, WARN, "median >= 2000")]
    if mode in ("ctf", "oneflag"):
        rules += [Rule("flags", m_ctf, BLOCK), Rule("flag_span", m_ctf_span, WARN),
                  Rule("flanks", m_flanks, WARN)]
    if mode == "domination":
        rules += [Rule("points_apart", m_domination, WARN, ">= 3000"),
                  Rule("points_room", m_domination_min, BLOCK, ">= 1500")]
    if mode == "koth":
        rules += [Rule("hill", m_koth, WARN)]
    if mode == "copsandrobbers":
        rules += [Rule("points", m_points(3), BLOCK), Rule("cell_central", m_cops_cell, WARN)]
    if mode == "snd":
        rules += [Rule("sd_keys", m_sd_keys, BLOCK), Rule("sd_times", m_sd_times, WARN)]
    if mode in RING_WIDEST:
        rules += [Rule("ring_fits", m_ring, WARN, "plate radius >= widest / 2 + 400"),
                  Rule("ring_room", m_ring_min, BLOCK, "plate radius >= widest / 4"),
                  Rule("centre", m_centre, BLOCK), Rule("ring_spawns", m_ring_spawns, WARN)]
        if mode in FLAT_PLATE:
            rules.append(Rule("flat_plate", m_flat_plate, BLOCK))
        if mode == "smash":
            rules.append(Rule("stage", m_smash_stage, WARN))
    if mode == "shellrace":
        rules += [Rule("track", m_marker_start, BLOCK), Rule("drive", m_race_drive, BLOCK),
                  Rule("gate_gap", m_gate_gap, WARN)]
    if mode == "shellbattle":
        rules += [Rule("arena", m_battle_arena, WARN)]
    if mode == "line":
        rules += [Rule("line_keys", m_line_keys, BLOCK), Rule("rlgl", m_rlgl, BLOCK)]
    if mode == "flood":
        rules += [Rule("flood_winnable", m_flood, BLOCK)]
    if mode in HIDE:
        rules += [Rule("spread", m_chase_spread, WARN)]
    if mode == "silverfive":
        rules += [Rule("points", m_points(5), BLOCK)]
    return rules
REQUIREMENTS = dict((k, _rules_for(k)) for k in ALL_MODES)
def map_modes(arena, brief=None):
    named = list((brief or {}).get("modes") or []) if brief is not None else []
    got = named or list(arena.get("onlyFor") or [])
    if not got and arena.get("family"):
        from . import modes as modesmod
        got = modesmod.keys_for(arena["family"])
    return [m for m in got if m in REQUIREMENTS]
def judge(arena, modes=None, brief=None):
    if modes is None:
        modes = map_modes(arena, brief)
    out = {"modes": list(modes), "blocking": {}, "warnings": {}}
    ctx = {}
    passes = 0
    for mode in modes:
        rows, blocks, warns = {}, [], []
        for rule in REQUIREMENTS.get(mode, ()):
            try:
                value, ok, note = rule.measure(arena, mode, ctx)
            except Exception as why:
                value, ok, note = None, rule.level != BLOCK, "not measured (%s)" % why
            rows[rule.name] = {"value": value, "ok": bool(ok), "level": rule.level,
                               "band": rule.band, "note": note}
            if not ok:
                (blocks if rule.level == BLOCK else warns).append("%s: %s" % (rule.name, note))
        out[mode] = {"pass": not blocks, "rows": rows, "blocks": blocks, "warns": warns}
        if blocks:
            out["blocking"][mode] = blocks
        else:
            passes += 1
        if warns:
            out["warnings"][mode] = warns
    out["share"] = passes / float(len(modes)) if modes else 1.0
    if "drive" in ctx and ctx["drive"] is not None:
        out["drive"] = ctx["drive"]
    return out
def summary(v):
    return {"modes": v["modes"], "share": round(v["share"], 3), "blocking": v["blocking"],
            "warnings": v["warnings"]}
def repair(arena, verdict, brief=None):
    notes = []
    named = set((brief or {}).get("modes") or []) if brief is not None else set()
    for mode, why in list(verdict["blocking"].items()):
        rows = verdict[mode]["rows"]
        if "ffa_points" in rows and not rows["ffa_points"]["ok"]:
            n = field_points(arena)
            if n:
                notes.append("%d free-for-all points spread over the floor (%s)" % (n, mode))
        if "points_room" in rows and not rows["points_room"]["ok"]:
            if domination_points(arena):
                notes.append("Domination's A, B, C spread between the bases")
        if "sd_keys" in rows and not rows["sd_keys"]["ok"]:
            if sd_spots(arena):
                notes.append("Search and Destroy's spawns and sites A, B placed")
        if "drive" in rows and not rows["drive"]["ok"] and isinstance(arena.get("track"), dict):
            if regate(arena):
                notes.append("race gates re-placed mid-straight with the road's own facing")
    for mode, why in list(verdict["warnings"].items()):
        rows = verdict[mode]["rows"]
        if "flanks" in rows and not rows["flanks"]["ok"] and brief is not None:
            if flank_zones(arena, brief):
                notes.append("flank zones laid for both teams (%s)" % mode)
        if "points_apart" in rows and not rows["points_apart"]["ok"]:
            if domination_points(arena):
                notes.append("Domination's A, B, C spread between the bases")
        if "ffa_spread" in rows and not rows["ffa_spread"]["ok"]:
            if field_points(arena):
                notes.append("free-for-all points spread over the floor (%s)" % mode)
        if "cell_central" in rows and not rows["cell_central"]["ok"]:
            if central_cell(arena):
                notes.append("Cops and Robbers' cell: the point nearest the middle")
    v2 = judge(arena, verdict["modes"], brief)
    for mode in v2["blocking"]:
        if mode in named:
            continue
        if mode in (arena.get("onlyFor") or []):
            arena["onlyFor"] = [x for x in arena["onlyFor"] if x != mode]
            notes.append("not offered to %s: %s" % (mode, v2["blocking"][mode][0]))
    return notes
def flank_zones(arena, brief):
    from . import teamzones
    f = brief.get("features") or {}
    b = dict((k, brief.get(k)) for k in ("symmetry", "size", "players", "theme", "seed",
                                           "verticality", "density", "pace"))
    b.update({"features": {"want": list(f.get("want") or []) + ["split_spawns"],
                           "avoid": [x for x in f.get("avoid") or [] if x != "split_spawns"]},
              "sides": "2", "family": "objective", "seed": brief.get("seed") or 0})
    b["symmetry"] = b.get("symmetry") or "mirror"
    try:
        teamzones.apply(arena, b)
    except Exception:
        return False
    return bool(_spots(arena, "flankRed")) and bool(_spots(arena, "flankBlue"))
def central_cell(arena):
    pts = _spots(arena, "points")
    if len(pts) < 2:
        return False
    cx = sum(p["x"] for p in pts) / float(len(pts))
    cz = sum(p["z"] for p in pts) / float(len(pts))
    k = min(range(len(pts)), key=lambda i: math.hypot(pts[i]["x"] - cx, pts[i]["z"] - cz))
    if k == 0:
        return False
    pts[0], pts[k] = pts[k], pts[0]
    arena["survey"]["points"] = pts
    return True
def _reached_cells(arena):
    m = _m()
    cells, edges = m.walk_graph(arena)
    sp = (arena.get("spawns") or [None])[0]
    if sp is None:
        return []
    first = m.spawn_cell(sp)
    if first not in cells:
        return []
    return [c for c in m.reach(edges, first) if c[0] > -1000000]
def _spot_of(c, yaw=0):
    m = _m()
    return {"x": c[0] * m.GRID + m.GRID // 2, "y": c[2], "z": c[1] * m.GRID + m.GRID // 2, "yaw": yaw}
def field_points(arena, n=24, gap=FFA_GAP_WANT):
    cells = _reached_cells(arena)
    if not cells:
        return 0
    cols = {}
    for c in cells:
        cols.setdefault((c[0], c[1]), []).append(c[2])
    ok = [c for c in cells if all(any(abs(h - c[2]) <= 24 for h in cols.get((c[0] + dx, c[1] + dz), ()))
                                  for dx, dz in ((2, 0), (-2, 0), (0, 2), (0, -2)))]
    ok.sort()
    if not ok:
        return 0
    sp = arena["spawns"]
    heads = sp[:2]
    chosen = [min(ok, key=lambda c: (c[0] * 100 - s["x"]) ** 2 + (c[1] * 100 - s["z"]) ** 2)
              for s in heads]
    best = dict((c, min(math.hypot((c[0] - h[0]) * 100, (c[1] - h[1]) * 100) for h in chosen))
                for c in ok if c not in chosen)
    while len(chosen) < n and best:
        c = max(sorted(best), key=lambda k: best[k])
        if best[c] < FFA_GAP_BLOCK:
            break
        chosen.append(c)
        del best[c]
        for k in best:
            best[k] = min(best[k], math.hypot((k[0] - c[0]) * 100, (k[1] - c[1]) * 100))
    cx = sum(c[0] for c in chosen) / float(len(chosen))
    cz = sum(c[1] for c in chosen) / float(len(chosen))
    pts = [_spot_of(c, int(round(math.degrees(math.atan2(cx - c[0], cz - c[1])))) % 360)
           for c in chosen]
    for k, s in enumerate(heads):
        pts[k] = {"x": s["x"], "y": s.get("y", pts[k]["y"]), "z": s["z"],
                  "yaw": s.get("yaw", pts[k]["yaw"])}
    if len(pts) < FFA_POINTS:
        return 0
    arena.setdefault("survey", {})["points"] = pts
    return len(pts)
def _nearest_cell(cells, x, z):
    return min(cells, key=lambda c: ((c[0] * 100 + 50 - x) ** 2 + (c[1] * 100 + 50 - z) ** 2, c))
def domination_points(arena):
    r, b = _spots(arena, "ctfRed"), _spots(arena, "ctfBlue")
    cells = _reached_cells(arena)
    if not r or not b or not cells:
        return False
    out = []
    D = _d(r[0], b[0]) or 1.0
    ux, uz = (b[0]["x"] - r[0]["x"]) / D, (b[0]["z"] - r[0]["z"]) / D
    side = math.sqrt(max(0.0, DOM_GAP ** 2 - (0.17 * D) ** 2)) + 200
    for f, lat in ((0.33, side), (0.5, 0.0), (0.67, -side)):
        x = r[0]["x"] + (b[0]["x"] - r[0]["x"]) * f + uz * lat
        z = r[0]["z"] + (b[0]["z"] - r[0]["z"]) * f - ux * lat
        out.append(_spot_of(_nearest_cell(cells, x, z)))
    now = _spots(arena, "points")[:3]
    was = min([_d(now[i], now[j]) for i in range(len(now)) for j in range(i + 1, len(now))]
              or [0])
    got = min(_d(out[i], out[j]) for i in range(3) for j in range(i + 1, 3))
    if got < DOM_GAP / 2 or got <= was:
        return False
    rest = [p for p in _spots(arena, "points")[3:]]
    arena.setdefault("survey", {})["points"] = out + rest
    return True
def sd_spots(arena):
    sp = arena.get("spawns") or []
    r, b = _spots(arena, "ctfRed"), _spots(arena, "ctfBlue")
    cells = _reached_cells(arena)
    if len(sp) < 16 or not r or not b or not cells:
        return False
    red = sorted(sp, key=lambda s: _d(s, r[0]))[:8]
    blue = sorted(sp, key=lambda s: _d(s, b[0]))[:8]
    if set(id(s) for s in red) & set(id(s) for s in blue):
        return False
    D, T = _centre(blue), _centre(red)
    L = _d(D, T) or 1.0
    ux, uz = (T["x"] - D["x"]) / L, (T["z"] - D["z"]) / L
    fwd = min(2500.0, max(1500.0, 0.3 * L))
    side = min(3000.0, 0.35 * L)
    sites = []
    for s_ in (1, -1):
        x = D["x"] + ux * fwd + uz * side * s_
        z = D["z"] + uz * fwd - ux * side * s_
        sites.append(_spot_of(_nearest_cell(cells, x, z)))
    sv = arena.setdefault("survey", {})
    sv["sdDefend"] = [dict(s) for s in blue]
    sv["sdAttack"] = [dict(s) for s in red]
    sv["sdSiteA"], sv["sdSiteB"] = sites[0], sites[1]
    return True
GATE_BELOW, GATE_ABOVE, GATE_BAND = 300, 1500, 600
GATE_FEEL_STEP, GATE_FEEL_MOST, GATE_EDGE = 100, 4000, 150
GATE_SHIFT_MOST, GATE_WIDEN_MOST = 300, 2.5
BACK_FRAMES, BACK_DEPTH = 20, 250
WRONG_AFTER, WRONG_OFF = 60, 120.0
FRAME = SHELL / 30.0
EDGE_IN = 250
def gates_of(arena, fl):
    k = _m().KIND
    raw = sorted([x for x in arena.get("markers") or [] if x.get("kind") == k["GATE"]],
                 key=lambda x: x["num"])
    n = len(raw)
    out = []
    for i, g in enumerate(raw):
        b, c = raw[(i - 1) % n], raw[(i + 1) % n]
        dx, dz = c["x"] - b["x"], c["z"] - b["z"]
        L = math.hypot(dx, dz) or 1.0
        nx, nz = dx / L, dz / L
        own = (g.get("b") or 0) & 2
        if own or (g.get("yaw") or 0) % 360:
            ox, oz = math.sin(math.radians(g.get("yaw") or 0)), math.cos(math.radians(g.get("yaw") or 0))
            if ox * nx + oz * nz < 0 and not own:
                ox, oz = -ox, -oz
            nx, nz = ox, oz
        out.append({"x": float(g["x"]), "y": float(g["y"]), "z": float(g["z"]), "nx": nx, "nz": nz,
                    "w": float((g.get("a") or 16) * 100), "num": g["num"]})
    for g in out:
        if fl.near(g["x"], g["y"], g["z"]) is None:
            continue
        reach = {}
        for side in (1, -1):
            sx, sz = g["nz"] * side, -g["nx"] * side
            r = 0
            for d in range(GATE_FEEL_STEP, GATE_FEEL_MOST + 1, GATE_FEEL_STEP):
                y = fl.near(g["x"] + sx * d, g["y"], g["z"] + sz * d, GATE_BELOW, GATE_BELOW)
                if y is None:
                    break
                r = d
            reach[side] = r
        span = reach[1] + reach[-1] + 2 * GATE_EDGE
        if span > g["w"]:
            shift = max(-GATE_SHIFT_MOST, min(GATE_SHIFT_MOST, (reach[1] - reach[-1]) / 2.0))
            g["x"] += g["nz"] * shift
            g["z"] -= g["nx"] * shift
            g["w"] = min(span, g["w"] * GATE_WIDEN_MOST)
    return out
def crossed(g, p, q, forwards):
    before = (p[0] - g["x"]) * g["nx"] + (p[2] - g["z"]) * g["nz"]
    after = (q[0] - g["x"]) * g["nx"] + (q[2] - g["z"]) * g["nz"]
    if abs(before) > GATE_BAND or abs(after) > GATE_BAND:
        return False
    if forwards:
        if not (before < 0 <= after):
            return False
    elif not (before >= 0 > after):
        return False
    share = before / (before - after) if before != after else 0.0
    cx = p[0] + (q[0] - p[0]) * share
    cy = p[1] + (q[1] - p[1]) * share
    cz = p[2] + (q[2] - p[2]) * share
    side = (cx - g["x"]) * g["nz"] - (cz - g["z"]) * g["nx"]
    if abs(side) > g["w"] * 0.5:
        return False
    return -GATE_BELOW <= cy - g["y"] <= GATE_ABOVE
def road_dir(G, done, x, z):
    n = len(G)
    nxt = G[done % n]
    if done <= 0:
        return nxt["nx"], nxt["nz"]
    last = G[(done - 1) % n]
    past = (x - last["x"]) * last["nx"] + (z - last["z"]) * last["nz"]
    ahead = (nxt["x"] - x) * nxt["nx"] + (nxt["z"] - z) * nxt["nz"]
    k = 0.5
    if past + ahead > 1:
        k = max(0.0, min(1.0, past / (past + ahead)))
    rx = last["nx"] * (1 - k) + nxt["nx"] * k
    rz = last["nz"] * (1 - k) + nxt["nz"] * k
    L = math.hypot(rx, rz)
    return (rx / L, rz / L) if L > 1e-3 else (0.0, 1.0)
def drive(G, path):
    n = len(G)
    done, back_frames, back, wrong, flashes = 0, 0, 0, 0, 0
    for i in range(1, len(path)):
        p, q = path[i - 1], path[i]
        nxt = G[done % n]
        aft = G[(done + 1) % n] if n >= 3 else None
        steps = 0
        if crossed(nxt, p, q, True):
            steps = 1
        elif aft is not None and done > 0 and crossed(aft, p, q, True):
            steps = 2
        if steps:
            back_frames = 0
            done += steps
        elif done > 0:
            last = G[(done - 1) % n]
            if back_frames == 0:
                if crossed(last, p, q, False):
                    back_frames = 1
            else:
                depth = (q[0] - last["x"]) * last["nx"] + (q[2] - last["z"]) * last["nz"]
                side = (q[0] - last["x"]) * last["nz"] - (q[2] - last["z"]) * last["nx"]
                if depth >= 0 or abs(side) > last["w"] * 0.5 or depth < -GATE_BAND:
                    back_frames = 0
                else:
                    back_frames += 1
                    if back_frames >= BACK_FRAMES and depth <= -BACK_DEPTH:
                        back_frames = 0
                        done -= 1
                        back += 1
        vx, vz = q[0] - p[0], q[2] - p[2]
        if vx * vx + vz * vz <= 1:
            wrong = max(0, wrong - 2)
            continue
        rx, rz = road_dir(G, done, q[0], q[2])
        diff = abs((math.degrees(math.atan2(vx, vz) - math.atan2(rx, rz)) + 180) % 360 - 180)
        before = wrong
        wrong = wrong + 1 if diff > WRONG_OFF else max(0, wrong - 2)
        if before < WRONG_AFTER <= wrong:
            flashes += 1
    laps = max(0, (done - 1) // n) if done else 0
    return {"done": done, "laps": laps, "flashes": flashes, "back": back}
def _offset(line, off):
    n = len(line)
    out = []
    for i in range(n):
        a, b, c = line[i - 1], line[i], line[(i + 1) % n]
        def unit(dx, dz):
            L = math.hypot(dx, dz) or 1.0
            return dx / L, dz / L
        u1 = unit(b[0] - a[0], b[2] - a[2])
        u2 = unit(c[0] - b[0], c[2] - b[2])
        l1, l2 = (-u1[1], u1[0]), (-u2[1], u2[0])
        mx, mz = l1[0] + l2[0], l1[1] + l2[1]
        dot = l1[0] * l2[0] + l1[1] * l2[1]
        k = off / (1.0 + dot) if 1.0 + dot > 1e-6 else off
        out.append((b[0] + mx * k, b[1], b[2] + mz * k))
    return out
def _path(line, fl, closed=True):
    out = []
    n = len(line)
    for i in range(n if closed else n - 1):
        a, b = line[i], line[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[2] - a[2])
        k = max(1, int(L / FRAME))
        for j in range(k):
            t = j / float(k)
            x, z = a[0] + (b[0] - a[0]) * t, a[2] + (b[2] - a[2]) * t
            y0 = a[1] + (b[1] - a[1]) * t
            ts = fl.tops(x, z)
            y = min(ts, key=lambda v: abs(v - y0)) if ts else y0
            if abs(y - y0) > 600:
                y = y0
            out.append((x, y, z))
    return out
def race_drive(arena):
    tr = arena.get("track")
    if not isinstance(tr, dict) or not tr.get("loop"):
        return None
    fl = Floor(arena.get("pieces") or [])
    G = gates_of(arena, fl)
    if len(G) < 3:
        return None
    loop = [tuple(p) for p in tr["loop"]]
    W = tr.get("width") or 2000
    lines = {"centre": loop, "left": _offset(loop, W / 2.0 - EDGE_IN),
             "right": _offset(loop, -(W / 2.0 - EDGE_IN))}
    for i, sc in enumerate(tr.get("shortcuts") or ()):
        lines["shortcut%d" % (i + 1)] = [tuple(p) for p in sc]
    out = {}
    for name, line in lines.items():
        path = _path(line, fl)
        full = path * LAPS + path[:max(2, len(path) // 20)]
        out[name] = drive(G, full)
    plan = tr.get("gates") or []
    skip = set(i for i, g in enumerate(plan) if g.get("after_skip")) if len(plan) == len(G) else set()
    gaps = [math.hypot(G[i]["x"] - G[i - 1]["x"], G[i]["z"] - G[i - 1]["z"])
            for i in range(len(G)) if i not in skip] or [0.0]
    rev = drive(G, (_path(loop, fl) * 2)[::-1])
    return {"lines": out, "gap_max": max(gaps), "gates": len(G), "backwards_laps": rev["laps"]}
def regate(arena):
    tr = arena.get("track") or {}
    plan = tr.get("gates")
    if not plan:
        return False
    k = _m().KIND
    keep = [x for x in arena.get("markers") or [] if x.get("kind") != k["GATE"]]
    gates = []
    for i, g in enumerate(plan):
        gates.append({"kind": k["GATE"], "num": i, "a": int(g.get("a", (tr.get("width") or 2000) // 100 + 3)),
                      "b": 2, "x": int(round(g["x"])), "y": int(round(g["y"])), "z": int(round(g["z"])),
                      "yaw": int(round(g["yaw"])) % 360, "label": "G%02d" % i})
    arena["markers"] = keep + gates
    return True
