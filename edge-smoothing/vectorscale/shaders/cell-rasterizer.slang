#version 450

// Cell rasterizer — renders optimized B-spline curves at viewport scale.
//
// For each output pixel, scans a 5x5 CP neighborhood, finds the nearest
// B-spline boundary via Newton-Raphson, resolves color from edge data,
// and applies analytical anti-aliasing at boundary edges.
//
// Multi-hit resolution: tries up to 4 nearest CPs with single-neighbor
// endpoint rejection.
//
// Input textures:
//   FinalPositions: optimized absolute positions
//   CellGraph: original positions + neighbors + flags + packed directions
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

layout(set = 0, binding = 2) uniform sampler2D FinalPositions;  // optimized CP absolute positions
layout(set = 0, binding = 3) uniform sampler2D CellGraph;       // positions + neighbors + flags + directions
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

// Read optimized absolute position from FinalPositions.
vec2 read_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(-1e10);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    vec4 val = texelFetch(FinalPositions, ivec2(cx, cy_slot), 0);
    return vec2(val.r, val.g);
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
// Used by the multi-curve wedge AA path to partition a pixel by multiple
// curves; each wedge's color is then resampled via classify_at.
struct AaLine {
    vec2 cpt;
    vec2 normal;       // Unit normal. Side test: dot(p - cpt, normal).
    bool valid;
};

// ---- Convex polygon (max 8 verts, enough for a 4-vert pixel clipped twice) ----
struct Polygon {
    vec2 v[8];
    int n;
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

// ---- AA-line builder ----
//
// Builds a tangent-line classifier at the hit's closest_t. Returns invalid
// when the CP has no usable edge (no color discontinuity to either side via
// prev_dir/next_dir).
AaLine build_aa_line(Hit hit) {
    AaLine result;
    result.cpt = vec2(0.0);
    result.normal = vec2(0.0);
    result.valid = false;

    vec2 tang = beval_deriv(hit.prev_pos, hit.cp_pos, hit.next_pos, hit.t);
    float tl = length(tang);
    if (tl < 1e-4) return result;
    vec2 normal = vec2(-tang.y, tang.x) / tl;

    ivec2 grid = cp_grid_corner(hit.cp_idx);
    ivec2 dirs = read_dirs(hit.cp_idx);
    int prev_dir = dirs.x;
    int next_dir = dirs.y;

    bool prev_split = false;
    bool next_split = false;
    if (prev_dir >= 0) {
        vec3 pl, pr;
        get_edge_colors(grid.x, grid.y, prev_dir, pl, pr);
        prev_split = any(notEqual(pl, pr));
    }
    if (next_dir >= 0) {
        vec3 nl, nr;
        get_edge_colors(grid.x, grid.y, next_dir, nl, nr);
        next_split = any(notEqual(nl, nr));
    }
    if (!prev_split && !next_split) return result;

    result.cpt = beval(hit.prev_pos, hit.cp_pos, hit.next_pos, hit.t);
    result.normal = normal;
    result.valid = true;
    return result;
}

// ---- Sutherland-Hodgman: clip a convex polygon against a half-plane ----
//
// keep_pos selects which side of the line: dot(p - cpt, normal) > 0 if true.
Polygon clip_polygon(Polygon poly, AaLine line, bool keep_pos) {
    Polygon out_poly;
    out_poly.n = 0;
    if (poly.n == 0) return out_poly;

    vec2 prev = poly.v[poly.n - 1];
    float prev_s = dot(prev - line.cpt, line.normal);

    for (int i = 0; i < poly.n; i++) {
        vec2 curr = poly.v[i];
        float curr_s = dot(curr - line.cpt, line.normal);
        bool curr_in = keep_pos ? (curr_s > 0.0) : (curr_s < 0.0);
        bool prev_in = keep_pos ? (prev_s > 0.0) : (prev_s < 0.0);
        if (curr_in) {
            if (!prev_in) {
                float denom = prev_s - curr_s;
                if (abs(denom) > 1e-12 && out_poly.n < 8) {
                    float tt = prev_s / denom;
                    out_poly.v[out_poly.n] = prev + tt * (curr - prev);
                    out_poly.n++;
                }
            }
            if (out_poly.n < 8) {
                out_poly.v[out_poly.n] = curr;
                out_poly.n++;
            }
        } else if (prev_in) {
            float denom = prev_s - curr_s;
            if (abs(denom) > 1e-12 && out_poly.n < 8) {
                float tt = prev_s / denom;
                out_poly.v[out_poly.n] = prev + tt * (curr - prev);
                out_poly.n++;
            }
        }
        prev = curr;
        prev_s = curr_s;
    }
    return out_poly;
}

float polygon_area(Polygon p) {
    if (p.n < 3) return 0.0;
    float a = 0.0;
    for (int i = 0; i < p.n; i++) {
        int j = (i + 1) % p.n;
        a += p.v[i].x * p.v[j].y - p.v[j].x * p.v[i].y;
    }
    return abs(a) * 0.5;
}

vec2 polygon_centroid(Polygon p) {
    if (p.n == 0) return vec2(0.0);
    vec2 s = vec2(0.0);
    for (int i = 0; i < p.n; i++) s += p.v[i];
    return s / float(p.n);
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

// ---- Tile-cache lookup: produce top-4 hits sorted by d² for `query` ----
//
// Replaces per-pixel cell scan with a read from the tile-cache texture.
// The tile-cache pass identified up to 50 CPs whose bbox can affect any
// pixel in this 2×2 source-pixel tile and stored their indices. We just
// iterate those, doing the same per-CP work (ghost adjustment, bbox
// check, closest-point) as before.
//
// Each cached CP is split into (cx, cy_slot) — small ints exact in fp16.
// 2 CPs per RGBA texel (cx0, cy_slot0, cx1, cy_slot1); 25 texels per tile;
// 50 CPs total. Sentinel: cx < 0.
int find_hits(vec2 query, out Hit hits[4]) {
    int num_hits = 0;
    for (int h = 0; h < 4; h++) {
        hits[h].d2 = 1e10; hits[h].t = 0.0; hits[h].cp_idx = -1;
        hits[h].prev_ci = -1; hits[h].next_ci = -1;
        hits[h].cp_pos = vec2(0.0); hits[h].prev_pos = vec2(0.0); hits[h].next_pos = vec2(0.0);
        hits[h].t_branch = 0.5; hits[h].is_line = false;
    }

    // 5x5 cell scan around the query pixel. The cheap flag==0 rejection
    // skips the ~half of grid corners with no active CP before any
    // expensive work — much faster than iterating a fixed-size tile
    // cache where every slot must be processed.
    int cell_cx = int(floor(query.x));
    int cell_cy = int(floor(query.y));

    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            int cx = cell_cx + dx;
            int cy = cell_cy + dy;
            if (cx < 0 || cy < 0 || cx >= CORNERS_W() || cy >= CORNERS_H()) continue;

            for (int slot = 0; slot < 2; slot++) {
                int ci = (cy * CORNERS_W() + cx) * 2 + slot;
                if (ci < 0 || ci >= NUM_CPS()) continue;

                uint flag = read_flags(ci);
                if (flag == 0u) continue;

                ivec2 nbrs = read_neighbors(ci);
                int prev_ci = nbrs.x;
                int next_ci = nbrs.y;
                if (prev_ci < 0 && next_ci < 0) continue;

                // Endpoint CPs (one neighbor missing) don't own a span
                // when their interior neighbor will clamp through them;
                // their span is implicitly drawn as the interior CP's
                // clamped Bezier ending at this CP's position. Only
                // render an endpoint here when the OTHER side is also an
                // endpoint (2-CP chain) — degenerate straight tail.
                bool i_am_endpoint = (prev_ci < 0 || next_ci < 0);
                bool two_cp_chain = false;
                if (i_am_endpoint) {
                    int other = (prev_ci < 0) ? next_ci : prev_ci;
                    bool other_is_end = (read_flags(other) & IS_ENDPOINT) != 0u;
                    if (!other_is_end) continue;
                    // 2-CP chain de-dup: only the lower-indexed endpoint
                    // owns the span (otherwise both endpoints render the
                    // same physical line with opposite ghost bowing).
                    if (ci > other) continue;
                    two_cp_chain = true;
                }

                vec2 cp_real = read_pos(ci);
                vec2 prev_pos = (prev_ci >= 0) ? read_pos(prev_ci) : cp_real;
                vec2 next_pos = (next_ci >= 0) ? read_pos(next_ci) : cp_real;

                // Ghost extension for clamped Bezier endpoints. Ghost =
                // 2*real - cp lands beval(...,t=0|1) exactly on the real
                // endpoint position.
                bool prev_is_end = (prev_ci >= 0) && ((read_flags(prev_ci) & IS_ENDPOINT) != 0u);
                bool next_is_end = (next_ci >= 0) && ((read_flags(next_ci) & IS_ENDPOINT) != 0u);

                vec2 cp, pp, np;
                if (two_cp_chain) {
                    int other = (prev_ci < 0) ? next_ci : prev_ci;
                    vec2 other_pos = read_pos(other);
                    vec2 a0 = (prev_ci < 0) ? cp_real : other_pos;
                    vec2 a1 = (next_ci < 0) ? cp_real : other_pos;
                    pp = 1.5 * a0 - 0.5 * a1;
                    cp = 0.5 * (a0 + a1);
                    np = 1.5 * a1 - 0.5 * a0;
                } else {
                    cp = cp_real;
                    pp = prev_is_end ? (2.0 * prev_pos - cp) : prev_pos;
                    np = next_is_end ? (2.0 * next_pos - cp) : next_pos;
                }

                // Bbox uses the real positions (not ghosts) for a tight
                // rejection bound — ghosts can extend well past the
                // curve's actual extent.
                vec2 bb_min = min(min(prev_pos, cp_real), next_pos) - vec2(1.0);
                vec2 bb_max = max(max(prev_pos, cp_real), next_pos) + vec2(1.0);
                if (query.x < bb_min.x || query.x > bb_max.x ||
                    query.y < bb_min.y || query.y > bb_max.y)
                    continue;

                vec2 result;
                if (two_cp_chain) {
                    vec2 a0 = 0.5 * (pp + cp);
                    vec2 a1 = 0.5 * (cp + np);
                    result = closest_on_segment(a0, a1, query);
                } else {
                    result = closest_on_span(pp, cp, np, query);
                }
                float span_t = result.x;
                float span_d2 = result.y;
                if (span_d2 >= 1.0) continue;

                // t_branch: for clamped spans, find the t at which the
                // rendered curve reaches the algebraic "before/after sc"
                // pivot (= interior B-spline's t=0.5). Used by the
                // through-curve LUT to color-split on the right side of
                // the junction.
                float t_branch;
                if (two_cp_chain) {
                    t_branch = 0.5;
                } else if (prev_is_end || next_is_end) {
                    vec2 interior_mid = 0.125 * pp + 0.75 * cp + 0.125 * np;
                    t_branch = closest_on_span(pp, cp, np, interior_mid).x;
                } else {
                    t_branch = 0.5;
                }

                for (int h = 0; h < 4; h++) {
                    if (span_d2 < hits[h].d2) {
                        for (int j = 3; j > h; j--) hits[j] = hits[j-1];
                        hits[h].d2 = span_d2;
                        hits[h].t = span_t;
                        hits[h].cp_idx = ci;
                        hits[h].prev_ci = prev_ci;
                        hits[h].next_ci = next_ci;
                        hits[h].cp_pos = cp;
                        hits[h].prev_pos = pp;
                        hits[h].next_pos = np;
                        hits[h].t_branch = t_branch;
                        hits[h].is_line = two_cp_chain;
                        if (num_hits < 4) num_hits++;
                        break;
                    }
                }
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
    Hit hits[4];
    int num_hits = find_hits(query, hits);
    for (int h = 0; h < num_hits; h++) {
        ResolveResult r = resolve_hit(hits[h], query);
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
    Hit hits[4];
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
    for (int h = 0; h < num_hits; h++) {
        ResolveResult rr = resolve_hit(hits[h], center);
        if (rr.resolved) {
            res = rr;
            center_color = rr.solid_color;
            resolved_h = h;
            break;
        }
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
    bool wedge_handled = false;
    int through_h = -1;
    int stem_h = -1;
    if (num_hits >= 2 && hits[0].cp_idx >= 0 && hits[1].cp_idx >= 0
        && hits[1].d2 < aa_threshold) {
        int ci0 = hits[0].cp_idx;
        int ci1 = hits[1].cp_idx;
        uint f0 = read_flags(ci0);
        uint f1 = read_flags(ci1);
        int slot1_ci_0 = (ci0 / 2) * 2 + 1;
        int slot1_ci_1 = (ci1 / 2) * 2 + 1;
        ivec2 slot1_n_0 = read_neighbors(slot1_ci_0);
        ivec2 slot1_n_1 = read_neighbors(slot1_ci_1);
        bool cp0_t = ((f0 & IS_TJUNCTION) != 0u)
            && (ci1 == slot1_ci_0 || slot1_n_0.x == ci1 || slot1_n_0.y == ci1);
        bool cp1_t = ((f1 & IS_TJUNCTION) != 0u)
            && (ci0 == slot1_ci_1 || slot1_n_1.x == ci0 || slot1_n_1.y == ci0);
        bool both_x_same =
            ((f0 & IS_CROSSING) != 0u)
            && ((f1 & IS_CROSSING) != 0u)
            && (ci0 / 2) == (ci1 / 2);
        if (cp0_t) { through_h = 0; stem_h = 1; }
        else if (cp1_t) { through_h = 1; stem_h = 0; }
        else if (both_x_same) { through_h = 0; stem_h = 1; }

        // Junction-in-pixel: through CP's pos must lie inside the pixel.
        if (through_h >= 0) {
            vec2 jp = hits[through_h].cp_pos;
            float pix_half = inv_scale * 0.5;
            if (abs(jp.x - center.x) > pix_half || abs(jp.y - center.y) > pix_half) {
                through_h = -1;
                stem_h = -1;
            }
        }
    }
    bool need_wedge_aa = resolved_h >= 0 && hits[resolved_h].d2 < aa_threshold
                        && through_h >= 0;
    if (need_wedge_aa) {
        AaLine line_a = build_aa_line(hits[through_h]);
        AaLine line_b = build_aa_line(hits[stem_h]);

        if (line_a.valid && line_b.valid) {
            float pix_h = inv_scale * 0.5;
            Polygon pixel;
            pixel.v[0] = vec2(center.x - pix_h, center.y - pix_h);
            pixel.v[1] = vec2(center.x + pix_h, center.y - pix_h);
            pixel.v[2] = vec2(center.x + pix_h, center.y + pix_h);
            pixel.v[3] = vec2(center.x - pix_h, center.y + pix_h);
            pixel.n = 4;

            Polygon above_a = clip_polygon(pixel, line_a, true);
            Polygon below_a = clip_polygon(pixel, line_a, false);
            Polygon wedges[4];
            wedges[0] = clip_polygon(above_a, line_b, true);
            wedges[1] = clip_polygon(above_a, line_b, false);
            wedges[2] = clip_polygon(below_a, line_b, true);
            wedges[3] = clip_polygon(below_a, line_b, false);

            vec3 sum_lin = vec3(0.0);
            float total_area = 0.0;

            // Through-curve color LUT: at a T-junction the through curve
            // (= hits[through_h]) carries all three colors via its two
            // edge segments split at t_branch — pre-junction edge gives
            // the (pos, neg) for t < t_branch, post-junction edge gives
            // them for t > t_branch.
            //
            // For each wedge centroid we use sidedness against line_a (which
            // side of the through curve) and against line_b (which segment
            // of the through curve, since line_b ≈ stem tangent crosses
            // line_a at the t_branch projection). This replaces the per-
            // wedge closest_on_span sweep + resolve_hit with two dot
            // products and a 2x2 LUT lookup.
            Hit through_hit = hits[through_h];

            // Resolve the through hit at center to get its pos/neg/normal.
            // If through_h == resolved_h we could reuse `res`, but the
            // resolve is cheap and avoids special-casing.
            ResolveResult through_res = resolve_hit(through_hit, center);

            // Build pos/neg colors for each segment, aligned to line_a.normal
            // (so a single sidedness test against line_a applies to both
            // segments). One segment is covered by through_res; resolve
            // the other. For 2-CP chains both halves are identical so we
            // skip the second resolve.
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
                ResolveResult res_other = resolve_hit(other_seg, line_a.cpt);
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

            // Segment selection: line_b only separates seg 0 from seg 1
            // when it crosses line_a's curve in [0, 1] — i.e., the mid-
            // seg-0 and mid-seg-1 points lie on opposite sides of line_b.
            // When line_b is geometrically outside line_a's curve range
            // (e.g., a stem at an adjacent corner), both segments fall
            // on the same side and sb-sidedness is meaningless. In that
            // case all wedges share one segment, picked from through_hit.t.
            float seg1_side = 1.0;
            bool b_separates = false;
            if (!through_hit.is_line) {
                float t_pre = through_hit.t_branch * 0.5;
                float t_post = (through_hit.t_branch + 1.0) * 0.5;
                vec2 p_pre  = beval(through_hit.prev_pos, through_hit.cp_pos, through_hit.next_pos, t_pre);
                vec2 p_post = beval(through_hit.prev_pos, through_hit.cp_pos, through_hit.next_pos, t_post);
                float s0 = dot(p_pre  - line_b.cpt, line_b.normal);
                float s1 = dot(p_post - line_b.cpt, line_b.normal);
                seg1_side = s1;
                b_separates = (s0 * s1) < 0.0;
            }
            bool center_in_seg1 = through_hit.t >= through_hit.t_branch;

            for (int wi = 0; wi < 4; wi++) {
                float area = polygon_area(wedges[wi]);
                if (area <= 1e-9) continue;
                vec2 cq = polygon_centroid(wedges[wi]);
                float sign_a = dot(cq - line_a.cpt, line_a.normal);
                bool in_seg1;
                if (b_separates) {
                    float sign_b = dot(cq - line_b.cpt, line_b.normal);
                    in_seg1 = (sign_b * seg1_side) > 0.0;
                } else {
                    in_seg1 = center_in_seg1;
                }
                vec3 color = in_seg1
                    ? ((sign_a > 0.0) ? pos1 : neg1)
                    : ((sign_a > 0.0) ? pos0 : neg0);
                sum_lin += pow(color, vec3(2.2)) * area;
                total_area += area;
            }

            if (total_area > 0.0) {
                center_color = pow(sum_lin / total_area, vec3(1.0 / 2.2));
                wedge_handled = true;
            }
        }
    }

    // Single-curve AA: exact pixel coverage from the resolved hit's tangent
    // line. Only fires when wedge AA didn't handle this pixel.
    if (!wedge_handled && resolved_h >= 0 && hits[resolved_h].d2 < aa_threshold &&
        any(notEqual(res.pos_side, res.neg_side))) {
        // Linear when |d_p| <= (a-b)/2 (line crosses two parallel edges),
        // quadratic in (a-b)/2 < |d_p| < (a+b)/2 (line cuts a corner triangle),
        // saturates outside.
        float nx = abs(res.opt_normal.x);
        float ny = abs(res.opt_normal.y);
        float a = max(nx, ny);
        float b = min(nx, ny);
        float half_ext = (a + b) * 0.5;
        float lin_ext = (a - b) * 0.5;
        float d_p = res.d / inv_scale;
        float frac;
        if (d_p >= half_ext) {
            frac = 1.0;
        } else if (d_p <= -half_ext) {
            frac = 0.0;
        } else if (abs(d_p) <= lin_ext) {
            frac = 0.5 + d_p / a;
        } else if (d_p > 0.0) {
            float t = half_ext - d_p;
            frac = 1.0 - 0.5 * t * t / (a * b);
        } else {
            float t = half_ext + d_p;
            frac = 0.5 * t * t / (a * b);
        }
        vec3 lin0 = pow(res.pos_side, vec3(2.2));
        vec3 lin1 = pow(res.neg_side, vec3(2.2));
        center_color = pow(frac * lin0 + (1.0 - frac) * lin1, vec3(1.0 / 2.2));
    }

    FragColor = vec4(center_color, 1.0);
}
