import colorsys
import json
import os
from studio.editor import geometry as geo
HERE = os.path.dirname(os.path.abspath(__file__))
def load(path=None):
    with open(path or os.path.join(HERE, "lessons.json"), encoding="utf-8") as h:
        return json.load(h)["lessons"]
LESSONS = load()
def get(lesson_id):
    return next(l for l in LESSONS if l["id"] == lesson_id)
def layout_of(lesson):
    from studio.editor.document import empty_layout
    m = lesson["map"]
    out = empty_layout()
    out["name"] = "Lesson: %s" % lesson["title"]
    out["level"] = m.get("level", "empty")
    out["budget"] = 150
    out["pieces"] = [{"kind": "box", "tex": t, "x": x, "y": y, "z": z, "w": w, "h": h, "d": d,
                      "yaw": 0, "tag": "lesson"} for x, y, z, w, h, d, t in m.get("pieces", [])]
    sx, sy, sz = m.get("spawn", (0, 0, 0))
    out["spawns"] = [{"x": sx, "y": sy, "z": sz, "yaw": 180}]
    return out
def notes_of(lesson):
    return [{"id": k + 1, "x": x, "y": y, "z": z, "text": t}
            for k, (x, y, z, t) in enumerate(lesson["map"].get("notes", []))]
def _camera_near(p, state):
    eye = state.get("eye")
    if eye is None:
        return False, "Fly closer"
    d = sum((a - b) ** 2 for a, b in zip(eye, p["point"])) ** 0.5
    return d <= p["within"], "%d m to go" % max(0, round((d - p["within"]) / 100.0))
def _reach(p, state):
    from studio.toolbox import measure
    doc = state["doc"]
    layout = doc.to_layout()
    spawns = layout.get("spawns") or []
    if not spawns:
        return False, "No spawn"
    s = spawns[0]
    m = measure.path(layout, (s["x"], s.get("y", 0), s["z"]), tuple(p["to"]))
    return bool(m.ok), ("Mario gets there!" if m.ok else "Mario can't get there yet")
def _used(p, state):
    used = set(state.get("used") or ())
    ok = any(a in used for a in p["any"])
    return ok, "" if ok else "Try %s" % p["any"][0]
def _colour_word(tex):
    try:
        from mapgen import kit
        r, g, b = kit.colours()[tex]
    except Exception:
        return "other"
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
    if s < 0.18 or l < 0.12:
        return "grey"
    deg = h * 360
    if 70 <= deg <= 170:
        return "green"
    return "other"
def _colour(p, state):
    doc = state["doc"]
    x0, x1, y0, y1, z0, z1 = p["box"]
    hits = []
    for r in doc.refs("piece"):
        b = geo.aabb(doc.get(r))
        cx, cy, cz = (b[0] + b[1]) / 2, (b[2] + b[3]) / 2, (b[4] + b[5]) / 2
        if x0 <= cx <= x1 and y0 <= cy <= y1 and z0 <= cz <= z1 and \
                ("above" not in p or b[2] >= p["above"] - 1):
            hits.append(_colour_word(doc.get(r).get("tex")))
    if not hits:
        return False, "Nothing there to paint"
    share = hits.count(p["want"]) / float(len(hits))
    return share >= p["share"], "%d%% %s" % (round(share * 100), p["want"])
def _symmetry(p, state):
    sym = (state["doc"].meta.get("symmetry") or {})
    on = bool(sym) and sym.get("mode") not in (None, "off")
    return on, "Symmetry is %s" % ("on" if on else "off (Shift+S)")
def _balanced(p, state):
    doc = state["doc"]
    k = 0 if p.get("axis", "x") == "x" else 2
    at = p.get("at", 0)
    left = right = 0
    for r in doc.refs("piece"):
        it = doc.get(r)
        if it.get("tag") == "lesson":
            continue
        c = (it["x"], it["y"], it["z"])[k]
        if c < at - 1:
            left += 1
        elif c > at + 1:
            right += 1
    ok = left == right and left >= p.get("min", 1)
    return ok, "%d left, %d right" % (left, right)
def _tagged(p, state):
    doc = state["doc"]
    n = sum(1 for r in doc.refs("piece") if p["word"] in str(doc.get(r).get("tag", "")))
    return n >= p["min"], ""
def _mood(p, state):
    look = state["doc"].rest.get("look") or {}
    ok = bool(look.get("mood") or look.get("weather"))
    return ok, "" if ok else "Pick a weather and mood"
def _walked(p, state):
    n = state.get("walked", 0)
    return n >= p["units"], "%d of %d m walked" % (n // 100, p["units"] // 100)
def _all(p, state):
    lines = []
    for sub in p["of"]:
        ok, line = run_check(sub, state)
        if not ok:
            return False, line
        lines.append(line)
    return True, "; ".join(l for l in lines if l)
def _any(p, state):
    last = ""
    for sub in p["of"]:
        ok, last = run_check(sub, state)
        if ok:
            return True, last
    return False, last
CHECKS = {"camera_near": _camera_near, "reach": _reach, "used": _used, "colour": _colour,
          "symmetry": _symmetry, "balanced": _balanced, "tagged": _tagged, "mood": _mood,
          "walked": _walked, "all": _all, "any": _any}
def run_check(p, state):
    try:
        return CHECKS[p["name"]](p, state)
    except Exception as why:
        return False, "can't tell yet (%s)" % why
def check(lesson, state):
    return run_check(lesson["check"], state)
