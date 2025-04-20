#version 450

// anaglyph to interlaced 3D
// author: hunterk
// license: public domain

// convert anaglyph 3D content to work with interlaced 3D displays

layout(push_constant) uniform Push
{
   vec4 SourceSize;
   vec4 OriginalSize;
   vec4 OutputSize;
   uint FrameCount;
   float anaglyph_selector, eye_swap, red;
} params;

#pragma parameter anaglyph_selector "Anaglyph Mode" 0.0 0.0 2.0 1.0
#pragma parameter eye_swap "Swap Eyes" 0.0 0.0 1.0 1.0
bool eye = bool(params.eye_swap);
#pragma parameter red "Use VB Red Palette" 0.0 0.0 1.0 1.0

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
   float frame1, frame2;
   
   if (params.anaglyph_selector == 0.0){ //red/blue and red/cyan
      frame1 = img.r;
      frame2 = max(img.g, img.b);
   }
   else if (params.anaglyph_selector == 1.0){ //red/green and green/magenta
      frame1 = max(img.r, img.b);
      frame2 = img.g;
   }
   else { //yellow and blue
      frame1 = max(img.r, img.g);
      frame2 = img.b;
   }
	
   bool oscillator = bool(mod(floor(vTexCoord.y * params.OutputSize.y), 2.0));
   oscillator = (eye) ? oscillator : !(oscillator);
   float comb = (oscillator) ? frame1 : frame2;
   float palette = mix(comb, 0.0, params.red);
   FragColor = vec4(comb, palette, palette, 1.0);
}
