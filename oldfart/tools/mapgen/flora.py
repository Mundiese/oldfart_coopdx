import math
from . import kit, pcg
CELL = 400
SPECIES = ("oak", "broadleaf", "birch", "pine", "megapine", "umbrella", "willow", "palm",
           "cactus", "snag", "mushroom", "bush")
TEX = {
    "bark_oak": ("barkoak", "darkplanks"), "bark_pine": ("barkpine", "barkdark", "darkplanks"),
    "bark_birch": ("barkbirch", "whitemarble"), "bark_dark": ("barkdark", "darkplanks"),
    "bark_jungle": ("barkjungle", "barkoak", "darkplanks"),
    "bark_mangrove": ("barkmangrove", "barkdark", "darkplanks"),
    "bark_cherry": ("barkcherry", "barkoak", "darkplanks"),
    "leaves": ("leaves", "hedge", "grass"), "leaves_dark": ("leavesdark", "leaves", "hedge"),
    "leaves_autumn": ("leavesautumn", "leaves", "hedge"),
    "blossom": ("flowerspink", "leaves", "hedge"),
    "cactus": ("grassteal", "hedge", "leaves"), "stalk": ("cutlight", "whitemarble", "sand"),
    "cap": ("mushroomsred", "flowersred", "carpet"),
    "fern": ("fern", "leaves", "hedge"),
}
def tex(part, have=None, crown=None):
    from . import soft64
    have = have if have is not None else kit.textures()
    keys = ((crown,) if crown else ()) + TEX[part]
    for k in keys:
        if k in have:
            return k
        kk = soft64.to_kit(k)
        if kk and kk in have:
            return kk
    return None
def _box(t, x0, x1, y0, y1, z0, z1, tag):
    return kit.kind("box").make(t, int(round(x0)), int(round(x1)), int(round(y0)),
                                int(round(y1)), int(round(z0)), int(round(z1)), None, tag)
def _pyramid(t, cx, cz, half, y0, y1, tag):
    return kit.kind("pyramid").make(t, int(cx - half), int(cx + half), int(y0), int(y1),
                                    int(cz - half), int(cz + half), "x", tag)
def _q(v, step=100):
    return max(step, int(round(v / float(step))) * step)
def _half(v, lo=100, hi=400):
    return max(lo, min(hi, int(round(v / 50.0)) * 50))
def build(species, cx, cz, g, rnd, room=200, have=None, crown_tex=None, tag="tree"):
    have = have if have is not None else kit.textures()
    def T(part):
        return tex(part, have, crown_tex if part.startswith(("leaves", "blossom")) else None)
    R = max(150, min(400, room))
    out = []
    jog = rnd.choice((-1, 1)) * 50
    along_x = rnd.random() < 0.5
    def off(v):
        return (v, 0) if along_x else (0, v)
    def bx(t, x0, x1, y0, y1, z0, z1, what):
        out.append(_box(t, x0, x1, y0, y1, z0, z1, tag + what))
    if species == "bush":
        a = _half(min(R, rnd.choice((150, 200))))
        bx(T("leaves"), cx - a, cx + a, g, g + rnd.choice((200, 300)), cz - a, cz + a, ".bush")
        return out
    if species == "cactus":
        h = rnd.choice((400, 500, 600))
        bx(T("cactus"), cx - 50, cx + 50, g, g + h, cz - 50, cz + 50, ".trunk")
        ay = g + rnd.choice((200, 300))
        s = rnd.choice((-1, 1))
        if along_x:
            x0 = cx + 50 if s > 0 else cx - 150
            bx(T("cactus"), x0, x0 + 100, ay, ay + 100, cz - 50, cz + 50, ".arm")
            bx(T("cactus"), x0, x0 + 100, ay + 100, ay + 300, cz - 50, cz + 50, ".arm")
        else:
            z0 = cz + 50 if s > 0 else cz - 150
            bx(T("cactus"), cx - 50, cx + 50, ay, ay + 100, z0, z0 + 100, ".arm")
            bx(T("cactus"), cx - 50, cx + 50, ay + 100, ay + 300, z0, z0 + 100, ".arm")
        return out
    if species == "snag":
        h = rnd.choice((500, 600, 700, 800))
        bx(T("bark_dark"), cx - 50, cx + 50, g, g + h, cz - 50, cz + 50, ".trunk")
        by = g + _q(h * rnd.uniform(0.5, 0.75))
        s = rnd.choice((-1, 1))
        if along_x:
            x0 = cx + 50 if s > 0 else cx - 250
            bx(T("bark_dark"), x0, x0 + 200, by, by + 100, cz - 50, cz + 50, ".branch")
        else:
            z0 = cz + 50 if s > 0 else cz - 250
            bx(T("bark_dark"), cx - 50, cx + 50, by, by + 100, z0, z0 + 200, ".branch")
        return out
    if species == "mushroom":
        h = rnd.choice((300, 400))
        bx(T("stalk"), cx - 50, cx + 50, g, g + h, cz - 50, cz + 50, ".trunk")
        a = 300 if R >= 300 and rnd.random() < 0.5 else 200
        bx(T("cap"), cx - a, cx + a, g + h, g + h + 100, cz - a, cz + a, ".crown")
        out.append(_pyramid(T("cap"), cx, cz, a, g + h + 100, g + h + 100 + a // 2,
                            tag + ".crown"))
        return out
    if species in ("pine", "megapine"):
        big = species == "megapine"
        w = 200 if big else 100
        h = rnd.choice((400, 500, 600)) if big else rnd.choice((200, 300))
        bx(T("bark_pine"), cx - w // 2, cx + w // 2, g, g + h, cz - w // 2, cz + w // 2, ".trunk")
        a = _half(R if big else min(R, rnd.choice((200, 250))))
        y = g + h
        tiers = []
        while a >= 100:
            tiers.append(a)
            a -= 100
        tiers.append(50)
        for a in tiers:
            hh = 100 if a == 50 else rnd.choice((100, 200) if not big else (200, 300))
            bx(T("leaves_dark"), cx - a, cx + a, y, y + hh, cz - a, cz + a, ".crown")
            y += hh
        return out
    if species == "umbrella":
        h1 = rnd.choice((300, 400))
        bx(T("bark_jungle"), cx - 50, cx + 50, g, g + h1, cz - 50, cz + 50, ".trunk")
        ox, oz = off(jog)
        h2 = rnd.choice((200, 300))
        bx(T("bark_jungle"), cx + ox - 50, cx + ox + 50, g + h1, g + h1 + h2, cz + oz - 50,
           cz + oz + 50, ".trunk")
        y = g + h1 + h2
        a = _half(R)
        bx(T("leaves"), cx + ox - a, cx + ox + a, y, y + 100, cz + oz - a, cz + oz + a, ".crown")
        b = _half(a * 0.5)
        bx(T("leaves"), cx + ox - b, cx + ox + b, y + 100, y + 200, cz + oz - b, cz + oz + b,
           ".crown")
        return out
    if species == "palm":
        y = g
        x, z = cx, cz
        for k in range(3):
            hh = rnd.choice((200, 300))
            bx(T("bark_jungle"), x - 50, x + 50, y, y + hh, z - 50, z + 50, ".trunk")
            y += hh
            if k < 2:
                dx, dz = off(jog)
                x, z = x + dx, z + dz
        a = 350 if R >= 350 else (250 if R >= 250 else 150)
        bx(T("fern"), x - a, x + a, y, y + 100, z - 50, z + 50, ".crown")
        bx(T("fern"), x - 50, x + 50, y, y + 100, z + 50, z + a, ".crown")
        bx(T("fern"), x - 50, x + 50, y, y + 100, z - a, z - 50, ".crown")
        return out
    if species == "willow":
        h = rnd.choice((400, 500))
        bx(T("bark_dark"), cx - 50, cx + 50, g, g + h, cz - 50, cz + 50, ".trunk")
        a = _half(R)
        bx(T("leaves_dark"), cx - a, cx + a, g + h, g + h + rnd.choice((200, 300)), cz - a,
           cz + a, ".crown")
        corners = ((1, 1), (-1, -1)) if rnd.random() < 0.5 else ((1, -1), (-1, 1))
        for sx, sz in corners:
            px, pz = cx + sx * (a - 50), cz + sz * (a - 50)
            bx(T("leaves_dark"), px - 50, px + 50, g + h - rnd.choice((200, 300)), g + h,
               pz - 50, pz + 50, ".drape")
        return out
    if species == "birch":
        h = rnd.choice((600, 700, 800))
        bx(T("bark_birch"), cx - 50, cx + 50, g, g + h, cz - 50, cz + 50, ".trunk")
        a = _half(min(R, rnd.choice((150, 200))))
        bx(T("leaves"), cx - a, cx + a, g + h, g + h + rnd.choice((300, 400)), cz - a, cz + a,
           ".crown")
        return out
    big = species == "broadleaf"
    w = 200 if big else 100
    h = rnd.choice((600, 700)) if big else rnd.choice((400, 500))
    bark = "bark_oak"
    bx(T(bark), cx - w // 2, cx + w // 2, g, g + h, cz - w // 2, cz + w // 2, ".trunk")
    a = _half(R if big else min(R, rnd.choice((200, 250, 300))))
    t1 = rnd.choice((300, 400)) if big else rnd.choice((200, 300))
    y = g + h
    bx(T("leaves"), cx - a, cx + a, y, y + t1, cz - a, cz + a, ".crown")
    b = _half(a * 0.6, 100, a - 50)
    ox, oz = off(jog if a - b >= 50 else 0)
    bx(T("leaves"), cx + ox - b, cx + ox + b, y + t1, y + t1 + rnd.choice((100, 200)),
       cz + oz - b, cz + oz + b, ".crown")
    if big:
        by = g + min(_q(h * rnd.uniform(0.5, 0.7)), h - 300)
        if along_x:
            x0 = cx + w // 2 if jog > 0 else cx - w // 2 - 200
            bx(T(bark), x0, x0 + 200, by, by + 100, cz - 50, cz + 50, ".branch")
        else:
            z0 = cz + w // 2 if jog > 0 else cz - w // 2 - 200
            bx(T(bark), cx - 50, cx + 50, by, by + 100, z0, z0 + 200, ".branch")
    return out
def height_of(species):
    return {"bush": 300, "cactus": 600, "snag": 800, "mushroom": 700, "pine": 1300,
            "megapine": 2100, "umbrella": 900, "palm": 1000, "willow": 800, "birch": 1200,
            "broadleaf": 1300, "oak": 1000}.get(species, 1000)
RADIUS = {"inner": 2.6, "edge": 2.2, "sparse": 4.5}
def bands(cells, allowed):
    s = set(cells)
    out = {}
    for c in cells:
        if any((c[0] + a, c[1] + b) not in s for a, b in pcg.N4):
            out[c] = "edge"
        else:
            out[c] = "inner"
    return out
def dither(species_slices, c, seed):
    v = _hash01(c, seed)
    total = sum(s for _, s in species_slices) or 1.0
    acc = 0.0
    for sp, share in species_slices:
        acc += share / total
        if v < acc:
            return sp
    return species_slices[-1][0]
def _hash01(c, seed):
    import zlib
    h = (c[0] * 73856093) ^ (c[1] * 19349663) ^ (zlib.crc32(str(seed).encode("utf-8")) & 0xFFFFFFFF)
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65536.0
def forest(cells, rnd, inner, edge, limit, clearing=None):
    clearing = set(clearing or ())
    by = bands([c for c in cells if c not in clearing], None)
    out = []
    for band, species in (("edge", edge), ("inner", inner)):
        cs = sorted(c for c, b in by.items() if b == band)
        if not cs or not species:
            continue
        pts = pcg.poisson_disk(cs, RADIUS[band], rnd, limit=max(1, limit))
        for c in pts:
            out.append((c, dither(species, c, "%s/%s" % (band, cs[0]))))
    out.sort(key=lambda t: t[0])
    return out[:limit]
def groves(cells, rnd, species, limit, parents=None, children=(2, 4)):
    s = set(cells)
    if not s or not species:
        return []
    ps = pcg.poisson_disk(sorted(s), RADIUS["sparse"], rnd,
                          limit=parents or max(1, limit // 3))
    out = []
    taken = set()
    for p in ps:
        sp = dither(species, p, "grove")
        group = [p]
        want = rnd.randint(children[0], children[1])
        near = sorted((c for c in s if 0 < max(abs(c[0] - p[0]), abs(c[1] - p[1])) <= 2),
                      key=lambda c: (_hash01(c, "g%s" % (p,)), c))
        for c in near:
            if len(group) > want:
                break
            if all(max(abs(c[0] - q[0]), abs(c[1] - q[1])) >= 2 for q in group):
                group.append(c)
        for c in group:
            if c not in taken:
                taken.add(c)
                out.append((c, sp))
        if len(out) >= limit:
            break
    return out[:limit]
def crown_room(c, free):
    n4 = all(free((c[0] + a, c[1] + b)) for a, b in pcg.N4)
    if not n4:
        return 200
    n8 = all(free((c[0] + a, c[1] + b)) for a in (-1, 0, 1) for b in (-1, 0, 1) if a or b)
    return 400 if n8 else 300
def pieces_of(species):
    return {"bush": 1, "snag": 2, "birch": 2, "pine": 4, "megapine": 6, "cactus": 3,
            "mushroom": 3, "oak": 3, "broadleaf": 4, "umbrella": 4, "willow": 4,
            "palm": 6}.get(species, 3)
def mean_pieces(species_slices):
    total = sum(s for _, s in species_slices) or 1.0
    return sum(pieces_of(sp) * s for sp, s in species_slices) / total
def is_tree(p):
    t = str(p.get("tag", "") or "")
    return t == "tree" or t.startswith("tree.")
def groups(pieces):
    trees = [p for p in pieces if is_tree(p)]
    n = len(trees)
    parent = list(range(n))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    boxes = []
    for p in trees:
        hw, hd = p.get("w", 0) / 2.0, p.get("d", 0) / 2.0
        if int(p.get("yaw", 0) or 0) % 180:
            hw, hd = hd, hw
        boxes.append((p["x"] - hw, p["x"] + hw, p["y"], p["y"] + p["h"], p["z"] - hd, p["z"] + hd))
    order = sorted(range(n), key=lambda i: boxes[i][0])
    for k, i in enumerate(order):
        a = boxes[i]
        for j in order[k + 1:]:
            b = boxes[j]
            if b[0] > a[1] + 1:
                break
            if b[4] <= a[5] + 1 and a[4] <= b[5] + 1 and b[2] <= a[3] + 1 and a[2] <= b[3] + 1:
                ri, rj = find(i), find(j)
                if ri != rj:
                    parent[ri] = rj
    out = {}
    for i in range(n):
        out.setdefault(find(i), []).append(trees[i])
    return [out[k] for k in sorted(out, key=lambda k: (out[k][0]["x"], out[k][0]["z"]))]
__all__ = ["is_tree", "groups", "SPECIES", "build", "forest", "groves", "dither", "crown_room", "height_of",
           "pieces_of", "mean_pieces", "math"]
