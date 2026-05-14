#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass 3: cell-graph builder.
//
// Builds B-spline control points at grid corners from the resolved
// similarity graph. Each CP is packed into a single RGBA32F texel using a
// uint-bits encoding (channels B/A carry uint bit patterns reinterpreted
// as float). Downstream passes (init-positions, optimize-energy,
// gradient-correction, update-tjunction, pack-positions, cell-rasterizer)
// read this format directly.
//
// 1 fragment per (grid corner, slot). Output texture: (W+1) × 2(H+1).
//
// Output layout (per corner cx, cy, slot ∈ {0, 1}):
//   Col cx, Row cy * 2 + slot:
//     R = pos.x
//     G = pos.y
//     B = uintBitsToFloat( (flag    << 24) | (prev_idx_24bit & 0xFFFFFFu) )
//     A = uintBitsToFloat( (dir_pack << 24) | (next_idx_24bit & 0xFFFFFFu) )
//
// dir_pack = (prev_dir + 1) | ((next_dir + 1) << 3)
//   — equals the legacy `(prev_dir+1) + (next_dir+1)*8` value, since 8 is
//     a power of two and each field fits in 3 bits.
// prev_idx_24bit / next_idx_24bit: 0xFFFFFFu sentinel for "no neighbor"
// (== -1 in the unpacked int domain), else the CP's global linear index.
// 24 bits supports up to 16M CPs — comfortable for any pixel-art input.

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
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

layout(set = 0, binding = 2) uniform sampler2D Source;   // ResolvedGraph

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }

const uint IS_CORNER = 16u;
const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING  = 64u;
const uint IS_ENDPOINT  = 128u;

uint g(int gx, int gy) {
    if (gx < 0 || gy < 0 || gx >= IMG_W() * 2 || gy >= IMG_H() * 2)
        return 0u;
    vec4 val = texelFetch(Source, ivec2(gx, gy), 0);
    return uint(val.r + 0.5);
}

uint px_color(int px, int py) {
    px = clamp(px, 0, IMG_W() - 1);
    py = clamp(py, 0, IMG_H() - 1);
    int gx = 2 * px + 1;
    int gy = 2 * py + 1;
    vec4 c = texelFetch(Source, ivec2(gx, gy), 0);
    uint r = uint(c.r * 255.0 + 0.5);
    uint g_ = uint(c.g * 255.0 + 0.5);
    uint b = uint(c.b * 255.0 + 0.5);
    return (r << 16u) | (g_ << 8u) | b;
}

void bnd_colors(int cx, int cy, int dir, out uint ca, out uint cb) {
    if (dir == 0)      { ca = px_color(cx - 1, cy - 1); cb = px_color(cx, cy - 1); }
    else if (dir == 1) { ca = px_color(cx, cy - 1);     cb = px_color(cx, cy);     }
    else if (dir == 2) { ca = px_color(cx, cy);         cb = px_color(cx - 1, cy); }
    else               { ca = px_color(cx - 1, cy);     cb = px_color(cx - 1, cy - 1); }
}

bool is_shading_edge(uint ca, uint cb) {
    if (ca == cb) return true;
    float dr = float(int((ca >> 16u) & 0xFFu) - int((cb >> 16u) & 0xFFu));
    float dg = float(int((ca >> 8u)  & 0xFFu) - int((cb >> 8u)  & 0xFFu));
    float db = float(int(ca & 0xFFu)          - int(cb & 0xFFu));
    float dy = (0.299 * dr + 0.587 * dg + 0.114 * db) / 255.0;
    float du = 0.493 * (db / 255.0 - dy);
    float dv = 0.877 * (dr / 255.0 - dy);
    float threshold = 100.0 / 255.0;
    return (dy * dy + du * du + dv * dv) <= threshold * threshold;
}

void select_tjunction_pair(int cx, int cy, int d0, int d1, int d2,
                           out int pair0, out int pair1) {
    uint ca0, cb0, ca1, cb1, ca2, cb2;
    bnd_colors(cx, cy, d0, ca0, cb0);
    bnd_colors(cx, cy, d1, ca1, cb1);
    bnd_colors(cx, cy, d2, ca2, cb2);
    bool s0 = is_shading_edge(ca0, cb0);
    bool s1 = is_shading_edge(ca1, cb1);
    bool s2 = is_shading_edge(ca2, cb2);
    int shading_count = (s0 ? 1 : 0) + (s1 ? 1 : 0) + (s2 ? 1 : 0);

    if (shading_count == 1) {
        if (s0) { pair0 = d1; pair1 = d2; }
        else if (s1) { pair0 = d0; pair1 = d2; }
        else { pair0 = d0; pair1 = d1; }
        return;
    }
    if ((d0 ^ d2) == 2) { pair0 = d0; pair1 = d2; }
    else if ((d0 ^ d1) == 2) { pair0 = d0; pair1 = d1; }
    else { pair0 = d1; pair1 = d2; }
}

bool similar(int px0, int py0, int px1, int py1) {
    int dx = px1 - px0;
    int dy = py1 - py0;
    int gx = 2 * px0 + 1;
    int gy = 2 * py0 + 1;
    if (dx == 1 && dy == 0) return g(gx + 1, gy) != 0u;
    if (dx == -1 && dy == 0) return g(gx - 1, gy) != 0u;
    if (dx == 0 && dy == 1) return g(gx, gy + 1) != 0u;
    if (dx == 0 && dy == -1) return g(gx, gy - 1) != 0u;
    return false;
}

int cp_base(int cx, int cy) {
    if (cx < 0 || cy < 0 || cx >= CORNERS_W() || cy >= CORNERS_H())
        return -1;
    return (cy * CORNERS_W() + cx) * 2;
}

int nbr_cp_idx(int cx, int cy, int from_dir) {
    int base = cp_base(cx, cy);
    if (base < 0) return -1;
    if (cx <= 0 || cy <= 0 || cx >= IMG_W() || cy >= IMG_H())
        return base;
    uint diag = g(2 * cx, 2 * cy);
    bool is_ullr = (diag & 1u) != 0u && (diag & 2u) == 0u;
    bool is_llur = (diag & 2u) != 0u && (diag & 1u) == 0u;

    if (!is_ullr && !is_llur) {
        bool t_bnd_n = g(2 * cx, 2 * cy - 1) == 0u;
        bool t_bnd_e = g(2 * cx + 1, 2 * cy) == 0u;
        bool t_bnd_s = g(2 * cx, 2 * cy + 1) == 0u;
        bool t_bnd_w = g(2 * cx - 1, 2 * cy) == 0u;
        uint t_count = (t_bnd_n ? 1u : 0u) + (t_bnd_e ? 1u : 0u)
                     + (t_bnd_s ? 1u : 0u) + (t_bnd_w ? 1u : 0u);
        if (t_count == 4u) {
            int target_side = from_dir ^ 2;
            if (target_side != 0 && target_side != 2) return base + 1;
        } else if (t_count == 3u) {
            int dirs[3]; int di = 0;
            if (t_bnd_n) dirs[di++] = 0;
            if (t_bnd_e) dirs[di++] = 1;
            if (t_bnd_s) dirs[di++] = 2;
            if (t_bnd_w) dirs[di++] = 3;
            int pair0, pair1;
            select_tjunction_pair(cx, cy, dirs[0], dirs[1], dirs[2], pair0, pair1);
            int target_side = from_dir ^ 2;
            if (target_side != pair0 && target_side != pair1) return base + 1;
        }
        return base;
    }

    int slot = 0;
    if (from_dir == 0) { if (is_llur) slot = 1; }
    else if (from_dir == 2) { if (is_ullr) slot = 1; }
    else if (from_dir == 3) { slot = 1; }
    return base + slot;
}

vec2 neighbor_cp_pos(int cx, int cy, int from_dir) {
    vec2 base_pos = vec2(float(cx), float(cy));
    if (cx <= 0 || cy <= 0 || cx >= IMG_W() || cy >= IMG_H()) return base_pos;
    uint diag = g(2 * cx, 2 * cy);
    bool is_ullr = (diag & 1u) != 0u && (diag & 2u) == 0u;
    bool is_llur = (diag & 2u) != 0u && (diag & 1u) == 0u;
    if (!is_ullr && !is_llur) return base_pos;
    int slot = 0;
    if (from_dir == 0) { if (is_llur) slot = 1; }
    else if (from_dir == 2) { if (is_ullr) slot = 1; }
    else if (from_dir == 3) { slot = 1; }
    if (is_ullr) {
        return (slot == 0) ? base_pos + vec2(-0.25, 0.25)
                           : base_pos + vec2(0.25, -0.25);
    } else {
        return (slot == 0) ? base_pos + vec2(-0.25, -0.25)
                           : base_pos + vec2(0.25, 0.25);
    }
}

bool checkForCorner(vec2 v1, vec2 v2) {
    float len1 = length(v1);
    float len2 = length(v2);
    if (len1 < 1e-6 || len2 < 1e-6) return false;
    float dp = dot(v1, v2) / (len1 * len2);
    if (dp > -0.01 && dp < 0.01) return true;
    if (dp > -0.72 && dp < -0.69) return true;
    if (dp > -0.33 && dp < -0.30) return true;
    return false;
}

bool is_isolated_pixel(int px, int py) {
    if (px <= 0 || py <= 0 || px >= IMG_W() - 1 || py >= IMG_H() - 1) return false;
    uint cand = px_color(px, py);
    uint n_col = px_color(px, py - 1);
    if (n_col == cand) return false;
    uint e_col = px_color(px + 1, py);
    uint s_col = px_color(px, py + 1);
    uint w_col = px_color(px - 1, py);
    if (n_col != e_col || n_col != s_col || n_col != w_col) return false;
    uint diag_tl = g(2 * px,       2 * py);
    uint diag_tr = g(2 * (px + 1), 2 * py);
    uint diag_br = g(2 * (px + 1), 2 * (py + 1));
    uint diag_bl = g(2 * px,       2 * (py + 1));
    return ((diag_tl & 2u) != 0u)
        && ((diag_tr & 1u) != 0u)
        && ((diag_br & 2u) != 0u)
        && ((diag_bl & 1u) != 0u);
}

struct CPData {
    vec2 pos;
    int prev;
    int next;
    uint flag;
    int prev_dir;
    int next_dir;
};

CPData make_inactive() {
    return CPData(vec2(0.0), -1, -1, 0u, -1, -1);
}

void compute_corner(int cx, int cy, out CPData slot0, out CPData slot1) {
    slot0 = make_inactive();
    slot1 = make_inactive();
    int base = cp_base(cx, cy);
    if (base < 0) return;
    bool is_interior = cx > 0 && cy > 0 && cx < IMG_W() && cy < IMG_H();

    if (!is_interior) {
        bool has_boundary = false;
        if (cy == 0 && cx > 0 && cx < IMG_W())
            has_boundary = !similar(cx - 1, 0, cx, 0);
        if (cy == IMG_H() && cx > 0 && cx < IMG_W())
            has_boundary = has_boundary || !similar(cx - 1, IMG_H() - 1, cx, IMG_H() - 1);
        if (cx == 0 && cy > 0 && cy < IMG_H())
            has_boundary = has_boundary || !similar(0, cy - 1, 0, cy);
        if (cx == IMG_W() && cy > 0 && cy < IMG_H())
            has_boundary = has_boundary || !similar(IMG_W() - 1, cy - 1, IMG_W() - 1, cy);
        if (has_boundary) {
            int nbr = -1;
            int our_dir = -1;
            if (cy == IMG_H())      { nbr = nbr_cp_idx(cx, cy-1, 0); our_dir = 0; }
            else if (cy == 0)       { nbr = nbr_cp_idx(cx, cy+1, 2); our_dir = 2; }
            else if (cx == IMG_W()) { nbr = nbr_cp_idx(cx-1, cy, 3); our_dir = 3; }
            else if (cx == 0)       { nbr = nbr_cp_idx(cx+1, cy, 1); our_dir = 1; }
            slot0.pos = vec2(float(cx), float(cy));
            slot0.flag = 1u;
            slot0.next = nbr;
            slot0.next_dir = our_dir;
        }
        return;
    }

    uint diag = g(2 * cx, 2 * cy);
    bool has_main = (diag & 1u) != 0u;
    bool has_anti = (diag & 2u) != 0u;
    bool bnd_n = !similar(cx - 1, cy - 1, cx, cy - 1);
    bool bnd_e = !similar(cx, cy - 1, cx, cy);
    bool bnd_s = !similar(cx - 1, cy, cx, cy);
    bool bnd_w = !similar(cx - 1, cy - 1, cx - 1, cy);
    uint bnd_count = (bnd_n ? 1u : 0u) + (bnd_e ? 1u : 0u)
                   + (bnd_s ? 1u : 0u) + (bnd_w ? 1u : 0u);
    if (bnd_count == 0u) return;

    if (has_main && !has_anti) {
        bool cp0_has_s = bnd_s, cp0_has_w = bnd_w;
        bool cp1_has_n = bnd_n, cp1_has_e = bnd_e;
        bool cp0_alive = cp0_has_s || cp0_has_w;
        bool cp1_alive = cp1_has_n || cp1_has_e;
        if (cp0_alive) {
            vec2 p0 = vec2(float(cx) - 0.25, float(cy) + 0.25);
            int prev0 = cp0_has_s ? nbr_cp_idx(cx, cy + 1, 2) : -1;
            int next0 = cp0_has_w ? nbr_cp_idx(cx - 1, cy, 3) : -1;
            bool cp0_junction = !(cp0_has_s && cp0_has_w);
            uint cp0_flag = cp0_junction ? 1u : 2u;
            if (!cp0_junction) {
                vec2 s_pos = neighbor_cp_pos(cx, cy + 1, 2);
                vec2 w_pos = neighbor_cp_pos(cx - 1, cy, 3);
                if (checkForCorner(s_pos - p0, w_pos - p0)) cp0_flag |= IS_CORNER;
                if (is_isolated_pixel(cx - 1, cy)) p0 = vec2(float(cx), float(cy));
            }
            int d_prev = cp0_has_s ? 2 : -1;
            int d_next = cp0_has_w ? 3 : -1;
            slot0 = CPData(p0, prev0, next0, cp0_flag, d_prev, d_next);
        }
        if (cp1_alive) {
            vec2 p1 = vec2(float(cx) + 0.25, float(cy) - 0.25);
            int prev1 = cp1_has_n ? nbr_cp_idx(cx, cy - 1, 0) : -1;
            int next1 = cp1_has_e ? nbr_cp_idx(cx + 1, cy, 1) : -1;
            bool cp1_junction = !(cp1_has_n && cp1_has_e);
            uint cp1_flag = cp1_junction ? 1u : 2u;
            if (!cp1_junction) {
                vec2 n_pos = neighbor_cp_pos(cx, cy - 1, 0);
                vec2 e_pos = neighbor_cp_pos(cx + 1, cy, 1);
                if (checkForCorner(n_pos - p1, e_pos - p1)) cp1_flag |= IS_CORNER;
                if (is_isolated_pixel(cx, cy - 1)) p1 = vec2(float(cx), float(cy));
            }
            int d_prev = cp1_has_n ? 0 : -1;
            int d_next = cp1_has_e ? 1 : -1;
            slot1 = CPData(p1, prev1, next1, cp1_flag, d_prev, d_next);
        }
        return;
    }

    if (has_anti && !has_main) {
        bool cp0_has_n = bnd_n, cp0_has_w = bnd_w;
        bool cp1_has_s = bnd_s, cp1_has_e = bnd_e;
        bool cp0_alive = cp0_has_n || cp0_has_w;
        bool cp1_alive = cp1_has_s || cp1_has_e;
        if (cp0_alive) {
            vec2 p0 = vec2(float(cx) - 0.25, float(cy) - 0.25);
            int prev0 = cp0_has_n ? nbr_cp_idx(cx, cy - 1, 0) : -1;
            int next0 = cp0_has_w ? nbr_cp_idx(cx - 1, cy, 3) : -1;
            bool cp0_junction = !(cp0_has_n && cp0_has_w);
            uint cp0_flag = cp0_junction ? 1u : 2u;
            if (!cp0_junction) {
                vec2 n_pos = neighbor_cp_pos(cx, cy - 1, 0);
                vec2 w_pos = neighbor_cp_pos(cx - 1, cy, 3);
                if (checkForCorner(n_pos - p0, w_pos - p0)) cp0_flag |= IS_CORNER;
                if (is_isolated_pixel(cx - 1, cy - 1)) p0 = vec2(float(cx), float(cy));
            }
            int d_prev = cp0_has_n ? 0 : -1;
            int d_next = cp0_has_w ? 3 : -1;
            slot0 = CPData(p0, prev0, next0, cp0_flag, d_prev, d_next);
        }
        if (cp1_alive) {
            vec2 p1 = vec2(float(cx) + 0.25, float(cy) + 0.25);
            int prev1 = cp1_has_s ? nbr_cp_idx(cx, cy + 1, 2) : -1;
            int next1 = cp1_has_e ? nbr_cp_idx(cx + 1, cy, 1) : -1;
            bool cp1_junction = !(cp1_has_s && cp1_has_e);
            uint cp1_flag = cp1_junction ? 1u : 2u;
            if (!cp1_junction) {
                vec2 s_pos = neighbor_cp_pos(cx, cy + 1, 2);
                vec2 e_pos = neighbor_cp_pos(cx + 1, cy, 1);
                if (checkForCorner(s_pos - p1, e_pos - p1)) cp1_flag |= IS_CORNER;
                if (is_isolated_pixel(cx, cy)) p1 = vec2(float(cx), float(cy));
            }
            int d_prev = cp1_has_s ? 2 : -1;
            int d_next = cp1_has_e ? 1 : -1;
            slot1 = CPData(p1, prev1, next1, cp1_flag, d_prev, d_next);
        }
        return;
    }

    vec2 pos = vec2(float(cx), float(cy));
    int n_idx = bnd_n ? nbr_cp_idx(cx, cy - 1, 0) : -1;
    int e_idx = bnd_e ? nbr_cp_idx(cx + 1, cy, 1) : -1;
    int s_idx = bnd_s ? nbr_cp_idx(cx, cy + 1, 2) : -1;
    int w_idx = bnd_w ? nbr_cp_idx(cx - 1, cy, 3) : -1;

    if (bnd_count == 2u) {
        int prev = -1, next = -1;
        int p_dir = -1, n_dir = -1;
        if (bnd_n) { if (prev < 0) { prev = n_idx; p_dir = 0; } else { next = n_idx; n_dir = 0; } }
        if (bnd_e) { if (prev < 0) { prev = e_idx; p_dir = 1; } else { next = e_idx; n_dir = 1; } }
        if (bnd_s) { if (prev < 0) { prev = s_idx; p_dir = 2; } else { next = s_idx; n_dir = 2; } }
        if (bnd_w) { if (prev < 0) { prev = w_idx; p_dir = 3; } else { next = w_idx; n_dir = 3; } }
        uint f = 2u;
        if (p_dir >= 0 && n_dir >= 0) {
            int prev_cx = cx + ((p_dir == 1) ? 1 : (p_dir == 3) ? -1 : 0);
            int prev_cy = cy + ((p_dir == 2) ? 1 : (p_dir == 0) ? -1 : 0);
            int next_cx = cx + ((n_dir == 1) ? 1 : (n_dir == 3) ? -1 : 0);
            int next_cy = cy + ((n_dir == 2) ? 1 : (n_dir == 0) ? -1 : 0);
            vec2 pp = neighbor_cp_pos(prev_cx, prev_cy, p_dir);
            vec2 np = neighbor_cp_pos(next_cx, next_cy, n_dir);
            if (checkForCorner(pp - pos, np - pos)) f |= IS_CORNER;
        }
        slot0 = CPData(pos, prev, next, f, p_dir, n_dir);
    } else if (bnd_count == 1u) {
        int nbr = -1; int nbr_dir = -1;
        if (bnd_n) { nbr = n_idx; nbr_dir = 0; }
        else if (bnd_e) { nbr = e_idx; nbr_dir = 1; }
        else if (bnd_s) { nbr = s_idx; nbr_dir = 2; }
        else { nbr = w_idx; nbr_dir = 3; }
        slot0 = CPData(pos, nbr, -1, 1u, nbr_dir, -1);
    } else if (bnd_count == 3u) {
        int dirs[3]; int di = 0;
        if (bnd_n) dirs[di++] = 0;
        if (bnd_e) dirs[di++] = 1;
        if (bnd_s) dirs[di++] = 2;
        if (bnd_w) dirs[di++] = 3;
        int t_prev_dir, t_next_dir;
        select_tjunction_pair(cx, cy, dirs[0], dirs[1], dirs[2], t_prev_dir, t_next_dir);
        int idx_arr[4] = int[4](n_idx, e_idx, s_idx, w_idx);
        int prev = idx_arr[t_prev_dir];
        int next = idx_arr[t_next_dir];
        if (prev >= 0 && next >= 0) {
            int prev_slot = prev / 2;
            int prev_cx = prev_slot % CORNERS_W();
            int prev_cy = prev_slot / CORNERS_W();
            int next_slot = next / 2;
            int next_cx = next_slot % CORNERS_W();
            int next_cy = next_slot / CORNERS_W();
            pos = vec2(
                0.125 * float(prev_cx) + 0.75 * float(cx) + 0.125 * float(next_cx),
                0.125 * float(prev_cy) + 0.75 * float(cy) + 0.125 * float(next_cy)
            );
        }
        slot0 = CPData(pos, prev, next, 2u | IS_TJUNCTION, t_prev_dir, t_next_dir);
        int stem_idx = -1; int stem_dir = -1;
        if (bnd_n && t_prev_dir != 0 && t_next_dir != 0) { stem_idx = n_idx; stem_dir = 0; }
        else if (bnd_e && t_prev_dir != 1 && t_next_dir != 1) { stem_idx = e_idx; stem_dir = 1; }
        else if (bnd_s && t_prev_dir != 2 && t_next_dir != 2) { stem_idx = s_idx; stem_dir = 2; }
        else if (bnd_w && t_prev_dir != 3 && t_next_dir != 3) { stem_idx = w_idx; stem_dir = 3; }
        if (stem_idx >= 0) {
            slot1 = CPData(pos, stem_idx, -1, 1u, stem_dir, -1);
        }
    } else {
        slot0 = CPData(pos, n_idx, s_idx, 2u | IS_CROSSING, 0, 2);
        slot1 = CPData(pos, e_idx, w_idx, 2u | IS_CROSSING, 1, 3);
    }
}

// Pack a single CP into the 4-channel compact format. -1 indices map
// to the 24-bit sentinel 0xFFFFFFu (which decodes back to -1 in Pass B).
vec4 pack_cp(CPData cp) {
    if (cp.flag == 0u) {
        // Inactive slot: write zeros for pos+flag, sentinels for neighbors.
        return vec4(
            0.0,
            0.0,
            uintBitsToFloat(0x00FFFFFFu), // flag=0, prev=-1
            uintBitsToFloat(0x00FFFFFFu)  // dir_pack=0, next=-1
        );
    }

    // Mark chain endpoints (matches the gate in the legacy main).
    uint flag = cp.flag;
    if (cp.prev < 0 || cp.next < 0) flag |= IS_ENDPOINT;

    uint dir_pack = uint(cp.prev_dir + 1) | (uint(cp.next_dir + 1) << 3);
    uint prev_safe = (cp.prev < 0) ? 0xFFFFFFu : (uint(cp.prev) & 0xFFFFFFu);
    uint next_safe = (cp.next < 0) ? 0xFFFFFFu : (uint(cp.next) & 0xFFFFFFu);

    return vec4(
        cp.pos.x,
        cp.pos.y,
        uintBitsToFloat((flag     << 24) | prev_safe),
        uintBitsToFloat((dir_pack << 24) | next_safe)
    );
}

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);
    int cx = opos.x;
    int row = opos.y;

    // Output rows are organized as `cy * 2 + slot`, with `slot ∈ {0, 1}`.
    int cy = row / 2;
    int slot = row & 1;

    if (cx > IMG_W() || cy > IMG_H() || cx >= CORNERS_W() || cy >= CORNERS_H()) {
        FragColor = vec4(0.0);
        return;
    }

    CPData s0, s1;
    compute_corner(cx, cy, s0, s1);
    CPData cp = (slot == 0) ? s0 : s1;
    FragColor = pack_cp(cp);
}
