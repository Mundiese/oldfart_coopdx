import importlib.util
import os
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(os.path.dirname(HERE))
ROOT = os.path.dirname(TOOLS)
_MODULES = {}
def _load(name, filename):
    if name not in _MODULES:
        path = os.path.join(TOOLS, filename)
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _MODULES[name] = module
    return _MODULES[name]
def tool():
    return _load("mapgen_v1_live", "make-arenas.py")
def frozen():
    if os.path.exists(os.path.join(TOOLS, "make-arenas-v1.py")):
        return _load("mapgen_v1_frozen", "make-arenas-v1.py")
    return tool()
VENUE_FAMILY = {
    "skykeep": "shooter",
}
VENUE_KEYS = ("skykeep",)
def venues():
    return frozen().arenas()
def venue(key):
    for arena in venues():
        if arena["key"] == key:
            return arena
    raise KeyError("no v1 venue %r (have %s)" % (key, ", ".join(VENUE_KEYS)))
_COLOURS = {}
def texture_colours():
    if _COLOURS:
        return _COLOURS
    try:
        import io
        from PIL import Image
        ma = tool()
        _, rows = ma.blocks.read_manifest()
        for row in rows:
            try:
                png = ma.blocks.read_texture(os.path.join(ROOT, row["source"]))
                im = Image.open(io.BytesIO(png)).convert("RGB")
                px = list(im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata())
                _COLOURS[row["slug"]] = tuple(sum(c[k] for c in px) // len(px) for k in range(3))
            except Exception:
                continue
    except Exception:
        pass
    return _COLOURS
