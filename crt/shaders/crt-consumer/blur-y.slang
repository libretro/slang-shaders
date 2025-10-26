#version 450
#pragma parameter u_gamma "Gamma" 1.2 1.0 2.0 0.05

layout(push_constant) uniform Push
{
float u_gamma;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} global;

#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
#define OutputSize global.OutputSize
#define FrameCount global.FrameCount
#define u_gamma params.u_gamma

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

#define psy vec2(0.0,SourceSize.w)
#define one 1.384615
#define two 3.230769
#define w0  0.227027
#define w1  0.316216
#define w2  0.070270 

void main()
{

/*
  use hardware hack for 9-tap blur using linear and 5 passes, see:
  https://www.rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
*/

vec3 res0 = texture(Source,vTexCoord).rgb*w0;
     res0 += texture(Source,vTexCoord+psy*one).rgb*w1;
     res0 += texture(Source,vTexCoord-psy*one).rgb*w1;
     res0 += texture(Source,vTexCoord-psy*two).rgb*w2;
     res0 += texture(Source,vTexCoord+psy*two).rgb*w2;
 
FragColor.rgb = res0;    
}