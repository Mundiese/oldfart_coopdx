import os
import sys
import tempfile
import time
import unittest
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
EXAMPLE = os.path.join(TOOLS, "mapgen", "examples", "frost-keep")
def run_pure():
    if not os.path.isdir(os.path.join(HERE, "tests")):
        print("  skipped: no tests in this copy (a release carries none)")
        return True, 0
    suite = unittest.defaultTestLoader.discover(os.path.join(HERE, "tests"),
                                                top_level_dir=os.path.join(HERE, "tests"))
    result = unittest.TextTestRunner(stream=sys.stdout, verbosity=1).run(suite)
    return result.wasSuccessful(), result.testsRun
def have_qt():
    try:
        import PySide6
        import OpenGL
        return None
    except ImportError as exc:
        return str(exc)
def _app(settings_path):
    if not os.environ.get("OF_SELFTEST_SESSION"):
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    os.environ.setdefault("STUDIO_NO_RECOVERY", "1")
    from studio.core import settings as smod
    settings = smod.Settings(settings_path)
    settings.set("view.msaa", 0)
    settings.set("nav.smooth_views", False)
    from studio.ui import glprobe
    glprobe.decide(settings)
    from studio.ui import app as appmod
    qapp = appmod.make_app(settings, ["studio-selftest"])
    studio = appmod.Studio.create(settings, extensions=False)
    return qapp, studio
def _pump(qapp, n=6):
    for _ in range(n):
        qapp.processEvents()
        time.sleep(0.01)
def _drawn(img, bg):
    w, h = img.width(), img.height()
    if w == 0 or h == 0:
        return 0
    n = 0
    step = max(1, min(w, h) // 60)
    for y in range(0, h, step):
        for x in range(0, w, step):
            c = img.pixelColor(x, y)
            if abs(c.red() - bg[0]) + abs(c.green() - bg[1]) + abs(c.blue() - bg[2]) > 60:
                n += 1
    return n
def check_gui(source):
    lines, ok = [], True
    with tempfile.TemporaryDirectory() as tmp:
        qapp, studio = _app(os.path.join(tmp, "settings.json"))
        win, sc, ctx = studio.window, studio.scene, studio.ctx
        def check(cond, what):
            nonlocal ok
            lines.append("  %s %s" % ("ok  " if cond else "FAIL", what))
            ok = ok and bool(cond)
        check(win.open(source), "opens %s" % source)
        check(len(sc.pieces) > 0 and len(sc.markers) > 0,
              "scene: %d pieces, %d markers" % (len(sc.pieces), len(sc.markers)))
        got = []
        ctx.selectionChanged.connect(lambda ids: got.append(ids))
        from studio.core import picking
        view = win.views.main.view
        hit = picking.Hit("piece", 3, (0, 0, 0), (0, 1, 0), 1.0)
        ctx.pick_handler(hit, {}, view)
        check(got and got[-1] == frozenset({3}), "the pick hook selects and selectionChanged fires")
        ctx.pick_handler(picking.Hit(), {}, view)
        check(sc.selection == frozenset(), "a click on nothing clears the selection")
        from PySide6.QtWidgets import QLabel
        dock = win.docks.add("bottom", "selftest", "Self-test", QLabel("panel"))
        check("selftest" in win.docks.keys() and dock.widget() is not None, "dock slot 'bottom' takes a panel")
        win.docks.remove("selftest")
        check("selftest" not in win.docks.keys(), "and gives it back")
        for aid in ("view.top", "view.front", "view.right", "view.quad", "view.frame_all",
                    "gizmo.move", "file.open"):
            check(aid in win.actions and win.actions[aid].shortcuts(), "action %s has keys" % aid)
        from studio.ui import app as appmod
        from studio.core.settings import SECTIONS
        from studio.ui.prefs import Preferences
        seen = []
        appmod.register_extension(lambda st: seen.append(st))
        studio.install_extensions()
        appmod._EXTENSIONS.clear()
        check(seen and seen[0] is studio, "an extension gets the Studio object")
        check(win.open(source) is not False and len(sc.pieces) > 0,
              "the map opens again through the extensions (%d pieces)" % len(sc.pieces))
        prefs = Preferences(studio.settings, win)
        check(prefs.stack.count() == len(SECTIONS) and len(prefs.editors) > 30,
              "Preferences: %d pages, %d settings" % (prefs.stack.count(), len(prefs.editors)))
        prefs.close()
        sc.set_highlight("issue", {0, 1})
        check("issue" in sc.highlights, "highlight layers")
        sc.clear_highlight()
        win.resize(1280, 800)
        win.show()
        _pump(qapp, 10)
        for line in check_input(qapp, studio):
            lines.append(line)
            ok = ok and not line.startswith("  FAIL")
        r = view.renderer
        if r is None or not r.ready:
            lines.append("  GL   not available on this platform (%s): the viewport's drawing is "
                         "not tested here - only on a machine with OpenGL 3.3"
                         % (view.gl_error or "no context"))
            win.close()
            return ok, lines, None
        lines.append("  ok   GL %(version)s on %(renderer)s" % r.gl_info)
        bg = tuple(int(c * 255) for c in view.options()["background"])
        for side in ("user", "top", "front", "right", "bottom", "back", "left"):
            pane = win.views.main
            pane.set_side(side)
            view.frame_all(animate=False)
            img = view.grabFramebuffer()
            check(_drawn(img, bg) > 40, "view %-6s draws the map (%dx%d)" % (side, img.width(), img.height()))
        from .core import kitbridge
        reg = studio.ctx.registry
        blocks = kitbridge.blocks()
        original = blocks.read_manifest
        tmpl, rows = original()
        extra = dict(rows[0], slug="selftest_new", name="Imported now", was=[])
        blocks.read_manifest = lambda *a, **k: (tmpl, list(rows) + [extra])
        try:
            reg.reload(force=True)
        finally:
            blocks.read_manifest = original
        view.grabFramebuffer()
        check(r._tex_serial == reg.serial and reg.known("selftest_new"),
              "a texture imported while the Studio runs is drawn at once (%d layers uploaded)"
              % reg.count())
        reg.reload(force=True)
        win.views.main.set_side("user")
        view.frame_all(animate=False)
        t = time.perf_counter()
        frames = 10
        for _ in range(frames):
            view.grabFramebuffer()
        ms = (time.perf_counter() - t) * 1000.0 / frames
        st = r.stats
        lines.append("  info %d draws, %d triangles, a frame %.1f ms incl. read-back (%s)"
                     % (st.get("draws", 0), st.get("triangles", 0), ms, r.gl_info["renderer"]))
        lines.append(stress(qapp, studio))
        win.close()
        return ok, lines, ms
def _mouse(view, kind, pos, button, buttons, mods=None):
    from PySide6.QtCore import QEvent, QPointF, Qt
    from PySide6.QtGui import QMouseEvent
    from PySide6.QtWidgets import QApplication
    types = {"press": QEvent.MouseButtonPress, "move": QEvent.MouseMove,
             "release": QEvent.MouseButtonRelease}
    p = QPointF(*pos)
    ev = QMouseEvent(types[kind], p, view.mapToGlobal(p), button, buttons,
                     mods if mods is not None else Qt.NoModifier)
    QApplication.sendEvent(view, ev)
def _drag(view, a, b, button, mods=None, steps=6):
    from PySide6.QtCore import Qt
    _mouse(view, "press", a, button, button, mods)
    for i in range(1, steps + 1):
        t = i / float(steps)
        _mouse(view, "move", (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), Qt.NoButton,
               button, mods)
    _mouse(view, "release", b, button, Qt.NoButton, mods)
def check_input(qapp, studio):
    from PySide6.QtCore import QPoint, QPointF, Qt
    from PySide6.QtGui import QWheelEvent
    from PySide6.QtWidgets import QApplication
    win, sc, ctx = studio.window, studio.scene, studio.ctx
    view = win.views.main.view
    out = []
    def check(cond, what):
        out.append("  %s %s" % ("ok  " if cond else "FAIL", what))
    view.frame_all(animate=False)
    w, h = view.width(), view.height()
    c = (w / 2.0, h / 2.0)
    cam = view.camera.copy()
    _drag(view, c, (c[0] + 120, c[1] + 40), Qt.MiddleButton)
    check(abs(view.camera.yaw - cam.yaw) > 10 and abs(view.camera.pitch - cam.pitch) > 3,
          "middle drag orbits (yaw %.0f -> %.0f)" % (cam.yaw, view.camera.yaw))
    t0 = view.camera.target
    _drag(view, c, (c[0] + 80, c[1]), Qt.MiddleButton, Qt.ShiftModifier)
    check(view.camera.target != t0, "Shift + middle drag pans")
    d0 = view.camera.distance
    ev = QWheelEvent(QPointF(*c), view.mapToGlobal(QPointF(*c)), QPoint(0, 0), QPoint(0, 240),
                     Qt.NoButton, Qt.NoModifier, Qt.NoScrollPhase, False)
    QApplication.sendEvent(view, ev)
    check(view.camera.distance < d0, "the wheel zooms in")
    view.frame_all(animate=False)
    sc.set_selection(())
    hit = view.pick_at(QPointF(*c), plane=False)
    _mouse(view, "press", c, Qt.LeftButton, Qt.LeftButton)
    _mouse(view, "release", c, Qt.LeftButton, Qt.NoButton)
    check(hit.kind is not None and (sc.selection == {hit.index} or sc.marker_selection == {hit.index}),
          "a left click selects what is under the mouse (%s %s)" % (hit.kind, hit.index))
    win.views.main.set_side("top")
    view.frame_all(animate=False)
    piece = next(i for i, p in enumerate(sc.pieces) if p["kind"] == "box")
    sc.set_selection({piece})
    ctx.set_gizmo_mode("move")
    got = []
    ctx.gizmo_handler = lambda delta, ids: got.append((delta, set(ids))) or True
    g = ctx.gizmo()
    tip = view.camera.to_pixel((g.centre[0] + g.scale(view.camera, h) * 0.8, g.centre[1], g.centre[2]), w, h)
    upp = view.camera.units_per_pixel(g.centre, h)
    _drag(view, (tip[0], tip[1]), (tip[0] + 610 / upp, tip[1] + 6), Qt.LeftButton)
    check(got and got[0][0].offset[0] == 600.0 and got[0][0].offset[2] == 0.0 and got[0][1] == {piece},
          "dragging the x arrow hands the hook a snapped move (%s)" % (got[0][0] if got else None))
    check(sc.preview is None, "the preview is cleared after the drag")
    got.clear()
    _mouse(view, "press", (tip[0], tip[1]), Qt.LeftButton, Qt.LeftButton)
    _mouse(view, "move", (tip[0] + 400 / upp, tip[1]), Qt.NoButton, Qt.LeftButton)
    check(sc.preview is not None, "a gizmo drag shows the preview")
    win.actions["select.none"].trigger()
    _mouse(view, "release", (tip[0] + 400 / upp, tip[1]), Qt.LeftButton, Qt.NoButton)
    check(not got and sc.preview is None and sc.selection == {piece},
          "Esc cancels the drag: nothing reaches the hook, the selection stays")
    ctx.gizmo_handler = None
    ctx.set_gizmo_mode("none")
    win.actions["view.front"].trigger()
    check(win.views.active.view.camera.side == "front", "the numpad action turns the active view")
    win.views.toggle_quad()
    _pump(qapp, 3)
    check(len(win.views.visible_views()) == 4, "the quad view shows four panes")
    win.views.toggle_quad()
    _pump(qapp, 4)
    check(view.width() > w * 0.9, "and back to one pane at full size (%d px wide)" % view.width())
    return out
STRESS_PIECES = 2000
def stress_pieces(n=STRESS_PIECES):
    from studio.core import kitbridge, textures
    kinds = kitbridge.kinds()
    slugs = sorted(textures.Registry(load_pixels=False).names)
    out = []
    for i in range(n):
        kind = kinds[i % len(kinds)]
        out.append({"kind": kind, "tex": slugs[(i * 7) % len(slugs)], "x": (i % 50) * 400.0,
                    "y": (i // 50 % 4) * 200.0, "z": (i // 50) * 400.0,
                    "w": 400.0 if kind != "rail" else 800.0, "h": 200.0 if kind != "rail" else 160.0,
                    "d": 400.0, "yaw": (i % 4) * 90, "tag": ""})
    return out
def stress(qapp, studio, frames=30):
    from OpenGL import GL
    sc = studio.scene
    view = studio.window.views.main.view
    sc.set_pieces(stress_pieces())
    sc.set_markers([])
    studio.window.views.main.set_side("user")
    view.frame_all(animate=False)
    view.makeCurrent()
    r = view.renderer
    opts = view.options()
    w, h = view._fb_w(), view._fb_h()
    r.draw(view.camera, w, h, opts)
    GL.glFinish()
    build, upload = r.stats.get("build_ms", 0.0), r.stats.get("upload_ms", 0.0)
    t = time.perf_counter()
    for k in range(frames):
        view.camera.orbit(1.0, 0.0)
        r.draw(view.camera, w, h, opts)
    GL.glFinish()
    ms = (time.perf_counter() - t) * 1000.0 / frames
    view.doneCurrent()
    return ("  info %d pieces: built in %.0f ms, uploaded in %.0f ms, %d draws, a frame %.1f ms "
            "(%.0f fps) at %dx%d on this machine's GL" % (
                STRESS_PIECES, build, upload, r.stats.get("draws", 0), ms, 1000.0 / max(ms, 1e-3), w, h))
def compose(win):
    from PySide6.QtCore import QPoint
    from PySide6.QtGui import QPainter
    img = win.grab().toImage()
    p = QPainter(img)
    for v in win.views.visible_views():
        p.drawImage(v.mapTo(win, QPoint(0, 0)), v.grabFramebuffer())
    p.end()
    return img
def output_without_console():
    if sys.stdout is not None:
        return None
    from studio import glchoice
    path = os.path.join(os.path.dirname(glchoice.log_path()), "selftest.log")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sys.stdout = sys.stderr = open(path, "w", encoding="utf-8")
    return path
def main(args):
    output_without_console()
    print("Oldfart Studio self-test")
    print("1. pure suite")
    if os.environ.get("OF_SELFTEST_SESSION") and not args.shots:
        print("  skipped: OF_SELFTEST_SESSION checks the session's window and GL")
        pure_ok, count = True, 0
    else:
        pure_ok, count = run_pure()
    missing = have_qt()
    if args.shots:
        if missing:
            print("studio: --shots needs PySide6 and PyOpenGL (%s)" % missing)
            return 2
        return shots(args.shots, args.source or EXAMPLE)
    if missing:
        from studio import PIP_HINT
        print("2. window and GL: not tested - %s (%s)" % (missing, PIP_HINT))
        print("studio selftest: %s (%d pure tests; GUI skipped)" % ("ok" if pure_ok else "FAILED", count))
        return 0 if pure_ok else 1
    from studio import packaged
    pk_ok, pk_lines = packaged.selfcheck()
    print("1b. packaged copy")
    print("\n".join(pk_lines))
    pure_ok = pure_ok and pk_ok
    print("2. window (QT_QPA_PLATFORM=%s)" % os.environ.get(
        "QT_QPA_PLATFORM", "session" if os.environ.get("OF_SELFTEST_SESSION") else "offscreen"))
    gui_ok, lines, ms = check_gui(args.source or EXAMPLE)
    print("\n".join(lines))
    print("  info drawing: QT_QPA_PLATFORM=%s PYOPENGL_PLATFORM=%s%s" % (
        os.environ.get("QT_QPA_PLATFORM", "(Qt's choice)"),
        os.environ.get("PYOPENGL_PLATFORM", "(default)"),
        " - software OpenGL" if os.environ.get("OF_STUDIO_GL_NOTICE") else ""))
    if os.environ.get("OF_SELFTEST_NEED_GL") and ms is None:
        print("  FAIL OF_SELFTEST_NEED_GL: no OpenGL 3.3 context here")
        gui_ok = False
    ok = pure_ok and gui_ok
    print("studio selftest: %s (%d pure tests, window %s%s)" % (
        "ok" if ok else "FAILED", count, "ok" if gui_ok else "FAILED",
        "" if ms is not None else ", GL not available here"))
    return 0 if ok else 1
class ShotsRefused(Exception):
    pass
def _no_boxes():
    from PySide6.QtWidgets import QMessageBox
    def said(kind):
        def box(*args, **_kw):
            words = [str(a) for a in args[1:3] if isinstance(a, str)]
            raise ShotsRefused("%s: %s" % (kind, " - ".join(words)))
        return staticmethod(box)
    for kind in ("warning", "critical", "information", "question"):
        setattr(QMessageBox, kind, said(kind))
    QMessageBox.exec = lambda self, *a, **k: (_ for _ in ()).throw(
        ShotsRefused("message: %s" % self.text()))
def shots(outdir, source):
    try:
        return _shots(outdir, source)
    except ShotsRefused as why:
        print("studio: --shots %s: %s" % (source, why))
        return 1
def _shots(outdir, source):
    os.makedirs(outdir, exist_ok=True)
    from studio.core import loader
    try:
        loader.load(source)
    except loader.LoadError as exc:
        print("studio: --shots cannot open %s: %s" % (source, exc))
        return 1
    with tempfile.TemporaryDirectory() as tmp:
        qapp, studio = _app(os.path.join(tmp, "settings.json"))
        _no_boxes()
        win, view = studio.window, studio.window.views.main.view
        if not win.open(source):
            print("studio: --shots cannot open %s" % source)
            return 1
        win.resize(1600, 1000)
        win.show()
        _pump(qapp, 10)
        if view.renderer is None or not view.renderer.ready:
            print("studio: no OpenGL here (%s) - no pictures" % view.gl_error)
            return 1
        written = []
        from studio.core.instances import outlined
        studio.scene.set_hidden({i for i, p in enumerate(studio.scene.pieces) if outlined(p)})
        def save(img, name):
            path = os.path.join(outdir, name)
            img.save(path)
            written.append(path)
        pane = win.views.main
        for side in ("user", "top", "bottom", "front", "back", "left", "right"):
            pane.set_side(side)
            view.frame_all(animate=False)
            _pump(qapp, 2)
            save(view.grabFramebuffer(), "view-%s.png" % side)
        pane.set_side("user")
        view.frame_all(animate=False)
        for shading in ("flat", "height", "game light", "baked"):
            studio.settings.set("view.shading", shading)
            _pump(qapp, 2)
            save(view.grabFramebuffer(), "shading-%s.png" % shading.replace(" ", "-"))
        studio.settings.set("view.shading", "textured")
        sc = studio.scene
        big = max((i for i in range(len(sc.pieces)) if i not in sc.hidden),
                  key=lambda i: sc.pieces[i]["y"] + sc.pieces[i]["h"])
        sc.set_selection({big})
        studio.ctx.set_gizmo_mode("move")
        view.frame_all(animate=False)
        _pump(qapp, 3)
        save(view.grabFramebuffer(), "view-selected.png")
        save(compose(win), "window-single.png")
        win.views.set_mode("quad")
        _pump(qapp, 6)
        win.views.frame_all(animate=False)
        _pump(qapp, 6)
        save(compose(win), "window-quad.png")
        win.close()
    print("studio: wrote %d pictures to %s" % (len(written), outdir))
    for p in written:
        print("  " + p)
    return 0
