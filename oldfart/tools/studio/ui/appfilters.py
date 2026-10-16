import contextlib
from PySide6.QtWidgets import QApplication
_FILTERS = []
def install(obj, app=None):
    app = app or QApplication.instance()
    if obj in _FILTERS:
        return obj
    app.installEventFilter(obj)
    _FILTERS.append(obj)
    obj.destroyed.connect(lambda *_a, o=obj: _forget(o))
    return obj
def _forget(obj):
    try:
        _FILTERS.remove(obj)
    except ValueError:
        pass
def remove(obj, app=None):
    app = app or QApplication.instance()
    if obj in _FILTERS:
        _FILTERS.remove(obj)
    try:
        app.removeEventFilter(obj)
    except RuntimeError:
        pass
def installed():
    return list(_FILTERS)
@contextlib.contextmanager
def suspended(app=None):
    app = app or QApplication.instance()
    held = []
    for obj in list(_FILTERS):
        try:
            app.removeEventFilter(obj)
            held.append(obj)
        except RuntimeError:
            _forget(obj)
    try:
        yield held
    finally:
        for obj in held:
            try:
                app.installEventFilter(obj)
            except RuntimeError:
                _forget(obj)
