import re
CUE = re.compile(
    r"\b(?:anything but|anything except|everything but|everything except|all but|"
    r"alles ausser|alles bis auf|alles nur nicht|bloss nicht|bloss keine?[nmrs]?|"
    r"bitte nicht|bitte keine?[nmrs]?|auf keinen fall|nichts mit|nix mit|nothing with|"
    r"zero|skip the|skip any|lose the|ditch the|drop the|get rid of(?: the)?|free of|"
    r"no more|not any|don'?t|do not|doesn'?t|does not|won'?t|will not|isn'?t|is not|"
    r"keinerlei|keine?[nmrs]?|kein|ohne|nicht|nichts|nothing|nix|nie|never|without|not|no|"
    r"avoid|vermeide\w*|weg mit)\b")
BOUNDARY = set("""aber sondern eher lieber dafuer stattdessen statt jedoch trotzdem nur
but rather instead however only just yes ja sowie plus ausserdem dazu zusaetzlich also
additionally mit with lieber vielmehr""".split())
NEW_PHRASE = set("""ein eine einen einem einer eines a an the der die das den dem viel viele
vielen many lots some ganz grosse grosser grossen grosses kleine kleiner kleinen grosse
mehrere several zwei drei vier fuenf two three four five
bei im am nachts abends tagsueber morgens at during by""".split())
LOCATIVE = re.compile(r"(?:im|in der|in dem|am|an der|auf der|auf dem|beim|in the|at the|"
                      r"on the|near the|inside the)\s+(?:\w+\s+)?\w*(?:dorf|village|stadt|town|city|"
                      r"wald|forest|burg|castle|schloss|haus|house|garten|garden|insel|island|"
                      r"mitte|middle|centre|center|tal|valley|land|welt|world)\b")
POSTPOSED = re.compile(r"[a-z]+\s+(?:nein|no|nope|bitte nicht|lieber nicht|rather not)\b"
                       r"(?=\s*(?:[,;.!?]|$|aber\b|but\b|und\b|and\b))")
LIST = {"und", "and", "oder", "or", "noch", "nor", "&", "sowie"}
SCOPE_WORDS = 8
EXCEPT = re.compile(r"\b(?:ausser|ausgenommen|bis auf|except(?: for)?|other than|apart from|"
                    r"besides|but)\b")
CORRECT = re.compile(r"\b(?:eher|lieber|vielmehr|sondern|stattdessen|dafuer|rather|instead|"
                     r"more like|but rather)\b")
TOKEN = re.compile(r"[a-z0-9'&]+|[,;.!?:\n]")
AFFIRM = re.compile(r"\b([a-z]+)\s+(?:ja|yes|gerne|gern)\b(?=\s*[,;.!?]|\s+aber\b|"
                    r"\s+but\b|\s*$)")
_cache = {}
_things = []
def _thing_at(low, at):
    if not _things:
        from . import wish
        _things.extend(re.compile(p) for p, _, _ in wish.THINGS)
    return any(p.match(low, at) for p in _things)
def _analyse(low):
    if low in _cache:
        return _cache[low]
    out = []
    toks = list(TOKEN.finditer(low))
    for c in CUE.finditer(low):
        s, e = c.start(), c.end()
        if any(s0 <= s < e0 for s0, e0, _, _ in out):
            continue
        end = len(low)
        excs = []
        after = [t for t in toks if t.start() >= e]
        i = 0
        run = 0
        seen = False
        while i < len(after):
            t = after[i]
            w = t.group(0)
            if w in ",;.!?:\n":
                end = t.start()
                break
            joined = i and after[i - 1].group(0) in LIST
            if w in LIST:
                run = 0
            else:
                run += 1
                thing = _thing_at(low, t.start())
                if (run > SCOPE_WORDS or (thing and seen)) and not joined:
                    end = t.start()
                    break
                seen = seen or thing
            if w in BOUNDARY:
                end = t.start()
                break
            if i > 0 and LOCATIVE.match(low, t.start()):
                end = t.start()
                break
            if w in LIST and i + 1 < len(after) and (after[i + 1].group(0) in NEW_PHRASE or
                                                     after[i + 1].group(0).isdigit()):
                end = t.start()
                break
            ex = EXCEPT.match(low, t.start())
            if ex and i > 0:
                stop = len(low)
                for u in after[i + 1:]:
                    if u.group(0) in ",;.!?:\n" or u.group(0) in BOUNDARY:
                        stop = u.start()
                        break
                excs.append((t.start(), stop))
                end = t.start()
                break
            i += 1
        out.append((s, e, end, excs))
    _cache[low] = out
    if len(_cache) > 4000:
        _cache.clear()
    return out
def cue(low, at):
    hit = None
    for s, e, end, _ in _analyse(low):
        if e <= at < end:
            hit = (s, e)
    return hit
def negated(low, at):
    return cue(low, at) is not None or POSTPOSED.match(low, at) is not None
def exception_after(low, at):
    for s, e, end, excs in _analyse(low):
        if excs and s <= at <= end + 1:
            return excs[0]
    return None
def correction_after(low, at, reach=40):
    m = CORRECT.search(low, at, min(len(low), at + reach))
    if not m:
        return None
    stop = re.search(r"[,;.!?]|\b(aber|but|und|and)\b", low[m.end():])
    return m.end(), m.end() + (stop.start() if stop else len(low) - m.end())
def affirmed(low):
    return {m.group(1): (m.start(), m.end()) for m in AFFIRM.finditer(low)}
