import importlib.util
import os
REGIONS = {
    "of_spawner.lua": [
        ("-- BEGIN BLOCKS (written by tools/make-blocks.py from tools/blocks-manifest.txt"
         " - edit the manifest, not these lines)",
         "-- END BLOCKS", "local BLOCK_WIDTH = ", "local BLOCK_WAS = {", False),
        ("-- BEGIN PREFABS (written by tools/prefabs.py from prefabs/*.prefab"
         " - edit those, not these lines)",
         "-- END PREFABS", "spawner.PREFABS = {", "spawner.PREFABS = {", False),
    ],
    "of_venues.lua": [
        ("-- BEGIN LAYOUTS (written by tools/make-arenas.py - edit the tool, not these lines)",
         "-- END LAYOUTS", "venues.PICTURES_AT_SIZE = ", "venues.LAYOUTS = {", False),
        ("-- BEGIN BAKE", "-- END BAKE", "local BAKE_CELL, ", "function venues.wear_lods(", False),
    ],
    "of_music.lua": [
        ("    -- music.py: rows begin (order: title)", "    -- music.py: rows end",
         "local IMPORTED = {", "local IMPORTED = {", True),
        ("-- music.py: retired begin", "-- music.py: retired end",
         "music.RETIRED_TRACKS = {", "music.RETIRED_TRACKS = {", False),
    ],
}
def _line_at(text, prefix, start=0):
    found = []
    at = start
    while True:
        at = text.find(prefix, at)
        if at < 0:
            break
        if at == 0 or text[at - 1] == "\n":
            found.append(at)
        at += 1
    return found[0] if len(found) == 1 else -1
def _closing(text, opener):
    line = text[opener:text.find("\n", opener)]
    close = "\n}\n" if line.rstrip().endswith("{") else "\nend\n"
    end = text.find(close, opener)
    return -1 if end < 0 else end + len(close)
def restore(text, name):
    for begin, end, first, last, inside in REGIONS.get(name, ()):
        if begin.strip() in text or end.strip() in text:
            continue
        a = _line_at(text, first)
        if a < 0:
            continue
        t = _line_at(text, last, a)
        if t < 0:
            continue
        b = _closing(text, t)
        if b < 0:
            continue
        if inside:
            head = text.find("\n", t) + 1
            text = (text[:head] + begin + "\n" + text[head:b - 2]
                    + end + "\n" + text[b - 2:])
        else:
            text = text[:a] + begin + "\n" + text[a:b] + end + "\n" + text[b:]
    return text
def _stripper():
    import sys
    if "of_strip_comments" not in sys.modules:
        spec = importlib.util.spec_from_file_location(
            "of_strip_comments", os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                              "strip-comments.py"))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules["of_strip_comments"] = module
    return sys.modules["of_strip_comments"]
def is_release(root):
    if any(os.path.isdir(os.path.join(root, d)) for d in ("docs", "tests")):
        return False
    try:
        with open(os.path.join(root, "main.lua"), encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return False
    s = _stripper()
    head = s.header_lines(text)
    try:
        return not any(kind == "comment" and line > head for kind, _, line in s.lex(text))
    except s.LexError:
        return False
def finish(text, root):
    if not is_release(root):
        return text
    return _stripper().tightened(text, None)
