from . import boundary, movement, v1
def _rects(pieces):
    m = v1.arenas_module()
    out = []
    for p in pieces:
        x0, x1, z0, z1, _ = m.footprint(p)
        out.append((x0, x1, z0, z1))
    return out
def _gap(a, b):
    dx = max(0.0, max(a[0], b[0]) - min(a[1], b[1]))
    dz = max(0.0, max(a[2], b[2]) - min(a[3], b[3]))
    return max(dx, dz)
def _top(p):
    return p["y"] + max(p.get("solid_h", p["h"]), p["h"], 0)
def _where(p):
    return "%s %s at (%d, %d, %d)" % (p["kind"], p["tex"], p["x"], p["y"], p["z"])
def reachable(arena, skip=()):
    ps = arena["pieces"]
    rects = _rects(ps)
    skip = set(skip)
    usable = [i for i, p in enumerate(ps) if i not in skip and not boundary.is_invisible(p)
              and p.get("kind") != "water"]
    seeds = set()
    for s in arena.get("spawns") or []:
        for i in usable:
            r = rects[i]
            if r[0] - 1 <= s["x"] <= r[1] + 1 and r[2] - 1 <= s["z"] <= r[3] + 1 \
                    and abs(_top(ps[i]) - s["y"]) <= 60:
                seeds.add(i)
    seen, todo = set(seeds), list(seeds)
    while todo:
        a = todo.pop()
        ta = _top(ps[a])
        for b in usable:
            if b in seen:
                continue
            if _gap(rects[a], rects[b]) <= movement.JUMP_GAP and _top(ps[b]) <= ta + movement.REACH:
                seen.add(b)
                todo.append(b)
    return seen
def hiding_faults(arena):
    ps = arena["pieces"]
    maze = [i for i, p in enumerate(ps) if p.get("tag") == "maze"]
    if not maze:
        return []
    rects = _rects(ps)
    got = reachable(arena, skip=maze)
    out = []
    for i in maze:
        t = _top(ps[i])
        for a in sorted(got):
            if _gap(rects[a], rects[i]) <= movement.JUMP_GAP and _top(ps[a]) + movement.REACH >= t:
                out.append("hiding: the maze wall %s (top %d) is reached from %s (top %d + %d, "
                           "no wall kick) - the maze is seen from above"
                           % (_where(ps[i]), t, _where(ps[a]), _top(ps[a]), movement.REACH))
                break
    return out
def escape_faults(arena):
    ps = arena["pieces"]
    rules = movement.Rules.of(arena)
    bounce = rules.interactions
    if rules.flight and boundary.edge_pieces(ps):
        return ["escape: the map's movement rules fly (%s) - no edge holds; a lid or a "
                "kill plane does" % ", ".join(rules.rows)]
    edge = boundary.edge_pieces(ps)
    if not edge:
        return []
    rects = _rects(ps)
    es = set(edge)
    cols = {}
    for i in edge:
        key = tuple(int(round(v)) for v in rects[i])
        cols.setdefault(key, []).append(i)
    out = []
    inner = [i for i, p in enumerate(ps) if i not in es and not boundary.is_invisible(p)
             and p.get("kind") != "water"]
    for key, members in sorted(cols.items()):
        top = max(_top(ps[i]) for i in members)
        why = None
        for b in inner:
            g = _gap(rects[b], key)
            tb = _top(ps[b])
            if movement.CHIMNEY_MIN <= g <= movement.KICK_GAP \
                    and min(tb, top) + movement.KICK_REACH >= top and ps[b]["h"] >= 400:
                why = ("by a wall-kick chimney against %s (top %d + %d)"
                       % (_where(ps[b]), tb, movement.KICK_REACH))
                break
        if not why:
            for b in inner:
                tb = _top(ps[b])
                up = movement.reach_at(_gap(rects[b], key))
                if tb + up >= top:
                    why = "from %s (top %d + %d)" % (_where(ps[b]), tb, round(up))
                    break
        if not why and bounce:
            for b in inner:
                tb = _top(ps[b])
                if _gap(rects[b], key) <= movement.JUMP_GAP and tb + movement.PARTNER_BOUNCE >= top:
                    why = ("from %s by a partner bounce (top %d + %d, player interactions on)"
                           % (_where(ps[b]), tb, movement.PARTNER_BOUNCE))
                    break
        if why:
            p = ps[members[0]]
            out.append("escape: the map edge %s tops at %d - a player gets over it %s"
                       % (_where(p), top, why))
    return out
