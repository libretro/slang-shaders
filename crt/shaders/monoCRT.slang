#version 450

// colEG
// by hunterk
// license: public domain

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	uint CurrentSubFrame;
	uint TotalSubFrames;
	float scanMax, horzSharp, brightBoost, gammaIn, gammaOut,
		noiseFactor, monoColParam, maskPicker;
} params;

#pragma parameter brightBoost "BrightBoost" 1.0 1.0 29.0 1.0
#define brightBoost params.brightBoost
#pragma parameter scanMax "Scanline Max (should be very high for mono input)" 2.2 1.0 10.0 0.1
#define scanMax params.scanMax
#pragma parameter horzSharp "Horizontal Sharpening" 2.0 1.0 11.0 1.0
int horzSharp = int(params.horzSharp);
#pragma parameter gammaIn "Input Gamma" 2.2 0.1 5.0 0.01
#define gammaIn params.gammaIn
#pragma parameter gammaOut "Output Gamma" 2.2 0.1 5.0 0.01
#define gammaOut params.gammaOut
#define noiseFactor 5.0
#pragma parameter monoColParam "Monochrome Palette" 0.0 0.0 4.0 1.0
#define monoColParam params.monoColParam

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec3 monoCol;
layout(location = 2) out vec2 scale;

// palettes
const vec3 amber1 = vec3(0.97647058, 0.51372549, 0.0);
const vec3 amber2 = vec3(0.98039215, 0.60784313, 0.41176470);
const vec3 green1 = vec3(0.44705882, 0.933333, 0.00784313);
const vec3 green2 = vec3(0.0, 0.933333, 0.41176470);

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord + vec2(0.01,0.); // not sure why it gets scootched, but this compensates
   int monoColSel = int(monoColParam);
   if(monoColSel == 1) monoCol = amber1;
   else if(monoColSel == 2) monoCol = amber2;
   else if(monoColSel == 3) monoCol = green1;
   else if(monoColSel == 4) monoCol = green2;
   else monoCol = vec3(1.,1.,1.);
   scale = params.OutputSize.xy * params.SourceSize.zw;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec3 monoCol;
layout(location = 2) in vec2 scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float rand(vec2 n) { 
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p){
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u*u*(3.0-2.0*u);
	
	float res = mix(
		mix(rand(ip),rand(ip+vec2(1.0,0.0)),u.x),
		mix(rand(ip+vec2(0.0,1.0)),rand(ip+vec2(1.0,1.0)),u.x),u.y);
	return res*res;
}

vec3 envelopeRMS(sampler2D tex, vec2 uv, float rowUV)
{
    vec3 sum = vec3(0.0);
    int samples = 0;

    for (int i = -16; i <= 16; i++)
    {
        if (samples >= (int(scale.y)*3 - 1) / horzSharp) break; // silly calculation but it scales well

        float offset = float(i) * params.OutputSize.z;
        vec3 s = pow(texture(tex, vec2(uv.x + offset, rowUV)).rgb, vec3(gammaIn));
		s = vec3(dot(s, vec3(0.299, 0.587, 0.114))); //force mono

        sum += s;
        samples++;
    }

    return pow((sum / float(samples)), vec3(1./gammaOut));
}

void main()
{
   vec2 uv = vTexCoord.xy;
   float uRows = params.SourceSize.y;
   // determine which signal row we belong to
   float row = floor(uv.y * uRows);
   
   // calculate beam perturbations
   vec2 uvOff = vec2(0.0);
   float timer = float(params.FrameCount * params.TotalSubFrames + params.CurrentSubFrame);
   uvOff.x = noise(sin(uv*params.OutputSize.xy * vTexCoord) * mod(timer + 773, 3061.));
   uvOff.y = noise(cos(uv*params.OutputSize.xy * vTexCoord) * mod(timer + 967, 5673.));
   uvOff *= (noiseFactor / (10000.));
   
   float rowUV = (row + 0.5) / uRows;

   float baseY = (row + 0.5) / uRows;

   // compute local envelope
   vec3 env = envelopeRMS(Source, uv, rowUV);

   env *= scanMax + clamp(params.TotalSubFrames, 0.0, 1.0); // give a small brightness boost if we're doing subframe effects

   float amp = 0.6 / uRows;

   vec3 height = env * amp;

   float yDist = abs(uv.y - baseY + uvOff.y);

   float edge = (30. - brightBoost) / 10000.;

   float r = smoothstep(height.r * 0.5, height.r * 0.5 - edge, yDist);
   float g = smoothstep(height.g * 0.5, height.g * 0.5 - edge, yDist);
   float b = smoothstep(height.b * 0.5, height.b * 0.5 - edge, yDist);
   
   vec3 col = vec3(r,g,b);
   
   // apply the palette
   col *= monoCol;
   FragColor = vec4(col, 1.0);
}