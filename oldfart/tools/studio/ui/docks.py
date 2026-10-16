from PySide6.QtCore import Qt, QTimer
from PySide6.QtWidgets import (QAbstractButton, QAbstractScrollArea, QBoxLayout, QComboBox,
                               QDockWidget, QFrame, QGridLayout, QLineEdit, QScrollArea, QStyle)
AREAS = {"left": Qt.LeftDockWidgetArea, "right": Qt.RightDockWidgetArea,
         "bottom": Qt.BottomDockWidgetArea}
LEFT_FIRST_RUN = 380
LEFT_CAP = 560
FIELD_WIDTH = 80
WIDGETS = (QAbstractButton, QComboBox, QLineEdit)
def _row_width(layout):
    if layout is None:
        return 0
    m = layout.contentsMargins()
    spacing = max(0, layout.spacing())
    if isinstance(layout, QGridLayout):
        rows = {}
        for i in range(layout.count()):
            r, _, _, _ = layout.getItemPosition(i)
            rows.setdefault(r, []).append(_item_width(layout.itemAt(i)))
        widest = max((sum(ws) + spacing * (len(ws) - 1) for ws in rows.values()), default=0)
    elif isinstance(layout, QBoxLayout) and layout.direction() in (QBoxLayout.LeftToRight,
                                                                   QBoxLayout.RightToLeft):
        ws = [w for w in (_item_width(layout.itemAt(i)) for i in range(layout.count())) if w]
        widest = sum(ws) + spacing * max(0, len(ws) - 1)
    else:
        widest = max((_item_width(layout.itemAt(i)) for i in range(layout.count())), default=0)
    return widest + m.left() + m.right()
def _item_width(item):
    if item is None:
        return 0
    if item.layout() is not None:
        return _row_width(item.layout())
    w = item.widget()
    if w is None or (w.isHidden() and w.testAttribute(Qt.WA_WState_ExplicitShowHide)):
        return 0
    if isinstance(w, QLineEdit):
        return FIELD_WIDTH
    if isinstance(w, QComboBox) and w.sizeAdjustPolicy() != QComboBox.AdjustToContents:
        return w.minimumSizeHint().width()
    if isinstance(w, WIDGETS):
        return w.sizeHint().width()
    return needed_width(w)
def needed_width(widget):
    if widget is None:
        return 0
    if callable(getattr(widget, "needed_width", None)):
        return widget.needed_width()
    if isinstance(widget, QScrollArea):
        inner = widget.widget()
        bar = widget.style().pixelMetric(QStyle.PM_ScrollBarExtent)
        return (needed_width(inner) + bar + 4) if inner is not None else 0
    if isinstance(widget, QLineEdit):
        return FIELD_WIDTH
    if isinstance(widget, WIDGETS):
        return widget.sizeHint().width()
    return _row_width(widget.layout())
COMBO_LETTERS = 10
def fold_combos(root):
    n = 0
    for box in root.findChildren(QComboBox):
        if box.sizeAdjustPolicy() == QComboBox.AdjustToContentsOnFirstShow:
            box.setSizeAdjustPolicy(QComboBox.AdjustToMinimumContentsLengthWithIcon)
            box.setMinimumContentsLength(COMBO_LETTERS)
            n += 1
    return n
def ui_scale(window):
    settings = getattr(window, "settings", None)
    try:
        return max(0.5, float(settings["ui.scale"]) / 100.0)
    except Exception:
        return 1.0
def column_widths(window, need_left=0, need_right=0):
    s = ui_scale(window)
    w, h = max(640, window.width()), max(400, window.height())
    left = int(min(340 * s, max(250 * s, w * 0.20)))
    right = int(min(420 * s, max(300 * s, w * 0.24)))
    bottom = int(min(200 * s, max(120 * s, h * 0.17)))
    return max(left, need_left), max(right, need_right), bottom
class Dock(QDockWidget):
    def set_panel(self, widget):
        self._panel = widget
        fold_combos(widget)
        if isinstance(widget, QAbstractScrollArea):
            self.setWidget(widget)
            return
        scroll = QScrollArea()
        scroll.setObjectName("dockscroll")
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll.setWidget(widget)
        self.setWidget(scroll)
    def widget(self):
        return getattr(self, "_panel", None) or super().widget()
class DockSlots:
    def __init__(self, window, panels_menu=None):
        self.window = window
        self.menu = panels_menu
        self._docks = {}
    def add(self, slot, key, title, widget, visible=True):
        if slot not in AREAS:
            raise ValueError("slot is one of %s" % ", ".join(AREAS))
        if key in self._docks:
            dock = self._docks[key][1]
            old = QDockWidget.widget(dock)
            dock.set_panel(widget)
            if old is not None:
                old.deleteLater()
            dock.setWindowTitle(title)
            return dock
        dock = Dock(title, self.window)
        dock.setObjectName("dock_" + key)
        dock.set_panel(widget)
        dock.setFeatures(QDockWidget.DockWidgetMovable | QDockWidget.DockWidgetFloatable
                         | QDockWidget.DockWidgetClosable)
        siblings = [d for s, d in self._docks.values() if s == slot]
        self.window.addDockWidget(AREAS[slot], dock)
        if siblings:
            self.window.tabifyDockWidget(siblings[-1], dock)
        self._docks[key] = (slot, dock)
        if self.menu is not None:
            self.menu.addAction(dock.toggleViewAction())
        dock.setVisible(visible)
        if slot == "left":
            QTimer.singleShot(0, self.window, self.fit_left)
        return dock
    def fit_left(self):
        widest = 0
        keys = [k for k in self.keys("left")]
        for key in keys:
            inner = self.get(key).widget()
            if inner is None:
                continue
            need = min(LEFT_CAP, needed_width(inner))
            inner.setMinimumWidth(need)
            outer = QDockWidget.widget(self.get(key))
            if outer is not inner and outer is not None:
                bar = outer.style().pixelMetric(QStyle.PM_ScrollBarExtent)
                outer.setMinimumWidth(min(LEFT_CAP, need + bar + 4))
            widest = max(widest, need)
        settings = getattr(self.window, "settings", None)
        state = getattr(settings, "state", None) or {}
        if keys and not state.get("docks"):
            want = column_widths(self.window)[0]
            self.window.resizeDocks([self.get(keys[0])], [max(want, widest)], Qt.Horizontal)
        return widest
    def needed(self, slot, keys=None):
        widest = 0
        for key in (keys if keys is not None else self.keys(slot)):
            if key not in self._docks:
                continue
            dock = self.get(key)
            inner = dock.widget()
            if inner is None:
                continue
            need = needed_width(inner)
            if QDockWidget.widget(dock) is not inner:
                need += dock.style().pixelMetric(QStyle.PM_ScrollBarExtent) + 4
            widest = max(widest, need)
        return widest
    def get(self, key):
        return self._docks[key][1]
    def slot_of(self, key):
        return self._docks[key][0]
    def remove(self, key):
        slot, dock = self._docks.pop(key)
        if self.menu is not None:
            self.menu.removeAction(dock.toggleViewAction())
        self.window.removeDockWidget(dock)
        dock.deleteLater()
    def keys(self, slot=None):
        return [k for k, (s, _) in self._docks.items() if slot is None or s == slot]
