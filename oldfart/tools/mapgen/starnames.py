import re
REAL_ACT_NAMES = (
    "Big Bob-omb on the Summit", "Footrace with Koopa the Quick",
    "Shoot to the Island in the Sky", "Find the 8 Red Coins", "Mario Wings to the Sky",
    "Behind Chain Chomp's Gate",
    "Chip off Whomp's Block", "To the Top of the Fortress", "Shoot into the Wild Blue",
    "Red Coins on the Floating Isle", "Fall onto the Caged Island", "Blast Away the Wall",
    "Plunder in the Sunken Ship", "Can the Eel Come Out to Play?",
    "Treasure of the Ocean Cave", "Red Coins on the Ship Afloat",
    "Blast to the Stone Pillar", "Through the Jet Stream",
    "Slip Slidin' Away", "Li'l Penguin Lost", "Big Penguin Race",
    "Frosty Slide for 8 Red Coins", "Snowman's Lost His Head", "Wall Kicks Will Work",
    "Go on a Ghost Hunt", "Ride Big Boo's Merry-Go-Round", "Secret of the Haunted Books",
    "Seek the 8 Red Coins", "Big Boo's Balcony", "Eye to Eye in the Secret Room",
    "Swimming Beast in the Cavern", "Elevate for 8 Red Coins",
    "Metal-Head Mario Can Move!", "Navigating the Toxic Maze",
    "A-Maze-Ing Emergency Exit", "Watch for Rolling Rocks",
    "Boil the Big Bully", "Bully the Bullies", "8-Coin Puzzle with 15 Pieces",
    "Red-Hot Log Rolling", "Hot-Foot-It into the Volcano", "Elevator Tour in the Volcano",
    "In the Talons of the Big Bird", "Shining Atop the Pyramid",
    "Inside the Ancient Pyramid", "Stand Tall on the Four Pillars",
    "Free Flying for 8 Red Coins", "Pyramid Puzzle",
    "Board Bowser's Sub", "Chests in the Current", "Pole-Jumping for Red Coins",
    "The Manta Ray's Reward", "Collect the Caps...",
    "Snowman's Big Head", "Chill with the Bully", "In the Deep Freeze",
    "Whirl from the Freezing Pond", "Shell Shreddin' for Red Coins", "Into the Igloo",
    "Shocking Arrow Lifts!", "Top o' the Town", "Secrets in the Shallows & Sky",
    "Express Elevator--Hurry Up!", "Go to Town for Red Coins",
    "Quick Race Through Downtown!",
    "Scale the Mountain", "Mystery of the Monkey Cage", "Scary 'Shrooms, Red Coins",
    "Mysterious Mountainside", "Breathtaking View from Bridge",
    "Blast to the Lonely Mushroom",
    "Pluck the Piranha Flower", "The Tip Top of the Huge Island",
    "Rematch with Koopa the Quick", "Five Itty Bitty Secrets", "Wiggler's Red Coins",
    "Make Wiggler Squirm",
    "Roll into the Cage", "The Pit and the Pendulums", "Get a Hand",
    "Stomp on the Thwomp", "Timed Jumps on Moving Bars", "Stop Time for Red Coins",
    "Cruiser Crossing the Rainbow", "The Big House in the Sky",
    "Coins Amassed in a Maze", "Swingin' in the Breeze", "Tricky Triangles!",
    "Somewhere over the Rainbow",
)
def folded(name):
    return re.sub(r"[^a-z0-9]", "", str(name).lower())
_REAL = frozenset(folded(n) for n in REAL_ACT_NAMES)
def is_real_act(name):
    return folded(name) in _REAL
PLACE = {
    "village": ("Village", "Rooftops", "Old Town", "Market"),
    "hills": ("Hills", "Highlands", "Ridge", "Crags"),
    "forest": ("Forest", "Woods", "Grove", "Thicket"),
    "ruins": ("Ruins", "Old Walls", "Fallen Keep", "Ancient Stones"),
    "garden": ("Garden", "Hedges", "Flowerbeds", "Orchard"),
    "lake": ("Lake", "Pond", "Shallows", "Lagoon"),
    "plaza": ("Plaza", "Square", "Courtyard", "Fountain Court"),
    None: ("Meadow", "Fields", "Open Country", "Valley"),
}
THEME_WORD = {
    "snow": "Frozen", "ice": "Frozen", "desert": "Sunbaked", "lava": "Scorching",
    "haunted": "Haunted", "night": "Moonlit", "beach": "Sunny", "forest": "Mossy",
    "castle": "Royal", "sky": "Windy",
}
TEMPLATES = {
    "summit": ("Atop the {w} {p}", "Up Where the {p} Ends", "Summit of the {p}",
               "Top of the {w} Hill", "Climb Above the {p}", "Wind over the {p} Peak"),
    "corner": ("The Tower in the Corner", "Steps of the {p} Tower",
               "Corner Keep of the {p}", "Watchtower by the {p}", "Climb the {w} Tower"),
    "lift": ("Ride the Lift by the {p}", "Going Up by the {p}", "The {p} Lift Ledge",
             "All Aboard to the Ledge", "A Lift to the {w} Ledge"),
    "ferry": ("Ferry to the Floating Isle", "Drift Above the {p}", "The Isle Above the {p}",
              "Sail to the {w} Island", "The Floating Island"),
    "sunken": ("Deep in the {p} Waters", "Dive to the {p} Floor", "Under the {w} {p}",
               "Down at the Bottom of the {p}", "Treasure Beneath the {p}"),
    "cave": ("End of the {p} Cave", "Into the Dark of the {p}", "Deep in the {w} Cave",
             "Where the {p} Cave Ends", "Light at the Cave's End"),
    "cannon": ("Cannon Shot over the {p}", "Fire Away to the Isle", "Blasted Above the {p}",
               "One Shot to the {w} Isle", "Launch from the {p}"),
    "guarded": ("Past the {p} Guards", "Guards on the {p} Deck", "Sneak by the Sentries",
                "Watchmen of the {p}", "The Guarded {p} Deck"),
    "wallrun": ("Run Up the Triangle Wall", "Triangles on the {p} Wall",
                "Wall Run in the {p}", "Up the {w} Block Wall", "Tilted Blocks to the Top"),
    "pillars": ("Hop the {p} Pillars", "Stepping Stones to the Sky", "Pillar Hops by the {p}",
                "Over the {w} Pillars", "Six Pillars Up"),
    "chimney": ("Wall-Kick Tower", "Kick Up the {p} Chimney", "Inside the {w} Chimney",
                "Bounce Up the Chimney", "The Chimney of the {p}"),
    "longjump": ("Leap from the {p} Deck", "One Big Leap to the Isle",
                 "Long Jump over the {p}", "Fly Off the {w} Deck", "A Leap of Faith"),
}
DEFAULT_WORD = {"summit": "Windy", "corner": "Lonely", "lift": "High", "ferry": "Hidden",
                "sunken": "Quiet", "cave": "Crystal", "cannon": "Distant",
                "guarded": "Old", "wallrun": "Crooked", "pillars": "Tall",
                "chimney": "Old", "longjump": "Open"}
MAX_LEN = 30
def _english(name):
    return all(ord(ch) < 128 for ch in name)
def name_stars(stars, districts=None, theme=None, seed=0, taken=None):
    import random
    r = random.Random("starnames:%s" % seed)
    kind_of = {d.get("i"): d.get("kind") for d in districts or []}
    used = set(folded(n) for n in (taken or []) if n)
    for st in stars:
        if st.get("name"):
            used.add(folded(st["name"]))
    for st in stars:
        if st.get("name"):
            continue
        place = kind_of.get(st.get("district"))
        nouns = list(PLACE.get(place) or PLACE[None])
        word = THEME_WORD.get(str(theme or "").lower()) or DEFAULT_WORD.get(st.get("kind"),
                                                                           "Hidden")
        temps = list(TEMPLATES.get(st.get("kind")) or ("The Star of the {p}",))
        r.shuffle(temps)
        r.shuffle(nouns)
        got = None
        for t in temps:
            for p in nouns:
                n = t.format(p=p, w=word)
                if len(n) > MAX_LEN or not _english(n) or is_real_act(n) or folded(n) in used:
                    continue
                got = n
                break
            if got:
                break
        if got is None:
            got = "Bonus Star %d of the %s" % (st.get("id", 0), nouns[0])
        used.add(folded(got))
        st["name"] = got
    return stars
ISLAND = ["ferry", "cannon", "pillars", "longjump"]
HINT_WORDS = [
    (r"wandsprung\w*|wall[- ]?kick\w*|kamin\w*|chimney", ["chimney"]),
    (r"kanone\w*|cannon\w*", ["cannon"]),
    (r"weitsprung\w*|long[- ]?jump\w*", ["longjump"]),
    (r"saeule\w*|pillars?|pfeiler\w*|trittsteine?\w*|stepping", ["pillars"]),
    (r"dreieck\w*|triangl\w*|wall ?run|wandlauf", ["wallrun"]),
    (r"faehre\w*|ferry", ["ferry"]),
    (r"lift\w*|aufzug\w*|fahrstuhl\w*|elevator", ["lift"]),
    (r"bewach\w*|guard\w*|waechter\w*|gegner\w*|wachen", ["guarded"]),
    (r"schwebend\w* insel|floating (?:isle|island)|sky island|himmelsinsel\w*|insel\w*|"
     r"island|isle", ISLAND),
    (r"hoehle\w*|cave\w*|grotte\w*|tunnel\w*", ["cave"]),
    (r"unter ?wasser|underwater|teich\w*|pool\w*|lake|seegrund|grund des|tauch\w*|"
     r"dive|bottom of", ["sunken"]),
    (r"turm\w*|tower\w*|ecke\w*|corner", ["corner"]),
    (r"berg\w*|gipfel\w*|huegel\w*|mountain\w*|summit|peak|hill\w*|spitze", ["summit"]),
]
ORDINALS = {"erste": 1, "ersten": 1, "erster": 1, "first": 1, "zweite": 2, "zweiten": 2,
            "zweiter": 2, "second": 2, "dritte": 3, "dritten": 3, "dritter": 3, "third": 3,
            "vierte": 4, "vierten": 4, "vierter": 4, "fourth": 4, "fuenfte": 5,
            "fuenften": 5, "fuenfter": 5, "fifth": 5, "sechste": 6, "sechsten": 6,
            "sechster": 6, "sixth": 6}
QUOTES = r"'([^']{2,40})'|\"([^\"]{2,40})\"|„([^“”]{2,40})[“”]|" \
         r"“([^”]{2,40})”|‘([^’]{2,40})’"
_START = re.compile(r"\b(?:(?:bonus ?)?(?:stern|star)(?:\s*(?:nr\.?|no\.?|nummer|number|#))?"
                    r"\s*(\d)\b|(%s)\s+(?:bonus ?)?(?:stern|star)\b)"
                    % "|".join(sorted(ORDINALS, key=len, reverse=True)))
def read_hints(text):
    from .wish import fold
    names = []
    def keep(m):
        names.append((m.start(), m.end(), next(g for g in m.groups() if g)))
        return " " * (m.end() - m.start())
    bare = re.sub(QUOTES, keep, text)
    low = fold(bare)
    if len(low) != len(bare):
        offsets = False
    else:
        offsets = True
    starts = [m for m in _START.finditer(low)]
    if not starts:
        return text, []
    hints = []
    cut = []
    for i, m in enumerate(starts):
        n = int(m.group(1)) if m.group(1) else ORDINALS.get(m.group(2), 0)
        end = starts[i + 1].start() if i + 1 < len(starts) else len(low)
        stop = re.search(r"[,;.]\s|[,;.]$|\bund (?!(?:bonus ?)?(?:stern|star))", low[m.end():end])
        seg_end = m.end() + stop.start() if stop else end
        seg = low[m.start():seg_end]
        if not 1 <= n <= 6:
            continue
        kinds = []
        for pat, ks in HINT_WORDS:
            if re.search(r"\b(?:%s)" % pat, seg[m.end() - m.start():]):
                kinds = list(ks)
                break
        h = {"n": n, "words": seg.strip()}
        if kinds:
            h["kinds"] = kinds
        hints.append(h)
        cut.append((m.start(), seg_end, h))
    for k, (a, b, name) in enumerate(names):
        owner = None
        for (s, e, h) in cut:
            if offsets and s <= a <= e + 2:
                owner = h
        if owner is None and not offsets and k < len(cut):
            owner = cut[k][2]
        if owner is None and cut:
            owner = min(cut, key=lambda c: abs(c[0] - a))[2] if offsets else cut[-1][2]
        if owner is not None and "name" not in owner:
            owner["name"] = name.strip()
    out = list(low)
    for (s, e, h) in cut:
        for j in range(s, min(e, len(out))):
            out[j] = " "
    rest = re.sub(r"\s+", " ", "".join(out)).strip(" ,;")
    seen, uniq = set(), []
    for h in hints:
        if h["n"] in seen:
            continue
        seen.add(h["n"])
        uniq.append(h)
    return rest, sorted(uniq, key=lambda h: h["n"])
def hint_request(hints, count=None):
    stars = []
    for h in hints:
        e = {"n": h["n"]}
        if h.get("kinds"):
            e["kinds"] = list(h["kinds"])
        if h.get("name"):
            e["name"] = h["name"]
        stars.append(e)
    top = max([h["n"] for h in hints] or [0])
    n = max(count or 0, top)
    return {"kind": "stars", "count": min(6, n) if n else None, "stars": stars}
