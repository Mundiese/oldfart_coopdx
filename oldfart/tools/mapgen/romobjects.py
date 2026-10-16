import glob
import importlib.util
import math
import os
import re
import numpy as np
TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(TOOLS)
ENV = "OF_DECOMP"
MISSING = "Set up your ROM extraction to paint vanilla objects"
LAYERS = ("LAYER_OPAQUE", "LAYER_OPAQUE_DECAL", "LAYER_ALPHA", "LAYER_TRANSPARENT_DECAL",
          "LAYER_TRANSPARENT", "LAYER_OPAQUE_INTER", "LAYER_TRANSPARENT_INTER")
NO_SHELVES = ("Enemies", "Bosses")
NO_WAYS = ("mode", "track", "sound", "ball", "tri")
GEO = {
    "E_MODEL_1UP": "mushroom_1up_geo",
    "E_MODEL_AMP": "amp_geo",
    "E_MODEL_BBH_TILTING_FLOOR_PLATFORM": "geo_bbh_0005C8",
    "E_MODEL_BBH_TUMBLING_PLATFORM": "geo_bbh_0005E0",
    "E_MODEL_BITDW_FERRIS_WHEEL_AXLE": "geo_bitdw_000570",
    "E_MODEL_BITDW_SEESAW_PLATFORM": "geo_bitdw_000540",
    "E_MODEL_BITFS_SEESAW_PLATFORM": "bitfs_geo_000788",
    "E_MODEL_BITFS_SINKING_CAGE_PLATFORM": "bitfs_geo_000690",
    "E_MODEL_BITFS_SINKING_PLATFORMS": "bitfs_geo_000770",
    "E_MODEL_BITFS_STRETCHING_PLATFORMS": "bitfs_geo_000708",
    "E_MODEL_BITS_OCTAGONAL_PLATFORM": "bits_geo_000610",
    "E_MODEL_BITS_SEESAW_PLATFORM": "bits_geo_000670",
    "E_MODEL_BITS_TILTING_W_PLATFORM": "bits_geo_000688",
    "E_MODEL_BITS_WARP_PIPE": "warp_pipe_geo",
    "E_MODEL_BLUE_COIN": "blue_coin_geo",
    "E_MODEL_BLUE_COIN_SWITCH": "blue_coin_switch_geo",
    "E_MODEL_BOB_SEESAW_PLATFORM": "bob_geo_000458",
    "E_MODEL_BOO": "boo_geo",
    "E_MODEL_BOOKEND": "bookend_geo",
    "E_MODEL_BOWLING_BALL": "bowling_ball_geo",
    "E_MODEL_BOWSER_2_TILTING_ARENA": "bowser_2_geo_000170",
    "E_MODEL_BREAKABLE_BOX": "breakable_box_geo",
    "E_MODEL_BREAKABLE_BOX_SMALL": "breakable_box_small_geo",
    "E_MODEL_BUB": "bub_geo",
    "E_MODEL_BUBBA": "bubba_geo",
    "E_MODEL_BUBBLY_TREE": "bubbly_tree_geo",
    "E_MODEL_BULLET_BILL": "bullet_bill_geo",
    "E_MODEL_CANNON_BASE": "cannon_base_geo",
    "E_MODEL_CAP_SWITCH": "cap_switch_geo",
    "E_MODEL_CASTLE_BOWSER_TRAP": "castle_geo_000F18",
    "E_MODEL_CHECKERBOARD_PLATFORM": "checkerboard_platform_geo",
    "E_MODEL_CLAM_SHELL": "clam_shell_geo",
    "E_MODEL_COURTYARD_SPIKY_TREE": "spiky_tree_geo",
    "E_MODEL_DDD_POLE": "ddd_geo_000450",
    "E_MODEL_ENEMY_LAKITU": "enemy_lakitu_geo",
    "E_MODEL_EXCLAMATION_BOX": "exclamation_box_geo",
    "E_MODEL_EXCLAMATION_BOX_OUTLINE": "exclamation_box_outline_geo",
    "E_MODEL_FLYGUY": "flyguy_geo",
    "E_MODEL_HAUNTED_CHAIR": "haunted_chair_geo",
    "E_MODEL_HEART": "heart_geo",
    "E_MODEL_HMC_ELEVATOR_PLATFORM": "hmc_geo_0005D0",
    "E_MODEL_HMC_ROLLING_ROCK": "hmc_geo_000548",
    "E_MODEL_JRB_FALLING_PILLAR": "jrb_geo_000900",
    "E_MODEL_JRB_FLOATING_PLATFORM": "jrb_geo_000948",
    "E_MODEL_KLEPTO": "klepto_geo",
    "E_MODEL_KOOPA_SHELL": "koopa_shell_geo",
    "E_MODEL_LLL_MOVING_OCTAGONAL_MESH_PLATFORM": "lll_geo_000B08",
    "E_MODEL_LLL_ROLLING_LOG": "lll_geo_000DE8",
    "E_MODEL_LLL_ROTATING_BLOCK_FIRE_BARS": "lll_geo_000B38",
    "E_MODEL_LLL_ROTATING_HEXAGONAL_RING": "lll_geo_000BB0",
    "E_MODEL_LLL_SINKING_ROCK_BLOCK": "lll_geo_000DD0",
    "E_MODEL_LLL_TILTING_SQUARE_PLATFORM": "lll_geo_000BF8",
    "E_MODEL_LLL_VOLCANO_FALLING_TRAP": "lll_geo_000EA8",
    "E_MODEL_MAD_PIANO": "mad_piano_geo",
    "E_MODEL_MARIOS_WING_CAP": "marios_wing_cap_geo",
    "E_MODEL_METAL_BOX": "metal_box_geo",
    "E_MODEL_MIPS": "mips_geo",
    "E_MODEL_MR_I": "mr_i_geo",
    "E_MODEL_NONE": "NULL",
    "E_MODEL_PALM_TREE": "palm_tree_geo",
    "E_MODEL_PENGUIN": "penguin_geo",
    "E_MODEL_PURPLE_SWITCH": "purple_switch_geo",
    "E_MODEL_RED_COIN": "red_coin_geo",
    "E_MODEL_RED_FLAME": "red_flame_geo",
    "E_MODEL_RR_DONUT_PLATFORM": "rr_geo_000920",
    "E_MODEL_RR_ELEVATOR_PLATFORM": "rr_geo_0008F0",
    "E_MODEL_RR_OCTAGONAL_PLATFORM": "rr_geo_0008A8",
    "E_MODEL_RR_ROTATING_BRIDGE_PLATFORM": "rr_geo_000878",
    "E_MODEL_RR_SEESAW_PLATFORM": "rr_geo_000908",
    "E_MODEL_RR_SWINGING_PLATFORM": "rr_geo_000860",
    "E_MODEL_SKEETER": "skeeter_geo",
    "E_MODEL_SNOW_TREE": "snow_tree_geo",
    "E_MODEL_SNUFIT": "snufit_geo",
    "E_MODEL_SSL_GRINDEL": "ssl_geo_000734",
    "E_MODEL_SSL_MOVING_PYRAMID_WALL": "ssl_geo_000794",
    "E_MODEL_SSL_SPINDEL": "ssl_geo_000764",
    "E_MODEL_SSL_TOX_BOX": "ssl_geo_000630",
    "E_MODEL_SWOOP": "swoop_geo",
    "E_MODEL_TRAMPOLINE": "springboard_top_geo",
    "E_MODEL_TTC_CLOCK_HAND": "ttc_geo_000358",
    "E_MODEL_TTC_ELEVATOR_PLATFORM": "ttc_geo_000340",
    "E_MODEL_TTC_LARGE_GEAR": "ttc_geo_0003A0",
    "E_MODEL_TTC_LARGE_TREADMILL": "ttc_geo_000288",
    "E_MODEL_TTC_PENDULUM": "ttc_geo_000270",
    "E_MODEL_TTC_PIT_BLOCK": "ttc_geo_000310",
    "E_MODEL_TTC_PUSH_BLOCK": "ttc_geo_0002C8",
    "E_MODEL_TTC_ROTATING_CUBE": "ttc_geo_000240",
    "E_MODEL_TTC_ROTATING_HEXAGON": "ttc_geo_0002E0",
    "E_MODEL_TTC_ROTATING_PRISM": "ttc_geo_000258",
    "E_MODEL_TTC_ROTATING_TRIANGLE": "ttc_geo_0002F8",
    "E_MODEL_TTC_SMALL_GEAR": "ttc_geo_000388",
    "E_MODEL_TTC_SMALL_TREADMILL": "ttc_geo_0002A8",
    "E_MODEL_TTC_SPINNER": "ttc_geo_000370",
    "E_MODEL_TTM_ROLLING_LOG": "ttm_geo_000730",
    "E_MODEL_TWEESTER": "tweester_geo",
    "E_MODEL_UNAGI": "unagi_geo",
    "E_MODEL_WATER_BOMB": "water_bomb_geo",
    "E_MODEL_WDW_ARROW_LIFT": "wdw_geo_000598",
    "E_MODEL_WDW_SQUARE_FLOATING_PLATFORM": "wdw_geo_000580",
    "E_MODEL_WF_KICKABLE_BOARD": "wf_geo_000BA8",
    "E_MODEL_WF_TOWER_SQUARE_PLATORM_ELEVATOR": "wf_geo_000B60",
    "E_MODEL_WOODEN_POST": "wooden_post_geo",
    "E_MODEL_WOODEN_SIGNPOST": "wooden_signpost_geo",
    "E_MODEL_YELLOW_COIN": "yellow_coin_geo",
    "E_MODEL_YOSHI": "yoshi_geo",
}
_cache = {}
def _read(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()
def _faces_tool():
    if "rvf" not in _cache:
        path = os.path.join(TOOLS, "render-vanilla-face.py")
        spec = importlib.util.spec_from_file_location("render_vanilla_face", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _cache["rvf"] = mod
    return _cache["rvf"]
def root(env=None):
    env = os.environ if env is None else env
    path = env.get(ENV) or ""
    if not path:
        return None
    path = os.path.abspath(os.path.expanduser(path))
    if os.path.basename(path.rstrip(os.sep)) == "levels":
        path = os.path.dirname(path.rstrip(os.sep))
    if not os.path.isdir(os.path.join(path, "actors")):
        return None
    if not glob.glob(os.path.join(path, "actors", "*", "*.png")):
        return None
    return path
def _lua_list(text, name):
    m = re.search(r"^arena\.%s = \{(.*?)^\}" % name, text, re.S | re.M)
    if not m:
        return set()
    body = "\n".join(line.split("--", 1)[0] for line in m.group(1).splitlines())
    return set(re.findall(r"id_(bhv\w+)", body))
def swept():
    if "swept" not in _cache:
        with open(os.path.join(REPO, "of_arena.lua"), encoding="utf-8") as handle:
            text = handle.read()
        _cache["swept"] = _lua_list(text, "ENEMIES") | _lua_list(text, "BOSSES")
    return _cache["swept"]
def placed(arena):
    from . import kit, modpackthings as mt
    shelves = kit.forge_shelves()
    rows = mt.spawner_rows()
    out = []
    for o in arena.get("objects") or []:
        if not isinstance(o, dict):
            continue
        key = o.get("key")
        row = rows.get(key)
        if row is None or shelves.get(key) in NO_SHELVES or mt.way(key) in NO_WAYS:
            continue
        bhv = str(row.get("bhv") or "")
        bhv = bhv[3:] if bhv.startswith("id_") else bhv
        if bhv in swept():
            continue
        model, _second, _params = mt.made(row, o)
        geo = GEO.get(str(model or ""))
        if geo is None:
            continue
        out.append((key, geo, float(o.get("x", 0) or 0), float(o.get("y", 0) or 0),
                    float(o.get("z", 0) or 0), float(o.get("yaw", 0) or 0), bhv))
    return out
def wanted(arena):
    return bool(placed(arena))
class Extraction:
    def __init__(self, path):
        self.root = path
        self.symbols = {}
        files = (glob.glob(os.path.join(path, "actors", "*", "*.inc.c"))
                 + glob.glob(os.path.join(path, "levels", "*", "*", "*.inc.c"))
                 + glob.glob(os.path.join(path, "bin", "*.c")))
        self.geo_file = {}
        for f in files:
            text = _read(f)
            for name, inc in re.findall(r"(\w+)\[\] = \{\s*#include \"([^\"]+)\.inc\.c\"", text):
                self.symbols[name] = inc
            if f.endswith("geo.inc.c"):
                for name in re.findall(r"const GeoLayout (\w+)\[\]", text):
                    self.geo_file[name] = f
        self._pics, self._texts, self._models = {}, {}, {}
        self.billboards = set()
        bd = os.path.join(path, "data", "behavior_data.c")
        if os.path.isfile(bd):
            text = _read(bd)
            for name, body in re.findall(r"const BehaviorScript (\w+)\[\] = \{(.*?)\n\};",
                                         text, re.S):
                if "BILLBOARD()" in body:
                    self.billboards.add(name)
    def picture(self, name):
        if name not in self._pics:
            inc = self.symbols.get(name)
            pic = None
            if inc:
                p = os.path.join(self.root, inc + ".png")
                if os.path.isfile(p):
                    from PIL import Image
                    with Image.open(p) as im:
                        pic = np.asarray(im.convert("RGBA"), np.float64) / 255.0
            self._pics[name] = pic
        return self._pics[name]
    def texts(self, folder):
        if folder not in self._texts:
            rvf = _faces_tool()
            text = ""
            for f in sorted(glob.glob(os.path.join(folder, "*.inc.c"))):
                if os.path.basename(f) in ("geo.inc.c", "collision.inc.c", "anims.inc.c"):
                    continue
                text += _read(f) + "\n"
            self._texts[folder] = (rvf._vertices(text), rvf._lights(text), rvf._lists(text))
        return self._texts[folder]
    def model(self, geo):
        if geo not in self._models:
            self._models[geo] = self._walk_geo(geo)
        return self._models[geo]
    def _geo_nodes(self, geo):
        f = self.geo_file.get(geo)
        if f is None:
            return None, None
        text = _read(f)
        m = re.search(r"const GeoLayout %s\[\] = \{(.*?)\n\};" % re.escape(geo), text, re.S)
        if not m:
            return None, None
        cmds = re.findall(r"(GEO_\w+)\((.*?)\),?\s*$", m.group(1), re.M)
        root = {"op": "ROOT", "args": "", "kids": []}
        stack, last = [root], root
        for op, args in cmds:
            if op == "GEO_OPEN_NODE":
                stack.append(last)
            elif op == "GEO_CLOSE_NODE":
                if len(stack) > 1:
                    stack.pop()
            elif op in ("GEO_END", "GEO_RETURN"):
                break
            else:
                node = {"op": op, "args": args, "kids": []}
                stack[-1]["kids"].append(node)
                last = node
        return root, os.path.dirname(f)
    def _walk_geo(self, geo, depth=0):
        root, folder = self._geo_nodes(geo)
        if root is None or depth > 4:
            return []
        out = []
        self._node(root, np.eye(4), False, folder, out, depth)
        return out
    def _node(self, node, m, board, folder, out, depth):
        op, args = node["op"], [a.strip() for a in node["args"].split(",")] if node["args"] else []
        kids = node["kids"]
        def num(a):
            try:
                return float(int(a, 0))
            except ValueError:
                return 0.0
        dl = None
        if op == "GEO_DISPLAY_LIST" and len(args) >= 2 and args[0] in LAYERS:
            dl = args[1]
        elif op == "GEO_ANIMATED_PART" and len(args) >= 5:
            m = m @ _translate(num(args[1]), num(args[2]), num(args[3]))
            if args[0] in LAYERS and args[4] != "NULL":
                dl = args[4]
        elif op in ("GEO_TRANSLATE_NODE", "GEO_TRANSLATE") and len(args) >= 4:
            m = m @ _translate(num(args[1]), num(args[2]), num(args[3]))
        elif op == "GEO_TRANSLATE_NODE_WITH_DL" and len(args) >= 5:
            m = m @ _translate(num(args[1]), num(args[2]), num(args[3]))
            dl = args[4] if args[0] in LAYERS else None
        elif op in ("GEO_ROTATION_NODE", "GEO_ROTATE") and len(args) >= 4:
            m = m @ _rotate(num(args[1]), num(args[2]), num(args[3]))
        elif op in ("GEO_TRANSLATE_ROTATE", "GEO_TRANSLATE_ROTATE_WITH_DL") and len(args) >= 7:
            m = m @ _translate(num(args[1]), num(args[2]), num(args[3])) @ _rotate(
                num(args[4]), num(args[5]), num(args[6]))
            if op.endswith("WITH_DL") and len(args) >= 8 and args[0] in LAYERS:
                dl = args[7]
        elif op == "GEO_SCALE" and len(args) >= 2:
            k = num(args[1]) / 65536.0
            m = m @ np.diag((k, k, k, 1.0))
        elif op == "GEO_BILLBOARD":
            board = True
        elif op in ("GEO_BRANCH", "GEO_BRANCH_AND_LINK") and args:
            for part in self._walk_geo(args[-1], depth + 1):
                out.append(part[:5] + (m @ part[5], board or part[6]))
        elif op in ("GEO_HELD_OBJECT", "GEO_ASM", "GEO_SHADOW", "GEO_RENDER_RANGE"):
            pass
        if dl:
            self._list(dl, m, board, folder, out)
        if op == "GEO_SWITCH_CASE":
            kids = kids[:1]
        for k in kids:
            self._node(k, m, board, folder, out, depth)
    def _list(self, dl, m, board, folder, out):
        verts, lights, lists = self.texts(folder)
        st = {"tex": None, "size": (32, 32), "lit": True, "textured": True, "light": None,
              "scale": (1.0, 1.0)}
        buf = {}
        groups = {}
        rvf = _faces_tool()
        def run(name, depth=0):
            body = lists.get(name)
            if body is None or depth > 8:
                return
            for cmd in re.finditer(r"(gs\w+)\((.*?)\),?\n", body + "\n"):
                op, args = cmd.group(1), cmd.group(2)
                if op == "gsSPDisplayList":
                    run(args.strip(), depth + 1)
                elif op == "gsSPBranchList":
                    run(args.strip(), depth + 1)
                    return
                elif op == "gsDPSetTextureImage":
                    st["tex"] = args.split(",")[-1].strip()
                elif op.startswith("gsDPLoadTextureBlock"):
                    parts = [a.strip() for a in args.split(",")]
                    st["tex"] = parts[0]
                    try:
                        st["size"] = (int(parts[3]), int(parts[4]))
                    except (ValueError, IndexError):
                        pass
                elif op == "gsDPSetTileSize":
                    mm = re.findall(r"\((\d+) - 1\)", args)
                    if len(mm) == 2:
                        st["size"] = (int(mm[0]), int(mm[1]))
                elif op == "gsSPSetGeometryMode" and "G_LIGHTING" in args:
                    st["lit"] = True
                elif op == "gsSPClearGeometryMode" and "G_LIGHTING" in args:
                    st["lit"] = False
                elif op == "gsSPLight":
                    mm = re.match(r"&(\w+)\.l", args.strip())
                    if mm:
                        st["light"] = mm.group(1)
                elif op == "gsSPTexture":
                    st["textured"] = "G_ON" in args
                    sc = rvf._ints(args)[:2]
                    if len(sc) == 2:
                        st["scale"] = tuple(min(1.0, v / 65535.0) if v else 1.0 for v in sc)
                elif op == "gsSPVertex":
                    mm = re.match(r"\s*(\w+)(?:\s*\+\s*(\d+))?,\s*(\d+),\s*(\d+)", args)
                    if not mm or mm.group(1) not in verts:
                        continue
                    rows = verts[mm.group(1)]
                    first = int(mm.group(2) or 0)
                    for k in range(int(mm.group(3))):
                        if first + k < len(rows):
                            buf[int(mm.group(4)) + k] = rows[first + k]
                elif op in ("gsSP1Triangle", "gsSP2Triangles"):
                    v = rvf._ints(args)
                    tris = [v[0:3]] if op == "gsSP1Triangle" else [v[0:3], v[4:7]]
                    key = st["tex"] if st["textured"] and st["tex"] else "__white"
                    g = groups.setdefault((key,) + tuple(st["size"]) + tuple(st["scale"]), [])
                    for t in tris:
                        if all(i in buf for i in t):
                            g.append([(buf[i], st["lit"], st["light"]) for i in t])
        run(dl)
        for (key, w, h, su, sv), tris in groups.items():
            pic = self.picture(key) if key != "__white" else None
            if pic is None:
                pic, key = np.ones((1, 1, 4)), "__white"
            out.append((key, pic, (w / su, h / sv), tris, lights, m, board))
def _translate(x, y, z):
    t = np.eye(4)
    t[:3, 3] = (x, y, z)
    return t
def _rotate(rx, ry, rz):
    ax, ay, az = (math.radians(a) for a in (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = (math.cos(ax), math.sin(ax), math.cos(ay), math.sin(ay),
                              math.cos(az), math.sin(az))
    X = np.array(((1, 0, 0), (0, cx, -sx), (0, sx, cx)))
    Y = np.array(((cy, 0, sy), (0, 1, 0), (-sy, 0, cy)))
    Z = np.array(((cz, -sz, 0), (sz, cz, 0), (0, 0, 1)))
    out = np.eye(4)
    out[:3, :3] = Y @ X @ Z
    return out
def extraction(path):
    if ("x", path) not in _cache:
        _cache[("x", path)] = Extraction(path)
    return _cache[("x", path)]
def triangles(objs, cam, path):
    from .render import levelview
    if not objs or not path:
        return None
    ex = extraction(path)
    rot = np.stack([cam.right, cam.up, cam.back])
    P, UV, C, N, T, keys = [], [], [], [], [], []
    for _key, geo, x, y, z, yaw, bhv in objs:
        parts = ex.model(geo)
        if not parts:
            continue
        if bhv in ex.billboards:
            face = np.array(cam.eye) - np.array((x, y, z))
            turn = math.atan2(face[0], face[2])
            pitch = math.atan2(face[1], math.hypot(face[0], face[2]))
            place = _translate(x, y, z) @ _rotate(0, math.degrees(turn), 0) @ _rotate(
                -math.degrees(pitch), 0, 0)
        else:
            place = _translate(x, y, z) @ _rotate(0, yaw, 0)
        for tkey, pic, (w, h), tris, lights, m, _board in parts:
            k = ("rom", tkey)
            levelview._pictures[k] = pic[..., :3].astype(np.float32)
            if pic.shape[-1] == 4 and float(pic[..., 3].min()) < 0.5:
                levelview._alphas[k] = pic[..., 3]
            if k not in keys:
                keys.append(k)
            full = place @ m
            lin = full[:3, :3]
            for tri in tris:
                p = np.array([v[:3] for v, _, _ in tri], np.float64)
                p = (lin @ p.T).T + full[:3, 3]
                n = np.cross(p[1] - p[0], p[2] - p[0])
                if np.linalg.norm(n) < 1e-9:
                    continue
                n /= np.linalg.norm(n)
                shade = []
                for v, lit, lname in tri:
                    if lit and lname in lights:
                        amb, dif, ldir = lights[lname]
                        vn = np.array([c - 256 if c > 127 else c for c in v[5:8]], np.float64)
                        vn = lin @ vn
                        vn = rot @ (vn / max(np.linalg.norm(vn), 1e-9))
                        shade.append(np.clip(amb + dif * max(0.0, float(vn @ ldir)), 0, 1))
                    else:
                        shade.append(np.array(v[5:8], np.float64) / 255.0)
                P.append(p)
                UV.append([(v[3] / 32.0 / w, v[4] / 32.0 / h) for v, _, _ in tri])
                C.append(shade)
                N.append(n)
                T.append(keys.index(k))
    if not P:
        return None
    return (np.array(P), np.array(UV), np.array(C), np.array(N), np.array(T, np.int32), keys)
