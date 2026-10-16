import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "dict", "common_guard.txt")
TOP = 40000
_words = None
def words():
    global _words
    if _words is None:
        out = set()
        try:
            with open(PATH, encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        out.add(line)
        except OSError:
            pass
        _words = frozenset(out)
    return _words
def ordinary(word):
    return word in words()
def _changed(w):
    from . import lexicon, wish
    fixed, _ = wish.correct(w, guard=False)
    if fixed != w:
        return True
    if lexicon.index().get(w):
        return False
    return bool(lexicon.fuzzy(w) or lexicon.swapped(w) or lexicon.everyday_typo(w))
def build(top=TOP):
    from wordfreq import top_n_list
    from . import wish
    keep = set()
    for lang in ("de", "en"):
        for w in top_n_list(lang, top):
            f = wish.fold(w)
            if len(f) < 4 or not f.isalpha() or f in keep:
                continue
            try:
                if _changed(f):
                    keep.add(f)
            except Exception:
                continue
    with open(PATH, "w", encoding="utf-8") as fh:
        fh.write("# Everyday words the wish reader's typo fixer must not change "
                 "(mapgen/commonguard.py).\n# Built from wordfreq's German and English "
                 "frequency lists (CC BY-SA 4.0, Robyn Speer).\n")
        for w in sorted(keep):
            fh.write(w + "\n")
    return len(keep)
if __name__ == "__main__":
    if "--build" in sys.argv:
        print("kept", build())
