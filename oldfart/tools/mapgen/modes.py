import os
import re
from . import v1
FAMILY = {
    "shooter": ("shooter", "oitc", "rocketarena", "wanted",
                "assassins", "laststanding", "crown", "coinrush", "greendemon", "bank",
                "murder", "bounty"),
    "objective": ("ctf", "oneflag", "domination", "koth", "football", "volleyball", "copsandrobbers"),
    "knockoff": ("sumo", "smash", "bumperballs", "chompfever", "logroll", "megarampage",
                 "hotpotato", "deflect"),
    "race": ("shellrace", "shellbattle", "downhill", "line", "flood"),
    "hide": ("hideseek", "sardines", "prophunt", "manhunt", "zombies", "rabbitchase",
             "hideballoon"),
    "party": ("bombsaway", "bombxing", "booksquirm", "lavaleave", "hotrope", "blizzard",
              "blast", "glassbridge", "turf", "spots", "simon", "frenzy", "blastgrid",
              "bombsort", "flyguy", "lakitu", "hexheat", "hexagone"),
    "course": ("onoffclimb", "silverfive", "course"),
}
FAMILY_OF = {k: fam for fam, keys in FAMILY.items() for k in keys}
_cache = {}
_files = {}
def all(repo=None):
    repo = repo or v1.REPO
    if repo in _cache:
        return dict(_cache[repo])
    out = {}
    try:
        names = sorted(n for n in os.listdir(repo) if n.startswith("of_gm_") and n.endswith(".lua"))
    except OSError:
        names = []
    for n in names:
        try:
            with open(os.path.join(repo, n), encoding="utf-8") as handle:
                text = handle.read()
        except OSError:
            continue
        at = text.find("\nlocal mode = {")
        if at < 0:
            continue
        end = text.find("\n}\n", at)
        body = text[at:end if end > 0 else at + 12000]
        k = re.search(r'\n    key = "([a-z0-9]+)"', body)
        nm = re.search(r'\n    name = "([^"]+)"', body)
        if k:
            out[k.group(1)] = nm.group(1) if nm else k.group(1)
            _files.setdefault(repo, {})[k.group(1)] = n
    _cache[repo] = out
    return dict(out)
def file_of(key, repo=None):
    repo = repo or v1.REPO
    all(repo)
    return _files.get(repo, {}).get(key)
_venue_family = {}
def family_of(key, repo=None):
    repo = repo or v1.REPO
    if (repo, key) not in _venue_family:
        fam = None
        name = file_of(key, repo)
        if name:
            try:
                with open(os.path.join(repo, name), encoding="utf-8") as handle:
                    m = re.search(r'\n    venueFamily = "([a-z]+)"', handle.read())
                fam = m.group(1) if m and m.group(1) in FAMILY else None
            except OSError:
                fam = None
        _venue_family[(repo, key)] = fam
    return _venue_family[(repo, key)] or FAMILY_OF.get(key)
def keys_for(family):
    have = all()
    return [k for k in FAMILY.get(family, ()) if k in have] or list(FAMILY.get(family, ()))
GENERIC_KEYS = {"spots", "line", "flood", "crown", "bank", "turf", "blast", "frenzy",
                "deflect", "simon", "course", "smash", "murder", "bounty", "wanted"}
RENAMED_KEYS = {"blizzard", "bombxing", "blast", "chompfever", "booksquirm", "hexheat",
                "bumperballs", "hotrope", "bombsaway", "goombabowl", "lavaleave", "smash"}
OLD_TITLES = ("mr blizzards brigade", "bob omb x ing", "bowsers bigger blast",
              "chain chomp fever", "booksquirm", "hexagon heat", "bumper balls",
              "hot rope jump", "bombs away", "goomba bowling", "lava or leave em")
def blank_old_titles(text):
    found = []
    for t in OLD_TITLES:
        words = t.split()
        parts = [re.escape(w[:-1]) + "['\u2019]?s" if len(w) > 3 and w.endswith("s")
                 else re.escape(w) for w in words]
        rx = re.compile(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % r"[^A-Za-z0-9]*".join(parts),
                        re.I)
        m = rx.search(text)
        while m:
            found.append(m.group(0))
            text = text[:m.start()] + " " * (m.end() - m.start()) + text[m.end():]
            m = rx.search(text)
    return text, found
def strip_old_titles(low):
    flat = re.sub(r"[^a-z0-9]+", " ", low)
    for t in OLD_TITLES:
        flat = re.sub(r"(?<![a-z0-9])%s(?![a-z0-9])" % re.escape(t), " ", flat)
    return flat
def lookup(text):
    low = " " + re.sub(r"[^a-z0-9äöüß]+", " ", text.lower()) + " "
    found = []
    table = sorted(all().items(), key=lambda kv: -len(kv[1]))
    for key, name in table:
        nm = " " + re.sub(r"[^a-z0-9äöüß]+", " ", name.lower()).strip() + " "
        if len(nm.strip()) >= 4 and nm in low:
            found.append((key, FAMILY_OF.get(key), name))
            low = low.replace(nm, " ")
        elif len(key) >= 4 and (" %s " % key) in low and key not in GENERIC_KEYS \
                and key not in RENAMED_KEYS:
            found.append((key, FAMILY_OF.get(key), key))
            low = low.replace(" %s " % key, " ")
    return found
