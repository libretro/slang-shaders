#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;


#define COMPAT_TEXTURE(c,d) texture(c,d)
#define TEX0 vTexCoord

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
   vTexCoord = TexCoord * 1.00001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float Overscan(float pos, float dy){
	pos=pos*2.0-1.0;    
	pos*=dy;
	return pos*0.5+0.5;
}

void main()
{
	float sm_tate = COMPAT_TEXTURE(Source, vec2(0.5)).a;
	float ratio = 1.0;
	vec2 tex = TEX0.xy; vec3 color = vec3(0.0);
	
	if (sm_tate < 0.5) { ratio = 1.0/3.0; tex.y = tex.y / ratio; color = COMPAT_TEXTURE(Source, tex).rgb; }
	else
	{
		ratio = (1.0/3.0) * params.SourceSize.x / params.SourceSize.y;
		tex = tex.yx;
		tex.x = tex.x / ratio;
		tex.y = Overscan(tex.y, params.SourceSize.x / params.SourceSize.y);
		color = COMPAT_TEXTURE(Source, tex).rgb;		
	}
	
	FragColor = vec4(color,ratio);
}