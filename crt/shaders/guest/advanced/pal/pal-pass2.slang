#version 450


//   Pal shader - pass 2
//   by guest.r
   

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BRIGHTNESS, SATURATION, ARTIFACTING, FRINGING, RFNOISE, RFNOISE1, RFNOISE2;
	float PHMOD, DLINE;
	float GCORR;
	float PAL_FILT;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter pal-row0    "[ PAL CONTROLS ]:"               0.0 0.0 0.0 1.00
#pragma parameter pal-row1    "-------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter PAL_FILT    "          PAL Connection: RF | Composite | S-Video | SCART " 2.00 1.00 4.00 1.00
#pragma parameter filter_res  "          Horizontal Filtering Resolution" 1.0 0.5 8.0 0.10
#pragma parameter auto_res    "          SNES/Amiga Hi-Res Auto Mode" 0.0 0.0 1.0 1.0
#pragma parameter PHMOD       "          PAL Phase: Auto | Progressive | Laced  " 0.0 0.0 2.0 1.0
#pragma parameter pal-row2    "-------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter ARTIFACTING "          PAL Artifacting Value   " 0.70 0.0 5.0 0.10
#pragma parameter FRINGING    "          PAL Fringing Value      " 0.70 0.0 5.0 0.10
#pragma parameter SATURATION  "          PAL Saturation Boost    " 1.05 0.0 2.0 0.01
#pragma parameter BRIGHTNESS  "          PAL Brightness          " 1.00 0.0 1.5 0.01
#pragma parameter CHROMAF     "          PAL UV Chroma Filter    " 2.00 1.0 2.0 1.00
#pragma parameter pal-row3    "-------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter DLINE       "          PAL Delay Line | Merge  " 2.00 0.0 6.0 1.00
#pragma parameter GCORR       "          PAL Y Gamma Correct     " 1.15 1.0 2.6 0.05
#pragma parameter pal-row4    "-------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter RFNOISE     "          PAL RF Noise Frequency  " 0.30 0.0 1.0 0.01
#pragma parameter RFNOISE1    "          PAL RF Noise Luma+      " 0.00 0.0 0.7 0.01
#pragma parameter RFNOISE2    "          PAL RF Noise Chroma+    " 0.00 0.0 0.7 0.01

#define ARTIFACTING params.ARTIFACTING
#define FRINGING    params.FRINGING
#define BRIGHTNESS  params.BRIGHTNESS
#define SATURATION  params.SATURATION
#define UVDESAT     params.UVDESAT
#define PHMOD       params.PHMOD
#define DLINE       params.DLINE


mat3 mmat = mat3(BRIGHTNESS, FRINGING, FRINGING, ARTIFACTING, 2.0*SATURATION, 0.0, ARTIFACTING, 0.0, 2.0*SATURATION);

const float CYCLES_PER_LINE = 4.43361875e6 / 15625.0;  //  283.3333 PAL UV cycles per line
const float PI = 3.14159265358979323846;

const mat3 rgb_yuv = mat3(
     0.29900,   0.58700,   0.11400,
    -0.14713,  -0.28886,   0.43600,
     0.61500,  -0.51499,  -0.10001);

vec3 rgb2yuv(vec3 rgb)
{
	return rgb * rgb_yuv;
}


float edge_cycles(int line, uint frameCount)
{
	float cycles = float(line) * (-0.25);
	if (PHMOD == 2.0 || (PHMOD == 0.0 && params.OriginalSize.y > 375.0)) cycles += float(frameCount & 7) * (-0.125);
	return cycles;
}


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
layout(set = 0, binding = 3) uniform sampler2D InterlacePass;

void main()
{
	vec3 rgb  = texture(InterlacePass, vTexCoord).rgb;	
	vec3 yuv = rgb2yuv(rgb);
	yuv.x = pow(max(yuv.x, 0.0), params.GCORR);
	vec3 res4 = yuv;
	
	float lum = yuv.x;
	vec3 yuvd = vec3(yuv.x, texture(Source, vTexCoord).zw);
	if (DLINE < 2.5) { yuvd = rgb2yuv(texture(InterlacePass, vTexCoord - vec2(0.0, params.OriginalSize.w)).rgb); yuvd.x = lum; }

	int line = int(floor(vTexCoord.y * params.OriginalSize.y));

	float xN = vTexCoord.x * CYCLES_PER_LINE;
	float cycles = xN + edge_cycles(line, params.FrameCount);
	float phase = 2.0 * PI * cycles;
	float linesign = (line%2 == 0) ? 1.0 : -1.0;

	vec2 uvmod = vec2(cos(phase), sin(phase*linesign));
	yuv.yz = yuv.yz * uvmod;
	yuv = yuv * mmat;
	yuv.yz = yuv.yz * uvmod;

if (DLINE > 0.5) // delay line code
{
	if (DLINE > 4.5) { uvmod = vec2(-uvmod.x, -uvmod.y); } else uvmod = vec2(uvmod.x, -uvmod.y);	
	yuvd.yz = yuvd.yz * uvmod;
	yuvd = yuvd * mmat;
	yuvd.yz = yuvd.yz * uvmod;
	if (DLINE == 2.0 || DLINE == 4.0 || DLINE == 6.0) yuv = mix(yuv, yuvd, 0.5); else yuv.x = mix(yuv.x, yuvd.x, 0.5);
}

	if (params.PAL_FILT == 4.0) yuv = res4;

	FragColor = vec4(yuv, lum);
}