from . import kit
C = 200
EAVE_T = 40
RIDGE_T = 20
RIDGE_W = 60
FINIAL_H = 300
FINIAL_W = 60
FORMS = ("gable", "hip", "pyramid", "cap", "shed")
PITCHES = {"low": 0.25, "steep": 0.5, "tower": 1.0}
class Spec(tuple):
    __slots__ = ()
    def __new__(cls, kind, tex, x0, x1, y0, y1, z0, z1, rises=None, word="roof"):
        return tuple.__new__(cls, (kind, tex, x0, x1, y0, y1, z0, z1, rises, word))
    @property
    def kind(self):
        return self[0]
    @property
    def word(self):
        return self[9]
def rise(span, pitch="low"):
    k = PITCHES.get(pitch, PITCHES["low"])
    return max(C, int(span * k) // 50 * 50)
def outline(x0, x1, z0, z1, form, along=None, eave=200, gable=100, cut=()):
    cut = set(cut or ())
    if form == "gable":
        along = along or ("x" if x1 - x0 >= z1 - z0 else "z")
        ex, ez = (gable, eave) if along == "x" else (eave, gable)
    else:
        ex = ez = eave
    return (x0 - (0 if "x0" in cut else ex), x1 + (0 if "x1" in cut else ex),
            z0 - (0 if "z0" in cut else ez), z1 + (0 if "z1" in cut else ez))
def pieces(form, tex, x0, x1, z0, z1, y, along=None, pitch="low", trim=None,
           board=True, ridge_cap=False, finial=None, toward="-z", height=None):
    w, d = x1 - x0, z1 - z0
    out = []
    if w <= 0 or d <= 0 or not tex:
        return out, y
    if board and trim:
        out.append(Spec("box", trim, x0, x1, y, y + EAVE_T, z0, z1, None, "trim.eave"))
        y += EAVE_T
    if form == "pyramid" and w != d:
        form = "hip"
    if form == "hip" and w == d:
        form = "pyramid"
    if form == "shed":
        h = height or rise(d if toward in ("-z", "+z") else w, pitch)
        out.append(Spec("ramp", tex, x0, x1, y, y + h, z0, z1, toward, "roof"))
        return out, y + h
    if form in ("pyramid", "cap"):
        h = height or rise(min(w, d), "tower" if form == "cap" else pitch)
        out.append(Spec("pyramid", tex, x0, x1, y, y + h, z0, z1, "x", "roof"))
        top = y + h
        if form == "cap" and finial:
            cx, cz = (x0 + x1) // 2, (z0 + z1) // 2
            out.append(Spec("pole", finial, cx - FINIAL_W // 2, cx + FINIAL_W // 2, top,
                            top + FINIAL_H, cz - FINIAL_W // 2, cz + FINIAL_W // 2, None,
                            "finial.post"))
        return out, top
    along = along or ("x" if w >= d else "z")
    span = d if along == "x" else w
    h = height or rise(span, pitch)
    top = y + h
    if form == "hip" and (w if along == "x" else d) > span:
        half = span // 2
        if along == "x":
            zc = z0 + half
            if x1 - half > x0 + half:
                out.append(Spec("ridge", tex, x0 + half, x1 - half, y, top, z0, z1, "x", "roof"))
            out += [Spec("outer", tex, x0, x0 + half, y, top, z0, zc, "+x+z", "roof"),
                    Spec("outer", tex, x0, x0 + half, y, top, zc, z1, "+x-z", "roof"),
                    Spec("outer", tex, x1 - half, x1, y, top, z0, zc, "-x+z", "roof"),
                    Spec("outer", tex, x1 - half, x1, y, top, zc, z1, "-x-z", "roof")]
            r0, r1 = x0 + half, x1 - half
        else:
            xc = x0 + half
            if z1 - half > z0 + half:
                out.append(Spec("ridge", tex, x0, x1, y, top, z0 + half, z1 - half, "z", "roof"))
            out += [Spec("outer", tex, x0, xc, y, top, z0, z0 + half, "+x+z", "roof"),
                    Spec("outer", tex, xc, x1, y, top, z0, z0 + half, "-x+z", "roof"),
                    Spec("outer", tex, x0, xc, y, top, z1 - half, z1, "+x-z", "roof"),
                    Spec("outer", tex, xc, x1, y, top, z1 - half, z1, "-x-z", "roof")]
            r0, r1 = z0 + half, z1 - half
    else:
        out.append(Spec("ridge", tex, x0, x1, y, top, z0, z1, along, "roof"))
        r0, r1 = (x0, x1) if along == "x" else (z0, z1)
    if ridge_cap and trim and r1 - r0 >= C:
        if along == "x":
            zc = (z0 + z1) // 2
            out.append(Spec("box", trim, r0, r1, top, top + RIDGE_T, zc - RIDGE_W // 2,
                            zc + RIDGE_W // 2, None, "trim.ridge"))
        else:
            xc = (x0 + x1) // 2
            out.append(Spec("box", trim, xc - RIDGE_W // 2, xc + RIDGE_W // 2, top,
                            top + RIDGE_T, r0, r1, None, "trim.ridge"))
    return out, top
def make(spec, tag):
    kind, tex, x0, x1, y0, y1, z0, z1, rises, word = spec
    return kit.kind(kind).make(tex, x0, x1, y0, y1, z0, z1, rises, "%s.%s" % (tag, word))
def build(form, tex, x0, x1, z0, z1, y, tag="roof", **kw):
    specs, top = pieces(form, tex, x0, x1, z0, z1, y, **kw)
    return [make(s, tag) for s in specs], top
def form_for(w, d, culture=None, r=None):
    if culture == "rooftropic":
        return "pyramid" if w == d else "hip"
    if culture == "roofeast":
        return "hip"
    return "gable"
