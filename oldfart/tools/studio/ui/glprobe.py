import os
import sys
from PySide6.QtCore import Qt
from PySide6.QtGui import QSurfaceFormat
from PySide6.QtWidgets import QApplication
def surface_format(settings, samples=None, profile="core", vsync=None):
    fmt = QSurfaceFormat()
    fmt.setRenderableType(QSurfaceFormat.OpenGL)
    fmt.setVersion(3, 3)
    fmt.setProfile(QSurfaceFormat.CoreProfile if profile == "core"
                   else QSurfaceFormat.CompatibilityProfile)
    fmt.setDepthBufferSize(24)
    fmt.setStencilBufferSize(8)
    fmt.setSamples(int(settings["view.msaa"]) if samples is None else samples)
    if vsync is None:
        vsync = settings["view.vsync"]
    fmt.setSwapInterval(1 if vsync else 0)
    return fmt
FORMAT_LADDER = (
    {},
    {"samples": 0},
    {"samples": 0, "vsync": False},
    {"samples": 0, "vsync": False, "profile": "compat"},
)
_PROBE = r"""import sys
from PySide6.QtGui import QGuiApplication, QOpenGLContext, QOffscreenSurface, QSurfaceFormat
samples, profile, vsync = int(sys.argv[1]), sys.argv[2], sys.argv[3] == "1"
fmt = QSurfaceFormat()
fmt.setRenderableType(QSurfaceFormat.OpenGL)
fmt.setVersion(3, 3)
fmt.setProfile(QSurfaceFormat.CoreProfile if profile == "core" else QSurfaceFormat.CompatibilityProfile)
fmt.setDepthBufferSize(24); fmt.setStencilBufferSize(8)
fmt.setSamples(samples); fmt.setSwapInterval(1 if vsync else 0)
QSurfaceFormat.setDefaultFormat(fmt)
app = QGuiApplication(sys.argv[:1])
ctx = QOpenGLContext(); ctx.setFormat(fmt)
if not ctx.create():
    sys.exit(3)
surf = QOffscreenSurface(); surf.setFormat(ctx.format()); surf.create()
if not ctx.makeCurrent(surf):
    sys.exit(4)
got = ctx.format()
ok = (got.majorVersion(), got.minorVersion()) >= (3, 3)
print("format", got.majorVersion(), got.minorVersion())
try:
    import re
    f = ctx.functions()
    v = f.glGetString(0x1F02)
    v = v.decode() if isinstance(v, bytes) else (v or "")
    r = f.glGetString(0x1F01)
    print("GL", v, "|", r.decode() if isinstance(r, bytes) else r)
    m = re.match(r"\s*(\d+)\.(\d+)", v)
    ok = ok and bool(m) and (int(m.group(1)), int(m.group(2))) >= (3, 3)
except Exception as exc:
    print("no GL_VERSION:", exc)
    ok = False
try:
    ok = ok and bool(ctx.getProcAddress(b"glCreateProgram"))
except Exception as exc:
    print("no glCreateProgram:", exc)
    ok = False
if ok:
    try:
        from PySide6.QtOpenGL import (QOpenGLFramebufferObject, QOpenGLShader,
                                      QOpenGLShaderProgram, QOpenGLVertexArrayObject)
        fbo = QOpenGLFramebufferObject(8, 8)
        fbo.bind()
        prog = QOpenGLShaderProgram()
        prog.addShaderFromSourceCode(QOpenGLShader.Vertex, "#version 330 core\n"
            "void main() { vec2 p[3] = vec2[3](vec2(-1,-1), vec2(3,-1), vec2(-1,3));"
            " gl_Position = vec4(p[gl_VertexID], 0.0, 1.0); }")
        prog.addShaderFromSourceCode(QOpenGLShader.Fragment, "#version 330 core\n"
            "out vec4 c; void main() { c = vec4(1.0, 0.0, 0.0, 1.0); }")
        drew = prog.link()
        vao = QOpenGLVertexArrayObject()
        vao.create()
        vao.bind()
        prog.bind()
        f.glViewport(0, 0, 8, 8)
        f.glClearColor(0.0, 0.0, 1.0, 1.0)
        f.glClear(0x4000)
        f.glDrawArrays(0x0004, 0, 3)
        f.glFinish()
        px = fbo.toImage().pixelColor(4, 4)
        drew = drew and px.red() > 200 and px.blue() < 60
        print("drew", drew, px.red(), px.green(), px.blue())
        ok = ok and drew
    except Exception as exc:
        print("draw failed:", exc)
        ok = False
if ok and sys.platform.startswith("win"):
    import ctypes, os
    if (ctypes.windll.kernel32.GetModuleHandleW("opengl32sw.dll")
            and os.environ.get("QT_OPENGL") != "software"):
        print("Qt is on opengl32sw.dll")
        sys.exit(6)
sys.exit(0 if ok else 5)
"""
def _probe(settings, step, platform=None):
    import subprocess
    samples = step.get("samples", int(settings["view.msaa"]))
    vsync = step.get("vsync", settings["view.vsync"])
    env = dict(os.environ)
    if platform == SOFTWARE:
        from .. import glchoice
        env.update(glchoice.software_env())
    elif platform:
        env["QT_QPA_PLATFORM"] = platform
    from .. import glchoice
    what = "probe %s%s" % (step or "{}", " on " + platform if platform else "")
    try:
        done = subprocess.run([sys.executable, "-c", _PROBE, str(samples),
                               step.get("profile", "core"), "1" if vsync else "0"],
                              env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              timeout=60)
    except Exception as exc:
        glchoice.log("%s: %s" % (what, exc))
        return False
    said = " ".join((done.stdout or b"").decode("utf-8", "replace").split())[-300:]
    glchoice.log("%s: exit %s %s" % (what, done.returncode, said))
    if done.returncode == 6:
        return SOFTWARE
    return done.returncode == 0
SOFTWARE = "software"
def pick_surface_format(settings, probe=None):
    probe = probe or _probe
    if os.environ.get("OF_STUDIO_NO_PROBE") or os.environ.get("QT_QPA_PLATFORM") == "offscreen":
        return surface_format(settings), None, FORMAT_LADDER[0]
    if os.environ.get("OF_STUDIO_SOFTWARE_GL", "") not in ("", "0"):
        return surface_format(settings), SOFTWARE, FORMAT_LADDER[0]
    platforms = [None]
    if os.environ.get("WAYLAND_DISPLAY") and os.environ.get("QT_QPA_PLATFORM") in (None, "", "wayland"):
        platforms.append("xcb")
    platforms.append(SOFTWARE)
    for platform in platforms:
        for step in FORMAT_LADDER:
            got = probe(settings, step, platform)
            if got == SOFTWARE:
                return surface_format(settings, **step), SOFTWARE, step
            if got:
                return surface_format(settings, **step), platform, step
    return surface_format(settings), None, FORMAT_LADDER[0]
def use_software_gl():
    from .. import glchoice
    for key, value in glchoice.software_env().items():
        os.environ[key] = value
    if sys.platform.startswith("win"):
        QApplication.setAttribute(Qt.AA_UseSoftwareOpenGL)
        pyopengl_software()
    os.environ["OF_STUDIO_GL_NOTICE"] = glchoice.SOFTWARE_NOTICE
def software_dll():
    import PySide6
    here = os.path.dirname(PySide6.__file__)
    for folder in (here, os.path.join(here, "Qt", "bin")):
        path = os.path.join(folder, "opengl32sw.dll")
        if os.path.exists(path):
            return path
    return None
def pyopengl_software(dll=None, loader=None):
    dll = dll or software_dll()
    if not dll:
        return None
    real = loader is None
    if real:
        from OpenGL.platform import ctypesloader as loader
    original = getattr(loader.loadLibrary, "__wrapped__", loader.loadLibrary)
    def load(dll_type, name, *args, **kw):
        if str(name).lower() in ("opengl32", "opengl32.dll"):
            name = dll
        return original(dll_type, name, *args, **kw)
    load.__wrapped__ = original
    loader.loadLibrary = load
    if real:
        repoint_platform(dll)
    return dll
_GL_NAMES = ("GL", "OpenGL", "WGL", "getExtensionProcedure", "GetCurrentContext",
             "CurrentContextIsValid")
def repoint_platform(dll, platform_module=None, open_dll=None):
    if platform_module is None:
        if not sys.platform.startswith("win"):
            return False
        import OpenGL.platform as platform_module
    if "OpenGL.GL" in sys.modules:
        from .. import glchoice
        glchoice.log("software OpenGL: PyOpenGL was imported too early - its GL stays the "
                     "system's")
        return False
    plat = platform_module.PLATFORM
    if open_dll is None:
        import ctypes
        open_dll = ctypes.WinDLL
    for name in _GL_NAMES:
        plat.__dict__.pop(name, None)
    lib = open_dll(dll)
    plat.GL = lib
    plat.install(vars(platform_module))
    return True
_DECIDED = []
def decide(settings, probe=None):
    if _DECIDED:
        return _DECIDED[0]
    fmt, platform, step = pick_surface_format(settings, probe)
    if platform == SOFTWARE:
        use_software_gl()
    elif platform:
        os.environ["QT_QPA_PLATFORM"] = platform
    if platform or step is not FORMAT_LADDER[0]:
        line = "OpenGL format fallback %s%s" % (step, " on " + platform if platform else "")
        sys.stderr.write("studio: %s\n" % line)
        from .. import glchoice
        glchoice.log(line)
    _DECIDED.append((fmt, platform, step))
    return _DECIDED[0]
