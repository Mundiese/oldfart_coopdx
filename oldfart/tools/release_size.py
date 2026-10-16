#!/usr/bin/env python3
import importlib.util
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ASSET_DIRS = ("actors", "data", "textures", "levels", "sound")
_strip = None
def stripper():
    global _strip
    if _strip is None:
        spec = importlib.util.spec_from_file_location(
            "strip_comments", os.path.join(HERE, "strip-comments.py"))
        _strip = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_strip)
    return _strip
def stripped_size(path):
    s = stripper()
    with open(path, encoding="utf-8") as handle:
        src = handle.read()
    return len(s.keep_header(src, s.tightened(src, s.tool_marker)).encode("utf-8"))
def asset_bytes(root):
    total = 0
    for d in ASSET_DIRS:
        for dirpath, _, names in os.walk(os.path.join(root, d)):
            for name in names:
                total += os.path.getsize(os.path.join(dirpath, name))
    return total
def dev_lua_bytes(root):
    total = 0
    for dirpath, dirnames, names in os.walk(root):
        if os.path.relpath(dirpath, root) == ".":
            dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for name in names:
            if name.endswith((".lua", ".luac")):
                total += os.path.getsize(os.path.join(dirpath, name))
    return total
def release_lua_bytes(root):
    total = 0
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name)
        if not os.path.isfile(path):
            continue
        if name.endswith(".lua"):
            total += stripped_size(path)
        elif name.endswith(".luac"):
            total += os.path.getsize(path)
    return total
MAX_MOD_SIZE = 35 * 1048576
ENGINE_DIRS = (("actors", (".bin", ".col")), ("data", (".bhv",)),
               ("textures", (".tex",)), ("levels", (".lvl",)),
               ("sound", (".m64", ".mp3", ".aiff", ".ogg")))
ENGINE_LUA = (".lua", ".luac")
_UNPORTABLE = set('/\\<>:"|?*')
def portable(name):
    if not name or name.startswith("."):
        return False
    return all(" " <= c <= "~" and c not in _UNPORTABLE for c in name)
def engine_files(root):
    out = []
    def lua_walk(rel):
        here = os.path.join(root, rel) if rel else root
        try:
            names = sorted(os.listdir(here))
        except OSError:
            return
        for name in names:
            if not portable(name):
                continue
            path = os.path.join(here, name)
            sub = os.path.join(rel, name) if rel else name
            if os.path.isdir(path):
                lua_walk(sub)
            elif name.endswith(ENGINE_LUA) and os.path.isfile(path):
                out.append((sub, os.path.getsize(path)))
    lua_walk("")
    for folder, kinds in ENGINE_DIRS:
        here = os.path.join(root, folder)
        if not os.path.isdir(here):
            continue
        for name in sorted(os.listdir(here)):
            path = os.path.join(here, name)
            if portable(name) and name.endswith(kinds) and os.path.isfile(path):
                out.append((folder + "/" + name, os.path.getsize(path)))
    return out
def engine_bytes(root=ROOT):
    return sum(size for _, size in engine_files(root))
def wall_bytes(root=ROOT, release=None):
    if release is None:
        release = sizes(root)["release"]
    return max(release, engine_bytes(root))
def wall_line(n):
    return "%.1f of %d MB as Coop DX counts it" % (n / 1048576.0, MAX_MOD_SIZE // 1048576)
def sizes(root=ROOT):
    assets = asset_bytes(root)
    rel, dev = release_lua_bytes(root), dev_lua_bytes(root)
    return {"release": rel + assets, "release_lua": rel,
            "dev": dev + assets, "dev_lua": dev, "assets": assets,
            "engine": engine_bytes(root)}
def main(argv):
    root = ROOT
    s = sizes(root)
    if "--bytes" in argv:
        print(s["release"])
        return 0
    print("release  %10d bytes (%d KB): Lua stripped %d + assets %d"
          % (s["release"], s["release"] // 1024, s["release_lua"], s["assets"]))
    print("dev tree %10d bytes (%d KB): Lua with comments %d + assets %d"
          % (s["dev"], s["dev"] // 1024, s["dev_lua"], s["assets"]))
    print("engine   %10d bytes (%d KB): %s (the wall: %d)"
          % (s["engine"], s["engine"] // 1024, wall_line(s["engine"]), MAX_MOD_SIZE))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
