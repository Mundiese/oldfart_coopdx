import math
from . import vec
SIDES = {
    "front": (0.0, 0.0),
    "back": (180.0, 0.0),
    "right": (90.0, 0.0),
    "left": (270.0, 0.0),
    "top": (0.0, 90.0),
    "bottom": (180.0, -90.0),
}
OPPOSITE = {"front": "back", "back": "front", "right": "left", "left": "right",
            "top": "bottom", "bottom": "top"}
LABELS = {"front": "Front", "back": "Back", "right": "Right", "left": "Left",
          "top": "Top", "bottom": "Bottom", "user": "User"}
PITCH_LIMIT = 90.0
class Camera:
    def __init__(self, target=(0.0, 0.0, 0.0), yaw=35.0, pitch=30.0, distance=9000.0,
                 ortho=False, fov=50.0, ortho_size=None):
        self.target = tuple(float(v) for v in target)
        self.yaw = float(yaw)
        self.pitch = float(pitch)
        self.distance = float(distance)
        self.ortho = bool(ortho)
        self.fov = float(fov)
        self.ortho_size = float(ortho_size if ortho_size is not None else self.matched_ortho_size())
        self.side = "user"
    def copy(self):
        c = Camera(self.target, self.yaw, self.pitch, self.distance, self.ortho, self.fov,
                   self.ortho_size)
        c.side = self.side
        return c
    def state(self):
        return {"target": list(self.target), "yaw": self.yaw, "pitch": self.pitch,
                "distance": self.distance, "ortho": self.ortho, "fov": self.fov,
                "ortho_size": self.ortho_size, "side": self.side}
    @classmethod
    def from_state(cls, s):
        c = cls(s["target"], s["yaw"], s["pitch"], s["distance"], s["ortho"], s.get("fov", 50.0),
                s.get("ortho_size"))
        c.side = s.get("side", "user")
        return c
    def matched_ortho_size(self):
        return self.distance * math.tan(math.radians(self.fov) / 2.0)
    def direction(self):
        y, p = math.radians(self.yaw), math.radians(self.pitch)
        return (math.cos(p) * math.sin(y), math.sin(p), math.cos(p) * math.cos(y))
    def basis(self):
        y = math.radians(self.yaw)
        right = (math.cos(y), 0.0, -math.sin(y))
        forward = vec.mul(self.direction(), -1.0)
        up = vec.cross(right, forward)
        return right, vec.norm(up), forward
    def eye(self):
        return vec.add(self.target, vec.mul(self.direction(), self.distance))
    def clip(self, scene_radius=20000.0):
        if self.ortho:
            reach = 4.0 * scene_radius + 1000.0
            return -reach, self.distance + reach
        near = max(2.0, self.distance * 0.002)
        far = self.distance + 4.0 * scene_radius + 100000.0
        return near, far
    def view_matrix(self):
        right, up, forward = self.basis()
        return vec.look_basis(self.eye(), right, up, forward)
    def projection_matrix(self, aspect, scene_radius=20000.0):
        near, far = self.clip(scene_radius)
        if self.ortho:
            return vec.orthographic(self.ortho_size * aspect, self.ortho_size, near, far)
        return vec.perspective(self.fov, aspect, near, far)
    def view_projection(self, aspect, scene_radius=20000.0):
        return vec.matmul(self.projection_matrix(aspect, scene_radius), self.view_matrix())
    def ndc(self, px, py, width, height):
        return (2.0 * px / width - 1.0, 1.0 - 2.0 * py / height)
    def ray(self, px, py, width, height, scene_radius=20000.0):
        nx, ny = self.ndc(px, py, width, height)
        aspect = width / float(max(1, height))
        right, up, forward = self.basis()
        if self.ortho:
            near, _ = self.clip(scene_radius)
            origin = vec.add(self.eye(), vec.add(vec.mul(right, nx * self.ortho_size * aspect),
                                                 vec.mul(up, ny * self.ortho_size)))
            origin = vec.add(origin, vec.mul(forward, near))
            return origin, forward
        t = math.tan(math.radians(self.fov) / 2.0)
        d = vec.add(forward, vec.add(vec.mul(right, nx * t * aspect), vec.mul(up, ny * t)))
        return self.eye(), vec.norm(d)
    def to_pixel(self, p, width, height):
        m = self.view_projection(width / float(max(1, height)))
        q = vec.project(m, p)
        if q is None:
            return None
        return ((q[0] + 1.0) * 0.5 * width, (1.0 - q[1]) * 0.5 * height, (q[2] + 1.0) * 0.5)
    def units_per_pixel(self, p, height):
        if self.ortho:
            return 2.0 * self.ortho_size / max(1, height)
        depth = vec.dot(vec.sub(p, self.eye()), self.basis()[2])
        depth = max(depth, 1.0)
        return 2.0 * depth * math.tan(math.radians(self.fov) / 2.0) / max(1, height)
    def orbit(self, d_yaw, d_pitch):
        self.yaw = (self.yaw + d_yaw) % 360.0
        self.pitch = max(-PITCH_LIMIT, min(PITCH_LIMIT, self.pitch + d_pitch))
        if d_yaw or d_pitch:
            self.side = "user"
    def pan_pixels(self, dx, dy, height):
        right, up, _ = self.basis()
        upp = self.units_per_pixel(self.target, height)
        self.target = vec.add(self.target, vec.add(vec.mul(right, -dx * upp), vec.mul(up, dy * upp)))
    def zoom(self, steps, factor=1.2, anchor=None, min_distance=50.0, max_distance=400000.0):
        k = factor ** (-steps)
        old_dist, old_size = self.distance, self.ortho_size
        if self.ortho:
            self.ortho_size = max(20.0, min(max_distance, self.ortho_size * k))
            real = self.ortho_size / old_size
        else:
            self.distance = max(min_distance, min(max_distance, self.distance * k))
            real = self.distance / old_dist
        if anchor is not None:
            self.target = vec.add(anchor, vec.mul(vec.sub(self.target, anchor), real))
    def fly_look(self, d_yaw, d_pitch):
        eye = self.eye()
        self.yaw = (self.yaw - d_yaw) % 360.0
        self.pitch = max(-PITCH_LIMIT, min(PITCH_LIMIT, self.pitch + d_pitch))
        self.target = vec.add(eye, vec.mul(self.direction(), -self.distance))
        if d_yaw or d_pitch:
            self.side = "user"
    def fly_move(self, right, up, forward):
        r, _, f = self.basis()
        step = vec.add(vec.add(vec.mul(r, right), (0.0, float(up), 0.0)), vec.mul(f, forward))
        self.target = vec.add(self.target, step)
    def dolly(self, amount):
        _, _, forward = self.basis()
        self.target = vec.add(self.target, vec.mul(forward, amount))
    def set_side(self, side, ortho=True):
        self.yaw, self.pitch = SIDES[side]
        self.side = side
        if ortho is not None:
            self.set_ortho(ortho)
    def opposite(self):
        if self.side in OPPOSITE:
            self.set_side(OPPOSITE[self.side], ortho=None)
        else:
            self.yaw = (self.yaw + 180.0) % 360.0
            self.pitch = -self.pitch
    def set_ortho(self, ortho):
        if ortho and not self.ortho:
            self.ortho_size = self.matched_ortho_size()
        elif not ortho and self.ortho:
            self.distance = self.ortho_size / math.tan(math.radians(self.fov) / 2.0)
        self.ortho = bool(ortho)
    def frame(self, lo, hi, aspect=1.0, margin=1.15):
        centre = vec.mul(vec.add(lo, hi), 0.5)
        radius = max(100.0, vec.length(vec.sub(hi, lo)) * 0.5) * margin
        self.target = centre
        fit_h = radius
        if aspect < 1.0:
            fit_h = radius / max(aspect, 0.1)
        self.ortho_size = fit_h
        self.distance = fit_h / math.sin(math.radians(self.fov) / 2.0)
        corners = [(x, y, z) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
        fill = 1.0 / margin
        for _ in range(16):
            m = self.view_projection(aspect, radius)
            worst = 0.0
            for c in corners:
                q = vec.project(m, c)
                if q is None:
                    worst = 2.0
                    break
                worst = max(worst, abs(q[0]), abs(q[1]))
            k = worst / fill
            if worst <= 0.0 or abs(k - 1.0) < 0.01:
                break
            if self.ortho:
                self.ortho_size *= k
            else:
                self.distance = max(radius * 0.25, self.distance * (0.5 + 0.5 * k))
        if self.ortho:
            self.distance = max(self.distance, radius * 2.0)
        else:
            self.ortho_size = self.matched_ortho_size()
    def label(self):
        if self.side not in LABELS or self.side == "user":
            return "3D view (flat)" if self.ortho else "3D view"
        return LABELS[self.side] + ("" if self.ortho else " (3D)")
def blend(a, b, t):
    c = b.copy()
    c.target = vec.lerp(a.target, b.target, t)
    c.yaw = vec.angle_lerp(a.yaw, b.yaw, t) % 360.0
    c.pitch = a.pitch + (b.pitch - a.pitch) * t
    c.distance = a.distance + (b.distance - a.distance) * t
    c.ortho_size = a.ortho_size + (b.ortho_size - a.ortho_size) * t
    c.ortho = b.ortho if t >= 0.5 else a.ortho
    return c
NUMPAD = {
    "1": ("side", "front"), "3": ("side", "right"), "7": ("side", "top"),
    "ctrl+1": ("side", "back"), "ctrl+3": ("side", "left"), "ctrl+7": ("side", "bottom"),
    "5": ("toggle_ortho", None), "9": ("opposite", None),
    "2": ("orbit", (0.0, -15.0)), "8": ("orbit", (0.0, 15.0)),
    "4": ("orbit", (15.0, 0.0)), "6": ("orbit", (-15.0, 0.0)),
    ".": ("frame_selected", None), "+": ("zoom", 1), "-": ("zoom", -1),
}
def apply_numpad(cam, key, step_deg=15.0, auto_perspective=True, was_persp=None):
    action = NUMPAD.get(key)
    if action is None:
        return None
    name, arg = action
    if name == "side":
        cam.set_side(arg, ortho=True if auto_perspective else None)
    elif name == "toggle_ortho":
        cam.set_ortho(not cam.ortho)
    elif name == "opposite":
        cam.opposite()
    elif name == "orbit":
        dy, dp = arg
        scale = step_deg / 15.0
        cam.orbit(dy * scale, dp * scale)
        if auto_perspective and cam.ortho and was_persp:
            cam.set_ortho(False)
    elif name == "zoom":
        cam.zoom(arg)
    return name
