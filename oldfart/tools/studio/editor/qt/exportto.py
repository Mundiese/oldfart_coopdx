import os
from PySide6.QtWidgets import QFileDialog, QMessageBox
from .. import engine, modfolder
def run(ed):
    doc = ed.session.doc
    g = engine.gate(doc.to_layout())
    if not g.ok:
        QMessageBox.warning(ed.window, "Not exported",
                            "The safety gate refuses this map:\n\n" + "\n".join(
                                "- " + f for f in g.faults[:8]))
        return None
    start = ed.settings_get("export.folder_to", os.path.expanduser("~"))
    name = engine.key_for(doc.rest.get("name") or "map") or "map"
    parent = QFileDialog.getExistingDirectory(ed.window, "Export the map folder into...", start)
    if not parent:
        return None
    ed.settings_set("export.folder_to", parent)
    folder = os.path.join(parent, name)
    if os.path.exists(folder) and os.listdir(folder) and QMessageBox.question(
            ed.window, "Replace?", "%s exists. Write the map's files into it (files of the "
            "same name are replaced)?" % folder) != QMessageBox.Yes:
        return None
    report = ed.report_text
    def job(progress, cancelled):
        progress(0, 0, "brief, layout, report and the pictures")
        return modfolder.export_folder(doc, folder, report)
    def done(files):
        ed.hint("Map folder written: %s (%d files) - `python3 tools/mapgen export %s` puts it "
                "into a mod" % (folder, len(files), folder))
    ed.jobs.run("Exporting the map folder", job, done,
                lambda reason: ed.hint("Not exported: %s" % reason))
    return folder
