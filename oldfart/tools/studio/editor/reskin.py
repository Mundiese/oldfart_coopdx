from mapgen import kit as mkit
from . import ops
from .commands import Change
def themes():
    return sorted(mkit.THEMES)
def _roles(theme):
    pal = mkit.THEMES.get(theme) or {}
    out = []
    for role, v in pal.items():
        if isinstance(v, str):
            out.append((role, 0, v))
        elif isinstance(v, list):
            out += [(role, i, t) for i, t in enumerate(v) if isinstance(t, str)]
    return out
def mapping(old, new):
    newpal = {(r, i): t for r, i, t in _roles(new)}
    out = {}
    for role, i, tex in _roles(old):
        if tex in out:
            continue
        want = newpal.get((role, i)) or newpal.get((role, 0))
        if want is None and role.startswith("wall"):
            want = newpal.get(("wall", 0))
        if want and want != tex:
            out[tex] = want
    return out
def reskin(doc, new, old=None):
    old = old or doc.brief.get("theme") or "castle"
    if new not in mkit.THEMES:
        raise ValueError("no theme %r (%s)" % (new, ", ".join(themes())))
    m = mapping(old, new)
    steps = []
    by_tex = {}
    for ref in doc.refs("piece"):
        tex = doc.get(ref).get("tex")
        if tex in m:
            by_tex.setdefault(m[tex], []).append(ref)
    for tex, refs in sorted(by_tex.items()):
        steps += ops.retexture(doc, refs, tex).steps
    steps += ops.set_brief(doc, {"theme": new}).steps
    n = sum(len(r) for r in by_tex.values())
    return Change("Re-skin %d pieces: %s to %s" % (n, old, new), steps, select=[])
