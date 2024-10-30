#version 450

// BFI Simple
// several different implementations of software BFI
// license: public domain

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount, CurrentSubFrame, TotalSubFrames;
   float bfi_mode, bfidummy0, bfidummy1, bfidummy2, bfidummy3, bfidummy4, bfidummy5;
} params;

#pragma parameter bfi_mode "Sub-Frame BFI Mode" 0.0 0.0 5.0 1.0
int mode = int(params.bfi_mode);

#pragma parameter bfidummy0 "|| Mode 0 -> Disable BFI" 0.00001 0.00001 0.00001 0.00001
#pragma parameter bfidummy1 "|| Mode 1 -> Cycle on each sub-frame" 0.00001 0.00001 0.00001 0.00001
#pragma parameter bfidummy2 "|| Mode 2 -> Show only the first sub-frame" 0.00001 0.00001 0.00001 0.00001
#pragma parameter bfidummy3 "|| Mode 3 -> Show all but the last sub-frame" 0.00001 0.00001 0.00001 0.00001
#pragma parameter bfidummy4 "|| Mode 4 -> Fade out" 0.00001 0.00001 0.00001 0.00001
#pragma parameter bfidummy5 "|| Mode 5 -> Half blank" 0.00001 0.00001 0.00001 0.00001

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 bfi;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   switch(mode){
   case 0: // passthru
      bfi = vec4(1.0);
      break;
   case 1: // classic oscillator
      bfi = vec4(mod(float(params.FrameCount * params.TotalSubFrames + params.CurrentSubFrame), 2.));
      break;
   case 2: // blank all subframes after the first (maximize blur reduction)
      bfi = (params.CurrentSubFrame == 1) ? vec4(1.0) : vec4(0.0);
      break;
   case 3: // blank the last subframe (maximize brightness)
      bfi = (params.CurrentSubFrame == params.TotalSubFrames) ? vec4(0.0) : vec4(1.0);
      break;
   case 4: // fade out
      bfi = vec4(1. - float(params.CurrentSubFrame - 1) / float(params.TotalSubFrames));
      break;
   case 5: // half on, half off
      bfi = (params.CurrentSubFrame > 0.5 * params.TotalSubFrames) ? vec4(1.0) : vec4(0.0);
      break;
   }
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 bfi;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
   FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
   if(params.TotalSubFrames < 2) return;
   else FragColor *= bfi;
}
