PIECE_VS = """
#version 330 core
layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec3 a_nrm;
layout(location = 2) in vec2 a_extra;
layout(location = 3) in vec3 i_pos;
layout(location = 4) in vec3 i_size;
layout(location = 5) in vec4 i_misc;
layout(location = 6) in vec3 i_tex;
uniform mat4 u_vp;
uniform vec3 u_cam_right;
uniform vec3 u_cam_up;
uniform vec3 u_cam_back;
uniform vec3 u_glight;
uniform vec3 u_glit;
uniform vec3 u_gamb;
uniform float u_gskew;
out vec3 v_world;
out vec3 v_normal;
out vec3 v_uvw;
out vec3 v_gshade;
flat out float v_state;
flat out float v_slot;
flat out float v_index;

vec3 turn(vec3 p, float s, float c) {
    return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
}

void main() {
    vec3 q = a_pos / 200.0 * i_size;
    float s = sin(i_misc.x), c = cos(i_misc.x);
    vec3 w = turn(q, s, c) + i_pos;
    v_world = w;
    v_normal = normalize(turn(a_nrm / max(i_size, vec3(0.001)), s, c));
    vec2 uv;
    if (abs(a_nrm.x) < 1e-6 && abs(a_nrm.z) < 1e-6) {
        uv = vec2(q.x + i_size.x * 0.5, q.z + i_size.z * 0.5);
    } else if (a_extra.y > 0.5) {
        uv = vec2(q.x + i_size.x * 0.5,
                  (q.z + i_size.z * 0.5) / i_size.z * length(vec2(i_size.y, i_size.z)));
    } else {
        vec2 u = normalize(vec2(a_nrm.z, -a_nrm.x));
        float span = abs(u.x) > abs(u.y) ? i_size.x : i_size.z;
        uv = vec2(dot(q.xz, u) + span * 0.5, i_size.y - q.y);
    }
    vec3 wl = u_glight.x * u_cam_right + u_glight.y * u_cam_up + u_glight.z * u_cam_back;
    vec3 ol = vec3(dot(vec3(c, 0.0, -s), wl), wl.y, dot(vec3(s, 0.0, c), wl));
    if (u_gskew > 0.5) ol *= i_size / 200.0;
    ol = normalize(ol);
    vec3 nr = normalize(a_nrm / max(i_size, vec3(0.001)));
    v_gshade = min(vec3(1.0), u_gamb + max(dot(nr, ol), 0.0) * u_glit);
    float layer = a_extra.x < 0.5 ? i_tex.x : (a_extra.x < 1.5 ? i_tex.y : i_tex.z);
    v_uvw = vec3(uv / 200.0, layer);
    v_state = i_misc.y;
    v_slot = i_misc.z;
    v_index = i_misc.w;
    gl_Position = u_vp * vec4(w, 1.0);
}
"""
PIECE_FS = """
#version 330 core
in vec3 v_world;
in vec3 v_normal;
in vec3 v_uvw;
in vec3 v_gshade;
flat in float v_state;
flat in float v_slot;
flat in float v_index;
uniform sampler2DArray u_tex;
uniform int u_shading;
uniform vec3 u_bsun;
uniform vec3 u_bsunc;
uniform vec3 u_bsky;
uniform vec3 u_bgnd;
uniform vec3 u_btint;
uniform vec3 u_light;
uniform vec3 u_eye;
uniform vec3 u_bg;
uniform float u_fog;
uniform vec2 u_fog_range;
uniform vec3 u_accent;
uniform vec3 u_slots[8];
uniform float u_hover;
uniform float u_ghost;
uniform vec2 u_height;
uniform float u_mfog;
uniform vec3 u_mfog_col;
uniform vec3 u_gfog;
uniform vec3 u_gfog_col;
uniform float u_gfog_shift;
uniform vec3 u_mmul;
uniform vec4 u_grade1;
uniform vec3 u_grade2;
out vec4 frag;

vec3 hue_turn(vec3 c, float turns) {
    float a = turns * 6.2831853;
    vec3 k = vec3(0.57735);
    float ca = cos(a);
    return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

vec3 mood_grade(vec3 col) {
    col *= u_mmul;
    col = hue_turn(col, u_grade1.x);
    float grey = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(grey), col, u_grade1.y);
    col *= u_grade1.z;
    col = (col - 0.5) * u_grade1.w + 0.5;
    col *= u_grade2.x;
    if (u_grade2.y < 7.5) col = floor(clamp(col, 0.0, 1.0) * u_grade2.y + 0.5) / u_grade2.y;
    if (u_grade2.z > 1.01 && mod(gl_FragCoord.y, 4.0) < 1.0)
        col *= 1.0 - min(0.6, (u_grade2.z - 1.0) * 0.07);
    return clamp(col, 0.0, 1.0);
}

vec3 height_ramp(float t) {
    vec3 a = vec3(0.20, 0.36, 0.78), b = vec3(0.30, 0.78, 0.62), c = vec3(0.96, 0.80, 0.32),
         d = vec3(0.94, 0.38, 0.33);
    t = clamp(t, 0.0, 1.0);
    if (t < 0.33) return mix(a, b, t / 0.33);
    if (t < 0.66) return mix(b, c, (t - 0.33) / 0.33);
    return mix(c, d, (t - 0.66) / 0.34);
}

void main() {
    vec3 n = normalize(v_normal);
    if (!gl_FrontFacing) n = -n;
    vec3 base;
    if (u_shading == 1) {
        base = textureLod(u_tex, v_uvw, 10.0).rgb;
    } else if (u_shading == 2) {
        float t = (v_world.y - u_height.x) / max(1.0, u_height.y - u_height.x);
        base = height_ramp(t);
    } else {
        base = texture(u_tex, v_uvw).rgb;
    }
    float diff = max(dot(n, normalize(u_light)), 0.0);
    float sky = 0.5 + 0.5 * n.y;
    vec3 col = base * (0.42 + 0.18 * sky + 0.55 * diff);
    if (u_shading == 3) col = base * v_gshade;
    if (u_shading == 4) {
        float hemi = 0.5 + 0.5 * n.y;
        vec3 amb = mix(u_bgnd, u_bsky, hemi) * u_btint;
        float ndl = max(dot(n, normalize(u_bsun)), 0.0);
        col = base * min(vec3(1.0), amb + u_bsunc * ndl * 0.60);
    }
    int state = int(v_state + 0.5);
    if ((state & 16) != 0 && (state & 1) == 0) discard;
    int slot = int(v_slot + 0.5);
    if (slot > 0) col = mix(col, u_slots[slot - 1], 0.45);
    if ((state & 1) != 0) col = mix(col, u_accent, 0.32) + 0.03;
    if ((state & 8) != 0) col = mix(col, u_accent, 0.12);
    if (abs(v_index - u_hover) < 0.5 && v_index >= 0.0) col = col * 1.15 + 0.035;
    float dist = length(v_world - u_eye);
    float f = u_fog * smoothstep(u_fog_range.x, u_fog_range.y, dist);
    col = mix(col, u_bg, f);
    col = mood_grade(col);
    float mf = u_mfog * smoothstep(u_fog_range.x * 0.15, u_fog_range.x * 2.2, dist);
    col = mix(col, u_mfog_col, mf);
    if (u_gfog.z > 0.5) {
        float gf = clamp((u_gfog.x + u_gfog.y / max(dist - u_gfog_shift, 1.0)) / 255.0, 0.0, 1.0);
        col = mix(col, u_gfog_col, gf);
    }
    float alpha = 1.0;
    if (u_ghost > 0.5) {
        col = mix(col, u_accent, 0.35);
        alpha = 0.32;
    }
    frag = vec4(col, alpha);
}
"""
EDGE_VS = """
#version 330 core
layout(location = 0) in vec3 a_pos;
layout(location = 3) in vec3 i_pos;
layout(location = 4) in vec3 i_size;
layout(location = 5) in vec4 i_misc;
uniform mat4 u_vp;
flat out float v_state;
flat out float v_index;
void main() {
    vec3 q = a_pos / 200.0 * i_size;
    float s = sin(i_misc.x), c = cos(i_misc.x);
    vec3 w = vec3(q.x * c + q.z * s, q.y, -q.x * s + q.z * c) + i_pos;
    v_state = i_misc.y;
    v_index = i_misc.w;
    gl_Position = u_vp * vec4(w, 1.0);
}
"""
EDGE_FS = """
#version 330 core
flat in float v_state;
flat in float v_index;
uniform vec3 u_accent;
uniform float u_all;
uniform float u_hover;
out vec4 frag;
void main() {
    int state = int(v_state + 0.5);
    if ((state & 1) != 0) { frag = vec4(u_accent * 1.25 + 0.1, 1.0); return; }
    if (abs(v_index - u_hover) < 0.5 && v_index >= 0.0) { frag = vec4(1.0, 1.0, 1.0, 0.85); return; }
    if ((state & 4) != 0) { frag = vec4(u_accent, 0.6); return; }
    if ((state & 16) != 0) { frag = vec4(0.62, 0.80, 1.0, 0.35); return; }
    if (u_all < 0.5) discard;
    frag = vec4(0.0, 0.0, 0.0, 0.28);
}
"""
MARKER_VS = """
#version 330 core
layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec3 a_nrm;
layout(location = 3) in vec4 i_pos_yaw;
layout(location = 4) in vec4 i_col_state;
uniform mat4 u_vp;
out vec3 v_normal;
out vec3 v_col;
flat out float v_state;
void main() {
    float s = sin(i_pos_yaw.w), c = cos(i_pos_yaw.w);
    vec3 p = vec3(a_pos.x * c + a_pos.z * s, a_pos.y, -a_pos.x * s + a_pos.z * c);
    v_normal = vec3(a_nrm.x * c + a_nrm.z * s, a_nrm.y, -a_nrm.x * s + a_nrm.z * c);
    v_col = i_col_state.rgb;
    v_state = i_col_state.a;
    gl_Position = u_vp * vec4(p + i_pos_yaw.xyz, 1.0);
}
"""
MARKER_FS = """
#version 330 core
in vec3 v_normal;
in vec3 v_col;
flat in float v_state;
uniform vec3 u_light;
uniform vec3 u_accent;
out vec4 frag;
void main() {
    vec3 n = normalize(v_normal);
    if (!gl_FrontFacing) n = -n;
    float diff = max(dot(n, normalize(u_light)), 0.0);
    vec3 col = v_col * (0.55 + 0.5 * diff);
    if (v_state > 0.5) col = mix(col, u_accent, 0.5) + 0.08;
    frag = vec4(col, 1.0);
}
"""
GRID_VS = """
#version 330 core
out vec2 v_ndc;
void main() {
    vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2) * 2.0 - 1.0;
    v_ndc = p;
    gl_Position = vec4(p, 0.0, 1.0);
}
"""
GRID_FS = """
#version 330 core
in vec2 v_ndc;
uniform mat4 u_inv_vp;
uniform mat4 u_vp;
uniform vec3 u_plane_point;
uniform vec3 u_plane_normal;
uniform ivec2 u_axes;
uniform vec2 u_spacing;
uniform vec3 u_line;
uniform vec3 u_axis_a;
uniform vec3 u_axis_b;
uniform vec3 u_eye;
uniform float u_persp;
uniform float u_fade;
uniform float u_behind;
out vec4 frag;

float lines(vec2 coord, float spacing) {
    vec2 g = coord / spacing;
    vec2 w = fwidth(g);
    vec2 a = abs(fract(g - 0.5) - 0.5) / max(w, vec2(1e-6));
    return 1.0 - min(min(a.x, a.y), 1.0);
}

void main() {
    vec4 n0 = u_inv_vp * vec4(v_ndc, -1.0, 1.0);
    vec4 n1 = u_inv_vp * vec4(v_ndc, 1.0, 1.0);
    vec3 p0 = n0.xyz / n0.w, p1 = n1.xyz / n1.w;
    vec3 d = p1 - p0;
    float den = dot(d, u_plane_normal);
    if (abs(den) < 1e-9) discard;
    float t = dot(u_plane_point - p0, u_plane_normal) / den;
    if (t < 0.0 || t > 1.0) discard;
    vec3 hit = p0 + d * t;
    vec2 coord = vec2(hit[u_axes.x], hit[u_axes.y]);
    float minor = lines(coord, u_spacing.x);
    float major = lines(coord, u_spacing.y);
    float a = max(minor * 0.16, major * 0.34);
    vec3 col = u_line;
    vec2 w = fwidth(coord);
    float on_a = 1.0 - min(abs(coord.y) / max(w.y, 1e-6) / 1.5, 1.0);
    float on_b = 1.0 - min(abs(coord.x) / max(w.x, 1e-6) / 1.5, 1.0);
    if (on_a > 0.0) { col = mix(col, u_axis_a, on_a); a = max(a, on_a * 0.85); }
    if (on_b > 0.0) { col = mix(col, u_axis_b, on_b); a = max(a, on_b * 0.85); }
    if (u_persp > 0.5) {
        float dist = length(hit - u_eye);
        a *= 1.0 - smoothstep(u_fade * 0.35, u_fade, dist);
        a *= smoothstep(0.0, 0.12, abs(dot(normalize(d), u_plane_normal)));
    }
    if (a < 0.003) discard;
    vec4 clip = u_vp * vec4(hit, 1.0);
    gl_FragDepth = u_behind > 0.5 ? 0.999999 : clamp((clip.z / clip.w) * 0.5 + 0.5, 0.0, 1.0);
    frag = vec4(col, a);
}
"""
BACKGROUND_VS = GRID_VS
BACKGROUND_FS = """
#version 330 core
in vec2 v_ndc;
uniform vec3 u_top;
uniform vec3 u_bottom;
out vec4 frag;
void main() {
    float t = clamp(v_ndc.y * 0.5 + 0.5, 0.0, 1.0);
    float v = 1.0 - 0.18 * dot(v_ndc * 0.7, v_ndc * 0.7);
    frag = vec4(mix(u_bottom, u_top, t) * v, 1.0);
}
"""
BAKED_VS = """
#version 330 core
layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec2 a_uv;
layout(location = 2) in vec3 a_col;
layout(location = 3) in float a_layer;
layout(location = 4) in vec3 a_nrm;
layout(location = 5) in float a_water;
uniform mat4 u_vp;
out vec3 v_world;
out vec3 v_uvw;
out vec3 v_col;
out vec3 v_nrm;
out float v_water;
void main() {
    v_world = a_pos;
    v_uvw = vec3(a_uv, a_layer);
    v_col = a_col;
    v_nrm = a_nrm;
    v_water = a_water;
    gl_Position = u_vp * vec4(a_pos, 1.0);
}
"""
BAKED_FS = """
#version 330 core
in vec3 v_world;
in vec3 v_uvw;
in vec3 v_col;
in vec3 v_nrm;
in float v_water;
uniform sampler2DArray u_tex;
uniform vec3 u_eye;
uniform vec3 u_bg;
uniform float u_fog;
uniform vec2 u_fog_range;
uniform float u_mfog;
uniform vec3 u_mfog_col;
uniform vec3 u_gfog;
uniform vec3 u_gfog_col;
uniform float u_gfog_shift;
uniform vec3 u_mmul;
uniform vec4 u_grade1;
uniform vec3 u_grade2;
out vec4 frag;
""" + PIECE_FS[PIECE_FS.index("vec3 hue_turn"):PIECE_FS.index("vec3 height_ramp")] + """
void main() {
    if (v_water < 0.5 && dot(v_nrm, u_eye - v_world) <= 0.0) discard;
    vec3 col = texture(u_tex, v_uvw).rgb * v_col;
    if (v_water > 0.5) col = col * 0.55 + vec3(0.47, 0.64, 0.78) * 0.45;
    float dist = length(v_world - u_eye);
    float f = u_fog * smoothstep(u_fog_range.x, u_fog_range.y, dist);
    col = mix(col, u_bg, f);
    col = mood_grade(col);
    float mf = u_mfog * smoothstep(u_fog_range.x * 0.15, u_fog_range.x * 2.2, dist);
    col = mix(col, u_mfog_col, mf);
    if (u_gfog.z > 0.5) {
        float gf = clamp((u_gfog.x + u_gfog.y / max(dist - u_gfog_shift, 1.0)) / 255.0, 0.0, 1.0);
        col = mix(col, u_gfog_col, gf);
    }
    frag = vec4(col, 1.0);
}
"""
FLAME_VS = """
#version 330 core
layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec4 a_col;
uniform mat4 u_vp;
out vec4 v_col;
void main() {
    v_col = a_col;
    gl_Position = u_vp * vec4(a_pos, 1.0);
}
"""
FLAME_FS = """
#version 330 core
in vec4 v_col;
out vec4 frag;
void main() {
    if (v_col.a <= 0.002) discard;
    frag = v_col;
}
"""
