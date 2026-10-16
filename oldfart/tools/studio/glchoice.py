import glob
import os
import sys
import time
VENDORS = {"0x10de": "nvidia", "0x1002": "amd", "0x8086": "intel", "0x1af4": "virtio",
           "0x15ad": "vmware", "0x80ee": "virtualbox", "0x1234": "qemu"}
SOFTWARE_NOTICE = ("Your graphics driver gave no OpenGL 3.3, so the 3D view draws in "
                   "software (slower). Updating the graphics driver makes it fast again.")
class Decision(dict):
    __getattr__ = dict.get
def detect_gpu(root="/", env=None):
    env = os.environ if env is None else env
    out = {"vendor": "unknown", "driver": "", "proprietary": False, "hybrid": False}
    cards = []
    try:
        for dev in sorted(glob.glob(os.path.join(root, "sys", "class", "drm", "card[0-9]*",
                                                 "device"))):
            if "-" in os.path.basename(os.path.dirname(dev)):
                continue
            try:
                with open(os.path.join(dev, "vendor"), encoding="ascii") as handle:
                    vendor = VENDORS.get(handle.read().strip().lower(), "other")
            except OSError:
                continue
            driver = ""
            link = os.path.join(dev, "driver")
            if os.path.islink(link):
                driver = os.path.basename(os.readlink(link))
            cards.append((vendor, driver))
    except OSError:
        pass
    nvidia_driver = os.path.exists(os.path.join(root, "proc", "driver", "nvidia", "version"))
    if not cards:
        if nvidia_driver:
            out.update(vendor="nvidia", driver="nvidia", proprietary=True)
        return out
    vendors = {v for v, _ in cards}
    out["hybrid"] = len(vendors) > 1
    offload = (env.get("__NV_PRIME_RENDER_OFFLOAD") == "1"
               or env.get("__GLX_VENDOR_LIBRARY_NAME") == "nvidia")
    nv = [(v, d) for v, d in cards if v == "nvidia"]
    if nv and (not out["hybrid"] or offload):
        driver = nv[0][1] or ("nvidia" if nvidia_driver else "")
        out.update(vendor="nvidia", driver=driver, proprietary=driver == "nvidia")
    else:
        other = [(v, d) for v, d in cards if v != "nvidia"] or cards
        out.update(vendor=other[0][0], driver=other[0][1])
    return out
def mesa(gpu):
    return bool(gpu) and gpu.get("vendor") in ("intel", "amd", "virtio", "vmware", "qemu",
                                               "nvidia") and not gpu.get("proprietary")
def software_env(platform=None):
    platform = platform or sys.platform
    if platform.startswith("win"):
        return {"QT_OPENGL": "software", "GALLIUM_DRIVER": "llvmpipe"}
    return {"LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe"}
def decide(env, gpu=None, platform=None):
    platform = platform or sys.platform
    gpu = gpu or {"vendor": "unknown"}
    sets = {}
    software = env.get("OF_STUDIO_SOFTWARE_GL", "") not in ("", "0")
    if not env.get("QT_SCALE_FACTOR_ROUNDING_POLICY"):
        sets["QT_SCALE_FACTOR_ROUNDING_POLICY"] = "PassThrough"
    if platform.startswith("win"):
        if env.get("QT_OPENGL"):
            why = "Windows, the user's QT_OPENGL=%s" % env["QT_OPENGL"]
            software = env["QT_OPENGL"] == "software"
        elif software:
            sets.update(software_env(platform))
            why = "Windows, software OpenGL asked for (OF_STUDIO_SOFTWARE_GL)"
        else:
            why = "Windows, desktop OpenGL (software when the probe finds no 3.3)"
        return Decision(qpa=env.get("QT_QPA_PLATFORM") or None, pyopengl=None,
                        software=software, why=why, env=sets, gpu=gpu)
    if software:
        sets.update(software_env(platform))
    wayland = bool(env.get("WAYLAND_DISPLAY")) or (
        env.get("XDG_SESSION_TYPE") == "wayland" and bool(env.get("WAYLAND_SOCKET")))
    x11 = bool(env.get("DISPLAY"))
    desktop = env.get("XDG_CURRENT_DESKTOP") or env.get("DESKTOP_SESSION") or "unknown desktop"
    forced = (env.get("OF_STUDIO_PLATFORM") or "").lower()
    if not forced and env.get("OF_STUDIO_WAYLAND"):
        forced = "wayland"
    qpa, why = None, ""
    user = env.get("QT_QPA_PLATFORM")
    if user:
        qpa, why = user, "the user's QT_QPA_PLATFORM=%s" % user
    elif forced in ("wayland", "xcb"):
        qpa = "xcb" if forced == "xcb" else (None if wayland else "wayland")
        why = "OF_STUDIO_PLATFORM=%s" % forced
    elif wayland and x11:
        if gpu.get("vendor") == "nvidia" and gpu.get("proprietary"):
            qpa, why = "xcb", "Wayland (%s) with NVIDIA's driver: XWayland + GLX" % desktop
        elif mesa(gpu):
            why = "Wayland (%s) with Mesa (%s): native Wayland + EGL" % (desktop, gpu["vendor"])
        else:
            qpa, why = "xcb", "Wayland (%s), GPU not known: XWayland + GLX" % desktop
    elif wayland:
        why = "Wayland (%s) without XWayland: native Wayland + EGL" % desktop
    elif x11:
        why = "X11 (%s): GLX" % desktop
    else:
        why = "no display: Qt's own choice (offscreen for --selftest)"
    if qpa and not user:
        sets["QT_QPA_PLATFORM"] = qpa
    if user or qpa:
        effective = user or qpa
    elif wayland and (forced == "wayland" or not x11 or mesa(gpu)):
        effective = "wayland"
    else:
        effective = ""
    pyopengl = env.get("PYOPENGL_PLATFORM")
    if not pyopengl:
        if effective.startswith("xcb"):
            pyopengl = "glx"
        elif effective.startswith("wayland"):
            pyopengl = "egl"
        if pyopengl:
            sets["PYOPENGL_PLATFORM"] = pyopengl
    if software:
        why += "; software OpenGL asked for (OF_STUDIO_SOFTWARE_GL)"
    return Decision(qpa=qpa, pyopengl=pyopengl, software=software, why=why, env=sets, gpu=gpu)
def apply(decision, env=None):
    env = os.environ if env is None else env
    for key, value in (decision.env or {}).items():
        env.setdefault(key, value)
    return decision
def log_path(env=None):
    env = os.environ if env is None else env
    if sys.platform.startswith("win") and not env.get("XDG_DATA_HOME"):
        base = env.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), "AppData",
                                                        "Local")
    else:
        base = env.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local",
                                                        "share")
    return os.path.join(base, "oldfart-studio", "studio.log")
def log(lines, env=None, limit=256 * 1024):
    if isinstance(lines, str):
        lines = [lines]
    path = log_path(env)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if os.path.exists(path) and os.path.getsize(path) > limit:
            os.replace(path, path + ".old")
        stamp = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(path, "a", encoding="utf-8") as handle:
            for line in lines:
                handle.write("%s %s\n" % (stamp, line))
    except OSError:
        return None
    return path
