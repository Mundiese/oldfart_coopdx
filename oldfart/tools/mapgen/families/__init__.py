import importlib
REGISTRY = {}
ALIASES = {"hide": "hunt", "chase": "hunt", "ctf": "objective",
           "domination": "objective", "koth": "objective", "sumo": "knockoff"}
FAILED = {}
POLISHED = {"objective": ("objective", "mirror"), "knockoff": ("knockoff", "turn4"),
            "party": ("party", "turn4")}
NATURAL_GROUND = {"garden": "grass", "ice": "snow", "desert": "sand", "castle": "stone",
                  "lava": "stone", "wood": "grass", "sky": "grass"}
NATURAL_GROUND_FAMILIES = ("explore", "hide")
def natural_ground(brief):
    if brief["family"] not in NATURAL_GROUND_FAMILIES:
        return "auto"
    theme = brief["theme"] if brief["theme"] not in (None, "auto") else "garden"
    return NATURAL_GROUND.get(theme, "auto")
LAVA_WEATHER = "lava bubbles, over lava"
def _painted(build):
    def run(brief, streams, reference=False, **kw):
        from .. import solids, kit
        from ..brief import dna
        given = brief.get("dna") or {}
        kit.PALETTE_DNA.clear()
        kit.PALETTE_FAMILY.clear()
        if not reference:
            kit.PALETTE_DNA.update({k: dna(brief, k) for k in ("coherence", "age", "nature")
                                    if k in given})
            kit.PALETTE_FAMILY["family"] = brief.get("family")
        arena, meta = build(brief, streams, reference=reference, **kw)
        polish = POLISHED.get(getattr(build, "__module__", "").rsplit(".", 1)[-1])
        if polish and not reference and brief["family"] == polish[0] \
                and not meta.get("polished"):
            from .. import layout
            sym = meta.get("symmetry")
            if sym not in ("turn4", "turn2", "mirror", "mirror2", "none"):
                sym = polish[1]
            if sym == "mirror" and (meta.get("params") or {}).get("turn", 0) % 2:
                sym = "mirrorx"
            arena, rep = layout.polish(arena, brief, streams, sym=sym, fill_on=False,
                                       dress_on=True)
            meta["beauty"] = rep.get("beauty")
            meta["kit"] = rep.get("kit")
        from .. import kit
        look = arena.get("look")
        if isinstance(look, dict):
            vis = kit.venue_visuals(brief.get("visuals") or [], brief["theme"],
                                    brief["family"])
            if vis:
                look["visuals"] = vis
            from .. import mood as moodmod
            m = moodmod.for_brief(brief.get("mood"))
            if m:
                look["mood"] = m
            lava = any(p.get("tex") in ("lava", "magmacrust") or p.get("kind") == "lava"
                       for p in arena.get("pieces") or [])
            mm = look.get("mood") if isinstance(look.get("mood"), dict) else {}
            if lava and not mm.get("weather") and not reference:
                mm = dict(mm, weather=LAVA_WEATHER)
                mm.pop("preset", None)
                look["mood"] = mm
            if not reference:
                from .. import autolight
                sky = autolight.night_sky(look.get("mood"), look.get("sky"), brief.get("sky"))
                if sky:
                    look["sky"] = sky
                want = set((brief.get("features") or {}).get("want") or ())
                avoid = set((brief.get("features") or {}).get("avoid") or ())
                dark = bool((look.get("mood") or {}).get("darkness")) or "dark" in want
                notes_ = meta.setdefault("notes", [])
                if (dark or "lanterns" in want) and "lanterns" not in avoid:
                    lamps = autolight.light_path(arena, lots="lanterns" in want)
                    arena["pieces"] = arena["pieces"] + lamps
                    if lamps:
                        notes_.append("lights: %d lamps along the paths" % len(lamps))
                if (dark or "glowing_mushrooms" in want) and "glowing_mushrooms" not in avoid:
                    glow = autolight.glow_mushrooms(arena, everyone="glowing_mushrooms" in want)
                    arena["pieces"] = arena["pieces"] + glow
                    if glow:
                        notes_.append("lights: %d mushrooms glow" % (len(glow) // 2))
        ground = brief.get("ground") or "auto"
        if ground == "auto" and brief["family"] in NATURAL_GROUND_FAMILIES:
            ground = natural_ground(brief)
        if arena.get("level") == "empty" and ground not in ("auto", "tiles"):
            arena["ground"] = ground
        if not reference:
            from .. import contract, detail
            meta["detail"] = detail.run(arena, brief, meta, theme=contract.theme_for(brief))
            own = arena["pieces"]
            from .. import values
            pal_wish = (brief.get("palette") or {})
            keep = [t for r in ("wall", "cover") for t in (pal_wish.get(r) or [])]
            meta.setdefault("notes", [])
            if "tops" not in ((brief.get("features") or {}).get("avoid") or ()):
                from .. import tops
                meta["notes"] += tops.apply(own, brief["theme"], brief.get("budget"))
            meta["notes"] += values.measured(own, brief["theme"], brief["family"], keep)
            arena["pieces"], notes = solids.resolve(own)
            kit.surfaces(arena["pieces"])
            if (meta.get("detail") or {}).get("pieces") and detail._defaulted(brief) \
                    and arena.get("budget") is not None:
                arena["budget"] = max(arena["budget"], min(detail.allowance(brief, arena),
                                                           detail.used_of(arena)))
            if arena["pieces"] is not own:
                from .. import guards
                meta["cuts"] = guards.function_cuts(own, arena["pieces"])
            if arena["pieces"] is not own:
                meta["raw_pieces"] = [dict(p) for p in own]
            meta.setdefault("notes", [])
            meta["notes"] += [n for n in notes if n not in meta["notes"]]
        kit.PALETTE_DNA.clear()
        kit.PALETTE_FAMILY.clear()
        return arena, meta
    run.painted = True
    run.__doc__ = build.__doc__
    run.__wrapped__ = build
    return run
def register(name, module_name=None):
    module_name = module_name or name
    try:
        mod = importlib.import_module("." + module_name, __name__)
    except ImportError as exc:
        FAILED[name] = str(exc)
        return None
    if not callable(getattr(mod, "build", None)):
        FAILED[name] = "families/%s.py has no build()" % module_name
        return None
    if not getattr(mod.build, "painted", False):
        mod.build = _painted(mod.build)
    REGISTRY[getattr(mod, "FAMILY", name)] = mod
    if getattr(mod, "FAMILY", name) != name:
        REGISTRY[name] = mod
    return mod
def get(name):
    return REGISTRY.get(name) or REGISTRY.get(ALIASES.get(name, ""))
def built():
    return tuple(sorted(REGISTRY))
register("shooter")
register("objective")
register("knockoff")
register("party")
register("race")
register("course")
register("hunt")
register("explore")
