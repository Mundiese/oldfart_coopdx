import math
import os
import sys
import numpy as np
SCREEN_WIDTH, SCREEN_HEIGHT = 320, 240
SKYBOX_WIDTH, SKYBOX_HEIGHT = 4 * SCREEN_WIDTH, 4 * SCREEN_HEIGHT
SKYBOX_TILE_WIDTH, SKYBOX_TILE_HEIGHT = SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2
TILES_ACROSS = SKYBOX_WIDTH // SKYBOX_TILE_WIDTH
TILES_DOWN = SKYBOX_HEIGHT // SKYBOX_TILE_HEIGHT
FOV = 90.0
DEFAULT = "BACKGROUND_OCEAN_SKY"
_TOOLS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_memo = {}
def angles(cam):
    fx, fy, fz = (float(c) for c in -np.asarray(cam.back, np.float64))
    yaw = math.pi / 2.0 - math.atan2(fz, fx)
    if yaw < 0:
        yaw += math.pi * 2.0
    pitch = math.pi / 2.0 - math.atan2(math.sqrt(fx * fx + fz * fz), fy)
    return yaw, pitch
def scaled_x(yaw, fov=FOV):
    sx = SCREEN_WIDTH * 180.0 * yaw / (fov * math.pi)
    if sx > SKYBOX_WIDTH:
        sx -= int(sx) // SKYBOX_WIDTH * SKYBOX_WIDTH
    return SKYBOX_WIDTH - sx
def scaled_y(pitch):
    degrees = pitch * 180.0 / math.pi
    sy = 360.0 * degrees / 90.0 + 5 * SKYBOX_TILE_HEIGHT
    return min(float(SKYBOX_HEIGHT), max(float(SCREEN_HEIGHT), sy))
def window(cam):
    yaw, pitch = angles(cam)
    return scaled_x(yaw), scaled_y(pitch)
def texels(cam, w, h, pic_w, pic_h):
    left, top = window(cam)
    X = left + SCREEN_WIDTH * (np.arange(w, dtype=np.float64) + 0.5) / w
    Y = top - SCREEN_HEIGHT * (np.arange(h, dtype=np.float64) + 0.5) / h
    cols = X / SKYBOX_TILE_WIDTH * (pic_w / float(TILES_ACROSS))
    rows = (SKYBOX_HEIGHT - Y) / SKYBOX_TILE_HEIGHT * (pic_h / float(TILES_DOWN))
    return cols, rows
def project(pic, cam, w, h, colour=None):
    pic = np.asarray(pic, np.float64)
    ph, pw = pic.shape[:2]
    cols, rows = texels(cam, w, h, pw, ph)
    c0 = np.floor(cols)
    fc = (cols - c0)[None, :, None]
    c0 = c0.astype(np.int64) % pw
    c1 = (c0 + 1) % pw
    rows = np.clip(rows, 0.0, ph - 1.0)
    r0 = np.floor(rows)
    fr = (rows - r0)[:, None, None]
    r0 = r0.astype(np.int64)
    r1 = np.minimum(r0 + 1, ph - 1)
    top = pic[r0][:, c0] * (1 - fc) + pic[r0][:, c1] * fc
    low = pic[r1][:, c0] * (1 - fc) + pic[r1][:, c1] * fc
    out = top * (1 - fr) + low * fr
    if colour is not None:
        out = out * (np.array([float(c) for c in colour[:3]], np.float64) / 255.0)[None, None, :]
    return out
def _romskies():
    if _TOOLS not in sys.path:
        sys.path.insert(0, _TOOLS)
    from studio.library import romskies
    return romskies
def _key(src):
    kind, path = src
    st = os.stat(path)
    return (kind, os.path.abspath(path), st.st_size, int(st.st_mtime))
def _pictures(src):
    from PIL import Image
    rs = _romskies()
    kind, path = src
    out = {}
    if kind == "decomp":
        for name in set(rs.FILES.values()):
            for n in rs.ALIASES.get(name, (name,)):
                f = os.path.join(path, n + ".png")
                if os.path.isfile(f):
                    with Image.open(f) as img:
                        out[name] = img.convert("RGB")
                    break
        return out
    from studio.library import romaudio
    with open(path, "rb") as handle:
        data, _ = romaudio.to_big_endian(handle.read())
    for name, raw in rs.rom_skyboxes(data).items():
        out[name] = rs.skybox_picture(raw)
    return out
def picture(sky, env=None, home=None, platform=None, rom=None):
    try:
        rs = _romskies()
        src = rs.source(rom, env, home, platform)
        if src is None:
            return None
        key = _key(src)
        if key not in _memo:
            _memo.clear()
            pics = _pictures(src)
            _memo[key] = {n: np.asarray(p, np.float64) / 255.0 for n, p in pics.items()}
        name = rs.FILES.get(sky if sky in rs.FILES else DEFAULT)
        return _memo[key].get(name)
    except Exception:
        return None
def forget():
    _memo.clear()
