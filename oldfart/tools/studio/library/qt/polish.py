from PySide6.QtWidgets import QAbstractButton, QDockWidget, QToolButton
DOCK_TIPS = {
    "palette": "Shapes, textures, prefabs and markers - drag into a view",
    "wish": "Say what you want; Generate builds it",
    "report": "How good the map is, and what stops an export",
    "properties": "The selection in numbers",
    "history": "Every change; click one to go back",
    "prefabs": "Finished builds - drag into a view, save your own",
    "music": "The mod's tracks and this map's music",
    "scene": "What is open: pieces, textures, the selection",
}
def tooltips(window):
    filled = []
    for aid, action in getattr(window, "actions", {}).items():
        tip = action.toolTip()
        label = action.text().replace("&", "")
        if not tip or tip == label:
            keys = ", ".join(s.toString() for s in action.shortcuts()[:2])
            action.setToolTip(label + ("  (%s)" % keys if keys else ""))
            filled.append(aid)
    for b in window.findChildren(QAbstractButton):
        if b.toolTip():
            continue
        if isinstance(b, QToolButton) and b.defaultAction() is not None:
            b.setToolTip(b.defaultAction().toolTip())
        elif b.text():
            b.setToolTip(b.text().replace("&", ""))
        else:
            continue
        filled.append(b.objectName() or b.text())
    for dock in window.findChildren(QDockWidget):
        key = dock.objectName().replace("dock.", "").replace("dock_", "")
        if not dock.toolTip():
            dock.setToolTip(DOCK_TIPS.get(key, dock.windowTitle()))
            filled.append(dock.windowTitle())
        for b in dock.findChildren(QAbstractButton):
            name = b.objectName()
            if b.toolTip():
                continue
            if name == "qt_dockwidget_floatbutton":
                b.setToolTip("Float the %s panel as its own window (double-click its title to "
                             "dock it again)" % dock.windowTitle())
            elif name == "qt_dockwidget_closebutton":
                b.setToolTip("Close the %s panel - View > Panels brings it back"
                             % dock.windowTitle())
    return filled
def missing(window):
    out = [aid for aid, a in getattr(window, "actions", {}).items() if not a.toolTip()]
    out += [b.text() or b.objectName() for b in window.findChildren(QAbstractButton)
            if not b.toolTip() and (b.text() or b.icon().isNull() is False) and b.isVisible()]
    return out
