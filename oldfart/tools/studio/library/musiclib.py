import copy
import json
import os
import re
import shutil
import subprocess
from . import tool
FFMPEG_INSTALL = "sudo pacman -S ffmpeg"
PLAYABLE = (".ogg", ".mp3", ".wav", ".flac")
SORTS = ("title", "game", "category")
def music():
    return tool("music")
def target(ed=None, remembered=None):
    from studio.editor import modfolder
    if remembered is None and ed is not None and hasattr(ed, "settings_get"):
        remembered = ed.settings_get("export.mod")
    found = modfolder.choose(remembered)
    if not found or os.path.realpath(found) == os.path.realpath(modfolder.REPO):
        return None
    return found
def load(root=None, clean=False):
    m = music()
    return m.load(root or m.REPO, clean=clean)
def wall(root):
    m = music()
    n = m.wall_bytes(root)
    return n, m.wall_line(n)
def ffmpeg_status():
    if shutil.which("ffmpeg"):
        return True, "ffmpeg is installed: recordings are converted to .ogg and made " \
                     "equally loud."
    return False, ("ffmpeg is not installed, so a recording cannot be converted or made "
                   "equally loud. Install it on CachyOS with:  %s  - until then an .ogg or "
                   ".mp3 goes in as it is, and a .m64 sequence always works." % FFMPEG_INSTALL)
def rows(reg):
    m = music()
    out = []
    for n, row in enumerate(reg.rows):
        f = row["fields"]
        path = reg.sound(row)
        ext = f.get("ext") or "m64"
        out.append({"id": f["file"], "title": f["name"], "game": f.get("game") or "",
                    "artist": m.row_artist(f) or "", "about": f.get("about") or "",
                    "label": m.row_label(f),
                    "imported": m.IMPORTED_MARK in row["comments"],
                    "category": f["family"], "kind": ext, "bank": f.get("bank"),
                    "volume": f.get("volume"), "loop": (f.get("loopFrom"), f.get("loopTo"))
                    if "loopFrom" in f else None,
                    "bytes": os.path.getsize(path) if os.path.isfile(path) else 0,
                    "path": path, "playable": ("." + ext) in PLAYABLE, "position": n + 1,
                    "venue": ext == "m64"})
    return out
def categories(reg):
    m = music()
    out = []
    for cat in m.category_tree(reg):
        if not cat["fixed"]:
            out.append((cat["key"], cat["label"]))
        out += [(f["key"], "%s / %s" % (cat["label"], f["label"])) for f in cat["folders"]]
    return out
def folder_tree(reg):
    return music().category_tree(reg)
def default_category(reg):
    return music().default_category(reg)
def add_category(reg, label, under=None):
    return music().add_category(reg, label, under)
def rename_category(reg, key, label):
    return music().rename_category(reg, key, label)
def delete_category(reg, key, move_to=None):
    return music().delete_category(reg, key, move_to)
def move_to_category(reg, idents, key):
    return music().move_to_category(reg, idents, key)
def folder_tracks(reg, key):
    return music().folder_tracks(reg, key)
def search(items, text):
    from studio.editor.palette import _fold
    words = [_fold(w) for w in (text or "").split() if w]
    return [r for r in items if all(w in _fold(" ".join(
        [r["title"], r["game"], r["artist"], r["category"], r["id"]])) for w in words)]
def importable(paths):
    m = music()
    out = []
    for path in paths:
        if os.path.isdir(path):
            for dirpath, _, names in os.walk(path):
                for name in sorted(names):
                    if os.path.splitext(name)[1].lower() in m.IMPORT_AUDIO + (".m64",):
                        out.append(os.path.join(dirpath, name))
        elif os.path.isfile(path):
            out.append(path)
    return out
def file_filter():
    kinds = " ".join("*" + e for e in music().IMPORT_AUDIO + (".m64",))
    return "Music (%s);;All files (*)" % kinds
def needs_ffmpeg(paths):
    m = music()
    return [p for p in importable(paths)
            if os.path.splitext(p)[1].lower() not in m.COPYABLE + (".m64",)]
def import_paths(reg, paths, **fields):
    m = music()
    notes = []
    have, _ = ffmpeg_status()
    if not have:
        fields["normalise"] = False
        blocked = needs_ffmpeg(paths)
        if blocked:
            raise m.MusicError("%s need ffmpeg to be converted. Install it on CachyOS "
                               "with:  %s" % (", ".join(os.path.basename(p) for p in blocked),
                                              FFMPEG_INSTALL))
        if any(os.path.splitext(p)[1].lower() in m.COPYABLE for p in importable(paths)):
            notes.append("taken as it is (no ffmpeg to make it equally loud: %s)"
                         % FFMPEG_INSTALL)
    ids = m.import_files(reg, paths, **fields)
    return ids, notes
TAG_FIELDS = ("title", "artist", "game")
FACT_FIELDS = ("album", "genre", "year", "bpm")
ALBUM_NOISE = re.compile(
    r"\s*[\(\[]?\b(original\s+(game\s+)?soundtrack|official\s+soundtrack|soundtrack|"
    r"o\.?s\.?t\.?|ost|music\s+collection)\b[\)\]]?\s*$", re.I)
def _clean(text):
    if isinstance(text, (list, tuple)):
        text = text[0] if text else ""
    text = str(text or "").replace("\x00", " ").strip()
    return re.sub(r"\s+", " ", text)
def game_from_album(album):
    album = _clean(album)
    for _ in range(2):
        album = ALBUM_NOISE.sub("", album).strip(" -:")
    return album
def _pick(tags):
    get = lambda *keys: next((_clean(tags[k]) for k in keys if _clean(tags.get(k))), "")
    album = get("album")
    year = get("date", "year", "tdrc", "tyer", "originaldate")
    year = (re.search(r"\b(1[89]\d\d|20\d\d)\b", year) or [""])[0] if year else ""
    bpm = get("bpm", "tbpm", "tempo")
    bpm = str(int(round(float(bpm)))) if re.fullmatch(r"\d+(\.\d+)?", bpm or "") else ""
    return {"title": get("title"),
            "artist": get("artist", "album_artist", "albumartist", "album artist",
                          "composer", "performer"),
            "game": game_from_album(album) if ALBUM_NOISE.search(album) else "",
            "album": album, "genre": get("genre"), "year": year, "bpm": bpm}
def tags_mutagen(path):
    try:
        import mutagen
    except ImportError:
        return None
    try:
        f = mutagen.File(path, easy=True)
    except Exception:
        return {}
    if f is None or not f.tags:
        return {}
    return _pick({str(k).lower(): v for k, v in f.tags.items()})
def tags_ffprobe(path):
    exe = shutil.which("ffprobe")
    if not exe:
        return None
    try:
        out = subprocess.run([exe, "-v", "quiet", "-print_format", "json", "-show_format",
                              "-show_streams", path], capture_output=True, text=True,
                             timeout=20)
        data = json.loads(out.stdout or "{}")
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}
    tags = {}
    for stream in data.get("streams") or []:
        tags.update({k.lower(): v for k, v in (stream.get("tags") or {}).items()})
    tags.update({k.lower(): v for k, v in ((data.get("format") or {}).get("tags")
                                          or {}).items()})
    return _pick(tags)
def _syncsafe(b):
    return (b[0] << 21) | (b[1] << 14) | (b[2] << 7) | b[3]
def _id3_text(data):
    if not data:
        return ""
    enc, raw = data[0], data[1:]
    try:
        if enc == 0:
            return raw.decode("latin-1")
        if enc == 1:
            return raw.decode("utf-16")
        if enc == 2:
            return raw.decode("utf-16-be")
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("latin-1", "replace")
ID3_FRAMES = {"TIT2": "title", "TPE1": "artist", "TPE2": "album_artist", "TALB": "album",
              "TCOM": "composer", "TT2": "title", "TP1": "artist", "TAL": "album",
              "TCON": "genre", "TCO": "genre", "TYER": "year", "TDRC": "date",
              "TYE": "year", "TBPM": "bpm", "TBP": "bpm"}
def _id3(head, tail):
    tags = {}
    if head[:3] == b"ID3" and len(head) >= 10:
        major, size = head[3], _syncsafe(head[6:10])
        body = head[10:10 + size]
        i = 0
        if major == 2:
            while i + 6 <= len(body) and body[i:i + 3] != b"\x00\x00\x00":
                fid, n = body[i:i + 3].decode("latin-1"), int.from_bytes(body[i + 3:i + 6], "big")
                if fid in ID3_FRAMES:
                    tags.setdefault(ID3_FRAMES[fid], _id3_text(body[i + 6:i + 6 + n]))
                i += 6 + n
        else:
            while i + 10 <= len(body) and body[i:i + 4] != b"\x00\x00\x00\x00":
                fid = body[i:i + 4].decode("latin-1", "replace")
                raw = body[i + 4:i + 8]
                n = _syncsafe(raw) if major >= 4 else int.from_bytes(raw, "big")
                if fid in ID3_FRAMES:
                    tags.setdefault(ID3_FRAMES[fid], _id3_text(body[i + 10:i + 10 + n]))
                i += 10 + n
    if not tags and tail[-128:-125] == b"TAG":
        v1 = tail[-128:]
        for key, a, b in (("title", 3, 33), ("artist", 33, 63), ("album", 63, 93)):
            tags[key] = v1[a:b].split(b"\x00")[0].decode("latin-1").strip()
    return tags
def _vorbis_comments(data, at):
    tags = {}
    try:
        n = int.from_bytes(data[at:at + 4], "little")
        at += 4 + n
        count = int.from_bytes(data[at:at + 4], "little")
        at += 4
        for _ in range(min(count, 512)):
            n = int.from_bytes(data[at:at + 4], "little")
            line = data[at + 4:at + 4 + n].decode("utf-8", "replace")
            at += 4 + n
            if "=" in line:
                k, v = line.split("=", 1)
                tags.setdefault(k.strip().lower(), v)
    except (IndexError, ValueError):
        pass
    return tags
def _flac(data):
    if data[:4] != b"fLaC":
        return {}
    at = 4
    while at + 4 <= len(data):
        head = data[at]
        n = int.from_bytes(data[at + 1:at + 4], "big")
        if head & 0x7F == 4:
            return _vorbis_comments(data, at + 4)
        if head & 0x80:
            break
        at += 4 + n
    return {}
def _ogg(data):
    if data[:4] != b"OggS":
        return {}
    for marker in (b"\x03vorbis", b"OpusTags"):
        at = data.find(marker)
        if at >= 0:
            return _vorbis_comments(data, at + len(marker))
    return {}
MP4_TAGS = {b"\xa9nam": "title", b"\xa9ART": "artist", b"aART": "album_artist",
            b"\xa9alb": "album", b"\xa9gen": "genre", b"\xa9day": "date",
            b"\xa9wrt": "composer", b"tmpo": "bpm"}
def _mp4(path):
    m = music()
    moov = m.mp4_moov(path)
    if not moov:
        return {}
    tags = {}
    def walk(a, b):
        for kind, x, y in m.mp4_boxes(moov, a, b):
            if kind == b"meta":
                walk(x + 4, y)
            elif kind in (b"udta", b"ilst"):
                walk(x, y)
            elif kind in MP4_TAGS:
                for sub, p, q in m.mp4_boxes(moov, x, y):
                    if sub != b"data" or q - p < 8:
                        continue
                    flavour, value = int.from_bytes(moov[p:p + 4], "big") & 0xFFFFFF, \
                        moov[p + 8:q]
                    if MP4_TAGS[kind] == "bpm" or flavour == 21:
                        text = str(int.from_bytes(value, "big")) if value else ""
                    else:
                        text = value.decode("utf-8", "replace")
                    tags.setdefault(MP4_TAGS[kind], text)
    walk(8, len(moov))
    return tags
def tags_builtin(path):
    try:
        with open(path, "rb") as handle:
            head = handle.read(256 * 1024)
            try:
                handle.seek(-128, os.SEEK_END)
                tail = handle.read(128)
            except OSError:
                tail = b""
    except OSError:
        return {}
    for reader in (lambda: _id3(head, tail), lambda: _flac(head), lambda: _ogg(head),
                   lambda: _mp4(path) if head[4:8] == b"ftyp" else {}):
        tags = reader()
        if tags:
            return _pick(tags)
    return {}
TRACK_NO = re.compile(r"^\s*(\(?\d{1,3}\)?|\d{1,2}-\d{1,3})\s*[-._)]*\s+")
def from_filename(path):
    stem = os.path.splitext(os.path.basename(path))[0]
    stem = re.sub(r"_+", " ", stem).strip()
    stem = TRACK_NO.sub("", stem).strip()
    parts = [p.strip() for p in re.split(r"\s+[-–—]\s+", stem) if p.strip()]
    if len(parts) >= 3:
        return {"artist": parts[0], "game": parts[1], "title": " - ".join(parts[2:])}
    if len(parts) == 2:
        return {"artist": parts[0], "game": "", "title": parts[1]}
    if stem.islower():
        stem = " ".join(w[:1].upper() + w[1:] for w in stem.split())
    return {"artist": "", "game": "", "title": stem}
def read_tags(path, readers=None):
    readers = readers or (("mutagen", tags_mutagen), ("ffprobe", tags_ffprobe),
                          ("tags", tags_builtin))
    got, source = {}, "file name"
    for name, fn in readers:
        tags = fn(path)
        if tags is None:
            continue
        if any(tags.get(k) for k in TAG_FIELDS):
            got, source = tags, name
            break
    named = from_filename(path)
    out = {k: got.get(k) or "" for k in TAG_FIELDS + FACT_FIELDS}
    if not out["title"]:
        out["title"] = named["title"]
    if not got:
        out["artist"] = out["artist"] or named["artist"]
        out["game"] = out["game"] or named["game"]
    out["source"] = source
    return out
def folder_artist(paths, tracks=None):
    from collections import Counter
    tracks = tracks if tracks is not None else [read_tags(p) for p in paths]
    tracks = [t if isinstance(t, dict) else vars(t) for t in tracks]
    named = Counter(t["artist"] for t in tracks if t.get("artist")
                    and t.get("source") != "file name")
    if named:
        return named.most_common(1)[0][0]
    folders = {os.path.basename(os.path.dirname(os.path.abspath(p))) for p in paths}
    if len(folders) == 1:
        name = folders.pop().replace("_", " ")
        parts = [s.strip() for s in re.split(r"\s+[-–—]\s+", name)]
        if len(parts) >= 2 and parts[0]:
            return parts[0]
    return ""
def genre_word(genre):
    m = re.fullmatch(r"\(?(\d{1,3})\)?", genre or "")
    if m:
        n = int(m.group(1))
        return ID3_GENRES[n] if n < len(ID3_GENRES) else ""
    return re.sub(r"^\(\d+\)", "", genre or "").strip()
ID3_GENRES = ("Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge",
              "Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R&B", "Rap",
              "Reggae", "Rock", "Techno", "Industrial", "Alternative", "Ska", "Death Metal",
              "Pranks", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal",
              "Jazz+Funk", "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House",
              "Game", "Sound Clip", "Gospel", "Noise", "Alternative Rock", "Bass", "Soul",
              "Punk", "Space", "Meditative", "Instrumental Pop", "Instrumental Rock",
              "Ethnic", "Gothic", "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk",
              "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40",
              "Christian Rap", "Pop/Funk", "Jungle", "Native American", "Cabaret", "New Wave",
              "Psychedelic", "Rave", "Showtunes", "Trailer", "Lo-Fi", "Tribal", "Acid Punk",
              "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock")
def facts(path, tags=None, seconds=None):
    tags = tags or {}
    if seconds is None:
        seconds = music().duration(path)
    parts = []
    if seconds and seconds >= 1:
        parts.append("%d:%02d" % divmod(int(round(seconds)), 60))
    extra = []
    if tags.get("bpm"):
        extra.append("%s BPM" % tags["bpm"])
    genre = genre_word(tags.get("genre") or "")
    if genre and tags.get("year"):
        extra.append("%s, %s" % (genre, tags["year"]))
    elif genre or tags.get("year"):
        extra.append(genre or tags["year"])
    if len(extra) < 2 and tags.get("album") and tags.get("album") != tags.get("game"):
        extra.append("from the album %s" % tags["album"])
    return " - ".join(parts + extra[:2]).replace('"', "'")
class Track:
    def __init__(self, path, tags=None):
        self.path = path
        tags = tags or read_tags(path)
        self.title = tags.get("title") or ""
        self.artist = tags.get("artist") or ""
        self.game = tags.get("game") or ""
        self.source = tags.get("source") or "file name"
        self.seconds = music().duration(path) if not path.lower().endswith(".m64") else None
        self.problem = decode_problem(path)
        self.about = facts(path, tags, self.seconds) if self.seconds or any(
            tags.get(k) for k in FACT_FIELDS) else ""
    def fields(self, folder_artist="", folder_game=""):
        return {"title": self.title.strip() or music().nice_title(
                    os.path.splitext(os.path.basename(self.path))[0]),
                "artist": self.artist.strip() or folder_artist.strip(),
                "game": self.game.strip() or folder_game.strip() or None,
                "about": (self.about or "").strip()}
    def label(self, folder_artist="", folder_game=""):
        f = self.fields(folder_artist, folder_game)
        return music().row_label({"name": f["title"], "artist": f["artist"],
                                  "game": f["game"]})
def row_width(text):
    return music().name_width(text)
def scrolls(text):
    return row_width(text) > music().ROW_WIDTH
def decode_problem(path):
    m = music()
    ext = os.path.splitext(path)[1].lower()
    if ext == ".m64":
        return None
    if ext not in m.IMPORT_AUDIO:
        return ("%s cannot be imported: .%s is not a kind of audio the import knows (%s)"
                % (os.path.basename(path), ext.lstrip(".") or "(no ending)", m.IMPORT_WORDS))
    return m.decode_problem(path)
def plan_tracks(paths, readers=None):
    return [Track(p, read_tags(p, readers)) for p in importable(paths)]
def missing_credit(tracks, folder_artist=""):
    return [t for t in tracks if not t.fields(folder_artist)["artist"]]
def import_tracks(reg, tracks, folder_artist="", folder_game="", **common):
    ids, notes = [], []
    unreadable = [t for t in tracks if getattr(t, "problem", None)]
    notes += [t.problem for t in unreadable]
    tracks = [t for t in tracks if not getattr(t, "problem", None)]
    if not tracks:
        return ids, notes
    lacking = missing_credit(tracks, folder_artist)
    if lacking:
        raise music().MusicError("%s name no artist - give the folder's artist, or one per "
                                 "track" % ", ".join(os.path.basename(t.path)
                                                     for t in lacking[:6]))
    m = music()
    running = m.wall_bytes(reg.root)
    for t in tracks:
        f = t.fields(folder_artist, folder_game)
        try:
            got, said = import_paths(reg, [t.path], title=f["title"], artist=f["artist"],
                                     game=f["game"], about=f["about"],
                                     release_bytes=running, **common)
            running = m.wall_bytes(reg.root)
        except music().MusicError as why:
            name, why = os.path.basename(t.path), str(why)
            notes.append(why if why.startswith(name) else "%s: %s" % (name, why))
            continue
        ids += got
        notes += [n for n in said if n not in notes]
    return ids, notes
def plan(reg, tracks, quality=None, channels=2, mp3_as_is="smaller", release_bytes=None):
    have, _ = ffmpeg_status()
    return music().plan_import(reg, [t.path for t in tracks], normalise=have,
                               quality=quality, channels=channels, mp3_as_is=mp3_as_is,
                               have_ffmpeg=have, release_bytes=release_bytes)
def qualities():
    m = music()
    out = []
    for key in m.QUALITY_ORDER:
        kbps = m.QUALITIES[key]
        label = ("%s - %d kbit/s, %.1f MB for 8 minutes" % (key, kbps, kbps * 60.0 / 1000)
                 if kbps else "original - the old fixed quality, about 128 kbit/s")
        out.append((key, label + (" (default)" if key == m.DEFAULT_QUALITY else "")))
    out.sort(key=lambda kv: kv[0] != m.DEFAULT_QUALITY)
    return out
CATEGORY_LABELS = (("vanilla", "Vanilla music (your ROM)"), ("mod", "The mod's music"),
                   ("imported", "Imported"))
def category_of(row):
    if row.get("vanilla") is not None:
        return "vanilla"
    return "imported" if row.get("imported") else "mod"
def group_of(row):
    return (row.get("game") or "").strip() or (row.get("artist") or "").strip() or "Unknown"
def tree(rows, folders=None, keep_empty=True):
    out = []
    vanilla = [r for r in rows if category_of(r) == "vanilla"]
    groups = {}
    for r in vanilla:
        groups.setdefault(group_of(r), []).append(r)
    out.append({"fold": "vanilla", "label": dict(CATEGORY_LABELS)["vanilla"], "folder": None,
                "rows": [], "children": [
                    {"fold": "vanilla/%s" % g, "label": g, "folder": None, "rows": rs,
                     "children": []}
                    for g, rs in sorted(groups.items(), key=lambda kv: kv[0].lower())]})
    mod = [r for r in rows if category_of(r) != "vanilla"]
    if folders is None:
        folders = [{"key": "games", "label": "From other games", "fixed": True,
                    "folders": [{"key": "other", "label": "Other games"}]}]
    known = {c["key"] for c in folders} | {f["key"] for c in folders for f in c["folders"]}
    fallback = "other" if "other" in known else None
    by = {}
    for r in mod:
        key = r.get("category") if r.get("category") in known else fallback
        by.setdefault(key, []).append(r)
    for cat in folders:
        kids = [{"fold": "cat:%s/%s" % (cat["key"], f["key"]), "label": f["label"],
                 "folder": f["key"], "rows": by.get(f["key"], []), "children": []}
                for f in cat["folders"]]
        node = {"fold": "cat:%s" % cat["key"], "label": cat["label"], "folder": cat["key"],
                "fixed": cat.get("fixed", False),
                "rows": [] if cat.get("fixed") else by.get(cat["key"], []),
                "children": [k for k in kids if keep_empty or k["rows"]]}
        if keep_empty or node["rows"] or node["children"]:
            out.append(node)
    return out
def count_rows(node):
    return len(node["rows"]) + sum(count_rows(k) for k in node["children"])
def edit(reg, ident, **fields):
    return music().edit(reg, ident, **fields)
def remove(reg, ident, to=None, keep_file=False):
    return music().remove(reg, ident, to=to, keep_file=keep_file)
def move(reg, ident, before=None, after=None, to=None):
    return music().move(reg, ident, before=before, after=after, to=to)
def drop_order(ids, moved, row):
    rest = [i for i in ids if i != moved]
    row = max(0, min(row, len(ids)))
    if moved in ids and ids.index(moved) < row:
        row -= 1
    if row >= len(rest):
        return None, rest[-1] if rest else None
    return rest[row], None
def sort(reg, by):
    m = music()
    m.sort_rows(reg, by)
    m.save(reg)
def problems(reg):
    return music().check(reg)
def meter(reg):
    return music().meter(reg)
def venue_tracks():
    from studio.editor import engine
    return engine.music_tracks()
def map_music(doc):
    asked = (doc.brief or {}).get("music") or "auto"
    plays = ((doc.rest.get("look") or {}).get("music")) or None
    return asked, plays
def set_map_music(doc, key):
    from studio.editor import ops
    from studio.editor.commands import Change
    auto = key in (None, "", "auto")
    a = ops.set_brief(doc, {"music": None if auto else key}, "Music")
    steps = list(a.steps)
    if not auto:
        look = copy.deepcopy(doc.rest.get("look") or {})
        if look.get("music") != key:
            look["music"] = key
            b = ops.set_rest(doc, "look", look, "Music")
            steps += b.steps
    return Change("Music: %s" % ("the theme's" if auto else key), steps, hand=False)
def map_playlist(doc):
    got = (doc.rest.get("look") or {}).get("playlist") or []
    return [str(k) for k in got if isinstance(k, str) and k and not k.startswith("SEQ_")]
def set_map_playlist(doc, keys):
    from studio.editor import ops
    from studio.editor.commands import Change
    clean = []
    for k in keys or []:
        if isinstance(k, str) and k and not k.startswith("SEQ_") and k not in clean:
            clean.append(k)
    look = copy.deepcopy(doc.rest.get("look") or {})
    if (look.get("playlist") or []) == clean:
        return None
    if clean:
        look["playlist"] = clean
    else:
        look.pop("playlist", None)
    b = ops.set_rest(doc, "look", look, "Music to take along")
    return Change("Music to take along: %d" % len(clean), list(b.steps), hand=False)
def toggle_take_along(doc, key):
    now = map_playlist(doc)
    on = key not in now
    keys = now + [key] if on else [k for k in now if k != key]
    return set_map_playlist(doc, keys), on
HINT_NO_MULTIMEDIA = ("Sound preview needs Qt's multimedia module, which this Qt does not have. "
                      "On CachyOS: sudo pacman -S pyside6 (the full package - PySide6-Essentials "
                      "has no multimedia), or in Oldfart Studio's venv: pip install PySide6-Addons.")
HINT_NO_DEVICE = ("No sound output was found. Plug in or switch on a speaker or "
                  "headphones (and check the system's sound settings), then press Check "
                  "audio.")
def audio_status(multimedia=None):
    if multimedia is None:
        try:
            from PySide6 import QtMultimedia as multimedia
        except Exception:
            return False, HINT_NO_MULTIMEDIA, []
    try:
        outputs = list(multimedia.QMediaDevices.audioOutputs())
    except Exception as why:
        return False, "%s (%s)" % (HINT_NO_DEVICE, why.__class__.__name__), []
    names = [d.description() for d in outputs]
    if not names:
        return False, HINT_NO_DEVICE, []
    try:
        default = multimedia.QMediaDevices.defaultAudioOutput().description()
    except Exception:
        default = names[0]
    return True, "Sound plays on %s" % (default or names[0]), names
def player():
    try:
        from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer
        return (QMediaPlayer, QAudioOutput), None
    except Exception as why:
        return None, ("Preview needs Qt's multimedia module, which this Qt does not have "
                      "(%s). On CachyOS: sudo pacman -S pyside6 (the full package), or "
                      "pip install PySide6-Addons in Oldfart Studio's venv." % why.__class__.__name__)
LISTS = (("vanilla", "Vanilla music (your ROM)"), ("mod", "The mod's music"))
VANILLA_ARTIST = "Koji Kondo"
def rom_status(chosen=None):
    from . import m64, romaudio
    path = romaudio.find_rom(extra=chosen)
    if not path:
        return None, romaudio.where_to_look()
    try:
        rom = m64.open_rom(path)
        sound = rom.sound()
    except (OSError, romaudio.RomError) as why:
        return None, "Your ROM (%s) could not be read: %s" % (path, why)
    kind = ("the vanilla %s game" % rom.region.upper()) if rom.vanilla else \
        "not a vanilla ROM Coop DX knows - its music is read as it is"
    return rom, ("Real instruments from your ROM: %s (%s, %d sequences, %d banks). Read "
                 "only, never copied." % (path, kind, len(sound.seqs), len(sound.ctl)))
def vanilla_rows(rom=None):
    from . import m64
    out = []
    sound = rom.sound() if rom is not None else None
    for n, (index, seq, title) in enumerate(m64.VANILLA):
        if sound is not None and index >= len(sound.seqs):
            continue
        banks = sound.banks_of(index) if sound is not None else []
        out.append({"id": seq, "title": title, "game": "Super Mario 64",
                    "artist": VANILLA_ARTIST, "about": "%s (sequence 0x%02X), read from your ROM"
                    % (seq, index), "category": "vanilla", "kind": "m64",
                    "bank": banks[0] if banks else None, "banks": banks, "volume": None,
                    "loop": None, "bytes": len(sound.sequence(index)) if sound else 0,
                    "path": None, "playable": sound is not None, "position": n + 1,
                    "venue": True, "vanilla": index})
    return out
def preview(row, out_path, rom=None, seconds=60):
    from . import m64
    if row.get("vanilla") is not None:
        return m64.preview(out_path, vanilla=row["vanilla"], rom=rom, seconds=seconds)
    return m64.preview(out_path, path=row["path"], bank=row.get("bank"), rom=rom,
                       seconds=seconds)
