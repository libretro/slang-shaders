#version 450

/*  Uborder-reflections shader - Hyllian 2024

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


layout(push_constant) uniform Push
{
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    uint FrameCount;
    float border_scale;
    float border_center_x;
    float border_center_y;
    float border_alpha_cutoff;
    float border_mirror_y;
    float bezel_w, bezel_h;
    float bezel_w_hlen, bezel_h_wlen;
    float frame_w, frame_h;
    float bezel_center_x;
    float bezel_center_y;
    float reflection_strength;
    float reflection_scr_distance_x;
    float reflection_scr_distance_y;
    float AdjustView;
    float ub_border_top;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    uint Rotation;
    float ref_warp_x, ref_warp_y;
    float ref_outer_warp;
    float inner_corner_radius;
    float outer_corner_radius;
    float border_luma_trans;
} global;

#pragma parameter border_nonono       "BORDER:"                            0.0  0.0 1.0 1.0
#pragma parameter ub_border_top       "    On top: [ Frame | Border ]"     0.0  0.0 1.0 1.0
#pragma parameter border_alpha_cutoff "    Frame 'On Top' Transparency"    0.38  0.0 1.0 0.01
#pragma parameter border_luma_trans   "        Luma Transp. [ Off | On ]" 1.0  0.0 1.0 1.0
#pragma parameter border_scale        "    Border Scale"                   1.0  0.5 5.0 0.002
#pragma parameter border_center_x     "    Border Center X"                0.0 -0.5 0.5 0.001
#pragma parameter border_center_y     "    Border Center Y"                0.0 -0.5 0.5 0.001
#pragma parameter border_mirror_y     "    Border Mirror (Y)"              0.0  0.0 1.0 1.0

#pragma parameter RF_NONONO              "REFLECTIONS:"                    0.0  0.0 1.0 1.0
#pragma parameter AdjustView             "    Reflection Adjust View"      0.0  0.0 1.0 1.0
#pragma parameter reflection_strength    "    Reflection Strengh"          0.25 0.0 1.0 0.01
#pragma parameter ref_outer_warp         "    Disable Outer Curvature"     0.0  0.0 1.0 1.0
#pragma parameter ref_warp_x             "    Reflection Warp X"           0.0  0.0 1.0 0.01
#pragma parameter ref_warp_y             "    Reflection Warp Y"           0.0  0.0 1.0 0.01
#pragma parameter frame_w                "    Reflection Width"            0.67 0.0 1.0 0.001
#pragma parameter frame_h                "    Reflection Height"           0.87 0.0 1.0 0.001
#pragma parameter bezel_w                "    Reflection Thickness X"      0.02 0.0 1.0 0.001
#pragma parameter bezel_h                "    Reflection Thickness Y"      0.02 0.0 1.0 0.001
#pragma parameter bezel_center_x         "    Reflection Center X"         0.0 -0.5 0.5 0.001
#pragma parameter bezel_center_y         "    Reflection Center Y"         0.0 -0.5 0.5 0.001
#pragma parameter reflection_scr_distance_x  "    Reflection Starting X"   0.0 -0.04 0.04 0.001
#pragma parameter reflection_scr_distance_y  "    Reflection Starting Y"   0.0 -0.04 0.04 0.001
#pragma parameter inner_corner_radius    "    Inner Corner Radius"         0.05 0.0 1.0 0.01
#pragma parameter outer_corner_radius    "    Outer Corner Radius"         0.0  0.0 1.0 0.01

#define bezel_w     params.bezel_w
#define bezel_h     params.bezel_h
#define frame_w     params.frame_w
#define frame_h     params.frame_h
#define bezel_center_x          params.bezel_center_x
#define bezel_center_y          params.bezel_center_y
#define inner_corner_radius     global.inner_corner_radius
#define outer_corner_radius     global.outer_corner_radius
#define border_mirror_y               params.border_mirror_y
#define border_alpha_cutoff           params.border_alpha_cutoff
#define border_luma_trans             global.border_luma_trans
#define reflection_strength           params.reflection_strength
#define reflection_scr_distance_x     params.reflection_scr_distance_x
#define reflection_scr_distance_y     params.reflection_scr_distance_y



#define MIDDLE vec2(0.5)
#define border_pos vec2(params.border_center_x,params.border_center_y)
#define BLUR 0.002
#define WARP vec2(global.ref_warp_x,global.ref_warp_y)

vec2 ref_aspect = vec2(1.0, params.OutputSize.y/params.OutputSize.x);

const vec3 Y = vec3(.2126, .7152, .0722);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 reflex_uv;
layout(location = 2) out vec2 border_uv;
layout(location = 3) out vec2 frame_size;
layout(location = 4) out vec4 bezel_size_ar;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord.xy;

    border_uv = mix( TexCoord.xy, vec2(     TexCoord.y, 1.0- TexCoord.x), float(global.Rotation==1.0));
    border_uv = mix(border_uv.xy, vec2(1.0-border_uv.x, 1.0-border_uv.y), float(global.Rotation==2.0)); // It seems useless...
    border_uv = mix(border_uv.xy, vec2(1.0-border_uv.y,     border_uv.x), float(global.Rotation==3.0));

    border_uv.y = mix(border_uv.y, 1.0-border_uv.y, border_mirror_y);

    border_uv = MIDDLE + (border_uv.xy - MIDDLE - border_pos) / params.border_scale;

    if (global.Rotation==3.0) {
        vTexCoord = TexCoord.xy + vec2(bezel_center_x, bezel_center_y);
    } else {
        vTexCoord = TexCoord.xy - vec2(bezel_center_x, bezel_center_y);
    }

    reflex_uv.xy = 2.0*vTexCoord  - 1.0.xx; // --> (-1.0, 1.0)

    frame_size    = vec2(frame_w, frame_h);
    bezel_size_ar = vec4(frame_size, frame_size + vec2(bezel_w, bezel_h)) * ref_aspect.xyxy; // aspect ratio ref
    reflex_uv.zw  = reflex_uv.xy  * ref_aspect; // aspect ratio ref
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 reflex_uv;
layout(location = 2) in vec2 border_uv;
layout(location = 3) in vec2 frame_size;
layout(location = 4) in vec4 bezel_size_ar;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D CRTPass;
layout(set = 0, binding = 3) uniform sampler2D BORDER;
layout(set = 0, binding = 4) uniform sampler2D BlurPass;

// uv must be in the interval (-1.0, 1.0)
float RoundedRect(vec2 uv, vec2 size, float radius)
{
    radius = radius * min(size.x, size.y);
    vec2 d = (abs(uv) - (size-radius.xx));
    float shape = length(max(d, 0.0.xx)) + min(max(d.x, d.y),  0.0);

    return smoothstep(radius-BLUR, radius+BLUR, shape);
}


float RoundRect(vec2 uv, vec2 size, float radius)
{
    radius = radius * min(size.x, size.y);
    vec2 d = (abs(uv) - (size-radius.xx));
    return length(max(d, 0.0.xx)) + min(max(d.x, d.y),  0.0);
}


vec4 Warp(vec4 uv, vec2 warp)
{
    uv *= (1.0.xxxx + (uv*uv).yxyx*warp.xyxy);

    return uv;
}


float RoundSquare(vec2 uv, vec2 size, float radius)
{
    return length(max(abs(uv)-size,0.0))-radius;
}

// Calculate normal to distance function and move along
// normal with distance to get point of reflection
vec2 ReflectionCoords(vec2 uv, vec2 size, float r)
{
/* // Still dunno if this code is faster...
    float eps = 0.0001;
    vec2 epsx = vec2(eps,0.0);
    vec2 epsy = vec2(0.0,eps);

    vec2 normal = vec2(RoundSquare(uv-epsx,size,r)-RoundSquare(uv+epsx,size,r),
                       RoundSquare(uv-epsy,size,r)-RoundSquare(uv+epsy,size,r))/eps;
    float d = RoundSquare(uv, size, r);

    return uv + d*normal;
*/

    vec2 ref_coord;

    ref_coord.x = (uv.x >= 0.0) ? uv.x-(max(0.0, 2.0*(uv.x - size.x))) : uv.x-(min(0.0, 2.0*(uv.x + size.x)));
    ref_coord.y = (uv.y >= 0.0) ? uv.y-(max(0.0, 2.0*(uv.y - size.y))) : uv.y-(min(0.0, 2.0*(uv.y + size.y)));

    return ref_coord;

}


void main()
{
    vec4 border = texture(BORDER, border_uv);

    vec4 frame  = texture(CRTPass, vTexCoord.xy);
    
    vec4 uv_ar  = Warp(reflex_uv, WARP); // uv --> (-1.0, 1.0)

    vec2 uv_outer = mix(uv_ar.zw, reflex_uv.zw, global.ref_outer_warp);

    vec2 uv = uv_ar.xy;

    float inner_bezel = RoundedRect(uv_ar.zw, bezel_size_ar.xy, inner_corner_radius);
    float outer_bezel = RoundedRect(uv_outer, bezel_size_ar.zw, outer_corner_radius);

    float bezel_area = inner_bezel * (1.0 - outer_bezel);

    vec2  bezel_size = frame_size + vec2(reflection_scr_distance_x, reflection_scr_distance_y);

    vec2  ref_coords = ReflectionCoords(uv, bezel_size, 0.0);

    ref_coords = 0.5 * ref_coords + vec2(0.5); // --> (0.0, 1.0)

    vec3 reflex = bezel_area * mix(texture(BlurPass, ref_coords).rgb, vec3(0.0, 1.0, 0.0), params.AdjustView);

//    reflex.rgb = mix(reflex.rgb, frame.rgb, frame.a); // Still needs tests, dunno if it's useless...

    border.rgb = clamp(border.rgb + reflection_strength * reflex.rgb, 0.0, 1.0);

    float border_alpha = mix(border_alpha_cutoff, clamp(border_alpha_cutoff - dot(frame.rgb, Y), 0.0, border_alpha_cutoff), border_luma_trans);

//    FragColor = mix(mix(frame, border, border.a), frame, (1.0 - params.ub_border_top) * (1.0-border_alpha*border.a)* frame.a);
    FragColor = mix(mix(border, frame, frame.a*(1.0-border_alpha)), mix(frame, border, border.a), params.ub_border_top);

}

