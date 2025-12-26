#version 450
#include "config.inc"

#define RGB_SHIFT_RANGE 20

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vR_offset;
layout(location = 2) out vec2 vG_offset;
layout(location = 3) out vec2 vB_offset;
layout(location = 4) out float vDo_shadow_mode;
layout(location = 5) out float vDecon_or_JustShadow;
layout(location = 6) out vec3 vCVBS_bandwidths;

layout(location = 9) out float vDotCrawlShift;
layout(location = 10) out vec4 vDotCrawlCoords_and_period;
#include "includes/functions.include.slang"

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord ;  
   
   //...to tell fragment shader if dot matrix feature requests shadows.
      vDo_shadow_mode = float(DOT_M_SHADOW_STR + DO_DOT_MATRIX > 1 + eps);
   
   //Shadow mode disables deconvergence, they do not coexist in real life.
   if (vDo_shadow_mode == 1.0) {
      vR_offset = vec2(DOT_M_SHADOW_OFF, abs(DOT_M_SHADOW_OFF));
      vG_offset = vR_offset;
      vB_offset = vR_offset;
      vec2 d = -params.OutputSize.zw * 0.5;
      vR_offset *= d;
      vG_offset *= d;
      vB_offset *= d;
   } else if (DO_SHIFT_RGB == 1.0) {
      // divide y by pi/2.0 to sync with sin() period in pixelgrid code in final pass.
      vR_offset=-(vec2(DECON_RX, DECON_RY) * vec2(NEW_SCALEMOD_X, NEW_SCALEMOD_Y) / global.upscale_passSize.xy) / vec2(pi/2.0);
      vG_offset=-(vec2(DECON_GX, DECON_GY) * vec2(NEW_SCALEMOD_X, NEW_SCALEMOD_Y) / global.upscale_passSize.xy) / vec2(pi/2.0);
      vB_offset=-(vec2(DECON_BX, DECON_BY) * vec2(NEW_SCALEMOD_X, NEW_SCALEMOD_Y) / global.upscale_passSize.xy) / vec2(pi/2.0);
   }   

   
   //Precalc some conditions:
   bool do_shadow = (DO_DOT_MATRIX == 1.0 && DOT_M_SHADOW_STR > 0.0);
   vDecon_or_JustShadow =  float(DO_SHIFT_RGB > 0.0 || do_shadow    );

   //https://www.sciencedirect.com/topics/computer-science/color-subcarrier
   //YIQ/YUV Ntsc/Pal bandwidths
   if (SAT_BLEED_PAL == 0.0)
      vCVBS_bandwidths = vec3(4.2, 1.5, 0.5); //NTSC
   else
      vCVBS_bandwidths = vec3(5.0, 1.3, 1.3); //PAL
   
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
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vR_offset;
layout(location = 2) in vec2 vG_offset;
layout(location = 3) in vec2 vB_offset;
layout(location = 4) in float vDo_shadow_mode;
layout(location = 5) in float vDecon_or_JustShadow;
layout(location = 6) in vec3 vCVBS_bandwidths;

layout(location = 9) in float vDotCrawlShift;
layout(location = 10) in vec4 vDotCrawlCoords_and_period;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 1) uniform sampler2D upscale_pass;


vec3 deconvergence_shadow(vec2 coords, sampler2D in_texture, vec3 source_pixel) {
      //Emulates deconvergence or shadowing for dot matrix screens like Gameboy.
      //Since both effects should not coexist in real life, we use a singe function for both.
      //The function stays more or less the same, but rgb offsets calculated in vertex shader
      //will be the same for shadow mode. Hopefully shader texture cache will take care of
      //multiple sampling for the same tex coords.
   
      vec3 pixel_offsetted;
      //Since we are sampling from a "clamp-to-border" texture, ensure we've no black bleeding
      //by clamping the texture coords
      //Removed, since shader chain changed, and this is now useless (?) WARNING <----
      //coords = clamp(coords,params.SourceSize.zw*1 ,1.0-params.SourceSize.zw);

      vec2 R_offset=vR_offset;
      vec2 G_offset=vG_offset;
      vec2 B_offset=vB_offset;

      if (DOT_M_SHADOW_STR == 0.0) {
         // Edge defocus:
         float dist_from_edge = distance_from_edge_linear(coords, EDGE_DEFOCUS_AREA_INV);
         float offset_multiplier = mix(EDGE_DEFOCUS, 1.0, dist_from_edge);
         R_offset *= offset_multiplier;
         G_offset *= offset_multiplier;
         B_offset *= offset_multiplier;
      }

      pixel_offsetted.r=texture(in_texture,coords + R_offset).r;
      pixel_offsetted.g=texture(in_texture,coords + G_offset).g;
      pixel_offsetted.b=texture(in_texture,coords + B_offset).b;
     
      vec3 deconvergence_mode = mix(source_pixel.rgb, pixel_offsetted, OFFSET_STRENGTH);
      vec3 shadow_mode = source_pixel.rgb - max( (source_pixel.rgb - pixel_offsetted), vec3(0.0) ) * DOT_M_SHADOW_STR;
     
      return mix_step(deconvergence_mode, shadow_mode, vDo_shadow_mode);
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

vec4 pixel_bleed(vec4 pixel_in, vec2 co, sampler2D in_texture, float sourcesize_z) { //FIXME pixelin.a è passante, non serve vec4
   //sometimes first frame has 0x0 size, that makes gpu mad in a way or another.
   //hopefully fixes: https://github.com/kokoko3k/koko-aio-slang/issues/28   
   if (sourcesize_z > 1.0) return pixel_in;
      
   mat3 colorspace_out;
   mat3 colorspace_rgb;

   //https://www.sciencedirect.com/topics/computer-science/color-subcarrier
   if (SAT_BLEED_PAL > 0.5) {
      colorspace_out = RGB2YUV;
      colorspace_rgb = YUV2RGB;
   } else {
      colorspace_out = RGB2YIQ;
      colorspace_rgb = YIQ2RGB;
   }
   
   #ifdef D3D_WORKAROUND
      // d3d11 compiler complains it is unable to unroll the loop because it is
      // clueless about the maximum pragma value; d3d12 hangs somewhere.
      float size = min(5.0,SAT_BLEED_SIZE) ;
   #else
      float size = min(20.0,SAT_BLEED_SIZE) ;
   #endif
   
   //Initial mix strength.
   float w = SAT_BLEED_STRENGTH;

   //Initial color in yiq space
   vec3 out_YIQ = colorspace_out * ( pixel_in.rgb );
   
   for ( float off = sourcesize_z ; off <= sourcesize_z*size ; off+=sourcesize_z ){
      //float new_offset = i*initial_offset;
      vec3 smp_YIQ  = colorspace_out * ( texture(in_texture, co - vec2(off,0.0) ).rgb) * 0.5; //sample left
           smp_YIQ += colorspace_out * ( texture(in_texture, co + vec2(off,0.0) ).rgb) * 0.5; //sample right

      //Blur Y,I,Q
      w=w/SAT_BLEED_FALLOFF;  //w = w * exp(i*i*(1-SAT_BLEED_FALLOFF)*0.1);
      //out_YIQ = mix(out_YIQ.xyz, smp_YIQ.xyz, w/vCVBS_bandwidths);
      out_YIQ = mix(out_YIQ.xyz,smp_YIQ.xyz, clamp(w/vCVBS_bandwidths, 0.0, 1.0));
     
   }
   vec3 pixel_bleeded = colorspace_rgb * ( out_YIQ ); //return to RGB colorspace

   // Clamping min to 0.0 is needed for nvidia to avoid bad graphical glitches, why?
   pixel_bleeded = clamp(pixel_bleeded, 0.0, 1.0);
   
   return vec4( pixel_bleeded, pixel_in.a);
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
   if (DO_SAT_BLEED > 0.5)
      pixel_out = pixel_bleed(pixel_out, vTexCoord, upscale_pass, params.OriginalSize.z*0.5);

   if (DOT_C > 0.0)
      pixel_out.rgb = dotc(upscale_pass, pixel_out.rgb, vTexCoord, params.OriginalSize);

   //... and shift
   if (vDecon_or_JustShadow > 0.0 )
      pixel_out.rgb = deconvergence_shadow(vTexCoord, upscale_pass, pixel_out.rgb);

   pixel_out.rgb = max(vec3(0.0), pixel_out.rgb);  //make sure everything is over 0.0

   pixel_out.rgb = pow(pixel_out.rgb, vec3(IN_GLOW_GAMMA)); //apply gamma in 
      
   FragColor = pixel_out;
}
