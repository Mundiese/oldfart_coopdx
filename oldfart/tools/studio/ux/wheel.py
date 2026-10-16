import math
SLICES = 8
DEAD = 18
DEFAULT = ["hotbar.slot1", "tools.brush_paint", "tools.brush_raise", "tools.brush_lower",
           "tools.room", "house.brush", "tools.symmetry", "edit.undo"]
WORDS = {"hotbar.slot1": "Place last", "tools.brush_paint": "Paint",
         "tools.brush_raise": "Raise", "tools.brush_lower": "Lower", "tools.room": "Room",
         "house.brush": "Houses", "tools.symmetry": "Symmetry", "edit.undo": "Undo"}
def slice_of_angle(dx, dy, n=SLICES):
    a = math.degrees(math.atan2(dx, -dy)) % 360.0
    return int(((a + 180.0 / n) % 360.0) // (360.0 / n))
class Wheel:
    def __init__(self, pages=None):
        self.pages = [list(p) + [None] * (SLICES - len(p)) for p in (pages or [DEFAULT])]
        self.page = 0
    def entry(self, page, k):
        if 0 <= page < len(self.pages) and 0 <= k < SLICES:
            return self.pages[page][k]
        return None
    def slice_at(self, dx, dy):
        if math.hypot(dx, dy) < DEAD:
            return None
        return slice_of_angle(dx, dy)
    def pick(self, dx, dy):
        k = self.slice_at(dx, dy)
        return None if k is None else self.entry(self.page, k)
    def add(self, entry):
        for p, page in enumerate(self.pages):
            if entry in page:
                return p, page.index(entry)
        for p, page in enumerate(self.pages):
            for k, e in enumerate(page):
                if e is None:
                    page[k] = entry
                    return p, k
        self.pages.append([entry] + [None] * (SLICES - 1))
        return len(self.pages) - 1, 0
    def put(self, page, k, entry):
        while page >= len(self.pages):
            self.pages.append([None] * SLICES)
        self.pages[page][k] = entry
    def remove(self, page, k):
        self.pages[page][k] = None
        while len(self.pages) > 1 and not any(self.pages[-1]):
            self.pages.pop()
        self.page = min(self.page, len(self.pages) - 1)
    def turn_page(self, step):
        self.page = (self.page + step) % len(self.pages)
        return self.page
    def state(self):
        return {"pages": [list(p) for p in self.pages]}
    @classmethod
    def from_state(cls, state):
        pages = (state or {}).get("pages")
        if not isinstance(pages, list) or not pages:
            return cls()
        good = [[e if isinstance(e, str) else None for e in p][:SLICES] for p in pages
                if isinstance(p, list)]
        return cls(good or None)
