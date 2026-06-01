#version 450
#extension GL_EXT_control_flow_attributes : enable
#pragma format R32G32B32A32_SFLOAT

// Per-CP Picard step: 2D Newton on the local θ² + positional energy
// around p_i, holding neighbors fixed. Mirrors the CPU `optimize_one_pass`
// in vibeboy/src/scaling/vectorize.rs.
//
// Energy = E_curvature + E_positional
//   E_curvature: sum of θ²/2 over the ≤3 quadratic-spline segments
//     touching p_i (θ = atan2(va×vb, va·vb)). Plus the second chain at
//     crossings and stem-via-ghost coupling at T-junctions.
//   E_positional: (POSITIONAL_SCALE · ‖p − p_orig‖)⁴.
//
// Single Newton step capped at MAX_STEP px (trust region). Output: RG only.
//
// The host preset runs this followed by gradient-correction.slang per
// outer iter.
//
// Register-pressure invariants (do not refactor away):
//   - Segment helpers compute only (g, H); there is no energy consumer.
//   - Crossing and stem-coupling code lives inside its own branch so
//     the non-special path doesn't carry the register state.

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

layout(set = 0, binding = 2) uniform sampler2D Source;    // current positions (RG)
layout(set = 0, binding = 3) uniform sampler2D CellGraph; // orig pos + neighbors + flags

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_H() << 12;  /* bit-packed encoding: cy < CH means cp_idx < CH<<12 */ }

const uint IS_CORNER    = 16u;
const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING  = 64u;
const uint IS_ENDPOINT  = 128u;

const float POSITIONAL_SCALE = 2.5;
// One inner Newton iter per outer pass; additional iters overshoot the
// Gauss-Seidel fixed point and slightly hurt converged energy.

// CP data accessors. Row-interleaved slot — see cell-rasterizer-single-aa.slang.
ivec2 decode_cp(int cp_idx) {
    int cp_slot = cp_idx & 1;
    int cx = (cp_idx >> 1) & 0x7FF;
    int cy = cp_idx >> 12;
    return ivec2(cx, (cy << 1) | cp_slot);
}

vec2 read_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(0.0);
    return texelFetch(Source, decode_cp(cp_idx), 0).rg;
}

// Compact CellGraph: 1 texel per CP. See cell-graph.slang for layout.
vec4 read_cg(int cp_idx) {
    return texelFetch(CellGraph, decode_cp(cp_idx), 0);
}

int unpack_idx(uint v) {
    return (v == 0xFFFFFFu) ? -1 : int(v);
}

vec2 read_orig_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(0.0);
    return read_cg(cp_idx).rg;
}

ivec2 read_neighbors(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return ivec2(-1, -1);
    vec4 val = read_cg(cp_idx);
    uint pv = floatBitsToUint(val.b) & 0xFFFFFFu;
    uint nv = floatBitsToUint(val.a) & 0xFFFFFFu;
    return ivec2(unpack_idx(pv), unpack_idx(nv));
}

uint read_flags(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return 0u;
    return (floatBitsToUint(read_cg(cp_idx).b) >> 24) & 0xFFu;
}

// Ghost-extension B-spline weights, returned as (sp, st, sn).
vec3 ghost_weights(bool prev_is_end, bool next_is_end) {
    if (prev_is_end && next_is_end) return vec3(0.25,  0.5,   0.25);
    if (prev_is_end)                return vec3(0.25,  0.625, 0.125);
    if (next_is_end)                return vec3(0.125, 0.625, 0.25);
    return                                 vec3(0.125, 0.75,  0.125);
}

// T-junction ghost: stem CPs read as the ghost-snapped position
// synthesized from T's through-pair, not their stored position.
// Bit 0 of flags is JUNCTION; a CP is a stem iff JUNCTION is set AND
// the CP at index-1 is a T-junction.
vec2 read_neighbor_pos(int idx) {
    if (idx <= 0 || idx >= NUM_CPS()) return read_pos(idx);
    uint f = read_flags(idx);
    if ((f & 1u) != 0u && (read_flags(idx - 1) & IS_TJUNCTION) != 0u) {
        int t = idx - 1;
        ivec2 t_nbrs = read_neighbors(t);
        if (t_nbrs.x >= 0 && t_nbrs.y >= 0) {
            bool prev_is_end = (read_flags(t_nbrs.x) & IS_ENDPOINT) != 0u;
            bool next_is_end = (read_flags(t_nbrs.y) & IS_ENDPOINT) != 0u;
            vec3 w = ghost_weights(prev_is_end, next_is_end);
            return w.x * read_pos(t_nbrs.x) + w.y * read_pos(t) + w.z * read_pos(t_nbrs.y);
        }
    }
    return read_pos(idx);
}

int grandneighbor_idx(int via, int back) {
    if (via < 0) return -1;
    if ((read_flags(via) & IS_CORNER) != 0u) return -1;
    ivec2 vn = read_neighbors(via);
    return (vn.x == back) ? vn.y : vn.x;
}

// Result of resolving a T-junction stem to its two physical endpoints.
// `valid` distinguishes the success case from the "stem has no chain
// partner" failure.
struct StemPoints { vec2 s; vec2 so; bool valid; };

StemPoints stem_endpoints(int t) {
    StemPoints r;
    r.s = vec2(0.0); r.so = vec2(0.0); r.valid = false;
    int s_idx = read_neighbors(t + 1).x;
    if (s_idx < 0) return r;
    ivec2 sn = read_neighbors(s_idx);
    int so = (sn.x == t + 1) ? sn.y : sn.x;
    if (so < 0) return r;
    r.s = read_pos(s_idx);
    r.so = read_neighbor_pos(so);
    r.valid = true;
    return r;
}

// SegMode: 0 full | 1 left half | 2 right half | 3 skip.
int seg_mode(bool center_corner, bool left_corner, bool right_corner) {
    if (center_corner) return 3;
    if (left_corner && right_corner) return 3;
    if (left_corner) return 2;
    if (right_corner) return 1;
    return 0;
}

// Polynomial atan2, accuracy ~1e-3. Curvature energy is θ²/2 so the
// errors square down further — safe in this context.
float fast_atan2(float y, float x) {
    float ax = abs(x), ay = abs(y);
    float a = min(ax, ay) / (max(ax, ay) + 1e-30);
    float s = a * a;
    float r = ((-0.0464964749 * s + 0.15931422) * s - 0.327622764) * s * a + a;
    if (ay > ax) r = 1.5707963 - r;
    if (x < 0.0)  r = 3.1415927 - r;
    return (y < 0.0) ? -r : r;
}

// Full-segment add (mode==0). Accumulates (g, H) only.
void add_segment_full(vec2 va, vec2 vb, float s_va, float s_vb,
                      inout vec2 g,
                      inout float h00, inout float h01, inout float h11) {
    float cross_v = va.x * vb.y - va.y * vb.x;
    float dot_v   = va.x * vb.x + va.y * vb.y;
    float theta = fast_atan2(cross_v, dot_v);
    float inv_lva2 = 1.0 / max(va.x * va.x + va.y * va.y, 1e-20);
    float inv_lvb2 = 1.0 / max(vb.x * vb.x + vb.y * vb.y, 1e-20);
    float dtheta_dpx = s_va * (va.y * inv_lva2) + s_vb * (-vb.y * inv_lvb2);
    float dtheta_dpy = s_va * (-va.x * inv_lva2) + s_vb * (vb.x * inv_lvb2);
    g.x += theta * dtheta_dpx;
    g.y += theta * dtheta_dpy;
    h00 += dtheta_dpx * dtheta_dpx;
    h01 += dtheta_dpx * dtheta_dpy;
    h11 += dtheta_dpy * dtheta_dpy;
}

// Half-segment-aware add. Used for the 3 main segments touching p
// where adjacent corners may need exclusion.
void add_segment_mode(int mode, vec2 va, vec2 vb, float s_va, float s_vb,
                      inout vec2 g,
                      inout float h00, inout float h01, inout float h11) {
    if (mode == 3) return;
    if (mode == 1) {
        vb = 0.5 * (va + vb);
        s_vb = 0.5 * (s_va + s_vb);
    } else if (mode == 2) {
        va = 0.5 * (va + vb);
        s_va = 0.5 * (s_va + s_vb);
    }
    add_segment_full(va, vb, s_va, s_vb, g, h00, h01, h11);
}

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);
    int col = opos.x;
    int cy_slot = opos.y;

    if (col >= CORNERS_W() || cy_slot >= CORNERS_H() * 2) {
        FragColor = vec4(0.0);
        return;
    }

    int cp_slot = cy_slot & 1;
    int cy = cy_slot >> 1;
    int i_self = (cy << 12) | (col << 1) | cp_slot;

    // Crossing slot-1 redirect: slot 1 of a crossing is the same physical
    // node as slot 0. Running Newton independently per slot drifts them
    // apart by ulp/step due to FP non-associativity, breaking the
    // rasterizer's t_branch invariant. Slot 1's fragment must compute
    // slot 0's update byte-for-byte.
    int cy_slot_self_for_flags = cy_slot;
    uint flags_self = (floatBitsToUint(
        texelFetch(CellGraph, ivec2(col, cy_slot_self_for_flags), 0).b) >> 24) & 0xFFu;
    bool is_crossing_self = (flags_self & IS_CROSSING) != 0u;
    if (is_crossing_self && cp_slot == 1) {
        cy_slot -= 1;
        cp_slot = 0;
    }
    int i = (cy << 12) | (col << 1) | cp_slot;

    vec2 starting_p = texelFetch(Source, ivec2(col, cy_slot), 0).rg;
    vec4 my_cg = texelFetch(CellGraph, ivec2(col, cy_slot), 0);
    uint my_b = floatBitsToUint(my_cg.b);
    uint my_a = floatBitsToUint(my_cg.a);
    vec2 p_orig = my_cg.rg;
    uint flags = (my_b >> 24) & 0xFFu;

    if (flags == 0u || (flags & 1u) != 0u) {
        FragColor = vec4(starting_p.x, starting_p.y, 0.0, 0.0);
        return;
    }

    int prev_idx = unpack_idx(my_b & 0xFFFFFFu);
    int next_idx = unpack_idx(my_a & 0xFFFFFFu);
    if (prev_idx < 0 || next_idx < 0) {
        FragColor = vec4(starting_p.x, starting_p.y, 0.0, 0.0);
        return;
    }

    ivec2 prev_xy = decode_cp(prev_idx);
    vec4 prev_cg = texelFetch(CellGraph, prev_xy, 0);
    uint prev_b = floatBitsToUint(prev_cg.b);
    uint prev_a = floatBitsToUint(prev_cg.a);
    uint prev_flags = (prev_b >> 24) & 0xFFu;
    int prev_pp_idx = unpack_idx(prev_b & 0xFFFFFFu);
    int prev_nn_idx = unpack_idx(prev_a & 0xFFFFFFu);

    ivec2 next_xy = decode_cp(next_idx);
    vec4 next_cg = texelFetch(CellGraph, next_xy, 0);
    uint next_b = floatBitsToUint(next_cg.b);
    uint next_a = floatBitsToUint(next_cg.a);
    uint next_flags = (next_b >> 24) & 0xFFu;
    int next_pp_idx = unpack_idx(next_b & 0xFFFFFFu);
    int next_nn_idx = unpack_idx(next_a & 0xFFFFFFu);

    // Ghost-aware position. A CP is a stem iff JUNCTION (bit 0) is set
    // AND its index-1 CP is a T-junction; the common JUNCTION-clear
    // case short-circuits without an extra flag fetch.
    vec2 n0 = texelFetch(Source, prev_xy, 0).rg;
    if ((prev_flags & 1u) != 0u && prev_idx > 0
        && (read_flags(prev_idx - 1) & IS_TJUNCTION) != 0u) {
        int t = prev_idx - 1;
        ivec2 t_nbrs = read_neighbors(t);
        if (t_nbrs.x >= 0 && t_nbrs.y >= 0) {
            bool pe = (read_flags(t_nbrs.x) & IS_ENDPOINT) != 0u;
            bool ne = (read_flags(t_nbrs.y) & IS_ENDPOINT) != 0u;
            float sp_g, st_g, sn_g;
            if (pe && ne)      { sp_g = 0.25;  st_g = 0.5;   sn_g = 0.25; }
            else if (pe)       { sp_g = 0.25;  st_g = 0.625; sn_g = 0.125; }
            else if (ne)       { sp_g = 0.125; st_g = 0.625; sn_g = 0.25; }
            else               { sp_g = 0.125; st_g = 0.75;  sn_g = 0.125; }
            n0 = sp_g * read_pos(t_nbrs.x) + st_g * read_pos(t) + sn_g * read_pos(t_nbrs.y);
        }
    }
    vec2 n1 = texelFetch(Source, next_xy, 0).rg;
    if ((next_flags & 1u) != 0u && next_idx > 0
        && (read_flags(next_idx - 1) & IS_TJUNCTION) != 0u) {
        int t = next_idx - 1;
        ivec2 t_nbrs = read_neighbors(t);
        if (t_nbrs.x >= 0 && t_nbrs.y >= 0) {
            bool pe = (read_flags(t_nbrs.x) & IS_ENDPOINT) != 0u;
            bool ne = (read_flags(t_nbrs.y) & IS_ENDPOINT) != 0u;
            float sp_g, st_g, sn_g;
            if (pe && ne)      { sp_g = 0.25;  st_g = 0.5;   sn_g = 0.25; }
            else if (pe)       { sp_g = 0.25;  st_g = 0.625; sn_g = 0.125; }
            else if (ne)       { sp_g = 0.125; st_g = 0.625; sn_g = 0.25; }
            else               { sp_g = 0.125; st_g = 0.75;  sn_g = 0.125; }
            n1 = sp_g * read_pos(t_nbrs.x) + st_g * read_pos(t) + sn_g * read_pos(t_nbrs.y);
        }
    }

    bool self_corner = (flags & IS_CORNER) != 0u;
    bool prev_corner = (prev_flags & IS_CORNER) != 0u;
    bool next_corner = (next_flags & IS_CORNER) != 0u;

    int gprev_idx = prev_corner ? -1 : ((prev_pp_idx == i) ? prev_nn_idx : prev_pp_idx);
    int gnext_idx = next_corner ? -1 : ((next_pp_idx == i) ? next_nn_idx : next_pp_idx);
    bool gprev_corner = gprev_idx >= 0 && (read_flags(gprev_idx) & IS_CORNER) != 0u;
    bool gnext_corner = gnext_idx >= 0 && (read_flags(gnext_idx) & IS_CORNER) != 0u;

    // Per-segment mode (0=full, 1=left half, 2=right half, 3=skip)
    // packed into one uint:
    //   bits 0-1: mode_self
    //   bits 2-3: mode_e_prev
    //   bits 4-5: mode_e_next
    uint state = uint(seg_mode(self_corner, prev_corner, next_corner))
               | (uint((gprev_idx < 0) ? 3 : seg_mode(prev_corner, gprev_corner, self_corner)) << 2)
               | (uint((gnext_idx < 0) ? 3 : seg_mode(next_corner, self_corner, gnext_corner)) << 4);

    // p-independent segment partials. va_prev_const = va of θ_{i-1};
    // vb_next_const = vb of θ_{i+1}. Drops nn0/nn1 from registers.
    vec2 va_prev_const = vec2(0.0);
    vec2 vb_next_const = vec2(0.0);
    if (((state >> 2) & 3u) != 3u) {
        va_prev_const = n0 - read_neighbor_pos(gprev_idx);
    }
    if (((state >> 4) & 3u) != 3u) {
        vb_next_const = read_neighbor_pos(gnext_idx) - n1;
    }

    const float s4 = POSITIONAL_SCALE * POSITIONAL_SCALE
                   * POSITIONAL_SCALE * POSITIONAL_SCALE; // 39.0625

    vec2 p = starting_p;
    vec2 g_ = vec2(0.0);
    float h00 = 0.0, h01 = 0.0, h11 = 0.0;

    int m_self   = int(state & 3u);
    int m_e_prev = int((state >> 2) & 3u);
    int m_e_next = int((state >> 4) & 3u);

    // Three main segments touching p (corner-aware modes).
    if (m_e_prev != 3) {
        add_segment_mode(m_e_prev, va_prev_const, p - n0, 0.0, 1.0,
                         g_, h00, h01, h11);
    }
    if (m_self != 3) {
        add_segment_mode(m_self, p - n0, n1 - p, 1.0, -1.0,
                         g_, h00, h01, h11);
    }
    if (m_e_next != 3) {
        add_segment_mode(m_e_next, n1 - p, vb_next_const, -1.0, 0.0,
                         g_, h00, h01, h11);
    }

    // Crossing's second chain. Kept inside the branch so non-crossing
    // CPs don't carry its register state.
    if ((flags & IS_CROSSING) != 0u) {
        int other = (cp_slot == 0) ? i + 1 : i - 1;
        ivec2 cn = read_neighbors(other);
        int c_prev_idx = cn.x;
        int c_next_idx = cn.y;
        bool other_not_corner = (read_flags(other) & IS_CORNER) == 0u;
        bool c_inc_prev = c_prev_idx >= 0 && (read_flags(c_prev_idx) & IS_CORNER) == 0u;
        bool c_inc_next = c_next_idx >= 0 && (read_flags(c_next_idx) & IS_CORNER) == 0u;
        vec2 c_n0 = (c_prev_idx >= 0) ? read_neighbor_pos(c_prev_idx) : vec2(0.0);
        vec2 c_n1 = (c_next_idx >= 0) ? read_neighbor_pos(c_next_idx) : vec2(0.0);

        if (c_inc_prev) {
            int c_gprev = grandneighbor_idx(c_prev_idx, other);
            if (c_gprev >= 0) {
                vec2 c_va_prev_const = c_n0 - read_neighbor_pos(c_gprev);
                add_segment_full(c_va_prev_const, p - c_n0, 0.0, 1.0,
                                 g_, h00, h01, h11);
            }
        }
        if (other_not_corner) {
            add_segment_full(p - c_n0, c_n1 - p, 1.0, -1.0,
                             g_, h00, h01, h11);
        }
        if (c_inc_next) {
            int c_gnext = grandneighbor_idx(c_next_idx, other);
            if (c_gnext >= 0) {
                vec2 c_vb_next_const = read_neighbor_pos(c_gnext) - c_n1;
                add_segment_full(c_n1 - p, c_vb_next_const, -1.0, 0.0,
                                 g_, h00, h01, h11);
            }
        }
    }

    // Stem coupling. Each case's data is local to its if-block to keep
    // the non-stem path off the hook.
    // Case A: i is a T-junction itself.
    if ((flags & IS_TJUNCTION) != 0u) {
        StemPoints sp_a = stem_endpoints(i);
        if (sp_a.valid) {
            bool pe = (prev_flags & IS_ENDPOINT) != 0u;
            bool ne = (next_flags & IS_ENDPOINT) != 0u;
            vec3 w = ghost_weights(pe, ne);
            float sp = w.x, st = w.y, sn = w.z;
            vec2 va = sp_a.s - sp_a.so;
            vec2 vb = sp * n0 + sn * n1 - sp_a.s + st * p;
            add_segment_full(va, vb, 0.0, st, g_, h00, h01, h11);
        }
    }
    // Case B[0]: prev is a T-junction with i in its through-pair.
    if ((prev_flags & IS_TJUNCTION) != 0u
        && prev_pp_idx >= 0 && prev_nn_idx >= 0) {
        bool jpe = (read_flags(prev_pp_idx) & IS_ENDPOINT) != 0u;
        bool jne = (read_flags(prev_nn_idx) & IS_ENDPOINT) != 0u;
        vec3 w = ghost_weights(jpe, jne);
        float sp = w.x, st = w.y, sn = w.z;
        float p_coef = 0.0;
        vec2 ghost_const = vec2(0.0);
        if (prev_pp_idx == i || prev_nn_idx == i) {
            vec2 p_t = texelFetch(Source, prev_xy, 0).rg;
            if (prev_pp_idx == i) {
                p_coef = sp;
                ghost_const = st * p_t + sn * read_neighbor_pos(prev_nn_idx);
            } else {
                p_coef = sn;
                ghost_const = sp * read_neighbor_pos(prev_pp_idx) + st * p_t;
            }
        }
        if (p_coef != 0.0) {
            StemPoints sp_b = stem_endpoints(prev_idx);
            if (sp_b.valid) {
                vec2 va = sp_b.s - sp_b.so;
                vec2 vb = ghost_const - sp_b.s + p_coef * p;
                add_segment_full(va, vb, 0.0, p_coef, g_, h00, h01, h11);
            }
        }
    }
    // Case B[1]: next is a T-junction with i in its through-pair.
    if ((next_flags & IS_TJUNCTION) != 0u
        && next_pp_idx >= 0 && next_nn_idx >= 0) {
        bool jpe = (read_flags(next_pp_idx) & IS_ENDPOINT) != 0u;
        bool jne = (read_flags(next_nn_idx) & IS_ENDPOINT) != 0u;
        vec3 w = ghost_weights(jpe, jne);
        float sp = w.x, st = w.y, sn = w.z;
        float p_coef = 0.0;
        vec2 ghost_const = vec2(0.0);
        if (next_pp_idx == i || next_nn_idx == i) {
            vec2 p_t = texelFetch(Source, next_xy, 0).rg;
            if (next_pp_idx == i) {
                p_coef = sp;
                ghost_const = st * p_t + sn * read_neighbor_pos(next_nn_idx);
            } else {
                p_coef = sn;
                ghost_const = sp * read_neighbor_pos(next_pp_idx) + st * p_t;
            }
        }
        if (p_coef != 0.0) {
            StemPoints sp_c = stem_endpoints(next_idx);
            if (sp_c.valid) {
                vec2 va = sp_c.s - sp_c.so;
                vec2 vb = ghost_const - sp_c.s + p_coef * p;
                add_segment_full(va, vb, 0.0, p_coef, g_, h00, h01, h11);
            }
        }
    }

    // Positional energy contribution.
    vec2 d = p - p_orig;
    float d2 = dot(d, d);
    g_.x += 4.0 * s4 * d2 * d.x;
    g_.y += 4.0 * s4 * d2 * d.y;
    h00 += 4.0 * s4 * (2.0 * d.x * d.x + d2);
    h11 += 4.0 * s4 * (2.0 * d.y * d.y + d2);
    h01 += 8.0 * s4 * d.x * d.y;

    // Newton step with branchless rank-1 fallback.
    float det = h00 * h11 - h01 * h01;
    bool low_rank = abs(det) < 1e-6;
    float trace = max(h00 + h11, 1e-20);
    float inv_trace = 1.0 / trace;
    float inv_det = 1.0 / (low_rank ? 1.0 : det);
    float dx_lr = -g_.x * inv_trace;
    float dy_lr = -g_.y * inv_trace;
    float dx_fr = -(h11 * g_.x - h01 * g_.y) * inv_det;
    float dy_fr = -(-h01 * g_.x + h00 * g_.y) * inv_det;
    float dx = low_rank ? dx_lr : dx_fr;
    float dy = low_rank ? dy_lr : dy_fr;

    // Magnitude cap (trust region).
    const float MAX_STEP = 0.10;
    float step_len2 = dx * dx + dy * dy;
    if (step_len2 > MAX_STEP * MAX_STEP) {
        float s = MAX_STEP / sqrt(step_len2);
        dx *= s;
        dy *= s;
    }
    p = p + vec2(dx, dy);

    FragColor = vec4(p.x, p.y, 0.0, 0.0);
}
