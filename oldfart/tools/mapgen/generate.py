import json
import time
from . import checks, fit as fitmod, score as scoring, solids
from . import families
from .rng import Streams
GENERATOR_VERSION = "mapgen 2"
FAMILIES = families.REGISTRY
class NotBuilt(ValueError):
    pass
class Candidate:
    def __init__(self, index, arena, meta, result, score, repairs, seconds):
        self.index = index
        self.arena = arena
        self.meta = meta
        self.checks = result
        self.score = score
        self.repairs = repairs
        self.seconds = seconds
    @property
    def ok(self):
        return self.checks.ok
    @property
    def quality(self):
        return self.score["quality"] if self.score else None
    def summary(self):
        p = self.meta.get("params") or {}
        style = self.meta.get("style") or {}
        across = p.get("across")
        if across is None and all(k in p for k in ("I", "G", "B")):
            across = 2 * (p["I"] + p["G"] + p["B"])
        shape = (p.get("skeleton") or p.get("shape") or self.meta.get("skeleton")
                 or describe(self.meta))
        out = {"candidate": self.index, "ok": self.ok, "quality": self.quality,
               "family": self.arena.get("family"), "pieces": len(self.arena["pieces"]),
               "skeleton": shape, "shape": shape, "across": across,
               "about": style.get("about"), "faults": self.checks.faults[:3],
               "repairs": self.repairs, "seconds": round(self.seconds, 2)}
        for k in ("centre", "lane", "corner"):
            out[k] = p.get(k, "-")
        return out
def describe(meta):
    mods = meta.get("modules") or {}
    words = []
    for k in sorted(mods):
        v = mods[k]
        if isinstance(v, (str, int, float, bool)) and len(words) < 3:
            words.append("%s %s" % (k, v))
    return ", ".join(words) or "-"
class Result:
    def __init__(self, brief, candidates, best):
        self.brief = brief
        self.candidates = candidates
        self.best = best
    def layout(self):
        a = dict(self.best.arena)
        a["pieces"] = [dict(p) for p in a["pieces"]]
        a["generator"] = {"version": GENERATOR_VERSION, "seed": self.brief["seed"],
                          "candidate": self.best.index, "family": self.brief["family"],
                          "modules": self.best.meta.get("modules", {}),
                          "params": self.best.meta.get("params", {}),
                          "quality": self.best.quality,
                          "score_source": self.best.score["source"] if self.best.score else None}
        return a
def _checked(arena, reference):
    if not reference:
        from . import boundary
        boundary.snap_seams(arena["pieces"])
    return checks.run(arena, solids=not reference)
def build_candidate(brief, index, use_metrics=True, force=None):
    family = families.get(brief["family"])
    t = time.time()
    streams = Streams(brief["seed"], index, brief["reseed"], force=force)
    reference = brief["reference"] == "skykeep" and index == 0
    arena, meta = family.build(brief, streams, reference=reference)
    meta["reference"] = reference
    arena["family"] = brief["family"]
    if brief["name"]:
        arena["name"] = brief["name"]
    meta["streams"] = sorted(set(streams.used))
    raw = meta.pop("raw_pieces", None) or [dict(p) for p in arena["pieces"]]
    if not reference:
        from . import gameplay
        keep = set(id(p) for p in arena["pieces"])
        meta["gameplay"] = gameplay.run(arena, brief, streams, meta)
        if any(id(p) not in keep for p in arena["pieces"]) or len(keep) != len(arena["pieces"]):
            raw = [dict(p) for p in arena["pieces"]]
        from . import scenery
        masses, why = scenery.tiles_backdrop(arena, brief, streams("tiles backdrop"))
        if masses:
            arena["pieces"] = arena["pieces"] + masses
            raw = raw + [dict(p) for p in masses]
            meta["beauty"] = meta.get("beauty") or {}
            meta["beauty"].setdefault("rules", {})["C3 backdrop"] = len(masses)
            meta.setdefault("notes", []).append(
                "C3 backdrop on The Tiles: %d masses beyond the invisible edge" % len(masses))
        elif why and "backdrop" in ((brief.get("features") or {}).get("want") or ()):
            meta.setdefault("notes", []).append("C3 backdrop: not built - %s" % why)
        scenery.void_rocks(arena["pieces"], arena.get("level"))
        scenery.void_rocks(raw, arena.get("level"))
        from . import surround
        isles, inotes = surround.dress(arena, brief, streams("surround"))
        if isles:
            arena["pieces"] = arena["pieces"] + isles
            raw = raw + [dict(p) for p in isles]
            meta["beauty"] = meta.get("beauty") or {}
            meta["beauty"].setdefault("rules", {})["C3 diorama"] = len(isles)
        meta.setdefault("notes", []).extend(inotes)
        from . import scatter
        if brief["family"] in scatter.FAMILIES:
            from . import setpieces
            spare = _room_left(arena, brief)
            wished = _room_left(arena, brief, wished=True)
            sp, so, snotes, gone = setpieces.run(arena, brief, spare - int(0.04 * spare),
                                                 streams("set pieces"),
                                                 wished_room=wished - int(0.04 * wished))
            if gone:
                ids = set(id(p) for p in gone)
                keys = set((p["x"], p["y"], p["z"], p["w"], p["h"], p["d"]) for p in gone)
                arena["pieces"] = [p for p in arena["pieces"] if id(p) not in ids]
                raw = [p for p in raw if (p["x"], p["y"], p["z"], p["w"], p["h"], p["d"])
                       not in keys]
            if sp:
                sp, so, left = reserve_setpieces(arena["pieces"], sp, so)
                for kind_ in left:
                    snotes.append("set piece %s: left out - it would share space with "
                                  "what stands there" % kind_)
            if sp or so:
                arena["pieces"] = arena["pieces"] + sp
                raw = raw + [dict(p) for p in sp]
                arena["objects"] = list(arena.get("objects") or []) + so
            meta.setdefault("notes", []).extend(snotes)
            meta.setdefault("not_possible", []).extend(set_piece_reasons(brief, snotes)
                                                       + said_late(arena, brief))
            from . import regions as regionsmod
            rp, rg, rnotes = regionsmod.build(
                arena, brief, _room_left(arena, brief),
                streams("regions"))
            if rp:
                rp = reserve_runs(arena["pieces"], rp, lambda p_, q_: str(
                    q_.get("tag", "")).endswith("cairn") and not str(p_.get("tag", "")).endswith(
                    "cairn"))
            if rp:
                arena["pieces"] = arena["pieces"] + rp
                raw = raw + [dict(p) for p in rp]
            if rg:
                arena["regions"] = rg
            meta.setdefault("notes", []).extend(rnotes)
            room = scatter.room_of(arena, brief)
            props, srep = scatter.run(arena, brief, room)
            if props:
                arena["pieces"] = arena["pieces"] + props
                raw = raw + [dict(p) for p in props]
                meta.setdefault("notes", []).append(scatter.say(srep))
            meta["scatter"] = srep
    if not reference and isinstance(arena.get("gu4"), dict):
        from . import decor
        d = decor.dressing_checks(arena, "hide" if brief["family"] == "hide" else "explore")
        arena["gu4"]["dressing"] = {k: list(v) for k, v in d.items()}
    def painted(pieces):
        if reference:
            return pieces
        out, notes = solids.resolve(pieces)
        from . import boundary as _boundary
        out = _boundary.rejoin(out)
        if out is not pieces:
            from . import guards
            meta["cuts"] = guards.function_cuts(pieces, out)
        from . import kit as _kit
        _kit.surfaces(out)
        for n in notes:
            if n not in meta.setdefault("notes", []):
                meta["notes"].append(n)
        return out
    if "budget" in brief.defaulted and not reference:
        from . import budget as budgetmod
        used = _objects_used(arena)
        top = budgetmod.ceiling(brief["family"], brief["modes"] or arena.get("onlyFor") or ())
        if arena.get("budget", 0) < used <= top:
            arena["budget"] = used
        elif arena.get("budget", 0) < used and brief["family"] in budgetmod.BAKED_TIER_FAMILIES:
            runtime = used - len(arena["pieces"])
            if runtime <= top and len(arena["pieces"]) <= budgetmod.BAKED_PIECE_MAX:
                arena["budget"] = used
    if not reference and arena.get("objects"):
        from . import cannons as cannonmod
        if cannonmod.cannons(arena):
            had = set(_key(p) for p in arena["pieces"])
            left = cannonmod.clear_cones(arena)
            for o in list(cannonmod.cannons(arena)):
                why = None
                if id(o) in left:
                    why = "%s over its firing cone" % str(left[id(o)][0].get("tag")
                                                          or left[id(o)][0].get("kind"))
                elif not cannonmod.reachable(arena, o):
                    why = "no way a player walks to it"
                if why:
                    _gone, stars = cannonmod.drop(arena, o)
                    meta.setdefault("notes", []).append(
                        "cannon at (%d, %d) given up: %s%s" % (
                            o["x"], o["z"], why, " (its island's star with it)" if stars else ""))
            now = set(_key(p) for p in arena["pieces"])
            if now != had:
                raw = [p for p in raw if _key(p) in now]
    result = _checked(arena, reference)
    repairs = []
    def strip_detail():
        nonlocal raw, result
        if reference or not (meta.get("detail") or {}).get("pieces") \
                or meta["detail"].get("removed"):
            return
        from . import detail
        bare = detail.strip(raw)
        if len(bare) == len(raw) and not any("detail_was" in p for p in raw):
            return
        raw = bare
        arena["pieces"] = painted(raw)
        repairs.append("removed the detail pass (%d pieces)" % meta["detail"]["pieces"])
        meta["detail"]["removed"] = True
        result = _checked(arena, reference)
    if not result.ok and not reference and any("solids must never share space" in f
                                               for f in result.faults):
        props = sharing_props(arena["pieces"])
        if props:
            raw = [p for p in raw if _key(p) not in props]
            arena["pieces"] = [p for p in arena["pieces"] if _key(p) not in props]
            repairs.append("removed %d props that shared space" % len(props))
            result = _checked(arena, reference)
    if not result.ok and any("objects against a budget" in f for f in result.faults) \
            and not reference:
        over = _objects_used(arena) - arena.get("budget", 0)
        cover = [i for i, p in enumerate(raw) if str(p.get("tag", "")).startswith("scatter.")]
        if 0 < over and cover:
            n = min(len(cover), over + 4)
            step = len(cover) / float(n)
            cut = set(cover[int(k * step)] for k in range(n))
            raw = [p for i, p in enumerate(raw) if i not in cut]
            arena["pieces"] = painted(raw)
            repairs.append("left out %d scatter pieces (over the budget)" % len(cut))
            result = _checked(arena, reference)
    if not result.ok and any("objects against a budget" in f for f in result.faults):
        strip_detail()
    if not result.ok and not reference and result.graph is not None and any(
            "one-way trip" in f for f in result.faults):
        from . import playable as _playable
        from . import basins as _basins
        fills = _playable.fill_pits(arena, result.graph,
                                    _basins.mound_texture(arena) or "grass")
        if fills:
            raw = raw + fills
            arena["pieces"] = painted(raw)
            repairs.append("filled %d pit cells' worth of ground (%d boxes): a one-way pit"
                           % (sum(int(p["w"] * p["d"] // 10000) for p in fills), len(fills)))
            result = _checked(arena, reference)
    if not result.ok:
        dress = [p for p in raw if str(p.get("tag", "")).startswith("dress.")
                 and p.get("tag") != "dress.parapet"]
        if dress:
            raw = [p for p in raw if p not in dress]
            arena["pieces"] = painted(raw)
            repairs.append("removed %d dress pieces" % len(dress))
            result = _checked(arena, reference)
    if not result.ok:
        fill = [p for p in raw if str(p.get("tag", "")).startswith("fill.")]
        if fill:
            raw = [p for p in raw if p not in fill]
            arena["pieces"] = painted(raw)
            repairs.append("removed %d cover pieces" % len(fill))
            result = _checked(arena, reference)
        if not result.ok:
            from . import detail as _detail
            if _detail.implicated(result.faults, arena["pieces"]):
                strip_detail()
        if not result.ok and len(arena["survey"].get("points", [])) > 16:
            arena["survey"]["points"] = arena["survey"]["points"][:16]
            repairs.append("dropped the field spawns")
            result = _checked(arena, reference)
    if not result.ok and not reference and any("objects against a budget" in f
                                               for f in result.faults):
        n = repair_budget(arena, raw, painted)
        if n:
            raw = n[1]
            repairs.append("budget: %s" % n[0])
            result = _checked(arena, reference)
    if not reference and result.ok:
        result, raw = rules_gate(brief, arena, meta, result, raw, painted, repairs)
    def stars_reached():
        if not (result.ok and arena.get("stars")):
            return
        from . import gameplay
        moved = gameplay.move_unreached(arena, result.graph)
        if moved:
            meta.setdefault("notes", []).extend(moved)
        bad = gameplay.check_stars(arena, result.graph)
        if bad:
            ids = set(int(f.split()[2]) for f in bad)
            arena["stars"] = [st for st in arena["stars"] if st["id"] not in ids]
            meta.setdefault("not_possible", []).extend(bad)
            if arena.get("gameplay"):
                arena["gameplay"]["unreached"] = len(ids)
    def fix_spawns():
        nonlocal result
        if result.ok or reference or not all(SPAWN_UNWALKED in f for f in result.faults):
            return
        moved = move_spawns(arena, result.graph)
        if moved:
            repairs.append("moved %d spawn(s) onto walked ground" % moved)
            result = _checked(arena, reference)
    fix_spawns()
    stars_reached()
    if not result.ok and not reference and any("-high slot under" in f
                                               for f in result.faults):
        for _ in range(12):
            pair = slot_pairs(arena)
            if not pair:
                break
            gone = drop_smaller(arena, pair[0])
            if gone is None:
                break
            raw = [p for p in raw if not _same_piece(p, gone)]
            repairs.append("removed %s %s at (%d, %d, %d): it closed a crawl slot"
                           % (gone["kind"], gone["tex"], gone["x"], gone["y"], gone["z"]))
        result = _checked(arena, reference)
        fix_spawns()
        if not reference and result.ok and meta.get("guards") is None:
            result, raw = rules_gate(brief, arena, meta, result, raw, painted, repairs)
        stars_reached()
    from . import budget as _budget
    pics = len(_budget.drawn(arena["pieces"])[0])
    line = _budget.pictures_line(pics)
    if line:
        meta.setdefault("notes", []).append(line)
    arena["report"] = generator_report(brief, meta, repairs, index)
    if not reference:
        from . import escape
        arena["report"]["escapes"] = escape.escape_faults(arena) + escape.hiding_faults(arena)
    if meta.get("guards") is not None:
        arena["report"]["guards"] = meta["guards"]
    if meta.get("detail") is not None:
        arena["report"]["detail"] = meta["detail"]
    if meta.get("coin_star") is not None:
        cs = dict(meta["coin_star"])
        cs["on"] = bool(arena.get("coinStar")) and bool(arena.get("stars"))
        arena["report"]["coin_star"] = cs
    if meta.get("land") is not None:
        from . import landscape
        ld = meta["land"]
        arena["report"]["land"] = dict(landscape.composition(
            arena, ld.get("biome_shares"), ld.get("species"), ld.get("landforms")),
            preset=ld.get("preset"), bands=ld.get("bands"))
    if meta.get("gameplay") is not None:
        arena["report"]["gameplay"] = [{"status": st, "id": i, "note": n}
                                       for st, i, n in meta["gameplay"]]
    sc = None
    if result.ok and result.graph is not None:
        sc = scoring.score(arena, result.graph, meta, brief, use_metrics)
        if sc and isinstance(sc.get("metrics"), dict) and "beauty" in sc["metrics"]:
            arena["report"]["beauty_score"] = sc["metrics"]["beauty"]
    return Candidate(index, arena, meta, result, sc, repairs, time.time() - t)
YIELDS = ("tree", "fill", "crate", "block", "breaker", "hedge", "garden", "dress", "prop",
          "decor", "flower", "bush", "rock", "pickup", "cover", "maze", "ruin", "bend",
          "low wall", "side wall")
LEDGE_OK = ("slope", "hills", "terrace", "perch", "flank", "lane", "ramp")
def _yields(p):
    t = str(p.get("tag", "")).lower()
    return any(t.startswith(w) or ("." + w) in t or (" " + w) in t for w in YIELDS)
def _overlaps_rect(p, rect, y0, y1):
    from . import v1
    x0, x1, z0, z1, _ = v1.arenas_module().footprint(p)
    return x0 < rect[1] and rect[0] < x1 and z0 < rect[3] and rect[2] < z1 \
        and p["y"] < y1 and p["y"] + p["h"] > y0
def rules_gate(brief, arena, meta, result, raw, painted, repairs):
    from . import contract, guards
    theme = contract.theme_for(brief)
    fam = brief.get("family")
    def gate():
        return guards.gate(arena, theme, graph=result.graph, cuts=meta.get("cuts"), family=fam,
                           raw=raw)
    def recheck(new_raw, label):
        nonlocal raw, result
        before = arena["pieces"]
        arena["pieces"] = painted(new_raw)
        r2 = checks.run(arena, solids=True)
        if not r2.ok:
            arena["pieces"] = before
            return False
        raw, result = new_raw, r2
        repairs.append(label)
        return True
    g = gate()
    done = {}
    if g["counts"].get("contract_refused"):
        n = contract.repair(raw, theme)
        contract.repair(arena["pieces"], theme)
        if n:
            repairs.append("contract: %d pieces repainted in their class's material" % n)
            done["contract"] = n
        g = gate()
    hard = [f for f in g["flights"] if f["rule"] in guards.hard_rules(f["piece"], fam)]
    if hard:
        add = guards.cheeks(arena, [f for f in hard if f["rule"] == "ST6"])
        if add and recheck(raw + add, "stairs: %d cheeks on open flight sides" % len(add)):
            done["cheeks"] = len(add)
        g = gate()
        hard = [f for f in g["flights"] if f["rule"] in guards.hard_rules(f["piece"], fam)]
    if hard:
        gone = []
        for f in hard:
            b = f.get("blocker")
            if b is None or not _yields(b):
                continue
            from . import v1
            x0, x1, z0, z1, _ = v1.arenas_module().footprint(b)
            gone += [p for p in raw if _yields(p) and p not in gone and
                     _overlaps_rect(p, (x0, x1, z0, z1), b["y"], b["y"] + b["h"])]
        if gone and recheck([p for p in raw if p not in gone],
                            "stairs: %d blocking pieces opened at a flight's end" % len(gone)):
            done["opened"] = len(gone)
        g = gate()
        hard = [f for f in g["flights"] if f["rule"] in guards.hard_rules(f["piece"], fam)]
    if hard:
        drop = []
        for f in hard:
            p = f["piece"]
            tag = str(p.get("tag", "")).lower()
            if p["h"] <= movement_rise() and any(w in tag for w in LEDGE_OK):
                drop.append(p)
        if drop:
            keys = set(_key(p) for p in drop)
            new = [p for p in raw if _key(p) not in keys]
            if len(new) < len(raw) and recheck(new, "stairs: %d failing flights made ledges"
                                                     % (len(raw) - len(new))):
                done["ledges"] = len(raw) - len(new)
        g = gate()
    if g["counts"].get("cuts"):
        gone = []
        for p, c in meta.get("cuts") or []:
            if c <= guards.CUT_MAX:
                continue
            from . import v1
            x0, x1, z0, z1, _ = v1.arenas_module().footprint(p)
            gone += [q for q in raw if _yields(q) and q not in gone and
                     _overlaps_rect(q, (x0, x1, z0, z1), p["y"], p["y"] + p["h"])]
        if gone and recheck([p for p in raw if p not in gone],
                            "cuts: %d pieces made way for a stair, door or bridge" % len(gone)):
            done["cut_room"] = len(gone)
        g = gate()
    if g["counts"].get("joins"):
        new, n = guards.join_pillars(arena, raw)
        if n and recheck(new, "joins: %d pillars cut into one-cell pieces that meet their walls"
                         % n):
            done["joins"] = n
        g = gate()
    if g["counts"].get("floating"):
        fl = guards.floating(arena)
        keys = set(_key(p) for grp in fl for p in grp if _yields(p) or guards._detail(p))
        new = [p for p in raw if _key(p) not in keys]
        if keys and len(new) < len(raw) and recheck(new, "support: %d floating pieces taken off"
                                                         % (len(raw) - len(new))):
            done["floating"] = len(raw) - len(new)
        g = gate()
    if g["counts"].get("movers"):
        bad = sorted(set(i for i, _ in guards.mover_faults(arena)))
        mv = arena.get("movers") or []
        drop = [i for i in bad if mv[i].get("pattern") in ("log_gauntlet", "pool_ferry")]
        if drop:
            arena["movers"] = [x for k, x in enumerate(mv) if k not in drop]
            repairs.append("movers: %d sweeping through another mover or a piece taken off"
                           % len(drop))
            done["movers"] = len(drop)
        g = gate()
    from . import hostpatterns
    if hostpatterns.ACTIVE:
        texts, gone = hostpatterns.faults(arena)
        if gone:
            keys = set(_key(p) for p in gone)
            new = [p for p in raw if _key(p) not in keys]
            if len(new) < len(raw) and recheck(new, "host never: %d pieces taken out"
                                                    % (len(raw) - len(new))):
                done["host_never"] = len(raw) - len(new)
            texts, gone = hostpatterns.faults(arena)
        g["counts"]["host_never"] = len(texts)
        g["counts"]["host_like"] = hostpatterns.likes(arena)
        g["faults"] = list(g["faults"]) + texts
    if g["faults"]:
        named = []
        for f in g["flights"]:
            if f["rule"] in guards.hard_rules(f["piece"], fam):
                named.append(f["piece"])
        if g["counts"].get("floating"):
            named += [p for grp in guards.floating(arena) for p in grp]
        kinds = set(_setpiece_of(p) for p in named) - {None}
        if kinds:
            wells = _well_owners(raw, arena.get("objects"))
            new = [p for p in raw if _setpiece_of(p) not in kinds
                   and wells.get(id(p)) not in kinds]
            if len(new) < len(raw) and recheck(new, "set pieces: %s left out (the rules refused "
                                                    "them)" % ", ".join(sorted(kinds))):
                done["setpieces"] = sorted(kinds)
                pat = tuple(sorted(kinds))
                arena["objects"] = [o for o in arena.get("objects") or []
                                    if not str(o.get("pattern", "")).startswith(pat)]
                g = gate()
    meta["guards"] = {"counts": g["counts"], "repaired": done, "warns": g["warns"][:12]}
    if g["faults"]:
        result = checks.Result(list(result.faults) + g["faults"], result.graph)
    return result, raw
def _key(p):
    return tuple(p.get(k) for k in ("kind", "x", "y", "z", "w", "h", "d", "yaw")) + (
        str(p.get("tex")),)
def movement_rise():
    from . import movement
    return movement.RISES["easy"]
SHARING_YIELDS = ("climb.vine",)
def _yields_space(p):
    return bool(p.get("decor")) or str(p.get("tag", "")) in SHARING_YIELDS
def sharing_props(pieces):
    out = set()
    for i, j, _, _ in solids.overlaps(pieces):
        for k, o in ((i, j), (j, i)):
            p = pieces[k]
            if _yields_space(p) and (not _yields_space(pieces[o]) or k > o):
                out.add(_key(p))
    return out
def _setpiece_of(p):
    tag = str(p.get("tag", "")).split(" ")[0]
    if not tag.startswith("setpiece."):
        return None
    return ".".join(tag.split(".")[:2])
WELL_NEAR = 1000
def _well_owners(pieces, objects):
    cannons = [(o["x"], o["z"], ".".join(str(o.get("pattern", "")).split(".")[:2]))
               for o in objects or [] if str(o.get("key", "")).startswith("cannon")
               and str(o.get("pattern", "")).startswith("setpiece.")]
    out = {}
    if not cannons:
        return out
    for p in pieces:
        if not str(p.get("tag", "")).startswith("play.cannon"):
            continue
        for x, z, kind in cannons:
            if abs(p["x"] - x) <= WELL_NEAR and abs(p["z"] - z) <= WELL_NEAR:
                out[id(p)] = kind
                break
    return out
def reserve_runs(standing, pieces, starts):
    runs, cur, prev = [], [], None
    for p in pieces:
        if cur and starts(prev, p):
            runs.append(cur)
            cur = []
        cur.append(p)
        prev = p
    if cur:
        runs.append(cur)
    kept = []
    for run in runs:
        sp, _, left = reserve_setpieces(list(standing) + kept, [dict(p, tag="setpiece.run")
                                                                for p in run], [])
        if not left:
            kept += run
    return kept
def reserve_setpieces(standing, sp, so):
    groups = {}
    owner = _well_owners(sp, so)
    for p in sp:
        key = owner.get(id(p)) or ".".join(str(p.get("tag", "")).split(" ")[0].split(".")[:2])
        groups.setdefault(key, []).append(p)
    from . import cells as _cells
    rects = [(_cells.piece_rect(q), q) for q in standing
             if not (q.get("decor") and q.get("pass")) and q.get("kind") != "water"]
    left = []
    for key, ps in sorted(groups.items()):
        bad = bool(solids.overlaps([p for p in ps if not (p.get("decor") and p.get("pass"))]))
        for p in ([] if bad else ps):
            if p.get("decor") and p.get("pass"):
                continue
            r = _cells.piece_rect(p)
            for rq, q in rects:
                if rq[0] >= r[1] - 1 or r[0] >= rq[1] - 1 or rq[2] >= r[3] - 1 \
                        or r[2] >= rq[3] - 1:
                    continue
                if solids.overlap_depth(p, q, r, rq)[1]:
                    bad = True
                    break
            if bad:
                break
        if bad:
            left.append(key)
    if not left:
        return sp, so, []
    gone = set(left)
    keep = [p for p in sp if (owner.get(id(p)) or ".".join(
        str(p.get("tag", "")).split(" ")[0].split(".")[:2])) not in gone]
    objs = [o for o in so if not any(str(o.get("pattern", "")).startswith(k) for k in gone)]
    return keep, objs, left
SPAWN_UNWALKED = "cannot be walked to and from spawn 1"
SPAWN_APART = 400
def move_spawns(arena, graph):
    import math
    from . import v1
    m = v1.arenas_module()
    if graph is None:
        graph = m.walk_graph(arena)
    cells, edges = graph
    spawns = arena.get("spawns") or []
    if not spawns:
        return 0
    first = m.spawn_cell(spawns[0])
    both = m.reach(edges, first) & m.reach(edges, first, reverse=True)
    good = [c for c in both if c in cells]
    if not good:
        return 0
    moved = 0
    for k, s in enumerate(spawns):
        if k == 0 or m.spawn_cell(s) in both:
            continue
        others = [(o["x"], o["z"]) for j, o in enumerate(spawns) if j != k]
        def cost(c):
            x, z = c[0] * m.GRID + m.GRID / 2.0, c[1] * m.GRID + m.GRID / 2.0
            return (math.hypot(x - s["x"], z - s["z"]) + abs(c[2] - s["y"]), c)
        for c in sorted(good, key=cost):
            x, z = c[0] * m.GRID + m.GRID // 2, c[1] * m.GRID + m.GRID // 2
            if all(math.hypot(x - ox, z - oz) >= SPAWN_APART for ox, oz in others):
                s["x"], s["y"], s["z"] = x, c[2], z
                moved += 1
                break
    return moved
def _room_left(arena, brief, wished=False):
    from . import scatter
    left = scatter.line_of(arena, brief) - _objects_used(arena)
    if brief.get("family") != "explore" or not (arena.get("terrain") or {}).get("mesh"):
        return left
    from . import heightfield
    from .families import explore
    ground = sum(1 for p in arena["pieces"] if heightfield.is_terrain(p))
    left += ground
    line = explore.structure_line(brief)
    if line is not None and not wished:
        left = min(left, line - (_objects_used(arena) - ground))
    return left
def _objects_used(arena):
    return (len(arena["pieces"]) + len(arena.get("markers", [])) + len(arena.get("objects", []))
            + len(arena.get("movers") or []))
def repair_budget(arena, raw, painted):
    over = _objects_used(arena) - arena["budget"]
    if over <= 0:
        return None
    done = []
    objs = arena.get("objects") or []
    pick = [o for o in objs if o.get("pattern") == "pickups"]
    if pick:
        take = pick[-over:] if over < len(pick) else pick
        gone = set(id(o) for o in take)
        arena["objects"] = [o for o in objs if id(o) not in gone]
        done.append("%d pickups left out" % len(take))
        over -= len(take)
    if over > 0:
        from . import flora
        trees = flora.groups(raw)
        trees.sort(key=lambda g: -(abs(g[0]["x"]) + abs(g[0]["z"])))
        cut = 0
        new = list(raw)
        for g in trees:
            if _objects_used(arena) - arena["budget"] <= 0:
                break
            gone = set(id(p) for p in g)
            new = [p for p in new if id(p) not in gone]
            cut += 1
            if cut % 4 == 0 or cut == len(trees):
                arena["pieces"] = painted(new)
        arena["pieces"] = painted(new)
        if cut:
            done.append("%d trees left out" % cut)
        raw = new
    over = _objects_used(arena) - arena["budget"]
    if over > 0:
        from . import levelfit
        idx = levelfit.removable(raw)
        if idx:
            cut = set(levelfit.spread(idx, min(len(idx), over + 2)))
            raw = [p for i, p in enumerate(raw) if i not in cut]
            arena["pieces"] = painted(raw)
            done.append("%d dressing pieces left out" % len(cut))
    if not done:
        return None
    return ", ".join(done), raw
def _same_piece(a, b):
    return all(a.get(k) == b.get(k) for k in ("kind", "tex", "x", "y", "z", "w", "h", "d", "yaw"))
def slot_pairs(arena):
    from . import v1
    m = v1.arenas_module()
    pieces = arena["pieces"]
    out = []
    for i, piece in enumerate(pieces):
        x0, x1, z0, z1, _ = m.footprint(piece)
        for px, pz in (((x0 + x1) / 2, (z0 + z1) / 2), (x0 + 50, z0 + 50), (x1 - 50, z1 - 50),
                       (x0 + 50, z1 - 50), (x1 - 50, z0 + 50)):
            top = m.top_at(piece, px, pz)
            if top is None:
                continue
            for j, other in enumerate(pieces):
                if j == i:
                    continue
                ox0, ox1, oz0, oz1, _ = m.footprint(other)
                if ox0 < px < ox1 and oz0 < pz < oz1 and m.covers(other, px, pz):
                    gap = other["y"] - top
                    if 1 < gap < m.MARIO_TALL and not m._gap_filled(pieces, i, j, px, pz, top,
                                                                  other["y"]):
                        out.append((other, piece))
    return out
def drop_smaller(arena, pair):
    keep = ("ground", "edge", "road")
    cands = [p for p in pair if str(p.get("tag", "")).split(".")[0] not in keep]
    if not cands:
        return None
    gone = min(cands, key=lambda p: p["w"] * p["h"] * p["d"])
    arena["pieces"] = [p for p in arena["pieces"] if p is not gone]
    return gone
SCENERY_RULES = {"backdrop": "C3 backdrop", "roofs": "C4 roofs",
                 "gradients": "R13 gradient walls", "framing": "C8 framing"}
SCENERY_WHY = {
    "backdrop": "backdrop masses stand beyond the edge of a map on The Void, outside play; "
                "this family or level has no room for them",
    "roofs": "a roof goes on the landmark and on towers nobody stands on; this map has none",
    "gradients": "base and cap courses go on walls 600 or taller; this map has none",
    "framing": "a gate frames each side's way out of its base in team maps with bases",
    "tops": "grass, snow and sand tops grow in the garden, ice and desert themes",
}
def generator_report(brief, meta, repairs, index, moved=None):
    by_id = {a["id"]: a for a in brief["anchors"]}
    done, not_possible = [], []
    for how, aid, note in meta.get("anchors", []):
        a = by_id.get(aid, {})
        done.append({"id": aid, "what": a.get("what", aid), "where": a.get("where"),
                     "status": how, "note": note})
        if how in ("refused", "not yet"):
            not_possible.append("%s: %s" % (aid, note))
    for o in brief["objects"]:
        not_possible.append("object %s x%d: Forge objects are placed from milestone 3 (needs "
                            "the of_venues objects reader)" % (o["key"], o["count"]))
    for lock in brief["locks"]:
        not_possible.append("lock %r: locks are honoured from milestone 3" % (lock,))
    for line in meta.get("not_possible") or []:
        if line not in not_possible:
            not_possible.append(line)
    for f in brief["features"]["want"]:
        if f in ("jump_pads", "long_lines"):
            not_possible.append("feature %s: not built by the shooter modules yet" % f)
    rules = (meta.get("beauty") or {}).get("rules") or {}
    notes = " ".join(str(n) for n in meta.get("notes") or [])
    for f, rule in SCENERY_RULES.items():
        if f in brief["features"]["want"] and not rules.get(rule):
            not_possible.append("feature %s: not built in this map (%s)" % (f, SCENERY_WHY[f]))
    if "tops" in brief["features"]["want"] and "auto-tops:" not in notes:
        not_possible.append("feature tops: not built in this map (%s)" % SCENERY_WHY["tops"])
    style = meta.get("style") or {}
    return {"done": done, "not_possible": not_possible, "not_understood": [],
            "notes": list(getattr(brief, "notes", []) or []) + list(meta.get("notes", [])),
            "repairs": list(repairs),
            "locks": list(brief["locks"]), "moved": list(moved or []),
            "reseed": dict(brief["reseed"]), "candidate": index, "seed": brief["seed"],
            "modules": meta.get("modules", {}), "defaulted": list(brief.defaulted),
            "skeleton": meta.get("skeleton") or (meta.get("params") or {}).get("skeleton"),
            "style": style, "about": style.get("about"),
            "fill": meta.get("fill"), "spawns": meta.get("spawn_report"),
            "beauty": meta.get("beauty"), "kit": meta.get("kit")}
def _build_job(job):
    brief, index, use_metrics, force = job
    c = build_candidate(brief, index, use_metrics, force)
    c.checks.graph = None
    return c
def workers_for(n, workers=None):
    import os
    if workers is not None:
        return max(1, int(workers))
    if n < 3:
        return 1
    return max(1, min(4, os.cpu_count() or 1, n))
PHASE_HOOKS = []
def phase(text):
    for fn in list(PHASE_HOOKS):
        try:
            fn(text)
        except Exception as why:
            if type(why).__name__ == "Cancelled":
                raise
def build_many(brief, indices, use_metrics=True, workers=None, progress=None, forces=None):
    forces = forces or [None] * len(indices)
    jobs = [(brief, i, use_metrics, f) for i, f in zip(indices, forces)]
    w = workers_for(len(jobs), workers)
    out = []
    if w > 1:
        try:
            import multiprocessing as mp
            ctx = mp.get_context("fork")
            phase("building %d candidates (%d at a time)" % (len(jobs), w))
            with ctx.Pool(w) as pool:
                for c in pool.imap(_build_job, jobs):
                    out.append(c)
                    if progress:
                        progress(c)
            return out
        except (OSError, ValueError, ImportError):
            out = []
    for k, job in enumerate(jobs):
        phase("building candidate %d of %d" % (k + 1, len(jobs)))
        c = build_candidate(*job)
        out.append(c)
        if progress:
            progress(c)
    return out
def generate(brief, candidates=None, use_metrics=True, progress=None, workers=None,
             report_fit=True, forces=None, start=0, finals=None):
    if families.get(brief["family"]) is None:
        raise NotBuilt("family %s is not built yet - milestone 2 brings it (built: %s)"
                       % (brief["family"], ", ".join(families.built())))
    n = candidates or brief["candidates"]
    if finals is None:
        finals = FINALS_ON
    out = build_many(brief, list(range(start, start + n)), use_metrics, workers, progress,
                     forces=forces)
    good = [c for c in out if c.ok and not (c.meta.get("reference") and len(out) > 1)]
    if not good and out and all(c.checks.faults and all(rule_fault(f) for f in c.checks.faults)
                                for c in out):
        more = build_many(brief, list(range(start + n, start + n + EXTRA_FOR_RULES)), use_metrics,
                          workers, progress)
        out += more
        good = [c for c in more if c.ok]
    def asked(c):
        return sum(1 for s in c.arena.get("stars") or [] if s.get("asked"))
    want = set((brief.get("features") or {}).get("want") or ())
    def kept(c):
        return wanted_kept(c.arena.get("pieces") or [], want)
    gated = bool(good) and GATES_ON and not any(c.meta.get("reference") for c in good)
    if gated:
        for c in good:
            phase("judging candidate %d (the exploration critic, the venue judge)" % (c.index + 1))
            purpose(brief, c)
        if not any(c.meta.get("purpose_ok") for c in good):
            more = build_many(brief, list(range(start + len(out), start + len(out) + EXTRA_FOR_GATES)),
                              use_metrics, workers, progress)
            out += more
            for c in more:
                if c.ok:
                    phase("judging candidate %d (the exploration critic, the venue judge)"
                          % (c.index + 1))
                    purpose(brief, c)
                    good.append(c)
        held = [c for c in good if c.meta.get("purpose_ok")]
        if held:
            good = held
    def rank(c):
        return (asked(c), kept(c), fitmod.met((c.score or {}).get("fit")),
                round((c.meta.get("purpose_score") or 0) / PURPOSE_STEP), c.quality or 0, -c.index)
    best = max(good, key=rank) if good else None
    if best is None:
        reasons = sorted(set(f for c in out for f in c.checks.faults))
        raise RuntimeError("no candidate passed the hard checks: %s" % "; ".join(reasons[:5]))
    rich = bool(finals and use_metrics)
    if rich and not best.meta.get("reference"):
        best = choose_finalist(brief, good, rank, best)
    if CRITIC_ON and not best.meta.get("reference"):
        best = critic_choice(brief, good, rank, best, rich=rich)
    if report_fit and use_metrics and not best.meta.get("reference"):
        report_wish_fit(brief, best)
    if gated:
        phase("measuring the chosen map")
        purpose(brief, best, final=True)
    return Result(brief, out, best)
GATES_ON = True
EXTRA_FOR_GATES = 3
def set_piece_reasons(brief, snotes):
    from . import setpieces
    want = setpieces.wanted(brief)[0]
    out = []
    for kind in want:
        word = "set piece %s:" % kind.replace("_", " ")
        why = [n[len(word):].strip() for n in snotes if n.startswith(word)
               and ("not built" in n or "no room" in n or "left out" in n)]
        if why:
            out.append("%s: %s" % (kind, why[0].replace("not built - ", "")))
    return out
def said_late(arena, brief):
    want = set((brief.get("features") or {}).get("want") or ())
    tags = [str(p.get("tag", "")) for p in arena.get("pieces") or ()]
    out = []
    if "crystals" in want and "cave.crystal" not in tags:
        out.append("crystals: they grow along a cave's passages - %s" % (
            "no cave on this world had a passage wide enough for them"
            if any(t.startswith("cave.") for t in tags) else
            "this world found no high ground for a cave (try caves on a larger size)"))
    if "lanterns" in want and not any("lamp" in t or "lantern" in t for t in tags):
        out.append("lanterns: no path on this world had room for a lamp")
    if "glowing_mushrooms" in want and not any(t.endswith(".glow") for t in tags):
        out.append("glowing mushrooms: no mushroom on this world to light")
    return out
PURPOSE_STEP = 5.0
def purpose(brief, c, final=False):
    from . import critic, venuejudge
    a = c.arena
    ok, score, lines = True, 0.0, []
    if brief["family"] == "explore" and not (brief.get("modes") or []):
        graph = None if final else c.checks.graph
        from . import basins
        before = len(a["pieces"])
        sealed = basins.seal_rims(a)
        if len(a["pieces"]) > before:
            res = checks.run(a)
            if res.ok:
                c.checks = res
                graph = None if final else res.graph
                c.repairs.extend("liquids: %s" % n for n in sealed)
            else:
                del a["pieces"][before:]
                c.repairs.append("liquids: the seals broke the checks (%s) - left out"
                                 % res.faults[0])
        from . import playable
        playable.repair(a)
        moved = critic.first_view(a)
        if moved and not moved[0].startswith("spawn 1's first view"):
            c.repairs.extend("first view: %s" % n for n in moved)
        fun = critic.explore_fun(a, graph=graph, bake=True)
        a["explore_fun"] = {"score": fun["score"], "pass_hard": fun["pass_hard"],
                            "fails": fun["fails"], "tier": fun["tier"],
                            "weak": fun["weak"][:6], "showcase": fun["showcase"]}
        ok, score = fun["pass_hard"], fun["score"]
        lines += ["exploration: %s - %s" % (k, fun["hard"][k]["note"]) for k in fun["fails"]]
    v = venuejudge.judge(a, brief=brief)
    if (v["blocking"] or v["warnings"]) and not final:
        notes = venuejudge.repair(a, v, brief)
        if notes:
            c.repairs.extend("venue repair: %s" % n for n in notes)
            v = venuejudge.judge(a, brief=brief)
    a["venue"] = venuejudge.summary(v)
    asked_modes = set(brief.get("modes") or [])
    for mode, why in v["blocking"].items():
        if not asked_modes or mode in asked_modes:
            ok = False
        lines += ["venue judge, %s: %s" % (mode, w) for w in why[:2]]
    if v["modes"]:
        score = score * 0.5 + 50.0 * v["share"] if score else 100.0 * v["share"]
    c.meta["purpose_ok"], c.meta["purpose_score"] = ok, score
    if final:
        rep = a.setdefault("report", {})
        if "explore_fun" in a:
            rep.setdefault("notes", []).append(
                "exploration critic %.0f%s" % (a["explore_fun"]["score"],
                                               "" if a["explore_fun"]["pass_hard"] else
                                               " - fails " + ", ".join(a["explore_fun"]["fails"])))
        if not ok:
            np_ = rep.setdefault("not_possible", [])
            for line in lines:
                if line not in np_:
                    np_.append(line)
    return ok, score
EXTRA_FOR_RULES = 4
RULE_FAULTS = ("ST1:", "ST2:", "ST6:", "cut:", "floating:", "pocket:", "contract:", "movers:",
               "overlap:", "lava:")
def rule_fault(text):
    return str(text).startswith(RULE_FAULTS)
FINALS_ON = True
FINALISTS = 3
FINAL_MARGIN = 0.03
PARETO_FLOOR = 0.06
FULL_FAMILIES = ("shooter", "objective", "hide")
def finalists(good, rank, best):
    head = rank(best)[:3]
    q = best.quality or 0
    out = [c for c in sorted(good, key=rank, reverse=True)
           if rank(c)[:3] == head and (c.quality or 0) >= q - FINAL_MARGIN - 1e-9]
    return out[:FINALISTS]
def _has_full_tier(brief):
    from .metrics import targets
    try:
        bands = targets.bands(brief["family"], brief.get("size"))
    except KeyError:
        return False
    if any(b.tier == "expensive" and not b.warn_only for b in bands.values()):
        return True
    return any(t[0] in fitmod.FULL_ASKS for t in fitmod.targets(brief))
def full_quality(brief, c):
    c.full_measure = None
    c.after = None
    if not _has_full_tier(brief):
        c.full_met = 0
        return c.quality
    try:
        from . import metrics
        res = metrics.measure(c.arena, family=brief["family"], tier="full",
                              players=brief["players"], size=brief.get("size"),
                              course_s=scoring.course_clean_s(c.meta))
        c.full_measure = res
        _, q = metrics.quality(res)
        try:
            c.after = fitmod.after_measured(brief, res, c.arena)
        except Exception:
            c.after = None
        try:
            c.full_met = fitmod.met(fitmod.measure_fit(brief, res, c.arena,
                                                       names=fitmod.FULL_ASKS))
        except Exception:
            c.full_met = 0
        return None if q is None else round(float(q), 4)
    except Exception:
        return None
def looks_audit(brief, c):
    try:
        from .metrics import looks
        a = looks.audit(c.arena, brief["family"], far=1, spawns=2)
        try:
            from .metrics import artdir
            a["artdir"] = artdir.render(a, c.arena)
        except Exception:
            pass
        a.pop("frames", None)
        return a
    except Exception:
        return None
def looks_tally(brief, c):
    a = looks_audit(brief, c)
    if a is None:
        return 0, 0, "not run"
    st = [row["status"] for row in a["checks"].values()]
    return st.count("fail"), st.count("warn"), a["summary"]
def verdict(brief, c):
    from . import critic
    notes = critic.repair(c.arena)
    q = full_quality(brief, c)
    measured = getattr(c, "full_measure", None)
    if measured is None and c.score and c.score.get("metrics"):
        measured = {"metrics": c.score["metrics"], "extra": {}, "world": None}
    audit = looks_audit(brief, c)
    res = critic.judge(c.arena, brief["family"], measured=measured, looks=audit,
                       modes=brief.get("modes"), size=brief.get("size"))
    res["repairs"] = notes
    res["verdict"] = True
    if audit is not None:
        res["looks_summary"] = audit.get("summary")
    c.arena["critic"] = res
    c.full_measure = None
    g = res.get("groups") or {}
    build = g.get("build", 1.0)
    return {"candidate": c.index, "cheap": c.quality, "full": q,
            "asks": getattr(c, "full_met", 0), "critic": res["score"], "pass": res["pass"],
            "play": round(g.get("play", 0.5), 4),
            "looks": round((g.get("looks", build) + build) / 2.0, 4)}
def _final_verdict(job):
    brief, c = job
    row = verdict(brief, c)
    return row, c.arena, getattr(c, "full_met", 0), getattr(c, "after", None)
def _final_map(fn, brief, cands):
    jobs = [(brief, c) for c in cands]
    if len(jobs) > 1 and workers_for(len(jobs) + 2) > 1:
        try:
            import multiprocessing as mp
            with mp.get_context("fork").Pool(min(len(jobs), workers_for(len(jobs) + 2))) as pool:
                return pool.map(fn, jobs)
        except (OSError, ValueError, ImportError, AttributeError, AssertionError):
            pass
    return [fn(j) for j in jobs]
def _axes(r):
    q = r["full"] if r["full"] is not None else (r["cheap"] or 0)
    return (q, r["play"], r["looks"])
def pareto_front(rows):
    out = []
    for r in rows:
        a = _axes(r)
        beaten = False
        for o in rows:
            if o is r:
                continue
            b = _axes(o)
            if all(y >= x - 1e-9 for x, y in zip(a, b)) and any(y > x + 1e-9
                                                                for x, y in zip(a, b)):
                beaten = True
                break
        if not beaten:
            out.append(r)
    return out
def _pick_key(r):
    return (r["pass"], round(sum(_axes(r)), 4), _axes(r)[0], -r["candidate"])
def wanted_kept(ps, want):
    tags = set(str(p.get("tag", "")) for p in ps)
    n = 0
    if "water" in want and any(p.get("kind") == "water" for p in ps):
        n += 1
    if "river" in want and "river.water" in tags:
        n += 1
    if "caves" in want and "cave.top" in tags:
        n += 1
        if "cave.floor" in tags:
            n += 1
    return n
def choose_finalist(brief, good, rank, best):
    fin = finalists(good, rank, best)
    outs = _final_map(_final_verdict, brief, fin)
    rows = []
    for c, (row, arena, met, after) in zip(fin, outs):
        c.arena = arena
        c.full_met = met
        c.after = after
        rows.append(row)
    if len(fin) < 2:
        return best
    most = max(r["asks"] for r in rows)
    left = [r for r in rows if r["asks"] == most]
    top = max(_axes(r)[0] for r in left)
    left = [r for r in left if _axes(r)[0] >= top - PARETO_FLOOR - 1e-9]
    front = pareto_front(left)
    for r in rows:
        r["kept"] = any(r is k for k in left)
        r["front"] = any(r is k for k in front)
    win_row = max(front, key=_pick_key)
    win = fin[rows.index(win_row)]
    others = sorted([r for r in rows if r is not win_row], key=lambda r: (
        r["kept"], r["front"]) + _pick_key(r), reverse=True)
    rep = win.arena.setdefault("report", {})
    rep["finalists"] = rows
    say = "finalists %s: candidate %d" % (", ".join(str(r["candidate"]) for r in rows),
                                          win.index)
    say += " on the front of quality, play and looks (%s)" % ", ".join(
        "%.2f" % v for v in _axes(win_row))
    rep.setdefault("notes", []).append(say)
    if others:
        loser = fin[rows.index(others[0])]
        rep["why_won"] = why_won(win_row, others[0], win.arena.get("critic") or {},
                                 loser.arena.get("critic") or {})
    return win
AXIS_WORDS = {"quality": "Score against the family's targets", "play": "How it plays",
              "looks": "How it looks"}
WHY_MIN = 0.05
WHY_ROWS = 6
def why_won(win, runner, cw, cr):
    from . import critic
    rows = []
    for k, (a, b) in zip(("quality", "play", "looks"), zip(_axes(win), _axes(runner))):
        rows.append({"row": k, "label": AXIS_WORDS[k], "winner": round(a, 3),
                     "runner_up": round(b, 3), "delta": round(a - b, 3),
                     "say": "%s: %s (%.0f vs %.0f)" % (
                         AXIS_WORDS[k], _better(a - b), a * 100, b * 100)})
    rw, rr = cw.get("rows") or {}, cr.get("rows") or {}
    diffs = []
    for k in rw:
        if k not in rr:
            continue
        d = rw[k]["score"] - rr[k]["score"]
        if abs(d) >= WHY_MIN:
            diffs.append((d, k))
    diffs.sort(key=lambda t: -abs(t[0]))
    for d, k in diffs[:WHY_ROWS]:
        label = critic.LABELS.get(k, k)
        rows.append({"row": k, "label": label, "winner": rw[k]["score"],
                     "runner_up": rr[k]["score"], "delta": round(d, 3),
                     "say": "%s: %s - this map: %s; the runner-up: %s" % (
                         label, _better(d), rw[k]["note"], rr[k]["note"])})
    ups = [r["label"].lower() for r in rows[3:] if r["delta"] > 0][:3]
    head = "Candidate %d won over candidate %d" % (win["candidate"], runner["candidate"])
    if not runner.get("kept", True):
        head += " (the runner-up was too far under on the score)"
    elif not runner.get("front", True):
        head += " (the runner-up was beaten on quality, play and looks at once)"
    if ups:
        head += ": better on " + ", ".join(ups)
    return {"winner": win["candidate"], "runner_up": runner["candidate"], "headline": head,
            "rows": rows}
def _better(d):
    if d >= WHY_MIN:
        return "better"
    if d <= -WHY_MIN:
        return "worse"
    return "about the same"
CRITIC_ON = True
CRITIC_MARGIN = 0.05
CRITIC_TRIES = 4
def critic_choice(brief, good, rank, best, rich=False):
    from . import critic
    fam = brief["family"]
    def judged(c):
        if rich:
            verdict(brief, c)
            return c.arena["critic"]
        notes = critic.repair(c.arena)
        res = critic.judge(c.arena, fam, modes=brief.get("modes"))
        res["repairs"] = notes
        c.arena["critic"] = res
        return res
    done = (best.arena.get("critic") or {}) if rich else {}
    res = done if done.get("verdict") else judged(best)
    win, tried = best, [(best.index, res["score"])]
    if not res["pass"]:
        head = rank(best)[:3]
        q = best.quality or 0
        others = [c for c in sorted(good, key=rank, reverse=True)
                  if c is not best and rank(c)[:3] == head
                  and (c.quality or 0) >= q - CRITIC_MARGIN - 1e-9][:CRITIC_TRIES]
        top = res["score"]
        for c in others:
            r2 = judged(c)
            tried.append((c.index, r2["score"]))
            if r2["score"] > top:
                win, top = c, r2["score"]
            if r2["pass"]:
                break
    rep = win.arena.setdefault("report", {})
    say = critic.summary(win.arena["critic"])
    if len(tried) > 1:
        say += "; judged %s" % ", ".join("%d: %.0f" % t for t in tried)
    rep.setdefault("notes", []).append(say)
    for n in win.arena["critic"].get("repairs") or []:
        rep["notes"].append("critic repair: %s" % n)
    report_mode_needs(brief, win.arena)
    return win
def report_mode_needs(brief, arena):
    if not brief.get("modes") or "modes" in (getattr(brief, "defaulted", ()) or ()):
        return []
    row = ((arena.get("critic") or {}).get("rows") or {}).get("mode_fit") or {}
    lines = ["mode %s - place it in the Studio (report card, Game modes) or pick another "
             "mode" % m for m in row.get("misses") or []]
    np = arena.setdefault("report", {}).setdefault("not_possible", [])
    for line in lines:
        if line not in np:
            np.append(line)
    return lines
def report_wish_fit(brief, best):
    cheap = (best.score or {}).get("fit")
    fit, lines = fitmod.after_choice(brief, best.arena, cheap,
                                     measured=getattr(best, "after", None),
                                     course_s=scoring.course_clean_s(best.meta))
    report = best.arena.setdefault("report", {})
    report["fit"] = fit
    np = report.setdefault("not_possible", [])
    for line in lines:
        if line not in np:
            np.append(line)
def layout_bytes(result):
    return json.dumps(result.layout(), sort_keys=True).encode()
