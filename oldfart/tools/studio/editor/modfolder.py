import glob
import json
import os
from . import REPO
NEEDS = ("of_venues.lua", "of_arena.lua", "levels")
PATTERNS = (
    "~/.local/share/sm64coopdx/mods/*",
    "~/.var/app/*/data/sm64coopdx/mods/*",
    "~/.local/share/sm64ex-coop/mods/*",
    "~/sm64coopdx/mods/*",
    "~/Games/sm64coopdx/mods/*",
    "/opt/sm64coopdx/mods/*",
    "/usr/share/sm64coopdx/mods/*",
    "~/AppData/Roaming/sm64coopdx/mods/*",
)
def packaged_tree():
    try:
        from studio import packaged
        return packaged.info(REPO) is not None
    except ImportError:
        return False
def is_mod(path):
    return bool(path) and os.path.isdir(path) and all(
        os.path.exists(os.path.join(path, n)) for n in NEEDS)
def candidates(home=None, patterns=PATTERNS):
    out = []
    for pattern in patterns:
        if home is not None and pattern.startswith("~"):
            pattern = os.path.join(home, pattern[2:])
        for path in sorted(glob.glob(os.path.expanduser(pattern))):
            path = os.path.realpath(path)
            if is_mod(path) and path not in out:
                out.append(path)
    out.sort(key=lambda p: 0 if "oldfart" in os.path.basename(p).lower() else 1)
    repo = os.path.realpath(REPO)
    if is_mod(repo) and repo not in out and not packaged_tree():
        out.append(repo)
    return out
def choose(remembered=None, home=None, patterns=PATTERNS):
    if remembered and is_mod(remembered):
        return os.path.realpath(remembered)
    found = candidates(home, patterns)
    if found:
        return found[0]
    return "" if packaged_tree() else os.path.realpath(REPO)
def why_not(path):
    if not path:
        return "choose the mod folder"
    if not os.path.isdir(path):
        return "%s is not a folder" % path
    missing = [n for n in NEEDS if not os.path.exists(os.path.join(path, n))]
    if missing:
        return "%s has no %s - is it the mod folder?" % (path, ", ".join(missing))
    return None
def export_folder(doc, folder, report_text=None, pictures=True):
    from . import engine
    layout = doc.to_layout()
    g = engine.gate(layout)
    if not g.ok:
        raise engine.EngineError("; ".join("safety gate: %s" % f for f in g.faults[:8]))
    files = doc.write_out_folder(folder)
    if report_text:
        path = os.path.join(folder, "report.md")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(report_text)
        files.append(path)
    if pictures and layout.get("pieces"):
        try:
            from mapgen import export as exportmod
            from mapgen.render import views
            arena = json.loads(json.dumps(layout))
            arena.setdefault("key", engine.key_for(doc.rest.get("name") or "map") or "map")
            top = os.path.join(folder, "top.png")
            exportmod.draw(arena, top)
            files.append(top)
            files += sorted(views.render_all(arena, folder).values())
        except ImportError as why:
            files.append("(no pictures: %s)" % why)
    return files
