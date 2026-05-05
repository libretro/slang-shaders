#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass: Denormalize per-CP render geometry into PackedPositions.
//
// Reads FinalPositions (post-tjunction stem snap) + CellGraph
// (neighbors, flags) and packs each CP's complete render geometry
// into 3 horizontally-adjacent texels:
//
//   (cx*3 + 0, cy_slot) = (pp.x, pp.y, prev_ci_as_float, 0)
//   (cx*3 + 1, cy_slot) = (cp.x, cp.y, t_branch, validity)
//                         validity: 0.0 = skip / inactive,
//                                   1.0 = valid normal,
//                                   2.0 = valid 2-CP chain (is_line)
//   (cx*3 + 2, cy_slot) = (np.x, np.y, next_ci_as_float, 0)
//
// pp / np are already ghost-extended (pp = 2·prev - cp etc.) for
// endpoint neighbors. t_branch is computed in the right way per CP
// type (see the t_branch dispatch in main()):
//   - IS_CROSSING: 2D Newton iteration on F(t,s) = B_a(t) - B_b(s) = 0,
//     starting from (0.5, 0.5).
//   - 2-CP chain (degenerate stem): t_branch = 0.5; pp/cp/np built as
//     a straight line so the rasterizer's is_line path takes over.
//   - One-sided clamped Bezier: closed-form cubic project of the
//     interior B-spline midpoint onto the clamped span.
//   - Else: t_branch = 0.5.
//
// Cost: ~once-per-frame O(num_cps) work — 3 fragments per CP slot, so
// 6·corners_w·corners_h fragments total. Drops per-pixel work in the
// rasterizer's test_one_cp from ~6 fetches + ghost construction +
// cubic/Newton solve down to 4 fetches (1 flag + 3 packed reads).
//
// resolve_hit still needs neighbor flags/dirs for color resolution, so
// the neighbor indices stay encoded in the B channels of texels 0/2.

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
int NUM_CPS()  { return CORNERS_W() * CORNERS_H() * 2; }

const uint IS_CROSSING = 64u;
const uint IS_ENDPOINT = 128u;

void decode_cp(int cp_idx, out int cx, out int cy_slot) {
    int cp_half = cp_idx / 2;
    int cp_slot = cp_idx & 1;
    cx = cp_half % CORNERS_W();
    int cy = cp_half / CORNERS_W();
    cy_slot = cy * 2 + cp_slot;
}

vec2 read_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(0.0);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    return texelFetch(FinalPositions, ivec2(cx, cy_slot), 0).rg;
}

// ---- B-spline curve-curve intersection (2D Newton) ----
//
// Solves F(t, s) = B_a(t) - B_b(s) = 0 from (t, s) = (0.5, 0.5). The
// optimizer keeps crossings near the grid corner so the initial guess
// is within ~0.1 of the answer; quadratic Newton convergence drives
// the residual below f32 epsilon in 3 iterations (4 for safety).
// Returns vec2(t_a, t_b).
//
// Each step: J·Δ = -F where J is the 2×2 partial-derivative matrix
//   J11 = ∂Fx/∂t = 2·aa.x·t + ba.x       J12 = ∂Fx/∂s = -(2·ab.x·s + bb.x)
//   J21 = ∂Fy/∂t = 2·aa.y·t + ba.y       J22 = ∂Fy/∂s = -(2·ab.y·s + bb.y)
// Inverted analytically. The early-break guard on |det(J)| < 1e-12
// is the tangent / parallel-curves case; in practice the pipeline
// guarantees a real crossing so this never fires, but it keeps the
// shader well-defined if a degenerate input ever shows up.
vec2 bspline_intersect(vec2 a_p0, vec2 a_p1, vec2 a_p2,
                       vec2 b_p0, vec2 b_p1, vec2 b_p2) {
    vec2 aa = 0.5 * a_p0 - a_p1 + 0.5 * a_p2;
    vec2 ba = -a_p0 + a_p1;
    vec2 ca = 0.5 * a_p0 + 0.5 * a_p1;
    vec2 ab = 0.5 * b_p0 - b_p1 + 0.5 * b_p2;
    vec2 bb = -b_p0 + b_p1;
    vec2 cb = 0.5 * b_p0 + 0.5 * b_p1;

    float t = 0.5;
    float s = 0.5;
    for (int iter = 0; iter < 4; iter++) {
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
    }
    return vec2(clamp(t, 0.0, 1.0), clamp(s, 0.0, 1.0));
}

int decode_neighbor(vec4 val) {
    if (val.r < -0.5) return -1;
    int ncx = int(val.r + 0.5);
    int ncy = int(val.g + 0.5);
    int nslot = int(val.b + 0.5);
    return (ncy * CORNERS_W() + ncx) * 2 + nslot;
}

uint read_flags(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return 0u;
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    return uint(texelFetch(CellGraph, ivec2(cx, base_row), 0).b + 0.5);
}

// Closest-point cubic solver — must match cell-rasterizer.slang's
// closest_on_span exactly so that t_branch values agree with what the
// rasterizer would compute. Inlined here because pack-positions runs once
// per frame (cheap) while the rasterizer runs per pixel.
float span_closest_t(vec2 p0, vec2 p1, vec2 p2, vec2 pt) {
    vec2 a = 0.5 * (p0 - 2.0 * p1 + p2);
    vec2 b = p1 - p0;
    vec2 e = 0.5 * (p0 + p1) - pt;

    float c3 = 2.0 * dot(a, a);
    float c2 = 3.0 * dot(a, b);
    float c1 = 2.0 * dot(a, e) + dot(b, b);
    float c0 = dot(b, e);

    #define EVAL_D2(t) dot((a*(t)+b)*(t)+e, (a*(t)+b)*(t)+e)
    float d0 = EVAL_D2(0.0);
    float d1 = EVAL_D2(1.0);
    float best_d2 = d0; float best_t = 0.0;
    if (d1 < best_d2) { best_d2 = d1; best_t = 1.0; }

    if (abs(c3) < 1e-12) {
        if (abs(c2) > 1e-12) {
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
        float inv3a = 1.0 / (3.0 * c3);
        float shift = -c2 * inv3a;
        float p = (3.0*c3*c1 - c2*c2) / (3.0*c3*c3);
        float q = (2.0*c2*c2*c2 - 9.0*c3*c2*c1 + 27.0*c3*c3*c0) / (27.0*c3*c3*c3);
        float disc = q*q/4.0 + p*p*p/27.0;

        if (disc > 1e-12) {
            float sq = sqrt(disc);
            float hq = -q * 0.5;
            float u1 = sign(hq+sq) * pow(abs(hq+sq), 1.0/3.0);
            float u2 = sign(hq-sq) * pow(abs(hq-sq), 1.0/3.0);
            float t1 = u1 + u2 + shift;
            if (t1 > 0.0 && t1 < 1.0) { float dd = EVAL_D2(t1); if (dd < best_d2) { best_d2 = dd; best_t = t1; } }
        } else {
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
    return best_t;
}

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);

    // Decode (cx, slot_within_cp, cy_slot) from the output coordinate.
    // The texture is 3*corners_w wide, so column = cx*3 + which_pos.
    int which_pos = opos.x % 3;             // 0=pp, 1=cp, 2=np
    int cx = opos.x / 3;
    int cy_slot = opos.y;

    if (cx >= CORNERS_W() || cy_slot >= CORNERS_H() * 2) {
        FragColor = vec4(0.0);
        return;
    }

    int cy = cy_slot / 2;
    int slot = cy_slot & 1;
    int ci = (cy * CORNERS_W() + cx) * 2 + slot;

    // Read flags + neighbors. Inactive CPs write zeros — the rasterizer
    // already skips them via its own flag check.
    uint flag = read_flags(ci);
    if (flag == 0u) {
        FragColor = vec4(0.0);
        return;
    }

    int base_row = cy_slot * 3;
    int prev_ci = decode_neighbor(texelFetch(CellGraph, ivec2(cx, base_row + 1), 0));
    int next_ci = decode_neighbor(texelFetch(CellGraph, ivec2(cx, base_row + 2), 0));

    // CPs with no neighbors (e.g. fully-isolated chain endpoints owned by
    // someone else's clamped extension) — write zeros.
    if (prev_ci < 0 && next_ci < 0) {
        FragColor = vec4(0.0);
        return;
    }

    // 2-CP-chain detection: both ends are endpoint markers and we own the
    // span. Only the lower-indexed endpoint renders. Mirror the
    // rasterizer's existing logic so the packed geometry matches what
    // test_one_cp would have constructed.
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
        // Render as a straight line between the two markers. Pick
        // p0=(3·a0-a1)/2, p1=midpoint, p2=(3·a1-a0)/2 so beval gives
        // B(t)=lerp(a0,a1,t). Closest-point queries dispatch to a line
        // solver via is_line in the rasterizer.
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

    // t_branch: rasterizer's branch threshold between prev_dir and
    // next_dir for color resolution. Mirrors test_one_cp's logic.
    //
    // Crossings: solve the curve-curve intersection inline (Newton
    // iteration on F(t,s) = B_a(t) - B_b(s) = 0). Need both this slot's
    // own neighbors and the partner slot's neighbors — slot 0 holds
    // the N-S chain, slot 1 holds E-W. cp_a and cp_b are the same
    // physical position (both slots of a crossing are co-located).
    float t_branch;
    if ((flag & IS_CROSSING) != 0u) {
        // Read partner-slot neighbor indices (partner is at cy_slot ^ 1
        // within the same cx column).
        int p_base_row = (cy_slot ^ 1) * 3;
        int p_prev = decode_neighbor(texelFetch(CellGraph, ivec2(cx, p_base_row + 1), 0));
        int p_next = decode_neighbor(texelFetch(CellGraph, ivec2(cx, p_base_row + 2), 0));

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
        // One-sided clamped Bezier: parameterization is shifted, so the
        // t at which the rendered curve reaches the symmetric
        // "before/after sc" location of an interior span isn't 0.5.
        // Project the interior-span midpoint onto the clamped span.
        vec2 interior_mid = 0.125 * pp + 0.75 * cp + 0.125 * np;
        t_branch = span_closest_t(pp, cp, np, interior_mid);
    } else {
        t_branch = 0.5;
    }

    float validity = two_cp_chain ? 2.0 : 1.0;
    float prev_ci_f = (prev_ci < 0) ? -1.0 : float(prev_ci);
    float next_ci_f = (next_ci < 0) ? -1.0 : float(next_ci);

    vec4 out_texel;
    if (which_pos == 0)      out_texel = vec4(pp.x, pp.y, prev_ci_f, 0.0);
    else if (which_pos == 1) out_texel = vec4(cp.x, cp.y, t_branch,  validity);
    else                     out_texel = vec4(np.x, np.y, next_ci_f, 0.0);
    FragColor = out_texel;
}
