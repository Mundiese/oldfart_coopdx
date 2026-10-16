import re
from . import wish
FAMILY_SAY = {
    "en": {"shooter": "a shooter arena", "hide": "a hide-and-seek map",
           "explore": "a world to explore", "race": "a race track",
           "course": "an obstacle course", "objective": "a team map with goals (flags, points)",
           "knockoff": "a knock-off arena", "party": "a party arena"},
    "de": {"shooter": "eine Shooter-Arena", "hide": "eine Versteck-Map",
           "explore": "eine Welt zum Erkunden", "race": "eine Rennstrecke",
           "course": "ein Parkour", "objective": "eine Team-Map mit Zielen (Flaggen, Punkte)",
           "knockoff": "eine Schubs-Arena", "party": "eine Party-Arena"},
}
WORDS = {
    "en": {"with": "with %s", "without": "without %s", "size": "size: %s",
           "theme": "looks like: %s", "players": "%s players", "sides": "two teams",
           "ffa": "everyone against everyone", "guess": "I guessed: %s",
           "unknown": "I don't know the word '%s'.",
           "unknown_group": "I couldn't read '%s'.",
           "place": "'%s' says WHERE, but not WHAT should go there.",
           "spawn_where": "Where should the world spawn be?",
           "no_spawns": "A map needs spawns, so 'no spawns' can't be built.",
           "other": "%s", "try": "try", "or_leave": "or leave it out",
           "cannot": "Sorry - the map generator can't build %s ('%s'). It builds worlds to "
                     "explore and arenas for the game modes: landscapes, villages, castles, "
                     "islands, caves, weather and the time of day.",
           "cannot_chat": "I only read map wishes - '%s' is not one. Describe a map, e.g. "
                          "'a snowy village by a lake'."},
    "de": {"with": "mit %s", "without": "ohne %s", "size": "Groesse: %s",
           "theme": "sieht aus wie: %s", "players": "%s Spieler", "sides": "zwei Teams",
           "ffa": "jeder gegen jeden", "guess": "Geraten: %s",
           "unknown": "Das Wort '%s' kenne ich nicht.",
           "unknown_group": "'%s' konnte ich nicht lesen.",
           "place": "'%s' sagt WO, aber nicht WAS dort hin soll.",
           "spawn_where": "Wo soll der World Spawn sein?",
           "no_spawns": "Eine Map braucht Spawns - 'keine Spawns' geht nicht.",
           "other": "%s", "try": "versuch", "or_leave": "oder lass es weg",
           "cannot": "Das kann der Map-Generator leider nicht bauen: %s ('%s'). Er baut Welten "
                     "zum Erkunden und Arenen fuer die Spielmodi: Landschaften, Doerfer, Burgen, "
                     "Inseln, Hoehlen, Wetter und Tageszeit.",
           "cannot_chat": "Ich lese nur Map-Wuensche - '%s' ist keiner. Beschreib eine Map, "
                          "z. B. 'ein verschneites Dorf am See'."},
}
CANNOT = {
    "en": {"vehicles": "vehicles to drive or ride", "creatures": "animals or creatures",
           "npcs": "people or characters that walk around", "gravity": "other gravity",
           "portals": "portals or teleporters", "change": "a map that changes while you play",
           "real_place": "real places", "other_game": "places from other games or films",
           "graphics": "other graphics", "voice": "voices or sounds", "players":
           "more than 16 players", "material": "maps made of real materials"},
    "de": {"vehicles": "Fahrzeuge zum Fahren", "creatures": "Tiere oder Kreaturen",
           "npcs": "Figuren, die herumlaufen", "gravity": "andere Schwerkraft",
           "portals": "Portale oder Teleporter", "change": "eine Map, die sich beim Spielen "
           "veraendert", "real_place": "echte Orte", "other_game": "Orte aus anderen Spielen "
           "oder Filmen", "graphics": "andere Grafik", "voice": "Stimmen oder Geraeusche",
           "players": "mehr als 16 Spieler", "material": "Maps aus echten Materialien"},
}
CANNOT_RE = re.compile(r"'(.+)': cannot build (\w+)$")
PLACE_THINGS = {"de": ("ein Turm", "die Spawns"), "en": ("a tower", "the spawns")}
SPAWN_PLACES = {"de": ("im Sueden", "in der Mitte"), "en": ("in the south", "in the middle")}
def _lang(reading):
    from . import lexicon, vocab
    text = getattr(reading, "text", "") or ""
    if vocab.language(text) == "de" or lexicon.german(wish.fold(text)) or re.search(
            r"[\u00e4\u00f6\u00fc\u00df]|\b(ohne|mit|und|kleine?|grosse?|keine?)\b",
            text.lower()):
        return "de"
    return "en"
def _feature(f, lang):
    from . import vocab
    try:
        row = vocab.row_of("feature", f)
    except Exception:
        row = None
    forms = (row or {}).get(lang) or (row or {}).get("en") or []
    if forms:
        return vocab.surface(forms[0].lstrip("~"))
    return f.replace("_", " ")
PRESET_SAY = {
    "en": {"village": "a village", "castle": "a castle", "ruins": "ruins",
           "skyisland": "a sky island", "desert": "a desert", "iceworld": "an ice world",
           "forest": "a forest", "lakeland": "a land of lakes", "lavafort": "a lava fort",
           "town": "a town"},
    "de": {"village": "ein Dorf", "castle": "eine Burg", "ruins": "Ruinen",
           "skyisland": "eine Wolkeninsel", "desert": "eine Wueste", "iceworld": "eine Eiswelt",
           "forest": "ein Wald", "lakeland": "ein Seenland", "lavafort": "eine Lavaburg",
           "town": "eine Stadt"},
}
THEME_SAY = {
    "en": {"castle": "a castle", "desert": "a desert", "ice": "ice and snow", "lava": "lava",
           "wood": "wood", "sky": "the sky", "garden": "a green meadow"},
    "de": {"castle": "eine Burg", "desert": "eine Wueste", "ice": "Eis und Schnee",
           "lava": "Lava", "wood": "Holz", "sky": "der Himmel", "garden": "eine gruene Wiese"},
}
SIZE_SAY = {"de": {"tiny": "winzig", "small": "klein", "medium": "mittel", "large": "gross",
                   "huge": "riesig", "gigantic": "gigantisch"}}
def _preset_key(name):
    from . import presets
    for p in presets.all_presets():
        if name in (p["key"], p["name"]):
            return p["key"]
    return None
def plain(line, lang="en"):
    W = WORDS[lang]
    m = re.match(r"preset (\w+)$", line)
    if m and _preset_key(m.group(1)) in PRESET_SAY[lang]:
        return PRESET_SAY[lang][_preset_key(m.group(1))]
    m = re.match(r"family (\w+)$", line)
    if m and m.group(1) in FAMILY_SAY[lang]:
        return FAMILY_SAY[lang][m.group(1)]
    m = re.match(r"mode (\w+) \((.+)\)$", line)
    if m:
        if m.group(1) in FAMILY_SAY[lang]:
            return FAMILY_SAY[lang][m.group(1)]
        return ("the game mode %s" if lang == "en" else "der Spielmodus %s") % m.group(2)
    m = re.match(r"not the (\w+) theme$", line)
    if m:
        look = THEME_SAY[lang].get(m.group(1), m.group(1))
        return ("not looking like %s" if lang == "en" else "nicht wie %s") % look
    m = re.match(r"(want|avoid) (\w+)$", line)
    if m:
        return W["with" if m.group(1) == "want" else "without"] % _feature(m.group(2), lang)
    m = re.match(r"size (\w+)$", line)
    if m:
        return W["size"] % SIZE_SAY.get(lang, {}).get(m.group(1), m.group(1))
    m = re.match(r"theme (\w+)( \(.*\))?$", line)
    if m and m.group(1) in THEME_SAY[lang]:
        return W["theme"] % THEME_SAY[lang][m.group(1)]
    if m:
        return W["theme"] % m.group(1)
    m = re.match(r"players (\d+)", line)
    if m:
        return W["players"] % m.group(1)
    if line == "two sides":
        return W["sides"]
    if line == "free-for-all":
        return W["ffa"]
    m = re.match(r"anchor (.+)$", line)
    if m:
        return m.group(1).replace("_", " ")
    return line.replace("_", " ")
def _tokens(text):
    return [(m.start(), m.end(), wish.fold(m.group(0)))
            for m in re.finditer(r"[^\W\d_][\w'\-]*", text or "")]
def _replace(text, word, new):
    for a, b, f in _tokens(text):
        if f == word:
            return text[:a] + new + text[b:]
    return None
def _drop(text, words):
    out = text
    for w in words.split():
        for a, b, f in reversed(_tokens(out)):
            if f == w:
                out = (out[:a] + out[b:])
                break
    out = re.sub(r"\s+([,.;!?])", r"\1", re.sub(r"\s{2,}", " ", out)).strip(" ,;")
    out = re.sub(r"(?i)[\s,]+(und|and|mit|with|oder|or|plus|sowie)$", "", out).strip(" ,;")
    return out
def rephrase(reading, group):
    from . import lexicon
    text = getattr(reading, "text", "") or ""
    lang = _lang(reading)
    out = []
    m = re.match(r"'(.+)': a place without a thing to put there$", group)
    if m:
        clause = m.group(1)
        for thing in PLACE_THINGS[lang]:
            new = _insert_before(text, clause, thing)
            if new:
                out.append(new)
        return out[:2]
    m = re.match(r"'(.+)': where should the world spawn be\?$", group)
    if m:
        for place in SPAWN_PLACES[lang]:
            out.append("%s %s" % (text.rstrip(" .!"), place))
        return out[:2]
    m = re.match(r"'(.+)': no spawns at all is not a map$", group)
    if m:
        new = _drop(text, wish.fold(m.group(1)))
        return [new] if new and new != text else []
    m = CANNOT_RE.match(group)
    if m:
        if m.group(2) == "chat":
            return []
        return _sensible([_drop_phrase(text, m.group(1))], text)
    if group.startswith("'") or ":" in group:
        return []
    if _cannot(reading):
        return []
    for word in group.split():
        for form, _, _ in lexicon.suggest(word, 3):
            new = _replace(text, word, form)
            if new and new not in out:
                out.append(new)
            if len(out) == 2:
                return _sensible(out, text)
        if out:
            return _sensible(out, text)
    left = _drop(text, group)
    if left and left != text:
        out.append(left)
    return _sensible(out[:2], text)
STOPS = set("""a an the me my i you it is to of and or with mit und oder ein eine einen einem
einer der die das den dem mir mich ich du es ist zu von im in am an auf for fuer that die
which who real echte echten echter""".split())
def _drop_phrase(text, words):
    toks = _tokens(text)
    target = words.split()[0]
    at = next((i for i, (_, _, f) in enumerate(toks) if f == target or f.startswith(target)),
              None)
    if at is None:
        return _drop(text, words)
    start = toks[at][0]
    for k in range(at - 1, max(-1, at - 5), -1):
        if toks[k][2] in ("mit", "with", "und", "and", "plus", "wie", "like", "von", "of",
                          "aus", "from"):
            start = toks[k][0]
            break
    end = len(text)
    stop = re.search(r"[,;.!?]", text[toks[at][1]:])
    if stop:
        end = toks[at][1] + stop.start()
        rel = re.match(r"\s*,\s*(die|der|das|welche\w*|that|which|who)\b[^,;.!?]*", text[end:])
        if rel:
            end += rel.end()
    out = (text[:start] + text[end:]).strip(" ,;")
    return re.sub(r"\s+,", ",", re.sub(r"\s{2,}", " ", out))
def _sensible(tries, text):
    out = []
    for t in tries:
        words = [w for w in re.findall(r"[^\W\d_]+", wish.fold(t or ""))]
        content = [w for w in words if w not in STOPS]
        if not t or t == text or len(content) < 1 or len(words) < 2:
            continue
        if words[-1] in STOPS or re.search(r"\b(with|mit|ohne|without|that|die|der|which)\s+"
                                          r"(that|die|der|which|you|einen|real|echten)\b",
                                          wish.fold(t)):
            continue
        out.append(t)
    return out
def _cannot(reading):
    return any(CANNOT_RE.match(g or "") for g in getattr(reading, "not_understood", []) or [])
def _insert_before(text, clause, thing):
    low = wish.fold(text)
    at = low.find(clause.strip())
    if at < 0:
        return None
    return (text[:at] + thing + " " + text[at:]).strip()
def _why(group, lang):
    W = WORDS[lang]
    m = re.match(r"'(.+)': a place without a thing to put there$", group)
    if m:
        return W["place"] % m.group(1)
    if re.search(r"where should the world spawn be\?$", group):
        return W["spawn_where"]
    if re.search(r"no spawns at all is not a map$", group):
        return W["no_spawns"]
    m = CANNOT_RE.match(group)
    if m:
        if m.group(2) == "chat":
            return W["cannot_chat"] % m.group(1)
        return W["cannot"] % (CANNOT[lang].get(m.group(2), m.group(2)), m.group(1))
    if group.startswith("'") or ":" in group:
        return group
    if " " not in group:
        return W["unknown"] % group
    return W["unknown_group"] % group
def panel(reading):
    lang = _lang(reading)
    if lang not in WORDS:
        lang = "en"
    und = []
    for line in getattr(reading, "understood", []) or []:
        p = plain(line, lang)
        if p not in und:
            und.append(p)
    ass = [WORDS[lang]["guess"] % a for a in getattr(reading, "assumed", []) or []]
    nu = []
    for g in getattr(reading, "not_understood", []) or []:
        nu.append({"words": g, "why": _why(g, lang), "try": rephrase(reading, g)})
    return {"understood": und, "assumed": ass, "not_understood": nu, "lang": lang}
def lines(reading):
    p = panel(reading)
    W = WORDS[p["lang"]]
    out = []
    for n in p["not_understood"]:
        out.append(n["why"])
        for t in n["try"]:
            out.append("  %s: \"%s\"" % (W["try"], t))
    return out
