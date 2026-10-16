import copy
import math
import re
from . import anchors as anchormod
from . import api, checks
from . import generate as gen
from . import wish as wishmod
from .brief import Brief, SIZES
HELP = """Refinement - talk to the engine, change only what was asked.

Every op works on the previous brief + layout and rebuilds the SAME candidate
with the same seed streams, so whatever the op does not touch draws the same
numbers and comes out the same; the result says which modules moved and why.

  op                     DE / EN                                  how
  reseed(module)         "andere Mitte", "another centre"         that module's stream advances
  set(field, value)      "mehr Vertikalitaet", "16 Spieler", "Eis"   a brief field
  more/less(axis)        "offener", "mehr Deckung", "hoeher"      a dial one step (with a  
                         "Mitte offener" (a region)               region, a nudge: the region's
                                                                  module re-rolled until the axis
                                                                  moves, the rest kept)
  resize(target, f)      "Mitte groesser", "map smaller"          the map's size one step; the
                                                                  centre's anchor sized
  move(anchor, dir, n)   "Spawn weiter nach Norden",              the anchor's solved point
                         "move the tower east by 800"             shifted (400 a step)
  swap(a, b)             "statt Krone eine Grube",                same place, other thing
                         "a pit instead of the crown"
  add(anchor)            "noch ein Turm im Osten"                 a new anchor (locks bind it)
  remove(thing)          "ohne Bruecken", "remove the tower"      anchors dropped + feature avoided
  lock(region)           "lass die Basen so", "lock the north"    the region's pieces copied
                                                                  verbatim from before
  retexture(role|theme)  "Boden in Eis", "Thema Wueste"           textures only; the geometry is
                                                                  checked to be unchanged
  objects                "ein paar Goombas auf die Bruecke"       Forge objects added

Anchors already solved keep their solved points (pinned), so adding a tower
does not shuffle the bridge.
"""
RESEED_WORDS = [
    (r"andere(n)? mitte|another (centre|center|middle)|neue mitte|new (centre|center|middle)|"
     r"different (centre|center|middle)", "centre"),
    (r"andere(n)? (basen|bastionen)|other bases|new bases|different bases", "unit"),
    (r"andere(n)? deckung|other cover|new cover|different cover", "fill"),
    (r"andere(n)? (groesse|form)|other (size|shape)", "frame"),
    (r"(nochmal|neu) wuerfeln|reroll|re-roll|noch eine variante|another one|try again",
     "frame"),
]
REGIONS = {
    "centre": (r"\bmitte\b|\bmiddle\b|\bcent(re|er)\b|\bzentrum\b", "centre", {"compass": "c"}),
    "bases": (r"\bbasen\b|\bbases\b|\bbastionen\b", "unit", {"edge": "ring"}),
    "n": (r"\bnorden\b|\bnorth\b", None, {"compass": "n"}),
    "s": (r"\bsueden\b|\bsouth\b", None, {"compass": "s"}),
    "e": (r"\bosten\b|\beast\b", None, {"compass": "e"}),
    "w": (r"\bwesten\b|\bwest\b", None, {"compass": "w"}),
}
DIRS = {"n": (0, -1), "s": (0, 1), "e": (1, 0), "w": (-1, 0), "ne": (1, -1), "nw": (-1, -1),
        "se": (1, 1), "sw": (-1, 1)}
DIR_WORDS = [(r"nord.?west\w*|north.?west\w*", "nw"), (r"nord.?ost\w*|north.?east\w*", "ne"),
             (r"sued.?west\w*|south.?west\w*", "sw"), (r"sued.?ost\w*|south.?east\w*", "se"),
             (r"\bnord\w*|\bnorth\w*|\bnach oben\b|\bup\b", "n"),
             (r"\bsued\w*|\bsouth\w*|\bnach unten\b|\bdown\b", "s"),
             (r"\bost\w*|\beast\w*|\bnach rechts\b|\bright\b", "e"),
             (r"\bwest\w*|\bnach links\b|\bleft\b", "w"),
             (r"\b(zur|in die|to the|towards the) mitte\b|\btowards the (centre|center|middle)\b",
              "c")]
WHAT_WORDS = [(r"world.?spawn|weltspawn|eingang|entry", "world_spawn"),
              (r"\bspawns?\b", "spawns"), (r"t(ue|u)rm\w*|towers?", "tower"),
              (r"br(ue|u)cke\w*|bridges?", "bridge"), (r"\bgrube\w*|\bpits?\b", "pit"),
              (r"\bkrone\b|\bcrown\b", "crown"), (r"huegel\w*|\bhills?\b", "hill"),
              (r"\bplatz\b|\bplaza\b", "plaza"), (r"\bbasen?\b|\bbases?\b", "base"),
              (r"perch\w*|aussichtspunkt\w*", "perch"), (r"rampen?|ramps?", "ramp")]
STEP = 400
def _what(text):
    for pat, w in WHAT_WORDS:
        if re.search(pat, text):
            return w
    return None
def _dir(text):
    for pat, d in DIR_WORDS:
        if re.search(pat, text):
            return d
    return None
def parse_ops(text, brief=None):
    low = wishmod.fold(text or "")
    P = None
    if wishmod.LEXICON:
        from . import lexicon
        P = lexicon.prepare(low, "refine")
        low = P.low
    ops, later, consumed = [], [], []
    def took(m):
        if m:
            consumed.append(m.group(0))
    m = re.search(r"(lass|lasse|behalte|keep|lock|sperr\w*|fixier\w*)\s+(die |den |das |the )?"
                  r"(\w+)(\s+(so|wie sie sind|as (it is|they are)))?", low)
    if m and re.search(r"\b(lass|lasse|behalte|keep|lock|sperr|fixier)", low):
        region = None
        for name, (pat, prefix, where) in REGIONS.items():
            if re.search(pat, m.group(0)):
                region = name
        if region:
            ops.append(("lock", region))
            took(m)
    m = re.search(r"statt (der |des |dem |einer? |the )?(\w+)\s+(eine?n?|a|an)?\s*(\w+)", low) or \
        re.search(r"(\w+) instead of (the |a |an )?(\w+)", low) or \
        re.search(r"(ersetze|replace) (die |den |das |the )?(\w+) (durch|with) (eine?n? |a |an )?(\w+)",
                  low)
    if m:
        g = [x for x in m.groups() if x]
        if "instead" in m.group(0):
            new, old = _what(m.group(1)), _what(m.group(3))
        elif m.group(0).startswith(("ersetze", "replace")):
            old, new = _what(g[2] if len(g) > 2 else ""), _what(g[-1])
        else:
            old, new = _what(m.group(2)), _what(m.group(4))
        if old and new and old != new:
            ops.append(("swap", old, new))
            took(m)
    m = re.search(r"(\w[\w\- ]*?)\s+(weiter |ein stueck |etwas )?(nach|richtung|towards?)\s+"
                  r"(\w+)(\s+(um|by)\s+(\d+))?", low) or \
        re.search(r"(move|verschieb\w*|setz\w*)\s+(the |den |die |das )?([\w\- ]+?)\s+"
                  r"(\w+)(\s+(um|by)\s+(\d+))?$", low)
    if m:
        what = _what(m.group(0))
        d = _dir(m.group(0)[len(m.group(1)) if m.group(1) and _what(m.group(1)) else 0:])
        if what and d:
            amount = int(m.group(7)) if m.group(7) else STEP
            ops.append(("move", what, d, amount))
            took(m)
    m = re.search(r"(mitte|middle|centre|center|map|karte|arena|insel|island)\s+(\w+\s+)?"
                  r"(groesser|bigger|larger|kleiner|smaller)|"
                  r"(groesser|bigger|larger|kleiner|smaller)e?n?\s+(mitte|middle|centre|center|"
                  r"map|karte|arena)|make the (middle|centre|center|map) (bigger|smaller)", low)
    if m:
        word = m.group(0)
        target = "centre" if re.search(r"mitte|middle|centre|center|insel|island", word) else "map"
        f = 1.25 if re.search(r"groesser|bigger|larger", word) else 0.8
        ops.append(("resize", target, f))
        took(m)
    m = re.search(r"(mitte|middle|centre|center|norden|north|sueden|south|osten|east|westen|"
                  r"west)\w*\s+(\w+\s+)?(offener|more open|enger|tighter|hoeher|higher|"
                  r"flacher|flatter)|(offener|more open|mehr deckung|more cover|hoeher|higher)"
                  r"\s+(in der |im |in the )?(mitte|middle|centre|center|norden|north|sueden|"
                  r"south|osten|east|westen|west)", low)
    if m:
        word = m.group(0)
        region = next((n for n, (pat, _, _) in REGIONS.items() if re.search(pat, word)), "centre")
        axis, sign = ("openness", 1) if re.search(r"offener|more open", word) else \
            ("openness", -1) if re.search(r"enger|tighter|deckung|cover", word) else \
            ("verticality", 1 if re.search(r"hoeher|higher", word) else -1)
        ops.append(("nudge", region, axis, sign))
        took(m)
    for m in re.finditer(r"(ohne|keine?n?|kein|no|remove|entfern\w*|weg mit|nimm)\s+(die |den |"
                         r"das |the )?(\w+)(\s+(mehr|weg|raus|anymore))?", low):
        what = _what(m.group(3))
        if what and not any(op[0] == "swap" for op in ops):
            ops.append(("remove", what))
            took(m)
    for pat, module in RESEED_WORDS:
        m = re.search(pat, low)
        if m:
            ops.append(("reseed", module))
            took(m)
    m = re.search(r"(thema|theme|textur\w*|look)\s+(\w+)|(\w+)[- ](thema|theme|look)\b", low)
    if m:
        t, _ = wishmod._first(wishmod.THEME_WORDS, m.group(0))
        if t:
            ops.append(("retexture", "theme", t))
            took(m)
    rest = low
    for c in consumed:
        rest = rest.replace(c, " ")
    r = wishmod._understand(rest, base=brief.to_dict() if brief is not None else None,
                            scope="refine", P=P)
    raw = r.raw
    nudged = any(op[0] in ("nudge",) for op in ops)
    for k in ("players", "size", "pace", "theme", "verticality", "density", "symmetry",
              "level", "family", "sides", "edge", "difficulty", "style", "sky", "music",
              "palette", "budget", "name", "dials"):
        if k in raw and not (nudged and k in ("density", "verticality")):
            if k == "theme" and any(op[0] == "retexture" for op in ops):
                continue
            if k == "palette":
                ops.append(("retexture", "palette", raw[k]))
            elif k == "theme":
                ops.append(("retexture", "theme", raw[k]))
            else:
                ops.append(("set", k, raw[k]))
    for a in raw.get("anchors", []):
        if not any(op[0] in ("move", "swap") and op[1] == a["what"] for op in ops):
            ops.append(("add", a))
    if raw.get("novelty"):
        ops.append(("novelty", raw["novelty"]))
    if raw.get("objects"):
        ops.append(("objects", raw["objects"]))
    if "features" in raw:
        ops.append(("features", raw["features"]))
    am = dict(raw.get("amounts") or {})
    if text:
        from . import lexicon
        avoid = set((raw.get("features") or {}).get("avoid") or [])
        for k, v in lexicon.amounts(wishmod.fold(text).replace("_", " ")).items():
            if k not in avoid:
                am.setdefault(k, v)
    if am:
        ops.append(("amounts", am))
    not_understood = list(r.not_understood)
    if not ops and text and text.strip():
        later.append("%r: no change found in it" % text)
    return ops, later, not_understood, r
def _raw(brief):
    raw = {k: v for k, v in brief.to_dict().items() if k not in brief.defaulted}
    raw.pop("defaulted", None)
    raw["seed"] = brief["seed"]
    return raw
def _step(value, table, up):
    i = table.index(value) if value in table else len(table) // 2
    return table[max(0, min(len(table) - 1, i + (1 if up else -1)))]
def apply(brief, ops, solved=None):
    raw = _raw(brief)
    why = []
    raw.setdefault("reseed", {})
    anchors = [dict(a) for a in raw.get("anchors") or []]
    for a in anchors:
        got = (solved or {}).get(a.get("id"))
        if got and "pin" not in a:
            a["pin"] = [got[0]["x"], got[0]["z"]]
    for op in ops:
        kind = op[0]
        if kind == "reseed":
            raw["reseed"] = dict(raw.get("reseed") or {})
            raw["reseed"][op[1]] = raw["reseed"].get(op[1], 0) + 1
            why.append("reseed %s: only its stream advanced" % op[1])
        elif kind == "set":
            raw[op[1]] = op[2]
            why.append("set %s = %s" % (op[1], op[2]))
        elif kind == "retexture":
            if op[1] == "theme":
                raw["theme"] = op[2]
                why.append("theme %s: textures and look only" % op[2])
            else:
                pal = dict(raw.get("palette") or {})
                pal.update(op[2])
                raw["palette"] = pal
                why.append("palette %s: textures only" % op[2])
        elif kind == "add":
            a = dict(op[1], added=True)
            a.setdefault("id", "%s%d" % (a["what"], 1 + sum(1 for x in anchors
                                                           if x["what"] == a["what"])))
            while any(x.get("id") == a["id"] for x in anchors):
                a["id"] += "b"
            anchors.append(a)
            why.append("add %s %s" % (a["what"], a.get("where")))
        elif kind == "remove":
            before = len(anchors)
            anchors = [a for a in anchors if a["what"] != op[1]]
            f = raw.get("features") or {"want": [], "avoid": []}
            feat = {"tower": "tower", "bridge": "bridge", "pit": "pit", "crown": "crown",
                    "plaza": "plaza", "perch": "perches", "ramp": "ramps"}.get(op[1])
            if feat:
                raw["features"] = {"want": [x for x in f["want"] if x != feat],
                                   "avoid": sorted(set(f["avoid"]) | {feat})}
            why.append("remove %s: %d anchor(s) dropped%s" % (
                op[1], before - len(anchors), ", feature avoided" if feat else ""))
        elif kind == "novelty":
            raw["novelty"] = dict(op[1])
            why.append("novelty %s%s: the next map differs from the ones made before" % (
                op[1].get("mode"), (" (" + ", ".join(op[1]["avoid"]) + ")")
                if op[1].get("avoid") else ""))
        elif kind == "swap":
            hit = [a for a in anchors if a["what"] == op[1]]
            for a in hit:
                a["what"] = op[2]
                a.pop("pin", None)
                a["id"] = a["id"].replace(op[1], op[2], 1)
            f = raw.get("features") or {"want": [], "avoid": []}
            f = {"want": [x for x in f["want"] if x != op[1]] + [op[2]],
                 "avoid": sorted(set(f["avoid"]) | {op[1]} - {op[2]})}
            if not hit:
                anchors.append({"what": op[2], "where": {"compass": "c"}, "id": op[2] + "1",
                                "added": True})
            raw["features"] = f
            why.append("swap %s -> %s in the same place" % (op[1], op[2]))
        elif kind == "move":
            what, d, amount = op[1], op[2], op[3]
            hit = [a for a in anchors if a["what"] == what or (what == "spawns" and
                                                                a["what"] == "spawn")]
            if what == "world_spawn" or (what in ("spawns", "spawn") and not hit):
                continue
            if not hit:
                why.append("move %s: there is no %s anchor to move" % (what, what))
                continue
            for a in hit:
                got = (solved or {}).get(a.get("id"))
                if got:
                    x, z = got[0]["x"], got[0]["z"]
                else:
                    c = a.get("where", {}).get("compass", "c")
                    vec = anchormod.COMPASS_VEC.get(c, (0, 0))
                    x, z = vec[0] * 2800, vec[1] * 2800
                if d == "c":
                    n = math.hypot(x, z) or 1.0
                    dx, dz = -x / n, -z / n
                else:
                    dx, dz = DIRS[d]
                    n = math.hypot(dx, dz)
                    dx, dz = dx / n, dz / n
                nx, nz = int(round((x + dx * amount) / 100.0)) * 100, \
                    int(round((z + dz * amount) / 100.0)) * 100
                a["asked"] = a.get("where")
                a["where"] = {"x": nx, "z": nz}
                a.pop("pin", None)
                a["once"] = True if a["what"] not in ("spawns",) else a.get("once", False)
                why.append("move %s %s by %d: (%d, %d) -> (%d, %d)" % (a.get("id"), d, amount,
                                                                      x, z, nx, nz))
        elif kind == "resize":
            if op[1] == "map":
                cur = raw.get("size", "medium")
                if isinstance(cur, str):
                    raw["size"] = _step(cur, list(SIZES), op[2] > 1)
                elif "w" in cur and "d" in cur:
                    raw["size"] = {k: int(round(cur[k] * op[2] / 100.0)) * 100
                                   for k in ("w", "d")}
                elif "aspect" in cur and "across" not in cur:
                    raw["size"] = dict(cur, tier=_step(cur.get("tier") or "medium",
                                                       list(SIZES), op[2] > 1))
                else:
                    k = "across" if "across" in cur else "across_s"
                    raw["size"] = {k: round(cur[k] * op[2], 1)}
                    if "aspect" in cur and k == "across":
                        raw["size"]["aspect"] = cur["aspect"]
                why.append("resize the map to %s" % raw["size"])
            else:
                hit = [a for a in anchors if a.get("where", {}).get("compass") == "c"]
                for a in hit:
                    a["size"] = _step(a.get("size", "medium"), list(SIZES), op[2] > 1)
                if not hit:
                    anchors.append({"what": "centre", "where": {"compass": "c"}, "id": "centre1",
                                    "size": "large" if op[2] > 1 else "small", "added": True})
                raw["reseed"] = dict(raw.get("reseed") or {})
                raw["reseed"]["centre"] = raw["reseed"].get("centre", 0) + 1
                why.append("resize the centre x%.2f: its anchor sized, its stream re-rolled "
                           "(the rest keeps its streams)" % op[2])
        elif kind == "lock":
            locks = list(raw.get("locks") or [])
            lk = {"region": op[1]}
            if lk not in locks:
                locks.append(lk)
            raw["locks"] = locks
            why.append("lock %s: copied verbatim from before" % op[1])
        elif kind == "nudge":
            why.append("nudge %s %s %s: the region's module re-rolled until the axis moves"
                       % (op[1], op[2], "up" if op[3] > 0 else "down"))
        elif kind == "objects":
            raw["objects"] = list(raw.get("objects") or []) + op[1]
            why.append("objects +%s" % ", ".join("%s x%d" % (o["key"], o.get("count", 1))
                                                  for o in op[1]))
        elif kind == "features":
            f = raw.get("features") or {"want": [], "avoid": []}
            raw["features"] = {"want": sorted((set(f["want"]) | set(op[1]["want"]))
                                              - set(op[1]["avoid"])),
                               "avoid": sorted((set(f["avoid"]) | set(op[1]["avoid"]))
                                               - set(op[1]["want"]))}
            why.append("features %s" % op[1])
            if raw.get("amounts"):
                raw["amounts"] = {k: v for k, v in raw["amounts"].items()
                                  if k not in op[1]["avoid"]}
        elif kind == "amounts":
            am = dict(raw.get("amounts") or {})
            am.update(op[1])
            raw["amounts"] = am
            why.append("amounts %s" % ", ".join("%s %s" % (v, k) for k, v in sorted(op[1].items())))
    raw["anchors"] = anchors
    return Brief.from_dict(raw), why
def _build(brief, index, use_metrics):
    raw = api.raw_of(brief)
    sol = anchormod.solve(raw)
    fam, _ = api.lenient(api.family_brief(raw, sol))
    cand = gen.build_candidate(fam, index, use_metrics)
    lines = []
    if cand.ok:
        lines = api.postprocess(cand.arena, brief, sol)
    return cand, sol, lines
def _region_pred(region, arena_like):
    _, _, where = REGIONS.get(region, (None, None, {"compass": region}))
    from . import place
    return place.region_filter(where, arena_like)
def _inside(pred, p):
    return pred(p["x"], p["z"], p)
def refine(brief, candidate_index, ops, use_metrics=True, old_layout=None):
    solved = (old_layout or {}).get("report", {}).get("anchors_solved")
    before, _, _ = _build(brief, candidate_index, use_metrics=False)
    new_brief, why = apply(brief, ops, solved)
    short = []
    after, sol, lines = _build(new_brief, candidate_index, use_metrics)
    reseeds = [op for op in ops if op[0] == "reseed"]
    tries = 0
    while reseeds and tries < 8 and not changed_modules(before, after):
        new_brief, _ = apply(new_brief, reseeds)
        after, sol, lines = _build(new_brief, candidate_index, use_metrics)
        tries += 1
    for op in list(ops):
        if op[0] == "resize" and op[1] == "centre":
            op = ("nudge", "centre", "centre_area", 1 if op[2] > 1 else -1)
        if op[0] != "nudge":
            continue
        module = REGIONS.get(op[1], (None, "centre", None))[1] or "fill"
        base_val = _axis(before.arena, op[2])
        best = (None, None)
        trial = new_brief
        for k in range(1, 9):
            rs = dict(trial["reseed"])
            rs[module] = rs.get(module, 0) + 1
            trial = trial.with_changes(reseed=rs)
            cand, s2, l2 = _build(trial, candidate_index, use_metrics)
            if not cand.ok:
                continue
            gain = (_axis(cand.arena, op[2]) - base_val) * op[3]
            if best[0] is None or gain > best[0]:
                best = (gain, (trial, cand, s2, l2))
        if best[1] is not None and best[0] > 0:
            new_brief, after, sol, lines = best[1]
            why.append("nudge: %s %s by %+.3f (best of 8 re-rolls of %s)"
                       % (op[2], op[1], best[0] * op[3], module))
            if best[0] < NUDGE_SMALL:
                short.append("refine %s %s: the best of 8 re-rolls of %s moved it only "
                             "%+.3f - the frame round it holds the rest" % (
                                 op[1], op[2], module, best[0] * op[3]))
        else:
            why.append("nudge: no re-roll of %s moved %s the asked way; kept the map"
                       % (module, op[2]))
            short.append("refine %s %s: no re-roll of %s moved it the asked way" % (
                op[1], op[2], module))
    want_cover = _cover_way(ops)
    if want_cover:
        had = cover_count(before.arena)
        now = cover_count(after.arena)
        if (now - had) * want_cover <= 0:
            trial = new_brief
            for k in range(1, 9):
                rs = dict(trial["reseed"])
                rs["fill"] = rs.get("fill", 0) + 1
                trial = trial.with_changes(reseed=rs)
                cand, s2, l2 = _build(trial, candidate_index, use_metrics)
                if cand.ok and (cover_count(cand.arena) - had) * want_cover > 0:
                    new_brief, after, sol, lines = trial, cand, s2, l2
                    now = cover_count(after.arena)
                    break
        word = "more" if want_cover > 0 else "less"
        if (now - had) * want_cover > 0:
            why.append("cover: %d pieces of cover before, %d now" % (had, now))
        else:
            short.append("refine %s cover: not built - the %s map's cover came out %d pieces "
                         "before and %d after, and no re-roll of its fill gave %s (%s)"
                         % (word, brief["family"], had, now, word,
                            "its free floor keeps every passage 500 clear and the spawns, "
                            "flags and ramps free" if want_cover > 0 else
                            "its family's own cover is part of its build"))
    lock_lines = {}
    for lk in new_brief["locks"]:
        if not isinstance(lk, dict) or "region" not in lk:
            continue
        pred = _region_pred(lk["region"], before.arena)
        if pred is None:
            continue
        kept = [p for p in before.arena["pieces"] if _inside(pred, p)]
        fresh = [p for p in after.arena["pieces"] if not _inside(pred, p)]
        from . import solids
        painted, _ = solids.resolve([dict(p) for p in fresh + kept])
        trial = dict(after.arena, pieces=painted)
        res = checks.run(trial)
        if res.ok:
            after.arena["pieces"] = trial["pieces"]
            why.append("lock %s: the %s %s kept as %s (%d pieces kept verbatim)"
                       % (lk["region"], lk["region"],
                          *(("are", "they were") if str(lk["region"]).endswith("s")
                            else ("is", "it was")), len(kept)))
            lock_lines["lock %r:" % (lk,)] = None
        else:
            why.append("lock %s: the kept pieces do not fit the new map (%s) - not applied"
                       % (lk["region"], "; ".join(res.faults[:2])))
            lock_lines["lock %r:" % (lk,)] = "lock %s: not applied - the kept pieces do not " \
                "fit the new map" % lk["region"]
    for op in ops:
        if op[0] != "move" or op[1] not in ("spawns", "spawn", "world_spawn"):
            continue
        if op[1] == "world_spawn":
            why.append(_slide(after.arena, op[2], op[3]))
        elif not any(a["what"] in ("spawns", "spawn") for a in brief["anchors"]):
            why.append(_shift_spawns(after.arena, op[2], op[3]))
    if ops and all(op[0] == "retexture" for op in ops):
        from . import cells
        same = cells.same_geometry(before.arena["pieces"], after.arena["pieces"]) \
            if hasattr(cells, "same_geometry") else None
        why.append("retexture: geometry %s" % ("unchanged" if same else
                                                "CHANGED (the theme's transition blocks)"
                                                if same is False else "not compared"))
    result = gen.Result(new_brief, [after], after)
    changed = changed_modules(before, after)
    targets = set()
    for op in ops:
        if op[0] == "reseed":
            targets.add(op[1])
        elif op[0] in ("swap", "resize") or (op[0] == "nudge" and op[1] == "centre"):
            targets.add("centre")
    if targets and changed:
        extra = [c for c in changed if not any(c.startswith(t) for t in targets)]
        if extra:
            why.append("moved with it: %s (they give way to what changed next to them)"
                       % ", ".join(extra))
    structural = [op for op in ops if op[0] not in ("lock", "objects", "move", "retexture")]
    if structural and not changed:
        why.append("no module came out different: the family builds this the same way "
                   "(the anchors' lines say what it made of each)")
    rep = after.arena.setdefault("report", {})
    rep["moved"] = changed
    rep["refine"] = why
    np = rep.setdefault("not_possible", [])
    for head, instead in lock_lines.items():
        np[:] = [instead if line.startswith(head) else line for line in np
                 if instead is not None or not line.startswith(head)]
    for line in short:
        if line not in np:
            np.append(line)
    return result, changed
NUDGE_SMALL = 0.1
def _cover_way(ops):
    for op in ops:
        if op[0] == "amounts" and isinstance(op[1], dict) and op[1].get("cover_walls"):
            v = op[1]["cover_walls"]
            return 1 if v in ("more", "lots") else -1 if v in ("less", "few", "trace") else 0
    return 0
def cover_count(arena):
    from . import contract
    words = set(contract._COVER)
    n = 0
    for p in arena.get("pieces") or []:
        ws = set(str(p.get("tag", "")).lower().replace(".", " ").replace("_", " ").split())
        if ws & words:
            n += 1
    return n
def _unit(d):
    if d == "c":
        return None
    dx, dz = DIRS[d]
    n = math.hypot(dx, dz)
    return dx / n, dz / n
def _slide(arena, d, amount):
    from . import v1
    u = _unit(d)
    if u is None:
        return "move world spawn to the middle: give a compass direction"
    tx, tz = -u[0] * amount, -u[1] * amount
    m = v1.arenas_module()
    moved = [dict(p, x=p["x"] + tx, z=p["z"] + tz) for p in arena["pieces"]]
    if not m.standable(moved, 0, 0, arena["level"]):
        return "move world spawn %s by %d: refused - the origin would stand on nothing" % (
            d, amount)
    trial = dict(arena, pieces=moved,
                 spawns=[dict(s, x=s["x"] + tx, z=s["z"] + tz) for s in arena["spawns"]])
    sv = dict(arena.get("survey") or {})
    for k, rows in sv.items():
        if isinstance(rows, list):
            sv[k] = [dict(s, x=s["x"] + tx, z=s["z"] + tz) for s in rows]
        elif isinstance(rows, dict):
            sv[k] = dict(rows, x=rows["x"] + tx, z=rows["z"] + tz)
    trial["survey"] = sv
    if arena.get("objects"):
        trial["objects"] = [dict(o, x=o["x"] + tx, z=o["z"] + tz) for o in arena["objects"]]
    res = checks.run(trial)
    if not res.ok:
        return "move world spawn %s by %d: refused - %s" % (d, amount, "; ".join(res.faults[:2]))
    for k in ("pieces", "spawns", "survey", "objects"):
        if k in trial:
            arena[k] = trial[k]
    return "move world spawn %s by %d: the layout slid %+d x %+d z under the origin" % (
        d, amount, tx, tz)
def _shift_spawns(arena, d, amount):
    from . import v1
    u = _unit(d)
    if u is None:
        return "move spawns to the middle: give a compass direction"
    m = v1.arenas_module()
    keep = [dict(s) for s in arena["spawns"]]
    new, moved = [], 0
    for s in keep:
        x, z = s["x"] + u[0] * amount, s["z"] + u[1] * amount
        hs = m.standable(arena["pieces"], x, z, arena["level"])
        if hs:
            h = min(hs, key=lambda v: abs(v - s["y"]))
            new.append(dict(s, x=int(x), z=int(z), y=int(h)))
            moved += 1
        else:
            new.append(s)
    pts = list((arena.get("survey") or {}).get("points") or [])
    arena["spawns"] = new
    if pts:
        arena["survey"] = dict(arena["survey"], points=new + pts[len(keep):])
    res = checks.run(arena)
    if not res.ok:
        arena["spawns"] = keep
        if pts:
            arena["survey"] = dict(arena["survey"], points=pts)
        return "move spawns %s by %d: refused - %s" % (d, amount, "; ".join(res.faults[:2]))
    return "move spawns %s by %d: %d of %d stepped (the rest would stand on nothing)" % (
        d, amount, moved, len(keep))
def _axis(arena, axis):
    if axis == "centre_area":
        from . import place
        tot = 0.0
        for p in arena["pieces"]:
            if str(p.get("tag", "")).startswith("centre"):
                x0, x1, z0, z1 = place._foot(p)
                tot += (x1 - x0) * (z1 - z0)
        return tot / 1e6
    try:
        from .metrics import measure
        from .metrics import qd
        return qd.descriptors(measure.measure(arena, tier="full")).get(axis) or 0.0
    except Exception:
        return 0.0
def changed_modules(a, b):
    ta, tb = a.meta.get("module_pieces", {}), b.meta.get("module_pieces", {})
    return sorted(k for k in set(ta) | set(tb) if ta.get(k) != tb.get(k))
