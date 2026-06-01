#version 450
#pragma format R32G32B32A32_SFLOAT

// T-junction stem snap.
//
// Stem CPs (the slot-1 partner of an IS_TJUNCTION through-CP) snap onto
// the rendered through-curve via the ghost-aware algebraic B(0.5)
// formula. Through-CPs and crossings pass through unchanged.
//
// Dispatched 3× by the host preset so stem CPs whose chain neighbors
// are themselves stems converge (Jacobi iteration).

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
int NUM_CPS()  { return CORNERS_H() << 12;  /* bit-packed encoding: cy < CH means cp_idx < CH<<12 */ }

const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING  = 64u;
const uint IS_ENDPOINT  = 128u;

// Bit-packed CP encoding. Row-interleaved slot — see cell-rasterizer-single-aa.slang.
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

    // Crossing slot-1 redirect — see optimize-energy.slang.
    uint flags_self = read_flags(i_self);
    bool is_crossing = (flags_self & IS_CROSSING) != 0u;
    int i = (is_crossing && cp_slot == 1) ? (i_self - 1) : i_self;

    uint flags = read_flags(i);
    vec2 curr_pos = read_pos(i);

    int partner = i ^ 1;
    uint partner_flags = read_flags(partner);

    if ((partner_flags & IS_TJUNCTION) != 0u && (flags & ~IS_ENDPOINT) == 1u) {
        // Stem CPs carry flags = IS_USED | IS_ENDPOINT (= 129); mask
        // IS_ENDPOINT before testing for a plain stem.
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

    // Through-CPs and crossings: keep the optimizer's position. The
    // crossing's curve-curve intersection parameter is computed
    // downstream in pack-positions.
    FragColor = vec4(curr_pos.x, curr_pos.y, 0.0, 0.0);
}
