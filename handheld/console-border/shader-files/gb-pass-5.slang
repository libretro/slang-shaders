#version 450

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 SourceSize;
	float SCALE;
	float OUT_X;
	float OUT_Y;
} params;

#pragma parameter SCALE "Box Scale" 0.6667 0.6667 1.5 0.33333
#pragma parameter OUT_X "Out X" 1600.0 1600.0 4800.0 8000.0
#pragma parameter OUT_Y "Out Y" 800.0 800.0 2400.0 400.0

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 tex_border;

void main()
{
	gl_Position	=	global.MVP * Position;
	vec2 scale	=	(params.OutputSize.xy * params.SourceSize.zw) / params.SCALE;
	vec2 middle	=	vec2(0.5, 0.5);
	vec2 diff	=	TexCoord.xy - middle;
	vTexCoord	=	middle + diff * scale;

	middle		=	vec2(0.5, 0.5);
	vec2 dist	=	TexCoord - middle;
	tex_border	=	middle + dist * params.OutputSize.xy / vec2(params.OUT_X, params.OUT_Y);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 tex_border;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;

void main()
{
	vec4 frame	=	texture(Source, vTexCoord).rgba;
	vec4 border	=	texture(BORDER, tex_border).rgba;
	FragColor	=	vec4(mix(frame, border, border.a));
}
