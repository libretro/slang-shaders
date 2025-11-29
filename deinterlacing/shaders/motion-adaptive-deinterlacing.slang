#version 450

/*
   Motion Adaptive Deinterlacing
   Author: hunterk
   License: Public domain
   
   Note: This shader is designed to work with the typical woven output from
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
	float scale, mThresh, debug, modePicker, bff;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

// I wish there were some way to make this automatic...
#pragma parameter scale "Deinterlacing Scale" 1.0 1.0 16.0 1.0

#pragma parameter mThresh "Deinterlacing Motion Threshold" 0.15 0.0 1.0 0.01

float motionThreshold = params.mThresh;

#pragma parameter modePicker "Deinterlacing Mode (Blend vs Bob)" 0.0 0.0 1.0 1.0

#pragma parameter bff "Bob Field Alignment (TFF vs BFF)" 0.0 0.0 1.0 1.0

#pragma parameter debug "Show Motion Detection (debug)" 0.0 0.0 1.0 1.0

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float is_interlaced;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
   is_interlaced = float(params.OriginalSize.y > 400.0 * params.scale);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float is_interlaced;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D OriginalHistory1;

float colDiff(vec3 color1, vec3 color2) {
   vec3 diff = color1 - color2;
   float distanceSq = dot(diff, diff); 
   return sqrt(distanceSq);
}

void main()
{
   // go ahead and sample the texture and early return if not interlaced
   vec4 current = texture(Source, vTexCoord);
   FragColor = current;
   if(!bool(is_interlaced)) return;
   
   float scale = params.scale;
   vec2 halfTexel = vec2(0.0, 0.49999 * params.SourceSize.w * scale);
	
   // sample above and below the current texel
   vec4 halfUp = texture(Source, vTexCoord - halfTexel);
   vec4 halfDown = texture(Source, vTexCoord + halfTexel);
	
   vec4 weave = current;
   
   // use mix() instead of averaging so we don't need to worry about linearizing
   vec4 mixed = mix(halfUp, halfDown, 0.5);
	
   // check for combing by comparing current vs offset texel and compare their 
   // difference with the motion threshold
   float upVsDown = colDiff(halfUp.rgb, halfDown.rgb);
   float upVsCurr = colDiff(halfUp.rgb, current.rgb);
   float downVsCurr = colDiff(halfDown.rgb, current.rgb);
   bool isCombed = ((upVsCurr > motionThreshold) || (downVsCurr > motionThreshold)) && (upVsDown > motionThreshold);

   // if it's combed, mix it up; if not, pass it through
   vec4 blended = (isCombed) ? mixed : weave;
   
   vec2 uv = vTexCoord * params.SourceSize.xy - 0.5;
   uv = (floor(uv) + 0.5) * params.SourceSize.zw;
   float y = (params.SourceSize.y / scale) * uv.y + mod(float(params.FrameCount), 2.0) + params.bff;
   vec4 offset = texture(Source, uv + vec2(0.0, params.SourceSize.w * scale));
   vec4 bobbed = (mod(y, 2.0) > 0.99999) ? offset : texture(Source, uv);
   bobbed = mix(weave, bobbed, vec4(isCombed));
   
   FragColor = mix(blended, bobbed, params.modePicker);
   
   // display areas that trigger the combing detection
   FragColor = (params.debug > 0.5) ? vec4(isCombed) : FragColor;
}
