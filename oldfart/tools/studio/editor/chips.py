import re
FAMILY_RE = re.compile(r"\bfamily (\w+)")
class Chip:
    def __init__(self, kind, text, word=None, options=None, field=None, why=None,
                 rephrase=None):
        self.kind = kind
        self.text = text
        self.word = word
        self.options = list(options or [])
        self.field = field
        self.why = why
        self.rephrase = list(rephrase or [])
    def __repr__(self):
        return "Chip(%s, %r%s)" % (self.kind, self.text,
                                   ", %r" % self.options if self.options else "")
def _families():
    from mapgen import brief
    return list(brief.FAMILIES)
def chips(reading):
    from mapgen import lexicon
    if reading is None:
        return []
    out = []
    for line in getattr(reading, "understood", []) or []:
        kind = "taught" if line.startswith("taught:") else "understood"
        out.append(Chip(kind, line))
    for line in getattr(reading, "assumed", []) or []:
        m = FAMILY_RE.search(line)
        if m and m.group(1) in _families():
            out.append(Chip("assumed", line, options=[f for f in _families()
                                                      if f != m.group(1)], field="family"))
        else:
            out.append(Chip("assumed", line))
    heard_in = getattr(reading, "heard_in", {}) or {}
    from mapgen import clarity
    plain = {n["words"]: n for n in clarity.panel(reading)["not_understood"]} \
        if getattr(reading, "not_understood", None) else {}
    for group in getattr(reading, "not_understood", []) or []:
        word = group if re.fullmatch(r"[a-z\u00e4\u00f6\u00fc\u00df'\-]{2,40}", group) else None
        sugg = ["%s (%s)" % (f, cid) for f, cid, _ in lexicon.suggest(word)] if word else []
        where = heard_in.get(group)
        tries = (plain.get(group) or {}).get("try") or []
        out.append(Chip("unread", group if not where or where.strip() == group else
                        "%s (in %r)" % (group, where.strip()), word=word,
                        options=sugg + tries + (["teach '%s' ..." % word] if word else []),
                        why=(plain.get(group) or {}).get("why"), rephrase=tries))
    for q in getattr(reading, "questions", []) or []:
        out.append(Chip("question", q.get("ask", ""), options=q.get("options") or []))
    return out
def teach(word, meaning):
    from mapgen import userlex
    return userlex.teach(word, meaning)
def apply_choice(chip, option, text):
    if chip.kind == "assumed" and chip.field == "family":
        return ("control", "family", option)
    if option in getattr(chip, "rephrase", ()):
        return ("text", option)
    if chip.kind == "unread" and chip.word and not option.startswith("teach "):
        form = option.split(" (")[0]
        edge = r"\w\u00e4\u00f6\u00fc\u00df"
        new = re.sub(r"(?i)(?<![%s])%s(?![%s])" % (edge, re.escape(chip.word), edge),
                     form, text, 1)
        return ("text", new)
    if chip.kind == "question":
        return ("text", (text.rstrip().rstrip(".,;") + ", " + option).strip(", "))
    return None
def export_taught(path):
    from mapgen import userlex
    return userlex.export(path)
