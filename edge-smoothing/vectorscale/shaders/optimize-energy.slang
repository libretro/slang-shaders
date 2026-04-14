#version 450
#pragma format R32G32B32A32_SFLOAT

// Optimizer pass: 2D Newton-Raphson for B-spline control point smoothing.
//
// Energy: E_curvature (|p0 - 2p + p2|²) + E_positional ((2.5·dist)⁴).
// Both gradient and Hessian are analytical, so Newton converges in 2-3
// iterations vs the ~120 energy evaluations the old golden section search
// needed.
//
// Stores absolute positions in F32 framebuffers.
//
// Input textures:
//   Source (previous pass): current absolute positions
//   CellGraph (pass 3): original positions + neighbors + flags
//
// Output: (R=pos.x, G=pos.y, B=0, A=0)

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
int NUM_CPS()  { return CORNERS_W() * CORNERS_H() * 2; }

const uint IS_CORNER = 16u;
const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING = 64u;

const float POSITIONAL_SCALE = 2.5;
const int NEWTON_ITER = 3;

// Decode CP index into (cx, cy_slot) where cy_slot = cy * 2 + slot.
void decode_cp(int cp_idx, out int cx, out int cy_slot) {
    int cp_half = cp_idx / 2;
    int cp_slot = cp_idx & 1;
    cx = cp_half % CORNERS_W();
    int cy = cp_half / CORNERS_W();
    cy_slot = cy * 2 + cp_slot;
}

// Read current absolute position from Source texture.
vec2 read_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(0.0);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    vec4 val = texelFetch(Source, ivec2(cx, cy_slot), 0);
    return vec2(val.r, val.g);
}

// Read original position from cell graph texture (row offset 0).
vec2 read_orig_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(0.0);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 val = texelFetch(CellGraph, ivec2(cx, base_row), 0);
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

// Read neighbor position, using corrected position for T-junctions.
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

// No energy/gradient/bracket functions needed — Newton uses inline
// analytical gradient and Hessian.

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);
    int col = opos.x;
    int cy_slot = opos.y;

    if (col >= CORNERS_W() || cy_slot >= CORNERS_H() * 2) {
        FragColor = vec4(0.0);
        return;
    }

    int cy = cy_slot / 2;
    int cp_slot = cy_slot % 2;
    int i = (cy * CORNERS_W() + col) * 2 + cp_slot;

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

    // Skip non-crossing nodes adjacent to crossings (crossing position
    // depends on all 4 neighbors; optimizing one side without the other
    // would break symmetry). Crossing nodes themselves must not be
    // skipped — they handle their own combined-curvature optimization.
    if ((flags & IS_CROSSING) == 0u) {
        if ((read_flags(prev_idx) & IS_CROSSING) != 0u ||
            (read_flags(next_idx) & IS_CROSSING) != 0u) {
            FragColor = vec4(p.x, p.y, 0.0, 0.0);
            return;
        }
    }

    vec2 n0 = read_neighbor_pos(prev_idx);
    vec2 n1 = read_neighbor_pos(next_idx);

    // Crossings: optimize with combined curvature from both chains.
    // Both slots independently compute the same result (same position,
    // same 4 neighbors) so they converge to the same output.
    bool is_crossing = (flags & IS_CROSSING) != 0u;
    vec2 n2 = vec2(0.0);
    vec2 n3 = vec2(0.0);
    if (is_crossing) {
        // The other slot is at i ± 1 (slot 0→1 or 1→0)
        int other = (cp_slot == 0) ? i + 1 : i - 1;
        ivec2 other_nbrs = read_neighbors(other);
        if (other_nbrs.x >= 0) n2 = read_neighbor_pos(other_nbrs.x);
        if (other_nbrs.y >= 0) n3 = read_neighbor_pos(other_nbrs.y);
    }

    // Corners: exclude curvature energy, keep positional energy only.
    bool exclude_curvature = (flags & IS_CORNER) != 0u;

    float s4 = POSITIONAL_SCALE * POSITIONAL_SCALE;
    s4 *= s4; // 2.5⁴ = 39.0625

    for (int iter = 0; iter < NEWTON_ITER; iter++) {
        vec2 d = p - p_orig;
        float d2 = dot(d, d);

        // Gradient: curvature + positional
        vec2 grad_curv = 4.0 * (2.0 * p - n0 - n1);
        if (is_crossing) grad_curv += 4.0 * (2.0 * p - n2 - n3);
        vec2 grad_pos = 4.0 * s4 * d2 * d;
        vec2 grad = exclude_curvature ? grad_pos : (grad_curv + grad_pos);

        // Hessian
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
