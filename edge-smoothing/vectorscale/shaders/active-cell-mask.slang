#version 450

// Active-cell info. Per source cell (cx, cy):
//   RGB = the cell's fallback color (= Original pixel at cx, cy)
//   A   = 8-bit mask of renderable CPs at the cell's 4 corners × 2 slots
//         (flag != 0 AND pack-positions validity = 1)
//
// Bit `oi * 2 + slot` matches cell-rasterizer's corner walk:
//   oi=0 → (0,0)   oi=1 → (1,0)   oi=2 → (0,1)   oi=3 → (1,1)
//
// The rasterizer uses mask == 0 to skip find_hits entirely (solid
// interior) and the set bits to walk only renderable CPs without
// per-CP flag/validity checks.

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

layout(set = 0, binding = 2) uniform sampler2D CellGraph;
layout(set = 0, binding = 3) uniform sampler2D PackedPositions;
layout(set = 0, binding = 4) uniform sampler2D Original;

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_H() { return IMG_H() + 1; }

// True iff (cx, cy, slot) is both active (CellGraph flag != 0) AND
// rendered (pack-positions validity = 1).
bool is_renderable(int cx, int cy, int slot) {
    int cell_row = (cy << 1) | slot;
    vec4 cg = texelFetch(CellGraph, ivec2(cx, cell_row), 0);
    uint flag = (floatBitsToUint(cg.b) >> 24) & 0xFFu;
    if (flag == 0u) return false;
    vec4 t0 = texelFetch(PackedPositions, ivec2(cx * 2, cell_row), 0);
    return t0.a >= 0.5;
}

void main() {
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);
    int cell_cx = opos.x;
    int cell_cy = opos.y;

    if (cell_cx >= IMG_W() || cell_cy >= IMG_H()) {
        FragColor = vec4(0.0);
        return;
    }

    vec3 fallback = texelFetch(Original, ivec2(cell_cx, cell_cy), 0).rgb;

    // Bit order matches find_hits's (oi*2 + slot) indexing. Slot 0/1 are
    // tested independently: cell-graph guarantees slot 1 is populated
    // only when slot 0 is, but renderability also depends on the chain
    // partner being IS_ENDPOINT — and the two slots have different chains.
    uint mask = 0u;
    if (is_renderable(cell_cx,     cell_cy,     0)) mask |= (1u << 0);
    if (is_renderable(cell_cx,     cell_cy,     1)) mask |= (1u << 1);
    if (is_renderable(cell_cx + 1, cell_cy,     0)) mask |= (1u << 2);
    if (is_renderable(cell_cx + 1, cell_cy,     1)) mask |= (1u << 3);
    if (is_renderable(cell_cx,     cell_cy + 1, 0)) mask |= (1u << 4);
    if (is_renderable(cell_cx,     cell_cy + 1, 1)) mask |= (1u << 5);
    if (is_renderable(cell_cx + 1, cell_cy + 1, 0)) mask |= (1u << 6);
    if (is_renderable(cell_cx + 1, cell_cy + 1, 1)) mask |= (1u << 7);

    FragColor = vec4(fallback, float(mask) / 255.0);
}
