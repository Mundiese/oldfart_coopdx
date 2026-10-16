import os
from . import actions, commands, csg, geometry as geo, groups, ops, rooms, \
    selection as selmod
from .document import Document, DocumentError, empty_layout
def keep_sun(doc, layout):
    sun = (doc.rest.get("look") or {}).get("sun")
    if not isinstance(sun, dict) or not isinstance(layout, dict):
        return layout
    look = layout.get("look") if isinstance(layout.get("look"), dict) else {}
    if isinstance(look.get("sun"), dict):
        return layout
    import copy
    out = dict(layout)
    out["look"] = dict(copy.deepcopy(look), sun=copy.deepcopy(sun))
    return out
class Session:
    def __init__(self, doc=None, autosaver=None):
        self.origin = "Opened" if doc is not None else "New map"
        self.doc = doc or Document({}, empty_layout())
        self.selection = selmod.Selection(self.doc)
        self.whole_groups = True
        self.group_focus = None
        self.selection.filter = lambda refs: groups.select_filter(self.doc, refs,
                                                                  self.whole_groups,
                                                                  self.focus())
        self.stack_filters = []
        self.stack = commands.CommandStack(self.doc)
        self._wire_stack()
        self.clipboard = ops.Clipboard()
        self.cursor = (0.0, 0.0, 0.0)
        self.texture = "stone1"
        self.magic = ("texture",)
        self.snap_on = True
        self.step = geo.GRID
        self.stack_count = 3
        self.stack_direction = "+x"
        self.stack_gap = 0
        self.paste_turns = 0
        self.prefab_opts = {"merge": True, "mirror": None, "ruin": 0.0, "seed": 1}
        self.texture2 = "mossyrock"
        self.room = {"w": 6, "d": 6, "h": 600, "doors": ["+z"], "ceiling": False}
        self.corridor = {"width": 2, "h": 500, "ceiling": False, "a": None, "b": None,
                         "shape": "xz", "doors": [], "via": []}
        self.stairs = {"rise": 400, "direction": "+z", "width": 2}
        self.clip = {"axis": "x", "at": None, "keep": "both"}
        self.hollow_thick = 200
        self.autosaver = autosaver
        self.listeners = []
    def _tell(self, event, payload=None):
        for fn in list(self.listeners):
            fn(event, payload)
    def status(self, text):
        self._tell("status", text)
        return text
    def title(self):
        name = self.doc.rest.get("name") or self.doc.brief.get("name") or "Untitled map"
        path = self.doc.meta.get("path")
        dirty = "" if self.stack.is_clean() else " *"
        return "%s%s%s" % (name, (" - " + os.path.basename(path)) if path else "", dirty)
    def focus(self):
        if self.group_focus and groups.get_group(self.doc, self.group_focus) is None:
            self.group_focus = None
        return self.group_focus
    def _replace_doc(self, doc, origin="Opened"):
        self.origin = origin
        self.group_focus = None
        self.doc = doc
        self.selection.doc = doc
        self.selection.set([])
        self.stack = commands.CommandStack(doc)
        self._wire_stack()
        self._tell("document", doc)
    def new(self, brief=None):
        self._replace_doc(Document(brief or {}, empty_layout()), origin="New map")
        return self.status("A new map on The Tiles - drag pieces in or generate one from a wish")
    def open(self, path):
        self.open_failed = None
        try:
            doc = Document.load(path)
        except (OSError, ValueError, DocumentError, TypeError, AttributeError,
                KeyError) as why:
            self.open_failed = open_error(path, why)
            return self.status("Could not open %s: %s" % (os.path.basename(path.rstrip("/")),
                                                          self.open_failed))
        self._replace_doc(doc)
        return self.status("Opened %s (%d pieces, %d spawns)" % (
            os.path.basename(path.rstrip("/")), len(doc.refs("piece")), len(doc.refs("spawn"))))
    open_failed = None
    def save(self, path=None):
        path = path or self.doc.meta.get("path")
        if not path:
            return None
        if not path.endswith(".ofmap"):
            path += ".ofmap"
        if self.autosaver is not None:
            self.autosaver.discard(self.doc)
        self.doc.save(path)
        self.stack.mark_clean()
        if self.autosaver is not None:
            self.autosaver.discard(self.doc)
        self.status("Saved %s" % path)
        return path
    def _wire_stack(self):
        self.stack.selection = self.selection
        self.stack.filters = self.stack_filters
        self.stack.guard = groups.guard_locked
        self.stack.listeners.append(lambda *_: self.selection.refilter())
    def autosave_tick(self, now=None):
        if self.autosaver is None:
            return None
        return self.autosaver.tick(self.doc, self.stack, now)
    def apply_generated(self, gen):
        layout = keep_sun(self.doc, gen.layout)
        from mapgen import mood as moodmod
        layout = moodmod.keep(self.doc.rest.get("look"), layout)
        layout, ids, meta, kept = groups.keep_locked(self.doc, layout)
        self.stack.push(ops.replace_map(self.doc, gen.brief, layout, gen.label or "Generate",
                                        ids=ids, meta=meta))
        return self.status("%s: %d pieces, %d spawns%s" % (
            gen.label or "Generated", len(self.doc.refs("piece")), len(self.doc.refs("spawn")),
            "; the locked layers kept (%d thing%s)" % (kept, "" if kept == 1 else "s")
            if kept else ""))
    def set_brief(self, changes, label="Change the wish"):
        self.stack.push(ops.set_brief(self.doc, changes, label))
    def refs(self):
        return [r for r in self.selection.refs if r in self.doc]
    def push(self, change):
        if self.stack.push(change):
            return self.status(change.label)
        if self.stack.refused is not None:
            return self.status(self.stack.refused.label)
        if change.refused:
            return self.status(change.label)
        return self.status("Nothing to do")
    def need_selection(self):
        return self.status("Select something first (click, drag a box, or L for connected)")
    def drop(self, entry, cursor=None, theme=None, items=None):
        if items is None:
            items = entry.make(self.texture, theme or self.doc.brief.get("theme"),
                               self.prefab_opts if entry.section == "prefabs" else None)
        if not items:
            return self.status("%s has nothing to place" % entry.label)
        names = [i.get("_name") for k, i in items if k == "spot" and "_slot" not in i]
        got = [(r, s) for r, s in self.doc.spots(names[0]) if "_slot" not in s] \
            if len(items) == 1 and names and names[0] else []
        if got:
            ref, spot = got[0]
            at = ops.geo.placed_at([i for k, i in items], cursor or self.cursor, self.snap_on)
            p = at[0] if at else spot
            what = "the world spawn" if names[0] == "world" else entry.label.lower()
            if names[0] != "world":
                what = "the " + what
            return self.push(ops.set_fields(self.doc, [ref], label="Move %s" % what,
                                            x=p.get("x", 0), y=p.get("y", 0), z=p.get("z", 0)))
        change = ops.place(self.doc, items, cursor or self.cursor, self.snap_on,
                           "Place %s" % entry.label, anchor=entry.data.get("anchor"))
        return self.push_built(change)
    def push_built(self, change):
        msg = self.push(change)
        new = change.select or [s[1] for s in change.steps if s[0] == "insert"]
        clash = self.sharing_space(new)
        if clash and msg == change.label:
            msg = self.status("%s - it shares space with %s; Export refuses that (move it, or "
                              "Ctrl+Z)" % (change.label, clash))
        return msg
    def sharing_space(self, refs):
        mine = [r for r in refs if r[0] == "piece" and r in self.doc]
        if not mine:
            return ""
        boxes = [geo.aabb(self.doc.get(r)) for r in mine]
        hit = []
        for r in self.doc.refs("piece"):
            if r in mine:
                continue
            b = geo.aabb(self.doc.get(r))
            if any(geo.overlap_volume(a, b) > 0 for a in boxes):
                hit.append(r)
        if not hit:
            return ""
        if len(hit) == 1:
            return groups.describe(self.doc, hit[0]).split(" at ")[0]
        return "%d pieces" % len(hit)
    def do(self, action):
        if action not in actions.ACTIONS:
            raise KeyError(action)
        refs = self.refs()
        doc = self.doc
        if action == "edit.undo":
            ch = self.stack.undo()
            return self.status("Undid %s" % ch.label if ch else "Nothing to undo")
        if action == "edit.redo":
            ch = self.stack.redo()
            return self.status("Redid %s" % ch.label if ch else "Nothing to redo")
        if action == "file.new":
            return self.new()
        if action in ("file.save", "file.save_as", "file.open_map", "map.generate", "map.refine",
                      "map.variety", "map.measure", "map.export", "map.play",
                      "map.export_to", "map.export_level", "map.seed_back", "map.seed_forward",
                      "map.seed_lock"):
            return None
        if action == "edit.leave_group":
            return self.leave_group()
        if action == "select.ignore_groups":
            self.whole_groups = not self.whole_groups
            return self.status("Clicks pick whole groups" if self.whole_groups else
                               "Clicks pick single things, even inside groups (Alt+W: "
                               "whole groups again)")
        if action == "layer.show_all":
            return self.push(groups.show_all(doc))
        if action == "layer.unlock_all":
            return self.push(self._unlock_all())
        if action == "build.room":
            return self.build_room()
        if action == "build.stairs":
            return self.build_stairs()
        if action == "build.corridor":
            return self.build_corridor()
        if action == "build.corridor_path":
            return self.status("The corridor's path is a tool of the views: click where it "
                               "goes, Enter builds it")
        if action in ("map.critic_worst", "help.tour"):
            return None
        if action == "file.insert_map":
            return self.status("Insert map picks a map in a window and places it with the "
                               "mouse: File > Insert map… (Ctrl+Shift+I)")
        if action == "edit.paste":
            if not self.clipboard:
                return self.status("The clipboard is empty - copy something first (Ctrl+C)")
            return self.push(self.clipboard.paste_at(doc, self.cursor, self.paste_turns,
                                                     self.snap_on))
        if action == "edit.paste_in_place":
            if not self.clipboard:
                return self.status("The clipboard is empty - copy something first (Ctrl+C)")
            return self.push(self.clipboard.paste_in_place(doc))
        if not refs:
            return self.need_selection()
        if action == "edit.copy":
            n = self.clipboard.copy(doc, refs)
            return self.status("Copied %d item%s" % (n, "" if n == 1 else "s"))
        if action == "edit.cut":
            return self.push(self.clipboard.cut(doc, refs))
        if action == "edit.duplicate":
            return self.push(ops.duplicate(doc, refs))
        if action == "edit.delete":
            return self.push(ops.delete(doc, refs))
        if action == "edit.stack":
            return self.push(ops.stack(doc, refs, self.stack_count, self.stack_direction,
                                       self.stack_gap))
        if action == "edit.turn":
            return self.push(ops.rotate(doc, refs, 1))
        if action == "edit.turn_back":
            return self.push(ops.rotate(doc, refs, 3))
        if action == "edit.mirror_x":
            return self.push(ops.mirror(doc, refs, "x"))
        if action == "edit.mirror_z":
            return self.push(ops.mirror(doc, refs, "z"))
        if action in actions.NUDGE:
            return self.push(ops.nudge(doc, refs, actions.NUDGE[action]))
        if action in actions.DUP_NUDGE:
            vx, vy, vz = ops.DIRECTIONS[actions.DUP_NUDGE[action]]
            return self.push(ops.duplicate(doc, refs, vx * geo.GRID, vy * geo.YGRID,
                                           vz * geo.GRID))
        if action == "edit.paint":
            return self.push(ops.retexture(doc, refs, self.texture))
        if action == "edit.eyedropper":
            for r in refs:
                if r[0] == "piece":
                    self.texture = doc.get(r)["tex"]
                    self._tell("texture", self.texture)
                    return self.status("Texture: %s" % self.texture)
            return self.status("Select a piece to take its texture")
        if action in ("select.linked", "select.similar"):
            seed = next((r for r in refs if r[0] == "piece"), None)
            if seed is None:
                return self.status("Select a piece first")
            got = selmod.magic_select(doc, seed, self.magic,
                                      connected=action == "select.linked")
            self.selection.set(got)
            return self.status("%d pieces with the same %s" % (len(got), " and ".join(self.magic)))
        if action == "edit.group":
            return self.push(groups.group(doc, refs, focus=self.focus()))
        if action == "edit.ungroup":
            return self.push(groups.ungroup(doc, refs, focus=self.focus()))
        if action == "edit.enter_group":
            g = next((groups.level_group(doc, r, self.focus()) for r in refs
                      if groups.level_group(doc, r, self.focus())), None)
            if g is None:
                return self.status("Select a group to enter (Ctrl+Alt+G makes one)")
            return self.enter_group(g["id"])
        if action == "layer.new":
            return self.push(groups.new_layer(doc, None, refs))
        if action == "layer.hide":
            return self.push(groups.hide_selection(doc, refs))
        if action in ("layer.isolate", "layer.lock"):
            lay = next((groups.layer_of(doc, r) for r in refs if groups.layer_of(doc, r)), None)
            if lay is None:
                return self.status("The selection is on no layer - Ctrl+L puts it on a new one")
            if action == "layer.isolate":
                return self.push(groups.isolate(doc, lay["id"]))
            return self.push(groups.set_layer(doc, lay["id"], locked=True))
        if action == "build.clip":
            c = self.clip
            return self.push(csg.clip(doc, refs, c["axis"], c["at"], c["keep"]))
        if action == "build.hollow":
            return self.push(csg.hollow(doc, refs, self.hollow_thick))
        if action == "build.carve":
            return self.push(csg.carve(doc, refs))
        if action == "map.reskin":
            return self.status("Re-skin: pick the theme (Map > Re-skin)")
        if action == "edit.eraser":
            return self.status("The eraser is a tool of the views: click or drag over things")
        raise KeyError(action)
    def enter_group(self, gid):
        g = groups.get_group(self.doc, gid)
        if g is None:
            return self.status("No group %s" % gid)
        self.group_focus = gid
        self.selection.refilter()
        self._tell("focus", gid)
        return self.status("Inside group %s: clicks pick its parts - Ctrl+Alt+Shift+E steps "
                           "out" % g.get("name"))
    def leave_group(self):
        g = groups.get_group(self.doc, self.focus()) if self.focus() else None
        if g is None:
            return self.status("Not inside a group (Ctrl+Alt+E enters the selected one)")
        up = groups.parent_of(self.doc, g)
        self.group_focus = up["id"] if up else None
        self.selection.refilter()
        self._tell("focus", self.group_focus)
        return self.status("Inside group %s" % up.get("name") if up else
                           "Out of the groups: clicks pick whole groups")
    def _unlock_all(self):
        before = groups.layers(self.doc)
        if not any(lay.get("locked") for lay in before):
            return commands.Change("No layer is locked")
        after = [dict(lay, locked=False) for lay in before]
        return commands.Change("Unlock every layer", [("meta", "layers",
                                                       [dict(lay) for lay in before], after)])
    def build_room(self, centre=None, **settings):
        self.room.update(settings)
        r = self.room
        ch, _ = rooms.room_at(self.doc, centre or self.cursor, r["w"], r["d"], r["h"],
                              r["doors"], r["ceiling"], self.texture, self.texture2)
        return self.push_built(ch)
    def corridor_ends(self):
        refs = self.refs()
        if len(refs) >= 2:
            ends = []
            for r in (refs[0], refs[-1]):
                b = geo.aabb(self.doc.view_item(r))
                ends.append(((b[0] + b[1]) / 2.0, b[3] if r[0] == "piece" else b[2],
                             (b[4] + b[5]) / 2.0))
            if (ends[0][0], ends[0][2]) != (ends[1][0], ends[1][2]):
                return ends[0], ends[1]
        c = self.corridor
        if c.get("a") and c.get("b"):
            return tuple(c["a"]), tuple(c["b"])
        x, y, z = self.cursor
        return (x, y, z), (x + 6 * geo.GRID, y, z)
    def build_corridor(self, a=None, b=None, **settings):
        self.corridor.update(settings)
        if a is None or b is None:
            a, b = self.corridor_ends()
        self.corridor["a"], self.corridor["b"] = list(a), list(b)
        c = self.corridor
        ch, _ = rooms.corridor(self.doc, a, b, c["width"], c["h"], c["ceiling"], self.texture,
                               self.texture2, via=[tuple(p) for p in c.get("via") or ()]
                               if c.get("shape") == "path" else (),
                               shape=c.get("shape") or "xz", doors=tuple(c.get("doors") or ()))
        return self.push_built(ch)
    def corridor_path(self, points, **settings):
        if len(points) < 2:
            return self.status("A corridor needs two points or more - click where it goes")
        settings = dict(settings, shape="path", via=[list(p) for p in points[1:-1]])
        return self.build_corridor(points[0], points[-1], **settings)
    def build_stairs(self, start=None, **settings):
        self.stairs.update(settings)
        st = self.stairs
        start = tuple(start or self.cursor)
        ch, _ = rooms.stairs(self.doc, start, start[1] + st["rise"], st["direction"],
                             st["width"], self.texture)
        return self.push_built(ch)
    def magic_click(self, ref, mode="replace"):
        if ref is None or ref[0] != "piece":
            self.selection.click(ref, mode)
            return None
        got = selmod.magic_select(self.doc, ref, self.magic, connected=True)
        self.selection.combine(got, mode)
        return self.status("%d connected pieces with the same %s" % (len(got),
                                                                    " and ".join(self.magic)))
    def empty_hint(self, keys=None):
        def key(action):
            got = (keys or {}).get(action) or actions.ACTIONS[action][0]
            return got[0] if isinstance(got, list) else got
        return ["An empty map - start it one of three ways",
                "%s  build a map from your wish (type it in the Wish panel)" % key("map.generate"),
                "Click a palette item, then click here  put a piece down",
                "%s  a room at the mouse, %s  a corridor, %s  stairs" % (
                    key("build.room"), key("build.corridor"), key("build.stairs")),
                "Shift+F1  the guided tour      F3  find any command"]
    def selection_line(self):
        info = selmod.info(self.doc, self.refs())
        if not info["count"]:
            pieces = len(self.doc.refs("piece"))
            budget = self.doc.rest.get("budget") or 120
            return "%d pieces of %d, %d spawns" % (pieces, budget, len(self.doc.refs("spawn")))
        texs = ", ".join("%s %d" % (t, n) for t, n in sorted(info["textures"].items(),
                                                            key=lambda kv: -kv[1])[:3])
        return "%d selected - %d x %d cells, %.1f s across%s" % (
            info["count"], info["cells"][0], info["cells"][1], info["seconds"],
            (" - " + texs) if texs else "")
def open_error(path, why):
    import json
    name = os.path.basename(str(path).rstrip("/")) or str(path)
    if isinstance(why, FileNotFoundError):
        return "%s is not there any more (moved or deleted)" % name
    if isinstance(why, PermissionError):
        return "%s may not be read (no permission)" % name
    if isinstance(why, IsADirectoryError) or (os.path.isdir(str(path)) and isinstance(
            why, OSError)):
        return "the folder %s holds no map (no layout.json or .ofmap in it)" % name
    if isinstance(why, json.JSONDecodeError):
        return ("%s is damaged or not a map - it is not readable map data (line %d, column %d)"
                % (name, why.lineno, why.colno))
    if isinstance(why, UnicodeDecodeError):
        return "%s is not a map file (it is not text)" % name
    if isinstance(why, DocumentError):
        text = str(why)
        if ": neither " in text:
            return "%s is not a map: neither an Oldfart Studio map, a layout nor a brief" % name
        return text.replace(os.path.abspath(str(path)), name).replace(str(path), name)
    if isinstance(why, (TypeError, AttributeError, KeyError)):
        return "%s is damaged or not a map (its data is not what a map holds)" % name
    return "%s: %s" % (name, why)
