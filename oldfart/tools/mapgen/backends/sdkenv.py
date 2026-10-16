import glob
import importlib
import os
import site
import subprocess
import sys
APP = "oldfart-studio"
PACKAGE = "anthropic"
HERE = os.path.dirname(os.path.abspath(__file__))
LOCK = os.path.join(os.path.dirname(os.path.dirname(HERE)), "studio", "packaging", "vendor",
                    "vendor.lock")
class Result:
    def __init__(self, ok, message, steps=None):
        self.ok = ok
        self.message = message
        self.steps = list(steps or [])
    def __repr__(self):
        return "Result(%s, %r)" % (self.ok, self.message)
def data_dir():
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local",
                                                           "share")
    return os.path.join(base, APP)
def venv_dir():
    return os.path.join(data_dir(), "claude-venv")
def venv_python(venv=None):
    venv = venv or venv_dir()
    if os.name == "nt":
        return os.path.join(venv, "Scripts", "python.exe")
    return os.path.join(venv, "bin", "python")
def site_packages(venv=None):
    venv = venv or venv_dir()
    found = sorted(glob.glob(os.path.join(venv, "lib", "python3*", "site-packages")))
    found += glob.glob(os.path.join(venv, "Lib", "site-packages"))
    return found
def pin(lock=None):
    needs = []
    with open(lock or LOCK, encoding="utf-8") as f:
        for line in f:
            if line.startswith(("# needs:", "needs:")):
                needs = line.split(":", 1)[1].split()
                continue
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            p, wheel, sha, url = line.split()
            name, version = p.split("==")
            if name == PACKAGE:
                return (version, wheel, sha, url), needs
    raise ValueError("%s is not pinned in %s" % (PACKAGE, lock or LOCK))
def manual_command(lock=None):
    try:
        version = pin(lock)[0][0]
    except (OSError, ValueError):
        version = "1.11.0"
    v = venv_dir().replace(os.path.expanduser("~"), "~", 1)
    return ("python3 -m venv --system-site-packages %s && %s/bin/pip install %s==%s"
            % (v, v, PACKAGE, version))
def activate(venv=None):
    added = False
    for sp in site_packages(venv):
        if sp not in sys.path:
            site.addsitedir(sp)
            added = True
    if added:
        importlib.invalidate_caches()
    return bool(site_packages(venv))
def install(run=None, python=None, venv=None, lock=None, timeout=600):
    run = run or subprocess.run
    python = python or sys.executable
    venv = venv or venv_dir()
    steps = []
    def step(cmd, what):
        steps.append(cmd)
        try:
            p = run(cmd, capture_output=True, text=True, timeout=timeout)
        except (OSError, subprocess.SubprocessError) as why:
            return "%s failed (%s)" % (what, why)
        if getattr(p, "returncode", 1) != 0:
            err = ((getattr(p, "stderr", "") or "") + (getattr(p, "stdout", "") or "")).strip()
            last = err.splitlines()[-1] if err else "exit %s" % getattr(p, "returncode", "?")
            return "%s failed: %s" % (what, last[:200])
        return None
    def fail(why):
        return Result(False, "%s. By hand: %s" % (why, manual_command(lock)), steps)
    try:
        (version, wheel, sha, url), needs = pin(lock)
    except (OSError, ValueError) as why:
        return fail("the SDK's pin could not be read (%s)" % why)
    os.makedirs(os.path.dirname(venv), exist_ok=True)
    if not os.path.exists(venv_python(venv)):
        bad = step([python, "-m", "venv", "--system-site-packages", venv], "making the venv")
        if bad:
            return fail(bad)
    req = os.path.join(venv, "requirements-claude.txt")
    with open(req, "w", encoding="utf-8") as f:
        f.write("%s==%s --hash=sha256:%s\n" % (PACKAGE, version, sha))
    py = venv_python(venv)
    bad = step([py, "-m", "pip", "install", "--disable-pip-version-check", "--require-hashes",
                "--no-deps", "-r", req], "installing %s %s (hash-checked)" % (PACKAGE, version))
    if bad:
        return fail(bad)
    if step([py, "-c", "import %s" % PACKAGE], "checking the SDK"):
        bad = step([py, "-m", "pip", "install", "--disable-pip-version-check"] + needs,
                   "installing the SDK's dependencies")
        if bad:
            return fail(bad)
        bad = step([py, "-c", "import %s" % PACKAGE], "checking the SDK")
        if bad:
            return fail(bad)
    activate(venv)
    return Result(True, "Claude support installed in %s (%s %s)" % (venv, PACKAGE, version),
                  steps)
