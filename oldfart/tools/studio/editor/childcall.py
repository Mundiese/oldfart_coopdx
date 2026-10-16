import importlib
import os
import pickle
import subprocess
import sys
TIMEOUT = 600
_DISABLED = []
def _tools_dir():
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def resolve(target):
    mod, _, name = target.partition(":")
    fn = importlib.import_module(mod)
    for part in name.split("."):
        fn = getattr(fn, part)
    return fn
class ChildFailed(Exception):
    pass
def _env():
    env = dict(os.environ)
    env["PYTHONPATH"] = _tools_dir() + (os.pathsep + env["PYTHONPATH"]
                                        if env.get("PYTHONPATH") else "")
    if sys.dont_write_bytecode:
        env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.pop("QT_QPA_PLATFORM", None)
    return env
def in_child(target, *args, **kwargs):
    kw = {}
    if sys.platform.startswith("win"):
        kw["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
    try:
        got = subprocess.run([sys.executable, "-X", "utf8", "-m", "studio.editor.childcall"],
                             input=pickle.dumps((target, args, kwargs), protocol=4),
                             capture_output=True, env=_env(), timeout=TIMEOUT, **kw)
    except OSError as why:
        _DISABLED.append(True)
        raise ChildFailed(str(why))
    except subprocess.SubprocessError as why:
        raise ChildFailed(str(why))
    if got.returncode != 0 or not got.stdout:
        raise ChildFailed((got.stderr or b"").decode("utf-8", "replace")[-2000:]
                          or "exit %d" % got.returncode)
    try:
        ok, value = pickle.loads(got.stdout)
    except Exception as why:
        raise ChildFailed("unreadable answer: %s" % why)
    if not ok:
        raise value
    return value
def call(target, *args, **kwargs):
    if not _DISABLED and not os.environ.get("STUDIO_NO_CHILD"):
        try:
            return in_child(target, *args, **kwargs)
        except ChildFailed as why:
            last = (str(why).strip().splitlines() or ["?"])[-1]
            sys.stderr.write("studio: a child measure did not run (%s) - measuring here\n"
                             % last)
    return resolve(target)(*args, **kwargs)
def main():
    target, args, kwargs = pickle.loads(sys.stdin.buffer.read())
    try:
        out = (True, resolve(target)(*args, **kwargs))
    except Exception as exc:
        out = (False, exc)
    try:
        data = pickle.dumps(out, protocol=4)
    except Exception as exc:
        data = pickle.dumps((False, RuntimeError("%s: %s" % (exc.__class__.__name__, exc))),
                            protocol=4)
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()
    return 0
if __name__ == "__main__":
    sys.exit(main())
