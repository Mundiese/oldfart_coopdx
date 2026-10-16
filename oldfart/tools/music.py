#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
MUSIC_LUA = "of_music.lua"
SOUND_DIR = "sound"
BEGIN_RE = re.compile(r"^    -- music\.py: rows begin \(order: (\w+)\)\n", re.M)
END_LINE = "    -- music.py: rows end\n"
RET_BEGIN = "-- music.py: retired begin\n"
RET_END = "-- music.py: retired end\n"
ORDERS = ("title", "game", "category", "manual")
STATE_FILE = os.path.join("tools", "music-release.json")
IMPORT_AUDIO = (".mp3", ".ogg", ".oga", ".wav", ".flac", ".aiff", ".aif", ".aifc",
                ".m4a", ".m4b", ".mp4", ".aac", ".opus", ".wma", ".webm", ".weba",
                ".mka", ".ac3", ".mp2", ".ape", ".wv", ".caf", ".amr", ".au")
IMPORT_WORDS = "mp3, ogg, m4a, aac, opus, flac, wav, wma, webm, aiff and other audio"
COPYABLE = (".mp3", ".ogg")
SAMPLE_RATE = 44100
DEFAULT_LUFS = -16.0
BUDGET = 10240000
HARD_WALL = 35 * 1048576
GROUP_SIZE = 40000
ROW_WIDTH = 678
FIELD_ORDER = ("file", "family", "bank", "ext", "volume", "loopFrom",
               "loopTo", "game", "name", "artist", "about")
QUALITIES = {"tiny": 32, "low": 48, "medium": 64, "high": 128, "original": None}
QUALITY_ORDER = ("tiny", "low", "medium", "high", "original")
DEFAULT_QUALITY = "medium"
ORIGINAL_KBPS = 128
OGG_OVERHEAD = 1.02
OGG_HEADERS = 4096
def luaregion():
    import importlib.util
    import sys
    if "of_luaregion" not in sys.modules:
        spec = importlib.util.spec_from_file_location(
            "of_luaregion", os.path.join(HERE, "luaregion.py"))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules["of_luaregion"] = module
    return sys.modules["of_luaregion"]
class MusicError(Exception):
    pass
TOKEN = re.compile(r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|-?\d+)')
def lua_unquote(text):
    body = text[1:-1]
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1),
                                                                   m.group(1)), body)
def lua_quote(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
def parse_row_literal(text):
    fields = {}
    for key, raw in TOKEN.findall(text):
        fields[key] = lua_unquote(raw) if raw.startswith('"') else int(raw)
    return fields
def write_row(row):
    f = row["fields"]
    lines = list(row["comments"])
    first = ['file = %s' % lua_quote(f["file"]),
             'family = %s' % lua_quote(f["family"])]
    if f.get("ext") not in (None, "m64"):
        first.append('ext = %s' % lua_quote(f["ext"]))
    else:
        first.append('bank = %d' % f["bank"])
    lines.append("    { " + ", ".join(first) + ",\n")
    extra = []
    if f.get("volume") is not None:
        extra.append("volume = %d" % f["volume"])
    if f.get("loopFrom") is not None:
        extra.append("loopFrom = %d" % f["loopFrom"])
        extra.append("loopTo = %d" % (f.get("loopTo") or 0))
    if extra:
        lines.append("      " + ", ".join(extra) + ",\n")
    if f.get("game"):
        lines.append("      game = %s,\n" % lua_quote(f["game"]))
    if f.get("artist"):
        lines.append("      name = %s,\n" % lua_quote(f["name"]))
        lines.append("      artist = %s,\n" % lua_quote(f["artist"]))
    else:
        lines.append("      name = %s,\n" % lua_quote(f["name"]))
    lines.append("      about = %s },\n" % lua_quote(f.get("about") or ""))
    return "".join(lines)
class Registry:
    def __init__(self, root):
        self.root = root
        self.path = os.path.join(root, MUSIC_LUA)
        with open(self.path, encoding="utf-8") as handle:
            raw = handle.read()
        src = luaregion().restore(raw, MUSIC_LUA)
        marked = BEGIN_RE.search(raw) is not None
        m = BEGIN_RE.search(src)
        if m is None:
            raise MusicError("of_music.lua has no '-- music.py: rows begin' line")
        end = src.find(END_LINE, m.end())
        if end < 0:
            raise MusicError("of_music.lua has no '-- music.py: rows end' line")
        self.order = m.group(1)
        self.head = src[:m.start()]
        self.tail = src[end + len(END_LINE):]
        self.rows = self._rows(src[m.end():end])
        rb = self.tail.find(RET_BEGIN)
        re_ = self.tail.find(RET_END)
        if rb < 0 or re_ < rb:
            raise MusicError("of_music.lua has no retired table markers")
        block = self.tail[rb + len(RET_BEGIN):re_]
        self.retired = {}
        for key, to in re.findall(r'\["([^"]+)"\]\s*=\s*"([^"]*)"', block):
            self.retired[key] = to
        self.families, self.family_under = [], {}
        for found in self._block("FAMILIES"):
            key, label, under = self._folder_line(found)
            self.families.append((key, label))
            self.family_under[key] = under
        self.categories = [self._folder_line(found)[:2]
                           for found in self._block("CATEGORIES")]
        kinds = re.search(r"music\.STREAM_KINDS = \{([^}]*)\}", src)
        self.stream_kinds = set(re.findall(r"(\w+) = true",
                                           kinds.group(1) if kinds else ""))
        vanilla = src.split("music.TRACKS = {", 1)[1].split("\n}\n", 1)[0]
        self.vanilla = re.findall(r'\{ seq = (SEQ_\w+),\s*name = "([^"]+)"',
                                  vanilla)
        if not marked:
            state = self._release_state()
            self.order = self._unmarked_order(state.get("order"))
            mine = set(state.get("imported") or ())
            for row in self.rows:
                if row["fields"].get("file") in mine and IMPORTED_MARK not in row["comments"]:
                    row["comments"] = row["comments"] + [IMPORTED_MARK]
    def _release_state(self):
        try:
            with open(os.path.join(self.root, STATE_FILE), encoding="utf-8") as handle:
                state = json.load(handle)
            return state if isinstance(state, dict) else {}
        except (OSError, ValueError):
            return {}
    def _unmarked_order(self, said):
        if said in ORDERS:
            return said
        for by in ("title", "category", "game"):
            if self.rows == sorted(self.rows, key=sort_key(self, by)):
                return by
        return "manual"
    @staticmethod
    def _rows(body):
        rows, comments, buf = [], [], None
        for line in body.splitlines(keepends=True):
            if buf is not None:
                buf.append(line)
                if line.rstrip().endswith("},"):
                    rows.append({"comments": comments,
                                 "fields": parse_row_literal("".join(buf)),
                                 "raw": "".join(buf)})
                    comments, buf = [], None
                continue
            stripped = line.strip()
            if stripped.startswith("--"):
                comments.append(line)
            elif stripped.startswith("{"):
                buf = [line]
                if stripped.endswith("},"):
                    rows.append({"comments": comments,
                                 "fields": parse_row_literal(line),
                                 "raw": line})
                    comments, buf = [], None
            elif stripped == "":
                continue
            else:
                raise MusicError("unreadable line in the registry: %r" % line)
        if buf is not None or comments:
            raise MusicError("the registry ends inside a row")
        return rows
    FOLDER_LINE = re.compile(r'\{ key = "(\w+)",\s*label = "([^"]+)"'
                             r'(?:,\s*under = "(\w+)")?\s*\}')
    def _block(self, name):
        span = self._span(self.head, name)
        if span is None:
            return []
        return self.FOLDER_LINE.findall(self.head[span[0]:span[1]])
    @staticmethod
    def _span(text, name):
        start = text.find("music.%s = {\n" % name)
        if start < 0:
            return None
        end = text.find("\n}\n", start)
        return (start, end + 3) if end >= 0 else None
    @staticmethod
    def _folder_line(found):
        key, label, under = found
        return key, label, under or None
    @staticmethod
    def folder_text(name, entries):
        out = ["music.%s = {\n" % name]
        for entry in entries:
            key, label = entry[0], entry[1]
            under = entry[2] if len(entry) > 2 else None
            out.append("    { key = %s label = %s%s },\n" % (
                ('"%s",' % key).ljust(12), lua_quote(label),
                (", under = %s" % lua_quote(under)) if under else ""))
        out.append("}\n")
        return "".join(out)
    def head_text(self):
        head = self.head
        span = self._span(head, "FAMILIES")
        if span is not None:
            head = head[:span[0]] + self.folder_text(
                "FAMILIES", [(k, l, self.family_under.get(k)) for k, l in self.families]
            ) + head[span[1]:]
        cats = self.folder_text("CATEGORIES", self.categories)
        span = self._span(head, "CATEGORIES")
        if span is not None:
            head = head[:span[0]] + cats + head[span[1]:]
        elif self.categories:
            at = head.find("music.FAMILY_FALLBACK")
            if at >= 0:
                at = head.find("\n", at) + 1
            else:
                at = self._span(head, "FAMILIES")[1]
            head = head[:at] + "\n" + cats + head[at:]
        return head
    def family_keys(self):
        return [k for k, _ in self.families] + [k for k, _ in self.categories]
    def find(self, ident):
        for i, row in enumerate(self.rows):
            if row["fields"]["file"] == ident:
                return i
        raise MusicError("no track with the id '%s' (see `music.py list`)" % ident)
    def text(self):
        out = [self.head_text(), "    -- music.py: rows begin (order: %s)\n" % self.order]
        out.extend(write_row(r) for r in self.rows)
        out.append(END_LINE)
        rb = self.tail.find(RET_BEGIN)
        re_ = self.tail.find(RET_END)
        ret = ["music.RETIRED_TRACKS = {\n"]
        for key in sorted(self.retired):
            ret.append('    [%s] = %s,\n' % (lua_quote(key), lua_quote(self.retired[key])))
        ret.append("}\n")
        tail = self.tail[:rb + len(RET_BEGIN)] + "".join(ret) + self.tail[re_:]
        out.append(tail)
        return "".join(out)
    def sound(self, row_or_fields):
        f = row_or_fields.get("fields", row_or_fields)
        ext = f.get("ext") or "m64"
        return os.path.join(self.root, SOUND_DIR, "%s.%s" % (f["file"], ext))
def leftovers(root=REPO):
    sound = os.path.join(root, SOUND_DIR)
    out = []
    for name in sorted(os.listdir(sound)) if os.path.isdir(sound) else []:
        path = os.path.join(sound, name)
        if ".music-tmp" in name and os.path.isfile(path):
            out.append((name, os.path.getsize(path)))
    return out
def clean_leftovers(root=REPO):
    gone = []
    for name, size in leftovers(root):
        try:
            os.remove(os.path.join(root, SOUND_DIR, name))
            gone.append((name, size))
        except OSError:
            pass
    return gone
def load(root=REPO, clean=False):
    if clean:
        clean_leftovers(root)
    return Registry(root)
def save(reg, leaving=()):
    problems = [p for p in check(reg, files=True, leaving=leaving)
                if p[0] == "error"]
    if problems:
        raise MusicError("not written - the result would be red:\n  "
                         + "\n  ".join(p[1] for p in problems))
    tmp = reg.path + ".music-tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(luaregion().finish(reg.text(), reg.root))
    os.replace(tmp, reg.path)
    if luaregion().is_release(reg.root) and os.path.isdir(os.path.join(reg.root, "tools")):
        state = {"order": reg.order,
                 "imported": sorted(r["fields"]["file"] for r in reg.rows
                                    if IMPORTED_MARK in r["comments"])}
        with open(os.path.join(reg.root, STATE_FILE), "w", encoding="utf-8") as handle:
            json.dump(state, handle, indent=1, sort_keys=True)
            handle.write("\n")
_WIDTHS = None
def char_widths(root=REPO):
    global _WIDTHS
    if _WIDTHS is None:
        table = {}
        try:
            with open(os.path.join(root, "tests", "harness.lua.txt"),
                      encoding="utf-8") as handle:
                src = handle.read()
            block = src.split("local CHAR_WIDTH = {", 1)[1].split("}\n", 1)[0]
            for ch, w in re.findall(r'\["(.)"\] = ([\d.]+)', block):
                table[ch] = float(w)
        except (OSError, IndexError):
            table = {" ": 9.6, "i": 6, "l": 6, "m": 21, "w": 19, "M": 21, "W": 22}
        _WIDTHS = table
    return _WIDTHS
def width(text, root=REPO):
    table = char_widths(root)
    return sum(table.get(ch, 16 if ch.isupper() else 14) for ch in text)
def name_width(name, root=REPO):
    return width("[ ] [ ] " + name, root)
def ffmpeg():
    return shutil.which("ffmpeg")
def need_ffmpeg(why):
    if ffmpeg() is None:
        raise MusicError(
            "ffmpeg is not installed on this machine, and %s needs it. Install "
            "ffmpeg (https://ffmpeg.org, or your package manager), or import an "
            ".ogg/.mp3 as it is with --no-normalise." % why)
def ogg_rate(path):
    try:
        with open(path, "rb") as handle:
            head = handle.read(4096)
    except OSError:
        return None
    at = head.find(b"\x01vorbis")
    if at < 0 or len(head) < at + 16:
        return None
    return struct.unpack("<I", head[at + 12:at + 16])[0]
def probe_rate(path):
    if path.lower().endswith(".ogg"):
        rate = ogg_rate(path)
        if rate:
            return rate
    probe = shutil.which("ffprobe")
    if probe:
        out = subprocess.run([probe, "-v", "error", "-select_streams", "a:0",
                              "-show_entries", "stream=sample_rate", "-of",
                              "default=nw=1:nk=1", path], capture_output=True,
                             text=True)
        if out.returncode == 0 and out.stdout.strip().isdigit():
            return int(out.stdout.strip())
    return None
def quality_kbps(quality):
    if quality is None:
        quality = DEFAULT_QUALITY
    if isinstance(quality, int):
        return quality
    if quality not in QUALITIES:
        raise MusicError("quality is one of %s, or a bitrate in kbit/s"
                         % ", ".join(QUALITY_ORDER))
    return QUALITIES[quality]
LOW_RATE = 24000
LOW_RATE_BELOW = 45
def encode_rate(kbps, channels=2):
    if kbps is not None and channels != 1 and kbps < LOW_RATE_BELOW:
        return LOW_RATE
    return SAMPLE_RATE
def transcode(src, dst, lufs, quality=None, channels=2, normalise=True):
    need_ffmpeg("turning %s into %s.ogg" % (os.path.basename(src),
                                            " a normalised" if normalise else " an"))
    kbps = quality_kbps(quality)
    rate = ["-q:a", "4"] if kbps is None else ["-b:a", "%dk" % kbps]
    cmd = [ffmpeg(), "-hide_banner", "-loglevel", "error", "-y", "-i", src,
           "-vn", "-map_metadata", "-1"]
    if normalise:
        cmd += ["-af", "loudnorm=I=%g:TP=-1.5:LRA=11" % lufs]
    cmd += ["-ar", str(encode_rate(kbps, channels)), "-ac", str(2 if channels != 1 else 1),
            "-c:a", "libvorbis"] + rate + [dst]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0 or not os.path.isfile(dst) or os.path.getsize(dst) == 0:
        raise MusicError(decode_reason(src, out.stderr))
DECODE_REASONS = (
    (r"libvorbis.*(return code -22|Invalid argument)",
     "the Ogg encoder has no mode for the size asked - pick another quality, or "
     "Mono"),
    (r"No such file or directory", "the file is not there any more"),
    (r"Permission denied", "the file may not be read (its permissions)"),
    (r"moov atom not found",
     "the file is incomplete: an .m4a/.mp4 keeps its index (the 'moov' part) at "
     "one end, and it is missing - often a download or a copy that did not finish"),
    (r"(?i)drm|encrypted|protected|\bdrms\b",
     "it is copy-protected (DRM - an old iTunes purchase, a streaming "
     "service's download) and no program may decode it"),
    (r"does not contain any stream|Output file .* does not contain|matches no streams",
     "it holds no sound - a video without an audio track, or an empty file"),
    (r"(?i)decoder .* not found|unknown codec|codec not currently supported|"
     r"Could not find codec parameters|no decoder",
     "this ffmpeg has no decoder for its kind of sound; a newer or fuller ffmpeg "
     "may (on CachyOS: sudo pacman -S ffmpeg)"),
    (r"Invalid data found when processing input|could not find sync|"
     r"Format .* detected only with low score|EBML header parsing failed|"
     r"Header missing|invalid frame|Error while decoding",
     "it is not audio ffmpeg can read: damaged, cut short, or not the kind its "
     "name says (renamed from something else)"),
    (r"Invalid argument|Error opening input",
     "ffmpeg could not open it as audio"),
)
def decode_reason(src, stderr=""):
    name = os.path.basename(src)
    text = stderr or ""
    if os.path.isfile(src) and os.path.getsize(src) == 0:
        why = "the file is empty (0 bytes)"
    else:
        why = next((w for pattern, w in DECODE_REASONS if re.search(pattern, text)),
                   "ffmpeg could not decode it")
    last = [l.strip() for l in text.strip().splitlines() if l.strip()]
    said = ""
    if last:
        tail = re.sub(r"^\[[^\]]*\]\s*", "", last[-1])
        said = " (ffmpeg: %s)" % tail[:160]
    return "%s cannot be imported: %s.%s" % (name, why, said)
def decode_problem(src):
    exe = ffmpeg()
    if exe is None:
        return None
    if os.path.isfile(src) and os.path.getsize(src) == 0:
        return decode_reason(src)
    try:
        out = subprocess.run([exe, "-hide_banner", "-v", "error", "-i", src, "-vn",
                              "-map", "0:a:0", "-t", "1", "-f", "null", "-"],
                             capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as why:
        return decode_reason(src, str(why))
    if out.returncode != 0:
        return decode_reason(src, out.stderr)
    return None
def _wav_seconds(data):
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        return None
    at, rate_bytes = 12, None
    while at + 8 <= len(data):
        tag, size = data[at:at + 4], struct.unpack("<I", data[at + 4:at + 8])[0]
        if tag == b"fmt " and size >= 16:
            rate_bytes = struct.unpack("<I", data[at + 16:at + 20])[0]
        elif tag == b"data" and rate_bytes:
            return size / rate_bytes
        at += 8 + size + (size & 1)
    return None
def _ogg_seconds(path, size):
    rate = ogg_rate(path)
    if not rate:
        return None
    with open(path, "rb") as handle:
        handle.seek(max(0, size - 65536))
        tail = handle.read()
    at = tail.rfind(b"OggS")
    while at >= 0:
        granule = struct.unpack("<q", tail[at + 6:at + 14])[0] if at + 14 <= len(tail) else -1
        if granule > 0:
            return granule / rate
        at = tail.rfind(b"OggS", 0, at)
    return None
def _flac_seconds(head):
    if head[:4] != b"fLaC" or len(head) < 26:
        return None
    info = head[8:42]
    rate = (info[10] << 12) | (info[11] << 4) | (info[12] >> 4)
    total = ((info[13] & 0x0F) << 32) | struct.unpack(">I", info[14:18])[0]
    return total / rate if rate else None
MP3_KBPS = {1: (0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320),
            2: (0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160)}
MP3_RATES = {3: (44100, 48000, 32000), 2: (22050, 24000, 16000), 0: (11025, 12000, 8000)}
def _mp3_seconds(head, size):
    at = 0
    if head[:3] == b"ID3" and len(head) >= 10:
        at = 10 + ((head[6] << 21) | (head[7] << 14) | (head[8] << 7) | head[9])
    while at + 4 <= len(head):
        if head[at] == 0xFF and (head[at + 1] & 0xE0) == 0xE0:
            version = (head[at + 1] >> 3) & 3
            layer = (head[at + 1] >> 1) & 3
            bi, ri = head[at + 2] >> 4, (head[at + 2] >> 2) & 3
            if version != 1 and layer == 1 and 0 < bi < 15 and ri < 3:
                kbps = MP3_KBPS[1 if version == 3 else 2][bi]
                rate = MP3_RATES[version][ri]
                per_frame = 1152 if version == 3 else 576
                for tag in (b"Xing", b"Info"):
                    x = head.find(tag, at, at + 200)
                    if x >= 0 and struct.unpack(">I", head[x + 4:x + 8])[0] & 1:
                        frames = struct.unpack(">I", head[x + 8:x + 12])[0]
                        return frames * per_frame / rate
                return (size - at) * 8 / (kbps * 1000.0)
        at += 1
    return None
MP4_EXTS = (".m4a", ".m4b", ".mp4", ".aac")
MP4_CONTAINERS = (b"moov", b"udta", b"ilst", b"trak", b"mdia")
def mp4_boxes(data, at=0, end=None):
    end = len(data) if end is None else end
    out = []
    while at + 8 <= end:
        size = struct.unpack(">I", data[at:at + 4])[0]
        kind = data[at + 4:at + 8]
        head = 8
        if size == 1 and at + 16 <= end:
            size = struct.unpack(">Q", data[at + 8:at + 16])[0]
            head = 16
        elif size == 0:
            size = end - at
        if size < head or at + size > end:
            break
        out.append((kind, at + head, at + size))
        at += size
    return out
def mp4_moov(path, limit=64 * 1048576):
    try:
        with open(path, "rb") as handle:
            total = os.fstat(handle.fileno()).st_size
            at = 0
            while at + 8 <= total:
                handle.seek(at)
                head = handle.read(16)
                if len(head) < 8:
                    return None
                size = struct.unpack(">I", head[:4])[0]
                kind = head[4:8]
                if size == 1 and len(head) >= 16:
                    size = struct.unpack(">Q", head[8:16])[0]
                elif size == 0:
                    size = total - at
                if size < 8:
                    return None
                if kind == b"moov":
                    if size > limit or at + size > total:
                        return None
                    handle.seek(at)
                    return handle.read(size)
                if at == 0 and kind != b"ftyp":
                    return None
                at += size
    except OSError:
        return None
    return None
def _mp4_seconds(path):
    moov = mp4_moov(path)
    if not moov:
        return None
    for kind, a, b in mp4_boxes(moov, 8):
        if kind == b"mvhd":
            body = moov[a:b]
            if body[:1] == b"\x01" and len(body) >= 32:
                scale, length = struct.unpack(">IQ", body[20:32])
            elif len(body) >= 20:
                scale, length = struct.unpack(">II", body[12:20])
            else:
                return None
            return length / float(scale) if scale else None
    return None
def _ffmpeg_seconds(path):
    exe = ffmpeg()
    if exe is None:
        return None
    try:
        out = subprocess.run([exe, "-hide_banner", "-i", path], capture_output=True,
                             text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    m = re.search(r"Duration:\s*(\d+):(\d\d):(\d\d(?:\.\d+)?)", out.stderr or "")
    if not m:
        return None
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
def duration(path):
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as handle:
            head = handle.read(262144)
    except OSError:
        return None
    ext = os.path.splitext(path)[1].lower()
    found = None
    if ext == ".wav":
        found = _wav_seconds(head)
    elif ext == ".ogg":
        found = _ogg_seconds(path, size)
    elif ext == ".flac":
        found = _flac_seconds(head)
    elif ext == ".mp3":
        found = _mp3_seconds(head, size)
    elif ext in MP4_EXTS:
        found = _mp4_seconds(path)
    if found is None and shutil.which("ffprobe"):
        out = subprocess.run([shutil.which("ffprobe"), "-v", "error", "-show_entries",
                              "format=duration", "-of", "default=nw=1:nk=1", path],
                             capture_output=True, text=True)
        try:
            found = float(out.stdout.strip())
        except ValueError:
            found = None
    if found is None and ext not in (".wav", ".ogg", ".flac", ".mp3", ".m64"):
        found = _ffmpeg_seconds(path)
    return found
def estimate_ogg(seconds, quality=None, channels=2):
    if seconds is None:
        return None
    kbps = quality_kbps(quality) or ORIGINAL_KBPS
    if kbps is None:
        kbps = ORIGINAL_KBPS
    if channels == 1 and quality_kbps(quality) is None:
        kbps = kbps * 0.6
    return int(seconds * kbps * 125 * OGG_OVERHEAD) + OGG_HEADERS
def how_imported(src, normalise=True, quality=None, channels=2, mp3_as_is="smaller",
                 have_ffmpeg=None):
    if have_ffmpeg is None:
        have_ffmpeg = ffmpeg() is not None
    ext = os.path.splitext(src)[1].lower()
    size = os.path.getsize(src) if os.path.isfile(src) else 0
    if ext == ".m64":
        return "m64", "sequence", size
    seconds = duration(src)
    ogg = estimate_ogg(seconds, quality, channels)
    if ext in COPYABLE:
        keep = not normalise and (quality == "original" or not have_ffmpeg)
        if ext == ".mp3" and mp3_as_is == "always":
            keep = True
        if ext == ".mp3" and mp3_as_is == "smaller" and ogg is not None and size <= ogg:
            keep = True
        if keep:
            return ext[1:], "as it is", size
    return "ogg", "converted", ogg
def plan_import(reg, paths, normalise=True, quality=None, channels=2, mp3_as_is="smaller",
                have_ffmpeg=None, release_bytes=None):
    files = gather(paths)
    now = wall_bytes(reg.root) if release_bytes is None else release_bytes
    tracks, running, over = [], now, []
    for src in files:
        out_ext, way, size = how_imported(src, normalise, quality, channels, mp3_as_is,
                                          have_ffmpeg)
        grow = (size or 0) + ROW_BYTES
        if running + grow > HARD_WALL:
            over.append(os.path.basename(src))
            fits = False
        else:
            running += grow
            fits = True
        tracks.append({"path": src, "name": os.path.basename(src), "ext": out_ext,
                       "way": way, "bytes": size, "seconds": duration(src)
                       if out_ext != "m64" else None, "fits": fits})
    return {"tracks": tracks, "release_now": now, "release_after": running,
            "wall": HARD_WALL, "over": over}
def mb(n):
    return "%.1f MB" % (n / 1048576.0)
def plan_lines(plan):
    out = []
    for t in plan["tracks"]:
        size = "?" if t["bytes"] is None else mb(t["bytes"])
        length = "" if not t["seconds"] else " %d:%02d," % divmod(int(t["seconds"]), 60)
        out.append("  %s:%s %s .%s, %s%s" % (t["name"], length, t["way"], t["ext"],
                                             "~" if t["way"] == "converted" else "", size)
                   + ("" if t["fits"] else "  - NOT imported: past the 35 MB wall"))
    out.append("the mod folder as Coop DX counts it: %s now, %s after the import "
               "(the wall: %s)"
               % (mb(plan["release_now"]), mb(plan["release_after"]), mb(plan["wall"])))
    if plan["over"]:
        out.append("refused, they would take the mod past Coop DX's 35 MB wall (it "
                   "would vanish from the mod list): " + ", ".join(plan["over"]))
    return out
def parse_span(text, flag):
    try:
        a, b = text.split(":", 1)
        return float(a), float(b)
    except ValueError:
        raise MusicError("%s wants START:END, got '%s'" % (flag, text))
def loop_frames(args, sound_path):
    if getattr(args, "no_loop", False):
        return None
    if getattr(args, "loop_frames", None):
        a, b = parse_span(args.loop_frames, "--loop-frames")
        return int(a), int(b)
    if getattr(args, "loop", None):
        a, b = parse_span(args.loop, "--loop")
        rate = probe_rate(sound_path)
        if rate is None:
            raise MusicError("cannot read the sample rate of %s to turn seconds "
                             "into frames; give --loop-frames instead"
                             % os.path.basename(sound_path))
        return int(round(a * rate)), (int(round(b * rate)) if b > 0 else int(b))
    return "keep"
def slug(text):
    s = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    s = re.sub(r"_+", "_", s)[:48].strip("_")
    if not s:
        s = "track"
    if not s[0].isalpha():
        s = "t_" + s
    return s
def nice_title(stem):
    words = re.sub(r"[_\-]+", " ", stem).strip()
    return " ".join(w[:1].upper() + w[1:] for w in words.split())
def resolve_category(reg, value):
    if value is None:
        return None
    low = value.strip().lower()
    for key, label, parent in folders(reg):
        path = "%s / %s" % (category_label(reg, parent), label) if parent else label
        if low in (key.lower(), path.lower()):
            return key
    for key, label, parent in folders(reg):
        if low == label.lower():
            return key
    raise MusicError("no category '%s'; one of: %s"
                     % (value, ", ".join(reg.family_keys())))
GAMES = "games"
GAMES_LABEL = "From other games"
DEFAULT_CATEGORY = "mine"
LABEL_MAX = 40
def category_label(reg, key):
    if key == GAMES:
        return GAMES_LABEL
    return dict(reg.categories).get(key, key)
def folders(reg):
    out = []
    cats = set(k for k, _ in reg.categories)
    for key, label in reg.families:
        under = reg.family_under.get(key)
        out.append((key, label, under if under in cats else GAMES))
    out += [(key, label, None) for key, label in reg.categories]
    return out
def category_tree(reg):
    out = [{"key": GAMES, "label": GAMES_LABEL, "fixed": True, "folders": []}]
    out += [{"key": k, "label": l, "fixed": False, "folders": []} for k, l in reg.categories]
    by = {c["key"]: c for c in out}
    for key, label, parent in folders(reg):
        if parent is not None:
            by[parent]["folders"].append({"key": key, "label": label})
    return out
def default_category(reg):
    keys = reg.family_keys()
    if DEFAULT_CATEGORY in keys:
        return DEFAULT_CATEGORY
    return "other" if "other" in keys else (keys[0] if keys else "other")
def folder_tracks(reg, key):
    inside = {key} | {k for k, _, parent in folders(reg) if parent == key}
    return [r["fields"]["file"] for r in reg.rows if r["fields"]["family"] in inside]
def _clean_label(reg, label, parent, skip=None):
    label = re.sub(r"\s+", " ", (label or "")).strip()
    if not label:
        raise MusicError("a category needs a name")
    if '"' in label or "\\" in label:
        raise MusicError("a category's name holds no quote or backslash")
    if len(label) > LABEL_MAX:
        raise MusicError("a category's name is at most %d letters" % LABEL_MAX)
    if parent is None:
        taken = [l for k, l in reg.categories if k != skip] + [GAMES_LABEL] + \
            list(reg_headings(reg))
    else:
        taken = [l for k, l in reg.families if k != skip]
    if label.lower() in (t.lower() for t in taken):
        raise MusicError("there is a category called '%s' already" % label)
    if width("   +  " + label, reg.root) > ROW_WIDTH:
        raise MusicError("'%s' is wider than the menu's %dpx row" % (label, ROW_WIDTH))
    return label
def reg_headings(reg):
    return re.findall(r'^music\.[A-Z]+\s*=\s*"([^"]+)"', reg.head, re.M)
def _new_key(reg, label):
    base = re.sub(r"[^a-z0-9]+", "", label.lower())[:10] or "folder"
    if not base[0].isalpha():
        base = "c" + base
    taken = set(reg.family_keys()) | {GAMES}
    key, n = base, 2
    while key in taken:
        key = "%s%d" % (base[:9], n)
        n += 1
    return key
def add_category(reg, label, under=None):
    if under is not None and under != GAMES and under not in dict(reg.categories):
        raise MusicError("no category '%s' to put a folder in" % under)
    label = _clean_label(reg, label, under)
    key = _new_key(reg, label)
    if under is None:
        reg.categories.append((key, label))
    else:
        reg.families.append((key, label))
        reg.family_under[key] = None if under == GAMES else under
    save(reg)
    return key
def rename_category(reg, key, label):
    if key == GAMES:
        raise MusicError("'From other games' is the game's own heading and keeps its name")
    found = [(k, l, p) for k, l, p in folders(reg) if k == key]
    if not found:
        raise MusicError("no category '%s'" % key)
    label = _clean_label(reg, label, found[0][2], skip=key)
    if found[0][2] is None:
        reg.categories = [(k, label if k == key else l) for k, l in reg.categories]
    else:
        reg.families = [(k, label if k == key else l) for k, l in reg.families]
    save(reg)
    return label
def delete_category(reg, key, move_to=None):
    if key in (GAMES, "other"):
        raise MusicError("'%s' stays: %s" % (category_label(reg, key) if key == GAMES
                                              else "Other games",
                                              "it is the game's own heading" if key == GAMES
                                              else "a track filed nowhere else lands there"))
    found = [(k, l, p) for k, l, p in folders(reg) if k == key]
    if not found:
        raise MusicError("no category '%s'" % key)
    held = folder_tracks(reg, key)
    inside = {key} | {k for k, _, p in folders(reg) if p == key}
    if held:
        if move_to is None:
            raise MusicError("'%s' holds %d track(s): move them to another category "
                             "first, or say where they go" % (found[0][1], len(held)))
        target = resolve_category(reg, move_to)
        if target in inside:
            raise MusicError("the tracks cannot move into the category being deleted")
        for row in reg.rows:
            if row["fields"]["family"] in inside:
                row["fields"]["family"] = target
    reg.categories = [(k, l) for k, l in reg.categories if k not in inside]
    reg.families = [(k, l) for k, l in reg.families if k not in inside]
    for k in inside:
        reg.family_under.pop(k, None)
    if reg.order == "category":
        sort_rows(reg, "category")
    save(reg)
    return held
def move_to_category(reg, idents, key):
    target = resolve_category(reg, key)
    for ident in idents:
        reg.rows[reg.find(ident)]["fields"]["family"] = target
    if reg.order != "manual":
        sort_rows(reg, reg.order)
    save(reg)
    return target
def build_about(game, artist, about):
    return about or ""
def row_artist(fields):
    return fields.get("artist") or artist_of(fields.get("about") or "")
def row_label(fields):
    name = fields.get("name") or fields.get("file") or ""
    game = fields.get("game")
    if game:
        return name if game in name else "%s - %s" % (game, name)
    artist = row_artist(fields)
    if not artist or name.endswith(" - " + artist):
        return name
    return "%s - %s" % (name, artist)
def set_artist(about, artist):
    at = about.rfind(", by ")
    if at >= 0:
        return about[:at] + ", by " + artist
    if about.startswith("by "):
        return "by " + artist
    return about + ", by " + artist
def artist_of(about):
    at = about.rfind(", by ")
    if at >= 0:
        return about[at + 5:]
    if about.startswith("by "):
        return about[3:]
    return ""
def place(reg, row):
    reg.rows.append(row)
    if reg.order != "manual":
        sort_rows(reg, reg.order)
IMPORTED_MARK = "    -- music.py: imported\n"
ROW_BYTES = 200
def gather(paths):
    files = []
    for path in paths:
        if os.path.isdir(path):
            for dirpath, _, names in os.walk(path):
                for name in sorted(names):
                    if os.path.splitext(name)[1].lower() in IMPORT_AUDIO + (".m64",):
                        files.append(os.path.join(dirpath, name))
        elif os.path.isfile(path):
            files.append(path)
        else:
            raise MusicError("no such file: %s" % path)
    return files
def import_files(reg, paths, title=None, game=None, artist=None, about=None,
                 category=None, bank=None, volume=None, loop=None,
                 loop_frames_=None, ident=None, normalise=True,
                 lufs=DEFAULT_LUFS, replace=False, quality=None, channels=2,
                 mp3_as_is="smaller", skipped=None, release_bytes=None):
    files = gather(paths)
    if not files:
        raise MusicError("nothing to import (%s, or an m64 sequence)" % IMPORT_WORDS)
    if len(files) > 1 and (ident or title):
        raise MusicError("--id and --title name one track; import the files "
                         "one at a time to give each its own")
    family = resolve_category(reg, category) or default_category(reg)
    done = []
    staged = []
    left_out = [] if skipped is None else skipped
    running = wall_bytes(reg.root) if release_bytes is None else release_bytes
    try:
        for src in files:
            mark = len(staged)
            try:
                running = _import_one(reg, src, running, staged, done, title, game,
                                      artist, about, family, bank, volume, loop,
                                      loop_frames_, ident, normalise, lufs, replace,
                                      quality, channels, mp3_as_is)
            except MusicError as why:
                for tmp, _ in staged[mark:]:
                    if tmp is not None and os.path.exists(tmp):
                        os.remove(tmp)
                del staged[mark:]
                left_out.append((src, str(why)))
        for tmp, dst in staged:
            if tmp is not None:
                os.replace(tmp, dst)
        while True:
            red = [s for lvl, s in check(reg, files=True, leaving=tuple(
                os.path.basename(d) for t, d in staged if t is None)) if lvl == "error"]
            blamed = [i for i in done if any(s.startswith(i + ":") for s in red)]
            if not blamed:
                break
            for ident_ in blamed:
                at = reg.find(ident_)
                row = reg.rows.pop(at)
                path = reg.sound(row)
                for tmp, dst in staged:
                    if tmp is not None and dst == path and os.path.exists(dst):
                        os.remove(dst)
                staged[:] = [(t, d) for t, d in staged if not (t is not None and d == path)]
                done.remove(ident_)
                left_out.append((ident_, "; ".join(s[len(ident_) + 2:] for s in red
                                                    if s.startswith(ident_ + ":"))))
        try:
            save(reg, leaving=tuple(os.path.basename(d) for t, d in staged
                                    if t is None))
        except MusicError:
            for tmp, dst in staged:
                if tmp is not None and os.path.exists(dst):
                    os.remove(dst)
            raise
        for tmp, dst in staged:
            if tmp is None and os.path.exists(dst):
                os.remove(dst)
    finally:
        for tmp, _ in staged:
            if tmp is not None and os.path.exists(tmp):
                os.remove(tmp)
    if skipped is None and left_out:
        said = "\n  ".join(why if why.startswith(os.path.basename(f)) else
                           "%s: %s" % (os.path.basename(f), why) for f, why in left_out)
        if done:
            raise MusicError("imported %s; not imported:\n  %s" % (", ".join(done), said))
        raise MusicError(said if len(left_out) == 1 else "nothing imported:\n  " + said)
    return done
def _import_one(reg, src, running, staged, done, title, game, artist, about, family,
                bank, volume, loop, loop_frames_, ident, normalise, lufs, replace,
                quality, channels, mp3_as_is):
    ext = os.path.splitext(src)[1].lower()
    stem = os.path.splitext(os.path.basename(src))[0]
    new_id = ident or slug(stem)
    existing = [i for i, r in enumerate(reg.rows)
                if r["fields"]["file"].lower() == new_id.lower()]
    if existing and not replace:
        raise MusicError("the id '%s' is taken; give --id, or --replace "
                         "to put the new file over it" % new_id)
    fields = {"file": new_id, "family": family,
              "name": title or nice_title(stem)}
    if game:
        fields["game"] = game
    who = artist or artist_of(about or "")
    if not who:
        raise MusicError("no artist - every track names who made it "
                         "(--artist)")
    fields["artist"] = who
    fields["about"] = build_about(game, who, about)
    if volume is not None:
        fields["volume"] = int(volume)
    if ext == ".m64":
        if bank is None:
            raise MusicError("a .m64 needs --bank (its soundfont number, "
                             "1-63: never guessed)")
        with open(src, "rb") as handle:
            if handle.read(1) != b"\xd3":
                raise MusicError("%s is not a sequence (an .m64 opens "
                                 "on 0xD3)" % os.path.basename(src))
        fields["bank"] = int(bank)
        out_ext, way = "m64", "sequence"
    elif ext in IMPORT_AUDIO:
        if bank is not None:
            raise MusicError("a recording carries its own sound and "
                             "takes no --bank")
        out_ext, way, _ = how_imported(src, normalise, quality, channels,
                                       mp3_as_is)
        if way == "converted":
            need_ffmpeg("a %s file" % ext)
        if out_ext not in reg.stream_kinds:
            raise MusicError("the mod cannot stream .%s (it streams %s)"
                             % (out_ext, ", ".join(sorted(reg.stream_kinds))))
        fields["ext"] = out_ext
    else:
        raise MusicError("%s cannot be imported: .%s is not a kind of audio the "
                         "import knows (%s, or an m64 sequence)"
                         % (os.path.basename(src), ext.lstrip(".") or "(no ending)",
                            IMPORT_WORDS))
    dst = os.path.join(reg.root, SOUND_DIR, "%s.%s" % (new_id, out_ext))
    tmp = os.path.join(reg.root, SOUND_DIR, "%s.music-tmp.%s" % (new_id, out_ext))
    staged.append((tmp, dst))
    if out_ext == "ogg" and way == "converted":
        transcode(src, tmp, lufs, quality, channels, normalise)
    else:
        shutil.copyfile(src, tmp)
    grow = os.path.getsize(tmp) + ROW_BYTES
    for i in existing:
        old_path = reg.sound(reg.rows[i])
        if os.path.exists(old_path):
            grow -= os.path.getsize(old_path)
    if running + grow > HARD_WALL:
        raise MusicError(
            "not imported: it would take the mod folder to %s as Coop DX counts "
            "it, past its 35 MB wall (over it the mod is greyed out in the "
            "list). Pick a lower quality or mono, or leave it out"
            % mb(running + grow))
    class _A:
        pass
    a = _A()
    a.loop, a.loop_frames, a.no_loop = loop, loop_frames_, False
    if out_ext != "m64":
        span = loop_frames(a, tmp)
        if span not in (None, "keep"):
            fields["loopFrom"], fields["loopTo"] = span
    elif loop or loop_frames_:
        raise MusicError("a sequence loops itself; --loop is for "
                         "recordings")
    for i in sorted(existing, reverse=True):
        old = reg.rows.pop(i)
        old_path = reg.sound(old)
        if old_path != dst and os.path.exists(old_path):
            staged.append((None, old_path))
    reg.retired.pop(new_id, None)
    place(reg, {"comments": [IMPORTED_MARK], "fields": fields, "raw": ""})
    done.append(new_id)
    return running + grow
def edit(reg, ident, title=None, game=None, artist=None, about=None,
         category=None, volume=None, bank=None, loop=None, loop_frames_=None,
         no_loop=False):
    row = reg.rows[reg.find(ident)]
    f = row["fields"]
    if title is not None:
        f["name"] = title
    if game is not None:
        if game:
            f["game"] = game
        else:
            f.pop("game", None)
    if about is not None:
        f["about"] = about
    if artist is not None:
        f["artist"] = artist
    if category is not None:
        f["family"] = resolve_category(reg, category)
    if volume is not None:
        f["volume"] = int(volume)
    if bank is not None:
        if f.get("ext") not in (None, "m64"):
            raise MusicError("a recording takes no bank")
        f["bank"] = int(bank)
    if loop or loop_frames_ or no_loop:
        if f.get("ext") in (None, "m64"):
            raise MusicError("a sequence loops itself; loop points are for "
                             "recordings")
        class _A:
            pass
        a = _A()
        a.loop, a.loop_frames, a.no_loop = loop, loop_frames_, no_loop
        span = loop_frames(a, reg.sound(row))
        if span is None:
            f.pop("loopFrom", None)
            f.pop("loopTo", None)
        elif span != "keep":
            f["loopFrom"], f["loopTo"] = span
    if reg.order != "manual":
        sort_rows(reg, reg.order)
    save(reg)
    return f
def _retire(reg, ident, to=None):
    i = reg.find(ident)
    if to is not None:
        reg.find(to)
        if to == ident:
            raise MusicError("a track cannot replace itself")
    row = reg.rows.pop(i)
    reg.retired[ident] = to or ""
    for key, val in list(reg.retired.items()):
        if val == ident and key != ident:
            reg.retired[key] = to or ""
    return row
def remove(reg, ident, to=None, keep_file=False):
    row = _retire(reg, ident, to)
    path = reg.sound(row)
    save(reg, leaving=() if keep_file else (os.path.basename(path),))
    if not keep_file and os.path.exists(path):
        os.remove(path)
    return row["fields"]
def remove_many(reg, idents, progress=None):
    paths = []
    for ident in idents:
        paths.append(reg.sound(_retire(reg, ident)))
        if progress:
            progress(ident)
    save(reg, leaving=tuple(os.path.basename(p) for p in paths))
    for path in paths:
        if os.path.exists(path):
            os.remove(path)
def move(reg, ident, before=None, after=None, to=None):
    i = reg.find(ident)
    if ident in (before, after):
        return "%s stays where it is: a track cannot go %s itself; nothing changed" % (
            ident, "before" if before == ident else "after")
    for target in (before, after):
        if target is not None:
            reg.find(target)
    row = reg.rows.pop(i)
    if before is not None:
        reg.rows.insert(reg.find(before), row)
    elif after is not None:
        reg.rows.insert(reg.find(after) + 1, row)
    elif to is not None:
        reg.rows.insert(max(0, min(len(reg.rows), int(to) - 1)), row)
    else:
        reg.rows.insert(i, row)
        raise MusicError("move needs --before, --after or --to")
    reg.order = "manual"
    save(reg)
    return "moved %s; order is now manual" % ident
def sort_key(reg, by):
    order = [f["key"] for f in category_tree(reg)[0]["folders"]]
    for cat in category_tree(reg)[1:]:
        order += [cat["key"]] + [f["key"] for f in cat["folders"]]
    rank = {k: n for n, k in enumerate(order)}
    def title(r):
        return r["fields"]["name"].lower()
    if by == "title":
        return title
    if by == "game":
        return lambda r: ((r["fields"].get("game") or r["fields"]["name"]).lower(),
                          title(r))
    if by == "category":
        return lambda r: (rank.get(r["fields"]["family"], len(rank)), title(r))
    raise MusicError("sort by title, game or category")
def sort_rows(reg, by):
    reg.rows.sort(key=sort_key(reg, by))
    reg.order = by
def _release_size():
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "release_size", os.path.join(HERE, "release_size.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
def shipped_sizes(root):
    return _release_size().sizes(root)
def shipped_bytes(root):
    return shipped_sizes(root)["release"]
def engine_bytes(root):
    return _release_size().engine_bytes(root)
def wall_bytes(root):
    return max(shipped_bytes(root), engine_bytes(root))
def wall_line(n):
    return _release_size().wall_line(n)
def lua_sound_refs(root):
    found = set()
    pattern = re.compile(r"""["']sound/([^"'/]+)["']""")
    for name in os.listdir(root):
        if name.endswith(".lua"):
            with open(os.path.join(root, name), encoding="utf-8", errors="replace") as handle:
                text = handle.read()
                found.update(pattern.findall(text))
                if '"sound/of_ui_" .. name .. ".ogg"' in text:
                    names = re.search(r"uisfx\.NAMES\s*=\s*\{([^}]*)\}", text)
                    for word in re.findall(r'"([a-z_]+)"', names.group(1) if names else ""):
                        found.add("of_ui_%s.ogg" % word)
    return found
def venue_music(root):
    path = os.path.join(root, "of_venues.lua")
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    start = text.find("venues.LAYOUTS = {")
    if start < 0:
        return []
    out, venue = [], None
    for line in text[start:].splitlines()[1:]:
        if line.startswith("}"):
            break
        head = re.match(r"^    ([A-Za-z_][A-Za-z0-9_]*) = \{", line)
        if head:
            venue = head.group(1)
        m = re.search(r"\blook = \{[^}]*\bmusic = \"([^\"]+)\"", line)
        if m and venue:
            out.append((venue, m.group(1)))
    return out
def check(reg, files=True, leaving=()):
    out = []
    err = lambda s: out.append(("error", s))
    note = lambda s: out.append(("note", s))
    keys = set(reg.family_keys())
    every = reg.family_keys()
    for key in sorted(set(k for k in every if every.count(k) > 1)):
        err("category key '%s' is used twice" % key)
    if GAMES in keys:
        err("'%s' is From other games' own key and names no category" % GAMES)
    cats = dict(reg.categories)
    for key, under in reg.family_under.items():
        if under is not None and under not in cats:
            err("folder '%s' is under '%s', which is no category" % (key, under))
    seen = {}
    for key, label, parent in folders(reg):
        where = "top" if parent is None else "sub"
        if label.lower() in seen.get(where, set()):
            err("the category name '%s' is used twice" % label)
        seen.setdefault(where, set()).add(label.lower())
        if width("   +  " + label, reg.root) > ROW_WIDTH:
            err("category '%s' is wider than the menu's %dpx row" % (label, ROW_WIDTH))
    for key, label in reg.categories:
        if label.lower() in [h.lower() for h in reg_headings(reg)] + [GAMES_LABEL.lower()]:
            err("category '%s' takes the name of one of the Music page's own headings"
                % label)
    ids, names = {}, {}
    if reg.order not in ORDERS:
        err("the order line says '%s'; it is one of %s" % (reg.order, ", ".join(ORDERS)))
    for row in reg.rows:
        f = row["fields"]
        ident = f.get("file")
        if not ident or not re.fullmatch(r"[a-z][a-z0-9_]*", ident):
            err("row id %r is not lower-case letters, digits and _" % ident)
            continue
        low = ident.lower()
        if low in ids:
            err("duplicate id: %s" % ident)
        ids[low] = row
        for field in f:
            if field not in FIELD_ORDER:
                err("%s: unknown field '%s'" % (ident, field))
        for field in ("family", "name"):
            if not isinstance(f.get(field), str) or not f.get(field):
                err("%s: no %s" % (ident, field))
        if not isinstance(f.get("about", ""), str):
            err("%s: about is not text" % ident)
        if not all(isinstance(f.get(k), str) for k in ("family", "name")):
            continue
        if f["family"] not in keys:
            err("%s: category '%s' is not one of music.FAMILIES or music.CATEGORIES"
                % (ident, f["family"]))
        if f["name"].lower() in names:
            err("duplicate title: %s (%s and %s)" % (f["name"], names[f["name"].lower()], ident))
        names[f["name"].lower()] = ident
        for field in ("name", "about", "game", "artist"):
            v = f.get(field)
            if isinstance(v, str) and ('"' in v or "\\" in v or "}," in v or "\n" in v):
                err("%s: %s holds a quote, backslash, '},' or line break" % (ident, field))
        if not (row_artist(f) or "").strip():
            err("%s: credits nobody (no artist)" % ident)
        w = name_width(row_label(f), reg.root)
        if w > ROW_WIDTH:
            note("%s: the row is %dpx, the menu's %dpx - it scrolls under the cursor"
                 % (ident, w, ROW_WIDTH))
        w = width(f.get("about") or "", reg.root)
        if w > ROW_WIDTH:
            note("%s: the description is %dpx, the footer's %dpx - it scrolls"
                 % (ident, w, ROW_WIDTH))
        ext = f.get("ext")
        recording = ext not in (None, "m64")
        if recording:
            if ext not in reg.stream_kinds:
                err("%s: .%s is not a kind the mod streams" % (ident, ext))
            if "bank" in f:
                err("%s: a recording takes no bank" % ident)
        else:
            bank = f.get("bank")
            if not isinstance(bank, int) or not 1 <= bank <= 63:
                err("%s: bank %r is not 1-63 (0 is the sound-effects bank)" % (ident, bank))
            if "loopFrom" in f or "loopTo" in f:
                err("%s: loop points on a sequence" % ident)
        vol = f.get("volume")
        if vol is not None and not 0 <= vol <= 127:
            err("%s: volume %d is not 0-127" % (ident, vol))
        if "loopFrom" in f:
            a, b = f["loopFrom"], f.get("loopTo", 0)
            if a < 0 or (b > 0 and b <= a):
                err("%s: loop %d:%d ends before it starts" % (ident, a, b))
        if files:
            path = reg.sound(row)
            if not os.path.isfile(path):
                err("%s: missing file %s" % (ident, os.path.relpath(path, reg.root)))
            else:
                with open(path, "rb") as handle:
                    magic = handle.read(4)
                if not recording and magic[:1] != b"\xd3":
                    err("%s: %s is not a sequence" % (ident, os.path.basename(path)))
                if ext == "ogg" and magic != b"OggS":
                    err("%s: %s is not an Ogg file" % (ident, os.path.basename(path)))
    if reg.order != "manual" and not reg.rows == sorted(reg.rows, key=sort_key(reg, reg.order)):
        err("the rows are not in %s order (run `music.py sort --by %s`)" % (reg.order, reg.order))
    for key, to in sorted(reg.retired.items()):
        if key.lower() in ids:
            err("retired id %s is also a live row" % key)
        if to and to.lower() not in ids:
            err("retired id %s points at %s, which is not a track" % (key, to))
    for venue, key in venue_music(reg.root):
        if key.startswith("SEQ_"):
            continue
        if key.lower() in ids:
            continue
        to = reg.retired.get(key)
        if to and to.lower() in ids:
            note("venue %s plays %s, a removed track: it plays %s instead" % (venue, key, to))
        else:
            err("venue %s plays %s, which is not a track any more - give the map other "
                "music (the Studio's Music tab, then export it again) before removing it"
                % (venue, key))
    if files:
        sound = os.path.join(reg.root, SOUND_DIR)
        used = {os.path.basename(reg.sound(r)) for r in reg.rows}
        used |= lua_sound_refs(reg.root)
        seen = {}
        for name in sorted(os.listdir(sound)) if os.path.isdir(sound) else []:
            path = os.path.join(sound, name)
            if not os.path.isfile(path):
                continue
            if ".music-tmp" in name:
                err("a half-written import is left in sound/: %s" % name)
                continue
            if name not in used and name not in leaving:
                err("unused file sound/%s (no row names it: import it, or "
                    "delete it - every file in sound/ is downloaded by every "
                    "joiner)" % name)
            with open(path, "rb") as handle:
                digest = hashlib.sha1(handle.read()).hexdigest()
            if digest in seen:
                err("duplicate file: sound/%s is sound/%s byte for byte" % (name, seen[digest]))
            seen.setdefault(digest, name)
    return out
def meter(reg):
    sound = os.path.join(reg.root, SOUND_DIR)
    music = sum(os.path.getsize(os.path.join(sound, n)) for n in os.listdir(sound)
                if os.path.isfile(os.path.join(sound, n))) if os.path.isdir(sound) else 0
    both = shipped_sizes(reg.root)
    total = both["release"]
    groups = -(-total // GROUP_SIZE)
    wall = max(total, both["engine"])
    left = leftovers(reg.root)
    return {"music_bytes": music, "shipped_bytes": total, "dev_bytes": both["dev"],
            "engine_bytes": both["engine"], "wall_bytes": wall, "wall_line": wall_line(wall),
            "leftovers": len(left), "leftover_bytes": sum(n for _, n in left),
            "root": reg.root, "budget_bytes": BUDGET,
            "share": music / total if total else 0, "groups": groups,
            "rounds": (groups + 1) // 2,
            "seconds_1mbit": total * 8 / 1e6, "seconds_10mbit": total * 8 / 1e7}
def tracks(reg):
    out = [{"id": seq, "title": name, "kind": "vanilla"} for seq, name in reg.vanilla]
    for row in reg.rows:
        f = row["fields"]
        out.append({"id": f["file"], "title": f["name"],
                    "kind": f.get("ext") or "m64", "category": f["family"],
                    "game": f.get("game") or "", "artist": row_artist(f),
                    "label": row_label(f), "imported": IMPORTED_MARK in row["comments"],
                    "venue": f.get("ext") in (None, "m64")})
    return out
def kb(n):
    return "%d KB" % (n // 1024)
def cmd_list(reg, args):
    rows = reg.rows
    if args.category:
        key = resolve_category(reg, args.category)
        rows = [r for r in rows if r["fields"]["family"] == key]
    if args.json:
        print(json.dumps([dict(r["fields"], artist=row_artist(r["fields"]),
                               size=os.path.getsize(reg.sound(r))
                               if os.path.exists(reg.sound(r)) else None)
                          for r in rows], indent=1, ensure_ascii=False))
        return 0
    print("%3s  %-30s %-4s %-9s %s" % ("#", "id", "kind", "category", "title / artist"))
    for n, r in enumerate(rows, 1):
        f = r["fields"]
        print("%3d  %-30s %-4s %-9s %s / %s" % (n, f["file"], f.get("ext") or "m64",
                                               f["family"], f["name"], row_artist(f)))
    print("%d track(s), order: %s, %d retired" % (len(rows), reg.order, len(reg.retired)))
    return 0
def cmd_category(reg, args):
    if args.what == "list":
        for cat in category_tree(reg):
            held = len(folder_tracks(reg, cat["key"])) if cat["key"] != GAMES else None
            print("%-12s %s%s" % (cat["key"], cat["label"], " (fixed)" if cat["fixed"]
                                  else "  - %d track(s)" % held))
            for f in cat["folders"]:
                print("  %-10s %s  - %d track(s)" % (f["key"], f["label"],
                                                     len(folder_tracks(reg, f["key"]))))
        return 0
    if args.what == "add":
        under = None
        if args.under:
            under = GAMES if args.under.lower() in (GAMES, GAMES_LABEL.lower()) else \
                resolve_category(reg, args.under)
        key = add_category(reg, args.name or args.key, under)
        print("added %s" % key)
        return 0
    if not args.key:
        raise MusicError("name the category (its key or its name)")
    key = GAMES if args.key == GAMES else resolve_category(reg, args.key)
    if args.what == "rename":
        print("renamed %s: %s" % (key, rename_category(reg, key, args.name)))
        return 0
    moved = delete_category(reg, key, args.move_to)
    print("deleted %s%s" % (key, (" - %d track(s) moved to %s" % (len(moved), args.move_to))
                            if moved else ""))
    return 0
def cmd_check(reg, args):
    found = check(reg)
    errors = [s for lvl, s in found if lvl == "error"]
    for s in errors:
        print("  error: " + s)
    m = meter(reg)
    over = m["wall_bytes"] >= HARD_WALL
    print("music %s of %s shipped in a release (%d%%), budget %s; a join is %d offset "
          "groups, about %ds on 1 Mbit, %ds on 10 Mbit"
          % (kb(m["music_bytes"]), kb(m["shipped_bytes"]), round(m["share"] * 100),
             kb(BUDGET), m["groups"], m["seconds_1mbit"], m["seconds_10mbit"]))
    if luaregion().is_release(reg.root):
        print("this release install as it is: %s; the folder %s"
              % (kb(m["dev_bytes"]), m["wall_line"]))
    else:
        print("the dev tree, comments and all: %s; the folder %s"
              % (kb(m["dev_bytes"]), m["wall_line"]))
    if over:
        print("  error: the mod is at the engine's %s wall - it would be "
              "disabled without a word" % kb(HARD_WALL))
    elif m["shipped_bytes"] > BUDGET:
        print("  note: over the %s download budget (reported, not refused)" % kb(BUDGET))
    if errors or over:
        print("music: %d problem(s)" % (len(errors) + int(over)))
        return 1
    print("music: %d track(s) green, order %s, %d retired"
          % (len(reg.rows), reg.order, len(reg.retired)))
    return 0
def selftest():
    if not os.path.isfile(os.path.join(REPO, "tests", "harness.lua.txt")):
        print("music: selftest skipped - it needs the dev tree's tests/ folder, "
              "which a release install does not have")
        return 0
    work = tempfile.mkdtemp(prefix="music-selftest-")
    fails = []
    def expect(cond, what):
        if not cond:
            fails.append(what)
    try:
        shutil.copyfile(os.path.join(REPO, MUSIC_LUA), os.path.join(work, MUSIC_LUA))
        os.makedirs(os.path.join(work, "tests"))
        shutil.copyfile(os.path.join(REPO, "tests", "harness.lua.txt"),
                        os.path.join(work, "tests", "harness.lua.txt"))
        shutil.copytree(os.path.join(REPO, SOUND_DIR), os.path.join(work, SOUND_DIR))
        for name in os.listdir(REPO):
            if name.endswith(".lua") and name != MUSIC_LUA:
                shutil.copyfile(os.path.join(REPO, name), os.path.join(work, name))
        reg = load(work)
        start = len(reg.rows)
        expect(reg.text() == open(os.path.join(REPO, MUSIC_LUA), encoding="utf-8").read(),
               "the registry does not round-trip byte for byte")
        expect(not [p for p in check(reg) if p[0] == "error"], "the shipped registry is red")
        fx = os.path.join(work, "fixtures")
        os.makedirs(fx)
        seq = os.path.join(fx, "Test Sequence.m64")
        with open(seq, "wb") as h:
            h.write(b"\xd3\x80\x00selftest-sequence")
        try:
            import_files(load(work), [seq], artist="Nobody")
            fails.append("a .m64 without --bank was taken")
        except MusicError:
            pass
        ids = import_files(load(work), [seq], artist="Nobody", game="Self Test",
                           bank=37, category="other")
        reg = load(work)
        expect(ids == ["test_sequence"] and len(reg.rows) == start + 1, "m64 import")
        row = reg.rows[reg.find("test_sequence")]["fields"]
        expect(row.get("artist") == "Nobody" and row["about"] == "" and row["bank"] == 37
               and row["name"] == "Test Sequence", "m64 row fields %r" % row)
        expect(os.path.isfile(os.path.join(work, SOUND_DIR, "test_sequence.m64")), "m64 file copied")
        try:
            import_files(load(work), [seq], artist="Nobody", bank=37)
            fails.append("a taken id was overwritten without --replace")
        except MusicError:
            pass
        rec = os.path.join(fx, "Loop Song.ogg")
        if ffmpeg():
            subprocess.run([ffmpeg(), "-hide_banner", "-loglevel", "error", "-y", "-f",
                            "lavfi", "-i", "sine=frequency=440:duration=2",
                            "-c:a", "libvorbis", rec], check=True)
            ids = import_files(load(work), [rec], artist="Nobody", loop="0.5:1.5")
            r = load(work)
            f = r.rows[r.find("loop_song")]["fields"]
            expect(f.get("ext") == "ogg" and f.get("loopFrom") == 22050
                   and f.get("loopTo") == 66150, "ogg import with loop %r" % f)
        else:
            with open(rec, "wb") as h:
                h.write(b"OggS\x00\x02" + b"\x00" * 22 + b"\x01vorbis"
                        + struct.pack("<IBI", 0, 2, 44100) + b"\x00" * 64)
            try:
                import_files(load(work), [rec], artist="Nobody")
                fails.append("a normalised import ran without ffmpeg")
            except MusicError as e:
                expect("ffmpeg is not installed" in str(e), "the missing-ffmpeg sentence")
            ids = import_files(load(work), [rec], artist="Nobody", normalise=False,
                               loop="0.5:1.5")
            r = load(work)
            f = r.rows[r.find("loop_song")]["fields"]
            expect(f.get("ext") == "ogg" and f.get("loopFrom") == 22050
                   and f.get("loopTo") == 66150, "ogg copy with loop %r" % f)
            wav = os.path.join(fx, "raw.wav")
            open(wav, "wb").write(b"RIFF")
            try:
                import_files(load(work), [wav], artist="Nobody")
                fails.append("a .wav was taken without ffmpeg")
            except MusicError:
                pass
        reg = load(work)
        edit(reg, "test_sequence", title="Zz Self Test", artist="Somebody", volume=90)
        r = load(work)
        f = r.rows[r.find("test_sequence")]["fields"]
        expect(f["name"] == "Zz Self Test" and f.get("artist") == "Somebody"
               and f["volume"] == 90, "edit %r" % f)
        expect(r.rows[-1]["fields"]["file"] == "test_sequence", "edit keeps title order")
        try:
            edit(load(work), "test_sequence", category="no such series")
            fails.append("an unknown category was taken")
        except MusicError:
            pass
        edit(load(work), "test_sequence", title="W" * 60)
        said = " | ".join(s for lvl, s in check(load(work)) if lvl == "note")
        expect("scrolls" in said, "a wide row is not noted as scrolling: " + said[:200])
        edit(load(work), "test_sequence", title="Zz Self Test")
        other = os.path.join(fx, "Fixture Overworld.m64")
        with open(other, "wb") as h:
            h.write(b"\xd3\x80\x00selftest-overworld")
        import_files(load(work), [other], artist="Nobody", bank=17, category="mario2d")
        reg = load(work)
        sort_rows(reg, "category")
        save(reg)
        r = load(work)
        expect(r.order == "category" and r.rows[0]["fields"]["family"] == "mario2d",
               "sort by category")
        move(load(work), "test_sequence", to=1)
        r = load(work)
        expect(r.order == "manual" and r.rows[0]["fields"]["file"] == "test_sequence",
               "move to the top")
        reg = load(work)
        sort_rows(reg, "title")
        save(reg)
        remove(load(work), "test_sequence", to="fixture_overworld")
        r = load(work)
        expect(r.retired.get("test_sequence") == "fixture_overworld"
               and not os.path.exists(os.path.join(work, SOUND_DIR, "test_sequence.m64")),
               "remove retires and deletes")
        third = os.path.join(fx, "Fixture Athletic.m64")
        with open(third, "wb") as h:
            h.write(b"\xd3\x80\x00selftest-athletic")
        import_files(load(work), [third], artist="Nobody", bank=17, category="mario2d")
        remove(load(work), "fixture_overworld")
        r = load(work)
        expect(r.retired.get("test_sequence") == "", "a retirement follows its target out")
        import_files(load(work), [seq], artist="Nobody", bank=37)
        expect("test_sequence" not in load(work).retired, "re-import un-retires")
        r = load(work)
        os.remove(os.path.join(work, SOUND_DIR, "test_sequence.m64"))
        shutil.copyfile(os.path.join(work, SOUND_DIR, "fixture_athletic.m64"),
                        os.path.join(work, SOUND_DIR, "stray.m64"))
        found = " | ".join(s for _, s in check(r))
        expect("missing file" in found and "unused file sound/stray.m64" in found
               and "duplicate file" in found, "check findings: " + found[:300])
        expect(len(tracks(r)) == len(r.rows) + len(r.vanilla) and len(r.vanilla) >= 20,
               "the picker list")
        with open(os.path.join(work, SOUND_DIR, "test_sequence.m64"), "wb") as h:
            h.write(b"\xd3\x80\x00selftest-sequence-again")
        os.remove(os.path.join(work, SOUND_DIR, "stray.m64"))
        r = load(work)
        cat = add_category(r, "Selftest Music")
        sub = add_category(load(work), "Selftest Calm", under=cat)
        move_to_category(load(work), ["fixture_athletic"], sub)
        lua = open(os.path.join(work, MUSIC_LUA), encoding="utf-8").read()
        expect('label = "Selftest Music"' in lua and 'under = "%s"' % cat in lua
               and 'family = "%s"' % sub in lua, "a category is not written for the game")
        rename_category(load(work), cat, "Selftest Tunes")
        expect(dict(load(work).categories).get(cat) == "Selftest Tunes", "rename")
        try:
            delete_category(load(work), cat)
            fails.append("a category holding a track was deleted")
        except MusicError:
            pass
        delete_category(load(work), cat, move_to="other")
        r = load(work)
        expect(cat not in r.family_keys() and sub not in r.family_keys()
               and r.rows[r.find("fixture_athletic")]["fields"]["family"] == "other",
               "delete with --move-to")
        expect(not [p for p in check(r) if p[0] == "error"], "red after the categories")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    for f in fails:
        print("  FAIL " + f)
    if fails:
        print("music selftest: %d failed" % len(fails))
        return 1
    print("music selftest: green (ffmpeg %s)" % ("present" if ffmpeg() else
                                                 "missing - recordings tested in copy mode"))
    return 0
def main(argv=None):
    p = argparse.ArgumentParser(prog="music.py", description="The music manager: import, list, edit, remove, move, sort and check the\n"
                                "tracks a host adds to this mod. Offline; nothing here talks to the game.")
    p.add_argument("--root", default=REPO, help="the mod's folder (default: this repo)")
    sub = p.add_subparsers(dest="cmd", required=True)
    def meta(sp):
        sp.add_argument("--title")
        sp.add_argument("--game")
        sp.add_argument("--artist")
        sp.add_argument("--about")
        sp.add_argument("--category")
        sp.add_argument("--volume", type=int)
        sp.add_argument("--bank", type=int)
        sp.add_argument("--loop", help="loop START:END in seconds (END <= 0 counts from the end)")
        sp.add_argument("--loop-frames", help="loop START:END in PCM frames")
    sp = sub.add_parser("list")
    sp.add_argument("--json", action="store_true")
    sp.add_argument("--category")
    sp = sub.add_parser("import")
    sp.add_argument("paths", nargs="+")
    meta(sp)
    sp.add_argument("--id")
    sp.add_argument("--no-normalise", action="store_true")
    sp.add_argument("--lufs", type=float, default=DEFAULT_LUFS)
    sp.add_argument("--replace", action="store_true")
    sp.add_argument("--quality", default=DEFAULT_QUALITY, choices=QUALITY_ORDER,
                    help="a recording's size: tiny 32, low 48, medium 64 (default), high 128 "
                         "kbit/s Ogg Vorbis, or original (the old fixed quality)")
    sp.add_argument("--mono", action="store_true", help="one channel instead of two")
    sp.add_argument("--mp3", default="smaller", choices=("smaller", "convert", "keep"),
                    help="an .mp3: kept as it is when smaller than its .ogg (default), "
                         "always converted, or always kept")
    sp.add_argument("--dry-run", action="store_true",
                    help="say what each file would become and the release size after, "
                         "and import nothing")
    sp = sub.add_parser("edit")
    sp.add_argument("id")
    meta(sp)
    sp.add_argument("--no-loop", action="store_true")
    sp = sub.add_parser("remove")
    sp.add_argument("id")
    sp.add_argument("--to")
    sp.add_argument("--keep-file", action="store_true")
    sp = sub.add_parser("move")
    sp.add_argument("id")
    sp.add_argument("--before")
    sp.add_argument("--after")
    sp.add_argument("--to", type=int)
    sp = sub.add_parser("sort")
    sp.add_argument("--by", required=True, choices=("title", "game", "category"))
    sp = sub.add_parser("tracks")
    sp.add_argument("--json", action="store_true")
    sp = sub.add_parser("category", help="list, add, rename or delete categories "
                        "and the folders in them")
    sp.add_argument("what", choices=("list", "add", "rename", "delete"))
    sp.add_argument("key", nargs="?", help="the category or folder (key or name)")
    sp.add_argument("--name", help="its name (add, rename)")
    sp.add_argument("--under", help="add a folder inside this category ('games' is "
                    "From other games)")
    sp.add_argument("--move-to", help="delete: where its tracks go")
    sub.add_parser("check")
    sub.add_parser("selftest")
    args = p.parse_args(argv)
    try:
        if args.cmd == "selftest":
            return selftest()
        if args.cmd != "check":
            for name, size in clean_leftovers(args.root):
                print("removed a half-written import: sound/%s (%s)" % (name, kb(size)),
                      file=sys.stderr)
        reg = load(args.root)
        if args.cmd == "list":
            return cmd_list(reg, args)
        if args.cmd == "check":
            return cmd_check(reg, args)
        if args.cmd == "tracks":
            rows = tracks(reg)
            if args.json:
                print(json.dumps(rows, indent=1, ensure_ascii=False))
            else:
                for t in rows:
                    print("%-34s %-7s %s" % (t["id"], t["kind"], t["title"]))
            return 0
        if args.cmd == "import":
            channels = 1 if args.mono else 2
            mp3 = {"smaller": "smaller", "convert": "never", "keep": "always"}[args.mp3]
            have = ffmpeg() is not None
            plan = plan_import(reg, args.paths, normalise=not args.no_normalise and have,
                               quality=args.quality, channels=channels, mp3_as_is=mp3)
            for line in plan_lines(plan):
                print(line)
            if args.dry_run:
                return 0
            skipped = []
            ids = import_files(reg, args.paths, title=args.title, game=args.game,
                               artist=args.artist, about=args.about,
                               category=args.category, bank=args.bank,
                               volume=args.volume, loop=args.loop,
                               loop_frames_=args.loop_frames, ident=args.id,
                               normalise=not args.no_normalise, lufs=args.lufs,
                               replace=args.replace, quality=args.quality,
                               channels=channels, mp3_as_is=mp3, skipped=skipped,
                               release_bytes=plan["release_now"])
            print("imported: " + (", ".join(ids) if ids else "nothing"))
            for src, why in skipped:
                print("not imported: %s - %s" % (os.path.basename(src), why))
            print("the mod's release is now %s; the folder %s"
                  % (mb(shipped_bytes(reg.root)), wall_line(wall_bytes(reg.root))))
            return 0 if ids else 1
        if args.cmd == "edit":
            f = edit(reg, args.id, title=args.title, game=args.game, artist=args.artist,
                     about=args.about, category=args.category, volume=args.volume,
                     bank=args.bank, loop=args.loop, loop_frames_=args.loop_frames,
                     no_loop=args.no_loop)
            print("edited %s: %s" % (args.id, f["name"]))
            return 0
        if args.cmd == "remove":
            remove(reg, args.id, to=args.to, keep_file=args.keep_file)
            print("removed %s%s" % (args.id, (" (saved picks now play %s)" % args.to)
                                    if args.to else " (saved picks now play the level's own music)"))
            return 0
        if args.cmd == "move":
            print(move(reg, args.id, before=args.before, after=args.after, to=args.to))
            return 0
        if args.cmd == "sort":
            sort_rows(reg, args.by)
            save(reg)
            print("sorted by %s" % args.by)
            return 0
        if args.cmd == "category":
            return cmd_category(reg, args)
    except MusicError as e:
        print("music.py: " + str(e), file=sys.stderr)
        return 1
    return 2
if __name__ == "__main__":
    sys.exit(main())
