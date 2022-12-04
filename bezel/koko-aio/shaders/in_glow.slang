#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;


void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord ;  
}


#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 3) uniform sampler2D FXAA_pass;
layout(set = 0, binding = 4) uniform sampler2D first_pass;
layout(set = 0, binding = 5) uniform sampler2D shift_and_bleed_pass;

// Blur sizes must not depend on input resolution
#define scalemod_x (params.OutputSize.x/360.0)
#define scalemod_y (params.OutputSize.y/270.0)

// What follows is an ugly optimization with a lot of code copied and pasted repeated multiple times,
// shamlessly hidden into an include:
#include "includes/pixel_glows.include.slang" 

void main() { 
   if (DO_IN_GLOW == 0.0) return;
   
   vec3 pixel_glowed;
   if ( DO_SHIFT_RGB + DO_SAT_BLEED > 0.0)
      pixel_glowed = pixel_glow(shift_and_bleed_pass, IN_GLOW_WH,IN_GLOW_WH,IN_GLOW_POWER,IN_GLOW_GAMMA,vTexCoord, params.OutputSize, params.OutputSize).rgb;
   else if (DO_FXAA > 0.0)
      pixel_glowed = pixel_glow(FXAA_pass, IN_GLOW_WH,IN_GLOW_WH,IN_GLOW_POWER,IN_GLOW_GAMMA,vTexCoord, params.OutputSize, params.OutputSize).rgb;
   else
      pixel_glowed = pixel_glow(first_pass, IN_GLOW_WH,IN_GLOW_WH,IN_GLOW_POWER,IN_GLOW_GAMMA,vTexCoord, params.OutputSize, params.OutputSize).rgb;
   
   FragColor = vec4((pixel_glowed),1.0);
}

