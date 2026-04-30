#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass: T-junction stem CP snap.
//
// Through-CPs (IS_TJUNCTION) and crossings (IS_CROSSING) pass through
// at their optimizer-final positions. Stem CPs (the slot-1 partner of
// an IS_TJUNCTION through-CP) snap onto the rendered through-curve via
// the ghost-aware algebraic B(0.5) formula. Coefficients depend on
// whether the through-CP's prev/next is a chain endpoint.
//
// Crossing curve-curve intersection is computed in pack-positions; this
// pass leaves the crossing CP positions alone.
//
// Multi-pass iteration: dispatched 3× so stem CPs whose chain
// neighbors are themselves stems converge (Jacobi iteration on the
// stem-position system, contraction ≈ 0.17/pass).
//
// Input textures:
//   Source (previous pass): current positions (neighbors)
//   CellGraph: neighbors + flags
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

layout(set = 0, binding = 2) uniform sampler2D Source;    // current positions (neighbors)
layout(set = 0, binding = 3) uniform sampler2D CellGraph; // pass 3 (neighbors + flags)

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_W() * CORNERS_H() * 2; }

const uint IS_TJUNCTION = 32u;
const uint IS_ENDPOINT  = 128u;

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
    vec4 val = texelFetch(Source, ivec2(cx, cy_slot), 0);
    return vec2(val.r, val.g);
}

int decode_neighbor(vec4 val) {
    if (val.r < -0.5) return -1;
    int ncx = int(val.r + 0.5);
    int ncy = int(val.g + 0.5);
    int nslot = int(val.b + 0.5);
    return (ncy * CORNERS_W() + ncx) * 2 + nslot;
}

ivec2 read_neighbors(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return ivec2(-1, -1);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 prev_val = texelFetch(CellGraph, ivec2(cx, base_row + 1), 0);
    vec4 next_val = texelFetch(CellGraph, ivec2(cx, base_row + 2), 0);
    return ivec2(decode_neighbor(prev_val), decode_neighbor(next_val));
}

uint read_flags(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return 0u;
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    int base_row = cy_slot * 3;
    vec4 val = texelFetch(CellGraph, ivec2(cx, base_row), 0);
    return uint(val.b + 0.5);
}

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

    uint flags = read_flags(i);
    vec2 curr_pos = read_pos(i);

    int partner = i ^ 1;
    uint partner_flags = read_flags(partner);

    if ((partner_flags & IS_TJUNCTION) != 0u && (flags & ~IS_ENDPOINT) == 1u) {
        // Stem CPs carry flags = IS_USED | IS_ENDPOINT (= 129); mask
        // IS_ENDPOINT before testing that this slot is a plain stem.
        // Snap onto the rendered through-curve via ghost-aware B(0.5).
        ivec2 partner_nbrs = read_neighbors(partner);
        int prev_idx = partner_nbrs.x;
        int next_idx = partner_nbrs.y;

        if (prev_idx >= 0 && next_idx >= 0) {
            vec2 prev_pos = read_pos(prev_idx);
            vec2 partner_pos = read_pos(partner);
            vec2 next_pos = read_pos(next_idx);
            bool prev_is_end = (read_flags(prev_idx) & IS_ENDPOINT) != 0u;
            bool next_is_end = (read_flags(next_idx) & IS_ENDPOINT) != 0u;
            float sp, st, sn;
            if (!prev_is_end && !next_is_end) { sp = 0.125; st = 0.75;  sn = 0.125; }
            else if (prev_is_end && !next_is_end) { sp = 0.25;  st = 0.625; sn = 0.125; }
            else if (!prev_is_end && next_is_end) { sp = 0.125; st = 0.625; sn = 0.25; }
            else { sp = 0.25;  st = 0.5;   sn = 0.25; }
            vec2 on_curve = sp * prev_pos + st * partner_pos + sn * next_pos;
            FragColor = vec4(on_curve.x, on_curve.y, 0.0, 0.0);
            return;
        }
    }

    // Default: pass through position unchanged. Crossings and T-junction
    // through-CPs both end up here — they keep the optimizer's position;
    // the crossing's curve-curve intersection parameter is computed
    // downstream in pack-positions.
    FragColor = vec4(curr_pos.x, curr_pos.y, 0.0, 0.0);
}
