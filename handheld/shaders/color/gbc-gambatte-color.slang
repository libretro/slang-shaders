#version 450

/*
   Gambatte Color
   A Slang/GLSL port of the color correction option on Gambatte emulator
   Ported by: RiskyJumps  (Optimized by community)
   License: Public domain
*/

/*
SIMULATE_INT (Not recommended)
It truncates floats. Then again, it's supposed to be more "accurate" 
but it looks just too similar. It's still a waste. Not recommended.
     color.rgb *= 255.0;

     int r = int(color.r);
     int g = int(color.g);
     int b = int(color.b);

     int R = (r * 13 + g * 2 + b) >> 4;
     int G = (g *  3 + b) >> 2;
     int B = (r *  3 + g * 2 + b * 11) >> 4;

     color.rgb = vec3(float(R), float(G), float(B));
     color.rgb /= 255.0;
*/

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const mat3 color_correction = mat3(
	13.0/16.0,  0.0/4.0,   3.0/16.0,
	2.0/16.0,  3.0/4.0,   2.0/16.0,
	1.0/16.0,  1.0/4.0,  11.0/16.0
);

void main() {

    vec3 color = texture(Source, vTexCoord).rgb;

    FragColor = vec4(color_correction * color, 1.0);
}
