GROUPS = (
    ("star", "Bonus stars"),
    ("spawn", "Spawns"),
    ("flank", "Flank zones"),
    ("survey", "Survey points"),
    ("flag", "Flags"),
    ("race", "Race markers"),
    ("mover", "Movers"),
    ("object", "Objects"),
    ("anchor", "Anchors"),
)
TITLES = dict(GROUPS)
STAR_NUMBERS = 6
NAME_MAX = 40
class Row:
    __slots__ = ("index", "group", "text", "ref", "number", "name", "issues", "label")
    def __init__(self, index, group, text, ref=None, number=None, name=None, label=""):
        self.index = index
        self.group = group
        self.text = text
        self.ref = ref
        self.number = number
        self.name = name
        self.issues = []
        self.label = label
    def editable(self):
        return self.group == "star" and self.ref is not None
    def __repr__(self):
        return "<Row %s %r>" % (self.group, self.text)
class Group:
    __slots__ = ("key", "title", "rows")
    def __init__(self, key, rows):
        self.key, self.title, self.rows = key, TITLES[key], rows
    def issue_count(self):
        return sum(len(r.issues) for r in self.rows)
def _ref(marker):
    data = getattr(marker, "data", None)
    if isinstance(data, tuple) and len(data) == 2 and isinstance(data[0], str):
        return data
    return None
def _item(marker, doc):
    ref = _ref(marker)
    if ref is not None and doc is not None:
        return doc.get(ref)
    data = getattr(marker, "data", None)
    return data if isinstance(data, dict) else None
def group_of(marker, item=None):
    kind = marker.kind
    ref = _ref(marker)
    label = str(marker.label or "")
    if kind == "star":
        return "star"
    if kind == "spawn":
        return "spawn"
    if kind == "survey":
        return "flank" if label.lower().startswith("flank") else "survey"
    if kind == "anchor":
        what = (item or {}).get("what") if isinstance(item, dict) else None
        if what == "flag" or (what is None and label.lower().startswith("flag")):
            return "flag"
        return "anchor"
    if kind == "race":
        return "race"
    if kind == "object":
        if (ref is not None and ref[0] == "mover") or label.endswith("(path)"):
            return "mover"
        return "object"
    return "anchor"
def _flank_words(label):
    rest = label[len("flank"):]
    side, _, num = rest.partition(" ")
    side = side or "?"
    return ("%s flank %s" % (side, num)).strip()
def _star_number(item):
    n = (item or {}).get("id")
    return n if isinstance(n, int) else None
def build(markers, doc=None):
    by = {key: [] for key, _ in GROUPS}
    spawn_n = 0
    for i, m in enumerate(markers):
        item = _item(m, doc)
        g = group_of(m, item)
        ref = _ref(m)
        label = str(m.label or "")
        if g == "star":
            n = _star_number(item)
            name = str((item or {}).get("name") or "")
            row = Row(i, g, "%s  %s" % (n if n is not None else "?", name or "(no name)"),
                      ref, n, name, label=("%s %s" % (n if n is not None else "?", name)).rstrip())
        elif g == "spawn" and ref is not None and ref[0] == "spot":
            row = Row(i, g, "World spawn", ref, label="world")
        elif g == "spawn":
            spawn_n += 1
            row = Row(i, g, "Spawn %d" % spawn_n, ref, spawn_n, label=str(spawn_n))
        elif g == "flank":
            words = _flank_words(label)
            row = Row(i, g, words, ref, label=words)
        else:
            row = Row(i, g, label or TITLES[g], ref, label=label)
        by[g].append(row)
    by["star"].sort(key=lambda r: (r.number is None, r.number or 0, r.index))
    out = [Group(key, by[key]) for key, _ in GROUPS if by[key]]
    attach_issues(out, doc)
    return out
def attach_issues(groups, doc=None):
    rows = [r for g in groups for r in g.rows]
    stars = [r for r in rows if r.group == "star"]
    seen = {}
    for r in stars:
        if r.number is not None:
            seen.setdefault(r.number, []).append(r)
    for r in stars:
        if r.number is None or not 1 <= r.number <= STAR_NUMBERS:
            r.issues.append("its number must be 1 to %d" % STAR_NUMBERS)
        elif len(seen[r.number]) > 1:
            r.issues.append("number %d is used by %d stars" % (r.number, len(seen[r.number])))
        if not r.name:
            r.issues.append("no name - the star select shows \"Star %s\""
                            % (r.number if r.number is not None else "?"))
    if len(stars) > STAR_NUMBERS:
        for r in stars:
            r.issues.append("%d stars - a world holds %d at most" % (len(stars), STAR_NUMBERS))
    if doc is None:
        return groups
    try:
        from studio.toolbox import stars as starsmod
        found = starsmod.issues(doc, reach=False)
    except Exception:
        found = []
    by_ref = {}
    for r in rows:
        if r.ref is not None:
            by_ref[r.ref] = r
    for issue in found:
        text = issue.text
        for ref in issue.refs:
            r = by_ref.get(ref)
            if r is None or _covered(r.issues, text):
                continue
            r.issues.append(text)
    return groups
def _covered(have, text):
    t = text.lower()
    for h in have:
        hl = h.lower()
        if "used by" in hl and "is used" in t:
            return True
        if "must be 1" in hl and "must be 1" in t:
            return True
        if "no name" in hl and "no name" in t:
            return True
        if "at most" in hl and "at most" in t:
            return True
    return False
def find_row(groups, index):
    for g in groups:
        for r in g.rows:
            if r.index == index:
                return r
    return None
DEFAULT_SHOWN = frozenset(("star", "spawn"))
def labels(groups, shown):
    out = []
    for g in groups:
        if g.key not in shown:
            continue
        for r in g.rows:
            if r.label:
                out.append((r.index, r.label, g.key, bool(r.issues)))
    return out
def shown_from(value):
    if not isinstance(value, (list, tuple, set, frozenset)):
        return set(DEFAULT_SHOWN)
    return set(k for k in value if k in TITLES)
def edit_text(row):
    return ("%s %s" % (row.number if row.number is not None else "", row.name or "")).strip()
def parse_edit(text):
    text = " ".join(str(text or "").split())
    head, _, rest = text.partition(" ")
    number = None
    if head.isdigit():
        number = int(head)
        if not 1 <= number <= STAR_NUMBERS:
            raise ValueError("a bonus star's number is 1 to %d" % STAR_NUMBERS)
        name = rest or None
    else:
        name = text or None
    if name is not None:
        name = name[:NAME_MAX]
    return number, name
def edit_apply(doc, row, text, push):
    from studio.editor import ops
    if not row.editable():
        return 0
    number, name = parse_edit(text)
    made = 0
    if number is not None and number != row.number:
        change = ops.set_star_number(doc, row.ref, number)
        if change:
            push(change)
            made += 1
    if name is not None and name != (row.name or ""):
        change = ops.set_star_name(doc, row.ref, name)
        if change:
            push(change)
            made += 1
    return made
