import hashlib
import json
import re
import time
import zlib
PREFIX = "OF-"
ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_DICT = (b'{"wish":"","seed":,"players":,"theme":"castle","size":"small","medium","large",'
         b'"family":"shooter","ctf","race","explore","sides":"ffa","teams","symmetry":"turn4",'
         b'"mirror","preset":"verticality":"high","low","density":"difficulty":"normal",'
         b'"style":"ice","lava","desert","forest","sky","night","snow","city","island","tower",'
         b'"bridge","cave","arena","map","with","and","a ","the ","for ","players","lots of",'
         b'"features":{"want":[],"avoid":[]},"dna":{"age":,"coherence":,"complexity":},'
         b'"prefabs":["castlewall","gate","watchtower"],"budget":,"candidates":')
SKIP = {"defaulted", "brief", "key", "name", "reseed", "locks", "reference", "requests",
        "dropped", "lines"}
class CodeError(ValueError):
    pass
_ANCHOR_DEFAULTS = ("id", "hard", "once", "tolerance")
def _lean_anchors(anchors):
    try:
        from mapgen.brief import normalise_anchor
    except ImportError:
        return anchors
    out = []
    for i, a in enumerate(anchors):
        if isinstance(a, dict):
            a = dict(a)
            for k in _ANCHOR_DEFAULTS:
                if k in a:
                    trial = {j: v for j, v in a.items() if j != k}
                    got = normalise_anchor(trial, i, [])
                    if got is not None and k in got and got[k] == a[k]:
                        a = trial
        out.append(a)
    return out
def _same_as_read(k, v, again):
    if again.get(k) == v:
        return True
    if k == "anchors" and isinstance(v, list) and isinstance(again.get(k), list):
        return _lean_anchors(v) == _lean_anchors(again[k])
    return False
def _lean(k, v):
    return _lean_anchors(v) if k == "anchors" and isinstance(v, list) else v
def _b32(data):
    bits = "".join("{:08b}".format(b) for b in data)
    bits += "0" * (-len(bits) % 5)
    return "".join(ALPHABET[int(bits[i:i + 5], 2)] for i in range(0, len(bits), 5))
def _unb32(text):
    bits = "".join("{:05b}".format(ALPHABET.index(c)) for c in text)
    n = len(bits) // 8
    return bytes(int(bits[i * 8:i * 8 + 8], 2) for i in range(n))
def _check(text):
    return ALPHABET[sum((i + 1) * ALPHABET.index(c) for i, c in enumerate(text)) % 32]
def encode(payload):
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    c = zlib.compressobj(9, zlib.DEFLATED, -15, 9, zlib.Z_DEFAULT_STRATEGY, _DICT)
    body = _b32(c.compress(raw) + c.flush())
    body += _check(body)
    return PREFIX + "-".join(body[i:i + 4] for i in range(0, len(body), 4))
def normalise(text):
    t = re.sub(r"[\s\-]", "", (text or "").upper())
    if t.startswith("OF"):
        t = t[2:]
    return t.replace("O", "0").replace("I", "1").replace("L", "1")
CODE_RE = re.compile(r"^\s*OF-[0-9A-Z]{4}(-[0-9A-Z]{1,4})+\s*$", re.I)
def looks_like(text):
    return bool(CODE_RE.match(text or ""))
def decode(code):
    body = normalise(code)
    if len(body) < 3 or any(c not in ALPHABET for c in body):
        raise CodeError("not a map code (they look like OF-K3M9-QX2T-...)")
    if _check(body[:-1]) != body[-1]:
        raise CodeError("this map code has a typo (its check letter does not fit)")
    try:
        d = zlib.decompressobj(-15, _DICT)
        raw = d.decompress(_unb32(body[:-1])) + d.flush()
        payload = json.loads(raw.decode("utf-8"))
    except (zlib.error, ValueError, UnicodeDecodeError):
        raise CodeError("this map code does not read - was it copied whole?")
    if not isinstance(payload, dict) or "seed" not in payload:
        raise CodeError("this map code holds no seed")
    return payload
def payload_of(brief, read=None):
    if not isinstance(brief, dict) or brief.get("seed") is None:
        return None
    defaulted = set(brief.get("defaulted") or ())
    wish = brief.get("wish") or ""
    again = read(wish) if (read and wish) else {}
    out = {"seed": brief["seed"]}
    if wish:
        out["wish"] = wish
    for k, v in brief.items():
        if k in SKIP or k in defaulted or k in ("seed", "wish") or v is None:
            continue
        if _same_as_read(k, v, again):
            continue
        out[k] = _lean(k, v)
    return out
def payload_from_raw(raw, seed, read=None):
    raw = dict(raw or {})
    wish = raw.get("wish") or ""
    again = read(wish) if (read and wish) else {}
    out = {"seed": seed}
    if wish:
        out["wish"] = wish
    for k, v in raw.items():
        if k in ("seed", "wish") or k in SKIP or v is None or _same_as_read(k, v, again):
            continue
        out[k] = _lean(k, v)
    return out
def raw_of(payload, read=None):
    payload = dict(payload)
    seed = payload.pop("seed")
    wish = payload.get("wish") or ""
    raw = dict(read(wish)) if (read and wish) else {}
    raw.update(payload)
    return raw, seed
def layout_hash(layout):
    keep = {k: layout.get(k) for k in ("pieces", "spawns", "objects", "movers") if k in layout}
    return hashlib.sha1(json.dumps(keep, sort_keys=True).encode("utf-8")).hexdigest()[:16]
def edited(doc):
    info = doc.meta.get("code")
    if not isinstance(info, dict) or not info.get("code"):
        return True
    return info.get("hash") != layout_hash(doc.to_layout(models=False))
def stamp(doc, code):
    doc.meta["code"] = {"code": code, "hash": layout_hash(doc.to_layout(models=False))}
    return doc.meta["code"]
def remix(meta, name, author="", code=None, digest=None, when=None):
    origin = [o for o in (meta.get("origin") or []) if isinstance(o, dict)]
    row = {"name": name or "a map", "author": author or "",
           "date": when or time.strftime("%Y-%m-%d")}
    if code:
        row["code"] = code
    if digest:
        row["hash"] = digest
    if origin and all(origin[-1].get(k) == row.get(k) for k in ("name", "author", "code")):
        return origin
    origin.append(row)
    meta["origin"] = origin
    return origin
def credit(meta):
    origin = [o for o in (meta.get("origin") or []) if isinstance(o, dict)]
    if not origin:
        return ""
    first = origin[0]
    line = "Made from %s" % first.get("name", "a map")
    if first.get("author"):
        line += " by %s" % first["author"]
    others = [o.get("author") for o in origin[1:] if o.get("author")]
    me = meta.get("author")
    if me and me not in others and me != first.get("author"):
        others.append(me)
    if others:
        line += " - remixed by %s" % ", ".join(others)
    return line
