import sys as _sys
VERSION = "1.6.1"
APP_NAME = "Oldfart Studio"
PIP_PACKAGES = ("PySide6-Essentials>=6.5,!=6.12.0", "PyOpenGL>=3.1.6")
PIP_HINT = "pip install " + " ".join('"%s"' % p for p in PIP_PACKAGES)
def keep_none_alive():
    if _sys.implementation.name != "cpython" or _sys.version_info >= (3, 12):
        return False
    import ctypes
    for immortal in (None, True, False):
        ctypes.c_ssize_t.from_address(id(immortal)).value += 1 << 40
    return True
_NONE_KEPT = keep_none_alive()
