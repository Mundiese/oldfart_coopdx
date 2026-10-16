import os
import re
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
RUNTIME = os.path.join(HERE, "standalone", "oldfart_maps.lua.txt")
PIECES = {
    "of_ball.lua": [
        (r"^ball\.MATERIALS = \{", r"^function ball\.unpack\("),
    ],
    "of_gm_football.lua": [
        (r"^local BALL_RADIUS = 100$", "line"),
        (r"^local GRAVITY = ", r"^local STOP_SPEED = "),
        (r"^football\.BALL_DEFAULT = ", r"^function football\.feel\("),
        (r"^football\.TOUCHES = \{", r"^function football\.dribble_bounce\("),
        (r"^local function clamp_speed\(", r"^local function clamp_speed\("),
        (r"^local function facing\(m\)", r"^function football\.touch\("),
        (r"^football\.CURL_DEAD = ", r"^function football\.curl_of\("),
        (r"^football\.CHARGE_GAIN = ", "line"),
    ],
    "of_hud.lua": [
        (r"^hud\.C = \{", r"^hud\.C = \{"),
        (r"^hud\.TYPE = \{", r"^hud\.MOTION = "),
        (r"^local function clamp01\(", r"^function hud\.progress\("),
        (r"^function hud\.colour\(", r"^function hud\.diamond\("),
        (r"^function hud\.plate\(", r"^function hud\.plate\("),
        (r"^local function face_for\(", r"^function hud\.cap\("),
        (r"^local function aligned_left\(", r"^function hud\.fit\("),
        (r"^function hud\.countdown_centre\(", r"^function hud\.go\("),
    ],
    "of_venues.lua": [
        (r"^venues\.LIGHTS_NEAR = ", r"^function venues\.lights_drop\("),
        (r"^venues\.CULL_ASPECT = ", r"^function venues\.cull_release\("),
    ],
    "of_spawner.lua": [
        (r"^local AREA_LOOP = ", r"^spawner\.AREA_TIMED = \{"),
    ],
    "of_gamemodes.lua": [
        (r"^function modes\.draw_count_digit\(", r"^function modes\.draw_count_title\("),
    ],
    "of_venues.lua#select": [("block", "select")],
    "of_venues.lua#water": [("block", "water")],
    "of_venues.lua#dance": [("block", "dance")],
    "of_venues.lua#arrival": [("block", "arrival")],
    "of_venues.lua#fogslots": [("block", "fogslots")],
    "of_venues.lua#counter": [("block", "counter")],
    "of_venues.lua#sky": [("block", "sky")],
    "of_music.lua#stream": [("block", "stream")],
    "of_music.lua#stall": [("block", "stall")],
    "of_celebrate.lua#weather": [("block", "weather")],
    "of_modifiers.lua#fogpaint": [("block", "fogpaint")],
    "of_spawner.lua#wiggler": [("block", "wiggler")],
    "of_spawner.lua#movers": [("block", "movers")],
    "of_spawner.lua#trampoline": [("block", "trampoline")],
    "of_spawner.lua#fixes": [("block", "fixes")],
    "of_spawner.lua#wallrun": [("block", "wallrun")],
    "of_ball.lua#ride": [("block", "ride")],
    "of_util.lua#rings": [("block", "rings")],
    "of_venues.lua#selectlogic": [("block", "selectlogic")],
}
class DriftError(ValueError):
    pass
def file_of(region):
    return region.split("#", 1)[0]
BLOCK_BEGIN = "-- BEGIN SHARED %s"
BLOCK_END = "-- END SHARED %s"
def block(lines, name):
    head, tail = BLOCK_BEGIN % name, BLOCK_END % name
    first = [i for i, ln in enumerate(lines) if ln.rstrip() == head]
    if len(first) != 1:
        raise DriftError("%d lines read %r (one wanted)" % (len(first), head))
    end = next((i for i in range(first[0] + 1, len(lines)) if lines[i].rstrip() == tail), None)
    if end is None:
        raise DriftError("%r never ends (%r)" % (head, tail))
    return lines[first[0] + 1:end]
OF_WORD = re.compile(r"(?<![\w.])OF\s*[.\[]")
def blocks_free_of_of(root=REPO):
    out = []
    for region, specs in PIECES.items():
        for spec in specs:
            if spec[0] != "block":
                continue
            with open(os.path.join(root, file_of(region)), encoding="utf-8") as handle:
                lines = handle.read().split("\n")
            for ln in block(lines, spec[1]):
                code = ln.split("--", 1)[0]
                if OF_WORD.search(code):
                    out.append((region, ln.strip()))
    return out
def piece(lines, start, through):
    first = next((i for i, ln in enumerate(lines) if re.search(start, ln)), None)
    if first is None:
        raise DriftError("no line matches %r" % start)
    if through == "line":
        return lines[first:first + 1]
    at = next((i for i in range(first, len(lines)) if re.search(through, lines[i])), None)
    if at is None:
        raise DriftError("no line matches %r" % through)
    if re.search(r"^(local )?function |^\w[\w.]* = function", lines[at]) or lines[at].rstrip().endswith("{"):
        closer = "}" if lines[at].rstrip().endswith("{") else "end"
        end = next((i for i in range(at + 1, len(lines)) if lines[i].rstrip() == closer), None)
        if end is None:
            raise DriftError("%r never closes" % through)
    else:
        end = at
    return lines[first:end + 1]
def source(name, root=REPO):
    with open(os.path.join(root, file_of(name)), encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    out = []
    for start, through in PIECES[name]:
        out.extend(block(lines, through) if start == "block" else piece(lines, start, through))
        out.append("")
    return "\n".join(out).rstrip("\n")
def splice(text, root=REPO):
    if "-- >>> " not in text:
        return text
    for name in PIECES:
        if not os.path.isfile(os.path.join(root, file_of(name))):
            continue
        head, tail = "-- >>> %s\n" % name, "\n-- <<< %s" % name
        i = text.find(head)
        j = text.find(tail, i + 1)
        if i < 0 or j < 0:
            raise DriftError("the runtime has no %r region" % name)
        text = text[:i + len(head)] + source(name, root) + text[j:]
    return text
def main(argv):
    with open(RUNTIME, encoding="utf-8") as handle:
        text = handle.read()
    named = blocks_free_of_of()
    if named:
        for region, line in named:
            print("%s: a shared block names OF: %s" % (region, line))
        return 1
    fresh = splice(text)
    if fresh == text:
        print("the runtime carries the mod's ball as it is")
        return 0
    if "--write" in argv:
        with open(RUNTIME, "w", encoding="utf-8") as handle:
            handle.write(fresh)
        print("wrote", RUNTIME)
        return 0
    print("the runtime's copy of the mod's ball drifted: run tools/mapgen/sharedcode.py --write")
    return 1
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
