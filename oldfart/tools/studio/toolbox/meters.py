from studio.editor import REPO
AMBER = 0.85
PICTURE_KB = 2.5
PICTURES_MAX = 300
class Row:
    __slots__ = ("key", "label", "value", "limit", "level", "tip", "unit")
    def __init__(self, key, label, value, limit, tip="", unit="", level=None):
        self.key, self.label, self.value, self.limit = key, label, value, limit
        self.tip, self.unit = tip, unit
        self.level = level or level_of(value, limit)
    @property
    def share(self):
        if not self.limit:
            return 0.0
        return float(self.value) / float(self.limit)
    def text(self):
        if self.limit:
            return "%s %s%s of %s%s" % (self.label, _n(self.value), self.unit, _n(self.limit),
                                        self.unit)
        return "%s %s%s" % (self.label, _n(self.value), self.unit)
    def __repr__(self):
        return "<Row %s %s/%s %s>" % (self.key, self.value, self.limit, self.level)
def _n(v):
    return ("%.1f" % v) if isinstance(v, float) and v != int(v) else "%d" % v
def level_of(value, limit):
    if not limit:
        return "ok"
    share = float(value) / float(limit)
    if share > 1.0:
        return "fail"
    if share >= AMBER:
        return "warn"
    return "ok"
def _budget():
    try:
        from mapgen import budget
    except ImportError:
        return None
    return budget if hasattr(budget, "report") and hasattr(budget, "ceiling") else None
def _family_modes(layout, brief):
    brief = brief or {}
    family = brief.get("family") or layout.get("family") or "shooter"
    modes = list(brief.get("modes") or layout.get("onlyFor") or [])
    return family, modes
def report(layout, brief=None):
    layout = layout or {}
    pieces = layout.get("pieces") or []
    family, modes = _family_modes(layout, brief)
    objects = len((layout.get("objects") or []))
    budget = layout.get("budget") or (brief or {}).get("budget")
    mod = _budget()
    rows = []
    out = {"family": family, "modes": modes, "pieces": len(pieces)}
    if mod is not None and hasattr(mod, "baked_report") and layout.get("bake") is not False \
            and pieces:
        out["source"] = "mapgen.budget (a baked venue: its level carries its pieces)"
        out["table"] = list(mod.table()) if hasattr(mod, "table") else []
        out["baked"] = True
        rows += baked_rows(mod, layout, family, modes, budget)
    elif mod is not None:
        r = mod.report(layout, family, modes)
        ceiling = r["ceiling"]
        out["source"] = "mapgen.budget (measured engine numbers)"
        out["table"] = list(mod.table()) if hasattr(mod, "table") else []
        rows.append(Row("pieces", "Pieces", len(pieces), budget or ceiling,
                        "this map's own budget (the brief); the engine allows up to %d for "
                        "%s maps" % (ceiling, family)))
        rows.append(Row("ceiling", "Engine ceiling", len(pieces) + objects, ceiling,
                        "the object pool's build line (%d) less the level with 16 players, "
                        "the reserve and what %s modes spawn themselves - budget.py"
                        % (getattr(mod, "CEILING", 1050), family)))
        rows.append(Row("download", "Download", float(r["download_kb"]),
                        r["pictures_max"] * getattr(mod, "PICTURE_KB", PICTURE_KB),
                        "%d distinct pictures (kind, texture, size), ~%.1f KB each per joiner"
                        % (r["pictures"], getattr(mod, "PICTURE_KB", PICTURE_KB)), " KB"))
        rows.append(Row("triangles", "Collision", r["triangles"], 0,
                        "collision triangles (no cap: static collision grows - budget.py)"))
        rows.append(Row("survey", "Survey points", r["survey"], r["survey_max"],
                        "points the modes read (a sync string of 256)"))
        rows.append(Row("reach", "Reach", r["reach"], r["draw_reach"],
                        "the farthest piece from the middle against the draw distance", " u"))
    else:
        from mapgen import brief as briefmod
        ceiling = briefmod.BUDGET_MAX
        out["source"] = ("mapgen's current numbers (brief.BUDGET_MAX, the layout's budget); "
                         "the measured engine budget arrives with mapgen/budget.py")
        out["table"] = [("most pieces a brief may ask for", ceiling, "mapgen/brief.py BUDGET_MAX")]
        rows.append(Row("pieces", "Pieces", len(pieces), budget or ceiling,
                        "this map's own budget (the brief)"))
        rows.append(Row("ceiling", "Engine ceiling", len(pieces) + objects, ceiling,
                        "the most a brief may ask for today (mapgen/brief.py)"))
        pics = set((p.get("kind"), p.get("tex"), int(p.get("w", 0)), int(p.get("h", 0)),
                    int(p.get("d", 0))) for p in pieces)
        rows.append(Row("download", "Download", round(len(pics) * PICTURE_KB, 1),
                        PICTURES_MAX * PICTURE_KB, "%d distinct pictures, ~%.1f KB each per joiner"
                        % (len(pics), PICTURE_KB), " KB"))
        survey = len(((layout.get("survey") or {}).get("points") or []))
        rows.append(Row("survey", "Survey points", survey, 28,
                        "points the modes read (a sync string of 256)"))
    try:
        new_kb, distinct = _new_pictures(layout)
        rows.append(Row("new", "New pictures", new_kb, 0,
                        "%d of the map's pictures are not in actors/ yet: every joiner "
                        "downloads them (report card)" % (new_kb // 3 if new_kb else 0), " KB"))
    except Exception:
        pass
    out["rows"] = rows
    out["worst"] = max((r.level for r in rows), key=["ok", "warn", "fail"].index) if rows else "ok"
    return out
BAKED_ROWS = (
    ("view", "View", " tris", "the most triangles one camera draws (sampled from the spawns, "
     "eight ways round each)"),
    ("draw_triangles", "Triangles", "", "every triangle the venue's level draws"),
    ("collision_triangles", "Collision", "", "collision triangles in the area"),
    ("cell_walls", "Busiest walls", "", "walls in the busiest 1024 collision cell (every "
     "player's every step walks one cell's lists)"),
    ("cell_floors", "Busiest floors", "", "floors in the busiest 1024 collision cell"),
    ("lvl_kb", "Level file", " KB", "the venue's level file every joiner downloads"),
    ("levels_mb", "All levels", " MB", "every level file together (each stays loaded)"),
    ("textures", "Textures", "", "block textures the level carries (one copy each)"),
    ("reach", "Reach", " u", "the farthest drawn corner from the middle (s16: 32767 is the edge)"),
)
def _where(at):
    if not at:
        return ""
    if len(at) == 3:
        return " - worst from (%d, %d) looking %d degrees round" % at
    return " - busiest around (%d, %d)" % at
def baked_rows(mod, layout, family, modes, budget):
    rep = mod.baked_report(layout, family, modes)
    lines = getattr(mod, "BAKED_METERS", {})
    pieces = len(layout.get("pieces") or [])
    rows = [Row("pieces", "Pieces", pieces, budget or getattr(mod, "BAKED_PIECE_MAX", 0),
                "baked into the venue's own level: no objects - the meters below hold them"),
            Row("ceiling", "Run-time objects", rep["objects"][0], rep["object_ceiling"],
                "what is still put down at run time (movers, Forge objects, markers, stars) "
                "against the object pool's line for %s maps" % family, level=rep["objects"][1])]
    for key, label, unit, tip in BAKED_ROWS:
        value, level, at = rep[key]
        if value is None:
            continue
        green, yellow = lines.get(key, (0, 0))
        if isinstance(value, float):
            value = round(value, 1 if key != "levels_mb" else 2)
        text = "%s; green up to %s, yellow up to %s" % (tip, _n(green), _n(yellow))
        if level != "ok":
            text += _where(at)
        rows.append(Row(key, label, value, green, text, unit, level=level))
    rims = rep.get("liquid_rims")
    if rims is not None and rims[0] is not None:
        n, level, at = rims
        text = ("points just past a water or lava surface's edge with nothing to hold it "
                "(it floats or leaks); none is green")
        if n and at:
            text += " - the first at (%d, %d)" % tuple(at[:2])
        rows.append(Row("liquid_rims", "Liquids held", n, 0, text, "", level=level))
    return rows
def _new_pictures(layout):
    from mapgen.report.card import new_pictures_kb
    if not layout.get("pieces"):
        return 0, 0
    return new_pictures_kb(layout)
def status_line(rep):
    rows = {r.key: r for r in rep["rows"]}
    parts = []
    for key in ("pieces", "ceiling", "download"):
        if key in rows:
            parts.append(rows[key].text())
    return "   ".join(parts)
