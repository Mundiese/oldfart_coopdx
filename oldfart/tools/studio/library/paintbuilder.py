import os
import re
FRAMES = (("bob", "Bob-omb Battlefield"), ("wf", "Whomp's Fortress"),
          ("jrb", "Jolly Roger Bay"), ("ccm", "Cool, Cool Mountain"),
          ("lll", "Lethal Lava Land"), ("wdw", "Wet-Dry World"),
          ("thi", "Tiny-Huge Island"), ("ttm", "Tall, Tall Mountain"))
ZOOM_MIN, ZOOM_MAX = 1.0, 4.0
class Placement:
    def __init__(self, zoom=1.0, dx=0.0, dy=0.0):
        self.zoom = max(ZOOM_MIN, min(ZOOM_MAX, float(zoom)))
        lim = 0.5 * (1.0 - 1.0 / self.zoom)
        self.dx = max(-lim, min(lim, float(dx)))
        self.dy = max(-lim, min(lim, float(dy)))
    def moved(self, ddx, ddy):
        return Placement(self.zoom, self.dx + ddx, self.dy + ddy)
    def zoomed(self, zoom):
        return Placement(zoom, self.dx, self.dy)
    def __eq__(self, other):
        return isinstance(other, Placement) and (self.zoom, self.dx, self.dy) == (
            other.zoom, other.dx, other.dy)
    def __repr__(self):
        return "Placement(%.2f, %.3f, %.3f)" % (self.zoom, self.dx, self.dy)
def framed(src, placement=None, size=192):
    from PIL import Image
    placement = placement or Placement()
    src = src.convert("RGB")
    w, h = src.size
    side = min(w, h) / placement.zoom
    cx = w / 2.0 + placement.dx * min(w, h)
    cy = h / 2.0 + placement.dy * min(w, h)
    cx = max(side / 2.0, min(w - side / 2.0, cx))
    cy = max(side / 2.0, min(h - side / 2.0, cy))
    box = (cx - side / 2.0, cy - side / 2.0, cx + side / 2.0, cy + side / 2.0)
    return src.resize((size, size), Image.LANCZOS, box=box)
def build(src, placement=None, frame="bob", painted=True, k=2):
    from mapgen import painting
    pic = framed(src, placement)
    top, bottom = painting.halves(pic, frame, k, stylised=painted)
    return top, bottom, preview_of(top, bottom)
def preview_of(top, bottom):
    from PIL import Image
    w, h = top.size
    k = max(1, w // 64)
    out = Image.new("RGB", (w, 2 * h - k))
    out.paste(top, (0, 0))
    out.paste(bottom.crop((0, k, w, h)), (0, h))
    return out
def tex_name(name):
    slug = re.sub(r"[^a-z0-9]+", "_", str(name or "").lower()).strip("_") or "painting"
    return "ofpnt_custom_" + slug[:40]
def save(folder, name, top, bottom):
    from mapgen import painting
    stem = tex_name(name)
    tex_dir = os.path.join(folder, "textures")
    os.makedirs(tex_dir, exist_ok=True)
    written = []
    for half, img in (("top", top), ("bottom", bottom)):
        tname = "%s_%s" % (stem, half)
        png = painting.png_bytes(img)
        for path, data in ((os.path.join(tex_dir, tname + ".tex"), painting.tex_bytes(tname, png)),
                           (os.path.join(folder, "paintings", tname + ".png"), png)):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            tmp = path + ".part"
            with open(tmp, "wb") as fh:
                fh.write(data)
            os.replace(tmp, path)
            written.append(path)
    return written
_frames = {}
def quick_preview(src, placement=None, frame="bob", width=256):
    import numpy as np
    from PIL import Image
    from mapgen import painting
    f = painting.faces()
    if frame not in _frames:
        base = f.master_from(Image.new("RGB", (8, 8)), frame, stylised=False)
        _frames[frame] = Image.fromarray(np.clip(base, 0, 255).astype("uint8"))
    m = _frames[frame].copy()
    x0, y0, x1, y1 = f.OPEN_BOX
    pic = f.opening_crop(framed(src, placement))
    m.paste(pic.resize((x1 - x0, y1 - y0), Image.BILINEAR), (x0, y0))
    r = f.R
    box = (int(1.0 * r), int(1.5 * r), int(65.0 * r), int(64.5 * r))
    return m.crop(box).resize((width, int(round(width * 63 / 64.0))), Image.BILINEAR)
