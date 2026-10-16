ACTIONS = {
    "file.new": (["Ctrl+N"], "New map", "File"),
    "file.open_map": (["Ctrl+Shift+O"], "Open a map (.ofmap, a generator folder)", "File"),
    "file.save": (["Ctrl+S"], "Save", "File"),
    "file.save_as": (["Ctrl+Shift+S"], "Save as", "File"),
    "file.insert_map": (["Ctrl+Shift+I"], "Insert map\u2026", "File"),
    "edit.undo": (["Ctrl+Z"], "Undo", "Edit"),
    "edit.redo": (["Ctrl+Shift+Z", "Ctrl+Y"], "Redo", "Edit"),
    "edit.copy": (["Ctrl+C"], "Copy", "Edit"),
    "edit.cut": (["Ctrl+X"], "Cut", "Edit"),
    "edit.paste": (["Ctrl+V"], "Paste at the cursor", "Edit"),
    "edit.paste_in_place": (["Shift+V"], "Paste in place", "Edit"),
    "edit.duplicate": (["Shift+D"], "Duplicate", "Edit"),
    "edit.delete": (["Delete", "X"], "Delete", "Edit"),
    "edit.stack": (["Ctrl+Shift+D"], "Stack copies", "Edit"),
    "edit.turn": (["T"], "Turn a quarter", "Edit"),
    "edit.turn_back": (["Shift+T"], "Turn back a quarter", "Edit"),
    "edit.mirror_x": (["Ctrl+M"], "Mirror across x (left-right)", "Edit"),
    "edit.mirror_z": (["Ctrl+Shift+M"], "Mirror across z (front-back)", "Edit"),
    "edit.nudge_left": (["Left"], "Nudge -x one cell", "Edit"),
    "edit.nudge_right": (["Right"], "Nudge +x one cell", "Edit"),
    "edit.nudge_back": (["Up"], "Nudge -z one cell", "Edit"),
    "edit.nudge_front": (["Down"], "Nudge +z one cell", "Edit"),
    "edit.nudge_up": (["PgUp"], "Nudge up one step", "Edit"),
    "edit.nudge_down": (["PgDown"], "Nudge down one step", "Edit"),
    "edit.dup_left": (["Ctrl+Left"], "Duplicate and nudge -x", "Edit"),
    "edit.dup_right": (["Ctrl+Right"], "Duplicate and nudge +x", "Edit"),
    "edit.dup_back": (["Ctrl+Up"], "Duplicate and nudge -z", "Edit"),
    "edit.dup_front": (["Ctrl+Down"], "Duplicate and nudge +z", "Edit"),
    "edit.dup_up": (["Ctrl+PgUp"], "Duplicate and nudge up", "Edit"),
    "edit.paint": (["P"], "Paint the selection with the current texture", "Edit"),
    "edit.eyedropper": (["I"], "Take the selected piece's texture", "Edit"),
    "edit.eraser": (["Shift+X"], "Eraser: click or drag over things to delete them", "Edit"),
    "select.linked": (["L"], "Select connected (magic: same texture/kind/height)", "Select"),
    "select.similar": (["Shift+G"], "Select similar (anywhere)", "Select"),
    "map.generate": (["Ctrl+Return"], "Generate from the wish", "Map"),
    "map.refine": (["Ctrl+Shift+Return"], "Refine (change only what was asked)", "Map"),
    "map.variety": (["Ctrl+Alt+Return"], "Variety - different good maps", "Map"),
    "map.measure": (["F4"], "Measure (report card)", "Map"),
    "map.export": (["F5"], "Export into the mod", "Map"),
    "map.export_to": (["Shift+F5"], "Export a map folder to...", "Map"),
    "map.export_level": (["Ctrl+F5"], "Export level (for any modpack)...", "Map"),
    "map.seed_back": (["Alt+Left"], "The map before (seed history)", "Map"),
    "map.seed_forward": (["Alt+Right"], "The map after (seed history)", "Map"),
    "map.seed_lock": (["Ctrl+Alt+L"], "Lock the seed", "Map"),
    "map.play": (["F6"], "Export and play it", "Map"),
    "map.reskin": (["Ctrl+Alt+T"], "Re-skin in another theme (no new map)", "Map"),
    "map.critic_worst": (["Alt+C"], "Show the critic's weakest point", "Map"),
    "edit.group": (["Ctrl+Alt+G"], "Group the selection", "Edit"),
    "edit.ungroup": (["Ctrl+Alt+U"], "Ungroup", "Edit"),
    "edit.enter_group": (["Ctrl+Alt+E"], "Enter the group (pick inside it)", "Edit"),
    "edit.leave_group": (["Ctrl+Alt+Shift+E"], "Step out of the group", "Edit"),
    "select.ignore_groups": (["Alt+W"], "Pick inside groups (on / off)", "Select"),
    "layer.new": (["Ctrl+L"], "New layer from the selection", "Layers"),
    "layer.hide": (["H"], "Hide the selection", "Layers"),
    "layer.show_all": (["Ctrl+Shift+H"], "Show everything", "Layers"),
    "layer.isolate": (["Shift+H"], "Isolate the selection's layer (again: show all)", "Layers"),
    "layer.lock": (["Ctrl+Shift+L"], "Lock the selection's layer", "Layers"),
    "layer.unlock_all": (["Alt+L"], "Unlock every layer", "Layers"),
    "build.room": (["Ctrl+Alt+R"], "Room by size (walls, floor, doors)", "Build"),
    "build.corridor": (["Ctrl+Alt+C"], "Corridor from A to B", "Build"),
    "build.corridor_path": (["Ctrl+Alt+Shift+C"], "Corridor through clicked points", "Build"),
    "build.stairs": (["Ctrl+Alt+PgUp"], "Stairs between floors", "Build"),
    "build.clip": (["Alt+X"], "Clip boxes by a plane", "Build"),
    "build.hollow": (["Ctrl+H"], "Hollow the boxes (walls of a thickness)", "Build"),
    "build.carve": (["Ctrl+Shift+C"], "Carve the selected box out of the others", "Build"),
    "help.tour": (["Shift+F1"], "Guided tour (start, or skip it)", "Help"),
}
TIPS = {
    "file.insert_map": "Bring another map, or a part of it (a box, its layers or groups), "
                       "into this one - with its targets, buttons and wires, and its sun "
                       "and mood if you want",
    "edit.group": "Glue the selected things together: a click on one picks them all. "
                  "Groups can go in groups",
    "edit.ungroup": "Take the selected groups apart one level (the things and the groups "
                    "inside stay)",
    "edit.enter_group": "Work inside the selected group: clicks pick its parts, Ctrl+Alt+G "
                        "groups them, Ctrl+Alt+U takes its groups apart",
    "edit.leave_group": "Step out of the group you entered: clicks pick it whole again",
    "select.ignore_groups": "On: a click picks one thing even inside a group",
    "layer.new": "Put the selection on a new layer you can hide, lock and colour",
    "layer.hide": "Hide the selected things (Ctrl+Shift+H shows them again)",
    "layer.show_all": "Every hidden layer back, nothing isolated",
    "layer.isolate": "Show only the layer of the selection - press again to see everything",
    "layer.lock": "Lock the layer of the selection: you see it but cannot pick or change it",
    "layer.unlock_all": "Every layer can be picked and changed again",
    "build.room": "A room at the mouse: walls, a floor, doors on the sides you tick, a ceiling "
                  "if you want",
    "build.corridor": "A corridor between two selected things (or two points you type): "
                      "straight or with a turn, walls on both sides, open ends or doors",
    "build.corridor_path": "Click where a corridor goes, point by point - a ghost shows it as "
                           "you click, the corners turn by themselves, Enter builds it",
    "build.stairs": "Flights of stairs from the mouse up to the next floor, landings between",
    "build.clip": "Cut the selected boxes in two along a line; keep both halves or one",
    "build.hollow": "Turn a solid box into a room: its walls, floor and roof stay",
    "build.carve": "Cut the selected box out of everything it overlaps (a doorway, a window)",
    "map.critic_worst": "Fly to the critic's weakest row (the meter in the status bar)",
    "help.tour": "A short walk through the Studio, from an empty map to playing it - press "
                 "again to skip",
}
NUDGE = {"edit.nudge_left": "-x", "edit.nudge_right": "+x", "edit.nudge_back": "-z",
         "edit.nudge_front": "+z", "edit.nudge_up": "+y", "edit.nudge_down": "-y"}
DUP_NUDGE = {"edit.dup_left": "-x", "edit.dup_right": "+x", "edit.dup_back": "-z",
             "edit.dup_front": "+z", "edit.dup_up": "+y"}
def register(keymap_module=None):
    if keymap_module is None:
        from studio.core import keymap as keymap_module
    already = []
    for action, (keys, label, group) in ACTIONS.items():
        if not keymap_module.register(action, keys, label, group):
            already.append(action)
    return already
