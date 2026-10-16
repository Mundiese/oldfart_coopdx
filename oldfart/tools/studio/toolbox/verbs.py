from mapgen import detailrules as rules
from studio.editor import geometry as geo
from studio.editor.commands import Change
ORDER = rules.ORDER
STATE_COLOURS = {"ok": (90, 190, 110), "warn": (230, 170, 60), "bad": (220, 70, 70)}
def label(rule_id):
    return rules.RULES[rule_id].verb
def about(rule_id):
    return rules.RULES[rule_id].about
def theme_of(doc):
    from studio.toolbox import dress
    return dress.theme_of(doc)
def _scope(doc, refs, rule):
    pieces = [(r, doc.get(r)) for r in (refs or doc.refs("piece")) if r[0] == "piece" and r in doc]
    return [(r, p) for r, p in pieces if rule.applies(p)]
def made(doc, refs, rule_id, theme=None, seed=1):
    rule = rules.RULES[rule_id]
    theme = theme or theme_of(doc)
    scope = _scope(doc, refs, rule)
    if rule.make is None:
        return [], len(scope)
    ctx = rules.Ctx(theme, seed)
    out = []
    for _, p in scope:
        out += rule.make(p, ctx)
    return [geo.cleaned(p) for p in out], len(scope)
def preview(doc, refs, rule_id, theme=None, seed=1):
    theme = theme or theme_of(doc)
    rule = rules.RULES[rule_id]
    pieces = [doc.get(r) for r in doc.refs("piece")]
    if rule.make is None:
        ch, _ = _delegated(doc, refs, rule_id, theme, seed)
        new = [s[3] for s in ch.steps if s[0] == "insert"]
    else:
        new, _ = made(doc, refs, rule_id, theme, seed)
    return rules.bands(pieces, new, theme)
def _delegated(doc, refs, rule_id, theme, seed):
    rule = rules.RULES[rule_id]
    if rule.delegate == "autoshape":
        from studio.toolbox import autoshape
        box = None
        sel = [doc.get(r) for r in (refs or []) if r in doc]
        if sel:
            b = geo.union(geo.aabb(p) for p in sel)
            box = (b[0], b[1], b[4], b[5])
        ch, n = autoshape.autoshape(doc, box=box)
        ch.label = "Soften steps: %d slope%s" % (n, "" if n == 1 else "s")
        return ch, n
    from studio.toolbox import dress
    which = rule.delegate.split(":", 1)[1]
    ch, rep = dress.auto_dress(doc, refs or None, theme=theme, rules=(which,), seed=seed)
    ch.label = "%s (%s)" % (rule.verb, ", ".join(rep.lines()))
    return ch, sum(rep.rules.values())
def apply_verb(doc, refs, rule_id, theme=None, seed=1):
    from studio.editor import ops
    from studio.toolbox import dress
    theme = theme or theme_of(doc)
    rule = rules.RULES[rule_id]
    pieces = [doc.get(r) for r in doc.refs("piece")]
    if rule.make is None:
        ch, n = _delegated(doc, refs, rule_id, theme, seed)
        new = [s[3] for s in ch.steps if s[0] == "insert"]
        return ch, rules.bands(pieces, new, theme), [ch.label]
    new, n = made(doc, refs, rule_id, theme, seed)
    if not new:
        return Change("%s: nothing it fits" % rule.verb, []), rules.bands(pieces, [], theme), \
            ["%s fits none of the selection (%s)" % (rule.verb, rule.about)]
    bands = rules.bands(pieces, new, theme)
    all_refs = doc.refs("piece")
    current = {r: dict(doc.get(r)) for r in all_refs}
    steps = dress._resolved_steps(doc, current, all_refs, new)
    if not steps:
        steps = ops.insert(doc, [("piece", p) for p in new], rule_id, select=False).steps
    ch = Change("%s: %d piece%s on %d" % (rule.verb, len(new), "" if len(new) == 1 else "s", n),
                steps)
    ch.twins = True
    lines = [ch.label] + ["%s: %s" % (b["name"], b["text"]) for b in bands if b["state"] != "ok"]
    return ch, bands, lines
