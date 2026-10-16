from studio.editor import geometry as geo
from . import autoshape as autoshapemod, brushes, build, dress, measure, overlays, snapshots, \
    symmetry
from .brushes import Brush
from .symmetry import MODES as SYM_MODES, Symmetry, map_centre
ACTIONS = {
    "tools.select": (["Shift+Q"], "Select tool (no brush)", "Tools",
                     "Back to selecting: clicks select, drags box-select (Esc in a view does it too)"),
    "tools.brush_paint": (["Shift+P"], "Brush: paint", "Tools", brushes.HINTS["paint"]),
    "tools.brush_raise": (["Shift+E"], "Brush: raise ground", "Tools", brushes.HINTS["raise"]),
    "tools.brush_lower": (["Shift+W"], "Brush: lower ground", "Tools", brushes.HINTS["lower"]),
    "tools.brush_scatter": (["Shift+C"], "Brush: scatter", "Tools", brushes.HINTS["scatter"]),
    "tools.brush_fill": (["Shift+F"], "Brush: fill", "Tools", brushes.HINTS["fill"]),
    "tools.brush_bigger": (["Alt+]"], "Brush bigger", "Tools", "The brush one cell wider"),
    "tools.brush_smaller": (["Alt+["], "Brush smaller", "Tools", "The brush one cell narrower"),
    "tools.ruler": (["D"], "Ruler in Mario seconds", "Tools",
                    "Click points: the distance and the run, long-jump and walk times"),
    "tools.path": (["J"], "Walk path in Mario seconds", "Tools",
                   "Click two points: the way Mario walks between them, with its times"),
    "tools.symmetry": (["Shift+S"], "Symmetry: next mode", "Tools",
                       "Off, mirror x, mirror z, both, radial 2/3/4/6/8 - every edit repeats "
                       "on the twins"),
    "tools.symmetry_centre": (["Alt+Shift+S"], "Symmetry centre on the selection", "Tools",
                              "Put the symmetry's centre on the selection (or the map's middle)"),
    "tools.dress": (["Ctrl+B"], "Auto-dress", "Tools",
                    "BEAUTY's rules on the selection (or the whole map): palette, edge rails, "
                    "pillars, battlements, columns under overhangs, light"),
    "tools.region": (["Ctrl+R"], "Regenerate the selected region", "Tools",
                     "Build only the area the selection spans again from the wish; the rest "
                     "stays, the seam passes the safety gate"),
    "tools.fill_region": (["Ctrl+Shift+F"], "Fill the selected region", "Tools",
                          "A floor in every empty cell of the area the selection spans"),
    "tools.autoshape": (["Alt+Shift+A"], "Auto-shape the steps", "Tools",
                        "Slope the ground's one-layer steps in the selection (or the whole "
                        "map): ramps and corners picked by the neighbours, straight runs "
                        "first, 26.6 degrees (SM64 never slides on them)"),
    "tools.snapshot": (["Ctrl+Alt+S"], "Take a named snapshot", "Tools",
                       "Keep this version of the map inside the .ofmap (the timeline)"),
    "tools.compare": (["Ctrl+Alt+D"], "Compare with the snapshot", "Tools",
                      "Added (green), changed (amber), moved and removed (ghosts) against the "
                      "chosen snapshot"),
    "tools.issue_next": (["F7"], "Next issue", "Tools", "Frame the next problem of the issue list"),
    "tools.issue_prev": (["Shift+F7"], "Previous issue", "Tools",
                         "Frame the previous problem of the issue list"),
    "tools.overlay_reach": (["Ctrl+Alt+1"], "Overlay: reachability", "Overlays",
                            "Where Mario gets from spawn 1 (green) and where he can stand but "
                            "never gets (red)"),
    "tools.overlay_sight": (["Ctrl+Alt+2"], "Overlay: sightlines", "Overlays",
                            "The long open lines; with a spawn selected, what it sees"),
    "tools.overlay_exposure": (["Ctrl+Alt+3"], "Overlay: spawn safety", "Overlays",
                               "How much of the map sees each spawn; spawn-kill pairs in red"),
    "tools.overlay_heat": (["Ctrl+Alt+4"], "Overlay: bot heatmap", "Overlays",
                           "Where sixteen bots stood in a match (mapgen's bot run)"),
    "tools.overlay_deaths": (["Ctrl+Alt+5"], "Overlay: bot deaths", "Overlays",
                             "Where the bots died"),
    "tools.overlay_gameplay": (["Ctrl+Alt+6"], "Overlay: stars, water, items", "Overlays",
                               "The bonus stars (kind and grade), the water bodies and the "
                               "Forge items the gameplay pass placed"),
    "tools.overlay_routes": (["Ctrl+Alt+7"], "Overlay: routes and shortcuts", "Overlays",
                             "The viable routes from a base to the centre (within 1.3x the "
                             "fastest) and the shortcuts an SM64 move opens"),
    "tools.overlay_flanks": (["Ctrl+Alt+8"], "Overlay: flank sightlines", "Overlays",
                             "The spots that hold the main route and what they see of the flank"),
    "tools.overlay_pens": (["Ctrl+Alt+9"], "Overlay: spawn pens", "Overlays",
                           "Each base's ways out and the camper spot that sees most of them"),
    "tools.overlay_clear": (["Ctrl+Alt+0"], "Overlays off", "Overlays", "Hide every overlay"),
    "tools.push_face": (["E"], "Push a face out", "Build",
                        "The face of the selection (or of the box under the mouse) nearest "
                        "the mouse goes out one cell - grow a box by cells"),
    "tools.pull_face": (["Ctrl+E"], "Pull a face in", "Build",
                        "The face nearest the mouse comes in one cell - shrink a box"),
    "tools.variant_next": (["Tab"], "Next variant of the piece", "Build",
                           "Ramp -> corners -> stairs, box -> diagonal -> arch, curve -> bank "
                           "-> curved wall...: the shape changes, texture, place and turn stay"),
    "tools.variant_prev": (["Alt+Shift+V"], "Previous variant of the piece", "Build",
                           "The variant before, in the same family"),
    "tools.gradient": (["Ctrl+Shift+G"], "Gradient paint (by height)", "Build",
                       "The selection painted from the current texture at the bottom to the "
                       "second texture at the top, the middle dithered"),
    "tools.noise": (["Ctrl+Shift+N"], "Noise paint (patches)", "Build",
                    "The second texture in seeded patches over the current one (moss, wear); "
                    "press again for another pattern"),
    "tools.second_texture": (["Alt+I"], "Take the second texture", "Build",
                             "The selected piece's texture becomes the second texture "
                             "(gradients, noise, a room's floor)"),
    "tools.room": (["Ctrl+Shift+R"], "Room tool", "Build",
                   "Drag a rectangle in a view: a floor, four walls with a door gap and, "
                   "if ticked, a roof - one undo step"),
    "tools.paste_sticky": (["Ctrl+Shift+V"], "Paste stays armed", "Build",
                           "On: after Ctrl+V every click pastes again until Esc"),
    "tools.reach_ghost": (["Alt+R"], "Mario's reach on the ghost", "Build",
                          "Before placing, the ghost's top is outlined by what Mario needs to "
                          "get onto it: walk, jump, double, triple, wall kicks, out of reach"),
    "tools.note": (["Shift+N"], "Map note here", "Build",
                   "A note at the mouse (or edit the one there) - saved with the map, never "
                   "exported"),
    "tools.notes_show": (["Alt+N"], "Show map notes", "Build", "Show or hide the map's notes"),
}
BRUSH_ACTIONS = {"tools.brush_paint": "paint", "tools.brush_raise": "raise",
                 "tools.brush_lower": "lower", "tools.brush_scatter": "scatter",
                 "tools.brush_fill": "fill"}
OVERLAY_ACTIONS = {"tools.overlay_reach": "reach", "tools.overlay_sight": "sight",
                   "tools.overlay_exposure": "exposure", "tools.overlay_heat": "heat",
                   "tools.overlay_deaths": "deaths", "tools.overlay_gameplay": "gameplay",
                   "tools.overlay_routes": "routes", "tools.overlay_flanks": "flanks",
                   "tools.overlay_pens": "pens"}
MODES = ("select",) + brushes.KINDS + ("ruler", "path", "room", "paste")
def register(keymap_module=None):
    if keymap_module is None:
        from studio.core import keymap as keymap_module
    already = []
    for aid, (keys, label, group, _) in ACTIONS.items():
        if not keymap_module.register(aid, keys, label, group):
            already.append(aid)
    return already
class ToolState:
    def __init__(self, session):
        self.session = session
        self.mode = "select"
        self.brush = Brush("paint")
        self.symmetry = Symmetry()
        self.points = []
        self.result = None
        self.cursor = None
        self.layers = {}
        self.diff = None
        self.compare_index = None
        self.scatter_make = None
        self.dress_rules = list(dress.RULES)
        self.snapshot_cap = snapshots.CAP
        self._stroke = 0
        self._last_cell = None
        self.gradient_axis = "y"
        self.noise_share = 0.35
        self.noise_patch = 600
        self.noise_seed = 1
        self.room_height = 600
        self.room_doors = ("+z",)
        self.room_roof = False
        self.room_start = None
        self.room_rect = None
        self.paste_sticky = True
        self.reach_on = True
        self.reach = None
        self.notes_shown = True
        self.listeners = []
        session.stack_filters.append(self._filter)
    def _tell(self, event, payload=None):
        for fn in list(self.listeners):
            fn(event, payload)
    def status(self, text):
        self._tell("status", text)
        return text
    def _filter(self, doc, change):
        return self.symmetry.expand(doc, change)
    def set_mode(self, mode):
        if mode not in MODES:
            raise ValueError(mode)
        if mode in brushes.KINDS:
            self.brush.kind = mode
        if mode != self.mode or mode not in ("ruler", "path"):
            self.points = []
            self.result = None
        self.room_start = self.room_rect = None
        if mode != "paste":
            self.reach = None
        self.mode = mode
        self._tell("mode", mode)
        if mode == "select":
            return self.status("Select")
        if mode == "room":
            return self.status("Room: drag a rectangle in a view (at least 3 x 3 cells) - walls "
                               "in the current texture, the floor in the second (Esc ends)")
        if mode == "paste":
            return self.status("Pasting: every click puts a copy down, Esc stops")
        if mode in ("ruler", "path"):
            return self.status("%s: click a point, then the next (Esc ends)" % (
                "Ruler" if mode == "ruler" else "Walk path"))
        return self.status("%s brush - size %d, falloff %d%%: click or drag in a view (Esc ends)"
                           % (brushes.LABELS[mode], self.brush.size, 100 * self.brush.falloff))
    @property
    def active(self):
        return self.mode != "select"
    def set_symmetry(self, mode, centre=None):
        if centre is None:
            centre = self.symmetry.centre
        self.symmetry = Symmetry(mode, centre)
        self._tell("guides", None)
        if mode == "off":
            return self.status("Symmetry off")
        note = symmetry.facing_note(mode)
        return self.status("Symmetry: %s about (%d, %d) - every edit repeats on the twins%s"
                           % (mode.replace("_", " "), self.symmetry.centre[0],
                              self.symmetry.centre[1], (". " + note) if note else ""))
    def next_symmetry(self):
        i = SYM_MODES.index(self.symmetry.mode)
        return self.set_symmetry(SYM_MODES[(i + 1) % len(SYM_MODES)])
    def centre_symmetry(self):
        refs = self.session.refs()
        doc = self.session.doc
        if refs:
            b = geo.grid_box([doc.view_item(r) for r in refs])
            c = ((b[0] + b[1]) / 2.0, (b[4] + b[5]) / 2.0)
        else:
            c = map_centre(doc)
        return self.set_symmetry(self.symmetry.mode, c)
    def click(self, point, mods=None):
        if not self.active or point is None:
            return None
        mods = mods or {}
        if self.mode in brushes.KINDS:
            self._stroke += 1
            return self._dab(point, "begin")
        if self.mode == "paste":
            s = self.session
            if not s.clipboard:
                self.set_mode("select")
                return self.status("The clipboard is empty - copy something first (Ctrl+C)")
            return s.push(s.clipboard.paste_at(s.doc, point, s.paste_turns, s.snap_on))
        if self.mode == "room":
            return self.status("Room: drag a rectangle, do not click")
        if self.mode == "ruler":
            if self.result is not None and not mods.get("shift"):
                self.points = []
            self.points.append(tuple(point))
            self.result = measure.ruler(self.points) if len(self.points) > 1 else None
        else:
            if len(self.points) >= 2:
                self.points = []
            self.points.append(tuple(point))
            self.result = None
            if len(self.points) == 2:
                self.result = measure.path(self.session.doc.to_layout(), self.points[0],
                                           self.points[1])
        self._tell("guides", None)
        if self.result is None:
            return self.status("Click the next point")
        return self.status("   ".join(self.result.lines()[:2]))
    def drag(self, point, phase):
        if self.mode == "room":
            return self._room_drag(point, phase)
        if self.mode not in brushes.KINDS or point is None:
            return None
        if phase == "begin":
            self._stroke += 1
            self._last_cell = None
        if phase in ("begin", "drag"):
            return self._dab(point, phase)
        self._last_cell = None
        return None
    def _dab(self, point, phase):
        cell = self.brush.centre(point)
        if phase != "begin" and cell == self._last_cell:
            return None
        self._last_cell = cell
        make = self.scatter_make[1] if self.scatter_make else None
        ch = self.brush.stroke(self.session.doc, point, self.session.texture, make=make,
                               stroke_id=self._stroke, symmetry=self.symmetry or None)
        if not ch:
            return self.status(ch.label if ch.label else "Nothing under the brush")
        return self.session.push(ch)
    def _room_drag(self, point, phase):
        if phase == "begin":
            self.room_start = tuple(point) if point is not None else None
            self.room_rect = None
        if self.room_start is None:
            return None
        if point is not None and phase in ("begin", "drag", "end"):
            sx, sy, sz = self.room_start
            self.room_rect = (sx, point[0], sz, point[2], sy)
            self._tell("guides", None)
        if phase != "end":
            return None
        rect, self.room_start, self.room_rect = self.room_rect, None, None
        self._tell("guides", None)
        if rect is None:
            return None
        s = self.session
        ch, note = build.room_change(s.doc, rect[:4], rect[4], s.texture,
                                     floor_tex=s.texture2, height=self.room_height,
                                     doors=self.room_doors, roof=self.room_roof,
                                     roof_tex=s.texture)
        if not ch:
            return self.status(note)
        return s.push(ch)
    def push_pull(self, out=True):
        s = self.session
        ch, face = build.push_pull(s.doc, s.refs(), self.cursor or s.cursor, out)
        line = build.push_note(ch, face)
        if ch:
            s.push(ch)
        return self.status(line)
    def variant(self, step=1):
        s = self.session
        refs = [r for r in s.refs() if r[0] == "piece"]
        objects = [r for r in s.refs() if r[0] == "object"]
        if objects and not refs:
            return self.object_variant(objects, step)
        if not refs:
            return s.need_selection()
        ch = build.cycle_variant(s.doc, refs, step)
        if not ch:
            return self.status("No other shape fits: these pieces have no variant family, or "
                               "the corners need a square footprint")
        return s.push(ch)
    def object_variant(self, refs, step=1):
        from studio.editor import forgeobjects, ops
        s = self.session
        from studio.editor.commands import Change
        steps, names = [], []
        for r in refs:
            o = s.doc.get(r)
            kinds = forgeobjects.variant_names(o.get("key"))
            if len(kinds) < 2:
                continue
            n = ((int(o.get("variant") or 1) - 1 + step) % len(kinds)) + 1
            steps += ops.set_fields(s.doc, [r], variant=n).steps
            names.append(kinds[n - 1][1])
        if not steps:
            return self.status("These objects have no other kind")
        s.push(Change("Next kind: %s" % ", ".join(sorted(set(names))), steps,
                      select=list(refs)))
        return self.status("Kind: %s" % ", ".join(sorted(set(names))))
    def paint_gradient(self):
        s = self.session
        refs = [r for r in s.refs() if r[0] == "piece"]
        if len(refs) < 2:
            return self.status("Select the pieces to paint (two or more) - the gradient runs "
                               "from the current texture to the second one")
        ch = build.gradient(s.doc, refs, [s.texture, s.texture2], self.gradient_axis)
        if not ch:
            return self.status("The gradient changes nothing here (the same texture twice?)")
        return s.push(ch)
    def paint_noise(self):
        s = self.session
        refs = [r for r in s.refs() if r[0] == "piece"]
        if not refs:
            return s.need_selection()
        ch = build.noise(s.doc, refs, [s.texture, s.texture2], self.noise_share,
                         self.noise_patch, self.noise_seed)
        self.noise_seed += 1
        if not ch:
            return self.status("The noise changes nothing here - press again for another "
                               "pattern")
        return s.push(ch)
    def take_second_texture(self):
        s = self.session
        for r in s.refs():
            if r[0] == "piece":
                s.texture2 = s.doc.get(r)["tex"]
                self._tell("texture2", s.texture2)
                return self.status("Second texture: %s" % s.texture2)
        return self.status("Select a piece to take its texture as the second texture")
    def arm_paste(self):
        if self.paste_sticky and self.session.clipboard:
            return self.set_mode("paste")
        return None
    def paste_ghost(self):
        s = self.session
        if self.mode != "paste" or not s.clipboard or self.cursor is None:
            return []
        return s.clipboard.ghost(self.cursor, s.paste_turns, s.snap_on)
    def preview_reach(self, pieces):
        if not self.reach_on or not pieces:
            self.reach = None
            return None
        self.reach = build.ghost_reach(self.session.doc, pieces)
        self._tell("guides", None)
        return self.reach["line"] if self.reach else None
    def note_here(self, text, point=None):
        s = self.session
        point = point or self.cursor or s.cursor
        near = build.note_near(s.doc, point)
        if near is not None:
            ch = build.edit_note(s.doc, near["id"], text)
        else:
            ch = build.add_note(s.doc, point, text)
        if not ch:
            return self.status("No note written - type something")
        s.push(ch)
        self._tell("guides", None)
        return self.status(ch.label)
    def twin_preview(self, refs, offset=(0, 0, 0), quarters=0, pivot=None):
        if not self.symmetry:
            return []
        doc = self.session.doc
        out = []
        for r in refs:
            item = doc.get(r)
            if item is None or r[0] != "piece":
                continue
            moved = dict(item)
            if quarters % 4 and pivot is not None:
                moved = geo.turned(moved, quarters, pivot)
            moved = geo.translated(moved, *offset)
            out += self.symmetry.images(moved)
        return out
    def move_cursor(self, point):
        self.cursor = tuple(point) if point is not None else None
    def guides(self):
        out = []
        if self.symmetry:
            y = self.cursor[1] if self.cursor else 0.0
            out.append(overlays.guide_axes(self.symmetry, y=y))
        if self.mode in ("ruler", "path") and self.points:
            m = self.result or measure.ruler(self.points)
            if self.result is None and len(self.points) == 1 and self.cursor:
                m = measure.ruler(self.points + [self.cursor])
            out.append(overlays.guide_measure(m))
        if self.mode in brushes.KINDS and self.cursor:
            layer = overlays.Layer("brush", "Brush")
            y = self.cursor[1]
            for x, z, w in self.brush.cells(self.cursor, self.symmetry or None):
                a = 0.15 + 0.45 * w
                layer.quad(x - 100, x + 100, z - 100, z + 100, y, (0.35, 0.80, 1.0, a))
            out.append(layer)
        if self.mode == "room" and self.room_rect is not None:
            x0, x1, z0, z1, y = self.room_rect
            pieces, note = build.room(x0, x1, z0, z1, y, self.session.texture,
                                      height=self.room_height, doors=self.room_doors,
                                      roof=self.room_roof)
            box = (min(x0, x1), max(x0, x1), y, y, min(z0, z1), max(z0, z1))
            layer = overlays.guide_box(box, "Room", (0.35, 0.80, 1.0, 0.9) if pieces
                                       else (0.92, 0.30, 0.30, 0.9))
            layer.label(((x0 + x1) / 2.0, y + 80, (z0 + z1) / 2.0), note)
            out.append(layer)
        if self.reach is not None and self.reach_on:
            out.append(build.reach_layer(self.reach))
        if self.notes_shown and self.session.doc.meta.get("notes"):
            out.append(build.notes_layer(self.session.doc))
        return out
    def brush_size(self, step):
        self.brush.size = max(1, min(brushes.SIZE_MAX, self.brush.size + step))
        return self.status("Brush size %d" % self.brush.size)
    def compute_layer(self, key, layout=None, eye=None):
        layout = layout if layout is not None else self.session.doc.to_layout()
        if key == "sight":
            return overlays.sightlines(layout, eye=eye)
        fn = dict((k, f) for k, _, f in overlays.LAYERS)[key]
        return fn(layout)
    def show_layer(self, layer):
        self.layers[layer.key] = layer
        self._tell("guides", None)
    def hide_layer(self, key=None):
        if key is None:
            self.layers.clear()
        else:
            self.layers.pop(key, None)
        self._tell("guides", None)
    def eye(self):
        for r in self.session.refs():
            if r[0] == "spawn":
                s = self.session.doc.get(r)
                return (s["x"], s.get("y", 0), s["z"])
        return None
    def snapshot(self, name=None, now=None):
        i = snapshots.take(self.session.doc, name, now, cap=self.snapshot_cap)
        return self.status("Snapshot %r taken - it is saved with the map (Ctrl+S)"
                           % snapshots.entries(self.session.doc)[i]["name"])
    def compare(self, index):
        self.diff = snapshots.compare(self.session.doc, index)
        self.compare_index = index
        self._tell("diff", self.diff)
        return self.status("Against %s: %s" % (snapshots.entries(self.session.doc)[index]["name"],
                                               self.diff.summary()))
    def clear_compare(self):
        self.diff = None
        self.compare_index = None
        self._tell("diff", None)
    def restore(self, index):
        return self.session.push(snapshots.restore(self.session.doc, index))
    def dress(self, refs=None):
        refs = [r for r in (refs if refs is not None else self.session.refs()) if r[0] == "piece"]
        ch, rep = dress.auto_dress(self.session.doc, refs or None, rules=self.dress_rules)
        self.last_dress = rep
        if not ch:
            return self.status("Auto-dress: " + "; ".join(rep.lines()))
        self.session.push(ch)
        return self.status("Auto-dress%s: %s" % (" (the selection)" if refs else "",
                                                 "; ".join(rep.lines())))
    def autoshape(self, budget=60):
        refs = self.session.refs()
        doc = self.session.doc
        box = None
        if refs:
            b = geo.grid_box([doc.view_item(r) for r in refs])
            box = (b[0], b[1], b[4], b[5])
        ch, n = autoshapemod.autoshape(doc, box, budget, self.session.texture)
        if not n:
            return self.status("Auto-shape: no one-layer step on a plain box top to slope")
        self.session.push(ch)
        return self.status("Auto-shape%s: %d slope%s" % (" (the selection)" if refs else "", n,
                                                          "" if n == 1 else "s"))
    def fill_region(self):
        refs = self.session.refs()
        if not refs:
            return self.status("Select the area to fill first (drag a box)")
        doc = self.session.doc
        b = geo.grid_box([doc.view_item(r) for r in refs])
        top = b[3] if b[3] > b[2] else b[2]
        return self.session.push(brushes.fill_region(doc, (b[0], b[1], b[4], b[5], top),
                                                     self.session.texture, self.brush.height))
