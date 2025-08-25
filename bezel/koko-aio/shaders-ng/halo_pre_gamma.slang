#version 450
#include "config.inc"
#include "includes/functions.include.slang" 

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float vHALO_UNGAIN_FACTOR;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    //Shift texel coord to optimize blurring.
    //will invert the shift in the second pass.
        float m = map_range(HALO_SHARPNESS, 0.0, GLOW_SHARP_MAX, 0.0, 1.0);
        vTexCoord -= mix( params.SourceSize.zw*0.5, vec2(0.0), m);
    
    vHALO_UNGAIN_FACTOR = get_halo_ungain_factor();
        
    bool bIs_Interlaced = is_interlaced();
    
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vHALO_UNGAIN_FACTOR;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 4) uniform sampler2D in_glow_pass;

#ifndef D3D_WORKAROUND
#ifdef _HAS_FRAMETIME_UNIFORMS
#ifndef ORIGINAL_FPS_TRUSTED
    layout(set = 0, binding = 5) uniform sampler2D halo_pre_gamma_passFeedback;
#endif
#endif
#endif

void main() {
    
    #ifndef D3D_WORKAROUND
    #ifdef _HAS_FRAMETIME_UNIFORMS
    #ifndef ORIGINAL_FPS_TRUSTED
        if (global.OriginalFPS < 35.0) {
            //always trust cores that reports under 35fps (30,25).
            FragColor.a = global.OriginalFPS;
        } else {
            float fps_avg = texture(halo_pre_gamma_passFeedback, vec2(0.5)).a;
            float fps_now = 1000.0/(global.FrameTimeDelta/1000.0);

            //Ditch values outside thhis range:
            float l = 10.0;
            float h = 90.0;
            
            if (clamp(fps_now, l, h) != fps_now)
                fps_now = FPS_MEAN;
            if (clamp(fps_avg, l, h) != fps_avg)
                fps_avg = FPS_MEAN;    

            //Average values:
            FragColor.a = mix(fps_avg, fps_now, 0.05);
        }
    #endif
    #endif
    #endif


    #ifndef D3D_WORKAROUND
        if (is_skipped_frame())
            return;
    #endif

    if (DO_HALO == 0.0 ) return;
        
    vec3 pixel_haloed = texture(in_glow_pass, vTexCoord).rgb;

    if (HALO_NO_PREGAIN == 1.0) pixel_haloed/=vHALO_UNGAIN_FACTOR;

    pixel_haloed = pow(pixel_haloed, vec3(HALO_GAMMA));

    FragColor.rgb = pixel_haloed;
    
}
