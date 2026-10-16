import threading
import traceback
from PySide6.QtCore import QObject, QThread, Signal
_LIVE = set()
def _wait_all():
    for t in list(_LIVE):
        try:
            t.wait(30000)
        except RuntimeError:
            pass
import atexit
atexit.register(_wait_all)
class _Thread(QThread):
    progressed = Signal(int, int, str)
    finished_ok = Signal(object)
    failed = Signal(str)
    def __init__(self, fn, cancel):
        super().__init__()
        self.fn = fn
        self.cancel = cancel
    def run(self):
        try:
            out = self.fn(lambda a, b, text: self.progressed.emit(int(a), int(b), str(text)),
                          self.cancel.is_set)
        except Exception as exc:
            from ..engine import Cancelled, EngineError
            if isinstance(exc, Cancelled):
                self.failed.emit("Cancelled")
            elif isinstance(exc, EngineError):
                self.failed.emit(str(exc))
            else:
                self.failed.emit("%s: %s\n%s" % (exc.__class__.__name__, exc,
                                                 traceback.format_exc(limit=4)))
            return
        self.finished_ok.emit(out)
class Jobs(QObject):
    started = Signal(str)
    progress = Signal(int, int, str)
    ended = Signal(str)
    def __init__(self, parent=None):
        super().__init__(parent)
        self._thread = None
        self._cancel = threading.Event()
        self.label = ""
    def busy(self):
        return self._thread is not None
    def run(self, label, fn, on_done, on_fail=None):
        if self.busy():
            return False
        self._cancel = threading.Event()
        self.label = label
        t = _Thread(fn, self._cancel)
        t.progressed.connect(self.progress)
        def ok(result):
            self._thread = None
            try:
                self.ended.emit("")
            except RuntimeError:
                return
            on_done(result)
        def bad(reason):
            self._thread = None
            try:
                self.ended.emit(reason)
            except RuntimeError:
                return
            if on_fail is not None:
                on_fail(reason)
        t.finished_ok.connect(ok)
        t.failed.connect(bad)
        self._thread = t
        self._last = t
        for old in list(_LIVE):
            if old.isFinished():
                _LIVE.discard(old)
        _LIVE.add(t)
        self.started.emit(label)
        t.start()
        return True
    def cancel(self):
        self._cancel.set()
    def wait(self, ms=None):
        if self._thread is not None:
            return self._thread.wait() if ms is None else self._thread.wait(ms)
        return True
