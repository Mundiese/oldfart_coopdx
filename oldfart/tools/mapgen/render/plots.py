from .views import BG, INK, DIM, heat_colour, _pil
AXIS = (120, 120, 135)
def _frame(d, x0, y0, w, h, xlabel, ylabel, xr, yr, title):
    d.rectangle([x0, y0, x0 + w, y0 + h], outline=AXIS)
    for k in range(6):
        t = k / 5.0
        X = x0 + w * t
        Y = y0 + h - h * t
        d.line([(X, y0 + h), (X, y0 + h + 4)], fill=AXIS)
        d.line([(x0 - 4, Y), (x0, Y)], fill=AXIS)
        d.text((X - 10, y0 + h + 6), "%.1f" % (xr[0] + (xr[1] - xr[0]) * t), fill=DIM)
        d.text((x0 - 34, Y - 6), "%.1f" % (yr[0] + (yr[1] - yr[0]) * t), fill=DIM)
    d.text((x0 + w / 2 - 40, y0 + h + 22), xlabel, fill=INK)
    d.text((6, y0 - 18), ylabel, fill=INK)
    if title:
        d.text((x0, 6), title, fill=INK)
def scatter(points, xaxis, yaxis, xr=(0, 1), yr=(0, 1), size=520, title=None, labels=None,
            colours=None):
    Image, ImageDraw = _pil()
    im = Image.new("RGB", (size, size), BG)
    d = ImageDraw.Draw(im)
    x0, y0, w, h = 60, 40, size - 90, size - 100
    _frame(d, x0, y0, w, h, xaxis, yaxis, xr, yr, title)
    for k, pt in enumerate(points):
        if pt is None or pt[0] is None or pt[1] is None:
            continue
        tx = (pt[0] - xr[0]) / float(xr[1] - xr[0])
        ty = (pt[1] - yr[0]) / float(yr[1] - yr[0])
        X = x0 + w * max(0.0, min(1.0, tx))
        Y = y0 + h - h * max(0.0, min(1.0, ty))
        col = (colours[k] if colours else (110, 200, 255))
        d.ellipse([X - 4, Y - 4, X + 4, Y + 4], fill=col, outline=(0, 0, 0))
        if labels:
            d.text((X + 6, Y - 6), str(labels[k]), fill=INK)
    return im
def era_heatmap(points, xaxis, yaxis, bins=10, xr=(0, 1), yr=(0, 1), size=520, title=None):
    Image, ImageDraw = _pil()
    im = Image.new("RGB", (size, size), BG)
    d = ImageDraw.Draw(im)
    x0, y0, w, h = 60, 40, size - 90, size - 100
    counts = [[0] * bins for _ in range(bins)]
    for pt in points:
        if pt is None or pt[0] is None or pt[1] is None:
            continue
        i = int((pt[0] - xr[0]) / float(xr[1] - xr[0]) * bins)
        j = int((pt[1] - yr[0]) / float(yr[1] - yr[0]) * bins)
        counts[max(0, min(bins - 1, j))][max(0, min(bins - 1, i))] += 1
    vmax = max(max(r) for r in counts) or 1
    cw, ch = w / float(bins), h / float(bins)
    for j in range(bins):
        for i in range(bins):
            c = counts[j][i]
            if c:
                col = heat_colour(c / float(vmax))
                d.rectangle([x0 + i * cw, y0 + h - (j + 1) * ch, x0 + (i + 1) * cw, y0 + h - j * ch],
                            fill=col)
                d.text((x0 + i * cw + 3, y0 + h - (j + 1) * ch + 2), str(c), fill=(0, 0, 0))
    _frame(d, x0, y0, w, h, xaxis, yaxis, xr, yr, title)
    hit = sum(1 for r in counts for c in r if c)
    d.text((x0 + w - 150, 6), "bins hit: %d / %d" % (hit, bins * bins), fill=DIM)
    return im
def archive_grid(archive, size=520, title=None):
    Image, ImageDraw = _pil()
    im = Image.new("RGB", (size, size), BG)
    d = ImageDraw.Draw(im)
    x0, y0, w, h = 60, 40, size - 90, size - 100
    b = archive.bins
    cw, ch = w / float(b), h / float(b)
    fits = [e.fitness for _, e in archive.elites(True)]
    lo, hi = (min(fits), max(fits)) if fits else (0, 1)
    for i in range(b):
        for j in range(b):
            e = archive.elite((i, j), True)
            box = [x0 + i * cw + 1, y0 + h - (j + 1) * ch + 1, x0 + (i + 1) * cw - 1, y0 + h - j * ch - 1]
            if e is not None:
                t = (e.fitness - lo) / float(hi - lo) if hi > lo else 1.0
                d.rectangle(box, fill=heat_colour(t))
                d.text((box[0] + 3, box[1] + 3), "%.2f" % e.fitness, fill=(0, 0, 0))
            elif archive.elite((i, j), False) is not None:
                d.rectangle(box, fill=(70, 70, 80))
    ax = archive.axes
    _frame(d, x0, y0, w, h, ax[0], ax[1], (0, 1), (0, 1),
           title or "archive %dx%d - coverage %.0f%%" % (b, b, 100 * archive.coverage()))
    return im
