#version 450

// Cell rasterizer (single-curve AA). Renders single-curve AA at viewport
// scale and writes a sentinel signaling whether a multi-curve AA pass
// could refine the result for this pixel.
//
// Output:
//   RGB = single-curve AA color (or fallback for non-AA pixels).
//   A   = 1.0 iff a 2nd hit lies within aa_threshold (multi-curve refine
//         might fire); 0.0 otherwise. Standalone use ignores alpha.
//
// Inputs:
//   PackedPositions: per-CP denormalized geometry (pp, cp, np with ghosts,
//                    t_branch) from pack-positions.slang.
//   CellGraph: positions + neighbors + flags + packed directions.
//   Original: input pixel art image.

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

layout(set = 0, binding = 2) uniform sampler2D PackedPositions; // pack-positions output (2 texels per CP)
layout(set = 0, binding = 3) uniform sampler2D CellGraph;       // pos + neighbors + flags + dirs
layout(set = 0, binding = 4) uniform sampler2D Original;        // input pixel art
layout(set = 0, binding = 5) uniform sampler2D CellInfo;        // active-cell-mask: RGB = fallback, A = 8-bit active CP mask

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_H() << 12;  /* bit-packed encoding: cy < CH means cp_idx < CH<<12 */ }

// Chain endpoint flag — see cell-graph.slang.
const uint IS_ENDPOINT = 128u;
const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING = 64u;

// ---- Texture reading helpers ----

// CP encoding: bit-packed (cy << 12) | (cx << 1) | slot.
//   bit 0     = slot (0 or 1)
//   bits 1-11 = cx (max 2047)
//   bits 12+  = cy
// Decode is pure bit ops — no div/mod by CORNERS_W.

ivec2 decode_cp(int cp_idx) {
    // Row-interleaved slot: y = cy*2 + slot keeps slot 0 and slot 1 of
    // the same corner on adjacent texture rows.
    int slot = cp_idx & 1;
    int cx   = (cp_idx >> 1) & 0x7FF;
    int cy   = cp_idx >> 12;
    return ivec2(cx, (cy << 1) | slot);
}

// Compact CellGraph: 1 texel per CP. See cell-graph.slang for layout.
vec4 read_cg(int cp_idx) {
    return texelFetch(CellGraph, decode_cp(cp_idx), 0);
}

int unpack_idx(uint v) {
    return (v == 0xFFFFFFu) ? -1 : int(v);
}

// Read original position from cell graph (RG channels).
vec2 read_orig(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(-1e10);
    return read_cg(cp_idx).rg;
}

// Per-CP packed render geometry from pack-positions. 2 horizontal texels:
//   col 0 = (cp.x, cp.y, t_branch, validity 0=skip 1=valid)
//   col 1 = (pp.x, pp.y, np.x,     np.y)
// prev_ci/next_ci live in CellGraph (read by resolve_hit).
struct PackedCp {
    vec2 pp;
    vec2 cp;
    vec2 np;
    float t_branch;
    bool valid;
};

PackedCp read_packed_cp(int cp_idx) {
    PackedCp r;
    r.valid = false;
    r.t_branch = 0.5;
    r.pp = vec2(0.0); r.cp = vec2(0.0); r.np = vec2(0.0);

    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return r;
    ivec2 xy = decode_cp(cp_idx);

    vec4 t0 = texelFetch(PackedPositions, ivec2(xy.x*2,     xy.y), 0);
    if (t0.a < 0.5) return r;  // pack-positions wrote skip/inactive
    vec4 t1 = texelFetch(PackedPositions, ivec2(xy.x*2 + 1, xy.y), 0);

    r.cp = t0.rg;
    r.t_branch = t0.b;
    r.pp = t1.rg;
    r.np = t1.ba;
    r.valid = true;
    return r;
}

// Read neighbors from cell graph (BA channels, low 24 bits each).
ivec2 read_neighbors(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return ivec2(-1, -1);
    vec4 val = read_cg(cp_idx);
    uint pv = floatBitsToUint(val.b) & 0xFFFFFFu;
    uint nv = floatBitsToUint(val.a) & 0xFFFFFFu;
    return ivec2(unpack_idx(pv), unpack_idx(nv));
}

// Read flags from cell graph (B channel, top 8 bits).
uint read_flags(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return 0u;
    return (floatBitsToUint(read_cg(cp_idx).b) >> 24) & 0xFFu;
}

// Read packed boundary directions from cell graph (A channel, top 8 bits).
// Returns (prev_dir, next_dir) where -1 = none, 0=N, 1=E, 2=S, 3=W.
ivec2 read_dirs(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return ivec2(-1, -1);
    uint dp = (floatBitsToUint(read_cg(cp_idx).a) >> 24) & 0xFFu;
    return ivec2(int(dp & 0x7u) - 1, int((dp >> 3) & 0x7u) - 1);
}

// Get the grid corner (icx, icy) for a CP index. xy.y = cy*2 + slot,
// so `xy.y >> 1` drops the slot bit.
ivec2 cp_grid_corner(int cp_idx) {
    ivec2 xy = decode_cp(cp_idx);
    return ivec2(xy.x, xy.y >> 1);
}

// The 4 source pixels around an integer grid corner (icx, icy). Both
// prev_dir and next_dir edge-color lookups share this 2×2 block.
struct CornerPixels { vec3 nw, ne, se, sw; };

// Gather the 2×2 block via 3 textureGathers (one per RGB channel).
// Original is bound clamp-to-edge (RetroArch slang input default), so
// out-of-image corners reuse the nearest in-bounds pixel.
CornerPixels read_corner_pixels(int icx, int icy) {
    vec2 uv = vec2(float(icx), float(icy)) / vec2(float(IMG_W()), float(IMG_H()));
    vec4 r = textureGather(Original, uv, 0);
    vec4 g = textureGather(Original, uv, 1);
    vec4 b = textureGather(Original, uv, 2);
    // textureGather order, with base texel at (icx-1, icy-1):
    //   .w = (icx-1, icy-1) = NW   .z = (icx,   icy-1) = NE
    //   .x = (icx-1, icy)   = SW   .y = (icx,   icy)   = SE
    CornerPixels cp;
    cp.nw = vec3(r.w, g.w, b.w);
    cp.ne = vec3(r.z, g.z, b.z);
    cp.se = vec3(r.y, g.y, b.y);
    cp.sw = vec3(r.x, g.x, b.x);
    return cp;
}

struct EdgeColors { vec3 left; vec3 right; };

// Pick the left/right edge colors for `dir` from a CornerPixels block.
EdgeColors edge_from(CornerPixels cp, int dir) {
    EdgeColors r;
    if      (dir == 0) { r.left = cp.nw; r.right = cp.ne; }
    else if (dir == 1) { r.left = cp.ne; r.right = cp.se; }
    else if (dir == 2) { r.left = cp.se; r.right = cp.sw; }
    else if (dir == 3) { r.left = cp.sw; r.right = cp.nw; }
    else               { r.left = vec3(0.0); r.right = vec3(0.0); }
    return r;
}

// ---- B-spline evaluation ----

vec2 beval(vec2 p0, vec2 p1, vec2 p2, float t) {
    float u = 1.0 - t;
    return 0.5 * u * u * p0 + (u * t + 0.5) * p1 + 0.5 * t * t * p2;
}

vec2 beval_deriv(vec2 p0, vec2 p1, vec2 p2, float t) {
    return (t - 1.0) * p0 + (1.0 - 2.0 * t) * p1 + t * p2;
}

// Minimal hit record: ranking key (d2), closest-point parameter (t),
// and CP index. Everything else is re-derived via read_packed_cp at
// the consumer.
struct Hit {
    float d2;
    float t;
    int cp_idx;
};

// Tangent line at a hit's closest_t. Used by the wedge AA partition
// (cpt = junction J) and the dual-curve AA path (cpt = curve point).
struct AaLine {
    vec2 cpt;
    vec2 normal;       // Unit normal. Side test: dot(p - cpt, normal).
    bool valid;
};

// One Newton step on D'(t) = c3·t³+c2·t²+c1·t+c0. Polishes a closed-form
// root (Cardano/trig) to ~1 ULP. Skips when D''(t) is small or the step
// would diverge. Safe for the quadratic case (c3 ≈ 0).
float polish_root_c(float t, float c3, float c2, float c1, float c0) {
    float dp = fma(fma(fma(c3, t, c2), t, c1), t, c0);
    float ddp = fma(fma(3.0 * c3, t, 2.0 * c2), t, c1);
    if (abs(ddp) > 1e-10) {
        float step = dp / ddp;
        if (abs(step) < 0.5) t -= step;
    }
    return t;
}

vec2 closest_on_segment(vec2 a0, vec2 a1, vec2 pt) {
    vec2 v = a1 - a0;
    float vv = dot(v, v);
    float t = (vv > 0.0) ? clamp(dot(pt - a0, v) / vv, 0.0, 1.0) : 0.0;
    vec2 closest = a0 + t * v;
    vec2 d = pt - closest;
    return vec2(t, dot(d, d));
}

// Closest point on a B-spline span. D(t) = |B(t)-pt|² is degree 4 so
// D'(t) is cubic → closed-form roots. Evaluates D at all real roots in
// (0,1) plus both endpoints and returns the global min.
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

    // Threshold 1e-10 catches 2-CP-chain straight-line spans (c3 ≈ 4e-12
    // from FP noise in the ghost-construction's a-coeff cancellation).
    // MUST stay in lock-step with pack-positions.slang::span_closest_t.
    if (abs(c3) < 1e-10) {
        // Degenerate: quadratic or linear
        if (abs(c2) > 1e-12) {
            // FMA on `b²−4ac` + Numerical Recipes root form: avoids
            // catastrophic cancellation at near-double-root configs.
            float disc = fma(c1, c1, -4.0 * c2 * c0);
            if (disc >= 0.0) {
                float sq = sqrt(disc);
                float qq = -0.5 * (c1 + sign(c1) * sq);
                float t1 = polish_root_c(qq / c2, c3, c2, c1, c0);
                float t2 = polish_root_c(c0 / qq, c3, c2, c1, c0);
                if (t1 > 0.0 && t1 < 1.0) { float dd = EVAL_D2(t1); if (dd < best_d2) { best_d2 = dd; best_t = t1; } }
                if (t2 > 0.0 && t2 < 1.0) { float dd = EVAL_D2(t2); if (dd < best_d2) { best_d2 = dd; best_t = t2; } }
            }
        } else if (abs(c1) > 1e-12) {
            float t1 = polish_root_c(-c0 / c1, c3, c2, c1, c0);
            if (t1 > 0.0 && t1 < 1.0) { float dd = EVAL_D2(t1); if (dd < best_d2) { best_d2 = dd; best_t = t1; } }
        }
    } else {
        // Full cubic: depressed form via t = u - c2/(3·c3)
        float inv3a = 1.0 / (3.0 * c3);
        float shift = -c2 * inv3a;
        float p = (3.0*c3*c1 - c2*c2) / (3.0*c3*c3);
        float q = (2.0*c2*c2*c2 - 9.0*c3*c2*c1 + 27.0*c3*c3*c0) / (27.0*c3*c3*c3);
        // FMA on q²/4 + p³/27: one extra bit at the Cardano/trig boundary.
        float disc = fma(q * 0.5, q * 0.5, p*p*p/27.0);

        if (disc > 1e-12) {
            // One real root
            float sq = sqrt(disc);
            float hq = -q * 0.5;
            float u1 = sign(hq+sq) * pow(abs(hq+sq), 1.0/3.0);
            float u2 = sign(hq-sq) * pow(abs(hq-sq), 1.0/3.0);
            float t1 = polish_root_c(u1 + u2 + shift, c3, c2, c1, c0);
            if (t1 > 0.0 && t1 < 1.0) { float dd = EVAL_D2(t1); if (dd < best_d2) { best_d2 = dd; best_t = t1; } }
        } else {
            // Three real roots (trigonometric). disc <= 0 implies -p/3 ≥ 0,
            // so no max guard on the sqrt argument. r = 0 only at the
            // triple-root case (p = q = 0); the resulting NaN in cos_arg
            // is filtered by the t ∈ (0,1) test below.
            float r = sqrt(-p / 3.0);
            float cos_arg = clamp((-q * 0.5) / (r * r * r), -1.0, 1.0);
            float phi = acos(cos_arg);
            const float TAU = 6.283185307;
            for (int k = 0; k < 3; k++) {
                float angle = (phi + TAU * float(k)) / 3.0;
                float t1 = polish_root_c(2.0 * r * cos(angle) + shift, c3, c2, c1, c0);
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

// Exact pixel coverage by a tangent line. d_p is the line's signed
// perpendicular distance from pixel center, in pixel-side units. Returns
// the area on the line's positive side in [0, 1].
//   |d_p| <= (a-b)/2    → linear regime (line crosses parallel edges)
//   |d_p| < (a+b)/2     → corner-cut quadratic
//   else                → saturated
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

// Returns the t value on sc_b's curve (∈ {0.0, 1.0}) at which it passes
// through the junction at sc_a's corner, or -1.0 if sc_b isn't the
// stem-side curve. Caller pre-filters on (flags(ci_a) & IS_TJUNCTION).
//   case (a): sc_b IS slot 1 of sc_a's corner (2-CP-chain stem) → t=1.0.
//   case (b): sc_b is slot 1's neighbor — t=0.0 if its prev is endpoint,
//             t=1.0 if its next is.
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

// Builds a tangent-line classifier anchored at J with tangent evaluated
// at `t_eval`. Both line_a and line_b in wedge AA pass through J; the
// unit tangent is returned so the caller can align line_b's normal with
// line_a's tangent (so sb > 0 = post-junction along line_a).
AaLine build_junction_aa_line(Hit hit, vec2 J, float t_eval, out vec2 out_tang_unit) {
    AaLine result;
    result.cpt = J;
    result.normal = vec2(0.0);
    result.valid = false;
    out_tang_unit = vec2(0.0);

    PackedCp pcp = read_packed_cp(hit.cp_idx);
    vec2 tang = beval_deriv(pcp.pp, pcp.cp, pcp.np, t_eval);
    float tl2 = dot(tang, tang);
    if (tl2 < 1e-8) return result;  // length < 1e-4
    vec2 tu = tang * inversesqrt(tl2);
    out_tang_unit = tu;

    ivec2 grid = cp_grid_corner(hit.cp_idx);
    ivec2 dirs = read_dirs(hit.cp_idx);
    if (dirs.x < 0 && dirs.y < 0) return result;
    CornerPixels cps = read_corner_pixels(grid.x, grid.y);
    bool prev_split = false, next_split = false;
    if (dirs.x >= 0) {
        EdgeColors p = edge_from(cps, dirs.x);
        prev_split = any(notEqual(p.left, p.right));
    }
    if (dirs.y >= 0) {
        EdgeColors n = edge_from(cps, dirs.y);
        next_split = any(notEqual(n.left, n.right));
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

// Top-2 ranking by cp-pos distance. Flag fetches deferred to Phase C.
struct Top2 {
    int ci0;   float d0;
    int ci1;   float d1;
};

// Phase A: read one CP's cp-pos, insert into top-2.
void scan_one(int ci, vec2 query, inout Top2 t) {
    if (ci < 0 || ci >= NUM_CPS()) return;
    ivec2 xy = decode_cp(ci);
    vec4 t0 = texelFetch(PackedPositions, ivec2(xy.x*2, xy.y), 0);
    if (t0.a < 0.5) return;  // pack-positions wrote skip/inactive
    vec2 d = query - t0.rg;
    float d2 = dot(d, d);
    if (d2 < t.d0) {
        t.d1 = t.d0; t.ci1 = t.ci0;
        t.d0 = d2;   t.ci0 = ci;
    } else if (d2 < t.d1) {
        t.d1 = d2;   t.ci1 = ci;
    }
}

// Combined slot-0 + slot-1 scan for one corner. Issues both fetches up
// front so the compiler can schedule them as independent memory ops.
// Inactive slots (pair bit clear) read wasted texels — small bandwidth
// cost vs the parallel-issue win on the active slots.
void scan_corner_slots(int base, uint pair, vec2 query, inout Top2 t) {
    int cx = (base >> 1) & 0x7FF;
    int cy = base >> 12;
    int x_col = cx * 2;
    int y_s0  = cy << 1;
    int y_s1  = y_s0 | 1;

    vec4 t0_s0 = texelFetch(PackedPositions, ivec2(x_col, y_s0), 0);
    vec4 t0_s1 = texelFetch(PackedPositions, ivec2(x_col, y_s1), 0);

    if ((pair & 1u) != 0u && t0_s0.a >= 0.5) {
        vec2 d = query - t0_s0.rg;
        float d2 = dot(d, d);
        if (d2 < t.d0) {
            t.d1 = t.d0; t.ci1 = t.ci0;
            t.d0 = d2;   t.ci0 = base;
        } else if (d2 < t.d1) {
            t.d1 = d2;   t.ci1 = base;
        }
    }
    if ((pair & 2u) != 0u && t0_s1.a >= 0.5) {
        int ci = base + 1;
        vec2 d = query - t0_s1.rg;
        float d2 = dot(d, d);
        if (d2 < t.d0) {
            t.d1 = t.d0; t.ci1 = t.ci0;
            t.d0 = d2;   t.ci0 = ci;
        } else if (d2 < t.d1) {
            t.d1 = d2;   t.ci1 = ci;
        }
    }
}

// Phase D: full PackedCp fetch + cubic refine for one CP, insertion-
// sort into (hit, hit2). Called ≤4× per fragment.
void refine_to_hits(int ci, vec2 query, inout Hit hit, inout Hit hit2) {
    if (ci < 0) return;
    PackedCp pcp = read_packed_cp(ci);
    if (!pcp.valid) return;

    // closest_on_span's abs(c3) < 1e-10 branch handles 2-CP-chain
    // straight-line spans, so we don't need an is_line dispatch.
    vec2 result = closest_on_span(pcp.pp, pcp.cp, pcp.np, query);
    float span_t  = result.x;
    float span_d2 = result.y;
    if (span_d2 >= 1.0) return;

    if (span_d2 < hit.d2) {
        hit2 = hit;
        hit.d2 = span_d2; hit.t = span_t; hit.cp_idx = ci;
    } else if (span_d2 < hit2.d2) {
        hit2.d2 = span_d2; hit2.t = span_t; hit2.cp_idx = ci;
    }
}

// Top-2-by-cp-pos prune + T-junction stem fan-in.
//
// Phase A/B (fused): walk the 4 cell corners, rank each candidate's
// cp_d² into an inline Top2.
// Phase C: for each top-2 winner with IS_TJUNCTION, also pull its
// slot-1 stem CP's chain neighbor (the curve that ghost-extends to
// render the stem) into the refinement set.
// Phase D: refine the ≤4-CP set (top-2 + ≤2 stem fan-ins) with the
// cubic solver and insertion-sort into (hit, hit2).
//
// Ranking by cp-pos (not 3-sample quick_d²) prevents the ranking from
// tying adjacent same-chain CPs at their shared chain joint, which
// otherwise burned both Top2 slots on the through chain in T-junction
// pixels and lost the stem.
bool find_hits(uint mask, int cell_cx, int cell_cy, vec2 query,
               out Hit hit, out Hit hit2) {
    hit.d2 = 1e10; hit.t = 0.0; hit.cp_idx = -1;
    hit2.d2 = 1e10; hit2.t = 0.0; hit2.cp_idx = -1;

    if (mask == 0u) return false;

    const ivec2 corner_offsets[4] = ivec2[4](
        ivec2(0, 0),  // SW
        ivec2(1, 0),  // SE
        ivec2(0, 1),  // NW
        ivec2(1, 1)   // NE
    );

    // Phases A+B fused: walk and rank inline.
    Top2 t;
    t.ci0 = -1; t.d0 = 1e10;
    t.ci1 = -1; t.d1 = 1e10;

    // Track IS_TJUNCTION slot-0 bases for force-refinement in Phase D —
    // a T-junction's through-curve is often closer to the pixel than its
    // CP, but cp-pos ranking can demote it when an adjacent CORNER CP
    // happens to sit closer.
    int tj_bases[4] = int[4](-1, -1, -1, -1);
    int tj_count = 0;

    for (int oi = 0; oi < 4; oi++) {
        uint pair = (mask >> (oi * 2)) & 0x3u;
        if (pair == 0u) continue;
        int cx = cell_cx + corner_offsets[oi].x;
        int cy = cell_cy + corner_offsets[oi].y;
        int base = (cy << 12) | (cx << 1);  // slot=0; base|1 = slot=1

        scan_corner_slots(base, pair, query, t);

        // Stem fan-out: only fires for IS_TJUNCTION slot 0. Lazy flag
        // fetch — most corners exit after one CellGraph texelFetch.
        if ((pair & 1u) != 0u) {
            uint slot0_flag = (floatBitsToUint(
                texelFetch(CellGraph, decode_cp(base), 0).b) >> 24) & 0xFFu;
            if ((slot0_flag & IS_TJUNCTION) != 0u) {
                tj_bases[tj_count++] = base;
                ivec2 slot1_n = read_neighbors(base + 1);
                int sci = slot1_n.x >= 0 ? slot1_n.x : slot1_n.y;
                if (sci >= 0) {
                    ivec2 s_grid = cp_grid_corner(sci);
                    bool already_walked =
                        s_grid.x >= cell_cx && s_grid.x <= cell_cx + 1
                     && s_grid.y >= cell_cy && s_grid.y <= cell_cy + 1;
                    if (!already_walked) scan_one(sci, query, t);
                }
            }
        }
    }
    if (t.ci0 < 0) return false;

    // Phase C: T-junction stem fan-in. Fetch flags for top-2 only.
    uint flag0 = (t.ci0 >= 0) ? ((floatBitsToUint(
        texelFetch(CellGraph, decode_cp(t.ci0), 0).b) >> 24) & 0xFFu) : 0u;
    uint flag1 = (t.ci1 >= 0) ? ((floatBitsToUint(
        texelFetch(CellGraph, decode_cp(t.ci1), 0).b) >> 24) & 0xFFu) : 0u;

    int stem0 = -1, stem1 = -1;
    if ((flag0 & IS_TJUNCTION) != 0u) {
        ivec2 nbrs = read_neighbors(t.ci0 + 1);
        stem0 = nbrs.x >= 0 ? nbrs.x : nbrs.y;
    }
    if (t.ci1 >= 0 && (flag1 & IS_TJUNCTION) != 0u) {
        ivec2 nbrs = read_neighbors(t.ci1 + 1);
        stem1 = nbrs.x >= 0 ? nbrs.x : nbrs.y;
    }

    // Phase D: refine selected CPs. refine_to_hits is idempotent and
    // gates on validity ≥ 0.5 so duplicates are cheap.
    refine_to_hits(t.ci0, query, hit, hit2);
    refine_to_hits(t.ci1, query, hit, hit2);
    for (int i = 0; i < tj_count; i++) {
        int tj = tj_bases[i];
        if (tj != t.ci0 && tj != t.ci1) refine_to_hits(tj, query, hit, hit2);
        // Slot 1 of the T-junction corner: renders only if it's the
        // lower-indexed endpoint of the 2-CP stem chain.
        refine_to_hits(tj + 1, query, hit, hit2);
    }
    if (stem0 != t.ci0 && stem0 != t.ci1)
        refine_to_hits(stem0, query, hit, hit2);
    if (stem1 != t.ci0 && stem1 != t.ci1 && stem1 != stem0)
        refine_to_hits(stem1, query, hit, hit2);

    return hit.cp_idx >= 0;
}

// Resolve solid color + AA components from one hit. Returns
// resolved=false when the hit defers (endpoint at hit_t lands on a
// co-located CP, no edge has a color discontinuity, or tangents
// degenerate).
ResolveResult resolve_hit(Hit hit, vec2 query) {
    ResolveResult r;
    r.solid_color = vec3(0.0);
    r.pos_side = vec3(0.0); r.neg_side = vec3(0.0);
    r.opt_normal = vec2(0.0); r.d = 0.0;
    r.resolved = false;

    int ci = hit.cp_idx;
    ivec2 xy = decode_cp(ci);
    int slot = ci & 1;
    int cx = xy.x;
    int cy = xy.y >> 1;  // xy.y = cy*2 + slot; drop slot bit

    vec4 t0 = texelFetch(PackedPositions, ivec2(xy.x*2,     xy.y), 0);
    if (t0.a < 0.5) return r;
    vec4 t1 = texelFetch(PackedPositions, ivec2(xy.x*2 + 1, xy.y), 0);

    float hit_t = hit.t;
    vec2 cp = t0.rg;
    float t_branch_pcp = t0.b;
    vec2 pp = t1.rg;
    vec2 np = t1.ba;

    // CellGraph texel: prev_ci/next_ci live in the low 24 bits of .b/.a.
    vec4 cg_ci = texelFetch(CellGraph, xy, 0);
    int prev_ci = unpack_idx(floatBitsToUint(cg_ci.b) & 0xFFFFFFu);
    int next_ci = unpack_idx(floatBitsToUint(cg_ci.a) & 0xFFFFFFu);

    // dp_ci top byte: prev_dir (bits 0-2), next_dir (bits 3-5), and the
    // bake-neighbor-endpoints prev/next IS_ENDPOINT bits (6, 7).
    uint dp_ci = (floatBitsToUint(cg_ci.a) >> 24) & 0xFFu;
    int prev_dir = int(dp_ci & 0x7u) - 1;
    int next_dir = int((dp_ci >> 3) & 0x7u) - 1;

    // Endpoint defer: hit at exact t=0|1 of an endpoint-extended curve.
    bool prev_is_endpoint = (prev_ci < 0) || ((dp_ci & 0x40u) != 0u);
    bool next_is_endpoint = (next_ci < 0) || ((dp_ci & 0x80u) != 0u);
    if ((prev_is_endpoint && hit_t == 0.0) || (next_is_endpoint && hit_t == 1.0)) {
        return r;
    }
    ivec2 grid = ivec2(cx, cy);

    CornerPixels cps = read_corner_pixels(grid.x, grid.y);
    vec3 pl = vec3(0.0), pr = vec3(0.0), nl = vec3(0.0), nr = vec3(0.0);
    if (prev_dir >= 0) { EdgeColors p = edge_from(cps, prev_dir); pl = p.left; pr = p.right; }
    if (next_dir >= 0) { EdgeColors n = edge_from(cps, next_dir); nl = n.left; nr = n.right; }

    // Pick prev's or next's edge by hit_t side of t_branch. The (nr, nl)
    // swap keeps c_left along the curve normal regardless of source dir.
    // (0,0,0) defaults from edge_from cover the prev_dir<0 / next_dir<0
    // case via the *_valid tests.
    bool prev_valid = any(notEqual(pl, pr));
    bool next_valid = any(notEqual(nl, nr));
    if (!prev_valid && !next_valid) return r;
    bool use_prev = prev_valid && (!next_valid || hit_t < t_branch_pcp);
    vec3 c_left  = use_prev ? pl : nr;
    vec3 c_right = use_prev ? pr : nl;

    vec2 opt_tang = beval_deriv(pp, cp, np, hit_t);
    float opt_tl2 = dot(opt_tang, opt_tang);
    if (opt_tl2 < 1e-8) return r;
    vec2 opt_normal = vec2(-opt_tang.y, opt_tang.x) * inversesqrt(opt_tl2);

    vec2 curve_pt = beval(pp, cp, np, hit_t);
    float d = dot(query - curve_pt, opt_normal);

    r.pos_side = c_left;
    r.neg_side = c_right;
    r.opt_normal = opt_normal;
    r.d = d;
    r.solid_color = (d > 0.0) ? c_left : c_right;
    r.resolved = true;
    return r;
}

void main() {
    float scale_x = params.OutputSize.x / float(IMG_W());
    float scale_y = params.OutputSize.y / float(IMG_H());
    float scale = min(scale_x, scale_y);
    float inv_scale = 1.0 / scale;

    vec2 center = vTexCoord * vec2(float(IMG_W()), float(IMG_H()));
    int cell_cx = int(floor(center.x));
    int cell_cy = int(floor(center.y));

    // CellInfo: RGB = fallback color, A = 8-bit active-CP mask for this cell.
    cell_cx = clamp(cell_cx, 0, IMG_W() - 1);
    cell_cy = clamp(cell_cy, 0, IMG_H() - 1);
    vec4 cell_info = texelFetch(CellInfo, ivec2(cell_cx, cell_cy), 0);
    vec3 fallback = cell_info.rgb;
    uint cell_mask = uint(cell_info.a * 255.0 + 0.5);

    // Track top 2 hits so that when the closest one defers (endpoint at
    // chain boundary) we can resolve the second-closest instead of
    // falling through to the source-color leak.
    Hit hit;
    Hit hit2;
    bool found = find_hits(cell_mask, cell_cx, cell_cy, center, hit, hit2);
    float second_d2 = hit2.d2;

    vec3 center_color = fallback;
    ResolveResult res;
    res.solid_color = fallback;
    res.pos_side = vec3(0.0);
    res.neg_side = vec3(0.0);
    res.opt_normal = vec2(0.0);
    res.d = 0.0;
    res.resolved = false;
    if (found) {
        ResolveResult rr = resolve_hit(hit, center);
        // Closest deferred (endpoint at chain boundary): the second-
        // closest is typically the through curve at ~the same d². Without
        // this fallback, single-AA shows a 1-pixel source-color leak near
        // 3-color T-junctions.
        if (!rr.resolved && hit2.cp_idx >= 0) {
            rr = resolve_hit(hit2, center);
            if (rr.resolved) { hit = hit2; }
        }
        if (rr.resolved) { res = rr; center_color = rr.solid_color; }
    }

    // Pixel half-diagonal² in source units. Beyond this, the tangent-
    // coverage formula saturates anyway.
    float aa_threshold = 0.5 / (scale * scale);

    // Single-curve AA: exact pixel coverage from the resolved hit's
    // tangent line.
    if (res.resolved && hit.d2 < aa_threshold
        && any(notEqual(res.pos_side, res.neg_side))) {
        float d_p = res.d / inv_scale;
        float frac = line_coverage_pos(res.opt_normal, d_p);
        vec3 lin0 = srgb_to_linear(res.pos_side);
        vec3 lin1 = srgb_to_linear(res.neg_side);
        center_color = linear_to_srgb(frac * lin0 + (1.0 - frac) * lin1);
    }

    // Sentinel: 1.0 iff a 2nd hit is within aa_threshold. The multi-AA
    // pass uses this to decide whether to do any work.
    float sentinel = (second_d2 < aa_threshold) ? 1.0 : 0.0;
    FragColor = vec4(center_color, sentinel);
}
