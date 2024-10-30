#version 450

// NewRisingSun and blargg's NTSC filter
// simplified and ported to glsl by metallic77
// no license given, but I would expect it to inherit the LGPL license from the C version

#include "blargg_params.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define PI 3.1415926 

// Colorspace conversion matrix for RGB-to-YIQ
const mat3 RGBYIQ = mat3(
      0.2989, 0.5870, 0.1140,
      0.5959, -0.2744, -0.3216,
      0.2115, -0.5229, 0.3114
);
#define onedeg 0.017453

void main()
{
    float modulo = 3.0; if (global.OriginalSize.x > 300.0) modulo = 2.0;
    float phase = floor(vTexCoord.x*params.SourceSize.x)*pi_mod*onedeg + mod(floor(vTexCoord.y*params.SourceSize.y),modulo)*PI*vert_scal; 
    phase += ntsc_hue;
    if (stat_ph == 1.0) phase += sin(mod(float(params.FrameCount/2),2.0))*PI;
    
    vec3 YUV = texture(Source,vTexCoord).rgb; 
    YUV = YUV*RGBYIQ;

    YUV *= vec3(ntsc_bri, cos(phase), sin(phase));
    float signal = YUV.x + YUV.y + YUV.z;   
    FragColor = vec4(vec3(signal), 1.0);
}
