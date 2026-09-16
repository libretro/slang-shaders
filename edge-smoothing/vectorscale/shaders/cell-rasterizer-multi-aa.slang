#version 450

// Cell rasterizer (multi-curve AA refinement). Second pass after the
// single-AA rasterizer.
//
// If SingleAA's alpha sentinel is clear, passes RGB through. Otherwise
// redoes find_hits (top-3) and runs the wedge / dual-curve AA gates.
// Falls back to the single-AA color when neither fires.
//
// Inputs:
//   SingleAA: pass 1 output (RGB color, A sentinel).
//   PackedPositions, CellGraph, Original, CellInfo: see single-AA pass.

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

layout(set = 0, binding = 2) uniform sampler2D PackedPositions;
layout(set = 0, binding = 3) uniform sampler2D CellGraph;
layout(set = 0, binding = 4) uniform sampler2D Original;
layout(set = 0, binding = 5) uniform sampler2D CellInfo;
layout(set = 0, binding = 6) uniform sampler2D SingleAA;        // RGB = single-AA color, A = multi-AA sentinel

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_H() << 12;  /* bit-packed encoding: cy < CH means cp_idx < CH<<12 */ }

// Chain endpoint flag — see cell-graph.slang.
const uint IS_ENDPOINT = 128u;
const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING = 64u;

// Bit-packed CP encoding — see cell-rasterizer-single-aa.slang.
ivec2 decode_cp(int cp_idx) {
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

// Per-CP packed render geometry. See cell-rasterizer-single-aa.slang.
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
    if (t0.a < 0.5) return r;
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

// Get the grid corner (icx, icy) — see cell-rasterizer-single-aa.slang.
ivec2 cp_grid_corner(int cp_idx) {
    ivec2 xy = decode_cp(cp_idx);
    return ivec2(xy.x, xy.y >> 1);
}

// 2×2 source pixels around grid corner (icx, icy) — see single-aa.
struct CornerPixels { vec3 nw, ne, se, sw; };

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

// Minimal hit record. Other per-CP data is re-derived via
// read_packed_cp at consumer sites; storing it forces register spill.
struct Hit {
    float d2;
    float t;
    int cp_idx;
};

// Tangent line at a hit's closest_t — see single-aa.
struct AaLine {
    vec2 cpt;
    vec2 normal;       // Unit normal. Side test: dot(p - cpt, normal).
    bool valid;
};

// One Newton step on a cubic — see cell-rasterizer-single-aa.slang.
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

// Closest point on a B-spline span — see cell-rasterizer-single-aa.slang.
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

    // MUST stay in lock-step with the other span_closest_t copies.
    if (abs(c3) < 1e-10) {
        // Degenerate: quadratic or linear
        if (abs(c2) > 1e-12) {
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
            // Three real roots (trigonometric).
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

// Exact pixel coverage by a tangent line — see single-aa.
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

// Structural junction detection — see single-aa.
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

// Junction-anchored AA-line builder — see single-aa.
AaLine build_junction_aa_line(Hit hit, vec2 J, float t_eval, out vec2 out_tang_unit) {
    AaLine result;
    result.cpt = J;
    result.normal = vec2(0.0);
    result.valid = false;
    out_tang_unit = vec2(0.0);

    PackedCp pcp = read_packed_cp(hit.cp_idx);
    vec2 tang = beval_deriv(pcp.pp, pcp.cp, pcp.np, t_eval);
    float tl2 = dot(tang, tang);
    if (tl2 < 1e-8) return result;
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

// Top-2 ranking by cp-pos — see single-aa.
struct Top2 {
    int ci0;   float d0;
    int ci1;   float d1;
};

void scan_one(int ci, vec2 query, inout Top2 t) {
    if (ci < 0 || ci >= NUM_CPS()) return;
    ivec2 xy = decode_cp(ci);
    vec4 t0 = texelFetch(PackedPositions, ivec2(xy.x*2, xy.y), 0);
    if (t0.a < 0.5) return;
    vec2 d = query - t0.rg;
    float d2 = dot(d, d);
    if (d2 < t.d0) {
        t.d1 = t.d0; t.ci1 = t.ci0;
        t.d0 = d2;   t.ci0 = ci;
    } else if (d2 < t.d1) {
        t.d1 = d2;   t.ci1 = ci;
    }
}

// Combined slot-0 + slot-1 scan — see single-aa.
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

// Phase D: full PackedCp fetch + cubic refine, insertion-sort into
// hits[3]. Called ≤4× per fragment.
void refine_to_hits(int ci, vec2 query, inout Hit hits[3], inout int num_hits) {
    if (ci < 0) return;
    PackedCp pcp = read_packed_cp(ci);
    if (!pcp.valid) return;

    vec2 result = closest_on_span(pcp.pp, pcp.cp, pcp.np, query);
    float span_t  = result.x;
    float span_d2 = result.y;
    if (span_d2 >= 1.0) return;

    Hit cand;
    cand.d2 = span_d2; cand.t = span_t; cand.cp_idx = ci;
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
}

// Top-2-by-cp-pos prune + T-junction stem fan-in. Populates hits[3]
// for the multi-curve AA path. See single-aa for rationale.
int find_hits(uint mask, int cell_cx, int cell_cy, vec2 query, out Hit hits[3]) {
    int num_hits = 0;
    hits[0].d2 = 1e10; hits[0].t = 0.0; hits[0].cp_idx = -1;
    hits[1].d2 = 1e10; hits[1].t = 0.0; hits[1].cp_idx = -1;
    hits[2].d2 = 1e10; hits[2].t = 0.0; hits[2].cp_idx = -1;

    if (mask == 0u) return num_hits;

    const ivec2 corner_offsets[4] = ivec2[4](
        ivec2(0, 0),  // SW
        ivec2(1, 0),  // SE
        ivec2(0, 1),  // NW
        ivec2(1, 1)   // NE
    );

    Top2 t;
    t.ci0 = -1; t.d0 = 1e10;
    t.ci1 = -1; t.d1 = 1e10;

    int tj_bases[4] = int[4](-1, -1, -1, -1);
    int tj_count = 0;

    for (int oi = 0; oi < 4; oi++) {
        uint pair = (mask >> (oi * 2)) & 0x3u;
        if (pair == 0u) continue;
        int cx = cell_cx + corner_offsets[oi].x;
        int cy = cell_cy + corner_offsets[oi].y;
        int base = (cy << 12) | (cx << 1);  // slot=0; base|1 = slot=1

        scan_corner_slots(base, pair, query, t);

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
    if (t.ci0 < 0) return num_hits;

    // Phase C: T-junction stem fan-in.
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

    // Phase D: refine selected CPs.
    refine_to_hits(t.ci0, query, hits, num_hits);
    refine_to_hits(t.ci1, query, hits, num_hits);
    for (int i = 0; i < tj_count; i++) {
        int tj = tj_bases[i];
        if (tj != t.ci0 && tj != t.ci1) refine_to_hits(tj, query, hits, num_hits);
        refine_to_hits(tj + 1, query, hits, num_hits);
    }
    if (stem0 != t.ci0 && stem0 != t.ci1)
        refine_to_hits(stem0, query, hits, num_hits);
    if (stem1 != t.ci0 && stem1 != t.ci1 && stem1 != stem0)
        refine_to_hits(stem1, query, hits, num_hits);

    return num_hits;
}

// Resolve solid color + AA components from one hit — see single-aa.
ResolveResult resolve_hit(Hit hit, vec2 query) {
    ResolveResult r;
    r.solid_color = vec3(0.0);
    r.pos_side = vec3(0.0); r.neg_side = vec3(0.0);
    r.opt_normal = vec2(0.0); r.d = 0.0;
    r.resolved = false;

    int ci = hit.cp_idx;
    float hit_t = hit.t;
    ivec2 xy = decode_cp(ci);
    int slot = ci & 1;
    int cx = xy.x;
    int cy = xy.y >> 1;  // xy.y = cy*2 + slot; drop slot bit

    vec4 t0 = texelFetch(PackedPositions, ivec2(xy.x*2,     xy.y), 0);
    if (t0.a < 0.5) return r;
    vec4 t1 = texelFetch(PackedPositions, ivec2(xy.x*2 + 1, xy.y), 0);

    vec2 cp = t0.rg;
    float t_branch_pcp = t0.b;
    vec2 pp = t1.rg;
    vec2 np = t1.ba;

    vec4 cg_ci = texelFetch(CellGraph, xy, 0);
    int prev_ci = unpack_idx(floatBitsToUint(cg_ci.b) & 0xFFFFFFu);
    int next_ci = unpack_idx(floatBitsToUint(cg_ci.a) & 0xFFFFFFu);

    // dp_ci top byte: prev_dir (0-2), next_dir (3-5), prev/next
    // IS_ENDPOINT (6, 7) from bake-neighbor-endpoints.
    uint dp_ci = (floatBitsToUint(cg_ci.a) >> 24) & 0xFFu;
    int prev_dir = int(dp_ci & 0x7u) - 1;
    int next_dir = int((dp_ci >> 3) & 0x7u) - 1;

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
    vec4 prev = textureLod(SingleAA, vTexCoord, 0.0);

    // Sentinel clear → pass through SingleAA color.
    if (prev.a < 0.5) {
        FragColor = vec4(prev.rgb, 1.0);
        return;
    }

    float scale_x = params.OutputSize.x / float(IMG_W());
    float scale_y = params.OutputSize.y / float(IMG_H());
    float scale = min(scale_x, scale_y);
    float inv_scale = 1.0 / scale;

    vec2 center = vTexCoord * vec2(float(IMG_W()), float(IMG_H()));
    int cell_cx = clamp(int(floor(center.x)), 0, IMG_W() - 1);
    int cell_cy = clamp(int(floor(center.y)), 0, IMG_H() - 1);

    // CellInfo mask drives find_hits; fallback color = SingleAA's RGB
    // (already AA-smoothed for the no-multi-AA case).
    uint cell_mask = uint(texelFetch(CellInfo, ivec2(cell_cx, cell_cy), 0).a * 255.0 + 0.5);
    vec3 fallback = prev.rgb;

    Hit hits[3];
    int num_hits = find_hits(cell_mask, cell_cx, cell_cy, center, hits);

    // Resolve AA state from the first hit that resolves. The single-AA
    // pass already wrote the single-curve color; we only need `res` for
    // the wedge / dual-curve paths.
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
        if (rr.resolved) { res = rr; resolved_h = 0; }
    }
    if (num_hits >= 2 && resolved_h < 0) {
        ResolveResult rr = resolve_hit(hits[1], center);
        if (rr.resolved) { res = rr; resolved_h = 1; }
    }
    if (num_hits >= 3 && resolved_h < 0) {
        ResolveResult rr = resolve_hit(hits[2], center);
        if (rr.resolved) { res = rr; resolved_h = 2; }
    }

    // Pixel half-diagonal² in source units.
    float aa_threshold = 0.5 / (scale * scale);

    // Wedge AA: fires when (a) two hits share a structural junction
    // (T-junction through+stem, or two IS_CROSSING hits at the same
    // corner) AND (b) the junction point J lies inside the pixel.
    //
    // T-junction structural cases:
    //   (a) sc_b IS slot 1 of sc_a's corner (2-CP-chain stem) → t = 1.
    //   (b) sc_b is slot 1's surviving non-(-1) neighbor — chain CP that
    //       ghost-extends through slot 1's position. t = 0 if its prev is
    //       endpoint, t = 1 if its next is.
    //
    // J = beval(sc_a, t_branch) — point on the rendered curve at the
    // junction parameter. NOT cp_pos: those differ for ghost-extended CPs.
    // Without the in-pixel check, two curves that graze the same pixel
    // without their junction being in it would mix a third color via the
    // LUT that isn't actually present.
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
            t_b_eval = read_packed_cp(ci1).t_branch;
        }

        // Junction-in-pixel.
        if (through_h >= 0) {
            // Explicit selection on through_h ∈ {0,1} keeps hits[] in regs.
            Hit th = (through_h == 0) ? hits[0] : hits[1];
            PackedCp th_pcp = read_packed_cp(th.cp_idx);
            vec2 J = beval(th_pcp.pp, th_pcp.cp, th_pcp.np, th_pcp.t_branch);
            float pix_half = inv_scale * 0.5;
            if (abs(J.x - center.x) > pix_half || abs(J.y - center.y) > pix_half) {
                through_h = -1;
                stem_h = -1;
            }
        }
    }
    // Explicit selection avoids dynamic-indexed read into hits[].
    float resolved_d2 = (resolved_h == 0) ? hits[0].d2
                      : (resolved_h == 1) ? hits[1].d2
                      : (resolved_h == 2) ? hits[2].d2 : 1e10;
    bool need_wedge_aa = resolved_h >= 0 && resolved_d2 < aa_threshold
                        && through_h >= 0;
    if (need_wedge_aa) {
        Hit through_hit = (through_h == 0) ? hits[0] : hits[1];
        Hit stem_hit    = (stem_h    == 0) ? hits[0] : hits[1];

        PackedCp through_pcp = read_packed_cp(through_hit.cp_idx);

        vec2 J = beval(through_pcp.pp, through_pcp.cp, through_pcp.np,
                        through_pcp.t_branch);

        // line_a: through tangent at t_branch.
        vec2 tang_a_unit;
        AaLine line_a = build_junction_aa_line(through_hit, J, through_pcp.t_branch, tang_a_unit);

        // line_b: stem tangent at the junction. t_b_eval comes from the
        // structural gate above.
        vec2 tang_b_unit;
        AaLine line_b = build_junction_aa_line(stem_hit, J, t_b_eval, tang_b_unit);

        // Align line_b.normal so sb > 0 = post-junction along line_a.
        if (line_b.valid && dot(line_b.normal, tang_a_unit) < 0.0) {
            line_b.normal = -line_b.normal;
        }

        if (line_a.valid && line_b.valid) {
            // The through curve carries all three colors via its two edge
            // segments split at t_branch. line_b's normal is aligned with
            // line_a's tangent so (sa-sign, sb-sign) maps directly to
            // (pos|neg) × (pre|post-junction) buckets.

            // Reuse `res` if the through hit is already the resolved one.
            ResolveResult through_res = (through_h == resolved_h)
                ? res
                : resolve_hit(through_hit, center);

            // Pack the 4 corner colors with packUnorm4x8 so they stay
            // cold during the boundary-sweep loop. Inputs are 8-bit sRGB
            // from Original so the pack round-trips losslessly.
            uint fb_p   = packUnorm4x8(vec4(fallback, 0.0));
            uint pos0_p = fb_p, neg0_p = fb_p;
            uint pos1_p = fb_p, neg1_p = fb_p;

            // pos_side / neg_side from resolve_hit are topologically tied
            // to the cells flanking the span — invariant along the span,
            // so no normal-swap is needed even though line_a.normal differs
            // from opt_normal where the curve bends.
            bool res_in_seg1 = through_hit.t >= through_pcp.t_branch;
            if (through_res.resolved) {
                uint rp = packUnorm4x8(vec4(through_res.pos_side, 0.0));
                uint rn = packUnorm4x8(vec4(through_res.neg_side, 0.0));
                if (res_in_seg1) { pos1_p = rp; neg1_p = rn; }
                else             { pos0_p = rp; neg0_p = rn; }
            }

            // Sample the OTHER segment of the through curve at its
            // midpoint to fill in colors for both sides of t_branch.
            {
                Hit other_seg = through_hit;
                other_seg.t = res_in_seg1
                    ? (through_pcp.t_branch * 0.5)
                    : (0.5 * (through_pcp.t_branch + 1.0));
                ResolveResult res_other = resolve_hit(other_seg, J);
                if (res_other.resolved) {
                    uint opp = packUnorm4x8(vec4(res_other.pos_side, 0.0));
                    uint onp = packUnorm4x8(vec4(res_other.neg_side, 0.0));
                    if (res_in_seg1) { pos0_p = opp; neg0_p = onp; }
                    else             { pos1_p = opp; neg1_p = onp; }
                } else if (through_res.resolved) {
                    uint rp = packUnorm4x8(vec4(through_res.pos_side, 0.0));
                    uint rn = packUnorm4x8(vec4(through_res.neg_side, 0.0));
                    if (res_in_seg1) { pos0_p = rp; neg0_p = rn; }
                    else             { pos1_p = rp; neg1_p = rn; }
                }
            }

            // Boundary-sweep area accumulation. Walk the pixel CCW; on
            // each edge find up to 2 line crossings, split into ≤3 sub-
            // segments, classify each by (sa, sb)-sign at its midpoint,
            // and add the triangle (u, v, J) area to the matching wedge
            // bucket. J inside the pixel + consistent walk direction
            // makes |cross| the wedge area directly.
            float pix_h = inv_scale * 0.5;
            vec2 corners[4];
            corners[0] = vec2(center.x - pix_h, center.y - pix_h);
            corners[1] = vec2(center.x + pix_h, center.y - pix_h);
            corners[2] = vec2(center.x + pix_h, center.y + pix_h);
            corners[3] = vec2(center.x - pix_h, center.y + pix_h);

            // Wedge area buckets keyed by (sa_sign, sb_sign):
            //   _np: sa<0, sb<0 (neg side, pre-junction)  → neg0
            //   _pp: sa>0, sb<0 (pos side, pre-junction)  → pos0
            //   _nn: sa<0, sb>0 (neg side, post-junction) → neg1
            //   _pn: sa>0, sb>0 (pos side, post-junction) → pos1
            float a_neg0 = 0.0, a_pos0 = 0.0, a_neg1 = 0.0, a_pos1 = 0.0;
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
                            bool sa_pos = sa_m > 0.0;
                            bool sb_pos = sb_m > 0.0;
                            if (sa_pos) {
                                if (sb_pos) a_pos1 += area; else a_pos0 += area;
                            } else {
                                if (sb_pos) a_neg1 += area; else a_neg0 += area;
                            }
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
                        bool sa_pos = sa_m > 0.0;
                        bool sb_pos = sb_m > 0.0;
                        if (sa_pos) {
                            if (sb_pos) a_pos1 += area; else a_pos0 += area;
                        } else {
                            if (sb_pos) a_neg1 += area; else a_neg0 += area;
                        }
                        total_area += area;
                    }
                }
            }

            if (total_area > 0.0) {
                // Unpack + linearize one color at a time so only one
                // vec3 is live at the reduction.
                vec3 sum_lin = a_neg0 * srgb_to_linear(unpackUnorm4x8(neg0_p).rgb)
                             + a_pos0 * srgb_to_linear(unpackUnorm4x8(pos0_p).rgb)
                             + a_neg1 * srgb_to_linear(unpackUnorm4x8(neg1_p).rgb)
                             + a_pos1 * srgb_to_linear(unpackUnorm4x8(pos1_p).rgb);
                center_color = linear_to_srgb(sum_lin / total_area);
                wedge_handled = true;
            }
        }
    }

    // Dual-curve AA: two distinct-chain curves passing through the pixel
    // without a junction inside it (typical of thin strokes). Partitions
    // the pixel into 3 stripes via two single-line coverages.
    bool dual_handled = false;
    if (!wedge_handled && resolved_h >= 0 && resolved_d2 < aa_threshold) {
        Hit hit_a = (resolved_h == 0) ? hits[0]
                  : (resolved_h == 1) ? hits[1]
                                      : hits[2];
        // Find sc_b: first cached hit not on hit_a's chain (1-step
        // neighbor test) and within aa_threshold. Macro keeps the loop
        // unrolled on constant indices so hits[] stays in registers.
        ivec2 hit_a_nbrs = read_neighbors(hit_a.cp_idx);
        int sec_h = -1;
        Hit hit_b;
        #define TRY_SEC(s, hs) \
            if (sec_h < 0 && (s) < num_hits && (s) != resolved_h \
                && (hs).d2 < aa_threshold && (hs).cp_idx >= 0) { \
                ivec2 hs_nbrs = read_neighbors((hs).cp_idx); \
                bool same_chain = (hit_a.cp_idx == (hs).cp_idx) \
                    || (hit_a.cp_idx == hs_nbrs.x) \
                    || (hit_a.cp_idx == hs_nbrs.y) \
                    || ((hs).cp_idx == hit_a_nbrs.x) \
                    || ((hs).cp_idx == hit_a_nbrs.y); \
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
                PackedCp pcp_a = read_packed_cp(hit_a.cp_idx);
                PackedCp pcp_b = read_packed_cp(hit_b.cp_idx);
                vec2 cpt_a = beval(pcp_a.pp, pcp_a.cp, pcp_a.np, hit_a.t);
                vec2 cpt_b = beval(pcp_b.pp, pcp_b.cp, pcp_b.np, hit_b.t);
                vec2 na = res.opt_normal;
                vec2 nb = res_b.opt_normal;

                // Inner-side: which side of curve A faces curve B?
                vec2 delta_ba = cpt_b - cpt_a;
                bool inner_a_pos = dot(delta_ba, na) > 0.0;
                bool inner_b_pos = dot(-delta_ba, nb) > 0.0;
                vec3 a_inner = inner_a_pos ? res.pos_side  : res.neg_side;
                vec3 b_inner = inner_b_pos ? res_b.pos_side: res_b.neg_side;

                // Dual-curve assumes a shared middle region. Inner-color
                // mismatch means there's a missed junction; defer.
                if (all(equal(a_inner, b_inner))) {
                    float d_a = dot(center - cpt_a, na) / inv_scale;
                    float d_b = dot(center - cpt_b, nb) / inv_scale;
                    float fa_pos = line_coverage_pos(na, d_a);
                    float fb_pos = line_coverage_pos(nb, d_b);
                    float fa_outer = inner_a_pos ? (1.0 - fa_pos) : fa_pos;
                    float fb_outer = inner_b_pos ? (1.0 - fb_pos) : fb_pos;
                    // Lines crossing inside pixel ⇒ outer fractions sum > 1.
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

    // Falls back to single-AA's center_color (= prev.rgb) when neither
    // wedge nor dual-curve AA fired.
    FragColor = vec4(center_color, 1.0);
}
