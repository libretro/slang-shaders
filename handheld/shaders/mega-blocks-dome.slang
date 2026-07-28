#version 450

/* ================================================================
 *  Mega Blocks Dome Shader
 *  Superimposes circular lighting profiles onto source pixels to simulate 3D studs.
 *  Enforces per-axis integer scaling at vertex stage to eliminate moire.
 *  Copyright (c) 2026 by crashGG.
 * ================================================================ */

layout(push_constant) uniform Push
{
    vec4  SourceSize;
    vec4  OriginalSize;
    vec4  OutputSize;
    uint  FrameCount;
    float bevel_depth;
    float highlight_ratio;
} params;

// Bevel Depth: Default 0.27 | Range [0.01, 0.50] | Step 0.01
#pragma parameter bevel_depth "Bevel Depth" 0.27 0.01 0.50 0.01
#define bevel_depth params.bevel_depth

// Highlight Ratio: Default 0.90 | Range [0.30, 1.25] | Step 0.05
#pragma parameter highlight_ratio "Highlight Intensity" 0.90 0.30 1.25 0.05
#define highlight_ratio params.highlight_ratio

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

/* ================================================================
 *  Vertex Stage - Per-Axis Integer Scaling & Viewport Letterboxing
 * ================================================================ */
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vScale;

void main()
{
    vec4 clip = global.MVP * Position;

    // Floor scaling factors independently per axis (clamped to 1.0 minimum)
    vec2 int_scale = max(floor(params.OutputSize.xy * params.SourceSize.zw), vec2(1.0));

    // Calculate the ratio of the integer-scaled frame relative to the target viewport
    vec2 render_ratio = params.SourceSize.xy * (int_scale * params.OutputSize.zw);

    clip.xy *= render_ratio;

    gl_Position = clip;
    vTexCoord   = TexCoord;
    vScale      = int_scale;
}

/* ================================================================
 *  Fragment Stage - Radial Distance Field Lighting
 * ================================================================ */
#pragma stage fragment
layout(location = 0) in  vec2 vTexCoord;
layout(location = 1) in  vec2 vScale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Mid-point intensity horizon along the unit square diagonal: |(0.5, 0.5)| = sqrt(0.5)
const float ARC_ZERO = 0.70710678;

void main()
{
    // Normalized continuous coordinates within the current source pixel quad [0, 1)
    vec2 cell_uv = fract(vTexCoord * params.SourceSize.xy);

    // Floating-point precision jitter protection at integer boundaries
    cell_uv = mix(cell_uv, vec2(0.0), step(vec2(0.9999), cell_uv));

    // --- Coordinate Quantization ---
    // Quantizes pixel centers to discrete integer indices normalized over the [0, 1] range.
    // This anchors the minimum/maximum lighting intensities perfectly at the cell corners.
    vec2 position = floor(cell_uv * vScale)
                  / max(vScale - vec2(1.0), vec2(1.0));

    // --- Radial Distance Field ---
    // Evaluates Euclidean distance to the top-left corner (0,0) to form a circular shading profile.
    float shading_field = ARC_ZERO - length(position);

    // --- Asymmetric Shading Profile ---
    float shade = min(shading_field, 0.0)
               + max(shading_field, 0.0) * highlight_ratio;

    // --- Final Compositing ---
    vec3 color  = texture(Source, vTexCoord).rgb;
    vec3 result = color + color * shade * bevel_depth;

    FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
