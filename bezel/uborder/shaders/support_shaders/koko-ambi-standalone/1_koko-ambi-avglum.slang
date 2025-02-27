#version 450

// Released under: See LICENSE.txt

#define leds_per_strip 8

layout(push_constant) uniform Push {
	mat4 MVP;
	vec4 SourceSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float lod;

void main() {
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord;
	
	//Calc a lod for a texture sized led_strip x led_strip
		lod = log2(params.SourceSize.y / leds_per_strip);

}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float lod;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D avglum_passFeedback;


/* The following will allow to sample at reduced interval
   The scene change detection logic will take advantage of it
   So that quick fades will still be treated as scene changes
*/
#define AMBI_AVGLUM_DIVIDER 4

float get_avg_lum_from_mip() {
    vec3 mip = textureLod(Source, vec2(0.5,0.5),20.0).rgb;
    return dot(mip, vec3(1/3.0));
}

float get_avglum() {
	//Only update at right time; else return the previous frame.
		bool reduced_sample_time_is_now = (mod(params.FrameCount,AMBI_AVGLUM_DIVIDER) == 0);
		if (reduced_sample_time_is_now)
			return get_avg_lum_from_mip();
	
	float avglum_feedback = texture(avglum_passFeedback,vTexCoord).a;
	avglum_feedback = max(avglum_feedback, 0.0); // <- Sanitize input to avoid glitches when enabling the option runtime.
	return avglum_feedback;
}

void main() {
	vec4 pixel_out ; 
	FragColor = vec4( textureLod(Source, vTexCoord, lod).rgb, get_avglum() );
}
 
  
