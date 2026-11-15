#version 450

/*
 * Raw Motion Interpolation v13 — corrected multiplier-aware automatic search radius plus static-patch fast path.
 *
 * Intended order:
 *   raw emulator frame -> this pass -> CRT/LCD shader chain
 *
 * Uses RetroArch sub-frame timing and OriginalHistory1 as the previous raw
 * frame, matching the experimental v1 interface. The preset renders this pass
 * at 2x source resolution so a one-source-pixel translation can be represented
 * as two output-pixel steps. This does not create missing scene information;
 * it only provides a finer spatial grid for translating the existing pixel art.
 *
 * Experimental: validate the configured subframe cadence and performance in RetroArch.
 */

#pragma name RawMotionInterpolation2
#pragma format R8G8B8A8_UNORM

#pragma parameter SEARCH_RADIUS "Motion Search Radius (0=automatic)" 0.0 0.0 10.0 1.0
#pragma parameter PATCH_SIZE "Motion Patch Size" 2.0 1.0 3.0 1.0
#pragma parameter MATCH_LIMIT "Maximum Match Error" 0.12 0.01 0.40 0.01
#pragma parameter STATIC_PATCH_THRESHOLD "Static Patch Fast-Path Threshold" 0.003 0.0 0.03 0.001
#pragma parameter SUBPIXEL_SCALE "Intermediate Resolution Scale" 2.0 1.0 4.0 1.0
#pragma parameter FALLBACK_MODE "Uncertain Motion (0=nearest frame, 1=blend)" 0.0 0.0 1.0 1.0
#pragma parameter VERTICAL_MOTION_PENALTY "Vertical Motion Penalty" 0.01 0.0 0.05 0.005
#pragma parameter FRAME_MULTIPLIER "Frame Multiplier (x1 = bypass)" 2.0 1.0 10.0 1.0
#pragma parameter REFRESH_MULTIPLIER "Refresh Multiplier (match RetroArch subframes)" 2.0 1.0 10.0 1.0

layout(set = 0, binding = 0, std140) uniform UBO { mat4 MVP; } global;

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    uint TotalSubFrames;
    uint CurrentSubFrame;
    float GAIN_VS_BLUR;
    float GAMMA;
    float FPS_DIVISOR;
    float LCD_ANTI_RETENTION_TOGGLE;
    float POS_MOD;
    float LCD_INVERSION_COMPENSATION_SLEW;
    float SCAN_DIRECTION;
    float SEARCH_RADIUS;
    float PATCH_SIZE;
    float MATCH_LIMIT;
    float STATIC_PATCH_THRESHOLD;
    float SUBPIXEL_SCALE;
    float FALLBACK_MODE;
    float VERTICAL_MOTION_PENALTY;
    float FRAME_MULTIPLIER;
    float REFRESH_MULTIPLIER;
} params;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Original;
layout(set = 0, binding = 3) uniform sampler2D OriginalHistory1;

vec4 nowAt(ivec2 p, ivec2 size)
{
    return texelFetch(Original, clamp(p, ivec2(0), size - ivec2(1)), 0);
}
vec4 oldAt(ivec2 p, ivec2 size)
{
    return texelFetch(OriginalHistory1, clamp(p, ivec2(0), size - ivec2(1)), 0);
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

/* A 5x5-ish patch comparison reduces false matches on isolated repeated dots. */
float matchError(ivec2 p, ivec2 d, ivec2 size, int patchRadius)
{
    float e = 0.0;
    float w = 0.0;
    for (int y = -3; y <= 3; ++y)
    {
        if (abs(y) > patchRadius) continue;
        for (int x = -3; x <= 3; ++x)
        {
            if (abs(x) > patchRadius) continue;
            float weight = (x == 0 && y == 0) ? 2.0 : 1.0;
            vec3 a = nowAt(p + ivec2(x, y), size).rgb;
            vec3 b = oldAt(p + d + ivec2(x, y), size).rgb;
            /* Luma plus a weaker RGB term preserves colored pixel-art features. */
            vec3 delta = abs(a - b);
            e += weight * (abs(lum(a) - lum(b)) * 0.75 +
                           (delta.r + delta.g + delta.b) * 0.0833333);
            w += weight;
        }
    }
    return e / max(w, 1.0);
}

void main()
{
    ivec2 srcSize = ivec2(params.OriginalSize.xy);
    vec2 sourcePos = vTexCoord * vec2(srcSize) - vec2(0.5);
    ivec2 p = clamp(ivec2(floor(sourcePos + vec2(0.5))),
                    ivec2(0), srcSize - ivec2(1));

    vec4 current = nowAt(p, srcSize);
    float frameMultiplier = clamp(floor(params.FRAME_MULTIPLIER + 0.5), 1.0, 10.0);
    float refreshMultiplier = clamp(floor(params.REFRESH_MULTIPLIER + 0.5), 1.0, 10.0);

    /*
     * Frame Multiplier x1 is a true bypass. Unlike v8, Refresh Multiplier x1
     * does not disable interpolation: when no subframes are available, render
     * the midpoint (t=0.5) between the current and previous source frames.
     * This changes the image sampled at each invocation; it does not itself
     * increase RetroArch's presentation rate. The user configures subframes
     * to match Refresh Multiplier when additional output positions are wanted.
     */
    if (frameMultiplier < 1.5 || params.FrameCount < 2u)
    {
        FragColor = current;
        return;
    }

    float t;
    bool haveSubframes = params.TotalSubFrames >= 2u;
    if (!haveSubframes || refreshMultiplier < 1.5)
    {
        /* No subframe positions: use a single midpoint sample. */
        t = 0.5;
    }
    else
    {
        /* Subframe zero is the real/source position, so leave it untouched. */
        if (params.CurrentSubFrame == 0u)
        {
            FragColor = current;
            return;
        }

        /*
         * Map the actual subframe index onto the requested interpolation grid.
         * Equal multipliers retain v7's t = subframe / count behavior. When
         * multipliers differ, map each available subframe to the nearest
         * requested intermediate position, excluding the source endpoint.
         */
        float requestedStep = floor(
            float(params.CurrentSubFrame) * frameMultiplier / refreshMultiplier + 0.5);
        requestedStep = clamp(requestedStep, 1.0, frameMultiplier - 1.0);
        t = requestedStep / frameMultiplier;
    }
    /*
     * Cheap static-patch fast path. This runs before the large motion search:
     * if a small neighborhood is effectively unchanged between the current
     * and previous source frames, output the current pixel directly. On a
     * paused/static image this avoids nearly all of the expensive matching
     * work. It is local rather than a blanket frame bypass, so moving regions
     * still reach the normal matcher and multiplier-based cadence logic is
     * preserved. A small threshold tolerates tiny sampling/quantization noise.
     */
    float staticThreshold = max(params.STATIC_PATCH_THRESHOLD, 0.0);
    if (staticThreshold > 0.0)
    {
        float localDiff = 0.0;
        for (int sy = -1; sy <= 1; ++sy)
        {
            for (int sx = -1; sx <= 1; ++sx)
            {
                vec3 aStatic = nowAt(p + ivec2(sx, sy), srcSize).rgb;
                vec3 bStatic = oldAt(p + ivec2(sx, sy), srcSize).rgb;
                vec3 dStatic = abs(aStatic - bStatic);
                localDiff += (dStatic.r + dStatic.g + dStatic.b) / 3.0;
            }
        }
        localDiff /= 9.0;
        if (localDiff <= staticThreshold)
        {
            FragColor = current;
            return;
        }
    }

    /*
     * Automatic radius calibrated to the user's tests:
     *   Frame x2 / Refresh x2 -> radius 6
     *   Frame x2 / Refresh x1 -> radius 2
     *   Frame x4 / Refresh x2 -> radius 2 (conservative for 3 generated frames)
     *   Equal multipliers otherwise use round(12 / Frame Multiplier).
     * When the multipliers differ, use radius 2 because the cadence is
     * intentionally dropping/omitting source-frame positions rather than
     * representing every intermediate position. Explicit nonzero values
     * retain manual control.
     */
    int radius;
    if (params.SEARCH_RADIUS < 0.5)
    {
        if (abs(frameMultiplier - refreshMultiplier) > 0.5)
        {
            radius = 2;
        }
        else
        {
            radius = int(floor(12.0 / frameMultiplier + 0.5));
            radius = clamp(radius, 1, 10);
        }
    }
    else
    {
        radius = int(clamp(floor(params.SEARCH_RADIUS + 0.5), 1.0, 10.0));
    }
    int patchRadius = int(clamp(params.PATCH_SIZE, 1.0, 3.0));

    float best = 1e20;
    float second = 1e20;
    ivec2 bestD = ivec2(0);

    /* Search the prior frame for the best match to this current-frame patch. */
    for (int y = -10; y <= 10; ++y)
    {
        if (abs(y) > radius) continue;
        for (int x = -10; x <= 10; ++x)
        {
            if (abs(x) > radius) continue;
            ivec2 d = ivec2(x, y);
            float e = matchError(p, d, srcSize, patchRadius);
            /* For horizontal scrolling, mildly discourage false vertical displacement. */
            e += abs(float(y)) * params.VERTICAL_MOTION_PENALTY;
            if (e < best)
            {
                second = best;
                best = e;
                bestD = d;
            }
            else if (e < second)
            {
                second = e;
            }
        }
    }

    /* Ambiguous matches are common in repeated pixel-art patterns. */
    bool uncertain = best > params.MATCH_LIMIT ||
                     (second - best) < max(0.002, params.MATCH_LIMIT * 0.025);

    if (uncertain)
    {
        if (params.FALLBACK_MODE > 0.5)
            FragColor = mix(oldAt(p, srcSize), current, t);
        else
            FragColor = (t < 0.5) ? oldAt(p, srcSize) : current;
        return;
    }

    /*
     * Render on the configured higher-resolution output grid. Fractional
     * source-pixel shifts are represented by the output grid; source sampling
     * remains nearest-neighbour to avoid introducing blur.
     *
     * bestD is the location in the old frame corresponding to current pixel p.
     */
    vec2 prevPos = sourcePos + vec2(bestD) * t;
    vec2 currPos = sourcePos - vec2(bestD) * (1.0 - t);

    ivec2 prevPixel = ivec2(floor(prevPos + vec2(0.5)));
    ivec2 currPixel = ivec2(floor(currPos + vec2(0.5)));

    vec4 a = oldAt(prevPixel, srcSize);
    vec4 b = nowAt(currPixel, srcSize);

    /*
     * Both samples should describe the same moving content at time t.
     * Select the better endpoint instead of alpha-blending mismatched edges,
     * which is a common source of ghosting. The fallback handles unreliable
     * matches above.
     */
    FragColor = (t < 0.5) ? a : b;
}
