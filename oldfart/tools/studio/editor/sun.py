from . import ops
class SunTool:
    def __init__(self, ed):
        self.ed = ed
        self.visible = False
    def doc(self):
        session = getattr(self.ed, "session", None)
        return getattr(session, "doc", None)
    def shown(self):
        return bool(self.visible) and self.doc() is not None
    def sun(self):
        from mapgen import bake
        doc = self.doc()
        return bake.sun_of((doc.rest.get("look") or {}) if doc is not None else {})
    def own(self):
        doc = self.doc()
        return doc is not None and isinstance((doc.rest.get("look") or {}).get("sun"), dict)
    def commit(self, sun):
        doc = self.doc()
        if doc is None:
            return False
        self.ed.push(ops.set_sun(doc, sun))
        return True
