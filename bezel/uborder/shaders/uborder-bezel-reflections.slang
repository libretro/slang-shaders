#version 450

/*  Uborder-bezel-reflections shader - Hyllian 2025


   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

*/

#define USE_BEZEL_REFLECTIONS_COMMON

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;

#include "content_bezel_shaders/include/uborder_bezel_reflections_global_declarations.inc"

} global;


#include "content_bezel_shaders/include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     global.OutputSize
#define ub_OriginalSize   global.OriginalSize
#define ub_Rotation       global.Rotation

#include "content_bezel_shaders/include/uborder_bezel_reflections_common.inc"

#define fx(c) max(abs(c), 1e-5)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 uv;
layout(location = 2) out vec2 border_uv;
layout(location = 3) out vec2 bezel_uv;

void main()
{
   gl_Position = global.MVP * Position;

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
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec2 border_uv;
layout(location = 3) in vec2 bezel_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;
layout(set = 0, binding = 4) uniform sampler2D LAYER2;



vec3 get_content(vec2 vTex, vec2 uv)
{
    return texture(Source, vTex).rgb;
}


#define ReflexSrc Source

// Yeah, an unorthodox 'include' usage.
#include "content_bezel_shaders/include/uborder_bezel_reflections_main.inc"
