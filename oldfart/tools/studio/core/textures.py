from . import kitbridge, pixcache
SIZE = 32
MISSING = 0
INVISIBLE = 1
INVISIBLE_SLUG = "invisible"
def _glass():
    out = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            on = (x + y) % 16 < 2
            out += bytes((120, 190, 255, 255)) if on else bytes((190, 225, 255, 255))
    return bytes(out)
def _checker():
    out = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            on = ((x // 8) + (y // 8)) % 2 == 0
            out += bytes((255, 0, 220, 255)) if on else bytes((20, 20, 20, 255))
    return bytes(out)
def rgba_of(png, where="texture"):
    w, h, rows = kitbridge.blocks().png_pixels(png, where)
    out = bytearray()
    for row in rows:
        for px in row:
            if len(px) == 3:
                out += bytes((px[0], px[1], px[2], 255))
            else:
                out += bytes(px[:4])
    return w, h, bytes(out)
def fit(w, h, data, size=SIZE):
    if w == size and h == size:
        return data
    out = bytearray()
    for y in range(size):
        sy = y * h // size
        for x in range(size):
            sx = x * w // size
            i = (sy * w + sx) * 4
            out += data[i:i + 4]
    return bytes(out)
class Registry:
    def __init__(self, load_pixels=True):
        self.serial = 0
        self.listeners = []
        self._read(load_pixels)
    def reload(self, force=False):
        if not force and _stamp() == self._stamp:
            return self
        self._read(self._load_pixels)
        self.serial += 1
        for fn in list(self.listeners):
            fn()
        return self
    def _read(self, load_pixels):
        self._load_pixels = load_pixels
        self._stamp = _stamp()
        self.layers = [("missing", _checker()),
                       (INVISIBLE_SLUG, _glass())]
        self.slugs = {INVISIBLE_SLUG: (INVISIBLE, INVISIBLE, INVISIBLE)}
        self.names = {INVISIBLE_SLUG: "Invisible wall (collision only)"}
        self.shelves = {INVISIBLE_SLUG: "special"}
        self.averages = {INVISIBLE_SLUG: (190, 225, 255)}
        self.problems = []
        b = kitbridge.blocks()
        _, rows = b.read_manifest()
        for row in rows:
            sources = row["layers"] or [row["source"]]
            idx = []
            for k, rel in enumerate(sources):
                label = row["slug"] if k == 0 else "%s/%s" % (row["slug"], ("top", "side", "bottom")[k])
                pixels = None
                if load_pixels:
                    try:
                        path = kitbridge.repo_path(rel)
                        pixels = pixcache.get(path, "rgba%d" % SIZE, lambda path=path, rel=rel: fit(
                            *rgba_of(b.read_texture(path), rel)))
                    except Exception as exc:
                        self.problems.append("%s: %s" % (rel, exc))
                        pixels = None
                if pixels is None and load_pixels:
                    idx.append(MISSING)
                    continue
                self.layers.append((label, pixels))
                idx.append(len(self.layers) - 1)
            top = idx[0]
            side = idx[1] if len(idx) > 1 else top
            bottom = idx[2] if len(idx) > 2 else top
            self.slugs[row["slug"]] = (top, side, bottom)
            self.names[row["slug"]] = row["name"]
            self.shelves[row["slug"]] = row["shelf"]
            for old in row.get("was") or ():
                self.slugs.setdefault(old, (top, side, bottom))
            if load_pixels and self.layers[top][1] is not None:
                self.averages[row["slug"]] = average(self.layers[top][1])
        if load_pixels:
            pixcache.save()
    def count(self):
        return len(self.layers)
    def layers_for(self, piece):
        top, side, bottom = self.slugs.get(piece.get("tex"), (MISSING, MISSING, MISSING))
        if piece.get("tex_top"):
            top = self.slugs.get(piece["tex_top"], (MISSING,))[0]
        if piece.get("tex_side"):
            side = self.slugs.get(piece["tex_side"], (MISSING,))[0]
        if piece.get("tex_bottom"):
            bottom = self.slugs.get(piece["tex_bottom"], (MISSING,))[0]
        return top, side, bottom
    def known(self, slug):
        return slug in self.slugs
    def pixel_bytes(self):
        return b"".join(px for _, px in self.layers)
def _stamp():
    import os
    try:
        st = os.stat(getattr(kitbridge.blocks(), "MANIFEST", ""))
        return (st.st_mtime_ns, st.st_size)
    except (OSError, TypeError):
        return None
def average(rgba):
    n = len(rgba) // 4
    return tuple(sum(rgba[k::4]) // max(1, n) for k in range(3))
