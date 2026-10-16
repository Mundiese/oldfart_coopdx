import array
import math
import os
import random
import struct
RATE = 22050
KINDS = ("place", "row", "delete", "paint", "undo", "redo", "bonk", "coin", "chime",
         "fanfare", "tick", "open", "close")
VOLUME = {"off": 0.0, "quiet": 0.15, "full": 0.35}
PENTATONIC = (0, 2, 4, 7, 9)
MAJOR = (0, 2, 4, 5, 7, 9, 11)
PROFILE = (6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88)
def midi_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)
def tonic_of(keys):
    keys = [int(k) for k in keys if k is not None]
    if not keys:
        return None
    hist = [0] * 12
    for k in keys:
        hist[k % 12] += 1
    best, score = 0, None
    for t in range(12):
        s = sum(hist[(t + i) % 12] * PROFILE[i] for i in range(12))
        if score is None or s > score:
            best, score = t, s
    return best
def m64_path(name, roots=None):
    if not name or not isinstance(name, str) or name.upper().startswith("SEQ_"):
        return None
    here = os.path.dirname(os.path.abspath(__file__))
    roots = roots or [os.path.join(here, "..", "..", "..", "sound")]
    for root in roots:
        p = os.path.join(root, name.lower() + ".m64")
        if os.path.exists(p):
            return p
    return None
_KEYS = {}
def key_of_map(music, roots=None):
    if music in _KEYS:
        return _KEYS[music]
    got = None
    path = m64_path(music, roots)
    if path:
        try:
            from studio.library import m64
            with open(path, "rb") as h:
                song = m64.read(h.read(), seconds=20)
            got = tonic_of([n.key for n in song.notes if not n.drum])
        except Exception:
            got = None
    _KEYS[music] = got
    return got
def place_note(y, tonic=0, base=60):
    step = int(math.floor(max(-2000.0, min(6000.0, y)) / 400.0))
    octave, deg = divmod(step, len(PENTATONIC))
    return base + (tonic or 0) + octave * 12 + PENTATONIC[deg]
def _env(i, n, attack=0.004, power=3.0):
    t = i / float(n)
    a = min(1.0, (i / RATE) / attack) if attack else 1.0
    return a * (1.0 - t) ** power
def _tone(freq, seconds, shape="sine", power=3.0, sweep=1.0, noise=0.0, seed=1, amp=1.0):
    n = max(1, int(RATE * seconds))
    rnd = random.Random(seed)
    out = []
    phase = 0.0
    lp = 0.0
    for i in range(n):
        f = freq * (sweep ** (i / float(n)))
        phase += 2 * math.pi * f / RATE
        if shape == "sine":
            v = math.sin(phase)
        elif shape == "square":
            v = 0.6 if math.sin(phase) >= 0 else -0.6
        elif shape == "saw":
            v = ((phase / (2 * math.pi)) % 1.0) * 2 - 1
        elif shape == "wood":
            v = math.sin(phase) + 0.35 * math.sin(2.7 * phase) + 0.15 * math.sin(5.4 * phase)
        elif shape == "bell":
            v = math.sin(phase) + 0.5 * math.sin(2.76 * phase) + 0.25 * math.sin(5.4 * phase)
        else:
            v = 0.0
        if noise:
            lp += (rnd.uniform(-1, 1) - lp) * 0.35
            v = v * (1 - noise) + lp * noise * 2.2
        out.append(v * _env(i, n, power=power) * amp)
    return out
def _mix(*parts):
    n = max(len(p) for p, _ in parts)
    out = [0.0] * n
    for p, at in parts:
        k = int(at * RATE)
        for i, v in enumerate(p):
            if k + i < n:
                out[k + i] += v
            else:
                out.append(v)
                n += 1
    return out
def synth(kind, y=0.0, tonic=0, what="shapes", seed=1):
    if kind not in KINDS:
        raise KeyError(kind)
    if kind == "place":
        f = midi_hz(place_note(y, tonic))
        shape = {"markers": "bell", "forge": "bell", "decor": "bell"}.get(what, "wood")
        s = _tone(f, 0.09 if shape == "wood" else 0.16, shape, power=4.0, sweep=0.92,
                  noise=0.12 if shape == "wood" else 0.0, seed=seed)
        if what == "prefabs":
            s = _mix((s, 0.0), (_tone(f * 1.5, 0.08, "wood", 4.0, 0.92, 0.1, seed + 1), 0.06))
    elif kind in ("row", "tick"):
        f = midi_hz(place_note(y, tonic) + 12)
        s = _tone(f, 0.03, "sine", power=2.5, amp=0.7)
    elif kind == "delete":
        s = _tone(520.0, 0.14, "sine", power=2.0, sweep=0.45, noise=0.75, seed=seed, amp=0.8)
    elif kind == "paint":
        s = _tone(900.0, 0.15, "sine", power=1.6, sweep=1.8, noise=0.9, seed=seed, amp=0.6)
    elif kind == "undo":
        s = _tone(900.0, 0.09, "sine", power=1.5, sweep=0.55, amp=0.7)
    elif kind == "redo":
        s = _tone(500.0, 0.09, "sine", power=1.5, sweep=1.8, amp=0.7)
    elif kind == "bonk":
        s = _tone(150.0, 0.12, "sine", power=2.5, sweep=0.7, noise=0.15, seed=seed, amp=0.9)
    elif kind == "coin":
        s = _mix((_tone(988.0, 0.07, "square", 1.0, amp=0.5), 0.0),
                 (_tone(1319.0, 0.22, "square", 2.0, amp=0.5), 0.07))
    elif kind == "chime":
        base = 72 + (tonic or 0)
        s = _mix(*[(_tone(midi_hz(base + d), 0.35, "bell", 3.0, amp=0.45), k * 0.08)
                   for k, d in enumerate((0, 4, 7, 12))])
    elif kind == "fanfare":
        base = 67 + (tonic or 0)
        s = _mix((_tone(midi_hz(base), 0.12, "saw", 1.2, amp=0.35), 0.0),
                 (_tone(midi_hz(base), 0.12, "saw", 1.2, amp=0.35), 0.13),
                 (_tone(midi_hz(base + 5), 0.4, "saw", 1.5, amp=0.4), 0.26))
    elif kind == "open":
        s = _tone(660.0, 0.06, "sine", power=2.0, sweep=1.3, amp=0.5)
    else:
        s = _tone(660.0, 0.06, "sine", power=2.0, sweep=0.75, amp=0.5)
    peak = max(1e-6, max(abs(v) for v in s))
    gain = 0.9 / peak if peak > 0.9 else 1.0
    return array.array("h", (int(max(-1.0, min(1.0, v * gain)) * 32000) for v in s))
def wav_bytes(pcm, rate=RATE):
    data = pcm.tobytes()
    return (b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVEfmt " +
            struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16) + b"data" +
            struct.pack("<I", len(data)) + data)
def pop_scale(t_ms, length=120.0):
    if t_ms <= 0:
        return 0.85
    if t_ms >= length:
        return 1.0
    u = t_ms / length
    if u < 0.6:
        return 0.85 + (1.05 - 0.85) * (u / 0.6)
    return 1.05 - 0.05 * ((u - 0.6) / 0.4)
