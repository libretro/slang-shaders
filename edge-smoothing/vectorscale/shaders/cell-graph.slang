#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass 3: cell-graph builder. Builds B-spline control points at grid
// corners from the resolved similarity graph and packs each CP into a
// single RGBA32F texel.
//
// 1 fragment per (grid corner, slot). Output texture: (W+1) × 2(H+1).
//
// Output layout (per corner cx, cy, slot ∈ {0, 1}):
//   Col cx, Row (cy*2 + slot):
//     R = pos.x
//     G = pos.y
//     B = uintBitsToFloat( (flag    << 24) | (prev_idx_24bit & 0xFFFFFFu) )
//     A = uintBitsToFloat( (dir_pack << 24) | (next_idx_24bit & 0xFFFFFFu) )
//
// Row-interleaved slot — slot 0 and slot 1 of the same corner sit on
// adjacent rows so downstream readers hit the same texture cache line.
//
// dir_pack = (prev_dir + 1) | ((next_dir + 1) << 3)  (3 bits each).
// prev/next_idx_24bit: 0xFFFFFFu = "no neighbor" (decodes to -1).

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

// 4 pixel colors around corner (cx, cy):
//   .x = NW (cx-1, cy-1)   .y = NE (cx, cy-1)
//   .z = SE (cx,   cy)     .w = SW (cx-1, cy)
uvec4 load_corner_pixels(int cx, int cy) {
    return uvec4(
        px_color(cx - 1, cy - 1),
        px_color(cx,     cy - 1),
        px_color(cx,     cy),
        px_color(cx - 1, cy)
    );
}

uvec2 bnd_colors_from(uvec4 c, int dir) {
    if (dir == 0) return uvec2(c.x, c.y);
    if (dir == 1) return uvec2(c.y, c.z);
    if (dir == 2) return uvec2(c.z, c.w);
    return uvec2(c.w, c.x);
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

ivec2 select_tjunction_pair(int cx, int cy, int d0, int d1, int d2) {
    uvec4 corners = load_corner_pixels(cx, cy);
    uvec2 c0 = bnd_colors_from(corners, d0);
    uvec2 c1 = bnd_colors_from(corners, d1);
    uvec2 c2 = bnd_colors_from(corners, d2);
    bool s0 = is_shading_edge(c0.x, c0.y);
    bool s1 = is_shading_edge(c1.x, c1.y);
    bool s2 = is_shading_edge(c2.x, c2.y);
    int shading_count = (s0 ? 1 : 0) + (s1 ? 1 : 0) + (s2 ? 1 : 0);

    if (shading_count == 1) {
        if (s0) return ivec2(d1, d2);
        if (s1) return ivec2(d0, d2);
        return ivec2(d0, d1);
    }
    if ((d0 ^ d2) == 2) return ivec2(d0, d2);
    if ((d0 ^ d1) == 2) return ivec2(d0, d1);
    return ivec2(d1, d2);
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

// Bit-packed CP encoding: (cy << 12) | (cx << 1) | slot.
//   bit 0 = slot, bits 1-11 = cx (max 2047), bits 12+ = cy.
// Decoded via shifts; fits within the 24-bit CellGraph index storage.
int cp_base(int cx, int cy) {
    if (cx < 0 || cy < 0 || cx >= CORNERS_W() || cy >= CORNERS_H())
        return -1;
    return (cy << 12) | (cx << 1);
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
        uint t_g_n = g(2 * cx,     2 * cy - 1);
        uint t_g_e = g(2 * cx + 1, 2 * cy);
        uint t_g_s = g(2 * cx,     2 * cy + 1);
        uint t_g_w = g(2 * cx - 1, 2 * cy);
        bool t_bnd_n = t_g_n == 0u;
        bool t_bnd_e = t_g_e == 0u;
        bool t_bnd_s = t_g_s == 0u;
        bool t_bnd_w = t_g_w == 0u;
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
            ivec2 pair = select_tjunction_pair(cx, cy, dirs[0], dirs[1], dirs[2]);
            int target_side = from_dir ^ 2;
            if (target_side != pair.x && target_side != pair.y) return base + 1;
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

// Compute CPData for one (corner, slot). Slot-specialized: most cases
// short-circuit on slot==1; only diagonal / T-junction / crossing cases
// produce a slot-1 CP.
CPData compute_corner(int cx, int cy, int slot) {
    CPData cp = make_inactive();
    int base = cp_base(cx, cy);
    if (base < 0) return cp;
    bool is_interior = cx > 0 && cy > 0 && cx < IMG_W() && cy < IMG_H();

    if (!is_interior) {
        // Boundary corners never produce slot 1.
        if (slot != 0) return cp;
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
            cp.pos = vec2(float(cx), float(cy));
            cp.flag = 1u;
            cp.next = nbr;
            cp.next_dir = our_dir;
        }
        return cp;
    }

    // Batch the 4 edge-bit fetches up front for parallel memory issue.
    uint g_n = g(2 * cx,     2 * cy - 1);
    uint g_e = g(2 * cx + 1, 2 * cy);
    uint g_s = g(2 * cx,     2 * cy + 1);
    uint g_w = g(2 * cx - 1, 2 * cy);
    bool bnd_n = (g_n == 0u);
    bool bnd_e = (g_e == 0u);
    bool bnd_s = (g_s == 0u);
    bool bnd_w = (g_w == 0u);
    uint bnd_count = (bnd_n ? 1u : 0u) + (bnd_e ? 1u : 0u)
                   + (bnd_s ? 1u : 0u) + (bnd_w ? 1u : 0u);
    if (bnd_count == 0u) return cp;

    // diag is only needed for the diagonal-pattern branches below.
    uint diag = g(2 * cx, 2 * cy);
    bool has_main = (diag & 1u) != 0u;
    bool has_anti = (diag & 2u) != 0u;

    if (has_main && !has_anti) {
        // Main-diagonal: slot 0 at (-0.25, +0.25) uses S/W; slot 1 at
        // (+0.25, -0.25) uses N/E.
        if (slot == 0) {
            bool has_s = bnd_s, has_w = bnd_w;
            if (!(has_s || has_w)) return cp;
            vec2 p = vec2(float(cx) - 0.25, float(cy) + 0.25);
            int prev = has_s ? nbr_cp_idx(cx, cy + 1, 2) : -1;
            int next = has_w ? nbr_cp_idx(cx - 1, cy, 3) : -1;
            bool junction = !(has_s && has_w);
            uint flag = junction ? 1u : 2u;
            if (!junction) {
                vec2 s_pos = neighbor_cp_pos(cx, cy + 1, 2);
                vec2 w_pos = neighbor_cp_pos(cx - 1, cy, 3);
                if (checkForCorner(s_pos - p, w_pos - p)) flag |= IS_CORNER;
                if (is_isolated_pixel(cx - 1, cy)) p = vec2(float(cx), float(cy));
            }
            int d_prev = has_s ? 2 : -1;
            int d_next = has_w ? 3 : -1;
            cp = CPData(p, prev, next, flag, d_prev, d_next);
        } else {
            bool has_n = bnd_n, has_e = bnd_e;
            if (!(has_n || has_e)) return cp;
            vec2 p = vec2(float(cx) + 0.25, float(cy) - 0.25);
            int prev = has_n ? nbr_cp_idx(cx, cy - 1, 0) : -1;
            int next = has_e ? nbr_cp_idx(cx + 1, cy, 1) : -1;
            bool junction = !(has_n && has_e);
            uint flag = junction ? 1u : 2u;
            if (!junction) {
                vec2 n_pos = neighbor_cp_pos(cx, cy - 1, 0);
                vec2 e_pos = neighbor_cp_pos(cx + 1, cy, 1);
                if (checkForCorner(n_pos - p, e_pos - p)) flag |= IS_CORNER;
                if (is_isolated_pixel(cx, cy - 1)) p = vec2(float(cx), float(cy));
            }
            int d_prev = has_n ? 0 : -1;
            int d_next = has_e ? 1 : -1;
            cp = CPData(p, prev, next, flag, d_prev, d_next);
        }
        return cp;
    }

    if (has_anti && !has_main) {
        // Anti-diagonal: slot 0 at (-0.25, -0.25) uses N/W; slot 1 at
        // (+0.25, +0.25) uses S/E.
        if (slot == 0) {
            bool has_n = bnd_n, has_w = bnd_w;
            if (!(has_n || has_w)) return cp;
            vec2 p = vec2(float(cx) - 0.25, float(cy) - 0.25);
            int prev = has_n ? nbr_cp_idx(cx, cy - 1, 0) : -1;
            int next = has_w ? nbr_cp_idx(cx - 1, cy, 3) : -1;
            bool junction = !(has_n && has_w);
            uint flag = junction ? 1u : 2u;
            if (!junction) {
                vec2 n_pos = neighbor_cp_pos(cx, cy - 1, 0);
                vec2 w_pos = neighbor_cp_pos(cx - 1, cy, 3);
                if (checkForCorner(n_pos - p, w_pos - p)) flag |= IS_CORNER;
                if (is_isolated_pixel(cx - 1, cy - 1)) p = vec2(float(cx), float(cy));
            }
            int d_prev = has_n ? 0 : -1;
            int d_next = has_w ? 3 : -1;
            cp = CPData(p, prev, next, flag, d_prev, d_next);
        } else {
            bool has_s = bnd_s, has_e = bnd_e;
            if (!(has_s || has_e)) return cp;
            vec2 p = vec2(float(cx) + 0.25, float(cy) + 0.25);
            int prev = has_s ? nbr_cp_idx(cx, cy + 1, 2) : -1;
            int next = has_e ? nbr_cp_idx(cx + 1, cy, 1) : -1;
            bool junction = !(has_s && has_e);
            uint flag = junction ? 1u : 2u;
            if (!junction) {
                vec2 s_pos = neighbor_cp_pos(cx, cy + 1, 2);
                vec2 e_pos = neighbor_cp_pos(cx + 1, cy, 1);
                if (checkForCorner(s_pos - p, e_pos - p)) flag |= IS_CORNER;
                if (is_isolated_pixel(cx, cy)) p = vec2(float(cx), float(cy));
            }
            int d_prev = has_s ? 2 : -1;
            int d_next = has_e ? 1 : -1;
            cp = CPData(p, prev, next, flag, d_prev, d_next);
        }
        return cp;
    }

    // bnd_count ∈ {1, 2, 3, 4}, on-grid positions.
    // bnd_count < 3: only slot 0 is produced.
    if (bnd_count < 3u && slot != 0) return cp;

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
        cp = CPData(pos, prev, next, f, p_dir, n_dir);
    } else if (bnd_count == 1u) {
        int nbr = -1; int nbr_dir = -1;
        if (bnd_n) { nbr = n_idx; nbr_dir = 0; }
        else if (bnd_e) { nbr = e_idx; nbr_dir = 1; }
        else if (bnd_s) { nbr = s_idx; nbr_dir = 2; }
        else { nbr = w_idx; nbr_dir = 3; }
        cp = CPData(pos, nbr, -1, 1u, nbr_dir, -1);
    } else if (bnd_count == 3u) {
        // T-junction: slot 0 is the through-CP, slot 1 is the stem.
        int dirs[3]; int di = 0;
        if (bnd_n) dirs[di++] = 0;
        if (bnd_e) dirs[di++] = 1;
        if (bnd_s) dirs[di++] = 2;
        if (bnd_w) dirs[di++] = 3;
        ivec2 t_pair = select_tjunction_pair(cx, cy, dirs[0], dirs[1], dirs[2]);
        int t_prev_dir = t_pair.x;
        int t_next_dir = t_pair.y;
        int idx_arr[4] = int[4](n_idx, e_idx, s_idx, w_idx);
        int prev = idx_arr[t_prev_dir];
        int next = idx_arr[t_next_dir];
        // Both slots stay at the grid corner. The stem CP is snapped onto
        // the rendered through-curve later in update-tjunction.slang using
        // ghost-aware (sp, st, sn) coefficients; pre-snapping here with
        // fixed weights would mis-bias the optimizer's positional energy
        // when prev/next is an endpoint.
        if (slot == 0) {
            cp = CPData(pos, prev, next, 2u | IS_TJUNCTION, t_prev_dir, t_next_dir);
        } else {
            int stem_idx = -1; int stem_dir = -1;
            if (bnd_n && t_prev_dir != 0 && t_next_dir != 0) { stem_idx = n_idx; stem_dir = 0; }
            else if (bnd_e && t_prev_dir != 1 && t_next_dir != 1) { stem_idx = e_idx; stem_dir = 1; }
            else if (bnd_s && t_prev_dir != 2 && t_next_dir != 2) { stem_idx = s_idx; stem_dir = 2; }
            else if (bnd_w && t_prev_dir != 3 && t_next_dir != 3) { stem_idx = w_idx; stem_dir = 3; }
            if (stem_idx >= 0) {
                cp = CPData(pos, stem_idx, -1, 1u, stem_dir, -1);
            }
        }
    } else {
        // bnd_count == 4: crossing.
        if (slot == 0) cp = CPData(pos, n_idx, s_idx, 2u | IS_CROSSING, 0, 2);
        else           cp = CPData(pos, e_idx, w_idx, 2u | IS_CROSSING, 1, 3);
    }
    return cp;
}

// Pack a single CP into the 4-channel compact format. -1 indices map
// to the 24-bit sentinel 0xFFFFFFu.
vec4 pack_cp(CPData cp) {
    if (cp.flag == 0u) {
        return vec4(
            0.0,
            0.0,
            uintBitsToFloat(0x00FFFFFFu), // flag=0, prev=-1
            uintBitsToFloat(0x00FFFFFFu)  // dir_pack=0, next=-1
        );
    }

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

    // Row-interleaved slot layout: row = cy*2 + slot.
    int slot = row & 1;
    int cy   = row >> 1;

    if (cx >= CORNERS_W() || cy >= CORNERS_H()) {
        FragColor = vec4(0.0);
        return;
    }

    CPData cp = compute_corner(cx, cy, slot);
    FragColor = pack_cp(cp);
}
