#version 450

// Cell rasterizer — renders optimized B-spline curves at viewport scale.
//
// For each output pixel, walks the cell's 4 corners (with a T-junction
// stem fan-out for stems pointing outside the 4-corner walk), finds the
// nearest B-spline boundary via the closed-form cubic solver, resolves
// color from edge data, and applies analytical anti-aliasing along
// boundary edges (single-curve / wedge / dual-curve paths).
//
// Multi-hit resolution: top-3 nearest CPs with endpoint-defer rejection.
//
// Input textures:
//   PackedPositions: per-CP denormalized geometry (pp, cp, np with ghosts
//                    pre-applied + t_branch + neighbor indices + is_line)
//                    written by pack-positions.slang.
//   CellGraph: original positions + neighbors + flags + packed directions
//              (resolve_hit still uses neighbors for color resolution).
//   Original: input pixel art image
//
// Output: viewport-sized final image

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

layout(set = 0, binding = 2) uniform sampler2D PackedPositions; // pack-positions output: (pp, cp, np, t_branch, prev_ci, next_ci, validity, is_line) per CP across 3 horizontal texels
layout(set = 0, binding = 3) uniform sampler2D CellGraph;       // flags + directions (and neighbor indices, now redundant for test_one_cp)
layout(set = 0, binding = 4) uniform sampler2D Original;        // input pixel art image

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_W() * CORNERS_H() * 2; }

// Chain endpoint flag — see cell-graph.slang.
const uint IS_ENDPOINT = 128u;
const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING = 64u;

// ---- Texture reading helpers ----

void decode_cp(int cp_idx, out int cx, out int cy_slot) {
    int cp_half = cp_idx / 2;
    int cp_slot = cp_idx & 1;
    int cx_ = cp_half % CORNERS_W();
    int cy_ = cp_half / CORNERS_W();
    cx = cx_;
    cy_slot = cy_ * 2 + cp_slot;
}

// Read original position from cell graph texture (row 0, RG channels).
vec2 read_orig(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(-1e10);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 val = texelFetch(CellGraph, ivec2(cx, base_row), 0);
    return vec2(val.r, val.g);
}

// Per-CP packed render geometry from pack-positions. 3 horizontal texels:
//   col 0 = (pp.x, pp.y, prev_ci_or_-1, _)
//   col 1 = (cp.x, cp.y, t_branch, validity 0=skip 1=normal 2=2cp-chain)
//   col 2 = (np.x, np.y, next_ci_or_-1, _)
struct PackedCp {
    vec2 pp;
    vec2 cp;
    vec2 np;
    float t_branch;
    int prev_ci;
    int next_ci;
    bool is_line;
    bool valid;
};

PackedCp read_packed_cp(int cp_idx) {
    PackedCp r;
    r.valid = false;
    r.is_line = false;
    r.t_branch = 0.5;
    r.prev_ci = -1; r.next_ci = -1;
    r.pp = vec2(0.0); r.cp = vec2(0.0); r.np = vec2(0.0);

    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return r;
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);

    vec4 t1 = texelFetch(PackedPositions, ivec2(cx*3 + 1, cy_slot), 0);
    if (t1.a < 0.5) return r;  // pack-positions wrote skip/inactive

    vec4 t0 = texelFetch(PackedPositions, ivec2(cx*3,     cy_slot), 0);
    vec4 t2 = texelFetch(PackedPositions, ivec2(cx*3 + 2, cy_slot), 0);

    r.pp = t0.rg;
    r.cp = t1.rg;
    r.np = t2.rg;
    r.t_branch = t1.b;
    r.is_line = t1.a > 1.5;
    r.prev_ci = (t0.b < -0.5) ? -1 : int(t0.b + 0.5);
    r.next_ci = (t2.b < -0.5) ? -1 : int(t2.b + 0.5);
    r.valid = true;
    return r;
}

// Decode a neighbor CP index from component encoding.
int decode_neighbor(vec4 val) {
    if (val.r < -0.5) return -1;
    int ncx = int(val.r + 0.5);
    int ncy = int(val.g + 0.5);
    int nslot = int(val.b + 0.5);
    return (ncy * CORNERS_W() + ncx) * 2 + nslot;
}

// Read neighbors from cell graph texture (row offsets 1 and 2).
ivec2 read_neighbors(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return ivec2(-1, -1);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 prev_val = texelFetch(CellGraph, ivec2(cx, base_row + 1), 0);
    vec4 next_val = texelFetch(CellGraph, ivec2(cx, base_row + 2), 0);
    return ivec2(decode_neighbor(prev_val), decode_neighbor(next_val));
}

// Read flags from cell graph texture (row 0, B channel).
uint read_flags(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return 0u;
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 val = texelFetch(CellGraph, ivec2(cx, base_row), 0);
    return uint(val.b + 0.5);
}

// Read packed boundary directions from cell graph (row 0, A channel).
// Returns (prev_dir, next_dir) where -1 = none, 0=N, 1=E, 2=S, 3=W.
ivec2 read_dirs(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return ivec2(-1, -1);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 val = texelFetch(CellGraph, ivec2(cx, base_row), 0);
    int dir_pack = int(val.a + 0.5);
    int prev_dir = (dir_pack % 8) - 1;
    int next_dir = (dir_pack / 8) - 1;
    return ivec2(prev_dir, next_dir);
}

// Get the grid corner (icx, icy) for a CP index.
ivec2 cp_grid_corner(int cp_idx) {
    int cp_half = cp_idx / 2;
    return ivec2(cp_half % CORNERS_W(), cp_half / CORNERS_W());
}

// Read pixel color from original image as normalized RGB.
vec3 read_pixel(int px, int py) {
    px = clamp(px, 0, IMG_W() - 1);
    py = clamp(py, 0, IMG_H() - 1);
    vec4 c = texelFetch(Original, ivec2(px, py), 0);
    return c.rgb;
}

// Compute edge colors for a boundary direction at grid corner (icx, icy).
void get_edge_colors(int icx, int icy, int dir, out vec3 color_left, out vec3 color_right) {
    switch (dir) {
        case 0: // N
            color_left  = read_pixel(icx - 1, icy - 1);
            color_right = read_pixel(icx,     icy - 1);
            break;
        case 1: // E
            color_left  = read_pixel(icx,     icy - 1);
            color_right = read_pixel(icx,     icy);
            break;
        case 2: // S
            color_left  = read_pixel(icx,     icy);
            color_right = read_pixel(icx - 1, icy);
            break;
        case 3: // W
            color_left  = read_pixel(icx - 1, icy);
            color_right = read_pixel(icx - 1, icy - 1);
            break;
        default:
            color_left = vec3(0.0); color_right = vec3(0.0);
            break;
    }
}

// ---- B-spline evaluation ----

vec2 beval(vec2 p0, vec2 p1, vec2 p2, float t) {
    float u = 1.0 - t;
    return 0.5 * u * u * p0 + (u * t + 0.5) * p1 + 0.5 * t * t * p2;
}

vec2 beval_deriv(vec2 p0, vec2 p1, vec2 p2, float t) {
    return (t - 1.0) * p0 + (1.0 - 2.0 * t) * p1 + t * p2;
}

// ---- Per-hit data carried from scan into resolve / wedge AA ----
//
// prev_pos / next_pos may be *ghost* positions (2*real - cp) when the
// corresponding neighbor carries IS_ENDPOINT — the ghost makes B(t=0|1) of
// the same polynomial form land exactly on the real endpoint position,
// giving a clamped Bezier without changing the eval API.
struct Hit {
    float d2;
    float t;
    int cp_idx;
    int prev_ci;
    int next_ci;
    vec2 cp_pos;
    vec2 prev_pos;
    vec2 next_pos;
    float t_branch;
    bool is_line;  // 2-CP chain (degenerate stem, both ends endpoint markers)
};

// ---- Linear approximation of a curve at a hit's closest_t ----
//
// Tangent line used by the wedge AA partition (cpt = junction J), and
// by the dual-curve AA path (cpt = closest point on the curve).
struct AaLine {
    vec2 cpt;
    vec2 normal;       // Unit normal. Side test: dot(p - cpt, normal).
    bool valid;
};

// ---- Closest point on a line segment (closed-form) ----
//
// Used for 2-CP-chain spans (degenerate stems with both ends being endpoint
// markers — geometrically a straight line). Calling closest_on_span with the
// straight-line construction p0=(3·a0-a1)/2, p1=midpoint, p2=(3·a1-a0)/2
// would leave ~1e-6 of float noise in the t² coefficient, making c3 ≈ 4e-12
// and pushing the cubic solver into its numerically-unstable regime. The
// closed form below sidesteps the cubic entirely.
vec2 closest_on_segment(vec2 a0, vec2 a1, vec2 pt) {
    vec2 v = a1 - a0;
    float vv = dot(v, v);
    float t = (vv > 0.0) ? clamp(dot(pt - a0, v) / vv, 0.0, 1.0) : 0.0;
    vec2 closest = a0 + t * v;
    vec2 d = pt - closest;
    return vec2(t, dot(d, d));
}

// ---- Closest point on B-spline span (exact cubic solver) ----
//
// D(t) = |B(t)-pt|² is degree 4, D'(t) is cubic → closed-form roots.
// Evaluates D at all real roots in [0,1] + endpoints, returns global min.

vec2 closest_on_span(vec2 p0, vec2 p1, vec2 p2, vec2 pt) {
    // Polynomial form: B(t) = a*t² + b*t + c
    vec2 a = 0.5 * (p0 - 2.0 * p1 + p2);
    vec2 b = p1 - p0;
    vec2 e = 0.5 * (p0 + p1) - pt;  // c - pt

    // D'(t)/2 cubic coefficients
    float c3 = 2.0 * dot(a, a);
    float c2 = 3.0 * dot(a, b);
    float c1 = 2.0 * dot(a, e) + dot(b, b);
    float c0 = dot(b, e);

    #define EVAL_D2(t) dot((a*(t)+b)*(t)+e, (a*(t)+b)*(t)+e)

    // Start with endpoints
    float d0 = EVAL_D2(0.0);
    float d1 = EVAL_D2(1.0);
    float best_d2 = d0; float best_t = 0.0;
    if (d1 < best_d2) { best_d2 = d1; best_t = 1.0; }

    if (abs(c3) < 1e-12) {
        // Degenerate: quadratic or linear
        if (abs(c2) > 1e-12) {
            // Numerically stable quadratic root formula (Numerical Recipes 5.6):
            // q = -0.5*(c1 + sgn(c1)*sqrt(disc)); roots: q/c2, c0/q.
            // Avoids catastrophic cancellation when c2 is small and the
            // (-c1 ± sqrt(disc)) form subtracts two near-equal numbers.
            float disc = c1*c1 - 4.0*c2*c0;
            if (disc >= 0.0) {
                float sq = sqrt(disc);
                float qq = -0.5 * (c1 + sign(c1) * sq);
                float t1 = qq / c2;
                float t2 = c0 / qq;
                if (t1 > 0.0 && t1 < 1.0) { float dd = EVAL_D2(t1); if (dd < best_d2) { best_d2 = dd; best_t = t1; } }
                if (t2 > 0.0 && t2 < 1.0) { float dd = EVAL_D2(t2); if (dd < best_d2) { best_d2 = dd; best_t = t2; } }
            }
        } else if (abs(c1) > 1e-12) {
            float t1 = -c0 / c1;
            if (t1 > 0.0 && t1 < 1.0) { float dd = EVAL_D2(t1); if (dd < best_d2) { best_d2 = dd; best_t = t1; } }
        }
    } else {
        // Full cubic: depressed form via t = u - c2/(3·c3)
        float inv3a = 1.0 / (3.0 * c3);
        float shift = -c2 * inv3a;
        float p = (3.0*c3*c1 - c2*c2) / (3.0*c3*c3);
        float q = (2.0*c2*c2*c2 - 9.0*c3*c2*c1 + 27.0*c3*c3*c0) / (27.0*c3*c3*c3);
        float disc = q*q/4.0 + p*p*p/27.0;

        if (disc > 1e-12) {
            // One real root
            float sq = sqrt(disc);
            float hq = -q * 0.5;
            float u1 = sign(hq+sq) * pow(abs(hq+sq), 1.0/3.0);
            float u2 = sign(hq-sq) * pow(abs(hq-sq), 1.0/3.0);
            float t1 = u1 + u2 + shift;
            if (t1 > 0.0 && t1 < 1.0) { float dd = EVAL_D2(t1); if (dd < best_d2) { best_d2 = dd; best_t = t1; } }
        } else {
            // Three real roots (trigonometric)
            float r = sqrt(max(-p*p*p/27.0, 0.0));
            float phi = (r < 1e-15) ? 0.0 : acos(clamp(-q/(2.0*r), -1.0, 1.0));
            float cube_r = 2.0 * sign(r) * pow(abs(r), 1.0/3.0);
            const float TAU = 6.283185307;
            for (int k = 0; k < 3; k++) {
                float angle = (phi + TAU * float(k)) / 3.0;
                float t1 = cube_r * cos(angle) + shift;
                if (t1 > 0.0 && t1 < 1.0) { float dd = EVAL_D2(t1); if (dd < best_d2) { best_d2 = dd; best_t = t1; } }
            }
        }
    }

    #undef EVAL_D2
    return vec2(best_t, best_d2);
}

// ---- sRGB ↔ linear conversion (gamma 2.2 approximation) ----
vec3 srgb_to_linear(vec3 c) { return pow(c, vec3(2.2)); }
vec3 linear_to_srgb(vec3 c) { return pow(c, vec3(1.0 / 2.2)); }

// ---- Single-line pixel coverage (closed-form) ----
//
// Exact coverage of a pixel by a tangent line. d_p is the line's signed
// perpendicular distance from pixel center in pixel-side units. Returns
// the area on the line's positive side, in [0, 1].
//   |d_p| <= (a-b)/2     → linear regime (line crosses parallel edges)
//   (a-b)/2 < |d_p| < (a+b)/2 → corner-cut quadratic
//   |d_p| >= (a+b)/2     → saturated
float line_coverage_pos(vec2 normal, float d_p) {
    float nx = abs(normal.x);
    float ny = abs(normal.y);
    float a = max(nx, ny);
    float b = min(nx, ny);
    float half_ext = (a + b) * 0.5;
    float lin_ext = (a - b) * 0.5;
    if (d_p >= half_ext) return 1.0;
    if (d_p <= -half_ext) return 0.0;
    if (abs(d_p) <= lin_ext) return 0.5 + d_p / a;
    if (d_p > 0.0) {
        float t = half_ext - d_p;
        return 1.0 - 0.5 * t * t / (a * b);
    }
    float t = half_ext + d_p;
    return 0.5 * t * t / (a * b);
}

// ---- Structural junction detection ----
//
// Returns the t value on sc_b's curve (in {0.0, 1.0}) at which it
// passes through the junction at sc_a's corner, or -1.0 if sc_b isn't
// the stem-side curve. Caller pre-filters on (flags(ci_a) & IS_TJUNCTION).
//   case (a): sc_b IS slot 1 of sc_a's corner — 2-CP chain stem, t=1.0.
//   case (b): sc_b is slot 1's neighbor — t=0.0 if its prev_ci is
//             IS_ENDPOINT, t=1.0 if its next_ci is.
//   else: -1 (no match).
float slot1_t_case(int ci_a, int ci_b) {
    int slot1_ci_a = (ci_a / 2) * 2 + 1;
    if (ci_b == slot1_ci_a) return 1.0;  // case (a)
    ivec2 slot1_n = read_neighbors(slot1_ci_a);
    if (slot1_n.x != ci_b && slot1_n.y != ci_b) return -1.0;
    ivec2 nb = read_neighbors(ci_b);
    if (nb.x >= 0 && (read_flags(nb.x) & IS_ENDPOINT) != 0u) return 0.0;
    if (nb.y >= 0 && (read_flags(nb.y) & IS_ENDPOINT) != 0u) return 1.0;
    return -1.0;
}

// ---- Junction-anchored AA-line builder ----
//
// Builds a tangent-line classifier with cpt = J (junction position), and
// tangent evaluated at `t_eval` on the curve. Used by wedge AA so both
// line_a and line_b literally pass through J. Returns the unit tangent
// alongside the line so caller can align line_b's normal to line_a's
// tangent direction (so sb > 0 = post-junction along line_a).
AaLine build_junction_aa_line(Hit hit, vec2 J, float t_eval, out vec2 out_tang_unit) {
    AaLine result;
    result.cpt = J;
    result.normal = vec2(0.0);
    result.valid = false;
    out_tang_unit = vec2(0.0);

    vec2 tang = beval_deriv(hit.prev_pos, hit.cp_pos, hit.next_pos, t_eval);
    float tl = length(tang);
    if (tl < 1e-4) return result;
    vec2 tu = tang / tl;
    out_tang_unit = tu;

    ivec2 grid = cp_grid_corner(hit.cp_idx);
    ivec2 dirs = read_dirs(hit.cp_idx);
    bool prev_split = false, next_split = false;
    if (dirs.x >= 0) {
        vec3 pl, pr;
        get_edge_colors(grid.x, grid.y, dirs.x, pl, pr);
        prev_split = any(notEqual(pl, pr));
    }
    if (dirs.y >= 0) {
        vec3 nl, nr;
        get_edge_colors(grid.x, grid.y, dirs.y, nl, nr);
        next_split = any(notEqual(nl, nr));
    }
    if (!prev_split && !next_split) return result;

    result.normal = vec2(-tu.y, tu.x);
    result.valid = true;
    return result;
}

// ---- ResolveResult: solid color + AA components from one hit ----
struct ResolveResult {
    vec3 solid_color;
    vec3 pos_side;
    vec3 neg_side;
    vec2 opt_normal;
    float d;
    bool resolved;
};

// Test one CP and (if it passes) insert into the top-3 hits array.
// Returns the tested CP's flag bits (0u for inactive), so the caller
// can gate follow-up work like the T-junction stem fan-out without
// re-fetching CellGraph row 0.
uint test_one_cp(int ci, vec2 query, inout Hit hits[3], inout int num_hits) {
    if (ci < 0 || ci >= NUM_CPS()) return 0u;

    uint flag = read_flags(ci);
    if (flag == 0u) return 0u;

    // Per-CP geometry — denormalized by pack-positions. Replaces the
    // read_neighbors + 3 read_pos chain + ghost-extension dance with 3
    // texel reads. valid=false means pack-positions wrote skip
    // (inactive, isolated, or non-owner of a 2-CP chain).
    PackedCp pcp = read_packed_cp(ci);
    if (!pcp.valid) return flag;

    vec2 pp = pcp.pp;
    vec2 cp = pcp.cp;
    vec2 np = pcp.np;

    // Quick screen: 3-sample distance² reject. Evaluating beval at
    // t=0, 1/2, 1 with the ghost-extended pp/cp/np gives the real
    // curve start, midpoint-ish, end. > 2.0 means the curve can't
    // possibly come within 1 source unit of the fragment.
    vec2 b0 = 0.5 * (pp + cp);
    vec2 bm = 0.125 * pp + 0.75 * cp + 0.125 * np;
    vec2 b1 = 0.5 * (cp + np);
    vec2 dq0 = query - b0;
    vec2 dqm = query - bm;
    vec2 dq1 = query - b1;
    float quick_d2 = min(min(dot(dq0, dq0), dot(dqm, dqm)), dot(dq1, dq1));
    if (quick_d2 > 2.0) return flag;

    vec2 result;
    if (pcp.is_line) {
        vec2 a0 = 0.5 * (pp + cp);
        vec2 a1 = 0.5 * (cp + np);
        result = closest_on_segment(a0, a1, query);
    } else {
        result = closest_on_span(pp, cp, np, query);
    }
    float span_t = result.x;
    float span_d2 = result.y;
    if (span_d2 >= 1.0) return flag;

    // Build candidate Hit and insert via explicit if/else over constant
    // indices — keeps hits[] register-allocated.
    Hit cand;
    cand.d2 = span_d2; cand.t = span_t; cand.cp_idx = ci;
    cand.prev_ci = pcp.prev_ci; cand.next_ci = pcp.next_ci;
    cand.cp_pos = cp; cand.prev_pos = pp; cand.next_pos = np;
    cand.t_branch = pcp.t_branch; cand.is_line = pcp.is_line;

    if (span_d2 < hits[0].d2) {
        hits[2] = hits[1];
        hits[1] = hits[0];
        hits[0] = cand;
        if (num_hits < 3) num_hits++;
    } else if (span_d2 < hits[1].d2) {
        hits[2] = hits[1];
        hits[1] = cand;
        if (num_hits < 3) num_hits++;
    } else if (span_d2 < hits[2].d2) {
        hits[2] = cand;
        if (num_hits < 3) num_hits++;
    }
    return flag;
}

int find_hits(vec2 query, out Hit hits[3]) {
    int num_hits = 0;
    // Init via constant indices — keeps hits[] in registers vs spilling
    // to local memory (dynamic-indexed loop would force the latter on
    // most GPU compilers).
    hits[0].d2 = 1e10; hits[0].t = 0.0; hits[0].cp_idx = -1;
    hits[0].prev_ci = -1; hits[0].next_ci = -1;
    hits[0].cp_pos = vec2(0.0); hits[0].prev_pos = vec2(0.0); hits[0].next_pos = vec2(0.0);
    hits[0].t_branch = 0.5; hits[0].is_line = false;
    hits[1].d2 = 1e10; hits[1].t = 0.0; hits[1].cp_idx = -1;
    hits[1].prev_ci = -1; hits[1].next_ci = -1;
    hits[1].cp_pos = vec2(0.0); hits[1].prev_pos = vec2(0.0); hits[1].next_pos = vec2(0.0);
    hits[1].t_branch = 0.5; hits[1].is_line = false;
    hits[2].d2 = 1e10; hits[2].t = 0.0; hits[2].cp_idx = -1;
    hits[2].prev_ci = -1; hits[2].next_ci = -1;
    hits[2].cp_pos = vec2(0.0); hits[2].prev_pos = vec2(0.0); hits[2].next_pos = vec2(0.0);
    hits[2].t_branch = 0.5; hits[2].is_line = false;

    int cell_cx = int(floor(query.x));
    int cell_cy = int(floor(query.y));
    if (cell_cx < 0 || cell_cy < 0 || cell_cx >= IMG_W() || cell_cy >= IMG_H()) {
        return num_hits;
    }

    // Walk the cell's 4 corners, both slots each. A quadratic B-spline
    // bows ≤0.5 units from chord, so a span centered at a corner extends
    // at most 0.5 units beyond — only spans centered at the cell's own
    // 4 corners can geometrically overlap the cell's interior.
    const ivec2 corner_offsets[4] = ivec2[4](
        ivec2(0, 0),  // SW
        ivec2(1, 0),  // SE
        ivec2(0, 1),  // NW
        ivec2(1, 1)   // NE
    );

    for (int oi = 0; oi < 4; oi++) {
        int cx = cell_cx + corner_offsets[oi].x;
        int cy = cell_cy + corner_offsets[oi].y;
        if (cx < 0 || cy < 0 || cx >= CORNERS_W() || cy >= CORNERS_H()) continue;
        int base = (cy * CORNERS_W() + cx) * 2;

        // Test slot 0 and slot 1 at this corner.
        uint slot0_flag = test_one_cp(base,     query, hits, num_hits);
        test_one_cp(base + 1, query, hits, num_hits);

        // T-junction stem fan-out: when slot 0 carries IS_TJUNCTION, the
        // stem-bottom CP can sit at offset (+2, +1) etc. — outside the
        // 4-cell-corner walk — so look it up via slot 1's chain neighbor
        // and test its span. Slot 1 itself is a stem CP filtered out by
        // test_one_cp's endpoint dedup; its chain link still points to
        // the renderable stem-bottom. Skipped when stem-bottom is already
        // one of the 4 cell corners we walk anyway.
        if ((slot0_flag & IS_TJUNCTION) != 0u) {
            ivec2 slot1_n = read_neighbors(base + 1);
            int sci = slot1_n.x >= 0 ? slot1_n.x : slot1_n.y;
            if (sci >= 0) {
                int s_cx = (sci / 2) % CORNERS_W();
                int s_cy = (sci / 2) / CORNERS_W();
                bool already_walked =
                    s_cx >= cell_cx && s_cx <= cell_cx + 1
                 && s_cy >= cell_cy && s_cy <= cell_cy + 1;
                if (!already_walked) test_one_cp(sci, query, hits, num_hits);
            }
        }
    }
    return num_hits;
}

// ---- Resolve solid color + AA components from one hit ----
//
// Returns resolved=false when this hit defers (endpoint at hit_t lands on
// co-located other CP, or no edge has a color discontinuity, or tangents
// degenerate). Out fields populated when resolved=true.
ResolveResult resolve_hit(Hit hit, vec2 query) {
    ResolveResult r;
    r.solid_color = vec3(0.0);
    r.pos_side = vec3(0.0); r.neg_side = vec3(0.0);
    r.opt_normal = vec2(0.0); r.d = 0.0;
    r.resolved = false;

    int ci = hit.cp_idx;
    int prev_ci = hit.prev_ci;
    int next_ci = hit.next_ci;
    float hit_t = hit.t;
    vec2 cp = hit.cp_pos;
    vec2 pp = hit.prev_pos;
    vec2 np = hit.next_pos;

    // Read row 0 of the cell graph for ci, prev, and next exactly once
    // each — it packs orig_pos (rg), flags (b), and dir_pack (a). The
    // helpers (read_orig / read_flags / read_dirs) all hit the same
    // texel; calling each separately costs 3 redundant texelFetches per
    // resolve. Inline the unpack here.
    int cx_ci, cy_slot_ci;       decode_cp(ci, cx_ci, cy_slot_ci);
    int row0_ci_y = cy_slot_ci * 3;
    vec4 row0_ci = texelFetch(CellGraph, ivec2(cx_ci, row0_ci_y), 0);

    vec4 row0_prev = vec4(0.0);
    if (prev_ci >= 0 && prev_ci < NUM_CPS()) {
        int cx_p, cy_slot_p; decode_cp(prev_ci, cx_p, cy_slot_p);
        row0_prev = texelFetch(CellGraph, ivec2(cx_p, cy_slot_p * 3), 0);
    }
    vec4 row0_next = vec4(0.0);
    if (next_ci >= 0 && next_ci < NUM_CPS()) {
        int cx_n, cy_slot_n; decode_cp(next_ci, cx_n, cy_slot_n);
        row0_next = texelFetch(CellGraph, ivec2(cx_n, cy_slot_n * 3), 0);
    }

    // Endpoint defer: hit at exact t=0|1 of an endpoint-extended curve
    // — defer to the next-closest hit. Use already-fetched row0 data
    // instead of separate read_flags calls.
    bool prev_is_endpoint = (prev_ci < 0)
        || (uint(row0_prev.b + 0.5) & IS_ENDPOINT) != 0u;
    bool next_is_endpoint = (next_ci < 0)
        || (uint(row0_next.b + 0.5) & IS_ENDPOINT) != 0u;
    if ((prev_is_endpoint && hit_t == 0.0) || (next_is_endpoint && hit_t == 1.0)) {
        return r;
    }

    int dir_pack_ci = int(row0_ci.a + 0.5);
    int prev_dir = (dir_pack_ci % 8) - 1;
    int next_dir = (dir_pack_ci / 8) - 1;
    ivec2 grid = ivec2((ci / 2) % CORNERS_W(), (ci / 2) / CORNERS_W());

    vec3 pl = vec3(0.0), pr = vec3(0.0), nl = vec3(0.0), nr = vec3(0.0);
    if (prev_dir >= 0) get_edge_colors(grid.x, grid.y, prev_dir, pl, pr);
    if (next_dir >= 0) get_edge_colors(grid.x, grid.y, next_dir, nl, nr);

    vec3 c_left, c_right;
    float ref_t;
    bool prev_valid = any(notEqual(pl, pr));
    bool next_valid = any(notEqual(nl, nr));

    if (prev_ci < 0) {
        if (!next_valid) return r;
        c_left = nr; c_right = nl; ref_t = 1.0;
    } else if (next_ci < 0) {
        if (!prev_valid) return r;
        c_left = pl; c_right = pr; ref_t = 0.0;
    } else if (hit_t < hit.t_branch) {
        if (prev_valid) { c_left = pl; c_right = pr; ref_t = 0.0; }
        else if (next_valid) { c_left = nr; c_right = nl; ref_t = 1.0; }
        else return r;
    } else {
        if (next_valid) { c_left = nr; c_right = nl; ref_t = 1.0; }
        else if (prev_valid) { c_left = pl; c_right = pr; ref_t = 0.0; }
        else return r;
    }

    vec2 orig_ci   = row0_ci.rg;
    vec2 orig_prev = (prev_ci >= 0) ? row0_prev.rg : orig_ci;
    vec2 orig_next = (next_ci >= 0) ? row0_next.rg : orig_ci;
    vec2 orig_cp, orig_pp, orig_np;
    if (hit.is_line) {
        // 2-CP chain: a0 is the prev-side endpoint, a1 is the next-side.
        // Whichever side is < 0, we use the CP's own orig as the marker.
        vec2 a0_orig = (prev_ci < 0) ? orig_ci : orig_prev;
        vec2 a1_orig = (next_ci < 0) ? orig_ci : orig_next;
        orig_pp = 1.5 * a0_orig - 0.5 * a1_orig;
        orig_cp = 0.5 * (a0_orig + a1_orig);
        orig_np = 1.5 * a1_orig - 0.5 * a0_orig;
    } else {
        orig_cp = orig_ci;
        orig_pp = orig_prev;
        orig_np = orig_next;
    }

    vec2 orig_tang = beval_deriv(orig_pp, orig_cp, orig_np, ref_t);
    float otl = length(orig_tang);
    if (otl < 1e-4) return r;
    vec2 orig_normal = vec2(-orig_tang.y, orig_tang.x) / otl;

    vec2 opt_tang = beval_deriv(pp, cp, np, hit_t);
    float opt_tl = length(opt_tang);
    if (opt_tl < 1e-4) return r;
    vec2 opt_normal = vec2(-opt_tang.y, opt_tang.x) / opt_tl;

    vec2 curve_pt = beval(pp, cp, np, hit_t);
    float d = dot(query - curve_pt, opt_normal);

    bool flip = dot(opt_normal, orig_normal) < 0.0;
    vec3 pos_side = flip ? c_right : c_left;
    vec3 neg_side = flip ? c_left : c_right;

    r.pos_side = pos_side;
    r.neg_side = neg_side;
    r.opt_normal = opt_normal;
    r.d = d;
    r.solid_color = (d > 0.0) ? pos_side : neg_side;
    r.resolved = true;
    return r;
}

// classify_at — solid color (no AA) for a wedge centroid query. Does its
// own scan + resolve at the query point.
vec3 classify_at(vec2 query, vec3 fallback) {
    Hit hits[3];
    int num_hits = find_hits(query, hits);
    if (num_hits >= 1) {
        ResolveResult r = resolve_hit(hits[0], query);
        if (r.resolved) return r.solid_color;
    }
    if (num_hits >= 2) {
        ResolveResult r = resolve_hit(hits[1], query);
        if (r.resolved) return r.solid_color;
    }
    if (num_hits >= 3) {
        ResolveResult r = resolve_hit(hits[2], query);
        if (r.resolved) return r.solid_color;
    }
    return fallback;
}

// ---- Main rasterizer ----

void main() {
    // Map output pixel to source coordinates via vTexCoord (MVP-transformed).
    float scale_x = params.OutputSize.x / float(IMG_W());
    float scale_y = params.OutputSize.y / float(IMG_H());
    float scale = min(scale_x, scale_y);
    float inv_scale = 1.0 / scale;

    vec2 center = vTexCoord * vec2(float(IMG_W()), float(IMG_H()));

    // Fallback: nearest pixel color (normalized RGB).
    int fb_x = clamp(int(floor(center.x)), 0, IMG_W() - 1);
    int fb_y = clamp(int(floor(center.y)), 0, IMG_H() - 1);
    vec3 fallback = read_pixel(fb_x, fb_y);

    // Scan + collect nearest 4 hits.
    Hit hits[3];
    int num_hits = find_hits(center, hits);

    // Resolve color from first hit that resolves. Save AA state from the
    // resolved hit for the AA paths below.
    vec3 center_color = fallback;
    int resolved_h = -1;
    ResolveResult res;
    res.solid_color = fallback;
    res.pos_side = vec3(0.0);
    res.neg_side = vec3(0.0);
    res.opt_normal = vec2(0.0);
    res.d = 0.0;
    res.resolved = false;
    if (num_hits >= 1 && resolved_h < 0) {
        ResolveResult rr = resolve_hit(hits[0], center);
        if (rr.resolved) { res = rr; center_color = rr.solid_color; resolved_h = 0; }
    }
    if (num_hits >= 2 && resolved_h < 0) {
        ResolveResult rr = resolve_hit(hits[1], center);
        if (rr.resolved) { res = rr; center_color = rr.solid_color; resolved_h = 1; }
    }
    if (num_hits >= 3 && resolved_h < 0) {
        ResolveResult rr = resolve_hit(hits[2], center);
        if (rr.resolved) { res = rr; center_color = rr.solid_color; resolved_h = 2; }
    }

    // AA threshold: a pixel's half-diagonal² in source units is
    // 0.5/scale². Beyond that, the curve passes outside the pixel and
    // the analytical pixel-coverage formula saturates to a solid color
    // anyway, so AA work would be wasted. The same tight bound applies
    // to single-curve AA and the wedge AA gate so each fires only on
    // pixels the curve(s) pass through.
    float aa_threshold = 0.5 / (scale * scale);

    // Multi-curve wedge AA fires only when the structural junction
    // relationship holds AND the geometric junction lies inside the pixel.
    //
    // At a T-junction corner, slot 0 holds the through curve and slot 1
    // holds the original stem CP. Slot 1's render span — when present — is
    // owned either by an adjacent chain CP (regular case: slot 1 filtered,
    // its surviving non-(-1) neighbor IS the stem render CP) or by slot 1
    // itself (2-CP-chain case: both stem endpoints are markers, slot 1
    // survives and renders as a straight-line span). Candidate A is the
    // through-curve at the junction iff
    //   (a) A is IS_TJUNCTION-flagged, AND
    //   (b) slot 1 at A's corner either equals B's ci (2-CP-chain) or
    //       has B's ci as one of its neighbors (regular).
    // Crossings (valence-4): both hits IS_CROSSING at the same corner.
    //
    // Junction-in-pixel: the through CP's pos (= junction location post-
    // correction) must lie inside the pixel square. When two curves graze
    // a pixel without their junction being in it (e.g. consecutive chain
    // CPs along a smooth diagonal), the local geometry is 2-color and
    // wedge AA's LUT mixes a third color that isn't actually present.
    // Multi-curve wedge AA fires only at a structural junction whose
    // geometric location lies inside the pixel.
    //
    // Structural cases (each pinned by how the cell graph constructs the
    // relevant CPs — no closest_t computation needed for line_b):
    //   (a) sc_b IS slot 1 of sc_a's corner — 2-CP-chain stem. Cell graph
    //       creates slot 1 with next_ci = -1, so the rasterizer's 2-CP
    //       construction puts a1 = slot1.pos = junction-side endpoint at
    //       t = 1.
    //   (b) sc_b is slot 1's surviving non-(-1) neighbor — slot 1 was
    //       filtered, sc_b is the chain CP at the dropped-boundary corner
    //       and ghost-extends through slot 1.pos at whichever of its
    //       prev/next neighbors is IS_ENDPOINT-flagged (t = 0 for prev,
    //       t = 1 for next).
    //   Crossings (valence-4): both hits IS_CROSSING at same corner; sc_b's
    //   curve passes through J at sc_b.t_branch.
    //
    // Junction-in-pixel: J = beval(sc_a, t_branch) — point on the rendered
    // curve at the junction parameter (NOT cp_pos, the polynomial control
    // point, which can differ for non-ghost-extended CPs). For multi-curve
    // pixels where curves graze without an in-pixel junction, fall back to
    // single-curve AA.
    bool wedge_handled = false;
    int through_h = -1;
    int stem_h = -1;
    float t_b_eval = 0.0;
    if (num_hits >= 2 && hits[0].cp_idx >= 0 && hits[1].cp_idx >= 0
        && hits[1].d2 < aa_threshold) {
        int ci0 = hits[0].cp_idx;
        int ci1 = hits[1].cp_idx;
        uint f0 = read_flags(ci0);
        uint f1 = read_flags(ci1);

        float cp0_t = ((f0 & IS_TJUNCTION) != 0u) ? slot1_t_case(ci0, ci1) : -1.0;
        float cp1_t = ((f1 & IS_TJUNCTION) != 0u) ? slot1_t_case(ci1, ci0) : -1.0;
        bool both_x_same =
            ((f0 & IS_CROSSING) != 0u)
            && ((f1 & IS_CROSSING) != 0u)
            && (ci0 / 2) == (ci1 / 2);
        if (cp0_t >= 0.0) {
            through_h = 0; stem_h = 1; t_b_eval = cp0_t;
        } else if (cp1_t >= 0.0) {
            through_h = 1; stem_h = 0; t_b_eval = cp1_t;
        } else if (both_x_same) {
            through_h = 0; stem_h = 1;
            t_b_eval = hits[1].t_branch;
        }

        // Junction-in-pixel.
        if (through_h >= 0) {
            // through_h ∈ {0, 1}; explicit selection avoids dynamic indexing.
            Hit th = (through_h == 0) ? hits[0] : hits[1];
            vec2 J = beval(th.prev_pos, th.cp_pos, th.next_pos, th.t_branch);
            float pix_half = inv_scale * 0.5;
            if (abs(J.x - center.x) > pix_half || abs(J.y - center.y) > pix_half) {
                through_h = -1;
                stem_h = -1;
            }
        }
    }
    // resolved_h ∈ {0, 1, 2}; pick d2 by explicit selection to keep
    // hits[] register-allocated (dynamic-indexed read would force spill).
    float resolved_d2 = (resolved_h == 0) ? hits[0].d2
                      : (resolved_h == 1) ? hits[1].d2
                      : (resolved_h == 2) ? hits[2].d2 : 1e10;
    bool need_wedge_aa = resolved_h >= 0 && resolved_d2 < aa_threshold
                        && through_h >= 0;
    if (need_wedge_aa) {
        // through_h, stem_h ∈ {0, 1}; explicit selection.
        Hit through_hit = (through_h == 0) ? hits[0] : hits[1];
        Hit stem_hit    = (stem_h    == 0) ? hits[0] : hits[1];

        // J = beval(through, t_branch). Both lines anchored at J.
        vec2 J = beval(through_hit.prev_pos, through_hit.cp_pos, through_hit.next_pos,
                        through_hit.t_branch);

        // line_a: through tangent at t_branch.
        vec2 tang_a_unit;
        AaLine line_a = build_junction_aa_line(through_hit, J, through_hit.t_branch, tang_a_unit);

        // line_b: stem tangent at the junction. t_b_eval was determined
        // structurally by the gate above (no closest_t needed).
        vec2 tang_b_unit;
        AaLine line_b = build_junction_aa_line(stem_hit, J, t_b_eval, tang_b_unit);

        // Align line_b.normal so sb > 0 = post-junction along line_a.
        if (line_b.valid && dot(line_b.normal, tang_a_unit) < 0.0) {
            line_b.normal = -line_b.normal;
        }

        if (line_a.valid && line_b.valid) {
            // Through-curve color LUT: at a T-junction the through curve
            // (= through_hit) carries all three colors via its two edge
            // segments split at t_branch — pre-junction edge gives the
            // (pos, neg) for t < t_branch, post-junction edge gives them
            // for t > t_branch.
            //
            // line_b's normal is aligned to line_a's tangent direction,
            // so sb > 0 = post-junction (seg 1) and sb < 0 = pre-junction
            // (seg 0). Maps (sa-sign, sb-sign) directly to LUT entries.

            // Resolve the through hit at center to get its pos/neg/normal.
            // If through_hit IS the already-resolved hit, reuse `res` to
            // skip a redundant resolve_hit call (~3 fewer CellGraph reads).
            ResolveResult through_res = (through_h == resolved_h)
                ? res
                : resolve_hit(through_hit, center);

            // Build pos/neg colors for each segment, aligned to line_a.normal
            // (so a single sidedness test against line_a applies to both
            // segments). One segment is covered by through_res at the
            // pixel center; resolve the other at the OTHER segment's mid.
            // For 2-CP chains both halves are identical so we skip the
            // second resolve.
            vec3 pos0 = fallback, neg0 = fallback;
            vec3 pos1 = fallback, neg1 = fallback;

            bool flip_res = dot(through_res.opt_normal, line_a.normal) < 0.0;
            vec3 res_pos = flip_res ? through_res.neg_side : through_res.pos_side;
            vec3 res_neg = flip_res ? through_res.pos_side : through_res.neg_side;
            bool res_in_seg1 = through_hit.t >= through_hit.t_branch;
            if (through_res.resolved) {
                if (res_in_seg1) { pos1 = res_pos; neg1 = res_neg; }
                else             { pos0 = res_pos; neg0 = res_neg; }
            }

            if (!through_hit.is_line) {
                Hit other_seg = through_hit;
                other_seg.t = res_in_seg1
                    ? (through_hit.t_branch * 0.5)
                    : (0.5 * (through_hit.t_branch + 1.0));
                ResolveResult res_other = resolve_hit(other_seg, J);
                if (res_other.resolved) {
                    bool flip_o = dot(res_other.opt_normal, line_a.normal) < 0.0;
                    vec3 op = flip_o ? res_other.neg_side : res_other.pos_side;
                    vec3 on = flip_o ? res_other.pos_side : res_other.neg_side;
                    if (res_in_seg1) { pos0 = op; neg0 = on; }
                    else             { pos1 = op; neg1 = on; }
                } else if (through_res.resolved) {
                    if (res_in_seg1) { pos0 = res_pos; neg0 = res_neg; }
                    else             { pos1 = res_pos; neg1 = res_neg; }
                }
            } else if (through_res.resolved) {
                // Straight 2-CP chain: same colors throughout.
                pos0 = res_pos; neg0 = res_neg;
                pos1 = res_pos; neg1 = res_neg;
            }

            // LUT decoded once. Indexed by (sa>0) | ((sb>0) << 1):
            //   0 = neg0, 1 = pos0, 2 = neg1, 3 = pos1.
            vec3 lut_lin[4];
            lut_lin[0] = srgb_to_linear(neg0);
            lut_lin[1] = srgb_to_linear(pos0);
            lut_lin[2] = srgb_to_linear(neg1);
            lut_lin[3] = srgb_to_linear(pos1);

            // Boundary-sweep area accumulation. Walk the pixel boundary
            // CCW; on each edge find up to 2 line crossings (line_a and
            // line_b), split the edge into <=3 sub-segments, classify
            // each by (sa, sb)-sign at its midpoint, and add a signed-
            // triangle area (J as origin) to the matching wedge bucket.
            // J interior + consistent walk direction => |cross| gives the
            // wedge area directly. No polygon storage, no centroid pass.
            float pix_h = inv_scale * 0.5;
            vec2 corners[4];
            corners[0] = vec2(center.x - pix_h, center.y - pix_h);
            corners[1] = vec2(center.x + pix_h, center.y - pix_h);
            corners[2] = vec2(center.x + pix_h, center.y + pix_h);
            corners[3] = vec2(center.x - pix_h, center.y + pix_h);

            vec3 sum_lin = vec3(0.0);
            float total_area = 0.0;

            for (int ei = 0; ei < 4; ei++) {
                vec2 p = corners[ei];
                vec2 q = corners[(ei + 1) & 3];
                float sa_p = dot(p - line_a.cpt, line_a.normal);
                float sa_q = dot(q - line_a.cpt, line_a.normal);
                float sb_p = dot(p - line_b.cpt, line_b.normal);
                float sb_q = dot(q - line_b.cpt, line_b.normal);

                float splits[2];
                splits[0] = 0.0;
                splits[1] = 0.0;
                int nsplit = 0;
                if (sa_p * sa_q < 0.0) {
                    splits[nsplit] = sa_p / (sa_p - sa_q);
                    nsplit++;
                }
                if (sb_p * sb_q < 0.0) {
                    splits[nsplit] = sb_p / (sb_p - sb_q);
                    nsplit++;
                }
                if (nsplit == 2 && splits[0] > splits[1]) {
                    float tmp = splits[0]; splits[0] = splits[1]; splits[1] = tmp;
                }

                float t_prev = 0.0;
                vec2 u = p;
                for (int k = 0; k < 2; k++) {
                    if (k >= nsplit) break;
                    float t_curr = splits[k];
                    if (t_curr > t_prev + 1e-9) {
                        vec2 v = p + t_curr * (q - p);
                        vec2 m = p + (0.5 * (t_prev + t_curr)) * (q - p);
                        float sa_m = dot(m - line_a.cpt, line_a.normal);
                        float sb_m = dot(m - line_b.cpt, line_b.normal);
                        vec2 uj = u - J;
                        vec2 vj = v - J;
                        float area = abs(uj.x * vj.y - uj.y * vj.x) * 0.5;
                        if (area >= 1e-9) {
                            int idx = (sa_m > 0.0 ? 1 : 0) | (sb_m > 0.0 ? 2 : 0);
                            sum_lin += lut_lin[idx] * area;
                            total_area += area;
                        }
                        u = v;
                    }
                    t_prev = t_curr;
                }
                if (t_prev < 1.0 - 1e-9) {
                    vec2 m = p + (0.5 * (t_prev + 1.0)) * (q - p);
                    float sa_m = dot(m - line_a.cpt, line_a.normal);
                    float sb_m = dot(m - line_b.cpt, line_b.normal);
                    vec2 uj = u - J;
                    vec2 vj = q - J;
                    float area = abs(uj.x * vj.y - uj.y * vj.x) * 0.5;
                    if (area >= 1e-9) {
                        int idx = (sa_m > 0.0 ? 1 : 0) | (sb_m > 0.0 ? 2 : 0);
                        sum_lin += lut_lin[idx] * area;
                        total_area += area;
                    }
                }
            }

            if (total_area > 0.0) {
                center_color = linear_to_srgb(sum_lin / total_area);
                wedge_handled = true;
            }
        }
    }

    // Dual-curve AA: two distinct-chain curves passing through the pixel
    // without an actual junction inside it (typical of thin strokes where
    // two boundary curves graze the same pixel). Partitions the pixel
    // into 3 stripes via two single-line coverages — closed-form, no
    // boundary sweep. Skips when wedge AA fired, or when no second non-
    // chain hit is within threshold, or when the LUT model breaks down
    // (inner-color mismatch / lines cross inside pixel).
    bool dual_handled = false;
    if (!wedge_handled && resolved_h >= 0 && resolved_d2 < aa_threshold) {
        // resolved_h ∈ {0, 1, 2}; explicit selection.
        Hit hit_a = (resolved_h == 0) ? hits[0]
                  : (resolved_h == 1) ? hits[1]
                                      : hits[2];
        // Find sc_b: first cached hit not on hit_a's chain (1-step
        // neighbor test) and within aa_threshold. Unrolled across
        // s ∈ {0, 1, 2} on constant indices to keep hits[] in registers.
        int sec_h = -1;
        Hit hit_b;
        #define TRY_SEC(s, hs) \
            if (sec_h < 0 && (s) < num_hits && (s) != resolved_h \
                && (hs).d2 < aa_threshold && (hs).cp_idx >= 0) { \
                bool same_chain = (hit_a.cp_idx == (hs).cp_idx) \
                    || (hit_a.cp_idx == (hs).prev_ci) \
                    || (hit_a.cp_idx == (hs).next_ci) \
                    || ((hs).cp_idx == hit_a.prev_ci) \
                    || ((hs).cp_idx == hit_a.next_ci); \
                if (!same_chain) { sec_h = (s); hit_b = (hs); } \
            }
        TRY_SEC(0, hits[0])
        TRY_SEC(1, hits[1])
        TRY_SEC(2, hits[2])
        #undef TRY_SEC
        if (sec_h >= 0
            && any(notEqual(res.pos_side, res.neg_side))) {
            ResolveResult res_b = resolve_hit(hit_b, center);
            if (res_b.resolved && any(notEqual(res_b.pos_side, res_b.neg_side))) {
                vec2 cpt_a = beval(hit_a.prev_pos, hit_a.cp_pos, hit_a.next_pos, hit_a.t);
                vec2 cpt_b = beval(hit_b.prev_pos, hit_b.cp_pos, hit_b.next_pos, hit_b.t);
                vec2 na = res.opt_normal;
                vec2 nb = res_b.opt_normal;

                // Inner-side: which side of curve A faces curve B?
                vec2 delta_ba = cpt_b - cpt_a;
                bool inner_a_pos = dot(delta_ba, na) > 0.0;
                bool inner_b_pos = dot(-delta_ba, nb) > 0.0;
                vec3 a_inner = inner_a_pos ? res.pos_side  : res.neg_side;
                vec3 b_inner = inner_b_pos ? res_b.pos_side: res_b.neg_side;

                // Dual-curve assumes a shared middle region. If inner
                // colors disagree, geometry has 3 distinct colors (a
                // junction missed by structural detection). Defer.
                if (all(equal(a_inner, b_inner))) {
                    float d_a = dot(center - cpt_a, na) / inv_scale;
                    float d_b = dot(center - cpt_b, nb) / inv_scale;
                    float fa_pos = line_coverage_pos(na, d_a);
                    float fb_pos = line_coverage_pos(nb, d_b);
                    float fa_outer = inner_a_pos ? (1.0 - fa_pos) : fa_pos;
                    float fb_outer = inner_b_pos ? (1.0 - fb_pos) : fb_pos;
                    // Lines crossing inside pixel → A_outer ∩ B_outer
                    // overlaps → fractions sum > 1. Defer.
                    if (fa_outer + fb_outer <= 1.0 + 1e-4) {
                        float fm = max(0.0, 1.0 - fa_outer - fb_outer);
                        vec3 a_outer = inner_a_pos ? res.neg_side  : res.pos_side;
                        vec3 b_outer = inner_b_pos ? res_b.neg_side: res_b.pos_side;
                        vec3 lin = srgb_to_linear(a_outer) * fa_outer
                                 + srgb_to_linear(b_outer) * fb_outer
                                 + srgb_to_linear(a_inner) * fm;
                        center_color = linear_to_srgb(lin);
                        dual_handled = true;
                    }
                }
            }
        }
    }

    // Single-curve AA: exact pixel coverage from the resolved hit's tangent
    // line. Only fires when neither wedge AA nor dual-curve AA handled it.
    if (!wedge_handled && !dual_handled
        && resolved_h >= 0 && resolved_d2 < aa_threshold
        && any(notEqual(res.pos_side, res.neg_side))) {
        float d_p = res.d / inv_scale;
        float frac = line_coverage_pos(res.opt_normal, d_p);
        vec3 lin0 = srgb_to_linear(res.pos_side);
        vec3 lin1 = srgb_to_linear(res.neg_side);
        center_color = linear_to_srgb(frac * lin0 + (1.0 - frac) * lin1);
    }

    FragColor = vec4(center_color, 1.0);
}
