import math
EYES_MAX = 48
def thin(cells, most=EYES_MAX):
    cells = sorted(cells)
    if len(cells) <= most:
        return cells
    step = len(cells) / float(most)
    return [cells[int(i * step)] for i in range(most)]
def sees(heights, eye_cell, eye_y, cell, y):
    (i0, j0), (i1, j1) = eye_cell, cell
    n = max(abs(i1 - i0), abs(j1 - j0))
    for k in range(1, n):
        t = k / float(n)
        c = (int(round(i0 + (i1 - i0) * t)), int(round(j0 + (j1 - j0) * t)))
        if c == cell or c == eye_cell:
            continue
        h = heights.get(c)
        if h is not None and h > eye_y + (y - eye_y) * t:
            return False
    return True
def counts(heights, eyes, targets, eye=1, rise=6):
    out = {}
    for key, cell in targets.items():
        y = heights.get(cell, 0) + rise
        out[key] = sum(1 for e in eyes if sees(heights, e, heights.get(e, 0) + eye, cell, y))
    return out
def hidden_near(heights, eyes, cells, near, eye=1, rise=1):
    out = []
    for c in cells:
        d = min((math.hypot(c[0] - e[0], c[1] - e[1]) for e in eyes), default=1e9)
        if d > near:
            continue
        y = heights.get(c, 0) + rise
        out.append((sum(1 for e in eyes if sees(heights, e, heights.get(e, 0) + eye, c, y)),
                    d, c))
    out.sort()
    return [c for _, _, c in out]
