#version 450

layout(push_constant) uniform Push
{
  vec4 SourceSize;
  vec4 OriginalSize;
  vec4 OutputSize;
  uint FrameCount;

} params;

#define _ 0.0
#define o (1./3.)
#define b (2./3.)
#define B 1.0

#define color_enhance 1.0
#define SourceSize params.SourceSize

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
   vTexCoord = TexCoord*1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


// Color lookup table (RGBI palette with brown fix)
const vec3 rgbi_palette[19] = 
{
  vec3(_, _, _),
  vec3(_, _, b),
  vec3(_, b, _),
  vec3(_, b, _),
  vec3(_, b, _),
  vec3(_, b, _),
  vec3(_, b, b),
  vec3(b, _, _),
  vec3(b, _, b),
  vec3(b, o, _),
  vec3(b, b, b),
  vec3(o, o, o),
  vec3(o, o, B),
  vec3(o, B, o),
  vec3(o, B, B),
  vec3(B, o, o),
  vec3(B, o, B),
  vec3(B, B, o),
  vec3(B, B, B),
};


// Came off the wikipedia(R) article for Ordered_Dithering
const int dithertable[16] = 
{
	 1, 9, 3,11,
	13, 5,15, 7,
	 4,12, 2,10,
  16, 8,14, 6,
};


// Compare vector distances and return nearest RGBI color
vec3 nearest_rgbi (vec3 original) 
{
  float dst;
  float min_dst = 2.0;
  int idx = 0;
  for (int i=0; i<19; i++) 
  {
    dst = distance(original, rgbi_palette[i]);
    if (dst < min_dst) 
     {
      min_dst = dst;
      idx = i;
     }
  }
  return rgbi_palette[idx];
}


float modu(float x, float y)
{
	return x - y * floor(x/y);
}

//fragment
void main()
{
  vec3 color = texture(Source, vTexCoord.xy).rgb;

	// leilei - dither 
	vec2 res;
	vec2 tex=vTexCoord.xy;
	res.x = SourceSize.x; 

	if (SourceSize.y < 900.0)
		res.y = SourceSize.y; 
	   else
	     res.y = SourceSize.y / 2.0; 

	int ohyes;
  int i;
  vec2 ditheu = tex.xy * res.xy;

  int ditdex =  int(modu(ditheu.x, 4))*4 + int(modu(ditheu.y, 4)); // 4x4!

  // looping through a lookup table matrix
  
  for (i = ditdex; i < (ditdex+16); i = i+1) 
      ohyes = dithertable[i-15] * 2 - 21;
      ohyes = ohyes - 6;
      
      color *= 255.0;
      color += ohyes;
      color /= 255.0;
  FragColor = vec4(nearest_rgbi(color*color_enhance), 1.0);
}
