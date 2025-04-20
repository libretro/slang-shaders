#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float anaglyph_selector, eye_swap;
} params;

#pragma parameter anaglyph_selector "Anaglyph Mode" 0.0 0.0 2.0 1.0
#pragma parameter eye_swap "Swap Eyes" 0.0 0.0 1.0 1.0

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
   vec3 img = texture(Source, vTexCoord).rgb;
   vec3 frame1, frame2;
   
   if (params.anaglyph_selector == 0.0){ //red/blue and red/cyan
	   frame1.rgb = vec3(img.r);
	   frame2.rgb = vec3(max(img.g, img.b));
	}
   else if (params.anaglyph_selector == 1.0){ //red/green and green/magenta
	   frame1.rgb = vec3(max(img.r, img.b));
	   frame2.rgb = vec3(img.g);
	}
   else { //yellow and blue
	   frame1.rgb = vec3(max(img.r, img.g));
	   frame2.rgb = vec3(img.b);
	}
	
	bool oscillator = bool(mod(floor(vTexCoord.y * params.OutputSize.y), 2.0));
	vec3 comb = (oscillator) ? frame1 : frame2;
   FragColor = vec4(comb, 1.0);
}
