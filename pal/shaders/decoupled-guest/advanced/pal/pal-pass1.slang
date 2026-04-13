#version 450

//   Pal shader - pass 1
//   by guest.r

const mat3 rgb_yuv = mat3(
     0.29900,   0.58700,   0.11400,
    -0.14713,  -0.28886,   0.43600,
     0.61500,  -0.51499,  -0.10001);

vec3 rgb2yuv(vec3 rgb)
{
	return rgb * rgb_yuv;
}


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

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
layout(set = 0, binding = 3) uniform sampler2D PalPass1Feedback;

void main()
{
	vec3 ycolor = rgb2yuv(texture(Source, vTexCoord).rgb);
	vec4 pcolor = vec4(texture(PalPass1Feedback, vTexCoord));
	FragColor = vec4(ycolor.yz, pcolor.xy);
}