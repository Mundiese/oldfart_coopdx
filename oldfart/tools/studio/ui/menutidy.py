from PySide6.QtGui import QKeySequence
FILE_ORDER = (
    ("file.new", False),
    ("file.open", False),
    ("Open Recent", False),
    ("Open more", True),
    ("file.save", False),
    ("file.save_as", False),
    ("file.insert_map", False),
    ("Reload", False),
    ("file.start_over", True),
    ("file.share", False),
    ("Exchange", False),
    ("file.screenshot", True),
    ("app.preferences", True),
    ("Quit", False),
)
OPEN_MORE = ("Open folder", "file.open_code", "file.playground", "Venues", "file.open_map")
EDIT_SUBMENUS = (
    ("Nudge", ("edit.nudge_left", "edit.nudge_right", "edit.nudge_back", "edit.nudge_front",
               "edit.nudge_up", "edit.nudge_down", None, "edit.dup_left", "edit.dup_right",
               "edit.dup_back", "edit.dup_front", "edit.dup_up")),
    ("Group", ("edit.group", "edit.ungroup", "edit.enter_group", "edit.leave_group")),
)
HELP_ORDER = ("lib.wizard", "help.tour", "help.lessons", "help.lesson_next", None,
              "lib.commands", "app.shortcuts", None, "app.controller", None, "About")
ONCE = {"lib.wizard": "Help", "lib.commands": "Help"}
OPENS_A_WINDOW = ("app.preferences", "app.shortcuts", "file.open", "file.save_as",
                  "lib.textures", "lib.taste", "lib.wizard", "help.lessons", "build.room",
                  "build.corridor", "build.stairs", "tools.snapshot", "map.export",
                  "map.play", "file.share", "file.open_code", "file.insert_map")
def _menus(win):
    return {a.text().replace("&", ""): a.menu() for a in win.menuBar().actions()
            if a.menu() is not None}
def ellipsis(text):
    if text.endswith("..."):
        return text[:-3].rstrip() + "…"
    if not text.endswith("…"):
        return text + "…"
    return text
def tidy(win):
    ids = dict(win.actions)
    menus = _menus(win)
    out = []
    f = menus.get("File")
    if f is not None:
        out = _tidy_file(win, f, ids)
    e = menus.get("Edit")
    if e is not None:
        _fold(e, EDIT_SUBMENUS, ids)
    for aid, keep in ONCE.items():
        a = ids.get(aid)
        if a is None:
            continue
        for title, m in menus.items():
            if title != keep and a in m.actions():
                m.removeAction(a)
    h = menus.get("Help")
    if h is not None:
        _order(h, HELP_ORDER, ids)
    for m in list(menus.values()):
        _ellipses(m, ids)
        _trim_separators(m)
    return out
def _order(menu, keys, ids):
    entries = [a for a in menu.actions()]
    for a in entries:
        menu.removeAction(a)
    placed = set()
    for key in keys:
        if key is None:
            menu.addSeparator()
            continue
        a = _find_in(entries, key, ids)
        if a is None:
            a = next((x for x in entries if x.text().replace("&", "").startswith(key)), None)
        if a is not None and a not in placed:
            menu.addAction(a)
            placed.add(a)
    rest = [a for a in entries if a not in placed and not a.isSeparator()]
    if rest:
        about = menu.actions()[-1] if menu.actions() else None
        for a in rest:
            menu.insertAction(about, a)
def _trim_separators(menu):
    prev_sep = True
    acts = menu.actions()
    for a in acts:
        if a.isSeparator():
            if prev_sep:
                menu.removeAction(a)
            prev_sep = True
        else:
            prev_sep = False
    acts = menu.actions()
    while acts and acts[-1].isSeparator():
        menu.removeAction(acts[-1])
        acts = menu.actions()
def _tidy_file(win, f, ids):
    open_act = ids.get("file.open")
    if open_act is not None:
        open_act.setText("Open…")
        if "file.open_map" in ids:
            editor_open = getattr(win, "editor_open_dialog", None)
            if editor_open is not None:
                try:
                    open_act.triggered.disconnect()
                except (RuntimeError, TypeError):
                    pass
                open_act.triggered.connect(lambda _=False: editor_open())
    recent = _find_in(f.actions(), "Recent", {})
    if recent is not None:
        recent.setText("Open Recent")
    quit_act = _find_in(f.actions(), "Quit", {})
    if quit_act is not None and quit_act.shortcut().isEmpty():
        quit_act.setShortcut(QKeySequence("Ctrl+Q"))
    entries = [a for a in f.actions()]
    for a in entries:
        f.removeAction(a)
    placed = set()
    more = f.addMenu("Open more")
    more_act = more.menuAction()
    for key in OPEN_MORE:
        a = _find_in(entries, key, ids)
        if a is not None and a not in placed:
            if key == "file.open_map":
                placed.add(a)
                continue
            more.addAction(a)
            placed.add(a)
    f.removeAction(more_act)
    order = []
    for key, sep in FILE_ORDER:
        a = more_act if key == "Open more" else _find_in(entries, key, ids)
        if a is None or a in placed and a is not more_act:
            continue
        f.addAction(a)
        placed.add(a)
        order.append(a.text())
        if sep:
            f.addSeparator()
    rest = [a for a in entries if a not in placed and not a.isSeparator()]
    if rest:
        f.insertSeparator(quit_act) if quit_act in f.actions() else f.addSeparator()
        for a in rest:
            f.insertAction(quit_act if quit_act in f.actions() else None, a)
            order.append(a.text())
    return order
def _find_in(entries, key, ids):
    want = ids.get(key)
    for a in entries:
        if a.isSeparator():
            continue
        if want is not None:
            if a is want:
                return a
        elif a.text().replace("&", "").rstrip(".…").strip() == key:
            return a
    return None
def _fold(menu, groups, ids):
    for title, keys in groups:
        acts = [ids.get(k) if k else None for k in keys]
        present = [a for a in acts if a is not None and a in menu.actions()]
        if not present:
            continue
        from PySide6.QtWidgets import QMenu
        sub = QMenu(title, menu)
        menu.insertMenu(present[0], sub)
        for a in acts:
            if a is None:
                sub.addSeparator()
            elif a in present:
                menu.removeAction(a)
                sub.addAction(a)
def _ellipses(menu, ids):
    wanting = {ids[k] for k in OPENS_A_WINDOW if k in ids}
    for a in menu.actions():
        if a.isSeparator():
            continue
        t = a.text()
        if a.menu() is not None:
            _ellipses(a.menu(), ids)
            continue
        if t.endswith("...") or a in wanting:
            a.setText(ellipsis(t))
