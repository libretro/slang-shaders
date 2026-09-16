#ifndef NNEDI3_PREV_TEXTURE
#error NNEDI3_PREV_TEXTURE must name the previous source sampler
#endif

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

void main (void) {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D NNEDI3_PREV_TEXTURE;

void main()
{
	ivec2 src_size = ivec2(params.SourceSize.xy);
	ivec2 out_size = ivec2(params.OutputSize.xy);
	ivec2 op = clamp(ivec2(floor(vTexCoord.xy * params.OutputSize.xy)), ivec2(0), out_size - ivec2(1));

#if NNEDI3_VERTICAL
	ivec2 base = clamp(ivec2(op.x, op.y >> 1), ivec2(0), src_size - ivec2(1));
	bool copy_source = (op.y & 1) == 0;
#else
	ivec2 base = clamp(ivec2(op.x >> 1, op.y), ivec2(0), src_size - ivec2(1));
	bool copy_source = (op.x & 1) == 0;
#endif

	FragColor = copy_source
		? texelFetch(NNEDI3_PREV_TEXTURE, base, 0)
		: texelFetch(Source, base, 0);
}
