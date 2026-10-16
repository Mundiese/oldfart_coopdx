import importlib.util
import os
import sys
from studio.editor import REPO, TOOLS
_TOOLS = {}
def tool(name, file=None):
    if name in _TOOLS:
        return _TOOLS[name]
    if name in sys.modules and getattr(sys.modules[name], "__file__", "").startswith(TOOLS):
        _TOOLS[name] = sys.modules[name]
        return _TOOLS[name]
    path = os.path.join(TOOLS, file or name + ".py")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    _TOOLS[name] = module
    return module
def kb(n):
    if abs(n) >= 1024 * 1024:
        return "%.2f MB" % (n / 1048576.0)
    return "%.1f KB" % (n / 1024.0)
