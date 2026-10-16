SLOTS = 9
def key_for(slot, emulate_numpad=False):
    return ("Alt+%d" if emulate_numpad else "%d") % (slot + 1)
class Hotbar:
    def __init__(self, n=SLOTS):
        self.n = n
        self.pins = {}
        self.slots = [None] * n
        self.current = 0
        self._recent = []
    def fill(self, recent):
        self._recent = list(recent)
        pinned = set(self.pins.values())
        free = [e for e in self._recent if e not in pinned]
        out = []
        for k in range(self.n):
            if k in self.pins:
                out.append(self.pins[k])
            else:
                out.append(free.pop(0) if free else None)
        self.slots = out
        return out
    def pin(self, slot, entry_id):
        if not 0 <= slot < self.n:
            raise IndexError(slot)
        for k, e in list(self.pins.items()):
            if e == entry_id:
                del self.pins[k]
        self.pins[slot] = entry_id
        return self.fill(self._recent)
    def unpin(self, slot):
        self.pins.pop(slot, None)
        return self.fill(self._recent)
    def pinned(self, slot):
        return slot in self.pins
    def get(self, slot):
        return self.slots[slot] if 0 <= slot < self.n else None
    def cycle(self, step):
        held = [k for k, e in enumerate(self.slots) if e]
        if not held:
            return None
        k = self.current
        for _ in range(self.n):
            k = (k + step) % self.n
            if self.slots[k]:
                self.current = k
                return k
        return None
    def state(self):
        return {"pins": {str(k): e for k, e in self.pins.items()}}
    def restore(self, state, known=None):
        pins = (state or {}).get("pins") or {}
        self.pins = {}
        for k, e in pins.items():
            try:
                k = int(k)
            except ValueError:
                continue
            if 0 <= k < self.n and (known is None or e in known):
                self.pins[k] = e
        return self.fill(self._recent)
