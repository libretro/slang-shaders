#version 450

/* This pass:
 * Composes the previous passes
 * Does masks, spot, bezel, vignette, background image (anything else?)
 */

#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;


layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vOutputCoord;
layout(location = 2) out vec2 spot_offset;
layout(location = 3) out vec2 vFragCoord;
layout(location = 4) out float vIsRotated;


//Curvature:
    layout(location = 5) out vec2 vWarp_vexp;
    layout(location = 6) out vec2 vWarp_arg2;

//Scanlines:
    layout(location = 7) out float vIsInterlaced;
    layout(location = 8) out float vFlickeringScanlines;
    layout(location = 9) out float vScanlinePeriod;
    layout(location = 10) out float vScanlinesAlternate;

//Vignette, spot:
    layout(location = 11) out float vIn_aspect;


    
#include "includes/functions.include.slang"

void main() {
    gl_Position = global.MVP * Position;
    vIsRotated = float(is_rotated());
    vIn_aspect = get_in_aspect();
    vTexCoord = get_scaled_coords_aspect(TexCoord,global.FinalViewportSize, vIn_aspect, bool(vIsRotated)) + vec2(0.00001);

    if (DO_GLOBAL_SHZO >0.5)
        vTexCoord = zoom(vTexCoord + vec2(-GLOBAL_OFFX, -GLOBAL_OFFY), GLOBAL_ZOOM );
    
    vOutputCoord = TexCoord;
    
    vFragCoord = vec2( floor(vOutputCoord.x * params.OutputSize.x),
                       floor(vOutputCoord.y * params.OutputSize.y));

    //Precalc some Curvature/Warp values:
        vec2 geom_warp_adapted = vec2(GEOM_WARP_X, GEOM_WARP_Y);
        
       /* if (DO_BEZEL > 0.0) {
            geom_warp_adapted *= (-BEZEL_INNER_ZOOM) + 1;
        }*/
        vWarp_vexp = 1.0/ (1 + (vec2(geom_warp_adapted.x, geom_warp_adapted.y) * 0.2)) ;
        
        
        vWarp_arg2 = 1.0 - pow(vec2(0.29289321881345247559915563789515), vWarp_vexp );
        
    //Help scanline code too:
        if (DO_SCANLINES > 0.5) {
            bool bIs_Interlaced = is_interlaced();
            vIsInterlaced = float(bIs_Interlaced);
            vFlickeringScanlines = float((DO_SCANLINES == 1.0) && scanline_have_to_flicker(bIs_Interlaced)) ;
            
            //Scanline period:
            vScanlinePeriod = 1.0;
            vScanlinesAlternate = 0.0;
            if (bIs_Interlaced) {
                if (params.FrameCount % 2 == 0.0) vScanlinesAlternate = 1.0;
                if (params.OriginalSize.y > MIN_LINES_INTERLACED )  vScanlinePeriod = 0.5;
            }
            //vScanlinePhase = 0.0;
            //vScanlinePhase = vScanlinePeriod * pi - pi/4.0; //<-- needed to match scanlines done in first_pass. //FIXME check what happens for highter res.
        }
    //SPOT
        spot_offset = offsets_from_float(S_POSITION+420.0,40);
        spot_offset = spot_offset / 10.0 + vec2(0.0,1.0);
        
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vOutputCoord;
layout(location = 2) in vec2 spot_offset;
layout(location = 3) in vec2 vFragCoord;
layout(location = 4) in float vIsRotated;
layout(location = 5) in vec2 vWarp_vexp;
layout(location = 6) in vec2 vWarp_arg2;
layout(location = 7) in float vIsInterlaced;
layout(location = 8) in float vFlickeringScanlines;
layout(location = 9) in float vScanlinePeriod;
layout(location = 10) in float vScanlinesAlternate;
layout(location = 11) in float vIn_aspect;

layout(location = 0) out vec4 FragColor;


#ifdef STATIC_SUPPORT_BACKDROP
    layout(set = 0, binding = 1) uniform sampler2D backdrop;
        #else
    layout(set = 0, binding = 1) uniform sampler2D first_pass;
#endif
layout(set = 0, binding = 2)  uniform sampler2D bloom_pass_final;
layout(set = 0, binding = 3)  uniform sampler2D reflected_blurred_pass2;
layout(set = 0, binding = 4)  uniform sampler2D ambi_temporal_pass;
layout(set = 0, binding = 5)  uniform sampler2D avglum_pass;
layout(set = 0, binding = 6)  uniform sampler2D monitor_body_straight;
layout(set = 0, binding = 7)  uniform sampler2D monitor_body_curved;
layout(set = 0, binding = 8)  uniform sampler2D bg_under;
layout(set = 0, binding = 9)  uniform sampler2D bg_over;
layout(set = 0, binding = 10) uniform sampler2D shift_and_bleed_pass;
layout(set = 0, binding = 11) uniform sampler2D in_glow_pass;
layout(set = 0, binding = 12) uniform sampler2D halo_pass;


#define HALF_PI 1.5707963267949
#define QUARTER_PI 0.785398163397448

#include "includes/functions.include.slang"

vec3 pixel_vmask(vec3 source, float white_reference, float over_white) {
// Simple RGB mask emulation with or without horizontal gap
    float ooo = 1.0 - RGB_MASK_STRENGTH;
    
    // RGB mask:     R     G     B
    vec3 m1 =  vec3( 1.0 , ooo , ooo );  //col 1
    vec3 m2 =  vec3( ooo , 1.0 , ooo );  //col 2
    vec3 m3 =  vec3( ooo , ooo , 1.0 );  //col 3
    vec3 gap = vec3( ooo );
    
    vec3 pixel_out;
    vec3 vmasked;
    vec4 vec_mod=(vec4(3,1,2,3) + vec4(VMASK_GAP,0.0,0.0,0.0))* VMASK_DARKLINE_SCALE ;
    
    float fcol = vOutputCoord.x * params.OutputSize.x;
    if (mod(fcol, vec_mod.x) < vec_mod.y)
        vmasked = m1 * source;
    else if (mod(fcol, vec_mod.x) < vec_mod.z) 
        vmasked = m2 * source;
    else if (mod(fcol, vec_mod.x) <  vec_mod.w)
        vmasked = m3 * source;
    else vmasked = gap * source;
    
    if (over_white == 1.0) pixel_out = vmasked;
        else {
            white_reference-= over_white;
            white_reference=  clamp(white_reference,0.0,1.0);
            pixel_out=  mix(vmasked,source,white_reference);
        }
   return pixel_out;  
    
}

vec3 pixel_vmask_and_gm(vec3 source, float white_reference, float over_white) {
// Simple RGB mask emulation with or without horizontal gap
    float ooo = 1.0 - RGB_MASK_STRENGTH;
    
    // RGB mask:     R     G     B
    vec3 m1_rgb =  vec3( 1.0 , ooo , ooo );  //col 1
    vec3 m2_rgb =  vec3( ooo , 1.0 , ooo );  //col 2
    vec3 m3_rgb =  vec3( ooo , ooo , 1.0 );  //col 3
    vec3 gap = vec3( ooo );
       
    vec3 m1_gm = vec3( ooo , 1.0 , ooo );    //col 1
    vec3 m2_gm = vec3( 1.0 , ooo , 1.0 );    //col 2
    
    
    vec3 m1 = (m1_gm * VMASK_USE_GM) + (m1_rgb * (1-VMASK_USE_GM));
    vec3 m2 = (m2_gm * VMASK_USE_GM) + (m2_rgb * (1-VMASK_USE_GM));
    vec3 m3 = m3_rgb;
    
    
    vec3 pixel_out;
    vec3 vmasked;
    vec4 vec_mod_rgb = vec4(3,1,2,3);
    vec4 vec_mod_gm =  vec4(2,1,2,0.0);
    vec4 vec_mod = (vec_mod_gm * VMASK_USE_GM) + (vec_mod_rgb* (1-VMASK_USE_GM));
    vec_mod=(vec_mod + vec4(VMASK_GAP,0.0,0.0,0.0))* VMASK_DARKLINE_SCALE ;


    float fcol = vOutputCoord.s * params.OutputSize.x;
    if (mod(fcol, vec_mod.x) < vec_mod.y)
        vmasked = m1 * source;
    else if (mod(fcol, vec_mod.x) < vec_mod.z) 
        vmasked = m2 * source;
    else if (    mod(fcol, vec_mod.x) <  vec_mod.w && VMASK_USE_GM < 1.0  )
        vmasked = m3 * source;
    else vmasked = gap * source;
    
    if (over_white == 1.0) pixel_out = vmasked;
        else {
            white_reference-= over_white;
            white_reference=  clamp(white_reference,0.0,1.0);
            pixel_out=  mix(vmasked,source,white_reference);
        }
   return pixel_out;  
    
}


vec3 pixel_vmask_gm(vec3 source, float white_reference, float over_white) {
// Simple RGB mask emulation with or without horizontal gap
    float ooo = 1.0 - RGB_MASK_STRENGTH;
    // RGB mask:     R     G     B
    vec3 m1 =  vec3( ooo , 1.0 , ooo );    //col 1
    vec3 m2 =  vec3( 1.0 , ooo , 1.0 );    //col 2
    vec3 gap = vec3( ooo );
    
    float fcol = vOutputCoord.s * params.OutputSize.x;
    vec3 pixel_out;
    vec3 vmasked;
    vec3 vec_mod=(vec3(2,1,2) + vec3(VMASK_GAP,0.0,0.0))* VMASK_DARKLINE_SCALE ;

    if (mod(fcol, vec_mod.x) < vec_mod.y)
        vmasked = m1 * source;
    else if (mod(fcol, vec_mod.x) < vec_mod.z)
        vmasked = m2 * source;
    else 
        vmasked = gap * source;

    if (over_white == 1.0) pixel_out = vmasked;
        else {
            white_reference-= over_white;
            white_reference=  clamp(white_reference,0.0,1.0);
            pixel_out=  mix(vmasked,source,white_reference);
        }

   return pixel_out;
}

/*vec3 pixel_darklines_old(vec3 source,float darkline_every, float darkline_trans,
                     float do_offset, float white_reference,float over_white, vec2 coords) {
    // "darklines" are vertical gaps that can be used to emulate aperturegrille
    // or slotmasks
    //
    
    float Darkline_part_w = (3.0 - VMASK_USE_GM + VMASK_GAP) * VMASK_DARKLINE_SCALE;
    float Darkline_part_w_x2 = Darkline_part_w*2;

    darkline_every *= VMASK_DARKLINE_SCALE;

    if (over_white != 1.0) {
        //less effect on bright colors.
        darkline_trans+=(white_reference-over_white);
        darkline_trans=clamp(darkline_trans,0.0,1.0);
    }

    //Slotmask (darklines are drawn with offset)
    if (do_offset > 0.0) {
        bool odd_line_meno_densa = mod(vFragCoord.y, darkline_every) > VMASK_DARKLINE_SCALE ;
        bool odd_line_piu_densa = !(mod(vFragCoord.y, darkline_every/2) < VMASK_DARKLINE_SCALE && odd_line_meno_densa);
        bool odd_column = mod(vFragCoord.x + Darkline_part_w  , Darkline_part_w_x2) < Darkline_part_w;
        bool draw_mask = odd_line_piu_densa && !odd_column || odd_column && odd_line_meno_densa;

        return source * clamp(float(draw_mask),darkline_trans,1.0);
    }
    
    //Aperture grille (darklines are drawn straight)
        bool draw_dark = mod(vFragCoord.y, darkline_every) < VMASK_DARKLINE_SCALE;
        bool draw_color = !draw_dark;
        return source * ( float(draw_color) +  float(draw_dark) * darkline_trans );
}*/


vec3 pixel_darklines(vec3 source,float darkline_every, float darkline_trans,
                     float do_offset, float white_reference,float over_white, vec2 coords) {
    
    
    float period_x = (3.0 - VMASK_USE_GM + VMASK_GAP) * VMASK_DARKLINE_SCALE;
    float period_y = darkline_every * VMASK_DARKLINE_SCALE;
    
    vec2 FragCoord = vFragCoord;

    
    if (over_white != 1.0) {
        //less effect on bright colors.
        darkline_trans+=(white_reference-over_white);
        darkline_trans=clamp(darkline_trans,0.0,1.0);
    }
    
    
    if (do_offset > 0.0) {
        float column = int(floor(mod(FragCoord.x, period_x*2.0)));
        if (column < period_x) FragCoord.y+=period_y/2.0;
    }
    
    float row = int(floor(mod(FragCoord.y, period_y)));

    if (row < VMASK_DARKLINE_SCALE)
        return source * darkline_trans;
            else
        return source;
    
}


float scanline_shape(vec2 coords, bool do_slotmask, float lum) {
/* Produces a B/W scanline shape to be multiplicated by the source
 * pixel later on to emulate scanline effect.
 * scanlines can be drawn on odd and even fields alternating on odd and
 * even frames to emulate that aspect of interlacing.
 */

    float period = vScanlinePeriod;
    bool is_interlaced = bool(vIsInterlaced);
    bool alternate = bool(vScanlinesAlternate);
    bool do_flicker = bool(vFlickeringScanlines);

    //...to scale scanline tickness:
    //float lum_scaled = scale_to_range(lum, SCANLINE_MIN, SCANLINE_MAX);
    float lum_scaled = lum * SCANLINE_MAX; 
          lum_scaled = clamp( lum_scaled, SCANLINE_MIN, SCANLINE_MAX );
              
        

     
    float angle_base = coords.y * pi * params.OriginalSize.y * period;// + vScanlinePhase;

    float lines = 1.0;
    
    if (!( is_interlaced && SCANLINE_DISABLE_ON_INTERLACE == 1.0 )) {
        
        /*if (alternate)
            lines = -sin(angle_base + HALF_PI); 
                else
            lines = sin(angle_base);
        */
        //Unbranched the previous if/then/else:
        lines = (2*vScanlinesAlternate -1) * sin(angle_base + (vScanlinesAlternate * HALF_PI)) ;
         
        lines = (lines*lines);
    }


    //Draw the slotmask right here if the height is the same as the scanline.
    if (do_slotmask) {
        if (do_flicker) {
            //Fallback to old darklines code to avoid glitches/artifacts.
            lines = lines * pixel_darklines(vec3(1.0),DARKLINES_PERIOD,1-SCANLINE_SM_STRENGTH,1.0, 0.0 ,1.0, coords).r;

        } else {
            float Darkline_part_w = (3.0 - VMASK_USE_GM + VMASK_GAP) * VMASK_DARKLINE_SCALE;
            float Darkline_part_w_x2 = Darkline_part_w*2;
            bool odd_column = mod(vFragCoord.x + Darkline_part_w  , Darkline_part_w_x2) < Darkline_part_w;


            if (SCANLINE_SM_TYPE == 1.0) {
                // Slotmask is out oh phase every "odd" triple and mixed with
                // the straight scanline.
                // slotmask strength and stagger are configurable.
                // Acceptable values are with stagger around 79 (pi/4)
                if (odd_column) {
                    float phase = pi + SCANLINE_SM_VOFFSET*0.01 * lum_scaled;
                    float angle_slotmask = angle_base + phase;
                    float slotmask = sin(angle_slotmask);
                    slotmask = (slotmask*slotmask);
                    lines = mix(lines, slotmask, SCANLINE_SM_STRENGTH);
                }
            }

            else if (SCANLINE_SM_TYPE == 2.0) {
                float phase;
                //Slotmask is always out of phase by QUARTER_PI
                //Every "odd triple" column, it is also out of phase of HALF_PI
                //Slotmask is multiplied by original scanline and thinner.
                //Only strength parameter is taken into account.
               if (odd_column)
                    phase = period * pi + QUARTER_PI * lum_scaled;
                        else
                    phase = period * HALF_PI + QUARTER_PI;

                float angle_slotmask = angle_base + phase;
                float slotmask = sin(angle_slotmask);
                slotmask = slotmask*slotmask; slotmask = slotmask*slotmask; // eleva alla 4 per renderla sottile. valori maggiori producono moiree.
                slotmask = mix(1.0, slotmask, SCANLINE_SM_STRENGTH); // riduci la forza della slotmask
                lines = lines * slotmask;
            }

            else if (SCANLINE_SM_TYPE == 3.0) {
                // Thinner slotmask screen, no scanlines.
                // No parameter taken into account.
                if (odd_column) {
                    float phase = pi + HALF_PI;
                    float angle_slotmask = angle_base + phase;
                    float slotmask = sin(angle_slotmask);
                    slotmask = (slotmask*slotmask); slotmask = (slotmask*slotmask);
                    lines = slotmask;
                }
            }
        }
    }


    //Thickness (min):

        //lines = pow(lines, 1/(lum_scaled+eps) );
        //lines = pow(lines, 1/(sqrt(lum_scaled) ) );
//lines = pow(lines, 1/(lum_scaled*lum_scaled+eps) );

//lines = pow( lines , 1/(lum_scaled ) ) ;

//0.0125 is an anti-moiree measure.

//lines = pow(   max(lines, 0.05),   1/lum_scaled) ;

//lines = pow(lines, 1/(sqrt(lum_scaled) ) );

//lines = pow(clamp(lines + 0.05, 0.0,1.0) , 1/sqrt(lum_scaled));
//float extra_power_1 = 3.0;

float extra_power_1 = max(SCANLINE_MAX/3.0, 1.0);
lines = pow(clamp(lines, SCANLINE_DARK * 2.0, 1.0) , 1/(sqrt(lum_scaled*lum_scaled*extra_power_1) ) );

//lines = pow(clamp(lines + 0.05, 0.0,1.0) , 1/(sqrt(lum_scaled*lum_scaled*extra_power_1) ) ) * extra_power_1/2.0;


        //lines = pow(clamp(lines + 0.05, 0.0,1.0) , 1/(lum_scaled*lum_scaled));

    //Thickness (max):

            /*lines = pow(abs(lines), 1/(10*lum_scaled*lum_scaled));
            float clamp_start=0.5;
            if (lum_scaled>clamp_start) lines = clamp(lines,(lum_scaled-clamp_start)/(1-clamp_start) ,1.0); //FIXME use step?*/

//min-max, ma difficile da gestire con la slotmask.
//    float extra_power = 2.0;
//    float m = mod(angle_base + (vScanlinesAlternate * HALF_PI), pi);
//    lines = exp( -pow((m-(HALF_PI)),2) / ( lum*extra_power ) ) * extra_power;


    lines = lines * (1-SCANLINE_DARK ) + SCANLINE_DARK ;
    return lines;
}

float get_clamped_white_reference(vec3 pixel_in){
    float white_reference = max(max(pixel_in.r,pixel_in.g),pixel_in.b);
    white_reference = min(white_reference,1.0); //Clamp here for both vmask and darklines.
    return white_reference;
}

vec4 pixel_main_pass(vec2 coords, bool bBorder_needed) {
    //Exit if we don't need a border (ambient light/background picture)
    //And we are outside the the border (unsure if this double check is good for performance) //FIXME
    if (bBorder_needed &&
       (vTexCoord.x < 0.0 || vTexCoord.x > 1.0 || vTexCoord.y < 0.0 || vTexCoord.y > 1.0))
       return vec4(0.0);

    vec3 pixel_in;
    vec3 pixel_glowed;

    //Get the first available pixel_in:
    //vec2 off=vec2(0.0,+ global.first_passSize.w*0.5); needed
    //To be added to the following coords and to halo coords (FIXME: WHY?)
    //if drawing scanlines on first pass too)
    if  (DO_IN_GLOW == 1.0) {
            pixel_glowed = texture(in_glow_pass,coords).rgb;
            pixel_in = pixel_glowed; 
    } else {
        pixel_in = texture(shift_and_bleed_pass,coords).rgb ;
    }


    vec3 pixel_out = pixel_in;
    float white_reference;
    if (VMASK_OVERWHITE+DRKLN_OVERWHITE  < 2.0 ) {
        white_reference = get_clamped_white_reference(pixel_in);
    }
    
    //Mask and darklines:
    if (DO_VMASK_AND_DARKLINES == 1.0 ) {
        vec3 pixel_in_compensated = pixel_in;
        
        pixel_in_compensated = pixel_push_luminance(pixel_in, RGB_MASK_STRENGTH * MASK_COMPENSATION);
        
        if (RGB_MASK_STRENGTH > 0.0) {
            //Use RGB pattern or exploit RGB layout with green and magenta?
            if (VMASK_USE_GM < 1.0)
                pixel_out = pixel_vmask(pixel_in_compensated, white_reference, VMASK_OVERWHITE);
            else
                pixel_out = pixel_vmask_gm(pixel_in_compensated, white_reference, VMASK_OVERWHITE);
            //Tried to unbranch to no avail (worse performances)
            //pixel_out = pixel_vmask_and_gm(pixel_in_compensated, white_reference, VMASK_OVERWHITE);
        }

        pixel_out = pixel_push_luminance(pixel_out, DARKLINES_STRENGTH * (1.0/DARKLINES_PERIOD) * MASK_COMPENSATION); 
        
        //Screen lines (slotmask aperture grille)
        if (   DARKLINES_STRENGTH > 0.0 ) {
            float MYDARKLINES_TRANSPARENCY = 1.0 - DARKLINES_STRENGTH;
            pixel_out = pixel_darklines(pixel_out, DARKLINES_PERIOD, MYDARKLINES_TRANSPARENCY, DARKLINES_VOFFSET, white_reference, DRKLN_OVERWHITE, coords);
        }

    }

    float lum = clamp(max(max(pixel_out.r,pixel_out.g),pixel_out.b), 0.0,1.0);
    
    //Halo
    vec3 pixel_haloed;
    if (DO_HALO == 1.0 ) {
        pixel_haloed = texture(halo_pass,coords).rgb;
        pixel_out += pixel_haloed * (1 - HALO_VS_SCAN);
    }

    /* Non flickering scanlines, Don't do them if
     * - User doesn't want scanlines
     * - The screen is interlaced and the user doesn't want scanlines on it.
     */
    if  ( DO_SCANLINES == 1.0 ) {
        /* pixel_bleed is the color that will bleed over scanline gap.
         * It is selected by the first available one depending on the shader
         * features enabled by the user */ 
        vec3 pixel_bleed;
        /*if (DO_HALO == 1.0) 
            pixel_bleed = pixel_haloed;
        else */if (DO_IN_GLOW == 1.0)
            pixel_bleed = pixel_glowed;
        else 
            pixel_bleed = pixel_in;
        
        // Optionally apply a gamma correction to the scanline shape.
        if (SCANLINE_COMPENSATION > 0.0) {
            float mypow = mix(1.0, (0.33 * SCANLINE_DARK + 0.67), SCANLINE_COMPENSATION);
            pixel_out = pow(pixel_out,vec3(mypow));
        }
        
        //Obtain the scanlines screen by multiplying the scanline shape by the pixel color.
        //and emulate the bleeding of the color over the dark part of the scanlined screen.
        //float scanline_shape = scanline_shape(coords, SCANLINE_SM_TYPE > 0.0 );     
            float lum = max(max(pixel_out.r, pixel_out.g), pixel_out.b);
            float scanline_shape = scanline_shape(coords, SCANLINE_SM_TYPE > 0.0, lum );
            
            pixel_out = pixel_out * ( scanline_shape + ( pixel_bleed * SCANLINES_BLEEDING * ( 1 - scanline_shape ) ));
                        
            //pixel_out *= scanline_shape;

    }

    
     if (DO_HALO == 1.0 ) {
        pixel_out += pixel_haloed * HALO_VS_SCAN;
        //pixel_out = pixel_out + (pixel_haloed * (1-lum));
     }
     
    // Apply color correction (in this pass it is just the final output gamma)
    if (DO_CCORRECTION == 1.0) pixel_out = pow(max(pixel_out, vec3(0.0)),vec3(GAMMA_OUT));

    //Out
    return vec4(pixel_out,1.0) ; //* border(border_coords);
}

float global_noise;

#ifdef STATIC_SUPPORT_BACKDROP
    vec3 pixel_backdrop_image() {
        vec2 backdrop_offset=vec2(BACKDROP_OFFX,BACKDROP_OFFY);

        vec2 backdrop_tex_size = textureSize(backdrop, 0);
        float backdrop_lod = log2(backdrop_tex_size.y / global.FinalViewportSize.y);

        vec2 backdrop_coords =  get_scaled_coords_aspect(
                                vOutputCoord+backdrop_offset,
                                global.FinalViewportSize,
                                backdrop_tex_size.x/backdrop_tex_size.y,
                                bool(vIsRotated));

        backdrop_coords=zoom(backdrop_coords, BACKDROP_ZOOM);
        return textureLod(backdrop, backdrop_coords, backdrop_lod).rgb;
    }
#endif

vec4 textureLod_wrap(sampler2D tex, vec2 co, float lod, float wrap_mode) {
    /*
    // Mirrored repeat, once, useless since is done by default
    if (co.x > 1.0 || co.x < 0.0)
        co.x = 1- mod(co.x, 1.0);
    if (co.y > 1.0 || co.y < 0.0)
        co.y = 1- mod(co.y, 1.0);
    */
    
    if (wrap_mode == 1.0) {
        //Clamp to border, black.
        bool bOutside = (co.x < 0.0 || co.x > 1.0 || co.y < 0.0 || co.y > 1.0 ) ;
        if (bOutside) return vec4(0.0,0.0,0.0,1.0);
    } else if (wrap_mode == 2.0) {
        //Clamp to edge:
        co = clamp(co, 0.00, 1.0);
    } else if (wrap_mode == 3.0) {
        //Repeat no mirror:
        co = mod(co, 1.0);
    }
    
    return textureLod(tex, co, lod);
}


vec4 pixel_background_image(bool over){
    //return the aspect corrected background image:
    vec2 bg_image_offset=vec2(BG_IMAGE_OFFX,BG_IMAGE_OFFY);
    if (over) {
        vec2 tex_size = textureSize(bg_over, 0); // * BG_ZOOM;
        float bg_over_lod = log2(tex_size.y / global.FinalViewportSize.y);

        if (BG_IMAGE_ROTATION > 0.0  || ( BG_IMAGE_ROTATION < 0.0 && bool(vIsRotated) )  ) tex_size.xy = tex_size.yx;

        vec2 back_coords = get_scaled_coords_aspect(vOutputCoord + bg_image_offset, global.FinalViewportSize, tex_size.x/tex_size.y, bool(vIsRotated));
        
        if (BG_IMAGE_ROTATION < 0.0 && bool(vIsRotated) ) {
            //handle automatic rotation of bg image for rotated games
            back_coords.xy = back_coords.yx;
            back_coords.y = 1 - back_coords.y;
        } else if (BG_IMAGE_ROTATION > 0.0) {
            //rotate as user prefs
            back_coords.xy = back_coords.yx;
            if (BG_IMAGE_ROTATION == 1.0) back_coords.y = 1 - back_coords.y;
            if (BG_IMAGE_ROTATION == 2.0) back_coords.x = 1 - back_coords.x;
        }
        back_coords=zoom(back_coords, BG_IMAGE_ZOOM);
        return textureLod_wrap(bg_over, back_coords, bg_over_lod, BG_IMAGE_WRAP_MODE);
    }
    //under
        vec2 tex_size = textureSize(bg_under, 0); // * BG_ZOOM;
        if (BG_IMAGE_ROTATION > 0.0) tex_size.xy = tex_size.yx;
        float bg_under_lod = log2(tex_size.y / global.FinalViewportSize.y);
        vec2 back_coords = get_scaled_coords_aspect(vOutputCoord + bg_image_offset,global.FinalViewportSize, tex_size.x/tex_size.y, bool(vIsRotated));
        if (BG_IMAGE_ROTATION > 0.0) {
            back_coords.xy = vec2(back_coords.y, back_coords.x);
            if (BG_IMAGE_ROTATION == 1.0) back_coords.y = 1 - back_coords.y;
            if (BG_IMAGE_ROTATION == 2.0) back_coords.x = 1 - back_coords.x;
        }
        back_coords=zoom(back_coords, BG_IMAGE_ZOOM);
        return textureLod_wrap(bg_under,back_coords,bg_under_lod, BG_IMAGE_WRAP_MODE);
        //return textureLod(bg_under,back_coords,bg_under_lod);
}

vec3 pixel_border(bool image_over) {
    /* Returns the surrounding of the tube/bezel:
     * The led lights alone
     * the led light "under" a background image (alpha driven)
     * black if we need to overlay a game backdrop
     */
    #ifdef STATIC_SUPPORT_BACKDROP
        return vec3(0.0);
    #endif
    vec3 pixel_out = vec3(1.0);
    if (DO_AMBILIGHT == 1.0)
        pixel_out =  texture(ambi_temporal_pass, vOutputCoord).rgb + vec3(global_noise);
    if (DO_BG_IMAGE == 1.0 && !image_over) {
        vec4 bg_image = pixel_background_image(false);
        pixel_out = mix(pixel_out,bg_image.rgb,bg_image.a);
    }
    return pixel_out;
}


vec3 pixel_alternate(vec3 source, float whiteness) {
    // Emulate the low crt persistance by only drawing odd/even lines
    // on odd/even frames
    float line = vTexCoord.y * params.OutputSize.y;
    vec3 pixel_out = source;
    float l_period_half = ALT_BLANK_PERIOD / 2;
    if  (mod(float(params.FrameCount),2.0  ) == 1) {
        if  (mod(line,ALT_BLANK_PERIOD) > l_period_half) pixel_out=mix(source,vec3(0), whiteness) ;
    } else {
        if  (mod(line,ALT_BLANK_PERIOD) <= l_period_half) pixel_out=mix(source,vec3(0), whiteness) ;
    }
    return pixel_out;
}


#define bezel_luminance bezel.r
vec3 bezel_color(float lum)  {
    //Colorize bezel frame
    vec3 col = vec3(BEZEL_R,BEZEL_G,BEZEL_B) + lum;
    float con_max =  0.5 * BEZEL_CON + 0.5;
    col = scale_to_range_vec3(col, -con_max+1, con_max);
    return clamp(col,0.0,1.0);
}


#define STATIC_BEZEL_USE_MIPMAP 1.0

vec3 compose_bezel_over(vec3 full_viewport) {
    vec2 coords_for_bezel = vTexCoord;
    
    if (BEZEL_FRAME_ZOOM != 0.0)
        coords_for_bezel = zoomout_coords(coords_for_bezel,-BEZEL_FRAME_ZOOM,1.0);  
    
    /* Bezel image is a fixed png file, and is curved.
     * To have a straight bezel, we can "unwarp" it and then curve it again
     * Too lame?
                    float BEZEL_IMG_BORDER_START_X = 120.0/2923.0; //= 0.03; 120
                    float BEZEL_IMG_BORDER_END_X = 220.0/2923.0 ;//= 0.2;    220
                    
                    float BEZEL_IMG_BORDER_START_Y = 75.0/2178.0; //= 0.01;  75
                    float BEZEL_IMG_BORDER_END_Y = 160.0/2178.0;//= 0.4;    160
                    
                    float BEZEL_IMG_CURVATURE_X = 0.6;
                    float BEZEL_IMG_CURVATURE_Y = 0.6;
                    
                    float min_x = min(coords_for_bezel.x, 1-coords_for_bezel.x);
                    float min_y = min(coords_for_bezel.y, 1-coords_for_bezel.y);

                    
                    
                    float kx = smoothstep(BEZEL_IMG_BORDER_START_X, BEZEL_IMG_BORDER_END_X, min(coords_for_bezel.x, 1-coords_for_bezel.x));
                    float ky = smoothstep(BEZEL_IMG_BORDER_START_Y, BEZEL_IMG_BORDER_END_Y, min(coords_for_bezel.y, 1-coords_for_bezel.y));
                    coords_for_bezel = Warp(coords_for_bezel,-BEZEL_IMG_CURVATURE_X * kx , -BEZEL_IMG_CURVATURE_Y * ky ); 
                    coords_for_bezel = Warp(coords_for_bezel,GEOM_WARP_X * kx , GEOM_WARP_Y * ky );
    */

    

    

    //No need to draw anything outside this:
    if (coords_for_bezel.x < 0  || coords_for_bezel.y < 0 || coords_for_bezel.x > 1.0 || coords_for_bezel.y > 1.0) return full_viewport;

    vec2 coords_for_mirror = coords_for_bezel;
    
    //Main lut:
    vec4 bezel;
    #ifdef STATIC_BEZEL_USE_MIPMAP
        vec2 bezel_lut_size = textureSize(monitor_body_curved,0); //no need to branch here if we assume straight and curved textures are the same size. //FIXME?
        float bezel_frame_lod = log2(bezel_lut_size.y * (BEZEL_FRAME_ZOOM+1.0) /global.FinalViewportSize.y);
        if (BEZEL_USE_STRAIGHT < 0.5)
            bezel = textureLod(monitor_body_curved,coords_for_bezel,bezel_frame_lod);
                else
            bezel = textureLod(monitor_body_straight,coords_for_bezel,bezel_frame_lod);
    #else
        if (BEZEL_USE_STRAIGHT < 0.5)
            bezel = texture(monitor_body_curved,coords_for_bezel);
                else
            bezel = texture(monitor_body_straight,coords_for_bezel);
    #endif
    
//return mix(bezel.rgb, vec3(kx), 0.5);
    //No need to draw anything on full alpha:
    if (bezel.a == 0.0) return full_viewport;

    //We use the red component of the bezel to express its luminance (define bezel_luminance bezel.r)
    vec3 bezel_colored = bezel_color(bezel_luminance);

    //This is the reflection to be composed over the bezel);
    vec3 pixel_mirrored = texture(reflected_blurred_pass2,
                          coords_for_mirror + random( min(global.FinalViewportSize.z,global.FinalViewportSize.w)*1.5, vTexCoord ) ).rgb;
//return pixel_mirrored;
    //Take the reflection modifier from the texture blue component into account; it is/may be used to lower the reflection in the corners.
        //float reflection = (reflection_shade * 1.4 -  0.4)  * bezel.b ;
        //reflection = clamp (reflection, 0.0, 1.0);
        float reflection = bezel.b;
        //return vec3(reflection);
        pixel_mirrored = pixel_mirrored * reflection * BEZEL_REFL_STRENGTH;
        //return pixel_mirrored;
        vec3 bezel_out = bezel_colored + pixel_mirrored;
        
        //Mix ambient light over bezel? (branching this is worse)     
        vec3 ambitemporalpass = texture(ambi_temporal_pass, vOutputCoord).rgb;
        ambitemporalpass = max(ambitemporalpass, 0.0); //<-- this to avoid undefined results
        vec3 pixel_ambilight = DO_AMBILIGHT * (ambitemporalpass + global_noise);
        

        float opacita = bezel.a;
        bezel_out = bezel_out + pixel_ambilight * AMBI_OVER_BEZEL * (1 -reflection) * bezel.a;
        
        //bezel_out = vec3(bezel.a);
        
         //(1- (max(reflection, lut_hardness), bezel.a)) ;
        //We use the green component to express Hardness/Specularity; there the reflection will be completely diffused.
        //For the task, we use a mipmap whit adeguate precision.
        float lut_hardness = bezel.g;
        if (lut_hardness > 0.0) {
            vec4 pixel_avglum = texture(avglum_pass,vOutputCoord);
            bezel_out = bezel_out + ( ( pixel_avglum.rgb + pixel_avglum.a*0.5)  * lut_hardness * 0.57 * BEZEL_REFL_STRENGTH );
        }
        
    return mix(full_viewport, bezel_out, bezel.a);
}

vec4 pixel_inner_frame(vec2 coords, bool bBorder_needed) {
//This takes care of drawing the main content.
    
    vec4 pixel_in = pixel_main_pass(coords, bBorder_needed);
    vec3 pixel_out = pixel_in.rgb;
    vec3 bloomed;

    //Mix bloom texture
    if (DO_BLOOM == 1.0 ) {
        bloomed=texture(bloom_pass_final, coords).rgb ;
                
        if (BLOOM_BYPASS > 0.5)
            pixel_out = bloomed;
        else
            pixel_out += bloomed;
    }

    //Black frame insertion
        if (DO_ALT_BLANK == 1.0 ) {
            pixel_out = pixel_alternate(pixel_out.rgb, ALT_BLANK_STRENGTH );
        }

    //vignette and spot
        if (DO_VIGNETTE + DO_SPOT >0.0) {
            //float in_aspect = get_in_aspect();

            if (DO_VIGNETTE == 1.0) {
                float dist = length(vec2((coords.x-0.5)*vIn_aspect,coords.y-0.5));
                float vignette = smoothstep(V_SIZE,0.0,dist)*V_POWER;                
                //float vignette = vV_POWER * (vV_SIZE + 16.0* coords.x*coords.y*(1.0-coords.x)*(1.0-coords.y));
                //vignette = min(vignette,99999.0); //<--- big wtf here, why is this needed? 
                ////...see: https://github.com/kokoko3k/koko-aio-slang/issues/3
                pixel_out = pixel_out * vignette;
            }

            if (DO_SPOT == 1.0) {
                float dist = length(vec2((coords.x-0.5)*vIn_aspect,coords.y-0.5)+spot_offset);
                float spot = smoothstep(S_SIZE,0.0,dist)*S_POWER;
                //vec2 scoords = clamp(coords + spot_offset, 0.0,1.0);
                //float spot = vS_POWER * (vS_SIZE + 16.0*scoords.x*scoords.y*(1.0-scoords.x)*(1.0-scoords.y));
                pixel_out = pixel_out + spot;
            }
            //pixel_out += global_noise;
        }

    //smooth border (edge)
        float border_inner_frame = 1.0;
        if (DO_BEZEL==1.0 || DO_CURVATURE == 1.0)
            border_inner_frame = border(coords);

        float pixel_out_alpha = pixel_in.a * border_inner_frame;

    //Out
        return vec4(pixel_out,pixel_out_alpha) * border_inner_frame;
}


vec4 main_wrap(vec2 coords){
    /* Handle inner border and outer border, not bezel */
    if (DO_VIGNETTE + DO_SPOT + DO_AMBILIGHT >0.0) global_noise = random(NOISEPOWER, vTexCoord * params.FrameCount);
    
    //Just do pixel_inner_frame() and exit when there is no need to paint border.
    if (!border_needed()) return pixel_inner_frame(coords, false);

    //From now on, we need a border.
        bool bIs_outer_frame = ((vTexCoord.x < 0.0) || (vTexCoord.x > 1.0));

        //Handle outer frame cases
            //if we want ambilights in the outer frame, draw it and return
            if (bIs_outer_frame)
                return vec4(pixel_border(BG_IMAGE_OVER == 1.0),1.0);

            //But if it is just outer frame, just make it black.
            if (bIs_outer_frame) return vec4(0.0);


        //Handle inner frame cases
            vec4 vPixel_inner_frame = pixel_inner_frame(coords, true);
                //mix ambilight in the inner frame too, as curvature could shrink into the inner frame.
                bool draw_border = true;
                //Not painting ambilights here is the best way to cheaply draw a border around the frame
                if (DO_BEZEL == 1.0) {
                    vec2 vTexCoord_zoomout = zoomout_coords(vTexCoord, -BEZEL_INNER_ZOOM , 1.0);
                    float border_start = 1-BEZEL_IMAGE_BORDER;
                    //Not using curved coords here because crazy things would happen with vertical games
                    draw_border = vTexCoord_zoomout.x < border_start || vTexCoord_zoomout.x > BEZEL_IMAGE_BORDER ||
                                vTexCoord_zoomout.y < border_start || vTexCoord_zoomout.y > BEZEL_IMAGE_BORDER ;
                }
                if (draw_border)
                    return vec4(mix(pixel_border(BG_IMAGE_OVER == 1.0).rgb,vPixel_inner_frame.rgb,min(vPixel_inner_frame.a*1.5,1.0)),vPixel_inner_frame.a);
                //return vec4(1.0,0.0,0.0,1.0);

        //Last case, inner border without ambilight:
            return vPixel_inner_frame;
}


void main() {
    
    vec2 coords = vTexCoord;

    //Luminosity dependant zoom
    if (DO_DYNZOOM == 1.0) {
        //float zoomin = 1.0 + (texture(bloom_pass_final, coords   ).a/ DYNZOOM_FACTOR * 80.0); <<-- funny.
        //float dynzoom = 1.0 + (texture(avglum_pass, vec2(0.75,0.75)    ).a/ DYNZOOM_FACTOR);
        float dynzoom = get_dyn_zoom(avglum_pass);
        coords = zoom(coords, dynzoom);
    }

    //Scale coords according to bezel settings?
    if (DO_BEZEL == 1.0) {
        coords = zoomout_coords(coords, -BEZEL_INNER_ZOOM , 1.0);
        coords = clamp(coords, 0.0,1.0);
    }
    
    //Curvature
    if (DO_CURVATURE == 1.0) {
        if ((GEOM_WARP_X > 0.0) || (GEOM_WARP_Y > 0.0))
            coords = Warp_fast(coords, vWarp_vexp, vWarp_arg2);
            
    }
     
    //"Just" handle inner and outer frame here:
    vec4 pixel_out = main_wrap(coords);


#ifdef STATIC_SUPPORT_BACKDROP
    pixel_out += vec4(pixel_backdrop_image(), 1.0);
#endif


    
    //Draw bezel
    if (DO_BEZEL == 1.0) {
        pixel_out = vec4(compose_bezel_over(pixel_out.rgb),1.0);
    }

    //Draw an image "Over" the bezel with an hole inside by the alpha channel
    if (DO_BG_IMAGE == 1.0 && BG_IMAGE_OVER==1.0) {
        vec4 bg_image = pixel_background_image(true);
        pixel_out = mix(pixel_out,bg_image,bg_image.a);
    }

    //For debug purposes:
        //quad split screen
        //if ( (vOutputCoord.x < 0.5  && vOutputCoord.y > 0.5) || (vOutputCoord.x > 0.5  && vOutputCoord.y < 0.5)  ) pixel_out = texture(first_pass,vOutputCoord);
        //split screen
        //if (vTexCoord.y < 0.5) pixel_out = texture(first_pass,vTexCoord);
        //pixel_out = texture(avglum_pass,vTexCoord);

    //vec4 pixel_mirrored = texture(reflected_blurred_pass2,vTexCoord);
    //pixel_out = pixel_mirrored;
    
    
    FragColor = pixel_out;
    
    //FragColor = vec4(blur_shade(vTexCoord) );
    
    //FragColor = vec4(random(1.0, vTexCoord * params.FrameCount));
}
