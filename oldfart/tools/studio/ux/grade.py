from dataclasses import dataclass
A_FROM = 85.0
B_FROM = 72.0
D_UNDER = 15.0
LETTERS = ("A", "B", "C", "D", "E")
WORDS = {"A": "Wow - a great map!", "B": "Good map!", "C": "Nice - it works",
         "D": "Getting there", "E": "Let's fix it together", "-": "Build something"}
MOODS = {"A": 1.0, "B": 0.6, "C": 0.2, "D": -0.3, "E": -0.7, "-": 0.0}
MEANING = {"A": "good", "B": "good", "C": "good", "D": "warn", "E": "bad", "-": "none"}
EMPTY_TIP = "Put something down and I'll tell you what I think"
GOOD_TIP = "Nothing to fix - try Walk it (F8) and play it!"
@dataclass
class Grade:
    letter: str
    score: float
    line: float
    mood: float
    words: str
    tip: str
    row: str = ""
    fixable: bool = False
    @property
    def meaning(self):
        return MEANING[self.letter]
    def rank(self):
        return 0 if self.letter == "-" else 5 - LETTERS.index(self.letter)
def letter_of(score, line=58.0):
    if score is None:
        return "-"
    if score >= A_FROM:
        return "A"
    if score >= B_FROM:
        return "B"
    if score >= line:
        return "C"
    if score >= line - D_UNDER:
        return "D"
    return "E"
def _worst(res):
    rows = [r for r in (res or {}).get("rows") or [] if r.state != "ok"]
    if not rows:
        return None, None
    worst = res.get("worst")
    for r in rows:
        if r.key == worst:
            return r.key, r
    r = min(rows, key=lambda r: r.score)
    return r.key, r
def _explain(key):
    try:
        from mapgen import critic
        return critic.EXPLAIN.get(key, "")
    except Exception:
        return ""
def grade(res):
    if not res:
        return Grade("-", 0.0, 0.0, MOODS["-"], WORDS["-"], EMPTY_TIP)
    score = float(res.get("score") or 0.0)
    line = float(res.get("line") or 58.0)
    letter = letter_of(score, line)
    key, row = _worst(res)
    if row is None:
        tip, key, fixable = GOOD_TIP, "", False
    else:
        from studio.editor import critic_live, criticfix
        tip = critic_live.ADVICE.get(key) or _explain(key) or row.text()
        fixable = criticfix.has_fix(key) and key not in criticfix.MODE_ROWS
    mood = MOODS[letter]
    mood = max(-1.0, min(1.0, mood + (score - line) / 400.0))
    return Grade(letter, score, line, round(mood, 3), WORDS[letter], tip, key or "", fixable)
def change(before, after):
    if before is None or after is None:
        return ""
    if after.rank() > before.rank() and before.letter != "-":
        return "up"
    if after.rank() < before.rank() and after.letter != "-":
        return "down"
    return ""
