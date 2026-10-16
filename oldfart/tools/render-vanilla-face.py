#!/usr/bin/env python3
import argparse
import glob
import os
import re
import sys
import numpy as np
from PIL import Image
MOD_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(MOD_DIR, "tools"))
from mapgen.render import levelview
from mapgen.render.raster import Camera
SIZE = 192
SUPER = 3
FOV = 45.0
COURSES = {
    "bob": ("bob", "water"), "wf": ("wf", "cloud_floor"), "jrb": ("jrb", "water"),
    "ccm": ("ccm", "ccm"), "lll": ("lll", "bitfs"), "wdw": ("wdw", "wdw"),
    "thi": ("thi", "water"), "ttm": ("ttm", "water"),
}
LAYERS = ("LAYER_OPAQUE", "LAYER_OPAQUE_DECAL", "LAYER_ALPHA", "LAYER_TRANSPARENT_DECAL")
def default_out():
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local",
                                                           "share")
    return os.path.join(base, "oldfart-studio", "paintings-review")
def _ints(s):
    return [int(v, 0) for v in re.findall(r"-?(?:0x[0-9a-fA-F]+|\d+)", s)]
class Decomp:
    def __init__(self, root):
        self.root = root
        self.symbols = {}
        for path in glob.glob(os.path.join(root, "bin", "*.c")) + glob.glob(
                os.path.join(root, "levels", "*", "*.c")) + glob.glob(
                os.path.join(root, "levels", "*", "*", "*.c")):
            text = open(path, encoding="utf-8", errors="replace").read()
            for name, inc in re.findall(r"(\w+)\[\] = \{\s*#include \"([^\"]+)\.inc\.c\"", text):
                self.symbols[name] = inc
        self._pics = {}
    def picture(self, name):
        if name in self._pics:
            return self._pics[name]
        inc = self.symbols.get(name)
        pic = None
        if inc:
            path = os.path.join(self.root, inc + ".png")
            if os.path.isfile(path):
                with Image.open(path) as im:
                    pic = np.asarray(im.convert("RGBA"), np.float64) / 255.0
        self._pics[name] = pic
        return pic
def _texts(level_dir):
    out = ""
    skip = ("collision.inc.c", "macro.inc.c", "geo.inc.c", "trajectory.inc.c", "movtext.inc.c")
    for path in sorted(glob.glob(os.path.join(level_dir, "areas", "1", "*", "*.inc.c"))
                       + glob.glob(os.path.join(level_dir, "areas", "1", "*.inc.c"))):
        if os.path.basename(path) in skip:
            continue
        out += open(path, encoding="utf-8", errors="replace").read() + "\n"
    return out
def _vertices(text):
    out = {}
    for name, body in re.findall(r"Vtx (\w+)\[\] = \{(.*?)\n\};", text, re.S):
        rows = []
        for row in re.findall(r"\{\{\{(.*?)\}, (-?\d+), \{(.*?)\}, \{(.*?)\}\}\}", body):
            x, y, z = _ints(row[0])
            s, t = _ints(row[2])
            c = _ints(row[3])
            rows.append((x, y, z, s, t, c[0], c[1], c[2], c[3]))
        out[name] = rows
    return out
def _lights(text):
    out = {}
    for name, body in re.findall(r"Lights1 (\w+) = gdSPDefLights1\((.*?)\);", text, re.S):
        v = _ints(body)
        amb = np.array(v[0:3], np.float64) / 255.0
        dif = np.array(v[3:6], np.float64) / 255.0
        d = np.array([x - 256 if x > 127 else x for x in v[6:9]], np.float64)
        out[name] = (amb, dif, d / max(np.linalg.norm(d), 1e-9))
    return out
def _lists(text):
    return {name: body for name, body in re.findall(r"Gfx (\w+)\[\] = \{(.*?)\n\};", text, re.S)}
def walk(level_dir, dc):
    text = _texts(level_dir)
    geo = open(os.path.join(level_dir, "areas", "1", "geo.inc.c"), encoding="utf-8").read()
    verts, lights, lists = _vertices(text), _lights(text), _lists(text)
    roots = [dl for layer, dl in re.findall(r"GEO_DISPLAY_LIST\((\w+), (\w+)\)", geo)
             if layer in LAYERS]
    groups = {}
    st = {"tex": None, "size": (32, 32), "lit": True, "textured": True, "light": None}
    def run(name, depth=0):
        body = lists.get(name)
        if body is None or depth > 8:
            return
        buf = {}
        for cmd in re.finditer(r"(gs\w+)\((.*?)\),?\n", body + "\n"):
            op, args = cmd.group(1), cmd.group(2)
            if op == "gsSPDisplayList":
                run(args.strip(), depth + 1)
            elif op == "gsDPSetTextureImage":
                st["tex"] = args.split(",")[-1].strip()
            elif op == "gsDPLoadTextureBlock":
                parts = [a.strip() for a in args.split(",")]
                st["tex"] = parts[0]
                try:
                    st["size"] = (int(parts[3]), int(parts[4]))
                except ValueError:
                    pass
            elif op == "gsDPSetTileSize":
                m = re.findall(r"\((\d+) - 1\)", args)
                if len(m) == 2:
                    st["size"] = (int(m[0]), int(m[1]))
            elif op == "gsSPSetGeometryMode" and "G_LIGHTING" in args:
                st["lit"] = True
            elif op == "gsSPClearGeometryMode" and "G_LIGHTING" in args:
                st["lit"] = False
            elif op == "gsSPLight":
                m = re.match(r"&(\w+)\.l", args.strip())
                if m:
                    st["light"] = m.group(1)
            elif op == "gsDPSetCombineMode":
                st["textured"] = "G_CC_SHADE," not in args + "," or "TEXEL" in args \
                    or "MODULATE" in args or "DECAL" in args or "BLEND" in args
            elif op == "gsSPTexture":
                st["textured"] = "G_ON" in args
            elif op == "gsSPVertex":
                m = re.match(r"\s*(\w+)(?:\s*\+\s*(\d+))?,\s*(\d+),\s*(\d+)", args)
                if not m or m.group(1) not in verts:
                    continue
                rows = verts[m.group(1)]
                first = int(m.group(2) or 0)
                for k in range(int(m.group(3))):
                    if first + k < len(rows):
                        buf[int(m.group(4)) + k] = rows[first + k]
            elif op in ("gsSP1Triangle", "gsSP2Triangles"):
                v = _ints(args)
                tris = [v[0:3]] if op == "gsSP1Triangle" else [v[0:3], v[4:7]]
                key = st["tex"] if st["textured"] and st["tex"] else "__white"
                w, h = st["size"]
                g = groups.setdefault((key, w, h), [])
                for t in tris:
                    if all(i in buf for i in t):
                        g.append([(buf[i], st["lit"], st["light"]) for i in t])
    for dl in roots:
        run(dl)
    out = []
    for (key, w, h), tris in groups.items():
        pic = dc.picture(key) if key != "__white" else None
        if pic is None:
            pic = np.ones((1, 1, 4))
            key = "__white"
        out.append((key, pic, (w, h), tris, lights))
    return out
def triangles(groups, cam):
    rot = np.stack([cam.right, cam.up, cam.back])
    P, UV, C, N, T, keys = [], [], [], [], [], []
    for key, pic, (w, h), tris, lights in groups:
        levelview._pictures[key] = pic[..., :3]
        if key not in keys:
            keys.append(key)
        for tri in tris:
            p = np.array([v[:3] for v, _, _ in tri], np.float64)
            face = np.cross(p[1] - p[0], p[2] - p[0])
            if np.linalg.norm(face) < 1e-9:
                continue
            face /= np.linalg.norm(face)
            shade = []
            for v, lit, lname in tri:
                if lit and lname in lights:
                    amb, dif, ldir = lights[lname]
                    n = np.array([c - 256 if c > 127 else c for c in v[5:8]], np.float64)
                    n = rot @ (n / max(np.linalg.norm(n), 1e-9))
                    shade.append(np.clip(amb + dif * max(0.0, float(n @ ldir)), 0, 1))
                else:
                    shade.append(np.array(v[5:8], np.float64) / 255.0)
            P.append(p)
            UV.append([(v[3] / 32.0 / w, v[4] / 32.0 / h) for v, _, _ in tri])
            C.append(shade)
            N.append(face)
            T.append(keys.index(key))
    return (np.array(P), np.array(UV), np.array(C), np.array(N), np.array(T, np.int32), keys)
def intro_camera(level_dir):
    geo = open(os.path.join(level_dir, "areas", "1", "geo.inc.c"), encoding="utf-8").read()
    m = re.search(r"GEO_CAMERA\(\s*\d+,\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),"
                  r"\s*(-?\d+)", geo)
    if not m:
        return None
    v = [float(x) for x in m.groups()]
    return Camera(v[0:3], v[3:6], fov=FOV)
def sky_square(dc_root, sky, size):
    path = os.path.join(dc_root, "textures", "skyboxes", sky + ".png")
    if not os.path.isfile(path):
        return None
    with Image.open(path) as im:
        im = im.convert("RGB")
        w, h = im.size
        side = min(w // 2, h)
        top = max(0, int(h * 0.45) - side // 2)
        return np.asarray(im.crop((0, top, side, top + side)).resize((size, size), Image.BICUBIC),
                          np.float64) / 255.0
PITCH = 30.0
PULL = 0.95
def composed(groups, intro, turn=0.0):
    import math
    pts = np.array([v[:3] for _k, _p, _s, tris, _l in groups for tri in tris
                    for v, _a, _b in tri], np.float64)
    lo = np.percentile(pts, 3, axis=0)
    hi = np.percentile(pts, 97, axis=0)
    centre = (lo + hi) / 2.0
    d = np.array(intro.target, np.float64) - np.array(intro.eye, np.float64)
    yaw = math.atan2(d[0], d[2]) + math.radians(turn)
    radius = float(np.linalg.norm((hi - lo)[[0, 2]])) / 2.0
    dist = radius / math.tan(math.radians(FOV) / 2.0) * PULL
    p = math.radians(PITCH)
    back = np.array((-math.sin(yaw) * math.cos(p), math.sin(p), -math.cos(yaw) * math.cos(p)))
    target = centre.copy()
    target[1] = lo[1] + (hi[1] - lo[1]) * 0.30
    return Camera(target + back * dist, target, fov=FOV)
def shoot(dc, key, cam=None, turn=0.0):
    level, sky = COURSES[key]
    level_dir = os.path.join(dc.root, "levels", level)
    groups = walk(level_dir, dc)
    cam = cam or composed(groups, intro_camera(level_dir), turn)
    tris = triangles(groups, cam)
    big = SIZE * SUPER
    from mapgen import skies
    renders = []
    for name, colour in (("OF_KEY_A", (0, 0, 0)), ("OF_KEY_B", (255, 255, 255))):
        skies.LOOK[name] = (colour, colour, colour, "none")
        try:
            renders.append(np.asarray(levelview.render(None, cam, size=(big, big), sky=name,
                                                       tris=tris), np.float64) / 255.0)
        finally:
            del skies.LOOK[name]
    covered = (np.abs(renders[0] - renders[1]).sum(-1) < 1e-6)
    back = sky_square(dc.root, sky, big)
    if back is None:
        back = np.ones((big, big, 3)) * 0.6
    rgb = np.where(covered[..., None], renders[0], back)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    return img.resize((SIZE, SIZE), Image.BOX), float(1.0 - covered.mean())
def faces_module():
    import importlib.util
    path = os.path.join(MOD_DIR, "tools", "make-painting-faces.py")
    spec = importlib.util.spec_from_file_location("make_painting_faces", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
def main():
    ap = argparse.ArgumentParser(description="Paints a course's own painting from its level data.")
    ap.add_argument("--decomp", default=os.environ.get("OF_DECOMP"))
    ap.add_argument("--out", default=default_out())
    ap.add_argument("--keys")
    ap.add_argument("--turn", type=float, default=0.0,
                    help="turn the camera round the course by this many degrees")
    args = ap.parse_args()
    if not args.decomp or not os.path.isdir(os.path.join(args.decomp, "levels")):
        print("no decomp extraction: set OF_DECOMP or pass --decomp")
        return 1
    if os.path.realpath(args.out).startswith(os.path.realpath(MOD_DIR) + os.sep):
        print("refused: the pictures are your ROM's - write them outside the repository")
        return 1
    dc = Decomp(args.decomp)
    faces = faces_module()
    os.makedirs(args.out, exist_ok=True)
    keys = args.keys.split(",") if args.keys else sorted(COURSES)
    for key in keys:
        src, sky = shoot(dc, key, turn=args.turn)
        src.save(os.path.join(args.out, key + "_source.png"))
        top, bottom = faces.halves_from(src, key if key in faces.VANILLA else "bob", 2)
        Image.fromarray(top).save(os.path.join(args.out, key + "_top.png"))
        Image.fromarray(bottom).save(os.path.join(args.out, key + "_bottom.png"))
        full = np.vstack([top, bottom[2:]])
        Image.fromarray(full).resize((256, 252), Image.NEAREST).save(
            os.path.join(args.out, key + "_preview.png"))
        print("%s: %.0f %% sky -> %s" % (key, 100 * sky, args.out))
    return 0
if __name__ == "__main__":
    sys.exit(main())
