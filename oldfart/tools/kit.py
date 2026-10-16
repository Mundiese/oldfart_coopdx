#!/usr/bin/env python3
import argparse
import datetime
import importlib.util
import io
import math
import os
import re
import subprocess
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ACTORS = os.path.join(ROOT, "actors")
RETIRED = os.path.join(HERE, "retired-names.txt")
MAPPING = os.path.join(ROOT, "assets-incoming", "1004", "surfaces", "MAPPING.csv")
DUMP = os.path.join(ROOT, "assets-incoming", "1004", "surfaces")
def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
blocks = _load("make_blocks", "make-blocks.py")
Refused = blocks.Refused
recode = _load("blockrecode", "blockrecode.py")
SEAM_CUT = 1.8
NEAR_BITS = 5
def image_module():
    try:
        from PIL import Image
    except ImportError:
        raise Refused("tools/kit.py needs Pillow (pip install pillow) to read and "
                      "scale pictures")
    return Image
def tile_from(path):
    Image = image_module()
    img = Image.open(path)
    w, h = img.size
    if w != h or w & (w - 1) or w < 8:
        raise Refused("%s: %dx%d - a block face is square and a power of two "
                      "(8, 16, 32, 64, ...)" % (os.path.basename(path), w, h))
    img = img.convert("RGBA")
    alpha = img.getchannel("A").tobytes()
    if min(alpha) < 250:
        clear = sum(1 for a in alpha if a < 250)
        raise Refused("%s: %d see-through texels - a block is solid"
                      % (os.path.basename(path), clear))
    done = "32x32"
    if w > blocks.TILE:
        img = img.reduce(w // blocks.TILE)
        done = "%dx%d box-filtered to 32x32" % (w, h)
    elif w < blocks.TILE:
        img = img.resize((blocks.TILE, blocks.TILE), Image.NEAREST)
        done = "%dx%d scaled up to 32x32" % (w, h)
    return img, done
def png_bytes(img):
    out = io.BytesIO()
    img.save(out, "PNG", optimize=True)
    return out.getvalue()
def pixels(img):
    return img.convert("RGBA").tobytes()
def seam_score(img):
    px = img.convert("RGB").load()
    n = img.size[0]
    def step(a, b):
        return sum(abs(a[k] - b[k]) for k in range(3))
    worst = 0.0
    for horizontal in (True, False):
        inside, wrap = [], []
        for i in range(n):
            for j in range(n):
                a = px[j, i] if horizontal else px[i, j]
                nxt = (j + 1) % n
                b = px[nxt, i] if horizontal else px[i, nxt]
                (wrap if nxt == 0 else inside).append(step(a, b))
        mean_in = sum(inside) / len(inside)
        mean_wrap = sum(wrap) / len(wrap)
        worst = max(worst, mean_wrap / max(mean_in, 1.0))
    return worst
def ahash(img):
    small = img.convert("L").resize((8, 8))
    data = list(small.tobytes())
    mean = sum(data) / len(data)
    return sum(1 << k for k, v in enumerate(data) if v > mean)
def hamming(a, b):
    return bin(a ^ b).count("1")
def builtin_names():
    if not os.path.exists(MAPPING) or not os.path.exists(blocks.BUILTIN_TEX):
        return {}
    by_path = {}
    pattern = re.compile(r'define_builtin_tex_?\((\w+), "([^"]+)", (\d+), (\d+)')
    with open(blocks.BUILTIN_TEX, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            found = pattern.search(line)
            if found and found.group(3) == found.group(4) and found.group(3) == "32":
                by_path[found.group(2)] = found.group(1)
    import csv
    Image = image_module()
    out = {}
    with open(MAPPING, encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            name = by_path.get(row.get("decomp", "") + ".png")
            path = os.path.join(DUMP, row.get("new", ""))
            if name and os.path.exists(path) and row.get("size") == "32x32":
                try:
                    out.setdefault(pixels(Image.open(path)), name)
                except OSError:
                    pass
    return out
def manifest_lines():
    with open(blocks.MANIFEST, encoding="utf-8") as handle:
        return handle.read().split("\n")
def write_manifest(lines):
    with open(blocks.MANIFEST, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
def row_line(row):
    source = " + ".join(row["layers"]) if row.get("layers") else row["source"]
    parts = [row["shelf"], row["name"], source, row.get("swatch") or "-"]
    if row.get("key_field"):
        parts.append("key=" + row["slug"])
    if row.get("shapes"):
        parts.append("shapes=" + row["shapes"])
    if row.get("was"):
        parts.append("was=" + ",".join(row["was"]))
    if row.get("roles"):
        parts.append("roles=" + ",".join(row["roles"]))
    while parts[-1] == "-":
        parts.pop()
    return " | ".join(parts)
def find_row(rows, word):
    word_slug = re.sub(r"[^a-z0-9]", "", word.lower())
    for row in rows:
        if row["slug"] == word_slug or row["name"].lower() == word.lower():
            return row
    raise Refused("no block %r (tools/kit.py list shows them)" % word)
def replace_row(row, new_text):
    lines = manifest_lines()
    index = row["line"] - 1
    if new_text is None:
        del lines[index]
        drop_import_header(lines, index)
    else:
        lines[index] = new_text
    write_manifest(lines)
def with_key_field(row, name):
    return blocks.slug(name) != row["slug"]
def reread_row(word):
    _, rows = blocks.read_manifest()
    return find_row(rows, word)
def where_used(slug):
    out = []
    checks = [
        (os.path.join(HERE, "make-arenas.py"), "a venue (tools/make-arenas.py)"),
        (os.path.join(HERE, "mapgen", "kit.py"), "the generator's roles or themes (tools/mapgen/kit.py)"),
    ]
    for path, what in checks:
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
            if re.search(r'["\']%s["\']' % re.escape(slug), text):
                out.append(what)
    prefab_dir = os.path.join(ROOT, "prefabs")
    if os.path.isdir(prefab_dir):
        for name in sorted(os.listdir(prefab_dir)):
            if name.endswith(".prefab"):
                with open(os.path.join(prefab_dir, name), encoding="utf-8") as handle:
                    text = handle.read()
                if re.search(r"\b%s\b" % re.escape(slug), text):
                    out.append("prefab " + name)
    return out
def built_keys(slug):
    keys, geos = ["blk" + slug], ["of_blk_%s_geo" % slug]
    for name in sorted(os.listdir(ACTORS)):
        found = re.match(r"^of_slp_([a-z]+[0-9]?)_%s_geo\.bin$" % re.escape(slug), name)
        if found:
            keys.append(found.group(1) + slug)
            geos.append(name[:-4])
    _, rows = blocks.read_manifest()
    row = next((r for r in rows if r["slug"] == slug), None)
    if row is not None and row.get("drawn") == "runtime":
        slopes = _load("make_forgeslopes", "make-forgeslopes.py")
        for variant in slopes.variants():
            if slopes.builds_in(variant, row) and variant["tag"] + slug not in keys:
                keys.append(variant["tag"] + slug)
    return keys, geos
def retire(names, why):
    have = set()
    with open(RETIRED, encoding="utf-8") as handle:
        for line in handle:
            if line.strip() and not line.startswith("#"):
                have.add(line.split("\t")[0].strip())
    add = [(n, kind) for n, kind in names if n not in have]
    if not add:
        return 0
    with open(RETIRED, "a", encoding="utf-8") as handle:
        for name, kind in add:
            handle.write("%s\t%s\t%s\n" % (name, kind, why))
    return len(add)
def retired_set():
    out = set()
    with open(RETIRED, encoding="utf-8") as handle:
        for line in handle:
            if line.strip() and not line.startswith("#"):
                out.add(line.split("\t")[0].strip())
    return out
def actor_sizes():
    out = {}
    _, rows = blocks.read_manifest()
    slugs = sorted((r["slug"] for r in rows), key=len, reverse=True)
    for name in os.listdir(ACTORS):
        size = os.path.getsize(os.path.join(ACTORS, name))
        found = re.match(r"^of_blk_([a-z0-9]+)_geo\.bin$", name)
        if found:
            out.setdefault(found.group(1), {})["cube"] = size
            continue
        found = re.match(r"^of_slp_([a-z]+[0-9]?)_([a-z0-9]+)_geo\.bin$", name)
        if found:
            out.setdefault(found.group(2), {})[found.group(1)] = size
    return out
def total_size():
    return sum(sum(v.values()) for v in actor_sizes().values())
def run_builds(quiet=False):
    for tool in ("make-cube-template.py", "make-blocks.py", "make-forgeslopes.py"):
        result = subprocess.run([sys.executable, os.path.join(HERE, tool)],
                                capture_output=True, text=True)
        if not quiet or result.returncode:
            print((result.stdout + result.stderr).strip())
        if result.returncode:
            raise Refused("%s refused - the manifest is left as written; fix it or "
                          "put the old file back (git checkout tools/blocks-manifest.txt)" % tool)
    for tool in ("make-blocks.py", "make-forgeslopes.py"):
        result = subprocess.run([sys.executable, os.path.join(HERE, tool), "--check"],
                                capture_output=True, text=True)
        if result.returncode:
            print((result.stdout + result.stderr).strip())
            raise Refused("%s --check is red after the build" % tool)
def kb(n):
    return "%.1f KB" % (n / 1024.0)
def changed(before):
    after = total_size()
    sign = "+" if after >= before else "-"
    print("download: %s (%s%s)" % (kb(after), sign, kb(abs(after - before))))
def name_from_file(path):
    stem = os.path.splitext(os.path.basename(path))[0]
    words = re.sub(r"[_\-.]+", " ", stem)
    words = re.sub(r"\s+", " ", words).strip()
    if not words:
        raise Refused("%s: no name in the file name" % path)
    return words[0].upper() + words[1:]
def gather(folder, shelf):
    if not os.path.isdir(folder):
        raise Refused("%s: no such folder" % folder)
    out = []
    for entry in sorted(os.listdir(folder)):
        path = os.path.join(folder, entry)
        if os.path.isdir(path):
            if entry not in blocks.SHELVES:
                raise Refused("%s: a sub-folder is a shelf (%s)"
                              % (entry, ", ".join(blocks.SHELVES)))
            for inner in sorted(os.listdir(path)):
                if inner.lower().endswith(".png"):
                    out.append((os.path.join(path, inner), entry))
        elif entry.lower().endswith(".png"):
            out.append((path, shelf))
    if not out:
        raise Refused("%s: no PNG files" % folder)
    return out
def make_seamless(img):
    Image = image_module()
    img = img.convert("RGBA")
    n = img.size[0]
    half = n // 2
    shifted = Image.new("RGBA", img.size)
    for dx in (0, half):
        for dy in (0, half):
            box = (dx, dy, dx + (n - half), dy + (n - half))
            shifted.paste(img.crop(box), ((dx + half) % n, (dy + half) % n))
    band = max(1.0, n / 4.0)
    mask = Image.new("L", img.size)
    for y in range(n):
        for x in range(n):
            edge = min(x, n - 1 - x, y, n - 1 - y)
            mask.putpixel((x, y), int(255 * min(1.0, edge / band)))
    return Image.composite(img, shifted, mask)
class ImportContext:
    def __init__(self):
        _, rows = blocks.read_manifest()
        self.taken = {r["slug"] for r in rows} | {w for r in rows for w in r["was"]}
        self.retired = retired_set()
        Image = image_module()
        self.have_pixels, self.have_hash = {}, {}
        for row in rows:
            for source in (row.get("layers") or [row["source"]]):
                try:
                    img = Image.open(os.path.join(ROOT, source)).convert("RGBA")
                except OSError:
                    continue
                self.have_pixels[pixels(img)] = row["name"]
                self.have_hash[row["name"]] = ahash(img)
        self.builtins = builtin_names()
    def claim(self, item):
        self.taken.add(item["key"])
        self.have_pixels[pixels(item["img"])] = item["name"]
        self.have_hash[item["name"]] = ahash(item["img"])
def inspect(path, shelf, context, name=None, allow_seams=False, seamless=False):
    item = {"path": path, "shelf": shelf, "checks": [], "refusal": None, "img": None,
            "done": None, "seam": None, "near": [], "swatch": None, "name": name, "key": None}
    def say(check, level, text):
        item["checks"].append((check, level, text))
        if level == "fail" and item["refusal"] is None:
            item["refusal"] = text
    try:
        item["name"] = name or name_from_file(path)
        item["key"] = blocks.slug(item["name"])
    except Refused as why:
        say("name", "fail", str(why))
        return item
    label, key = item["name"], item["key"]
    if key in context.taken:
        say("key", "fail", "%s: the key %r is taken (rename the file)" % (label, key))
    elif ("blk" + key) in context.retired:
        say("key", "fail", "%s: the key %r was retired (rename the file)" % (label, key))
    else:
        say("key", "ok", "key %s is free" % key)
    if shelf not in blocks.SHELVES:
        say("shelf", "fail", "%s: shelf %r is not one of %s" % (label, shelf,
                                                               ", ".join(blocks.SHELVES)))
    try:
        img, done = tile_from(path)
    except Refused as why:
        say("size" if "power of two" in str(why) else "opaque", "fail", str(why))
        return item
    except OSError as why:
        say("size", "fail", "%s: not a picture (%s)" % (os.path.basename(path), why))
        return item
    say("size", "ok" if done == "32x32" else "note", done)
    say("opaque", "ok", "opaque")
    if seamless:
        img = make_seamless(img)
        done += ", made seamless"
    item["img"], item["done"] = img, done
    px = pixels(img)
    if px in context.have_pixels:
        say("duplicate", "fail", "%s: the same picture as the block %r"
            % (label, context.have_pixels[px]))
    item["seam"] = seam = seam_score(img)
    if seam > SEAM_CUT and not allow_seams:
        say("seams", "fail", "%s: seam score %.2f (over %.1f: a wall of it shows a grid; "
            "--allow-seams takes it anyway)" % (label, seam, SEAM_CUT))
    else:
        say("seams", "ok" if seam <= SEAM_CUT else "note", "seam score %.2f%s" % (
            seam, "" if seam <= SEAM_CUT else " - taken anyway"))
    mine = ahash(img)
    item["near"] = [n for n, h in context.have_hash.items() if hamming(h, mine) <= NEAR_BITS]
    if item["near"]:
        say("duplicate", "note", "looks like " + ", ".join(item["near"]))
    elif px not in context.have_pixels:
        say("duplicate", "ok", "a new picture")
    item["swatch"] = context.builtins.get(px)
    return item
def plan_import(files, allow_seams=False, context=None):
    context = context or ImportContext()
    plan, faults = [], []
    for path, shelf in files:
        item = inspect(path, shelf, context, allow_seams=allow_seams)
        if item["refusal"]:
            faults.append(item["refusal"])
            continue
        plan.append(item)
        context.claim(item)
    return plan, faults
IMPORT_HEADER = "# Imported by tools/kit.py from "
IMPORT_SOURCE = re.compile(r"^assets-incoming/\d{4}/blocks/[^/]+/[^/]+\.png$")
def is_release():
    return _load("of_luaregion", "luaregion.py").is_release(ROOT)
def drop_import_header(lines, index):
    if index < 1 or not lines[index - 1].startswith(IMPORT_HEADER):
        return lines
    following = lines[index] if index < len(lines) else ""
    if following.strip() == "" or following.startswith("#"):
        del lines[index - 1]
    return lines
def _tracked(path):
    if not os.path.exists(os.path.join(ROOT, ".git")):
        return False
    try:
        out = subprocess.run(["git", "-C", ROOT, "ls-files", "--error-unmatch", path],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        return True
    return out.returncode == 0
def drop_import_source(row, rows):
    source = row.get("source") or ""
    if row.get("layers") or not IMPORT_SOURCE.match(source.replace(os.sep, "/")):
        return None
    for other in rows:
        if other is row:
            continue
        if source in (other.get("layers") or ()) or other.get("source") == source:
            return None
    full = os.path.join(ROOT, source)
    if not os.path.isfile(full) or _tracked(source):
        return None
    os.remove(full)
    folder = os.path.dirname(full)
    top = os.path.join(ROOT, "assets-incoming")
    while os.path.abspath(folder) != os.path.abspath(top):
        try:
            os.rmdir(folder)
        except OSError:
            break
        folder = os.path.dirname(folder)
    return source
def apply_import(plan, source_label, date=None, quiet=False):
    if not plan:
        raise Refused("nothing to import")
    date = date or datetime.date.today().strftime("%m%d")
    slopes = _load("make_forgeslopes", "make-forgeslopes.py")
    for item in plan:
        if item.get("shapes"):
            slopes.shape_set({"slug": "kitprobe", "shapes": item["shapes"], "layers": None,
                              "shelf": item["shelf"], "line": 0})
        bad = [r for r in item.get("roles") or () if not re.match(r"^[a-z]+$", r)]
        if bad:
            raise Refused("%s: role %r is not a word" % (item["name"], bad[0]))
    before = total_size()
    lines = manifest_lines()
    while lines and lines[-1] == "":
        lines.pop()
    if not is_release():
        lines.append(IMPORT_HEADER + source_label)
    for item in plan:
        target = item.get("target") or os.path.join(
            "assets-incoming", date, "blocks", item["shelf"], item["name"] + ".png")
        item["target"] = target
        full = os.path.join(ROOT, target)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as handle:
            handle.write(png_bytes(item["img"]))
        roles = item.get("roles")
        row = {"shelf": item["shelf"], "name": item["name"], "source": target,
               "swatch": item["swatch"], "shapes": item.get("shapes"), "was": [],
               "roles": tuple(roles) if roles else None, "slug": item["key"]}
        lines.append(row_line(row))
    lines.append("")
    write_manifest(lines)
    run_builds(quiet=quiet)
    return total_size() - before
def cmd_import(args):
    if args.shelf not in blocks.SHELVES:
        raise Refused("--shelf %r is not one of %s" % (args.shelf, ", ".join(blocks.SHELVES)))
    date = args.date or datetime.date.today().strftime("%m%d")
    plan, faults = plan_import(gather(args.folder, args.shelf), allow_seams=args.allow_seams)
    for item in plan:
        item["target"] = os.path.join("assets-incoming", date, "blocks", item["shelf"],
                                      item["name"] + ".png")
        print("  %-24s %-16s %-15s seam %.2f%s%s" % (
            item["name"], item["key"], item["shelf"], item["seam"],
            ", swatch " + item["swatch"] if item["swatch"] else ", own swatch",
            (", looks like " + ", ".join(item["near"])) if item["near"] else ""))
        if item["done"] != "32x32":
            print("      " + item["done"])
    for fault in faults:
        print("  refused: " + fault)
    if not plan:
        raise Refused("nothing to import")
    if args.dry_run:
        print("dry run: nothing written")
        return 0
    roles = tuple(r.strip() for r in args.roles.split(",")) if args.roles else None
    for item in plan:
        item["shapes"], item["roles"] = args.shapes, roles
    before = total_size()
    apply_import(plan, os.path.relpath(os.path.abspath(args.folder), ROOT), date)
    print("imported %d block(s)" % len(plan))
    changed(before)
    return 0
def cmd_list(args):
    _, rows = blocks.read_manifest()
    slopes = _load("make_forgeslopes", "make-forgeslopes.py")
    sizes = actor_sizes()
    for row in rows:
        shapes = sorted(slopes.shape_set(row))
        size = sum(sizes.get(row["slug"], {}).values())
        used = where_used(row["slug"])
        print("%-18s %-22s %-16s %2d shapes %8s%s%s" % (
            row["slug"], row["name"], row["shelf"], len([s for s in shapes if not s.startswith("u")]),
            kb(size), ("  shapes=" + row["shapes"]) if row.get("shapes") else "",
            ("  used by " + "; ".join(used)) if used else ""))
    return 0
def cmd_shapes(args):
    _, rows = blocks.read_manifest()
    row = find_row(rows, args.block)
    slopes = _load("make_forgeslopes", "make-forgeslopes.py")
    probe = dict(row)
    probe["shapes"] = args.spec
    chosen = slopes.shape_set(probe)
    before = total_size()
    row["shapes"] = args.spec
    row["key_field"] = with_key_field(row, row["name"])
    replace_row(row, row_line(row))
    run_builds(quiet=True)
    print("%s: %s" % (row["name"], ", ".join(sorted(chosen))))
    changed(before)
    return 0
def code_uses(slug):
    keys, geos = built_keys(slug)
    names = sorted(set(keys) | set(geos))
    out = []
    for name in sorted(os.listdir(ROOT)):
        if not name.endswith(".lua"):
            continue
        with open(os.path.join(ROOT, name), encoding="utf-8") as handle:
            text = handle.read()
        text = _load("of_luaregion", "luaregion.py").restore(text, name)
        text = re.sub(r"-- BEGIN (BLOCKS|PREFABS)\b.*?-- END \1", "", text, flags=re.S)
        if "block_entry(" in text:
            continue
        found = [n for n in names if re.search(r"[\"']%s[\"']" % re.escape(n), text)]
        if found:
            out.append("%s (%s)" % (name, ", ".join(found)))
    return out
def recode_targets(slug, also=(), sav_dirs=None):
    out = []
    prefab_dir = os.path.join(ROOT, "prefabs")
    if os.path.isdir(prefab_dir):
        out += [os.path.join(prefab_dir, n) for n in sorted(os.listdir(prefab_dir))
                if n.endswith(".prefab")]
    out += recode.forge_saves(sav_dirs)
    out += [os.path.abspath(p) for p in also]
    keep = []
    for path in out:
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                if re.search(r"(?<![a-z0-9])[a-z]*%s(?![a-z0-9])" % re.escape(slug),
                             handle.read()):
                    keep.append(path)
        except OSError:
            keep.append(path)
    return keep
def rename_plan(block, name, also=(), sav_dirs=None):
    _, rows = blocks.read_manifest()
    row = find_row(rows, block)
    old, new = row["slug"], blocks.slug(name)
    plan = {"old": old, "new": new, "refused": None, "code": [], "files": []}
    taken = {r["slug"] for r in rows if r is not row} | {w for r in rows for w in r["was"]}
    if new == old:
        plan["refused"] = "the new name has the same key"
    elif new in taken or ("blk" + new) in retired_set():
        plan["refused"] = "the key %r is taken or retired" % new
    else:
        plan["code"] = code_uses(old)
        if plan["code"]:
            plan["refused"] = (
                "the mod's code names %s by key (%s) - code is not a save, so a rename "
                "cannot re-code it and the key stays" % (old, "; ".join(plan["code"])))
    if not plan["refused"]:
        plan["files"] = recode_targets(old, also, sav_dirs)
    return plan
def recode_files(paths, mapping):
    done, left = [], []
    tags = recode.shape_tags(ACTORS)
    for path in paths:
        try:
            new, n, notes = recode.recode_file(path, mapping, tags)
            if new is not None:
                recode.write_atomic(path, new)
                done.append((path, n))
            for note in notes:
                left.append((path, note))
        except (OSError, ValueError) as why:
            left.append((path, "%s - it is translated when it is read" % why))
    return done, left
def cmd_rename(args):
    _, rows = blocks.read_manifest()
    row = find_row(rows, args.block)
    new_slug = blocks.slug(args.name)
    before = total_size()
    if not args.new_key and not args.plan:
        row["name"] = args.name
        row["key_field"] = with_key_field(row, args.name)
        replace_row(row, row_line(row))
        run_builds(quiet=True)
        print("%s is now %r, key %s kept" % (row["slug"], args.name, row["slug"]))
        return 0
    sav_dirs = [] if args.no_saves else (args.sav_dir or None)
    plan = rename_plan(args.block, args.name, args.also, sav_dirs)
    if args.plan:
        print("%s -> %s" % (plan["old"], plan["new"]))
        if plan["refused"]:
            print("refused: %s" % plan["refused"])
        for path in plan["files"]:
            print("re-codes %s" % path)
        return 1 if plan["refused"] else 0
    if plan["refused"]:
        raise Refused("%s - rename without --new-key (only the name changes)"
                      % plan["refused"])
    old = row["slug"]
    keys, geos = built_keys(old)
    row["name"] = args.name
    row["slug"] = new_slug
    row["key_field"] = False
    row["was"] = row["was"] + [old]
    replace_row(row, row_line(row))
    _, rows = blocks.read_manifest()
    done, left = recode_files(plan["files"], recode.was_map(rows))
    run_builds(quiet=True)
    if any(p.endswith(".prefab") for p, _ in done):
        for argv in ([], ["--check"]):
            result = subprocess.run([sys.executable, os.path.join(HERE, "prefabs.py")] + argv,
                                    capture_output=True, text=True)
            if result.returncode:
                print((result.stdout + result.stderr).strip())
                raise Refused("prefabs.py %s is red after re-coding the prefabs"
                              % (" ".join(argv) or "build"))
    n = retire([(k, "key") for k in keys] + [(g, "ident") for g in geos],
               "renamed to %s by tools/kit.py (saved bars follow BLOCK_WAS)" % new_slug)
    print("%s -> %s (%r); %d old names retired" % (old, new_slug, args.name, n))
    for path, count in done:
        print("re-coded %s (%d)" % (os.path.relpath(path, ROOT) if path.startswith(ROOT)
                                    else path, count))
    for path, why in left:
        print("left as it was: %s: %s" % (path, why))
    changed(before)
    return 0
def cmd_remove(args):
    _, rows = blocks.read_manifest()
    row = find_row(rows, args.block)
    used = where_used(row["slug"])
    if used and not args.force:
        raise Refused("%s is named by %s (--force removes it anyway, and those go red "
                      "in their own checks)" % (row["slug"], "; ".join(used)))
    into = find_row(rows, args.into) if args.into else None
    if into is row:
        raise Refused("--into names the block being removed")
    before = total_size()
    keys, geos = built_keys(row["slug"])
    replace_row(row, None)
    if into is not None:
        into = reread_row(into["slug"])
        into["was"] = into["was"] + [row["slug"]] + row["was"]
        into["key_field"] = with_key_field(into, into["name"])
        replace_row(into, row_line(into))
    run_builds(quiet=True)
    dropped = drop_import_source(row, rows)
    if dropped:
        print("deleted %s (no other block names it)" % dropped)
    n = retire([(k, "key") for k in keys] + [(g, "ident") for g in geos],
               "removed by tools/kit.py" + (" (saved bars load %s)" % into["slug"]
                                            if into is not None else ""))
    print("removed %s; %d names retired%s" % (row["name"], n,
          ("; saved bars load " + into["name"]) if into is not None else ""))
    changed(before)
    return 0
def cmd_size(args):
    sizes = actor_sizes()
    _, rows = blocks.read_manifest()
    cols = sum(os.path.getsize(os.path.join(ACTORS, n)) for n in os.listdir(ACTORS)
               if n.startswith("of_slp_") and n.endswith(".col"))
    total = 0
    if args.by_shape:
        per = {}
        for shapes in sizes.values():
            for shape, size in shapes.items():
                count, bytes_ = per.get(shape, (0, 0))
                per[shape] = (count + 1, bytes_ + size)
        for shape, (count, size) in sorted(per.items(), key=lambda kv: -kv[1][1]):
            print("  %-16s %3d pictures %10s" % (shape, count, kb(size)))
            total += size
    else:
        for row in rows:
            size = sum(sizes.get(row["slug"], {}).values())
            total += size
            print("  %-18s %-22s %3d pictures %10s" % (row["slug"], row["name"],
                  len(sizes.get(row["slug"], {})), kb(size)))
    print("blocks and shapes: %s, floors %s - added to every joiner's download"
          % (kb(total), kb(cols)))
    if args.release:
        rel = release_size()
        print("release (Lua stripped as release.py does): %.2f MB (%.2f MiB) - "
              "Lua %.2f MB, media %.2f MB, %d actor files; the wall is %.0f MiB"
              % (rel["total"] / 1e6, rel["total"] / MIB, rel["lua"] / 1e6, rel["media"] / 1e6,
                 rel["actors"], MAX_MOD_SIZE / MIB))
        for line in join_estimate(rel["total"], rel["files"]):
            print("  " + line)
    return 0
MIB = 1048576
MAX_MOD_SIZE = 35 * MIB
MEDIA_DIRS = ("actors", "data", "textures", "levels", "sound")
GROUP_BYTES = 40000
LIST_BYTES_PER_FILE = 110
def release_size(root=None):
    root = root or ROOT
    listed = subprocess.run(["git", "-C", root, "ls-files", "--", "*.lua"],
                            capture_output=True, text=True).stdout.split()
    lua = 0
    for name in listed:
        if "/" in name:
            continue
        out = subprocess.run([sys.executable, os.path.join(root, "tools", "strip-comments.py"),
                              "--tight", os.path.join(root, name)], capture_output=True).stdout
        lua += len(out)
    media = files = 0
    for folder in MEDIA_DIRS:
        for here, _, names in os.walk(os.path.join(root, folder)):
            for name in names:
                media += os.path.getsize(os.path.join(here, name))
                files += 1
    actors = len(os.listdir(os.path.join(root, "actors")))
    return {"lua": lua, "media": media, "total": lua + media, "files": files + len(listed),
            "actors": actors}
def join_seconds(size, files, rtt, mbit):
    rounds = math.ceil(size / GROUP_BYTES) / 2.0
    payload = size + files * LIST_BYTES_PER_FILE
    return rounds * rtt + payload * 8 / (mbit * 1e6)
def join_estimate(size, files):
    out = []
    for rtt, mbit in ((0.03, 50), (0.05, 10), (0.1, 10), (0.1, 2)):
        out.append("join: %4.0f s at %3d ms and %2d Mbit/s" % (
            join_seconds(size, files, rtt, mbit), rtt * 1000, mbit))
    return out
def cmd_long(args):
    slopes = _load("make_forgeslopes", "make-forgeslopes.py")
    have = slopes.long_slugs()
    word = (args.which or "show").strip()
    if word == "show":
        print("long pieces: %s" % (", ".join(have) if have else "none (tools/kit.py long on)"))
        return 0
    if word == "on":
        want = tuple(slopes.LONG_DEFAULT)
    elif word == "off":
        want = ()
    else:
        _, rows = blocks.read_manifest()
        want = tuple(find_row(rows, w.strip())["slug"] for w in word.split(",") if w.strip())
    before = total_size()
    lines = manifest_lines()
    text = "long: " + ", ".join(want)
    for index, line in enumerate(lines):
        if line.startswith("long:"):
            lines[index] = text
            break
    else:
        at = next(i for i, line in enumerate(lines) if line.startswith("template:"))
        lines.insert(at + 1, text)
    write_manifest(lines)
    run_builds(quiet=True)
    print("long pieces: %s" % (", ".join(want) if want else "none"))
    changed(before)
    return 0
def cmd_check(args):
    code = 0
    for tool in ("make-blocks.py", "make-forgeslopes.py", "prefabs.py"):
        path = os.path.join(HERE, tool)
        if not os.path.exists(path):
            continue
        result = subprocess.run([sys.executable, path, "--check"], capture_output=True, text=True)
        print((result.stdout + result.stderr).strip())
        code = code or result.returncode
    return code
def cmd_selftest(args):
    import shutil
    import tempfile
    Image = image_module()
    faults, said = [], []
    with tempfile.TemporaryDirectory(prefix="kit-selftest-") as tmp:
        for part in ("tools", "actors"):
            shutil.copytree(os.path.join(ROOT, part), os.path.join(tmp, part),
                            ignore=shutil.ignore_patterns("mapgen", "__pycache__"))
        os.makedirs(os.path.join(tmp, "tools", "mapgen"))
        shutil.copy(os.path.join(HERE, "mapgen", "kit.py"), os.path.join(tmp, "tools", "mapgen"))
        _, rows = blocks.read_manifest()
        twins = [blocks.HI_INDEX]
        for row in rows:
            for source in (row.get("layers") or [row["source"]]):
                dest = os.path.join(tmp, source)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                shutil.copy(os.path.join(ROOT, source), dest)
                twins.append(blocks.hi_twin(source))
        for twin in twins:
            if twin and os.path.isfile(os.path.join(ROOT, twin)):
                dest = os.path.join(tmp, twin)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                shutil.copy(os.path.join(ROOT, twin), dest)
        for source in _load("make_cube_template", "make-cube-template.py").inputs():
            dest = os.path.join(tmp, source)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copy(os.path.join(ROOT, source), dest)
        for name in ("of_spawner.lua", "of_forge.lua"):
            shutil.copy(os.path.join(ROOT, name), tmp)
        inbox = os.path.join(tmp, "incoming")
        os.makedirs(os.path.join(inbox, "Wood"))
        img = Image.new("RGB", (64, 64))
        for y in range(64):
            for x in range(64):
                v = int(120 + 40 * math.sin(math.pi * y / 8) + 20 * math.sin(math.pi * x / 16))
                img.putpixel((x, y), (v, v * 7 // 10, v * 4 // 10))
        img.save(os.path.join(inbox, "Wood", "test_planks.png"))
        grad = Image.new("RGB", (32, 32))
        for y in range(32):
            for x in range(32):
                grad.putpixel((x, y), (x * 8, 40, y * 8))
        grad.save(os.path.join(inbox, "seamy.png"))
        Image.new("RGB", (30, 30), (9, 9, 9)).save(os.path.join(inbox, "odd.png"))
        Image.new("RGBA", (32, 32), (9, 9, 9, 0)).save(os.path.join(inbox, "clear.png"))
        shutil.copy(os.path.join(ROOT, find_row(rows, "stone1")["source"]),
                    os.path.join(inbox, "stone_again.png"))
        def kit(*argv):
            result = subprocess.run([sys.executable, os.path.join(tmp, "tools", "kit.py")]
                                    + list(argv), cwd=tmp, capture_output=True, text=True)
            return result.returncode, result.stdout + result.stderr
        def has(name):
            return os.path.exists(os.path.join(tmp, "actors", name))
        def text(name):
            return open(os.path.join(tmp, name), encoding="utf-8").read()
        code, out = kit("import", inbox, "--shapes", "ramps", "--date", "0000")
        if code != 0 or out.count("refused:") != 4:
            faults.append("import: exit %d, %d refused (%s)" % (code, out.count("refused:"),
                                                               out.strip()[-300:]))
        if not (has("of_blk_testplanks_geo.bin") and has("of_slp_slope_testplanks_geo.bin")
                and has("of_slp_uslope_testplanks_geo.bin")
                and not has("of_slp_wall_testplanks_geo.bin")):
            faults.append("import: the cube and the ramps only were not built")
        if 'key = "blktestplanks", name = "Test planks", geo = "of_blk_testplanks_geo", ' \
                'tex = "of_blk_testplanks_texture"' not in text("of_spawner.lua"):
            faults.append("import: no Forge row with its own swatch")
        said.append("imported")
        code, out = kit("shapes", "testplanks", "walls")
        if code != 0 or not has("of_slp_wall_testplanks_geo.bin") \
                or has("of_slp_slope_testplanks_geo.bin"):
            faults.append("shapes: walls not in, ramps not out (%d)" % code)
        said.append("reshaped")
        code, out = kit("rename", "testplanks", "Oak boards")
        if code != 0 or "key=testplanks" not in text("tools/blocks-manifest.txt") \
                or 'name = "Oak boards", geo = "of_blk_testplanks_geo"' not in text("of_spawner.lua"):
            faults.append("rename: the key did not stay (%d)" % code)
        said.append("renamed")
        code, out = kit("rename", "testplanks", "Oak boards", "--new-key")
        if code != 0 or not has("of_blk_oakboards_geo.bin") or has("of_blk_testplanks_geo.bin") \
                or '["testplanks"] = "oakboards"' not in text("of_spawner.lua") \
                or "blktestplanks\tkey" not in text("tools/retired-names.txt"):
            faults.append("rename --new-key: no new key, fallback or retirement (%d)" % code)
        said.append("re-keyed")
        code, out = kit("remove", "oakboards", "--into", "darkplanks")
        if code != 0 or has("of_blk_oakboards_geo.bin") \
                or "was=oakboards,testplanks" not in text("tools/blocks-manifest.txt") \
                or '["oakboards"] = "darkplanks"' not in text("of_spawner.lua"):
            faults.append("remove --into: %d" % code)
        said.append("removed")
        code, out = kit("remove", "stone1")
        if code == 0 or not has("of_blk_stone1_geo.bin"):
            faults.append("remove: a block a venue uses went")
        said.append("refused a used one")
    if faults:
        print("kit selftest: " + "; ".join(faults))
        return 1
    print("kit selftest: " + ", ".join(said))
    return 0
def main(argv):
    if argv[:1] == ["prefab"]:
        prefabs = _load("prefabs", "prefabs.py")
        return prefabs.main(argv[1:])
    parser = argparse.ArgumentParser(prog="tools/kit.py", description="The Forge's asset pipeline: a folder of textures in, blocks out.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("import")
    p.add_argument("folder")
    p.add_argument("--shelf", default="Blocks")
    p.add_argument("--shapes", default=None)
    p.add_argument("--roles", default=None)
    p.add_argument("--date", default=None)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--allow-seams", action="store_true")
    sub.add_parser("list")
    p = sub.add_parser("shapes")
    p.add_argument("block")
    p.add_argument("spec")
    p = sub.add_parser("rename")
    p.add_argument("block")
    p.add_argument("name")
    p.add_argument("--new-key", action="store_true")
    p.add_argument("--plan", action="store_true",
                   help="say what a key move would re-code, change nothing")
    p.add_argument("--also", nargs="*", default=[],
                   help="more files to re-code: Studio maps (.ofmap), layouts, saves (.sav)")
    p.add_argument("--sav-dir", action="append", default=None,
                   help="a folder of Coop DX saves (default: its own sav folders)")
    p.add_argument("--no-saves", action="store_true", help="leave the game's saves alone")
    p = sub.add_parser("remove")
    p.add_argument("block")
    p.add_argument("--into", default=None)
    p.add_argument("--force", action="store_true")
    p = sub.add_parser("size")
    p.add_argument("--by-shape", action="store_true")
    p.add_argument("--release", action="store_true",
                   help="also the release size (Lua stripped) and a join-time estimate")
    p = sub.add_parser("long")
    p.add_argument("which", nargs="?", default="show",
                   help="on (the 20 they had), off, show, or a comma list of blocks")
    sub.add_parser("check")
    sub.add_parser("selftest")
    args = parser.parse_args(argv)
    try:
        return {"import": cmd_import, "list": cmd_list, "shapes": cmd_shapes,
                "rename": cmd_rename, "remove": cmd_remove, "size": cmd_size,
                "check": cmd_check, "selftest": cmd_selftest, "long": cmd_long}[args.command](args)
    except Refused as why:
        print("kit: %s" % why)
        return 1
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
