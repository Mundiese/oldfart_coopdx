import json
import os
import shutil
import time
KEEP = 40
KINDS = ("texture", "music", "prefab")
def folder():
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local",
                                                           "share")
    path = os.environ.get("OLDFART_TRASH") or os.path.join(base, "oldfart-studio", "trash")
    os.makedirs(path, exist_ok=True)
    return path
class Entry:
    __slots__ = ("path", "kind", "label", "when", "files")
    def __init__(self, path, data):
        self.path = path
        self.kind = data.get("kind")
        self.label = data.get("label", "")
        self.when = data.get("when", 0)
        self.files = data.get("files", [])
    def __repr__(self):
        return "<removed %s %r>" % (self.kind, self.label)
def keep(kind, label, paths):
    if kind not in KINDS:
        raise ValueError("kind is one of %s" % ", ".join(KINDS))
    stamp = "%d-%06d" % (int(time.time()), int(time.perf_counter() * 1e6) % 1000000)
    where = os.path.join(folder(), "%s-%s" % (stamp, kind))
    os.makedirs(where)
    files = []
    for n, path in enumerate(paths):
        path = os.path.abspath(path)
        existed = os.path.isfile(path)
        if existed:
            shutil.copy2(path, os.path.join(where, "%d.bin" % n))
        files.append({"path": path, "existed": existed, "copy": "%d.bin" % n})
    data = {"kind": kind, "label": label, "when": time.time(), "files": files}
    with open(os.path.join(where, "entry.json"), "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=1)
    _thin()
    return Entry(where, data)
def entries():
    out = []
    root = folder()
    for name in os.listdir(root):
        path = os.path.join(root, name, "entry.json")
        try:
            with open(path, encoding="utf-8") as handle:
                out.append(Entry(os.path.dirname(path), json.load(handle)))
        except (OSError, ValueError):
            continue
    return sorted(out, key=lambda e: e.when, reverse=True)
def restore(entry):
    for f in entry.files:
        if f["existed"]:
            os.makedirs(os.path.dirname(f["path"]), exist_ok=True)
            tmp = f["path"] + ".trash-tmp"
            shutil.copy2(os.path.join(entry.path, f["copy"]), tmp)
            os.replace(tmp, f["path"])
        elif os.path.exists(f["path"]):
            os.remove(f["path"])
    forget(entry)
    return entry
def forget(entry):
    shutil.rmtree(entry.path, ignore_errors=True)
def _thin():
    for old in entries()[KEEP:]:
        forget(old)
