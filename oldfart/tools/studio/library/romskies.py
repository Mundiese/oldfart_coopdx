import hashlib
import os
import struct
FILES = {
    "BACKGROUND_OCEAN_SKY": "water",
    "BACKGROUND_FLAMING_SKY": "bitfs",
    "BACKGROUND_UNDERWATER_CITY": "wdw",
    "BACKGROUND_BELOW_CLOUDS": "cloud_floor",
    "BACKGROUND_SNOW_MOUNTAINS": "ccm",
    "BACKGROUND_DESERT": "ssl",
    "BACKGROUND_HAUNTED": "bbh",
    "BACKGROUND_GREEN_SKY": "bidw",
    "BACKGROUND_ABOVE_CLOUDS": "clouds",
    "BACKGROUND_PURPLE_SKY": "bits",
}
ALIASES = {"bidw": ("bidw", "bitdw")}
ROM_ORDER = ("water", "ccm", "clouds", "bitfs", "wdw", "cloud_floor", "ssl", "bbh", "bidw",
             "bits")
US_PLACES = {"water": 2803376, "ccm": 2854672, "clouds": 2913232, "bitfs": 2949184,
             "wdw": 2974960, "cloud_floor": 3045504, "ssl": 3085536, "bbh": 3125680,
             "bidw": 3153104, "bits": 3198656}
TILE, TILE_BYTES, DRAWN = 32, 32 * 32 * 2, 31
ROWS, COLS, ROW_PTRS = 8, 8, 10
PTRLIST = ROWS * ROW_PTRS * 4
SEGMENT = 0x0A000000
SIDE = COLS * DRAWN
PREVIEW = (192, 120)
ENV_DECOMP = "OF_DECOMP"
CACHE_VERSION = "2"
_memo = {}
class SkyError(ValueError):
    pass
def decomp_skyboxes(env=None):
    env = os.environ if env is None else env
    root = env.get(ENV_DECOMP)
    if not root:
        return None
    for base in (root, os.path.dirname(os.path.abspath(root))):
        folder = os.path.join(base, "textures", "skyboxes")
        if os.path.isfile(os.path.join(folder, "water.png")):
            return folder
    return None
def source(rom=None, env=None, home=None, platform=None):
    folder = decomp_skyboxes(env)
    if folder:
        return ("decomp", folder)
    from . import romaudio
    path = romaudio.find_rom(env=env, home=home, platform=platform, extra=rom)
    if path:
        return ("rom", path)
    return None
def cache_dir(env=None):
    env = os.environ if env is None else env
    base = env.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(base, "oldfart-studio", "skies")
def _source_key(src):
    kind, path = src
    if kind == "rom":
        st = os.stat(path)
        sig = "%s|%d|%d" % (os.path.abspath(path), st.st_size, int(st.st_mtime))
    else:
        sig = os.path.abspath(path) + "|" + "|".join(
            "%s:%d" % (n, int(os.stat(os.path.join(path, n)).st_mtime))
            for n in sorted(os.listdir(path)) if n.endswith(".png"))
    return hashlib.sha1((CACHE_VERSION + kind + sig).encode("utf-8")).hexdigest()[:16]
def mio0(data, at=0):
    if data[at:at + 4] != b"MIO0":
        raise SkyError("no MIO0 block at 0x%X" % at)
    size, comp, plain = struct.unpack(">III", data[at + 4:at + 16])
    out = bytearray()
    bits_at, comp_at, plain_at = at + 16, at + comp, at + plain
    word, left = 0, 0
    while len(out) < size:
        if left == 0:
            word = struct.unpack(">I", data[bits_at:bits_at + 4])[0]
            bits_at += 4
            left = 32
        left -= 1
        if word >> left & 1:
            out.append(data[plain_at])
            plain_at += 1
        else:
            v = data[comp_at] << 8 | data[comp_at + 1]
            comp_at += 2
            length, back = (v >> 12) + 3, (v & 0xFFF) + 1
            start = len(out) - back
            if start < 0:
                raise SkyError("MIO0 reaches before its start")
            for i in range(length):
                out.append(out[start + i])
    return bytes(out[:size])
def _is_skybox(raw):
    if len(raw) < PTRLIST + TILE_BYTES or (len(raw) - PTRLIST) % TILE_BYTES:
        return False
    tiles = (len(raw) - PTRLIST) // TILE_BYTES
    for (p,) in struct.iter_unpack(">I", raw[-PTRLIST:]):
        off = p - SEGMENT
        if off < 0 or off % TILE_BYTES or off // TILE_BYTES >= tiles:
            return False
    return True
def _header_size(data, at):
    if data[at:at + 4] != b"MIO0":
        return None
    return struct.unpack(">I", data[at + 4:at + 8])[0]
def rom_skyboxes(data):
    out = {}
    if all(_header_size(data, at) for at in US_PLACES.values()):
        for name, at in US_PLACES.items():
            raw = mio0(data, at)
            if _is_skybox(raw):
                out[name] = raw
        if len(out) == len(US_PLACES):
            return out
    found = []
    at = data.find(b"MIO0")
    while at >= 0:
        size = _header_size(data, at)
        if size and PTRLIST + TILE_BYTES <= size <= PTRLIST + ROWS * COLS * TILE_BYTES \
                and (size - PTRLIST) % TILE_BYTES == 0:
            try:
                raw = mio0(data, at)
            except (SkyError, IndexError, struct.error):
                raw = b""
            if _is_skybox(raw):
                found.append(raw)
        at = data.find(b"MIO0", at + 4)
    if len(found) != len(ROM_ORDER):
        raise SkyError("found %d skyboxes in the ROM, not %d" % (len(found), len(ROM_ORDER)))
    return dict(zip(ROM_ORDER, found))
def skybox_picture(raw):
    from PIL import Image
    ptrs = [p - SEGMENT for (p,) in struct.iter_unpack(">I", raw[-PTRLIST:])]
    img = Image.new("RGB", (SIDE, SIDE))
    for row in range(ROWS):
        for col in range(COLS):
            off = ptrs[row * ROW_PTRS + col]
            tile = raw[off:off + TILE_BYTES]
            px = bytearray()
            for y in range(DRAWN):
                for x in range(DRAWN):
                    c = tile[(y * TILE + x) * 2] << 8 | tile[(y * TILE + x) * 2 + 1]
                    px += bytes(((c >> 11 & 31) * 255 // 31, (c >> 6 & 31) * 255 // 31,
                                 (c >> 1 & 31) * 255 // 31))
            img.paste(Image.frombytes("RGB", (DRAWN, DRAWN), bytes(px)),
                      (col * DRAWN, row * DRAWN))
    return img
def crop_preview(img):
    from PIL import Image
    w, h = img.size
    pw, ph = PREVIEW
    cw = w // 2
    ch = min(h, int(round(cw * ph / float(pw))))
    top = max(0, min(h - ch, int(h * 0.45) - ch // 2))
    return img.convert("RGB").crop((0, top, cw, top + ch)).resize(PREVIEW, Image.LANCZOS)
def _build(src):
    from PIL import Image
    kind, path = src
    out = {}
    if kind == "decomp":
        for key, name in FILES.items():
            for n in ALIASES.get(name, (name,)):
                f = os.path.join(path, n + ".png")
                if os.path.isfile(f):
                    with Image.open(f) as img:
                        out[key] = crop_preview(img)
                    break
        return out
    from . import romaudio
    with open(path, "rb") as handle:
        data, _ = romaudio.to_big_endian(handle.read())
    boxes = rom_skyboxes(data)
    for key, name in FILES.items():
        if name in boxes:
            out[key] = crop_preview(skybox_picture(boxes[name]))
    return out
def previews(rom=None, env=None, home=None, platform=None):
    try:
        src = source(rom, env, home, platform)
    except OSError:
        src = None
    if src is None:
        return {}
    try:
        key = _source_key(src)
    except OSError:
        return {}
    if key in _memo:
        return _memo[key]
    from PIL import Image
    folder = os.path.join(cache_dir(env), key)
    got = {}
    if all(os.path.isfile(os.path.join(folder, k + ".png")) for k in FILES):
        try:
            for k in FILES:
                with Image.open(os.path.join(folder, k + ".png")) as img:
                    got[k] = img.convert("RGB")
        except OSError:
            got = {}
    if not got:
        try:
            got = _build(src)
        except (OSError, SkyError, ValueError, IndexError, struct.error):
            got = {}
        if len(got) == len(FILES):
            try:
                os.makedirs(folder, exist_ok=True)
                for k, img in got.items():
                    img.save(os.path.join(folder, k + ".png"))
            except OSError:
                pass
        elif got:
            got = {}
    _memo[key] = got
    return got
def preview(name, rom=None, env=None, home=None, platform=None):
    return previews(rom, env, home, platform).get(name)
def forget():
    _memo.clear()
