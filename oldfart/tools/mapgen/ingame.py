import glob
import json
import os
import sys
import tempfile
import zipfile
from . import modpack
SHARED = "oldfart-maps"
SHARED_NAME = "Oldfart Maps"
MANIFEST = "oldfart-maps.json"
MARK = "-- name: Oldfart Maps"
SHARED_MAIN = (MARK + "\n-- description: Maps made with Oldfart Studio.\\n\\nType /ofmap in the "
               "chat to see them and travel to one.\n")
SHARED_FILES = ("main.lua", modpack.RUNTIME_NAME, modpack.README_NAME, MANIFEST)
COOPDX_DIRS = ("sm64coopdx", "sm64ex-coop")
DONE = "Done! Start Coop DX, tick 'Oldfart Maps' in Mods, host, and type /ofmap"
def mods_folders(env=None, home=None, platform=None):
    env = os.environ if env is None else env
    home = home or os.path.expanduser("~")
    platform = platform or sys.platform
    bases = []
    if platform.startswith("win"):
        bases.append(env.get("APPDATA") or os.path.join(home, "AppData", "Roaming"))
    elif platform == "darwin":
        bases.append(os.path.join(home, "Library", "Application Support"))
    else:
        bases.append(env.get("XDG_DATA_HOME") or os.path.join(home, ".local", "share"))
        bases.extend(sorted(glob.glob(os.path.join(home, ".var", "app", "*", "data"))))
    out = [os.path.join(base, name, "mods") for base in bases for name in COOPDX_DIRS]
    if not platform.startswith("win") and platform != "darwin":
        out += [os.path.join(home, "sm64coopdx", "mods"),
                os.path.join(home, "Games", "sm64coopdx", "mods"),
                "/opt/sm64coopdx/mods", "/usr/share/sm64coopdx/mods"]
    return out
def find_mods_folder(env=None, home=None, platform=None, isdir=os.path.isdir):
    places = mods_folders(env, home, platform)
    for path in places:
        if isdir(path):
            return path
    for path in places:
        if isdir(os.path.dirname(path)):
            return path
    return None
def full_mod_in(mods):
    if not mods or not os.path.isdir(mods):
        return False
    for name in sorted(os.listdir(mods)):
        sub = os.path.join(mods, name)
        if os.path.isfile(os.path.join(sub, "of_venues.lua")) and \
                os.path.isfile(os.path.join(sub, "main.lua")):
            return True
    return False
def shared_folder(mods):
    return os.path.join(mods, SHARED)
def _manifest(folder):
    try:
        with open(os.path.join(folder, MANIFEST), encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        data = {}
    if not isinstance(data.get("maps"), dict):
        data["maps"] = {}
    return data
def _write_manifest(folder, data):
    path = os.path.join(folder, MANIFEST)
    with open(path + ".part", "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=1, sort_keys=True)
    os.replace(path + ".part", path)
def maps_in_game(mods):
    folder = shared_folder(mods)
    maps = _manifest(folder)["maps"]
    return sorted(((k, v.get("name") or k) for k, v in maps.items()
                   if os.path.isfile(os.path.join(folder, "oldfart_map_%s.lua" % k))),
                  key=lambda kv: kv[1].lower())
def _own_main(folder):
    path = os.path.join(folder, "main.lua")
    if os.path.isfile(path):
        with open(path, encoding="utf-8", errors="replace") as handle:
            if not handle.read().startswith(MARK + "\n"):
                return False
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(SHARED_MAIN)
    return True
def _drop(folder, rels):
    for rel in sorted(rels):
        path = os.path.join(folder, rel)
        if os.path.isfile(path):
            os.remove(path)
        parent = os.path.dirname(path)
        while parent != folder and os.path.isdir(parent) and not os.listdir(parent):
            os.rmdir(parent)
            parent = os.path.dirname(parent)
def _others(maps, key):
    keep = set()
    for k, v in maps.items():
        if k != key:
            keep.update(v.get("files") or [])
    return keep
def put_in_game(layout, mods, key, name, blurb=None, made=None):
    folder = shared_folder(mods)
    os.makedirs(folder, exist_ok=True)
    _own_main(folder)
    res = modpack.export(layout, folder, key, name, blurb, made)
    rels = sorted({os.path.relpath(p, folder).replace(os.sep, "/") for p in res["files"]}
                  - set(SHARED_FILES))
    data = _manifest(folder)
    old = set((data["maps"].get(key) or {}).get("files") or [])
    _drop(folder, old - set(rels) - _others(data["maps"], key))
    data["maps"][key] = {"name": name, "files": rels}
    _write_manifest(folder, data)
    res.update(folder=folder, fullMod=full_mod_in(mods), maps=maps_in_game(mods))
    return res
def remove_map(mods, key):
    folder = shared_folder(mods)
    data = _manifest(folder)
    entry = data["maps"].pop(key, None)
    if entry is None:
        return False
    _drop(folder, set(entry.get("files") or []) - _others(data["maps"], key))
    if data["maps"]:
        _write_manifest(folder, data)
    else:
        _drop(folder, SHARED_FILES)
        if os.path.isdir(folder) and not os.listdir(folder):
            os.rmdir(folder)
    return True
def mod_main(name):
    clean = " ".join((name or "").split()) or "My maps"
    return ("-- name: %s\n-- description: Maps made with Oldfart Studio.\\n\\n"
            "Type /ofmap in the chat to see them and travel to one.\n" % clean)
def mod_folder_name(name):
    words = "".join(ch if ch.isalnum() else " " for ch in (name or "").lower()).split()
    return "-".join(words) or "my-maps"
def mods_in(mods):
    out = []
    if not mods or not os.path.isdir(mods):
        return out
    for name in sorted(os.listdir(mods), key=str.lower):
        sub = os.path.join(mods, name)
        if name == SHARED or not os.path.isfile(os.path.join(sub, "main.lua")):
            continue
        if os.path.isfile(os.path.join(sub, "of_venues.lua")):
            continue
        out.append(sub)
    return out
def new_mod(mods, name):
    folder = os.path.join(mods, mod_folder_name(name))
    os.makedirs(folder, exist_ok=True)
    main = os.path.join(folder, "main.lua")
    if not os.path.isfile(main):
        with open(main, "w", encoding="utf-8") as handle:
            handle.write(mod_main(name))
    return folder
def zip_folder_name(key):
    return "oldfart-map-%s" % key
def make_zip(layout, path, key, name, blurb=None, made=None):
    if not path.lower().endswith(".zip"):
        path += ".zip"
    top = zip_folder_name(key)
    with tempfile.TemporaryDirectory(prefix="ofmap-zip-") as tmp:
        folder = os.path.join(tmp, top)
        res = modpack.export(layout, folder, key, name, blurb, made)
        with open(os.path.join(folder, "main.lua"), "w", encoding="utf-8") as handle:
            handle.write(zip_main(name))
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        part = path + ".part"
        with zipfile.ZipFile(part, "w", zipfile.ZIP_DEFLATED) as z:
            for root, _dirs, names in os.walk(folder):
                for n in sorted(names):
                    full = os.path.join(root, n)
                    z.write(full, os.path.relpath(full, tmp).replace(os.sep, "/"))
        os.replace(part, path)
    res.update(zip=path, files=[path])
    return res
def done_note(res, name, key):
    lines = [DONE + " (or /ofmap %s)." % key, "",
             "%s is in %s." % (name, res["folder"])]
    if res.get("fullMod"):
        lines += ["", "Oldfart's Mod Menu is installed too: the map also shows up there as one "
                      "of its worlds - nothing else is needed."]
    others = [n for k, n in res.get("maps") or [] if k != key]
    if others:
        lines += ["", "Your other maps in the game: " + ", ".join(others) + "."]
    if res.get("notes"):
        lines += ["", "Good to know:"] + ["  - " + n for n in res["notes"]]
    return "\n".join(lines)
def zip_note(res, name, key):
    return "\n".join([
        "%s is ready to share: %s" % (name, res["zip"]), "",
        "Whoever gets it unpacks it into Coop DX's mods folder, ticks "
        "'Oldfart Map: %s' in Mods, hosts, and types /ofmap %s." % (name, key),
        "Everything is explained in %s inside it." % modpack.README_NAME])
def zip_main(name):
    return mod_main("Oldfart Map: " + name)
def problems(layout, choice, place, key, name):
    if choice == "game":
        if not (place or "").strip():
            return ["Coop DX's mods folder was not found - choose it (it is the folder called "
                    "mods next to Coop DX's saves)"]
        return modpack.problems(layout, shared_folder(place), key, name)
    if choice == "zip":
        out = modpack.problems(layout, os.path.join(tempfile.gettempdir(), "ofmap-zip-check"),
                               key, name)
        if not (place or "").strip():
            out.append("Choose where the zip goes")
        return out
    return modpack.problems(layout, place, key, name)
