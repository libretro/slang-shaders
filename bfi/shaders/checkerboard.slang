#version 450

// checkerboard / interlacing BFI
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
   float sizePicker, sizeMult, lines, axisPicker;
} params;

#pragma parameter sizePicker "Check Size (0 = pixel, 1 = texel)" 0.0 0.0 1.0 1.0
#pragma parameter sizeMult "Check Size Multiplier" 1.0 1.0 20.0 1.0
#pragma parameter lines "Use Checks vs Lines" 0.0 0.0 1.0 1.0
#pragma parameter axisPicker "Cycle Lines on X or Y Axis" 0.0 0.0 1.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 checkSize;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
   checkSize = (params.sizePicker > 0.5) ? params.SourceSize.xy : params.OutputSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 checkSize;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
   FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
// early return if we don't have subframes enabled
   if(params.TotalSubFrames == 1) return;

// set up our alternating bools on each pixel/texel
   bool xaxis = bool(int(mod(vTexCoord.x * (checkSize.x / params.sizeMult), 2.0)));
   bool yaxis = bool(int(mod(vTexCoord.y * (checkSize.y / params.sizeMult), 2.0)));
// stagger the effect to make a checkerboard pattern (or not, if we want lines instead)
   xaxis = (yaxis && params.lines < 0.5) ? !xaxis : xaxis;
// flip the effect on half sub-frames
   xaxis = (params.CurrentSubFrame > 0.5 * float(params.TotalSubFrames)) ? !xaxis : xaxis;
   yaxis = (params.CurrentSubFrame > 0.5 * float(params.TotalSubFrames)) ? !yaxis : yaxis;
// animate on which axis?
   bool axis = (params.axisPicker > 0.5) ? yaxis : xaxis;
   FragColor *= (axis) ?  vec4(0.0) : vec4(1.0);
}
