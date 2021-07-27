#version 450

layout(push_constant) uniform Push
{
	float GAMMA_INPUT;
} params;

#pragma parameter GAMMA_INPUT "Gamma Input" 2.4 0.5 5.0 0.05
#define GAMMA_INPUT params.GAMMA_INPUT

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

void main()
{
	float ratio = texture(Source, vec2(0.5,0.1)).a;
	if (vTexCoord.y > ratio) discard;   
	float gamma = 2.4;
	if ( (GAMMA_INPUT > 0.4) || (GAMMA_INPUT < 4.1) ) gamma = GAMMA_INPUT;
	gamma = 1.0/gamma;
	
	FragColor = vec4(pow(vec3(texture(Source, vTexCoord).rgb), vec3(GAMMA_INPUT)),gamma);
}