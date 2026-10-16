import array
import glob
import hashlib
import os
import struct
import sys
KNOWN_MD5 = {
    "20b854b239203baf6c961b850a4a51a2": "us",
    "85d61f5525af708c9f1e84dce6dc10e9": "jp",
    "45676429ef6b90e65b517129b700308e": "eu",
    "2d727c3278aa232d94f2fb45aec4d303": "sh",
}
COUNTRY = {0x45: "us", 0x4A: "jp", 0x50: "eu"}
COOPDX_DIRS = ("sm64coopdx", "sm64ex-coop")
ENV_ROM = "OF_SM64_ROM"
US_PLACES = {"ctl": 0x57B720, "tbl": 0x593560, "seq": 0x7B0860, "banksets": 0x7CC620}
TYPE_CTL, TYPE_TBL, TYPE_SEQ = 1, 2, 3
OUTPUT_RATE = 32000
ADSR_DISABLE, ADSR_HANG, ADSR_GOTO, ADSR_RESTART = 0, -1, -2, -3
class RomError(ValueError):
    pass
def coopdx_folders(env=None, home=None, platform=None):
    env = os.environ if env is None else env
    home = home or os.path.expanduser("~")
    platform = platform or sys.platform
    bases = []
    if platform.startswith("win"):
        appdata = env.get("APPDATA") or os.path.join(home, "AppData", "Roaming")
        bases.append(appdata)
    elif platform == "darwin":
        bases.append(os.path.join(home, "Library", "Application Support"))
    else:
        bases.append(env.get("XDG_DATA_HOME") or os.path.join(home, ".local", "share"))
        bases.extend(sorted(glob.glob(os.path.join(home, ".var", "app", "*", "data"))))
    out = []
    for base in bases:
        for name in COOPDX_DIRS:
            out.append(os.path.join(base, name))
    return out
def find_rom(env=None, home=None, platform=None, extra=None):
    env = os.environ if env is None else env
    for path in (extra, env.get(ENV_ROM)):
        if path and os.path.isfile(path):
            return os.path.abspath(path)
    for folder in coopdx_folders(env, home, platform):
        if not os.path.isdir(folder):
            continue
        names = sorted(n for n in os.listdir(folder)
                       if n.startswith("baserom.") and n.endswith(".z64"))
        names.sort(key=lambda n: n != "baserom.us.z64")
        for name in names:
            return os.path.join(folder, name)
    return None
def where_to_look(env=None, home=None, platform=None):
    first = coopdx_folders(env, home, platform)[0]
    return ("No SM64 ROM was found. Coop DX keeps yours as baserom.us.z64 in %s once it "
            "has started with it - or choose the file (any .z64 of the US game) with "
            "Choose ROM. It is only read, never copied." % first)
def to_big_endian(data):
    head = bytes(data[:4])
    if head == b"\x80\x37\x12\x40":
        return bytes(data), "z64"
    if head == b"\x37\x80\x40\x12":
        a = array.array("H", bytes(data[:len(data) & ~1]))
        a.byteswap()
        return a.tobytes(), "v64"
    if head == b"\x40\x12\x37\x80":
        a = array.array("I", bytes(data[:len(data) & ~3]))
        a.byteswap()
        return a.tobytes(), "n64"
    raise RomError("not an N64 ROM (it does not start like one)")
class Rom:
    def __init__(self, data, path=None):
        raw_md5 = hashlib.md5(data).hexdigest()
        self.data, self.order = to_big_endian(data)
        self.path = path
        self.md5 = hashlib.md5(self.data).hexdigest()
        self.file_md5 = raw_md5
        self.sha1 = hashlib.sha1(self.data).hexdigest()
        d = self.data
        self.name = d[0x20:0x34].decode("ascii", "replace").strip("\0 ")
        self.code = d[0x3B:0x3F].decode("ascii", "replace")
        self.version = d[0x3F]
        self.crc = struct.unpack(">II", d[0x10:0x18])
        self.region = KNOWN_MD5.get(self.md5) or COUNTRY.get(d[0x3E], "?")
        self.vanilla = self.md5 in KNOWN_MD5
        self._sound = None
    @classmethod
    def open(cls, path):
        if not path:
            return None
        with open(path, "rb") as handle:
            return cls(handle.read(), path)
    def describe(self):
        kind = ("the vanilla %s ROM%s" % (self.region.upper(),
                                          " (the one Coop DX uses)" if self.region == "us"
                                          else " (Coop DX uses only the US one)")
                if self.vanilla else "not a vanilla ROM Coop DX knows (region %s)"
                % self.region.upper())
        return "%s: %s, %s, %d KB, CRC %08X %08X, MD5 %s%s" % (
            os.path.basename(self.path or "rom"), self.name or "?", kind, len(self.data) // 1024,
            self.crc[0], self.crc[1], self.md5,
            "" if self.order == "z64" else " (read as .%s)" % self.order)
    def sound(self):
        if self._sound is None:
            self._sound = SoundData.locate(self.data)
        return self._sound
def _table(data, at, magic, lo=1, hi=64, limit=None):
    if at < 0 or at + 4 > len(data):
        return None
    m, count = struct.unpack_from(">HH", data, at)
    if m != magic or not lo <= count <= hi:
        return None
    head = (4 + 8 * count + 15) & ~15
    if at + head > len(data):
        return None
    limit = limit or (len(data) - at)
    out = []
    for i in range(count):
        off, length = struct.unpack_from(">II", data, at + 4 + 8 * i)
        if off < head or length > limit or off + length > limit:
            return None
        out.append((off, length))
    return out
def _seq_table(data, at):
    t = _table(data, at, TYPE_SEQ, 2, 64, 0x200000)
    if not t or t[0][0] != (4 + 8 * len(t) + 15) & ~15:
        return None
    for (a, la), (b, _) in zip(t, t[1:]):
        if b < a + la:
            return None
    return t
def _ctl_table(data, at):
    t = _table(data, at, TYPE_CTL, 1, 64, 0x100000)
    if not t:
        return None
    for off, length in t:
        if length < 16:
            return None
        ni, nd = struct.unpack_from(">II", data, at + off)
        if ni > 128 or nd > 128:
            return None
    return t
def _tbl_table(data, at, count):
    t = _table(data, at, TYPE_TBL, count, count, 0x800000)
    return t
def _banksets(data, at, nseq, nbanks):
    if at < 0 or at + 2 * nseq > len(data):
        return None
    offs = struct.unpack_from(">%dH" % nseq, data, at)
    if offs[0] != 2 * nseq:
        return None
    out = []
    for o in offs:
        if at + o >= len(data):
            return None
        n = data[at + o]
        if n > 16 or at + o + 1 + n > len(data):
            return None
        ids = list(data[at + o + 1:at + o + 1 + n])
        if any(b >= nbanks for b in ids):
            return None
        out.append(ids[::-1])
    return out
def _search(data, pattern, check):
    at = data.find(pattern)
    while at >= 0:
        if at % 16 == 0:
            found = check(at)
            if found:
                return at, found
        at = data.find(pattern, at + 1)
    return None, None
class Instrument:
    __slots__ = ("index", "range_lo", "range_hi", "release", "envelope", "low", "normal", "high")
    def sound_for(self, key):
        if key < self.range_lo:
            return self.low
        if key <= self.range_hi:
            return self.normal
        return self.high
class Drum:
    __slots__ = ("index", "release", "pan", "sound", "envelope")
class Sound:
    __slots__ = ("sample", "tuning")
    def __init__(self, sample, tuning):
        self.sample, self.tuning = sample, tuning
class Sample:
    __slots__ = ("addr", "size", "order", "predictors", "book", "loop_start", "loop_end",
                 "loop_count")
    @property
    def frames(self):
        return self.size // 9
class Bank:
    def __init__(self, index):
        self.index = index
        self.instruments = []
        self.drums = []
    def instrument(self, number):
        if not self.instruments:
            return None
        if number >= len(self.instruments):
            number = len(self.instruments) - 1
        while number >= 0:
            inst = self.instruments[number]
            if inst is not None:
                return inst
            number -= 1
        return None
    def drum(self, key):
        if not self.drums:
            return None
        return self.drums[min(max(key, 0), len(self.drums) - 1)]
class SoundData:
    def __init__(self, data, ctl, tbl, seq, banksets):
        self.data = data
        self.ctl_at, self.ctl = ctl
        self.tbl_at, self.tbl = tbl
        self.seq_at, self.seqs = seq
        self.banksets_at, self.banksets = banksets
        self._banks = {}
        self._pcm = {}
    @classmethod
    def locate(cls, data, places=US_PLACES):
        ctl_at = places.get("ctl")
        ctl = _ctl_table(data, ctl_at) if ctl_at is not None else None
        if not ctl:
            ctl_at, ctl = _search(data, b"\x00\x01\x00", lambda a: _ctl_table(data, a))
        if not ctl:
            raise RomError("this ROM has no SM64 sound banks where they can be found")
        nb = len(ctl)
        tbl_at = places.get("tbl")
        tbl = _tbl_table(data, tbl_at, nb) if tbl_at is not None else None
        if not tbl:
            tbl_at, tbl = _search(data, struct.pack(">HH", TYPE_TBL, nb),
                                  lambda a: _tbl_table(data, a, nb))
        if not tbl:
            raise RomError("this ROM's sample table could not be found")
        seq_at = places.get("seq")
        seq = _seq_table(data, seq_at) if seq_at is not None else None
        if not seq:
            seq_at, seq = _search(data, b"\x00\x03\x00", lambda a: _seq_table(data, a))
        if not seq:
            raise RomError("this ROM's sequences could not be found")
        ns = len(seq)
        bs_at = places.get("banksets")
        bs = _banksets(data, bs_at, ns, nb) if bs_at is not None else None
        if not bs:
            end = seq_at + max(o + n for o, n in seq)
            for at in range(end & ~15, min(len(data), end + 0x200), 16):
                bs = _banksets(data, at, ns, nb)
                if bs:
                    bs_at = at
                    break
        if not bs:
            bs_at, bs = _search(data, struct.pack(">H", 2 * ns),
                                lambda a: _banksets(data, a, ns, nb))
        if not bs:
            raise RomError("this ROM's bank sets could not be found")
        return cls(data, (ctl_at, ctl), (tbl_at, tbl), (seq_at, seq), (bs_at, bs))
    def describe(self):
        return ("%d sequences at 0x%X, %d banks at 0x%X, samples at 0x%X, bank sets at 0x%X"
                % (len(self.seqs), self.seq_at, len(self.ctl), self.ctl_at, self.tbl_at,
                   self.banksets_at))
    def sequence(self, index):
        off, length = self.seqs[index]
        return bytes(self.data[self.seq_at + off:self.seq_at + off + length])
    def banks_of(self, index):
        return list(self.banksets[index])
    def bank(self, index):
        if index in self._banks:
            return self._banks[index]
        if not 0 <= index < len(self.ctl):
            raise RomError("bank %d is not in this ROM (it has %d)" % (index, len(self.ctl)))
        bank = self._parse_bank(index)
        self._banks[index] = bank
        return bank
    def _parse_bank(self, index):
        d = self.data
        off, length = self.ctl[index]
        start = self.ctl_at + off
        ninst, ndrums = struct.unpack_from(">II", d, start)
        mem = start + 16
        size = length - 16
        tbl_base = self.tbl_at + self.tbl[index][0]
        tbl_end = self.tbl_at + self.tbl[index][0] + self.tbl[index][1]
        samples = {}
        def u32(p):
            if not 0 <= p <= size - 4:
                raise RomError("bank %d points outside itself (0x%X)" % (index, p))
            return struct.unpack_from(">I", d, mem + p)[0]
        def f32(p):
            return struct.unpack_from(">f", d, mem + p)[0]
        def envelope(p):
            out = []
            for k in range(64):
                if not 0 <= p + 4 * k <= size - 4:
                    break
                delay, arg = struct.unpack_from(">hh", d, mem + p + 4 * k)
                out.append((delay, arg))
                if delay in (ADSR_DISABLE, ADSR_HANG, ADSR_GOTO, ADSR_RESTART):
                    break
            return tuple(out)
        def sample(p):
            if p == 0:
                return None
            if p in samples:
                return samples[p]
            s = Sample()
            addr = u32(p + 4)
            loop = u32(p + 8)
            book = u32(p + 12)
            s.size = u32(p + 16)
            s.addr = tbl_base + addr
            if s.addr + s.size > tbl_end + 16:
                raise RomError("a sample of bank %d runs past its samples" % index)
            s.order, s.predictors = struct.unpack_from(">ii", d, mem + book)
            if not (1 <= s.order <= 8 and 1 <= s.predictors <= 16):
                raise RomError("a codebook of bank %d is not one (%d, %d)"
                               % (index, s.order, s.predictors))
            n = 8 * s.order * s.predictors
            s.book = struct.unpack_from(">%dh" % n, d, mem + book + 8)
            s.loop_start, s.loop_end, s.loop_count = struct.unpack_from(">IIi", d, mem + loop)
            samples[p] = s
            return s
        def sound(p):
            return Sound(sample(u32(p)), f32(p + 4))
        bank = Bank(index)
        for i in range(ninst):
            p = u32(4 + 4 * i)
            if p == 0:
                bank.instruments.append(None)
                continue
            inst = Instrument()
            inst.index = i
            inst.range_lo, inst.range_hi, inst.release = d[mem + p + 1], d[mem + p + 2], \
                d[mem + p + 3]
            inst.envelope = envelope(u32(p + 4))
            inst.low = sound(p + 8)
            inst.normal = sound(p + 16)
            inst.high = sound(p + 24)
            bank.instruments.append(inst)
        drums_at = u32(0)
        if drums_at and ndrums:
            for i in range(ndrums):
                p = u32(drums_at + 4 * i)
                if p == 0:
                    bank.drums.append(None)
                    continue
                dr = Drum()
                dr.index = i
                dr.release, dr.pan = d[mem + p], d[mem + p + 1]
                dr.sound = sound(p + 4)
                dr.envelope = envelope(u32(p + 12))
                bank.drums.append(dr)
        return bank
    def samples(self, s):
        key = (s.addr, s.size)
        pcm = self._pcm.get(key)
        if pcm is None:
            raw = self.data[s.addr:s.addr + s.size]
            pcm = decode_vadpcm(raw, s.order, s.predictors, s.book)
            self._pcm[key] = pcm
        return pcm
def expand_book(order, predictors, book):
    out = []
    for p in range(predictors):
        rows = [[book[(p * order + j) * 8 + k] for k in range(8)] for j in range(order)]
        hist = [tuple(rows[j][k] for j in range(order)) for k in range(8)]
        last = rows[order - 1]
        resid = [tuple(last[k - m - 1] for m in range(k)) for k in range(8)]
        out.append((hist, resid))
    return out
def _numpy():
    try:
        import numpy
        return numpy
    except Exception:
        return None
def decode_vadpcm(raw, order, predictors, book, frames=None, fast=True):
    n = len(raw) // 9 if frames is None else min(frames, len(raw) // 9)
    np = _numpy() if fast else None
    if np is not None and n:
        return _decode_numpy(np, raw, order, predictors, book, n)
    return _decode_plain(raw, order, predictors, book, n)
def _decode_numpy(np, raw, order, predictors, book, n):
    buf = np.frombuffer(bytes(raw[:9 * n]), dtype=np.uint8).reshape(n, 9).astype(np.int64)
    head = buf[:, 0]
    scale = np.left_shift(1, head >> 4)
    pred = head & 0xF
    pred = np.where(pred < predictors, pred, 0)
    nib = np.empty((n, 16), dtype=np.int64)
    nib[:, 0::2] = buf[:, 1:] >> 4
    nib[:, 1::2] = buf[:, 1:] & 0xF
    nib = np.where(nib >= 8, nib - 16, nib) * scale[:, None]
    r = nib.reshape(2 * n, 8)
    ph = np.repeat(pred, 2)
    b = np.array(book, dtype=np.int64).reshape(predictors, order, 8)
    a = b.transpose(0, 2, 1)
    m = np.zeros((predictors, 8, 8), dtype=np.int64)
    for k in range(8):
        for j in range(k):
            m[:, k, j] = b[:, order - 1, k - j - 1]
    resid = np.zeros((2 * n, 8), dtype=np.int64)
    for p in range(predictors):
        sel = ph == p
        if sel.any():
            resid[sel] = r[sel] @ m[p].T
    tail = 8 - order
    rows = a[:, tail:, :].tolist()
    rt = (resid[:, tail:]).tolist()
    xt = r[:, tail:].tolist()
    phl = ph.tolist()
    prev = [0] * order
    prevs = []
    for h in range(2 * n):
        prevs.append(prev)
        rw = rows[phl[h]]
        rh = rt[h]
        xh = xt[h]
        new = []
        for j in range(order):
            row = rw[j]
            tot = rh[j]
            for i in range(order):
                tot += row[i] * prev[i]
            v = (tot >> 11) + xh[j]
            if not -0x80000000 <= v <= 0x7FFFFFFF:
                v = ((v + 0x80000000) & 0xFFFFFFFF) - 0x80000000
            new.append(v)
        prev = new
    pm = np.array(prevs, dtype=np.int64).reshape(2 * n, order)
    hist = np.zeros((2 * n, 8), dtype=np.int64)
    for p in range(predictors):
        sel = ph == p
        if sel.any():
            hist[sel] = pm[sel] @ a[p].T
    out = ((hist + resid) >> 11) + r
    return array.array("h", np.clip(out.ravel(), -32768, 32767).astype(np.int16).tobytes())
def _decode_plain(raw, order, predictors, book, n):
    table = expand_book(order, predictors, book)
    out = array.array("h", bytes(32 * n))
    state = [0] * 16
    pos = 0
    for f in range(n):
        at = 9 * f
        head = raw[at]
        scale = 1 << (head >> 4)
        p = head & 0xF
        hist_c, resid_c = table[p if p < predictors else 0]
        ix = []
        for b in raw[at + 1:at + 9]:
            hi, lo = b >> 4, b & 0xF
            ix.append((hi - 16 if hi >= 8 else hi) * scale)
            ix.append((lo - 16 if lo >= 8 else lo) * scale)
        new = [0] * 16
        for j in (0, 1):
            prev = state[16 - order:] if j == 0 else new[8 - order:8]
            base = 8 * j
            r = ix[base:base + 8]
            for k in range(8):
                hc = hist_c[k]
                tot = 0
                for i in range(order):
                    tot += hc[i] * prev[i]
                rc = resid_c[k]
                for m in range(k):
                    tot += rc[m] * r[m]
                v = (tot >> 11) + r[k]
                if not -0x80000000 <= v <= 0x7FFFFFFF:
                    v = ((v + 0x80000000) & 0xFFFFFFFF) - 0x80000000
                new[base + k] = v
                out[pos] = 32767 if v > 32767 else (-32768 if v < -32768 else v)
                pos += 1
        state = new
    return out
def encode_plain(pcm, scale_power=0):
    out = bytearray()
    scale = 1 << scale_power
    for at in range(0, len(pcm), 16):
        chunk = list(pcm[at:at + 16]) + [0] * (16 - len(pcm[at:at + 16]))
        out.append(scale_power << 4)
        nib = [max(-8, min(7, int(round(v / float(scale))))) & 0xF for v in chunk]
        for i in range(0, 16, 2):
            out.append((nib[i] << 4) | nib[i + 1])
    return bytes(out)
