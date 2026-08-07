#version 450
#pragma format R32G32B32A32_SFLOAT

// Pack-positions. Denormalize per-CP render geometry into PackedPositions
// from FinalPositions + CellGraph. 2 horizontally-adjacent texels per CP:
//
//   (cx*2 + 0, cy_slot) = (cp.x, cp.y, t_branch, validity)
//                         validity: 0.0 = skip / inactive, 1.0 = valid
//   (cx*2 + 1, cy_slot) = (pp.x, pp.y, np.x,     np.y)
//
// pp / np are ghost-extended (pp = 2·prev - cp etc.) when the relevant
// neighbor is an endpoint. t_branch is computed per CP type:
//   - IS_CROSSING: 2D Newton on F(t,s) = B_a(t) - B_b(s) = 0.
//   - 2-CP chain (degenerate stem): t_branch = 0.5; pp/cp/np built as
//     a straight line (the rasterizer's c3<1e-10 path handles it).
//   - One-sided clamped Bezier: closed-form cubic projection of the
//     interior B-spline midpoint onto the clamped span.
//   - Else: 0.5.

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

layout(set = 0, binding = 2) uniform sampler2D FinalPositions; // post-tjunction stem-snapped positions
layout(set = 0, binding = 3) uniform sampler2D CellGraph;      // neighbors + flags

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_H() << 12;  /* bit-packed encoding: cy < CH means cp_idx < CH<<12 */ }

const uint IS_CROSSING = 64u;
const uint IS_ENDPOINT = 128u;

// Bit-packed CP encoding. Row-interleaved slot — see cell-rasterizer-single-aa.slang.
ivec2 decode_cp(int cp_idx) {
    int cp_slot = cp_idx & 1;
    int cx = (cp_idx >> 1) & 0x7FF;
    int cy = cp_idx >> 12;
    return ivec2(cx, (cy << 1) | cp_slot);
}

vec2 read_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(0.0);
    return texelFetch(FinalPositions, decode_cp(cp_idx), 0).rg;
}

// Forward decl — span_closest_t seeds bspline_intersect.
float span_closest_t(vec2 p0, vec2 p1, vec2 p2, vec2 pt);

// B-spline curve-curve intersection. Solves F(t,s) = B_a(t) - B_b(s) = 0
// via 2D Newton, seeded with closest-t on each span to a_p1 (which equals
// b_p1 post-optimization). The closest-t seed handles asymmetric chains
// where one side is endpoint-clamped — fixed t=s=0.5 lands in the wrong
// basin and produces wedge-AA artifacts. 6 iters with step-size early
// out; matches the vibeboy reference.
vec2 bspline_intersect(vec2 a_p0, vec2 a_p1, vec2 a_p2,
                       vec2 b_p0, vec2 b_p1, vec2 b_p2) {
    vec2 aa = 0.5 * a_p0 - a_p1 + 0.5 * a_p2;
    vec2 ba = -a_p0 + a_p1;
    vec2 ca = 0.5 * a_p0 + 0.5 * a_p1;
    vec2 ab = 0.5 * b_p0 - b_p1 + 0.5 * b_p2;
    vec2 bb = -b_p0 + b_p1;
    vec2 cb = 0.5 * b_p0 + 0.5 * b_p1;

    float t = span_closest_t(a_p0, a_p1, a_p2, a_p1);
    float s = span_closest_t(b_p0, b_p1, b_p2, a_p1);

    for (int iter = 0; iter < 6; iter++) {
        vec2 fa = aa * t * t + ba * t + ca;
        vec2 fb = ab * s * s + bb * s + cb;
        vec2 f = fa - fb;
        vec2 dft = 2.0 * aa * t + ba;
        vec2 dfs = -(2.0 * ab * s + bb);
        float det = dft.x * dfs.y - dft.y * dfs.x;
        if (abs(det) < 1e-12) break;
        float dt = ( dfs.y * f.x - dfs.x * f.y) / det;
        float ds = (-dft.y * f.x + dft.x * f.y) / det;
        t -= dt;
        s -= ds;
        if (abs(dt) < 1e-7 && abs(ds) < 1e-7) break;
    }
    return vec2(clamp(t, 0.0, 1.0), clamp(s, 0.0, 1.0));
}

// Compact CellGraph: 1 texel per CP. See cell-graph.slang for layout.
vec4 read_cg(int cp_idx) {
    return texelFetch(CellGraph, decode_cp(cp_idx), 0);
}

int unpack_idx(uint v) {
    return (v == 0xFFFFFFu) ? -1 : int(v);
}

uint read_flags(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return 0u;
    return (floatBitsToUint(read_cg(cp_idx).b) >> 24) & 0xFFu;
}

// MUST stay byte-identical to cell-rasterizer-*.slang::polish_root_c.
float polish_root_c(float t, float c3, float c2, float c1, float c0) {
    float dp = fma(fma(fma(c3, t, c2), t, c1), t, c0);
    float ddp = fma(fma(3.0 * c3, t, 2.0 * c2), t, c1);
    if (abs(ddp) > 1e-10) {
        float step = dp / ddp;
        if (abs(step) < 0.5) t -= step;
    }
    return t;
}

// MUST match cell-rasterizer-*.slang's closest_on_span ulp-for-ulp.
// Any drift flips the rasterizer's `hit_t < t_branch` side-of-curve
// decision at near-singular crossings → visible color-switch artifacts.
float span_closest_t(vec2 p0, vec2 p1, vec2 p2, vec2 pt) {
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

    if (abs(c3) < 1e-10) {
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
    return best_t;
}

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);

    // Texture is 2*corners_w wide: column = cx*2 + which_texel.
    //   which_texel = 0 → (cp.x, cp.y, t_branch, validity)
    //   which_texel = 1 → (pp.x, pp.y, np.x,    np.y)
    int which_texel = opos.x & 1;
    int cx = opos.x >> 1;
    int cy_slot = opos.y;

    if (cx >= CORNERS_W() || cy_slot >= CORNERS_H() * 2) {
        FragColor = vec4(0.0);
        return;
    }

    int slot = cy_slot & 1;
    int cy = cy_slot >> 1;
    int ci = (cy << 12) | (cx << 1) | slot;

    vec4 cg = texelFetch(CellGraph, ivec2(cx, cy_slot), 0);
    uint cg_b = floatBitsToUint(cg.b);
    uint cg_a = floatBitsToUint(cg.a);
    uint flag = (cg_b >> 24) & 0xFFu;
    if (flag == 0u) {
        FragColor = vec4(0.0);
        return;
    }

    int prev_ci = unpack_idx(cg_b & 0xFFFFFFu);
    int next_ci = unpack_idx(cg_a & 0xFFFFFFu);

    // No neighbors: chain endpoints owned by another CP's clamped extension.
    if (prev_ci < 0 && next_ci < 0) {
        FragColor = vec4(0.0);
        return;
    }

    // 2-CP-chain: both ends are endpoint markers, only the lower-
    // indexed endpoint renders the span.
    bool i_am_endpoint = (prev_ci < 0 || next_ci < 0);
    bool two_cp_chain = false;
    if (i_am_endpoint) {
        int other = (prev_ci < 0) ? next_ci : prev_ci;
        bool other_is_end = (read_flags(other) & IS_ENDPOINT) != 0u;
        if (!other_is_end || ci > other) {
            FragColor = vec4(0.0);
            return;
        }
        two_cp_chain = true;
    }

    vec2 cp_real = read_pos(ci);
    vec2 prev_pos = (prev_ci >= 0) ? read_pos(prev_ci) : cp_real;
    vec2 next_pos = (next_ci >= 0) ? read_pos(next_ci) : cp_real;

    bool prev_is_end = (prev_ci >= 0) && ((read_flags(prev_ci) & IS_ENDPOINT) != 0u);
    bool next_is_end = (next_ci >= 0) && ((read_flags(next_ci) & IS_ENDPOINT) != 0u);

    vec2 cp, pp, np;
    if (two_cp_chain) {
        // Straight line between the markers. Picking p0=(3·a0-a1)/2,
        // p1=midpoint, p2=(3·a1-a0)/2 makes beval evaluate to lerp(a0,a1,t).
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

    // t_branch: rasterizer's prev_dir/next_dir split parameter.
    // Crossings solve the curve-curve intersection inline; slot 0 holds
    // the N-S chain and slot 1 the E-W, and both share the same physical
    // position.
    float t_branch;
    if ((flag & IS_CROSSING) != 0u) {
        // Partner CP index is ci^1 (slot bit at position 0).
        vec4 p_cg = texelFetch(CellGraph, decode_cp(ci ^ 1), 0);
        int p_prev = unpack_idx(floatBitsToUint(p_cg.b) & 0xFFFFFFu);
        int p_next = unpack_idx(floatBitsToUint(p_cg.a) & 0xFFFFFFu);

        int n_idx, s_idx, e_idx, w_idx;
        if (slot == 0) {
            n_idx = prev_ci; s_idx = next_ci;   // own (slot 0) = N-S
            e_idx = p_prev;  w_idx = p_next;    // partner (slot 1) = E-W
        } else {
            n_idx = p_prev;  s_idx = p_next;    // partner (slot 0) = N-S
            e_idx = prev_ci; w_idx = next_ci;   // own (slot 1) = E-W
        }

        if (n_idx >= 0 && s_idx >= 0 && e_idx >= 0 && w_idx >= 0) {
            vec2 n_pos = read_pos(n_idx);
            vec2 s_pos = read_pos(s_idx);
            vec2 e_pos = read_pos(e_idx);
            vec2 w_pos = read_pos(w_idx);

            bool n_is_end = (read_flags(n_idx) & IS_ENDPOINT) != 0u;
            bool s_is_end = (read_flags(s_idx) & IS_ENDPOINT) != 0u;
            bool e_is_end = (read_flags(e_idx) & IS_ENDPOINT) != 0u;
            bool w_is_end = (read_flags(w_idx) & IS_ENDPOINT) != 0u;

            vec2 n_in = n_is_end ? (2.0 * n_pos - cp_real) : n_pos;
            vec2 s_in = s_is_end ? (2.0 * s_pos - cp_real) : s_pos;
            vec2 e_in = e_is_end ? (2.0 * e_pos - cp_real) : e_pos;
            vec2 w_in = w_is_end ? (2.0 * w_pos - cp_real) : w_pos;

            vec2 t_pair = bspline_intersect(n_in, cp_real, s_in,
                                             e_in, cp_real, w_in);
            t_branch = (slot == 0) ? t_pair.x : t_pair.y;
        } else {
            t_branch = 0.5;
        }
    } else if (two_cp_chain) {
        t_branch = 0.5;
    } else if (prev_is_end || next_is_end) {
        // One-sided clamped Bezier: the rendered curve's parameterization
        // is shifted, so t=0.5 isn't the symmetric split point. Project
        // the interior-span midpoint onto the clamped span.
        vec2 interior_mid = 0.125 * pp + 0.75 * cp + 0.125 * np;
        t_branch = span_closest_t(pp, cp, np, interior_mid);
    } else {
        t_branch = 0.5;
    }

    vec4 out_texel = (which_texel == 0)
        ? vec4(cp.x, cp.y, t_branch, 1.0)
        : vec4(pp.x, pp.y, np.x,     np.y);
    FragColor = out_texel;
}
