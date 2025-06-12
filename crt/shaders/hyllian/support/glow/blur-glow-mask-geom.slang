#version 450

layout(push_constant) uniform Push
{
    float GLOW_ENABLE;
    float GLOW_RADIUS;
    float GLOW_STRENGTH;
    float PRESET_OPTION;
    float DISPLAY_RES;
    float PHOSPHOR_LAYOUT;
    float MASK_STRENGTH;
    float BRIGHTBOOST;
    float MONITOR_SUBPIXELS;
    float VSCANLINES;
    float H_OUTPUT_GAMMA;
    float H_MaskGamma;
    float h_curvature;
    float h_shape;
    float h_radius;
    float h_cornersize;
    float h_cornersmooth;
} params;


layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} global;

#pragma parameter H_OUTPUT_GAMMA    "    Output Gamma"    2.2 1.0 3.0 0.05
#pragma parameter BRIGHTBOOST       "    Brightboost"     1.0 0.5 2.0 0.01


#pragma parameter GLOW_ENABLE    "    Enable Glow"   0.0  0.0 1.0 1.0
#pragma parameter GLOW_RADIUS    "        Radius"    4.0  2.0 4.0 0.1
#pragma parameter GLOW_STRENGTH  "        Strength"  0.05 0.0 1.0 0.01

#pragma parameter VSCANLINES         "    Orientation [ HORIZONTAL, VERTICAL ]"    0.0 0.0 1.0 1.0

#pragma parameter DISPLAY_RES       "    Target Resolution [ 1080P, 4K ]"                         0.0 0.0  1.0 1.0
#pragma parameter PRESET_OPTION     "    Mask Preset [CUSTOM, APERT1, APERT2, SLOT1, SLOT2, DOT]" 0.0 0.0  5.0 1.0
#pragma parameter PHOSPHOR_LAYOUT   "    * Mask [1-6 APERT, 7-10 DOT, 11-14 SLOT, 15-17 LOTTES]"  1.0 0.0 17.0 1.0
#pragma parameter MASK_STRENGTH     "    Mask Strength"                                           1.0 0.0  1.0 0.02
#pragma parameter H_MaskGamma       "    Mask Gamma"                                              2.4 1.0  3.0 0.05
#pragma parameter MONITOR_SUBPIXELS "    Monitor Subpixels Layout [ RGB, BGR ]"                   0.0 0.0  1.0 1.0

#pragma parameter h_nonono        "CURVATURE SETTINGS:"                 0.0  0.0  0.0 1.0
#pragma parameter h_curvature     "    Curvature Toggle"                0.0  0.0  1.0 1.0
#pragma parameter h_shape         "        Shape [ SPHERE, CYLINDER ]"  0.0  0.0  1.0 1.0
#pragma parameter h_radius        "        Radius"                      5.0  1.5 10.0 0.1
#pragma parameter h_cornersize    "        Corner Size"                 0.04 0.01 1.0 0.01
#pragma parameter h_cornersmooth  "        Corner Smoothness"           0.5  0.1  1.0 0.1



#define BRIGHTBOOST params.BRIGHTBOOST
#define DISPLAY_RES params.DISPLAY_RES
#define GLOW_ENABLE params.GLOW_ENABLE
#define GLOW_RADIUS params.GLOW_RADIUS
#define MASK_STRENGTH params.MASK_STRENGTH
#define MONITOR_SUBPIXELS params.MONITOR_SUBPIXELS
#define VSCANLINES params.VSCANLINES
#define GLOW_STRENGTH params.GLOW_STRENGTH

#define H_MaskGamma params.H_MaskGamma
#define INV_OUTPUT_GAMMA (1.0 / params.H_OUTPUT_GAMMA)
#define saturate(c) clamp(c, 0.0, 1.0)

#define GAMMA_OUT(color)    pow(color, vec3(INV_OUTPUT_GAMMA))

// Macros.
#define FIX(c) max(abs(c), 1e-5);
#define PI 3.141592653589

float r2           = params.h_radius * params.h_radius;
vec2  max_size     = vec2(sqrt( (r2 - 2.0) / (r2 - 1.0) ), 1.0);
vec2  aspect       = vec2(1.0, global.OutputSize.y/global.OutputSize.x);
float cornersize   = params.h_cornersize * min(aspect.x, aspect.y);
float cornersmooth = params.h_cornersmooth/100.0;

// aspect ratio
//vec2 aspect     = vec2(params.geom_invert_aspect > 0.5 ? (0.75, 1.0) : (1.0, 0.75));
vec2 overscan   = vec2(1.01, 1.01);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 mask_profile;

vec2 get_beam_profile()
{
    vec2 bp = vec2(params.PHOSPHOR_LAYOUT, MASK_STRENGTH);

    if (DISPLAY_RES < 0.5)
    {
	if (params.PRESET_OPTION == 1.0)  bp = vec2( 1.0, 1.00);
	if (params.PRESET_OPTION == 2.0)  bp = vec2( 2.0, 1.00);
	if (params.PRESET_OPTION == 3.0)  bp = vec2(11.0, 1.00);
	if (params.PRESET_OPTION == 4.0)  bp = vec2(11.0, 1.00);
	if (params.PRESET_OPTION == 5.0)  bp = vec2( 7.0, 1.00);
    } else {
	if (params.PRESET_OPTION == 1.0)  bp = vec2( 2.0, 1.00);
	if (params.PRESET_OPTION == 2.0)  bp = vec2( 4.0, 1.00);
	if (params.PRESET_OPTION == 3.0)  bp = vec2(14.0, 1.00);
	if (params.PRESET_OPTION == 4.0)  bp = vec2(14.0, 1.00);
	if (params.PRESET_OPTION == 5.0)  bp = vec2( 9.0, 1.00);
     }

	return bp;
}


void main()
{
    gl_Position = global.MVP * Position;

    vTexCoord = TexCoord * vec2(1.0001);

    mask_profile = get_beam_profile();
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 mask_profile;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D CRTPass;

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


vec3 get_bloom(sampler2D src, vec2 tex, vec2 dxy) {
    vec3  bloom = vec3(0.0);

    const float k[9] = {
        0.001234403, 0.014304688, 0.082317798,
        0.235235546, 0.33381513,  0.235235546,
        0.082317798, 0.014304688, 0.001234403
    };

    bloom += k[0] * texture(src, tex - 4.0 * dxy).rgb;
    bloom += k[1] * texture(src, tex - 3.0 * dxy).rgb;
    bloom += k[2] * texture(src, tex - 2.0 * dxy).rgb;
    bloom += k[3] * texture(src, tex -       dxy).rgb;
    bloom += k[4] * texture(src, tex           ).rgb;
    bloom += k[5] * texture(src, tex +       dxy).rgb;
    bloom += k[6] * texture(src, tex + 2.0 * dxy).rgb;
    bloom += k[7] * texture(src, tex + 3.0 * dxy).rgb;
    bloom += k[8] * texture(src, tex + 4.0 * dxy).rgb;

    return bloom;
}


float h_corner(vec2 uv)
{
    vec2  d          = abs((2.0*uv - 1.0) * aspect) - (aspect - cornersize.xx);
    float borderline = length(max(d, 0.0.xx)) + min(max(d.x, d.y), 0.0) - cornersize;

    return smoothstep(cornersmooth, -cornersmooth, borderline);
}


vec2 h_warp(vec2 uv)
{
    uv = 2.0*uv - 1.0;

    vec2 cylinder = sqrt( (r2 - uv.x*uv.x) / (r2 - 2.0*uv.x*uv.x) )*max_size;
    vec2 sphere   = sqrt( (r2 - 1.0      ) / (r2 - dot(uv, uv))   ).xx;

    uv *= mix(sphere, cylinder, params.h_shape);

    return uv*0.5 + 0.5;
}




void main()
{
    vec2    uv = params.h_curvature > 0.5 ? h_warp(vTexCoord) : vTexCoord;   
    float cval = params.h_curvature > 0.5 ? h_corner(uv)      : 1.0;

    // Bloom: Vertical blur
    vec2 dy    = vec2(0.0, GLOW_RADIUS*global.SourceSize.w);

    vec3 bloom = (GLOW_ENABLE > 0.5) ? get_bloom(Source, uv, dy) : vec3(0.0);

    // Mask
    vec2 mask_coords = vTexCoord.xy * global.OutputSize.xy;

    mask_coords = mix(mask_coords.xy, mask_coords.yx, VSCANLINES);

    vec3 mask = mask_weights(mask_coords, mask_profile.x);

    mask = (MONITOR_SUBPIXELS > 0.5) ? mask.bgr : mask;

    // CRT + Bloom + Mask + Curvature
    vec3 crt = BRIGHTBOOST * texture(CRTPass, uv).rgb;

    crt += GLOW_STRENGTH * bloom;

    crt = clamp(crt, 0.0, 1.0);

    crt = GAMMA_OUT(crt);

    crt = mask + (1.0 - 2.0*mask)*pow(abs(mask - crt), mask*MASK_STRENGTH*(H_MaskGamma - 1.0) + 1.0); 

    crt *= cval;

    FragColor = vec4(crt, 1.0);
}
