#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float vHALO_H;


void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   vHALO_H = HALO_H / NEW_SCALEMOD_Y; //Make it resolution independent.
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vHALO_H;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "includes/functions.include.slang"    


void main() {
    if (DO_HALO == 0.0 ) return;
   
    vec3 pixel_haloed;
    
   //apply just gamma and power for tighter blurs and exit:
   if (HALO_W >= GLOW_SHARP_MAX && HALO_H >= GLOW_SHARP_MAX) {
      FragColor = vec4( glow_dumb(Source, HALO_POWER, HALO_GAMMA, vTexCoord), 1.0);
      return;
   }

    pixel_haloed = blur9_y(Source, vTexCoord, global.first_passSize.xy, vHALO_H) * HALO_POWER;
    FragColor = vec4(pixel_haloed.rgb,1.0);
    
    
}
