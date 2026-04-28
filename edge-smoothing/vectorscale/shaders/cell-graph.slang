#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass 3: Build cell graph — positions, neighbors, flags, and boundary directions.
//
// Creates B-spline control points at grid corners from the resolved similarity
// graph. Edge colors are NOT stored here; the rasterizer computes them on-the-fly.
//
// Output texture: 3 rows per CP (edge colors computed by rasterizer on-the-fly).
//   For grid corner (cx, cy) and slot s (0 or 1):
//     Row (cy * 2 + s) * 3 + 0, Col cx:
//       R = pos.x, G = pos.y, B = float(flag), A = float(dir_pack)
//       dir_pack = (prev_dir+1) + (next_dir+1)*8
//     Row (cy * 2 + s) * 3 + 1, Col cx:
//       R = prev_cx, G = prev_cy, B = prev_slot, A = 0
//       (-1.0 sentinel for no neighbor)
//     Row (cy * 2 + s) * 3 + 2, Col cx:
//       R = next_cx, G = next_cy, B = next_slot, A = 0
//       (-1.0 sentinel for no neighbor)
//
// Reads from: ResolvedGraph (pass 2 output)

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

// Dimensions derived from input image at runtime.
int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }

const uint IS_CORNER = 16u;
const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING  = 64u;
// Chain endpoint (prev or next neighbor is -1). Set on active CPs only —
// inactive default-init slots have flag=0 and stay that way. The rasterizer
// and update_tjunction key off this bit to apply clamped-Bezier termination
// (curve ends exactly at the endpoint position) and mask the stem-snap test.
const uint IS_ENDPOINT  = 128u;

// Read edge/diagonal flag from the resolved graph texture.
uint g(int gx, int gy) {
    if (gx < 0 || gy < 0 || gx >= IMG_W() * 2 || gy >= IMG_H() * 2)
        return 0u;
    vec4 val = texelFetch(Source, ivec2(gx, gy), 0);
    return uint(val.r + 0.5);
}

// Read pixel color from the graph (stored as normalized RGB at odd,odd coordinates).
// Returns packed 0xRRGGBB.
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

// Get the two pixel colors separated by a boundary edge at corner (cx,cy) in direction dir.
void bnd_colors(int cx, int cy, int dir, out uint ca, out uint cb) {
    if (dir == 0)      { ca = px_color(cx - 1, cy - 1); cb = px_color(cx, cy - 1); } // N
    else if (dir == 1) { ca = px_color(cx, cy - 1);      cb = px_color(cx, cy);     } // E
    else if (dir == 2) { ca = px_color(cx, cy);           cb = px_color(cx - 1, cy); } // S
    else               { ca = px_color(cx - 1, cy);       cb = px_color(cx - 1, cy - 1); } // W
}

// Classify an edge as shading (similar colors) per paper Section 3.3.
// YUV Euclidean distance <= 100/255.
bool is_shading_edge(uint ca, uint cb) {
    if (ca == cb) return true;
    float dr = float(int((ca >> 16u) & 0xFFu) - int((cb >> 16u) & 0xFFu));
    float dg = float(int((ca >> 8u) & 0xFFu) - int((cb >> 8u) & 0xFFu));
    float db = float(int(ca & 0xFFu) - int(cb & 0xFFu));
    float dy = (0.299 * dr + 0.587 * dg + 0.114 * db) / 255.0;
    float du = 0.493 * (db / 255.0 - dy);
    float dv = 0.877 * (dr / 255.0 - dy);
    float threshold = 100.0 / 255.0;
    return (dy * dy + du * du + dv * dv) <= threshold * threshold;
}

// Select the through-pair at a 3-way T-junction (paper Section 3.3).
// Returns the two through-pair directions in pair0/pair1.
void select_tjunction_pair(int cx, int cy, int d0, int d1, int d2,
                           out int pair0, out int pair1) {
    // Step 1: Shading/contour classification.
    uint ca0, cb0, ca1, cb1, ca2, cb2;
    bnd_colors(cx, cy, d0, ca0, cb0);
    bnd_colors(cx, cy, d1, ca1, cb1);
    bnd_colors(cx, cy, d2, ca2, cb2);
    bool s0 = is_shading_edge(ca0, cb0);
    bool s1 = is_shading_edge(ca1, cb1);
    bool s2 = is_shading_edge(ca2, cb2);
    int shading_count = (s0 ? 1 : 0) + (s1 ? 1 : 0) + (s2 ? 1 : 0);

    if (shading_count == 1) {
        // 1 shading + 2 contour: connect the 2 contour edges.
        if (s0) { pair0 = d1; pair1 = d2; }
        else if (s1) { pair0 = d0; pair1 = d2; }
        else { pair0 = d0; pair1 = d1; }
        return;
    }

    // Step 2: Angle-based fallback — connect the pair closest to 180 degrees.
    // At grid corners, opposite pairs (N-S=0^2, E-W=1^3) are 180 degrees;
    // all other pairs are 90 degrees. With 3 of 4 cardinal directions,
    // there is always exactly one opposite pair.
    if ((d0 ^ d2) == 2) { pair0 = d0; pair1 = d2; }
    else if ((d0 ^ d1) == 2) { pair0 = d0; pair1 = d1; }
    else { pair0 = d1; pair1 = d2; }
}

// Check if two adjacent pixels are similar using the graph.
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

// Get the correct CP index at a neighbor corner, accounting for diagonal splits.
int nbr_cp_idx(int cx, int cy, int from_dir) {
    int base = cp_base(cx, cy);
    if (base < 0) return -1;

    if (cx <= 0 || cy <= 0 || cx >= IMG_W() || cy >= IMG_H())
        return base;

    uint diag = g(2 * cx, 2 * cy);
    bool is_ullr = (diag & 1u) != 0u && (diag & 2u) == 0u;
    bool is_llur = (diag & 2u) != 0u && (diag & 1u) == 0u;

    if (!is_ullr && !is_llur) {
        // No resolved diagonal: check for 3/4-way junction needing slot routing.
        // Slot 0 = main pair, slot 1 = stem (3-way) or second pair (4-way).
        bool t_bnd_n = g(2 * cx, 2 * cy - 1) == 0u;
        bool t_bnd_e = g(2 * cx + 1, 2 * cy) == 0u;
        bool t_bnd_s = g(2 * cx, 2 * cy + 1) == 0u;
        bool t_bnd_w = g(2 * cx - 1, 2 * cy) == 0u;
        uint t_count = (t_bnd_n ? 1u : 0u) + (t_bnd_e ? 1u : 0u)
                     + (t_bnd_s ? 1u : 0u) + (t_bnd_w ? 1u : 0u);
        if (t_count == 4u) {
            // Valence-4 crossing: slot 0 = N-S, slot 1 = E-W
            int target_side = from_dir ^ 2;
            if (target_side != 0 && target_side != 2) return base + 1;
        } else if (t_count == 3u) {
            // Collect the 3 boundary directions and select through-pair
            // using paper's shading/contour + angle heuristic.
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

// Compute the actual CP position at a neighbor grid corner.
vec2 neighbor_cp_pos(int cx, int cy, int from_dir) {
    vec2 base_pos = vec2(float(cx), float(cy));

    if (cx <= 0 || cy <= 0 || cx >= IMG_W() || cy >= IMG_H())
        return base_pos;

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

// Corner detection: checks if angle between two edge vectors matches
// known sharp-turn angles. Ranges detect ~90° (dp≈0), ~135° (dp≈-0.707),
// and ~109° (dp≈-0.316) with ~1° tolerance.
bool checkForCorner(vec2 v1, vec2 v2) {
    float len1 = length(v1);
    float len2 = length(v2);
    if (len1 < 1e-6 || len2 < 1e-6) return false;
    float dp = dot(v1, v2) / (len1 * len2);
    if (dp > -0.01 && dp < 0.01) return true;   // ~90°
    if (dp > -0.72 && dp < -0.69) return true;   // ~135°
    if (dp > -0.33 && dp < -0.30) return true;   // ~109°
    return false;
}

// Encode a CP index as (cx, cy, slot) components.
vec3 encode_cp_idx(int cp_idx) {
    if (cp_idx < 0) return vec3(-1.0);
    int cp_half = cp_idx / 2;
    int cp_slot = cp_idx & 1;
    int ncx = cp_half % CORNERS_W();
    int ncy = cp_half / CORNERS_W();
    return vec3(float(ncx), float(ncy), float(cp_slot));
}

// Combined CP data: geometry + metadata.
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

// Compute both CPs for a given grid corner (cx, cy).
void compute_corner(int cx, int cy, out CPData slot0, out CPData slot1) {
    slot0 = make_inactive();
    slot1 = make_inactive();

    int base = cp_base(cx, cy);
    if (base < 0) return;

    bool is_interior = cx > 0 && cy > 0 && cx < IMG_W() && cy < IMG_H();

    if (!is_interior) {
        // Border CPs: pinned, connected back to interior neighbor via
        // nbr_cp_idx (graph-only, no race). from_dir = direction at
        // the border corner (not the interior corner).
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

    // Interior corner
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

    // Handle diagonal crossings: split into 2 CPs
    if (has_main && !has_anti) {
        // Backslash: CP0=SW, CP1=NE
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
            }
            int d_prev = cp1_has_n ? 0 : -1;
            int d_next = cp1_has_e ? 1 : -1;
            slot1 = CPData(p1, prev1, next1, cp1_flag, d_prev, d_next);
        }
        return;
    }

    if (has_anti && !has_main) {
        // Slash: CP0=NW, CP1=SE
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
            }
            int d_prev = cp1_has_s ? 2 : -1;
            int d_next = cp1_has_e ? 1 : -1;
            slot1 = CPData(p1, prev1, next1, cp1_flag, d_prev, d_next);
        }
        return;
    }

    // No diagonal (or both kept): single CP at slot 0
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
        // Paper Section 3.3: select through-pair via shading/contour + angle heuristic.
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

        // T-junction position correction approximation
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

        // Stem CP at slot 1 for the dropped direction
        int stem_idx = -1; int stem_dir = -1;
        if (bnd_n && t_prev_dir != 0 && t_next_dir != 0) { stem_idx = n_idx; stem_dir = 0; }
        else if (bnd_e && t_prev_dir != 1 && t_next_dir != 1) { stem_idx = e_idx; stem_dir = 1; }
        else if (bnd_s && t_prev_dir != 2 && t_next_dir != 2) { stem_idx = s_idx; stem_dir = 2; }
        else if (bnd_w && t_prev_dir != 3 && t_next_dir != 3) { stem_idx = w_idx; stem_dir = 3; }
        if (stem_idx >= 0) {
            slot1 = CPData(pos, stem_idx, -1, 1u, stem_dir, -1);
        }

    } else {
        // Valence 4 cross-junction: inverse-correct both CPs so their
        // B-spline curves pass through the grid corner at t=0.5.
        // IS_CROSSING: inverse correction in update_tjunction, combined
        // curvature optimization in optimize_energy.
        slot0 = CPData(pos, n_idx, s_idx, 2u | IS_CROSSING, 0, 2);
        slot1 = CPData(pos, e_idx, w_idx, 2u | IS_CROSSING, 1, 3);
    }
}

// Output: 3 rows per CP (packed layout, edge colors computed by rasterizer).
// Row 0: pos.x, pos.y, float(flag), float(dir_pack)
//   dir_pack = (prev_dir+1) + (next_dir+1)*8
// Row 1: prev_cx, prev_cy, prev_slot, 0 (or -1.0 sentinel)
// Row 2: next_cx, next_cy, next_slot, 0 (or -1.0 sentinel)

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);
    int col = opos.x; // cx
    int row = opos.y;

    if (col >= CORNERS_W() || row >= CORNERS_H() * 2 * 3) {
        FragColor = vec4(0.0);
        return;
    }

    // Decode which CP and sub-row this pixel represents
    // row = (cy * 2 + slot) * 3 + sub_row
    int cy_slot = row / 3;
    int sub_row = row % 3;
    int cy = cy_slot / 2;
    int slot = cy_slot % 2;
    int cx = col;

    if (cx > IMG_W() || cy > IMG_H()) {
        FragColor = vec4(0.0);
        return;
    }

    // Compute both slots for this corner
    CPData s0, s1;
    compute_corner(cx, cy, s0, s1);

    CPData cp = (slot == 0) ? s0 : s1;

    // Mark active chain endpoints so the rasterizer knows to apply clamped
    // Bezier termination at adjacent spans. Gated on flag != 0 so that
    // default-init inactive slots stay at flag=0.
    if (cp.flag != 0u && (cp.prev < 0 || cp.next < 0)) cp.flag |= IS_ENDPOINT;

    if (cp.flag == 0u) {
        // Inactive CP: sentinels for all sub-rows
        if (sub_row == 0) {
            FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        } else {
            FragColor = vec4(-1.0, -1.0, -1.0, 0.0);
        }
        return;
    }

    if (sub_row == 0) {
        // Position + flags + packed directions
        float dir_pack = float((cp.prev_dir + 1) + (cp.next_dir + 1) * 8);
        FragColor = vec4(cp.pos.x, cp.pos.y, float(cp.flag), dir_pack);
    } else if (sub_row == 1) {
        // Previous neighbor encoded as (cx, cy, slot)
        vec3 prev_enc = encode_cp_idx(cp.prev);
        FragColor = vec4(prev_enc, 0.0);
    } else {
        // Next neighbor encoded as (cx, cy, slot)
        vec3 next_enc = encode_cp_idx(cp.next);
        FragColor = vec4(next_enc, 0.0);
    }
}
