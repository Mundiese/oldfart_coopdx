import math
from . import kit, scatter, v1
FAMILIES = ("explore", "hide")
COUNT = {"large": 3, "huge": 5, "gigantic": 6}
CAIRN_COST = 4
HERO_TAGS = ("setpiece.", "landmark", "dress.landmark", "spire")
ADJECTIVES = {
    "garden": ("Sunny", "Clover", "Daisy", "Honey", "Breezy", "Bluebell", "Meadowlark"),
    "wood": ("Mossy", "Acorn", "Owl", "Fern", "Shady", "Hollow", "Bramble"),
    "ice": ("Frosty", "Snowy", "Crystal", "Icicle", "Chilly", "Glacier", "Snowdrift"),
    "desert": ("Dusty", "Sunbaked", "Cactus", "Golden", "Mirage", "Scorpion", "Dune"),
    "lava": ("Ember", "Cinder", "Smoky", "Molten", "Ashen", "Fire", "Sulphur"),
    "castle": ("Royal", "Banner", "Knight's", "Crown", "Rampart", "Herald", "Lantern"),
    "sky": ("Cloud", "Breezy", "Feather", "Rainbow", "Starlight", "Windy", "Sunbeam"),
}
HEART_NOUNS = {"giant_mushrooms": "Mushroom Grove", "waterfall": "Waterfall Glen",
               "lookout": "Lookout Hill", "spiral_path": "Spiral Peak",
               "secret_alcove": "Hidden Hollow", "slide": "Slide Slope",
               "floating_islands": "Sky Isles"}
LOOK_NOUNS = {"peak": ("Peak", "Heights", "Ridge"), "water": ("Lake", "Shore", "Springs"),
              "woods": ("Woods", "Forest", "Thicket"), "open": ("Meadow", "Fields", "Vale")}
def wanted(brief):
    from . import budget as budgetmod
    if brief.get("family") not in FAMILIES:
        return 0
    return COUNT.get(budgetmod.tier_of(brief.get("size") or "medium"), 0)
def _hearts(arena):
    out = {}
    for p in arena.get("pieces") or []:
        t = str(p.get("tag", ""))
        if t.startswith("setpiece.") or t.startswith("landform.waterfall"):
            kind = t.split(" ")[0].split(".")[1] if t.startswith("setpiece.") else "grotto"
            kind = {"mushroom": "giant_mushrooms", "grotto": "waterfall", "spiral": "spiral_path",
                    "alcove": "secret_alcove", "island": "floating_islands"}.get(kind, kind)
            out.setdefault(kind, []).append((p["x"], p["z"]))
    return {k: (sum(x for x, _ in v) / len(v), sum(z for _, z in v) / len(v))
            for k, v in out.items()}
def build(arena, brief, room, rnd):
    n = wanted(brief)
    if not n:
        return [], [], []
    G = scatter.Ground(arena)
    cells = [k for k in range(G.nx * G.nz) if G.h[k] is not None]
    if len(cells) < 50:
        return [], [], []
    hearts = sorted(_hearts(arena).items())
    seeds = [(x, z, kind) for kind, (x, z) in hearts][:n]
    pts = [G.centre(k) for k in cells[::7]]
    if not seeds:
        x, z = pts[rnd.randrange(len(pts))]
        seeds.append((x, z, None))
    while len(seeds) < n:
        far = max(pts, key=lambda p: min(math.hypot(p[0] - s[0], p[1] - s[1]) for s in seeds))
        seeds.append((far[0], far[1], None))
    members = [[] for _ in seeds]
    for k in cells:
        x, z = G.centre(k)
        i = min(range(len(seeds)), key=lambda s: (x - seeds[s][0]) ** 2 + (z - seeds[s][1]) ** 2)
        members[i].append(k)
    theme = brief.get("theme") if brief.get("theme") in ADJECTIVES else "garden"
    adjs = list(ADJECTIVES[theme])
    rnd.shuffle(adjs)
    used = set()
    regions, pieces, notes = [], [], []
    tops = sorted(G.h[k] for k in cells)
    high = tops[int(len(tops) * 0.85)] if tops else 0
    landmarks = [p for p in arena.get("pieces") or []
                 if any(t in str(p.get("tag", "")) for t in HERO_TAGS)]
    m = v1.arenas_module()
    for i, (sx, sz, heart) in enumerate(seeds):
        ks = members[i]
        if not ks:
            continue
        xs = [G.centre(k)[0] for k in ks]
        zs = [G.centre(k)[1] for k in ks]
        box = [min(xs) - 100, max(xs) + 100, min(zs) - 100, max(zs) + 100]
        open_ks = [k for k in ks if not G.built[k] and not G.water[k] and not G.road[k]
                   and not G.sloped[k]]
        summit = max(open_ks or ks, key=lambda k: (G.h[k], -k))
        hx, hz = G.centre(summit)
        hy = G.h[summit]
        if heart:
            noun = HEART_NOUNS.get(heart, "Corner")
        else:
            wet = sum(1 for k in ks if G.water[k]) / float(len(ks))
            wooded = sum(1 for k in ks if G.tree[k]) / float(len(ks))
            look = "peak" if hy >= high and hy > min(tops) + 400 else (
                "water" if wet > 0.08 else ("woods" if wooded > 0.12 else "open"))
            noun = LOOK_NOUNS[look][i % len(LOOK_NOUNS[look])]
        name = None
        for adj in adjs + ["Little", "Far", "Old", "Lucky", "Merry"]:
            cand = "%s %s" % (adj, noun)
            if cand not in used:
                name = cand
                break
        used.add(name)
        if name.split(" ")[0] in adjs:
            adjs.remove(name.split(" ")[0])
        marked = heart is not None or any(
            box[0] <= p["x"] <= box[1] and box[2] <= p["z"] <= box[3] for p in landmarks)
        cairn = []
        if not marked and room - len(pieces) >= CAIRN_COST:
            cairn = _cairn(arena, brief, G, hx, hz, hy, ks, rnd, i)
            if cairn:
                for p in cairn:
                    p["model"] = m.model_name(p)
                pieces += cairn
                hx, hz = cairn[0]["x"], cairn[0]["z"]
                hy = max(p["y"] + p["h"] for p in cairn)
        regions.append({"name": name, "x": int(hx), "y": int(hy) + 400, "z": int(hz),
                        "box": [int(v) for v in box], "heart": heart or (
                            "cairn" if cairn else ("landmark" if marked else None))})
    if regions:
        notes.append("regions: %s" % ", ".join(r["name"] for r in regions))
    return pieces, regions, notes
def _cairn(arena, brief, G, hx, hz, hy, ks, rnd, i):
    from . import setpieces
    S = setpieces.Site(arena, brief)
    best = None
    for k in sorted(ks, key=lambda k: -G.h[k])[:800]:
        x, z = G.centre(k)
        x, z = int(round(x / 100.0)) * 100, int(round(z / 100.0)) * 100
        g = S.flat(x, z, 250, pad=100)
        if g is not None:
            best = (x, z, g)
            break
    if best is None:
        return []
    x, z, g = best
    have = kit.textures()
    worn = set(p.get("tex") for p in arena.get("pieces") or [])
    rocks = [t for t in ("rockboulder", "rockgrey", "rockbrown", "mossyrock") if t in have]
    rock = next((t for t in rocks if t in worn), rocks[0] if rocks else "stone1")
    tag = "region.summit"
    seed = (x * 7 + z * 13 + i) & 0x7fff
    def stone(x0, x1, y0, y1, z0, z1, s, rnd_=3.0):
        p = kit.kind("box").make(rock, int(x0), int(x1), int(y0), int(y1), int(z0), int(z1),
                                 None, tag + " cairn")
        p["sculpt"] = {"shape": "rock", "seed": s, "round": rnd_, "flat": False, "table": True,
                       "segs": 12, "rings": 7}
        return p
    out = [stone(x - 250, x + 250, g, g + 200, z - 250, z + 250, seed),
           stone(x - 170, x + 170, g + 200, g + 360, z - 170, z + 170, seed + 1)]
    pal_acc = "bannerred" if "bannerred" in have else rock
    out.append(kit.kind("pillar").make("darkplanks" if "darkplanks" in have else rock,
                                       x - 40, x + 40, g + 360, g + 1060, z - 40, z + 40, None,
                                       tag + " pole"))
    out.append(kit.kind("box").make(pal_acc, x + 40, x + 340, g + 820, g + 1020, z - 10, z + 10,
                                    None, tag + " pennant"))
    return out
