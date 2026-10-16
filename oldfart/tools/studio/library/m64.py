import io
import math
import os
import random
import struct
import sys
import tempfile
import time
import wave
try:
    from . import romaudio
except ImportError:
    import romaudio
TICKS_PER_BEAT = 48
RATE = 22050
SLOW_SECONDS = 20
MAX_SECONDS = 90
C4 = 261.6256
SHORT_VELOCITY = (12, 25, 38, 51, 57, 64, 71, 76, 83, 89, 96, 102, 109, 115, 121, 127)
SHORT_DURATION = (229, 203, 177, 151, 139, 126, 113, 100, 87, 74, 61, 48, 36, 23, 10, 0)
class M64Error(ValueError):
    pass
class Note:
    __slots__ = ("start", "length", "key", "velocity", "channel", "program", "drum", "volume",
                 "bank", "inst", "layer_inst", "env", "release", "sustain", "pan",
                 "pan_weight", "freq")
    def __init__(self, start, length, key, velocity, channel, program, drum, volume):
        self.start, self.length, self.key = start, length, key
        self.velocity, self.channel, self.program = velocity, channel, program
        self.drum, self.volume = drum, volume
        self.bank = None
        self.inst = None
        self.layer_inst = False
        self.env = ("default",)
        self.release = 0x20
        self.sustain = 0
        self.pan = 0.5
        self.pan_weight = 1.0
        self.freq = 1.0
    def __repr__(self):
        return "<Note %.2fs %.2fs key %d ch %d>" % (self.start, self.length, self.key,
                                                   self.channel)
class Song:
    def __init__(self):
        self.notes = []
        self.seconds = 0.0
        self.tempos = []
        self.channels = set()
        self.ended = False
        self.unknown = 0
        self.overrun = 0
        self.data = b""
        self.banks = []
class _State:
    def __init__(self, pc):
        self.pc = pc
        self.stack = []
        self.loops = []
class _Layer:
    def __init__(self, pc):
        self.s = _State(pc)
        self.enabled = True
        self.delay = 0
        self.duration = 0
        self.stop = False
        self.note_duration = 0x80
        self.transposition = 0
        self.velocity = 0
        self.play_percentage = 0
        self.default_percentage = 0x80
        self.continuous = False
        self.program = None
        self.inst = None
        self.current = None
class _Channel:
    def __init__(self, bank=None):
        self.enabled = False
        self.s = None
        self.delay = 0
        self.layers = [None] * 4
        self.value = 0
        self.dyntable = None
        self.init(bank)
    def init(self, bank):
        self.transposition = 0
        self.large = False
        self.program = 0
        self.drum = False
        self.has_instrument = False
        self.volume = 1.0
        self.vol_scale = 1.0
        self.freq = 1.0
        self.pan = 0.5
        self.pan_weight = 1.0
        self.bank = bank
        self.inst = None
        self.env = ("default",)
        self.release = 0x20
        self.sustain = 0
class _Reader:
    def __init__(self, data, seconds, banks=None):
        self.d = bytes(data)
        self.seconds = seconds
        self.song = Song()
        self.song.data = self.d
        self.banks = list(banks or [])
        self.song.banks = list(self.banks)
        default = self.banks[0] if self.banks else None
        self.bpm = 120
        self.transposition = 0
        self.volume = 1.0
        self.delay = 0
        self.value = 0
        self.variation = 0
        self.enabled = True
        self.s = _State(0)
        self.channels = [_Channel(default) for _ in range(16)]
        self.short_velocity = SHORT_VELOCITY
        self.short_duration = SHORT_DURATION
        self.time = 0.0
    def u8(self, s):
        if s.pc >= len(self.d) or s.pc < 0:
            self.song.overrun += 1
            s.pc += 1
            return 0xFF
        v = self.d[s.pc]
        s.pc += 1
        return v
    def s8(self, s):
        v = self.u8(s)
        return v - 256 if v >= 128 else v
    def s16(self, s):
        hi = self.u8(s)
        lo = self.u8(s)
        v = (hi << 8) | lo
        return v - 0x10000 if v >= 0x8000 else v
    def u16(self, s):
        return self.s16(s) & 0xFFFF
    def var(self, s):
        v = self.u8(s)
        if v & 0x80:
            v = ((v << 8) & 0x7F00) | self.u8(s)
        return v
    def table(self, at):
        return tuple(self.d[at:at + 16]) if 0 <= at and at + 16 <= len(self.d) else None
    def run(self):
        tick = 60.0 / (self.bpm * TICKS_PER_BEAT)
        guard = 0
        while self.time < self.seconds:
            if not self.enabled and not any(c.enabled for c in self.channels):
                self.song.ended = True
                break
            self.sequence_tick()
            for i, c in enumerate(self.channels):
                if c.enabled:
                    self.channel_tick(i, c)
            tick = 60.0 / (max(1, self.bpm) * TICKS_PER_BEAT)
            self.time += tick
            guard += 1
            if guard > 2000000:
                break
        for c in self.channels:
            for layer in c.layers:
                if layer is not None and layer.current is not None:
                    self.end_note(layer)
        self.song.seconds = min(self.time, self.seconds)
        return self.song
    def sequence_tick(self):
        if not self.enabled:
            return
        if self.delay > 1:
            self.delay -= 1
            return
        s = self.s
        for _ in range(10000):
            cmd = self.u8(s)
            if cmd == 0xFF:
                if not s.stack:
                    self.enabled = False
                    return
                s.pc = s.stack.pop()
                continue
            if cmd == 0xFD:
                self.delay = self.var(s)
                return
            if cmd == 0xFE:
                self.delay = 1
                return
            if cmd >= 0xC0:
                self.sequence_command(cmd, s)
            else:
                lo = cmd & 0xF
                hi = cmd & 0xF0
                if hi == 0x00:
                    self.value = 1 if not self.channels[lo].enabled else 0
                elif hi == 0x50:
                    self.value -= self.variation
                elif hi == 0x70:
                    self.variation = self.value
                elif hi == 0x80:
                    self.value = self.variation
                elif hi == 0x90:
                    at = self.u16(s)
                    self.start_channel(lo, at)
        raise M64Error("the sequence never waits (offset %d)" % s.pc)
    def sequence_command(self, cmd, s):
        if cmd == 0xFC:
            at = self.u16(s)
            s.stack.append(s.pc)
            s.pc = at
        elif cmd == 0xF8:
            s.loops.append(self.u8(s) or 256)
            s.stack.append(s.pc)
        elif cmd == 0xF7:
            s.loops[-1] -= 1
            if s.loops[-1] > 0:
                s.pc = s.stack[-1]
            else:
                s.loops.pop()
                s.stack.pop()
        elif cmd in (0xFB, 0xFA, 0xF9, 0xF5):
            at = self.u16(s)
            if (cmd == 0xFA and self.value != 0) or (cmd == 0xF9 and self.value >= 0) or \
                    (cmd == 0xF5 and self.value < 0):
                return
            s.pc = at
        elif cmd == 0xF2:
            self.u8(s)
        elif cmd == 0xDF:
            self.transposition = self.s8(s)
        elif cmd == 0xDE:
            self.transposition += self.s8(s)
        elif cmd == 0xDD:
            self.bpm = max(1, self.u8(s))
            self.song.tempos.append((round(self.time, 3), self.bpm))
        elif cmd == 0xDC:
            self.bpm = max(1, self.bpm + self.s8(s))
            self.song.tempos.append((round(self.time, 3), self.bpm))
        elif cmd == 0xDB:
            self.volume = self.u8(s) / 127.0
        elif cmd == 0xDA:
            self.volume = max(0.0, self.volume + self.s8(s) / 127.0)
        elif cmd == 0xD7:
            mask = self.u16(s)
            for i in range(16):
                if mask & (1 << i):
                    self.channels[i].init(self.banks[0] if self.banks else None)
        elif cmd == 0xD6:
            self.u16(s)
        elif cmd in (0xD5, 0xD3, 0xD0):
            self.u8(s)
        elif cmd in (0xD2, 0xD1):
            at = self.u16(s)
            t = self.table(at)
            if t is not None:
                if cmd == 0xD2:
                    self.short_velocity = t
                else:
                    self.short_duration = t
        elif cmd == 0xCC:
            self.value = self.u8(s)
        elif cmd == 0xC9:
            self.value &= self.u8(s)
        elif cmd == 0xC8:
            self.value -= self.u8(s)
        elif cmd in (0xF1, 0xD4):
            pass
        else:
            self.song.unknown += 1
    def start_channel(self, i, at):
        c = self.channels[i]
        c.enabled = True
        c.s = _State(at)
        c.delay = 0
        for k, layer in enumerate(c.layers):
            if layer is not None and layer.current is not None:
                self.end_note(layer)
            c.layers[k] = None
        self.song.channels.add(i)
    def channel_tick(self, i, c):
        if c.delay != 0:
            c.delay -= 1
        if c.delay == 0:
            self.channel_script(i, c)
        for layer in c.layers:
            if layer is not None and layer.enabled:
                self.layer_tick(i, c, layer)
    def channel_script(self, i, c):
        s = c.s
        for _ in range(10000):
            cmd = self.u8(s)
            if cmd == 0xFF:
                if not s.stack:
                    c.enabled = False
                    for layer in c.layers:
                        if layer is not None and layer.current is not None:
                            self.end_note(layer)
                    return
                s.pc = s.stack.pop()
                continue
            if cmd == 0xFE:
                return
            if cmd == 0xFD:
                c.delay = self.var(s)
                return
            if cmd == 0xF3:
                c.enabled = False
                return
            if cmd > 0xC0:
                self.channel_command(c, cmd, s)
                continue
            lo, hi = cmd & 0xF, cmd & 0xF0
            if hi == 0x90:
                at = self.u16(s)
                if lo < 4:
                    if c.layers[lo] is not None and c.layers[lo].current is not None:
                        self.end_note(c.layers[lo])
                    c.layers[lo] = _Layer(at)
            elif hi == 0xA0:
                if lo < 4 and c.layers[lo] is not None:
                    if c.layers[lo].current is not None:
                        self.end_note(c.layers[lo])
                    c.layers[lo] = None
            elif hi == 0xB0:
                if c.value != -1 and c.dyntable is not None and lo < 4:
                    at = c.dyntable + 2 * c.value
                    if 0 <= at + 1 < len(self.d):
                        c.layers[lo] = _Layer((self.d[at] << 8) | self.d[at + 1])
            elif hi == 0x10:
                at = self.u16(s)
                self.start_channel(lo, at)
            elif hi == 0x20:
                self.channels[lo].enabled = False
            elif hi in (0x30, 0x40):
                self.u8(s)
            elif hi == 0x00:
                layer = c.layers[lo] if lo < 4 else None
                c.value = 0 if layer is None or layer.enabled else 1
        raise M64Error("channel %d never waits (offset %d)" % (i, s.pc))
    def channel_command(self, c, cmd, s):
        if cmd == 0xFC:
            at = self.u16(s)
            s.stack.append(s.pc)
            s.pc = at
        elif cmd == 0xF8:
            s.loops.append(self.u8(s) or 256)
            s.stack.append(s.pc)
        elif cmd == 0xF7:
            s.loops[-1] -= 1
            if s.loops[-1] > 0:
                s.pc = s.stack[-1]
            else:
                s.loops.pop()
                s.stack.pop()
        elif cmd == 0xF6:
            if s.stack:
                s.stack.pop()
                if s.loops:
                    s.loops.pop()
        elif cmd in (0xFB, 0xFA, 0xF9, 0xF5):
            at = self.u16(s)
            if (cmd == 0xFA and c.value != 0) or (cmd == 0xF9 and c.value >= 0) or \
                    (cmd == 0xF5 and c.value < 0):
                return
            s.pc = at
        elif cmd == 0xC2:
            c.dyntable = self.u16(s)
        elif cmd == 0xC5:
            if c.value != -1 and c.dyntable is not None:
                at = c.dyntable + 2 * c.value
                if 0 <= at + 1 < len(self.d):
                    c.dyntable = (self.d[at] << 8) | self.d[at + 1]
        elif cmd == 0xE4:
            if c.value != -1 and c.dyntable is not None:
                at = c.dyntable + 2 * c.value
                if 0 <= at + 1 < len(self.d):
                    s.stack.append(s.pc)
                    s.pc = (self.d[at] << 8) | self.d[at + 1]
        elif cmd == 0xC1:
            prog = self.u8(s)
            c.program = prog
            c.drum = prog == 0x7F
            c.has_instrument = True
            if prog < 0x7F:
                c.inst = (c.bank, prog)
                c.env = ("inst", c.bank, prog)
                c.release = ("inst", c.bank, prog)
            else:
                c.inst = None
        elif cmd == 0xC6:
            n = self.u8(s)
            if n < len(self.banks):
                c.bank = self.banks[n]
        elif cmd == 0xC3:
            c.large = False
        elif cmd == 0xC4:
            c.large = True
        elif cmd == 0xDF:
            c.volume = self.u8(s) / 127.0
        elif cmd == 0xE0:
            c.vol_scale = self.u8(s) / 128.0
        elif cmd == 0xDB:
            c.transposition = self.s8(s)
        elif cmd == 0xDD:
            c.pan = self.u8(s) / 128.0
        elif cmd == 0xDC:
            c.pan_weight = self.u8(s) / 128.0
        elif cmd == 0xDA:
            c.env = ("seq", self.u16(s))
        elif cmd == 0xD9:
            c.release = self.u8(s)
        elif cmd == 0xD2:
            c.sustain = self.u8(s)
        elif cmd == 0xD3:
            c.freq = 2.0 ** (self.s8(s) / 127.0)
        elif cmd == 0xDE:
            c.freq = self.s16(s) / 32768.0
        elif cmd == 0xCB:
            self.u16(s)
        elif cmd == 0xC7:
            self.u8(s)
            self.u16(s)
        elif cmd in (0xE2, 0xE1):
            self.u8(s), self.u8(s), self.u8(s)
        elif cmd in (0xC8, 0xC9, 0xCC):
            v = self.u8(s)
            v = v - 256 if v >= 128 else v
            if cmd == 0xC8:
                c.value -= v
            elif cmd == 0xCC:
                c.value = v
            else:
                c.value &= v
        elif cmd in (0xD8, 0xD7, 0xE3, 0xD6, 0xD4, 0xCA, 0xD0, 0xD1, 0xF2):
            self.u8(s)
        elif cmd == 0xF1:
            pass
        else:
            self.song.unknown += 1
    def layer_tick(self, i, c, layer):
        if layer.delay > 1:
            layer.delay -= 1
            if not layer.stop and layer.delay <= layer.duration:
                if layer.current is not None:
                    self.end_note(layer)
                layer.stop = True
            return
        if not layer.continuous and layer.current is not None:
            self.end_note(layer)
        s = layer.s
        cmd = None
        for _ in range(10000):
            cmd = self.u8(s)
            if cmd <= 0xC0:
                break
            if cmd == 0xFF:
                if not s.stack:
                    layer.enabled = False
                    if layer.current is not None:
                        self.end_note(layer)
                    return
                s.pc = s.stack.pop()
            elif cmd == 0xFC:
                at = self.u16(s)
                s.stack.append(s.pc)
                s.pc = at
            elif cmd == 0xF8:
                s.loops.append(self.u8(s) or 256)
                s.stack.append(s.pc)
            elif cmd == 0xF7:
                s.loops[-1] -= 1
                if s.loops[-1] > 0:
                    s.pc = s.stack[-1]
                else:
                    s.loops.pop()
                    s.stack.pop()
            elif cmd == 0xFB:
                s.pc = self.u16(s)
            elif cmd == 0xC1:
                v = self.u8(s)
                layer.velocity = v
            elif cmd == 0xCA:
                self.u8(s)
            elif cmd == 0xC2:
                layer.transposition = self.s8(s)
            elif cmd == 0xC9:
                layer.note_duration = self.u8(s)
            elif cmd in (0xC4, 0xC5):
                layer.continuous = cmd == 0xC4
                if layer.current is not None:
                    self.end_note(layer)
            elif cmd == 0xC3:
                layer.default_percentage = self.var(s)
            elif cmd == 0xC6:
                prog = self.u8(s)
                if prog < 127:
                    layer.program = prog
                    layer.inst = (c.bank, prog)
            elif cmd == 0xC7:
                mode = self.u8(s)
                self.u8(s)
                if mode & 0x80:
                    self.u8(s)
                else:
                    self.var(s)
            elif cmd == 0xC8:
                pass
            elif cmd & 0xF0 == 0xD0:
                layer.velocity = self.short_velocity[cmd & 0xF]
            elif cmd & 0xF0 == 0xE0:
                layer.note_duration = self.short_duration[cmd & 0xF]
            else:
                self.song.unknown += 1
        else:
            raise M64Error("a layer of channel %d never plays (offset %d)" % (i, s.pc))
        if cmd == 0xC0:
            layer.delay = self.var(s)
            layer.stop = True
            return
        layer.stop = False
        kind = cmd & 0xC0
        if c.large:
            if kind == 0x00:
                pct = self.var(s)
                layer.velocity = self.u8(s)
                layer.note_duration = self.u8(s)
                layer.play_percentage = pct
            elif kind == 0x40:
                pct = self.var(s)
                layer.velocity = self.u8(s)
                layer.note_duration = 0
                layer.play_percentage = pct
            else:
                pct = layer.play_percentage
                layer.velocity = self.u8(s)
                layer.note_duration = self.u8(s)
        else:
            if kind == 0x00:
                pct = self.var(s)
                layer.play_percentage = pct
            elif kind == 0x40:
                pct = layer.default_percentage
            else:
                pct = layer.play_percentage
        key = cmd - kind
        layer.delay = pct
        layer.duration = layer.note_duration * pct // 256
        if not c.has_instrument:
            layer.stop = True
            return
        if c.drum:
            key += c.transposition + layer.transposition
        else:
            key += self.transposition + c.transposition + layer.transposition
            if key >= 0x80 or key < 0:
                layer.stop = True
                return
        held = max(1, pct - layer.duration)
        tick = 60.0 / (max(1, self.bpm) * TICKS_PER_BEAT)
        note = Note(self.time, held * tick, key, min(1.0, layer.velocity / 127.0), i,
                    layer.program if layer.program is not None else c.program, c.drum,
                    c.volume * c.vol_scale * self.volume)
        note.bank = c.bank
        if not c.drum:
            note.inst = layer.inst or c.inst
            note.layer_inst = layer.inst is not None
        note.env, note.release, note.sustain = c.env, c.release, c.sustain
        note.pan, note.pan_weight, note.freq = c.pan, c.pan_weight, c.freq
        self.song.notes.append(note)
        layer.current = note
    def end_note(self, layer):
        note = layer.current
        layer.current = None
        if note is not None:
            note.length = max(0.01, min(note.length, self.time - note.start + 1e-6))
def read(data, seconds=60, banks=None):
    seconds = max(1.0, min(float(seconds), MAX_SECONDS))
    if len(data) < 4:
        raise M64Error("too short to be a sequence")
    return _Reader(data, seconds, banks).run()
VOICES = ("sine", "triangle", "square", "saw", "organ")
def voice_of(program):
    return VOICES[(program or 0) % len(VOICES)]
def _numpy():
    try:
        import numpy
        return numpy
    except Exception:
        return None
def render(song, rate=RATE, seconds=None, seed=7):
    np = _numpy()
    total = song.seconds if seconds is None else min(seconds, song.seconds)
    if np is None:
        total = min(total, SLOW_SECONDS)
    n = max(1, int(total * rate))
    if np is not None:
        return _render_numpy(np, song, rate, n, seed)
    return _render_plain(song, rate, n, seed)
def _render_numpy(np, song, rate, n, seed):
    out = np.zeros(n + rate, dtype=np.float64)
    rng = np.random.default_rng(seed)
    for note in song.notes:
        start = int(note.start * rate)
        if start >= n:
            continue
        rel = int(0.06 * rate)
        length = max(1, int(note.length * rate)) + rel
        t = np.arange(length) / float(rate)
        amp = 0.22 * note.velocity * note.volume
        env = np.ones(length)
        att = min(length, int(0.006 * rate))
        env[:att] = np.linspace(0, 1, att, endpoint=False) if att else env[:att]
        env[-rel:] *= np.linspace(1, 0, rel)
        if note.drum:
            decay = 0.25 if note.key < 40 else 0.08
            sig = rng.uniform(-1, 1, length) * np.exp(-t / decay)
            if note.key < 40:
                f = 60.0 * np.exp(-t * 8) + 40
                sig = 0.6 * sig + np.sin(2 * np.pi * np.cumsum(f) / rate) * np.exp(-t / 0.2)
        else:
            f = C4 * 2 ** ((note.key - 39) / 12.0)
            phase = 2 * np.pi * f * t
            v = voice_of(note.program)
            if v == "sine":
                sig = np.sin(phase)
            elif v == "triangle":
                sig = 2 / np.pi * np.arcsin(np.sin(phase))
            elif v == "square":
                sig = np.tanh(3 * np.sin(phase)) * 0.7
            elif v == "saw":
                sig = (2 * ((f * t) % 1.0) - 1) * 0.6
            else:
                sig = np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.25 * np.sin(3 * phase)
                sig *= 0.6
            sig = sig * (0.75 + 0.25 * np.exp(-t / 0.3))
        end = min(len(out), start + length)
        out[start:end] += (amp * env * sig)[:end - start]
    out = out[:n]
    peak = float(np.max(np.abs(out))) if len(out) else 0.0
    if peak > 0.98:
        out *= 0.98 / peak
    return (np.clip(out, -1, 1) * 32767).astype("<i2").tobytes()
def _render_plain(song, rate, n, seed):
    out = [0.0] * n
    rnd = random.Random(seed)
    for note in song.notes:
        start = int(note.start * rate)
        if start >= n:
            continue
        rel = int(0.05 * rate)
        length = min(n - start, max(1, int(note.length * rate)) + rel)
        amp = 0.22 * note.velocity * note.volume
        f = C4 * 2 ** ((note.key - 39) / 12.0)
        step = f / rate
        ph = 0.0
        for k in range(length):
            e = 1.0 if k < length - rel else (length - k) / float(rel)
            if note.drum:
                s = (rnd.random() * 2 - 1) * math.exp(-k / (0.08 * rate))
            else:
                ph += step
                s = 1.0 if (ph % 1.0) < 0.5 else -1.0
                s *= 0.5
            out[start + k] += amp * e * s
    peak = max((abs(v) for v in out), default=0.0)
    scale = 0.98 / peak if peak > 0.98 else 1.0
    return b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32767)) for v in out)
def wav(pcm, rate=RATE, channels=1):
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)
    return buf.getvalue()
def summary(song):
    bpm = song.tempos[0][1] if song.tempos else 120
    return "%d notes on %d channels, %d bpm, %.0f s%s" % (
        len(song.notes), len(song.channels), bpm, song.seconds,
        "" if song.ended else " (it loops - the preview stops there)")
def sketch(path, out_path, seconds=60):
    with open(path, "rb") as handle:
        song = read(handle.read(), seconds)
    with open(out_path, "wb") as handle:
        handle.write(wav(render(song)))
    return out_path, summary(song)
def rom_path():
    return romaudio.find_rom()
UPDATES_PER_SECOND = 240
RELEASE_CAP = 4.0
TAIL_SECONDS = 2.0
FADE_SECONDS = 1.5
VANILLA = (
    (0x01, "SEQ_EVENT_CUTSCENE_COLLECT_STAR", "Star Get"),
    (0x02, "SEQ_MENU_TITLE_SCREEN", "Title Theme"),
    (0x03, "SEQ_LEVEL_GRASS", "Bob-omb Battlefield"),
    (0x04, "SEQ_LEVEL_INSIDE_CASTLE", "Inside the Castle"),
    (0x05, "SEQ_LEVEL_WATER", "Dire, Dire Docks"),
    (0x06, "SEQ_LEVEL_HOT", "Lethal Lava Land"),
    (0x07, "SEQ_LEVEL_BOSS_KOOPA", "Bowser Battle"),
    (0x08, "SEQ_LEVEL_SNOW", "Cool, Cool Mountain"),
    (0x09, "SEQ_LEVEL_SLIDE", "Slider"),
    (0x0A, "SEQ_LEVEL_SPOOKY", "Big Boo's Haunt"),
    (0x0B, "SEQ_EVENT_PIRANHA_PLANT", "Piranha Plant's Lullaby"),
    (0x0C, "SEQ_LEVEL_UNDERGROUND", "Hazy Maze Cave"),
    (0x0D, "SEQ_MENU_STAR_SELECT", "Star Select"),
    (0x0E, "SEQ_EVENT_POWERUP", "Powerful Mario"),
    (0x0F, "SEQ_EVENT_METAL_CAP", "Metal Cap Theme"),
    (0x10, "SEQ_EVENT_KOOPA_MESSAGE", "Bowser's Message"),
    (0x11, "SEQ_LEVEL_KOOPA_ROAD", "Bowser's Road"),
    (0x12, "SEQ_EVENT_HIGH_SCORE", "High Score"),
    (0x13, "SEQ_EVENT_MERRY_GO_ROUND", "Merry-Go-Round"),
    (0x14, "SEQ_EVENT_RACE", "Race Fanfare"),
    (0x15, "SEQ_EVENT_CUTSCENE_STAR_SPAWN", "Star Appears"),
    (0x16, "SEQ_EVENT_BOSS", "Boss Fight"),
    (0x17, "SEQ_EVENT_CUTSCENE_COLLECT_KEY", "Key Get"),
    (0x18, "SEQ_EVENT_ENDLESS_STAIRS", "Endless Stairs"),
    (0x19, "SEQ_LEVEL_BOSS_KOOPA_FINAL", "Final Bowser"),
    (0x1A, "SEQ_EVENT_CUTSCENE_CREDITS", "Credits"),
    (0x1B, "SEQ_EVENT_SOLVE_PUZZLE", "Puzzle Solved"),
    (0x1C, "SEQ_EVENT_TOAD_MESSAGE", "Toad's Message"),
    (0x1D, "SEQ_EVENT_PEACH_MESSAGE", "Peach's Message"),
    (0x1E, "SEQ_EVENT_CUTSCENE_INTRO", "Peach's Letter"),
    (0x1F, "SEQ_EVENT_CUTSCENE_VICTORY", "Victory"),
    (0x20, "SEQ_EVENT_CUTSCENE_ENDING", "Ending"),
    (0x21, "SEQ_MENU_FILE_SELECT", "File Select"),
    (0x22, "SEQ_EVENT_CUTSCENE_LAKITU", "Lakitu's Introduction"),
)
SELFTEST_TRACKS = (0x03, 0x05, 0x0C)
DEFAULT_ENVELOPE = ((4, 32000), (1000, 32000), (romaudio.ADSR_HANG, 0))
def adsr_levels(envelope, fade, sustain, held, limit):
    env = list(envelope) or list(DEFAULT_ENVELOPE)
    out = []
    state = "initial"
    current = hires = index = delay = velocity = sus = 0
    for u in range(limit):
        decay = u == held
        if decay:
            sus = (current * (sustain << 8)) // 0x10000
        entry = state
        if entry in ("initial", "start", "loop", "fade"):
            if state == "initial":
                current = 0
                state = "start"
            if state == "start":
                index = 0
                hires = current << 16
                state = "loop"
            if state == "loop":
                d, arg = env[index] if 0 <= index < len(env) else (romaudio.ADSR_DISABLE, 0)
                if d == romaudio.ADSR_HANG:
                    state = "hang"
                elif d == romaudio.ADSR_GOTO:
                    index = arg
                elif d == romaudio.ADSR_RESTART:
                    state = "initial"
                elif d <= 0:
                    state = "off"
                else:
                    delay = d
                    velocity = int(((arg - current) << 16) / float(d))
                    state = "fade"
                    index += 1
            if state == "fade":
                hires += velocity
                current = hires >> 16
                delay -= 1
                if delay <= 0:
                    state = "loop"
        elif entry in ("decay", "release"):
            current -= fade
            if sus and entry == "decay":
                if current < sus:
                    current = sus
                    delay = sus // 16
                    state = "sustain"
            elif current < 100:
                current = 0
                state = "off"
        elif entry == "sustain":
            delay -= 1
            if delay <= 0:
                state = "release"
        if decay and state != "off":
            state = "decay"
        if state == "off":
            out.append(0)
            break
        out.append(max(0, min(32767, current)))
    return out
class Voices:
    def __init__(self, sound, np):
        self.sound = sound
        self.np = np
        self._pcm = {}
        self.missing = set()
    def pcm(self, sample):
        key = (sample.addr, sample.size)
        a = self._pcm.get(key)
        if a is None:
            raw = self.sound.samples(sample).tobytes()
            a = self.np.frombuffer(raw, dtype=self.np.int16).astype(self.np.float32) / 32768.0
            self._pcm[key] = a
        return a
    def bank(self, index):
        if index is None:
            return None
        try:
            return self.sound.bank(index)
        except romaudio.RomError:
            self.missing.add(index)
            return None
    @staticmethod
    def seq_envelope(song, at):
        out = []
        for k in range(64):
            p = at + 4 * k
            if p + 4 > len(song.data):
                break
            out.append(struct.unpack_from(">hh", song.data, p))
            if out[-1][0] <= 0:
                break
        return out
    def instrument(self, ref):
        b = self.bank(ref[0])
        return b.instrument(ref[1]) if b is not None else None
    def channel_adsr(self, song, note):
        env = ()
        if note.env[0] == "inst":
            inst = self.instrument(note.env[1:])
            env = inst.envelope if inst is not None else ()
        elif note.env[0] == "seq":
            env = self.seq_envelope(song, note.env[1])
        rel = note.release
        if isinstance(rel, tuple):
            inst = self.instrument(rel[1:])
            rel = inst.release if inst is not None else 0x20
        return env, rel
    def resolve(self, song, note):
        bank = self.bank(note.bank)
        if bank is None:
            return None
        if note.drum:
            drum = bank.drum(note.key)
            if drum is None or drum.sound.sample is None:
                return None
            if drum.release:
                return drum.sound, drum.envelope, drum.release, drum.pan / 128.0, 1.0
            env, rel = self.channel_adsr(song, note)
            return drum.sound, env, rel, drum.pan / 128.0, 1.0
        if note.inst is None:
            return None
        inst = self.instrument(note.inst)
        if inst is None:
            return None
        snd = inst.sound_for(note.key)
        if snd is None or snd.sample is None:
            return None
        freq = 2.0 ** ((note.key - 39) / 12.0)
        if note.layer_inst and inst.release:
            return snd, inst.envelope, inst.release, 0.5, freq
        env, rel = self.channel_adsr(song, note)
        return snd, env, rel, 0.5, freq
def render_real(song, sound, rate=romaudio.OUTPUT_RATE, seconds=None):
    np = _numpy()
    if np is None:
        raise M64Error("the real instruments need numpy (pip install numpy)")
    voices = Voices(sound, np)
    total = song.seconds if seconds is None else min(seconds, song.seconds)
    if song.ended and seconds is None:
        total += TAIL_SECONDS
    n = max(1, int(total * rate))
    left = np.zeros(n, dtype=np.float32)
    right = np.zeros(n, dtype=np.float32)
    per_update = rate / float(UPDATES_PER_SECOND)
    played = 0
    for note in song.notes:
        start = int(note.start * rate)
        if start >= n:
            continue
        got = voices.resolve(song, note)
        if got is None:
            continue
        snd, env, release, layer_pan, key_freq = got
        pcm = voices.pcm(snd.sample)
        if len(pcm) < 2:
            continue
        held = max(1, int(round(note.length * UPDATES_PER_SECOND)))
        levels = adsr_levels(env, release * 24, note.sustain, held,
                             held + int(RELEASE_CAP * UPDATES_PER_SECOND))
        length = min(n - start, int(len(levels) * per_update))
        if length <= 0:
            continue
        step = min(3.99992, key_freq * snd.tuning * note.freq) * romaudio.OUTPUT_RATE / rate
        pos = np.arange(length, dtype=np.float64) * step
        smp = snd.sample
        if smp.loop_count != 0 and min(smp.loop_end, len(pcm) - 1) > smp.loop_start:
            ls, le = float(smp.loop_start), float(min(smp.loop_end, len(pcm) - 1))
            over = pos >= le
            pos[over] = ls + np.mod(pos[over] - ls, le - ls)
        else:
            pos = pos[:int(np.searchsorted(pos, len(pcm) - 1))]
            length = len(pos)
            if length == 0:
                continue
        i = pos.astype(np.int64)
        frac = (pos - i).astype(np.float32)
        sig = pcm[i] * (1 - frac) + pcm[np.minimum(i + 1, len(pcm) - 1)] * frac
        lv = np.asarray(levels, dtype=np.float32) / 32767.0
        lv = lv * lv
        t = np.arange(length, dtype=np.float32) / per_update
        env_curve = np.interp(t, np.arange(1, len(lv) + 1, dtype=np.float32), lv, left=0.0)
        tail = min(length, int(0.01 * rate))
        if levels[-1] > 0 and tail:
            env_curve[-tail:] *= np.linspace(1, 0, tail)
        sig = sig * env_curve.astype(np.float32)
        gain = note.velocity * note.velocity * note.volume
        pan = layer_pan * (1.0 - note.pan_weight) + note.pan * note.pan_weight
        pan = min(1.0, max(0.0, pan))
        left[start:start + length] += sig * np.float32(gain * math.cos(pan * math.pi / 2))
        right[start:start + length] += sig * np.float32(gain * math.sin(pan * math.pi / 2))
        played += 1
    song.played = played
    song.missing_banks = sorted(voices.missing)
    if not song.ended:
        fade = min(n, int(FADE_SECONDS * rate))
        if fade:
            ramp = np.linspace(1, 0, fade).astype(np.float32)
            left[-fade:] *= ramp
            right[-fade:] *= ramp
    peak = max(float(np.max(np.abs(left))), float(np.max(np.abs(right))), 1e-9)
    scale = min(0.9 / peak, 8.0)
    out = np.empty(2 * n, dtype=np.float32)
    out[0::2] = left * scale
    out[1::2] = right * scale
    return (np.clip(out, -1, 1) * 32767).astype("<i2").tobytes()
_ROMS = {}
def open_rom(path=None):
    path = path or rom_path()
    if not path:
        return None
    rom = _ROMS.get(path)
    if rom is None:
        rom = romaudio.Rom.open(path)
        _ROMS.clear()
        _ROMS[path] = rom
    return rom
def preview(out_path, data=None, path=None, bank=None, vanilla=None, rom=None, seconds=60,
            rom_file=None):
    why_not = None
    if rom is None:
        try:
            rom = open_rom(rom_file)
        except (OSError, romaudio.RomError) as why:
            why_not = "your ROM could not be read: %s" % why
        if rom is None and why_not is None:
            why_not = "no ROM"
    if vanilla is not None:
        if rom is None:
            raise M64Error("the vanilla music is read from your ROM, and there is none. "
                           + romaudio.where_to_look())
        sound = rom.sound()
        data = sound.sequence(vanilla)
        banks = sound.banks_of(vanilla)
    else:
        if data is None:
            with open(path, "rb") as handle:
                data = handle.read()
        banks = [bank] if bank is not None else []
    song = read(data, seconds, banks)
    if rom is not None:
        if not banks:
            why_not = "no sound bank was given"
        elif _numpy() is None:
            why_not = "numpy is not installed (pip install numpy)"
        else:
            try:
                sound = rom.sound()
                if any(not 0 <= b < len(sound.ctl) for b in banks):
                    raise romaudio.RomError("bank %s is not in your ROM (it has 0-%d)" % (
                        ", ".join(str(b) for b in banks), len(sound.ctl) - 1))
                pcm = render_real(song, sound)
            except romaudio.RomError as why:
                why_not = str(why)
            else:
                with open(out_path, "wb") as handle:
                    handle.write(wav(pcm, romaudio.OUTPUT_RATE, 2))
                return out_path, summary(song), "real", None
    with open(out_path, "wb") as handle:
        handle.write(wav(render(song)))
    return out_path, summary(song), "sketch", why_not
def _slug(text):
    return "".join(ch if ch.isalnum() else "_" for ch in text).strip("_")
def selftest(rom_file=None, out_dir=None, seconds=30, stream=None):
    say = (stream or sys.stdout).write
    path = rom_file or rom_path()
    if not path:
        say("ROM: none found.\n%s\nLooked in: %s\n" % (
            romaudio.where_to_look(), ", ".join(romaudio.coopdx_folders())))
        return 1
    try:
        rom = romaudio.Rom.open(path)
        say("ROM: %s\n     %s\n     SHA-1 %s\n" % (path, rom.describe(), rom.sha1))
        if rom.file_md5 != rom.md5:
            say("     (the file itself is byte-swapped; its own MD5 is %s)\n" % rom.file_md5)
        sound = rom.sound()
        say("Sound data: %s\n" % sound.describe())
    except (OSError, romaudio.RomError) as why:
        say("FAIL: %s\n" % why)
        return 1
    bad = 0
    samples = set()
    for b in range(len(sound.ctl)):
        try:
            bank = sound.bank(b)
        except romaudio.RomError as why:
            say("FAIL bank %d: %s\n" % (b, why))
            bad += 1
            continue
        sounds = [s for i in bank.instruments if i is not None for s in (i.low, i.normal, i.high)]
        sounds += [d.sound for d in bank.drums if d is not None]
        samples.update((s.sample.addr, s.sample.size) for s in sounds if s.sample is not None)
    say("Banks: %d read, %d failed; %d different samples\n" % (len(sound.ctl) - bad, bad,
                                                               len(samples)))
    unknown = 0
    for i in range(len(sound.seqs)):
        try:
            unknown += read(sound.sequence(i), 20, sound.banks_of(i)).unknown
        except M64Error as why:
            say("FAIL sequence %d: %s\n" % (i, why))
            bad += 1
    say("Sequences: %d read, %d unknown commands\n" % (len(sound.seqs), unknown))
    if _numpy() is None:
        say("FAIL: numpy is not installed, so nothing can be rendered (pip install numpy)\n")
        return 1
    out_dir = out_dir or tempfile.mkdtemp(prefix="oldfart-m64-selftest-")
    os.makedirs(out_dir, exist_ok=True)
    names = dict((n, t) for n, _, t in VANILLA)
    for index in SELFTEST_TRACKS:
        if index >= len(sound.seqs):
            continue
        out = os.path.join(out_dir, "%02X-%s.wav" % (index, _slug(names.get(index, "track"))))
        t0 = time.time()
        try:
            _, line, mode, why = preview(out, vanilla=index, rom=rom, seconds=seconds)
        except (M64Error, romaudio.RomError) as why_:
            say("FAIL %s: %s\n" % (names.get(index), why_))
            bad += 1
            continue
        say("%s: %s - %s, %.1f s to render\n    %s\n" % (
            names.get(index), line, "real instruments" if mode == "real" else
            "a sketch (%s)" % why, time.time() - t0, out))
        if mode != "real":
            bad += 1
    say("%s Listen to the three files: each should sound like the game.\n"
        % ("OK." if not bad else "%d problem(s) above." % bad))
    return 0 if not bad else 1
def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(prog="python3 tools/studio/library/m64.py",
                                 description="Preview .m64 sequences; --selftest checks your ROM.")
    ap.add_argument("--selftest", action="store_true",
                    help="find your SM64 ROM, read its sound data, render three vanilla tracks")
    ap.add_argument("--rom", help="the ROM to use (default: the one Coop DX keeps)")
    ap.add_argument("--out", help="the folder for the .wav files (default: a new temp folder)")
    ap.add_argument("--seconds", type=float, default=30)
    ap.add_argument("m64", nargs="?", help="a .m64 to render (give its --bank)")
    ap.add_argument("--bank", type=int)
    ap.add_argument("--wav", help="where the .m64's .wav goes")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest(args.rom, args.out, args.seconds)
    if args.m64:
        out = args.wav or os.path.join(tempfile.gettempdir(), os.path.splitext(
            os.path.basename(args.m64))[0] + ".wav")
        _, line, mode, why = preview(out, path=args.m64, bank=args.bank, seconds=args.seconds,
                                     rom_file=args.rom)
        print("%s: %s (%s%s)" % (out, line, mode, (", " + why) if why else ""))
        return 0
    ap.print_help()
    return 2
if __name__ == "__main__":
    sys.exit(main())
