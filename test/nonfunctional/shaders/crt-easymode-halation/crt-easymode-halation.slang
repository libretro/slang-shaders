#version 450

/*
    CRT Shader by EasyMode
    License: GPL
*/

layout(push_constant) uniform Push
{
    float BRIGHTNESS;
    float DIFFUSION;
    float GAMMA_OUTPUT;
    float GEOM_CORNER_SIZE;
    float GEOM_CORNER_SMOOTH;
    float GEOM_CURVATURE;
    float GEOM_WARP;
    float HALATION;
    float INTERLACING_TOGGLE;
    float MASK_SIZE;
    float MASK_STRENGTH_MAX;
    float MASK_STRENGTH_MIN;
    float MASK_TYPE;
    float SCANLINE_BEAM_MAX;
    float SCANLINE_BEAM_MIN;
    float SCANLINE_STRENGTH_MAX;
    float SCANLINE_STRENGTH_MIN;
    float SHARPNESS_H;
    float SHARPNESS_V;
} param;

#pragma parameter GAMMA_OUTPUT "Gamma Output" 2.2 0.1 5.0 0.01
#pragma parameter SHARPNESS_H "Sharpness Horizontal" 0.6 0.0 1.0 0.05
#pragma parameter SHARPNESS_V "Sharpness Vertical" 1.0 0.0 1.0 0.05
#pragma parameter MASK_TYPE "Mask Type" 4.0 0.0 7.0 1.0
#pragma parameter MASK_STRENGTH_MIN "Mask Strength Min." 0.2 0.0 0.5 0.01
#pragma parameter MASK_STRENGTH_MAX "Mask Strength Max." 0.2 0.0 0.5 0.01
#pragma parameter MASK_SIZE "Mask Size" 1.0 1.0 100.0 1.0
#pragma parameter SCANLINE_STRENGTH_MIN "Scanline Strength Min." 0.2 0.0 1.0 0.05
#pragma parameter SCANLINE_STRENGTH_MAX "Scanline Strength Max." 0.4 0.0 1.0 0.05
#pragma parameter SCANLINE_BEAM_MIN "Scanline Beam Min." 1.0 0.25 5.0 0.05
#pragma parameter SCANLINE_BEAM_MAX "Scanline Beam Max." 1.0 0.25 5.0 0.05
#pragma parameter GEOM_CURVATURE "Geom Curvature" 0.0 0.0 0.1 0.01
#pragma parameter GEOM_WARP "Geom Warp" 0.0 0.0 0.1 0.01
#pragma parameter GEOM_CORNER_SIZE "Geom Corner Size" 0.0 0.0 0.1 0.01
#pragma parameter GEOM_CORNER_SMOOTH "Geom Corner Smoothness" 150.0 50.0 1000.0 25.0
#pragma parameter INTERLACING_TOGGLE "Interlacing Toggle" 1.0 0.0 1.0 1.0
#pragma parameter HALATION "Halation" 0.03 0.0 1.0 0.01
#pragma parameter DIFFUSION "Diffusion" 0.0 0.0 1.0 0.01
#pragma parameter BRIGHTNESS "Brightness" 1.0 0.0 2.0 0.05

#define FIX(c) max(abs(c), 1e-5)
#define PI 3.141592653589
#define TEX2D(c) texture(tex, c)

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    uint FrameCount;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord   = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D PassOutput0;

float curve_distance(float x, float sharp)
{
    float x_step = step(0.5, x);
    float curve = 0.5 - sqrt(0.25 - (x - x_step) * (x - x_step)) * sign(0.5 - x);

    return mix(x, curve, sharp);
}

mat4x4 get_color_matrix(sampler2D tex, vec2 co, vec2 dx)
{
    return mat4x4(TEX2D(co - dx), TEX2D(co), TEX2D(co + dx), TEX2D(co + 2.0 * dx));
}

vec4 filter_lanczos(vec4 coeffs, mat4x4 color_matrix)
{
    vec4 col        = coeffs * color_matrix;
    vec4 sample_min = min(color_matrix[1], color_matrix[2]);
    vec4 sample_max = max(color_matrix[1], color_matrix[2]);

    return clamp(col, sample_min, sample_max);
}

float get_scanline_weight(float pos, float beam, float strength)
{
    float weight = 1.0 - pow(cos(pos * 2.0 * PI) * 0.5 + 0.5, beam);
    
    return weight * strength * 2.0 + (1.0 - strength);
}

vec2 curve_coordinate(vec2 co, float curvature)
{
    vec2 curve     = vec2(curvature, curvature * 0.75);
    vec2 co2       = co + co * curve - curve * 0.5;
    vec2 co_weight = vec2(co.y, co.x) * 2.0 - 1.0;

    return mix(co, co2, co_weight * co_weight);
}

float get_corner_weight(vec2 co, vec2 corner, float smoothness)
{ 
    co = min(co, vec2(1.0) - co) * vec2(1.0, 0.75);
    co = (corner - min(co, corner));
    float corner_weight = clamp((corner.x - sqrt(dot(co, co))) * smoothness, 0.0, 1.0);
    
    return mix(1.0, corner_weight, ceil(corner.x));
}

void main()
{
    vec2 tex_size = global.SourceSize.xy;
    vec2 midpoint = vec2(0.5, 0.5);
    float scan_offset = 0.0;

    if (param.INTERLACING_TOGGLE > 0.0 && global.SourceSize.y >= 400)
    {
        tex_size.y *= 0.5;

        if (mod(float(global.FrameCount), 2.0) > 0.0)
        {
            midpoint.y  = 0.75;
            scan_offset = 0.5;
        }        
        else 
            midpoint.y = 0.25;
    }

    vec2 co = vTexCoord * tex_size * global.SourceSize.zw;
    vec2 xy = curve_coordinate(co, param.GEOM_WARP);
    xy *= global.SourceSize.xy / tex_size;

    vec2 dx     = vec2(1.0 / tex_size.x, 0.0);
    vec2 dy     = vec2(0.0, 1.0 / tex_size.y);
    vec2 pix_co = xy * tex_size - midpoint;
    vec2 tex_co = (floor(pix_co) + midpoint) / tex_size;
    vec2 dist   = fract(pix_co);

    vec2 curve = vec2(
       curve_distance(dist.x, param.SHARPNESS_H * param.SHARPNESS_H),
       curve_distance(dist.y, param.SHARPNESS_V * param.SHARPNESS_V)
    );

    mat2x4 coeffs = mat2x4(
        PI * vec4(1.0 + curve.x, curve.x, 1.0 - curve.x, 2.0 - curve.x),
        PI * vec4(1.0 + curve.y, curve.y, 1.0 - curve.y, 2.0 - curve.y)
    );

    coeffs[0]  = FIX(coeffs[0]);
    coeffs[0]  = 2.0 * sin(coeffs[0]) * sin(coeffs[0] * 0.5) / (coeffs[0] * coeffs[0]);
    coeffs[0] /= dot(coeffs[0], vec4(1.0));

    coeffs[1]  = FIX(coeffs[1]);
    coeffs[1]  = 2.0 * sin(coeffs[1]) * sin(coeffs[1] * 0.5) / (coeffs[1] * coeffs[1]);
    coeffs[1] /= dot(coeffs[1], vec4(1.0));

    mat4x4 color_matrix = mat4x4(
        filter_lanczos(coeffs[0], get_color_matrix(PassOutput0, tex_co - dy,       dx)),
        filter_lanczos(coeffs[0], get_color_matrix(PassOutput0, tex_co,            dx)),
        filter_lanczos(coeffs[0], get_color_matrix(PassOutput0, tex_co + dy,       dx)),
        filter_lanczos(coeffs[0], get_color_matrix(PassOutput0, tex_co + 2.0 * dy, dx))
    );

    vec3 col  = filter_lanczos(coeffs[1], color_matrix).rgb;
    vec3 diff = texture(Source, xy).rgb;

    float rgb_max       = max(col.r, max(col.g, col.b));
    float sample_offset = (global.SourceSize.y * global.OutputSize.w) * 0.5;
    float scan_pos      = xy.y * tex_size.y + scan_offset;
    float scan_strength = mix(param.SCANLINE_STRENGTH_MAX, param.SCANLINE_STRENGTH_MIN, rgb_max);
    float scan_beam     = clamp(rgb_max * param.SCANLINE_BEAM_MAX, param.SCANLINE_BEAM_MIN, param.SCANLINE_BEAM_MAX);
    
    vec4 mask_config = vec4(0.0);
    if      (param.MASK_TYPE == 1) mask_config = vec4(2.0, 1.0, 1.0, 0.0);
    else if (param.MASK_TYPE == 2) mask_config = vec4(3.0, 1.0, 1.0, 0.0);
    else if (param.MASK_TYPE == 3) mask_config = vec4(2.1, 1.0, 1.0, 0.0);
    else if (param.MASK_TYPE == 4) mask_config = vec4(3.1, 1.0, 1.0, 0.0);
    else if (param.MASK_TYPE == 5) mask_config = vec4(2.0, 1.0, 1.0, 1.0);
    else if (param.MASK_TYPE == 6) mask_config = vec4(3.0, 2.0, 1.0, 3.0);
    else if (param.MASK_TYPE == 7) mask_config = vec4(3.0, 2.0, 2.0, 3.0);

    float mask_colors     = floor(mask_config.x);
    float mask_dot_width  = mask_config.y;
    float mask_dot_height = mask_config.z;
    float mask_stagger    = mask_config.w;
    float mask_dither     = fract(mask_config.x) * 10.0;

    vec2 mod_fac = floor(
        vTexCoord * global.OutputSize.xy / 
        (vec2(param.MASK_SIZE, mask_dot_height * param.MASK_SIZE))
    );

    int dot_no = int(mod((mod_fac.x + mod(mod_fac.y, 2.0) * mask_stagger) / mask_dot_width, mask_colors));
    int dither = int(mod(mod_fac.y + mod(floor(mod_fac.x / mask_colors), 2.0), 2.0));

    float mask_strength = mix(param.MASK_STRENGTH_MAX, param.MASK_STRENGTH_MIN, rgb_max);
    float mask_dark     = 1.0 - mask_strength;
    float mask_bright   = 1.0 + mask_strength * 2.0;
    
    vec3  mask_weight   = vec3(mask_dark, mask_dark, mask_bright);
    if      (dot_no == 0) mask_weight = mix(vec3(mask_bright), vec3(mask_bright, mask_dark, mask_dark), mask_colors - 2.0);
    else if (dot_no == 1) mask_weight = mix(vec3(mask_dark),   vec3(mask_dark, mask_bright, mask_dark), mask_colors - 2.0);

    float mask_mul = dither > 0 ? mask_dark : mask_bright;
    mask_weight   *= mix(1.0, mask_mul, mask_dither);
    mask_weight    = mix(vec3(1.0), mask_weight, clamp(param.MASK_TYPE, 0.0, 1.0));

    vec3 col2         = (col * mask_weight) * param.BRIGHTNESS;
    float scan_weight = get_scanline_weight(scan_pos - sample_offset, scan_beam, scan_strength);
    col               = clamp(col2 * scan_weight, 0.0, 1.0);
    scan_weight       = get_scanline_weight(scan_pos, scan_beam, scan_strength);
    col              += clamp(col2 * scan_weight, 0.0, 1.0);
    scan_weight       = get_scanline_weight(scan_pos + sample_offset, scan_beam, scan_strength);
    col              += clamp(col2 * scan_weight, 0.0, 1.0);
    col              *= 0.333333333;
 
    float corner_weight = get_corner_weight(
        curve_coordinate(co, param.GEOM_CURVATURE), 
        vec2(param.GEOM_CORNER_SIZE), 
        param.GEOM_CORNER_SMOOTH
    );

    col *= vec3(corner_weight);
    col += diff * mask_weight * param.HALATION  * vec3(corner_weight);
    col += diff               * param.DIFFUSION * vec3(corner_weight);
    col  = pow(col, vec3(1.0 / param.GAMMA_OUTPUT));

    FragColor = vec4(col, 1.0);
}
