import contextlib
import io
import json
import os
from . import kb, tool
ROLE_HELP = {
    "floor": "walked on", "wall": "walls and towers", "ramp": "ramps and slopes",
    "bridge": "bridges and walkways", "deck": "upper floors", "keel": "under the map",
    "cover": "cover blocks", "trim": "edges and trims", "accent": "a touch of colour",
}
SHAPE_LABELS = {
    "cube": "Cube", "slab": "Slab", "plate": "Plate", "slope": "Slope", "outer": "Outer corner",
    "inner": "Inner corner", "ridge": "Ridge", "pyramid": "Pyramid", "wedge": "Wedge",
    "wedgetip": "Wedge tip", "wedgeouter": "Wedge outer", "wedgeinner": "Wedge inner",
    "wedgetipouter": "Tip outer", "wedgetipinner": "Tip inner", "stairs": "Stairs",
    "outerstairs": "Outer corner stairs", "innerstairs": "Inner corner stairs", "wall": "Wall",
    "wallcorner": "Wall corner", "wallt": "Wall T", "wallcross": "Wall cross",
    "panel": "Panel", "prism": "Diagonal half", "fence": "Fence", "fencecorner": "Fence corner",
    "pillar": "Pillar", "pole": "Pole", "roundcorner": "Round corner", "doorway": "Doorway",
    "window": "Window", "arch": "Arch",
    "slab2": "Slab, 2 long", "slab4": "Slab, 4 long", "plate2": "Plate, 2 long",
    "plate4": "Plate, 4 long", "wall2": "Wall, 2 long", "wall4": "Wall, 4 long",
    "panel2": "Panel, 2 long", "panel4": "Panel, 4 long",
}
FAMILY_GERMAN = {"Blocks": "Bloecke", "Ramps": "Rampen", "Wedges": "Keile", "Stairs": "Treppen",
                 "Walls": "Waende", "Fences": "Zaeune", "Columns": "Saeulen",
                 "Openings": "Oeffnungen"}
REBUILD = "python3 tools/make-blocks.py && python3 tools/make-forgeslopes.py"
AFTER = ("The blocks are built (the import ran both tools and their checks). "
         "Close Coop DX if it runs and start it again with the mod: the new blocks are on "
         "the Forge's shelves and wheel, and the map generator and Oldfart Studio's palette "
         "can use them. To rebuild by hand: " + REBUILD)
def kit():
    return tool("kit")
def slopes():
    return kit()._load("make_forgeslopes", "make-forgeslopes.py")
_SLOPES = None
def _sl():
    global _SLOPES
    if _SLOPES is None:
        _SLOPES = slopes()
    return _SLOPES
def shelves():
    return list(kit().blocks.SHELVES)
def roles():
    return list(ROLE_HELP)
def families():
    long_pieces = set(getattr(_sl(), "LONG_SPANS", ()))
    return [(name, [t for t in tags if t not in long_pieces])
            for name, tags in _sl().FAMILIES]
def upright_tags():
    return [t for _, tags in families() for t in tags]
def twin(tag):
    every = {v["tag"] for v in _sl().variants()}
    return "u" + tag if ("u" + tag) in every else None
def probe_row(shelf, spec=None, slug="studioprobe"):
    return {"slug": slug, "shapes": spec, "layers": None, "shelf": shelf, "line": 0}
def defaults(shelf):
    return set(_sl().shape_set(probe_row(shelf)))
def shapes_of(spec, shelf):
    return set(_sl().shape_set(probe_row(shelf, spec)))
def spec_for(chosen, shelf):
    chosen = set(chosen) - {"cube"}
    if chosen == defaults(shelf):
        return None
    if not chosen:
        return "none"
    every = {v["tag"] for v in _sl().variants()}
    items, covered = [], set()
    for name, tags in families():
        ups = [t for t in tags if t != "cube"]
        whole = set(ups) | {twin(t) for t in ups if twin(t)}
        if ups and whole <= chosen:
            items.append(name.lower())
            covered |= whole
    for tag in upright_tags():
        if tag == "cube" or tag in covered:
            continue
        tw = twin(tag)
        if tag in chosen:
            items.append(tag)
            covered.add(tag)
            if tw:
                covered.add(tw)
                if tw not in chosen:
                    items.append("-" + tw)
        elif tw and tw in chosen:
            items.append(tw)
            covered.add(tw)
    for tag in sorted(chosen - covered):
        if tag in every:
            items.append(tag)
    got = shapes_of(",".join(items), shelf) if items else set()
    items += ["-" + t for t in sorted(got - chosen)]
    return ",".join(items)
def family_state(chosen, family):
    tags = [t for name, ts in families() if name == family for t in ts if t != "cube"]
    have = [t for t in tags if t in chosen]
    if family == "Blocks":
        tags, have = tags + ["cube"], have + ["cube"]
    return "all" if len(have) == len(tags) else "none" if not have else "some"
def toggle_family(chosen, family, on):
    out = set(chosen)
    for name, tags in families():
        if name != family:
            continue
        for t in tags:
            if t == "cube":
                continue
            for x in (t, twin(t)):
                if x:
                    (out.add if on else out.discard)(x)
    return out
def shape_costs():
    sums = {}
    for shapes in kit().actor_sizes().values():
        for tag, size in shapes.items():
            n, total = sums.get(tag, (0, 0))
            sums[tag] = (n + 1, total + size)
    costs = {tag: total / float(n) for tag, (n, total) in sums.items()}
    for variant in slopes().variants():
        costs.setdefault(variant["tag"], 0.0)
    return costs
def estimate(chosen, costs=None):
    costs = costs if costs is not None else shape_costs()
    mean = sum(costs.values()) / float(len(costs) or 1)
    return int(costs.get("cube", mean) + sum(costs.get(t, mean) for t in set(chosen)
                                              if t != "cube"))
def meter():
    sizes = kit().actor_sizes()
    by_texture = {slug: sum(v.values()) for slug, v in sizes.items()}
    by_shape = {}
    for shapes in sizes.values():
        for tag, size in shapes.items():
            n, b = by_shape.get(tag, (0, 0))
            by_shape[tag] = (n + 1, b + size)
    return {"total": sum(by_texture.values()), "by_texture": by_texture,
            "by_shape": by_shape}
def blocks():
    k = kit()
    _, rows = k.blocks.read_manifest()
    sizes = k.actor_sizes()
    try:
        from mapgen import soft64 as s64
    except Exception:
        s64 = None
    out = []
    for row in rows:
        shapes = set(_sl().shape_set(row))
        fam = s64.family_of(row["slug"]) if s64 is not None else None
        out.append({"key": row["slug"], "name": row["name"], "shelf": row["shelf"],
                    "family": fam[0] if fam else "", "soft64": fam[2] if fam else "",
                    "source": (row.get("layers") or [row["source"]])[0],
                    "layered": bool(row.get("layers")), "shapes": shapes,
                    "spec": row.get("shapes"), "bytes": sum(sizes.get(row["slug"], {}).values()),
                    "pictures": len(sizes.get(row["slug"], {})),
                    "used_by": k.where_used(row["slug"]), "roles": list(row.get("roles") or ()),
                    "was": list(row["was"])})
    return out
def run_kit(*argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            code = kit().main(list(argv))
        except SystemExit as why:
            code = why.code if isinstance(why.code, int) else 2
    return code, out.getvalue().strip()
def rename(key, name, new_key=False, also=()):
    argv = ["rename", key, name]
    if new_key:
        argv.append("--new-key")
        if also:
            argv += ["--also"] + list(also)
    return run_kit(*argv)
def rename_plan(key, name, also=()):
    return kit().rename_plan(key, name, also=also)
def rename_choice(plan):
    if plan["refused"]:
        return False, "%s keeps its key: %s. Only the name changes." % (plan["old"],
                                                                       plan["refused"])
    return True, None
def recode_change(doc, mapping):
    import blockrecode
    from studio.editor import ops
    from studio.editor.commands import Change
    pairs = []
    for ref in doc.refs("piece"):
        item = doc.get(ref)
        new = json.loads(json.dumps(item))
        if blockrecode.recode_layout(new, mapping):
            pairs.append((ref, new))
    if not pairs:
        return None
    return Change("Re-code a renamed block", ops._replace_steps(doc, pairs))
def set_shapes(key, chosen, shelf):
    spec = spec_for(chosen, shelf) or "default"
    return run_kit("shapes", key, spec)
def remove(key, into=None, force=False):
    argv = ["remove", key]
    if into:
        argv += ["--into", into]
    if force:
        argv.append("--force")
    return run_kit(*argv)
def rebuild():
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        try:
            kit().run_builds(quiet=True)
        except kit().Refused as why:
            return False, "%s\n%s" % (out.getvalue().strip(), why)
    return True, out.getvalue().strip() or "both builds are current"
IMAGE_EXT = (".png",)
class Item:
    def __init__(self, path, shelf):
        self.path = path
        self.shelf = shelf
        self.name = None
        self.allow_seams = False
        self.seamless = False
        self.shapes = None
        self.roles = []
        self.skip = False
        self.result = None
    @property
    def ok(self):
        return self.result is not None and not self.result["refusal"]
    def chosen(self):
        return set(self.shapes) if self.shapes is not None else defaults(self.shelf)
    def spec(self):
        return spec_for(self.chosen(), self.shelf)
    def levels(self):
        rank = {"ok": 0, "note": 1, "fail": 2}
        out = {}
        for check, level, _ in (self.result or {}).get("checks", []):
            if rank[level] >= rank.get(out.get(check), -1):
                out[check] = level
        return out
    def fixes(self):
        lv = self.levels()
        out = []
        said = " ".join(t for _, _, t in (self.result or {}).get("checks", []))
        if lv.get("seams") == "fail":
            out.append(("seamless", "Make it seamless"))
            out.append(("allow_seams", "Take it anyway"))
        if lv.get("key") == "fail" or lv.get("name") == "fail":
            out.append(("rename", "Give it another name"))
        if lv.get("duplicate") == "fail" or "the same picture" in said:
            out.append(("skip", "Leave it out"))
        return out
class Inbox:
    def __init__(self, shelf="Blocks"):
        self.items = []
        self.shelf = shelf
        self.faults = []
    def add(self, paths, shelf=None):
        shelf = shelf or self.shelf
        for path in paths:
            path = os.path.expanduser(path)
            if os.path.isdir(path):
                try:
                    found = kit().gather(path, shelf)
                except kit().Refused as why:
                    self.faults.append(str(why))
                    continue
            elif path.lower().endswith(IMAGE_EXT) and os.path.isfile(path):
                found = [(path, shelf)]
            else:
                self.faults.append("%s: not a PNG picture or a folder" % os.path.basename(path))
                continue
            have = {i.path for i in self.items}
            self.items.extend(Item(p, s) for p, s in found if p not in have)
        self.check()
        return self.items
    def remove(self, item):
        self.items.remove(item)
        self.check()
    def check(self):
        k = kit()
        context = k.ImportContext()
        for item in self.items:
            item.result = k.inspect(item.path, item.shelf, context, name=item.name,
                                    allow_seams=item.allow_seams, seamless=item.seamless)
            if item.ok and not item.skip:
                context.claim(item.result)
        return self.items
    def fix(self, item, fix, value=None):
        if fix == "seamless":
            item.seamless = True
        elif fix == "allow_seams":
            item.allow_seams = True
        elif fix == "rename":
            item.name = value
        elif fix == "skip":
            item.skip = True
        elif fix == "shelf":
            item.shelf = value
        self.check()
    def ready(self):
        return [i for i in self.items if i.ok and not i.skip]
    def refused(self):
        return [i for i in self.items if not i.ok and not i.skip]
    def estimate(self, costs=None):
        costs = costs if costs is not None else shape_costs()
        return sum(estimate(i.chosen(), costs) for i in self.ready())
    def plan(self):
        out = []
        for item in self.ready():
            entry = dict(item.result)
            entry["shapes"] = item.spec()
            entry["roles"] = list(item.roles) or None
            out.append(entry)
        return out
def import_now(inbox, date=None, label="Oldfart Studio's texture manager"):
    plan = inbox.plan()
    if not plan:
        raise kit().Refused("nothing is ready to import - fix or leave out what is refused")
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        added = kit().apply_import(plan, label, date, quiet=True)
    names = ", ".join(p["name"] for p in plan)
    said = "imported %d block(s): %s; download %s%s" % (len(plan), names,
                                                        "+" if added >= 0 else "-", kb(abs(added)))
    return added, (said + "\n" + out.getvalue()).strip()
_DRAWINGS = {}
_ICONS = {}
def shape_faces(tag):
    sl = _sl()
    if tag == "cube":
        return [(pts, n) for pts, n in sl.box_faces(sl.LO, sl.HI, 0, sl.TOP, sl.LO, sl.HI)]
    variant = next((v for v in sl.variants() if v["tag"] == tag), None)
    if variant is None:
        raise KeyError("no shape %r" % tag)
    return sl.solid(variant)
def shape_icon(tag):
    if tag not in _ICONS:
        from studio.core import shapeicon
        _ICONS[tag] = shapeicon.drawing(shape_faces(tag))
    return _ICONS[tag]
def shape_drawing(tag):
    if tag not in _DRAWINGS:
        _DRAWINGS[tag] = list(shape_icon(tag).polys)
    return _DRAWINGS[tag]
