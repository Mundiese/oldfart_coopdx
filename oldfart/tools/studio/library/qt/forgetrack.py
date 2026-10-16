import os
from PySide6.QtWidgets import QFileDialog, QInputDialog, QMessageBox
from studio.library import forgetrack, prefablib
def _save_path(lib, title):
    start = (prefablib.save_locations() or [os.path.expanduser("~")])[0]
    path, _ = QFileDialog.getOpenFileName(lib.window, title, start,
                                          "Mod storage (*.sav);;All files (*)")
    return path
def import_build(lib, path=None, key=None):
    path = path or _save_path(lib, "The mod's save file (Coop DX keeps it in its sav folder)")
    if not path:
        return None
    try:
        store = forgetrack.read_storage(path)
    except OSError as why:
        QMessageBox.warning(lib.window, "No save", str(why))
        return None
    levels = forgetrack.kept_levels(store)
    if not levels:
        QMessageBox.warning(lib.window, "Nothing kept", "This save keeps no Forge build.")
        return None
    races = set(store.get(forgetrack.RACE_INDEX, "").split(","))
    names = ["%s - %d things%s" % (k, n, " - holds a track" if k in races else "")
             for k, n in levels]
    if key is None:
        picked, ok = QInputDialog.getItem(lib.window, "Which level", "Kept builds in the save:",
                                          names, 0, False)
        if not ok:
            return None
        key = levels[names.index(picked)][0]
    try:
        change = forgetrack.import_change(lib.ed.session.doc, path, key)
    except forgetrack.Refused as why:
        QMessageBox.warning(lib.window, "Refused", str(why))
        return None
    lib.ed.push(change)
    lib.ed.hint("Forge build %s: move, turn, copy and delete its things; "
                "Library > Forge build back into the game save when done" % key)
    return key
def number_gates(lib):
    try:
        change, count = forgetrack.number_change(lib.ed.session.doc)
    except forgetrack.Refused as why:
        lib.ed.hint(str(why))
        return 0
    if count == 0:
        lib.ed.hint("No race gates in this map")
        return 0
    try:
        lib.ed.push(change)
    except forgetrack.Refused as why:
        lib.ed.hint(str(why))
        return 0
    lib.ed.hint("%d gates numbered from each track's start ring along the road" % count)
    return count
def export_build(lib, path=None):
    doc = lib.ed.session.doc
    where = doc.meta.get("forge") or {}
    path = path or where.get("save") or _save_path(lib, "Write into which save file")
    if not path:
        return None
    key = where.get("key")
    if not key:
        key, ok = QInputDialog.getText(lib.window, "Which level",
                                       "The level's key in the save (as the game keeps it, e.g. 9a1):")
        if not ok or not key.strip():
            return None
        key = key.strip()
    try:
        count, said = forgetrack.export_doc(doc, path, key)
    except (forgetrack.Refused, OSError) as why:
        QMessageBox.warning(lib.window, "Refused", str(why))
        return None
    lib.ed.hint("Kept %d things for %s in %s (the old file is %s.bak)%s" % (
        count, key, os.path.basename(path), os.path.basename(path),
        (" - " + said) if said else ""))
    return count
