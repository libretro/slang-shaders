#version 450
#pragma format R32G32B32A32_SFLOAT

// Global gradient correction step. Pass B of the 2-pass outer iter
// (Picard → gradient) for the unbiased vectorize optimizer. Mirrors
// the CPU `compute_g`-then-step in
// vibeboy/src/scaling/vectorize.rs::optimize_energy.
//
// For each CP i:
//   p_out[i] = p_in[i] − η · clip(∇E_i, MAX_STEP)
//
// Each unique CP touched is fetched once via fetch_basic() (1 Source +
// 1 CellGraph row-0 read for position + flags). Ghost positions for
// stem-shadow neighbors are resolved inline using the already-fetched
// flags plus at most one extra (idx-1) flag check.

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 CellGraphSize;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D CellGraph;

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_W() * CORNERS_H() * 2; }

const uint IS_CORNER    = 16u;
const uint IS_TJUNCTION = 32u;
const uint IS_ENDPOINT  = 128u;

const float POSITIONAL_SCALE = 2.5;
const float ETA      = 0.05;
const float MAX_STEP = 0.25;
const float S4 = POSITIONAL_SCALE * POSITIONAL_SCALE * POSITIONAL_SCALE * POSITIONAL_SCALE;

ivec2 cp_coords(int cp_idx) {
    int cp_half = cp_idx / 2;
    int cp_slot = cp_idx & 1;
    int cx = cp_half % CORNERS_W();
    int cy = cp_half / CORNERS_W();
    return ivec2(cx, cy * 2 + cp_slot);
}

vec2 read_pos(int cp_idx) {
    return texelFetch(Source, cp_coords(cp_idx), 0).rg;
}

// Position + flags for one CP. One Source fetch + one CellGraph row-0
// fetch. Caller is responsible for checking idx >= 0 first.
struct CpBasic {
    vec2 pos;
    uint flags;
};

CpBasic fetch_basic(int cp_idx) {
    CpBasic d;
    ivec2 xy = cp_coords(cp_idx);
    d.pos = texelFetch(Source, xy, 0).rg;
    d.flags = uint(texelFetch(CellGraph, ivec2(xy.x, xy.y * 3), 0).b + 0.5);
    return d;
}

uint read_flags(int cp_idx) {
    ivec2 xy = cp_coords(cp_idx);
    return uint(texelFetch(CellGraph, ivec2(xy.x, xy.y * 3), 0).b + 0.5);
}

vec2 read_orig(int cp_idx) {
    ivec2 xy = cp_coords(cp_idx);
    return texelFetch(CellGraph, ivec2(xy.x, xy.y * 3), 0).rg;
}

int decode_neighbor(vec4 val) {
    if (val.r < -0.5) return -1;
    int ncx = int(val.r + 0.5);
    int ncy = int(val.g + 0.5);
    int nslot = int(val.b + 0.5);
    return (ncy * CORNERS_W() + ncx) * 2 + nslot;
}

ivec2 read_neighbors(int cp_idx) {
    ivec2 xy = cp_coords(cp_idx);
    int base_row = xy.y * 3;
    return ivec2(decode_neighbor(texelFetch(CellGraph, ivec2(xy.x, base_row + 1), 0)),
                 decode_neighbor(texelFetch(CellGraph, ivec2(xy.x, base_row + 2), 0)));
}

// Ghost-aware position resolution given already-fetched CpBasic. Most
// CPs short-circuit on the (flags & 1u) test without any extra fetches.
// Only stem-shadow CPs (bit 0 set AND idx-1 is a T-junction) pay the
// 4-CP synthesis cost.
vec2 ghost_pos(int idx, CpBasic d) {
    if (idx <= 0 || (d.flags & 1u) == 0u) return d.pos;
    if ((read_flags(idx - 1) & IS_TJUNCTION) == 0u) return d.pos;
    int t = idx - 1;
    ivec2 t_nbrs = read_neighbors(t);
    if (t_nbrs.x < 0 || t_nbrs.y < 0) return d.pos;
    bool pe = (read_flags(t_nbrs.x) & IS_ENDPOINT) != 0u;
    bool ne = (read_flags(t_nbrs.y) & IS_ENDPOINT) != 0u;
    float sp, st, sn;
    if (pe && ne)      { sp = 0.25;  st = 0.5;   sn = 0.25; }
    else if (pe)       { sp = 0.25;  st = 0.625; sn = 0.125; }
    else if (ne)       { sp = 0.125; st = 0.625; sn = 0.25; }
    else               { sp = 0.125; st = 0.75;  sn = 0.125; }
    return sp * read_pos(t_nbrs.x) + st * read_pos(t) + sn * read_pos(t_nbrs.y);
}

int seg_mode_3(bool center, bool left, bool right) {
    if (center) return 3;
    if (left && right) return 3;
    if (left) return 2;
    if (right) return 1;
    return 0;
}

void ghost_weights(bool pe, bool ne, out float sp, out float st, out float sn) {
    if (pe && ne)      { sp = 0.25;  st = 0.5;   sn = 0.25; }
    else if (pe)       { sp = 0.25;  st = 0.625; sn = 0.125; }
    else if (ne)       { sp = 0.125; st = 0.625; sn = 0.25; }
    else               { sp = 0.125; st = 0.75;  sn = 0.125; }
}

// Returns θ * j_endpoint for one segment (endpoint ∈ {0,1,2} = a,b,c).
vec2 seg_grad_one(vec2 pa, vec2 pb, vec2 pc, int mode, int endpoint) {
    if (mode == 3) return vec2(0.0);
    vec2 va = pb - pa;
    vec2 vb = pc - pb;
    float inv_la2 = 1.0 / max(va.x * va.x + va.y * va.y, 1e-20);
    float inv_lb2 = 1.0 / max(vb.x * vb.x + vb.y * vb.y, 1e-20);
    vec2 dva = vec2( va.y * inv_la2, -va.x * inv_la2);
    vec2 dvb = vec2(-vb.y * inv_lb2,  vb.x * inv_lb2);
    float theta;
    vec2 j;
    if (mode == 0) {
        theta = atan(va.x * vb.y - va.y * vb.x, va.x * vb.x + va.y * vb.y);
        if      (endpoint == 0) j = -dva;
        else if (endpoint == 1) j = dva - dvb;
        else                    j = dvb;
    } else if (mode == 1) {
        vec2 m = 0.5 * (va + vb);
        theta = atan(va.x * m.y - va.y * m.x, va.x * m.x + va.y * m.y);
        float inv_lm2 = 1.0 / max(m.x * m.x + m.y * m.y, 1e-20);
        vec2 dm = vec2(-m.y * inv_lm2, m.x * inv_lm2);
        if      (endpoint == 0) j = -dva - 0.5 * dm;
        else if (endpoint == 1) j = dva;
        else                    j = 0.5 * dm;
    } else {
        vec2 m = 0.5 * (va + vb);
        theta = atan(m.x * vb.y - m.y * vb.x, m.x * vb.x + m.y * vb.y);
        float inv_lm2 = 1.0 / max(m.x * m.x + m.y * m.y, 1e-20);
        vec2 dm = vec2(-m.y * inv_lm2, m.x * inv_lm2);
        if      (endpoint == 0) j = 0.5 * dm;
        else if (endpoint == 1) j = -dvb;
        else                    j = -0.5 * dm + dvb;
    }
    return theta * j;
}

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);
    int cx = opos.x;
    int cy_slot = opos.y;
    int cp_idx = ((cy_slot / 2) * CORNERS_W() + cx) * 2 + (cy_slot & 1);

    // Fetch self in one go.
    ivec2 self_xy = cp_coords(cp_idx);
    vec2 p_self = texelFetch(Source, self_xy, 0).rg;
    FragColor = vec4(p_self, 0.0, 0.0);
    if (cp_idx >= NUM_CPS()) return;
    vec4 self_cg0 = texelFetch(CellGraph, ivec2(self_xy.x, self_xy.y * 3), 0);
    uint sf = uint(self_cg0.b + 0.5);
    vec2 p_orig = self_cg0.rg;
    if (sf == 0u || (sf & 1u) != 0u) return;

    bool self_corner = (sf & IS_CORNER) != 0u;
    ivec2 self_nbrs = read_neighbors(cp_idx);
    int prev_idx = self_nbrs.x;
    int next_idx = self_nbrs.y;

    // Fetch immediate neighbors. Held across the segment computations
    // because both feed multiple segments and the T-junction cases.
    CpBasic prev_d, next_d;
    if (prev_idx >= 0) prev_d = fetch_basic(prev_idx);
    else { prev_d.pos = vec2(0.0); prev_d.flags = 0u; }
    if (next_idx >= 0) next_d = fetch_basic(next_idx);
    else { next_d.pos = vec2(0.0); next_d.flags = 0u; }

    vec2 g = vec2(0.0);

    // ---- Segment centered at self ----
    if (!self_corner && prev_idx >= 0 && next_idx >= 0) {
        bool prev_corner = (prev_d.flags & IS_CORNER) != 0u;
        bool next_corner = (next_d.flags & IS_CORNER) != 0u;
        int mode = seg_mode_3(self_corner, prev_corner, next_corner);
        // Stem-shadow short-circuits when bit 0 of flags is clear (the
        // common case for regular interior CPs).
        bool prev_stem = ((prev_d.flags & 1u) != 0u) && ((read_flags(prev_idx - 1) & IS_TJUNCTION) != 0u);
        bool next_stem = ((next_d.flags & 1u) != 0u) && ((read_flags(next_idx - 1) & IS_TJUNCTION) != 0u);
        if (mode != 3 && !prev_stem && !next_stem) {
            vec2 pa = ghost_pos(prev_idx, prev_d);
            vec2 pc = ghost_pos(next_idx, next_d);
            g += seg_grad_one(pa, p_self, pc, mode, 1);
        }
    }

    // ---- Segment centered at prev ----
    if (prev_idx >= 0 && (prev_d.flags & (1u | IS_CORNER)) == 0u) {
        ivec2 prev_nbrs = read_neighbors(prev_idx);
        int gp_idx = (prev_nbrs.x == cp_idx) ? prev_nbrs.y : prev_nbrs.x;
        if (gp_idx >= 0) {
            CpBasic gp_d = fetch_basic(gp_idx);
            bool gp_corner = (gp_d.flags & IS_CORNER) != 0u;
            bool gp_stem = ((gp_d.flags & 1u) != 0u) && ((read_flags(gp_idx - 1) & IS_TJUNCTION) != 0u);
            if (!gp_stem) {
                int mode = seg_mode_3(false, gp_corner, self_corner);
                if (mode != 3) {
                    vec2 pa = ghost_pos(gp_idx, gp_d);
                    vec2 pb = ghost_pos(prev_idx, prev_d);
                    g += seg_grad_one(pa, pb, p_self, mode, 2);
                }
            }
        }
    }

    // ---- Segment centered at next ----
    if (next_idx >= 0 && (next_d.flags & (1u | IS_CORNER)) == 0u) {
        ivec2 next_nbrs = read_neighbors(next_idx);
        int gn_idx = (next_nbrs.x == cp_idx) ? next_nbrs.y : next_nbrs.x;
        if (gn_idx >= 0) {
            CpBasic gn_d = fetch_basic(gn_idx);
            bool gn_corner = (gn_d.flags & IS_CORNER) != 0u;
            bool gn_stem = ((gn_d.flags & 1u) != 0u) && ((read_flags(gn_idx - 1) & IS_TJUNCTION) != 0u);
            if (!gn_stem) {
                int mode = seg_mode_3(false, self_corner, gn_corner);
                if (mode != 3) {
                    vec2 pb = ghost_pos(next_idx, next_d);
                    vec2 pc = ghost_pos(gn_idx, gn_d);
                    g += seg_grad_one(p_self, pb, pc, mode, 0);
                }
            }
        }
    }

    // ---- T-junction Case A: self is a T-junction ----
    if ((sf & IS_TJUNCTION) != 0u && prev_idx >= 0 && next_idx >= 0
        && cp_idx + 1 < NUM_CPS()) {
        int s_idx = read_neighbors(cp_idx + 1).x;
        if (s_idx >= 0) {
            ivec2 s_nbrs = read_neighbors(s_idx);
            int so_i = (s_nbrs.x == cp_idx + 1) ? s_nbrs.y : s_nbrs.x;
            if (so_i >= 0) {
                bool pe = (prev_d.flags & IS_ENDPOINT) != 0u;
                bool ne = (next_d.flags & IS_ENDPOINT) != 0u;
                float sp, st, sn;
                ghost_weights(pe, ne, sp, st, sn);
                vec2 ghost = sp * prev_d.pos + st * p_self + sn * next_d.pos;
                g += st * seg_grad_one(ghost, read_pos(s_idx), read_pos(so_i), 0, 0);
            }
        }
    }

    // ---- T-junction Case B: self is T_prev or T_next of an adjacent T-junction ----
    for (int k = 0; k < 2; k++) {
        int t_idx = (k == 0) ? prev_idx : next_idx;
        CpBasic t_d = (k == 0) ? prev_d : next_d;
        if (t_idx < 0 || (t_d.flags & IS_TJUNCTION) == 0u) continue;
        ivec2 t_nbrs = read_neighbors(t_idx);
        if (t_nbrs.x < 0 || t_nbrs.y < 0) continue;
        if (t_nbrs.x != cp_idx && t_nbrs.y != cp_idx) continue;
        if (t_idx + 1 >= NUM_CPS()) continue;
        int s_idx = read_neighbors(t_idx + 1).x;
        if (s_idx < 0) continue;
        ivec2 s_nbrs = read_neighbors(s_idx);
        int so_i = (s_nbrs.x == t_idx + 1) ? s_nbrs.y : s_nbrs.x;
        if (so_i < 0) continue;
        bool pe = (read_flags(t_nbrs.x) & IS_ENDPOINT) != 0u;
        bool ne = (read_flags(t_nbrs.y) & IS_ENDPOINT) != 0u;
        float sp, st, sn;
        ghost_weights(pe, ne, sp, st, sn);
        float w = (t_nbrs.x == cp_idx) ? sp : sn;
        vec2 ghost = sp * read_pos(t_nbrs.x) + st * t_d.pos + sn * read_pos(t_nbrs.y);
        g += w * seg_grad_one(ghost, read_pos(s_idx), read_pos(so_i), 0, 0);
    }

    // ---- T-junction Case C: self is the chain CP s of an adjacent T-junction ----
    for (int k = 0; k < 2; k++) {
        int n_idx = (k == 0) ? prev_idx : next_idx;
        CpBasic n_d = (k == 0) ? prev_d : next_d;
        if (n_idx <= 0 || (n_d.flags & 1u) == 0u) continue;
        int t = n_idx - 1;
        if ((read_flags(t) & IS_TJUNCTION) == 0u) continue;
        ivec2 t_nbrs = read_neighbors(t);
        if (t_nbrs.x < 0 || t_nbrs.y < 0) continue;
        int s_chk = read_neighbors(t + 1).x;
        if (s_chk != cp_idx) continue;
        int so_i = (self_nbrs.x == t + 1) ? self_nbrs.y : self_nbrs.x;
        if (so_i < 0) continue;
        bool pe = (read_flags(t_nbrs.x) & IS_ENDPOINT) != 0u;
        bool ne = (read_flags(t_nbrs.y) & IS_ENDPOINT) != 0u;
        float sp, st, sn;
        ghost_weights(pe, ne, sp, st, sn);
        vec2 ghost = sp * read_pos(t_nbrs.x) + st * read_pos(t) + sn * read_pos(t_nbrs.y);
        g += seg_grad_one(ghost, p_self, read_pos(so_i), 0, 1);
    }

    // Positional gradient.
    vec2 d = p_self - p_orig;
    g += 4.0 * S4 * dot(d, d) * d;

    // Step.
    vec2 step_v = -ETA * g;
    float len2 = dot(step_v, step_v);
    if (len2 > MAX_STEP * MAX_STEP) {
        step_v *= MAX_STEP / sqrt(len2);
    }
    FragColor = vec4(p_self + step_v, 0.0, 0.0);
}
