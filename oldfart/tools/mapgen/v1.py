import importlib.util
import os
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
REPO = os.path.dirname(TOOLS)
_cache = {}
def _load(name, filename, tools=TOOLS):
    key = (name, tools)
    if key not in _cache:
        spec = importlib.util.spec_from_file_location(name, os.path.join(tools, filename))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _cache[key] = module
    return _cache[key]
def arenas_module():
    return _load("make_arenas", "make-arenas.py")
def frozen_module():
    return _load("make_arenas_v1", "make-arenas-v1.py")
def venue_levels_module():
    return _load("make_venue_levels", "make-venue-levels.py")
VENUES = (("skykeep", "sky_keep"),)
def venue(key):
    m = arenas_module()
    for k, fn in VENUES:
        if k == key:
            arena = getattr(m, fn)()
            for piece in arena["pieces"]:
                piece["model"] = m.model_name(piece)
            return arena
    raise KeyError("no venue %r (one of %s)" % (key, ", ".join(k for k, _ in VENUES)))
def venue_keys():
    return [k for k, _ in VENUES]
