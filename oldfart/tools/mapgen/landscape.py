from . import pcg
LAYER = 200
PRESETS = {
    "bergisch": {"risers": (2, 3, 2), "extra": 0, "words": ("hills", "rolling_hills", "bergisch",
                                                         "valley", "forest")},
    "alpine": {"risers": (3, 2, 3), "extra": 2, "words": ("mountains", "alpine", "glacier",
                                                         "peaks")},
    "mesa": {"risers": (3, 3), "extra": 2, "words": ("mesa", "canyon", "badlands", "desert_rock")},
    "islands": {"risers": (2, 2), "extra": 0, "words": ("islands", "island", "coast", "beach")},
    "plateau": {"risers": (4,), "extra": 1, "words": ("plateau", "tableland")},
}
PRESET_ORDER = ("bergisch", "alpine", "mesa", "islands", "plateau")
PRESET_WEIGHTS = {"bergisch": 4, "alpine": 2, "mesa": 1, "islands": 1, "plateau": 2}
THEME_PRESET = {"desert": "mesa", "lava": "alpine", "ice": "alpine"}
def preset_for(brief, rnd=None):
    want = set(((brief.get("features") or {}).get("want")) or ())
    for name in PRESET_ORDER:
        if want & set(PRESETS[name]["words"]):
            return name, "the wish asks (%s)" % ", ".join(sorted(want & set(PRESETS[name]["words"])))
    theme = brief.get("theme")
    if theme in THEME_PRESET:
        return THEME_PRESET[theme], "the %s theme" % theme
    if rnd is None:
        return "bergisch", "the default"
    total = sum(PRESET_WEIGHTS.values())
    x = rnd.random() * total
    for name in PRESET_ORDER:
        x -= PRESET_WEIGHTS[name]
        if x <= 0:
            return name, "the seed"
    return "bergisch", "the seed"
def band_levels(top, preset):
    p = PRESETS[preset]
    cap = top + p["extra"]
    out = [0]
    k = 0
    while True:
        r = p["risers"][k % len(p["risers"])]
        if out[-1] + r > cap:
            break
        out.append(out[-1] + r)
        k += 1
    if len(out) == 1 and cap >= 1:
        out.append(cap)
    return out
RAISED_MAX = 0.6
def band_plinths(plinth, top, levels, raised_max=RAISED_MAX):
    if top <= 0 or len(levels) <= 1:
        return dict(plinth)
    out = {}
    for d, v in plinth.items():
        if v <= 0:
            out[d] = 0
            continue
        q = v / float(top)
        out[d] = levels[min(len(levels) - 1, max(1, int(round(q * (len(levels) - 1)))))]
    raised = sorted((d for d in out if out[d] > 0), key=lambda d: (plinth[d], d))
    cap = int(raised_max * len(out))
    for d in raised[:max(0, len(raised) - cap)]:
        out[d] = 0
    return out
def settle_step(h, keep=(), step=1):
    keep = set(keep)
    todo = sorted(h)
    queued = set(todo)
    while todo:
        nxt = []
        for c in todo:
            queued.discard(c)
            if c in keep:
                continue
            for a, b in pcg.N4:
                m = (c[0] + a, c[1] + b)
                if m not in h:
                    continue
                if h[c] - h[m] > step:
                    h[c] = h[m] + step
                    for a2, b2 in pcg.N4:
                        k = (c[0] + a2, c[1] + b2)
                        if k in h and k not in queued:
                            queued.add(k)
                            nxt.append(k)
        todo = sorted(set(nxt))
    return h
HILL_RISER = 2
def band_hills(h, step=HILL_RISER, keep=()):
    keep = set(keep)
    n = 0
    for c in sorted(h):
        if c in keep or h[c] <= 0:
            continue
        v = (h[c] // step) * step
        if v != h[c]:
            h[c] = v
            n += 1
    return n
def climb_cells(ramps):
    step = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}
    out = set(ramps)
    for c, d in ramps.items():
        out.add((c[0] + step[d][0], c[1] + step[d][1]))
    return out
def clefts(owner, streets, sites, plinth, G1=None, count=None):
    by = {}
    for c, d in owner.items():
        if c not in streets:
            by.setdefault(d, set()).add(c)
    out = {}
    for d, cs in sorted(by.items()):
        if plinth.get(d, 0) <= 0 or d >= len(sites):
            continue
        want = count or (2 if len(cs) >= 120 else 1)
        start = tuple(sites[d])
        if start not in cs:
            start = min(cs, key=lambda c: (abs(c[0] - start[0]) + abs(c[1] - start[1]), c))
        prev = {start: None}
        todo = [start]
        exits = []
        while todo:
            nxt = []
            for c in todo:
                if any((c[0] + a, c[1] + b) in streets and
                       (G1 is None or G1.get((c[0] + a, c[1] + b), 0) < plinth.get(d, 0))
                       for a, b in pcg.N4):
                    exits.append(c)
                for a, b in pcg.N4:
                    m = (c[0] + a, c[1] + b)
                    if m in cs and m not in prev:
                        prev[m] = c
                        nxt.append(m)
            todo = sorted(nxt)
        if not exits:
            continue
        exits.sort(key=lambda c: (_depth(prev, c), c))
        chosen = [exits[0]]
        if want > 1 and len(exits) > 1:
            chosen.append(max(exits, key=lambda c: (abs(c[0] - exits[0][0])
                                                    + abs(c[1] - exits[0][1]), c)))
        for e in chosen:
            c = e
            while c is not None:
                if G1 is None or G1.get(c, 0) < plinth.get(d, 0):
                    out[c] = d
                c = prev[c]
            for a, b in pcg.N4:
                m = (e[0] + a, e[1] + b)
                if m in streets:
                    out[m] = d
                    break
    return out
def _depth(prev, c):
    n = 0
    while prev.get(c) is not None:
        c = prev[c]
        n += 1
    return n
def cliff_ground(G1, owner, streets, plinth, sites, step, keep=()):
    cl = clefts(owner, streets, sites, plinth, G1)
    fixed = set(keep) | set(cl)
    keep = set(keep) | set(streets) | set(cl)
    G = {}
    for c, d in owner.items():
        G[c] = G1[c] if c in keep else max(G1[c], plinth.get(d, 0))
    settle_step(G, keep=keep, step=step)
    snap_blocks(G, keep, fixed, SNAP)
    tidy(G, keep=keep)
    settle_step(G, keep=keep, step=step)
    return G, cl
SNAP = 2
def snap_blocks(G, keep, fixed=(), size=SNAP):
    if size <= 1:
        return 0
    fixed = set(fixed)
    blocks = {}
    for c in G:
        blocks.setdefault((c[0] // size, c[1] // size), []).append(c)
    n = 0
    for b in sorted(blocks):
        cs = blocks[b]
        vals = [G[c] for c in cs if c not in fixed]
        if not vals:
            continue
        lo = min(vals)
        for c in cs:
            if c not in keep and G[c] > lo:
                G[c] = lo
                n += 1
    return n
def tidy(G, keep=(), passes=3):
    keep = set(keep)
    for _ in range(passes):
        changed = 0
        for c in sorted(G):
            if c in keep:
                continue
            h = G[c]
            ns = [G[(c[0] + a, c[1] + b)] for a, b in pcg.N4 if (c[0] + a, c[1] + b) in G]
            if len(ns) < 4:
                continue
            same_or_up = sum(1 for v in ns if v >= h)
            higher = [v for v in ns if v > h]
            lower = [v for v in ns if v < h]
            if same_or_up < 2 and lower:
                G[c] = max(lower)
                changed += 1
            elif len(higher) >= 3:
                G[c] = min(higher)
                changed += 1
        if not changed:
            break
    return G
def strata(theme, n=3):
    from . import contract, kit
    rocks = [t for t in contract.members(theme, "fort_wall") if contract.family(t) == "rock"]
    if not rocks:
        rocks = [t for t in kit.textures() if contract.family(t) == "rock"]
    try:
        from . import values
        st = values.stats()
        rocks.sort(key=lambda t: (st.get(t, (0.5,))[0], t))
    except Exception:
        rocks.sort()
    if len(rocks) <= n:
        return rocks
    return [rocks[int(round(i * (len(rocks) - 1) / float(n - 1)))] for i in range(n)]
THEME_ROCK = {"garden": "rockmossy", "forest": "rockmossy", "village": "rockgrey",
              "desert": "sandstonelayered", "lava": "basaltcolumns", "ice": "frostrock",
              "sky": "rockgrey", "castle": "rockgrey", "wood": "rockbrown"}
def riser_tex(theme, level, have):
    from . import soft64
    base = soft64.to_kit(THEME_ROCK.get(theme, "rockgrey")) or THEME_ROCK.get(theme)
    seq = [t for t in strata(theme, 3) if t in have]
    if base in have and base not in seq:
        seq = [base] + seq
    if not seq:
        return None
    return seq[(level // 2) % len(seq)]
BIOMES = {
    "meadow": {"slope": ("dirt", "grass"), "proto": (0.1, 0.5, 0.25, 0.35), "top": ("grassmeadow", "grassflowers", "grass"),
               "riser": ("rockgrey", "greystone"),
               "inner": [("oak", 3), ("birch", 1)], "edge": [("bush", 2), ("birch", 1)],
               "sparse": [("oak", 3), ("birch", 2), ("bush", 2), ("broadleaf", 1)]},
    "forest": {"slope": ("dirtdark", "dirt"), "proto": (0.3, 0.75, 0.4, 0.2), "top": ("grasslush", "moss", "grass"),
               "riser": ("rockmossy", "mossyrock", "rockgrey"),
               "inner": [("oak", 3), ("broadleaf", 1), ("pine", 1)],
               "edge": [("birch", 2), ("bush", 2)],
               "sparse": [("oak", 2), ("birch", 2), ("bush", 1)]},
    "taiga": {"slope": ("pathgravel", "dirt"), "proto": (0.55, 0.5, 0.65, 0.2), "top": ("grassteal", "moss", "grass"),
              "riser": ("rockgrey", "greystone"),
              "inner": [("pine", 4), ("megapine", 1)], "edge": [("pine", 2), ("bush", 1)],
              "sparse": [("pine", 3), ("bush", 1)]},
    "steppe": {"slope": ("dirt", "sand"), "proto": (0.35, 0.2, 0.3, 0.7), "top": ("grassdry", "dirt", "sand"),
               "riser": ("dirtbrown", "dirt", "rockgrey"),
               "inner": [("umbrella", 2), ("bush", 2)], "edge": [("bush", 1)],
               "sparse": [("umbrella", 2), ("bush", 3)]},
    "desert": {"slope": ("sanddune", "sand"), "proto": (0.2, 0.05, 0.1, 0.95), "top": ("sanddune", "sand", "sandblock"),
               "riser": ("sandstone", "sandstonelayered", "sandblock"),
               "inner": [("cactus", 2), ("palm", 1)], "edge": [("cactus", 1)],
               "sparse": [("cactus", 3), ("bush", 1)]},
    "badlands": {"slope": ("dirtred", "sand"), "proto": (0.5, 0.1, 0.4, 0.85), "top": ("dirtred", "sandstonered", "sand"),
                 "riser": ("sandstonered", "sandstonelayered", "sandstone"),
                 "inner": [("snag", 2), ("cactus", 1)], "edge": [("cactus", 1)],
                 "sparse": [("snag", 1), ("cactus", 2)]},
    "alpine": {"slope": ("pathgravel", "frostedrock"), "proto": (0.8, 0.5, 0.85, 0.3), "top": ("snowfresh", "snowblock", "rockgrey"),
               "riser": ("frostrock", "frostedrock", "rockgrey"),
               "inner": [("pine", 2)], "edge": [("pine", 1)], "sparse": [("pine", 1)]},
    "glacier": {"slope": ("snowfresh", "snowblock"), "proto": (1.0, 0.6, 1.0, 0.2), "top": ("icepacked", "snowfresh", "ice"),
                "riser": ("icecracked", "frostrock", "frostedrock"),
                "inner": [], "edge": [], "sparse": []},
    "swamp": {"slope": ("mud", "dirt"), "proto": (0.05, 0.95, 0.4, 0.05), "top": ("mud", "moss", "dirt"),
              "riser": ("dirtdark", "dirt"),
              "inner": [("willow", 2), ("snag", 1)], "edge": [("bush", 2), ("willow", 1)],
              "sparse": [("willow", 1), ("snag", 1), ("bush", 2)]},
    "river valley": {"slope": ("dirt", "grass"), "proto": (0.1, 1.0, 0.35, 0.2), "top": ("grasslush", "grass"),
                     "riser": ("rockgrey", "greystone"),
                     "inner": [("willow", 1), ("birch", 2)], "edge": [("bush", 2), ("birch", 1)],
                     "sparse": [("birch", 2), ("willow", 1), ("bush", 1)]},
    "volcanic": {"slope": ("ash", "flagstone"), "proto": (0.4, 0.05, 0.5, 0.9), "top": ("ash", "basalttop", "flagstone"),
                 "riser": ("basaltcolumns", "basaltrough", "obsidian", "greystone"),
                 "inner": [("snag", 1)], "edge": [], "sparse": [("snag", 1)]},
    "sky isles": {"slope": ("dirt", "grass"), "proto": (0.5, 0.5, 0.4, 0.3), "top": ("grassmeadow", "grass"),
                  "riser": ("rockgrey", "whitestonebrick"),
                  "inner": [("birch", 2), ("oak", 2)], "edge": [("bush", 2)],
                  "sparse": [("birch", 2), ("oak", 1)]},
    "mushroom grove": {"slope": ("dirtdark", "dirt"), "proto": (0.2, 0.9, 0.5, 0.1), "top": ("moss", "grasslush", "grass"),
                       "riser": ("rockdark", "rockgrey"),
                       "inner": [("mushroom", 3), ("snag", 1)], "edge": [("mushroom", 1), ("bush", 2)],
                       "sparse": [("mushroom", 2), ("bush", 1)]},
}
THEME_BIOMES = {
    "garden": ("meadow", "forest", "taiga", "river valley", "swamp", "alpine", "mushroom grove"),
    "wood": ("forest", "taiga", "meadow", "river valley", "swamp"),
    "castle": ("meadow", "forest", "river valley", "taiga", "alpine"),
    "sky": ("sky isles", "meadow", "forest"),
    "desert": ("desert", "badlands", "steppe", "river valley"),
    "ice": ("alpine", "glacier", "taiga"),
    "lava": ("volcanic", "badlands"),
}
THEME_BIAS = {"ice": (0.5, -0.2), "desert": (-0.2, 0.5), "lava": (0.0, 0.6), "wood": (0.05, -0.1),
              "garden": (0.0, 0.0), "castle": (0.0, 0.0), "sky": (0.0, 0.0)}
def _have_tex(keys, have):
    from . import soft64
    for k in keys:
        if k in have:
            return k
        kk = soft64.to_kit(k)
        if kk and kk in have:
            return kk
    return None
def biome_top(name, have):
    return _have_tex(BIOMES[name]["top"], have)
def biome_slope(name, have):
    return _have_tex(BIOMES[name].get("slope", ()), have)
def biome_riser(name, have):
    return _have_tex(BIOMES[name]["riser"], have)
HIGH = 8.0
def biomes(theme, plinth, top, wet, rnd=None, kinds=None, preset=None):
    theme = theme if theme in THEME_BIOMES else "garden"
    allowed = [b for b in THEME_BIOMES[theme] if b not in ("river valley", "swamp")] \
        or list(THEME_BIOMES[theme])
    bias_c, bias_d = THEME_BIAS.get(theme, (0.0, 0.0))
    if preset == "alpine":
        bias_c += 0.1
    elif preset == "mesa":
        bias_d += 0.2
    kinds = kinds or {}
    out = {}
    for d in sorted(plinth):
        w = wet.get(d, 0.0)
        if kinds.get(d) == "lake" and "swamp" in THEME_BIOMES[theme]:
            out[d] = "swamp"
            continue
        if w >= 0.5 and "river valley" in THEME_BIOMES[theme]:
            out[d] = "river valley"
            continue
        band = min(1.0, plinth[d] / HIGH)
        wob = rnd.uniform(-0.12, 0.12) if rnd else 0.0
        cold = max(0.0, min(1.0, 0.2 + 0.8 * band + bias_c))
        dry = max(0.0, min(1.0, 0.3 + bias_d - 0.3 * w + wob))
        best = None
        for name in allowed:
            pb, _, pc, pd = BIOMES[name]["proto"]
            dist = (band - pb) ** 2 + 1.5 * (cold - pc) ** 2 + (dry - pd) ** 2 \
                + (0.04 if name == "mushroom grove" else 0.0)
            if best is None or dist < best[0]:
                best = (dist, name)
        out[d] = best[1]
    return out
def biome_share(biome_of, owner):
    n = {}
    for c, d in owner.items():
        b = biome_of.get(d)
        if b:
            n[b] = n.get(b, 0) + 1
    total = float(sum(n.values()) or 1)
    return {b: round(v / total, 2) for b, v in sorted(n.items(), key=lambda t: -t[1])}
def meander(path, n, rnd, amp=2, lam=12, margin=2):
    import math
    m = len(path)
    if m < lam:
        return list(path)
    phase = rnd.uniform(0.0, 2.0 * math.pi)
    pts = []
    for k, c in enumerate(path):
        a, b = path[max(0, k - 3)], path[min(m - 1, k + 3)]
        dx, dz = b[0] - a[0], b[1] - a[1]
        perp = (0, 1) if abs(dx) >= abs(dz) else (1, 0)
        env = min(1.0, k / (lam / 2.0), (m - 1 - k) / (lam / 2.0))
        o = int(round(amp * env * math.sin(2.0 * math.pi * k / lam + phase)))
        q = (min(n - 1 - margin, max(margin, c[0] + o * perp[0])),
             min(n - 1 - margin, max(margin, c[1] + o * perp[1])))
        if k in (0, m - 1):
            q = c
        pts.append(q)
    out = [pts[0]]
    for q in pts[1:]:
        cur = out[-1]
        while cur != q:
            if cur[0] != q[0]:
                cur = (cur[0] + (1 if q[0] > cur[0] else -1), cur[1])
            else:
                cur = (cur[0], cur[1] + (1 if q[1] > cur[1] else -1))
            out.append(cur)
    res, seen = [], {}
    for c in out:
        if c in seen:
            res = res[:seen[c] + 1]
            seen = {x: i for i, x in enumerate(res)}
            continue
        seen[c] = len(res)
        res.append(c)
    return res
def boulder(cx, cz, g, rnd, tex):
    from . import kit
    a = rnd.choice((100, 150))
    h = rnd.choice((200, 300))
    out = [kit.kind("box").make(tex, cx - a, cx + a, g, g + h, cz - a, cz + a, None, "rock.boulder")]
    if rnd.random() < 0.6:
        b = 50
        ox = rnd.choice((-50, 0, 50))
        oz = rnd.choice((-50, 0, 50))
        out.append(kit.kind("box").make(tex, cx + ox - b, cx + ox + b, g + h, g + h + 100,
                                        cz + oz - b, cz + oz + b, None, "rock.boulder"))
    return out
def cliff_feet(T, cells, step=2):
    out = []
    for c in cells:
        h = T.get(c)
        if h is None:
            continue
        for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if T.get((c[0] + a, c[1] + b), -99) - h >= step:
                out.append(c)
                break
    return out
def first_view(arena):
    import math
    sp = (arena.get("spawns") or [None])[0]
    if not sp:
        return {"score": 0}
    x, y, z = sp["x"], sp.get("y", 0), sp["z"]
    eye = y + 160
    tops = sorted(p["y"] + p["h"] for p in arena["pieces"]
                  if str(p.get("tag", "")).startswith(("terrace", "hills")))
    med = tops[len(tops) // 2] if tops else 0
    out = {"high": y >= med + 200}
    frame = mid = 0
    weenie = None
    water = False
    feet = True
    for p in arena["pieces"]:
        d = math.hypot(p["x"] - x, p["z"] - z)
        top = p["y"] + p["h"]
        tag = str(p.get("tag", ""))
        if p.get("kind") in ("water", "lava") or tag.endswith((".lava", ".water")):
            if d <= 12000:
                water = True
            continue
        if 600 <= d <= 1500 and top >= eye + 200:
            frame += 1
        if 1500 < d <= 5000 and top >= eye + 200:
            mid += 1
        if 4000 <= d <= 12000 and tag.startswith(("spire", "landmark", "volcano", "landform",
                                                   "lighthouse", "tower")):
            if weenie is None or top > weenie:
                weenie = top
        hw, hd = p.get("w", 0) / 2.0, p.get("d", 0) / 2.0
        if abs(p["x"] - x) < hw + 400 and abs(p["z"] - z) < hd + 400 and p["y"] < eye \
                and top > y + 30 and not tag.startswith(("terrace", "hills", "road", "ground")):
            feet = False
    out.update({"frame": frame > 0, "weenie": weenie is not None and weenie > y + 600,
                "mid": mid >= 2, "water": water, "feet": feet})
    out["score"] = sum(1 for k in ("high", "frame", "weenie", "mid", "water", "feet") if out[k])
    return out
def composition(arena, biome_shares=None, species=None, landforms=None):
    lm = land_measures(arena["pieces"])
    shares = biome_shares or {}
    row = dict(lm)
    row.update({"biomes": len(shares),
                "smallest_biome": min(shares.values()) if shares else None,
                "species": len(set(species or ())),
                "landforms": list(landforms or ()),
                "first_view": first_view(arena)})
    return row
GROUND_TAGS = ("terrace", "hills", "volcano", "cave.top")
ROAD_TAGS = ("road", "path", "plaza", "street")
def land_measures(pieces, cell=400):
    from . import contract
    tops = {}
    side_tex = {}
    roads = set()
    for p in pieces:
        if not str(p.get("tag", "")).startswith(ROAD_TAGS) or p.get("kind") != "box":
            continue
        x0, x1 = p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0
        z0, z1 = p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0
        i = int(x0 // cell)
        while i * cell < x1:
            j = int(z0 // cell)
            while j * cell < z1:
                roads.add((i, j))
                j += 1
            i += 1
    for p in pieces:
        tag = str(p.get("tag", ""))
        if p.get("kind") not in ("box", "ice") or not tag.startswith(GROUND_TAGS):
            continue
        x0, x1 = p["x"] - p["w"] / 2.0, p["x"] + p["w"] / 2.0
        z0, z1 = p["z"] - p["d"] / 2.0, p["z"] + p["d"] / 2.0
        top = p["y"] + p["h"]
        i = int(x0 // cell)
        while i * cell < x1:
            j = int(z0 // cell)
            while j * cell < z1:
                if top > tops.get((i, j), -1e9):
                    tops[(i, j)] = top
                side_tex.setdefault((i, j), []).append((p["y"], top, p.get("tex")))
                j += 1
            i += 1
    one = cliff = rock = 0
    tallest = 0
    for (i, j), t in tops.items():
        for d in ((1, 0), (0, 1)):
            n_ = (i + d[0], j + d[1])
            o = tops.get(n_)
            if o is None:
                continue
            r = abs(o - t)
            if r < 150:
                continue
            if (i, j) in roads and n_ in roads:
                continue
            if r < 350:
                one += 1
            else:
                cliff += 1
                tallest = max(tallest, r)
                hi = (i, j) if t > o else (i + d[0], j + d[1])
                lo_top = min(t, o)
                mid = lo_top + r / 2.0
                for y0, y1, tex in side_tex.get(hi, []):
                    if y0 <= mid <= y1:
                        if contract.family(tex) in ("rock", "masonry"):
                            rock += 1
                        break
    steps = one + cliff
    vals = list(tops.values())
    return {"one_layer_steps": one, "cliff_edges": cliff,
            "one_layer_share": round(one / float(steps), 3) if steps else 0.0,
            "tallest_riser": int(tallest), "relief": int(max(vals) - min(vals)) if vals else 0,
            "levels": len(set(int(v // LAYER) for v in vals)),
            "rock_risers": round(rock / float(cliff), 3) if cliff else None}
