import os
import shutil
PORT = 7777
PLACES = ("~/.local/share/sm64coopdx/sm64coopdx", "~/sm64coopdx/sm64coopdx",
          "~/Games/sm64coopdx/sm64coopdx", "/opt/sm64coopdx/sm64coopdx",
          "/usr/bin/sm64coopdx", "/usr/local/bin/sm64coopdx")
def find_game(chosen=None):
    if chosen:
        path = os.path.expanduser(chosen)
        return path if os.path.isfile(path) and os.access(path, os.X_OK) else None
    found = shutil.which("sm64coopdx")
    if found:
        return found
    for p in PLACES:
        p = os.path.expanduser(p)
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return None
def command(game, mod=None, name="Studio"):
    argv = [game, "--server", str(PORT), "--skip-intro", "--playername", name]
    if mod:
        argv += ["--enable-mod", os.path.basename(os.path.normpath(mod))]
    return argv
def start(argv):
    from PySide6.QtCore import QProcess
    ok = QProcess.startDetached(argv[0], argv[1:])
    return bool(ok[0] if isinstance(ok, tuple) else ok)
