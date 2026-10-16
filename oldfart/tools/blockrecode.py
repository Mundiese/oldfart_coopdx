#!/usr/bin/env python3
import importlib.util
import json
import os
import re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ACTORS = os.path.join(ROOT, "actors")
PIECE_TEX = ("tex", "tex_top", "tex_side", "tex_bottom")
MODEL_PREFIX = "of_ak_"
BAR_KEY = "forge_bar"
PAGE_SEP = ";"
DRAFT_KEY = "prefab_draft"
DRAFT_PART = 900
DRAFT_PARTS = 16
VALUE_MAX = 1023
_blocks = None
def _make_blocks():
    global _blocks
    if _blocks is None:
        spec = importlib.util.spec_from_file_location("make_blocks_recode",
                                                      os.path.join(HERE, "make-blocks.py"))
        _blocks = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_blocks)
    return _blocks
def was_map(rows=None):
    if rows is None:
        _, rows = _make_blocks().read_manifest()
    out = {}
    for row in rows:
        for old in row.get("was") or ():
            out[old] = row["slug"]
    return out
def shape_tags(actors=ACTORS):
    tags = set()
    if os.path.isdir(actors):
        for name in os.listdir(actors):
            found = re.match(r"^of_slp_([a-z]+)_[a-z0-9]+_geo\.bin$", name)
            if found:
                tags.add(found.group(1))
    if actors == ACTORS:
        spec = importlib.util.spec_from_file_location("make_forgeslopes_recode",
                                                      os.path.join(HERE, "make-forgeslopes.py"))
        slopes = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(slopes)
        tags |= {v["tag"] for v in slopes.variants()}
    return tags | {"u" + t for t in tags if not t.startswith("u")}
def renamed_key(key, mapping, tags=None):
    if not isinstance(key, str) or not mapping:
        return None
    tags = shape_tags() if tags is None else tags
    for prefix in ["blk"] + sorted(tags, key=len, reverse=True):
        if key.startswith(prefix) and key[len(prefix):] in mapping:
            return prefix + mapping[key[len(prefix):]]
    return None
def _model(model, mapping):
    if isinstance(model, str) and model.startswith(MODEL_PREFIX):
        rest = model[len(MODEL_PREFIX):]
        for old in sorted(mapping, key=len, reverse=True):
            if rest.startswith(old + "_"):
                return MODEL_PREFIX + mapping[old] + rest[len(old):]
    return model
def recode_layout(data, mapping):
    if not mapping:
        return 0
    count = 0
    stack = [data]
    while stack:
        item = stack.pop()
        if isinstance(item, dict):
            if "kind" in item:
                for field in PIECE_TEX:
                    tex = item.get(field)
                    if isinstance(tex, str) and tex in mapping:
                        item[field] = mapping[tex]
                        count += 1
                if "model" in item:
                    item["model"] = _model(item["model"], mapping)
            pal = item.get("palette")
            if isinstance(pal, dict):
                for role, seq in pal.items():
                    if isinstance(seq, list):
                        new = [mapping.get(s, s) if isinstance(s, str) else s for s in seq]
                        count += sum(1 for a, b in zip(seq, new) if a != b)
                        pal[role] = new
            stack.extend(v for k, v in item.items() if k != "palette")
        elif isinstance(item, list):
            stack.extend(item)
    return count
def recode_prefab(prefab, mapping):
    count = 0
    for piece in prefab.get("pieces") or ():
        if len(piece) > 4 and isinstance(piece[4], str) and piece[4] in mapping:
            piece[4] = mapping[piece[4]]
            count += 1
    roles = prefab.get("roles")
    if isinstance(roles, dict):
        for role, slug in list(roles.items()):
            if slug in mapping:
                roles[role] = mapping[slug]
                count += 1
    return count
def recode_draft(text, mapping):
    if not mapping or not text:
        return text, 0
    items = text.split(";")
    count = 0
    for i, item in enumerate(items[1:], 1):
        parts = item.split(".")
        if len(parts) == 7 and parts[0] != "lg" and parts[1] in mapping:
            parts[1] = mapping[parts[1]]
            items[i] = ".".join(parts)
            count += 1
        elif len(parts) in (11, 12) and parts[0] == "mv" and parts[2] in mapping:
            parts[2] = mapping[parts[2]]
            items[i] = ".".join(parts)
            count += 1
    return ";".join(items), count
_LINE = re.compile(r"^(\s*)([^=\s][^=]*?)(\s*=\s*)(.*?)(\s*)$")
def recode_save(text, mapping, tags=None):
    if not mapping:
        return text, 0, []
    tags = shape_tags() if tags is None else tags
    lines = text.split("\n")
    notes, count = [], 0
    drafts = {}
    for i, line in enumerate(lines):
        found = _LINE.match(line)
        if not found:
            continue
        key, value = found.group(2), found.group(4)
        if key == BAR_KEY:
            pages = []
            n = 0
            for page in value.split(PAGE_SEP):
                keys = []
                for k in page.split(","):
                    new = renamed_key(k, mapping, tags) if k else None
                    if new:
                        n += 1
                    keys.append(new or k)
                pages.append(",".join(keys))
            new_value = PAGE_SEP.join(pages)
            if n and len(new_value) > VALUE_MAX:
                notes.append("the Forge bar would be longer than a save value may be (%d of %d "
                             "characters), so it stays - the game reads its old keys through "
                             "BLOCK_WAS" % (len(new_value), VALUE_MAX))
            elif n:
                lines[i] = found.group(1) + key + found.group(3) + new_value + found.group(5)
                count += n
        draft = re.match(r"^%s(\d+)$" % DRAFT_KEY, key)
        if draft:
            drafts[int(draft.group(1))] = (i, found)
    if drafts:
        order = sorted(drafts)
        joined = "".join(drafts[k][1].group(4) for k in order)
        new, n = recode_draft(joined, mapping)
        if n:
            parts = [new[j:j + DRAFT_PART] for j in range(0, len(new), DRAFT_PART)]
            if len(parts) > max(DRAFT_PARTS, len(order)):
                notes.append("the prefab draft would not fit in %d parts after the rename, so "
                             "it stays - prefabs.py import-save translates it as it reads it"
                             % DRAFT_PARTS)
            else:
                for slot, k in enumerate(order):
                    i, found = drafts[k]
                    part = parts[slot] if slot < len(parts) else ""
                    lines[i] = found.group(1) + found.group(2) + found.group(3) + part \
                        + found.group(5)
                if len(parts) > len(order):
                    last = drafts[order[-1]][0]
                    extra = ["%s%d = %s" % (DRAFT_KEY, order[-1] + j + 1, p)
                             for j, p in enumerate(parts[len(order):])]
                    lines[last + 1:last + 1] = extra
                count += n
    return "\n".join(lines), count, notes
def sav_dirs(home=None):
    home = home or os.path.expanduser("~")
    out = [os.path.join(home, ".local", "share", "sm64coopdx", "sav")]
    flat = os.path.join(home, ".var", "app")
    if os.path.isdir(flat):
        for app in sorted(os.listdir(flat)):
            out.append(os.path.join(flat, app, "data", "sm64coopdx", "sav"))
    return [d for d in out if os.path.isdir(d)]
def forge_saves(dirs=None):
    out = []
    for folder in (sav_dirs() if dirs is None else dirs):
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            path = os.path.join(folder, name)
            if not name.endswith(".sav") or not os.path.isfile(path):
                continue
            try:
                with open(path, encoding="utf-8", errors="replace") as handle:
                    text = handle.read()
            except OSError:
                continue
            if re.search(r"^\s*(%s|%s\d+)\s*=" % (BAR_KEY, DRAFT_KEY), text, re.M):
                out.append(path)
    return out
def recode_file(path, mapping, tags=None):
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    if path.endswith(".sav"):
        new, n, notes = recode_save(text, mapping, tags)
        return (new if n else None), n, notes
    data = json.loads(text)
    if path.endswith(".prefab"):
        n = recode_prefab(data, mapping)
        new = prefab_text(data)
    else:
        n = recode_layout(data, mapping)
        new = json.dumps(data, indent=1, sort_keys=True) + "\n"
    return (new if n else None), n, []
def prefab_text(prefab):
    head = {k: v for k, v in prefab.items() if k not in ("pieces", "key")}
    text = json.dumps(head, indent=2)
    pieces = ",\n".join("    " + json.dumps(p) for p in prefab["pieces"])
    return text[:-2] + ',\n  "pieces": [\n' + pieces + "\n  ]\n}\n"
def write_atomic(path, text):
    tmp = path + ".recode.tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)
