#version 450

/* ================================================================
 *  Mega Blocks Brick Shader
 *  Superimposes lighting profiles onto source pixels to simulate 3D bricks.
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
 *  Fragment Stage - Analytical Bevel Profile & Diagonal Lighting
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
    vec2 inv_scale = 1.0 / vScale;

    // Normalized continuous coordinates within the current source pixel quad [0, 1)
    vec2 cell_uv = fract(vTexCoord * params.SourceSize.xy);

    vec3 color = texture(Source, vTexCoord).rgb;

    // --- Compute Per-Axis Bevel Width in UV Space ---
    vec2 bevel_w = max(round(vScale * 0.145898), vec2(1.0)) * inv_scale;

    // --- Generate Bevel Mask ---
    vec2  slope   = clamp(min(cell_uv, 1.0 - cell_uv) / bevel_w, 0.0, 1.0);
    float is_edge = 1.0 - min(slope.x, slope.y);

    // --- Diagonal Directional Lighting (2D Continuous Gradient) ---
    float grad = -dot(cell_uv - 0.5, vec2(ARC_ZERO)) * 2.0;

    float highlight = max(grad, 0.0) * highlight_ratio;
    float shadow    = min(grad, 0.0);

    // --- Screen-Space Edge Bleed Protection ---
    // Smoothly attenuate shadows within the outermost source pixels to prevent harsh clipping boundaries
    vec2  screen_d  = min(vTexCoord, 1.0 - vTexCoord);
    float src_pixel = min(params.SourceSize.z, params.SourceSize.w);
    shadow *= smoothstep(0.0, src_pixel, min(screen_d.x, screen_d.y));

    // --- Final Compositing ---
    vec3 weight = color * (highlight + shadow) * is_edge * bevel_depth;

    FragColor = vec4(clamp(color + weight, 0.0, 1.0), 1.0);
}
