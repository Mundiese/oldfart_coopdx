from . import kit
CONTRAST = {"shooter": 0.25, "knockoff": 0.25, "objective": 0.22, "race": 0.22, "course": 0.22,
            "party": 0.18, "explore": 0.18, "hide": 0.10}
CONTRAST_DEFAULT = 0.18
TRIM_MIN = 0.15
LIT_WALL = 0.47
VERY_BUSY = 0.25
BUSY = 0.11
CALM_WALLS = ("shooter", "objective", "knockoff", "party")
BLEND = ("hide",)
FIGHT_IN_VIEW = ("shooter", "knockoff", "objective")
MATERIALS = {
    "stone": ("stone2", "greystone", "flagstone", "stone1", "whitestonebrick", "frostedrock"),
    "brick": ("brickdarkgrey", "bricktwocolored", "redbrick", "brickpyramid", "bricklightgrey"),
    "wood": ("shipplanks", "darkplanks", "crate", "woodenplank1", "woodenplank2", "greenplanks",
             "hatchedwood"),
    "earth": ("dirt", "mossyrock", "grassblock", "grass", "sand", "sandblock"),
    "cold": ("frostedrock", "whitemarble", "snowblock", "ice", "glassblock"),
    "metal": ("rivetedplate", "diamondplate", "studdedsteel"),
    "tile": ("carpet", "tile1", "tile2", "hexpaving", "whitemarble"),
}
NOT_WALL = ("grassblock", "snowblock", "sandblock", "lava", "hazardstripes", "glassblock",
            "tile1", "tile2", "ice", "carpet", "sand", "grass", "brick", "water", "crate")
NOT_WALL += ("checkerrw", "stripesrw", "target", "glowpink", "glowblue", "glowamber",
             "glowgreen", "arrowtile", "starpanel", "watersurface", "grasslush", "grassdry",
             "grassclover", "grassteal", "grassflowers", "flowersred", "flowersblue",
             "flowerswhite", "moss", "sanddune", "sandwhite", "sandwet", "mud", "mudcracked",
             "path", "pathgravel", "gravel", "gravelbrown", "snowfresh", "snowridge",
             "snowdirty", "snowpacked", "icecracked", "icepacked", "magmacrust", "ash",
             "carpetblue", "carpetgreen", "carpetpurple", "rugstriped", "grasscliffcube",
             "grassdrycube", "grasslushcube", "mosscube", "sanddirtcube", "snowcliffcube",
             "birchlog", "darklog", "oaklog", "pinelog")
LIGHT_BASE = {"sky": "diamondplate", "ice": "stone2"}
_stats = {}
def stats():
    if _stats:
        return _stats
    import io
    from PIL import Image
    from . import v1
    m = v1.arenas_module()
    for slug, t in kit.textures().items():
        try:
            png = m.blocks.read_texture(kit._repo_path(t["source"]))
            im = Image.open(io.BytesIO(png)).convert("RGB")
        except Exception:
            continue
        import numpy as np
        a = np.asarray(im, dtype=np.float64) / 255.0
        lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
        _stats[slug] = (float(lum.mean()), float(lum.std()))
    return _stats
def material_of(slug):
    for name, members in MATERIALS.items():
        if slug in members:
            return name
    return None
def members(slug, have):
    fam = material_of(slug)
    if fam is None:
        return []
    st = stats()
    return sorted((t for t in MATERIALS[fam] if t in have and t in st),
                  key=lambda t: st[t][0])
def _may_wall(t, have):
    roles = tuple(r for r in ((have.get(t) or {}).get("roles") or ())
                  if r not in ("any", "cap"))
    return not (have.get(t) or {}).get("roles_from") == "manifest" or "wall" in roles
def minimum(family):
    return CONTRAST.get(family, CONTRAST_DEFAULT)
def bands(pal, theme, family):
    st = stats()
    have = kit.textures()
    notes = []
    if not st or pal.get("floor") not in st or pal.get("wall") not in st:
        return notes
    need = minimum(family)
    lf = st[pal["floor"]][0]
    def set_wall(t, why):
        notes.append("beauty M1/M3: wall %s -> %s (%s)" % (pal["wall"], t, why))
        if pal.get("cover") == pal["wall"]:
            pal["cover"] = t
        pal["wall"] = t
    if family in BLEND:
        lw, sw = st[pal["wall"]]
        if sw < BUSY or lw > 0.6:
            pool = [t for t in members(pal["wall"], have) if t not in NOT_WALL
                    and _may_wall(t, have)
                    and 0.2 <= st[t][0] <= 0.5 and st[t][1] >= BUSY
                    and abs(st[t][0] * LIT_WALL - lf) >= need]
            if pool:
                set_wall(min(pool, key=lambda t: abs(st[t][0] - lw)),
                         "hide: a busy mid wall in its family, players blend in")
    elif family in CALM_WALLS:
        for role in ("wall", "cover"):
            t = pal.get(role)
            if t in st and st[t][1] > VERY_BUSY:
                pool = [c for c in members(t, have) if c not in NOT_WALL
                        and st[c][1] <= VERY_BUSY and abs(st[c][0] * LIT_WALL - lf) >= need]
                if pool:
                    best = min(pool, key=lambda c: (st[c][1], abs(st[c][0] - st[t][0])))
                    notes.append("beauty M3: %s %s -> %s (a very busy texture where players "
                                 "stand swallows them)" % (role, t, best))
                    if role == "wall":
                        set_wall(best, "M3")
                    else:
                        pal[role] = best
    lw = st[pal["wall"]][0]
    if lf >= 0.6 and lw >= 0.6 and theme in LIGHT_BASE and family not in BLEND \
            and family not in FIGHT_IN_VIEW and abs(lf - lw * LIT_WALL) < need:
        dark = LIGHT_BASE[theme]
        if dark in have and dark in st:
            pal["wall_base"] = dark
            notes.append("beauty M1: a light theme keeps its light walls; a dark base course "
                         "and trims in %s (%.2f under the floor)" % (dark, lf - st[dark][0]))
            if abs(st.get(pal.get("trim"), (lf, 0))[0] - lf) < TRIM_MIN:
                pal["trim"] = dark
    tr = pal.get("trim")
    if tr in st and abs(st[tr][0] - lf) < TRIM_MIN:
        pool = [t for t in members(tr, have) if abs(st[t][0] - lf) >= TRIM_MIN
                and t not in ("lava", "water")]
        if not pool and pal.get("wall_base") in st:
            pool = [pal["wall_base"]]
        if pool:
            best = min(pool, key=lambda t: abs(st[t][0] - st[tr][0]))
            notes.append("beauty M1: trim %s -> %s (an edge you cannot see does not read; "
                         "%.2f off the floor)" % (tr, best, abs(st[best][0] - lf)))
            pal["trim"] = best
    return notes
def remodel(p):
    if "model" in p:
        from . import v1
        p["model"] = v1.arenas_module().model_name(p)
def _areas(pieces):
    out = {}
    for p in pieces:
        if p.get("tex") in (None, "invisible") or p.get("kind") == "water" \
                or str(p.get("tag", "")).startswith("dress.backdrop"):
            continue
        w, h, d = p["w"], p["h"], p["d"]
        t, u = out.get(p["tex"], (0.0, 0.0))
        out[p["tex"]] = (t + w * d, u + 2.0 * (w + d) * h)
    return out
def measured(pieces, theme, family, keep=()):
    st = stats()
    have = kit.textures()
    areas = _areas(pieces)
    tops = [(st[t][0], a[0]) for t, a in areas.items() if t in st and a[0] > 0]
    if not tops:
        return []
    fv = sum(v * a for v, a in tops) / sum(a for _, a in tops)
    walls = sorted(((a[1], t) for t, a in areas.items()
                    if t in st and a[1] > a[0] and t not in NOT_WALL), reverse=True)
    if not walls:
        return []
    wall = walls[0][1]
    if wall in keep:
        return []
    need = minimum(family)
    lw = st[wall][0]
    if abs(fv - lw * LIT_WALL) >= need:
        return []
    if family in BLEND:
        return []
    wa = areas[wall][0]
    total = sum(a for _, a in tops)
    def after(t):
        f2 = (fv * total - lw * wa + st[t][0] * wa) / total
        return abs(f2 - st[t][0] * LIT_WALL)
    fam = [t for t in members(wall, have) if t not in NOT_WALL]
    if "wall" in (have.get(wall) or {}).get("roles", ()):
        fam = [t for t in fam if "wall" in (have.get(t) or {}).get("roles", ())] or fam
    pool = [t for t in fam if after(t) >= need]
    how = "its family"
    if not pool:
        gain = [t for t in fam if after(t) >= abs(fv - lw * LIT_WALL) + 0.05]
        if not gain:
            return []
        pool = [max(gain, key=lambda t: (after(t), t))]
        how = "its family's best, short of the minimum"
    best = min(pool, key=lambda t: (abs(st[t][0] - lw), t))
    n = 0
    for p in pieces:
        if p.get("tex") == wall:
            p["tex"] = best
            remodel(p)
            n += 1
    return ["beauty M1 (measured): wall %s -> %s on %d pieces (floor %.2f, wall %.2f -> %.2f; "
            "%s, minimum %.2f)" % (wall, best, n, fv, lw, st[best][0], how, need)]
SOFT64_ROLES = {"floor": "floor", "deck": "deck", "wall": "wall", "ramp": "ramp",
                "bridge": "bridge", "keel": "keel", "cover": "cover", "trim": "trim",
                "accents": "accents", "wall_base": "wall_base", "wall_cap": "wall_cap",
                "roof": "roof"}
def materials_from_soft64(palettes):
    return {name: tuple(keys) for name, keys in (palettes.get("gradients") or {}).items()
            if not name.startswith("_") and isinstance(keys, list)}
def palette_from_soft64(palettes, theme):
    row = (palettes.get("themes") or {}).get(theme) or {}
    out = dict(row.get("kit_roles") or {})
    for role in ("wall_base", "wall_cap", "roof"):
        if row.get(role):
            out[role] = row[role]
    if isinstance(out.get("floor"), str) and out["floor"].endswith("+layered"):
        out["floor"] = out["floor"][:-len("+layered")]
    return {SOFT64_ROLES[k]: v for k, v in out.items() if k in SOFT64_ROLES}
MATERIALS_BEFORE_SOFT64 = dict(MATERIALS)
LIGHT_BASE_BEFORE_SOFT64 = dict(LIGHT_BASE)
def _soft64_tables():
    try:
        from . import soft64
    except ImportError:
        return
    fams = soft64.materials()
    if fams:
        MATERIALS.clear()
        MATERIALS.update(fams)
    for theme in list(LIGHT_BASE):
        pal = soft64.theme_palette(theme) or {}
        if pal.get("wall_base"):
            LIGHT_BASE[theme] = pal["wall_base"]
_soft64_tables()
