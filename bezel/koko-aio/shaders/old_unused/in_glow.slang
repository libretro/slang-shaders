#version 450
#include "config.inc"


#define eps 1e-8
#define pi 3.141592654


// Blur sizes must not depend on input resolution
#define scalemod_x (params.SourceSize.x/360.0)
#define scalemod_y (params.SourceSize.y/270.0)


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vOutputCoord;


#include "functions.include"
void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord ; //get_scaled_coords(TexCoord);
   vOutputCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vOutputCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D FXAA_pass;
layout(set = 0, binding = 3) uniform sampler2D doublesize_pass;

// What follows is an ugly optimization with a lot of code copied and pasted repeated multiple times,
// shamlessly hidden into an include:
#include "pixel_glows.slang"    
    

#include "functions.include"

vec4 main_wrap(void) {
    //Halo
    vec2 in_glow_coords = vTexCoord;
        if (DO_CURVATURE == 1.0) {
            if ((GEOM_WARP_X > 0.0) || (GEOM_WARP_Y > 0.0))
                in_glow_coords = Warp(vTexCoord,GEOM_WARP_X,GEOM_WARP_Y);
        }
        vec3 pixel_glowed;
        if (DO_FXAA == 1.0)
            pixel_glowed = pixel_glow(FXAA_pass, in_glow_wh,in_glow_wh,in_glow_power,in_glow_gamma,in_glow_coords, global.FXAA_passSize, global.FXAA_passSize).rgb;
                else
            pixel_glowed = pixel_glow(doublesize_pass, in_glow_wh,in_glow_wh,in_glow_power,in_glow_gamma,in_glow_coords, global.FXAA_passSize, global.FXAA_passSize).rgb;
            
        return vec4(pixel_glowed.rgb,1.0);
    //Out
    return vec4(vec3(0.0),1.0);
}



void main() {
    if (DO_IN_GLOW == 1.0 ) {
        FragColor = main_wrap();
    } else {
        return;
    }
}
