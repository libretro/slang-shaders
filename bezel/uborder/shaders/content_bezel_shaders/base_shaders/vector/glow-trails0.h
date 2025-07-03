
layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float mixfactor0;
	float threshold;
} params;

#pragma parameter GT_NONONO            "GLOW-TRAILS:"                     0.0  0.0   1.0 1.0
#pragma parameter mixfactor0           "    Motionblur Fadeout" 0.5 0.0 1.0 0.01
#pragma parameter threshold            "    Brightness Threshold" 0.9 0.0 1.0 0.01

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

const vec3 Y = vec3( 0.299,  0.587,  0.114);

float lum(vec3 color)
{
  return dot(color, Y);
}


float key(float avg)
{
	float guess = 1.5 - (1.5 / (avg * 0.1 + 1.0));
	return max(0.0, guess) + 0.1;
}

mat3 yiq2rgb_mat = mat3(
   1.0, 1.0, 1.0,
   0.956, -0.2720, -1.1060,
   0.6210, -0.6474, 1.7046
);

mat3 yiq_mat = mat3(
      0.2989, 0.5959, 0.2115,
      0.5870, -0.2744, -0.5229,
      0.1140, -0.3216, 0.3114
);

#ifdef USE_AMBIENT_LIGHT
    #define Pfeedback PassFeedback4
#else
    #define Pfeedback PassFeedback1
#endif



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
#ifdef USE_AMBIENT_LIGHT
    layout(set = 0, binding = 3) uniform sampler2D PassFeedback4;
#else
    layout(set = 0, binding = 3) uniform sampler2D PassFeedback1;
#endif
void main()
{
	vec3 frame   = texture(Source, vTexCoord).rgb;
//	float luma   = (frame.rrr * yiq_mat).r;
	float luma   = lum(frame);
    float trails = clamp(luma - params.threshold, 0.0, 1.0);
    vec4 fdback  = pow(texture(Pfeedback, vTexCoord), vec4(2.2));
    vec4 mixed   = clamp((1.0 - params.mixfactor0) * vec4(trails) - params.mixfactor0 * fdback, 0.0, 1.0) + params.mixfactor0 * fdback;
//	vec4 current = pow(texture(Source, vTexCoord), vec4(2.2));
    
    FragColor = pow(mixed, vec4(1.0 / 2.2));
}
