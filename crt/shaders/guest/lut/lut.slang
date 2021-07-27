#version 450

layout(push_constant) uniform Push
{
   vec4 SourceSize;
   vec4 OriginalSize;
   vec4 OutputSize;
   uint FrameCount;
   float TNTC;
} params;

#pragma parameter TNTC "LUT Colors" 0.0 0.0 3.0 1.0
#define TNTC params.TNTC

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D SamplerLUT1;
layout(set = 0, binding = 4) uniform sampler2D SamplerLUT2;
layout(set = 0, binding = 5) uniform sampler2D SamplerLUT3;

#define LUT_Size 32.0
#define COMPAT_TEXTURE(c,d) texture(c,d)

const mat3 D65_to_XYZ = mat3 (
           0.4306190,  0.2220379,  0.0201853,
           0.3415419,  0.7066384,  0.1295504,
           0.1783091,  0.0713236,  0.9390944);
 
const mat3 XYZ_to_D50 = mat3 (
           2.9603944, -0.9787684,  0.0844874,
          -1.4678519,  1.9161415, -0.2545973,
          -0.4685105,  0.0334540,  1.4216174);


// This shouldn't be necessary but it seems some undefined values can
// creep in and each GPU vendor handles that differently. This keeps
// all values within a safe range
vec4 mixfix(vec4 a, vec4 b, float c)
{
	return (a.z < 1.0) ? mix(a, b, c) : a;
}

void main()
{
   vec4 imgColor = COMPAT_TEXTURE(Source, vTexCoord.xy);
   if (int(TNTC) == 0)
   {
      FragColor = imgColor;
      return;
   }
   else
   {
      float red = ( imgColor.r * (LUT_Size - 1.0) + 0.499999 ) / (LUT_Size * LUT_Size);
      float green = ( imgColor.g * (LUT_Size - 1.0) + 0.499999 ) / LUT_Size;
      float blue1 = (floor( imgColor.b  * (LUT_Size - 1.0) ) / LUT_Size) + red;
      float blue2 = (ceil( imgColor.b  * (LUT_Size - 1.0) ) / LUT_Size) + red;
      float mixer = clamp(max((imgColor.b - blue1) / (blue2 - blue1), 0.0), 0.0, 32.0);
      vec4 color1, color2, res;
      if (int(TNTC) == 1)
      {
         color1 = COMPAT_TEXTURE( SamplerLUT1, vec2( blue1, green ));
         color2 = COMPAT_TEXTURE( SamplerLUT1, vec2( blue2, green ));
         res = mixfix(color1, color2, mixer);
         float mx = max(res.r,max(res.g,res.b));
         float l = mix(length(imgColor.rgb), length(res.rgb), max(mx-0.5,0.0));
         res.rgb = mix(imgColor.rgb, res.rgb, clamp(25.0*(mx-0.02),0.0,1.0));
         res.rgb = normalize(res.rgb+1e-10)*l;
         vec3 cooler = D65_to_XYZ*res.rgb;
         cooler = XYZ_to_D50*cooler;
         res.rgb = mix(res.rgb, cooler, 0.25);
      }
      else if (int(TNTC) == 2)
      {
         color1 = COMPAT_TEXTURE( SamplerLUT2, vec2( blue1, green ));
         color2 = COMPAT_TEXTURE( SamplerLUT2, vec2( blue2, green ));
         res = mixfix(color1, color2, mixer);
         float l = mix(length(imgColor.rgb), length(res.rgb), 0.4);
         res.rgb = normalize(res.rgb + 1e-10)*l;
      }	
      else if (int(TNTC) == 3)
      {
         color1 = COMPAT_TEXTURE( SamplerLUT3, vec2( blue1, green ));
         color2 = COMPAT_TEXTURE( SamplerLUT3, vec2( blue2, green ));
         res = mixfix(color1, color2, mixer);
         res.rgb = pow(res.rgb, vec3(1.0/1.20));
         float mx = max(res.r,max(res.g,res.b));
         res.rgb = mix(imgColor.rgb, res.rgb, clamp(25.0*(mx-0.05),0.0,1.0));		
         float l = length(imgColor.rgb);
         res.rgb = normalize(res.rgb + 1e-10)*l;
      }	
      
      FragColor = vec4(mix(imgColor.rgb, res.rgb, min(TNTC,1.0)),1.0);
   }
}
