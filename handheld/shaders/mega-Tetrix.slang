#version 450

/* ================================================================
 *  mega-Tetrix Shader
 *  Part of the mega-blocks framework extensions.
 *  
 *  Copyright (c) 2026 by crashGG.
 * ================================================================ */

layout(push_constant) uniform Push
{
    vec4  SourceSize;
    vec4  OriginalSize;
    vec4  OutputSize;
    uint  FrameCount;
    float bevel_depth;     
} params;

#pragma parameter bevel_depth "Bevel Depth" 0.25 0.01 0.50 0.01
#define bevel_depth params.bevel_depth

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

/* ================================================================
 *  Vertex Stage — Independent Coordinate Integer Alignment
 * ================================================================ */
#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vScale;

void main()
{
    vec4 clip = global.MVP * Position;

    vec2 int_scale = max(floor(params.OutputSize.xy * params.SourceSize.zw), vec2(1.0));
    vec2 render_ratio = params.SourceSize.xy * (int_scale * params.OutputSize.zw);

    clip.xy *= render_ratio;

    gl_Position = clip;
    vTexCoord   = TexCoord;
    vScale      = int_scale;
}

/* ================================================================
 *  Fragment Stage — Lazy Sampling & Chiral Multi-Branch Pipeline
 * ================================================================ */
#pragma stage fragment
layout(location = 0) in  vec2 vTexCoord;
layout(location = 1) in  vec2 vScale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Vectorized 3-channel tolerance checker (Eliminates high-cost sqrt)
bool color_equal(vec3 c1, vec3 c2)
{
    vec3 diff = abs(c1 - c2);
    return all(lessThanEqual(diff, vec3(0.01)));
}

void main()
{
    // Convert normalized UV to discrete integer pixel coordinates inside the cell
    vec2 pixel_coord = floor(fract(vTexCoord * params.SourceSize.xy) * vScale);

    // Compute dynamic border thickness (0.2 scale factor, clamped to 1px min)
    vec2 border_w = max(floor(vScale * 0.2), vec2(1.0));

    // Calculate discrete Manhattan distances to cell boundaries
    float dist_left   = pixel_coord.x;
    float dist_right  = (vScale.x - 1.0) - pixel_coord.x;
    float dist_top    = pixel_coord.y;
    float dist_bottom = (vScale.y - 1.0) - pixel_coord.y;

    // [Lazy Sampling Stage 1]: Fetch source texel color first
    vec3 color = texture(Source, vTexCoord).rgb;

    /* ---- Critical Optimization: Early-Out Bailing ----
     * Immediately discard inner 13x13 fragments to reclaim register memory.
     * Prevents redundant neighborhood sampling for center texels.
     */
    if (dist_left >= border_w.x && dist_right >= border_w.x && dist_top >= border_w.y && dist_bottom >= border_w.y)
    {
        FragColor = vec4(color, 1.0);
        return; 
    }

    // [Lazy Sampling Stage 2]: Fetch 1st-order von Neumann neighborhood
    vec3 color_left  = texture(Source, vTexCoord + vec2(-params.SourceSize.z, 0.0)).rgb;
    vec3 color_right = texture(Source, vTexCoord + vec2( params.SourceSize.z, 0.0)).rgb;
    vec3 color_top   = texture(Source, vTexCoord + vec2(0.0, -params.SourceSize.w)).rgb;
    vec3 color_bottom= texture(Source, vTexCoord + vec2(0.0,  params.SourceSize.w)).rgb;

    // Evaluate connectivity states
    bool same_left   = color_equal(color, color_left);
    bool same_right  = color_equal(color, color_right);
    bool same_top    = color_equal(color, color_top);
    bool same_bottom = color_equal(color, color_bottom);

    float mod_weight = 0.0;

    // Geometric partitioning indicators
    bool is_main_diag = (pixel_coord.x == pixel_coord.y);
    bool is_anti_diag = (pixel_coord.x + pixel_coord.y == vScale.x - 1.0);

    /* ---- Corner Case: Isolated Texel Peak Mitigation ---- */
    bool is_corner = (dist_top == 0.0 || dist_bottom == 0.0) && (dist_left == 0.0 || dist_right == 0.0);
    
    if (is_corner && !same_left && !same_right && !same_top && !same_bottom)
    {
        if (dist_top == 0.0 && dist_left == 0.0)          mod_weight = 0.75;
        else if (dist_top == 0.0 && dist_right == 0.0)     mod_weight = 0.25;
        else if (dist_bottom == 0.0 && dist_right == 0.0)  mod_weight = -0.75;
        else if (dist_bottom == 0.0 && dist_left == 0.0)   mod_weight = -0.25;
    }
    else
    {
        /* ---- Spatial Bounding Logic for Connected Primitives ---- */
        bool is_in_box_tl = (dist_left < border_w.x)  && (dist_top < border_w.y);
        bool is_in_box_tr = (dist_right < border_w.x) && (dist_top < border_w.y);
        bool is_in_box_bl = (dist_left < border_w.x)  && (dist_bottom < border_w.y);
        bool is_in_box_br = (dist_right < border_w.x) && (dist_bottom < border_w.y);

        // Compute adaptive flat edge extensions (Handles contiguous block masking)
        bool valid_top    = (dist_top < border_w.y)    && ((same_left  || dist_top < dist_left)   && (same_right || dist_top < dist_right));
        bool valid_left   = (dist_left < border_w.x)   && ((same_top   || dist_left < dist_top)   && (same_bottom|| dist_left < dist_bottom));
        bool valid_bottom = (dist_bottom < border_w.y) && ((same_left  || dist_bottom < dist_left) && (same_right || dist_bottom < dist_right));
        bool valid_right  = (dist_right < border_w.x)  && ((same_top   || dist_right < dist_top)  && (same_bottom|| dist_right < dist_bottom));

        /* ---- Chiral Inside-Corner Resolver & [Lazy Sampling Stage 3] ---- */
        
        // ┌ Top-Left Inside Corner
        if (same_left && same_top && is_in_box_tl)
        {
            // Deferred conditional fetch for the specific 2nd-order diagonal neighbor
            vec3 color_top_left = texture(Source, vTexCoord + vec2(-params.SourceSize.z, -params.SourceSize.w)).rgb;
            if (!color_equal(color, color_top_left)) 
            {
                if (!is_main_diag && dist_left < dist_top)       mod_weight = 1.0;  // Adjacent to Left wall
                else if (!is_main_diag && dist_top < dist_left)  mod_weight = 0.5;  // Adjacent to Top wall
                else if (is_main_diag)                            mod_weight = 0.75; // Diagonal blend
            }
        }
        // └ Bottom-Left Inside Corner
        else if (same_left && same_bottom && is_in_box_bl)
        {
            vec3 color_bottom_left = texture(Source, vTexCoord + vec2(-params.SourceSize.z, params.SourceSize.w)).rgb;
            if (!color_equal(color, color_bottom_left))
            {
                if (!is_anti_diag && dist_left < dist_bottom)    mod_weight = -1.0; 
                else if (!is_anti_diag && dist_bottom < dist_left) mod_weight = 0.5;  
                else if (is_anti_diag)                             mod_weight = -0.25;
            }
        }
        // ┐ Top-Right Inside Corner
        else if (same_right && same_top && is_in_box_tr)
        {
            vec3 color_top_right = texture(Source, vTexCoord + vec2(params.SourceSize.z, -params.SourceSize.w)).rgb;
            if (!color_equal(color, color_top_right))
            {
                if (!is_anti_diag && dist_right < dist_top)     mod_weight = 1.0;  
                else if (!is_anti_diag && dist_top < dist_right)  mod_weight = -0.5; 
                else if (is_anti_diag)                             mod_weight = 0.25;
            }
        }
        // ┘ Bottom-Right Inside Corner
        else if (same_right && same_bottom && is_in_box_br)
        {
            vec3 color_bottom_right = texture(Source, vTexCoord + vec2(params.SourceSize.z, params.SourceSize.w)).rgb;
            if (!color_equal(color, color_bottom_right))
            {
                if (!is_main_diag && dist_right < dist_bottom)   mod_weight = -1.0; 
                else if (!is_main_diag && dist_bottom < dist_right) mod_weight = -0.5; 
                else if (is_main_diag)                              mod_weight = -0.75;
            }
        }

        /* ---- Standard Convex & Flat Edge Profiling ---- */
        if (mod_weight == 0.0)
        {
            if (is_main_diag && dist_top < border_w.y && !same_top && !same_left)                 mod_weight = 0.75;
            else if (is_main_diag && dist_bottom < border_w.y && !same_bottom && !same_right)      mod_weight = -0.75;
            else if (is_anti_diag && dist_top < border_w.y && !same_top && !same_right)            mod_weight = 0.25;
            else if (is_anti_diag && dist_bottom < border_w.y && !same_bottom && !same_left)       mod_weight = -0.25;

            else if (!same_top && valid_top)                       mod_weight = 1.0;
            else if (!same_left && valid_left)                     mod_weight = 0.5;
            else if (!same_bottom && valid_bottom)                 mod_weight = -1.0;
            else if (!same_right && valid_right)                   mod_weight = -0.5;
        }
    }

    /* ---- Global Viewport Edge Protection ---- */
    if (mod_weight < 0.0)
    {
        vec2  screen_d  = min(vTexCoord, 1.0 - vTexCoord);
        float src_pixel = min(params.SourceSize.z, params.SourceSize.w);
        mod_weight *= smoothstep(0.0, src_pixel, min(screen_d.x, screen_d.y));
    }

    // Final color pass
    vec3 weight = color * mod_weight * bevel_depth;
    FragColor = vec4(color + weight, 1.0);
}
