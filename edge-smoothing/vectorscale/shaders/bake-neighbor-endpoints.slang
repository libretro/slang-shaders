#version 450
#pragma format R32G32B32A32_SFLOAT

// Bake-neighbor-endpoints. Passthrough copy of CellGraphRaw with two
// extra bits added to each CP's dp_ci byte (top byte of channel A):
//
//   bit 6 (0x40) — prev neighbor has IS_ENDPOINT set
//   bit 7 (0x80) — next neighbor has IS_ENDPOINT set
//
// Lets resolve_hit gate its endpoint-defer condition without fetching
// the prev/next neighbor's full CellGraph row.
//
// dp_ci layout after this pass:
//   bits 0-2 — (prev_dir + 1)
//   bits 3-5 — (next_dir + 1)
//   bit  6   — prev_is_endpoint
//   bit  7   — next_is_endpoint
//
// Other channels and the low 24 bits of A pass through unchanged.

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
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

layout(set = 0, binding = 2) uniform sampler2D CellGraphRaw;

int IMG_W()     { return int(params.OriginalSize.x); }
int IMG_H()     { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()   { return CORNERS_H() << 12;  /* bit-packed encoding: cy < CH means cp_idx < CH<<12 */ }

const uint IS_ENDPOINT = 128u;
const uint NO_NEIGHBOR = 0x00FFFFFFu;

// Bit-packed CP encoding. Row-interleaved slot — see cell-rasterizer-single-aa.slang.
ivec2 decode_cp(int cp_idx) {
    int cp_slot = cp_idx & 1;
    int cx = (cp_idx >> 1) & 0x7FF;
    int cy = cp_idx >> 12;
    return ivec2(cx, (cy << 1) | cp_slot);
}

bool neighbor_is_endpoint(uint idx_24) {
    if (idx_24 == NO_NEIGHBOR) return false;
    int ci = int(idx_24);
    if (ci >= NUM_CPS()) return false;
    vec4 cg = texelFetch(CellGraphRaw, decode_cp(ci), 0);
    uint flag = (floatBitsToUint(cg.b) >> 24) & 0xFFu;
    return (flag & IS_ENDPOINT) != 0u;
}

void main() {
    ivec2 p = ivec2(gl_FragCoord.xy);
    vec4 cg = texelFetch(CellGraphRaw, p, 0);

    // Out-of-range texels (cell-graph output is over-allocated by ~5%)
    // pass through unchanged; they're never sampled via decode_cp.
    int cx  = p.x;
    int row = p.y;
    int slot = row & 1;
    int cy   = row >> 1;
    if (cx >= CORNERS_W() || cy >= CORNERS_H()) {
        FragColor = cg;
        return;
    }

    uint b_bits = floatBitsToUint(cg.b);
    uint a_bits = floatBitsToUint(cg.a);
    uint prev_idx_24 = b_bits & 0x00FFFFFFu;
    uint next_idx_24 = a_bits & 0x00FFFFFFu;

    uint extra = 0u;
    if (neighbor_is_endpoint(prev_idx_24)) extra |= 0x40u;
    if (neighbor_is_endpoint(next_idx_24)) extra |= 0x80u;

    uint orig_dp_ci = (a_bits >> 24) & 0xFFu;
    uint new_dp_ci  = orig_dp_ci | extra;
    uint new_a      = (new_dp_ci << 24) | next_idx_24;

    FragColor = vec4(cg.r, cg.g, cg.b, uintBitsToFloat(new_a));
}
