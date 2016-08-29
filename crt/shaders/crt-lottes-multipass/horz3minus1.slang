#version 450

#define hardPix     -3.0
#define brightboost  1
#define shape        2.0

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 REFERENCESize;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
//   vTexCoord = floor(global.REFERENCESize.xy * TexCoord);
//   vTexCoord = (vTexCoord + 0.5) * global.REFERENCESize.zw;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D REFERENCE;

// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.
vec3 Fetch(vec2 pos, vec2 off) 
{
    pos = vTexCoord;//(floor(pos*global.REFERENCESize.xy+off)+vec2(0.5,0.5)) * global.REFERENCESize.zw;
    
    return brightboost * texture(REFERENCE, pos.xy).rgb;
}

// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos)
{
    pos = pos*global.REFERENCESize.xy;
    
    return -((pos - floor(pos)) - vec2(0.5));
}
    
// 1D Gaussian.
float Gaus(float pos, float scale)
{
    return exp2(scale*pow(abs(pos), shape));
}

// 3-tap Gaussian filter along horz line.
vec3 Horz3(vec2 pos, float off)
{
    vec3 b = Fetch(pos,vec2(-1.0, off));
    vec3 c = Fetch(pos,vec2( 0.0, off));
    vec3 d = Fetch(pos,vec2( 1.0, off));
    float dst = Dist(pos).x;
    
    // Convert distance to weight.
    float scale = hardPix;
    float wb = Gaus(dst - 1.0, scale);
    float wc = Gaus(dst + 0.0, scale);
    float wd = Gaus(dst + 1.0, scale);
    
    // Return filtered sample.
    return (b*wb+c*wc+d*wd) / (wb+wc+wd);
}

void main()
{
    FragColor = vec4(Horz3(vTexCoord, -1.0).rgb, 1.0);
}
