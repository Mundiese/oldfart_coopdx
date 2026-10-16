import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
STUDIO = os.path.dirname(HERE)
TOOLS = os.path.dirname(STUDIO)
REPO = os.path.dirname(TOOLS)
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
from mapgen import v1 as _v1
def arenas():
    return _v1.arenas_module()
def slopes():
    return arenas().slopes
def blocks():
    return arenas().blocks
def venue_keys():
    return _v1.venue_keys()
def venues():
    return list(_v1.VENUES)
def venue(key):
    return _v1.venue(key)
def repo_path(rel):
    return os.path.join(REPO, rel)
def kinds():
    return list(arenas().KINDS.keys())
