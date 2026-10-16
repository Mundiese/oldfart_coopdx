#!/usr/bin/env python3
import argparse
import io
import os
import re
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
MOD_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(MOD_DIR, "tools"))
from mapgen.render import levelview
from mapgen.render.raster import Camera
from mapgen import skies
LEVELS_DIR = os.path.join(MOD_DIR, "levels")
OUT_DIR = os.path.join(MOD_DIR, "assets-incoming", "1010", "paintings")
SKY_DIR = os.path.join(OUT_DIR, "sky")
SIZE = 192
SUPER = 3
FOV = 45.0
SHOTS = {
    "the_plate":   ("the_plate",   (0.0, 600.0, 4200.0), (0.0, -900.0, 0.0)),
    "desert_cage": ("desert_cage", (3300.0, 1100.0, 3300.0), (0.0, -700.0, 0.0)),
    "ice_donut":   ("ice_donut",   (0.0, 900.0, 5000.0), (0.0, -500.0, 0.0)),
}
SKY_MASKS = {
    "the_plate": [(170, 520), (260, 410), (440, 345), (750, 308), (1020, 300), (1300, 315),
                  (1600, 360), (1790, 440), (1880, 525), (1870, 700), (1700, 800),
                  (1360, 880), (1000, 905), (630, 875), (350, 795), (180, 700)],
    "ice_donut":   [(190, 640), (300, 520), (560, 430), (1000, 400), (1440, 430),
                    (1700, 520), (1820, 640), (1810, 820), (1600, 960), (1100, 1015),
                    (700, 1000), (330, 930), (200, 820)],
    "desert_cage": [(40, 415), (200, 315), (1005, 185), (1765, 310), (1955, 400),
                    (1690, 900), (1520, 1125), (700, 1125), (330, 1000), (130, 690)],
}
SHOT_CHROME = [(0, 0, 2000, 26), (1900, 26, 2000, 90)]
SKY_HOLES = {"ice_donut": (1000, 600, 395, 70)}
def _ints(s):
    return [int(v) for v in re.findall(r"-?\d+", s)]
def _byte_array(text, name):
    m = re.search(r"u8 %s\[\] = \{(.*?)\};" % re.escape(name), text, re.S)
    if not m:
        raise SystemExit("no u8 array %s" % name)
    return bytes(int(v, 16) for v in re.findall(r"0x([0-9a-fA-F]{2})", m.group(1)))
def _rgba16(raw):
    a = np.frombuffer(raw, dtype=">u2").astype(np.uint32)
    r, g, b = (a >> 11) & 31, (a >> 6) & 31, (a >> 1) & 31
    return np.stack([(c << 3) | (c >> 2) for c in (r, g, b)], -1).astype(np.float64) / 255.0
def _list(text, name):
    m = re.search(r"Gfx %s\[\] = \{(.*?)\};" % re.escape(name), text, re.S)
    if not m:
        raise SystemExit("no display list %s" % name)
    return m.group(1)
def _vertices(text, name):
    m = re.search(r"Vtx %s\[\d+\] = \{(.*?)\n\};" % re.escape(name), text, re.S)
    if not m:
        raise SystemExit("no vertex array %s" % name)
    out = []
    for row in re.findall(r"\{\{ \{(.*?)\}, (-?\d+), \{(.*?)\}, \{(.*?)\} \}\}", m.group(1)):
        x, y, z = _ints(row[0])
        s, t = _ints(row[2])
        n = [v - 256 if v > 127 else v for v in _ints(row[3])[:3]]
        out.append((x, y, z, s, t, n[0] / 127.0, n[1] / 127.0, n[2] / 127.0))
    return out
def _lights(text, name):
    m = re.search(r"Lights1 %s = gdSPDefLights1\((.*?)\);" % re.escape(name), text, re.S)
    v = [int(x, 16) for x in re.findall(r"0x([0-9A-Fa-f]{2})", m.group(1))]
    amb = np.array(v[0:3], np.float64) / 255.0
    dif = np.array(v[3:6], np.float64) / 255.0
    d = np.array([x - 256 if x > 127 else x for x in v[6:9]], np.float64)
    return amb, dif, d / np.linalg.norm(d)
def load_level(level):
    base = os.path.join(LEVELS_DIR, level)
    text = open(os.path.join(base, "model.inc.c")).read()
    geo = open(os.path.join(base, "area_1", "geo.inc.c")).read()
    out = []
    for layer, dx, dy, dz, dl in re.findall(
            r"GEO_TRANSLATE_NODE_WITH_DL\((\w+), (-?\d+), (-?\d+), (-?\d+), (\w+)\)", geo):
        if layer != "LAYER_OPAQUE":
            continue
        off = np.array([int(dx), int(dy), int(dz)], np.float64)
        mat = None
        cull = True
        for call in re.findall(r"gsSPDisplayList\((\w+)\)", _list(text, dl)):
            body = _list(text, call)
            if call.startswith("mat_revert_"):
                continue
            if call.startswith("mat_"):
                if "gsSPClearGeometryMode(G_CULL_BACK)" in body:
                    cull = False
                images = re.findall(r"gsDPSetTextureImage\(\w+, \w+, \d+, (\w+)\)", body)
                pal = [n for n in images if n.endswith("_pal_rgba16")]
                tex = [n for n in images if not n.endswith("_pal_rgba16")][0]
                size = _ints(re.search(r"gsDPSetTileSize\((.*?)\)", body).group(1))
                w, h = size[3] // 4 + 1, size[4] // 4 + 1
                if tex.endswith("_ci8"):
                    colours = _rgba16(_byte_array(text, pal[0]))
                    pic = colours[np.frombuffer(_byte_array(text, tex), np.uint8)]
                else:
                    pic = _rgba16(_byte_array(text, tex))
                lights = re.search(r"gsSPSetLights1\((\w+)\)", body).group(1)
                mat = {"name": tex, "picture": pic.reshape(h, w, 3), "size": (w, h),
                       "lights": _lights(text, lights), "cull": cull}
                out.append((mat, []))
                continue
            buf = {}
            for cmd in re.finditer(r"gsSPVertex\((\w+) \+ (\d+), (\d+), (\d+)\)|"
                                   r"gsSP1Triangle\((\d+), (\d+), (\d+), \d+\)", body):
                if cmd.group(1):
                    verts = _vertices(text, cmd.group(1))
                    first, n, at = int(cmd.group(2)), int(cmd.group(3)), int(cmd.group(4))
                    for k in range(n):
                        v = verts[first + k]
                        buf[at + k] = (v[0] + off[0], v[1] + off[1], v[2] + off[2]) + v[3:]
                else:
                    out[-1][1].append([buf[int(cmd.group(i))] for i in (5, 6, 7)])
        if not cull:
            out[-1][0]["cull"] = False
    return out
def triangles(materials, cam):
    rot = np.stack([cam.right, cam.up, cam.back])
    P, UV, C, N, T, keys = [], [], [], [], [], []
    eye = np.array(cam.eye)
    for mat, tris in materials:
        key = mat["name"]
        levelview._pictures[key] = mat["picture"]
        if key not in keys:
            keys.append(key)
        amb, dif, ldir = mat["lights"]
        w, h = mat["size"]
        for tri in tris:
            p = np.array([v[:3] for v in tri], np.float64)
            n = np.array([v[5:8] for v in tri], np.float64)
            shade = []
            for k in range(3):
                ne = rot @ n[k]
                ne /= max(np.linalg.norm(ne), 1e-9)
                shade.append(np.clip(amb + dif * max(0.0, float(ne @ ldir)), 0, 1))
            face = np.cross(p[1] - p[0], p[2] - p[0])
            if np.linalg.norm(face) < 1e-9:
                continue
            face /= np.linalg.norm(face)
            if face @ n.sum(0) < 0:
                face = -face
            if not mat["cull"] and face @ (eye - p[0]) < 0:
                face = -face
            P.append(p)
            UV.append([(v[3] / 32.0 / w, v[4] / 32.0 / h) for v in tri])
            C.append(shade)
            N.append(face)
            T.append(keys.index(key))
    return (np.array(P), np.array(UV), np.array(C), np.array(N),
            np.array(T, np.int32), keys)
def _rows(img, hole):
    out = img.copy()
    xs = np.arange(img.shape[1])
    for y in range(img.shape[0]):
        known = ~hole[y]
        if known.all() or not known.any():
            continue
        for c in range(3):
            out[y, :, c] = np.where(known, img[y, :, c],
                                    np.interp(xs, xs[known], img[y, known, c]))
    return out
def _fill(img, hole, both=False):
    out = _rows(img, hole)
    if both:
        out = (out + _rows(img.transpose(1, 0, 2), hole.T).transpose(1, 0, 2)) / 2.0
    soft = np.asarray(Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).filter(
        ImageFilter.BoxBlur(24 if both else 6)), np.float64) / 255.0
    return np.where(hole[..., None], soft, img)
def make_sky(key, shot_path):
    with Image.open(shot_path) as im:
        shot = im.convert("RGB")
    mask = Image.new("L", shot.size, 0)
    d = ImageDraw.Draw(mask)
    d.polygon(SKY_MASKS[key], fill=255)
    mask = mask.filter(ImageFilter.MaxFilter(21))
    d = ImageDraw.Draw(mask)
    if key in SKY_HOLES:
        cx, cy, rx, ry = SKY_HOLES[key]
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=0)
    for box in SHOT_CHROME:
        d.rectangle(box, fill=255)
    img = np.asarray(shot, np.float64) / 255.0
    hole = np.asarray(mask) > 0
    if key == "ice_donut":
        med = np.asarray(shot.filter(ImageFilter.MedianFilter(15)), np.float64) / 255.0
        specks = Image.fromarray(((np.abs(img - med).max(-1)) > 0.16).astype(np.uint8) * 255)
        hole |= np.asarray(specks.filter(ImageFilter.MaxFilter(11))) > 0
    out = _fill(img, hole, both=key == "ice_donut")
    out = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))
    out = out.crop((0, 26, 2000, 1125)).resize((666, 366), Image.LANCZOS)
    os.makedirs(SKY_DIR, exist_ok=True)
    out.save(os.path.join(SKY_DIR, key + ".png"), optimize=True)
def sky_square(key, size):
    with Image.open(os.path.join(SKY_DIR, key + ".png")) as im:
        w, h = im.size
        return np.asarray(im.convert("RGB").crop(((w - h) // 2, 0, (w + h) // 2, h)).resize(
            (size, size), Image.BICUBIC), np.float64) / 255.0
def shoot(key):
    level, eye, target = SHOTS[key]
    cam = Camera(eye, target, fov=FOV)
    tris = triangles(load_level(level), cam)
    big = SIZE * SUPER
    renders = []
    for name, colour in (("OF_KEY_A", (0, 0, 0)), ("OF_KEY_B", (255, 255, 255))):
        skies.LOOK[name] = (colour, colour, colour, "none")
        try:
            renders.append(np.asarray(levelview.render(None, cam, size=(big, big), sky=name,
                                                       tris=tris), np.float64) / 255.0)
        finally:
            del skies.LOOK[name]
    covered = (np.abs(renders[0] - renders[1]).sum(-1) < 1e-6)
    sky = sky_square(key, big)
    rgb = np.where(covered[..., None], renders[0], sky)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    return img.resize((SIZE, SIZE), Image.BOX), float(1.0 - covered.mean())
def main():
    ap = argparse.ArgumentParser(description="Shoots a painting source of one of the mod's own levels as it looks now.")
    ap.add_argument("--keys")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--make-sky", nargs=2, metavar=("KEY", "SHOT"))
    args = ap.parse_args()
    if args.make_sky:
        make_sky(*args.make_sky)
        return 0
    keys = args.keys.split(",") if args.keys else sorted(SHOTS)
    stale = 0
    for key in keys:
        img, sky = shoot(key)
        buf = io.BytesIO()
        img.save(buf, format="PNG", optimize=True)
        path = os.path.join(OUT_DIR, key + ".png")
        if args.check:
            with Image.open(path) as im:
                same = np.array_equal(np.asarray(im.convert("RGB")), np.asarray(img))
            if not same:
                print("STALE: %s" % path)
                stale += 1
            continue
        with open(path, "wb") as handle:
            handle.write(buf.getvalue())
        print("%-12s skybox %2.0f %%  -> %s" % (key, sky * 100, os.path.relpath(path, MOD_DIR)))
    return 1 if stale else 0
if __name__ == "__main__":
    sys.exit(main())
