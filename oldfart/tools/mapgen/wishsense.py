import re
from . import wish as W
MAP_NOUNS = (r"map|karte|welt|world|level|arena|plate|platte|plattform|strecke|track|circuit|"
             r"rundkurs|parcours|parkour|course|landschaft|insel|island|ort|place|spielfeld|"
             r"gelaende|abenteuerwelt|deathmatch|shooter|ctf|sumo|rennstrecke|"
             r"versteckspiel|hindernisparcours|partyplatte|ballerkarte|flaggen|"
             r"capture|hide|obstacle|parkour|racing|race|gunfight|hiding|adventure|"
             r"open|jump|party|knock|ffa|flag|schiesserei|sumo|lobby|spielwiese|reich|dorf|"
             r"village|stadt|town|wueste|desert|valley|tal|meadow|wiese|forest|wald|park|garden|garten|"
             r"landscape|area|gebiet|plain|ebene|irrgarten|labyrinth|maze|dungeon|kerker")
SIZE = [
    (r"gigantisch\w*|gigantic|titanisch\w*|gargantuan|riesengross\w*|maximal\w*", "gigantic"),
    (r"riesig\w*|huge|massive|massiv\w*|enorm\w*|enormous|gewaltig\w*|kolossal\w*|colossal|"
     r"immens\w*|immense|vast", "huge"),
    (r"gross\w*|big|large|weit\w*", "large"),
    (r"mittelgross\w*|medium(?:[- ]sized)?|mid(?:[- ]sized)?|mittel\w*", "medium"),
    (r"klein\w*|small|little", "small"),
    (r"winzig\w*|tiny|mini", "tiny"),
]
ORDER = ("tiny", "small", "medium", "large", "huge", "gigantic")
INTENSE = (r"sehr|ganz|richtig|super|mega|echt|voll|really|very|so|extra|extremely|ultra|wirklich|"
           r"extrem\w*|besonders|totally|quite|irre|wahnsinnig\w*|krass|insanely|"
           r"incredibly|unglaublich\w*|ultra")
SKIP = r"(?:\s+(?:und|and|,)\s+|\s+)"
def _said(r, line):
    r.understood.append(line)
def _want(r, feat, why=None):
    f = r.raw.setdefault("features", {"want": [], "avoid": []})
    f.setdefault("want", [])
    f.setdefault("avoid", [])
    if feat in f["avoid"] or feat in f["want"]:
        return False
    f["want"].append(feat)
    _said(r, "want %s%s" % (feat.replace("_", " "), (" (%s)" % why) if why else ""))
    return True
def _avoid(r, feat, why=None):
    f = r.raw.setdefault("features", {"want": [], "avoid": []})
    f.setdefault("want", [])
    f.setdefault("avoid", [])
    if feat in f["want"]:
        f["want"].remove(feat)
    if feat not in f["avoid"]:
        f["avoid"].append(feat)
        _said(r, "avoid %s%s" % (feat.replace("_", " "), (" (%s)" % why) if why else ""))
        return True
    return False
def _drop_avoid(r, feat):
    f = r.raw.get("features") or {}
    if feat in (f.get("avoid") or []):
        f["avoid"].remove(feat)
        r.understood = [u for u in r.understood if u != "avoid %s" % feat]
        return True
    return False
def _drop_want(r, feat):
    f = r.raw.get("features") or {}
    if feat in (f.get("want") or []):
        f["want"].remove(feat)
        return True
    return False
def _negated(low, at):
    return W._negated(low, at)
def _size_of(word):
    for pat, size in SIZE:
        if re.fullmatch(pat, word):
            return size
    return None
def _step(size, n):
    i = ORDER.index(size)
    return ORDER[max(0, min(len(ORDER) - 1, i + n))]
PLACE_NOUNS = (r"\w*burg|castle|schloss|festung|fortress|stadt|city|town|wald|forest|forrest|"
               r"dorf|village|jungle|dschungel")
def _predicate(words, i):
    back = words[max(0, i - 5):i]
    return any(re.match(r"(?:%s)$" % MAP_NOUNS, x) for x in back) and any(
        x in ("soll", "sollte", "should", "muss", "must", "is", "ist", "wird", "be", "sein")
        for x in back)
NEG = ("not", "nicht", "no", "kein", "keine", "never", "nie")
WITH_ART = ("a", "an", "the", "some", "ein", "eine", "einer", "einem", "einen", "den", "der",
            "die", "dem", "vielen", "many", "lots", "ganz", "sehr", "very")
THING_NOUNS = (r"(pilz|baum|baeum|tree|rutsch|slide|insel|island|turm|tuerm|tower|haus|haeus|"
               r"house|huette|hut|berg|mountain|see$|lake|bruecke|bridge|huegel|hill|raum|"
               r"raeum|room|tor$|gate|statue|stein|rock|fels|platt?form|kanone|cannon|"
               r"wasserfall|waterfall|hoehle|cave|tempel|temple|ruine|ruin|brunnen|fountain|"
               r"pyramid|vulkan|volcano|schiff|ship|rampe|ramp|treppe|stairs|mauer|wall|"
               r"teich|pond|fluss|river|platz|plaza|kirche|church|leuchtt|lighthouse|"
               r"windm|garten|garden|pilze|mushroom|kristall|crystal|blume|flower|"
               r"loch|hole|luecke|gap|sprung|jump|ring|tunnel|weg|path|road|strasse)")
def map_size(low):
    words = re.findall(r"[a-z]+|\d+|-", low)
    found, any_size, fallback = None, False, None
    for i, w in enumerate(words):
        size = _size_of(w)
        if w == "mid" and "range" in words[i + 1:i + 3]:
            continue
        if size is None:
            m = re.fullmatch(r"(riesen|mini|klein|gross)(\w{3,})", w)
            if m:
                any_size = True
                if found is None and re.fullmatch(r"(welt|karte|map|level|arena|insel|landschaft)\w{0,2}",
                                                  m.group(2)):
                    found = {"riesen": "huge", "mini": "tiny", "klein": "small",
                             "gross": "large"}[m.group(1)]
            continue
        j = i + 1
        while j < len(words) and (words[j] in ("-", "und", "and", "sized", "size", "night", "day",
                                                "nacht", "tag") or _size_of(words[j])
                                  or re.fullmatch(INTENSE + r"|flach\w*|flat|schnell\w*|"
                                                  r"fast|offen\w*|open|tief\w*|deep|neu\w*|"
                                                  r"schoen\w*|nice|cool\w*|lustig\w*|bunt\w*",
                                                  words[j])):
            j += 1
        noun = words[j] if j < len(words) else ""
        for k in range(j, min(j + 3, len(words))):
            if re.fullmatch(r"mit|with|und|and|im|in|on|auf|of|von|fuer|for|a|an|the|ein\w*|"
                            r"der|die|das|dem|den|zum|zur|to|but|aber", words[k]):
                break
            if re.match(r"(?:%s)$" % MAP_NOUNS, words[k]) or (
                    i <= 2 and re.fullmatch(PLACE_NOUNS, words[k])):
                noun = words[k]
                break
        prev = words[i - 1] if i > 0 else ""
        prev2 = words[i - 2] if i > 1 else ""
        with_thing = prev in ("mit", "with") or (prev2 in ("mit", "with") and prev in WITH_ART)
        if prev in ("als", "than") and re.search(r"\b(lieber|eher|rather|more)\b",
                                                 " ".join(words[max(0, i - 5):i])):
            continue
        if prev in ("too", "zu") and prev2 in NEG:
            fallback = fallback or "medium"
            continue
        if prev in NEG or (prev2 in NEG and re.fullmatch(INTENSE, prev)):
            continue
        if re.fullmatch(r"normal\w*", prev):
            size = "medium"
        is_map = bool(re.match(r"(?:%s)" % MAP_NOUNS, noun)) or noun == "" \
            or bool(re.fullmatch(r"\w+(welt|karte|level|strecke|arena|landschaft)\w{0,2}", noun)) \
            or bool(re.search(r"(^|,)\s*(?:(?:%s)\s+)*(?:%s)\s*(,|$)" % (INTENSE, re.escape(w)), low)) \
            or _predicate(words, i) \
            or (i <= 2 and re.fullmatch(PLACE_NOUNS, noun) is not None
                and not any(re.match(r"(?:%s)$" % MAP_NOUNS, x) for x in words[j + 1:]))
        if with_thing and not (re.match(r"(?:%s)$" % MAP_NOUNS, noun) or re.fullmatch(
                r"\w+(welt|karte|level|strecke|arena|landschaft)\w{0,2}", noun)):
            is_map = False
            any_size = True
            continue
        if is_map and re.match(r"insel|island", noun):
            rest = " ".join(words[j + 1:j + 4])
            if re.match(r"(im|in the|in dem|in der|auf dem|on the|mitten)\b", rest) \
                    and not re.match(r"(im|in the|in dem)\s+(meer|sea|ozean|ocean)\b", rest):
                is_map = False
        if not is_map:
            if re.match(THING_NOUNS, noun):
                any_size = True
            continue
        if re.fullmatch(INTENSE, prev):
            if prev2 and re.fullmatch(INTENSE, prev2) and size in ("large", "huge") \
                    and prev2 == prev:
                pass
            size = _step(size, 1 if ORDER.index(size) >= 3 else -1)
        if found is None:
            found = size
    return found or fallback, any_size
def _clean(r, text):
    low = text
    name = r.raw.get("name")
    if name:
        low = low.replace(W.fold(name), " ")
    low = re.sub(r"\"[^\"]*\"|\u201e[^\u201c\u201d]*[\u201c\u201d]|'[^']{2,}'", " ", low)
    low = re.sub(r"\b(namens|named|called|genannt|heisst)\s+\w+(\s+\w+)?", " ", low)
    low = re.sub(r"[^a-z0-9\-,. ]+", " ", low)
    return re.sub(r"\s+", " ", low)
def _size(r, low):
    size, any_size = map_size(low)
    fixed = _clean(r, getattr(r, "low", None) or "")
    if size is None and not any_size and fixed.strip() and fixed != low:
        size, any_size = map_size(fixed)
    if size is None and not any_size:
        return
    if re.search(r"\b(so gross (wie )?(es )?(geht|moeglich)|as (big|large) as (it gets|possible)|"
                 r"(biggest|largest) possible|gr(oe|o)sstm(oe|o)glich\w*|max(imale)? gr(oe|o)sse)\b", low):
        return
    if re.search(r"\b(doppelt|twice|halb|half|dreimal|three times|zweimal|viermal)\s+(so|as)\b", low):
        return
    have = r.raw.get("size")
    if size is not None:
        if have != size:
            r.raw["size"] = size
            _said(r, "size %s (the map's own size word)" % size)
        return
    tail = re.search(r"(\b\w+\s+)?(\b\w+\s+)?\b(%s)\b\s*$" % MAP_NOUNS, low)
    if tail and re.search(r"\b(im|in|am|an|auf|beim|bei|at|on|near|by|inside|vom|from)\b",
                          (tail.group(1) or "") + (tail.group(2) or "")):
        tail = None
    if have is not None and not tail:
        r.raw.pop("size", None)
        r.understood = [u for u in r.understood if not u.startswith("size ")]
        _said(r, "a size word was a thing's, not the map's")
WATER = (r"\b(strand\w*|beach\w*|kueste\w*|coast\w*|meer\w*|seas?|seaside|oceans?|ozean\w*|"
         r"\w*oase\w*|\w*oasis|teich\w*|pond\w*|lagune\w*|lagoon\w*|bucht(en)?|coves?|bays?|"
         r"sumpf\w*|swamp\w*|zugefroren\w*|frozen lake|see\b|lake\w*)\b")
CHURCH = r"\b(kirch\w*|kapelle\w*|church\w*|chapel\w*|dom\b|kathedrale\w*|cathedral\w*)"
MAZE = r"\b(\w*labyrinth\w*|irrgarten|irrgaerten|maze\w*)\b"
HARBOUR = (r"\b(fischerdorf\w*|fischerdoerfer|fishing (village|town|port|harbou?r)\w*|\w*hafen|"
           r"harbou?rs?|seaport|port town|hafenstadt)\b")
MARKET = r"\b(marktplatz\w*|marktstadt\w*|marktflecken|market ?square|market ?place|markt\b|market\b|market town)"
CANYON = r"\b(schlucht\w*|canyon\w*|klamm\b|gorge\w*|ravine\w*)"
LAVA_WATER = r"\b(lava|magma) ?(see|seen|teich|pool|lake|lakes|lagoon|fluss|river)\b|\blavasee\w*"
SNOW_MOUNTAIN = (r"\b(schneeberg\w*|eisberg\w*|snow(y)? mountains?|ice mountains?|"
                 r"verschneite\w* berg\w*|schneebedeckte\w* berg\w*|snow ?peaks?)")
MOUNTAIN = r"\b(mountain|berg|gipfel|peak|summit|bergkette|gebirge|montain|mountin)\b"
CRYSTAL_CAVE = r"\b(kristallhoehle\w*|crystal caves?|kristall-hoehle\w*)"
ICE_CAVE = r"\b(eishoehle\w*|ice caves?|eis-hoehle\w*)"
HAUNTED_HOUSE = r"\b(haunted (house|mansion|castle)|spukhaus\w*|geisterhaus\w*|spukschloss\w*|gruselhaus\w*)"
PIRATE = r"\b(pirat\w*|pirate\w*)"
SHIP = r"\b(schiff\w*|ship|ships|boot|boat|wrack\w*|wreck\w*)\b"
GREAT_TREE = (r"\b(riesig\w* baum|riesenbaum\w*|giant tree|huge tree|big old tree|huge old tree|"
              r"great tree|gross\w* alt\w* baum|uralt\w* baum|world tree|weltenbaum)")
FLOATING = (r"\b(insel\w* in den wolken|islands? in the (clouds|sky)|schwebend\w* insel\w*|"
            r"floating islands?|sky islands?|himmelsinsel\w*|fliegend\w* insel\w*)")
HUT = r"(\w*huette\w*|\bhut|\bhuts|\bcabin\w*|\w*haeuschen|\bcottage\w*)\b"
FOUNTAIN = r"\b(springbrunnen\w*|fountain\w*|brunnen)\b"
def _lexical(r, low):
    if re.search(WATER, low):
        m = re.search(WATER, low)
        if not _negated(low, m.start()) and not re.search(LAVA_WATER, low):
            _want(r, "water", "a body of water")
    if re.search(CHURCH, low):
        m = re.search(CHURCH, low)
        if not _negated(low, m.start()):
            _want(r, "belltower", "a church")
            _want(r, "buildings")
        else:
            _avoid(r, "belltower", "no church")
            _drop_avoid(r, "buildings")
            r.not_understood = [n for n in r.not_understood if not re.search(CHURCH, n)]
    m = re.search(MAZE, low)
    if m and not _negated(low, m.start()):
        if not re.search(r"\b(hecke\w*|hedge\w*)", low):
            _want(r, "walls", "a maze")
        r.raw.setdefault("density", "dense")
    m = re.search(r"\b(dschungel\w*|jungle\w*|regenwald\w*|rain ?forest\w*|urwald\w*)", low)
    if m and not _negated(low, m.start()) and "trees" not in (r.raw.get("amounts") or {}):
        r.raw.setdefault("amounts", {})["trees"] = "lots"
        _said(r, "lots of trees (a jungle)")
    m = re.search(HARBOUR, low)
    if m and not _negated(low, m.start()):
        _want(r, "water", "by the water")
    m = re.search(r"(\b(mit|with|und|and|plus|over|ueber|voller|full of)\s+(viel\w* |lots of )?|#)lava\b", low)
    if m and not _negated(low, m.end() - 4):
        _want(r, "lava", "lava itself")
    m = re.search(r"\b(burg|schloss|festung|castle|fort)\w*\b.{0,30}\bgraben\b", low)
    if m and not _negated(low, m.end() - 6):
        _drop_want(r, "pit")
        r.understood = [u for u in r.understood if u != "want pit"]
        _want(r, "water", "a castle's ditch is a moat")
    m = re.search(r"\b(im schnee|in the snow|schnee|snow|snowy|verschneit\w*|schneebedeckt\w*|"
                  r"winter\w*)\b", low)
    if m and not _negated(low, m.start()) and r.raw.get("mood") in (None, "clear") and \
            not re.search(r"\b(schneesturm|blizzard)", low):
        r.raw["mood"] = "snow"
        _said(r, "mood snow")
    if re.search(MARKET, low) and not _negated(low, re.search(MARKET, low).start()):
        _want(r, "marketsquare", "a market")
        if re.search(r"(town|stadt|dorf|village)\b", low):
            _want(r, "buildings")
    m = re.search(CANYON, low)
    if m and not _negated(low, m.start()) and not re.search(
            r"\b(getrennt|separated|divided|split|geteilt)\b.{0,20}$", low[:m.start()]):
        _drop_want(r, "void_gaps")
        _want(r, "valley", "a canyon is a valley")
    m = re.search(LAVA_WATER, low)
    if m and not _negated(low, m.start()):
        _want(r, "lava", "a lava lake")
        if not re.search(r"\b(wasser|water)\b", low) and not re.search(
                WATER.replace(r"|see\b|lake\w*", ""), low):
            _drop_want(r, "water")
    m = re.search(r"\b(bruecke\w*|bridges?)\b.{0,12}\b(ueber|over|across)\b.{0,10}\blava\b", low)
    if m:
        _want(r, "lava", "the bridge crosses it")
    elif re.search(r"\b(ueber|over|above|across)\s+(der |the |dem |einem |a )?(lava|magma)\b", low):
        _want(r, "lava", "the map stands over it")
    m = re.search(SNOW_MOUNTAIN, low)
    if m and not _negated(low, m.start()):
        _want(r, "mountains")
    m = re.search(MOUNTAIN, low)
    if m and not _negated(low, m.start()) and "mountains" not in \
            ((r.raw.get("features") or {}).get("avoid") or []):
        _want(r, "mountains", "a mountain")
    m = re.search(CRYSTAL_CAVE, low)
    if m and not _negated(low, m.start()):
        _want(r, "caves")
        _want(r, "crystals")
    m = re.search(ICE_CAVE, low)
    if m and not _negated(low, m.start()):
        _want(r, "caves")
        if r.raw.get("theme") in (None, "auto", "garden"):
            r.raw["theme"] = "ice"
            _said(r, "theme ice (ice caves)")
    if re.search(r"\b(zugefroren\w*|frozen|gefroren\w*|vereist\w*|icy)\b", low) and \
            r.raw.get("theme") in (None, "auto", "garden"):
        r.raw["theme"] = "ice"
        _said(r, "theme ice (frozen)")
    m = re.search(HAUNTED_HOUSE, low)
    if m and not _negated(low, m.start()):
        _want(r, "buildings", "a haunted house")
        if "mood" not in r.raw:
            r.raw["mood"] = "spooky"
            _said(r, "mood spooky")
    if re.search(PIRATE, low) and (re.search(SHIP, low) or re.search(r"\b(bucht|cove|bay)\b", low)):
        _want(r, "shipwreck", "a pirate ship")
        _want(r, "water")
    m = re.search(GREAT_TREE, low)
    if m and not _negated(low, m.start()):
        _want(r, "greattree", "a giant tree")
        if not re.search(r"\b(\d+|zwei|drei|vier|two|three|four|viele|many|lots)\s+(baeume|trees)\b",
                         low):
            objs = [o for o in r.raw.get("objects") or []
                    if not (o.get("key") == "tree" and int(o.get("count", 1)) == 1)]
            if objs:
                r.raw["objects"] = objs
            else:
                r.raw.pop("objects", None)
    m = re.search(FLOATING, low)
    if m and not _negated(low, m.start()):
        _want(r, "floating_islands")
        _want(r, "islands")
    m = re.search(HUT, low)
    if m and not _negated(low, m.start()):
        _want(r, "buildings", "a hut")
    m = re.search(FOUNTAIN, low)
    if m and not _negated(low, m.start()) and not re.search(r"\bziehbrunnen\w*|\bwell\b", low):
        _want(r, "fountain")
    m = re.search(r"\b(ziehbrunnen\w*|wishing well|a well|einem brunnen in der mitte)\b", low)
    if m and not _negated(low, m.start()):
        _want(r, "well")
    if re.search(r"\b(dunkl\w* (hoehle|cave|map|karte|welt)|dark (cave|map|world|level))", low):
        _want(r, "dark", "a dark place")
PIECE_WORDS = [
    ("lighthouse", r"leuchtt(ue|u)rm\w*|lighthouses?"),
    ("windmill", r"windm(ue|u)hle\w*|windmills?"),
    ("ruin", r"ruine\w*|ruins?"),
    ("pyramid", r"pyramide\w*|pyramids?"),
    ("temple", r"tempel\w*|temples?"),
    ("statue", r"statue\w*|statues?"),
    ("shipwreck", r"schiffswrack\w*|shipwrecks?"),
    ("greattree", r"riesig\w* baum|riesenbaum\w*|giant tree|huge tree|great tree"),
    ("fountain", r"springbrunnen\w*|fountains?"),
    ("belltower", r"glockent(ue|u)rm\w*|bell ?towers?|kirche\w*|church\w*"),
    ("well", r"ziehbrunnen\w*|wells?"),
    ("obelisk", r"obelisk\w*"),
    ("watchtower", r"wacht(ue|u)rm\w*|watch ?towers?"),
    ("shrine", r"schrein\w*|shrines?"),
]
ANCHOR_WORDS = [
    ("tower", r"t(ue|u)rm|towers?"),
    ("bridge", r"bruecke|bridges?"),
]
COMPASS = [
    ("ne", r"im nordosten|in the north-?east|northeast|nordoestlich"),
    ("nw", r"im nordwesten|in the north-?west|northwest"),
    ("se", r"im suedosten|in the south-?east|southeast"),
    ("sw", r"im suedwesten|in the south-?west|southwest"),
    ("n", r"im norden|in the north|noerdlich"),
    ("s", r"im sueden|in the south|suedlich"),
    ("e", r"im osten|in the east|oestlich"),
    ("w", r"im westen|in the west|westlich"),
    ("c", r"in der mitte|im zentrum|in the (middle|centre|center)|mittig"),
]
def _places(r, low):
    reqs = r.raw.setdefault("requests", [])
    for feat, pat in PIECE_WORDS:
        for m in re.finditer(r"\b(?:%s)\b" % pat, low):
            tail = low[m.end():m.end() + 30]
            for c, cp in COMPASS:
                mm = re.match(r"\s*(?:,\s*)?(?:%s)\b" % cp, tail)
                if mm:
                    if _negated(low, m.start()):
                        break
                    if not any(q.get("kind") == "place" and q.get("what") == feat
                               and (q.get("where") or {}).get("compass") == c for q in reqs):
                        reqs.append({"kind": "place", "what": feat, "where": {"compass": c}})
                        _want(r, feat)
                        _said(r, "%s %s (asked; placed where the world has room)"
                              % (feat.replace("_", " "), c))
                    break
    anchors = r.raw.get("anchors") or []
    for feat, pat in ANCHOR_WORDS:
        for m in re.finditer(r"(?<!glocken)(?<!wach)(?<!leucht)(?<!bell )(?<!watch )\b(?:%s)\b" % pat, low):
            tail = low[m.end():m.end() + 30]
            for c, cp in COMPASS:
                if not re.match(r"\s*(?:,\s*)?(?:%s)\b" % cp, tail):
                    continue
                if _negated(low, m.start()):
                    break
                anchors = [a for a in anchors
                           if (a.get("where") or {}).get("compass") != c or a.get("what") == feat]
                if not any(a.get("what") == feat and (a.get("where") or {}).get("compass") == c
                           for a in anchors):
                    anchors.append({"what": feat, "where": {"compass": c}})
                    _want(r, feat)
                    _said(r, "anchor %s in the %s" % (feat, c))
                for o in r.raw.get("objects") or []:
                    if (o.get("where") or {}).get("compass") == c:
                        o["where"] = {"region": "field"}
                break
    if anchors:
        r.raw["anchors"] = anchors
    m = re.search(r"\b(ein|einen|one|a|\d+|zwei|two|drei|three)\s+(t(ue|u)rme?|towers?)\b", low)
    if m and re.search(r"\b\d+\s+[a-z]", low) and not any(a.get("what") == "tower" for a in anchors) \
            and not _negated(low, m.start()):
        w = m.group(1)
        n = int(w) if w.isdigit() else {"zwei": 2, "two": 2, "drei": 3, "three": 3}.get(w, 1)
        anchors.append({"what": "tower", "count": n})
        r.raw["anchors"] = anchors
        _want(r, "tower")
        _said(r, "%d tower%s" % (n, "" if n == 1 else "s"))
    for q in reqs:
        if q.get("kind") == "place" and q.get("what") in ("house", "buildings") and re.search(
                r"\b(tempel\w*|temples?)\s+(hinter|behind|vor|in front of|neben|next to|beside)\b",
                low):
            q["what"] = "temple"
    for feat, pat in PIECE_WORDS + [("buildings", r"dorf\w*|village\w*|haus|house|huts?|huette\w*")]:
        for m in re.finditer(r"\b(?:%s)\b\s+(?:am|an der|beim|by the|at the|beside the|next to the)\s+"
                             r"(?P<of>wasser|water|see|lake|meer|sea|strand|beach|fluss|river|kueste|coast)\b"
                             % pat, low):
            of = {"wasser": "water", "water": "water", "meer": "water", "sea": "water",
                  "strand": "water", "beach": "water", "kueste": "water", "coast": "water",
                  "see": "lake", "lake": "lake", "fluss": "river", "river": "river"}[m.group("of")]
            what = "house" if feat == "buildings" else feat
            if not any(q.get("kind") == "place" and q.get("what") in (what, feat)
                       and q.get("relation") == "next_to" for q in reqs):
                reqs.append({"kind": "place", "what": what, "relation": "next_to", "of": of})
                _want(r, feat if feat != "buildings" else "buildings")
                if of in ("water", "lake"):
                    _want(r, "water")
                if of == "river":
                    _want(r, "river")
                _said(r, "%s next to the %s" % (what, of))
    m = re.search(r"\b(mountain|montain|berg|huegel|hill|hil)\b.{0,30}\b(castle|castel|burg|schloss|"
                  r"festung|tower|turm)\b.{0,6}\b(on top|oben ?drauf|obendrauf|drauf|on it)\b", low) \
        or re.search(r"\b(castle|castel|burg|schloss|festung)\b\s+(on|auf)\s+(a|an|the|einem|dem|"
                     r"einen)?\s*(hill|hil|huegel|berg|mountain|montain)\b", low)
    if m:
        if not any(q.get("kind") == "place" and q.get("relation") == "on" for q in reqs):
            reqs.append({"kind": "place", "what": "castle", "relation": "on", "of": "mountain"})
            _said(r, "castle on the mountain")
        _want(r, "mountains")
    if not reqs:
        r.raw.pop("requests", None)
PEOPLE = (r"bruder|schwester|freund\w*|freundin|kumpel\w*|papa|mama|vater|mutter|opa|oma|"
          r"cousin\w*|sohn|tochter|frau|mann|partner\w*|brother|sister|friend|buddy|dad|mom|"
          r"mum|son|daughter|wife|husband|girlfriend|boyfriend|kid|kind")
WORD_N = {"zwei": 2, "drei": 3, "vier": 4, "fuenf": 5, "sechs": 6, "acht": 8, "two": 2,
          "three": 3, "four": 4, "five": 5, "six": 6, "eight": 8}
def _people(r, low):
    if r.raw.get("players") is not None:
        return
    n = None
    m = re.search(r"\b(ich|me|mich|mir|myself)\b(.{0,40})", low)
    if m:
        rest = m.group(2)
        k = 1
        for mm in re.finditer(r"\b(und|and|mit|with|\+)\s+(mein\w*\s+|my\s+)?(\d+|%s)?\s*(%s)s?\b"
                              % ("|".join(WORD_N), PEOPLE), rest):
            cnt = mm.group(3)
            k += int(cnt) if cnt and cnt.isdigit() else (WORD_N.get(cnt, 1) if cnt else 1)
        if k > 1:
            n = k
    m = re.search(r"\b(wir|uns|we|us)\s+(zwei|drei|vier|fuenf|sechs|acht|two|three|four|five|six|"
                  r"eight|\d+)\b|\b(?:the |only |just )?(two|three|four|five|six|eight) of us\b", low)
    if m:
        w = m.group(2) or m.group(3)
        n = int(w) if w.isdigit() else WORD_N.get(w)
    if n is not None and 2 <= n <= 16:
        r.raw["players"] = n
        _said(r, "players %d (the people the wish names)" % n)
        r.not_understood = [x for x in r.not_understood if not re.fullmatch(
            r"(ich|me|mich|mir|myself|mein\w*|my|%s|%ss|freunde)" % (PEOPLE, PEOPLE.replace("|", "s|")), x)]
    if r.raw.get("family") in (None,) and re.search(
            r"\b(kaempf\w*|zum kaempfen|fight\w*|to fight|battle\w*|duell\w*|duel\w*)\b", low):
        r.raw["family"] = "shooter"
        _said(r, "family shooter (to fight)")
MOODS = [
    ("snow", r"\b(es schneit|schneit\w*|schneefall\w*|schneegestoeber|snowfall|snows|snowing|"
             r"while it (is )?snow\w*|where it snows|in the snow)\b"),
    ("rain", r"\b(es soll regnen|regnet|regnen|regenwetter|im regen|rainy|raining|rains|"
             r"in the rain|rainy weather)\b"),
    ("storm", r"\b(gewitter\w*|sturm mit blitz\w*|thunderstorm\w*|storm with lightning|"
              r"lightning)\b"),
    ("foggy", r"\b(nebel\w*|dichtem nebel|mist|misty|fog|foggy|dunst\w*)\b"),
    ("sunset", r"\b(sonnenuntergang\w*|abenddaemmerung|daemmerung|am abend|abends|dusk|"
               r"at sunset|sunset|evening|twilight|blaue\w* stunde|lila\w* stunde|"
               r"purple hour|blue hour|golden hour|goldene\w* stunde)\b"),
    ("night", r"\b(nachts|bei nacht|in der nacht|at night|by night|nighttime|night)\b"),
    ("sunny", r"\b(sonnenschein|sonnig\w*|am mittag|mittags|sunny|sunshine|at noon|noon|"
              r"high noon)\b"),
    ("spooky", r"\b(gruselig\w*|unheimlich\w*|spooky|creepy|haunted)\b"),
]
def _weather(r, low):
    hits = []
    for key, pat in MOODS:
        m = re.search(pat, low)
        if m and not _negated(low, m.start()):
            hits.append((m.start(), key))
    if not hits:
        return
    have = r.raw.get("mood")
    keys = [k for _, k in sorted(hits)]
    weather = [k for k in keys if k in ("snow", "rain", "storm", "foggy")]
    pick = weather[0] if weather else keys[0]
    if have in (None, "volcano", "clear") or (have in ("sunny", "night", "sunset", "spooky")
                                              and pick in weather and have not in keys):
        if have != pick:
            r.raw["mood"] = pick
            _said(r, "mood %s" % pick)
    if re.search(r"\bregnen\b|\bregnet\b", low) and r.raw.get("family") == "race" and not \
            re.search(r"\b(rennen|race|strecke|track|racing|rennstrecke)\b", low):
        r.raw.pop("family", None)
        r.understood = [u for u in r.understood if u != "family race"]
MUSIC_LEVEL = [
    ("SEQ_LEVEL_SNOW", r"(schnee|eis|winter|snow|ice)"),
    ("SEQ_LEVEL_WATER", r"(wasser|water|unterwasser|underwater)"),
    ("SEQ_LEVEL_HOT", r"(wuesten|wueste|desert|sand|lava|hot)"),
    ("SEQ_LEVEL_GRASS", r"(gras|grass|wiesen|wiese|bob-?omb|bobomb|meadow)"),
    ("SEQ_LEVEL_SLIDE", r"(rutschen|rutsche|slide)"),
    ("SEQ_LEVEL_SPOOKY", r"(grusel|spuk|geister|boo|spooky|haunted|creepy|gruselig\w*)"),
    ("SEQ_LEVEL_UNDERGROUND", r"(hoehlen|hoehle|cave|underground)"),
    ("SEQ_LEVEL_KOOPA_ROAD", r"(burg|schloss|castle)"),
    ("SEQ_LEVEL_BOSS_KOOPA_FINAL", r"(boss|bowser)"),
]
def _music(r, low):
    if r.raw.get("music"):
        return
    for seq, pat in MUSIC_LEVEL:
        if re.search(r"\b%s\w*[- ]?(level|welt|stage)?[- ]?(musik|music|song|soundtrack)\b" % pat, low) \
                or re.search(r"\b(musik|music|song)\s+(vom|von|aus dem|from the|of the)\s+%s\w*"
                             r"[- ]?(level|welt|stage|lvl)?\b" % pat, low) \
                or re.search(r"\b%s\w*level[- ]?(musik|music)\b" % pat, low) \
                or re.search(r"\b(musik|music)\s+(vom|from the|of the)\s+%s\w*level\b" % pat, low) \
                or re.search(r"\b(gruselig\w*|spooky|creepy)\s+(musik|music)\b", low) and \
                seq == "SEQ_LEVEL_SPOOKY":
            if G_SEQ_OK(seq):
                r.raw["music"] = seq
                _said(r, "music %s" % seq)
            return
def G_SEQ_OK(seq):
    return isinstance(seq, str) and seq.startswith("SEQ_")
def _negation(r, low):
    if re.search(r"\b(keine|kein|ohne|no|without|not any)\s+(baeume|baum|trees?|waelder|wald|forest)\b",
                 low):
        am = r.raw.setdefault("amounts", {})
        if am.get("trees") != "trace":
            am["trees"] = "trace"
            _said(r, "hardly any trees")
        r.raw["objects"] = [o for o in r.raw.get("objects") or []
                            if o.get("key") != "tree" or (o.get("where") or {}).get("edge")]
        if not r.raw["objects"]:
            r.raw.pop("objects")
    lots = re.search(r"\b(ueberall|lots of|viele|tons of|full of|voller)\s+(baeume|trees)\b", low)
    if lots and re.search(r"\b(nicht|not|no)\s+(so|zu|too|allzu)?\s*$", low[:lots.start()]):
        lots = None
    if re.search(r"\b(baeume|trees)\b.{0,12}\b(ueberall|all around|everywhere|rundherum|drumherum)\b",
                 low) or lots:
        am = r.raw.setdefault("amounts", {})
        am["trees"] = "lots"
        _said(r, "lots of trees")
    for m in re.finditer(r"\b(without|ohne)\s+(?:a |an |any |eine?n? |die |the )?(\w+)", low):
        feat = _feature_word(m.group(2))
        if feat:
            _avoid(r, feat, "without it")
    for m in re.finditer(r"\b(statt|anstatt|anstelle von|instead of|rather than)\s+(\w+)", low):
        word = m.group(2)
        feat = _feature_word(word)
        if feat:
            _avoid(r, feat, "instead of it")
    for m in re.finditer(r"\b(lieber|eher|rather|preferably|preferring)\b[^,;.!?]{0,40}?\b(als|than)\s+"
                         r"(?:(?:a|an|the|any|eine?[nmrs]?|die|der|das)\s+)?(\w+)", low):
        feat = _feature_word(m.group(3))
        if feat:
            _avoid(r, feat, "preferred less than the other")
    for m in re.finditer(r"\b(statt|anstatt|instead of)\s+\w+\s+(\w+)", low):
        feat = _feature_word(m.group(2))
        if feat and feat in ((r.raw.get("features") or {}).get("want") or []):
            pass
LEVELS_STOREYS = (r"\b([3-9]|drei|vier|fuenf|mehrere\w*|viele\w*|verschiedene\w*|einige\w*|"
                  r"three|four|five|several|many|multiple|different)\s+(ebenen|etagen|"
                  r"stockwerk\w*|stockwerken|levels|floors|storeys|stories|tiers)\b")
POURING = r"\b(regnet|regnen|giesst|schuettet|pisst)\w*\s+(es\s+)?(in|wie aus)\s+(stroemen|kuebeln)\b"
def _shooter_lookout(r):
    want = (r.raw.get("features") or {}).get("want") or []
    if r.raw.get("family") in ("shooter", "objective") and "lookout" in want:
        _drop_want(r, "lookout")
        r.understood = [u for u in r.understood if not u.startswith("want lookout")]
        _want(r, "perches", "a shooter's lookout is a perch")
def _homonyms(r, low):
    if re.search(LEVELS_STOREYS, low):
        if r.raw.get("verticality") in (None, "flat", "low"):
            r.raw["verticality"] = "high"
            r.understood = [u for u in r.understood if not u.startswith("verticality ")]
            _said(r, "verticality high (several levels are storeys)")
        r.not_understood = [n for n in r.not_understood
                            if n not in ("viele", "mehrere", "several", "many")]
    if re.search(POURING, low) and not re.search(r"\b(fluss\w*|river\w*|bach\w*|stream)\b",
                                                 low):
        if _drop_want(r, "river"):
            r.understood = [u for u in r.understood if u != "want river"]
            _said(r, "'in Stroemen' is pouring rain, no river")
        if r.raw.get("mood") in (None, "clear"):
            r.raw["mood"] = "rain"
MUSHROOM = r"\b(\w*pilz(e|en)?|mushrooms?|toadstools?|fliegenpilz\w*)\b"
ONE_UP = (r"\b(1.?ups?|one.?ups?|extraleben|extra (lives|life|leben)|gr(ue|u)ne\w* pilze\w*|"
          r"green mushrooms?|lebenspilz\w*)\b")
ITEM_CONTEXT = (r"\b(items?|forge|objekte?n?|objects?|power.?ups?|sammeln|einsammeln|collect\w*|"
                r"pick.?ups?|aufheben|loot)\b")
def _mushrooms(r, low):
    m = re.search(MUSHROOM, low)
    if not m or re.search(ONE_UP, low) or re.search(ITEM_CONTEXT, low):
        return
    objs = r.raw.get("objects") or []
    ups = [o for o in objs if o.get("key") == "1up"]
    if any((o.get("where") or {}) != {"region": "field"} for o in ups) or re.search(
            r"\b\d+\s+(\w*pilz|mushroom)", low):
        return
    if _negated(low, m.start()):
        _avoid(r, "giant_mushrooms", "mushrooms refused")
        r.assumed = [a for a in r.assumed if not a.startswith("no 1up")]
    else:
        _want(r, "giant_mushrooms", "mushrooms in a landscape are scenery; say '1-Ups' for "
                                    "the item")
    r.not_understood = [n for n in r.not_understood if not re.fullmatch(MUSHROOM, n)]
CORRECTION = r"\b(eher|lieber|besser|doch|vielmehr|rather|actually|instead|or rather|oder eher)\b"
DAY_WORDS = r"\b(tag|tags|tagsueber|am tag|day|daytime|by day|sonnig\w*|sunny|mittags|noon)\b"
NIGHT_WORDS = r"\b(nacht|nachts|night|nighttime|at night|mitternacht|midnight)\b"
STORM_WORDS = r"\b(gewitter\w*|thunderstorm\w*|sturm|storm\w*|unwetter)\b"
def _ask(r, de, ask_de, ask_en, opts_de, opts_en):
    q = {"ask": ask_de if de else ask_en, "options": opts_de if de else opts_en}
    if q not in r.questions:
        r.questions.append(q)
def _contradictions(r, low):
    from . import lexicon
    de = lexicon.german(low)
    words = re.findall(r"[a-z]+|\d+|-", low)
    said = []
    for i, w in enumerate(words):
        size = _size_of(w)
        if w == "mid" and "range" in words[i + 1:i + 3]:
            continue
        if size is None:
            continue
        prev = words[i - 1] if i else ""
        prev2 = words[i - 2] if i > 1 else ""
        if prev in ("mit", "with") or prev2 in ("mit", "with") or prev in ("als", "than"):
            continue
        label = w
        if prev in ("too", "zu") and prev2 in NEG:
            size, label = "medium", "%s %s %s" % (prev2, prev, w)
        elif prev in NEG or prev2 in NEG:
            continue
        nxt = words[i + 1] if i + 1 < len(words) else ""
        if nxt and not re.match(r"(?:%s)$" % MAP_NOUNS, nxt) and re.match(THING_NOUNS, nxt):
            continue
        said.append((i, label, size))
    for (i, w1, a), (j, w2, b) in zip(said, said[1:]):
        if abs(ORDER.index(a) - ORDER.index(b)) >= 2 and not re.search(
                CORRECTION, " ".join(words[i:j + 1])):
            def opt(w, word):
                return w if " " in w else "%s %s" % (word, w)
            _ask(r, de, "Größe: %s oder %s?" % (w1, w2), "size: %s or %s?" % (w1, w2),
                 [opt(w1, "eher"), opt(w2, "eher")], [opt(w1, "rather"), opt(w2, "rather")])
            break
    want = (r.raw.get("features") or {}).get("want") or []
    if r.raw.get("verticality") == "flat" and "mountains" in want and not re.search(CORRECTION, low):
        _ask(r, de, "flach oder bergig?", "flat or mountainous?",
             ["eher flach", "eher bergig"], ["rather flat", "rather mountainous"])
    for feat, pat in (("lava", r"\blava\b"), ("water", r"\b(wasser|water)\b"),
                      ("bridge", r"\b(bruecken?|bridges?)\b"), ("tower", r"\b(tuerme?|turm|towers?)\b")):
        hits = list(re.finditer(pat, low))
        if len(hits) >= 2 and any(_negated(low, h.start()) for h in hits) and any(
                not _negated(low, h.start()) for h in hits):
            _ask(r, de, "%s: mit oder ohne?" % feat, "%s: with or without?" % feat,
                 ["mit %s" % hits[0].group(0), "ohne %s" % hits[0].group(0)],
                 ["with %s" % hits[0].group(0), "without %s" % hits[0].group(0)])
    day = re.search(DAY_WORDS, low)
    night = re.search(NIGHT_WORDS, low)
    if day and night and not _negated(low, day.start()) and not _negated(low, night.start()) \
            and not re.search(CORRECTION, low) and not re.search(
                r"\b(tag und nacht wechsel\w*|day.?night cycle|tag.?nacht.?wechsel)\b", low):
        _ask(r, de, "Tag oder Nacht?", "day or night?", ["am Tag", "bei Nacht"],
             ["by day", "at night"])
    storm = re.search(STORM_WORDS, low)
    sunny = re.search(r"\b(sonnig\w*|sunny|sonnenschein|sunshine)\b", low)
    if storm and sunny and not _negated(low, storm.start()) and not _negated(low, sunny.start()):
        _ask(r, de, "Sonne oder Gewitter?", "sunshine or a thunderstorm?",
             ["eher sonnig", "eher Gewitter"], ["rather sunny", "rather a thunderstorm"])
OUT_OF_SCOPE = [
    ("vehicles", r"\b(\w*autos?|(?<!bumper )cars?|fahrzeug\w*|vehicles?|u.?boot\w*|submarines?|"
                 r"flugzeug\w*|aeroplanes?|airplanes?|"
                 r"motorrad\w*|motorbikes?|zug|zuege|trains?|raumschiff\w*|spaceships?|"
                 r"starship\w*|achterbahn\w*|roller ?coasters?)\b"),
    ("creatures", r"\b(dinosaurier\w*|dinosaurs?|dinos?|drache[n]?|dragons?|monsters\b|"
                  r"aliens?|tier(e|en)?|animals?|pferd(e|en)?|horses?|hund(e|en)?|dogs?|katzen?|cats?|"
                  r"kuehe?n?|cows?|schaf(e|en)?|sheep)\b"),
    ("npcs", r"\b(npcs?|bewohner\w*|einwohner\w*|passanten|villagers|townsfolk|"
             r"leute,? die rumlaufen|people walking)\b"),
    ("gravity", r"\b(schwerkraft|gravity|zero.?g|schwerelos\w*|weightless)\b"),
    ("portals", r"\b(teleport\w*|portal gun|(wie in|like in|like) portal)\b"),
    ("change", r"\b(jede runde ver\w*|changes every round|changes each round|"
               r"veraendert sich (jede|bei|beim|staendig)|changes while)\b"),
    ("real_place", r"\b(wohnort|heimatstadt|hometown|my town|meine stadt|koeln|berlin|"
                   r"hamburg|muenchen|chicago|new york|london|paris|eiffel\w*|"
                   r"google maps|openstreetmap)\b"),
    ("other_game", r"\b(minecraft|fortnite|hogwarts|zelda|pokemon|portal 2|counter.?strike|"
                   r"call of duty|gta|roblox|star wars|enterprise|harry potter)\b"),
    ("graphics", r"\b(grafik\w*|graphics|realistisch\w*|realistic|raytracing|4k|hd|"
                 r"texturen in hd)\b"),
    ("voice", r"\b(sprachausgabe|voice ?over|stimme\w*|spricht|talking|sound ?effekte?)\b"),
    ("chat", r"\b(witz\w*|jokes?|wetter morgen|weather tomorrow|wie geht'?s|how are you|"
             r"erzaehl|tell me)\b"),
    ("material", r"\b(schokolade|chocolate|kaese|cheese|suessigkeiten|candy)\b"),
]
GAME_WORDS = (r"\b(verstecken|versteck\w*|hide|prop ?hunt|fangen|zombies|ctf|flagge\w*|race|rennen|"
              r"parkour|sumo|deathmatch|shooter|erkund\w*|explore\w*)\b")
def _out_of_scope(r, low):
    found = []
    for kind, pat in OUT_OF_SCOPE:
        for m in re.finditer(pat, low):
            if _negated(low, m.start()):
                continue
            if kind == "creatures" and re.search(r"\b(koopa|goomba|boo|bob.?omb|chomp)|"
                                                 r"cat and mouse|katz(e)? und maus", low):
                continue
            found.append((m.start(), m.end(), kind, m.group(0)))
            break
    if not found:
        return
    for a, b, kind, words in found:
        note = "'%s': cannot build %s" % (words, kind)
        if note not in r.not_understood:
            r.not_understood.append(note)
        r.not_understood = [n for n in r.not_understood
                            if n == note or not (re.fullmatch(r"[a-z0-9' ]+", n) and
                                                 any(w in words.split() or words in n
                                                     for w in n.split()))]
    kinds = set(k for _, _, k, _ in found)
    if kinds & {"creatures", "npcs", "vehicles"} and r.raw.get("family") in ("hide", "explore") \
            and not re.search(GAME_WORDS, low):
        fam = r.raw.pop("family")
        r.understood = [u for u in r.understood if u != "family %s" % fam]
        r.assumed = [a for a in r.assumed if "family %s" % fam not in a]
        if r.raw.get("theme") == "garden" and fam == "explore":
            r.raw.pop("theme")
    if "portals" in kinds and re.search(r"\bportal(e|en|s)?\b(?! gun)", low):
        _drop_want(r, "gate")
        r.understood = [u for u in r.understood if u != "want gate"]
    if "vehicles" in kinds and re.search(r"\bu.?boot", low):
        objs = [o for o in r.raw.get("objects") or [] if o.get("key") != "boo"]
        if objs:
            r.raw["objects"] = objs
        else:
            r.raw.pop("objects", None)
        r.understood = [u for u in r.understood if not u.startswith("object boo")]
    if r.raw.get("features") == {"want": [], "avoid": []}:
        r.raw.pop("features")
_OOS_KEEP = re.compile(r"\"[^\"]*\"|\u201e[^\u201c\u201d]*[\u201c\u201d]|'[^']{2,}'|"
                       r"\b(?:namens|named|called|genannt|heisst|hei\u00dft)\s+\w+(?:\s+\w+)?", re.I)
def blank_out_of_scope(text):
    keep = [m.span() for m in _OOS_KEEP.finditer(text)]
    toks = [m for m in re.finditer(r"[^\W_]+|'", text)
            if not any(a <= m.start() < b for a, b in keep)]
    low, spans = "", []
    for m in toks:
        w = W.fold(m.group(0))
        if low and w != "'" and not low.endswith("'"):
            low += " "
        spans.append((len(low), len(low) + len(w), m.start(), m.end()))
        low += w
    kinds = OUT_OF_SCOPE
    if re.search(r"\b(koopa|goomba|boo|bob.?omb|chomp)|cat and mouse|katz(e)? und maus", low):
        kinds = [(k, p) for k, p in OUT_OF_SCOPE if k != "creatures"]
    cut = set()
    for kind, pat in kinds:
        for m in re.finditer(pat, low):
            if not _negated(low, m.start()):
                cut |= set((s, e) for la, lb, s, e in spans if la < m.end() and lb > m.start())
    if not cut:
        return text, []
    out = list(text)
    for s, e in cut:
        out[s:e] = " " * (e - s)
    return "".join(out), [text[s:e] for s, e in sorted(cut)]
SINGLE_THINGS = {"bruecke": "bridge", "bridge": "bridge", "turm": "tower", "tower": "tower",
                 "insel": "island", "island": "island", "tunnel": "tunnel", "rampe": "ramp",
                 "ramp": "ramp", "saeule": "pillar", "pillar": "pillar", "grube": "pit",
                 "pit": "pit", "bogen": "arch", "arch": "arch", "tor": "gate", "gate": "gate"}
def _single(r, low):
    for m in re.finditer(r"\b(eine?[nmrs]? einzige[nmrs]?|nur eine?[nmrs]?|a single|only one|"
                         r"just one|one single|genau eine?[nmrs]?|exactly one)\s+(\w+)", low):
        what = SINGLE_THINGS.get(m.group(2))
        if not what or _negated(low, m.start()):
            continue
        anchors = r.raw.setdefault("anchors", [])
        if any(a.get("what") == what for a in anchors):
            continue
        anchors.append({"what": what, "where": {"anywhere": True}})
        _said(r, "one %s (just one)" % what)
def _feature_word(word):
    table = {"treppen": "stairs", "treppe": "stairs", "stairs": "stairs", "steps": "stairs",
             "rampen": "ramps", "ramps": "ramps", "bruecken": "bridge", "bridges": "bridge",
             "tunnel": "tunnel", "tunnels": "tunnel", "wasser": "water", "water": "water",
             "lava": "lava", "berge": "mountains", "mountains": "mountains", "leitern": "stairs",
             "slide": "slide", "slides": "slide", "rutsche": "slide", "rutschen": "slide",
             "stufen": "stairs", "tuerme": "tower", "towers": "tower", "hoehlen": "caves",
             "caves": "caves", "inseln": "islands", "islands": "islands", "mauern": "walls",
             "walls": "walls", "zaeune": "fences", "fences": "fences", "pits": "pit",
             "gruben": "pit"}
    return table.get(word)
def _senses(r, low):
    if re.search(r"\bkeep (it|the|things|everything)\b", low) and not re.search(
            r"\b(a|the|an|old|stone|castle|tall) keep\b(?! it)", low.replace("keep it", "")):
        if _drop_want(r, "keep"):
            r.understood = [u for u in r.understood if "keep" not in u]
        if r.raw.get("theme") == "castle" and not re.search(r"\b(castle|burg|schloss|fort)", low):
            r.raw.pop("theme", None)
            r.raw.pop("preset", None)
            r.understood = [u for u in r.understood if "castle" not in u.lower()
                            and "burg" not in u.lower()]
    if any(re.search(r"\b(stern\w*|stars?)\b", cl) and re.search(
            r"\b(nacht\w*|night\w*|himmel\w*|sky|nachthimmel\w*|sternenhimmel\w*|starry)\b", cl)
            for cl in re.split(r"[,;.!?:\n]+", low)) \
            and not re.search(r"\b(sammel\w*|collect\w*|bonus|power ?stars?|"
                              r"(\d+|zwei|drei|vier|fuenf|sechs|sieben|acht|neun|zehn|"
                              r"two|three|four|five|six|seven|eight|nine|ten) (\w+ ){0,2}(stern|star)\w*|"
                              r"(stern|star)\w* \d+|versteck\w*|hide|hidden|verborgen\w*)\b", low):
        reqs = [q for q in r.raw.get("requests") or [] if q.get("kind") != "stars"]
        if len(reqs) != len(r.raw.get("requests") or []):
            if reqs:
                r.raw["requests"] = reqs
            else:
                r.raw.pop("requests", None)
            r.understood = [u for u in r.understood if "star" not in u.lower()]
            r.assumed = [a for a in r.assumed if "bonus star" not in a]
            if r.raw.get("family") == "explore" and not re.search(
                    r"\b(welt|world|erkund\w*|explor\w*)\b", low):
                r.raw.pop("family", None)
                r.raw.pop("theme", None) if r.raw.get("theme") == "garden" else None
    if re.search(r"\b(versteck ?spiel\w*|verstecken spiel\w*|versteckspiel\w*|hiding (map|game|level)|"
                 r"hide ?and ?seek)\b", low):
        if r.raw.get("family") != "hide":
            r.raw["family"] = "hide"
            _said(r, "family hide")
        _drop_want(r, "secret_alcove")
    if re.search(r"\b(parkour|parcours|hindernis\w*|obstacle|jump ?and ?run|jump'?n'?run)\b", low) \
            and r.raw.get("family") == "race" and not re.search(r"\b(rennen|race|racing)\b", low):
        r.raw["family"] = "course"
        _said(r, "family course")
    if r.raw.get("family") is None and re.search(
            r"\b(push each other off|runterschubs\w*|herunterschubs\w*|knock each other off|"
            r"push (people|players|them) off)\b", low):
        r.raw["family"] = "knockoff"
        _said(r, "family knockoff")
    if re.search(r"\bzombie", low) and "zombies" in (r.raw.get("modes") or []):
        r.raw["modes"] = [m for m in r.raw["modes"] if m != "laststanding"]
        if r.raw.get("family") == "shooter":
            from . import modes as modesmod
            fam = None
            try:
                fam = modesmod.family_of("zombies")
            except Exception:
                fam = None
            if fam:
                r.raw["family"] = fam
            else:
                r.raw.pop("family", None)
def _no_music_words(low):
    low = re.sub(r"\b(musik|music|song)\s+(vom|von|aus dem|from the|of the)\s+\w+([- ]?(level|welt|stage|lvl))?\b",
                 " ", low)
    low = re.sub(r"\b\w+[- ]?(level|lvl|stage)?[- ]?(musik|music|song|soundtrack)\b", " ", low)
    return re.sub(r"\b\w+[- ]?(level|lvl|stage)\b", " ", low)
def _themes(r, low):
    if re.search(r"\b(lava|magma)", low) and re.search(r"(burg|castle|festung|fortress)\b", low) \
            and not _negated(low, re.search(r"\b(lava|magma)", low).start()) \
            and r.raw.get("preset") in (None, "castle"):
        r.raw["preset"] = "lavafort"
        r.raw["theme"] = "lava"
        _said(r, "preset lavafort (a castle with lava)")
    if re.search(r"\w*wiese\w*|\bmeadows?\b", low) and r.raw.get("theme") in (None, "auto"):
        r.raw["theme"] = "garden"
        _said(r, "theme garden (a meadow)")
    if re.search(r"\bforr?ests?\b", low) and r.raw.get("preset") is None \
            and not _negated(low, re.search(r"\bforr?ests?\b", low).start()):
        r.raw["preset"] = "forest"
        _said(r, "preset forest")
    if re.search(r"\b(in|auf) (einer|der) burg\b|\bim burg-?stil\b|\bburgmauer\w*\b|castle walls|"
                 r"in castle style|in a castle", low) and r.raw.get("theme") in (None, "auto"):
        r.raw["theme"] = "castle"
        _said(r, "theme castle")
    if re.search(r"\bim eis-?stil\b|\bin ice style\b|\baus eis\b|\bmade of ice\b|\bon ice\b|"
                 r"\bauf eis\b", low) and r.raw.get("theme") in (None, "auto", "garden"):
        r.raw["theme"] = "ice"
        _said(r, "theme ice")
    if re.search(r"\bin den wolken\b|\bin the clouds\b|\bhoch im himmel\b|\bup in the sky\b", low):
        if r.raw.get("theme") in (None, "auto", "garden") or (
                r.raw.get("theme") == "desert" and not re.search(r"\b(wueste|desert|sand)\w*\b",
                                                                 _no_music_words(low))):
            r.raw["theme"] = "sky"
            _said(r, "theme sky")
def _length(r, low):
    if r.raw.get("family") != "course":
        return
    course = r.raw.get("course") or {}
    if course.get("length"):
        return
    for key, pat in (("short", r"\b(kurz\w*|short|quick)\b"),
                     ("long", r"\b(lang\w*|long)\b(?!\s+(sprung|spruen\w*|jumps?|weit\w*|"
                              r"und schmal\w*|and narrow|,? ?schmal\w*))"),
                     ("marathon", r"\b(marathon|endless|endlos\w*)\b")):
        m = re.search(pat, low)
        if m and not _negated(low, m.start()):
            course["length"] = key
            r.raw["course"] = course
            _said(r, "course %s" % key)
            return
def _volcano(r, low):
    for c, cp in COMPASS:
        m = re.search(r"\b(vulkan\w*|volcano\w*)\s*(?:,\s*)?(?:%s)\b" % cp, low)
        if m and not _negated(low, m.start()):
            anchors = r.raw.setdefault("anchors", [])
            if not any(a.get("what") == "volcano" for a in anchors):
                anchors.append({"what": "volcano", "where": {"compass": c}, "once": True})
                _said(r, "anchor volcano in the %s" % c)
            _want(r, "volcano")
            return
def apply(r, text, said=None):
    low = _clean(r, W.fold(text))
    fixed = getattr(r, "low", None) or ""
    both = low if not fixed or fixed == low else low + " . " + re.sub(r"\s+", " ", fixed)
    _senses(r, low)
    _size(r, low)
    _lexical(r, both)
    _places(r, both)
    _people(r, low)
    _weather(r, low)
    _music(r, low)
    _negation(r, low)
    _homonyms(r, low)
    _shooter_lookout(r)
    _mushrooms(r, low)
    _contradictions(r, low)
    _single(r, low)
    _out_of_scope(r, _clean(r, W.fold(said)) if said is not None else low)
    _themes(r, low)
    _length(r, low)
    _volcano(r, low)
    return r
