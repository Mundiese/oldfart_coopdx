import hashlib
import json
import os
import time
from .document import Document, write_atomic
INTERVAL = 60.0
KEEP = 10
def default_folder():
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local",
                                                           "share")
    return os.path.join(base, "oldfart-studio", "autosave")
class AutoSaver:
    def __init__(self, folder=None, interval=INTERVAL, keep=KEEP):
        self.folder = folder or default_folder()
        self.interval = interval
        self.keep = keep
        self.last = {}
    def name_of(self, doc):
        path = doc.meta.get("path")
        if path:
            stem = os.path.splitext(os.path.basename(path))[0]
            tag = hashlib.blake2b(os.path.abspath(path).encode("utf-8"), digest_size=4).hexdigest()
            return "%s-%s.ofmap" % (stem, tag)
        token = doc.meta.setdefault("session", "%x" % int(time.time() * 1000))
        return "untitled-%s.ofmap" % token
    def path_of(self, doc):
        return os.path.join(self.folder, self.name_of(doc))
    def due(self, doc, stack, now):
        if stack is not None and stack.is_clean():
            return False
        name = self.name_of(doc)
        at, rev = self.last.get(name, (None, None))
        if rev == doc.revision:
            return False
        return at is None or now - at >= self.interval
    def tick(self, doc, stack, now=None):
        now = time.time() if now is None else now
        if not self.due(doc, stack, now):
            return None
        return self.write(doc, now)
    def write(self, doc, now=None):
        now = time.time() if now is None else now
        path = self.path_of(doc)
        data = json.loads(doc.to_json())
        data["autosave"] = {"at": now, "of": doc.meta.get("path"),
                            "name": doc.rest.get("name") or doc.brief.get("name")}
        write_atomic(path, json.dumps(data, indent=1, sort_keys=True) + "\n")
        self.last[self.name_of(doc)] = (now, doc.revision)
        self._prune()
        return path
    def _prune(self):
        files = self._files()
        for path, _, _ in files[self.keep:]:
            try:
                os.remove(path)
            except OSError:
                pass
    def _files(self):
        if not os.path.isdir(self.folder):
            return []
        out = []
        for name in os.listdir(self.folder):
            if not name.endswith(".ofmap"):
                continue
            path = os.path.join(self.folder, name)
            try:
                with open(path, encoding="utf-8") as handle:
                    info = json.load(handle).get("autosave") or {}
            except (OSError, ValueError):
                continue
            out.append((path, info.get("at", os.path.getmtime(path)), info.get("name")))
        return sorted(out, key=lambda t: -t[1])
    def recoverable(self):
        out = []
        for path, at, name in self._files():
            try:
                with open(path, encoding="utf-8") as handle:
                    of = (json.load(handle).get("autosave") or {}).get("of")
            except (OSError, ValueError):
                continue
            if of and os.path.exists(of) and os.path.getmtime(of) >= at:
                continue
            out.append((path, at, name))
        return out
    def recover(self, path):
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        info = data.pop("autosave", {}) or {}
        doc = Document.from_data(data)
        doc.meta["path"] = info.get("of")
        return doc
    def put_aside(self, path):
        try:
            os.replace(path, os.path.splitext(path)[0] + ".declined")
        except OSError:
            try:
                os.remove(path)
            except OSError:
                return False
        return True
    def discard(self, doc):
        path = self.path_of(doc)
        self.last.pop(self.name_of(doc), None)
        if os.path.exists(path):
            os.remove(path)
