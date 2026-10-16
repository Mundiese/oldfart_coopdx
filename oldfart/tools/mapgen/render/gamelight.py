import math
AMBIENT = 0x50
DIFFUSE = 0xE6
LIGHT_DIR = (0x00, 0x6E, 0x3F)
CUBE = (AMBIENT, DIFFUSE, LIGHT_DIR)
OLD_BLOCK = (63, 255, (40, 40, 40))
CALIBRATED = CUBE
PITCH = 20.0
SHADING = {
    None: ((255, 255, 255), (255, 255, 255)),
    "hard shadows": ((255, 255, 255), (25, 25, 30)),
    "a warm sun": ((255, 205, 130), (70, 80, 130)),
    "moonlight": ((150, 175, 255), (40, 45, 70)),
    "sickly": ((150, 255, 120), (110, 70, 110)),
    "a sunset": ((255, 150, 90), (100, 60, 90)),
    "a fluorescent office": ((235, 245, 255), (160, 170, 175)),
    "firelight": ((255, 170, 80), (60, 30, 25)),
}
AMBIENT_COLOUR_MIN = 40
def _norm(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v) if n > 1e-12 else (0.0, 0.0, 0.0)
def _dot(a, b):
    return sum(x * y for x, y in zip(a, b))
def camera_axes(yaw_deg, pitch_deg=PITCH):
    y, p = math.radians(yaw_deg), math.radians(pitch_deg)
    back = (math.cos(p) * math.sin(y), math.sin(p), math.cos(p) * math.cos(y))
    right = (math.cos(y), 0.0, -math.sin(y))
    up = (back[1] * right[2] - back[2] * right[1],
          back[2] * right[0] - back[0] * right[2],
          back[0] * right[1] - back[1] * right[0])
    return right, _norm(up), back
def piece_axes(yaw_deg):
    r = math.radians(yaw_deg or 0)
    c, s = math.cos(r), math.sin(r)
    return (c, 0.0, -s), (0.0, 1.0, 0.0), (s, 0.0, c)
def light_vector(hour=None, light=None):
    h = tuple(hour) if hour else (0.0, 0.0, 0.0)
    return tuple(d / 127.0 + o for d, o in zip((light or CUBE)[2], h))
def coeffs(cam, axes=None, size=None, hour=None, skew=False, light=None):
    right, up, back = cam
    l = light_vector(hour, light)
    w = tuple(l[0] * right[i] + l[1] * up[i] + l[2] * back[i] for i in range(3))
    axes = axes or piece_axes(0)
    o = tuple(_dot(a, w) for a in axes)
    if skew and size:
        o = tuple(c * s / 200.0 for c, s in zip(o, size))
    return _norm(o)
def real_normal(n_unit, size):
    return _norm(tuple(c / max(1e-6, s) for c, s in zip(n_unit, size)))
def shade(n_obj, cf, shading=None, light=None):
    lit, amb = SHADING.get(shading, SHADING[None])
    ambient, diffuse, _ = light or CUBE
    i = max(0.0, _dot(n_obj, cf))
    return tuple(min(255.0, ambient * amb[k] / 255.0 + i * diffuse * lit[k] / 255.0)
                 for k in range(3))
def grey(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
FACES = {"top": (0, 1, 0), "front": (0, 0, 1), "right": (1, 0, 0), "left": (-1, 0, 0),
         "back": (0, 0, -1), "bottom": (0, -1, 0)}
def box_faces(size=(200, 200, 200), hour=None, yaw=0.0, pitch=PITCH, skew=False,
              shading=None, light=None):
    cam = camera_axes(yaw, pitch)
    cf = coeffs(cam, piece_axes(0), size, hour, skew, light)
    return {name: grey(shade(real_normal(n, size), cf, shading, light))
            for name, n in FACES.items()}
L3_TOP_MIN = 230
L3_FRONT = (110, 220)
L3_SIDE_DARK = 90
def three_value(hour=None, shading=None, light=CALIBRATED):
    f = box_faces(hour=hour, shading=shading, light=light)
    ok = f["top"] >= L3_TOP_MIN and L3_FRONT[0] <= f["front"] <= L3_FRONT[1] \
        and f["front"] >= max(f["left"], f["right"]) - 0.5 \
        and min(f["left"], f["right"]) <= L3_SIDE_DARK
    return ok, f
def ambient_ok(shading):
    if shading is None:
        return True
    _, amb = SHADING.get(shading, SHADING[None])
    return grey(amb) >= AMBIENT_COLOUR_MIN
