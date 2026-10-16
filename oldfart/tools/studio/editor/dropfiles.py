import os
PICTURES = (".png", ".jpg", ".jpeg", ".bmp", ".gif", ".tga", ".webp")
AUDIO = (".mp3", ".ogg", ".wav", ".flac", ".aiff", ".aif", ".m4a", ".opus", ".m64")
MAP_FILES = (".ofmap", ".json")
GLTF = (".gltf", ".glb")
def _ext(path):
    return os.path.splitext(path)[1].lower()
def _folder_kind(path):
    if os.path.exists(os.path.join(path, "layout.json")) or \
            os.path.exists(os.path.join(path, "brief.json")):
        return "map"
    try:
        names = os.listdir(path)
    except OSError:
        return None
    exts = set(_ext(n) for n in names)
    for sub in names:
        full = os.path.join(path, sub)
        if os.path.isdir(full):
            try:
                exts |= set(_ext(n) for n in os.listdir(full))
            except OSError:
                pass
    if exts & set(AUDIO) and not exts & set(PICTURES):
        return "music"
    if exts & set(PICTURES):
        return "textures"
    return None
def classify(paths):
    paths = [p for p in paths if p]
    if not paths:
        return None, [], "nothing to drop"
    kinds = {}
    for p in paths:
        if os.path.isdir(p):
            k = _folder_kind(p)
        else:
            e = _ext(p)
            k = ("map" if e in MAP_FILES else "textures" if e in PICTURES else
                 "music" if e in AUDIO else "gltf" if e in GLTF else None)
        kinds.setdefault(k, []).append(p)
    if None in kinds or len(kinds) > 1:
        return None, [], "drop one kind at a time: a map, pictures, music or a glTF"
    what, got = next(iter(kinds.items()))
    if what in ("map", "gltf") and len(got) > 1:
        return None, [], "one map at a time"
    words = {"map": "Open the map %s" % os.path.basename(os.path.normpath(got[0])),
             "textures": "Import %d as textures" % len(got) if not os.path.isdir(got[0])
             else "Import the pictures in %s as textures" % os.path.basename(got[0]),
             "music": "Import %d as music" % len(got),
             "gltf": "Import the glTF %s" % os.path.basename(got[0])}[what]
    return what, got, words
