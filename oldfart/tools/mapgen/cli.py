import argparse
import json
import os
import re
import time
from . import anchors, api
from . import brief as briefmod
from . import checks, cells, explain, export, generate as gen, kit, refine as refmod, v1
from . import wish as wishmod
from .brief import Brief, BriefError
from .skeleton import AnchorConflict
def _anchor(text):
    parts = text.split(":")
    if len(parts) < 2:
        raise argparse.ArgumentTypeError("--anchor wants what:where, e.g. tower:nw")
    what, where = parts[0], parts[1]
    a = {"what": what}
    w = where.lower()
    if "," in w:
        x, z = w.split(",", 1)
        a["where"] = {"x": float(x), "z": float(z)}
    elif w.rstrip("h").isdigit() or w.endswith("oclock"):
        a["where"] = {"clock": int(w.replace("oclock", "").rstrip("h"))}
    else:
        a["where"] = {"compass": w}
    for flag in parts[2:]:
        if flag == "once":
            a["once"] = True
        elif flag == "soft":
            a["hard"] = False
        elif flag in briefmod.SIZES:
            a["size"] = flag
        else:
            raise argparse.ArgumentTypeError("--anchor flag %r (once, soft, or a size)" % flag)
    return a
def _object(text):
    key, _, count = text.partition(":")
    return {"key": key, "count": int(count) if count else 1}
def _palette(items):
    out = {}
    for item in items or []:
        role, _, texs = item.partition("=")
        out[role] = [t for t in texs.split(",") if t]
    return out or None
BRIEF_FLAGS = ("family", "players", "size", "pace", "symmetry", "sides", "verticality",
               "density", "difficulty", "edge", "boundary", "theme", "style", "sky", "music", "level",
               "budget", "seed", "candidates", "reference", "name", "key")
def add_brief_flags(p):
    g = p.add_argument_group("brief fields (anything left out takes the family's default)")
    g.add_argument("--brief", help="start from this brief.json (flags override it)")
    g.add_argument("--family", help="shooter | objective | knockoff | race | hide | party | "
                   "course (only shooter is built in milestone 1)")
    g.add_argument("--players", type=int, help="2..16 (default 16)")
    g.add_argument("--size", help="tiny | small | medium | large | huge, or ACROSS units "
                   "(e.g. 9000), or SECONDSs walk time (e.g. 9s)")
    g.add_argument("--pace", help="slow | normal | fast")
    g.add_argument("--symmetry", help="auto | none | mirror | turn2 | turn4 | turn8")
    g.add_argument("--sides", help="auto | ffa | 2 | 4")
    g.add_argument("--verticality", help="flat | low | medium | high")
    g.add_argument("--density", help="sparse | medium | dense (cover)")
    g.add_argument("--difficulty", help="easy | normal | hard")
    g.add_argument("--edge", help="auto | walled | rails | void")
    g.add_argument("--boundary", help="auto | visible | invisible | both (the map edge's wall: "
                   "drawn, collision only, or a low rim with an invisible wall over it)")
    g.add_argument("--theme", help="castle | desert | ice | lava | wood | sky | garden")
    g.add_argument("--palette", action="append", metavar="ROLE=TEX[,TEX]",
                   help="texture per role (floor, deck, wall, ramp, bridge, keel, cover, "
                   "accent); repeatable")
    g.add_argument("--style", help="auto | plain | built")
    g.add_argument("--sky", help="a BACKGROUND_* name (default: the theme's)")
    g.add_argument("--music", help="a track of the music page: a SEQ_* name, an imported "
                   "track's file or its name (default: the theme's; `mapgen music` lists them)")
    g.add_argument("--level", help="empty (The Tiles) | empty2 (The Void)")
    g.add_argument("--ground", help="The Tiles' floor: %s" % " | ".join(briefmod.GROUNDS))
    g.add_argument("--visual", action="append", metavar="VISUAL",
                   help="a visual modifier the venue wears (%s); repeatable, none by default"
                   % ", ".join(sorted(briefmod.VISUALS)))
    g.add_argument("--dna", action="append", metavar="KEY=0..1",
                   help="World DNA (%s); repeatable" % ", ".join(briefmod.DNA))
    g.add_argument("--want", action="append", metavar="FEATURE",
                   help="a wanted feature (%s); repeatable" % ", ".join(briefmod.FEATURES))
    g.add_argument("--avoid", action="append", metavar="FEATURE", help="an avoided feature")
    g.add_argument("--anchor", action="append", type=_anchor, metavar="WHAT:WHERE[:once]",
                   help="where you want what: tower:nw, worldspawn:s, pit:c, tower:10h:once, "
                   "base:-3000,0; repeatable")
    g.add_argument("--object", action="append", type=_object, metavar="KEY[:COUNT]",
                   help="a Forge object asked for (recorded; placed from milestone 3)")
    g.add_argument("--budget", type=int, help="objects the venue may use (20 up to the family's measured ceiling, "
                   "tools/mapgen/budget.py)")
    g.add_argument("--seed", type=int, help="the map's seed (default: a hash of the brief)")
    g.add_argument("--candidates", type=int, help="seeded candidates to build (default 6)")
    g.add_argument("--reference", help="skykeep: candidate 0 is built from the Sky Keep's "
                   "own numbers")
    g.add_argument("--preset", help="a named World DNA preset (explain --presets)")
    g.add_argument("--prefab", action="append", metavar="NAME",
                   help="a prefab from the library to lay (explain --prefabs)")
    g.add_argument("--name", help="the map's name")
    g.add_argument("--key", help="the venue key for export")
def brief_from_args(args, base=None):
    raw = dict(base or {})
    if getattr(args, "brief", None):
        with open(args.brief, encoding="utf-8") as handle:
            loaded = json.load(handle)
        for k in loaded.pop("defaulted", []) or []:
            loaded.pop(k, None)
        raw.update(loaded)
    for k in BRIEF_FLAGS:
        v = getattr(args, k, None)
        if v is not None:
            raw[k] = v
    if isinstance(raw.get("size"), str):
        s = raw["size"]
        if s.endswith("s") and s[:-1].replace(".", "").isdigit():
            raw["size"] = {"across_s": float(s[:-1])}
        elif s.isdigit():
            raw["size"] = {"across": int(s)}
        elif "x" in s and all(p.isdigit() for p in s.split("x", 1)):
            w, d = (int(p) for p in s.split("x", 1))
            raw["size"] = {"w": w, "d": d}
    if getattr(args, "palette", None):
        raw["palette"] = _palette(args.palette)
    if getattr(args, "want", None) or getattr(args, "avoid", None):
        f = raw.get("features") or {"want": [], "avoid": []}
        raw["features"] = {"want": list(f.get("want", [])) + list(args.want or []),
                           "avoid": list(f.get("avoid", [])) + list(args.avoid or [])}
    if getattr(args, "anchor", None):
        raw["anchors"] = list(raw.get("anchors") or []) + args.anchor
    if getattr(args, "object", None):
        raw["objects"] = list(raw.get("objects") or []) + args.object
    if getattr(args, "ground", None):
        raw["ground"] = args.ground
    if getattr(args, "visual", None):
        raw["visuals"] = list(raw.get("visuals") or []) + args.visual
    if getattr(args, "preset", None):
        raw["preset"] = args.preset
    if getattr(args, "prefab", None):
        raw["prefabs"] = list(raw.get("prefabs") or []) + args.prefab
    for item in getattr(args, "dna", None) or []:
        k, _, v = item.partition("=")
        try:
            raw.setdefault("dna", {})[k.strip()] = float(v)
        except ValueError:
            raise SystemExit("mapgen: --dna %s: give KEY=0..1" % item)
    return Brief.from_dict(raw, kit.forge_keys())
def _progress(quiet):
    def show(c):
        if quiet:
            return
        s = c.summary()
        print("  candidate %d: %s  quality %-6s %3d pieces  centre %-14s lanes %-8s %.1fs%s"
              % (s["candidate"], "ok    " if s["ok"] else "FAILED", s["quality"], s["pieces"],
                 s.get("centre"), s.get("lane"), s["seconds"],
                 "" if s["ok"] else "  " + "; ".join(s["faults"][:1])))
    return show
MARK = {"placed": "OK", "approximated": "~ ", "refused": "NO", "not yet": "..",
        "unverified": "? "}
def print_reading(reading):
    print("understood:     %s" % ("; ".join(reading.understood) or "-"))
    if reading.assumed:
        print("assumed:        %s" % "; ".join(reading.assumed))
    print("not understood: %s" % ("; ".join(
        ("%s (in %r)" % (n, reading.heard_in[n])) if n in reading.heard_in else n
        for n in reading.not_understood) or "-"))
    heard = getattr(reading, "heard", None)
    if heard:
        print("lexicon:        %s" % "; ".join(heard))
    if getattr(reading, "not_understood", None):
        from . import clarity
        for line in clarity.lines(reading):
            print("                %s" % line)
    later = (reading.raw.get("requests") or []) if hasattr(reading, "raw") else []
    if later:
        print("requested:      %s" % "; ".join(
            "%s%s" % (q["kind"], " x%d" % q["count"] if q.get("count") else "") for q in later))
def print_language(lines):
    for status, aid, note in lines:
        print("  [%s] %s: %s" % (MARK.get(status, status), aid, note))
def run_generate(brief, out, args, wish=None, understood=None, not_understood=None):
    t = time.time()
    print("mapgen: %s, seed %d, %d candidates" % (brief["family"], brief["seed"],
                                                    brief["candidates"]))
    hist = False if getattr(args, "no_history", False) else True
    run = api.run(brief, use_metrics=not args.no_metrics, progress=_progress(args.quiet),
                  history=hist)
    result = run.result
    best = result.best
    print("mapgen: best is candidate %d (quality %s, %s), %d pieces, %d survey points, %.1fs"
          % (best.index, best.quality, best.score["source"] if best.score else "-",
             len(best.arena["pieces"]), len((best.arena.get("survey") or {}).get("points", [])),
             time.time() - t))
    print_language(run.lines)
    for how, aid, note in best.meta.get("anchors", []):
        if not any(aid == l[1] or str(aid).startswith(l[1] + ".") for l in run.lines):
            print("  [%s] %s: %s (the family)" % (MARK.get(how, how), aid, note))
    for n in best.arena.get("report", {}).get("notes", []):
        print("  note: %s" % n)
    if best.arena.get("objects"):
        print("  objects: %d Forge object(s) in the venue table (free play only unless a "
              "mode is named)" % len(best.arena["objects"]))
    text = explain.report(result, wish, understood, not_understood, language=run.lines)
    if getattr(args, "explain", False):
        print("")
        print(text)
    if out:
        files = export.write_out(result, out, text, wish, not_understood,
                                 card=not args.no_card)
        print("mapgen: wrote %s" % ", ".join(files))
    return run
def cmd_generate(args):
    brief = brief_from_args(args)
    if args.explain:
        print(explain.brief_text(brief))
    run_generate(brief, args.out, args)
    return 0
def _backend_reading(args, text):
    reading = wishmod.understand(text)
    name = getattr(args, "backend", None) or "offline"
    if name == "offline":
        return reading, reading.raw
    from . import backends
    from .backends import diff as bdiff
    cfg = backends.Config(backend=name)
    if getattr(args, "model", None):
        if name == "claude":
            cfg.claude_model = args.model
        else:
            cfg.ollama_model = args.model
    got = backends.read(text, cfg)
    for line in got.lines():
        print(line)
    if got.used != "offline":
        print("what %s changed against the offline parser:" % backends.LABELS[name])
        print("  " + bdiff.text(bdiff.diff(reading.raw, got.raw)).replace("\n", "\n  "))
    return reading, got.raw
def cmd_wish(args):
    reading, raw = _backend_reading(args, args.text)
    for k in BRIEF_FLAGS:
        v = getattr(args, k, None)
        if v is not None:
            raw[k] = v
    print_reading(reading)
    brief = Brief.from_dict(raw, kit.forge_keys())
    if args.brief_only or args.explain:
        print(explain.brief_text(brief) if args.explain else brief.to_json())
    if args.brief_only:
        return 0
    run_generate(brief, args.out, args, args.text, reading.understood + [
        "assumed: " + a for a in reading.assumed], reading.not_understood)
    return 0
def _load_out(path):
    if os.path.isdir(path):
        bpath = os.path.join(path, "brief.json")
    else:
        bpath = path
    with open(bpath, encoding="utf-8") as handle:
        brief = Brief.from_json(handle.read())
    layout = None
    lpath = os.path.join(os.path.dirname(bpath), "layout.json")
    if os.path.exists(lpath):
        layout = export.read_layout(lpath)
    return brief, layout
def cmd_refine(args):
    brief, layout = _load_out(args.folder)
    index = layout["generator"]["candidate"] if layout else 0
    ops, later, not_understood, reading = refmod.parse_ops(args.text or "", brief)
    for module in args.reseed or []:
        ops.append(("reseed", module))
    for region in args.lock or []:
        ops.append(("lock", region))
    for line in later:
        print("not yet: %s" % line)
    if reading.assumed:
        print("assumed: %s" % "; ".join(reading.assumed))
    if not_understood:
        print("not understood: %s" % "; ".join(not_understood))
    if not ops:
        print("refine: nothing to change")
        return 1
    print("refine: %s" % "; ".join(" ".join(str(x) for x in op) for op in ops))
    if any(op[0] == "novelty" for op in ops):
        new_brief, why = refmod.apply(brief, ops)
        for w in why:
            print("  why: %s" % w)
        run_generate(new_brief, args.out or args.folder, args, "refine: " + (args.text or ""))
        return 0
    result, changed = refmod.refine(brief, index, ops, use_metrics=not args.no_metrics,
                                    old_layout=layout)
    if not result.best.ok:
        print("refine: the refined map fails the hard checks: %s"
              % "; ".join(result.best.checks.faults))
        return 1
    rep = result.best.arena.get("report", {})
    for d in rep.get("done", []):
        print("  [%s] %s: %s" % (MARK.get(d.get("status"), d.get("status")), d.get("id"),
                                 d.get("note")))
    for why in rep.get("refine", []):
        print("  why: %s" % why)
    print("refine: candidate %d rebuilt, quality %s; modules that changed: %s"
          % (index, result.best.quality, ", ".join(changed) or "none"))
    out = args.out or args.folder
    text = explain.report(result, "refine: " + (args.text or ""))
    if args.explain:
        print(text)
    export.write_out(result, out, text, "refine: " + (args.text or ""), card=not args.no_card)
    print("refine: wrote %s" % out)
    return 0
def _engine_variety():
    import importlib
    for mod, name in (("mapgen.variety", "run"),):
        try:
            m = importlib.import_module(mod)
        except Exception:
            continue
        fn = getattr(m, name, None)
        if callable(fn):
            return fn, "%s.%s" % (mod, name)
    return None, None
def cmd_variety(args):
    brief, _ = _load_out(args.folder) if args.folder and os.path.exists(args.folder) else \
        (None, None)
    if brief is None:
        if args.wish:
            reading = wishmod.understand(args.wish)
            print_reading(reading)
            brief = Brief.from_dict(reading.raw, kit.forge_keys())
        else:
            brief = brief_from_args(args)
    fn, name = _engine_variety()
    maps = []
    if fn is not None:
        raw = api.raw_of(brief)
        sol = anchors.solve(raw)
        fam, _ = api.lenient(api.family_brief(raw, sol))
        print("variety: %s, %d maps searched" % (name, args.children))
        res = fn(fam, children=args.children, k=max(1, args.count - 1),
                 workers=args.workers)
        for e in res.picks[:args.count]:
            arena = e.arena
            api.postprocess(arena, brief, sol)
            maps.append((arena, e))
        if args.out:
            from . import variety as varmod
            os.makedirs(args.out, exist_ok=True)
            varmod.write_out(res, args.out)
    else:
        from .metrics.measure import measure as _measure
        from .metrics import qd
        print("variety: %d alternatives from %d seeds (the engine's archive is not here "
              "yet - seeds + the diverse picker)" % (args.count, args.count * args.spread))
        entries = []
        for k in range(args.count * args.spread):
            b = brief.with_changes(seed=(brief["seed"] + 1009 * (k + 1)) % 2147483647,
                                   candidates=args.candidates)
            try:
                run = api.run(b, use_metrics=False)
            except Exception as why:
                print("  seed %d: %s" % (b["seed"], why))
                continue
            arena = run.layout()
            desc = qd.descriptors(_measure(arena, tier="cheap"))
            q = run.result.best.quality or 0.0
            entries.append(qd.Entry(b["seed"], q, desc, meta={"arena": arena}))
            if not args.quiet:
                print("  seed %d: quality %.3f  %s" % (b["seed"], q, " ".join(
                    "%s %.2f" % (a, desc.get(a) or 0) for a in ("verticality", "openness"))))
        picked = qd.pick_diverse(entries, k=args.count - 1, floor=0.8)
        if len(picked) < args.count:
            print("variety: only %d of them differ by more than 0.05 on the behaviour axes "
                  "(the engine's own variety is ENGINE's archive); the rest by quality"
                  % len(picked))
            rest = sorted((e for e in entries if e not in picked), key=lambda e: -e.fitness)
            picked += rest[:args.count - len(picked)]
        maps = [(e.meta["arena"], e) for e in picked]
    if not maps:
        print("variety: nothing built")
        return 1
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        from .render import views
        ims = []
        for k, (arena, e) in enumerate(maps):
            folder = os.path.join(args.out, "v%02d" % (k + 1))
            os.makedirs(folder, exist_ok=True)
            with open(os.path.join(folder, "layout.json"), "w", encoding="utf-8") as handle:
                json.dump(arena, handle, indent=1, sort_keys=True)
            b = brief.with_changes(seed=arena.get("generator", {}).get("seed", brief["seed"]))
            with open(os.path.join(folder, "brief.json"), "w", encoding="utf-8") as handle:
                handle.write(b.to_json())
            ims.append(views.top_down(arena, size=320))
        views.sheet(ims, cols=min(3, len(ims)), label="variety").save(
            os.path.join(args.out, "variety.png"))
        print("variety: wrote %d maps and variety.png into %s (refine or export any vNN "
              "folder)" % (len(maps), args.out))
    for k, (arena, e) in enumerate(maps):
        g = arena.get("generator", {})
        q = getattr(e, "quality", None) if e is not None else None
        if q is None:
            q = g.get("quality")
        if isinstance(q, float):
            q = round(q, 3)
        print("  v%02d seed %s quality %s%s" % (k + 1, g.get("seed", brief["seed"]), q,
                                                 ("  " + " ".join("%s %.2f" % (a, e.desc.get(a) or 0)
                                                                  for a in ("verticality", "openness")))
                                                 if e is not None else ""))
    return 0
def cmd_music(args):
    tracks = kit.music_tracks()
    print("Music a venue may play (--music KEY or the name; \"mit Musik ...\" in a wish):")
    for t in tracks:
        print("  %-34s %s%s" % (t["key"], t["label"],
                                "  (a recording: plays as the place's own music)"
                                if t["stream"] else ""))
    print("Visual modifiers a venue may wear (--visual, none by default; 'auto' = the "
          "theme's pairing):")
    for name, (row, stop) in sorted(briefmod.VISUALS.items()):
        if row:
            print("  %-14s the %s row at '%s'" % (name, row, stop))
    print("The Tiles' grounds (--ground, level empty): %s" % ", ".join(briefmod.GROUNDS[1:]))
    return 0
def cmd_objects(args):
    keys = kit.forge_keys() or []
    if args.wish:
        reading = wishmod.understand(args.wish)
        print_reading(reading)
        objs = reading.raw.get("objects") or []
        if not objs:
            print("objects: none asked for - a generated map never carries objects unless "
                  "the wish names them")
        for o in objs:
            ok = o["key"] in keys
            print("  %s x%d %s%s%s" % (o["key"], o.get("count", 1), wishmod._say(o["where"]),
                                       "" if ok else "  (NOT a Forge key)",
                                       "  rounds: " + ", ".join(o["modes"]) if o.get("modes")
                                       else "  free play only"))
        return 0
    words = {}
    for pat, key in wishmod.OBJECTS:
        words.setdefault(key, []).append(re.sub(r"\\b|\\w\*|\?|\(|\)", "", pat.split("|")[0]))
    print("Forge objects a wish may name (%d keys; words the parser knows in brackets):"
          % len(keys))
    for k in keys:
        if args.all or k in words:
            print("  %-14s %s" % (k, ("[" + ", ".join(words[k]) + "]") if k in words else ""))
    print("Placed only when asked; free play only unless the wish says the mode's rounds use "
          "them (\"auch in den Runden\").")
    return 0
def cmd_export(args):
    mod = args.mod or v1.REPO
    if args.remove:
        export.unexport_mod(mod, args.remove)
        print("export: removed %s from %s" % (args.remove, mod))
        return 0
    if not args.folder:
        print("export: give the folder a generate/wish --out wrote")
        return 2
    layout = export.read_layout(args.folder)
    name = args.name or layout.get("name") or "Generated Keep"
    key = args.key or "".join(ch for ch in name.lower() if ch.isalnum())
    if key.startswith("the") and len(key) > 6:
        key = key[3:]
    if args.explain:
        print(export.explain_export(layout, key, name))
    res = export.export_mod(layout, mod, key, name, args.blurb, args.note)
    for tool, code, text in res["tools"]:
        print("  %s: %s" % (tool, text.strip().splitlines()[-1] if text.strip() else code))
    if export._luaregion().is_release(mod):
        print("export: %s (%s) is a venue in %s - script of_%s; host a game with the mod "
              "to play it (export --remove %s takes it out again)" % (name, key, mod, key, key))
    else:
        print("export: %s (%s) is a venue in %s - script of_%s; run the Venues block and "
              "check-levels before shipping" % (name, key, mod, key))
    return 0
def cmd_pack(args):
    from . import modpack
    layout = export.read_layout(args.folder)
    name = args.name or layout.get("name") or "My Map"
    key = args.key or modpack.key_for(name)
    try:
        res = modpack.export(layout, args.into, key, name, args.blurb)
    except modpack.PackError as why:
        print("pack: %s" % why)
        return 1
    print(modpack.handoff(res, name, key, args.into))
    return 0
def cmd_check(args):
    targets = args.what or v1.venue_keys()
    failed = 0
    for what in targets:
        if what in v1.venue_keys():
            arena = v1.venue(what)
            label = what
        else:
            gen = os.path.join(export.generated_dir(v1.REPO), what + ".json")
            path = gen if not os.path.exists(what) and os.path.isfile(gen) else what
            if not os.path.exists(path):
                print("check %s: FAIL - no venue key, generated venue (%s), folder or "
                      "layout.json of that name" % (what, os.path.relpath(gen, v1.REPO)))
                failed += 1
                continue
            arena = export.read_layout(path)
            m = v1.arenas_module()
            for p in arena["pieces"]:
                p["model"] = m.model_name(p)
            label = what
        r = checks.run(arena)
        extra = ""
        if what in v1.venue_keys():
            out = cells.CellGrid.from_pieces(arena["pieces"]).to_pieces()
            same = cells.same_geometry(arena["pieces"], out)
            extra = "; cells round trip %s (%d -> %d pieces)" % ("exact" if same else "DIFFERS",
                                                                 len(arena["pieces"]),
                                                                 len(out))
            failed += not same
            shared = checks.venue_overlaps(arena)
            if shared:
                extra += "; %d overlaps kept (a hand venue stays byte-identical)" % len(shared)
        print("check %s: %s, %d pieces, %d spawns%s" % (
            label, "pass" if r.ok else "FAIL - " + "; ".join(r.faults[:4]),
            len(arena["pieces"]), len(arena["spawns"]), extra))
        if args.explain and not r.ok:
            for f in r.faults:
                print("    %s" % f)
        failed += not r.ok
    co = checks.collision_order()
    print("check collision order (sort_first): %s" % ("pass" if not co else "; ".join(co)))
    failed += bool(co)
    return 1 if failed else 0
def cmd_explain(args):
    if getattr(args, "presets", False) or getattr(args, "prefabs", False) or \
            getattr(args, "budget", False):
        if args.presets:
            from . import presets
            print("World DNA presets (name one in a wish, or --preset KEY):")
            for key, name, about in presets.table():
                print("  %-10s %-12s %s" % (key, name, about))
        if args.prefabs:
            from . import prefablib
            print("Prefab library (tools/prefabs.py; your own saves with import-save):")
            for key, name, tags in prefablib.names():
                print("  %-12s %-14s %s" % (key, name, ", ".join(tags)))
        if args.budget:
            from . import budget
            print("Map budget (tools/mapgen/budget.py):")
            for what, value, source in budget.table():
                print("  %-44s %6s   %s" % (what, value, source))
        return 0
    if args.wish:
        reading, raw = _backend_reading(args, args.wish)
        print_reading(reading)
        brief = Brief.from_dict(raw)
        print(explain.brief_text(brief))
        try:
            sol = anchors.solve(api.raw_of(brief))
            if sol.problem.anchors:
                print("Anchors (solved before any module is chosen):")
                print_language(sol.lines())
                for n in sol.notes:
                    print("  note: %s" % n)
        except anchors.Refused as why:
            print("Anchors: %s" % why)
        return 0
    if not args.path:
        print("explain: give an --out folder, a brief.json, or --wish TEXT")
        return 2
    brief, layout = _load_out(args.path)
    print(explain.brief_text(brief))
    if layout:
        g = layout.get("generator", {})
        print("\nMap: candidate %s of seed %s, quality %s (%s)" % (
            g.get("candidate"), g.get("seed"), g.get("quality"), g.get("score_source")))
        print("Modules: %s" % json.dumps(g.get("modules"), sort_keys=True))
        rep = layout.get("report", {})
        for d in rep.get("done", []):
            print("  [%s] %s: %s" % (MARK.get(d.get("status"), d.get("status")), d.get("id"),
                                     d.get("note")))
        for why in rep.get("refine", []):
            print("  refine: %s" % why)
        if layout.get("objects"):
            print("Objects: %d (%s)" % (len(layout["objects"]), ", ".join(sorted(set(
                o["key"] for o in layout["objects"])))))
        path = os.path.join(args.path if os.path.isdir(args.path) else
                            os.path.dirname(args.path), "report.md")
        if os.path.exists(path):
            print("Report: %s" % path)
    return 0
HELP = """Map generator v2: a wish or a brief in, a checked map out, exported into the
mod as a venue. Offline, deterministic (same brief + seed = the same map).

  wish     "kleine schnelle Shooter-Map, Turm im Nordwesten, World Spawn im Sueden"
  generate --theme ice --anchor tower:nw:once --anchor worldspawn:s --seed 7
  refine   OUT "Mitte groesser" | "Spawn weiter nach Norden" | "statt Krone eine Grube"
           | "lass die Basen so" | "Mitte offener" | "andere Mitte" | "Boden in Eis"
  variety  OUT --count 9             a spread of different good maps
  objects  [--wish TEXT]             Forge objects a wish may ask for (only when asked)
  export   OUT --name "Frost Keep"   into the mod as a new venue
  pack     OUT INTO --name "Frost Keep"   for any sm64coopdx mod or modpack (/ofmap)
  check    [venue | OUT]             v1's hard checks
  explain  OUT | --wish TEXT         the brief, every assumed field marked, and why

Every command takes --explain for the reasoning. `mapgen COMMAND --help` lists
every flag."""
def cmd_history(args):
    from . import history
    p = history.path()
    if args.forget:
        print("history: %s %s" % ("forgot" if history.forget(p) else "nothing to forget at", p))
        return 0
    h = history.load(p)
    print("history: %s - %d maps made, %d kept" % (p, h.get("count", 0), len(h["entries"])))
    for e in h["entries"][-args.last:]:
        print("  %-9s %-12s %-7s %-8s %-10s seed %s" % (e["family"], e["formation"], e["theme"],
                                                       e["size"], e["preset"] or "-", e["seed"]))
    for rj in h["rejects"]:
        print("  rejected: %s %s %s (for %d more %s maps)" % (
            rj["family"], rj["aspect"], rj["value"], rj["left"], rj["family"]))
    return 0
def parser():
    p = argparse.ArgumentParser(prog="mapgen", description=HELP,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", metavar="COMMAND")
    def common(q, out=True, card=True):
        if out:
            q.add_argument("--out", help="folder for brief.json, layout.json, top.png, "
                           "report.md and the report card")
        q.add_argument("--no-metrics", action="store_true", help="the built-in score only "
                       "(faster)")
        if card:
            q.add_argument("--no-card", action="store_true", help="skip the report card and "
                           "its pictures in --out")
        q.add_argument("--quiet", action="store_true", help="no per-candidate lines")
        q.add_argument("--no-history", action="store_true", help="leave the generation history "
                       "alone (no surprise memory, no 'not that again')")
        q.add_argument("--explain", action="store_true", help="print the reasoning: the brief "
                       "with its defaults, the anchors, the report")
    g = sub.add_parser("generate", help="build a map from brief flags (or --brief FILE)")
    add_brief_flags(g)
    common(g)
    g.set_defaults(fn=cmd_generate)
    w = sub.add_parser("wish", help="free text (German or English) -> brief -> map",
                       description="Free text in German or English. What was understood, "
                       "assumed and not understood is printed before anything is built.")
    w.add_argument("text")
    w.add_argument("--brief-only", action="store_true", help="print the brief, build nothing")
    for k in ("seed", "candidates", "players", "budget"):
        w.add_argument("--" + k, type=int)
    for k in ("name", "key", "theme", "family"):
        w.add_argument("--" + k)
    backend_flags(w)
    common(w)
    w.set_defaults(fn=cmd_wish)
    r = sub.add_parser("refine", help="change a generated map - only what was asked changes",
                       description=refmod.HELP,
                       formatter_class=argparse.RawDescriptionHelpFormatter)
    r.add_argument("folder", help="an --out folder")
    r.add_argument("text", nargs="?", help="e.g. \"Mitte groesser\", \"Spawn weiter nach "
                   "Norden\", \"a pit instead of the crown\", \"lass die Basen so\"")
    r.add_argument("--reseed", action="append", metavar="MODULE",
                   help="re-roll one module's stream: centre, unit, fill, frame")
    r.add_argument("--lock", action="append", metavar="REGION",
                   help="keep a region verbatim: centre, bases, n, s, e, w")
    common(r, out=True)
    r.set_defaults(fn=cmd_refine)
    v = sub.add_parser("variety", help="a spread of genuinely different good maps for one "
                       "brief")
    v.add_argument("folder", nargs="?", help="an --out folder whose brief to vary (or give "
                   "--wish / brief flags)")
    v.add_argument("--wish", help="vary this wish instead")
    v.add_argument("--count", type=int, default=6, help="how many maps (default 6)")
    v.add_argument("--spread", type=int, default=3, help="seeds tried per map kept "
                   "(default 3; only without the engine's archive)")
    v.add_argument("--children", type=int, default=120, help="maps the archive search "
                   "builds (default 120)")
    v.add_argument("--workers", type=int, default=None, help="processes (default: the "
                   "engine's)")
    add_brief_flags(v)
    common(v, card=False)
    v.set_defaults(fn=cmd_variety)
    o = sub.add_parser("objects", help="the Forge objects a wish may ask for")
    o.add_argument("--wish", help="show what a wish asks for")
    o.add_argument("--all", action="store_true", help="every Forge key, not only the named")
    o.add_argument("--explain", action="store_true")
    o.set_defaults(fn=cmd_objects)
    mu = sub.add_parser("music", help="the tracks a venue may play, and the looks it may wear")
    mu.add_argument("--explain", action="store_true")
    mu.set_defaults(fn=cmd_music)
    e = sub.add_parser("export", help="put a generated map into the mod as a new venue")
    e.add_argument("folder", nargs="?", help="an --out folder (or layout.json)")
    e.add_argument("--name", help="the venue's name (e.g. \"The Frost Keep\")")
    e.add_argument("--key", help="its key (default: from the name)")
    e.add_argument("--blurb")
    e.add_argument("--note")
    e.add_argument("--mod", help="the mod folder (default: this repository)")
    e.add_argument("--remove", metavar="KEY", help="take a generated venue out again")
    e.add_argument("--explain", action="store_true", help="say what goes where")
    e.set_defaults(fn=cmd_export)
    pk = sub.add_parser("pack", help="the map for any sm64coopdx mod or modpack: its level, "
                        "the oldfart_maps.lua runtime and everything in it (/ofmap)")
    pk.add_argument("folder", help="an --out folder (or layout.json)")
    pk.add_argument("into", help="the folder to write into (a mod of a modpack, or a new one)")
    pk.add_argument("--name", help="the map's name (e.g. \"The Frost Keep\")")
    pk.add_argument("--key", help="its short name for /ofmap (default: from the name)")
    pk.add_argument("--blurb")
    pk.set_defaults(fn=cmd_pack)
    c = sub.add_parser("check", help="v1's hard checks on venues or layouts (default: the "
                       "five, with the cell round trip)")
    c.add_argument("what", nargs="*", help="venue keys (hand-built, or generated: "
                   "tools/venues-generated/<key>.json), --out folders or layout.json files")
    c.add_argument("--explain", action="store_true", help="every fault, not the first four")
    c.set_defaults(fn=cmd_check)
    hi = sub.add_parser("history", help="the maps made lately (surprise / novelty / 'not "
                        "that again' read it); --forget deletes it")
    hi.add_argument("--forget", action="store_true", help="delete the generation history")
    hi.add_argument("--last", type=int, default=20, help="how many to list")
    hi.set_defaults(fn=cmd_history)
    x = sub.add_parser("explain", help="print a brief (assumed fields marked) and why")
    x.add_argument("path", nargs="?", help="an --out folder or a brief.json")
    x.add_argument("--wish", help="explain what a wish would become instead")
    x.add_argument("--presets", action="store_true",
                   help="list the named World DNA presets a wish may name")
    x.add_argument("--prefabs", action="store_true",
                   help="list the prefab library (a wish names one: mit meinem Haus 'Cottage')")
    x.add_argument("--budget", action="store_true",
                   help="the map budget: every limit with its source, the ceiling per family")
    x.add_argument("--explain", action="store_true", help=argparse.SUPPRESS)
    backend_flags(x)
    x.set_defaults(fn=cmd_explain)
    t = sub.add_parser("teach", help="teach the wish reader a word: teach WORD \"what it means\" "
                                     "(your own file; --list, --forget WORD, --export FILE)")
    t.add_argument("word", nargs="?")
    t.add_argument("meaning", nargs="?", help="what it means, in words the reader knows")
    t.add_argument("--forget", action="store_true", help="forget WORD")
    t.add_argument("--list", action="store_true", help="the words taught so far")
    t.add_argument("--export", metavar="FILE",
                   help="write the taught words as lexicon concepts for a merge")
    t.set_defaults(fn=cmd_teach)
    return p
def cmd_teach(args):
    from . import userlex
    if args.export:
        n = userlex.export(args.export)
        print("%d taught word(s) written to %s (lexicon concepts, review before a merge)"
              % (n, args.export))
        return 0
    if args.list or not args.word:
        ws = userlex.words()
        print("taught words (%s): %d" % (userlex.path(), len(ws)))
        for w, e in sorted(ws.items()):
            print("  %s = %s  [%s]" % (w, e["means"], "; ".join(e.get("reads") or [])))
        return 0
    if args.forget:
        print(("forgot '%s'" if userlex.forget(args.word) else "'%s' was not taught")
              % args.word)
        return 0
    if not args.meaning:
        print("mapgen: say what '%s' means: teach %s \"...\"" % (args.word, args.word))
        return 2
    try:
        reads = userlex.teach(args.word, args.meaning)
    except userlex.TeachError as why:
        print("mapgen: %s" % why)
        return 1
    print("taught: '%s' = %s -> %s" % (args.word, args.meaning, "; ".join(reads)))
    return 0
def backend_flags(sp):
    sp.add_argument("--backend", choices=("offline", "claude", "ollama"), default="offline",
                    help="who reads the text: the offline rules (default), the Claude API "
                         "(ANTHROPIC_API_KEY) or a local Ollama; falls back to offline")
    sp.add_argument("--model", help="the backend's model (claude-opus-5-5 by default, or an "
                                    "installed Ollama model)")
def main(argv):
    if argv and argv[0] == "gallery":
        from . import gallery
        return gallery.main(argv[1:])
    if argv and argv[0] == "contract":
        from . import contract
        return contract.main(argv[1:])
    p = parser()
    args = p.parse_args(argv)
    if not getattr(args, "fn", None):
        p.print_help()
        return 2
    try:
        return args.fn(args)
    except anchors.Refused as why:
        print("mapgen: %s" % why)
        return 1
    except (BriefError, AnchorConflict, gen.NotBuilt, export.ExportError) as why:
        print("mapgen: %s" % why)
        return 1
    except RuntimeError as why:
        print("mapgen: %s" % why)
        return 1
