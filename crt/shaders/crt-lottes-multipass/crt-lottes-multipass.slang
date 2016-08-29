#version 450

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	float hardScan;
	float warpX;
	float warpY;
	float maskDark;
	float maskLight;
	float shadowMask;
	float bloomAmount;
	float hardBloomScan;
	float shape;
} params;

#pragma parameter hardScan "hardScan" -8.0 -20.0 0.0 1.0
#pragma parameter warpX "warpX" 0.031 0.0 0.125 0.01
#pragma parameter warpY "warpY" 0.041 0.0 0.125 0.01
#pragma parameter maskDark "maskDark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "maskLight" 1.5 0.0 2.0 0.1
#pragma parameter shadowMask "shadowMask" 3.0 0.0 4.0 1.0
#pragma parameter hardBloomScan "bloom-y soft" -2.0 -4.0 -1.0 0.1
#pragma parameter bloomAmount "bloom amount" 0.15 0.0 1.0 0.05
#pragma parameter shape "filter kernel shape" 2.0 0.0 10.0 0.05

#define DO_BLOOM

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

// PUBLIC DOMAIN CRT STYLED SCAN-LINE SHADER
//
//   by Timothy Lottes
//
// This is more along the style of a really good CGA arcade monitor.
// With RGB inputs instead of NTSC.
// The shadow mask example has the mask rotated 90 degrees for less chromatic aberration.
//
// Left it unoptimized to show the theory behind the algorithm.
//
// It is an example what I personally would want as a display option for pixel art games.
// Please take and use, change, or whatever.

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 FragCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D horz3minus1;
layout(set = 0, binding = 3) uniform sampler2D horz3plus1;
layout(set = 0, binding = 4) uniform sampler2D horz5minus2;
layout(set = 0, binding = 5) uniform sampler2D horz5;
layout(set = 0, binding = 6) uniform sampler2D horz5plus2;
layout(set = 0, binding = 7) uniform sampler2D horz7minus1;
layout(set = 0, binding = 8) uniform sampler2D horz7;
layout(set = 0, binding = 9) uniform sampler2D horz7plus1;

// Linear to sRGB.
// Assuming using sRGB typed textures this should not be needed.
float ToSrgb1(float c)
{
    return(c < 0.0031308 ? c*12.92 : 1.055*pow(c, 0.41666) - 0.055);
}

vec3 ToSrgb(vec3 c)
{
    return vec3(ToSrgb1(c.r), ToSrgb1(c.g), ToSrgb1(c.b));
}
  
// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos)
{
    pos = pos*params.SourceSize.xy;
    
    return -((pos - floor(pos)) - vec2(0.5));
}
    
// 1D Gaussian.
float Gaus(float pos, float scale)
{
    return exp2(scale*pow(abs(pos), params.shape));
}
  
// Return scanline weight.
float Scan(vec2 pos, float off)
{
    float dst = Dist(pos).y;

    return Gaus(dst + off, params.hardScan);
}
  
// Return scanline weight for bloom.
float BloomScan(vec2 pos, float off)
{
    float dst = Dist(pos).y;
    
    return Gaus(dst + off, params.hardBloomScan);
}
  
// Allow nearest three lines to effect pixel.
vec3 Tri(vec2 pos)
{
    vec3 a = texture(horz3minus1, pos).rgb;//Horz3(pos,-1.0);
    vec3 b = texture(horz5,       pos).rgb;//Horz5(pos, 0.0);
    vec3 c = texture(horz3plus1,  pos).rgb;//Horz3(pos, 1.0);

    float wa = Scan(pos, -1.0);
    float wb = Scan(pos,  0.0);
    float wc = Scan(pos,  1.0);
 
    return a*wa+b*wb+c*wc;
}
  
// Small bloom.
vec3 Bloom(vec2 pos)
{
    vec3 a = texture(horz5minus2, pos).rgb;//Horz5(pos,-2.0);
    vec3 b = texture(horz7minus1, pos).rgb;//Horz7(pos,-1.0);
    vec3 c = texture(horz7,       pos).rgb;//Horz7(pos, 0.0);
    vec3 d = texture(horz7plus1,  pos).rgb;//Horz7(pos, 1.0);
    vec3 e = texture(horz5plus2,  pos).rgb;//Horz5(pos, 2.0);
    
    float wa = BloomScan(pos, -2.0);
    float wb = BloomScan(pos, -1.0);
    float wc = BloomScan(pos,  0.0);
    float wd = BloomScan(pos,  1.0);
    float we = BloomScan(pos,  2.0);
    
    return a*wa+b*wb+c*wc+d*wd+e*we;
}
  
// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*params.warpX, 1.0 + (pos.x*pos.x)*params.warpY);
    
    return pos*0.5 + 0.5;
}
  
// Shadow mask.
vec3 Mask(vec2 pos)
{
    vec3 mask = vec3(params.maskDark, params.maskDark, params.maskDark);
  
    // Very compressed TV style shadow mask.
    if (params.shadowMask == 1.0) 
    {
        float line = params.maskLight;
        float odd = 0.0;
        
        if (fract(pos.x*0.166666666) < 0.5) odd = 1.0;
        if (fract((pos.y + odd) * 0.5) < 0.5) line = params.maskDark;  
        
        pos.x = fract(pos.x*0.333333333);

        if      (pos.x < 0.333) mask.r = params.maskLight;
        else if (pos.x < 0.666) mask.g = params.maskLight;
        else                    mask.b = params.maskLight;
        mask*=line;  
    } 

    // Aperture-grille.
    else if (params.shadowMask == 2.0) 
    {
        pos.x = fract(pos.x*0.333333333);

        if      (pos.x < 0.333) mask.r = params.maskLight;
        else if (pos.x < 0.666) mask.g = params.maskLight;
        else                    mask.b = params.maskLight;
    } 

    // Stretched VGA style shadow mask (same as prior shaders).
    else if (params.shadowMask == 3.0) 
    {
        pos.x += pos.y*3.0;
        pos.x  = fract(pos.x*0.166666666);

        if      (pos.x < 0.333) mask.r = params.maskLight;
        else if (pos.x < 0.666) mask.g = params.maskLight;
        else                    mask.b = params.maskLight;
    }

    // VGA style shadow mask.
    else if (params.shadowMask == 4.0) 
    {
        pos.xy  = floor(pos.xy*vec2(1.0, 0.5));
        pos.x  += pos.y*3.0;
        pos.x   = fract(pos.x*0.166666666);

        if      (pos.x < 0.333) mask.r = params.maskLight;
        else if (pos.x < 0.666) mask.g = params.maskLight;
        else                    mask.b = params.maskLight;
    }

    return mask;
}

void main()
{
    vec2 pos = Warp(vTexCoord);
    vec3 outColor = Tri(pos);

#ifdef DO_BLOOM
    //Add Bloom
    outColor.rgb += Bloom(pos)*params.bloomAmount;
#endif

    if (params.shadowMask > 0.0)
        outColor.rgb *= Mask(vTexCoord.xy / params.OutputSize.zw * 1.000001);

    FragColor = vec4(ToSrgb(outColor.rgb), 1.0);
}
