#version 450
#include "config.inc"

float CVBS_get_bleed_size() {
    // This will be called by Fragment and vertex shader
    #ifdef D3D_WORKAROUND
        // d3d11 compiler complains it is unable to unroll the loop because it is
        // clueless about the maximum pragma value; d3d12 hangs somewhere.
        return min(5.0,CVBS_BLEED_SAMPLES);
    #else
        return min(20.0,CVBS_BLEED_SAMPLES);
    #endif
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) noperspective out vec2 vTexCoord;
layout(location = 6) flat out vec3 vCVBS_blur_weights;

layout(location = 9) flat out float vDotCrawlShift;
layout(location = 10) noperspective out vec4 vDotCrawlCoords_and_period;
#include "includes/functions.include.slang"

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord ;  


   
    // Help CVBS blur:
    //https://www.sciencedirect.com/topics/computer-science/color-subcarrier
    //YIQ/YUV Ntsc/Pal bandwidths
        vec3 composite_mhz = vec3(0.0);
        if (CVBS_BLEED_PAL == 1.0)
            composite_mhz = vec3(5.0, 1.3, 1.3); //pal YUV
        else
            composite_mhz = vec3(4.2, 1.5, 0.5);  //ntsc YIQ
            
        //composite_mhz.yz /= vec2(2.0);
    
        //0.5 because it is the minimum bandwidth present (Q in ntsc)
        vCVBS_blur_weights = 0.5/composite_mhz;

        vCVBS_blur_weights *= CVBS_get_bleed_size()+1;
  
        vCVBS_blur_weights /= (CVBS_BLEED_ADJUST+eps); //modulate bandwidths via parameter
        
                
   //Mod framecount for animating dot crawl (needed to avoid precision errors)   
      float dot_c_steps = 6.0; // frames needed to reach sin period; higher = slower;
      dot_c_steps = 22-( abs(DOT_C_SPEED) *2)+0.0001;
      vDotCrawlShift =((pi*2)/dot_c_steps) * mod(params.FrameCount, dot_c_steps);
   
      float dotc_w_adapted = 1.0; //320.0/params.OriginalSize.x;
      
      vDotCrawlCoords_and_period = vec4(vTexCoord, params.OriginalSize.xy * vec2( dotc_w_adapted, 1.0) );
   
      // switch to vertical movement
      if (DOT_C_SPEED < 0.0)
         vDotCrawlCoords_and_period.xyzw = vDotCrawlCoords_and_period.yxwz;
}


#pragma stage fragment
#include "includes/functions.include.slang"
layout(location = 0) noperspective in vec2 vTexCoord;
layout(location = 6) flat in vec3 vCVBS_blur_weights;

layout(location = 9) flat in float vDotCrawlShift;
layout(location = 10) noperspective in vec4 vDotCrawlCoords_and_period;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D upscale_pass;


vec3 shadow(vec2 coords, sampler2D in_texture, vec3 source_pixel) {
    //Emulates shadowing for dot matrix screens like Gameboy.
    vec2 off = vec2(DOT_M_SHADOW_OFF, abs(DOT_M_SHADOW_OFF)) * -params.OutputSize.zw * 0.5;
    vec3 pixel_shadow = texture(in_texture,coords + off).rgb;
    return source_pixel.rgb - max( (source_pixel.rgb - pixel_shadow), vec3(0.0) ) * DOT_M_SHADOW_STR;
}

float dotc_carrier(vec2 co, vec2 OriginalSize) {  
   float sin_crawl = sin(co.x*OriginalSize.x*pi - vDotCrawlShift ) *
                     sin(co.y*OriginalSize.y*pi);
   
   sin_crawl = step(0.0, sin_crawl);
               
   sin_crawl *= DOT_C; //Modulate strength
   return sin_crawl;
}

float distance_approx(vec2 a, vec2 b, float p) {
   // for p = 0.5 it acts like distance(), but with more cycles.
   float d = dot( a-b, a-b );
   return pow(d,p);
}

vec3 dotc(sampler2D in_texture, vec3 pixel_in, vec2 co, vec4 tex_size){
   //Sample adiacent texels and switch colorspace.
   const float dot_crawl_size = 1.0; //0.5, 1.0, 1.5
   vec3 cm = rgb2yiq( texture(in_texture, co).rgb );
   vec3 cr = rgb2yiq( texture(in_texture, co + vec2(tex_size.z*dot_crawl_size, 0.0)).rgb );
   vec3 cl = rgb2yiq( texture(in_texture, co - vec2(tex_size.z*dot_crawl_size, 0.0)).rgb );
   //Compute max chroma change
      //float d = max(distance(cm.yz,cr.yz),  distance(cm.yz,cl.yz));
      //d = pow(d, 1.5); // bias, less on lower distance.
      //The following have less cycles, but same result.
      const float p = 0.75;
      float d = max(distance_approx(cm.yz,cr.yz,p),  distance_approx(cm.yz,cl.yz,p));
      d=pow(d, 0.5);
      
   //apply moving square carrier (already modulatd by strength) to the chroma distance
      float crosstalk = d * dotc_carrier(vDotCrawlCoords_and_period.xy, vDotCrawlCoords_and_period.zw);
      //return vec3(dotc_carrier(co, tex_size.xy));
   
   // chroma into luma
      pixel_in = rgb2yiq( pixel_in );
      //pixel_in.x = mix(pixel_in.x, (pixel_in.y+pixel_in.z)*0.5, crosstalk);
      pixel_in.x = pixel_in.x - (abs(pixel_in.y)+abs(pixel_in.z)) * crosstalk;
      
   return yiq2rgb( pixel_in );
}

vec3 pixel_bleed(vec3 pixel_in, vec2 co, sampler2D in_texture, float sourcesize_z) { 
   //Sometimes first frame has 0x0 size, that makes gpu mad in a way or another.
   //Fixes: https://github.com/kokoko3k/koko-aio-slang/issues/28
   if (sourcesize_z > 1.0) return pixel_in;
   mat3 colorspace_out;
   mat3 colorspace_rgb;
   //https://www.sciencedirect.com/topics/computer-science/color-subcarrier
   if (CVBS_BLEED_PAL > 0.5) {
      colorspace_out = RGB2YUV;
      colorspace_rgb = YUV2RGB;
   } else {
      colorspace_out = RGB2YIQ;
      colorspace_rgb = YIQ2RGB;
   }
      //Initial color in yiq or yuv space
      vec3 pixel_YIQ = colorspace_out * pixel_in.rgb;
      float size = CVBS_get_bleed_size(); //number of samples.
      vec3 sum_color = pixel_YIQ * vCVBS_blur_weights;
      vec3 total_weight = vCVBS_blur_weights;
      for (float i = 1.0; i <= size; i++) {
          
         float offset = sourcesize_z * (i + i*i*CVBS_BLEED_COARSE); //optional use coarse sampling
      
         vec3 smp_RGB = (texture(in_texture, vTexCoord + vec2(offset, 0.0)).rgb +
                        texture(in_texture, vTexCoord - vec2(offset, 0.0)).rgb) * 0.5;
         vec3 smp_YIQ = colorspace_out * smp_RGB;
         
         vec3 current_weight = max(2.0 * (vCVBS_blur_weights - vec3(i)), vec3(0.0));
         
         sum_color += smp_YIQ * current_weight;
         total_weight += current_weight;
      }
      // Normalizzazione finale
      pixel_YIQ = sum_color / total_weight;
      vec3 pixel_RGB = colorspace_rgb * pixel_YIQ;
      
      return pixel_RGB;
}





void main() {
   #ifndef D3D_WORKAROUND
      if (fps_halver_is_skipped_frame())
         return;
   #endif
   vec4 pixel_out;

   pixel_out = texture(upscale_pass, vTexCoord);
   
   // CVBS bleeding before deconvergence is better when CVBS bleeding is set to pal.
   // That way deconvergence does not completely succumb to PAL bleed.
   // For performance reasons, is still a tradeoff, but at least you can modulate
   // between the two.
   
   //bleed
   if (DO_CVBS_BLEED > 0.5)
      // do not use upscale_pass size, but params.OriginalSize.z*0.5 so that hiresgames presets will look the same
      pixel_out.rgb = pixel_bleed(pixel_out.rgb, vTexCoord, upscale_pass, params.OriginalSize.z*0.5);

   if (DOT_C > 0.0)
      pixel_out.rgb = dotc(upscale_pass, pixel_out.rgb, vTexCoord, params.OriginalSize);

   //... and shift
    if (DO_DOT_MATRIX == 1.0)
        pixel_out.rgb = shadow(vTexCoord, upscale_pass, pixel_out.rgb);

   pixel_out.rgb = max(vec3(0.0), pixel_out.rgb);  //make sure everything is over 0.0

   pixel_out.rgb = pow(pixel_out.rgb, vec3(IN_GLOW_GAMMA)); //apply gamma in 
      
   FragColor = pixel_out;
}
