import copy
import json
import os
import time
from . import generate as gen
from .brief import Brief
FIELDS_VARIED = ("verticality", "density")
FAMILY_AXES = {
    "shooter": ("verticality", "openness"),
    "objective": ("verticality", "openness"),
    "knockoff": ("ring", "tiers"),
    "race": ("lap_length", "elevation"),
    "course": ("difficulty", "verticality"),
    "hide": ("openness", "floors"),
    "party": ("size", "density"),
}
FAMILY_AXES["explore"] = ("challenge", "movers")
EXTRA_AXES = {"challenge": (0.0, 1.0), "items": (0.0, 1.0), "movers": (0.0, 1.0),
              "star_kinds": (0.0, 1.0),
              "lap_length": (0.0, 1.0), "elevation": (0.0, 1.0), "difficulty": (0.0, 1.0),
              "floors": (0.0, 1.0), "ring": (0.0, 1.0), "tiers": (0.0, 1.0),
              "relief": (0.0, 1.0), "rugged": (0.0, 1.0), "plateaus": (0.0, 1.0),
              "water": (0.0, 1.0), "weirs": (0.0, 1.0), "caves": (0.0, 1.0),
              "mix": (0.0, 1.0), "landmarks": (0.0, 1.0), "loops": (0.0, 1.0),
              "built": (0.0, 1.0)}
def _clamp(v):
    return max(0.0, min(1.0, v))
def descriptors(result):
    from .metrics import qd
    d = dict(qd.descriptors(result))
    m = result["metrics"]
    if m.get("lap_length"):
        d["lap_length"] = round(_clamp(m["lap_length"] / 120000.0), 4)
    if m.get("elevation_range") is not None:
        d["elevation"] = round(_clamp(m["elevation_range"] / 1600.0), 4)
    jc = m.get("jump_class_needed")
    cs = m.get("course_s")
    if jc is not None or cs:
        parts = []
        if jc is not None:
            parts.append(_clamp(jc / 3.0))
        if cs:
            parts.append(_clamp((cs - 30.0) / 90.0))
        d["difficulty"] = round(sum(parts) / len(parts), 4)
    layers = m.get("layers")
    if layers is not None:
        d["floors"] = round(_clamp((layers - 1) / 4.0), 4)
    if m.get("ring_radius"):
        d["ring"] = round(_clamp(m["ring_radius"] / 2400.0), 4)
    if m.get("tiers") is not None:
        d["tiers"] = round(_clamp((m["tiers"] - 1) / 3.0), 4)
    return d
def arena_descriptors(arena):
    from . import movers
    g = (arena or {}).get("gameplay") or {}
    d = dict(g.get("descriptor") or {})
    out = {}
    if "challenge" in d:
        out["challenge"] = round(_clamp(d["challenge"]), 4)
    if "items" in d:
        out["items"] = round(_clamp(d["items"]), 4)
    if "star_kinds" in d:
        out["star_kinds"] = round(_clamp(d["star_kinds"] / 6.0), 4)
    if (arena or {}).get("movers") is not None or g:
        out["movers"] = round(_clamp(movers.descriptors(arena or {})["mover_share"]), 4)
    for k, v in (((arena or {}).get("sites") or {}).get("descriptors") or {}).items():
        if k in EXTRA_AXES and isinstance(v, (int, float)):
            out[k] = round(_clamp(float(v)), 4)
    return out
def default_axes(family):
    return FAMILY_AXES.get(family, ("verticality", "openness"))
VERTS = ("flat", "low", "medium", "high")
DENS = ("sparse", "medium", "dense")
EXPENSIVE_AXES = ("openness", "engagement")
class Elite(object):
    def __init__(self, genome, arena, quality, desc, valid, faults, summary):
        self.genome = genome
        self.arena = arena
        self.quality = quality
        self.desc = desc
        self.valid = valid
        self.faults = faults
        self.summary = summary
    def as_dict(self):
        return {"genome": self.genome, "quality": self.quality, "desc": self.desc,
                "valid": self.valid, "faults": self.faults, "summary": self.summary}
class Result(object):
    def __init__(self, brief, archive, elites, picks, stats):
        self.brief = brief
        self.archive = archive
        self.elites = elites
        self.picks = picks
        self.stats = stats
    @property
    def best(self):
        return self.picks[0] if self.picks else None
def brief_of(brief, genome):
    changes = dict(genome.get("brief") or {})
    reseed = dict(brief["reseed"])
    reseed.update(genome.get("reseed") or {})
    if reseed:
        changes["reseed"] = reseed
    return brief.with_changes(**changes) if changes else brief
def build(brief, genome, tier="cheap"):
    from .metrics import measure, quality as quality_of
    b = brief_of(brief, genome)
    c = gen.build_candidate(b, genome["index"], use_metrics=False, force=genome.get("force"))
    summary = c.summary()
    if not c.ok:
        return None, 0.0, {}, False, list(c.checks.faults), summary
    res = measure(c.arena, family=b["family"], tier=tier, players=b["players"])
    _, q = quality_of(res)
    desc = descriptors(res)
    desc.update(arena_descriptors(c.arena))
    arena = c.arena
    arena["report"]["genome"] = genome
    return arena, round(float(q), 4), desc, True, [], summary
def _job(args):
    brief_dict, genome, tier = args
    brief = Brief.from_dict(brief_dict)
    try:
        return build(brief, genome, tier)
    except Exception as why:
        return None, 0.0, {}, False, ["%s: %s" % (why.__class__.__name__, why)], {}
def _free_fields(brief):
    defaulted = set(brief.defaulted)
    return [f for f in FIELDS_VARIED if f in defaulted]
def _skeletons(brief):
    if brief["family"] != "shooter":
        return []
    from . import skeletons
    units = skeletons.wanted_units(brief)
    across = skeletons.across_of(brief, brief["players"])
    out = []
    for name, (syms, _, _, min_across) in sorted(skeletons.SKELETONS.items()):
        if units == 4 and "turn4" not in syms:
            continue
        if units == 2 and not any(s in ("mirror", "turn2") for s in syms):
            continue
        if across < min_across and name != "keep":
            continue
        out.append(name)
    return out
def opening(brief, n, rng):
    free = _free_fields(brief)
    skels = _skeletons(brief)
    out = []
    k = max(1, len(skels))
    for i in range(n):
        g = {"index": i, "force": {"skeleton": skels[i % k]} if skels else {}, "brief": {}}
        if "verticality" in free:
            g["brief"]["verticality"] = VERTS[(i // k) % len(VERTS)]
        if "density" in free:
            g["brief"]["density"] = DENS[(i // (k * len(VERTS))) % len(DENS)
                                         if n > k * len(VERTS) else rng.randrange(3)]
        if g["force"].get("skeleton") in ("twin", "terraces", "courtyard", "canyon") and \
                g["brief"].get("verticality") == "flat":
            g["brief"]["verticality"] = "low"
        out.append(g)
    return out
def mutate(parent, brief, rng, index, towards=None):
    from . import dice
    g = copy.deepcopy(parent)
    g["index"] = index
    g.setdefault("force", {})
    g.setdefault("brief", {})
    g.setdefault("reseed", {})
    free = _free_fields(brief)
    if brief["family"] == "shooter":
        ops = ["reseed", "reseed", "skeleton", "boost"] + ["field"] * (2 if free else 0)
    else:
        ops = ["fresh", "fresh"] + ["field"] * (2 if free else 0)
    op = rng.choice(ops)
    if towards is not None and free:
        op = "toward"
    if op == "reseed":
        stream = rng.choice(("fill", "fill.options", "style", "beauty", "centre",
                             "skeleton." + g["force"].get("skeleton", "keep"), "unit", "frame"))
        g["reseed"][stream] = g["reseed"].get(stream, 0) + 1
    elif op == "fresh":
        pass
    elif op == "skeleton":
        g["force"]["skeleton"] = rng.choice(_skeletons(brief))
    elif op == "boost":
        g["force"]["boost"] = rng.choice(sorted(dice.KNOBS))
    elif op == "field":
        f = rng.choice(free)
        vals = VERTS if f == "verticality" else DENS
        cur = g["brief"].get(f, brief[f])
        i = vals.index(cur) + rng.choice((-1, 1))
        g["brief"][f] = vals[max(0, min(len(vals) - 1, i))]
    elif op == "toward":
        dv, do = towards
        if "verticality" in free and dv:
            cur = g["brief"].get("verticality", brief["verticality"])
            i = VERTS.index(cur) + (1 if dv > 0 else -1)
            g["brief"]["verticality"] = VERTS[max(0, min(3, i))]
        if "density" in free and do:
            cur = g["brief"].get("density", brief["density"])
            i = DENS.index(cur) + (-1 if do > 0 else 1)
            g["brief"]["density"] = DENS[max(0, min(2, i))]
        g["reseed"]["fill"] = g["reseed"].get("fill", 0) + 1
    if g["force"].get("skeleton") in ("twin", "terraces", "courtyard", "canyon") and \
            g["brief"].get("verticality") == "flat":
        g["brief"]["verticality"] = "low"
    if not g["reseed"]:
        g.pop("reseed")
    return g
def _evaluate(brief, genomes, tier, workers, pool):
    jobs = [(brief.to_dict(), g, tier) for g in genomes]
    if pool is not None:
        return pool.map(_job, jobs, chunksize=1)
    return [_job(j) for j in jobs]
def run(brief, axes=None, bins=5, children=None, workers=None,
        progress=None, tier=None, floor=0.8, k=8, opening_size=None, seed=None):
    import random
    from .metrics import qd
    if not isinstance(brief, Brief):
        brief = Brief.from_dict(brief)
    if seed is not None:
        brief = brief.with_changes(seed=seed)
    axes = tuple(axes or default_axes(brief["family"]))
    known = dict(qd.AXES)
    known.update(EXTRA_AXES)
    for a in axes:
        if a not in known:
            raise ValueError("no behaviour axis %r (axes: %s)" % (a, ", ".join(sorted(known))))
    tier = tier or ("full" if any(a in EXPENSIVE_AXES for a in axes) else "cheap")
    total = int(children or 8 * bins ** len(axes))
    n0 = int(opening_size or max(12, min(total // 3, 8 * max(1, len(_skeletons(brief))))))
    rng = random.Random("variety/%s/%s" % (brief["seed"], ",".join(axes)))
    archive = qd.MapElites(axes, bins=bins, ranges=EXTRA_AXES)
    arenas = {}
    w = gen.workers_for(total, workers)
    pool = None
    if w > 1:
        try:
            import multiprocessing as mp
            pool = mp.get_context("fork").Pool(w)
        except (OSError, ValueError, ImportError):
            pool = None
    t0 = time.time()
    done = 0
    invalid = 0
    batch = max(4, 2 * w)
    try:
        genomes = opening(brief, n0, rng)
        next_index = n0
        while genomes:
            results = _evaluate(brief, genomes, tier, w, pool)
            for g, (arena, q, desc, valid, faults, summary) in zip(genomes, results):
                key = json.dumps(g, sort_keys=True)
                if valid:
                    archive.add(g, q, desc, True, 0.0, meta={"summary": summary})
                    arenas[key] = arena
                else:
                    invalid += 1
                    archive.add(g, 0.0, {a: 0.0 for a in axes}, False, float(len(faults)),
                                meta={"faults": faults[:3], "summary": summary})
            done += len(genomes)
            if done == n0:
                _slide(archive, axes)
            if progress:
                progress(done, total, archive, time.time() - t0)
            if done >= total:
                break
            genomes = []
            empty = archive.empty_cells()
            for _ in range(min(batch, total - done)):
                towards = None
                parent = archive.sample_parent(rng, invalid_share=0.1)
                if parent is None:
                    parent_g = {"index": next_index, "force": {}}
                else:
                    parent_g = parent.genome
                if empty and rng.random() < 0.5 and parent is not None:
                    target = rng.choice(empty)
                    cell = archive.cell_of(parent.desc) or target
                    towards = (target[0] - cell[0], target[1] - cell[1] if len(target) > 1 else 0)
                genomes.append(mutate(parent_g, brief, rng, next_index, towards))
                next_index += 1
    finally:
        if pool is not None:
            pool.close()
            pool.join()
    elites = {}
    for cell, e in archive.elites(True):
        key = json.dumps(e.genome, sort_keys=True)
        elites[cell] = Elite(e.genome, arenas.get(key), e.fitness, e.desc, True, [],
                             e.meta.get("summary"))
    entries = [e for _, e in archive.elites(True)]
    chosen = qd.pick_diverse(entries, k=k, floor=floor, axes=axes)
    short = None
    if len(chosen) < k + 1 and chosen:
        top = max(e.fitness or 0 for e in chosen)
        rest = [e for e in entries if e not in chosen and e.fitness is not None
                and e.fitness >= floor * top - 1e-9]
        while rest and len(chosen) < k + 1:
            def gap(e):
                return min(qd.distance(e.desc, p.desc, axes) for p in chosen) if chosen else 0
            rest.sort(key=lambda e: (-gap(e), -(e.fitness or 0)))
            chosen.append(rest.pop(0))
        if len(chosen) < k + 1:
            short = ("%d of %d maps: %d different valid maps came out of %d built (%d "
                     "invalid), %d of them within %d%% of the best's quality - more "
                     "children (or a lower floor) give more"
                     % (len(chosen), k + 1, len(entries), done, invalid,
                        len(chosen), round(100 * floor)))
    picks = []
    for e in chosen:
        key = json.dumps(e.genome, sort_keys=True)
        picks.append(Elite(e.genome, arenas.get(key), e.fitness, e.desc, True, [],
                           e.meta.get("summary")))
    stats = {"children": done, "invalid": invalid, "coverage": round(archive.coverage(), 3),
             "qd_score": round(archive.qd_score(), 3), "cells": len(elites),
             "axes": list(axes), "bins": bins, "tier": tier, "workers": w,
             "ranges": {a: list(archive.ranges[a]) for a in axes},
             "seconds": round(time.time() - t0, 1), "floor": floor,
             "best": picks[0].quality if picks else None,
             "alternatives": len(picks) - 1 if picks else 0, "short": short}
    return Result(brief, archive, elites, picks, stats)
def _slide(archive, axes):
    vals = {a: [e.desc.get(a) for e in archive._all if e.valid and e.desc.get(a) is not None]
            for a in axes}
    for a in axes:
        v = vals[a]
        if len(v) < 4:
            continue
        lo, hi = min(v), max(v)
        if hi - lo < 1e-6:
            continue
        pad = 0.05 * (hi - lo)
        archive.ranges[a] = (lo - pad, hi + pad)
    archive.set_axes(axes)
def contact_sheet(res, cell_px=220):
    from PIL import Image, ImageDraw
    from .render.views import top_down
    axes = res.archive.axes
    b = res.archive.bins
    pad, top, left = 6, 44, 34
    W = left + b * (cell_px + pad) + pad
    H = top + b * (cell_px + 34 + pad) + pad + 20
    im = Image.new("RGB", (W, H), (24, 26, 30))
    d = ImageDraw.Draw(im)
    pick_keys = [json.dumps(p.genome, sort_keys=True) for p in res.picks]
    d.text((left, 8), "variety grid %s x %s - %d maps, coverage %.0f%%, best %.3f; gold frame = a "
           "pick (>= %.0f%% of the best, farthest apart)" % (
               axes[0], axes[1] if len(axes) > 1 else "-", res.stats["children"],
               100 * res.stats["coverage"], res.stats["best"] or 0, 100 * res.stats["floor"]),
           fill=(230, 230, 230))
    d.text((left, 24), "x: %s (low -> high)   y: %s (low at the bottom)" % (
        axes[0], axes[1] if len(axes) > 1 else "-"), fill=(170, 170, 170))
    for cell, e in sorted(res.elites.items()):
        i = cell[0]
        j = cell[1] if len(cell) > 1 else 0
        x = left + pad + i * (cell_px + pad)
        y = top + pad + (b - 1 - j) * (cell_px + 34 + pad)
        if e.arena is not None:
            th = top_down(e.arena, size=cell_px, legend=False)
            th = th.crop((0, 0, cell_px, cell_px))
            im.paste(th, (x, y))
        key = json.dumps(e.genome, sort_keys=True)
        if key in pick_keys:
            n = pick_keys.index(key)
            d.rectangle([x - 2, y - 2, x + cell_px + 1, y + cell_px + 1], outline=(230, 180, 40),
                        width=3)
            d.text((x + 4, y + 4), "#%d" % (n + 1), fill=(230, 180, 40))
        sk = (e.summary or {}).get("skeleton", "?")
        d.text((x + 2, y + cell_px + 3), "%.3f %s" % (e.quality, sk), fill=(220, 220, 220))
        g = e.genome.get("brief") or {}
        d.text((x + 2, y + cell_px + 17), " ".join(str(v) for v in g.values())[:34],
               fill=(150, 150, 150))
    return im
def picks_sheet(res, size=360):
    from .render.views import sheet, top_down, iso
    ims = []
    for n, p in enumerate(res.picks):
        if p.arena is None:
            continue
        a = dict(p.arena)
        a["key"] = "pick %d - %.3f %s" % (n + 1, p.quality, (p.summary or {}).get("skeleton", ""))
        ims.append(top_down(a, size=size))
        ims.append(iso(a, size=size))
    return sheet(ims, cols=4, label="the best and its alternatives (plan + 3D each)")
def write_out(res, out):
    os.makedirs(out, exist_ok=True)
    files = []
    data = {"brief": res.brief.to_dict(), "stats": res.stats,
            "picks": [p.as_dict() for p in res.picks],
            "grid": {"%s" % (list(c),): e.as_dict() for c, e in sorted(res.elites.items())},
            "archive": res.archive.to_dict()}
    p = os.path.join(out, "variety.json")
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1, sort_keys=True, default=str)
    files.append(p)
    for n, pk in enumerate(res.picks):
        if pk.arena is None:
            continue
        p = os.path.join(out, "pick-%d.layout.json" % (n + 1))
        with open(p, "w", encoding="utf-8") as fh:
            json.dump(pk.arena, fh, indent=1, sort_keys=True, default=str)
        files.append(p)
    try:
        p = os.path.join(out, "variety-grid.png")
        contact_sheet(res).save(p, optimize=True)
        files.append(p)
        p = os.path.join(out, "variety-picks.png")
        picks_sheet(res).save(p, optimize=True)
        files.append(p)
    except ImportError as why:
        files.append("(no pictures: %s)" % why)
    return files
def rebuild(brief, genome):
    if not isinstance(brief, Brief):
        brief = Brief.from_dict(brief)
    b = brief_of(brief, genome)
    return gen.build_candidate(b, genome["index"], use_metrics=False, force=genome.get("force"))
def print_progress(done, total, archive, elapsed):
    best = archive.best()
    print("variety: %d/%d maps, %d cells filled (%.0f%%), best %s, %.0f s"
          % (done, total, len(archive.elites(True)), 100 * archive.coverage(),
             "%.3f" % best.fitness if best else "-", elapsed), flush=True)
