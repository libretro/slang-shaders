#version 450

/*  border-final shader

    Based on ambient-glow, this shader must be used after
    any other shader. It only works properly if no mask or
    warp functions are used.

*/


layout(push_constant) uniform Push
{
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    uint FrameCount;
    float ub_border_top;
} params;

#pragma parameter border_nonono       "BORDER:"                           0.0  0.0 1.0 1.0
#pragma parameter ub_border_top       "    On top: [ Frame | Border ]"    0.0  0.0 1.0 1.0


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
    vTexCoord.xy = TexCoord.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D CRTPass;
layout(set = 0, binding = 3) uniform sampler2D BORDER;


void main()
{
    vec4 border = texture( BORDER, vTexCoord);
    vec4 frame  = texture(CRTPass, vTexCoord);

    vec4 color = mix(mix(border, frame, frame.a), mix(frame, border, border.a), params.ub_border_top);

    FragColor = color;
}
