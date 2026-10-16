import errno
import json
import os
import shutil
import subprocess
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MARKER = ".oldfart-packaged"
APP = "oldfart-studio"
DESKTOP_ID = "oldfart-studio"
INTEGRATED = "X-Oldfart-Studio-AppImage=true"
def info(root=None):
    try:
        with open(os.path.join(root or ROOT, MARKER), encoding="utf-8") as handle:
            meta = json.load(handle)
    except (OSError, ValueError):
        return None
    return meta if isinstance(meta, dict) else {}
def user_dirs(env=None, platform=None, home=None):
    env = os.environ if env is None else env
    platform = platform or sys.platform
    home = home or os.path.expanduser("~")
    if platform.startswith("win"):
        roaming = env.get("APPDATA") or os.path.join(home, "AppData", "Roaming")
        local = env.get("LOCALAPPDATA") or os.path.join(home, "AppData", "Local")
        return {"config": roaming, "data": local}
    return {"config": env.get("XDG_CONFIG_HOME") or os.path.join(home, ".config"),
            "data": env.get("XDG_DATA_HOME") or os.path.join(home, ".local", "share")}
def bootstrap(env=None, platform=None, root=None, guard=True):
    env = os.environ if env is None else env
    platform = platform or sys.platform
    root = root or ROOT
    meta = info(root)
    if meta is None:
        return None
    sys.dont_write_bytecode = True
    if platform.startswith("win"):
        dirs = user_dirs(env, platform)
        env.setdefault("XDG_CONFIG_HOME", dirs["config"])
        env.setdefault("XDG_DATA_HOME", dirs["data"])
        fix_executable()
        pyside = os.path.join(sys.base_prefix, "Lib", "site-packages", "PySide6")
        path = env.get("PATH", "")
        if os.path.isdir(pyside) and pyside not in path.split(os.pathsep):
            env["PATH"] = pyside + (os.pathsep + path if path else "")
        env.setdefault("GALLIUM_DRIVER", "llvmpipe")
        env.pop("PYTHONHOME", None)
    env["OLDFART_PACKAGED"] = str(meta.get("kind") or "yes")
    if guard:
        log_crashes()
    env.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
    if guard:
        install_guard(root)
    return meta
def log_crashes():
    previous = sys.excepthook
    def hook(kind, value, tb):
        try:
            import traceback
            from studio import glchoice
            glchoice.log(["crash:"] + "".join(
                traceback.format_exception(kind, value, tb)).rstrip().splitlines())
        except Exception:
            pass
        previous(kind, value, tb)
    sys.excepthook = hook
    return hook
def fix_executable(prefix=None, exists=os.path.exists):
    name = os.path.basename(sys.executable or "").lower()
    if name.startswith("python"):
        return sys.executable
    prefix = prefix or sys.base_prefix
    for cand in ("pythonw.exe", "python.exe", "bin/python3"):
        path = os.path.join(prefix, cand)
        if exists(path):
            sys.executable = path
            sys._base_executable = path
            return path
    return sys.executable
_WRITE_FLAGS = (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_APPEND | os.O_TRUNC)
_PATH_EVENTS = ("os.mkdir", "os.remove", "os.rmdir", "os.truncate", "os.symlink", "os.link",
                "shutil.rmtree", "shutil.copyfile", "shutil.copytree", "shutil.move")
def written(event, args):
    try:
        if event == "open":
            path, mode, flags = (tuple(args) + (None, None, None))[:3]
            if path is None or isinstance(path, int):
                return []
            if isinstance(mode, str) and mode:
                write = any(c in mode for c in "wax+")
            else:
                write = isinstance(flags, int) and bool(flags & _WRITE_FLAGS)
            return [path] if write else []
        if event == "os.rename":
            return [args[0], args[1]]
        if event in ("shutil.copyfile", "shutil.copytree"):
            return [args[1]]
        if event == "shutil.move":
            return [args[0], args[1]]
        if event in _PATH_EVENTS:
            return [args[0]]
    except (IndexError, TypeError, ValueError):
        return []
    return []
def _norm(path):
    try:
        path = os.fsdecode(os.fspath(path))
    except TypeError:
        return None
    return os.path.normcase(os.path.realpath(os.path.abspath(path)))
def make_guard(root):
    top = _norm(root)
    watched = frozenset(("open", "os.rename") + _PATH_EVENTS)
    def hook(event, args):
        if event not in watched:
            return
        for path in written(event, args):
            p = _norm(path)
            if p is not None and (p == top or p.startswith(top + os.sep)):
                raise PermissionError(
                    errno.EACCES, "Oldfart Studio's own folder is read-only (choose your "
                    "mod folder in Export, or work from a checkout of the mod)", os.fsdecode(path))
    return hook
_guarded = []
def install_guard(root):
    if root in _guarded:
        return False
    sys.addaudithook(make_guard(root))
    _guarded.append(root)
    return True
def desktop_dir(env=None, home=None):
    env = os.environ if env is None else env
    home = home or os.path.expanduser("~")
    conf = os.path.join(env.get("XDG_CONFIG_HOME") or os.path.join(home, ".config"),
                        "user-dirs.dirs")
    path = None
    try:
        with open(conf, encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if line.startswith("XDG_DESKTOP_DIR="):
                    path = line.split("=", 1)[1].strip().strip('"').replace("$HOME", home)
    except OSError:
        pass
    path = path or os.path.join(home, "Desktop")
    return path if os.path.isdir(path) and os.path.abspath(path) != os.path.abspath(home) else None
def integration_paths(env=None, home=None):
    env = os.environ if env is None else env
    data = user_dirs(env, "linux", home)["data"]
    desk = desktop_dir(env, home)
    return {"menu": os.path.join(data, "applications", DESKTOP_ID + ".desktop"),
            "icon": os.path.join(data, "icons", "hicolor", "256x256", "apps", APP + ".png"),
            "mime": os.path.join(data, "mime", "packages", APP + ".xml"),
            "desktop": os.path.join(desk, DESKTOP_ID + ".desktop") if desk else None}
def desktop_entry(appimage, version=""):
    quoted = '"%s"' % appimage.replace("\\", "\\\\").replace('"', '\\"')
    return "\n".join([
        "[Desktop Entry]",
        "Type=Application",
        "Name=Oldfart Studio",
        "GenericName=Map builder",
        "Comment=Build, edit and export maps for the oldfart mod - offline",
        "Exec=%s %%f" % quoted,
        "TryExec=%s" % appimage,
        "Icon=" + APP,
        "Terminal=false",
        "Categories=Graphics;3DGraphics;Development;",
        "MimeType=application/x-oldfart-map;",
        "StartupWMClass=Studio",
        "X-AppImage-Version=%s" % version,
        INTEGRATED,
        ""])
def _ours(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return INTEGRATED in handle.read()
    except OSError:
        return False
def integrated(env=None, home=None):
    return _ours(integration_paths(env, home)["menu"])
def _quietly(args):
    if shutil.which(args[0]):
        try:
            subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=20, check=False)
        except (OSError, subprocess.SubprocessError):
            pass
def _refresh_caches(paths):
    data = os.path.dirname(os.path.dirname(paths["menu"]))
    _quietly(["update-desktop-database", os.path.join(data, "applications")])
    _quietly(["update-mime-database", os.path.join(data, "mime")])
    _quietly(["gtk-update-icon-cache", "-q", "-t", os.path.join(data, "icons", "hicolor")])
def integrate(appimage, env=None, home=None, root=None, desktop_icon=True, refresh=True):
    root = root or ROOT
    paths = integration_paths(env, home)
    pkg = os.path.join(root, "tools", "studio", "packaging")
    version = (info(root) or {}).get("version", "")
    entry = desktop_entry(os.path.abspath(appimage), version)
    done = []
    for key, src in (("icon", os.path.join(pkg, APP + ".png")),
                     ("mime", os.path.join(pkg, APP + ".xml"))):
        os.makedirs(os.path.dirname(paths[key]), exist_ok=True)
        shutil.copyfile(src, paths[key])
        done.append(paths[key])
    targets = ["menu"] + (["desktop"] if desktop_icon and paths["desktop"] else [])
    for key in targets:
        path = paths[key]
        if os.path.exists(path) and not _ours(path):
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(entry)
        os.chmod(path, 0o755)
        done.append(path)
    if "desktop" in targets and paths["desktop"] in done:
        _quietly(["gio", "set", paths["desktop"], "metadata::trusted", "true"])
    if refresh:
        _refresh_caches(paths)
    return done
def unintegrate(env=None, home=None, refresh=True):
    paths = integration_paths(env, home)
    gone = []
    for key in ("menu", "desktop"):
        path = paths[key]
        if path and _ours(path):
            os.remove(path)
            gone.append(path)
    if gone:
        for key in ("icon", "mime"):
            if os.path.exists(paths[key]):
                os.remove(paths[key])
                gone.append(paths[key])
        if refresh:
            _refresh_caches(paths)
    return gone
def stale(appimage, env=None, home=None):
    path = integration_paths(env, home)["menu"]
    if not _ours(path):
        return False
    with open(path, encoding="utf-8") as handle:
        return ("TryExec=%s\n" % os.path.abspath(appimage)) not in handle.read()
def selfcheck(root=None, env=None):
    env = os.environ if env is None else env
    root = root or ROOT
    meta = info(root)
    if meta is None:
        return True, ["  info not packaged (a checkout): nothing to check"]
    lines, ok = [], True
    def check(cond, what):
        nonlocal ok
        lines.append("  %s %s" % ("ok  " if cond else "FAIL", what))
        ok = ok and bool(cond)
    check(meta.get("version"), "packaged %s %s" % (meta.get("kind"), meta.get("version")))
    from studio.core import settings as smod
    cfg = smod.config_dir()
    check(not _norm(cfg).startswith(_norm(root)),
          "settings live outside the program (%s)" % cfg)
    probe = os.path.join(root, "tools", "studio", ".selftest-write")
    try:
        with open(probe, "w") as handle:
            handle.write("x")
        os.remove(probe)
        check(False, "the program's folder refuses writes")
    except OSError:
        check(True, "the program's folder refuses writes")
    check(sys.dont_write_bytecode, "no bytecode written next to the program")
    exe = os.path.basename(sys.executable).lower()
    check(exe.startswith("python"), "child Pythons start the bundled Python (%s)" % exe)
    try:
        from studio.library import romaudio
        rom = romaudio.find_rom(env=env)
        lines.append("  info ROM: %s" % (rom or romaudio.where_to_look(env=env)))
    except Exception as exc:
        check(False, "the ROM search runs (%s)" % exc)
    for mod in ("PIL", "OpenGL", "anthropic"):
        try:
            __import__(mod)
            check(True, "%s is bundled" % mod)
        except ImportError as exc:
            check(mod == "anthropic", "%s is bundled (%s)" % (mod, exc))
    return ok, lines
