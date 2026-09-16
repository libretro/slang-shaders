#version 450
#pragma format R32G32B32A32_SFLOAT

// Simple-energy optimizer. 2D Newton-Raphson on
//   E = |p0 - 2p + p2|² + (2.5·‖p − p_orig‖)⁴
// Analytical gradient + Hessian, NEWTON_ITER iters per pass.
//
// Inputs: Source (current positions), CellGraph (orig + neighbors + flags).
// Output: (R=pos.x, G=pos.y, B=0, A=0).

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

layout(set = 0, binding = 2) uniform sampler2D Source;    // previous pass (current positions)
layout(set = 0, binding = 3) uniform sampler2D CellGraph; // pass 3 (orig positions + neighbors + flags)

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_H() << 12;  /* bit-packed encoding: cy < CH means cp_idx < CH<<12 */ }

const uint IS_CORNER = 16u;
const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING = 64u;

const float POSITIONAL_SCALE = 2.5;
const int NEWTON_ITER = 3;

// Bit-packed CP encoding — see cell-rasterizer-single-aa.slang.
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

// Neighbor pos, using stem-corrected position for T-junctions.
vec2 read_neighbor_pos(int idx) {
    if (idx < 0 || idx >= NUM_CPS()) return vec2(0.0);
    uint f = read_flags(idx);
    if ((f & IS_TJUNCTION) != 0u) {
        int ci = idx + 1;
        if (ci < NUM_CPS()) {
            vec2 p = read_pos(ci);
            if (p.x != 0.0 || p.y != 0.0) return p;
        }
    }
    return read_pos(idx);
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

    // Crossing slot-1 redirect: slot 1 is the same physical node as
    // slot 0. Running Newton independently per slot drifts them apart
    // by ulp/step due to FP non-associativity, breaking the rasterizer's
    // t_branch invariant. Slot 1's fragment must compute slot 0's update
    // byte-for-byte.
    uint flags_self = read_flags(i_self);
    bool is_crossing = (flags_self & IS_CROSSING) != 0u;
    int i = (is_crossing && cp_slot == 1) ? (i_self - 1) : i_self;

    vec2 p = read_pos(i);
    vec2 p_orig = read_orig_pos(i);

    uint flags = read_flags(i);

    if (flags == 0u || (flags & 1u) != 0u) {
        FragColor = vec4(p.x, p.y, 0.0, 0.0);
        return;
    }

    ivec2 nbrs = read_neighbors(i);
    int prev_idx = nbrs.x;
    int next_idx = nbrs.y;

    if (prev_idx < 0 || next_idx < 0) {
        FragColor = vec4(p.x, p.y, 0.0, 0.0);
        return;
    }

    vec2 n0 = read_neighbor_pos(prev_idx);
    vec2 n1 = read_neighbor_pos(next_idx);

    // Crossings: combined curvature from both chains. The slot-1
    // redirect above guarantees i is slot 0 here, so the partner is i+1.
    vec2 n2 = vec2(0.0);
    vec2 n3 = vec2(0.0);
    if (is_crossing) {
        int other = i + 1;
        ivec2 other_nbrs = read_neighbors(other);
        if (other_nbrs.x >= 0) n2 = read_neighbor_pos(other_nbrs.x);
        if (other_nbrs.y >= 0) n3 = read_neighbor_pos(other_nbrs.y);
    }

    // Corners keep only positional energy.
    bool exclude_curvature = (flags & IS_CORNER) != 0u;

    float s4 = POSITIONAL_SCALE * POSITIONAL_SCALE;
    s4 *= s4;

    for (int iter = 0; iter < NEWTON_ITER; iter++) {
        vec2 d = p - p_orig;
        float d2 = dot(d, d);

        vec2 grad_curv = 4.0 * (2.0 * p - n0 - n1);
        if (is_crossing) grad_curv += 4.0 * (2.0 * p - n2 - n3);
        vec2 grad_pos = 4.0 * s4 * d2 * d;
        vec2 grad = exclude_curvature ? grad_pos : (grad_curv + grad_pos);

        float curv_h = exclude_curvature ? 0.0 : (is_crossing ? 16.0 : 8.0);
        float h00 = curv_h + 4.0 * s4 * (2.0 * d.x * d.x + d2);
        float h11 = curv_h + 4.0 * s4 * (2.0 * d.y * d.y + d2);
        float h01 = 8.0 * s4 * d.x * d.y;

        float det = h00 * h11 - h01 * h01;
        if (abs(det) < 1e-20) break;

        p -= vec2(h11 * grad.x - h01 * grad.y,
                  -h01 * grad.x + h00 * grad.y) / det;
    }

    FragColor = vec4(p.x, p.y, 0.0, 0.0);
}
