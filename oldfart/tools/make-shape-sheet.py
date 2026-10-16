#!/usr/bin/env python3
import importlib.util
import io
import math
import os
import sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "docs", "shapes")
_spec = importlib.util.spec_from_file_location("make_forgeslopes",
                                               os.path.join(HERE, "make-forgeslopes.py"))
slopes = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(slopes)
CELL = 220
VIEW = (1.0, 0.85, 1.3)
LIGHT = (0.4, 1.0, 0.7)
def norm(v):
    length = math.sqrt(sum(c * c for c in v))
    return tuple(c / length for c in v)
def texture(png):
    return Image.open(io.BytesIO(png)).convert("RGB")
def render(faces, textures, layered, size=CELL):
    d = norm(VIEW)
    right = norm((d[2], 0.0, -d[0]))
    up = (d[1] * right[2] - d[2] * right[1], d[2] * right[0] - d[0] * right[2],
          d[0] * right[1] - d[1] * right[0])
    up = norm(up)
    if up[1] < 0:
        up = tuple(-c for c in up)
    light = norm(LIGHT)
    scale = size / 330.0
    img = Image.new("RGB", (size, size), (34, 36, 46))
    px = img.load()
    zbuf = [[-1e9] * size for _ in range(size)]
    def project(p):
        q = (p[0], p[1] - 100, p[2])
        x = sum(q[k] * right[k] for k in range(3))
        y = sum(q[k] * up[k] for k in range(3))
        z = sum(q[k] * d[k] for k in range(3))
        return (size / 2 + x * scale, size / 2 - y * scale, z)
    for pts, normal in faces:
        n = norm(normal)
        if sum(n[k] * d[k] for k in range(3)) <= 0:
            continue
        shade = 0.45 + 0.55 * max(0.0, sum(n[k] * light[k] for k in range(3)))
        layer = slopes.layer_of(normal) if layered else 0
        tex = textures[layer]
        tpx = tex.load()
        uvs = [(slopes.layered_uv(pts, normal, p) if layered else slopes.uv(p, normal))
               for p in pts]
        scr = [project(p) for p in pts]
        for a, b, c in ((0, i, i + 1) for i in range(1, len(pts) - 1)):
            (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = scr[a], scr[b], scr[c]
            den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
            if abs(den) < 1e-9:
                continue
            for y in range(max(0, int(min(y0, y1, y2))), min(size, int(max(y0, y1, y2)) + 1)):
                for x in range(max(0, int(min(x0, x1, x2))), min(size, int(max(x0, x1, x2)) + 1)):
                    w0 = ((y1 - y2) * (x - x2) + (x2 - x1) * (y - y2)) / den
                    w1 = ((y2 - y0) * (x - x2) + (x0 - x2) * (y - y2)) / den
                    w2 = 1 - w0 - w1
                    if w0 < -1e-6 or w1 < -1e-6 or w2 < -1e-6:
                        continue
                    z = w0 * z0 + w1 * z1 + w2 * z2
                    if z <= zbuf[y][x]:
                        continue
                    zbuf[y][x] = z
                    s = w0 * uvs[a][0] + w1 * uvs[b][0] + w2 * uvs[c][0]
                    t = w0 * uvs[a][1] + w1 * uvs[b][1] + w2 * uvs[c][1]
                    tx = int(math.floor(s / 32.0)) % tex.width
                    ty = int(math.floor(t / 32.0)) % tex.height
                    r, g, bl = tpx[min(tx, 31), min(ty, 31)]
                    px[x, y] = (int(r * shade), int(g * shade), int(bl * shade))
    return img
def sheet(tiles, title, columns):
    rows = (len(tiles) + columns - 1) // columns
    out = Image.new("RGB", (columns * CELL, rows * (CELL + 18) + 24), (20, 21, 28))
    draw = ImageDraw.Draw(out)
    draw.text((8, 6), title, fill=(240, 240, 240))
    for i, (label, img) in enumerate(tiles):
        x, y = (i % columns) * CELL, 24 + (i // columns) * (CELL + 18)
        out.paste(img, (x, y))
        draw.text((x + 6, y + CELL + 2), label, fill=(220, 220, 220))
    return out
def main(argv):
    slug = argv[0] if argv else "stone1"
    _, rows = slopes.blocks.read_manifest()
    by = {row["slug"]: row for row in rows}
    if slug not in by:
        print("make-shape-sheet: no block %r" % slug)
        return 1
    cube = slopes.solid({"tag": "cube", "flip": False,
                         "faces": slopes.box_faces(slopes.LO, slopes.HI, 0, slopes.TOP,
                                                   slopes.LO, slopes.HI)})
    os.makedirs(OUT, exist_ok=True)
    png, _ = slopes.row_textures(by[slug])
    tex = [texture(png)] * 3
    tiles = [("cube", render(cube, tex, False))]
    for variant in slopes.variants():
        tiles.append(("%d %s" % (variant["byte"], variant["tag"]),
                      render(slopes.solid(variant), tex, False)))
    sheet(tiles, "Forge shapes in %s (byte, tag) - drawn from make-forgeslopes' own faces"
          % by[slug]["name"], 5).save(os.path.join(OUT, "shapes-%s.png" % slug), optimize=True)
    tiles = []
    for row in rows:
        if not row.get("layers"):
            continue
        top, layers = slopes.row_textures(row)
        tex = [texture(top), texture(layers[0]), texture(layers[1])]
        tiles.append(("%s cube" % row["name"], render(cube, tex, True)))
        for variant in slopes.variants():
            if slopes.builds_in(variant, row):
                tiles.append(("%s %s" % (row["name"], variant["tag"]),
                              render(slopes.solid(variant), tex, True)))
    if tiles:
        sheet(tiles, "Transition blocks (top / side / bottom) in every shape they come in",
              7).save(os.path.join(OUT, "transition-blocks.png"), optimize=True)
    tiles = []
    for variant in slopes.variants():
        if variant["byte"] < 19:
            continue
        mine = [row for row in rows if slopes.builds_in(variant, row) and not row.get("layers")]
        for row in mine[:3]:
            png, _ = slopes.row_textures(row)
            tiles.append(("%d %s %s" % (variant["byte"], variant["tag"], row["slug"]),
                          render(slopes.solid(variant), [texture(png)] * 3, False)))
    sheet(tiles, "7 Days to Die shapes (byte, tag, texture) - make-forgeslopes' own faces",
          6).save(os.path.join(OUT, "kit-shapes.png"), optimize=True)
    tiles = []
    kit_layered = ("slab", "plate", "prism", "wedge", "wedgetip", "wedgeouter", "wedgeinner",
                   "wedgetipouter", "wedgetipinner", "ridge", "pyramid")
    for row in rows:
        if not row.get("layers"):
            continue
        top, layers = slopes.row_textures(row)
        tex = [texture(top), texture(layers[0]), texture(layers[1])]
        for variant in slopes.variants():
            if variant["tag"] in kit_layered and slopes.builds_in(variant, row):
                tiles.append(("%s %s" % (row["name"], variant["tag"]),
                              render(slopes.solid(variant), tex, True)))
    if tiles:
        sheet(tiles, "Transition tops on the ground shapes",
              6).save(os.path.join(OUT, "kit-transitions.png"), optimize=True)
    print("make-shape-sheet: docs/shapes/shapes-%s.png, docs/shapes/transition-blocks.png, "
          "docs/shapes/kit-shapes.png, docs/shapes/kit-transitions.png" % slug)
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
