#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float cropOverscan_x;
	float signalResolutionY;
	float signalResolutionI;
	float signalResolutionQ;
} params;

#pragma parameter cropOverscan_x "Crop Overscan X" 0.0 0.0 1.0 1.0
#pragma parameter signalResolutionY "Signal Res Y" 200.0 20.0 500.0 10.0
#pragma parameter signalResolutionI "Signal Res I" 125.0 20.0 350.0 10.0
#pragma parameter signalResolutionQ "Signal Res Q" 125.0 20.0 350.0 10.0

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

////////////////////////////////////////////////////////
//	GTU-famicom version 0.50
//	Author: aliaspider - aliaspider@gmail.com
//	License: GPLv3
////////////////////////////////////////////////////////

#define YIQ_to_RGB 	mat3x3( 1.0   , 1.0      , 1.0      ,	0.9563   , -0.2721   , -1.1070   ,		0.6210   , -0.6474   , 1.7046   )
#define pi			3.14159265358
#define a(x) abs(x)
#define d(x,b) (pi*b*min(a(x)+0.5,1.0/b))
#define e(x,b) (pi*b*min(max(a(x)-0.5,-1.0/b),1.0/b))
#define STU(x,b) ((d(x,b)+sin(d(x,b))-e(x,b)-sin(e(x,b)))/(2.0*pi))
//#define X(i) (offset-(i))
#define GETC (texture(Source, vec2(vTexCoord.x - X * params.SourceSize.z, vTexCoord.y)).rgb)
#define VAL vec3((c.x*STU(X,(params.signalResolutionY * params.SourceSize.z))),(c.y*STU(X,(params.signalResolutionI * params.SourceSize.z))),(c.z*STU(X,(params.signalResolutionQ * params.SourceSize.z))))
#define PROCESS(i) X=(offset-(i));c=GETC;tempColor+=VAL;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   if (params.cropOverscan_x > 0.0)
	gl_Position.x /= (240.0 / 256.0);
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
	float	offset	= fract((vTexCoord.x * params.SourceSize.x) - 0.5);
	vec3	tempColor = vec3(0.0);
	float 	X;
	vec3 	c;
	
	float range = ceil(0.5 + params.SourceSize.x / min(min(params.signalResolutionY, params.signalResolutionI), params.signalResolutionQ));
	
	float i;
//	for (i=-range;i<range+2.0;i++){
	for (i=1.0-range;i<range+1.0;i++){
		PROCESS(i)
	}

	tempColor=clamp(YIQ_to_RGB * tempColor,0.0,1.0);
	
   FragColor = vec4(tempColor, 1.0);
}