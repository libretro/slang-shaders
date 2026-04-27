#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass: Post-optimization junction position correction.
//
// Crossings: ghost-aware inverse B-spline correction (each slot
//   independently). Coefficients depend on whether prev/next is a
//   chain endpoint, which causes the rasterizer to ghost-adjust
//   that side of the clamped Bezier.
// T-junctions: through-CP is left at the optimizer's value (not
//   overwritten). Stem CPs snap onto the rendered through-curve
//   via the ghost-aware algebraic B(0.5) formula.
//
// Uses Opt2 (original optimizer output) for the crossing-correction
// grid target, Source (previous pass) for neighbor positions. Multi-
// pass iteration: dispatch a few times so junction CPs whose neighbors
// are themselves junctions converge.
//
// Input textures:
//   Source (previous pass): current positions (neighbors)
//   Opt2: original optimizer output (center weight)
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
    vec4 Opt2Size;
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
layout(set = 0, binding = 4) uniform sampler2D Opt2;      // original optimizer output

int IMG_W()    { return int(params.OriginalSize.x); }
int IMG_H()    { return int(params.OriginalSize.y); }
int CORNERS_W() { return IMG_W() + 1; }
int CORNERS_H() { return IMG_H() + 1; }
int NUM_CPS()  { return CORNERS_W() * CORNERS_H() * 2; }

const uint IS_TJUNCTION = 32u;
const uint IS_CROSSING  = 64u;
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

vec2 read_orig_pos(int cp_idx) {
    if (cp_idx < 0 || cp_idx >= NUM_CPS()) return vec2(0.0);
    int cx, cy_slot;
    decode_cp(cp_idx, cx, cy_slot);
    vec4 val = texelFetch(Opt2, ivec2(cx, cy_slot), 0);
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
    vec2 orig_pos = read_orig_pos(i);

    int partner = i ^ 1;
    uint partner_flags = read_flags(partner);

    // Valence-4 crossing: ghost-aware inverse B-spline correction.
    // Each slot processed independently (different pp/np). The
    // coefficients (a, bp, bn) solve B_rendered(0.5) = grid for cp,
    // accounting for the rasterizer's ghost extension of any endpoint
    // neighbor on this slot's chain.
    if ((flags & IS_CROSSING) != 0u) {
        ivec2 nbrs = read_neighbors(i);
        int prev_idx = nbrs.x;
        int next_idx = nbrs.y;

        if (prev_idx >= 0 && next_idx >= 0) {
            vec2 prev_pos = read_pos(prev_idx);
            vec2 next_pos = read_pos(next_idx);
            bool prev_is_end = (read_flags(prev_idx) & IS_ENDPOINT) != 0u;
            bool next_is_end = (read_flags(next_idx) & IS_ENDPOINT) != 0u;
            float a, bp, bn;
            if (!prev_is_end && !next_is_end) { a = 0.75; bp = 0.125; bn = 0.125; }
            else if (prev_is_end && !next_is_end) { a = 0.625; bp = 0.25; bn = 0.125; }
            else if (!prev_is_end && next_is_end) { a = 0.625; bp = 0.125; bn = 0.25; }
            else { a = 0.5; bp = 0.25; bn = 0.25; }
            vec2 corrected = (orig_pos - bp * prev_pos - bn * next_pos) / a;
            FragColor = vec4(corrected.x, corrected.y, 0.0, 0.0);
            return;
        }
    } else if ((flags & IS_TJUNCTION) != 0u) {
        // T-junction through-CP: leave at the optimizer's position.
        FragColor = vec4(curr_pos.x, curr_pos.y, 0.0, 0.0);
        return;
    } else if ((partner_flags & IS_TJUNCTION) != 0u && (flags & ~IS_ENDPOINT) == 1u) {
        // Stem CPs carry flags = IS_USED | IS_ENDPOINT (= 129); mask
        // IS_ENDPOINT before testing that this slot is a plain stem.
        // Stem: snap onto the rendered through-curve via ghost-aware B(0.5).
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

    // Default: pass through position unchanged
    FragColor = vec4(curr_pos.x, curr_pos.y, 0.0, 0.0);
}
