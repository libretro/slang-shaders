#version 450

// motionblur test
// by hunterk
// license: public domain

layout(push_constant) uniform Push
{
   vec4 SourceSize;
   vec4 OriginalSize;
   vec4 OutputSize;
   uint FrameCount;
   uint TotalSubFrames;
   uint CurrentSubFrame;
   vec4 FinalViewportSize;
   float inv_speed;
   float OriginalAspect;
} params;

#pragma parameter inv_speed "Invader Speed" 1.0 1.0 20.0 1.0
float speed = params.FrameCount * params.inv_speed;


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 noSubCoord;
layout(location = 2) out vec2 fullSubCoord;
layout(location = 3) out vec2 halfSubCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   noSubCoord = vec2(vTexCoord.xy * params.OutputSize.xy) - ivec2(mod(speed * params.TotalSubFrames, params.OutputSize.x),100);
   fullSubCoord = vec2(vTexCoord.xy * params.OutputSize.xy) - ivec2(mod(speed * params.TotalSubFrames + params.CurrentSubFrame - 1., params.OutputSize.x),400);
   halfSubCoord = vec2(vTexCoord.xy * params.OutputSize.xy) - ivec2(mod(speed * params.TotalSubFrames + int((params.CurrentSubFrame - 1.) / 2.), params.OutputSize.x),250);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 noSubCoord;
layout(location = 2) in vec2 fullSubCoord;
layout(location = 3) in vec2 halfSubCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D base;
layout(set = 0, binding = 4) uniform sampler2D twoSub;
layout(set = 0, binding = 5) uniform sampler2D threeSub;
layout(set = 0, binding = 6) uniform sampler2D fourSub;

void main()
{
	FragColor = texture(Source, vTexCoord);
	if(params.TotalSubFrames == 2)
	{
		FragColor = vec4(0.0);
		vec4 invader60 = texelFetch(base, ivec2(noSubCoord), 0);
		FragColor = mix(FragColor, invader60, invader60.a);
		vec4 invader120 = texelFetch(twoSub, ivec2(fullSubCoord), 0);
		FragColor = mix(FragColor, invader120, invader120.a);
	}
	else if(params.TotalSubFrames == 3)
	{
		FragColor = vec4(0.0);
		vec4 invader60 = texelFetch(base, ivec2(noSubCoord), 0);
		FragColor = mix(FragColor, invader60, invader60.a);
		vec4 invader180 = texelFetch(threeSub, ivec2(fullSubCoord), 0);
		FragColor = mix(FragColor, invader180, invader180.a);
	}
	else if(params.TotalSubFrames == 4)
	{
		FragColor = vec4(0.0);
		vec4 invader60 = texelFetch(base, ivec2(noSubCoord), 0);
		FragColor = mix(FragColor, invader60, invader60.a);
		vec4 invader120 = texelFetch(twoSub, ivec2(halfSubCoord), 0);
		FragColor = mix(FragColor, invader120, invader120.a);
		vec4 invader240 = texelFetch(fourSub, ivec2(fullSubCoord), 0);
		FragColor = mix(FragColor, invader240, invader240.a);
	}
	else return;
}
