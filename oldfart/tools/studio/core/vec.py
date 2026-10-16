import math
EPS = 1e-9
def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)
def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def length(a):
    return math.sqrt(dot(a, a))
def norm(a):
    n = length(a)
    if n < EPS:
        return (0.0, 0.0, 0.0)
    return (a[0] / n, a[1] / n, a[2] / n)
def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)
def identity():
    return [1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0]
def matmul(a, b):
    out = [0.0] * 16
    for r in range(4):
        for c in range(4):
            out[r * 4 + c] = (a[r * 4] * b[c] + a[r * 4 + 1] * b[4 + c]
                              + a[r * 4 + 2] * b[8 + c] + a[r * 4 + 3] * b[12 + c])
    return out
def transform(m, p, w=1.0):
    x, y, z = p
    return (m[0] * x + m[1] * y + m[2] * z + m[3] * w,
            m[4] * x + m[5] * y + m[6] * z + m[7] * w,
            m[8] * x + m[9] * y + m[10] * z + m[11] * w,
            m[12] * x + m[13] * y + m[14] * z + m[15] * w)
def project(m, p):
    x, y, z, w = transform(m, p)
    if w <= EPS:
        return None
    return (x / w, y / w, z / w)
def column_major(m):
    return [m[c * 4 + r] for r in range(4) for c in range(4)]
def look_basis(eye, right, up, forward):
    f = forward
    return [right[0], right[1], right[2], -dot(right, eye),
            up[0], up[1], up[2], -dot(up, eye),
            -f[0], -f[1], -f[2], dot(f, eye),
            0.0, 0.0, 0.0, 1.0]
def perspective(fov_y_deg, aspect, near, far):
    f = 1.0 / math.tan(math.radians(fov_y_deg) / 2.0)
    return [f / aspect, 0.0, 0.0, 0.0,
            0.0, f, 0.0, 0.0,
            0.0, 0.0, (far + near) / (near - far), 2.0 * far * near / (near - far),
            0.0, 0.0, -1.0, 0.0]
def orthographic(half_w, half_h, near, far):
    return [1.0 / half_w, 0.0, 0.0, 0.0,
            0.0, 1.0 / half_h, 0.0, 0.0,
            0.0, 0.0, -2.0 / (far - near), -(far + near) / (far - near),
            0.0, 0.0, 0.0, 1.0]
def yaw_turn(yaw_deg, p):
    s, c = math.sin(math.radians(yaw_deg)), math.cos(math.radians(yaw_deg))
    x, y, z = p
    return (x * c + z * s, y, -x * s + z * c)
def ease(t):
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3
def angle_lerp(a, b, t):
    d = (b - a + 180.0) % 360.0 - 180.0
    return a + d * t
def invert(m):
    a = [list(m[r * 4:r * 4 + 4]) + [1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]
    for col in range(4):
        pivot = max(range(col, 4), key=lambda r: abs(a[r][col]))
        if abs(a[pivot][col]) < 1e-18:
            return identity()
        a[col], a[pivot] = a[pivot], a[col]
        pv = a[col][col]
        a[col] = [v / pv for v in a[col]]
        for r in range(4):
            if r != col:
                f = a[r][col]
                if f:
                    a[r] = [x - f * y for x, y in zip(a[r], a[col])]
    return [a[r][4 + c] for r in range(4) for c in range(4)]
