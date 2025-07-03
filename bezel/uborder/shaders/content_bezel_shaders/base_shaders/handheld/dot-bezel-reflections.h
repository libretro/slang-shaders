
#define USE_BEZEL_REFLECTIONS_COMMON


layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;

#include "../../include/uborder_bezel_reflections_global_declarations.inc"

} global;


#include "../../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     global.OutputSize
#define ub_OriginalSize   global.OriginalSize
#define ub_Rotation       global.Rotation

#include "../../include/uborder_bezel_reflections_common.inc"

#define gamma 2.4
#define shine 0.05
#define blend 0.65

/*
   Author: Themaister
   License: Public domain
*/

//#define TEX(coord) texture(Source, vTexCoord).rgb
#define TEX(coord) texture(Source, vTex).rgb

float dist(vec2 coord, vec2 source)
{
   vec2 delta = coord - source;
   return sqrt(dot(delta, delta));
}

float color_bloom(vec3 color)
{
   const vec3 gray_coeff = vec3(0.30, 0.59, 0.11);
   float bright = dot(color, gray_coeff);
   return mix(1.0 + shine, 1.0 - shine, bright);
}

vec3 lookup(vec2 pixel_no, float offset_x, float offset_y, vec3 color)
{
   vec2 offset = vec2(offset_x, offset_y);
   float delta = dist(fract(pixel_no), offset + vec2(0.5, 0.5));
   return color * exp(-gamma * delta * color_bloom(color));
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 c00_10;
layout(location = 2) out vec4 c00_01;
layout(location = 3) out vec4 c20_01;
layout(location = 4) out vec4 c21_02;
layout(location = 5) out vec4 c12_22;
layout(location = 6) out vec2 c11;
layout(location = 7) out vec2 pixel_no;
layout(location = 8) out vec2 uv;
layout(location = 9) out vec2 border_uv;
layout(location = 10) out vec2 bezel_uv;

void main()
{
   gl_Position = global.MVP * Position;
//   vTexCoord = TexCoord;

    vec2 diff    = TexCoord.xy * vec2(1.000001) - middle;
    vTexCoord    = middle + diff/fr_scale - fr_center;

    uv           = 2.0*vTexCoord - 1.0;
    bezel_uv  = uv - 2.0*bz_center;

    border_uv = get_unrotated_coords(get_unrotated_coords(TexCoord.xy, ub_Rotation), int(global.border_allow_rot));

    border_uv.y = mix(border_uv.y, 1.0-border_uv.y, border_mirror_y);

    border_uv = middle + (border_uv.xy - middle - border_pos) / (global.border_scale*all_zoom);

    border_uv = border_uv.xy * vec2(1.000001);

#ifdef KEEP_BORDER_ASPECT_RATIO
    border_uv -= 0.5.xx;
#endif
   
   float dx = global.SourceSize.z;
   float dy = global.SourceSize.w;
   
   c00_10 = vec4(vTexCoord + vec2(-dx, -dy), vTexCoord + vec2(0, -dy));
   c20_01 = vec4(vTexCoord + vec2(dx, -dy), vTexCoord + vec2(-dx, 0));
   c21_02 = vec4(vTexCoord + vec2(dx, 0), vTexCoord + vec2(-dx, dy));
   c12_22 = vec4(vTexCoord + vec2(0, dy), vTexCoord + vec2(dx, dy));
   c11 = vTexCoord;
   pixel_no = vTexCoord * global.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 c00_10;
layout(location = 2) in vec4 c00_01;
layout(location = 3) in vec4 c20_01;
layout(location = 4) in vec4 c21_02;
layout(location = 5) in vec4 c12_22;
layout(location = 6) in vec2 c11;
layout(location = 7) in vec2 pixel_no;
layout(location = 8) in vec2 uv;
layout(location = 9) in vec2 border_uv;
layout(location = 10) in vec2 bezel_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;
layout(set = 0, binding = 4) uniform sampler2D LAYER2;
#ifdef USE_AMBIENT_LIGHT
layout(set = 0, binding = 5) uniform sampler2D ambi_temporal_pass;
#endif

vec3 get_content(vec2 vTex, vec2 uv)
{
   vec3 mid_color = lookup(pixel_no, 0.0, 0.0, TEX(c11));
   vec3 color = vec3(0.0, 0.0, 0.0);
   color += lookup(pixel_no, -1.0, -1.0, TEX(c00_10.xy));
   color += lookup(pixel_no,  0.0, -1.0, TEX(c00_10.zw));
   color += lookup(pixel_no,  1.0, -1.0, TEX(c20_01.xy));
   color += lookup(pixel_no, -1.0,  0.0, TEX(c20_01.zw));
   color += mid_color;
   color += lookup(pixel_no,  1.0,  0.0, TEX(c21_02.xy));
   color += lookup(pixel_no, -1.0,  1.0, TEX(c21_02.zw));
   color += lookup(pixel_no,  0.0,  1.0, TEX(c12_22.xy));
   color += lookup(pixel_no,  1.0,  1.0, TEX(c12_22.zw));

   return mix(1.2 * mid_color, color, blend);
}


#define ReflexSrc Source

// Yeah, an unorthodox 'include' usage.
#include "../../include/uborder_bezel_reflections_main.inc"
