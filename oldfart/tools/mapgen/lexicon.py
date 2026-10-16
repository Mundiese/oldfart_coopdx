import json
import os
import re
HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "lexicon.json")
_data = None
_cache = {}
SLOT = "zzlx"
ASCII = set()
def data():
    global _data
    if _data is None:
        with open(PATH, encoding="utf-8") as handle:
            _data = json.load(handle)
        _merge_vocab(_data)
    return _data
def _merge_vocab(d):
    try:
        from . import vocab
        rows = vocab.rows()
    except Exception:
        return
    have = set()
    for c in d["concepts"]:
        for f in c.get("forms", []):
            have.add(_fold(f.lstrip("~")))
    by_expect = {}
    for c in d["concepts"]:
        e = c.get("expect")
        if e and "set" not in c:
            by_expect.setdefault(json.dumps(e, sort_keys=True), c)
    for r in rows:
        c = by_expect.get(json.dumps(vocab.setting(r["param"], r["value"]), sort_keys=True))
        if c is None:
            continue
        for lg in ("en", "de"):
            for form in r.get(lg) or []:
                words = vocab.surface(form).split()
                while len(words) > 1 and words[0] in vocab.ARTICLES:
                    words = words[1:]
                f = " ".join(words)
                if not f or _fold(f) in have:
                    continue
                if r["param"] == "feature" and _negated_form(f):
                    continue
                have.add(_fold(f))
                c.setdefault("forms", []).append(("~" + f) if form.startswith("~") else f)
def _negated_form(form):
    from . import negation
    m = negation.CUE.match(_fold(form))
    return m is not None
def concepts():
    return data()["concepts"]
def by_id(cid):
    for c in concepts():
        if c["id"] == cid:
            return c
    return None
def _fold(t):
    t = t.lower()
    for a, b in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss"), ("é", "e"), ("’", "'"),
                 ("-", " ")):
        t = t.replace(a, b)
    return re.sub(r"\s+", " ", t).strip()
def _ascii(form):
    out = set()
    for a, b in (("ue", "u"), ("ae", "a"), ("oe", "o")):
        if a in form:
            out.add(form.replace(a, b))
    if "ue" in form and "ae" in form:
        out.add(form.replace("ue", "u").replace("ae", "a"))
    return out
def expand(form):
    rules = data()["rules"]
    form = form.strip()
    out = []
    if form.startswith("~"):
        stem = _fold(form[1:])
        out.append((stem, False))
        last = stem.split(" ")
        for e in rules["de_adj_endings"]:
            if stem.endswith("e") and e.startswith("e"):
                w = stem + e[1:]
            else:
                w = stem + e
            out.append((" ".join(last[:-1] + [last[-1] + e]) if len(last) > 1 else w, False))
    elif "(" in form and form.endswith(")"):
        stem, rest = form[:-1].split("(", 1)
        stem = _fold(stem)
        out.append((stem, False))
        for suf in rest.split("|"):
            out.append((stem + _fold(suf), True))
    elif form.endswith("+s"):
        stem = _fold(form[:-2])
        out.append((stem, False))
        out.append((stem[:-1] + "ies" if stem.endswith("y") else stem + "s", True))
    else:
        out.append((_fold(form), False))
    more = []
    plain = set(f for f, _ in out)
    for f, pl in out:
        for a in _ascii(f):
            more.append((a, pl))
            if a not in plain:
                ASCII.add(a)
    seen, res = set(), []
    for f, pl in out + more:
        if f and f not in seen:
            seen.add(f)
            res.append((f, pl))
    return res
def _build():
    if "index" in _cache:
        return
    single, multi, collisions = {}, {}, []
    for c in concepts():
        for key, pl in (("canon", False), ("canon_pl", True)):
            cf = c.get(key)
            if cf and " " not in cf:
                single.setdefault(cf, (c, pl))
    for c in concepts():
        names = list(c.get("forms", []))
        for form in names:
            for f, pl in expand(form):
                table = multi if " " in f else single
                if f in table and table[f][0]["id"] != c["id"]:
                    other = table[f][0]
                    if canon_of(other, table[f][1]) != canon_of(c, pl):
                        collisions.append((f, other["id"], c["id"]))
                    continue
                table.setdefault(f, (c, pl))
    sources = {}
    byid = {c["id"]: c for c in concepts()}
    for layer in dictionary_layers():
        for cid, words in layer["forms"].items():
            c = byid.get(cid)
            if c is None:
                continue
            for w in words:
                table = multi if " " in w else single
                if w not in table:
                    table[w] = (c, False)
                    sources[w] = layer["source"]
    _cache["dict_sources"] = sources
    _cache["index"] = single
    _cache["multi"] = multi
    _cache["collisions"] = collisions
    _cache["multi_sorted"] = sorted(multi, key=lambda p: -len(p))
DICT_DIR = os.path.join(HERE, "dict")
def dictionary_layers():
    if os.environ.get("OLDFART_DICT") == "off":
        return []
    out = []
    try:
        names = sorted(n for n in os.listdir(DICT_DIR) if n.endswith(".json"))
    except OSError:
        return []
    for n in names:
        try:
            with open(os.path.join(DICT_DIR, n), encoding="utf-8") as f:
                d = json.load(f)
            if isinstance(d.get("forms"), dict):
                out.append(d)
        except (OSError, ValueError):
            continue
    return out
def source_of(word):
    _build()
    return _cache.get("dict_sources", {}).get(word)
def reset():
    _cache.clear()
    ASCII.clear()
def index():
    _build()
    return _cache["index"]
def phrases_index():
    _build()
    return _cache["multi"]
def collisions():
    _build()
    return list(_cache["collisions"])
def count():
    return len(index()) + len(phrases_index())
def canon_of(concept, plural):
    if "set" in concept and not concept.get("canon"):
        return None
    if plural and concept.get("canon_pl"):
        return concept["canon_pl"]
    return concept.get("canon")
def say_of(concept, form):
    sf = concept.get("say_forms") or {}
    for k, v in sf.items():
        if form in [f for f, _ in expand(k)]:
            return v
    return concept.get("say")
def _protected():
    if "protected" in _cache:
        return _cache["protected"]
    from . import wish
    d = data()
    p = set(wish.STOP) | set(wish.VOCAB) | set(wish.NUMBERS) | set(d["keep_whole"]) | \
        set(d["fillers"]) | set(d["common"]) | set(d["heads"]) | set(d.get("parts", []))
    try:
        from . import modes
        for k, name in modes.all().items():
            p.add(k)
            p.update(re.findall(r"[a-z0-9]+", _fold(name)))
    except Exception:
        pass
    try:
        from . import presets
        for pr in presets.all_presets():
            for w in pr.get("words", []) + [pr["name"]]:
                p.update(re.findall(r"[a-z0-9]+", _fold(w)))
    except Exception:
        pass
    try:
        from . import prefablib
        for key, name, _ in prefablib.names():
            p.add(key)
            p.update(re.findall(r"[a-z0-9]+", _fold(name)))
    except Exception:
        pass
    try:
        from . import kit
        for t in kit.music_tracks():
            for n in t["names"]:
                p.update(w for w in re.findall(r"[a-z0-9]+", _fold(n)) if len(w) >= 4)
    except Exception:
        pass
    _cache["protected"] = p
    return p
def _parts():
    if "parts" in _cache:
        return _cache["parts"]
    from . import wish
    d = data()
    m = d["rules"]["min_part"]
    parts = {}
    for f, (c, pl) in index().items():
        if len(f) >= m and not c.get("set"):
            parts[f] = canon_of(c, pl) or f
    for w in list(wish.VOCAB) + d["heads"] + d.get("parts", []):
        if len(w) >= m:
            parts.setdefault(w, w)
    for w in ("spawn", "welt", "world", "eis", "burg", "wald", "dorf", "stadt", "insel",
              "berg", "haus", "turm", "lava", "sand", "holz", "stein", "wasser", "see",
              "feuer", "himmel", "wolken", "garten", "wiese", "schnee", "frost",
              "huegel", "mauer", "zaun", "tor", "platz", "dach"):
        parts.setdefault(w, index()[w][0].get("canon", w) if w in index() else w)
    for w in ("riesen", "mega", "monster", "mini", "klein", "gross"):
        parts.setdefault(w, index()[w][0]["canon"] if w in index() else w)
    _cache["parts"] = parts
    return parts
ENDINGS = ("e", "en", "er", "es", "n", "s")
def split(token, inner=False):
    parts = _parts()
    links = [""] + data()["rules"]["linkers"]
    m = data()["rules"]["min_part"]
    n = len(token)
    best = {n: []}
    def solve(i):
        if i in best:
            return best[i]
        res = None
        for j in range(n, i + m - 1, -1):
            piece = token[i:j]
            if piece not in parts or (inner and i == 0 and j == n):
                continue
            for ln in links:
                k = j + len(ln)
                if token[j:k] != ln or (k == n and ln and ln not in ENDINGS):
                    continue
                tail = solve(k)
                if tail is not None and (res is None or len(tail) + 1 < len(res)):
                    res = [piece] + tail
            if res is not None and len(res) <= 2:
                break
        best[i] = res
        return res
    got = solve(0)
    if got and len(got) >= 2:
        return got
    return None
def distance(a, b, cap=3):
    if abs(len(a) - len(b)) > cap:
        return cap + 1
    prev2 = None
    prev = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        cur = [i] + [0] * len(b)
        lo = cur[0]
        for j in range(1, len(b) + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            v = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                v = min(v, prev2[j - 2] + 1)
            cur[j] = v
            lo = min(lo, v)
        if lo > cap:
            return cap + 1
        prev2, prev = prev, cur
    return prev[-1]
def _pool():
    if "pool" in _cache:
        return _cache["pool"]
    from . import wish
    pool = list(index().items())
    have = set(index())
    native = set(wish.VOCAB)
    try:
        from . import presets
        for pr in presets.all_presets():
            for w in pr.get("words", []) + [pr["name"]]:
                native.update(x for x in re.findall(r"[a-z]+", _fold(w)) if len(x) >= 5)
    except Exception:
        pass
    native.update(NATIVE_EXTRA)
    native.update(w for w in wish.NUMBERS if w.isalpha() and len(w) >= 4)
    for w in sorted(native - have):
        if len(w) >= 4:
            pool.append((w, ({"id": "native:" + w, "canon": w}, False)))
    _cache["pool"] = pool
    return pool
NATIVE_EXTRA = (
    "pyramide", "pyramiden", "pyramid", "pyramids", "windmuehle", "windmuehlen", "windmill",
    "windmills", "leuchtturm", "lighthouse", "wasserfall", "waterfall", "waterfalls",
    "springbrunnen", "fountain", "fountains", "brunnen", "statue", "statuen", "statues",
    "obelisk", "schiffswrack", "shipwreck", "tempel", "temple", "temples", "ruine", "ruinen",
    "ruins", "schrein", "shrine", "glockenturm", "wachturm", "watchtower", "pilze", "pilzen",
    "mushrooms", "mushroom", "kristalle", "crystals", "laternen", "lanterns", "rutsche",
    "slide", "vulkan", "volcano", "gletscher", "glacier", "duenen", "dunes", "hoehlen",
    "hoehle", "caves", "inseln", "islands", "bruecke", "bridge", "bridges", "river", "fluss",
    "mountains", "berge")
_FUZZY_DE = [False]
def fuzzy(word):
    fz = data()["rules"]["fuzzy"]
    if len(word) < fz["min_len"] or word in _protected() or not word.isalpha():
        return None
    cap = fz["max_dist_long"] if len(word) >= fz["long_from"] else fz["max_dist_short"]
    best, hits = None, []
    for f, (c, pl) in _pool():
        if abs(len(f) - len(word)) > cap or len(f) < 4:
            continue
        if len(word) == 4 and not (len(f) == 5 and any(f[:i] + f[i + 1:] == word
                                                       for i in range(1, 5))):
            continue
        if f[0] != word[0] and not (len(f) > 1 and f[:2] == word[1::-1]):
            continue
        d = distance(word, f, cap)
        if d > cap or d == 0:
            continue
        if best is None or d < best:
            best, hits = d, [(f, c, pl)]
        elif d == best:
            hits.append((f, c, pl))
    if not hits:
        return None
    land = [h for h in hits if h[0] in NATIVE_EXTRA]
    if land and len({h[0] for h in land}) == 1:
        f = land[0][0]
        conf = round(1.0 - float(best) / max(len(word), len(f)), 2)
        if conf >= fz["min_confidence"]:
            return {"id": "native:" + f, "canon": f}, False, f, conf
    if len({c["id"] for _, c, _ in hits}) > 1:
        key = sound(word)
        hits = [h for h in hits if sound(h[0]) == key]
        if len({c["id"] for _, c, _ in hits}) != 1:
            return None
    f, c, pl = hits[0]
    if f in _no_cross() and _FUZZY_DE[0]:
        return None
    conf = round(1.0 - float(best) / max(len(word), len(f)), 2)
    if conf < fz["min_confidence"]:
        return None
    return c, pl, f, conf
UMLAUT_BACK = (("aeu", "au"), ("ae", "a"), ("oe", "o"), ("ue", "u"))
def _letter_run(w):
    from . import wish
    if not re.search(r"(.)\1", w) or not w.isalpha():
        return None
    cands = [re.sub(r"(.)\1{2,}", r"\1\1", w), re.sub(r"(.)\1{2,}", r"\1", w)]
    for i in range(len(w) - 1):
        if w[i] == w[i + 1]:
            cands.append(w[:i] + w[i + 1:])
    for c in cands:
        if c == w or len(c) < 3:
            continue
        hit = index().get(c)
        if hit:
            return hit[0], hit[1], c
        if c in wish.VOCAB or c in wish.NUMBERS or c in NATIVE_EXTRA or wish.native_lines(c):
            return {"id": "native:" + c, "canon": c}, False, c
    return None
def known(w):
    from . import wish
    hit = index().get(w)
    if hit:
        return hit
    if w in wish.VOCAB or w in _parts():
        canon = _parts().get(w, w)
        return {"id": "native:" + canon, "canon": canon}, False
    return None
def stems(w):
    m = data().get("morph") or {}
    lo = m.get("min_stem", 3)
    sufs = sorted(m.get("suffixes", []), key=len)
    out = [w[:-len(s)] for s in sufs if w.endswith(s) and len(w) - len(s) >= lo]
    more = []
    for st in [w] + out:
        for a, b in UMLAUT_BACK:
            i = st.rfind(a)
            if i >= 0:
                more.append(st[:i] + b + st[i + len(a):])
                break
    more += [x[:-len(s)] for x in more for s in sufs
             if x.endswith(s) and len(x) - len(s) >= lo]
    seen, res = set(), []
    for x in out + more:
        if x not in seen and x != w:
            seen.add(x)
            res.append(x)
    return res
def morph(w):
    if len(w) < 5 or w in _protected():
        return None
    for st in stems(w):
        for cand in (st, st + "e", st + "en", st + "n"):
            k = known(cand)
            if k and cand not in _no_cross():
                return k[0], k[1], cand
    return None
def _no_cross():
    return set((data().get("morph") or {}).get("no_cross", []))
def head_compound(w):
    m = data().get("morph") or {}
    if len(w) < 7:
        return None
    for h in m.get("generic_heads", []):
        for ln in m.get("linkers", [""]):
            tail = ln + h
            for end in ("", "n", "en", "s"):
                if not w.endswith(tail + end) or len(w) - len(tail + end) < 3:
                    continue
                mod = w[:-len(tail + end)]
                k = known(mod)
                if k:
                    return k[0], k[1], mod
                k = morph(mod)
                if k:
                    return k
    return None
def sound(w):
    w = re.sub(r"ph", "f", w)
    w = re.sub(r"ck", "k", w)
    w = re.sub(r"dt|th", "t", w)
    w = re.sub(r"([aeiou])h", r"\1", w)
    w = w.replace("v", "f").replace("c", "k").replace("y", "i")
    return re.sub(r"(.)\1+", r"\1", w)
SWAP_NATIVE = ("haus", "turm", "berg", "wald", "ramp", "snow", "eis", "see")
def swapped(word):
    from . import wish
    if not 3 <= len(word) <= 4 or word in _protected() or not word.isalpha():
        return None
    freq = (data().get("everyday") or {}).get("freq") or {}
    if word in freq:
        return None
    hits = {}
    for i in range(len(word) - 1):
        s = word[:i] + word[i + 1] + word[i] + word[i + 2:]
        if s == word:
            continue
        hit = index().get(s)
        if hit is None and (s in wish.VOCAB or s in SWAP_NATIVE):
            hit = ({"id": "native:" + s, "canon": s}, False)
        if hit is not None:
            hits.setdefault(hit[0]["id"], (hit[0], hit[1], s))
    if len(hits) != 1:
        return None
    c, pl, f = list(hits.values())[0]
    return c, pl, f, 0.75
def everyday_typo(w):
    freq = (data().get("everyday") or {}).get("freq") or {}
    if not 3 <= len(w) <= 6 or w in freq or w in _protected() or not w.isalpha():
        return None
    best = None
    for cand, n in freq.items():
        if abs(len(cand) - len(w)) > 1 or len(cand) < 3:
            continue
        if cand[0] != w[0] and cand[:2] != w[1::-1]:
            continue
        if distance(w, cand, 1) == 1 and (best is None or n > best[1]):
            best = (cand, n)
    return best
def suggest(word, n=3):
    w = _fold(word)
    if not w or " " in w:
        return []
    cap = 1 if len(w) <= 4 else 2
    best = []
    for f, (c, pl) in _pool():
        if abs(len(f) - len(w)) > cap or c["id"].startswith("native:"):
            continue
        d = distance(w, f, cap)
        if d <= cap:
            best.append((d, f, c))
    best.sort(key=lambda t: (t[0], t[1]))
    out, seen = [], set()
    for d, f, c in best:
        if c["id"] in seen:
            continue
        seen.add(c["id"])
        out.append((f, c["id"], c.get("expect") or c.get("set") or {}))
        if len(out) >= n:
            break
    return out
def lookup(word):
    w = _fold(word)
    hit = phrases_index().get(w) or index().get(w)
    if hit:
        return hit[0], canon_of(hit[0], hit[1]), 1.0, "exact"
    if " " not in w:
        parts = split(w)
        if parts:
            return None, " ".join(_parts()[p] for p in parts), 0.95, "compound"
        fz = fuzzy(w)
        if fz:
            return fz[0], canon_of(fz[0], fz[1]), fz[3], "fuzzy"
    return None
THING_FIELDS = ("thing.",)
def _thing_alt():
    if "thing_alt" in _cache:
        return _cache["thing_alt"]
    from . import wish
    words = set()
    for f, (c, _) in list(index().items()) + list(phrases_index().items()):
        if c["id"].startswith(THING_FIELDS) and c["id"] not in ("thing.start", "thing.finish",
                                                                  "thing.spawns", "thing.world_spawn"):
            words.add(f)
    for c in concepts():
        if c["id"].startswith(THING_FIELDS):
            for k in ("canon", "canon_pl"):
                if c.get(k):
                    words.add(c[k])
    words.update(("wasser", "lava", "zaeune", "zaun", "mauern", "mauer", "treppen", "treppe",
                  "rampen", "bruecken", "bruecke", "tuerme", "turm", "brucken", "tuerme",
                  "gelaender", "tunnel", "tunnels", "boegen", "saeulen", "huegel", "inseln",
                  "water", "fences", "walls", "stairs", "ramps", "bridges", "towers", "rails",
                  "arches", "pillars", "columns", "islands", "gaps", "pits", "holes", "trees",
                  "baeume", "kisten", "crates", "gruben", "luecken", "spruenge", "jumps"))
    alt = "|".join(sorted((re.escape(w) for w in words if len(w) >= 3), key=len, reverse=True))
    _cache["thing_alt"] = alt
    return alt
AMOUNT_GRADES = (
    ("trace", r"kaum noch|kaum|hardly any|hardly|barely any|barely|scarcely any|almost no|"
              r"next to no|fast keine?[nmrs]?|fast gar keine?[nmrs]?|so gut wie keine?[nmrs]?|"
              r"nur ganz wenig\w*|very few|very little|sehr wenig\w*"),
    ("less", r"nicht so viele?[nmrs]?|nicht zu viele?[nmrs]?|not so many|not so much|"
             r"not too many|not too much|not as much|not as many|not much|not many|"
             r"nicht viele?[nmrs]?|weniger|less|fewer"),
    ("few", r"nur wenige?n?|nur wenig|wenig|wenige|wenigen|wenigem|weniges|a little|a few|"
            r"a couple of|ein paar|ein bisschen|ein wenig|bisschen|vereinzelte?[nmrs]?|einzelne|only a few|few|"
            r"sparse|spaerliche?[nmrs]?"),
    ("more", r"viel mehr|noch mehr|lots more|much more|mehr|more|extra|zusaetzliche?[nmrs]?"),
    ("lots", r"jede menge|eine menge|haufenweise|massig|massenhaft|unmengen an|unmengen von|"
             r"tonnenweise|lots of|a lot of|tons of|loads of|plenty of|heaps of|masses of|"
             r"ganz viele?[nmrs]?|sehr viele?[nmrs]?|richtig viele?[nmrs]?|viele?[nmrs]?|"
             r"many|much|a ton of|overflowing with|voller|full of"),
)
LESS_WORDS = AMOUNT_GRADES[1][1]
MORE_WORDS = AMOUNT_GRADES[3][1]
AMOUNT_WORDS = {"trees": ("baeume", "baeumen", "baum", "trees", "tree", "wald", "waelder",
                          "forest", "forests", "woods", "palmen", "palms"),
                "terrain": ("huegel", "huegeln", "hills", "hill", "berge", "bergen",
                            "mountains", "bergig"),
                "cover_walls": ("deckung", "deckungen", "cover", "deckungsmauern"),
                "lava": ("lava", "magma", "lavaseen", "lavafluesse"),
                "water": ("wasser", "water", "seen", "lakes", "teiche", "ponds"),
                "buildings": ("haeuser", "haeusern", "houses", "gebaeude", "gebaeuden",
                              "buildings", "huetten")}
_AMOUNT_RX = []
_AMOUNT_THING = {}
def _amount_rx():
    if not _AMOUNT_RX:
        alts = []
        for grade, words in AMOUNT_GRADES:
            for w in words.split("|"):
                alts.append((w, grade))
        alts.sort(key=lambda t: -len(t[0]))
        _AMOUNT_RX.append(re.compile(r"\b(%s)\s+(?:(?:the|an|a|der|die|das|den|an)\s+)?"
                                     r"([a-z]+)" % "|".join("(?:%s)" % w for w, _ in alts)))
        _AMOUNT_RX.append([(re.compile(r"(?:%s)$" % w), g) for w, g in alts])
    return _AMOUNT_RX
def amount_spans(low):
    from . import negation
    rx, grades = _amount_rx()
    out = []
    for m in rx.finditer(low):
        word, first = m.group(1), m.group(2)
        grade = next(g for r, g in grades if r.fullmatch(word))
        hit = [k for k, ws in AMOUNT_WORDS.items() if first in ws]
        if not hit:
            if first not in _AMOUNT_THING:
                from . import wish
                _AMOUNT_THING[first] = list((wish.understand("mit " + first).raw.get(
                    "features") or {}).get("want", []))
            hit = list(_AMOUNT_THING[first])
        if not hit:
            continue
        cued = negation.CUE.search(word) is not None
        out.append((m.start(), m.end(1), grade, hit, cued))
    return out
def amounts(low):
    out = {}
    for _, _, grade, feats, _ in amount_spans(low):
        for f in feats:
            out.setdefault(f, grade)
    return out
def _rules(scope):
    key = "rules_" + scope
    if key in _cache:
        return _cache[key]
    d = data()
    rows = []
    src = list(d["phrases"])
    if scope == "refine":
        src = list(d.get("refine_phrases", [])) + src
    for i, ph in enumerate(src):
        sc = ph.get("scope", "refine" if ph in d.get("refine_phrases", []) else "both")
        if sc not in ("both", scope):
            continue
        pat = ph["re"].replace("{thing}", "(?:%s)" % _thing_alt())
        rows.append((re.compile(pat), ph))
    _cache[key] = rows
    return rows
DE_WORDS = set("und mit der die das ein eine einen nicht kein keine ohne bitte im in auf ist "
               "mir mach ich sehr viel viele wie oder aber auch fuer".split())
EN_WORDS = set("and with the a an not no without please in on is me make i very much many "
               "like or but also for some".split())
def german(low):
    words = re.findall(r"[a-z]+", low)
    de = sum(1 for w in words if w in DE_WORDS)
    en = sum(1 for w in words if w in EN_WORDS)
    return de > en
def _slot_name(n):
    s = ""
    n += 1
    while n:
        n, k = divmod(n - 1, 26)
        s = chr(97 + k) + s
    return SLOT + s
class Prepared:
    def __init__(self, low):
        self.low = low
        self.notes = []
        self.slots = {}
        self.lexicon = []
        self.modifiers = []
def _protect(low):
    spans = []
    for m in re.finditer(r"(?:(?<=\s)|^)[\"'„“‘‚]([^\"'“”‘’]{2,40})"
                         r"[\"'“”‘’]", low):
        spans.append((m.start(), m.end()))
    for m in re.finditer(r"(?:namens|genannt|heisst|called|named|name[:=]?)\s+[^,;.!?]{1,40}", low):
        spans.append((m.start(), m.end()))
    for m in re.finditer(r"\b(?:musik|music|track|song|lied|soundtrack)\s*[:=]\s*[^;.!?]{1,40}",
                         low):
        spans.append((m.start(), m.end()))
    return spans
def prepare(low, scope="wish"):
    P = Prepared(low)
    spans = _protect(low)
    saved = []
    for a, b in sorted(spans, reverse=True):
        piece = low[a:b]
        saved.append(piece)
        low = low[:a] + " zzqp%s " % _slot_name(len(saved) - 1)[len(SLOT):] + low[b:]
    low = _multi(P, low)
    low = _join_split(P, low)
    is_de = german(low)
    for rx, ph in _rules(scope):
        if ph.get("lang") == "de" and not is_de:
            continue
        low = _apply_rule(P, rx, ph, low)
    low = _eager(P, low)
    low = _numbers(P, low)
    low = _compounds(P, low)
    for i in range(len(saved) - 1, -1, -1):
        low = low.replace(" zzqp%s " % _slot_name(i)[len(SLOT):], saved[i], 1)
    P.low = re.sub(r"[ \t]+", " ", low)
    return P
def _join_split(P, low):
    if "bigrams" not in _cache:
        grams = set()
        for p in phrases_index():
            ws = p.split()
            grams.update(" ".join(ws[i:i + 2]) for i in range(len(ws) - 1))
        _cache["bigrams"] = grams
    grams = _cache["bigrams"]
    def fix(m):
        a, b = m.group(1), m.group(2)
        joined = a + b
        if len(joined) < 7 or (a + " " + b) in grams:
            return m.group(0)
        if joined in NATIVE_EXTRA or (joined in index() and not index()[joined][0].get("set")
                                      and len(a) >= 3 and len(b) >= 3):
            P.notes.append(("assumed", "'%s %s' read as '%s'" % (a, b, joined)))
            return joined
        return m.group(0)
    return re.sub(r"(?<![a-z0-9])([a-z]{3,})[ -]([a-z]{3,})(?![a-z0-9])", fix, low)
def _apply_rule(P, rx, ph, low):
    out, last = [], 0
    for m in rx.finditer(low):
        if SLOT in m.group(0) or "zzqp" in m.group(0):
            continue
        out.append(low[last:m.start()])
        rep = _replacement(P, m, ph)
        out.append(rep)
        last = m.end()
    out.append(low[last:])
    return "".join(out)
def _replacement(P, m, ph):
    text = m.group(0).strip()
    if "set" in ph:
        name = _slot_name(len(P.slots))
        P.slots[name] = (ph["set"], (ph.get("say") or "%s") % text if ph.get("say") else None,
                         text)
        return " %s " % name
    if "fn" in ph:
        rep = FUNCS[ph["fn"]](m)
    else:
        rep = m.expand(ph["to"])
    if ph.get("say"):
        P.notes.append(("assumed", ph["say"] % text))
    if rep.strip() != text:
        P.lexicon.append("'%s' -> '%s'" % (text, rep.strip()))
    lead = " " if m.group(0)[:1] == " " else ""
    return lead + rep
def _slot_for(P, c, form):
    name = _slot_name(len(P.slots))
    P.slots[name] = (c["set"], say_of(c, form) or "'%s' read as %s" % (form, c["id"]), form)
    return name
def _multi(P, low):
    if "multi_rx" not in _cache:
        alts = [re.escape(p).replace(r"\ ", "[ -]") for p in _cache.get("multi_sorted") or
                (_build() or _cache["multi_sorted"])]
        _cache["multi_rx"] = re.compile(r"(?<![a-z0-9])(%s)(?![a-z0-9])" % "|".join(alts))
    pidx = phrases_index()
    def fix(m):
        form = m.group(1).replace("-", " ")
        c, pl = pidx[form]
        canon = canon_of(c, pl)
        if canon is None:
            canon = _slot_for(P, c, form)
        elif say_of(c, form):
            P.notes.append(("assumed", say_of(c, form)))
        if canon != form:
            P.lexicon.append("'%s' -> '%s'" % (form, c["id"] if canon.startswith(SLOT)
                                                else canon))
        return canon
    return _cache["multi_rx"].sub(fix, low)
def _eager(P, low):
    from . import wish
    idx = index()
    prot = _protected()
    def fix(m):
        w = m.group(0)
        hit = idx.get(w)
        if hit is None or w in prot:
            return w
        c, pl = hit
        canon = canon_of(c, pl)
        if canon == w:
            return w
        native, consumed = wish.native(w)
        if not native and not consumed:
            return w
        extra = _whole_plus(P, w)[len(w):] if len(w) >= 6 else ""
        if canon is None:
            name = _slot_for(P, c, w)
            P.lexicon.append("'%s' -> '%s'" % (w, c["id"]))
            return name + extra
        if native == wish.native_lines(canon):
            return w + extra
        if say_of(c, w):
            P.notes.append(("assumed", say_of(c, w)))
        P.lexicon.append("'%s' -> '%s'" % (w, canon))
        return canon + extra
    return re.sub(r"(?<![a-z0-9])[a-z]+(?![a-z0-9])", fix, low)
def _teams_of(m):
    n = int(m.group(1) or m.group(2))
    return "%d vs %d" % (n, n)
def _many_teams(m):
    ns = [int(g) for g in m.groups() if g]
    return "%d spieler, %d teams" % (sum(ns), len(ns))
def _spread_negation(m):
    neg = m.group(1)
    first = m.group(2)
    rest = re.split(r"\s*(?:,|\bund\b|\boder\b|\band\b|\bor\b|\bnoch\b|\bnor\b)\s*", m.group(3))
    rest = [r for r in rest if r.strip()]
    return ", ".join(["%s %s" % (neg, first)] + ["%s %s" % (neg, r.strip()) for r in rest])
def _swap_order(m):
    return "statt %s ein %s" % (m.group(4), m.group(1))
def _vs_words(m):
    from . import wish
    a, b = (wish.NUMBERS.get(x, x) for x in (m.group(1), m.group(2)))
    return "%s vs %s" % (a, b)
FUNCS = {"vs_words": _vs_words, "teams_of": _teams_of, "many_teams": _many_teams,
         "spread_negation": _spread_negation, "swap_order": _swap_order}
def _numbers(P, low):
    nums = data()["numbers"]
    for w in sorted(nums, key=len, reverse=True):
        rx = r"(?<![a-z0-9])%s(?![a-z0-9])" % re.escape(w)
        if re.search(rx, low):
            low = re.sub(rx, str(nums[w]), low)
            P.lexicon.append("'%s' -> %d" % (w, nums[w]))
    return low
def _part_word(p):
    from . import wish
    if p in PART_SENSE:
        return PART_SENSE[p]
    if wish.native_lines(p):
        return p
    return _parts()[p]
WHOLE_ONLY = {"piratenbucht", "wasserfall", "leuchtturm", "windmuehle", "hochhaus", "burggraben",
              "wassergraben", "seeufer", "sandstrand", "flussbett", "kirchturm", "glockenturm",
              "wachturm", "baumhaus", "schneemann", "eisberg", "feuerwerk"}
PART_SENSE = {"mountain": "mountains", "berg": "berg"}
def _whole_plus(P, w):
    from . import wish
    if w in data()["keep_whole"] or w in WHOLE_ONLY:
        return w
    parts = split(w, inner=True)
    if not parts:
        return w
    whole = index()[w][0]
    if not whole["id"].startswith(("thing.", "preset.", "idiom.")):
        return w
    extra = []
    for p in parts:
        hit = index().get(p)
        pid = hit[0]["id"] if hit else None
        if pid == whole["id"]:
            continue
        word = _part_word(p)
        lines = wish.native_lines(word)
        if not any(re.match(r"(want|preset|theme) ", x) for x in lines):
            continue
        if whole["id"].startswith("preset.") and all(re.match(r"(preset|theme) ", x)
                                                     for x in lines):
            continue
        extra.append(word)
    if not extra:
        return w
    P.lexicon.append("'%s' = %s + %s" % (w, w, " + ".join(extra)))
    return w + " " + " ".join(extra)
def _compounds(P, low):
    from . import wish
    prot = _protected()
    idx = index()
    def fix(m):
        w = m.group(0)
        if len(w) < 6 or w in prot or w.startswith((SLOT, "zzqp")):
            return w
        if w in idx:
            return _whole_plus(P, w)
        parts = split(w)
        if not parts:
            return w
        canon = " ".join(_part_word(p) for p in parts)
        whole = wish.native_lines(w)
        split_lines = wish.native_lines(canon)
        if not split_lines or (whole and not (whole < split_lines)):
            return w
        P.lexicon.append("'%s' = %s" % (w, " + ".join(parts)))
        P.modifiers.append((w, [_parts()[p] for p in parts[:-1]]))
        return canon
    return re.sub(r"[a-z]+", fix, low)
def rewrite(low, free, P):
    reps = []
    is_de = german(low) or bool(re.search(r"ae|oe|ue|ss", low)) and not re.search(
        r"\b(the|and|with|a)\b", low)
    _FUZZY_DE[0] = is_de
    i = 0
    multi = _cache.get("multi_sorted") or (_build() or _cache["multi_sorted"])
    pidx = phrases_index()
    maxn = max((p.count(" ") + 1 for p in pidx), default=1)
    while i < len(free):
        done = False
        for n in range(min(maxn, len(free) - i), 1, -1):
            group = free[i:i + n]
            if any(not re.fullmatch(r"[\s\-]*", low[group[k][1]:group[k + 1][0]])
                   for k in range(n - 1)):
                continue
            if all(g[3] for g in group):
                continue
            phrase = " ".join(g[2] for g in group)
            hit = pidx.get(phrase)
            if hit:
                c, pl = hit
                reps.append((group[0][0], group[-1][1], phrase, c, pl, 1.0, "exact"))
                i += n
                done = True
                break
        if done:
            continue
        a, b, w, stop = free[i]
        i += 1
        if stop or w.startswith((SLOT, "zzqp")):
            continue
        hit = index().get(w)
        if hit:
            reps.append((a, b, w, hit[0], hit[1], 1.0, "exact"))
            continue
        run = _letter_run(w)
        if run:
            reps.append((a, b, w, run[0], run[1], 0.9, "fuzzy:" + run[2]))
            continue
        mo = morph(w) if is_de else None
        if mo:
            reps.append((a, b, w, mo[0], mo[1], 1.0, "morph:" + mo[2]))
            continue
        hc = head_compound(w) if is_de else None
        if hc:
            reps.append((a, b, w, hc[0], hc[1], 0.9, "head:" + hc[2]))
            continue
        from . import commonguard
        if commonguard.ordinary(w):
            continue
        fz = fuzzy(w) or swapped(w)
        if fz:
            reps.append((a, b, w, fz[0], fz[1], fz[3], "fuzzy:" + fz[2]))
            continue
        ev = everyday_typo(w)
        if ev:
            reps.append((a, b, w, {"id": "native:" + ev[0], "canon": ev[0]}, False, 0.9,
                         "everyday:" + ev[0]))
    if not reps:
        return low
    out = low
    for a, b, w, c, pl, conf, how in sorted(reps, key=lambda r: -r[0]):
        canon = canon_of(c, pl)
        if canon is None:
            name = _slot_name(len(P.slots))
            P.slots[name] = (c["set"], say_of(c, w) or "'%s' read as %s" % (w, c["id"]), w)
            canon = name
        out = out[:a] + canon + out[b:]
        if how.startswith("fuzzy"):
            P.notes.append(("assumed", "typo: %r read as %r (confidence %.2f)" % (
                w, how.split(":", 1)[1], conf)))
            P.confidence = min(getattr(P, "confidence", 1.0), conf)
        elif how.startswith("everyday"):
            P.notes.append(("assumed", "typo: %r read as %r (the most frequent word one "
                                       "letter off)" % (w, how.split(":", 1)[1])))
        elif how.startswith("head"):
            P.notes.append(("assumed", "%r read as %r (its head says nothing more)"
                            % (w, how.split(":", 1)[1])))
        say = say_of(c, w)
        if say and canon_of(c, pl) is not None:
            P.notes.append(("assumed", say))
        P.lexicon.append("'%s' -> '%s'" % (w, canon if not canon.startswith(SLOT) else c["id"]))
    return out
SIZE_ORDER = ("tiny", "small", "medium", "large", "huge", "gigantic")
def apply(r, low, P, base=None):
    from . import wish
    raw = r.raw
    for m in re.finditer(r"\b%s[a-z]+\b" % SLOT, low):
        got = P.slots.get(m.group(0))
        if got is None:
            continue
        sets, say, text = got
        r.take(m)
        neg = wish._negated(low, m.start())
        if neg:
            wish._take_negation(r, low, m.start())
        if say:
            r.said(say if not neg else "not: " + say)
        if neg and re.search(r"symmetr", text) and "symmetry" not in raw:
            raw["symmetry"] = "none"
            r.said("symmetry none (not symmetric)")
        for k, v in sets.items():
            if k == "want":
                feats = raw.setdefault("features", {"want": [], "avoid": []})
                from . import brief as briefmod
                for f in v:
                    if f not in briefmod.FEATURES:
                        continue
                    side = "avoid" if neg else "want"
                    other = "want" if neg else "avoid"
                    if f not in feats[side]:
                        feats[side].append(f)
                    if f in feats[other]:
                        feats[other].remove(f)
                    r.said("%s %s" % (side, f))
            elif k == "visuals":
                if neg:
                    continue
                vis = raw.setdefault("visuals", [])
                for x in v:
                    if x not in vis:
                        vis.append(x)
            elif k == "dna":
                dna = raw.setdefault("dna", {})
                for kk, vv in v.items():
                    dna.setdefault(kk, vv)
            elif k == "step":
                for field, n in v.items():
                    cur = (base or {}).get(field) or raw.get(field) or "medium"
                    if not isinstance(cur, str) or cur not in SIZE_ORDER:
                        cur = "medium"
                    i = max(0, min(len(SIZE_ORDER) - 1, SIZE_ORDER.index(cur) + n))
                    raw[field] = SIZE_ORDER[i]
                    r.said("%s %s (%+d steps from %s)" % (field, SIZE_ORDER[i], n, cur))
            elif k in ("surprise", "novel", "reject"):
                if neg:
                    continue
                nov = dict(raw.get("novelty") or {})
                nov["mode"] = {"surprise": "surprise", "novel": "novel",
                               "reject": "reject"}[k] if nov.get("mode") != "reject" else "reject"
                raw["novelty"] = nov
                if k == "reject":
                    aspects = _reject_aspects(low, r)
                    if aspects:
                        nov["avoid"] = aspects
                for mm in re.finditer(NOVELTY_WORDS, low):
                    r.take(mm)
            elif k == "split_spawns":
                feats = raw.setdefault("features", {"want": [], "avoid": []})
                side = "avoid" if neg else "want"
                if "split_spawns" not in feats[side]:
                    feats[side].append("split_spawns")
                raw.setdefault("sides", "2")
            elif k == "variety":
                if not neg:
                    raw.setdefault("variety", v)
            elif k == "request":
                if neg and v.get("kind") == "stars":
                    reqs = [q for q in raw.get("requests") or [] if q.get("kind") != "stars"]
                    raw["requests"] = reqs + [{"kind": "stars", "count": 0}]
                    r.said("no bonus stars")
                    continue
                if neg:
                    continue
                req = dict(v)
                n = _count_before(low, m.start())
                if n:
                    req["count"] = n[0]
                    r.take(n[1])
                reqs = raw.setdefault("requests", [])
                if req not in reqs:
                    reqs.append(req)
                r.said("requested %s%s%s (the gameplay pass builds it where it fits)" % (
                    req["kind"], " (%s)" % req["sub"].replace("_", " ") if req.get("sub") else "",
                    " x%d" % req["count"] if req.get("count") else ""))
            elif k == "forge_off":
                if neg:
                    continue
                from . import negation
                ex = re.match(r"\s*(?:%s)" % negation.EXCEPT.pattern, low[m.end():])
                if ex:
                    r.consumed.append((m.end(), m.end() + ex.end()))
                    r.said("%s stay on: only what follows '%s' is named" % (
                        ", ".join(v), ex.group(0).strip()))
                    continue
                off = raw.setdefault("forge_off", [])
                for x in v:
                    if x not in off:
                        off.append(x)
                r.said("Forge objects off: %s" % ", ".join(v))
            else:
                if neg:
                    continue
                if k not in raw:
                    raw[k] = v
                    r.said("%s %s" % (k, v))
    if raw.get("features") == {"want": [], "avoid": []}:
        raw.pop("features")
ASPECT_WORDS = [
    (r"formation|aufbau|anordnung|layout|grundriss|skelett|skeleton|struktur|structure|form\b|"
     r"shape|aufteilung", "formation"),
    (r"thema|theme|textur\w*|farben|colou?rs|look|optik|material\w*", "theme"),
    (r"groesse|size|so gross|so klein", "size"),
    (r"preset|vorlage|dorf|burg|stadt|wald", "preset"),
    (r"tuerme|towers|bruecken|bridges|features|sachen|elemente|elements", "features"),
]
NOVELTY_WORDS = (r"\b(einige|ein paar|mehrere|viele|several|many|a few)\s+(male?|times)\b|"
                 r"\b(andere[nrs]?|anders|different|other|neue[nrs]?|new|before|vorher|zuvor|"
                 r"davor|bisher|already|bereits|so oft|too often|zu oft)\b")
def _reject_aspects(low, r=None):
    out = []
    for pat, a in ASPECT_WORDS:
        for m in re.finditer(r"\b(%s)" % pat, low):
            if a not in out:
                out.append(a)
            if r is not None:
                r.take(m)
    return out
def _count_before(low, at):
    from . import wish
    m = re.search(r"(\d+|%s)\s+(\w+\s+)?$" % "|".join(
        sorted((k for k in wish.NUMBERS if k.isalpha()), key=len, reverse=True)), low[:at])
    if not m:
        return None
    n = int(m.group(1)) if m.group(1).isdigit() else wish.NUMBERS.get(m.group(1))
    if not n or n < 2 and not m.group(1).isdigit():
        return None
    return n, m
def summary(per=6):
    out = []
    for c in concepts():
        forms = []
        for f in c.get("forms", []):
            ff = expand(f)[0][0]
            if ff not in forms:
                forms.append(ff)
            if len(forms) >= per:
                break
        what = json.dumps(c.get("expect") or c.get("set") or {}, sort_keys=True,
                          ensure_ascii=False)
        out.append("  %s %s: %s" % (c["id"], what, ", ".join(forms)))
    return out
