#version 450

/*
   Hyllian's crt-nobody Shader
   
   Copyright (C) 2011-2025 Hyllian - sergiogdb@gmail.com

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
    float CN_MaskGamma;
    float fr_zoom;
    float fr_scale_x;
    float fr_scale_y;
    float fr_center_x;
    float fr_center_y;
    float h_shape;
    float h_radius;
    float h_cornersize;
    float h_cornersmooth;
    float h_overscan_x;
    float h_overscan_y;
    float h_angle_x;
    float h_angle_y;
    float h_curvature;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} global;



#pragma parameter CN_NONONO          "** CRT-NOBODY **"               0.0  0.0 0.0 1.0
#pragma parameter NO_NONONO          " "                              0.0  0.0 0.0 1.0
#pragma parameter col_nonono         "COLOR SETTINGS:"                0.0  0.0 0.0 1.0
#pragma parameter CN_InputGamma      "    Input Gamma"                2.4  0.0 4.0 0.1
#pragma parameter CN_OutputGamma     "    Output Gamma"               2.2  0.0 3.0 0.1
#pragma parameter CN_BRIGHTBOOST     "    Brightness Boost"           1.0  0.5 1.5 0.01
#pragma parameter CN_VIG_TOGGLE      "    Vignette Toggle"            0.0  0.0 1.0 1.0
#pragma parameter CN_VIG_BASE        "        Vignette Range"        48.0  2.0 100.0 2.0
#pragma parameter CN_VIG_EXP         "        Vignette Strength"      0.16  0.0 2.0 0.02

#pragma parameter scan_nonono        "SCANLINES SETTINGS:"           0.0  0.0 0.0 1.0
#pragma parameter CN_BEAM_MIN_WIDTH  "    Min Beam Width"           0.80 0.0 1.0 0.01
#pragma parameter CN_BEAM_MAX_WIDTH  "    Max Beam Width"           1.0  0.0 1.0 0.01
#pragma parameter CN_SCAN_SIZE       "    Scanlines Thickness"      0.86 0.0 1.0 0.01
#pragma parameter CN_VSCANLINES      "    Orientation [ HORIZONTAL, VERTICAL ]"    0.0 0.0 1.0 1.0

#pragma parameter msk_nonono           "MASK SETTINGS:"               0.0 0.0  0.0 1.0
#pragma parameter CN_PHOSPHOR_LAYOUT   "    Mask [1-6 APERT, 7-10 DOT, 11-14 SLOT, 15-17 LOTTES]" 1.0 0.0 17.0 1.0
#pragma parameter CN_MASK_STRENGTH     "    Mask Strength"            1.0 0.0 1.0 0.02
#pragma parameter CN_MaskGamma         "    Mask Gamma"               2.4 1.0 5.0 0.1
#pragma parameter CN_MONITOR_SUBPIXELS "    Monitor Subpixels Layout [ RGB, BGR ]" 0.0 0.0 1.0 1.0

#pragma parameter scl_nonono        "SCALING SETTINGS:"                 0.0 0.0    0.0 1.0
#pragma parameter fr_zoom           "    Zoom %"                      100.0 20.0 200.0 1.0
#pragma parameter fr_scale_x        "    Scale X%"                    100.0 20.0 200.0 0.2
#pragma parameter fr_scale_y        "    Scale Y%"                    100.0 20.0 200.0 0.2
#pragma parameter fr_center_x       "    Center X"                     0.0 -100.0 100.0 0.1
#pragma parameter fr_center_y       "    Center Y"                     0.0 -100.0 100.0 0.1

#pragma parameter h_nonono        "CURVATURE SETTINGS:"                  0.0  0.0 0.0 1.0
#pragma parameter h_curvature     "    Curvature Toggle"                 1.0 0.0 1.0 1.0
#pragma parameter h_shape         "        Shape [ SPHERE, CYLINDER ]"   0.0 0.0 1.0 1.0
#pragma parameter h_radius        "        Curvature Radius"             6.0 1.0 10.0 0.1
#pragma parameter h_cornersize    "        Corner Size"                  0.04 0.01 1.0 0.01
#pragma parameter h_cornersmooth  "        Corner Smoothness"            0.5 0.1 1.0 0.1
#pragma parameter h_angle_x       "        Angle X"                      0.0 -1.0 1.0 0.001
#pragma parameter h_angle_y       "        Angle Y"                      0.0 -1.0 1.0 0.001
#pragma parameter h_overscan_x    "        Curved Overscan X%"         100.0 20.0 200.0 0.2
#pragma parameter h_overscan_y    "        Curved Overscan Y%"         100.0 20.0 200.0 0.2


#define CN_VSCANLINES        params.CN_VSCANLINES
#define CN_BEAM_MIN_WIDTH    params.CN_BEAM_MIN_WIDTH
#define CN_BEAM_MAX_WIDTH    params.CN_BEAM_MAX_WIDTH
#define CN_SCAN_SIZE         params.CN_SCAN_SIZE
#define CN_BRIGHTBOOST       params.CN_BRIGHTBOOST
#define CN_InputGamma        params.CN_InputGamma
#define CN_OutputGamma       params.CN_OutputGamma
#define CN_MaskGamma         params.CN_MaskGamma
#define CN_MASK_STRENGTH     params.CN_MASK_STRENGTH
#define CN_MONITOR_SUBPIXELS params.CN_MONITOR_SUBPIXELS

#define GAMMA_IN(color)     CN_BRIGHTBOOST*pow(color, vec3(CN_InputGamma))
#define GAMMA_OUT(color)    pow(color, vec3(1.0 / CN_OutputGamma))

#define PIX_SIZE       1.111111
#define CN_OFFSET      0.5
#define CN_SCAN_OFFSET 0.0

// Macros.
#define FIX(c) max(abs(c), 1e-5)
#define PI 3.141592653589

float pix_sizex  = mix(PIX_SIZE, CN_SCAN_SIZE, CN_VSCANLINES);
float scan_sizey = mix(CN_SCAN_SIZE, PIX_SIZE, CN_VSCANLINES);
vec2  fr_center  = vec2(params.fr_center_x, params.fr_center_y)/100.0;
vec2  fr_scale   = vec2(params.fr_scale_x, params.fr_scale_y)*params.fr_zoom/10000.0;
vec2  mask_size  = global.OutputSize.xy* fr_scale * (1.0 - 0.5*params.h_curvature);

vec2  overscan   = vec2(params.h_overscan_x, params.h_overscan_y)/100.0;

float r2           = params.h_radius * params.h_radius;
vec2  max_size     = vec2(sqrt( (r2 - 2.0) / (r2 - 1.0) ), 1.0);
vec2  aspect       = vec2(1.0, global.OutputSize.y/global.OutputSize.x);
float cornersize   = params.h_cornersize * min(aspect.x, aspect.y);
float cornersmooth = params.h_cornersmooth/100.0;


const vec2 middle  = 0.5.xx;
const float on  = 1.;
const float off = 0.;



#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2  vTexCoord;
layout(location = 1) out vec4  intl_profile;

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

    vec2 diff    = TexCoord.xy * vec2(1.000001) - middle;
    vTexCoord    = middle + diff/fr_scale - fr_center;

    vTexCoord    = mix(vTexCoord, 2.0*vTexCoord - 1.0, params.h_curvature);

    intl_profile = get_interlace_profile();
}


#pragma stage fragment
layout(location = 0) in vec2  vTexCoord;
layout(location = 1) in vec4  intl_profile;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;



// Shadow mask.
vec3 Mask(vec2 pos, float shadowMask)
{
    const float maskDark  = 0.0;
    const float maskLight = 1.0;

    vec3 mask = vec3(maskDark, maskDark, maskDark);
  
    // Very compressed TV style shadow mask.
    if (shadowMask == 15.0) 
    {
        float line = maskLight;
        float odd = 0.0;
        
        if (fract(pos.x*0.166666666) < 0.5) odd = 1.0;
        if (fract((pos.y + odd) * 0.5) < 0.5) line = maskDark;  
        
        pos.x = fract(pos.x*0.333333333);

        if      (pos.x < 0.333) mask.b = maskLight;
        else if (pos.x < 0.666) mask.g = maskLight;
        else                    mask.r = maskLight;
        mask*=line;  
    } 

    // Aperture-grille. This mask is the same as mask 2.
/*    else if (shadowMask == 16.0) 
    {
        pos.x = fract(pos.x*0.333333333);

        if      (pos.x < 0.333) mask.b = maskLight;
        else if (pos.x < 0.666) mask.g = maskLight;
        else                    mask.r = maskLight;
    } 
*/
    // Stretched VGA style shadow mask (same as prior shaders).
    else if (shadowMask == 16.0) 
    {
        pos.x += pos.y*3.0;
        pos.x  = fract(pos.x*0.166666666);

        if      (pos.x < 0.333) mask.b = maskLight;
        else if (pos.x < 0.666) mask.g = maskLight;
        else                    mask.r = maskLight;
    }

    // VGA style shadow mask.
    else if (shadowMask == 17.0) 
    {
        pos.xy  = floor(pos.xy*vec2(1.0, 0.5));
        pos.x  += pos.y*3.0;
        pos.x   = fract(pos.x*0.166666666);

        if      (pos.x < 0.333) mask.b = maskLight;
        else if (pos.x < 0.666) mask.g = maskLight;
        else                    mask.r = maskLight;
    }

    return mask;
}


/* Mask code pasted from subpixel_masks.h. Masks 3 and 4 added. */
vec3 mask_weights(vec2 coord, float phosphor_layout){
   
//   if (lottes_mask > 0.5) return Mask(coord);

   if (phosphor_layout > 14) return Mask(coord, phosphor_layout);

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
      const vec3 aperture2[3] = vec3[](black, white, black);
      
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

float h_corner(vec2 uv)
{
    vec2  d          = abs((2.0*uv - 1.0) * aspect * overscan) - (aspect - cornersize.xx);
    float borderline = length(max(d, 0.0.xx)) + min(max(d.x, d.y), 0.0) - cornersize;

    return smoothstep(cornersmooth, -cornersmooth, borderline);
}

vec2 h_warp(vec2 uv)
{
    float r = params.h_radius;

    vec2 cylinder = sqrt( (r2 + 2.0 - uv.x*uv.x) / (r2 + 2.0 - 2.0*uv.x*uv.x) ) * vec2(r / sqrt(r2 + 1.0) , 1.0);
    vec2 sphere      = r / vec2( sqrt( r2 + 1.0 - dot(uv, uv)     )                                 );

    vec2 base_shape = vec2(r2 + 1.0 - dot(uv, uv));
    vec2 shape      = params.h_shape * (uv.y*uv.y - uv.x*uv.x + vec2(1.0, -1.0));

    uv *= ( (params.h_shape > 0.5 ? cylinder : sphere )/overscan );

    return (uv - 2.0*vec2(params.h_angle_x, params.h_angle_y))*0.5 + 0.5;
}


void main()
{
//    vec2 uv = mix(vTexCoord, h_warp(vTexCoord), params.h_curvature);   

//    float cval = h_corner(uv)  *  step(0.0, fract(uv.y));  // Discard off limit pixels

    // Texture coordinates of the texel containing the active pixel.
    vec2    uv = params.h_curvature > 0.5 ? h_warp(vTexCoord) : vTexCoord;

    float cval = params.h_curvature > 0.5 ? h_corner(uv) * step(0.0, fract(uv.y)) : 1.0;



    float vig = (params.CN_VIG_TOGGLE > 0.5) ? vignette(uv) : 1.0;

    vec4  TextureSize = vec4(global.SourceSize.x, intl_profile.x, global.SourceSize.z, intl_profile.y);
    vec2  cn_offset   = vec2(CN_OFFSET     , intl_profile.z);
    vec2  scan_off    = vec2(CN_SCAN_OFFSET, intl_profile.w);

    vec2 pix_coord = uv * TextureSize.xy - scan_off;
    vec2 tc        = (floor(pix_coord)   + cn_offset) * TextureSize.zw; // tc  = texel coord
    vec2 pos       =  fract(pix_coord)   - cn_offset; // pos = pixel position
    vec2 dir       =  sign(pos); // dir = pixel direction
    pos            =   abs(pos);

    vec2 g1 = dir * vec2(TextureSize.z,  0);
    vec2 g2 = dir * vec2( 0, TextureSize.w);

    mat2x3 AB = mat2x3(GAMMA_IN(texture(Source, tc    ).xyz), GAMMA_IN(texture(Source, tc +g1   ).xyz));
    mat2x3 CD = mat2x3(GAMMA_IN(texture(Source, tc +g2).xyz), GAMMA_IN(texture(Source, tc +g1+g2).xyz));

    vec2 wx = wgt(vec2(pos.x, 1.0-pos.x) / pix_sizex);

    mat2x3 c = mat2x3(AB * wx, CD * wx);

    float c0max = max(c[0].r, max(c[0].g, c[0].b));
    float c1max = max(c[1].r, max(c[1].g, c[1].b));

    float lum0  = mix(CN_BEAM_MIN_WIDTH, CN_BEAM_MAX_WIDTH, c0max);
    float lum1  = mix(CN_BEAM_MIN_WIDTH, CN_BEAM_MAX_WIDTH, c1max);

    vec2  ssy   = mix(scan_sizey * vec2(lum0, lum1), scan_sizey.xx, CN_VSCANLINES);

    vec3  color = vig * (c * wgt(vec2(pos.y, 1.0-pos.y) / ssy));

// Mask

    vec2 mask_coords = vTexCoord.xy * mask_size;

    mask_coords = mix(mask_coords.xy, mask_coords.yx, CN_VSCANLINES);

    vec3 mask_wgts = mask_weights(mask_coords, params.CN_PHOSPHOR_LAYOUT);

    mask_wgts = (CN_MONITOR_SUBPIXELS > 0.5) ? mask_wgts.bgr : mask_wgts;

    color  = clamp(color, 0.0, 1.0);

    vec3 mask = mask_wgts;

    color = mask + (1.0 - 2.0*mask)*pow(abs(mask - color), mask*CN_MASK_STRENGTH*(CN_MaskGamma-1.0)+1.0.xxx); 

    color = GAMMA_OUT(color);

    color *= cval;

    FragColor = vec4(color, cval);
}
