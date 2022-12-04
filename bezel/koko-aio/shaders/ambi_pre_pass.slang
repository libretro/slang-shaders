#version 450

/* This pass simulates the presence of a led strip placed on the back of the virtual screen */

#include "config.inc"

#define internalness 0.07  //The distance between the screen border and the led strip
#define leds_per_strip 8   //How many leds per border

#define radius 0.001       //The base radius of the emitted light (tuned by user parameter later)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float border_min;
layout(location = 2) out float border_max;
layout(location = 3) out float fstep;
layout(location = 4) out float lod;

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   
   border_min=internalness ;
   border_max=1.0-internalness ;
   fstep = (border_max - border_min)  / (leds_per_strip-1);
   //Calc a lod for a texture sized led_strip x led_strip
   lod = log2(params.SourceSize.y / leds_per_strip);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float border_min;
layout(location = 2) in float border_max;
layout(location = 3) in float fstep;
layout(location = 4) in float lod;

layout(location = 0) out vec4 FragColor;


layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D isrotated_passFeedback;
layout(set = 0, binding = 4) uniform sampler2D ambi_pre_pass1Feedback;


#include "includes/functions.include.slang"

vec3 circle_smooth(vec2 coords, vec2 middle, float f_radius, float FALLOFF, float f_lod) {
    float fdistance=distance(middle, vec2(coords.x, coords.y));
    float circle = (1-smoothstep(f_radius-FALLOFF, f_radius+FALLOFF, fdistance));
    vec3 circle_color = textureLod(Source, middle, f_lod).rgb * circle;
    return circle_color;
}

#define tol_start 0.06 //skip tolerance
#define tol_end   0.94 //1-tol_start


/*
   To spare gpu cycles, completely skip the pass 
   by the following factor and return instead the previous 
   (temporal) frame. The trick works because the pass is 
   temporal smoothed later on.
   
   The only downside is that the leds will have less reaction time.
   Esample:
   a FRAME_DIVIDER = 3 over a 60hz content will give
   a minimum reaction time of 60/3=20Hz=50msecs.
*/

#define FRAME_DIVIDER 3

void main() {
    if (DO_AMBILIGHT != 1.0) return; 
    
    if ( mod(params.FrameCount, FRAME_DIVIDER) != 0.0) {
        FragColor = texture(ambi_pre_pass1Feedback, vTexCoord);
        return;
    }
    
    bool is_rotated = texture(isrotated_passFeedback, vec2(0.5, 0.5)).r > 0.5;
    
    //Scale to the original aspect
    vec2 coords = get_scaled_coords(vTexCoord, global.FinalViewportSize, is_rotated);
    if (DO_BEZEL==1.0) coords = zoomout_coords(coords, -BEZEL_INNER_ZOOM , 1.0);
    
    //Skip coords in the rect "under the monitor"
    FragColor = vec4(0.0);
    
    //First consider to skip the curved coords
    if (DO_CURVATURE == 1.0) {
        if ((GEOM_WARP_X > 0.0) || (GEOM_WARP_Y > 0.0)) {
            vec2 coords_curved = Warp(coords, GEOM_WARP_X, GEOM_WARP_Y);
            if ( ( (coords_curved.x > tol_start && coords_curved.x < 1.0 - tol_start ) && (coords_curved.y > tol_start && coords_curved.y < 1.0 - tol_start) ) &&
                !( (coords.x < - tol_start || coords.x > 1.0 + tol_start) ||  (coords.y < - tol_start || coords.y > 1.0 + tol_start) ) )
                return;
        }       
    }    
    //...next, the straight ones (needed even when curvature is due, because it returns particular values in the corners)
    //skip_pass = skip_pass && !( (coords.x < 0.0 -tol || coords.x > 1.0 +tol) ||  (coords.y < 0.0 -tol || coords.y > 1.0 +tol) );
    if (coords.x > tol_start && coords.x < tol_end && coords.y > tol_start && coords.y < tol_end)  return;
    
    //Finally, emulate leds.
    vec3 pixel_out = vec3(0.0);
    float middle_x; float middle_y ;
    
    middle_x=border_min;
    for (middle_y=border_min ; middle_y <= border_max+eps ; middle_y=middle_y + fstep ) {
        pixel_out +=circle_smooth(coords, vec2(middle_x,middle_y), radius, AMBI_FALLOFF, lod);
    }
    middle_x=border_max;
    for (middle_y=border_min ; middle_y <=  border_max+eps ; middle_y=middle_y + fstep ) {
        pixel_out +=circle_smooth(coords, vec2(middle_x,middle_y), radius, AMBI_FALLOFF, lod);
    }    

    middle_y=border_min;
    for (middle_x=border_min+fstep ; middle_x <= border_max-fstep+eps ; middle_x=middle_x + fstep ) {
        pixel_out +=circle_smooth(coords, vec2(middle_x,middle_y), radius, AMBI_FALLOFF, lod);
    }
    middle_y=border_max;
    for (middle_x=border_min+fstep ; middle_x <= border_max-fstep+eps ; middle_x=middle_x + fstep ) {
        pixel_out +=circle_smooth(coords, vec2(middle_x,middle_y), radius, AMBI_FALLOFF, lod);
    }    

    FragColor = vec4(pixel_out,1.0);
    return;

}
