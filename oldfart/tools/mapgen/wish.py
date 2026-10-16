import difflib
import re
if getattr(re, "_MAXCACHE", 4096) < 4096:
    re._MAXCACHE = 4096
from . import brief as briefmod
from . import negation
FOLD = (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss"), ("é", "e"), ("’", "'"),
        ("–", "-"), ("—", "-"),
        ("\ufe0f", ""), ("🌲", " forest "), ("🌳", " forest "), ("🏰", " castle "),
        ("🌙", " night "), ("🌕", " full moon "), ("❄", " snow "), ("☃", " snow "),
        ("🌋", " volcano "), ("👻", " spooky "), ("🌊", " water "), ("⛰", " mountains "),
        ("🏔", " mountains "), ("🔥", " lava "), ("🏝", " island "), ("🏜", " desert "),
        ("🌅", " sunset "), ("🌄", " sunset "), ("☀", " sunny "), ("🌞", " sunny "),
        ("🌧", " rain "), ("⛈", " thunderstorm "), ("🌩", " thunderstorm "),
        ("🌫", " fog "), ("🏡", " house "), ("🏠", " house "), ("🍄", " mushrooms "),
        ("🏖", " beach "), ("🌴", " palm trees "), ("💀", " spooky "), ("🎃", " spooky "))
def fold(text):
    t = text.lower()
    for a, b in FOLD:
        t = t.replace(a, b)
    return t
NUMBERS = {
    "ein": 1, "eine": 1, "einen": 1, "einem": 1, "einer": 1, "eins": 1, "a": 1, "an": 1,
    "one": 1, "single": 1, "einzelne": 1, "einzelnen": 1, "einzigen": 1, "einzige": 1,
    "zwei": 2, "two": 2, "beide": 2, "both": 2, "pair": 2, "paar_": 2, "couple": 2,
    "drei": 3, "three": 3, "vier": 4, "four": 4, "fuenf": 5, "five": 5, "sechs": 6,
    "six": 6, "sieben": 7, "seven": 7, "acht": 8, "eight": 8, "neun": 9, "nine": 9,
    "zehn": 10, "ten": 10, "elf": 11, "eleven": 11, "zwoelf": 12, "twelve": 12,
    "dreizehn": 13, "thirteen": 13, "vierzehn": 14, "fourteen": 14, "fuenfzehn": 15,
    "fifteen": 15, "sechzehn": 16, "sixteen": 16, "zwanzig": 20, "twenty": 20,
    "dutzend": 12, "dozen": 12,
}
VAGUE = [(r"\bein paar\b|\ba few\b|\bfew\b|\beinige\b|\bsome\b", 3),
         (r"\bein bisschen\b|\ba couple of\b|\bcouple of\b", 2),
         (r"\bmehrere\b|\bseveral\b", 4),
         (r"\bviele\b|\blots of\b|\bmany\b|\bjede menge\b|\ba lot of\b|\bhaufenweise\b", 8)]
NUM_RE = r"(\d+|%s)" % "|".join(sorted((k for k in NUMBERS if not k.endswith("_")),
                                        key=len, reverse=True))
def number(word):
    if word is None:
        return None
    if word.isdigit():
        return int(word)
    return NUMBERS.get(word)
VOCAB = """
spieler players turm tuerme towers tower bruecke bruecken bridge bridges grube pit
huegel hill krone crown mitte middle centre center zentrum norden sueden osten westen
nordwesten nordosten suedwesten suedosten north south east west northwest northeast
southwest southeast vertikalitaet verticality vertikal vertical deckung cover offen open
offener flach flat schnell fast langsam slow klein kleine kleinen small gross grosse grossen
large big riesig huge winzig tiny mittel medium eis ice schnee snow wueste desert lava
feuer burg schloss castle festung holz wood himmel sky garten garden wiese rampen rampe
ramps ramp treppen treppe stairs stufen saeulen pillars columns mauern walls waende
spawn spawns rand edge ecken corners zwischen between neben next ueber above around
gegenueber opposite hinter behind entlang along symmetrisch asymmetrisch symmetric
asymmetric gespiegelt mirrored teams team gegen versus shooter deathmatch arena karte
map rennstrecke rennen race strecke track verstecken hide parkour hindernis obstacle
course sumo flagge flaggen flag domination kontrollpunkte goombas goomba muenzen coins
coin itemboxen itembox trampoline trampolin herzen hearts kisten boxes aufzug elevator
lifts plattform plattformen platforms inseln islands tunnel tunnels tor gate abkuerzung
shortcut spruenge jumps luecken gaps geländer railings gelaender rails leere void boden
ground wasser water ohne without keine kein nicht viel viele mehr weniger more less
hoeher higher groesser bigger kleiner smaller schneller faster etagen ebenen floors levels
schwierig schwer leicht easy hard detailliert schlicht plain detailed verziert
basen bases basis lager perch perches aussichtspunkt nischen nooks platform
vulkan
""".split()
def correct(text, guard=True):
    notes = []
    vocab = set(VOCAB)
    if guard:
        from . import commonguard
        common = commonguard.words()
    else:
        common = ()
    def fix(m):
        w = m.group(0)
        if len(w) < 5 or w in vocab or w in NUMBERS or w.isdigit() or w in STOP or w in common:
            return w
        if LEXICON and _lexicon_word(w):
            return w
        if LEXICON:
            from . import lexicon
            if w in lexicon._protected():
                return w
        close = difflib.get_close_matches(w, VOCAB, n=1, cutoff=0.82)
        if close and (close[0][0] != w[0] or close[0] in w or w in close[0]
                      or abs(len(close[0]) - len(w)) > 2):
            close = None
        if close and close[0] != w:
            notes.append("%r read as %r" % (w, close[0]))
            return close[0]
        return w
    return re.sub(r"[a-z]+", fix, text), notes
FAMILY_WORDS = [
    (r"capture the flag|\bctf\b|flaggen ?(erobern|klau\w*)|\bflagge\b|\bflaggen\b|"
     r"\bflags?\b", "objective", ["ctf"]),
    (r"\bdomination\b|kontrollpunkt\w*|control points?|\bdom\b", "objective", ["domination"]),
    (r"king of the hill|\bkoth\b|koenig des huegels|huegelkoenig", "objective", ["koth"]),
    (r"\bsumo\b|knock.?off|runterschubsen|runterstossen|push.?off|ring.?kampf",
     "knockoff", []),
    (r"rennstrecke|\brennen\b|\brace\b|racing|racetrack|race track|rundkurs|\btrack\b|"
     r"\bstrecke\b", "race", []),
    (r"verstecken|versteckspiel|hide.?and.?seek|\bhide\b|\bfangen\b|\bhunt\b|\bjagd\b|"
     r"\bchase\b", "hide", []),
    (r"\bparty\b|minispiel\w*|minigame\w*", "party", []),
    (r"parkour|hindernis\w*|obstacle|\bcourse\b|\bco.?op\b|kletter\w*|\bclimb\b",
     "course", []),
    (r"bereis\w*|erkund\w*|erforsch\w*|\bwelt\b(?!\s*spawn)|open.?world|\bexplor\w*|"
     r"\btravel\w*|\broam\w*|\bwander\w*|\bentdeck\w*|\bworld\b(?!\s*spawn)|\breise\w*",
     "explore", []),
    (r"shooter|deathmatch|\bdm\b|ballern|schiess\w*|\bffa\b|free.?for.?all|jeder gegen "
     r"jeden|ballerei|shoot\w*|\bgefecht\b|\bkampf\w*", "shooter", []),
]
SIZE_WORDS = [(r"\bwinzig\w*|\btiny\b|\bmini\b", "tiny"),
              (r"gigantisch\w*|\bgigantic\b|\bmaximal\w*|\briesigste\w*|\bendlos\w*|"
               r"\bopen.?world\b|so gross wie (es )?(geht|moeglich)|as big as (it gets|possible)|"
               r"\bbiggest\b|\bgroesste\w*", "gigantic"),
              (r"\briesig\w*|\briesen\w*|\bhuge\b|\bmassive\b|"
               r"\benorm\w*|\bmassiv\w*", "huge"),
              (r"\bklein\w*|\bsmall\b|(?<!\ba )\blittle\b|\ba little(?= (map|arena|level|world|"
               r"island|keep|castle|place|course|track)\b)|\bkompakt\w*|\bcompact\b|\bcosy\b|\bcozy\b",
               "small"),
              (r"\bgross\w*|\bbig\b|\blarge\b|\bweit\b|\bgeraeumig\w*|\bspacious\b", "large"),
              (r"\bmittel(gross|grosse|groesse)?\b|\bmedium\b|normale groesse|normal size",
               "medium")]
LANDSCAPE_AFTER = (r"\s*(\w+\s+)?(map|arena|karte|level|landschaft\w*|welt\w*|world|"
                   r"landscape\w*|natur\w*|gegend|gelaende)\b")
PACE_WORDS = [(r"\bschnell\w*|\bfast\b|\bquick\w*|\brasant\w*|\bhektisch\w*|\bhectic\b|"
               r"action.?reich|\bspeedy\b", "fast"),
              (r"\blangsam\w*|\bruhig\w*|\bslow\b|gemuetlich\w*|\btaktisch\w*|\btactical\b|"
               r"\bchill\w*", "slow")]
THEME_WORDS = [(r"\beis\w*|\bice\b|\bicy\b|\bwinter\w*|\bschnee\w*|\bsnow\w*|\bfrost\w*|"
                r"\bfrozen\b|\bgefroren\w*", "ice"),
               (r"\bwueste\w*|\bdesert\b|\bsand\w*|\bduenen\b|\bdunes?\b|\bpyramid\w*",
                "desert"),
               (r"\blava\b|\bfeuer\w*|\bfire\b|\bmagma\b|\bhoelle\b|"
                r"\bhell\b|\binferno\b", "lava"),
               (r"\bburg\w*|\bschloss\w*|\bcastle\b|\bfestung\w*|\bfortress\b|\bmittelalter\w*|\bfort\b",
                "castle"),
               (r"\bholz\w*|\bwood\w*|\bhuette\w*|\bplanken\b|\bplanks?\b", "wood"),
               (r"\bhimmel\w*|\bsky\b|\bwolken\w*|\bclouds?\b|\bluft\b", "sky"),
               (r"\bgarten\w*|\bgarden\w*|\bwiese\w*|\bgruen\w*|\bgrass\w*|\bgras\b|\bpark\b|"
                r"\bwald\b|\bforest\b|\bjungle\b|\bdschungel\b", "garden")]
VERT_WORDS = [(r"vertikal\w* (hoch|viel|stark)|(viel|lots of|much|high|great|hohe|grosse|starke) "
               r"?(vertikal\w*|verticality|"
               r"hoehe|hoehenunterschied\w*|height)|sehr vertikal|very vertical|\bvertical\b|"
               r"\bvertikal\w*|hoch hinaus|mehrere (ebenen|etagen|stockwerke)|multi.?level\w*|"
               r"many (levels|floors)|\btuermig\b|\bhigh\b|\btall\b|stacked (floors|levels)|"
               r"gestapelt\w*|uebereinander\w*|vertikal\w* (hoch|viel|stark)|"
               r"(verticality|height) (high|lots)", "high"),
              (r"(etwas|some|a bit of|ein bisschen) ?(vertikal\w*|verticality|hoehe|height)",
               "medium"),
              (r"wenig ?(vertikal\w*|hoehe)|little (verticality|height)|low verticality|"
               r"\bniedrig\w*|\blow\b|\bzwei (ebenen|etagen)\b|\btwo (floors|levels)\b", "low"),
              (r"\bflach\w*|\bflat\b|\beben\b|keine hoehenunterschiede|no height|single "
               r"level|one level|eine ebene", "flat")]
DENSITY_WORDS = [(r"(viel|lots of|much|heaps of) ?(deckung|cover)|\beng\b|\benge\b|"
                  r"\btight\b|\bdense\b|\bdicht\w*|\bverwinkelt\w*|\blabyrinth\w*|\bcramped\b|"
                  r"\bcluttered\b|\bmaze\b|deckung (viel|reichlich|dicht)|cover (lots|heavy)|"
                  r"\b(deckung|cover) (alle (ein )?(paar|par|wenige[nr]?) (metern?|schritte)|every (few|couple "
                  r"of|other|so many) (meters?|metres?|steps?|yards?|feet))\b",
                  "dense"),
                 (r"\boffen\w*|\bopen\b|\bweitlaeufig\w*|wenig deckung|little cover|"
                  r"\bsparse\b|freie sicht|clear sight\w*|\bluftig\b|nothing to hide "
                  r"behind|nichts zum verstecken|keine deckung|no cover", "sparse"),
                 (r"(etwas|some|a bit of) ?(deckung|cover)", "medium")]
COMPARATIVES = [
    (r"\bmehr deckung\b|\bmore cover\b", "density", "dense", "more cover"),
    (r"\bweniger deckung\b|\bless cover\b", "density", "sparse", "less cover"),
    (r"\boffener\b|\bmore open\b|\bopener\b", "density", "sparse", "more open"),
    (r"\benger\b|\btighter\b|\bverwinkelter\b", "density", "dense", "tighter"),
    (r"\bhoeher\b|\bmehr hoehe\b|\bmore height\b|\btaller\b|\bmore vertical\b|"
     r"\bvertikaler\b", "verticality", "high", "higher"),
    (r"\bflacher\b|\bflatter\b|\bless height\b|\bweniger hoehe\b", "verticality", "low",
     "flatter"),
    (r"\bgroesser\b|\bbigger\b|\blarger\b", "size", "large", "bigger"),
    (r"\bkleiner\b|\bsmaller\b", "size", "small", "smaller"),
    (r"\bschneller\b|\bfaster\b", "pace", "fast", "faster"),
    (r"\blangsamer\b|\bslower\b|\bruhiger\b|\bcalmer\b", "pace", "slow", "slower"),
]
SYM_WORDS = [(r"\basymmetri\w*|\bunsymmetri\w*|\buneven\b|\bungleich\w*", "none"),
             (r"\bspiegel\w*|\bgespiegelt\w*|\bmirror\w*", "mirror"),
             (r"\bvierfach\w*|\b4.?fach\w*|\bfour.?fold\b|\bdrehsymmetri\w*|\brotational\b",
              "turn4"),
             (r"\bzweifach\w*|\bpunktsymmetri\w*|\btwo.?fold\b|\bhalf.?turn\b", "turn2"),
             (r"\bachtfach\w*|\beight.?fold\b", "turn8"),
             (r"\bturn ?2\b", "turn2"), (r"\bturn ?4\b", "turn4"), (r"\bturn ?8\b", "turn8")]
LEVEL_WORDS = [(r"ueber der leere|over the void|\bleere\b|\bvoid\b(?! ?gaps?)|\bschwebend\w*|\bfloating\b|ueber dem abgrund|"
                r"\bim himmel\b|in the sky|\bin der luft\b", "empty2"),
               (r"\btiles\b|\bfliesen\b|auf dem boden|on the ground|auf festem boden|"
                r"auf der erde", "empty")]
EDGE_WORDS = [(r"ummauert|\bwalled\b|mauern? (drum ?herum|rundherum|ringsum)|walls? around|"
               r"eingezaeunt|\bfenced\b|\bcompounds?\b", "walled"),
              (r"ohne gelaender|no rail\w*|death edges?|todeskanten?|runterfallen|fall off|"
               r"offene kanten|\bdeath.?plane\b", "void"),
              (r"mit gelaender\w*|with rail\w*|gelaender ringsum|railings? around", "rails")]
BOUNDARY_WORDS = [(r"(niedrige[rn]? )?(rand|kante|rim) (und|mit|plus) (einer )?unsichtbare[rn]? "
                   r"(wand|mauer|grenze)|(low )?rim (and|with|plus) (an )?invisible (wall|boundary|border)",
                   "both"),
                  (r"unsichtbare[rn]? (wand|waende|mauer|mauern|grenze|begrenzung|rand)|"
                   r"invisible (walls?|boundary|border|barrier|edge)", "invisible"),
                  (r"(?<!un)sichtbare[rn]? (wand|mauer|grenze|begrenzung)|\bvisible (walls?|boundary|border)",
                   "visible")]
DIFF_WORDS = [(r"\bhardcore\b|\bkaizo\w*|\bfuer (die )?profis\b|\bfor (the )?pros\b", "pro"),
              (r"\b(easy|simple) for (little )?(kids|children)\b|"
               r"\b(leicht|einfach)\w* fuer (kleine )?kinder\b", "easy"),
              (r"\b(sehr )?(schwer|schwierig\w*|knackig\w*|anspruchsvoll\w*)\b|\bhard\b|"
               r"\bdifficult\b|\bchalleng\w*|\bbrutal\b", "hard"),
              (r"\b(leicht|einfach)e?n? (strecke|parkour|kurs|map|karte|spruenge|course)\b|"
               r"\beasy\b|\banfaenger\w*|\bbeginner\w*|schwierigkeit leicht", "easy"),
              (r"mittlere schwierigkeit|medium difficulty|normal difficulty|"
               r"\bmittelschwer\w*", "normal")]
STYLE_WORDS = [(r"\bschlicht\w*|\bplain\b|\bminimal\w*|\bclean\b|\bschnoerkellos\b", "plain"),
               (r"\bverziert\w*|\bdetailliert\w*|\bprunkvoll\w*|\bornate\b|\bdetailed\b|"
                r"\bfancy\b|\bschick\w*|\bschoen\w*|\bbeautiful\b|\bpretty\b", "built")]
DNA_WORDS = [
    (r"\bkomplex\w*\s*(bauten|gebaeude\w*|strukturen|architektur|bauwerke?|haeuser\w*)?|"
     r"\bverschachtelt\w*|\bdetailreich\w*|\baufwendig\w*|\bausgekluegelt\w*|"
     r"\bcomplex\b(\s*(buildings|structures|architecture))?|\bintricate\b|\belaborate\b|"
     r"\bviele (bauten|gebaeude|haeuser)\b|\blots of buildings\b",
     "complexity", 0.9, "complex structures"),
    (r"\beinfach\w* (bauten|gebaeude|formen|strukturen)\b|\bsimple (buildings|shapes|"
     r"structures)\b|\bwenig(e)? (bauten|gebaeude)\b|\bblockig\w*|\bblocky\b",
     "complexity", 0.15, "simple structures"),
    (r"\bstimmig\w*(\s*(textur\w*|farb\w*|material\w*|look|optik|palette))?|"
     r"\bpassend\w* (textur\w*|farb\w*|material\w*)|\beinheitlich\w*|\bharmonisch\w*|"
     r"\bcoheren\w*( (textures|palette|look|materials))?|\bmatching (textures|materials)\b|"
     r"\bconsistent (textures|look|palette|materials)\b|\bcohesive\b|\baus einem guss\b",
     "coherence", 0.9, "a coherent palette"),
    (r"\bwunderschoen\w*|\bbildschoen\w*|\bschoen(e|en|er|es)\b|\bschoen\b(?=\s*(map|karte|level|welt|arena|$|[,.!]))|\bbeautiful\b|\bstunning\b|\bgorgeous\b|"
     r"\bmalerisch\w*|\bpicturesque\b|\bhuebsch\w*",
     "coherence", 0.85, "beautiful (a coherent palette)"),
    (r"\bbunt\w*|\bfarbenfroh\w*|\bcolou?rful\b|\bwild gemischt\w*|\bmixed textures\b|"
     r"\bkunterbunt\w*|\bmany colou?rs\b|\bviele farben\b",
     "coherence", 0.1, "a colourful mix"),
    (r"\balt(e|en|er|es)?\b|\bruine\w*|\bverfallen\w*|\bzerfallen\w*|\bantik\w*|\buralt\w*|\bancient\b|"
     r"\bruined\b|\bruins\b|\babandoned\b|\bverlassen\w*|\bbemoost\w*|\bmossy\b|"
     r"\bovergrown\b|\bueberwuchert\w*|\bvergessen\w*|\bforgotten\b|\bcrumbling\b",
     "age", 0.85, "old and worn"),
    (r"\bnagelneu\w*|\bbrand.?new\b|\bpristine\b|\bblitzblank\w*|\bmodern\w*|\bsauber\w*",
     "age", 0.0, "new and clean"),
    (r"\bnatuerlich\w*|\bnatur\w*|\bwildnis\b|\bwilderness\b|\bnatural\b|\boutdoors?\b|"
     r"\bim freien\b|\bdraussen\b|"
     r"\b(training|exercise|drill) ?yards?\b|\bausbildungsgelaende\b",
     "nature", 0.8, "a natural ground"),
    (r"\bcompounds?\b",
     "nature", 0.1, "a compound (a built, walled yard)"),
    (r"\bstaedtisch\w*|\burban\b|\bstadt\b|\bcity\b|\bkuenstlich\w*|\bartificial\b",
     "nature", 0.0, "built ground"),
    (r"\bzum erkunden\b|\berkund\w*|\bexplor\w*|\bgeheim\w*|\bsecret\w*|\bverwinkelt\w*|"
     r"\bnooks and crannies\b|\bverborgen\w*|\bhidden (rooms|passages|ways)\b",
     "exploration", 0.9, "much to explore"),
]
VISUAL_WORDS = [
    (r"\bsonnenuntergang\w*|\bsunset\b|\babendrot\w*|\bdaemmerung\b|\bdusk\b", "sunset"),
    (r"\bwarm\w* (sonne|licht)\b|\bwarm (sun|light)\b|\bsonnig\w*|\bsunny\b|\bgoldene stunde\b|"
     r"\bgolden hour\b", "warm_sun"),
    (r"\bmondlicht\w*|\bmoonlight\w*|\bmondschein\w*|\bbei nacht\b|\bat night\b|\bnachts\b|"
     r"\bnight ?time\b", "moonlight"),
    (r"\bfackel\w*|\bfeuerschein\w*|\bfirelight\b|\blagerfeuer\w*|\btorch\w*", "firelight"),
    (r"\bharte schatten\b|\bhard shadows\b|\bkontrastreich\w*|\bhigh contrast\b", "hard_shadows"),
    (r"\bschneesturm\w*|\bblizzard\w*", "blizzard"),
    (r"\bschneefall\w*|\bes schneit\b|\bfallende\w* schnee\w*|\bfalling snow\b|\bsnowing\b|"
     r"\bschneeflocken\b|\bsnowflakes\b", "snow"),
    (r"\bbluetenblaett\w*|\bblumenblaett\w*|\bpetals?\b|\bblueten\w*", "petals"),
    (r"\bgewitter\w*|\bthunderstorm\w*|\bthunder\b|\bblitz und donner\b", "thunderstorm"),
    (r"\bregen\b|\bregnet\b|\bregnerisch\w*|\brain\b|\brainy\b|\braining\b", "rain"),
    (r"\bsepia\w*|\bvintage\b|\bnostalgisch\w*|\bnostalgic\b|\balte(s|r)? foto\w*", "sepia"),
    (r"\brostig\w*|\brust(y)?\b|\brostfarb\w*", "rust"),
    (r"\bgruenspan\w*|\bverdigris\b|\bpatina\b", "verdigris"),
    (r"\beisig\w* (licht|farb\w*|toene|look)\b|\bicy (tint|light|colou?rs|look)\b|"
     r"\bkalte farben\b|\bcold colou?rs\b", "ice_tint"),
    (r"\bgolden\w* (look|glanz|toene|licht)\b|\bgold(en)? tint\b|\bvergoldet\w*", "gold"),
    (r"\broter? dunst\b|\broten dunst\b|\bred haze\b", "red_haze"),
    (r"\bblaue\w* ferne\b|\bblue distance\b", "blue_distance"),
    (r"\bdichte\w* nebel\w*|\bdicke\w* nebel\w*|\bthick fog\b|\berbsensuppe\b|"
     r"\bpea soup\b", "thick_fog"),
    (r"\bstaubige\w* luft\b|\bstaub in der luft\b|\bdusty air\b|\bdust in the air\b|"
     r"\bsandsturm\w*|\bsandstorm\w*", "dust"),
    (r"\brauch\b|\brauchig\w*|\bsmoke\b|\bsmoky\b|\bqualm\w*", "smoke"),
    (r"\bhimmelsfarbe\w* dunst\w*|\bdunst in (der )?farbe des himmels\b|"
     r"\bsky[- ]colou?red haze\b|\bhaze the colou?r of the sky\b", "sky_haze"),
    (r"\bdunst\w*|\bdiesig\w*|\bhaze\b|\bhazy\b", "haze"),
    (r"\bnebel\w*|\bneblig\w*|\bfog\b|\bfoggy\b|\bmisty\b", "fog"),
    (r"\bklare\w* (luft|sicht)\b|\bclear (air|view)\b", "clear_air"),
    (r"\bmit (visuellen |grafischen |optischen )?effekten\b|\bstimmungsvoll\w*|"
     r"\batmosphaer\w*|\bmoody\b|\batmospheric\b|\bwith (visual )?effects\b|"
     r"\bvisuell aufgewertet\b|\bfancy (look|visuals)\b", "auto"),
]
GROUND_WORD = {"gras": "grass", "grass": "grass", "rasen": "grass", "wiese": "grass",
               "eis": "ice", "ice": "ice", "sand": "sand", "wueste": "sand", "desert": "sand",
               "stein": "stone", "stone": "stone", "fels": "stone", "schnee": "snow",
               "snow": "snow", "holz": "wood", "wood": "wood", "wooden": "wood",
               "planken": "wood", "fliesen": "tiles", "tiles": "tiles", "checker": "tiles"}
GROUND_RE = (r"(the tiles|tiles|basismap|base ?map|untergrund|grundboden|level.?boden|"
             r"ground of the tiles)\s*(?:\w+\s*)?(?:aus|mit|in|of|with|als|aus)\s*(\w+)"
             r"|(gras|grass|rasen|eis|ice|sand|stein|stone|schnee|snow|holz|wooden|wood)"
             r"[\s-]*(tiles|untergrund|grundboden|variante)")
SKY_WORDS = [(r"lila himmel|purple sky|violett\w* himmel", "BACKGROUND_PURPLE_SKY"),
             (r"feuerhimmel|roter himmel|flaming sky|red sky", "BACKGROUND_FLAMING_SKY"),
             (r"schneeberge|snow mountains|verschneite berge", "BACKGROUND_SNOW_MOUNTAINS"),
             (r"ueber den wolken|above the clouds|wolkenhimmel", "BACKGROUND_ABOVE_CLOUDS"),
             (r"blauer himmel|blue sky|ozeanhimmel|ocean sky|meerblick", "BACKGROUND_OCEAN_SKY"),
             (r"unterwasser\w*|underwater", "BACKGROUND_UNDERWATER_CITY"),
             (r"spuk\w* himmel|haunted sky|gruselig\w*|spooky", "BACKGROUND_HAUNTED"),
             (r"wuestenhimmel|desert sky", "BACKGROUND_DESERT")]
MUSIC_WORDS = [(r"(boss|bowser)\w*.?musi[ck]|music (of|from) bowser", "SEQ_LEVEL_BOSS_KOOPA_FINAL"),
               (r"schnee.?musik|snow music|winter.?musi[ck]", "SEQ_LEVEL_SNOW"),
               (r"wasser.?musik|water music", "SEQ_LEVEL_WATER"),
               (r"rutschen.?musik|slide music", "SEQ_LEVEL_SLIDE"),
               (r"wuesten.?musik|desert music", "SEQ_LEVEL_HOT"),
               (r"koopa.?road|burg.?musik|castle music", "SEQ_LEVEL_KOOPA_ROAD"),
               (r"(bob.?omb|wiesen|grass).?musi[ck]", "SEQ_LEVEL_GRASS")]
REFERENCES = [(r"sky ?keep", "skykeep")]
THINGS = [
    (r"waende hoeher als ein sprung|walls? higher than a jump|hohe waende|tall walls|"
     r"mauern hoeher als ein sprung", "tall_walls", None),
    (r"\blava\b|\blavasee\b|\blava lakes?\b", "lava", None),
    (r"\bring\b|\bkampfring\b|\barena ring\b", None, "ring"),
    (r"\bkreuzung\b|\bcrossing\b|\bintersection\b", None, "crossing"),
    (r"world.?spawn\w*|welt.?spawn\w*|\beingang\w*|\bankunft\b|\beinstieg\b|\bentry\b|"
     r"\bentrance\b|\barrival\b|startpunkt der lobby", None, "world_spawn"),
    (r"\bspawn(s|punkte?|plaetze|points?)?\b|\bstartplaetze\b|\bwiedereinstieg\w*|"
     r"\brespawns?\b", None, "spawns"),
    (r"\bt(ue|u)rm(e|en|chen)?\b|\btowers?\b|\bwachturm\w*", "tower", "tower"),
    (r"\bbr(ue|u)cken?\b|\bbridges?\b|\bsteg\w*", "bridge", "bridge"),
    (r"\bkrone\b|\bcrown\b|erhoehte mitte|raised (middle|centre|center)|mitte (ist )?erhoeht",
     "crown", "crown"),
    (r"\bhuegellandschaft\w*|\blandschaft\w*|\bterrain\b|\bhuegelig\w*|\bhilly\b|"
     r"\bnatuerliche\w* (gelaende|boden|untergrund)|\bnatural (ground|terrain)\b|"
     r"\bgelaende\b|\b(rolling )?hills\b", "terrain", None),
    (r"\bfl(ue|u)ss(e|lauf)?\b|\brivers?\b|\bbach\b|\bstreams?\b", "river", None),
    (r"\bstrassen?\b|\broads?\b|\bpfade\b|\bfeldwege?\b", "roads", None),
    (r"\bhuegel\w*|\bhill\b|\banhoehe\b|\berhebung\b", None, "hill"),
    (r"\bgrube\w*|\bpit\b|\bgraben\b|\bsenke\b|\bkrater\b|\bkuhle\b|\bmulde\b", "pit", "pit"),
    (r"\bplatz\b|\bplaza\b|\bpavillon\b|\bbandstand\b|\bmarktplatz\b|\bcourtyard\b|"
     r"\binnenhof\b|\bburghof\b", "plaza", "plaza"),
    (r"\bperch\w*|\baussichtspunkt\w*|\bausguck\w*|\bkanzel\w*|\bhochsitz\w*|\bvantage\b",
     "perches", "perch"),
    (r"\brampen?\b|\bramps?\b|\bschraege\w*|\bslopes?\b", "ramps", "ramp"),
    (r"\beck(rampen|stufen|treppen)\b|\bcorner (ramps|stairs|slopes|steps)\b|"
     r"\bwendeltreppe\w*|\bspiral stair\w*|\bum die ecke\b", "corners", None),
    (r"\btreppe(n)?\b|\bstairs?\b|\bstufen\b|\bstaircases?\b", "stairs", "stairs"),
    (r"\bzaeune?n?\b|\bzaun\b|\bfences?\b|\bumzaeunung\w*|\bpalisade\w*", "fences", None),
    (r"\bplatten\b|\bslabs?\b|\bsimse?\b|\bledges?\b|\bvorspruenge?\b", "slabs", None),
    (r"\bdiagonal\w*|\bschraege waende\b|\bachteck\w*|\boctagon\w*|\bschraeg\w* ecken\b",
     "diagonals", None),
    (r"\bkurven?\b|\bcurves?\b|\bkurvig\w*|\bcurvy\b|\bbends?\b|\bgeschwungen\w*|"
     r"\bsteilkurven?\b|\bbanked\b|\bgebogen\w*|\brunde ecken\b", "curves", None),
    (r"\bbauten\b|\bgebaeude\w*|\bhaeuser\w*|\bhaus\b|\bhuetten?\b|\bbuildings?\b|"
     r"\bhouses?\b|\bhuts?\b|\bbauwerke?\b|\bdorf\b|\bdoerfer\w*|\bvillages?\b|"
     r"\bstaedtchen\b|\btowns?\b",
     "buildings", None),
    (r"\bsaeulen?\b|\bcolumns?\b|\bpillars?\b|\bpfeiler\b", "columns", "pillar"),
    (r"\beckbasen\b|\bcorner bases\b|\beckfestung\w*", "corner_bases", None),
    (r"\bboegen\b|\bbogen\b|\barch(es)?\b|\btorboegen\b", "arches", "arch"),
    (r"\bkulissen?\b|\bhintergrundkulisse\w*|\bbackdrops?\b|\bscenery\b", "backdrop", None),
    (r"\b100[- ]?(muenzen|münzen|coins?)[- ]?stern\w*|\b100[- ]coin stars?\b|"
     r"\bhundred[- ]coin stars?\b", "coin_star", None),
    (r"\bspitzdaech\w*|\bspitzdach\b|\bturmdaech\w*|\bturmdach\b|\bpointed roofs?\b|"
     r"\btower roofs?\b|\broofs on (the )?towers\b", "roofs", None),
    (r"\bfarbverl(ae|a)uf\w*|\bgradient walls?\b|\bgradients?\b|\bsockel\w*|"
     r"\bbase courses?\b", "gradients", None),
    (r"\bframing\b|\bframed\b|\beingerahmt\w*", "framing", None),
    (r"\bgrasdecke\w*|\bgrass(y)? tops?\b|\bsnow(y)? tops?\b|\bauto[- ]?tops?\b",
     "tops", None),
    (r"\bmauern?\b|\bwaende\b|\bwand\b|\bwalls?\b", "walls", "wall"),
    (r"\btore?\b|\bgates?\b|\btorbogen\b", "gate", "gate"),
    (r"\btunnels?\b|\bunterfuehrung\w*|\bdurchgaenge?\b|\bpassages?\b", "tunnel", "tunnel"),
    (r"\bberg(e|en|ig\w*|isch\w*|land\w*|landschaft\w*|kette\w*|massiv\w*)?\b|"
     r"\bgebirg\w*|\bmountains\b|\bmountainous\b|\bmountain range\w*|\bhochland\w*|"
     r"\bhighlands?\b",
     "mountains", None),
    (r"\btal\b|\btals\b|\btaeler\w*|\btaelern\b|\btalsohle\w*|"
     r"\bvalleys?\b", "valley", None),
    (r"\bmesas?\b|\btafelberg\w*|\bbuttes?\b|\btable mountains?\b", "mesa", None),
    (r"\bfelsbogen\w*|\bfelsbr(ue|u)cke\w*|\bfelstor\w*|\bnatural arch\w*|\brock arch\w*|"
     r"\bsteinbogen\w*", "natural_arch", None),
    (r"\briesenpilz\w*|\briesige\w* pilze\b|\bgro(ss|ß)e\w* pilze\b|\bpilzwald\w*|"
     r"\bpilzplattform\w*|\bgiant mushrooms?\b|\bbig mushrooms?\b|\bhuge mushrooms?\b|"
     r"\bmushroom (forest|platforms?)\b", "giant_mushrooms", None),
    (r"\brutsch(e|en|bahn\w*)\b|\bslides?\b|\bwater ?slides?\b|\bwasserrutsche\w*|"
     r"\bpenguin slides?\b|\bpinguinrutsche\w*", "slide", None),
    (r"\bschwebende\w* inseln?\b|\bfliegende\w* inseln?\b|\bhimmelsinseln?\b|"
     r"\bfloating islands?\b|\bflying islands?\b|\bsky islands?\b|\bisland in the sky\b|"
     r"\binsel(n)? (im|in den) himmel\b", "floating_islands", None),
    (r"\bspiral(e)? ?(path|road|way|weg|strasse)\w*|\bwendelweg\w*|\bserpentine\w*|"
     r"\bwinding path\w* (up|to the top)\b|\bpath (that )?(spirals|winds) up\b",
     "spiral_path", None),
    (r"\baussichtspunkt\w*|\baussichtsplattform\w*|\blookouts?\b|\bviewpoints?\b|"
     r"\blook ?out (tower|point)s?\b", "lookout", None),
    (r"\bgeheim\w* (nische|ecke|versteck|raum)\w*|\bversteck(e|en)?\b|"
     r"\bsecret (alcove|nook|hideout|spot|room|corner|place)s?\b|\bhidey ?holes?\b|"
     r"\bhideouts?\b|\bgeheimnis\w*|\bsecrets\b|\bhidden (spots|places|corners)\b",
     "secret_alcove", None),
    (r"\bwasserf(ae|a)ll\w*|\bwaterfalls?\b", "waterfall", None),
    (r"\bd(ue|u)nen?\b|\bdunes?\b|\bsandd(ue|u)nen?\b", "dunes", None),
    (r"\bgletscher\w*|\bglaciers?\b|\beisfeld\w*|\bice ?fields?\b", "glacier", None),
    (r"\bsanfte\w* h(ue|u)gel\w*|\brolling hills\b|\bwellige\w* h(ue|u)gel\w*",
     "rolling_hills", None),
    (r"\bh(oe|o)hle\w*|\bh(oe|o)hlensystem\w*|\bcaves?\b|\bcavern\w*|\bgrotte\w*|"
     r"\bgrotto\w*|\bcave systems?\b|\bkristallh(oe|o)hle\w*", "caves", None),
    (r"\bleuchtend\w* pilz\w*|\bleuchtpilz\w*|\bglowing mushrooms?\b|\bglow(ing)? ?shrooms?\b|"
     r"\bbioluminescen\w*|\bbiolumineszen\w*", "glowing_mushrooms", None),
    (r"\bkristall\w*|\bcrystals?\b|\bcrystal caves?\b", "crystals", None),
    (r"\bbas(en|is)\b|\bbases?\b|\blager\b|\bhauptquartier\w*|\bhq\b|\bbastion\w*",
     None, "base"),
    (r"\bfahnen?\b", None, "flag"),
    (r"\bkontrollpunkte?n?\b|\bpunkten?\b|\bcapture points?\b|\bpoints\b|\bzonen\b",
     None, "point"),
    (r"bewegliche plattformen|moving platforms?", "moving_platforms", None),
    (r"\bplattform(en)?\b|\bplatforms?\b", None, "platform"),
    (r"\binseln?\b|\bislands?\b", "islands", "island"),
    (r"\bvulkan\w*|\bvolcano(es)?\b|\bvolcanic cone\b|\bfeuerberg\w*", "volcano", "volcano"),
    (r"\bsprungfeder\w*|\bjump ?pads?\b|\bsprungpads?\b|\bschanze\w*", "jump_pads", None),
    (r"\bluecken\b|\babgruende\b|\bgaps?\b|\bspalten\b|\bvoid gaps?\b", "void_gaps", None),
    (r"lange sicht(linien|achsen)?|long sight ?lines?|\bsniper\w*|weite sicht",
     "long_lines", None),
    (r"\btrickabkuerzung\w*", "move_shortcuts", None),
    (r"\bflanken\b|\bflank(s|ing)?\b", "flanks", None),
    (r"\bwegwahl\b", "routes", None),
    (r"\bspawncamping\b", "spawn_camping", None),
    (r"\bspawnschutz\b", "spawn_safety", None),
    (r"\bcomebacks?\b", "comeback", None),
    (r"\brundwege?\b|\bloops?\b|\brundgaenge?\b|\bkreislauf\w*", "loops", None),
    (r"\blanes?\b|\bwege\b|\bbahnen\b|\brouten\b|\bzugaenge?\b|\bzugang\b|\bpaths?\b|"
     r"\broutes?\b|\bapproaches\b", "lanes", None),
    (r"\bgelaender\w*|\brailings?\b|\brails?\b|\bbruestung\w*", "rails", None),
    (r"\bwasser\b|\bwater\b|\bseen?\b|\blakes?\b|\bpools?\b", "water", None),
    (r"\bnischen\b|\bnooks?\b|\bverstecke\b|\bhiding (spots|places)\b|\becken und winkel\b",
     "nooks", None),
    (r"zweite(n)? (etage|ebene|stockwerk)|second (floor|storey|level)|obergeschoss|"
     r"upper floor", "second_floor", None),
    (r"\babkuerzung\w*|\bshortcuts?\b", "shortcut", "shortcut"),
    (r"\bspruenge?\b|\bsprung\b|\bjumps?\b", "jumps", "jump"),
    (r"form einer acht|\bachter\b|\b8er\b|figure.?(8|eight)", "figure_eight", None),
    (r"\bstart(linie)?\b|\bstart line\b", None, "start_line"),
    (r"\bziel(linie)?\b|\bfinish( line)?\b|\bgoal\b", None, "finish"),
]
OBJECTS = [
    (r"\bblaue muenzen?\b|\bblue coins?\b", "bluecoin"),
    (r"\brote muenzen?\b|\bred coins?\b", "redcoin"),
    (r"\bmuenzen?\b|\bcoins?\b|\btaler\b|\bgeld\b", "coin"),
    (r"\bgumbas?\b|\bgoombas?\b|\bgumbaz?\b", "goomba"),
    (r"\bbob.?ombs?\b|\bbomben\b|\bbombs\b", "bobomb"),
    (r"\bkoopas?\b|\bschildkroeten?\b", "koopa"),
    (r"\bitem.?(box|boxen|boxes|bloecke|blocks?)\b|\bfragezeichen.?(bloecke|box\w*)\b|"
     r"\bausrufezeichen.?(bloecke|box\w*)\b|\b(!|exclamation).?(blocks?|boxes)\b", "exclam"),
    (r"\bmetall.?(box|boxen|bloecke)\b|\bmetal (box|boxes|blocks?)\b", "metalbox"),
    (r"\bkisten\b|\bkiste\b|\bcrates?\b|\bholzkisten\b|\bwooden boxes\b", "box"),
    (r"\btrampolin(e)?\b|\btrampolines?\b|\bsprungfedern\b|\bsprings?\b", "trampoline"),
    (r"\bherz(en)?\b|\bhearts?\b", "heart"),
    (r"\b1.?ups?\b|\bextraleben\b|(?<!riesige )(?<!grosse )(?<!große )(?<!riesen)"
     r"(?<!leuchtende )(?<!leuchtenden )\bpilze\b|"
     r"(?<!giant )(?<!big )(?<!huge )(?<!glowing )\bmushrooms?\b(?! (forest|platforms?))", "1up"),
    (r"\bthwomps?\b|\bsteingesichter\b", "thwomp"),
    (r"\bwhomps?\b", "whomp"),
    (r"\bkettenhunde?\b|\bchain.?chomps?\b|\bchomps?\b", "chainchomp"),
    (r"\bpiranha.?pflanzen?\b|\bpiranha plants?\b|\bpiranhas?\b", "piranha"),
    (r"\bamps?\b|\belektro.?kugeln\b", "amp"),
    (r"\bbuu.?huus?\b|\bboos?\b|\bgeister\b|\bghosts?\b", "boo"),
    (r"\bkugelwillis?\b|\bbullet bills?\b", "bulletbill"),
    (r"\bfly.?guys?\b|\bflugschergen\b", "flyguy"),
    (r"\blakitus?\b", "lakitu"),
    (r"\bpanzer\b|\bshells?\b", "shell"),
    (r"\baufzu(e)?ge?\b|\blifts?\b|\belevators?\b|\bfahrstuehle?\b|\bfahrstuhl\b", "elevator"),
    (r"\bbaeume?\b|\btrees?\b", "tree"),
    (r"\bkanonen?\b|\bcannons?\b", "cannon"),
    (r"\bfeuerstangen?\b|\bfire.?bars?\b|\bfirebars?\b", "firebar"),
    (r"\bflammenwerfer\b|\bflame.?jets?\b|\bflammen\b", "flamejet"),
    (r"\bstacheis\b|\bspin(y|ies)\b", "spiny"),
    (r"\bbullys?\b|\brempler\b", "bully"),
    (r"\bpinguine?\b|\bpenguins?\b", "penguin"),
    (r"\byoshis?\b", "yoshi"),
    (r"\bmips\b|\bhasen\b|\brabbits?\b", "mips"),
    (r"\bfluegelkappen?\b|\bwing.?caps?\b", "wingcap"),
    (r"\bbuehnen?\b|\bstages?\b", "stage"),
    (r"\bwippen?\b|\bseesaws?\b", "seesaw"),
    (r"\bfeinde\b|\benemies\b|\bgegner\b|\bmonster\b", "goomba"),
]
FORGE_KEY_SKIP = {"fire", "pillar", "pole", "chair", "piano", "checkers", "coins", "stage",
                  "box", "bub", "clam", "raft", "goombas", "fireball", "blizzard", "tree",
                  "shell", "bowling", "smallbox", "woodpost", "bowser", "finalbowser"}
_FORGE_DONE = []
def _forge_objects():
    if _FORGE_DONE:
        return
    _FORGE_DONE.append(True)
    try:
        from . import kit
        keys = kit.forge_keys() or []
    except Exception:
        keys = []
    have = set(k for _, k in OBJECTS)
    for k in keys:
        if k not in have and k not in FORGE_KEY_SKIP and k.isalpha() and len(k) >= 4:
            OBJECTS.append((r"\b%ss?\b" % k, k))
COMPASS_WORDS = [
    (r"\bnord.?west\w*|\bnorth.?west\w*|\bnw\b|oben links|top.?left|upper left", "nw"),
    (r"\bnord.?o?e?st\w*|\bnorth.?east\w*|oben rechts|top.?right|upper right", "ne"),
    (r"\bsued.?west\w*|\bsouth.?west\w*|\bsw\b|unten links|bottom.?left|lower left", "sw"),
    (r"\bsued.?o?e?st\w*|\bsouth.?east\w*|\bse\b|unten rechts|bottom.?right|lower right", "se"),
    (r"\bnord\w*|\bnorth\w*|\bam oberen rand\b|\btop edge\b", "n"),
    (r"\bsued\w*|\bsouth\w*|\bam unteren rand\b|\bbottom edge\b", "s"),
    (r"\bost\b|\bosten\b|\boestlich\w*|\beast\w*|\brechts\b|\bon the right\b", "e"),
    (r"\bwest\w*|\bwestlich\w*|\blinks\b|\bon the left\b", "w"),
]
CENTRE = (r"in der mitte|\bmittig\b|\bzentral\b|im zentrum|in the (middle|centre|center)|"
          r"\bcentered\b|\bcentred\b|\bmittendrin\b|\bin die mitte\b|\bmitte\b|\bmiddle\b|"
          r"\bcent(re|er)\b|\bzentrum\b")
EDGE = (r"am rand\w*|\bam aussenrand\b|\bringsum\b|\brundherum\b|\baussen\b|an den raendern|"
        r"at the edges?|along the edges?|around the edges?|on the outside|\bperimeter\b|"
        r"\bam rande\b|\bedge\b|\brand\b")
CORNERS = r"in den ecken|an den ecken|in (all |the )?(four )?corners|\becken\b|\bcorners\b"
CLOCK = r"(?:auf|um|at)?\s*(\d{1,2})\s*(?:uhr|o.?clock)\b"
RELATIONS = [
    (r"\bzwischen\b|\bbetween\b", "between"),
    (r"\bneben\b|\bnext to\b|\bbeside\b|\bbeneben\b|\bdaneben\b|\bnahe bei\b|\bclose to\b",
     "next_to"),
    (r"\bueber\b|\babove\b|\boberhalb\b|\bover\b", "above"),
    (r"\bauf dem\b|\bauf der\b|\bauf den\b|\bon top of\b|\bon the\b|\bon\b|\bdrauf\b", "on"),
    (r"\bum\b.*\bherum\b|\baround\b|\brings um\b|\bumgeben\b|\bsurrounding\b", "around"),
    (r"\bgegenueber\b|\bopposite\b|\bfacing\b", "opposite"),
    (r"\bvor dem\b|\bvor der\b|\bin front of\b", "in_front_of"),
    (r"\bhinter\b|\bbehind\b", "behind"),
    (r"\bentlang\b|\balong\b|\blaengs\b", "along"),
    (r"\bweit weg von\b|\bfar from\b|\bfern\b", "far"),
    (r"\bnahe\b|\bnear\b|\bin der naehe\b", "near"),
]
NEGATION = (r"\b(ohne|keine?n?|keinerlei|kein|nicht|no|without|not|never|nie|avoid|vermeide\w*|"
            r"nothing|nichts|"
            r"bloss keine?n?|bitte keine?n?|nix|weg mit)\b")
ONLY = r"\b(nur|only|ausschliesslich|just)\b"
SIZE_ADJ = [(r"\b(gigantisch\w*|gigantic)\b", "gigantic"),
            (r"\b(riesig\w*|huge|massiv\w*)\b", "huge"),
            (r"\b(gross\w*|big|large|breit\w*|wide)\b", "large"),
            (r"\b(klein\w*|small|little|schmal\w*|narrow)\b", "small"),
            (r"\b(winzig\w*|tiny)\b", "tiny")]
HEIGHT = [(r"\bauf (\d{3,4})\b|\bat (?:height )?(\d{3,4})\b|\b(\d{3,4}) hoch\b|\b(\d{3,4}) high\b",
           None), (r"\bhoch oben\b|\bhigh up\b|\bganz oben\b|\bup high\b", 600),
          (r"\bebenerdig\b|\bground level\b|\bunten\b|\bat ground\b", 0),
          (r"\berhoeht\b|\braised\b|\belevated\b|\bhoeher gelegen\b", 400)]
IN_ROUNDS = (r"auch (in den|im|waehrend der|fuer die) (runden?|spiel\w*|modus|game mode)|"
             r"also (in|during) (the )?(rounds?|game|mode)|in rounds too|for the mode too|"
             r"im modus|fuer den modus")
STOP = set("""
mein meine meinem meinen meiner my zum zur fuers bitte please eine ein einen einem einer eines a an the der die das den dem des und and
mit with aber but auch also so sehr very mal map karte level arena maps karten mach
mache machen make bau baue bauen build ich i will want moechte haette gern gerne would
like gib give mir me uns us es it ist is sind are sein be soll should sollen hat has
haben have von of fuer for in im am an auf on at zu to bei by aus out oder or wie like
as als dass that was what wo where da there hier here etwas something bisschen bit
viel much richtig really total ganz quite ziemlich pretty some einige noch still more
mehr weniger less dann then statt instead nur only just schon already bloss halt eben
mach's machs gerne ok okay hey hallo hi neue new neuer nice schoene schoen cool geil
super gut good tolle toll great awesome je jeweils each pro per alle all every jede
jeden jeder sowie plus dazu dabei ungefaehr about circa ca around etwa roughly
here there hier dort ne nen theme thema stil style look motto setting rest frei free slider least connected by sollte waere wuerde could can kann koennte maybe vielleicht wir we sie they man one
dort darin drin inside innen thing dinge things sachen place ort platz bereich area
region seite side seiten sides spot spots stelle stellen herum drum
""".split())
class Reading:
    def __init__(self, text):
        self.text = text
        self.raw = {"wish": text}
        self.understood = []
        self.assumed = []
        self.not_understood = []
        self.consumed = []
        self.anchor_ids = {}
        self.last_anchor = None
        self.pending = []
        self.heard_in = {}
        self.free = []
        self.soft = []
        self.heard = []
        self.confidence = 1.0
        self.questions = []
        self.taught = []
    def take(self, m, offset=0):
        if m is not None:
            self.consumed.append((offset + m.start(), offset + m.end()))
    def said(self, line):
        if line not in self.understood:
            self.understood.append(line)
    def guess(self, line):
        if line not in self.assumed:
            self.assumed.append(line)
def _first(table, text, reading=None):
    for pat, val in table:
        for m in re.finditer(pat, text):
            if reading is not None and _negated(text, m.start()):
                reading.take(m)
                _take_negation(reading, text, m.start())
                reading.said("not %s" % m.group(0))
                continue
            if reading is not None:
                for mm in re.finditer(pat, text):
                    reading.take(mm)
            return val, m
    return None, None
def _take_negation(r, text, at, window=28, offset=0):
    c = negation.cue(text, at)
    if c is not None:
        r.consumed.append((offset + c[0], offset + c[1]))
        return
    lo = max(0, at - window)
    m = None
    for m in re.finditer(NEGATION, text[lo:at]):
        pass
    if m is not None:
        r.consumed.append((offset + lo + m.start(), offset + lo + m.end()))
PREFAB_WORD = (r"(?:prefab|vorlage|bauplan|blueprint|haus|house|turm|tower|mauer|wall|tor|gate|"
               r"bruecke|bridge|stand|stall|gebaeude|building)\w*")
def _prefab_words(r, raw, low):
    try:
        from . import prefablib
        lib = prefablib.names()
    except Exception:
        return
    got = list(raw.get("prefabs") or [])
    for key, name, _ in lib:
        for nm in sorted({fold(name), key}, key=len, reverse=True):
            if len(nm) < 4:
                continue
            m = re.search(r"(?<![a-z0-9])%s(?![a-z0-9])" % re.escape(nm), low)
            if m:
                if key not in got:
                    got.append(key)
                    r.said("prefab %s" % name)
                for mm in re.finditer(r"(?<![a-z0-9])%s(?![a-z0-9])" % re.escape(nm), low):
                    r.take(mm)
                break
    for m in re.finditer(PREFAB_WORD + r"\s*[\"'\u201e\u201c\u2018\u201a]([^\"'\u201c\u201d\u2018\u2019]{2,40})"
                         r"[\"'\u201c\u201d\u2018\u2019]", low):
        want = m.group(1).strip()
        if prefablib.find(want) is None:
            r.not_understood.append("prefab '%s' (the library has %s)" % (
                want, ", ".join(n for _, n, _ in lib) or "none"))
        r.take(m)
    if got:
        raw["prefabs"] = got
def _preset_words(r, raw, low):
    try:
        from . import presets
    except Exception:
        return
    hit = presets.find_in(low)
    while hit is not None and _negated(low, hit[1].start()):
        a, b = hit[1].span()
        low = low[:a] + " " * (b - a) + low[b:]
        hit = presets.find_in(low)
    if hit is None:
        return
    key, m = hit
    r.soft.append((m.start(), m.end()))
    if raw.get("preset") is None:
        raw["preset"] = key
        r.said("preset %s" % presets.get(key)["name"])
LEXICON = True
def _lexicon_word(w):
    from . import lexicon
    lexicon.index()
    return (w in lexicon.index() and w not in lexicon.ASCII) or w in lexicon.data()["fillers"]
LANDSCAPE_NOUNS = (r"\blandschaft\w*|\bnatur\w*|\bwelt\b|\blandscape\w*|\bnature\b|"
                   r"\bscenery\b|\bwildnis\b|\bwilderness\b|\bgegend\b|\bcountryside\b")
LANDSCAPE_WANTS = {"terrain", "river", "water", "trees", "tunnel", "caves", "valley",
                   "mesa", "natural_arch", "waterfall", "dunes", "glacier", "rolling_hills",
                   "mountains", "roads", "water_levels", "volcano", "lava", "islands",
                   "terraces", "weirs", "landmarks", "lighthouse", "obelisk", "watchtower",
                   "temple",
                   "windmill", "belltower", "keep", "ruin", "statue", "pyramid", "spirerock",
                   "fountain", "shrine", "greattree", "marketsquare", "fortress", "domedhall",
                   "well", "shipwreck", "courtyard",
                   "slide", "floating_islands", "spiral_path", "lookout", "secret_alcove",
                   "giant_mushrooms"}
LANDSCAPE_STRONG = {"terrain", "river", "caves", "valley", "mountains", "volcano", "terraces",
                    "weirs"}
FIGHT_WORDS = r"shooter|deathmatch|ballern|schiess|\bffa\b|kampf|gefecht|shoot|\bpvp\b"
def _landscape_family(r, base):
    raw = r.raw
    want0 = set((raw.get("features") or {}).get("want") or [])
    if "volcano" in want0 and not raw.get("theme") and not (base or {}).get("theme"):
        raw["theme"] = "lava"
        r.guess("a volcano: the lava theme")
    if raw.get("family") or raw.get("modes") or (base or {}).get("family"):
        return
    if any(a.get("what") in ("base", "spawns", "flag", "point") for a in raw.get("anchors") or []):
        return
    low = fold(r.text or "")
    if re.search(FIGHT_WORDS, low):
        return
    want = set((raw.get("features") or {}).get("want") or [])
    stars = any(q.get("kind") == "stars" for q in raw.get("requests") or [])
    noun = re.search(LANDSCAPE_NOUNS, low)
    things = bool(want & LANDSCAPE_STRONG) and want <= LANDSCAPE_WANTS
    placed = any(q.get("kind") == "place" for q in raw.get("requests") or [])
    if not (noun or things or stars or placed):
        return
    raw["family"] = "explore"
    why = ("a landscape with no game named" if (noun or things) else
           "a thing placed by a landmark with no game named" if placed else
           "bonus stars with no game named")
    if not raw.get("theme"):
        raw["theme"] = "garden"
        r.guess("%s reads as a world to explore (family explore, a natural garden theme)"
                % why)
    else:
        r.guess("%s reads as a world to explore (family explore)" % why)
COURSE_LENGTH_WORDS = [(r"\bmarathon\w*", "marathon"),
                       (r"\bkurz(e|er|en|es)?\b|\bshort\b", "short"),
                       (r"\blang(e|er|en|es)?\b(?!\s+(sprung|spruen|weit))|"
                        r"\blong\b(?!\s+jump)", "long")]
def _course_length(r, raw, low, base=None):
    family = raw.get("family") or (base or {}).get("family")
    if family != "course" or (raw.get("course") or {}).get("length"):
        return
    for pat, val in COURSE_LENGTH_WORDS:
        for m in re.finditer(pat, low):
            if any(a <= m.start() < b for a, b in r.consumed):
                continue
            if _negated(low, m.start()):
                r.take(m)
                _take_negation(r, low, m.start())
                r.said("not a %s course" % val)
                continue
            course = dict(raw.get("course") or {})
            course["length"] = val
            raw["course"] = course
            r.take(m)
            r.said("course length %s" % val)
            return
def understand(text, base=None):
    from . import modes as modesmod
    text, gone = modesmod.blank_old_titles(text)
    from . import wishsense
    said = text
    text, oos = wishsense.blank_out_of_scope(text)
    r = _understand_all(text, base)
    if oos and r.raw.get("wish") == text:
        r.raw["wish"] = said
    if gone:
        r.not_understood = list(r.not_understood) + gone
    _place_sentences(r, text)
    _crazy(r, text)
    seen = text + " . " + " ".join(_fixed_words(r)) if _fixed_words(r) else text
    _set_pieces(r, seen, base)
    _landscape_family(r, base)
    _set_pieces(r, seen, base, late=True)
    _landmark_kinds(r, seen)
    from . import vocab
    vocab.apply(r, seen)
    _set_pieces_tidy(r)
    _isles_in_a_world(r, text)
    wishsense.apply(r, text, said=said)
    _tidy_not_understood(r)
    r.not_understood = [n for n in r.not_understood
                        if not (re.fullmatch(r"[a-z]+", n) and _subsumed(r, n))]
    if r.raw.get("features") == {"want": [], "avoid": []}:
        r.raw.pop("features")
    if oos and getattr(r, "text", None) == text:
        r.text = said
    return r
def _fixed_words(r):
    out = []
    for line in list(r.assumed) + list(getattr(r, "heard", []) or []):
        m = re.match(r"typo: '([a-z ]+)' read as '([a-z ]+)'", line) or re.match(
            r"'([a-z ]+)' read as '([a-z]+)'$", line)
        if m:
            out.append(m.group(2))
            continue
        m = re.match(r"'([a-z]+)' = ([a-z +]+)$", line)
        if m:
            out += [p.strip() for p in m.group(2).split("+")]
    return out
def _tidy_not_understood(r):
    from .lexicon import NATIVE_EXTRA
    out = []
    for g in r.not_understood:
        if re.fullmatch(r"[a-z]+( [a-z]+)*", g or ""):
            words = [w for w in g.split() if w not in NATIVE_EXTRA]
            if not words:
                continue
            g = " ".join(words)
        out.append(g)
    r.not_understood = out
PLACE_THINGS = (
    ("cave", "caves", r"caves?|grott(o|e|en)|hoehlen?"),
    ("lake", "water", r"lakes?|ponds?|seen?|teich(e|en)?|weiher"),
    ("tower", "tower", r"(?:watch ?)?towers?|(?:wach)?tuerme?n?|(?:wach)?turm"),
    ("castle", None, r"castles?|keeps?|fortress(es)?|burg(en)?|schloss|schloesser|festung(en)?"),
    ("house", "buildings", r"houses?|huts?|cottages?|haus|haeuser|huetten?"),
    ("house", "temple", r"temples?|tempel"),
)
PLACE_LANDMARKS = (
    ("waterfall", "waterfall", r"waterfalls?|wasserf(ae|a)ll(e|en)?"),
    ("castle", None, r"castles?|keeps?|fortress(es)?|burg|schloss|festung"),
    ("tower", "tower", r"towers?|tuerme?n?|turm|lighthouse|leuchtturm"),
    ("lake", "water", r"lakes?|ponds?|see|teich|weiher"),
    ("bridge", "bridge", r"bridges?|bruecke"),
    ("cave", "caves", r"caves?|hoehle|grotte|grotto"),
    ("mountain", "mountains", r"mountains?|hills?|berg|huegel|gebirge"),
    ("house", None, r"houses?|haus|village|dorf"),
)
PLACE_RELATIONS = (
    ("behind", r"behind|hinter(m|n)?"),
    ("in_front_of", r"in front of|vor"),
    ("next_to", r"next to|beside|neben|bei|by"),
    ("on", r"on top of|on|auf(m)?|oben auf"),
    ("under", r"under(neath)?|beneath|below|unter(m|halb)?"),
    ("inside", r"inside|within|innerhalb|im inneren|in|im"),
)
PLACE_ART = (r"(?:the|a|an|der|die|das|dem|den|des|einem|einer|einen|ein|eine|dieser|diesem|"
             r"dieses)")
HIDDEN = r"hidden|secret|versteckt\w*|geheim\w*|verborgen\w*"
def _place_sentences(r, text):
    low = fold(text)
    raw = r.raw
    reqs = raw.get("requests") or []
    from . import placefeat
    have = set((placefeat.norm_what(q.get("what")), placefeat.norm_rel(q.get("relation")),
                placefeat.norm_of(q.get("of"))) for q in reqs if q.get("kind") == "place")
    for name, feat, pat in PLACE_THINGS:
        for rel, rpat in PLACE_RELATIONS:
            for lname, lfeat, lpat in PLACE_LANDMARKS:
                if lname == name:
                    continue
                rx = (r"\b(?:(?P<hid>%s)\s+)?(?:%s)\s+(?:(?:is|liegt|steht|sits|stands)\s+)?"
                      r"(?:%s)\s+(?:%s\s+)?(?:%s)\b" % (HIDDEN, pat, rpat, PLACE_ART, lpat))
                m = re.search(rx, low)
                if not m or (name, rel, lname) in have:
                    continue
                if any(placefeat.norm_what(a.get("what")) == name
                       and placefeat.norm_rel((a.get("where") or {}).get("relation")) == rel
                       for a in raw.get("anchors") or []):
                    continue
                q = {"kind": "place", "what": name, "relation": rel, "of": lname}
                if m.group("hid"):
                    q["hidden"] = True
                have.add((name, rel, lname))
                raw.setdefault("requests", []).append(q)
                feats = raw.setdefault("features", {"want": [], "avoid": []})
                for f in (feat, lfeat):
                    if f and f not in feats["want"] and f not in feats["avoid"]:
                        feats["want"].append(f)
                r.said("%s%s %s the %s (placed on the map by the %s)" % (
                    "hidden " if q.get("hidden") else "", name, rel.replace("_", " "), lname,
                    lname if lname != "castle" else "castle, or the theme's main building"))
                _explained(r, m.group(0))
    _place_pronouns(r, low, have)
PLACE_BACK = (
    ("behind", r"behind (?:it|them)|dahinter|hinter (?:ihm|ihr|ihnen)"),
    ("in_front_of", r"in front of (?:it|them)|davor|vor (?:ihm|ihr|ihnen)"),
    ("next_to", r"next to (?:it|them)|beside (?:it|them)|daneben|neben (?:ihm|ihr|ihnen)"),
    ("on", r"on top of (?:it|them)|on (?:it|them)|darauf|obendrauf|drauf"),
    ("under", r"under(?:neath)? (?:it|them)|below (?:it|them)|darunter|drunter"),
    ("inside", r"inside (?:it|them)|in (?:it|them)|darin|drin(?:nen)?"),
)
def _place_pronouns(r, low, have):
    raw = r.raw
    for name, feat, pat in PLACE_THINGS:
        for rel, rpat in PLACE_BACK:
            rx = (r"\b(?:(?P<hid>%s)\s+)?(?:%s)\s+(?:(?:is|liegt|steht|sits|stands)\s+)?(?:%s)\b"
                  % (HIDDEN, pat, rpat))
            for m in re.finditer(rx, low):
                best = None
                for lname, lfeat, lpat in PLACE_LANDMARKS:
                    if lname == name:
                        continue
                    for lm in re.finditer(r"\b(?:%s)\b" % lpat, low[:m.start()]):
                        if best is None or lm.start() > best[0]:
                            best = (lm.start(), lname, lfeat)
                if best is None:
                    continue
                _, lname, lfeat = best
                if (name, rel, lname) in have:
                    _explained(r, m.group(0))
                    continue
                q = {"kind": "place", "what": name, "relation": rel, "of": lname}
                if m.group("hid"):
                    q["hidden"] = True
                have.add((name, rel, lname))
                raw.setdefault("requests", []).append(q)
                feats = raw.setdefault("features", {"want": [], "avoid": []})
                for f in (feat, lfeat):
                    if f and f not in feats["want"] and f not in feats["avoid"]:
                        feats["want"].append(f)
                r.said("%s%s %s the %s (placed on the map by the %s)" % (
                    "hidden " if q.get("hidden") else "", name, rel.replace("_", " "), lname,
                    lname))
                _explained(r, m.group(0))
def _explained(r, text):
    words = set(re.findall(r"[a-z0-9']+", fold(text)))
    keep = []
    for entry in r.not_understood:
        if not isinstance(entry, str):
            keep.append(entry)
            continue
        left = [w for w in entry.split(" ") if w not in words]
        if not left:
            r.heard_in.pop(entry, None)
            continue
        if len(left) != len(entry.split(" ")):
            new = " ".join(left)
            if entry in r.heard_in:
                r.heard_in[new] = r.heard_in.pop(entry)
            entry = new
        keep.append(entry)
    r.not_understood = keep
SET_PIECE_WORDS = (
    ("giant_mushrooms", r"\briesenpilz\w*|\briesige\w* pilze\w*|\bpilzwald\w*|"
                        r"\bgiant mushrooms?\b|\bbig mushrooms?\b|\bhuge mushrooms?\b|"
                        r"\bmushroom (forest|platforms?)\b"),
    ("lookout", r"\baussichtspunkt\w*|\baussichtsplattform\w*|\blookouts?\b|\bviewpoints?\b"),
    ("secret_alcove", r"\bgeheim\w* (nische|ecke|versteck|raum)\w*|\bversteck(e|en)?\b|"
                      r"\bsecret (alcove|nook|hideout|spot|room|corner|place)s?\b|"
                      r"\bhidey ?holes?\b|\bhideouts?\b|\bgeheimnis\w*|\bsecrets\b|"
                      r"\bhidden (spots|places|corners)\b"),
    ("floating_islands", r"\bschwebende\w* inseln?\b|\bfliegende\w* inseln?\b|"
                         r"\bhimmelsinseln?\b|\bfloating islands?\b|\bflying islands?\b|"
                         r"\bsky islands?\b"),
)
SET_PIECES_STRONG = ("slide", "floating_islands", "spiral_path", "lookout", "secret_alcove",
                     "giant_mushrooms")
WORLD_FAMILIES = ("explore", "hide")
SKY_WORLD = (r"\bsky\b|\bvoid\b|\bclouds?\b|\bwolken\w*|\bhimmel\w*|\bleere\b|"
             r"\bluft\b|ueber dem abgrund|\bsky ?world\b")
def _isles_in_a_world(r, text):
    raw = r.raw
    want = (raw.get("features") or {}).get("want") or []
    if "floating_islands" not in want or raw.get("family") not in WORLD_FAMILIES:
        return
    low = fold(text)
    pat = dict(SET_PIECE_WORDS)["floating_islands"]
    rest = re.sub(pat, " ", low)
    rest = re.sub(r"\b(schwebe|luft|wolken)inseln?\b|\bisland in the sky\b|"
                  r"\binsel(n)? (im|in den) himmel\b", " ", rest)
    if re.search(SKY_WORLD, rest):
        return
    undone = []
    for key, value in (("theme", "sky"), ("preset", "skyisland"), ("level", "empty2"),
                       ("edge", "void")):
        if raw.get(key) == value:
            raw.pop(key)
            undone.append(key)
    if not undone:
        return
    gone = ("theme sky", "preset Wolkeninsel", "level empty2", "edge void")
    r.understood = [u for u in r.understood if u not in gone]
    if not raw.get("theme"):
        raw["theme"] = "garden"
    r.said("floating islands: a set piece in the world's own sky (the world keeps its ground)")
def _set_pieces(r, text, base, late=False):
    raw = r.raw
    low = fold(text)
    family = raw.get("family") or (base or {}).get("family")
    if family not in (None,) + WORLD_FAMILIES or re.search(FIGHT_WORDS, low):
        return
    if raw.get("modes"):
        return
    feats = raw.setdefault("features", {"want": [], "avoid": []})
    feats.setdefault("want", [])
    feats.setdefault("avoid", [])
    want = feats["want"]
    for feat, pat in SET_PIECE_WORDS:
        m = re.search(pat, low)
        if not m or feat in want or feat in feats["avoid"]:
            continue
        if feat == "floating_islands" and not late:
            continue
        if late and family not in WORLD_FAMILIES:
            continue
        if _negated(low, m.start()):
            if feat not in feats["avoid"]:
                feats["avoid"].append(feat)
            continue
        want.append(feat)
        if feat == "lookout" and "perches" in want:
            want.remove("perches")
            r.understood = [u for u in r.understood if u != "want perches"]
        r.said("want %s (a set piece)" % feat.replace("_", " "))
    if not late and not family and set(want) & set(SET_PIECES_STRONG):
        raw["family"] = "explore"
        r.guess("%s with no game named: a world to explore (family explore)"
                % " and a ".join(sorted(f.replace("_", " ") for f in set(want)
                                        & set(SET_PIECES_STRONG))))
def _set_pieces_tidy(r):
    feats = r.raw.get("features") or {}
    want = feats.get("want") or []
    for piece, kit_word in (("spiral_path", "spiral"), ("lookout", "perches")):
        if piece in want and kit_word in want:
            want.remove(kit_word)
            r.understood = [u for u in r.understood if u != "want %s" % kit_word]
    family = r.raw.get("family")
    if family and family not in WORLD_FAMILIES and "lookout" in want:
        want[want.index("lookout")] = "perches"
        r.understood = ["want perches" if u == "want lookout" else u for u in r.understood]
CRAZY = r"^\W*(crazy|verrueckt\w*|wild|irre|bonkers|mach was verruecktes)\W*$"
def _crazy(r, text):
    if not re.match(CRAZY, fold(text).strip()):
        return
    raw = r.raw
    raw["novelty"] = {"mode": "surprise"}
    raw.setdefault("verticality", "high")
    raw.setdefault("variety", "high")
    r.said("'%s': a fun surprise - high, varied and rolled boldly" % text.strip())
    _explained(r, text)
LANDMARK_WORDS = (
    (r"\bleucht+(ue|u)rm\w*|\blighthouses?\b", "lighthouse"),
    (r"\bobelisk\w*", "obelisk"),
    (r"\bwacht(ue|u)rm\w*|\bwatch ?towers?\b|\baussichtst(ue|u)rm\w*", "watchtower"),
    (r"\btempel\b|\btempeln\b|\btemples?\b|\bpavillons?\b", "temple"),
)
def _landmark_kinds(r, text):
    from . import brief as briefmod
    low = fold(text)
    for pat, feat in LANDMARK_WORDS:
        if feat not in briefmod.FEATURES:
            continue
        for m in re.finditer(pat, low):
            feats = r.raw.setdefault("features", {"want": [], "avoid": []})
            feats.setdefault("want", [])
            feats.setdefault("avoid", [])
            side = "avoid" if _negated(low, m.start()) else "want"
            other = "want" if side == "avoid" else "avoid"
            if feat not in feats[side]:
                feats[side].append(feat)
                r.said("%s %s" % (side, feat))
            if feat in feats[other]:
                feats[other].remove(feat)
            r.not_understood = [n for n in r.not_understood if n != m.group(0)]
            break
def _understand_all(text, base=None):
    from . import starnames
    rest, hints = starnames.read_hints(text)
    if not hints:
        return _understand(text, base, scope="wish")
    r = _understand(rest, base, scope="wish")
    r.text = text
    r.raw["wish"] = text
    reqs = [q for q in r.raw.get("requests") or [] if q.get("kind") != "stars"]
    had = next((q.get("count") for q in r.raw.get("requests") or []
                if q.get("kind") == "stars"), None)
    req = starnames.hint_request(hints, had if had else None)
    if req.get("count") is None:
        req.pop("count")
    r.raw["requests"] = reqs + [req]
    for h in hints:
        r.said("bonus star %d: %s%s" % (
            h["n"], " or ".join(k.replace("longjump", "long jump") for k in h.get("kinds") or [])
            or "anywhere", (" named \"%s\"" % h["name"]) if h.get("name") else ""))
    return r
def _understand(text, base=None, scope="wish", P=None):
    low = fold(text)
    low = low.replace("_", " ")
    from . import userlex
    low, taught = userlex.rewrite(low)
    if not LEXICON:
        return _read(text, low, base or {}, None)
    from . import lexicon
    if P is None:
        P = lexicon.prepare(low, scope)
    else:
        P.low = low
    r = _read(text, P.low, base or {}, P)
    new = lexicon.rewrite(r.low, r.free, P)
    if new != r.low:
        r = _read(text, new, base or {}, P)
    if "mood" not in r.raw:
        from . import mood as moodmod
        key = moodmod.from_wish(low)
        if key is not None:
            r.raw["mood"] = key
            r.said("mood %s" % moodmod.PRESET_BY_KEY[key][1].lower())
    for kind, line in P.notes:
        r.guess(line)
    _modifier_hills(r, P)
    if r.raw.get("style") == "plain" and "variety" not in r.raw:
        r.raw["variety"] = "low"
        r.guess("plain: material variety low (fewer pictures)")
    _amounts(r, low)
    r.heard = list(dict.fromkeys(P.lexicon))
    for w, meaning in taught:
        r.understood.insert(0, "taught: '%s' = %s" % (w, meaning))
        r.heard.insert(0, "'%s' -> taught" % w)
    r.taught = taught
    r.confidence = getattr(P, "confidence", 1.0)
    return r
AMOUNT_SAY = {"trace": "hardly any", "few": "a little / a few", "less": "less",
              "more": "more", "lots": "lots of"}
def _amounts(r, low):
    from . import lexicon
    spans = lexicon.amount_spans(low) + lexicon.amount_spans(getattr(r, "low", low))
    feats = r.raw.get("features") or {}
    avoid = set(feats.get("avoid") or [])
    counted = set()
    for a in r.raw.get("anchors") or []:
        if a.get("count") and a.get("what") != "hill":
            w = a["what"]
            counted.add(briefmod.FEATURE_ALIASES.get(w, w))
            counted.add(w)
    am = {}
    for _, _, grade, fs, cued in spans:
        for f in fs:
            if f in counted or f in am:
                continue
            if f in avoid:
                if not cued:
                    continue
                avoid.discard(f)
                feats["avoid"] = [x for x in feats.get("avoid") or [] if x != f]
                if f in briefmod.FEATURES and f not in feats.get("want", []):
                    feats.setdefault("want", []).append(f)
                r.understood = [u for u in r.understood if u != "avoid %s" % f]
            am[f] = grade
    if not am:
        return
    if "terrain" in am and r.raw.get("anchors"):
        keep = [a for a in r.raw["anchors"] if not (
            a.get("what") == "hill" and a.get("count") and "anywhere" in (a.get("where") or {}))]
        if len(keep) != len(r.raw["anchors"]):
            r.raw["anchors"] = keep
            r.assumed = [x for x in r.assumed if not re.match(r"'[^']+' read as \d+$", x)]
            if not keep:
                r.raw.pop("anchors")
    r.raw["amounts"] = dict(sorted(dict(r.raw.get("amounts") or {}, **am).items()))
    r.guess("how much: %s" % ", ".join("%s %s" % (AMOUNT_SAY[v], k.replace("_", " "))
                                       for k, v in sorted(am.items())))
HILL_PARTS = ("berg", "huegel", "hill", "mountain")
def _modifier_hills(r, P):
    mods = [(w, ps) for w, ps in getattr(P, "modifiers", []) if any(
        p.startswith(HILL_PARTS) for p in ps)]
    from . import lexicon
    for m in re.finditer(r"\b(berg|huegel)([a-z]{3,})\b", fold(r.text or "")):
        if m.group(0) in lexicon.index():
            continue
        if not re.match(r"(e|en|es|n|s|ig\w*|ige\w*|ab|auf|hoch|steig\w*)$", m.group(2)):
            mods.append((m.group(0), [m.group(1)]))
    if not mods or not r.raw.get("anchors"):
        return
    whole = fold(r.text or "")
    if re.search(r"\b(berg|huegel|hill|mountain)\w*\b", re.sub(
            r"\b(%s)\b" % "|".join(re.escape(w) for w, _ in mods), " ", whole)):
        return
    keep = [a for a in r.raw["anchors"] if not (
        a.get("what") == "hill" and a.get("where") == {"compass": "c"})]
    if len(keep) == len(r.raw["anchors"]):
        return
    if keep:
        r.raw["anchors"] = keep
    else:
        r.raw.pop("anchors")
    r.assumed = [x for x in r.assumed if x != "a hill without a place: in the middle"]
    feats = r.raw.setdefault("features", {"want": [], "avoid": []})
    feats.setdefault("want", [])
    feats.setdefault("avoid", [])
    if not set(feats["want"]) & {"terrain", "mountains"} and "terrain" not in feats["avoid"]:
        feats["want"].append("terrain")
    r.guess("'%s': the hills describe it - hilly ground, no hill placed in the middle"
            % mods[0][0])
FACING_WHO = r"\b(bases?|basen|basis|lager|camps?|forts?|festungen|burgen|castles)\b"
FACING = (r"\b(face each other|facing each other|face one another|facing one another|"
          r"opposite each other|opposite one another|on opposite (sides|ends)|at opposite ends|"
          r"(sich |einander )?gegenueber(stehen|stehend\w*|liegen|liegend\w*)?|"
          r"an (den )?gegenueberliegenden (seiten|enden)|gegenueberliegende\w*|"
          r"(stehen|liegen) sich gegenueber)\b")
ACROSS = (r"\b(across|over|ueber|getrennt durch|separated by|with|mit|and|und)?\s*"
          r"(a|an|the|ein|eine|einen|einem|einer|den|dem|der)?\s*(%s)"
          r"(\s+(between|zwischen)\s+(them|ihnen|den basen|the bases))?")
ACROSS_WHAT = {"river": r"fluss\w*|rivers?|bach|stream|creek",
               "water": r"see|lake|wasser|water",
               "void_gaps": r"abgrund|schlucht|chasm|canyon|gap|kluft",
               "bridge": r"bruecke|bridge"}
def _facing(r, low):
    who = re.search(FACING_WHO, low)
    fm = re.search(FACING, low)
    if who is None or fm is None:
        return
    raw = r.raw
    r.take(who)
    r.take(fm)
    for m in re.finditer(r"\b(each other|one another|einander|sich|die|which|that|"
                         r"zwei|two|both|beide[n]?)\b", low):
        r.take(m)
    raw["sides"] = "2"
    a = {"what": "base", "count": 2,
         "where": {"relation": "opposite", "of": "bases", "edge": "ring"}}
    raw["anchors"] = [x for x in raw.get("anchors") or [] if x.get("what") != "base"] + [a]
    r.understood = [u for u in r.understood if not u.startswith("anchor 2 base")]
    r.said("two bases facing each other (opposite ends of the map)")
    for feat, pat in ACROSS_WHAT.items():
        am = re.search(ACROSS % pat, low)
        if am is None or am.group(1) is None and am.group(5) is None:
            continue
        r.take(am)
        feats = raw.setdefault("features", {"want": [], "avoid": []})
        feats.setdefault("want", [])
        feats.setdefault("avoid", [])
        if feat not in feats["want"] and feat not in feats["avoid"]:
            feats["want"].append(feat)
        raw["anchors"] = [x for x in raw["anchors"]
                          if not (x.get("what") == "bridge" and feat != "bridge")]
        r.said("a %s between the bases" % ACROSS_WHAT_SAY.get(feat, feat))
        break
ACROSS_WHAT_SAY = {"void_gaps": "chasm", "water": "lake"}
def _read(text, low, base, P):
    if LEXICON:
        _forge_objects()
    r = Reading(text)
    r.P = P
    low, typos = correct(low)
    for t in typos:
        r.guess("typo: " + t)
    low = re.sub(r"(\d+)\s*,\s*(\d+)", r"\1:\2", low)
    low = re.sub(r"(\d)\.(\d)", lambda m: m.group(1) + "\u2024" + m.group(2), low)
    r.low = low
    _whole(r, low, base)
    _clauses(r, low)
    if P is not None:
        from . import lexicon
        lexicon.apply(r, low, P, base)
        for a, b, _, _, _ in lexicon.amount_spans(low):
            r.consumed.append((a, b))
    _facing(r, low)
    _leftovers(r, low)
    if r.raw.get("players") is not None and not 2 <= r.raw["players"] <= 16:
        r.not_understood.append("'%d players': cannot build players" % r.raw["players"])
        r.raw.pop("players")
    return r
_NATIVE = {}
def native_lines(text):
    return native(text)[0]
def native(text):
    if text not in _NATIVE:
        r = _read(text, text, {}, None)
        _NATIVE[text] = (frozenset(r.understood), not any(not f[3] for f in r.free))
    return _NATIVE[text]
def parse(text):
    r = understand(text)
    return r.raw, r.understood + ["assumed: " + a for a in r.assumed], r.not_understood
def _set(r, field, value, said, m=None):
    r.raw[field] = value
    r.said(said)
    r.take(m)
ROOM_WORDS = (
    (r"\bkill ?house\b|\btraining (course|ground|house)\b|\btrainingsparcours\w*|"
     r"\btrainingsgelaende\b|\bschiessbahn\w*|\bshooting (range|course)\b|"
     r"\bschiessstand\w*|\bschiesstraining\w*", "training_course"),
    (r"\brooms?( and|,) (corridors|hallways|halls)\b|\braeume?n?\b|\bzimmer(n)?\b|"
     r"\bindoor\w*|\binnenraeume?n?\b|\bcorridors?\b|\bkorridore?n?\b|\bhallways?\b|"
     r"\bgaenge(n)?\b|\bflure(n)?\b|\bhaeuserkampf\w*|\bclose quarters?\b|\bcqb\b|"
     r"\binterior\w*|\brooms\b", "rooms"),
)
LIGHT_WORDS = (
    (r"\blatern\w*|\blanterns?\b|\bstrassenlatern\w*|\bstreet ?lights?\b|"
     r"\blamp ?posts?\b|\blampen\b|\bfackeln\b|\btorches\b|\blots of lights\b|"
     r"\bviele lichter\b|"
     r"\b(viel|mehr|ganz viel|sehr viel|lots of|plenty of|much|more) licht\b|"
     r"\b(lots of|plenty of|much|more) light\b|\bhell beleuchtet\w*|\bwell lit\b|"
     r"\blagerfeuer\w*|\bcamp ?fires?\b|\bfeuerstellen?\b", "lanterns"),
    (r"\bdunkel\w*|\bdark\b|\bfinster\w*|\bstockdunkel\b|\bpitch.?(black|dark)\b|"
     r"\bduester\w*", "dark"),
)
def _light_words(r, low):
    raw = r.raw
    orig = fold(r.text)
    for pat, feat in LIGHT_WORDS:
        for text in (low, orig):
            m = re.search(pat, text)
            if m is None:
                continue
            feats = raw.setdefault("features", {"want": [], "avoid": []})
            if _negated(text, m.start()):
                if feat not in feats.setdefault("avoid", []):
                    feats["avoid"].append(feat)
                    r.said("avoid %s" % feat)
            elif feat not in feats.setdefault("want", []):
                feats["want"].append(feat)
                r.said("want %s" % feat)
            if text is low:
                for mm in re.finditer(pat, low):
                    r.take(mm)
            break
def _room_words(r, low):
    raw = r.raw
    for pat, feat in ROOM_WORDS:
        hits = [m for m in re.finditer(pat, low)]
        if not hits:
            orig = fold(r.text)
            m = re.search(pat, orig)
            if m and not _negated(orig, m.start()):
                feats = raw.setdefault("features", {"want": [], "avoid": []})
                if feat not in feats.setdefault("want", []):
                    feats["want"].append(feat)
                    r.said("want %s" % feat)
            continue
        feats = raw.setdefault("features", {"want": [], "avoid": []})
        if _negated(low, hits[0].start()):
            if feat not in feats.setdefault("avoid", []):
                feats["avoid"].append(feat)
                r.said("avoid %s" % feat)
            _take_negation(r, low, hits[0].start())
        elif feat not in feats.setdefault("want", []):
            feats["want"].append(feat)
            r.said("want %s" % feat)
        for m in hits:
            r.take(m)
def _whole(r, low, base):
    raw = r.raw
    _room_words(r, low)
    _light_words(r, low)
    for m in re.finditer(r"\bmid[- ]?range( (sight ?lines?|lines? of sight|sichtlinien|"
                         r"sichtachsen|sniper))?\b|\bmittlere\w* (distanz|reichweite|sichtlinien|"
                         r"sichtachsen)\b", low):
        r.take(m)
        if m.group(1) or "sicht" in m.group(0):
            r.said("mid-range sightlines: the family's own sight lines (medium), no long lines")
        else:
            r.said("mid-range fights: the family's own sight lines (medium)")
    for m in re.finditer(r"\b(every|alle) (few|couple( of)?|(ein )?paar) (meters?|metres?|metern?|steps|"
                         r"schritte)\b", low):
        r.take(m)
        r.said("'%s': spaced as the generator spaces them" % m.group(0))
    for pat, key in REFERENCES:
        m = re.search(r"((wie (die|der|das|in der)?|like( the)?|im stil (der|von)|in the style "
                      r"of( the)?|die|the)\s*)?" + pat, low)
        if m:
            if key == "skykeep":
                _set(r, "reference", "skykeep", "reference: the Sky Keep", m)
                if "symmetry" not in raw:
                    raw["symmetry"] = "turn4"
                    r.guess("symmetry turn4 (the Sky Keep's own)")
            else:
                r.guess("like %s: read as its family's defaults (only the Sky Keep is a "
                        "reference the engine builds from)" % key)
                r.take(m)
            dm = re.search(r"aber anders|but different|nur anders|something new|etwas neues|"
                           r"aber neu|but new", low)
            if dm:
                r.take(dm)
                r.said("a new map, not the reference itself")
            break
    for dm in re.finditer(r"(openness|offenheit|verticality|vertikalitaet|density|dichte)\s*"
                          r"[:=]?\s*(0?[.\u2024]\d+|1[.\u2024]0|0|1)\b", low):
        field = {"offenheit": "openness", "vertikalitaet": "verticality",
                 "dichte": "density"}.get(dm.group(1), dm.group(1))
        dials = dict(raw.get("dials") or {})
        dials[field] = float(dm.group(2).replace("\u2024", "."))
        raw["dials"] = dials
        r.take(dm)
        r.said("dial %s %s" % (field, dm.group(2)))
    am = re.search(r"attack\W*(and\W*)?defen\w+|angriff\w*\W*(und\W*)?verteidig\w*|"
                   r"angreifer\w*\W*(und\W*)?verteidiger\w*", low)
    if am:
        r.take(am)
        raw.setdefault("family", "objective")
        raw["sides"] = "2"
        r.said("attack and defend: two sides")
        if "symmetry" not in raw and not re.search(r"symmetri", low):
            raw["symmetry"] = "none"
            r.guess("symmetry none (one side attacks, one defends)")
    m = re.search(r"(?:namens|genannt|heisst|called|named|name[:=]?)\s+[\"']?([a-z0-9][a-z0-9 '\-]{1,38}"
                  r"[a-z0-9])[\"']?", low)
    if m:
        orig = re.search(re.escape(m.group(1)), fold(r.text))
        name = r.text[orig.start():orig.end()] if orig else m.group(1)
        name = name.strip().title() if name.islower() else name.strip()
        _set(r, "name", name[:40], "name %s" % name[:40], m)
    m = re.search(r"\bseed\s*[:=]?\s*(\d+)", low)
    if m:
        _set(r, "seed", int(m.group(1)), "seed %s" % m.group(1), m)
    m = re.search(r"(\d+)\s*(kandidaten|candidates|versuche|tries|varianten|variants)", low)
    if m:
        _set(r, "candidates", max(1, min(1000, int(m.group(1)))), "candidates %s" % m.group(1), m)
    m = re.search(r"(max(imal)?|hoechstens|at most|up to|budget)\s*(\d+)\s*(objekte|objects|"
                  r"teile|pieces|stuecke)?", low)
    if m and m.group(4) or (m and m.group(1) == "budget"):
        _set(r, "budget", int(m.group(3)), "budget %s objects" % m.group(3), m)
    m = re.search(r"\b(\d+)\s*(?:vs\.?|v|gegen|versus|on|gg)\s*(\d+)\b", low)
    if m:
        a, b = int(m.group(1)), int(m.group(2))
        _set(r, "players", a + b, "players %d (%d vs %d)" % (a + b, a, b), m)
        if a == b and a > 1:
            raw["sides"] = "2"
            r.said("two sides")
    else:
        m = re.search(NUM_RE + r"\s*(spieler\w*|players?|leute|people|personen|mann|"
                      r"teilnehmer\w*|gamer|spielern)", low)
        if m:
            _set(r, "players", number(m.group(1)), "players %s" % number(m.group(1)), m)
        else:
            m = re.search(r"\bzu (zweit|dritt|viert|fuenft|sechst|acht|zehnt|zwoelft|sechzehnt)\b",
                          low)
            if m:
                n = {"zweit": 2, "dritt": 3, "viert": 4, "fuenft": 5, "sechst": 6, "acht": 8,
                     "zehnt": 10, "zwoelft": 12, "sechzehnt": 16}[m.group(1)]
                _set(r, "players", n, "players %d" % n, m)
            m2 = re.search(r"\bfuer (\d+)\b|\bfor (\d+)\b", low)
            if not m and m2:
                n = int(m2.group(1) or m2.group(2))
                if 2 <= n <= 16:
                    _set(r, "players", n, "players %d" % n, m2)
                    r.guess("'%s' read as %d players" % (m2.group(0), n))
    m = re.search(r"\b(2|zwei|two)\s*teams\b|\bteam\s*(vs|gegen|versus)\b|\brot gegen blau\b|"
                  r"\bred (vs|versus|against) blue\b|\bteams?\b|\bteamspiel\b", low)
    if m:
        raw["sides"] = "2"
        r.said("two sides")
        r.take(m)
        if LEXICON:
            for mm in re.finditer(m.re.pattern, low):
                if not re.match(r"\b(4|vier|four)\s*teams\b", mm.group(0)):
                    r.take(mm)
    m = re.search(r"\b(4|vier|four)\s*teams\b", low)
    if m:
        raw["sides"] = "4"
        r.said("four sides")
        r.take(m)
    m = re.search(r"jeder gegen jeden|free.?for.?all|\bffa\b|alle gegen alle", low)
    if m:
        raw["sides"] = "ffa"
        r.said("free-for-all")
        r.take(m)
    try:
        from . import modes as modesmod
        found = modesmod.lookup(low)
    except Exception:
        found = []
    if found:
        kept = []
        for k, f, nm in found:
            mm = re.search(re.escape(fold(nm)), low) or re.search(
                r"\W+".join(re.escape(w) for w in re.findall(r"[a-z0-9]+", fold(nm))), low)
            if mm is not None and _negated(low, mm.start()):
                r.take(mm)
                _take_negation(r, low, mm.start())
                r.said("not the mode %s" % k)
                continue
            kept.append((k, f, nm))
        found = kept
    if found:
        keys = [k for k, _, _ in found]
        raw["modes"] = keys
        fams = [f for _, f, _ in found if f]
        for k, f, nm in found:
            mm = re.search(re.escape(fold(nm)), low) or re.search(
                r"\W+".join(re.escape(w) for w in re.findall(r"[a-z0-9]+", fold(nm))), low)
            r.take(mm)
            if mm is not None:
                r.mode_spans = getattr(r, "mode_spans", []) + [(mm.start(), mm.end())]
            r.said("mode %s (%s)" % (k, nm))
        if fams:
            raw["family"] = fams[0]
            r.guess("family %s (the family %s is played on)" % (fams[0], found[0][2]))
    for pat, fam, modes in FAMILY_WORDS:
        m = None
        for mm in re.finditer(pat, low):
            if _negated(low, mm.start()):
                r.take(mm)
                _take_negation(r, low, mm.start())
                r.said("not the %s family" % fam)
            elif m is None:
                m = mm
        if m:
            for mm in re.finditer(pat, low):
                r.take(mm)
            if "family" not in raw:
                raw["family"] = fam
                r.said("family %s" % fam)
            if modes and not raw.get("modes"):
                raw["modes"] = list(modes)
                r.said("mode %s" % modes[0])
            if fam == "objective" and "sides" not in raw:
                raw["sides"] = "2"
                r.guess("two sides (an objective map is played by two teams)")
            break
    _prefab_words(r, raw, low)
    _preset_words(r, raw, low)
    mm = re.search(METRES, low)
    m = re.search(r"(\d{3,5})\s*(?:x|mal|by|\*)\s*(\d{3,5})", low)
    if mm:
        w = int(float(mm.group(1).replace(",", ".")) * 100)
        d = int(float(mm.group(2).replace(",", ".")) * 100)
        _set(r, "size", {"w": w, "d": d}, "size %d x %d (%s x %s m)"
             % (w, d, mm.group(1), mm.group(2)), mm)
    elif m:
        a, b = int(m.group(1)), int(m.group(2))
        if a == b:
            _set(r, "size", {"across": a}, "size %d across" % a, m)
        else:
            _set(r, "size", {"w": a, "d": b}, "size %d x %d (width by depth)" % (a, b), m)
    else:
        m = re.search(r"(\d{3,5})\s*(einheiten|units)?\s*(breit|across|wide|quer|gross)", low)
        if m:
            _set(r, "size", {"across": int(m.group(1))}, "size %s across" % m.group(1), m)
        m2 = re.search(r"(\d{1,2})\s*(s|sek\w*|sec\w*)\s*(quer|across|ueber|to cross|zum "
                       r"durchlaufen)", low)
        if m2:
            _set(r, "size", {"across_s": float(m2.group(1))},
                 "size: %s s to cross" % m2.group(1), m2)
    _music_by_name(r, low)
    visuals, rows = list(raw.get("visuals") or []), set()
    for pat, vis in VISUAL_WORDS:
        for m in re.finditer(pat, low):
            if _negated(low, m.start()):
                r.take(m)
                _take_negation(r, low, m.start())
                r.said("not the visual %s" % vis.replace("_", " "))
                if briefmod.VISUALS[vis][0] == "fog" and "fog" not in rows:
                    visuals.append("clear_air")
                    rows.add("fog")
                continue
            row = briefmod.VISUALS[vis][0]
            if vis in visuals or (row is not None and row in rows):
                r.take(m)
                continue
            visuals.append(vis)
            if row is not None:
                rows.add(row)
            for mm in re.finditer(pat, low):
                r.take(mm)
            r.said("visual %s%s" % (vis.replace("_", " "), " (the theme's own pairing)"
                                    if vis == "auto" else ""))
            break
    if visuals:
        raw["visuals"] = visuals
    if "mood" not in raw:
        from . import mood as moodmod
        key = moodmod.from_wish(low)
        if key is not None:
            raw["mood"] = key
            r.said("mood %s" % moodmod.PRESET_BY_KEY[key][1].lower())
    m = re.search(GROUND_RE, low)
    if m:
        word = m.group(2) or m.group(3)
        g = GROUND_WORD.get(word)
        if g is not None:
            raw["ground"] = g
            r.take(m)
            r.said("ground of The Tiles: %s" % g)
            if raw.get("level") not in (None, "empty"):
                r.guess("ground %s: on The Tiles, so the level is The Tiles" % g)
            raw["level"] = "empty"
    for field, table in (("pace", PACE_WORDS), ("theme", THEME_WORDS),
                         ("verticality", VERT_WORDS), ("density", DENSITY_WORDS),
                         ("symmetry", SYM_WORDS), ("level", LEVEL_WORDS), ("edge", EDGE_WORDS),
                         ("difficulty", DIFF_WORDS), ("style", STYLE_WORDS),
                         ("boundary", BOUNDARY_WORDS)):
        hits = []
        for pat, val in table:
            for m in re.finditer(pat, low):
                if field in ("style", "pace", "difficulty", "symmetry") and \
                        _negated(low, m.start()) and LEXICON:
                    r.take(m)
                    _take_negation(r, low, m.start())
                    r.said("not %s %s" % (field, val))
                    if field == "symmetry" and val != "none" and "symmetry" not in raw:
                        raw["symmetry"] = "none"
                        r.said("symmetry none (not symmetric)")
                    continue
                if field == "theme" and _negated(low, m.start()):
                    if not re.search(r"\blava\b|\bwasser\b|\bwater\b", m.group(0)):
                        r.take(m)
                        _take_negation(r, low, m.start())
                    r.said("not the %s theme" % val)
                    continue
                if any(a <= m.start() < b for a, b in r.consumed):
                    continue
                if field == "verticality" and val == "high" and m.group(0) in ("high", "tall") \
                        and not re.search(r"\b(map|arena|karte|level)\b", low[m.end():m.end() + 12]):
                    continue
                hits.append((m.start(), val, m))
        if not hits:
            continue
        hits.sort(key=lambda h: h[0])
        if field in raw:
            continue
        val, m = hits[0][1], hits[0][2]
        r.take(m)
        for _, _, mm in hits[1:]:
            r.take(mm)
        raw[field] = val
        r.said("%s %s" % (field, val))
        others = sorted(set(h[1] for h in hits) - {val})
        if others:
            r.guess("%s: %s taken (also heard %s)" % (field, val, ", ".join(others)))
    if "size" not in raw:
        for pat, val in SIZE_WORDS:
            for m in re.finditer(pat, low):
                after = low[m.end():m.end() + 30]
                if re.match(r"\s*\w*\s*(" + "|".join(p for p, _, _ in THINGS[2:12]) + ")",
                            after) and not re.match(LANDSCAPE_AFTER, after):
                    continue
                if any(a <= m.start() < b for a, b in r.consumed):
                    continue
                if _negated(low, m.start()):
                    r.take(m)
                    _take_negation(r, low, m.start())
                    r.said("not size %s" % val)
                    _size_correction(r, low, m.end())
                    continue
                raw["size"] = val
                r.said("size %s" % val)
                r.take(m)
                break
            if "size" in raw:
                break
    _aspect_words(r, raw, low)
    _course_length(r, raw, low, base)
    m = re.search(r"\bkreisrund\w*|\brundlich\w*|\brund\b|\bround(\W*ish)?\b|\bcircular\b|\boval\b", low)
    if m:
        r.take(m)
        r.guess("'%s': the shape of a ring or track is the family's own" % m.group(0))
    for field, table in (("sky", SKY_WORDS), ("music", MUSIC_WORDS)):
        val, m = _first(table, low, r)
        if val:
            raw[field] = val
            r.said("%s %s" % (field, val))
    dna = dict(raw.get("dna") or {})
    for pat, key, value, phrase in DNA_WORDS:
        if key in dna:
            if dna[key] == value:
                for m in re.finditer(pat, low):
                    r.take(m)
            continue
        for m in re.finditer(pat, low):
            if any(a <= m.start() < b for a, b in r.consumed if (a, b) != (m.start(), m.end())):
                continue
            if _negated(low, m.start()):
                continue
            dna[key] = value
            r.take(m)
            r.said("dna %s %.2f (%s)" % (key, value, phrase))
            if key == "complexity" and value > 0.5 and re.search(
                    r"bauten|gebaeude|haeuser|bauwerk|buildings|architektur|architecture",
                    m.group(0)):
                feats = raw.setdefault("features", {"want": [], "avoid": []})
                if "buildings" not in feats["want"]:
                    feats["want"].append("buildings")
                    r.said("want buildings")
            for more in re.finditer(pat, low):
                r.take(more)
            break
    if dna:
        raw["dna"] = dna
    for pat, field, value, phrase in COMPARATIVES:
        m = re.search(pat, low)
        if m and field not in raw:
            before = base.get(field)
            raw[field] = value
            r.take(m)
            r.said("%s %s (%s)" % (field, value, phrase))
            r.guess("'%s' is a step from %s, read as %s %s" % (
                phrase, ("the current %s" % before) if before else "the default", field, value))
    for m in re.finditer(r"(boden|floor|waende|walls|rampen|ramps|bruecken?|bridges?)\s*"
                         r"(aus|in|of|made of|wie)\s*(\w+)", low):
        role = {"boden": "floor", "floor": "floor", "waende": "wall", "walls": "wall",
                "rampen": "ramp", "ramps": "ramp"}.get(m.group(1), "bridge")
        theme, _ = _first(THEME_WORDS, m.group(3))
        if theme:
            from . import kit
            tex = kit.THEMES.get(theme, {}).get("floor" if role == "floor" else role)
            if tex:
                pal = dict(raw.get("palette") or {})
                pal[role] = [tex]
                raw["palette"] = pal
                r.take(m)
                r.said("palette %s %s (%s)" % (role, tex, theme))
                if raw.get("theme") == theme and theme_mentions(low) == 1:
                    raw.pop("theme")
                    r.understood = [u for u in r.understood if u != "theme %s" % theme]
    _metal(r, raw, low)
METAL_RE = (r"\b(?:(boden|floor|waende|walls|rampen|ramps)\s*(?:aus|in|of|made of|wie)\s*)?"
            r"(metall\w*|metal|steel|stahl\w*)\b(?!\s*-?\s*(box|boxen|boxes|bloecke|blocks?)\b)")
METAL_PALETTE = {"floor": "steelplate", "deck": "steelgrate", "wall": "rustplate",
                 "ramp": "steelplate", "bridge": "steelgrate", "cover": "steelcorrugated",
                 "trim": "steeldark"}
def _metal(r, raw, low):
    for m in re.finditer(METAL_RE, low):
        if any(a <= m.start(2) < b for a, b in r.consumed) or _negated(low, m.start()):
            continue
        role = {"boden": "floor", "floor": "floor", "waende": "wall", "walls": "wall",
                "rampen": "ramp", "ramps": "ramp"}.get(m.group(1))
        pal = dict(raw.get("palette") or {})
        roles = [role] if role else [k for k in METAL_PALETTE if k not in pal]
        for k in roles:
            pal[k] = [METAL_PALETTE[k]]
            r.said("palette %s %s (metal)" % (k, METAL_PALETTE[k]))
        if roles:
            raw["palette"] = pal
        r.take(m)
def _music_by_name(r, low):
    if not re.search(r"\b(musik|music|song|soundtrack|track|lied)\b", low):
        return
    from . import kit
    best = None
    for t in kit.music_tracks():
        for name in t["names"]:
            n = fold(name)
            at = low.find(n)
            if at >= 0 and len(n) >= 4 and (best is None or len(n) > len(best[1])):
                best = (t, n, at)
    if best is None:
        return
    t, n, at = best
    r.raw["music"] = t["key"]
    r.consumed.append((at, at + len(n)))
    m = re.search(r"\b(musik|music|song|soundtrack|track|lied)\b", low)
    r.take(m)
    r.said("music %s" % t["name"])
def theme_mentions(low):
    return sum(1 for pat, _ in THEME_WORDS for _ in re.finditer(pat, low))
def _negated(low, at, window=28):
    return negation.negated(low, at)
METRES = (r"\b(\d{1,3}(?:[.,]\d)?)\s*(?:m\s*)?(?:x|mal|by|auf|\*)\s*(\d{1,3}(?:[.,]\d)?)\s*"
          r"(?:m|meter|metern|metres|meters|metre)\b")
ASPECT_WORDS = (
    (r"\blong(,| and)? narrow\b|\blang\w*,? (und )?schmal\w*|\bschmal\w* (und )?lang\w*|"
     r"\blanggezogen\w*|\belongated\b|\bnarrow and long\b|\bschlauch\w*", 2.5,
     "long and narrow"),
    (r"\bwide (and )?(shallow|short|flat)\b|\bwide (map|arena|level|field)\b|"
     r"\bbreit\w* (und )?(flach|kurz)\w*|"
     r"\bin die breite\b", 1.6, "wide"),
)
def _aspect_words(r, raw, low):
    for pat, a, said in ASPECT_WORDS:
        m = re.search(pat, low)
        if not m or _negated(low, m.start()):
            continue
        cur = raw.get("size")
        if isinstance(cur, dict) and ("w" in cur or "across_s" in cur):
            r.take(m)
            return
        if isinstance(cur, dict) and "across" in cur:
            raw["size"] = {"across": cur["across"], "aspect": a}
        elif isinstance(cur, str):
            raw["size"] = {"aspect": a, "tier": cur}
        else:
            raw["size"] = {"aspect": a}
        r.take(m)
        r.said("size %s (width %.1f x the depth)" % (said, a))
        return
def _size_correction(r, low, at):
    span = negation.correction_after(low, at)
    if span is None or "size" in r.raw:
        return
    text = low[span[0]:span[1]]
    for pat, val in SIZE_WORDS + SIZE_ADJ:
        m = re.search(pat, text)
        if m and not _negated(low, span[0] + m.start()):
            r.raw["size"] = val
            r.consumed.append((span[0] + m.start(), span[0] + m.end()))
            cm = negation.CORRECT.search(low, at, span[0])
            if cm:
                r.consumed.append((cm.start(), cm.end()))
            r.said("size %s (the correction after the negation)" % val)
            return
def _affirmed(low, feat):
    if not feat:
        return False
    for word in negation.affirmed(low):
        if any(t[2] == feat for t in _thing_hits(" %s " % word)):
            return True
    return False
def _split(low):
    out = []
    for m in re.finditer(r"(?:[^,;.\n!?\s\u2013\u2014-]|[ \t](?![-\u2013\u2014][ \t])|"
                         r"(?<![ \t])[-\u2013\u2014]|[-\u2013\u2014](?![ \t]))+", low):
        start = m.start()
        piece = m.group(0)
        last = 0
        for j in re.finditer(r"\b(und|and|sowie|plus|aber|but|ausserdem|also|dazu|"
                             r"zusaetzlich|additionally|with|mit)\b(?!\s+(einer|einem|einen|"
                             r"a|an|the)?\s*(abkuerzung|shortcut|gelaender|rails?|rampen?|ramps?)\b)",
                             piece):
            seg = piece[last:j.start()]
            if seg.strip():
                out.append((start + last, seg))
            last = j.end()
        seg = piece[last:]
        if seg.strip():
            out.append((start + last, seg))
    return out
def _thing_hits(clause):
    hits = []
    for pat, feat, what in THINGS:
        for m in re.finditer(pat, clause):
            if any(not (m.end() <= a or m.start() >= b) for a, b, _, _, _ in hits):
                continue
            hits.append((m.start(), m.end(), feat, what, m))
    return sorted(hits, key=lambda h: h[0])
def _object_hits(clause):
    hits = []
    for pat, key in OBJECTS:
        for m in re.finditer(pat, clause):
            if any(not (m.end() <= a or m.start() >= b) for a, b, _, _ in hits):
                continue
            hits.append((m.start(), m.end(), key, m))
    return sorted(hits, key=lambda h: h[0])
def _take_count(r, m, off):
    if LEXICON:
        r.consumed.append((off + m.start(), off + m.end(1)))
    else:
        r.take(m, off)
def _count_before(clause, at, r, off):
    before = clause[:at]
    for pat, n in VAGUE:
        m = re.search("(" + pat + r")\s+(\w+\s+){0,2}$", before)
        if m:
            _take_count(r, m, off)
            r.guess("'%s' read as %d" % (m.group(1).strip(), n))
            return n, True
    m = re.search(r"(?:at least|mindestens|min\.?)\s+" + NUM_RE + r"\s+(\w+\s+){0,2}$", before)
    if m:
        _take_count(r, m, off)
        r.guess("'at least %s' read as %s" % (m.group(1), number(m.group(1))))
        return number(m.group(1)), True
    m = re.search(r"\b" + NUM_RE + r"\s+(\w+\s+){0,2}$", before)
    if m:
        n = number(m.group(1))
        _take_count(r, m, off)
        return n, m.group(1) not in ("ein", "eine", "einen", "einem", "einer", "a", "an",
                                     "one", "eins")
    for pat, n in VAGUE:
        m = re.search("(" + pat + r")\s+(\w+\s+){0,2}$", before)
        if m:
            _take_count(r, m, off)
            r.guess("'%s' read as %d" % (m.group(1).strip(), n))
            return n, True
    return None, False
def _plural(word):
    return bool(re.search(r"(e|en|n|s|er)$", word)) and word not in (
        "turm", "bruecke", "grube", "rampe", "treppe", "plattform", "base", "spawn")
def _position(clause, r, off, skip=()):
    m = re.search(r"\b(?:cell|zelle|feld)\s*(\d+)\s*[:;/ ]\s*(\d+)", clause)
    if m:
        r.take(m, off)
        return {"cell": [int(m.group(1)), int(m.group(2))]}
    m = re.search(r"\bx\s*=?\s*(-?\d+)\s*[:;/ ]?\s*z\s*=?\s*(-?\d+)", clause)
    if m:
        r.take(m, off)
        return {"x": int(m.group(1)), "z": int(m.group(2))}
    m = re.search(r"in a row|in einer reihe|in reihe|aufgereiht|hintereinander|"
                  r"in a line|in einer linie", clause)
    if m:
        r.take(m, off)
        return {"aligned": "long_axis"}
    m = re.search(CLOCK, clause)
    if m:
        r.take(m, off)
        return {"clock": int(m.group(1))}
    for pat, c in COMPASS_WORDS:
        m = re.search(pat, clause)
        if m and not any(a <= m.start() < b for a, b in skip):
            r.take(m, off)
            return {"compass": c}
    m = re.search(CORNERS, clause)
    if m:
        r.take(m, off)
        return {"compass": "corners"}
    m = re.search(EDGE, clause)
    if m:
        r.take(m, off)
        return {"edge": "ring"}
    m = re.search(CENTRE, clause)
    if m and not any(a <= m.start() < b for a, b in skip):
        r.take(m, off)
        return {"compass": "c"}
    return None
def _relation(clause, r, off, main_end):
    for pat, rel in RELATIONS:
        for m in re.finditer(pat, clause):
            if m.start() < main_end - 1 and rel not in ("between",):
                continue
            rest = clause[m.end():]
            targets = []
            span_end = m.end()
            for t in _thing_hits(rest)[:2] if rel == "between" else _thing_hits(rest)[:1]:
                targets.append(t)
                span_end = m.end() + t[1]
            pm = re.match(r"\s*(it|them|ihn|ihm|ihr|es|sie|ihnen|that|this|dem|davon)\b", rest)
            if not targets and pm and r.last_anchor:
                r.take(m, off)
                r.take(pm, off + m.end())
                hm = re.search(r"\bherum\b", rest)
                r.take(hm, off + m.end())
                return {"relation": rel, "of": r.last_anchor}, (m.start(), m.end() + pm.end())
            if not targets:
                cm = re.search(CENTRE, rest)
                if cm and cm.start() < 12:
                    r.take(m, off)
                    r.take(cm, off + m.end())
                    return {"relation": rel, "of": "centre"}, (m.start(), m.end() + cm.end())
                if rel in ("on", "near", "around", "next_to") or not rest.strip():
                    continue
                continue
            r.take(m, off)
            names = []
            for t in targets:
                r.take(t[4], off + m.end())
                what = t[3] or t[2]
                names.append(r.anchor_ids.get(what) or _plural_name(what, t[4].group(0)))
            tail = clause[span_end:]
            if len(targets) == 1 and names[0] not in r.anchor_ids.values():
                tpos = _position(tail, r, off + span_end)
                if tpos is not None:
                    tw = targets[0][3]
                    if tw:
                        tid = "%s%d" % (tw, 1 + sum(1 for x in r.pending if x["what"] == tw))
                        r.pending.append({"what": tw, "where": tpos, "id": tid})
                        r.anchor_ids.setdefault(tw, tid)
                        names[0] = tid
                        r.said("anchor %s %s" % (tw, _say(tpos)))
            where = {"relation": rel, "of": names if rel == "between" and len(names) > 1
                     else names[0]}
            if rel == "between" and len(names) == 1:
                where["of"] = names[0]
            return where, (m.start(), span_end)
    return None, None
def _slot_relation(clause, r, off, main_end):
    P = getattr(r, "P", None)
    if P is None or not getattr(P, "slots", None):
        return None
    for pat, rel in RELATIONS:
        for m in re.finditer(pat, clause):
            if m.start() < main_end - 1:
                continue
            sm = re.match(r"\s*(?:the|a|an|dem|der|den|die|das|einem|einer|einen)?\s*(zzlx[a-z]+)",
                          clause[m.end():])
            if not sm or sm.group(1) not in P.slots:
                continue
            want = (P.slots[sm.group(1)][0] or {}).get("want") or []
            if not want:
                continue
            r.take(m, off)
            return {"relation": rel, "of": want[-1]}
    return None
def _plural_name(what, word):
    if what in ("base",):
        return "bases"
    if what in ("ramp", "ramps"):
        return "ramps"
    if what in ("tower",) and _plural(word):
        return "towers"
    return what
def _height(clause, r, off):
    for pat, val in HEIGHT:
        m = re.search(pat, clause)
        if m:
            r.take(m, off)
            if val is None:
                return int(next(g for g in m.groups() if g))
            return val
    return None
def _exception(r, low, at):
    span = negation.exception_after(low, at)
    if span is None:
        return None
    a, b = span
    text = low[a:b]
    em = negation.EXCEPT.match(text)
    if em is None:
        return None
    where = _position(text, r, a)
    if where is None:
        return None
    r.consumed.append((a, a + em.end()))
    n = None
    nm = re.search(r"\b(einer|einem|einen|eine|eins|one|a single|zwei|two|drei|three|vier|four)"
                   r"\b", text[em.end():])
    if nm:
        r.consumed.append((a + em.end() + nm.start(), a + em.end() + nm.end()))
        n = number(nm.group(1).replace("a single", "one")) or 1
    for m in re.finditer(r"\b(am|an der|an den|in der|in den|at the|in the|around the|"
                         r"around|um|bei|near|by)\b", text[em.end():]):
        r.consumed.append((a + em.end() + m.start(), a + em.end() + m.end()))
    return where, n
def _clauses(r, low):
    raw = r.raw
    want, avoid, anchors, objects = [], [], [], []
    in_rounds = bool(re.search(IN_ROUNDS, low))
    if in_rounds:
        r.take(re.search(IN_ROUNDS, low))
    last_thing = [None]
    queue = list(_split(low))
    while queue:
        off, clause = queue.pop(0)
        objs = [o for o in _object_hits(clause)
                if not any(a <= off + o[0] < b and (a, b) != (off + o[0], off + o[1])
                           for a, b in getattr(r, "mode_spans", ()))]
        things = [t for t in _thing_hits(clause)
                  if not any(a <= off + t[0] < b for a, b in r.consumed)]
        if objs and things and objs[0][0] > things[0][1] and \
                not re.search(r"\b(mit|with|auf|on|in|im|an|am|bei|near|neben|ueber|unter|"
                              r"vor|hinter|zwischen|um|around)\b", clause[things[0][1]:objs[0][0]]):
            cut = objs[0][0]
            m_num = re.search(r"(\d+|\w+)\s*$", clause[:cut])
            if m_num and m_num.start() >= things[0][1] and (
                    m_num.group(1).isdigit() or m_num.group(1) in NUMBERS):
                cut = m_num.start()
            queue.insert(0, (off + cut, clause[cut:]))
            clause = clause[:cut]
            objs = []
            things = [t for t in things if t[0] < cut]
        if objs and (not things or objs[0][0] <= things[0][0]):
            start, end, key, m = objs[0]
            r.take(m, off)
            if _negated(low, off + start):
                _take_negation(r, low, off + start)
                exc = _exception(r, low, off + start)
                if exc is not None:
                    where, n = exc
                    n = n or (8 if "edge" in where else 3 if _plural(m.group(0)) else 1)
                    objects.append({"key": key, "count": n, "where": where})
                    r.said("object %s x%d %s, nowhere else (the exception)" % (key, n,
                                                                             _say(where)))
                    if key == "tree":
                        raw.setdefault("amounts", {})["trees"] = "trace"
                        r.guess("trees only %s: the world's own trees held to a trace"
                                % _say(where))
                    continue
                r.guess("no %s: nothing is placed unless asked anyway" % key)
                continue
            n, _ = _count_before(clause, start, r, off)
            if n is None:
                n = 1 if not _plural(m.group(0)) else 3
                if n == 3:
                    r.guess("%s without a number: 3" % key)
            where, span = _relation(clause, r, off, end)
            if where is None:
                where = _position(clause, r, off) or {"region": "field"}
            o = {"key": key, "count": n, "where": where}
            if in_rounds and raw.get("modes"):
                o["modes"] = list(raw["modes"])
            objects.append(o)
            r.said("object %s x%d %s" % (key, n, _say(where)))
            for t in _thing_hits(clause):
                if t[2] and t[0] >= end and t[2] not in want:
                    r.take(t[4], off)
                    want.append(t[2])
                    r.said("want %s (the objects stand on it)" % t[2])
            continue
        team = re.search(r"\b(blau\w*|blue|rot\w*|red|gruen\w*|green|gelb\w*|yellow)\b(\s+team)?",
                         clause)
        team_id = None
        if team:
            team_id = {"blau": "blue", "rot": "red", "gruen": "green", "gelb": "yellow"}.get(
                re.sub(r"(e|en|es|er)$", "", team.group(1)), team.group(1))
            team_id = {"blu": "blue"}.get(team_id, team_id)
            r.take(team, off)
            raw.setdefault("sides", "2")
        if not things:
            before_pos = len(r.consumed)
            pos = _position(clause, r, off)
            fm = re.search(r"\b(flags?|flaggen?)\b", clause) if pos is not None else None
            if fm is not None:
                anchors.append({"what": "flag", "where": pos})
                last_thing[0] = (None, "flag")
                r.take(fm, off)
                r.said("anchor flag %s" % _say(pos))
                continue
            if pos is not None and last_thing[0] is None and any(
                    off <= a < off + len(clause) for a, b in r.consumed[:before_pos]
                    if (b - a) > 2):
                r.guess("%r: the place of what was read there" % clause.strip())
                continue
            if pos is not None and last_thing[0] is not None:
                things = [(0, 0, last_thing[0][0], last_thing[0][1],
                           re.match(r"", clause))]
                r.guess("%r: the %s of the clause before" % (clause.strip(),
                                                             last_thing[0][1] or last_thing[0][0]))
                clause = clause
                ellipsis_pos = pos
            elif pos is not None and any(re.search(p, clause) for p, _, _, _ in COMPARATIVES):
                r.guess("%r: read for the whole map (a region on its own is a refine: "
                        "mapgen refine OUT \"%s\")" % (clause.strip(), clause.strip()))
                continue
            elif pos is not None:
                r.not_understood.append("%r: a place without a thing to put there"
                                        % clause.strip())
                continue
            else:
                continue
        else:
            ellipsis_pos = None
        start, end, feat, what, m = things[0]
        last_thing[0] = (feat, what)
        r.take(m, off)
        neg = _negated(low, off + start) and not _affirmed(low, feat)
        exc = _exception(r, low, off + start) if neg else None
        if exc is not None:
            where, n = exc
            _take_negation(r, low, off + start)
            if feat:
                want.append(feat)
                raw.setdefault("amounts", {})[feat] = "trace"
            if what:
                a = {"what": what, "where": where}
                if n and n > 1:
                    a["count"] = n
                elif where.get("compass") not in ("c", "corners") and "edge" not in where:
                    a["once"] = True
                anchors.append(a)
            r.said("%s only %s, nowhere else (the exception)" % (what or feat, _say(where)))
            continue
        if neg:
            _take_negation(r, low, off + start)
            for t in things:
                r.take(t[4], off)
                if t[2] and t is not things[0] and not _negated(low, off + t[0]):
                    want.append(t[2])
                    r.said("want %s" % t[2])
                elif t[2]:
                    avoid.append(t[2])
                    r.said("avoid %s" % t[2])
                elif t[3] == "spawns":
                    r.not_understood.append("%r: no spawns at all is not a map" % clause.strip())
            if raw.get("theme") == "lava" and any(
                    t[2] == "lava" or re.search(r"\blava\b", t[4].group(0) or "")
                    for t in things):
                raw.pop("theme")
            continue
        if re.search(ONLY + r"\s+(\w+\s+)?" + re.escape(m.group(0)), clause) and feat in (
                "ramps",):
            want.append("ramps_only")
            r.take(re.search(ONLY, clause), off)
            r.said("want ramps only")
        n, counted = _count_before(clause, start, r, off)
        size_adj = None
        for pat, val in SIZE_ADJ:
            sm = re.search(pat + r"\s+(\w+\s+)?$", clause[:start])
            if sm:
                size_adj = val
                r.take(sm, off)
                break
        where, span = _relation(clause, r, off, end)
        skip = [span] if span else []
        if where is None:
            where = _position(clause, r, off, skip)
        else:
            extra = _position(clause[:span[0]] if span else clause, r, off)
            if extra and where.get("relation") in ("on", "above"):
                pass
        height = _height(clause, r, off)
        if re.search(ONLY, clause[:start + 1]) and what == "spawns":
            r.take(re.search(ONLY, clause), off)
        if what == "world_spawn":
            if where is None:
                r.not_understood.append("%r: where should the world spawn be?" % clause.strip())
                continue
            a = {"what": "world_spawn", "where": where}
            anchors.append(a)
            r.said("world spawn %s" % _say(where))
            continue
        if ellipsis_pos is not None:
            where = ellipsis_pos
        sp = re.search(r"(\d+)\s*(apart|auseinander|voneinander entfernt|abstand)|"
                       r"(abstand|spacing|mindestens)\s*(von\s*)?(\d+)", clause)
        spacing = None
        if sp:
            spacing = int(sp.group(1) or sp.group(5))
            r.take(sp, off)
        if team_id and what == "spawns":
            players = raw.get("players") or 16
            a = {"what": "spawns", "where": where or {"anywhere": True},
                 "count": n if counted and n else players // 2, "id": team_id}
            if not (counted and n):
                r.guess("%s spawns: %d (half of %d players)" % (team_id, players // 2, players))
            anchors.append(a)
            r.anchor_ids.setdefault(team_id, team_id)
            r.said("anchor %s spawns %s" % (team_id, _say(a["where"])))
            continue
        if what is None and feat and where is None:
            where = _slot_relation(clause, r, off, end)
        if what is None and feat and where and where.get("relation") and isinstance(
                where.get("of"), str):
            q = {"kind": "place", "what": feat, "relation": where["relation"],
                 "of": where["of"]}
            hm = re.search(r"\b(hidden|secret|versteckt\w*|geheim\w*|verborgen\w*)\b", clause)
            if hm:
                r.take(hm, off)
                q["hidden"] = True
            reqs = raw.setdefault("requests", [])
            if q not in reqs:
                reqs.append(q)
            want.append(feat)
            if where["of"] in briefmod.FEATURES:
                want.append(where["of"])
            r.said("%s%s %s %s (asked; kept until a generator places it)" % (
                "hidden " if q.get("hidden") else "", feat, where["relation"].replace("_", " "),
                where["of"]))
            continue
        if what is None or (where is None and not counted and size_adj is None
                            and height is None and spacing is None):
            for t in things[1:]:
                r.take(t[4], off)
                if t[2] and _negated(low, off + t[0]):
                    _take_negation(r, low, off + t[0])
                    avoid.append(t[2])
                    r.said("avoid %s" % t[2])
                elif t[2]:
                    want.append(t[2])
                    r.said("want %s" % t[2])
            if feat:
                want.append(feat)
                r.said("want %s" % feat)
                if n and counted and feat == "lanes":
                    reqs = raw.setdefault("requests", [])
                    q = {"kind": "lanes", "count": n}
                    if q not in reqs:
                        reqs.append(q)
                    r.said("%d lanes asked (the map's lanes between the bases are counted "
                           "against it)" % n)
            elif what in ("spawns", "base", "point", "flag", "hill", "platform", "start_line",
                          "finish"):
                if where is None and what == "hill":
                    a = {"what": "hill", "where": {"compass": "c"}}
                    anchors.append(a)
                    r.guess("a hill without a place: in the middle")
                elif what in ("start_line", "finish") or where is None:
                    r.said("%s mentioned" % what)
            continue
        a = {"what": what}
        a["where"] = where or {"anywhere": True}
        if n and (counted or n > 1):
            a["count"] = n
        elif (n == 1 or (n is None and not _plural(m.group(0)))) and where is not None \
                and where.get("compass") not in ("c", "corners") \
                and "edge" not in where and "relation" not in where:
            a["once"] = True
        if spacing:
            a["spacing"] = spacing
        prev = [x for x in anchors if x["what"] == what]
        if prev and where is None and not counted and (spacing or size_adj or height is not None):
            for k in ("spacing", "size", "height"):
                if k in a:
                    prev[-1][k] = a[k]
            r.said("%s: %s" % (prev[-1].get("id", what), ", ".join(
                "%s %s" % (k, a[k]) for k in ("spacing", "size", "height") if k in a)))
            continue
        if size_adj:
            a["size"] = size_adj
        if height is not None:
            a["height"] = height
        if feat:
            want.append(feat)
        if team_id and what in ("base", "flag"):
            a["team"] = team_id
        aid = "%s%d" % (what, sum(1 for x in anchors if x["what"] == what) + 1)
        a["id"] = aid
        r.anchor_ids.setdefault(what, aid)
        anchors.extend(r.pending)
        r.pending = []
        anchors.append(a)
        r.last_anchor = aid
        r.said("anchor %s%s%s %s%s" % ("%d " % a["count"] if a.get("count") else "",
                                       "%s " % a["team"] if a.get("team") else "", what,
                                       _say(a["where"]),
                                     " (%s)" % size_adj if size_adj else ""))
        for t in things[1:]:
            if span and span[0] <= t[0] < span[1]:
                continue
            r.take(t[4], off)
            if t[2]:
                if _negated(low, off + t[0]):
                    avoid.append(t[2])
                else:
                    want.append(t[2])
    want = list((raw.get("features") or {}).get("want", [])) + want
    avoid = list(avoid) + [a for a in (raw.get("features") or {}).get("avoid", [])
                           if a in ("lanterns", "glowing_mushrooms", "crystals", "dark")]
    if "spawn_safety" in want:
        want = [w for w in want if w != "spawn_safety"]
        avoid.append("spawn_camping")
    if "spawn_safety" in avoid:
        avoid = [a for a in avoid if a != "spawn_safety"]
        want.append("spawn_camping")
    for f in dict.fromkeys(w for w in want if w in avoid):
        r.questions.append({"ask": "%s: with or without?" % f.replace("_", " "),
                            "options": ["with %s" % f.replace("_", " "),
                                        "without %s" % f.replace("_", " ")]})
    want = [w for w in dict.fromkeys(want) if w not in avoid]
    if want or avoid:
        raw["features"] = {"want": want, "avoid": sorted(set(avoid))}
    referred = set()
    for x in anchors + objects:
        of = (x.get("where") or {}).get("of")
        referred.update(of if isinstance(of, list) else [of])
    for a in anchors:
        if a.get("id") not in referred:
            a.pop("id", None)
    if anchors:
        raw["anchors"] = anchors
    if objects:
        raw["objects"] = objects
        if in_rounds and not raw.get("modes"):
            r.not_understood.append("objects in the rounds: name the mode whose rounds use them")
    elif in_rounds:
        r.not_understood.append("'in the rounds' without objects to put there")
def _say(where):
    if not where:
        return "anywhere"
    if "compass" in where:
        return {"c": "in the middle", "corners": "in the corners"}.get(
            where["compass"], "in the %s" % where["compass"])
    if "edge" in where:
        return "at the edge"
    if "clock" in where:
        return "at %d o'clock" % where["clock"]
    if "relation" in where:
        of = where.get("of")
        return "%s %s" % (where["relation"].replace("_", " "),
                          " and ".join(of) if isinstance(of, list) else of)
    if where.get("region") == "field" or where.get("anywhere"):
        return "anywhere on the map"
    return str(where)
_SUBSUMING = []
def _subsumed(r, word):
    if _SUBSUMING or len(word) < 5:
        return False
    _SUBSUMING.append(word)
    try:
        u = understand(word)
    except Exception:
        return False
    finally:
        _SUBSUMING.pop()
    raw = u.raw
    f = raw.get("features") or {}
    have = (r.raw.get("features") or {})
    if u.not_understood or not f.get("want") or f.get("avoid"):
        return False
    if not set(f["want"]) <= set(have.get("want") or ()):
        return False
    for k, v in raw.items():
        if k in ("wish", "features"):
            continue
        if k in ("family", "theme") and r.raw.get(k) in (None, v):
            continue
        return False
    return True
def _leftovers(r, low):
    mask = [False] * len(low)
    for a, b in r.consumed + r.soft:
        for i in range(max(0, a), min(len(low), b)):
            mask[i] = True
    fillers = set()
    if LEXICON:
        from . import lexicon
        fillers = set(lexicon.data()["fillers"])
    r.free = []
    for off, clause in _split(low):
        left = []
        for m in re.finditer(r"[a-z0-9']+", clause):
            a, b = off + m.start(), off + m.end()
            if any(mask[a:b]):
                continue
            w = m.group(0)
            stop = w in STOP or w in NUMBERS or len(w) <= 1 or w in fillers
            r.free.append((a, b, w, stop))
            if stop or w.startswith("zzlx"):
                continue
            left.append(w)
        if left:
            r.not_understood.append(" ".join(left))
            r.heard_in[" ".join(left)] = clause.strip()
