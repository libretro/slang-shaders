#version 450

/*
    zfast_crt_geo - A simple, fast CRT shader.

    Copyright (C) 2017 Greg Hogan (SoltanGris42)
    Copyright (C) 2023 Jose Linares (Dogway)

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.


Notes:  This shader does scaling with a weighted linear filter
        based on the algorithm by Iñigo Quilez here:
        https://iquilezles.org/articles/texture/
        but modified to be somewhat sharper. Then a scanline effect that varies
        based on pixel brightness is applied along with a monochrome aperture mask.
        This shader runs at ~60fps on the Chromecast HD (10GFlops) on a 1080p display.
        (https://forums.libretro.com/t/android-googletv-compatible-shaders-nitpicky)

Dogway: I modified zfast_crt.glsl shader to include screen curvature,
        vignetting, round corners and phosphor*temperature. Horizontal pixel is left out
        from the Quilez' algo (read above) to provide a more S-Video like horizontal blur.
        The scanlines and mask are also now performed in the recommended linear light.
        For this to run smoothly on GPU deprived platforms like the Chromecast and
        older consoles, I had to remove several parameters and hardcode them into the shader.
        Another POV is to run the shader on handhelds like the Switch or SteamDeck so they consume less battery.

*/


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float SCANLINE_WEIGHT,MASK_DARK, blurx, blury;
} params;

#pragma parameter SCANLINE_WEIGHT "Scanline Amount"     7.0 0.0 15.0 0.5
#pragma parameter MASK_DARK       "Mask Effect Amount"  0.5 0.0 1.0 0.05
#pragma parameter blurx           "Convergence X-Axis"  0.70 -2.0 2.0 0.05
#pragma parameter blury           "Convergence Y-Axis" -0.30 -2.0 2.0 0.05

#define SCANLINE_WEIGHT params.SCANLINE_WEIGHT
#define MASK_DARK params.MASK_DARK
#define blurx params.blurx
#define blury params.blury
#define SourceSize params.SourceSize
#define OutputSize params.OutputSize

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 invDims;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord.xy*1.0001;
	invDims = 1.0/SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 invDims;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define MSCL (OutputSize.y > 1499.0 ? 0.3333 : 0.5)
// This compensates the scanline+mask embedded gamma from the beam dynamics
#define pwr vec3(1.0/((-0.0325*SCANLINE_WEIGHT+1.0)*(-0.311*MASK_DARK+1.0))-1.2)
#define blur_xy vec2(vec2(blurx,blury)/(SourceSize.xy*2.0))


/*
// NTSC-J (D93) -> Rec709 D65 Joint Matrix (with D93 simulation)
// This is compensated for a linearization hack (RGB*RGB and then sqrt())
const mat3 P22D93 = mat3(
     1.00000, 0.00000, -0.06173,
     0.07111, 0.96887, -0.01136,
     0.00000, 0.08197,  1.07280);

// SAT 0.95;0.9
const mat3 SAT95 = mat3(
     0.921259999275207500, 0.07151728868484497, 0.007221288979053497,
     0.022333506494760513, 0.97512906789779660, 0.002537854015827179,
     0.010629460215568542, 0.03575950860977173, 0.953611016273498500);
*/

// P22D93 * SAT95
const mat3 P22D93SAT95 = mat3(
     0.920603871345520000, 0.06930985301733017, -0.051645118743181230,
     0.087028317153453830, 0.94945263862609860, -0.007860664278268814,
     0.013233962468802929, 0.11829412728548050,  1.023241996765136700);


// Returns gamma corrected output, compensated for scanline+mask embedded gamma
vec3 inv_gamma(vec3 col, vec3 power)
{
    vec3 cir  = col-1.0;
         cir *= cir;
         col  = mix(sqrt(col),sqrt(1.0-cir),power);
    return col;
}

vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;
    pos *= vec2(1.0 + (pos.y*pos.y)*0.0276, 1.0 + (pos.x*pos.x)*0.0414);
    return pos*0.5 + 0.5;
}


void main()
{
    vec2 vpos   = vTexCoord;
    vec2 xy     = Warp(vpos);

    vec2 corn   = min(xy,1.0-xy); // This is used to mask the rounded
         corn.x = 0.0001/corn.x;  // corners later on


     vec2 sample1 = texture(Source,vec2(xy.x + blur_xy.x, xy.y - blur_xy.y)).rg;
     vec3 sample2 = texture(Source,     xy).rgb;
     vec2 sample3 = texture(Source,vec2(xy.x - blur_xy.x, xy.y + blur_xy.y)).gb;

    vec3 colour =    vec3(sample1.r*0.50, sample1.g*0.25 + sample3.r*0.25, sample3.g*0.50) + 0.5 * sample2;

    vpos  *= (1.0 - vpos.xy);
    float vig = vpos.x * vpos.y * 46.0;
          vig = min(sqrt(vig), 1.0);


    // Of all the pixels that are mapped onto the texel we are
    // currently rendering, which pixel are we currently rendering?
     float ratio_scale = vTexCoord.y * SourceSize.y;
    // Snap to the center of the underlying texel.
    // This is just like "Quilez Scaling" but sharper
     float f = ratio_scale - (floor(ratio_scale) + 0.5);
     float Y = f*f;

     float whichmask = floor(vTexCoord.x*OutputSize.x)*-MSCL;
     float mask = 1.0 + float(fract(whichmask) < MSCL)    *-MASK_DARK;

    colour = max((colour*colour) * (P22D93SAT95 * vig), 0.0);

     float scanLineWeight = (1.5 - SCANLINE_WEIGHT*(Y - Y*Y));

    if (corn.y <= corn.x || corn.x < 0.0001)
    colour = vec3(0.0);

    FragColor.rgba = vec4(inv_gamma(colour.rgb*mix(scanLineWeight*mask, 1.0, colour.r*0.26667+colour.g*0.26667+colour.b*0.26667),pwr),1.0);

}
