from PySide6.QtCore import QByteArray, Qt
WORKSPACES = {
    "build": ("Build", "Ctrl+F1", [
        ("left", ["palette", "tools", "prefabs"]),
        ("right", ["properties", "outliner", "logic"]),
        ("right", ["wish", "report", "issues", "markers", "paths"]),
        ("bottom", ["music", "history", "snapshots"]),
    ]),
    "generate": ("Generate", "Ctrl+F2", [
        ("left", ["palette", "prefabs"]),
        ("right", ["wish"]),
        ("right", ["report", "issues"]),
        ("bottom", ["music", "gallery", "history"]),
    ]),
    "library": ("Library", "Ctrl+F3", [
        ("left", ["prefabs", "contract", "stamps"]),
        ("right", ["verbs", "patterns", "overlays"]),
        ("bottom", ["music", "gallery"]),
    ]),
}
AREAS = {"left": Qt.LeftDockWidgetArea, "right": Qt.RightDockWidgetArea,
         "bottom": Qt.BottomDockWidgetArea}
STATE_KEY = "workspaces"
def live_tab_bars(win):
    from PySide6.QtWidgets import QDockWidget, QTabBar
    groups = []
    for d in win.findChildren(QDockWidget):
        if d.isFloating() or not d.toggleViewAction().isChecked() or not d.isVisible():
            continue
        names = {d.windowTitle()} | {x.windowTitle() for x in win.tabifiedDockWidgets(d)
                                     if x.toggleViewAction().isChecked()}
        groups.append((d.geometry(), names))
    live = []
    for tb in win.findChildren(QTabBar):
        if tb.parent() is not win:
            continue
        names = {tb.tabText(i) for i in range(tb.count())}
        g = tb.geometry()
        for r, want in groups:
            if names == want and abs(g.left() - r.left()) <= 3 and -3 <= g.top() - r.bottom() <= 8:
                live.append(tb)
                break
    return live
def tidy_tab_bars(win):
    from PySide6.QtWidgets import QTabBar
    live = live_tab_bars(win)
    n = 0
    for tb in win.findChildren(QTabBar):
        if tb.parent() is not win:
            continue
        if tb.elideMode() != Qt.ElideNone:
            tb.setElideMode(Qt.ElideNone)
            tb.setUsesScrollButtons(True)
        if tb not in live and tb.isVisible():
            tb.hide()
            n += 1
    return n
def tidy_later(win):
    from PySide6.QtCore import QTimer
    QTimer.singleShot(0, win, lambda: tidy_tab_bars(win))
    QTimer.singleShot(150, win, lambda: tidy_tab_bars(win))
class Workspaces:
    def __init__(self, window):
        self.window = window
        self.current = None
        self.sizes_pending = False
        self.compact = False
        self._firsts = None
    def _state(self):
        settings = getattr(self.window, "settings", None)
        if settings is None:
            return {}
        if settings.state is None:
            settings.state = {}
        return settings.state.setdefault(STATE_KEY, {})
    def plan(self, name, compact=False):
        docks = self.window.docks
        have = set(docks.keys())
        out = []
        for slot, keys in WORKSPACES[name][2]:
            keys = [k for k in keys if k in have]
            if keys:
                out.append((slot, keys))
        if compact and any(s == "left" for s, _ in out) and any(s == "right" for s, _ in out):
            merged = [k for s, keys in out if s == "right" for k in keys]
            out = ([(s, keys) for s, keys in out if s == "left"] + [("left", merged)]
                   + [(s, keys) for s, keys in out if s not in ("left", "right")])
        return out
    def is_compact(self, name):
        from .docks import column_widths
        win, docks = self.window, self.window.docks
        keys_of = {}
        for slot, keys in self.plan(name):
            keys_of.setdefault(slot, []).extend(keys)
        if "left" not in keys_of or "right" not in keys_of:
            return False
        left, right, _ = column_widths(win, docks.needed("left", keys_of["left"]),
                                       docks.needed("right", keys_of["right"]))
        return left + right > 0.6 * max(640, win.width())
    def apply_default(self, name):
        win, docks = self.window, self.window.docks
        shown = set()
        firsts = {}
        for k in docks.keys():
            d = docks.get(k)
            if d.isFloating():
                d.setFloating(False)
            win.removeDockWidget(d)
        self.compact = self.is_compact(name)
        plan = self.plan(name, self.compact)
        heads = []
        for slot, keys in plan:
            first = docks.get(keys[0])
            win.addDockWidget(AREAS[slot], first)
            first.show()
            if slot in firsts:
                win.splitDockWidget(heads[-1][0] if heads[-1][1] == slot else firsts[slot],
                                    first, Qt.Vertical)
            else:
                firsts[slot] = first
            heads.append((first, slot))
            shown.add(keys[0])
        for (first, _), (slot, keys) in zip(heads, plan):
            for k in keys[1:]:
                d = docks.get(k)
                win.tabifyDockWidget(first, d)
                d.show()
                shown.add(k)
        for k in docks.keys():
            if k in shown:
                continue
            d = docks.get(k)
            slot = docks.slot_of(k)
            head = next((f for f, s in reversed(heads) if s == slot), None)
            if head is None:
                win.addDockWidget(AREAS[slot], d)
            else:
                win.tabifyDockWidget(head, d)
            d.hide()
        for first, _ in heads:
            first.raise_()
        self._firsts = (plan, firsts)
        self.apply_sizes()
        if not win.isVisible():
            self.sizes_pending = True
        self.current = name
        tidy_later(win)
        return shown
    def settle(self):
        name = self.current or "build"
        if name in WORKSPACES and self._firsts and self.is_compact(name) != self.compact:
            self.apply_default(name)
            return self.apply_sizes()
        return self.apply_sizes()
    def apply_sizes(self, *_):
        from .docks import column_widths
        self.sizes_pending = False
        got = getattr(self, "_firsts", None)
        if not got:
            return None
        plan, firsts = got
        win, docks = self.window, self.window.docks
        keys_of = {}
        for slot, keys in plan:
            keys_of.setdefault(slot, []).extend(keys)
        left, right, bottom = column_widths(
            win, docks.needed("left", keys_of.get("left", [])),
            docks.needed("right", keys_of.get("right", [])))
        if "right" not in firsts:
            left = max(docks.needed("left", keys_of.get("left", [])),
                       min(left, int(0.4 * max(640, win.width()))))
        if "bottom" in firsts:
            win.resizeDocks([firsts["bottom"]], [bottom], Qt.Vertical)
        sides = [(firsts.get(s), w) for s, w in (("left", left), ("right", right))]
        sides = [(d, w) for d, w in sides if d is not None]
        if sides:
            win.resizeDocks([d for d, _ in sides], [w for _, w in sides], Qt.Horizontal)
        return left, right, bottom
    def switch(self, name):
        if name not in WORKSPACES:
            raise KeyError(name)
        state = self._state()
        if self.current is not None:
            state[self.current] = bytes(self.window.saveState().toBase64()).decode()
        kept = state.get(name)
        self.current = name
        if kept:
            self.window.restoreState(QByteArray.fromBase64(kept.encode()))
            self.current = name
            tidy_later(self.window)
        else:
            self.apply_default(name)
        if getattr(self.window, "settings", None) is not None:
            self.window.settings.state["workspace"] = name
        self.window.hint("Workspace: %s" % WORKSPACES[name][0])
        return name
    def reset(self):
        name = self.current or "build"
        self._state().pop(name, None)
        self.apply_default(name)
        self.window.hint("Layout reset: %s" % WORKSPACES[name][0])
        return name
