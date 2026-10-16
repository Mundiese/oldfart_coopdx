import ctypes
import time
from OpenGL import GL
from ..core import instances, markers, meshes, theme, vec
from ..core.viewopts import axis_colours, fps_text, game_light_of, grid_plane, light_of
from ..core.viewopts import bake_of, bake_tint, sun_of, with_sun
from ..core.viewopts import mood_of, mood_uniforms, with_mood
SHADING_IDS = {"textured": 0, "flat": 1, "height": 2, "game light": 3, "baked": 4}
from . import shaders
FLOAT = 4
GAME_CAM = 1200.0
def fog_shift(cam):
    return max(0.0, float(cam.distance) - GAME_CAM)
GL_TEXTURE_MAX_ANISOTROPY = 0x84FE
class InstanceCache:
    def __init__(self, scene, registry):
        self.scene, self.registry = scene, registry
        self.serial = 0
        self._dirty = True
        self._markers_dirty = True
        self._registry_serial = getattr(registry, "serial", 0)
        self.opaque, self.ghosts, self.colours, self.marker_rows = {}, {}, [], {}
        self.build_ms = 0.0
        scene.listen(self._on)
    def _on(self, event, payload):
        if event == "hover":
            return
        if event in ("markers", "marker_selection"):
            self._markers_dirty = True
        else:
            self._dirty = True
    def get(self):
        serial = getattr(self.registry, "serial", 0)
        if serial != self._registry_serial:
            self._registry_serial = serial
            self._dirty = True
        if self._dirty or self._markers_dirty:
            t = time.perf_counter()
            if self._dirty:
                self.opaque, self.ghosts, self.colours = instances.build(
                    self.scene, self.registry, hover=False)
            if self._markers_dirty:
                self.marker_rows = markers.instances(self.scene)
            self._dirty = self._markers_dirty = False
            self.serial += 1
            self.build_ms = (time.perf_counter() - t) * 1000.0
        return self
def _compile(vs, fs):
    def stage(kind, src):
        sh = GL.glCreateShader(kind)
        GL.glShaderSource(sh, src)
        GL.glCompileShader(sh)
        if not GL.glGetShaderiv(sh, GL.GL_COMPILE_STATUS):
            raise RuntimeError("shader: %s" % GL.glGetShaderInfoLog(sh).decode(errors="replace"))
        return sh
    prog = GL.glCreateProgram()
    a, b = stage(GL.GL_VERTEX_SHADER, vs), stage(GL.GL_FRAGMENT_SHADER, fs)
    GL.glAttachShader(prog, a)
    GL.glAttachShader(prog, b)
    GL.glLinkProgram(prog)
    if not GL.glGetProgramiv(prog, GL.GL_LINK_STATUS):
        raise RuntimeError("program: %s" % GL.glGetProgramInfoLog(prog).decode(errors="replace"))
    GL.glDeleteShader(a)
    GL.glDeleteShader(b)
    return Program(prog)
class Program:
    def __init__(self, handle):
        self.handle = handle
        self._loc = {}
    def use(self):
        GL.glUseProgram(self.handle)
    def loc(self, name):
        if name not in self._loc:
            self._loc[name] = GL.glGetUniformLocation(self.handle, name)
        return self._loc[name]
    def mat4(self, name, m):
        GL.glUniformMatrix4fv(self.loc(name), 1, GL.GL_FALSE, vec.column_major(m))
    def vec3(self, name, v):
        GL.glUniform3f(self.loc(name), float(v[0]), float(v[1]), float(v[2]))
    def vec2(self, name, v):
        GL.glUniform2f(self.loc(name), float(v[0]), float(v[1]))
    def f(self, name, v):
        GL.glUniform1f(self.loc(name), float(v))
    def i(self, name, v):
        GL.glUniform1i(self.loc(name), int(v))
    def ivec2(self, name, v):
        GL.glUniform2i(self.loc(name), int(v[0]), int(v[1]))
class Buffer:
    def __init__(self):
        self.handle = GL.glGenBuffers(1)
        self.capacity = 0
        self.size = 0
        self.generation = 0
    def upload(self, data):
        raw = data.tobytes() if hasattr(data, "tobytes") else bytes(data)
        GL.glBindBuffer(GL.GL_ARRAY_BUFFER, self.handle)
        if len(raw) > self.capacity or len(raw) < self.capacity // 4:
            self.capacity = max(len(raw), 64)
            GL.glBufferData(GL.GL_ARRAY_BUFFER, self.capacity, None, GL.GL_DYNAMIC_DRAW)
            self.generation += 1
        if raw:
            GL.glBufferSubData(GL.GL_ARRAY_BUFFER, 0, len(raw), raw)
        self.size = len(raw)
    def delete(self):
        GL.glDeleteBuffers(1, [self.handle])
def _attrib(loc, size, stride, offset, divisor=0):
    GL.glEnableVertexAttribArray(loc)
    GL.glVertexAttribPointer(loc, size, GL.GL_FLOAT, GL.GL_FALSE, stride * FLOAT,
                             ctypes.c_void_p(offset * FLOAT))
    GL.glVertexAttribDivisor(loc, divisor)
class MeshGL:
    def __init__(self, mesh):
        self.tris = Buffer()
        self.tris.upload(_floats(mesh.vertices))
        self.count = mesh.count
        self.edges = Buffer()
        self.edges.upload(_floats(mesh.edges))
        self.edge_count = len(mesh.edges) // 3
def _floats(seq):
    import array
    return seq if isinstance(seq, array.array) else array.array("f", seq)
class BatchGL:
    def __init__(self, mesh_gl):
        self.mesh = mesh_gl
        self.inst = Buffer()
        self.count = 0
        self.vao = GL.glGenVertexArrays(1)
        self.edge_vao = GL.glGenVertexArrays(1)
        self._wired = -1
    def upload(self, batch):
        self.inst.upload(batch.data)
        self.count = batch.count
        if self._wired != self.inst.generation:
            self._wire()
            self._wired = self.inst.generation
    def _instance_attribs(self):
        F = instances.INSTANCE_FLOATS
        GL.glBindBuffer(GL.GL_ARRAY_BUFFER, self.inst.handle)
        _attrib(3, 3, F, 0, 1)
        _attrib(4, 3, F, 3, 1)
        _attrib(5, 4, F, 6, 1)
        _attrib(6, 3, F, 10, 1)
    def _wire(self):
        V = meshes.VERTEX_FLOATS
        GL.glBindVertexArray(self.vao)
        GL.glBindBuffer(GL.GL_ARRAY_BUFFER, self.mesh.tris.handle)
        _attrib(0, 3, V, 0)
        _attrib(1, 3, V, 3)
        _attrib(2, 2, V, 6)
        self._instance_attribs()
        GL.glBindVertexArray(self.edge_vao)
        GL.glBindBuffer(GL.GL_ARRAY_BUFFER, self.mesh.edges.handle)
        _attrib(0, 3, 3, 0)
        self._instance_attribs()
        GL.glBindVertexArray(0)
class Renderer:
    def __init__(self, cache, registry):
        self.cache = cache
        self.registry = registry
        self._serial = -1
        self.meshes = {}
        self.opaque, self.ghosts = {}, {}
        self.marker_batches = {}
        self.colours = []
        self.ready = False
        self.stats = {}
        self._tex_serial = None
        self._filter = "nearest"
    def init(self, filter_mode="nearest"):
        self.piece = _compile(shaders.PIECE_VS, shaders.PIECE_FS)
        self.edge = _compile(shaders.EDGE_VS, shaders.EDGE_FS)
        self.marker = _compile(shaders.MARKER_VS, shaders.MARKER_FS)
        self.grid = _compile(shaders.GRID_VS, shaders.GRID_FS)
        self.background = _compile(shaders.BACKGROUND_VS, shaders.BACKGROUND_FS)
        self.baked = _compile(shaders.BAKED_VS, shaders.BAKED_FS)
        self.baked_vao = GL.glGenVertexArrays(1)
        self.baked_buf = Buffer()
        self.baked_count = 0
        self._baked_key = None
        self.flame = _compile(shaders.FLAME_VS, shaders.FLAME_FS)
        self.flame_vao = GL.glGenVertexArrays(1)
        self.flame_buf = Buffer()
        self._flame_wired = -1
        self.flames_drawn = 0
        self.empty_vao = GL.glGenVertexArrays(1)
        self.texture = GL.glGenTextures(1)
        self.upload_textures()
        self.set_filter(filter_mode)
        self.ready = True
        self.gl_info = {
            "version": (GL.glGetString(GL.GL_VERSION) or b"?").decode(errors="replace"),
            "renderer": (GL.glGetString(GL.GL_RENDERER) or b"?").decode(errors="replace"),
        }
    def upload_textures(self):
        r = self.registry
        self._tex_serial = getattr(r, "serial", 0)
        GL.glBindTexture(GL.GL_TEXTURE_2D_ARRAY, self.texture)
        GL.glPixelStorei(GL.GL_UNPACK_ALIGNMENT, 1)
        GL.glTexImage3D(GL.GL_TEXTURE_2D_ARRAY, 0, GL.GL_RGBA8, 32, 32, r.count(), 0,
                        GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, r.pixel_bytes())
        GL.glTexParameteri(GL.GL_TEXTURE_2D_ARRAY, GL.GL_TEXTURE_WRAP_S, GL.GL_REPEAT)
        GL.glTexParameteri(GL.GL_TEXTURE_2D_ARRAY, GL.GL_TEXTURE_WRAP_T, GL.GL_REPEAT)
        GL.glGenerateMipmap(GL.GL_TEXTURE_2D_ARRAY)
        try:
            GL.glTexParameterf(GL.GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_ANISOTROPY, 8.0)
            GL.glGetError()
        except Exception:
            pass
    def set_filter(self, mode):
        self._filter = mode
        GL.glBindTexture(GL.GL_TEXTURE_2D_ARRAY, self.texture)
        mag = GL.GL_NEAREST if mode == "nearest" else GL.GL_LINEAR
        GL.glTexParameteri(GL.GL_TEXTURE_2D_ARRAY, GL.GL_TEXTURE_MAG_FILTER, mag)
        GL.glTexParameteri(GL.GL_TEXTURE_2D_ARRAY, GL.GL_TEXTURE_MIN_FILTER,
                           GL.GL_LINEAR_MIPMAP_LINEAR)
    def ready_baked(self, level):
        if level.count == 0:
            return False
        if self._baked_key is not level:
            from ..core import bakeview
            self.baked_buf.upload(level.data)
            self.baked_count = level.count
            F = bakeview.FLOATS
            GL.glBindVertexArray(self.baked_vao)
            GL.glBindBuffer(GL.GL_ARRAY_BUFFER, self.baked_buf.handle)
            _attrib(0, 3, F, 0)
            _attrib(1, 2, F, 3)
            _attrib(2, 3, F, 5)
            _attrib(3, 1, F, 8)
            _attrib(4, 3, F, 9)
            _attrib(5, 1, F, 12)
            GL.glBindVertexArray(0)
            self._baked_key = level
        return True
    def _draw_baked(self, vp, eye, bg, opts):
        b = self.baked
        b.use()
        b.mat4("u_vp", vp)
        b.vec3("u_eye", eye)
        b.vec3("u_bg", bg)
        b.f("u_fog", opts["fog"])
        cam_far = opts.get("fog_range") or (1e9, 1e9)
        b.vec2("u_fog_range", cam_far)
        mood = opts.get("mood") or mood_uniforms(None)
        b.f("u_mfog", mood["fog"])
        b.vec3("u_mfog_col", mood["fog_colour"])
        b.vec3("u_gfog", mood.get("gfog", (0.0, 0.0, 0.0)))
        b.vec3("u_gfog_col", mood.get("gfog_colour", (0.0, 0.0, 0.0)))
        b.f("u_gfog_shift", opts.get("gfog_shift", 0.0))
        b.vec3("u_mmul", mood["multiply"])
        GL.glUniform4f(b.loc("u_grade1"), *[float(v) for v in mood["grade1"]])
        b.vec3("u_grade2", mood["grade2"])
        GL.glActiveTexture(GL.GL_TEXTURE0)
        GL.glBindTexture(GL.GL_TEXTURE_2D_ARRAY, self.texture)
        b.i("u_tex", 0)
        GL.glDisable(GL.GL_CULL_FACE)
        GL.glBindVertexArray(self.baked_vao)
        GL.glDrawArrays(GL.GL_TRIANGLES, 0, self.baked_count)
        GL.glEnable(GL.GL_CULL_FACE)
    def _draw_flames(self, vp, cam, flames, t):
        from ..core import bakeview
        right, up, _ = cam.basis()
        data = bakeview.flame_vertices(flames, right, up, t)
        n = len(data) // bakeview.FLAME_FLOATS
        if n == 0:
            return 0
        self.flame_buf.upload(data)
        if self._flame_wired != self.flame_buf.generation:
            GL.glBindVertexArray(self.flame_vao)
            GL.glBindBuffer(GL.GL_ARRAY_BUFFER, self.flame_buf.handle)
            _attrib(0, 3, bakeview.FLAME_FLOATS, 0)
            _attrib(1, 4, bakeview.FLAME_FLOATS, 3)
            GL.glBindVertexArray(0)
            self._flame_wired = self.flame_buf.generation
        f = self.flame
        f.use()
        f.mat4("u_vp", vp)
        GL.glDisable(GL.GL_CULL_FACE)
        GL.glBindVertexArray(self.flame_vao)
        GL.glDrawArrays(GL.GL_TRIANGLES, 0, n)
        return n
    def _mesh(self, key):
        m = self.meshes.get(key)
        if m is None:
            m = self.meshes[key] = MeshGL(meshes.build(key))
        return m
    def _marker_mesh(self, kind):
        m = self.meshes.get(("marker", kind))
        if m is None:
            buf = Buffer()
            data = markers.build(kind)
            buf.upload(data)
            vao = GL.glGenVertexArrays(1)
            inst = Buffer()
            m = self.meshes[("marker", kind)] = {"buf": buf, "count": len(data) // 6, "vao": vao,
                                                  "inst": inst, "wired": -1, "n": 0}
        return m
    def sync(self):
        if getattr(self.registry, "serial", 0) != self._tex_serial:
            self.upload_textures()
            self.set_filter(self._filter)
        c = self.cache.get()
        if c.serial == self._serial:
            return
        t = time.perf_counter()
        for table, src in ((self.opaque, c.opaque), (self.ghosts, c.ghosts)):
            for key in list(table):
                if key not in src:
                    table[key].count = 0
            for key, batch in src.items():
                b = table.get(key)
                if b is None:
                    b = table[key] = BatchGL(self._mesh(key))
                b.upload(batch)
        for kind in list(self.marker_batches):
            if kind not in c.marker_rows:
                self.marker_batches[kind]["n"] = 0
        for kind, rows in c.marker_rows.items():
            m = self._marker_mesh(kind)
            m["inst"].upload(rows)
            m["n"] = len(rows) // markers.MARKER_FLOATS
            if m["wired"] != m["inst"].generation:
                GL.glBindVertexArray(m["vao"])
                GL.glBindBuffer(GL.GL_ARRAY_BUFFER, m["buf"].handle)
                _attrib(0, 3, 6, 0)
                _attrib(1, 3, 6, 3)
                GL.glBindBuffer(GL.GL_ARRAY_BUFFER, m["inst"].handle)
                _attrib(3, 4, markers.MARKER_FLOATS, 0, 1)
                _attrib(4, 4, markers.MARKER_FLOATS, 4, 1)
                GL.glBindVertexArray(0)
                m["wired"] = m["inst"].generation
            self.marker_batches[kind] = m
        self.colours = c.colours
        self._serial = c.serial
        self.stats["upload_ms"] = (time.perf_counter() - t) * 1000.0
        self.stats["build_ms"] = c.build_ms
    def draw(self, cam, width, height, opts):
        t0 = time.perf_counter()
        self.sync()
        GL.glViewport(0, 0, width, height)
        bg = opts["background"]
        GL.glClearColor(bg[0], bg[1], bg[2], 1.0)
        GL.glClear(GL.GL_COLOR_BUFFER_BIT | GL.GL_DEPTH_BUFFER_BIT)
        aspect = width / float(max(1, height))
        radius = opts.get("radius", 20000.0)
        vp = cam.view_projection(aspect, radius)
        eye = cam.eye()
        accent = opts["accent"]
        GL.glDisable(GL.GL_DEPTH_TEST)
        GL.glDepthMask(GL.GL_FALSE)
        self.background.use()
        self.background.vec3("u_top", [min(1.0, c * 1.18 + 0.01) for c in bg])
        self.background.vec3("u_bottom", [c * 0.86 for c in bg])
        GL.glBindVertexArray(self.empty_vao)
        GL.glDrawArrays(GL.GL_TRIANGLES, 0, 3)
        GL.glEnable(GL.GL_DEPTH_TEST)
        GL.glDepthFunc(GL.GL_LESS)
        GL.glDepthMask(GL.GL_TRUE)
        GL.glDisable(GL.GL_BLEND)
        GL.glEnable(GL.GL_CULL_FACE)
        GL.glCullFace(GL.GL_BACK)
        GL.glFrontFace(GL.GL_CCW)
        GL.glEnable(GL.GL_POLYGON_OFFSET_FILL)
        GL.glPolygonOffset(1.0, 1.0)
        p = self.piece
        p.use()
        p.mat4("u_vp", vp)
        p.i("u_shading", SHADING_IDS.get(opts["shading"], 0))
        p.vec3("u_light", opts["light"])
        game = opts.get("game_light") or game_light_of({})
        right, up, forward = cam.basis()
        p.vec3("u_cam_right", right)
        p.vec3("u_cam_up", up)
        p.vec3("u_cam_back", tuple(-c for c in forward))
        p.vec3("u_glight", game["light"])
        p.vec3("u_glit", game["lit"])
        p.vec3("u_gamb", game["amb"])
        p.f("u_gskew", 1.0 if game.get("skew") else 0.0)
        bk = opts.get("bake") or bake_of({})
        p.vec3("u_bsun", tuple(bk["sun"]))
        p.vec3("u_bsunc", tuple(bk["sunc"]))
        p.vec3("u_bsky", tuple(bk["sky"]))
        p.vec3("u_bgnd", tuple(bk["gnd"]))
        p.vec3("u_btint", bake_tint())
        p.vec3("u_eye", eye)
        p.vec3("u_bg", bg)
        p.f("u_fog", opts["fog"])
        far = radius * 2.5 if not cam.ortho else 1e12
        p.vec2("u_fog_range", (cam.distance * 0.6, cam.distance + far))
        opts["fog_range"] = (cam.distance * 0.6, cam.distance + far)
        p.vec3("u_accent", accent)
        p.f("u_hover", opts["hover"])
        p.f("u_ghost", 0.0)
        p.vec2("u_height", opts["height"])
        mood = opts.get("mood") or mood_uniforms(None)
        p.f("u_mfog", mood["fog"])
        p.vec3("u_mfog_col", mood["fog_colour"])
        p.vec3("u_gfog", mood.get("gfog", (0.0, 0.0, 0.0)))
        p.vec3("u_gfog_col", mood.get("gfog_colour", (0.0, 0.0, 0.0)))
        opts["gfog_shift"] = fog_shift(cam)
        p.f("u_gfog_shift", opts["gfog_shift"])
        p.vec3("u_mmul", mood["multiply"])
        GL.glUniform4f(p.loc("u_grade1"), *[float(v) for v in mood["grade1"]])
        p.vec3("u_grade2", mood["grade2"])
        slots = list(self.colours[:8]) + [(1.0, 1.0, 1.0)] * (8 - min(8, len(self.colours)))
        for k, c in enumerate(slots):
            GL.glUniform3f(p.loc("u_slots[%d]" % k), *[float(v) for v in c])
        GL.glActiveTexture(GL.GL_TEXTURE0)
        GL.glBindTexture(GL.GL_TEXTURE_2D_ARRAY, self.texture)
        p.i("u_tex", 0)
        draws = tris = 0
        level = opts.get("baked_mesh") if opts["shading"] == "baked" else None
        if level is not None and self.ready_baked(level):
            self._draw_baked(vp, eye, bg, opts)
            draws += 1
            tris += self.baked_count // 3
            p.use()
        else:
            for b in self.opaque.values():
                if b.count:
                    GL.glBindVertexArray(b.vao)
                    GL.glDrawArraysInstanced(GL.GL_TRIANGLES, 0, b.mesh.count, b.count)
                    draws += 1
                    tris += b.mesh.count // 3 * b.count
        GL.glDisable(GL.GL_POLYGON_OFFSET_FILL)
        if opts["markers"] and self.marker_batches:
            GL.glDisable(GL.GL_CULL_FACE)
            m = self.marker
            m.use()
            m.mat4("u_vp", vp)
            m.vec3("u_light", opts["light"])
            m.vec3("u_accent", accent)
            for mb in self.marker_batches.values():
                if mb["n"]:
                    GL.glBindVertexArray(mb["vao"])
                    GL.glDrawArraysInstanced(GL.GL_TRIANGLES, 0, mb["count"], mb["n"])
                    draws += 1
        GL.glEnable(GL.GL_BLEND)
        GL.glBlendFuncSeparate(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA, GL.GL_ZERO, GL.GL_ONE)
        GL.glDepthMask(GL.GL_FALSE)
        GL.glDepthFunc(GL.GL_LEQUAL)
        e = self.edge
        e.use()
        e.mat4("u_vp", vp)
        e.vec3("u_accent", accent)
        e.f("u_all", 1.0 if opts["edges"] else 0.0)
        e.f("u_hover", opts["hover"])
        for b in self.opaque.values():
            if b.count:
                GL.glBindVertexArray(b.edge_vao)
                GL.glDrawArraysInstanced(GL.GL_LINES, 0, b.mesh.edge_count, b.count)
                draws += 1
        self.flames_drawn = 0
        if level is not None and getattr(level, "flames", None):
            self.flames_drawn = self._draw_flames(vp, cam, level.flames,
                                                  opts.get("time", time.perf_counter()))
            draws += 1
        if opts["grid"]:
            self._grid(cam, vp, width, height, opts)
            draws += 1
        if any(b.count for b in self.ghosts.values()):
            GL.glDisable(GL.GL_CULL_FACE)
            p.use()
            p.f("u_ghost", 1.0)
            p.f("u_hover", -2.0)
            tint = opts.get("ghost_tint")
            if tint is not None:
                p.vec3("u_accent", tuple(tint))
            for b in self.ghosts.values():
                if b.count:
                    GL.glBindVertexArray(b.vao)
                    GL.glDrawArraysInstanced(GL.GL_TRIANGLES, 0, b.mesh.count, b.count)
            e.use()
            if tint is not None:
                e.vec3("u_accent", tuple(tint))
            for b in self.ghosts.values():
                if b.count:
                    GL.glBindVertexArray(b.edge_vao)
                    GL.glDrawArraysInstanced(GL.GL_LINES, 0, b.mesh.edge_count, b.count)
        GL.glBindVertexArray(0)
        GL.glUseProgram(0)
        GL.glDepthMask(GL.GL_TRUE)
        GL.glDisable(GL.GL_BLEND)
        GL.glDisable(GL.GL_CULL_FACE)
        GL.glDisable(GL.GL_DEPTH_TEST)
        self.stats.update({"draws": draws, "triangles": tris,
                           "cpu_ms": (time.perf_counter() - t0) * 1000.0})
    def _grid(self, cam, vp, width, height, opts):
        point, normal, axes = opts["grid_plane"]
        g = self.grid
        g.use()
        g.mat4("u_vp", vp)
        g.mat4("u_inv_vp", vec.invert(vp))
        g.vec3("u_plane_point", point)
        g.vec3("u_plane_normal", normal)
        g.ivec2("u_axes", axes)
        g.vec2("u_spacing", opts["grid_spacing"])
        g.vec3("u_line", opts["grid_colour"])
        g.vec3("u_axis_a", opts["axis_colours"][axes[0]])
        g.vec3("u_axis_b", opts["axis_colours"][axes[1]])
        g.vec3("u_eye", cam.eye())
        g.f("u_persp", 0.0 if cam.ortho else 1.0)
        g.f("u_fade", max(12000.0, cam.distance * 3.0))
        g.f("u_behind", 1.0 if cam.ortho else 0.0)
        GL.glBindVertexArray(self.empty_vao)
        GL.glDrawArrays(GL.GL_TRIANGLES, 0, 3)
    def delete(self):
        self.ready = False
