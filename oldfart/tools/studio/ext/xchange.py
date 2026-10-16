import os
def install(studio):
    from PySide6.QtWidgets import QFileDialog, QMessageBox
    from studio.exchange import docio
    win = studio.window
    ed = getattr(studio, "editor", None)
    def markers():
        return list(getattr(studio.scene, "markers", []) or [])
    def export_gltf():
        if ed is None:
            return
        doc = ed.session.doc
        base = (doc.to_layout().get("key") or doc.brief.get("key") or "map") + ".glb"
        path, _ = QFileDialog.getSaveFileName(
            win, "Export glTF for Blender", os.path.join(os.path.expanduser("~"), base),
            "glTF binary (*.glb);;glTF with embedded data (*.gltf)")
        if not path:
            return
        if not path.lower().endswith((".glb", ".gltf")):
            path += ".glb"
        try:
            _, n, m = docio.export_document(doc, path, markers(), registry=studio.ctx.registry)
        except (OSError, ValueError) as why:
            QMessageBox.warning(win, "Export glTF", "Could not write it: %s" % why)
            return
        ed.hint("glTF: %d pieces and %d markers -> %s (1 Blender unit = 100 game units)"
                % (n, m, path))
    def import_gltf():
        if ed is None:
            return
        path, _ = QFileDialog.getOpenFileName(win, "Import glTF from Blender",
                                              os.path.expanduser("~"),
                                              "glTF (*.glb *.gltf)")
        if not path:
            return
        try:
            change, lines = docio.import_change(ed.session.doc, path)
        except (OSError, ValueError, KeyError) as why:
            QMessageBox.warning(win, "Import glTF", str(why))
            return
        ed.push(change)
        ed.show_text("Back from Blender", "\n".join(lines))
    win.add_action("file.export_gltf", export_gltf, "Export glTF for Blender...", group="File")
    win.add_action("file.import_gltf", import_gltf, "Import glTF from Blender...", group="File")
    file_menu = next((a.menu() for a in win.menuBar().actions()
                      if a.text().replace("&", "") == "File"), None)
    if file_menu is not None:
        quit_ = next((a for a in file_menu.actions() if a.text() == "Quit"), None)
        sub = file_menu.addMenu("Exchange")
        sub.setToolTip("glTF out to Blender (Fast64's scale) and back")
        sub.addAction(win.actions["file.export_gltf"])
        sub.addAction(win.actions["file.import_gltf"])
        if quit_ is not None:
            file_menu.insertMenu(quit_, sub)
    win.actions["file.export_gltf"].setToolTip(
        "The map as glTF 2.0 for Blender: every piece a node with its textures; spawns as "
        "empties. 1 Blender unit = 100 game units (Fast64's default)")
    win.actions["file.import_gltf"].setToolTip(
        "Pieces moved, turned, scaled, copied or deleted in Blender come back as one undo "
        "step; what the kit cannot build is listed")
    return {"export": export_gltf, "import": import_gltf}
