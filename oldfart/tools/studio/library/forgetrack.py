import json
import math
import os
import re
import shutil
import sys
KEEP_PART = 1000
KEEP_PARTS = 12
KEEP_LEVELS = 40
INDEX_KEY = "fkindex"
RACE_INDEX = "fkrace"
RACER_KEYS = {"racestart": 1, "racegate": 2, "racefinish": 3, "racebox": 4, "raceboost": 5,
              "racecoin": 6, "racerespawn": 7, "raceout": 8}
RACER_GATES_FEWEST = 3
TRACK_SPEEDRUN, TRACK_RACE = "speedrun", "race"
TRACK_MOST = 9
TRACK_NAME_MOST = 20
TRACK_LAPS_MOST = 9
TRACK_LAPS = 3
SHIPPED_NAME = "Shipped track"
NORMAL_SIZE = 4
class Refused(ValueError):
    pass
def read_storage(path):
    out, section = {}, None
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            text = line.strip()
            if not text or text.startswith(";"):
                continue
            if text.startswith("["):
                section = text[1:text.find("]")].strip() if "]" in text else None
                continue
            if section == "storage" and "=" in text:
                key, value = text.split("=", 1)
                out[key.strip()] = value.strip()
    return out
def write_storage(path, store, backup=True):
    lines = []
    if os.path.exists(path):
        if backup:
            shutil.copyfile(path, path + ".bak")
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    out, section, written = [], None, set()
    for line in lines:
        text = line.strip()
        if text.startswith("["):
            if section == "storage":
                out += ["%s = %s" % (k, v) for k, v in store.items() if k not in written]
                written.update(store)
            section = text[1:text.find("]")].strip() if "]" in text else None
            out.append(line)
            continue
        if section == "storage" and "=" in text and not text.startswith(";"):
            key = text.split("=", 1)[0].strip()
            if key in store:
                out.append("%s = %s" % (key, store[key]))
                written.add(key)
            continue
        out.append(line)
    if section == "storage":
        out += ["%s = %s" % (k, v) for k, v in store.items() if k not in written]
        written.update(store)
    if not any(l.strip() == "[storage]" for l in out):
        out.append("[storage]")
        out += ["%s = %s" % (k, v) for k, v in store.items()]
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write("\n".join(out) + "\n")
    os.replace(tmp, path)
    return path
def clean_name(text):
    s = re.sub(r"[^A-Za-z0-9 \-.!'?]", "", str(text or "")).strip()
    return re.sub(r"\s+", " ", s)[:TRACK_NAME_MOST]
def default_meta(track):
    return {"name": "Track %d" % int(track), "kind": TRACK_SPEEDRUN, "laps": TRACK_LAPS}
def clean_meta(meta):
    meta = dict(meta or {})
    kind = meta.get("kind") if meta.get("kind") in (TRACK_SPEEDRUN, TRACK_RACE) else TRACK_SPEEDRUN
    try:
        laps = int(meta.get("laps", TRACK_LAPS))
    except (TypeError, ValueError):
        laps = TRACK_LAPS
    return {"name": clean_name(meta.get("name", "")), "kind": kind,
            "laps": max(1, min(TRACK_LAPS_MOST, laps))}
def track_field(track, meta=None):
    text = "~%d" % int(track)
    if meta is not None:
        meta = clean_meta(meta)
        text += ":%s:%d:%s" % ("r" if meta["kind"] == TRACK_RACE else "s", meta["laps"], meta["name"])
    return text
def read_track_field(text):
    found = re.match(r"^(\d+)(.*)$", text or "")
    if not found:
        return None, None
    meta = None
    rest = re.match(r"^:([sr]):(\d+):(.*)$", found.group(2))
    if rest:
        meta = {"kind": TRACK_RACE if rest.group(1) == "r" else TRACK_SPEEDRUN,
                "laps": int(rest.group(2)), "name": clean_name(rest.group(3))}
    return max(1, int(found.group(1))), meta
def kept_levels(store):
    return [(k, int(n)) for k, n in re.findall(r"([A-Za-z0-9]+):(\d+)", store.get(INDEX_KEY, ""))]
def parse_rows(text):
    rows = []
    for item in (text or "").split(";"):
        if not item:
            continue
        fields, builder, stretch, track = [], None, None, None
        for word in item.split(","):
            box = re.match(r"^#(\d+)x(\d+)x(\d+)$", word)
            if word.startswith("@"):
                builder = word[1:]
            elif word.startswith("~"):
                track = word[1:]
            elif box:
                stretch = [int(v) for v in box.groups()]
            elif word:
                fields.append(word)
        if len(fields) < 8:
            continue
        try:
            row = {"key": fields[0], "x": float(fields[1]), "y": float(fields[2]),
                   "z": float(fields[3]), "yaw": int(float(fields[4])) % 65536,
                   "pitch": int(float(fields[5])) % 65536, "size": int(float(fields[6])),
                   "byte": int(float(fields[7])) % 256}
        except ValueError:
            continue
        if len(fields) >= 13:
            row["pipe"] = fields[8:13]
        if stretch:
            row["stretch"] = stretch
        if track is not None:
            number, meta = read_track_field(track)
            if number is not None:
                row["track"] = number
                if meta is not None:
                    row["meta"] = meta
        if builder:
            row["builder"] = builder
        rows.append(row)
    return rows
def row_text(row):
    def n(v):
        return str(int(math.floor(float(v) + 0.5)))
    fields = [row["key"], n(row["x"]), n(row["y"]), n(row["z"]), str(int(row.get("yaw", 0)) % 65536),
              str(int(row.get("pitch", 0)) % 65536), str(int(row.get("size", NORMAL_SIZE))),
              str(int(row.get("byte", 0)) % 256)]
    fields += [str(v) for v in row.get("pipe") or []]
    if row.get("stretch"):
        fields.append("#" + "x".join(str(int(v)) for v in row["stretch"]))
    if row.get("track") is not None and row["key"] in RACER_KEYS:
        fields.append(track_field(row["track"], row.get("meta") if row["key"] == "racestart" else None))
    if row.get("builder"):
        fields.append("@" + re.sub(r"[^A-Za-z0-9]", "", row["builder"])[:24])
    return ",".join(fields)
def kept_rows(store, key):
    n = int(store.get("fk%sn" % key, "0") or 0)
    parts = [store.get("fk%sp%d" % (key, k), "") for k in range(1, min(n, KEEP_PARTS) + 1)]
    return parse_rows(";".join(parts))
def set_kept(store, key, rows):
    old = int(store.get("fk%sn" % key, "0") or 0)
    for k in range(1, max(old, KEEP_PARTS) + 1):
        store.pop("fk%sp%d" % (key, k), None)
    store.pop("fk%sn" % key, None)
    index = [(k, c) for k, c in kept_levels(store) if k != key]
    parts, current, count = [], "", 0
    for item in (row_text(r) for r in rows):
        if len(parts) >= KEEP_PARTS:
            break
        add = item if not current else current + ";" + item
        if len(add) > KEEP_PART:
            parts.append(current)
            current = ""
            if len(parts) >= KEEP_PARTS:
                break
            current, count = item, count + 1
        else:
            current, count = add, count + 1
    if current:
        parts.append(current)
    if parts:
        for k, part in enumerate(parts, 1):
            store["fk%sp%d" % (key, k)] = part
        store["fk%sn" % key] = str(len(parts))
        if len(index) >= KEEP_LEVELS:
            raise Refused("the save keeps %d levels already - forget one in the game" % KEEP_LEVELS)
        index.append((key, count))
    if index:
        store[INDEX_KEY] = ",".join("%s:%d" % kc for kc in index)
    else:
        store.pop(INDEX_KEY, None)
    races = [k for k in re.findall(r"[A-Za-z0-9]+", store.get(RACE_INDEX, "")) if k != key]
    if any(r["key"] == "racestart" for r in rows[:count]):
        races.append(key)
    if races:
        store[RACE_INDEX] = ",".join(races)
    else:
        store.pop(RACE_INDEX, None)
    return count
def track_number(row):
    try:
        return max(1, int(row.get("track") or 1))
    except (TypeError, ValueError):
        return 1
def track_numbers(rows):
    return sorted({track_number(r) for r in rows if r["key"] in RACER_KEYS})
def track_of(rows, track=None):
    mine = [r for r in rows if r["key"] in RACER_KEYS
            and (track is None or track_number(r) == track)]
    starts = [r for r in mine if r["key"] == "racestart"]
    finishes = [r for r in mine if r["key"] == "racefinish"]
    if not starts:
        raise Refused("No start ring here.")
    if len(starts) > 1:
        raise Refused("Two start rings in one track - take one away.")
    if len(finishes) > 1:
        raise Refused("Two finish flags in one track - take one away.")
    gates = sorted((r for r in mine if r["key"] == "racegate"),
                   key=lambda r: (r.get("byte", 0), r["x"], r["z"]))
    number = track if track is not None else track_number(starts[0])
    meta = starts[0].get("meta") or default_meta(number)
    return {"track": number, "name": meta.get("name") or "Track %d" % number,
            "kind": meta.get("kind") or TRACK_SPEEDRUN, "laps": meta.get("laps") or TRACK_LAPS,
            "start": starts[0], "finish": finishes[0] if finishes else None, "gates": gates,
            "boxes": [r for r in mine if r["key"] == "racebox"],
            "boosts": [r for r in mine if r["key"] == "raceboost"],
            "coins": [r for r in mine if r["key"] == "racecoin"],
            "respawns": [r for r in mine if r["key"] == "racerespawn"],
            "outs": [r for r in mine if r["key"] == "raceout"]}
def tracks_of(rows):
    out = []
    for n in track_numbers(rows):
        try:
            out.append((n, track_of(rows, n), None))
        except Refused as why:
            out.append((n, None, str(why)))
    return out
def problem(track):
    if track is None:
        return None
    if track["kind"] == TRACK_RACE:
        if len(track["gates"]) < RACER_GATES_FEWEST:
            return "A Shell Racer track needs %d gates - %d laid." % (RACER_GATES_FEWEST,
                                                                      len(track["gates"]))
        return None
    if track["finish"] is None:
        return "A speedrun track needs a finish flag."
    return None
def problems(rows):
    said = []
    tracks = tracks_of(rows)
    for n, shape, why in tracks:
        why = why or problem(shape)
        if why:
            said.append(why if len(tracks) == 1 else "Track %d: %s" % (n, why))
    return "; ".join(said) or None
FACING_COST = 3.0
def _forward(yaw):
    a = (yaw or 0) * math.pi / 32768.0
    return (math.sin(a), math.cos(a))
def _leg_cost(a, b, fa, fb):
    dx, dz = b[0] - a[0], b[1] - a[1]
    d = math.hypot(dx, dz)
    if d == 0:
        return 0.0
    ux, uz = dx / d, dz / d
    off = 0.0
    for f in (fa, fb):
        if f is not None:
            off += 1.0 - (ux * f[0] + uz * f[1])
    return d * (1.0 + FACING_COST * off)
def _tour_cost(points, faces, order):
    total = 0.0
    seq = [0] + order + [0]
    for k in range(len(seq) - 1):
        total += _leg_cost(points[seq[k]], points[seq[k + 1]], faces[seq[k]], faces[seq[k + 1]])
    return total
def drive_order(start, gates):
    n = len(gates)
    if n == 0:
        return []
    yaws = set(int(g.get("yaw") or 0) for g in gates)
    use_facing = len(yaws) > 1
    points = [(start["x"], start["z"])] + [(g["x"], g["z"]) for g in gates]
    faces = [_forward(start.get("yaw"))] + [(_forward(g.get("yaw")) if use_facing else None)
                                            for g in gates]
    order, left, at = [], set(range(1, n + 1)), 0
    while left:
        nxt = min(left, key=lambda k: (_leg_cost(points[at], points[k], faces[at], faces[k]), k))
        order.append(nxt)
        left.remove(nxt)
        at = nxt
    best = _tour_cost(points, faces, order)
    better = True
    rounds = 0
    while better and rounds < 50:
        better = False
        rounds += 1
        for a in range(n):
            for b in range(n):
                if a == b:
                    continue
                cand = order[:a] + order[a + 1:]
                cand.insert(b, order[a])
                c = _tour_cost(points, faces, cand)
                if c < best - 1e-6:
                    order, best, better = cand, c, True
        for a in range(n - 1):
            for b in range(a + 2, n + 1):
                cand = order[:a] + order[a:b][::-1] + order[b:]
                c = _tour_cost(points, faces, cand)
                if c < best - 1e-6:
                    order, best, better = cand, c, True
    return [k - 1 for k in order]
def number_along(rows):
    shapes = [shape for _, shape, _ in tracks_of(rows) if shape is not None]
    if not shapes:
        track_of(rows)
    for tr in shapes:
        gates = list(tr["gates"])
        for n, k in enumerate(drive_order(tr["start"], gates), 1):
            gates[k]["byte"] = n
    return rows
def from_markers(markers, track=1):
    def m(r):
        if isinstance(r, dict):
            return r["kind"], r.get("num", 0), r["x"], r["y"], r["z"]
        return r[0], r[1], r[4], r[5], r[6]
    furniture = {32: "racebox", 33: "racecoin", 64: "raceboost"}
    gates, rows = {}, []
    for r in markers or []:
        kind, num, x, y, z = m(r)
        if kind == 16:
            gates[num] = (x, y, z)
        elif kind in furniture:
            rows.append({"key": furniture[kind], "x": x, "y": y, "z": z, "yaw": 0, "track": track})
    count = 0
    while count in gates:
        count += 1
    if count < 2:
        raise Refused("this layout carries no race gates")
    out = []
    for n in range(count):
        x, y, z = gates[n]
        if n == 0:
            (ax, _, az), (bx, _, bz) = gates[count - 1], gates[1]
            yaw = int(round(math.atan2(bx - ax, bz - az) * 32768.0 / math.pi)) % 65536
            out.append({"key": "racestart", "x": x, "y": y, "z": z, "yaw": yaw, "track": track,
                        "meta": {"name": SHIPPED_NAME, "kind": TRACK_RACE, "laps": TRACK_LAPS}})
        else:
            (ax, _, az), (bx, _, bz) = gates[n - 1], gates[(n + 1) % count]
            yaw = int(round(math.atan2(bx - ax, bz - az) * 32768.0 / math.pi)) % 65536
            out.append({"key": "racegate", "x": x, "y": y, "z": z, "yaw": yaw, "byte": n,
                        "track": track})
    return out + rows
def free_track(rows):
    taken = set(track_numbers(rows))
    track = 1
    while track in taken:
        track += 1
    if track > TRACK_MOST:
        raise Refused("This level has as many tracks as it can hold.")
    return track
def to_layout(rows, key, name=None):
    objects = []
    for r in rows:
        o = {"key": r["key"], "what": r["key"], "x": r["x"], "y": r["y"], "z": r["z"],
             "yaw": round(r.get("yaw", 0) * 360.0 / 65536.0, 4),
             "forge": {k: r[k] for k in ("pitch", "size", "byte", "pipe", "stretch", "builder")
                       if k in r}}
        if r["key"] in RACER_KEYS:
            o["track"] = track_number(r)
        if r["key"] == "racegate":
            o["order"] = r.get("byte", 0)
        if r["key"] == "racestart" and r.get("meta"):
            o["track_meta"] = dict(r["meta"])
        objects.append(o)
    return {"name": name or "Forge build %s" % key, "key": "forgetrack", "level": "empty",
            "budget": max(120, len(objects)), "family": "race", "pieces": [], "spawns": [],
            "survey": {"points": []}, "look": {}, "objects": objects}
def from_layout(layout):
    rows = []
    for o in layout.get("objects") or []:
        keep = dict(o.get("forge") or {})
        row = {"key": o.get("key") or o.get("what"), "x": o.get("x", 0), "y": o.get("y", 0),
               "z": o.get("z", 0),
               "yaw": int(round(float(o.get("yaw", 0)) * 65536.0 / 360.0)) % 65536,
               "pitch": keep.get("pitch", 0), "size": keep.get("size", NORMAL_SIZE),
               "byte": keep.get("byte", 0)}
        for k in ("pipe", "stretch", "builder"):
            if keep.get(k):
                row[k] = keep[k]
        if row["key"] in RACER_KEYS:
            row["track"] = track_number(o)
        if row["key"] == "racegate":
            row["byte"] = int(o.get("order", row["byte"]) or 0)
        if row["key"] == "racestart" and o.get("track_meta"):
            row["meta"] = clean_meta(o["track_meta"])
        if row["key"]:
            rows.append(row)
    for n in track_numbers(rows):
        gates = sorted((r for r in rows if r["key"] == "racegate" and track_number(r) == n),
                       key=lambda r: (r["byte"], r["x"], r["z"]))
        for k, g in enumerate(gates, 1):
            g["byte"] = k
    return rows
def import_doc(save, key, name=None):
    from studio.editor.document import Document
    store = read_storage(save)
    if key not in dict(kept_levels(store)):
        raise Refused("%s keeps no build for %r (kept: %s)" % (
            save, key, ", ".join(k for k, _ in kept_levels(store)) or "none"))
    rows = kept_rows(store, key)
    doc = Document({"family": "race"}, to_layout(rows, key, name))
    doc.meta["forge"] = {"save": os.path.abspath(save), "key": key}
    return doc
def export_doc(doc, save=None, key=None):
    where = doc.meta.get("forge") or {}
    save = save or where.get("save")
    key = key or where.get("key")
    if not save or not key:
        raise Refused("which save and which level? (import from a save first, or name both)")
    rows = from_layout(doc.to_layout(models=False))
    said = problems(rows)
    store = read_storage(save) if os.path.exists(save) else {}
    count = set_kept(store, key, rows)
    write_storage(save, store)
    return count, said
def import_change(doc, save, key):
    from studio.editor import ops
    new = import_doc(save, key)
    return ops.replace_map(doc, new.brief, new.to_layout(models=False),
                           "Forge build %s from the save" % key, meta=dict(new.meta))
def number_change(doc):
    from studio.editor import ops
    from studio.editor.commands import Change
    refs = [r for r in doc.refs("object") if (doc.get(r) or {}).get("key") in RACER_KEYS]
    rows = from_layout({"objects": [doc.get(r) for r in refs]})
    number_along(rows)
    pairs = []
    for ref, row in zip(refs, rows):
        item = dict(doc.get(ref))
        if row["key"] == "racegate":
            item["order"] = row["byte"]
            pairs.append((ref, item))
    return Change("Number the race gates", ops._replace_steps(doc, pairs)), len(pairs)
USAGE = """python3 tools/studio/library/forgetrack.py list SAVE
       python3 tools/studio/library/forgetrack.py import SAVE KEY OUT.ofmap
       python3 tools/studio/library/forgetrack.py export MAP.ofmap SAVE [KEY]
       python3 tools/studio/library/forgetrack.py ship LAYOUT.json SAVE KEY"""
def main(argv):
    if not argv or argv[0] not in ("list", "import", "export", "ship"):
        print(USAGE)
        return 2
    try:
        if argv[0] == "list":
            store = read_storage(argv[1])
            races = set(re.findall(r"[A-Za-z0-9]+", store.get(RACE_INDEX, "")))
            for key, count in kept_levels(store):
                tracks = ""
                if key in races:
                    shapes = [s for _, s, _ in tracks_of(kept_rows(store, key)) if s]
                    tracks = "  (%s)" % ", ".join(
                        "%d: %s, %s" % (s["track"], s["name"], "Shell Racer" if s["kind"] == TRACK_RACE
                                        else "speedrun") for s in shapes) if shapes else ""
                print("%-16s %4d things%s" % (key, count, tracks))
            return 0
        if argv[0] == "import":
            doc = import_doc(argv[1], argv[2])
            doc.save(argv[3])
            print("%s: %d things" % (argv[3], len(doc.refs("object"))))
            return 0
        if argv[0] == "export":
            from studio.editor.document import Document
            doc = Document.load(argv[1])
            count, said = export_doc(doc, argv[2], argv[3] if len(argv) > 3 else None)
            print("kept %d things%s" % (count, (" - " + said) if said else ""))
            return 0
        with open(argv[1], encoding="utf-8") as handle:
            layout = json.load(handle)
        store = read_storage(argv[2]) if os.path.exists(argv[2]) else {}
        rows = kept_rows(store, argv[3])
        track = free_track(rows)
        rows += from_markers(layout.get("markers"), track)
        count = set_kept(store, argv[3], rows)
        write_storage(argv[2], store)
        print("kept %d things, the shipped track among them as track %d" % (count, track))
        return 0
    except (Refused, OSError, ValueError, KeyError) as why:
        print("forgetrack: %s" % why)
        return 1
if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    sys.exit(main(sys.argv[1:]))
