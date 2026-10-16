import base64
import json
import os
VERSION = 1
_mem = None
_dirty = False
def cache_path():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "oldfart-studio", "pixels-v%d.json" % VERSION)
def _load():
    global _mem
    if _mem is None:
        _mem = {}
        if os.environ.get("STUDIO_NO_PIXCACHE"):
            return _mem
        try:
            with open(cache_path(), encoding="utf-8") as handle:
                data = json.load(handle)
            if isinstance(data, dict):
                _mem = data
        except (OSError, ValueError):
            _mem = {}
    return _mem
def _key(path, kind):
    try:
        st = os.stat(path)
    except OSError:
        return None
    return "%s|%s|%d|%d" % (kind, os.path.abspath(path), st.st_size, st.st_mtime_ns)
def get(path, kind, compute):
    global _dirty
    key = _key(path, kind)
    mem = _load()
    if key is not None and key in mem:
        got = mem[key]
        try:
            if isinstance(got, dict) and "b64" in got:
                return base64.b64decode(got["b64"])
            return got
        except (ValueError, TypeError):
            pass
    value = compute()
    if key is not None and value is not None:
        mem[key] = {"b64": base64.b64encode(value).decode("ascii")} \
            if isinstance(value, (bytes, bytearray)) else value
        _dirty = True
    return value
def save():
    global _dirty
    if not _dirty or _mem is None or os.environ.get("STUDIO_NO_PIXCACHE"):
        return False
    keep = {}
    for key, value in _mem.items():
        parts = key.split("|")
        if len(parts) == 4 and _key(parts[1], parts[0]) == key:
            keep[key] = value
    path = cache_path()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = path + ".part"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(keep, handle)
        os.replace(tmp, path)
    except OSError:
        return False
    _dirty = False
    return True
def forget():
    global _mem, _dirty
    _mem, _dirty = None, False
