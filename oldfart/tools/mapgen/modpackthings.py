import os
import re
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SPAWNER = os.path.join(REPO, "of_spawner.lua")
STANDING_REACH = 20000
WAYS = {
    "onoff": "onoff", "onoffswitch": "onoff", "onoffred": "onoff", "onoffblue": "onoff",
    "logic": "logic", "lgtarget": "logic", "lgbutton": "logic", "lgzone": "logic",
    "racestart": "track", "racegate": "track", "racefinish": "track",
    "racebox": "mode", "raceboost": "mode", "racecoin": "mode", "racerespawn": "mode",
    "raceout": "mode",
    "soundspot": "sound", "stage": "stage", "triblock": "tri", "ball": "ball",
}
CARRIED = ("spawn", "onoff", "logic", "track", "sound", "stage", "tri", "ball")
LOGIC = {"lgtarget": "target", "lgbutton": "button", "lgzone": "zone"}
LOGIC_VARIANT = {1: "target", 2: "button", 3: "zone"}
ONOFF = {"onoffswitch": 0, "onoffred": 1, "onoffblue": 2}
RACER = {"racestart": 1, "racegate": 2, "racefinish": 3}
ACTORS = {"tri": ("actors/of_triblock_geo.bin", "actors/of_triblock_col.col"),
          "ball": ("actors/of_ball_geo.bin",)}
class ThingError(ValueError):
    pass
_cache = {}
def _code(text):
    out = []
    for line in text.splitlines():
        at = line.find("--")
        out.append(line if at < 0 else line[:at])
    return "\n".join(out)
def _constants(code):
    out = {}
    for m in re.finditer(r"^\s*(?:local\s+)?((?:spawner\.)?[A-Z][A-Z0-9_]*(?:\s*,\s*(?:spawner\.)?"
                         r"[A-Z][A-Z0-9_]*)*)\s*=\s*([-0-9xA-Fa-f, ]+)$", code, re.M):
        names = [n.strip() for n in m.group(1).split(",")]
        values = [v.strip() for v in m.group(2).split(",")]
        if len(names) != len(values):
            continue
        for n, v in zip(names, values):
            try:
                out[n] = int(v, 0)
            except ValueError:
                pass
    return out
def _value(text, consts):
    text = (text or "").strip()
    if text in consts:
        return consts[text]
    if text == "STANDING_REACH":
        return STANDING_REACH
    try:
        return int(text, 0)
    except ValueError:
        try:
            return float(text)
        except ValueError:
            return None
def _block(code, start):
    depth = 0
    for i in range(start, len(code)):
        ch = code[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return code[start:i + 1]
    return code[start:]
def _fields(body, consts):
    out = {}
    i, depth, n = 1, 0, len(body) - 1
    while i < n:
        m = re.compile(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*").match(body, i)
        if not m:
            i += 1
            continue
        name, j = m.group(1), m.end()
        if j < n and body[j] == "{":
            inner = _block(body, j)
            out[name] = inner
            i = j + len(inner)
        elif j < n and body[j] == '"':
            k = body.find('"', j + 1)
            out[name] = body[j + 1:k]
            i = k + 1
        else:
            k = j
            depth = 0
            while k < n and not (body[k] == "," and depth == 0):
                if body[k] in "({":
                    depth += 1
                elif body[k] in ")}":
                    depth -= 1
                k += 1
            out[name] = body[j:k].strip()
            i = k + 1
    return out
def spawner_rows(text=None):
    default = text is None
    if default and "rows" in _cache:
        return _cache["rows"]
    if default:
        with open(SPAWNER, encoding="utf-8") as handle:
            text = handle.read()
    code = _code(text)
    consts = _constants(code)
    rows = {}
    for m in re.finditer(r'\{\s*key\s*=\s*"([A-Za-z0-9_]+)"\s*,\s*name\s*=\s*"', code):
        key = m.group(1)
        if key in rows:
            continue
        f = _fields(_block(code, m.start()), consts)
        row = {"key": key, "name": f.get("name", key)}
        for name in ("bhv", "model"):
            if name in f:
                row[name] = f[name].strip()
        for name, out in (("params", "params"), ("variant", "second"), ("reach", "reach"),
                          ("action", "action"), ("racer", "racer")):
            if name in f:
                v = _value(f[name], consts)
                if v is not None:
                    row[out] = v
        if f.get("settle") in ("settle_log", "settle_lift"):
            row["settle"] = f["settle"][len("settle_"):]
        if f.get("pipe") == "true":
            row["pipe"] = True
        if f.get("logic") == "true":
            row["logic"] = True
        comp = f.get("companion")
        if comp:
            cf = _fields(comp, consts)
            row["companion"] = {"bhv": cf.get("bhv", "").strip(), "model": cf.get("model", "").strip()}
            if "second" in cf:
                row["companion"]["second"] = _value(cf["second"], consts)
        if f.get("variants"):
            vs = []
            body = f["variants"]
            for vm in re.finditer(r"\{[^{}]*\}", body[1:-1]):
                vf = _fields(vm.group(0), consts)
                v = {"name": vf.get("name", "")}
                for name in ("value", "first", "mask"):
                    if name in vf:
                        v[name] = _value(vf[name], consts)
                if "model" in vf:
                    v["model"] = vf["model"].strip()
                vs.append(v)
            row["variants"] = vs
        rows[key] = row
    if default:
        _cache["rows"] = rows
    return rows
def sound_names(text=None):
    if text is None:
        with open(SPAWNER, encoding="utf-8") as handle:
            text = handle.read()
    m = re.search(r"spawner\.SOUND_SPOT_SOUNDS\s*=\s*\{([^}]*)\}", text)
    return re.findall(r'"([A-Z0-9_]+)"', m.group(1)) if m else []
def way(key):
    if key in WAYS:
        return WAYS[key]
    row = spawner_rows().get(key)
    if row and str(row.get("bhv", "")).startswith("id_bhv") \
            and str(row.get("model", "")).startswith("E_MODEL_"):
        return "spawn"
    return None
def _num(v):
    v = float(v or 0)
    return int(v) if v == int(v) else round(v, 2)
def _variant(row, o):
    vs = row.get("variants") or []
    if not vs:
        return None
    try:
        i = int(o.get("variant") or 1)
    except (TypeError, ValueError):
        i = 1
    return vs[i - 1] if 1 <= i <= len(vs) else vs[0]
def made(row, o):
    v = _variant(row, o)
    second = v.get("value") if v else row.get("second")
    first = v.get("first") if v else None
    mask = v.get("mask") if v else None
    params = row.get("params")
    if any(isinstance(x, int) for x in (second, first, mask)):
        params = 0
        if isinstance(second, int):
            params += (second & 0xFF) << 16
        if isinstance(mask, int):
            params += (mask & 0xFF) << 8
        if isinstance(first, int):
            params += (first & 0xFF) << 24
    model = (v.get("model") if v else None) or row.get("model")
    return model, second if isinstance(second, int) else None, params
def _place(o):
    return [_num(o.get("x")), _num(o.get("y")), _num(o.get("z")), _num(o.get("yaw", 0))]
def spawn_row(key, o):
    row = spawner_rows()[key]
    model, second, params = made(row, o)
    out = {"kind": "spawn", "key": key, "at": _place(o), "bhv": row["bhv"], "model": model}
    if second is not None:
        out["second"] = second
    if isinstance(params, int):
        out["params"] = params
    for name in ("reach", "action", "settle"):
        if row.get(name) is not None:
            out[name] = row[name]
    if o.get("pitch"):
        out["pitch"] = _num(o["pitch"])
    if row.get("companion") and row["companion"].get("bhv"):
        out["friend"] = dict(row["companion"])
    if row.get("pipe"):
        p = o.get("pipe") if isinstance(o.get("pipe"), dict) else {}
        out["pipe"] = {k: int(p[k]) for k in ("kind", "level", "area", "tag", "pair")
                       if isinstance(p.get(k), (int, float))}
    return out
def things(arena, notes):
    rows, pieces, actors, counts = [], [], [], {}
    racers = []
    sounds = None
    for o in arena.get("objects") or []:
        key = str(o.get("key") or "")
        w = way(key)
        if w is None:
            raise ThingError("the %s at x %s, z %s is a kind of thing this export does not know "
                             "yet - take it out of the map or tell the Studio's makers"
                             % (key or "object", _num(o.get("x")), _num(o.get("z"))))
        counts[w] = counts.get(w, 0) + 1
        if w == "mode":
            continue
        if w == "logic":
            kind = LOGIC.get(key)
            if kind is None:
                try:
                    kind = LOGIC_VARIANT.get(int(o.get("variant") or 1), "target")
                except (TypeError, ValueError):
                    kind = "target"
            pieces.append([kind, _num(o.get("x")), _num(o.get("y")), _num(o.get("z")),
                           _num(o.get("yaw", 0)), int(o.get("link") or 1)])
            continue
        if w == "track":
            racers.append(o)
            continue
        if w == "spawn":
            rows.append(spawn_row(key, o))
            continue
        row = {"kind": w, "key": key, "at": _place(o)}
        if w == "onoff":
            if key in ONOFF:
                row["what"] = ONOFF[key]
            else:
                v = _variant(spawner_rows()["onoff"], o)
                row["what"] = int(v.get("value") or 0) if v else 0
        elif w == "sound":
            if sounds is None:
                sounds = sound_names()
            v = _variant(spawner_rows()["soundspot"], o)
            n = int(v.get("value") or 1) if v else 1
            row["sound"] = sounds[n - 1] if 1 <= n <= len(sounds) else sounds[0]
        elif w == "stage":
            v = _variant(spawner_rows()["stage"], o) or {}
            row["shape"] = int(v.get("value") or 0)
            row["motion"] = int(v.get("first") or 0)
            row["model"] = v.get("model") or "E_MODEL_CHECKERBOARD_PLATFORM"
        rows.append(row)
        for a in ACTORS.get(w, ()):
            if a not in actors:
                actors.append(a)
    tracks, shell = speedrun_tracks(racers)
    if shell:
        counts["mode"] = counts.get("mode", 0) + shell
    return rows, pieces, tracks, actors, counts
def speedrun_tracks(racers):
    by = {}
    for o in racers:
        try:
            n = max(1, int(o.get("track") or 1))
        except (TypeError, ValueError):
            n = 1
        by.setdefault(n, []).append(o)
    out, shell = [], 0
    for n in sorted(by):
        group = by[n]
        starts = [o for o in group if o.get("key") == "racestart"]
        meta = {}
        if starts:
            meta = starts[0].get("track_meta") or starts[0].get("meta") or {}
            if not isinstance(meta, dict):
                meta = {}
        if meta.get("kind") == "race":
            shell += len(group)
            continue
        if not starts:
            continue
        gates, next_order = [], 0
        for o in group:
            if o.get("key") != "racegate":
                continue
            order = o.get("order", (o.get("forge") or {}).get("byte"))
            try:
                order = int(order)
            except (TypeError, ValueError):
                order = None
            if not order:
                order = next_order + 1
            next_order = max(next_order, order)
            gates.append((order, o))
        gates.sort(key=lambda g: g[0])
        finish = next((o for o in group if o.get("key") == "racefinish"), None)
        s = starts[0]
        name = str(meta.get("name") or "").strip() or "Track %d" % n
        track = {"track": n, "name": name, "start": _place(s),
                 "gates": [_place(o)[:3] for _, o in gates]}
        if finish is not None:
            track["finish"] = _place(finish)[:3]
        out.append(track)
    return out, shell
