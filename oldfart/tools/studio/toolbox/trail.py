import os
from studio.toolbox import overlays
START = (0.30, 0.85, 0.45, 1.0)
END = (0.95, 0.28, 0.25, 1.0)
def sav_dirs(env=None):
    env = os.environ if env is None else env
    out = [os.path.expanduser("~/.local/share/sm64coopdx/sav"),
           os.path.expanduser("~/Library/Application Support/sm64coopdx/sav")]
    if env.get("XDG_DATA_HOME"):
        out.insert(0, os.path.join(env["XDG_DATA_HOME"], "sm64coopdx", "sav"))
    if env.get("APPDATA"):
        out.append(os.path.join(env["APPDATA"], "sm64coopdx", "sav"))
    return out
def read_storage(path):
    out = {}
    section = None
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith(";"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    section = line[1:-1].strip().lower()
                    continue
                if section == "storage" and "=" in line:
                    k, v = line.split("=", 1)
                    out[k.strip()] = v.strip()
    except OSError:
        return {}
    return out
def points(storage, key):
    try:
        n = int(storage.get("trail_%s" % key, "0") or 0)
    except ValueError:
        return []
    out = []
    for i in range(1, n + 1):
        for part in (storage.get("trail_%s_%d" % (key, i)) or "").split(";"):
            bits = part.split(",")
            if len(bits) != 3:
                continue
            try:
                out.append(tuple(float(b) for b in bits))
            except ValueError:
                continue
    return out
def find(keys, dirs=None):
    files = []
    for d in dirs if dirs is not None else sav_dirs():
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for name in names:
            if name.endswith(".sav"):
                p = os.path.join(d, name)
                files.append((os.path.getmtime(p), p))
    for _, path in sorted(files, reverse=True):
        st = read_storage(path)
        for key in [k for k in keys if k] + [st.get("trail_last")]:
            if key and points(st, key):
                return points(st, key), key, path
    return None, None, None
def layer(pts, title="Mario's trail"):
    lay = overlays.Layer("trail", title)
    if not pts:
        lay.note = "No trail: play the map (F6) and walk it, then show the trail again."
        return lay
    n = max(1, len(pts) - 1)
    for i in range(len(pts) - 1):
        rgba = overlays.ramp(i / float(n))[:3] + (0.95,)
        lay.line(pts[i], pts[i + 1], rgba, 3.0)
    lay.dot(pts[0], START, 7.0)
    lay.dot(pts[-1], END, 7.0)
    lay.label(pts[0], "start", START)
    lay.label(pts[-1], "end", END)
    lay.legend = [(START, "start"), (END, "end")]
    lay.facts = {"points": len(pts)}
    return lay
