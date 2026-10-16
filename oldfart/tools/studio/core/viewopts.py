from . import theme, vec
def light_of(meta, use_venue=True):
    default = vec.norm((0.35, 0.85, 0.42))
    if not use_venue:
        return default
    look = (meta.get("look") or {}) if isinstance(meta, dict) else {}
    from mapgen import bake
    own = bake.clean_sun(look.get("sun"))
    if own is not None:
        return vec.norm(bake.sun_dir(own["az"], own["el"]))
    light = look.get("light")
    d = None
    if isinstance(light, dict):
        if "dir" in light and len(light["dir"]) == 3:
            d = tuple(light["dir"])
        elif all(k in light for k in "xyz"):
            d = (light["x"], light["y"], light["z"])
    if d is None or vec.length(d) < 1e-6:
        return default
    d = vec.norm(d)
    if d[1] < 0.25:
        d = vec.norm((d[0], 0.25 + abs(d[1]) * 0.2, d[2]))
    return d
def game_light_of(meta, skew=False):
    from mapgen.render import gamelight as gl
    look = (meta.get("look") or {}) if isinstance(meta, dict) else {}
    light = look.get("light")
    if isinstance(light, dict):
        light = light.get("dir") or ([light[k] for k in "xyz"] if all(k in light for k in "xyz")
                                     else None)
    hour = tuple(light) if isinstance(light, (list, tuple)) and len(light) == 3 else None
    stop = None
    for row in look.get("visuals") or []:
        if isinstance(row, (list, tuple)) and len(row) == 2 and row[0] == "shading":
            stop = row[1]
    lit, amb = gl.SHADING.get(stop, gl.SHADING[None])
    return {"light": gl.light_vector(hour),
            "lit": tuple(gl.DIFFUSE * c / 255.0 / 255.0 for c in lit),
            "amb": tuple(gl.AMBIENT * c / 255.0 / 255.0 for c in amb),
            "skew": bool(skew)}
def bake_of(meta):
    from mapgen import bake
    look = (meta.get("look") or {}) if isinstance(meta, dict) else {}
    theme = (meta.get("theme") if isinstance(meta, dict) else None) or None
    pal = bake.sun_palette(look, theme)
    return {k: tuple(float(c) for c in pal[k]) for k in ("sun", "sunc", "sky", "gnd")}
def bake_tint():
    from mapgen import bake
    return tuple(float(c) for c in getattr(bake, "SHADE_TINT", (1.0, 1.0, 1.0)))
def sun_of(meta):
    from mapgen import bake
    look = (meta.get("look") or {}) if isinstance(meta, dict) else {}
    theme = (meta.get("theme") if isinstance(meta, dict) else None) or None
    return bake.sun_of(look, theme)
def with_sun(meta, sun):
    if sun is None or not isinstance(meta, dict):
        return meta
    out = dict(meta)
    out["look"] = dict(meta.get("look") or {}, sun=sun)
    return out
def with_mood(meta):
    look = (meta.get("look") or {}) if isinstance(meta, dict) else {}
    if not isinstance(look.get("mood"), dict):
        return meta
    from mapgen import mood as moodmod
    m = moodmod.clean(look["mood"])
    out_look = dict(look)
    if "light" in m:
        out_look["visuals"] = [r for r in (look.get("visuals") or [])
                               if not (isinstance(r, (list, tuple)) and r and r[0] == "shading")]
        out_look["visuals"].append(["shading", m["light"]])
    if "hour" in m:
        d = moodmod.HOUR_DIRS.get(m["hour"])
        if d is not None:
            out_look["light"] = {"dir": list(d)}
    out = dict(meta)
    out["look"] = out_look
    return out
def mood_of(meta, background=(0.18, 0.2, 0.23), shown=True):
    look = (meta.get("look") or {}) if isinstance(meta, dict) else {}
    from mapgen import mood as moodmod
    if not shown:
        return moodmod.preview({}, background)
    out = moodmod.preview(look["mood"] if isinstance(look.get("mood"), dict) else {}, background)
    from mapgen.render import gamefog
    out["game_fog"] = gamefog.look_fog(look)
    return out
def mood_uniforms(preview, background=(0.18, 0.2, 0.23)):
    if preview is None:
        from mapgen import mood as moodmod
        preview = moodmod.preview({}, background)
    d = preview["dials"]
    gfog, gcol = (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)
    g = preview.get("game_fog")
    if g is not None:
        from mapgen.render import gamefog
        c0, c1 = gamefog.linear(g[0], g[1], g[2])
        gfog, gcol = (c0, c1, 1.0), tuple(float(c) for c in g[3])
    return {"gfog": gfog, "gfog_colour": gcol,
            "fog": float(preview["fog"]),
            "fog_colour": tuple(float(c) for c in preview["fog_colour"]),
            "multiply": tuple(float(c) for c in preview["multiply"]),
            "grade1": (d["hue"], d["saturation"], d["brightness"], d["contrast"]),
            "grade2": (d["exposure"], d["posterization"], d["scanlines"])}
def axis_colours(tokens):
    return {0: theme.rgbf(tokens["axis_x"]), 1: theme.rgbf(tokens["axis_y"]),
            2: theme.rgbf(tokens["axis_z"])}
def grid_plane(cam, height=0.0):
    if cam.ortho and cam.side in ("front", "back"):
        return (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0, 1)
    if cam.ortho and cam.side in ("left", "right"):
        return (0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (2, 1)
    return (0.0, float(height), 0.0), (0.0, 1.0, 0.0), (0, 2)
def fps_text(frame_ms):
    if frame_ms <= 0:
        return ""
    return "%.1f ms  %d fps" % (frame_ms, int(round(1000.0 / frame_ms)))
