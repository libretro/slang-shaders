#version 450
#pragma format R32G32B32A32_SFLOAT

// Pass 0: build similarity graph from pixel-art input. Output is a
// 2x-scaled texture:
//   Odd,Odd   (2x+1, 2y+1) = pixel color in .rgb + 8-bit valence mask in .a
//                            (NW=1, W=2, SW=4, S=8, SE=16, E=32, NE=64, N=128).
//   Even,Odd  (2x,   2y+1) = horizontal edge: 1.0 if connected, else 0.0.
//   Odd,Even  (2x+1, 2y)   = vertical edge: 1.0 if connected, else 0.0.
//   Even,Even (2x,   2y)   = diagonal corner flags as float(0-3):
//     bit 0 = backslash (x-1,y-1)-(x,y), bit 1 = slash (x,y-1)-(x-1,y).
//
// The graph is conceptually (2W+1)×(2H+1) but we output to 2W×2H — the
// missing rightmost column / bottom row are border edges defaulting to 0.
//
// The valence mask is consumed by resolve-crossings; resolve-crossings
// only modifies even-even diagonal flags so the mask stays valid.

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

layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    // Output pixel coordinates (integer)
    ivec2 imgSize = ivec2(params.SourceSize.xy);
    ivec2 outSize = ivec2(params.OutputSize.xy); // should be 2*imgSize
    ivec2 opos = ivec2(vTexCoord * params.OutputSize.xy);

    if (opos.x >= outSize.x || opos.y >= outSize.y) {
        FragColor = vec4(0.0);
        return;
    }

    int gx = opos.x;
    int gy = opos.y;
    bool gx_even = (gx % 2 == 0);
    bool gy_even = (gy % 2 == 0);

    if (!gx_even && !gy_even) {
        // Odd, Odd: pixel color + 8-bit valence mask. Each bit set iff
        // the cardinal/diagonal neighbor has the same color.
        int px = (gx - 1) / 2;
        int py = (gy - 1) / 2;
        vec4 self = texelFetch(Source, ivec2(px, py), 0);

        uint valence = 0u;
        // Cardinals
        if (px > 0
            && all(equal(self.rgb, texelFetch(Source, ivec2(px - 1, py), 0).rgb))) valence |= 2u;   // W
        if (px + 1 < imgSize.x
            && all(equal(self.rgb, texelFetch(Source, ivec2(px + 1, py), 0).rgb))) valence |= 32u;  // E
        if (py > 0
            && all(equal(self.rgb, texelFetch(Source, ivec2(px, py - 1), 0).rgb))) valence |= 128u; // N
        if (py + 1 < imgSize.y
            && all(equal(self.rgb, texelFetch(Source, ivec2(px, py + 1), 0).rgb))) valence |= 8u;   // S
        // Diagonals
        if (px > 0 && py > 0
            && all(equal(self.rgb, texelFetch(Source, ivec2(px - 1, py - 1), 0).rgb))) valence |= 1u;  // NW
        if (px + 1 < imgSize.x && py > 0
            && all(equal(self.rgb, texelFetch(Source, ivec2(px + 1, py - 1), 0).rgb))) valence |= 64u; // NE
        if (px > 0 && py + 1 < imgSize.y
            && all(equal(self.rgb, texelFetch(Source, ivec2(px - 1, py + 1), 0).rgb))) valence |= 4u;  // SW
        if (px + 1 < imgSize.x && py + 1 < imgSize.y
            && all(equal(self.rgb, texelFetch(Source, ivec2(px + 1, py + 1), 0).rgb))) valence |= 16u; // SE

        FragColor = vec4(self.rgb, float(valence));

    } else if (gx_even && !gy_even) {
        // Even, Odd: horizontal edge between pixel (gx/2 - 1, (gy-1)/2) and (gx/2, (gy-1)/2)
        int px_left = gx / 2 - 1;
        int px_right = gx / 2;
        int py = (gy - 1) / 2;

        if (px_left < 0 || px_right >= imgSize.x) {
            // Border edge: not connected
            FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        } else {
            vec4 left = texelFetch(Source, ivec2(px_left, py), 0);
            vec4 right = texelFetch(Source, ivec2(px_right, py), 0);
            float val = (all(equal(left.rgb, right.rgb))) ? 1.0 : 0.0;
            FragColor = vec4(val, 0.0, 0.0, 0.0);
        }

    } else if (!gx_even && gy_even) {
        // Odd, Even: vertical edge between pixel ((gx-1)/2, gy/2 - 1) and ((gx-1)/2, gy/2)
        int px = (gx - 1) / 2;
        int py_top = gy / 2 - 1;
        int py_bot = gy / 2;

        if (py_top < 0 || py_bot >= imgSize.y) {
            // Border edge: not connected
            FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        } else {
            vec4 top = texelFetch(Source, ivec2(px, py_top), 0);
            vec4 bot = texelFetch(Source, ivec2(px, py_bot), 0);
            float val = (all(equal(top.rgb, bot.rgb))) ? 1.0 : 0.0;
            FragColor = vec4(val, 0.0, 0.0, 0.0);
        }

    } else {
        // Even, Even: diagonal corner flags (0-3)
        // Corner at graph (gx, gy) is between pixel block:
        //   TL = (gx/2 - 1, gy/2 - 1)  TR = (gx/2, gy/2 - 1)
        //   BL = (gx/2 - 1, gy/2)       BR = (gx/2, gy/2)
        int bx = gx / 2 - 1; // upper-left pixel x of the 2x2 block
        int by = gy / 2 - 1; // upper-left pixel y of the 2x2 block

        if (bx < 0 || by < 0 || bx + 1 >= imgSize.x || by + 1 >= imgSize.y) {
            // Border corner: no diagonals
            FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        } else {
            vec4 tl = texelFetch(Source, ivec2(bx, by), 0);
            vec4 tr = texelFetch(Source, ivec2(bx + 1, by), 0);
            vec4 bl = texelFetch(Source, ivec2(bx, by + 1), 0);
            vec4 br = texelFetch(Source, ivec2(bx + 1, by + 1), 0);

            uint flags = 0u;
            // Bit 0: backslash diagonal TL-BR
            if (all(equal(tl.rgb, br.rgb))) flags |= 1u;
            // Bit 1: slash diagonal TR-BL
            if (all(equal(tr.rgb, bl.rgb))) flags |= 2u;

            FragColor = vec4(float(flags), 0.0, 0.0, 0.0);
        }
    }
}
