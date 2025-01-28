#version 450

/*
   Uborder-bezels-reflections shader - Hyllian 2025.

   Bezels code is a modified version of this shadertoy: https://www.shadertoy.com/view/XdtfzX
*/


/*
   Hyllian's crt-nobody Shader
   
   Copyright (C) 2011-2025 Hyllian

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
    float CN_VSCANLINES;
    float CN_BEAM_MIN_WIDTH;
    float CN_BEAM_MAX_WIDTH;
    float CN_SCAN_SIZE;
    float CN_BRIGHTBOOST;
    float CN_VIG_TOGGLE;
    float CN_VIG_BASE;
    float CN_VIG_EXP;
    float CN_PHOSPHOR_LAYOUT;
    float CN_MASK_STRENGTH;
    float CN_MONITOR_SUBPIXELS;
    float CN_InputGamma;
    float CN_OutputGamma;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    uint Rotation;

    float all_zoom;

    float fr_zoom;
    float fr_aspect_x;
    float fr_aspect_y;
    float fr_center_x;
    float fr_center_y;
    float fr_i_scaling;
    float fr_i_scaling_fac;

    float h_shape;
    float h_radius;
    float h_cornersize;
    float h_cornersmooth;
    float h_overscan_x;
    float h_overscan_y;
    float h_angle_x;
    float h_angle_y;
    float h_curvature;

    float bz_shine_enable;
    float bz_shine;
    float bz_shine_size;
    float bz_ambient_enable;
    float bz_ambient;
    float bz_ambient_size;
    float bz_ref_str;
    float bz_lights;
    float bz_transparent;
    float bz_inner_bezel_x;
    float bz_inner_bezel_y;
    float bz_middle_bezel_x;
    float bz_middle_bezel_y;
    float bz_outer_bezel_x;
    float bz_outer_bezel_y;
    float bz_outer_curve;
    float bz_ref_dist;
    float bz_radius;
    float bz_red;
    float bz_green;
    float bz_blue;
    float bz_ang;
    float bz_pos;

    float border_scale;
    float border_center_x;
    float border_center_y;
    float border_mirror_y;
    float border_allow_rot;
    float ub_border_top;
    float border_alpha;
} global;

#define USE_BEZEL_REFLECTIONS_COMMON

#include "include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     global.OutputSize
#define ub_OriginalSize   global.OriginalSize
#define ub_Rotation       global.Rotation

#include "include/uborder_bezel_reflections_common.inc"


#pragma parameter CN_NONONO            "CRT-NOBODY:"                     0.0  0.0   1.0 1.0
#pragma parameter CN_BEAM_MIN_WIDTH    "    Min Beam Width"              0.80 0.0   1.0 0.01
#pragma parameter CN_BEAM_MAX_WIDTH    "    Max Beam Width"              1.0  0.0   1.0 0.01
#pragma parameter CN_SCAN_SIZE         "    Scanlines Thickness"         0.86 0.0   1.0 0.01
#pragma parameter CN_BRIGHTBOOST       "    Brightness Boost"            1.2  0.5   1.5 0.01
#pragma parameter CN_PHOSPHOR_LAYOUT   "    Mask [1..6 Aperture, 7..10 Shadow, 11..14 Slot]" 1.0 0.0 15.0 1.0
#pragma parameter CN_MASK_STRENGTH     "    Mask Strength"               0.64 0.0   1.0 0.02
#pragma parameter CN_MONITOR_SUBPIXELS "    Monitor Subpixels Layout [ RGB | BGR ]" 0.0 0.0 1.0 1.0
#pragma parameter CN_VSCANLINES        "    Vertical Scanlines"          0.0  0.0   1.0 1.0
#pragma parameter CN_VIG_TOGGLE        "    Vignette Toggle"             0.0  0.0   1.0 1.0
#pragma parameter CN_VIG_BASE          "    Vignette Range"             16.0  2.0 100.0 2.0
#pragma parameter CN_VIG_EXP           "    Vignette Strength"           0.16 0.0   2.0 0.02
#pragma parameter CN_InputGamma        "    Input Gamma"                 2.4  0.0   4.0 0.1
#pragma parameter CN_OutputGamma       "    Output Gamma"                2.2  0.0   3.0 0.1


#define CN_VSCANLINES        params.CN_VSCANLINES
#define CN_BEAM_MIN_WIDTH    params.CN_BEAM_MIN_WIDTH
#define CN_BEAM_MAX_WIDTH    params.CN_BEAM_MAX_WIDTH
#define CN_SCAN_SIZE         params.CN_SCAN_SIZE
#define CN_BRIGHTBOOST       params.CN_BRIGHTBOOST
#define CN_InputGamma        params.CN_InputGamma
#define CN_OutputGamma       params.CN_OutputGamma
#define CN_MASK_STRENGTH     params.CN_MASK_STRENGTH
#define CN_MONITOR_SUBPIXELS params.CN_MONITOR_SUBPIXELS

#define GAMMA_IN(color)     CN_BRIGHTBOOST*pow(color, vec3(CN_InputGamma))
#define GAMMA_OUT(color)    pow(color, vec3(1.0 / CN_OutputGamma))

#define PIX_SIZE    1.111111
#define CN_OFFSET      0.5
#define CN_SCAN_OFFSET 0.0

float pix_sizex  = mix(PIX_SIZE, CN_SCAN_SIZE, CN_VSCANLINES);
float scan_sizey = mix(CN_SCAN_SIZE, PIX_SIZE, CN_VSCANLINES);


vec2  mask_size  = ub_OutputSize.xy* fr_scale * (1.0 - 0.5*global.h_curvature);


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 uv;
layout(location = 2) out vec4 intl_profile;
layout(location = 3) out vec2 border_uv;


vec4 get_interlace_profile()
{
    vec4 int_p = vec4(global.SourceSize.y, global.SourceSize.w, CN_OFFSET, CN_SCAN_OFFSET);

    if ((global.SourceSize.y > 288.5) && (global.SourceSize.y < 576.5))
    {
        float field_offset = mod(global.FrameCount, 2.0);

        int_p.xy *= vec2(0.5, 2.0);
        int_p.zw += 0.5*vec2(field_offset - 0.5, field_offset);
    }

    return int_p;
}

void main()
{
    gl_Position  = global.MVP * Position;

    vec2 diff = TexCoord.xy * vec2(1.000001) - middle;
    vTexCoord = middle + diff/fr_scale - fr_center;

    uv           = 2.0*vTexCoord - 1.0;

    intl_profile = get_interlace_profile();

    border_uv = get_unrotated_coords(get_unrotated_coords(TexCoord.xy, ub_Rotation), int(global.border_allow_rot));

    border_uv.y = mix(border_uv.y, 1.0-border_uv.y, border_mirror_y);

    border_uv = middle + (border_uv.xy - middle - border_pos) / (global.border_scale*all_zoom);

    border_uv = border_uv.xy * vec2(1.000001);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec4  intl_profile;
layout(location = 3) in vec2 border_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;


/* Mask code pasted from subpixel_masks.h. Masks 3 and 4 added. */
vec3 mask_weights(vec2 coord, float phosphor_layout){
   vec3 weights = vec3(1.,1.,1.);

   const float on  = 1.;
   const float off = 0.;


   const vec3 red     = vec3(off, off, on );
   const vec3 green   = vec3(off, on,  off);
   const vec3 blue    = vec3(on,  off, off);
   const vec3 magenta = vec3(on,  off, on );
   const vec3 yellow  = vec3(off, on,  on );
   const vec3 cyan    = vec3(on,  on,  off);
   const vec3 black   = vec3(off, off, off);
   const vec3 white   = vec3(on,  on,  on );

   int w, z = 0;
   
   // This pattern is used by a few layouts, so we'll define it here
   vec3 aperture_classic = mix(magenta, green, floor(mod(coord.x, 2.0)));
   
   if(phosphor_layout == 0.) return weights;

   else if(phosphor_layout == 1.){
      // classic aperture for RGB panels; good for 1080p, too small for 4K+
      // aka aperture_1_2_bgr
      weights  = aperture_classic;
      return weights;
   }

   else if(phosphor_layout == 2.){
      // Classic RGB layout; good for 1080p and lower
      const vec3 aperture1[3] = vec3[](red, green, blue);
//      vec3 bw3[3] = vec3[](black, yellow, blue);
      
      z = int(floor(mod(coord.x, 3.0)));
      
      weights = aperture1[z];
      return weights;
   }

   else if(phosphor_layout == 3.){
      // black and white aperture; good for weird subpixel layouts and low brightness; good for 1080p and lower
      const vec3 aperture2[3] = vec3[](black, white, white);
      
      z = int(floor(mod(coord.x, 3.0)));
      
      weights = aperture2[z];
      return weights;
   }

   else if(phosphor_layout == 4.){
      // reduced TVL aperture for RGB panels. Good for 4k.
      // aperture_2_4_rgb
      
      const vec3 aperture3[4] = vec3[](red, yellow, cyan, blue);
      
      w = int(floor(mod(coord.x, 4.0)));
      
      weights = aperture3[w];
      return weights;
   }
   

   else if(phosphor_layout == 5.){
      // black and white aperture; good for weird subpixel layouts and low brightness; good for 4k 
      const vec3 aperture4[4] = vec3[](black, black, white, white);
      
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = aperture4[z];
      return weights;
   }


   else if(phosphor_layout == 6.){
      // aperture_1_4_rgb; good for simulating lower 
      const vec3 aperture5[4] = vec3[](red, green, blue, black);
      
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = aperture5[z];
      return weights;
   }

   else if(phosphor_layout == 7.){
      // 2x2 shadow mask for RGB panels; good for 1080p, too small for 4K+
      // aka delta_1_2x1_bgr
      vec3 inverse_aperture = mix(green, magenta, floor(mod(coord.x, 2.0)));
      weights               = mix(aperture_classic, inverse_aperture, floor(mod(coord.y, 2.0)));
      return weights;
   }

   else if(phosphor_layout == 8.){
      // delta_2_4x1_rgb
      const vec3 delta1[2][4] = {
         {red, yellow, cyan, blue},
         {cyan, blue, red, yellow}
      };
      
      w = int(floor(mod(coord.y, 2.0)));
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = delta1[w][z];
      return weights;
   }

   else if(phosphor_layout == 9.){
      // delta_1_4x1_rgb; dunno why this is called 4x1 when it's obviously 4x2 /shrug
      const vec3 delta1[2][4] = {
         {red,  green, blue, black},
         {blue, black, red,  green}
      };
      
      w = int(floor(mod(coord.y, 2.0)));
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = delta1[w][z];
      return weights;
   }
   
   else if(phosphor_layout == 10.){
      // delta_2_4x2_rgb
      const vec3 delta[4][4] = {
         {red,  yellow, cyan, blue},
         {red,  yellow, cyan, blue},
         {cyan, blue,   red,  yellow},
         {cyan, blue,   red,  yellow}
      };
      
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = delta[w][z];
      return weights;
   }

   else if(phosphor_layout == 11.){
      // slot mask for RGB panels; looks okay at 1080p, looks better at 4K
      const vec3 slotmask[4][6] = {
         {red, green, blue,    red, green, blue,},
         {red, green, blue,  black, black, black},
         {red, green, blue,    red, green, blue,},
         {black, black, black, red, green, blue,}
      };
      
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 6.0)));

      // use the indexes to find which color to apply to the current pixel
      weights = slotmask[w][z];
      return weights;
   }

   else if(phosphor_layout == 12.){
      // slot mask for RGB panels; looks okay at 1080p, looks better at 4K
      const vec3 slotmask[4][6] = {
         {black,  white, black,   black,  white, black,},
         {black,  white, black,  black, black, black},
         {black,  white, black,  black,  white, black,},
         {black, black, black,  black,  white, black,}
      };
      
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 6.0)));

      // use the indexes to find which color to apply to the current pixel
      weights = slotmask[w][z];
      return weights;
   }

   else if(phosphor_layout == 13.){
      // based on MajorPainInTheCactus' HDR slot mask
      const vec3 slot[4][8] = {
         {red,   green, blue,  black, red,   green, blue,  black},
         {red,   green, blue,  black, black, black, black, black},
         {red,   green, blue,  black, red,   green, blue,  black},
         {black, black, black, black, red,   green, blue,  black}
      };
      
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 8.0)));
      
      weights = slot[w][z];
      return weights;
   }

   else if(phosphor_layout == 14.){
      // same as above but for RGB panels
      const vec3 slot2[4][10] = {
         {red,   yellow, green, blue,  blue,  red,   yellow, green, blue,  blue },
         {black, green,  green, blue,  blue,  red,   red,    black, black, black},
         {red,   yellow, green, blue,  blue,  red,   yellow, green, blue,  blue },
         {red,   red,    black, black, black, black, green,  green, blue,  blue }
      };
   
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 10.0)));
      
      weights = slot2[w][z];
      return weights;
   }
   
   else if(phosphor_layout == 15.){
      // slot_3_7x6_rgb
      const vec3 slot[6][14] = {
         {red,   red,   yellow, green, cyan,  blue,  blue,  red,   red,   yellow, green,  cyan,  blue,  blue},
         {red,   red,   yellow, green, cyan,  blue,  blue,  red,   red,   yellow, green,  cyan,  blue,  blue},
         {red,   red,   yellow, green, cyan,  blue,  blue,  black, black, black,  black,  black, black, black},
         {red,   red,   yellow, green, cyan,  blue,  blue,  red,   red,   yellow, green,  cyan,  blue,  blue},
         {red,   red,   yellow, green, cyan,  blue,  blue,  red,   red,   yellow, green,  cyan,  blue,  blue},
         {black, black, black,  black, black, black, black, black, red,   red,    yellow, green, cyan,  blue}
      };
      
      w = int(floor(mod(coord.y, 6.0)));
      z = int(floor(mod(coord.x, 14.0)));
      
      weights = slot[w][z];
      return weights;
   }

   else return weights;
}

vec2 wgt(vec2 size)
{
   size = clamp(size, -1.0, 1.0);
   size = 1.0 - size * size;
   return size * size * size;
}

float vignette(vec2 uv)
{
    float vignette = uv.x * uv.y * ( 1.0 - uv.x ) * ( 1.0 - uv.y );

    return clamp( pow( params.CN_VIG_BASE * vignette, params.CN_VIG_EXP ), 0.0, 1.0 );
}

vec3 get_content(vec2 vTex, vec2 uv)
{
    vec4  TextureSize = vec4(global.SourceSize.x, intl_profile.x, global.SourceSize.z, intl_profile.y);
    vec2  cn_offset   = vec2(CN_OFFSET     , intl_profile.z);
    vec2  scan_off    = vec2(CN_SCAN_OFFSET, intl_profile.w);

    vec2 pix_coord = vTex * TextureSize.xy - scan_off;
    vec2 tc        = (floor(pix_coord)   + cn_offset) * TextureSize.zw; // tc  = texel coord
    vec2 pos       =  fract(pix_coord)   - cn_offset; // pos = pixel position
    vec2 dir       =  sign(pos); // dir = pixel direction
    pos            =   abs(pos);

    vec2 g1 = dir * vec2(TextureSize.z,  0);
    vec2 g2 = dir * vec2( 0, TextureSize.w);

    mat2x3 AB = mat2x3(clamp(GAMMA_IN(texture(Source, tc    ).xyz), 0.0, 1.0), clamp(GAMMA_IN(texture(Source, tc +g1   ).xyz), 0.0, 1.0));
    mat2x3 CD = mat2x3(clamp(GAMMA_IN(texture(Source, tc +g2).xyz), 0.0, 1.0), clamp(GAMMA_IN(texture(Source, tc +g1+g2).xyz), 0.0, 1.0));

    vec2 wx = wgt(vec2(pos.x, 1.0-pos.x) / pix_sizex);

    mat2x3 cc = mat2x3(AB * wx, CD * wx);

    float c0max = max(cc[0].r, max(cc[0].g, cc[0].b));
    float c1max = max(cc[1].r, max(cc[1].g, cc[1].b));

    float lum0  = mix(CN_BEAM_MIN_WIDTH, CN_BEAM_MAX_WIDTH, c0max);
    float lum1  = mix(CN_BEAM_MIN_WIDTH, CN_BEAM_MAX_WIDTH, c1max);

    vec2  ssy = scan_sizey.xx;
     ssy.x *= (CN_VSCANLINES > 0.5 ? 1.0 : lum0);
     ssy.y *= (CN_VSCANLINES > 0.5 ? 1.0 : lum1);

    float vig = (params.CN_VIG_TOGGLE > 0.5) ? vignette(vTex) : 1.0;

    vec3  content = vig * (cc * wgt(vec2(pos.y, 1.0-pos.y) / ssy));

// Mask

    vec2 mask_coords = mix(vTexCoord, uv, global.h_curvature) * mask_size;

    mask_coords = mix(mask_coords.xy, mask_coords.yx, CN_VSCANLINES);
    vec3 mask_wgts = mask_weights(mask_coords, params.CN_PHOSPHOR_LAYOUT);
    mask_wgts = clamp(mask_wgts + vec3(1.0-CN_MASK_STRENGTH), 0.0, 1.0);
    mask_wgts = (CN_MONITOR_SUBPIXELS > 0.5) ? mask_wgts.bgr : mask_wgts;

    return GAMMA_OUT(content) * GAMMA_OUT(mask_wgts);
}


void main()
{
// Bezels and border begins...

    vec2 uvFC = mix(uv, h_warp(uv), global.h_curvature); // Frame content area
    vec2 uvIB = uvFC;                                    // Inner bezel area
    vec2 uvMB = mix(uv, uvFC, global.bz_outer_curve);    // In Between bezel area
    vec2 uvOB = uvMB;                                    // Outer bezel area

    uvFC = uvFC*overscan - content_position;

    vec2 area_out = RoundedRectVec(vec4(uvMB, uvOB), vec4(MID_BZ, OUT_BZ), bz_r.xx, vec2(SMTH, -SMTH));

    vec4 border = texture(BORDER, border_uv);

    border.rgb *= (bz_lights > 0.5) ? 1.0 : 0.5;
    if (area_out.y < 1.0) {FragColor = vec4(border.rgb, 1.0); return;}

// Bezels pause...

     vec2 fcTex = 0.5*uvFC + 0.5;

    float cval = h_corner(fcTex)  *  step(0.0, fract(fcTex.y));  // Discard off limit pixels

// Call to content shader here.
    vec3 content = get_content(fcTex, uv) * vec3(cval);

// Bezels continue...

    vec2  area_inn      = RoundedRectVec(vec4(uvIB, uvMB), vec4(INN_BZ, MID_BZ), bz_r.xx, vec2(SMTH, -SMTH));

    float out_border    = 1.0 - area_out.y;

    vec3  frame_content = mix(content, mix(content.rgb, border.rgb, border.a), global.ub_border_top);

    const float ambient     = bz_ambient;
    const float ambient_out = 1.4*bz_ambient;
    vec3 shine_content      = 0.0.xxx;
    vec3 ambient_content    = 0.0.xxx;

    if (bz_lights == 1.0)
    {
        vec2 rct = RoundedRectVec(vec4(uvIB + bz_shadow, uvIB), INN_BZ.xyxy, bz_r.xx, vec2(-SMTH/2.0, -SMTH));
    	shine_content += max(0.0, bz_shine - shine_size*length(uvIB + shine_position)) * rct.x; // Glass Shine
	ambient_content += max(0.0, ambient - amb_size*length(uvIB)) * rct.y; // Ambient Light
    }
    else
    {
        // Ambient Light
	ambient_content += max(0.0, ambient - amb_size*length(uvIB)) * RoundedRect(uvIB, INN_BZ, bz_r, -SMTH.xx);
    }

    frame_content += (global.bz_ambient_enable*ambient_content + global.bz_shine_enable*shine_content);

    if (area_inn.x < 0.5)
    {
FragColor = vec4(mix(border.rgb, mix(border.rgb, frame_content, (1.0-global.border_alpha)), float((fcTex.x*fcTex.y) <=1.1)), 1.0);
      return;
    }

    float bezel_inner_area = area_inn.x * area_inn.y;
    float bezel_outer_area = area_out.x * area_out.y;

    vec3 bezels = 0.0.xxx;

    // Inner Bezel Reflection Coords
    vec2 uvR = ReflectionCoords(uvFC, bz_ref_dist);

    vec3 Blur = 0.0.xxx;
    float fsm = 1.0 - fsmoothstep(0.8, 1.0, abs(uvFC.x))*fsmoothstep(0.8, 1.0, abs(uvFC.y));

    for(int i = 0; i < R_BLUR_ITER; i++)
        Blur += texture(Source, uvR + (vec2(rand(uvR+float(i)),rand(uvR+float(i)+0.00625))-0.5)*R_BLUR_SIZE).rgb;

    Blur *= (fsm * bz_ref_str / float(R_BLUR_ITER));

    // This is a hack. Still needs analytical solution.
    vec2 IB = abs(uvIB);
    IB = vec2(IB.x*mb_aspect, IB.y - MID_BZ.y + mb_aspect*MID_BZ.x);
    float corner = fsmoothstep(-bz_r, bz_r, IB.y - mix(IB.x, bz_ang*IB.x + bz_pos, cyl_shape));

    if (global.bz_transparent > 0.5) BZ_COLOR = border.rgb;

    if (bz_lights == 1.0)
    {
        // Bezel texture 
        vec3 bz_color = clamp(BZ_COLOR + rand(uvIB)*0.0125-0.00625, 0.0, 1.0) + 
                                         rand(uvIB+1.0.xx)*0.0625 * cos(0.75*PI*uvIB.x);
        // Inner Bezel and Reflections
        bezels += (bz_color + Blur) * bezel_inner_area * (0.25*(1.0 + corner));

    	// Outer Bezel
   	bezels +=  mix(bz_color, BZ_COLOR, global.bz_transparent) * bezel_outer_area;

    }
    else
    {
        // Middle Bezel
        bezels -= (BZ_COLOR ) * RoundedRect(uvOB, MID_BZ, bz_r, vec2(SMTH*2.0, -SMTH*10.0)) * 
                                RoundedRect(uvOB, MID_BZ, bz_r, vec2(SMTH*2.0, -SMTH* 2.0));

        // Inner Bezel and Reflections
        bezels += (BZ_COLOR + Blur) * bezel_inner_area * (ambient_out * (0.7 + 0.35*(1.0 - corner)) + Blur);

        // Outer Bezel
        bezels += BZ_COLOR * bezel_outer_area * mix(ambient_out, 1.0, global.bz_transparent);

    }

    bezels = mix(bezels+border.rgb*bezel_inner_area*global.bz_transparent, mix(bezels, border.rgb, border.a), global.ub_border_top);

    FragColor = vec4(bezels, 1.0);
}
