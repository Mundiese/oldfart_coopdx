import copy
LIMIT = 500
class Change:
    refused = False
    def __init__(self, label, steps=None, merge=None, hand=True, select=None):
        self.label = label
        self.steps = list(steps or [])
        self.merge = merge
        self.hand = hand
        self.select = select
        self.select_before = None
    def __bool__(self):
        return bool(self.steps)
    def __repr__(self):
        return "<Change %s: %d steps>" % (self.label, len(self.steps))
def refusal(text):
    ch = Change(text)
    ch.refused = True
    return ch
def apply_step(doc, step):
    op = step[0]
    if op == "insert":
        _, ref, index, item = step
        doc.insert(ref, copy.deepcopy(item), index)
    elif op == "remove":
        _, ref, _, _ = step
        doc.remove(ref)
    elif op == "replace":
        _, ref, _, after = step
        doc.replace(ref, copy.deepcopy(after))
    elif op == "brief":
        doc.set_brief(step[2])
    elif op == "rest":
        _, key, _, after = step
        doc.set_rest(key, after)
    elif op == "state":
        doc.restore(step[2])
    elif op == "meta":
        _, key, _, after = step
        doc.set_meta(key, after)
    else:
        raise ValueError("unknown step %r" % (op,))
def revert_step(doc, step):
    op = step[0]
    if op == "insert":
        doc.remove(step[1])
    elif op == "remove":
        _, ref, index, item = step
        doc.insert(ref, copy.deepcopy(item), index)
    elif op == "replace":
        _, ref, before, _ = step
        doc.replace(ref, copy.deepcopy(before))
    elif op == "brief":
        doc.set_brief(step[1])
    elif op == "rest":
        _, key, before, _ = step
        doc.set_rest(key, before)
    elif op == "state":
        doc.restore(step[1])
    elif op == "meta":
        _, key, before, _ = step
        doc.set_meta(key, before)
    else:
        raise ValueError("unknown step %r" % (op,))
def apply(doc, change):
    for step in change.steps:
        apply_step(doc, step)
def revert(doc, change):
    for step in reversed(change.steps):
        revert_step(doc, step)
def _merged(a, b):
    steps = list(a.steps)
    for step in b.steps:
        if step[0] == "replace":
            for n, old in enumerate(steps):
                if old[0] == "replace" and old[1] == step[1]:
                    steps[n] = ("replace", step[1], old[2], step[3])
                    break
            else:
                steps.append(step)
        else:
            steps.append(step)
    out = Change(b.label, steps, b.merge, a.hand or b.hand, b.select)
    out.select_before = a.select_before
    return out
class CommandStack:
    def __init__(self, doc, limit=LIMIT):
        self.doc = doc
        self.done = []
        self.undone = []
        self.limit = limit
        self.clean_at = 0
        self.listeners = []
        self.selection = None
        self.filters = []
        self.guard = None
        self.refused = None
    def _tell(self, what, change):
        for fn in list(self.listeners):
            fn(what, change)
    def push(self, change, mergeable=True):
        if not change:
            return False
        self.refused = None
        for fn in list(self.filters):
            change = fn(self.doc, change) or change
        if self.guard is not None:
            no = self.guard(self.doc, change)
            if no is not None:
                self.refused = no
                self._tell("refused", no)
                return False
        if self.undone and self.clean_at is not None and self.clean_at > len(self.done):
            self.clean_at = None
        if self.selection is not None:
            change.select_before = list(self.selection.refs)
        apply(self.doc, change)
        top = self.done[-1] if self.done else None
        if (mergeable and change.merge is not None and top is not None and
                top.merge == change.merge and not self.undone and
                self.clean_at != len(self.done)):
            self.done[-1] = _merged(top, change)
        else:
            self.done.append(change)
            if len(self.done) > self.limit:
                drop = len(self.done) - self.limit
                del self.done[:drop]
                if self.clean_at is not None:
                    self.clean_at -= drop
                    if self.clean_at < 0:
                        self.clean_at = None
        self.undone = []
        self._select(change.select)
        self._tell("push", change)
        return True
    def _select(self, refs):
        if self.selection is not None and refs is not None:
            self.selection.set([r for r in refs if r in self.doc])
    def can_undo(self):
        return bool(self.done)
    def can_redo(self):
        return bool(self.undone)
    def undo(self):
        if not self.done:
            return None
        change = self.done.pop()
        revert(self.doc, change)
        self.undone.append(change)
        self._select(change.select_before)
        self._tell("undo", change)
        return change
    def redo(self):
        if not self.undone:
            return None
        change = self.undone.pop()
        apply(self.doc, change)
        self.done.append(change)
        self._select(change.select)
        self._tell("redo", change)
        return change
    def undo_to(self, n):
        while len(self.done) > n and self.undo():
            pass
        while len(self.done) < n and self.redo():
            pass
    def hand_edits(self):
        n = 0
        for c in reversed(self.done):
            if not c.hand:
                break
            n += 1
        return n
    def labels(self):
        return [(c.label, True) for c in self.done] + \
            [(c.label, False) for c in reversed(self.undone)]
    def mark_clean(self):
        self.clean_at = len(self.done)
        self._tell("clean", None)
    def is_clean(self):
        return self.clean_at == len(self.done)
    def clear(self):
        self.done, self.undone = [], []
        self.clean_at = 0
        self._tell("clean", None)
