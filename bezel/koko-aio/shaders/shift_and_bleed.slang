#version 450
#include "config.inc"

#define RGB_SHIFT_RANGE 20

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 r_offset;
layout(location = 2) out vec2 g_offset;
layout(location = 3) out vec2 b_offset;

#include "includes/functions.include.slang"

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord ;  
   if (DO_SHIFT_RGB == 1.0) {
      r_offset=offsets_from_float(SHIFT_R+210.0,RGB_SHIFT_RANGE);
      g_offset=offsets_from_float(SHIFT_G+210.0,RGB_SHIFT_RANGE);
      b_offset=offsets_from_float(SHIFT_B+210.0,RGB_SHIFT_RANGE);
   }
}


#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 r_offset;
layout(location = 2) in vec2 g_offset;
layout(location = 3) in vec2 b_offset;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 3) uniform sampler2D FXAA_pass;
layout(set = 0, binding = 4) uniform sampler2D first_pass;

vec3 hsv2rgb(vec3 c){
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb2hsv(vec3 c){
   vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
   vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
   vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

   float d = q.x - min(q.w, q.y);
   float e = 1.0e-10;
   return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

#define bandwidth_mhz_Y_ntsc 4.2
#define bandwidth_mhz_I 1.5
#define bandwidth_mhz_Q 0.5

const mat3 mat3_RGB2YIQ = mat3(
   0.2989,  0.5959,  0.2115,
   0.5870, -0.2744, -0.5229,
   0.1140, -0.3216,  0.3114);
      
const mat3 mat3_YIQ2RGB = mat3(
   1.0,     1.0,     1.0,
   0.956,  -0.2720, -1.1060,
   0.6210, -0.6474,  1.7046);

//https://www.sciencedirect.com/topics/computer-science/color-subcarrier
#define bandwidth_mhz_Y_pal 5.0
#define bandwidth_mhz_U 1.3
#define bandwidth_mhz_V 1.3

const mat3 mat3_RGB2YUV = mat3(
   0.299,     0.587,     0.114,
   -0.14713, -0.28886,   0.436,
   0.615,    -0.514991, -0.10001);

const mat3 mat3_YUV2RGB = mat3(
   1.000, 0.000,   1.13983,
   1.000,-0.39465,-0.58060,
   1.000, 2.03211, 0.00000);



vec3 pixel_offset(vec3 pixel_cur,vec2 coord, sampler2D in_texture, vec4 sourcesize2) {
      vec2 d = -vec2(sourcesize2.z, sourcesize2.w)*0.5;
      vec3 pixel_offset;
      pixel_offset.r=texture(in_texture,coord + r_offset * d).r;
      pixel_offset.g=texture(in_texture,coord + g_offset * d).g;
      pixel_offset.b=texture(in_texture,coord + b_offset * d).b;
      //return mix(pixel_cur,pixel_offset,OFFSET_STRENGTH);
      vec3 color_difformity = vec3(pixel_offset.r-pixel_cur.r, +pixel_offset.g-pixel_cur.g, pixel_offset.b - pixel_cur.b);
      vec3 pixel_offset_to_add = pixel_offset * color_difformity;
      return pixel_cur + (pixel_offset_to_add *OFFSET_STRENGTH);
      //return pixel_cur + (pixel_offset *OFFSET_STRENGTH*color_difformity);
}


vec3 pixel_offset_wrap (vec2 coord) {
   vec3 pixel_in;
   if ( DO_FXAA == 1.0)  {
      pixel_in = texture(FXAA_pass, vTexCoord).rgb;
      return pixel_offset(pixel_in, vTexCoord, FXAA_pass, global.FXAA_passSize);
   } else {
      pixel_in = texture(first_pass, vTexCoord).rgb;
      return pixel_offset(pixel_in, vTexCoord, first_pass, global.first_passSize);
   }
}



vec3 pixel_bleed_side_NTSC(vec3 pixel_in, vec2 co, float size, float side, sampler2D in_texture, vec4 sourcesize2) {
   float w = SAT_BLEED_STRENGTH;
   vec3 blur_YIQ = pixel_in * mat3_RGB2YIQ;    //Work in YIQ space
   float i = 0.0;
   for ( i=1 ; i <= size ; i++ ){
      w=w/SAT_BLEED_FALLOFF;
      //w=clamp(w,0.0,1.0);
      vec3 smp_YIQ = texture(first_pass, co - side * vec2(sourcesize2.z*i,0.0)).rgb * mat3_RGB2YIQ;
      blur_YIQ.x = mix(blur_YIQ.x, smp_YIQ.x, w/bandwidth_mhz_Y_ntsc);   // Blur Y
      blur_YIQ.y = mix(blur_YIQ.y, smp_YIQ.y, w/bandwidth_mhz_I     );   // Blur I
      blur_YIQ.z = mix(blur_YIQ.z, smp_YIQ.z, w/bandwidth_mhz_Q     );   //  BlurQ
   }
   //blur_YIQ.z/=i;
   return vec3(blur_YIQ.x, blur_YIQ.y, blur_YIQ.z) * mat3_YIQ2RGB; //return to RGB colorspace
}
vec3 pixel_bleed_side_PAL(vec3 pixel_in, vec2 co, float size, float side, sampler2D in_texture, vec4 sourcesize2) {
   float w = SAT_BLEED_STRENGTH;
   vec3 blur_YUV = pixel_in * mat3_RGB2YUV;    //Work in YIQ space
   float i = 0.0;
   for ( i=1 ; i <= size ; i++ ){
      w=w/SAT_BLEED_FALLOFF;
      //w=clamp(w,0.0,1.0);
      vec3 smp_YUV = texture(first_pass, co - side * vec2(sourcesize2.z*i,0.0)).rgb * mat3_RGB2YUV;
      blur_YUV.x = mix(blur_YUV.x, smp_YUV.x, w/bandwidth_mhz_Y_pal);    // Blur Y
      blur_YUV.y = mix(blur_YUV.y, smp_YUV.y, w/bandwidth_mhz_U     );   // Blur U
      blur_YUV.z = mix(blur_YUV.z, smp_YUV.z, w/bandwidth_mhz_V     );   // Blur V
   }
   return vec3(blur_YUV.x, blur_YUV.y, blur_YUV.z) * mat3_YUV2RGB; //return to RGB colorspace
}

#define SIDE_RIGHT 1
#define SIDE_LEFT -1


vec3 pixel_bleed(vec3 pixel_in, vec2 co, sampler2D in_texture, vec4 sourcesize2) {
   vec3 side_left ; vec3 side_right;
   if (SAT_BLEED_PAL == 1.0) {
      side_right = pixel_bleed_side_PAL(pixel_in, co, SAT_BLEED_SIZE_RIGHT, SIDE_RIGHT, in_texture, sourcesize2);
      side_left = pixel_bleed_side_PAL(pixel_in, co, SAT_BLEED_SIZE_LEFT, SIDE_LEFT, in_texture, sourcesize2);
   } else {
      side_right = pixel_bleed_side_NTSC(pixel_in, co, SAT_BLEED_SIZE_RIGHT, SIDE_RIGHT, in_texture, sourcesize2);
      side_left = pixel_bleed_side_NTSC(pixel_in, co, SAT_BLEED_SIZE_LEFT, SIDE_LEFT, in_texture, sourcesize2);
   }
   return mix(side_left,side_right,0.5);

}
void main() {
   if (DO_SHIFT_RGB + DO_SAT_BLEED == 0.0) return;
   
   //Handle case where both are needed:
   //First shift the right source, then pass it to bleed function.
   if (DO_SHIFT_RGB + DO_SAT_BLEED > 1.0) {
      vec3 pixel_out = pixel_offset_wrap(vTexCoord);
      if (DO_SAT_BLEED > 0.0) {      
         if ( DO_FXAA == 1.0)  {
            pixel_out = pixel_bleed(pixel_out, vTexCoord, FXAA_pass, global.FXAA_passSize);
         } else {
            pixel_out = pixel_bleed(pixel_out, vTexCoord, first_pass, global.first_passSize);
         }
      }
      FragColor = vec4(pixel_out,0.0);
      return;
   }
   
   //Handle case where only color shifting is requested
   if (DO_SHIFT_RGB > 0.0) {
      vec3 pixel_out = pixel_offset_wrap(vTexCoord);
      FragColor = vec4(pixel_out,0.0);
      return;
   }
   
   //Handle case where only chroma bleed is requested
   if (DO_SAT_BLEED > 0.0) {      
      vec3 pixel_out;
      if ( DO_FXAA == 1.0)  {
         pixel_out = texture(FXAA_pass, vTexCoord).rgb;
         pixel_out = pixel_bleed(pixel_out, vTexCoord, FXAA_pass, global.FXAA_passSize);
      } else {
         pixel_out = texture(first_pass, vTexCoord).rgb;
         pixel_out = pixel_bleed(pixel_out, vTexCoord, first_pass, global.first_passSize);
      }
      FragColor = vec4(pixel_out,0.0);
      return;
   }
   

}
