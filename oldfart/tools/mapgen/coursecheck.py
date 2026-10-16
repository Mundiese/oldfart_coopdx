from . import coursemoves as cm
RUN = 960.0
JUMPS = ("gap", "climb", "shaft", "kickup", "pound", "hop", "blj")
RESPAWN_S = 4.0
NET_BACK_S = 3.0
def _label(j):
    move = cm.MOVE_LABEL.get(j.get("move"), j.get("move") or "move")
    kind = j.get("kind")
    over = j.get("over")
    tail = " over %s" % over if over in ("lava", "void") else ""
    if kind == "gap" or kind == "hop":
        bits = ["%s %d" % (move, j["gap"])]
        if j.get("rise", 0) > 0:
            bits.append("up %d" % j["rise"])
        elif j.get("rise", 0) < 0:
            bits.append("down %d" % -j["rise"])
        if kind == "hop":
            bits.append("onto a moving platform")
        return " ".join(bits) + tail
    if kind == "climb":
        return "%s %d up" % (move, j["rise"])
    if kind == "beam":
        return "a %d beam %d long" % (j.get("width", 400), j.get("length", 1600)) + tail
    if kind == "shaft":
        return "wall kicks %d up a %d shaft" % (j["height"], j["width"])
    if kind == "kickup":
        return "side flip into wall kick %d up" % j["ledge"]
    if kind == "pound":
        return "ground pound onto a %d post %d down" % (j.get("post", 200), j["drop"]) + tail
    if kind == "ride":
        return "%s ride" % (j.get("what") or "moving platform")
    if kind == "blj":
        return "BLJ skip over %d" % j["gap"]
    return move
def judge(j, tier):
    kind = j.get("kind")
    move = j.get("move", "jump")
    grab = tier.grab if j.get("grab") is None else j["grab"]
    lw = -1
    secs = 0.0
    if kind == "gap":
        lw = cm.leeway(move, int(j["gap"]), int(j.get("rise", 0)), int(j.get("depth", 600)),
                       int(j.get("runup", 400)), bool(grab))
        secs = cm.airtime(move) / 30.0 + cm.SETUP_S.get(move, 0.0)
    elif kind == "climb":
        lw = cm.climb_leeway(move, int(j["rise"]), int(j.get("runway", 800)), bool(grab))
        secs = cm.airtime(move) / 30.0 + cm.SETUP_S.get(move, 0.0)
    elif kind == "shaft":
        c = cm.chimney_climb(int(j["width"]), j["policy"])
        if c is not None:
            kicks = cm.kicks_for(j["height"], j["width"], j["policy"])
            lw = 3 if j["policy"] == "easy_late_kicks" else 2
            secs = (kicks or 1) * c[1] / 30.0 + 1.0
            j["kicks"] = kicks
    elif kind == "kickup":
        lw = cm.kickup_leeway(int(j["width"]), int(j["ledge"]), j.get("first", "sideflip"))
        secs = 1.6
    elif kind == "pound":
        lw = cm.pound_window(int(j["gap"]), int(j["drop"]), int(j.get("post", 200)),
                             int(j.get("runup", 0)), move if move != "groundpound" else
                             "standjump") - 1
        secs = 1.8
    elif kind == "ride":
        lw = int(j.get("window", 0)) - 1
        secs = float(j.get("ride_s", 0.0)) + float(j.get("wait_s", 0.0))
    elif kind == "hop":
        lw = int(j.get("window", 0)) - 1
        secs = cm.airtime("jump") / 30.0 + float(j.get("wait_s", 0.0))
    elif kind == "blj":
        lw = 0 if cm.blj_leap(int(j["gap"]), int(j.get("rise", 0))) else -1
        secs = 4.0
    elif kind == "beam":
        lw = max(0, (int(j.get("width", 400)) - 100) // 50)
        secs = 0.0
    need = int(j.get("need", tier.leeway))
    risk_move = "wallkick" if kind == "shaft" else ("kickup" if kind == "kickup" else
                                                    ("groundpound" if kind == "pound" else move))
    p = cm.fail_chance(tier, risk_move, max(lw, 0))
    if kind == "ride":
        p = min(p, 0.01) if lw >= 30 else p
    if kind == "beam":
        p = min(0.2, tier.fail * 0.1 * (400.0 / max(100, int(j.get("width", 400)))) *
                (int(j.get("length", 1600)) / 1600.0))
    return {"ok": lw >= 0, "leeway": lw, "need": need, "p": round(p, 4),
            "seconds": round(secs, 2), "label": _label(j)}
def walk(route, tier, beats_s=None):
    out = {"tier": tier.name, "label": tier.label, "moves": len(route), "infeasible": [],
           "below_tier": [], "hardest": None, "hotspots": []}
    clean = float(beats_s or 0.0)
    expected = clean
    costs = []
    worst = None
    for i, j in enumerate(route):
        r = judge(j, tier)
        j["leeway"] = r["leeway"]
        j["p"] = r["p"]
        if not r["ok"]:
            out["infeasible"].append({"i": i, "label": r["label"], "leeway": r["leeway"]})
        elif r["leeway"] < r["need"] and j.get("kind") not in ("ride",):
            out["below_tier"].append({"i": i, "label": r["label"], "leeway": r["leeway"],
                                      "need": r["need"]})
        clean += r["seconds"]
        over = j.get("over")
        if over in ("void", "lava"):
            back = float(j.get("since_cp", 0.0)) + RESPAWN_S
        else:
            back = float(j.get("beat_s", 0.0)) + NET_BACK_S
        p = r["p"]
        retries = p / (1.0 - p)
        lost = retries * (back + r["seconds"])
        expected += r["seconds"] + lost
        costs.append((lost, i, r["label"], p))
        key = (p, -r["leeway"], j.get("gap", 0) or j.get("rise", 0) or j.get("height", 0))
        if j.get("kind") in JUMPS and (worst is None or key > worst[0]):
            worst = (key, i, r)
    if worst is not None:
        _, i, r = worst
        out["hardest"] = {"i": i, "text": r["label"], "leeway": r["leeway"], "p": r["p"],
                          "kind": route[i].get("kind"), "move": route[i].get("move"),
                          "over": route[i].get("over")}
    costs.sort(reverse=True)
    out["hotspots"] = [{"i": i, "text": label, "p": p, "lost_s": round(lost, 1)}
                       for lost, i, label, p in costs[:3] if lost > 0.05]
    out["clean_s"] = round(clean, 1)
    out["expected_s"] = round(expected, 1)
    out["min_leeway"] = min((j.get("leeway", 99) for j in route), default=None)
    out["text"] = card_text(out)
    return out
def card_text(rep):
    if not rep:
        return ""
    h = rep.get("hardest")
    if not h:
        return "Difficulty: %s" % rep.get("label", "")
    return "Difficulty: %s - hardest jump: %s" % (rep.get("label", ""), h["text"])
