#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass: Post-optimization T-junction position correction.
//
// Reads absolute positions from Source, applies T-junction correction,
// stores corrected absolute positions.
//
// For each CP with IS_TJUNCTION flag, recompute position as:
//   pos = 0.125 * prev_pos + 0.75 * pos + 0.125 * next_pos
//
// Also updates the stem CP at the other slot (i ^ 1) so it terminates
// exactly on the smooth curve.
//
// Input textures:
//   Source (previous pass): optimized absolute positions
//   CellGraph: original positions + neighbors + flags
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

layout(set = 0, binding = 2) uniform sampler2D Source;    // optimized positions
layout(set = 0, binding = 3) uniform sampler2D CellGraph; // pass 3 (neighbors + flags)

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_W() * CORNERS_H() * 2; }

const uint IS_TJUNCTION = 32u;

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

    vec2 curr_pos = read_pos(i);
    uint flags = read_flags(i);

    int partner = i ^ 1;
    uint partner_flags = read_flags(partner);

    if ((flags & IS_TJUNCTION) != 0u) {
        ivec2 nbrs = read_neighbors(i);
        int prev_idx = nbrs.x;
        int next_idx = nbrs.y;

        if (prev_idx >= 0 && next_idx >= 0) {
            vec2 prev_pos = read_pos(prev_idx);
            vec2 next_pos = read_pos(next_idx);
            vec2 corrected = 0.125 * prev_pos + 0.75 * curr_pos + 0.125 * next_pos;
            FragColor = vec4(corrected.x, corrected.y, 0.0, 0.0);
            return;
        }
    } else if ((partner_flags & IS_TJUNCTION) != 0u && flags == 1u) {
        ivec2 partner_nbrs = read_neighbors(partner);
        int prev_idx = partner_nbrs.x;
        int next_idx = partner_nbrs.y;

        if (prev_idx >= 0 && next_idx >= 0) {
            vec2 prev_pos = read_pos(prev_idx);
            vec2 partner_pos = read_pos(partner);
            vec2 next_pos = read_pos(next_idx);
            vec2 corrected = 0.125 * prev_pos + 0.75 * partner_pos + 0.125 * next_pos;
            vec2 on_curve = 0.125 * prev_pos + 0.75 * corrected + 0.125 * next_pos;
            FragColor = vec4(on_curve.x, on_curve.y, 0.0, 0.0);
            return;
        }
    }

    // Default: pass through position unchanged
    FragColor = vec4(curr_pos.x, curr_pos.y, 0.0, 0.0);
}
