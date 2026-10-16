from mapgen import hostpatterns, stamps as stampmod
WIDEN = (("a.fam", "either texture family"), ("b.fam", "the other's texture family"),
         ("a.kind", "either shape"), ("b.kind", "the other's shape"), ("rise", "the height"))
def pattern_of(doc, refs, kind, widen=()):
    pieces = [doc.get(r) for r in refs if r[0] == "piece" and r in doc]
    if len(pieces) != 2:
        return None, "select exactly two pieces (now %d)" % len(pieces)
    a, b = pieces
    rel, _ = hostpatterns.relation(a, b)
    if rel is None:
        return None, "the two pieces do not meet (on, beside, inside or within 200)"
    return hostpatterns.pattern(a, b, kind, widen), None
def keep_pattern(store, pat):
    added = store.add(pat)
    try:
        store.save()
    except OSError as why:
        return "not saved: %s" % why
    said = hostpatterns.describe(pat)
    return ("Kept - every map from now: " + said) if added else ("Already kept: " + said)
def pattern_rows(store):
    return [hostpatterns.describe(p) for p in store.items]
def check_doc(doc, store):
    pieces = [doc.get(r) for r in doc.refs("piece")]
    return [(hostpatterns.describe(p), a, b) for p, a, b in hostpatterns.matches(pieces,
                                                                                 store.items)]
GERMAN_WORDS = frozenset((
    "ein", "eine", "einem", "einer", "einen", "mit", "und", "oder", "der", "die", "das",
    "im", "viel", "viele", "vielen", "grosse", "kleine", "schnelle", "zwei",
    "mitte", "auf", "turm", "bruecke", "basen", "mauern", "toren", "burg", "welt",
    "fluss", "dorf", "bergen", "hoehlen", "wald", "ruinen", "ecken", "rennen", "kurven",
    "saeulen", "sprungen", "verstecken", "haeusern", "hecken", "ebenen", "holz", "eis",
))
GERMAN_LETTERS = "\u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df"
def typed_in_german(text):
    import re
    words = re.findall(r"[^\W\d_]+", text.lower())
    return sum(w in GERMAN_WORDS for w in words) >= 2 or any(c in text for c in GERMAN_LETTERS)
def gallery_rows(accepted=None):
    from mapgen import gallery
    acc = (accepted or gallery.load_accepted()).get("accepted") or {}
    rows = []
    for pair in gallery.pairs():
        c = acc.get(pair["id"]) or {}
        hard = sum(int(c.get(k) or 0) for k in gallery.HARD)
        fam = pair.get("family") or (pair.get("brief") or {}).get("family") or \
            ("venue" if pair["kind"] == "venue" else "?")
        bits = []
        if c.get("quality") is not None:
            bits.append("quality %.2f" % float(c["quality"]))
        if c.get("kinds_used") is not None:
            bits.append("%s kinds" % c["kinds_used"])
        if c.get("pieces") is not None:
            bits.append("%s pieces" % c["pieces"])
        if hard:
            bits.append("%d hard" % hard)
        if not c:
            bits.append("no accepted card")
        wish = pair.get("wish")
        if wish and typed_in_german(wish):
            wish = "%s %s wish typed in German" % ("an" if fam[:1] in "aeiou" else "a", fam)
        about = wish or pair.get("about") or pair.get("venue") or \
            ", ".join("%s %s" % kv for kv in sorted((pair.get("brief") or {}).items())
                      if not isinstance(kv[1], dict))
        rows.append({"id": pair["id"], "kind": pair["kind"], "family": fam, "hard": hard,
                     "line": "%s  -  %s" % (about, ", ".join(bits)), "pair": pair})
    return rows
def gallery_brief(row):
    from mapgen import gallery
    if row["pair"]["kind"] == "venue":
        return None
    return gallery._brief_of(row["pair"])
def board(theme):
    from mapgen import contract
    d = contract.data()
    out = []
    for cls in contract.classes():
        allowed = contract.allowed(theme, cls)
        fams = []
        for f in d["families"]:
            refused = cls in d["built"] and f in d["refused_on_built"]
            fams.append((f, f in allowed, refused))
        try:
            tiles = contract.members(theme, cls)[:12]
        except Exception:
            tiles = []
        out.append({"cls": cls, "allowed": allowed, "families": fams, "tiles": tiles})
    return out
def set_board(theme, cls, families, where=None):
    from mapgen import contract
    return contract.set_allowed(theme, cls, families, where)
def tile_file(slug):
    import os
    from mapgen import contract, soft64
    _, entry = contract._lib_entry(slug)
    if entry and entry.get("file"):
        return os.path.join(os.path.dirname(soft64.PALETTES), entry["file"])
    return None
GRID = 8
def stamp_new(store, name):
    s = stampmod.new(name or "stamp %d" % (len(store.items) + 1))
    store.items.append(s)
    return s
def stamp_capture(store, doc, refs, name=None):
    pieces = [doc.get(r) for r in refs if r[0] == "piece" and r in doc]
    if not pieces:
        return None, "select the land to capture"
    s = stampmod.capture(pieces, name or "captured %d" % (len(store.items) + 1))
    if not s["cells"]:
        return None, "the selection has no land above its lowest cell"
    store.items.append(s)
    return s, None
def stamp_click(stamp, cell, button):
    v = stamp["cells"].get(tuple(cell), 0) + (1 if button == "left" else -1)
    return stampmod.paint(stamp, cell, v)
def stamp_preview(stamp, seed=1, n=3):
    import random
    rng = random.Random("stamp-preview:%s" % seed)
    return [stampmod.vary(stamp, rng) for _ in range(n)]
