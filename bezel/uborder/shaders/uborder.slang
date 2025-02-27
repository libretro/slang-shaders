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
    float border_scale;
    float border_center_x;
    float border_center_y;
} params;

#pragma parameter border_nonono       "BORDER:"                           0.0  0.0 1.0 1.0
#pragma parameter ub_border_top       "    On top: [ Frame | Border ]"    0.0  0.0 1.0 1.0
#pragma parameter border_scale        "    Border Scale"                  1.0  0.5 5.0 0.002
#pragma parameter border_center_x        "    Border Center X"            0.0 -0.5 0.5 0.001
#pragma parameter border_center_y        "    Border Center Y"            0.0 -0.5 0.5 0.001

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;


#define middle vec2(0.5)
#define border_pos vec2(params.border_center_x,params.border_center_y)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 border_uv;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord.xy;

    border_uv = middle + (TexCoord.xy - middle - border_pos) / params.border_scale;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 border_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D CRTPass;
layout(set = 0, binding = 3) uniform sampler2D ambi_temporal_pass;


void main()
{
    vec4 border = texture(ambi_temporal_pass, border_uv);
    vec4 frame  = texture(CRTPass, vTexCoord);

    vec4 color = mix(mix(border, frame, frame.a), mix(frame, border, border.a), params.ub_border_top);

    FragColor = color;
}
