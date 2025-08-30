#version 450

/*
   Bob-Deinterlacing
   Author: hunterk
   License: Public domain
   
   Note: This shader is designed to work with the typical interlaced output from
   an emulator, which displays both even and odd fields twice.
   
   As such, it is inappropriate for general video use unless the video has
   already been similarly woven beforehand.
*/

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
layout(location = 1) out float is_interlaced;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
   is_interlaced = float(params.OriginalSize.y > 400.0);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float is_interlaced;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D OriginalHistory1;

void main()
{
   // snap to the center of the underlying texel
   vec2 uv = vTexCoord * params.SourceSize.xy - 0.5;
   uv = (floor(uv) + 0.5) * params.SourceSize.zw;
   
   // go ahead and sample the texture and early return if not interlaced
	vec4 current = texture(Source, uv);
	FragColor = current;
	if(!bool(is_interlaced)) return;

	// work our way down the vertical axis and skip up 1 pixel every other frame
	float y = (params.SourceSize.y) * uv.y + mod(float(params.FrameCount), 2.0);
	
	// deinterlace the current frame
	vec4 offset = texture(Source, uv + vec2(0.0, params.SourceSize.w));
	vec4 deint_current = (mod(y, 2.0) > 0.99999) ? offset : current;
	
	FragColor = deint_current;
}
