import os
import tempfile
import time
from PySide6.QtCore import QObject, QTimer
from studio.ux import sounds
POP_MS = 120
class SoundUI(QObject):
    def __init__(self, ux):
        super().__init__(ux)
        self.ux = ux
        self.ed = ux.ed
        self.effects = {}
        self.played = []
        self._mute = 0
        self._pops = {}
        self._timer = QTimer(self)
        self._timer.setInterval(16)
        self._timer.timeout.connect(self._pop_tick)
        ed = self.ed
        ed.click_sound = self.click
        original_erase = ed.erase
        def erase(refs):
            self._mute += 1
            try:
                got = original_erase(refs)
            finally:
                self._mute -= 1
            if got:
                self.play("delete")
            return got
        ed.erase = erase
        self._stack = None
        self._watch_stack()
        ed.session.listeners.append(lambda ev, _p: ev == "document" and self._watch_stack())
        original_generated = ed._generated
        def generated(gen, record=True):
            out = original_generated(gen, record)
            self.play("fanfare")
            return out
        ed._generated = generated
    def level(self):
        try:
            return self.ux.settings["ui.sounds"]
        except KeyError:
            return "full"
    def tonic(self):
        look = self.ed.session.doc.rest.get("look") or {}
        return sounds.key_of_map(look.get("music")) or 0
    def path(self, kind, **kw):
        key = (kind, int(kw.get("y", 0) // 400), kw.get("tonic", 0), kw.get("what", "shapes"))
        name = "oldfart-studio-%s-%d-%d-%s.wav" % key
        path = os.path.join(tempfile.gettempdir(), name)
        if not os.path.exists(path):
            data = sounds.wav_bytes(sounds.synth(kind, y=kw.get("y", 0), tonic=kw.get("tonic", 0),
                                                 what=kw.get("what", "shapes")))
            tmp = path + ".%d.tmp" % os.getpid()
            with open(tmp, "wb") as h:
                h.write(data)
            os.replace(tmp, path)
        return path
    def play(self, kind, **kw):
        if self._mute or kind not in sounds.KINDS:
            return None
        level = self.level()
        if level == "off":
            return None
        if kind in ("place", "row", "tick", "chime", "fanfare"):
            kw.setdefault("tonic", self.tonic())
        if kind == "tick" and "y" not in kw:
            kw["y"] = 400 if kw.pop("up", True) else 0
        kw.pop("up", None)
        self.played.append((kind, time.monotonic()))
        del self.played[:-20]
        try:
            path = self.path(kind, **kw)
            from PySide6.QtCore import QUrl
            from PySide6.QtMultimedia import QSoundEffect
            fx = self.effects.get(path)
            if fx is None:
                fx = QSoundEffect(self)
                fx.setSource(QUrl.fromLocalFile(path))
                self.effects[path] = fx
            fx.setVolume(sounds.VOLUME[level])
            fx.play()
        except Exception:
            pass
        return kind
    def click(self):
        armed = self.ed.armed or ""
        what = armed.split(":", 1)[0] if ":" in armed else "shapes"
        if what == "textures":
            return self.play("paint")
        return self.play("place", y=self.ed.session.cursor[1], what=what)
    def _watch_stack(self):
        stack = self.ed.session.stack
        if stack is self._stack:
            return
        self._stack = stack
        stack.listeners.append(self._stack_event)
    def _stack_event(self, what, change):
        if what == "undo":
            self.play("undo")
        elif what == "redo":
            self.play("redo")
        elif what == "refused":
            self.play("bonk")
        elif what == "push" and change is not None:
            label = (change.label or "").lower()
            if label.startswith(("delete", "cut")):
                self.play("delete")
            elif "paint" in label or "texture" in label:
                self.play("paint")
    def pop(self, refs):
        if self.ux.settings["ui.reduce_motion"]:
            return []
        sync = self.ed.sync
        sc = self.ux.ctx.scene
        now = time.monotonic()
        started = []
        for r in refs or ():
            if r[0] != "piece" or r not in sync.piece_refs:
                continue
            i = sync.piece_refs.index(r)
            if i >= len(sc.pieces):
                continue
            base = self._pops[i][0] if i in self._pops else dict(sc.pieces[i])
            self._pops[i] = (base, now, None)
            started.append(i)
        if started:
            self._pop_tick()
            self._timer.start()
        return started
    def _pop_tick(self, now=None):
        sc = self.ux.ctx.scene
        now = time.monotonic() if now is None else now
        changes = {}
        for i, (base, t0, last) in list(self._pops.items()):
            if i >= len(sc.pieces) or (last is not None and sc.pieces[i] != last):
                del self._pops[i]
                continue
            ms = (now - t0) * 1000.0
            k = sounds.pop_scale(ms, POP_MS)
            p = dict(base)
            if ms >= POP_MS:
                del self._pops[i]
            else:
                for f in ("w", "h", "d"):
                    p[f] = base[f] * k
                p["y"] = base["y"] + base["h"] * (1 - k) / 2.0
            changes[i] = p
            if i in self._pops:
                self._pops[i] = (base, t0, p)
        if changes:
            sc.update_pieces(changes)
        if not self._pops:
            self._timer.stop()
def install(ux):
    return SoundUI(ux)
