import json
import os
import sys
import time
HERE = os.path.dirname(os.path.abspath(__file__))
ACCEPTED = os.path.join(HERE, "gallery", "accepted.json")
HARD = ("refused", "contract_refused", "cuts", "stairs", "floating", "pockets", "escapes",
        "movers", "overlaps", "lava", "finding")
SOFT = ("quality", "kinds_used", "fit_coverage", "non_box_share", "contract_warn", "joins",
        "movement", "stairs_soft", "pieces", "critic")
PHASH_NEAR = 10
FAMILIES = ("shooter", "ctf", "race", "course", "hide", "explore")
RICH = {
    "shooter": ["kleine schnelle Shooter-Map, viel Vertikalitaet, Turm im Nordwesten",
                "shooter map on ice with a big bridge in the middle and three towers",
                "eine Burg mit Mauern und Toren, Shooter, Lava"],
    "ctf": ["CTF auf Eis, zwei Basen mit Mauern, eine Bruecke in der Mitte",
            "capture the flag in a desert with walls and gates",
            "CTF, viele Ebenen, Holz"],
    "race": ["ein langes Rennen mit vielen Kurven", "race track on ice with jumps",
             "a race through a desert canyon"],
    "course": ["ein Hindernisparcours mit Saeulen und Sprungen", "obstacle course in the sky",
               "Parcours mit Lava und Rampen"],
    "hide": ["Hide and Seek in einem Dorf mit Haeusern und Hecken",
             "hide and seek garden with a maze and houses",
             "Verstecken in Ruinen mit vielen Ecken"],
    "explore": ["eine grosse Welt mit Fluss, Dorf und Bergen",
                "a large world with a village, a castle and a lake",
                "eine Terrassenwelt mit Hoehlen und Wald"],
}
FINDINGS = [
    {"id": "F-hedge-houses", "brief": {"family": "hide", "theme": "garden", "size": "large",
                                       "dna": {"complexity": 0.8}, "features": {"want":
                                                                               ["buildings"]}},
     "seed": 1, "rule": "foliage_or_fabric_on_built",
     "about": "houses wore the maze/hedge wall"},
    {"id": "F-fabric-walls", "brief": {"family": "explore", "theme": "garden", "size": "large"},
     "seed": 2, "rule": "foliage_or_fabric_on_built",
     "about": "houses wore the tent stripes; roofs the paving"},
    {"id": "F-stairs-hedges", "brief": {"family": "hide", "theme": "garden",
                                        "size": "gigantic"},
     "seed": 1, "rule": "stairs",
     "about": "stairs and ramps ran into hedges and walls (the stair rule)"},
    {"id": "F-hedge-band", "brief": {"family": "explore", "theme": "garden", "size": "large",
                                     "features": {"want": ["landmarks"]}},
     "seed": 3, "rule": "foliage_or_fabric_on_built",
     "about": "a stone pillar (watchtower) with a hedge band in its middle"},
    {"id": "F-pillar-gap", "brief": {"family": "ctf", "theme": "desert"}, "seed": 1,
     "rule": "pillar_gap",
     "about": "corner pillars that do not meet the walls (a 40 slot cabin)"},
    {"id": "F-floating-cannon", "brief": {"family": "explore", "theme": "lava",
                                          "size": "gigantic"}, "seed": 1,
     "rule": "floating",
     "about": "the cannon star's construction floating free over a flat plain"},
    {"id": "F-logs-overlap", "brief": {"family": "explore", "theme": "lava",
                                       "size": "gigantic"}, "seed": 1,
     "rule": "movers",
     "about": "three rolling logs at random spots, partly overlapping, rolling up and down"},
    {"id": "F-lava-unsafe", "brief": {"family": "explore", "theme": "lava", "size": "large"},
     "seed": 1, "rule": "lava",
     "about": "lava walked on as a floor: a spawn, a star or a standing object on it"},
    {"id": "F-staircase", "brief": {"family": "explore", "size": "large"}, "seed": 1,
     "rule": "staircase",
     "about": "a terraced world of one-layer steps (349 of them, every step 200)"},
    {"id": "F-detail-guards", "brief": {"family": "explore", "size": "large",
                                        "preset": "village", "features": {"want": ["buildings"]}},
     "seed": 1, "rule": "detail_guards",
     "about": "detail that trips (a lip), shares space, leaves a crawl slot or floats"},
    {"id": "F-crossing-feet", "brief": {"family": "explore", "size": "large",
                                        "features": {"want": ["river"]}},
     "seed": 5, "rule": "crossing_feet",
     "about": "a crossing's post or deck end, or a climbing pole, standing on nothing"},
]
def pairs():
    out = []
    for fam in FAMILIES:
        for seed in (1, 2, 3):
            out.append({"id": "P-%s-d%d" % (fam, seed), "brief": {"family": fam}, "seed": seed,
                        "kind": "pair"})
        for i, text in enumerate(RICH[fam]):
            out.append({"id": "P-%s-w%d" % (fam, i + 1), "wish": text, "family": fam, "seed": 1,
                        "kind": "pair"})
    for f in FINDINGS:
        out.append(dict(f, kind="finding"))
    from .metrics import v1 as mv1
    for key in mv1.VENUE_KEYS:
        out.append({"id": "V-%s" % key, "venue": key, "kind": "venue"})
    return out
def _brief_of(pair):
    if pair.get("wish"):
        from . import wish
        brief = dict(wish.parse(pair["wish"])[0])
        if pair.get("family"):
            brief["family"] = pair["family"]
    else:
        brief = dict(pair["brief"])
    brief.setdefault("brief", 1)
    brief.setdefault("candidates", 2)
    brief["seed"] = pair["seed"]
    return brief
_BUILT = {}
def build(pair):
    if pair["kind"] == "venue":
        from .metrics import v1 as mv1
        return mv1.venue(pair["venue"])
    from . import api
    import copy
    key = json.dumps([_brief_of(pair), pair["seed"]], sort_keys=True)
    if key not in _BUILT:
        _BUILT.clear()
        _BUILT[key] = api.generate(_brief_of(pair), seed=pair["seed"])
    return copy.deepcopy(_BUILT[key])
def dhash(img, n=8):
    g = img.convert("L").resize((n + 1, n))
    px = list(g.getdata())
    bits = 0
    for y in range(n):
        for x in range(n):
            bits = (bits << 1) | (1 if px[y * (n + 1) + x] > px[y * (n + 1) + x + 1] else 0)
    return "%016x" % bits
def distance(a, b):
    if not a or not b:
        return None
    return bin(int(a, 16) ^ int(b, 16)).count("1")
def finding_count(rule, arena):
    from . import contract, guards
    if rule == "foliage_or_fabric_on_built":
        return sum(1 for i in contract.issues(arena) if i["refused"] and
                   i["family"] in ("foliage", "fabric"))
    if rule == "stairs":
        fam = arena.get("family")
        return sum(1 for f in guards.flights(arena, guards.reach_set(arena))
                   if f["rule"] in guards.hard_rules(f["piece"], fam))
    if rule == "floating":
        return (len(guards.floating(arena)) + len(guards.floating_objects(arena))
                + len(guards.unsupported(arena)))
    if rule == "movers":
        return len(guards.mover_faults(arena))
    if rule == "lava":
        return len(guards.lava_faults(arena)[0])
    if rule == "staircase":
        from . import landscape
        share = landscape.land_measures(arena["pieces"])["one_layer_share"]
        return max(0, int(round((share - 0.7) * 10)))
    if rule == "overlaps":
        g = ((arena.get("report") or {}).get("guards") or {}).get("counts") or {}
        if "overlaps" in g:
            return int(g["overlaps"])
        return len(guards.interpenetrations(arena["pieces"]))
    if rule == "detail_guards":
        from . import detail
        return detail.guard_faults(arena)
    if rule == "crossing_feet":
        from . import crossings
        return crossings.feet_faults(arena)
    if rule == "pillar_gap":
        return sum(1 for j in guards.joins(arena) for p in (j["a"], j["b"])
                   if p.get("kind") == "pillar" and int(p["w"]) == 200 and int(p["d"]) == 200)
    return 0
def card(pair, arena, seconds=0.0):
    from . import contract, guards, shapeuse
    out = {"id": pair["id"], "kind": pair["kind"], "seconds": round(seconds, 1)}
    if arena is None:
        out["refused"] = 1
        return out
    theme = "castle" if pair["kind"] == "venue" else contract.theme_for(_brief_of(pair))
    rep = arena.get("report") or {}
    g = (rep.get("guards") or {}).get("counts")
    if g is None:
        g = guards.gate(arena, theme)["counts"]
    su = shapeuse.measure(arena)
    out.update({"refused": 0, "pieces": len(arena["pieces"]),
                "escapes": len(rep.get("escapes") or []),
                "quality": (arena.get("generator") or {}).get("quality") or rep.get("quality"),
                "kinds_used": su["kinds_used"], "fit_coverage": su["fit_coverage"],
                "non_box_share": su["non_box_share"], "forced": su["forced"]})
    for k in ("contract_refused", "cuts", "stairs", "floating", "movers", "overlaps", "lava",
              "pockets",
              "contract_warn",
              "joins", "movement", "stairs_soft"):
        out[k] = int(g.get(k) or 0)
    if pair["kind"] == "finding":
        out["finding"] = finding_count(pair["rule"], arena)
    try:
        from . import critic
        res = arena.get("critic") or critic.judge(arena, arena.get("family"))
        out["critic"] = res["score"]
        out["critic_worst"] = res["worst"]
    except Exception:
        out["critic"] = None
    try:
        from .render import top_down
        out["phash"] = dhash(top_down(arena, size=256, legend=False))
    except Exception:
        out["phash"] = None
    return out
def picture(arena, path, focus=None):
    from .render import raster
    if focus is not None:
        import numpy as np
        x, y, z = focus
        cam = raster.Camera(np.array((x + 1400.0, y + 1100.0, z + 1400.0)),
                            np.array((float(x), float(y), float(z))), raster.FOV)
    else:
        cam = raster.far_cameras(arena)[0]
    img = raster.render(arena, cam, size=(640, 360)).image()
    img.save(path)
    return path
def focus_of(pair, arena):
    rule = pair.get("rule")
    want = {"foliage_or_fabric_on_built": ("house", "cottage", "landmark", "tower"),
            "floating": ("play.cannon", "play.lift"), "movers": ("road",),
            "stairs": ("slope", "house", "hills", "spire", "pond"),
            "pillar_gap": ("pillar", "gate", "lanes")}.get(rule, ())
    for p in arena.get("pieces") or []:
        t = str(p.get("tag", "")).lower()
        if t.startswith(want) or (rule == "pillar_gap" and p.get("kind") == "pillar") or \
                (rule == "stairs" and p.get("kind") == "stairs"):
            return (p["x"], p["y"], p["z"])
    return None
def run(only=None, out=None, pictures=False, log=print):
    cards = {}
    for pair in pairs():
        if only and pair["id"] not in only:
            continue
        t0 = time.time()
        try:
            arena = build(pair)
        except Exception as why:
            log("%s: refused (%s)" % (pair["id"], str(why)[:120]))
            arena = None
        c = card(pair, arena, time.time() - t0)
        cards[pair["id"]] = c
        log("%-22s %s" % (pair["id"], " ".join("%s=%s" % (k, c.get(k)) for k in HARD
                                                  if c.get(k))))
        if out and arena is not None:
            os.makedirs(out, exist_ok=True)
            with open(os.path.join(out, "%s.layout.json" % pair["id"]), "w") as fh:
                json.dump({k: v for k, v in arena.items() if k != "report"}, fh, default=str)
            try:
                from . import critic
                critic.thumbnail(arena, os.path.join(out, "%s-thumb.png" % pair["id"]))
            except Exception as why:
                log("  thumbnail: %s" % why)
        if out and arena is not None and pictures:
            os.makedirs(out, exist_ok=True)
            try:
                picture(arena, os.path.join(out, "%s-far.png" % pair["id"]))
                f = focus_of(pair, arena) if pair["kind"] == "finding" else None
                if f:
                    picture(arena, os.path.join(out, "%s-near.png" % pair["id"]), f)
            except Exception as why:
                log("  picture: %s" % why)
    if out:
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "gallery.json"), "w") as fh:
            json.dump(cards, fh, indent=1, sort_keys=True)
    return cards
def load_accepted():
    try:
        with open(ACCEPTED) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {"accepted": {}}
def compare(cards, accepted=None):
    acc = (accepted or load_accepted()).get("accepted") or {}
    bad, lines = [], []
    for pid, c in sorted(cards.items()):
        a = acc.get(pid)
        if a is None:
            lines.append("%s: new (no accepted state)" % pid)
            continue
        for k in HARD:
            if (c.get(k) or 0) > (a.get(k) or 0):
                bad.append("%s: %s rose %s -> %s" % (pid, k, a.get(k) or 0, c.get(k)))
        soft = []
        for k in SOFT:
            if c.get(k) != a.get(k) and c.get(k) is not None and a.get(k) is not None:
                soft.append("%s %s -> %s" % (k, a.get(k), c.get(k)))
        d = distance(c.get("phash"), a.get("phash"))
        if d is not None and d > PHASH_NEAR:
            soft.append("picture changed (%d of 64 bits)" % d)
        if soft:
            lines.append("%s: %s" % (pid, "; ".join(soft)))
    return bad, lines
def accept(cards, note=""):
    data = load_accepted()
    acc = data.setdefault("accepted", {})
    acc.update(cards)
    data["note"] = note or data.get("note", "")
    data["accepted_at"] = time.strftime("%Y-%m-%d")
    os.makedirs(os.path.dirname(ACCEPTED), exist_ok=True)
    with open(ACCEPTED, "w") as fh:
        json.dump(data, fh, indent=1, sort_keys=True)
        fh.write("\n")
    return ACCEPTED
def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(prog="python3 tools/mapgen gallery",
                                 description="The regression gallery with a ratchet: a hard-guard "
                                 "regression blocks, soft scores only report.")
    ap.add_argument("command", choices=("run", "check", "accept", "list"))
    ap.add_argument("--only", nargs="*", help="pair ids")
    ap.add_argument("--out", default=None, help="output folder (cards and pictures)")
    ap.add_argument("--pictures", action="store_true", help="render a far and a near view")
    ap.add_argument("--from", dest="src", default=None,
                    help="accept: the cards of a run (gallery.json) instead of a new run")
    ap.add_argument("--note", default="", help="accept: why the line moves")
    a = ap.parse_args(argv)
    if a.command == "list":
        for p in pairs():
            print("%-22s %-8s %s" % (p["id"], p["kind"], p.get("wish") or p.get("about") or
                                     p.get("brief") or p.get("venue")))
        return 0
    if a.command == "accept" and a.src:
        with open(a.src) as fh:
            cards = json.load(fh)
    else:
        cards = run(set(a.only) if a.only else None, a.out, a.pictures)
    if a.command == "accept":
        print("accepted %d pairs -> %s" % (len(cards), accept(cards, a.note)))
        return 0
    bad, lines = compare(cards)
    for line in lines:
        print("  soft  " + line)
    for line in bad:
        print("  HARD  " + line)
    print("gallery: %d pairs, %d hard regressions" % (len(cards), len(bad)))
    return 1 if (bad and a.command == "check") else 0
if __name__ == "__main__":
    sys.exit(main())
