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

#include "includes/functions.include.slang"

void main() {
    gl_Position = global.MVP * Position;
    vIsRotated = float(is_rotated());
    vTexCoord = get_scaled_coords(TexCoord,global.FinalViewportSize, bool(vIsRotated) ) + vec2(0.00001);
    vOutputCoord = TexCoord;

    spot_offset = offsets_from_float(S_POSITION+420.0,40);
    spot_offset = spot_offset / 10.0 + vec2(0.0,1.0);

    vFragCoord = vec2( floor(vOutputCoord.x * params.OutputSize.x),
                       floor(vOutputCoord.y * params.OutputSize.y));
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vOutputCoord;
layout(location = 2) in vec2 spot_offset;
layout(location = 3) in vec2 vFragCoord;
layout(location = 4) in float vIsRotated;

layout(location = 0) out vec4 FragColor;


layout(set = 0, binding = 2)  uniform sampler2D bloom_pass_final;
layout(set = 0, binding = 3)  uniform sampler2D reflected_blurred_pass2;
layout(set = 0, binding = 4)  uniform sampler2D ambi_temporal_pass;
layout(set = 0, binding = 5)  uniform sampler2D avglum_pass;
layout(set = 0, binding = 6)  uniform sampler2D monitor_body;
layout(set = 0, binding = 7)  uniform sampler2D bg_under;
layout(set = 0, binding = 8)  uniform sampler2D bg_over;
layout(set = 0, binding = 9)  uniform sampler2D first_pass;
layout(set = 0, binding = 10) uniform sampler2D shift_and_bleed_pass;

//Ex main_pass layouts:
    layout(set = 0, binding = 11) uniform sampler2D FXAA_pass;
    layout(set = 0, binding = 12) uniform sampler2D in_glow_pass;
    layout(set = 0, binding = 13) uniform sampler2D halo_pass;
    layout(set = 0, binding = 14) uniform sampler2D avglum_passFeedback;


#define HALF_PI 1.5707963267949
#define QUARTER_PI 0.785398163397448

#include "includes/functions.include.slang"

vec3 pixel_vmask(vec3 source, vec3 white_reference, float over_white) {
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
            float whiteness=max(max(white_reference.r,white_reference.g),white_reference.b);
            whiteness-= over_white;
            whiteness=  clamp(whiteness,0.0,1.0);
            pixel_out=  mix(vmasked,source,whiteness);
        }
   return pixel_out;  
    
}
    

vec3 pixel_vmask_gm(vec3 source, vec3 white_reference, float over_white) {
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
            float whiteness=max(max(white_reference.r,white_reference.g),white_reference.b);
            whiteness-= over_white;
            whiteness=  clamp(whiteness,0.0,1.0);
            pixel_out=  mix(vmasked,source,whiteness);
        }

   return pixel_out;
}



/*bool drawit( float period, float off, vec2 coords){    
    coords = vTexCoord; 
    float first_pass_size_y = global.first_passSize.y * period;   
    float current_line_int = floor(coords.y * first_pass_size_y) + off ;
    float screenline_height = first_pass_size_y/params.OutputSize.y;//; params.OutputSize.y/first_pass_size_y;
    return (coords.y * first_pass_size_y  > current_line_int) &&  
           (coords.y * first_pass_size_y  < current_line_int+screenline_height) ; 
}*/

vec3 pixel_darklines(vec3 source,float darkline_every, float darkline_trans,
                     float do_offset, vec3 white_reference,float over_white, vec2 coords) {
    /* "darklines" are vertical gaps that can be used to emulate aperturegrille
    * or slotmasks
    */
    
    float Darkline_part_w = (3.0 - VMASK_USE_GM + VMASK_GAP) * VMASK_DARKLINE_SCALE;
    float Darkline_part_w_x2 = Darkline_part_w*2;

    darkline_every *= VMASK_DARKLINE_SCALE;

    if (over_white != 1.0) {
        //less effect on bright colors.
        float whiteness=max(max(white_reference.r,white_reference.g),white_reference.b);
        darkline_trans+=(whiteness-over_white);
        darkline_trans=clamp(darkline_trans,0.0,1.0);
    }

    //Slotmask (darklines are drawn with offset)
    if (do_offset > 0.0) {
        bool odd_line_meno_densa = mod(vFragCoord.y, darkline_every) > VMASK_DARKLINE_SCALE ;
        bool odd_line_piu_densa = !(mod(vFragCoord.y, darkline_every/2) < VMASK_DARKLINE_SCALE && odd_line_meno_densa);
        bool odd_column = mod(vFragCoord.x + Darkline_part_w  , Darkline_part_w_x2) < Darkline_part_w;
        bool draw_mask = odd_line_piu_densa && !odd_column || odd_column && odd_line_meno_densa;
        
        /*
        //quante scanline è alta la darkline
        float darkline_height = 1/2.0;      
        draw_mask = drawit(darkline_height,0.0, coords) && odd_column || drawit(darkline_height,0.5, coords) && !odd_column;
        return source * float(!draw_mask);
        */
        
        return source * clamp(float(draw_mask),darkline_trans,1.0);
    }
    
    //Aperture grille (darklines are drawn straight)
        bool draw_dark = mod(vFragCoord.y, darkline_every) < VMASK_DARKLINE_SCALE;
        bool draw_color = !draw_dark;
        return source * ( float(draw_color) +  float(draw_dark) * darkline_trans );
}



float scanline_shape(vec2 coords, bool do_flicker, bool is_interlaced, bool do_slotmask) {
/* Produces a B/W scanline shape to be multiplicated by the source
 * pixel later on to emulate scanline effect.
 * scanlines can be drawn on odd and even fields alternating on odd and
 * even frames to emulate that aspect of interlacing.
 */

    bool alternate = false;
    float period = 1.0;
    if (do_flicker) {
        if (params.FrameCount % 2 == 0.0) alternate = true;
        if (params.OriginalSize.y > MIN_LINES_INTERLACED )  period = 0.5;
    }

    float angle_base = coords.y * pi * params.OriginalSize.y * period;

    float lines = 1.0;
    if (!( is_interlaced && SCANLINE_DISABLE_ON_INTERLACE == 1.0 )) {
        if (alternate)
            lines = -sin(angle_base + HALF_PI); //lines = abs(cos(angle))
                else
            lines = sin(angle_base);
        lines = (lines*lines);
    }


    //Draw the slotmask right here if the height is the same as the scanline.
    if (do_slotmask) {
        if (do_flicker) {
            //Fallback to old darklines code to avoid glitches/artifacts.
            lines = lines * pixel_darklines(vec3(1.0),DARKLINES_PERIOD,1-SCANLINE_SM_STRENGTH,1.0,vec3(0.0),1.0, coords).r;

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
                    float phase = pi + SCANLINE_SM_VOFFSET*0.01;
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
                    phase = period * pi + QUARTER_PI;
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
                lines = lines * lines;
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
    
    if (SCANLINE_DARK >= 0.0) {
        lines = lines * (1.0 - SCANLINE_DARK) + SCANLINE_DARK;
    } else {
        float deepness = -SCANLINE_DARK;
        lines = lines * ((1-SCANLINE_DARK) ) + SCANLINE_DARK ;
    }
    return lines;
}

vec4 pixel_main_pass(vec2 coords, bool bBorder_needed) {
    //Exit if we don't need a border (ambient light/background picture)
    //And we are outside the the border (unsure if this double check is good for performance) //FIXME
    if (bBorder_needed)
        if (vTexCoord.x < 0.0 || vTexCoord.x > 1.0 || vTexCoord.y < 0.0 || vTexCoord.y > 1.0) return vec4(0.0);

    bool isinterlaced = is_interlaced();
    bool flickering_scanlines = (DO_SCANLINES == 1.0) && scanline_have_to_flicker(isinterlaced) ;

    vec3 pixel_in;
    vec3 pixel_glowed;

    //Get the first available pixel_in:
    if  (DO_IN_GLOW == 1.0) {
            pixel_glowed = texture(in_glow_pass,coords).rgb;
            pixel_in = pixel_glowed; }
    else if ( DO_SHIFT_RGB + DO_SAT_BLEED > 0.0)
        pixel_in = texture(shift_and_bleed_pass,coords).rgb ;
    else if (DO_FXAA > 0.0)
        pixel_in = texture(FXAA_pass,coords).rgb ;
    else
        pixel_in = texture(first_pass,coords).rgb ;


    vec3 pixel_out = pixel_in;
    vec3 pixel_in_clamped = min(pixel_in,vec3(1.0)); //Clamp here for both vmask and darklines.

    //Mask and darklines:
    if (DO_VMASK_AND_DARKLINES == 1.0 ) {
        vec3 pixel_in_compensated = pixel_in;
        
        pixel_in_compensated = pixel_push_luminance(pixel_in, RGB_MASK_STRENGTH * MASK_COMPENSATION);
        
        if (RGB_MASK_STRENGTH > 0.0) {
            //Use RGB pattern or exploit RGB layout with green and magenta?
            if (VMASK_USE_GM < 1.0)
                pixel_out = pixel_vmask(pixel_in_compensated, pixel_in_clamped, VMASK_OVERWHITE);
            else
                pixel_out = pixel_vmask_gm(pixel_in_compensated, pixel_in_clamped, VMASK_OVERWHITE);
        }

        pixel_out = pixel_push_luminance(pixel_out, DARKLINES_STRENGTH * (1.0/DARKLINES_PERIOD) * MASK_COMPENSATION); 
        
        //Screen lines (slotmask aperture grille)
        if (   DARKLINES_STRENGTH > 0.0 ) {
            float MYDARKLINES_TRANSPARENCY = 1.0 - DARKLINES_STRENGTH;
            pixel_out = pixel_darklines(pixel_out,DARKLINES_PERIOD,MYDARKLINES_TRANSPARENCY,DARKLINES_VOFFSET,pixel_in_clamped,DRKLN_OVERWHITE, coords);
        }

    }

    
    float lum = clamp(max(max(pixel_out.r,pixel_out.g),pixel_out.b), 0.0,1.0);
    
    //Halo
    vec3 pixel_haloed;
    if (DO_HALO == 1.0 ) {
        pixel_haloed = texture(halo_pass,coords).rgb;
        pixel_out += pixel_haloed * (1 - HALO_VS_SCAN);
        //pixel_out += (pixel_haloed * (lum));
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
        
        //The following should be theoretically more correct, but it produces moiree:
/*         vec3 vscanline_shape = scanline_shape(coords, flickering_scanlines, isinterlaced,  SCANLINE_SM_TYPE > 0.0 ) + 
                               (pixel_bleed * SCANLINES_BLEEDING);
         vscanline_shape = min(vscanline_shape,1.0);
         pixel_out = vscanline_shape * pixel_out;
*/        
        
        //Obtain the scanlines screen by multiplying the scanline shape by the pixel color.
        //and emulate the bleeding of the color over the dark part of the scanlined screen.
        //float scanline_shape = scanline_shape(coords, flickering_scanlines, isinterlaced,  SCANLINE_SM_TYPE > 0.0 );     
            float scanline_shape = scanline_shape(coords, flickering_scanlines, isinterlaced,  SCANLINE_SM_TYPE > 0.0 );     
        
        //Modify scanline weight?
            //float l = max(max(pixel_bleed.r, pixel_bleed.g), pixel_bleed.b);
            //scanline_shape = min(pow(scanline_shape, 1/l), 1.0);
            
            pixel_out = pixel_out * ( scanline_shape + ( pixel_bleed * SCANLINES_BLEEDING * ( 1 - scanline_shape ) ));
      

        
    }

    
     if (DO_HALO == 1.0 ) {
        pixel_out += pixel_haloed * HALO_VS_SCAN;
        //pixel_out = pixel_out + (pixel_haloed * (1-lum));
     }
     
    // Apply color correction (in this pass it is just the final output gamma)
    if (DO_CCORRECTION == 1.0) pixel_out = pow(pixel_out,vec3(GAMMA_OUT));

    //Out
    return vec4(pixel_out,1.0) ; //* border(border_coords);
}

float global_noise;



vec4 pixel_background_image(bool over){
    //return the aspect corrected background image:
    vec2 bg_image_offset=vec2(BG_IMAGE_OFFX,BG_IMAGE_OFFY);
    if (over) {
        vec2 tex_size = textureSize(bg_over, 0); // * BG_ZOOM;
        float bg_over_lod = log2(tex_size.y / global.FinalViewportSize.y);

        if (BG_IMAGE_ROTATION > 0.0  || ( BG_IMAGE_ROTATION < 0.0 && bool(vIsRotated) )  ) tex_size.xy = tex_size.yx;

        vec2 back_coords =  get_scaled_coords_aspect(vOutputCoord+bg_image_offset,global.FinalViewportSize, tex_size.x/tex_size.y, bool(vIsRotated));
        
        if (BG_IMAGE_ROTATION < 0.0 && bool(vIsRotated) ) {
            //handle automatic rotation of bg image for rotated games
            back_coords.xy = vec2(back_coords.y, back_coords.x);
            back_coords.y = 1 - back_coords.y;
        } else if (BG_IMAGE_ROTATION > 0.0) {
            //rotate as user prefs
            back_coords.xy = vec2(back_coords.y, back_coords.x);
            if (BG_IMAGE_ROTATION == 1.0) back_coords.y = 1 - back_coords.y;
            if (BG_IMAGE_ROTATION == 2.0) back_coords.x = 1 - back_coords.x;
        }
        back_coords=zoom(back_coords, BG_IMAGE_ZOOM);
        return textureLod(bg_over,back_coords,bg_over_lod);
    }
    //under
        vec2 tex_size = textureSize(bg_under, 0); // * BG_ZOOM;
        if (BG_IMAGE_ROTATION > 0.0) tex_size.xy = tex_size.yx;
        float bg_under_lod = log2(tex_size.y / global.FinalViewportSize.y);
        vec2 back_coords =  get_scaled_coords_aspect(vOutputCoord+bg_image_offset,global.FinalViewportSize, tex_size.x/tex_size.y, bool(vIsRotated));
        if (BG_IMAGE_ROTATION > 0.0) {
            back_coords.xy = vec2(back_coords.y, back_coords.x);
            if (BG_IMAGE_ROTATION == 1.0) back_coords.y = 1 - back_coords.y;
            if (BG_IMAGE_ROTATION == 2.0) back_coords.x = 1 - back_coords.x;
        }
        back_coords=zoom(back_coords, BG_IMAGE_ZOOM);
        return textureLod(bg_under,back_coords,bg_under_lod);
}

vec3 pixel_border(bool image_over) {
    /* Returns the surrounding of the tube/bezel:
     * The led light alone
     * the led light "under" a background image (alpha driven)
     */
    vec3 pixel_out = vec3(1.0);
    if (DO_AMBILIGHT == 1.0)
        pixel_out =  texture(ambi_temporal_pass, vOutputCoord + global_noise ).rgb;
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

    col.r = scale_to_range(col.r, -con_max+1, con_max); //contrast
    col.g = scale_to_range(col.g, -con_max+1, con_max); //contrast
    col.b = scale_to_range(col.b, -con_max+1, con_max); //contrast
    return clamp(col,0.0,1.0);
}

vec3 compose_bezel_over(vec3 full_viewport) {
    vec2 bezel_lut_size = textureSize(monitor_body,0);
    float bezel_frame_lod = log2(bezel_lut_size.y * (BEZEL_FRAME_ZOOM+1.0) /global.FinalViewportSize.y);
    vec2 coords_for_bezel = vTexCoord;

    if (BEZEL_FRAME_ZOOM != 0.0)
        coords_for_bezel = zoomout_coords(vTexCoord,-BEZEL_FRAME_ZOOM,1.0);

    vec2 coords_for_mirror = coords_for_bezel;
    //No need to draw anything outside this:
    if (coords_for_bezel.x < 0  || coords_for_bezel.y < 0 || coords_for_bezel.x > 1.0 || coords_for_bezel.y > 1.0) return full_viewport;

    //Main lut:
    vec4 bezel = textureLod(monitor_body,coords_for_bezel,bezel_frame_lod);

    //No need to draw anything on full alpha:
    if (bezel.a == 0.0) return full_viewport;

    //We use the red component of the bezel to express its luminance (define bezel_luminance bezel.r)
    vec3 bezel_colored = bezel_color(bezel_luminance);

    //This is the reflection to be composed over the bezel);
    vec3 pixel_mirrored = texture(reflected_blurred_pass2,
                          coords_for_mirror + random( min(global.FinalViewportSize.z,global.FinalViewportSize.w), vTexCoord ) ).rgb;

    //Take the reflection modifier from the texture blue component into account; it is/may be used to lower the reflection in the corners.
        //float reflection = (reflection_shade * 1.4 -  0.4)  * bezel.b ;
        //reflection = clamp (reflection, 0.0, 1.0);
        float reflection = bezel.b;

        vec3 bezel_out = bezel_colored + (pixel_mirrored * reflection * 0.5) ;

    //Mix a bit of ambient light over the bezel
        vec4 pixel_avglum = texture(avglum_pass,vOutputCoord);
        bezel_out = bezel_out + (pixel_avglum.rgb * 0.05);

    //We use the green component to express Hardness/Specularity; there the reflection will be completely diffused.
    //For the task, we use a mipmap whit adeguate precision.
        float lut_hardness = bezel.g;
        if (lut_hardness > 0.0) {
            bezel_out = bezel_out + ( ( pixel_avglum.rgb + pixel_avglum.a*0.5)       * lut_hardness/3.5);
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
        if (BLOOM_BYPASS == 1.0)
            pixel_out = bloomed;
        else {
            float over_white_correction = 1.0;
            if (BLOOM_OVER_WHITE < 1.0) {
                    //Use mipmap to identify bright areas.
                    vec3 avglum = texture(avglum_pass,coords).rgb;
                    //avglum = apply_fuzzy_main_pass(avglum);
                    float b_brightness = max(avglum.b,max(avglum.r,avglum.g));
                    //b_brightness = max(pixel_out.b,max(pixel_out.r,pixel_out.g));
                    
                    b_brightness *= 1-BLOOM_OVER_WHITE;
                    over_white_correction =1- b_brightness;
            }

            pixel_out = pixel_out + (bloomed * BLOOM_MIX * over_white_correction);
        }
    }

    //Black frame insertion
        if (DO_ALT_BLANK == 1.0 ) {
            pixel_out = pixel_alternate(pixel_out.rgb, ALT_BLANK_STRENGTH );
        }

    //vignette and spot
        if (DO_VIGNETTE + DO_SPOT >0.0) {
            float in_aspect = get_in_aspect();

            if (DO_VIGNETTE == 1.0) {
                float vignette;
                float dist = length(vec2((coords.x-0.5)*in_aspect,coords.y-0.5));
                vignette = smoothstep(V_SIZE,0.0,dist)*V_POWER+global_noise;
                if (V_BYPASS < 1.0) pixel_out = vignette * clamp(pixel_out,0.0,1.0);
                    else
                pixel_out = vec3(vignette);
            }

            if (DO_SPOT == 1.0) {
            float spot;
            float dist = length(vec2((coords.x-0.5)*in_aspect,coords.y-0.5)+spot_offset);
            spot = smoothstep(S_SIZE,0.0,dist)*S_POWER+global_noise;
            if (S_BYPASS < 1.0) pixel_out = spot + pixel_out;
                else
            pixel_out = vec3(spot);
            }
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
        float zoomin = 1.0 + (texture(avglum_passFeedback, vec2(0.25,0.25)    ).a/ DYNZOOM_FACTOR);
        coords = zoom(coords, zoomin);
    }
    
    //Curvature
    if (DO_CURVATURE == 1.0) {
        if ((GEOM_WARP_X > 0.0) || (GEOM_WARP_Y > 0.0))
            coords = Warp(coords,GEOM_WARP_X,GEOM_WARP_Y);
    }

    //Scale coords according to bezel settings?
    if (DO_BEZEL == 1.0) {
        coords = zoomout_coords(coords, -BEZEL_INNER_ZOOM , 1.0);
    }

    //"Just" handle inner and outer frame here:
    vec4 pixel_out = main_wrap(coords);

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
        
    FragColor = pixel_out;
}
