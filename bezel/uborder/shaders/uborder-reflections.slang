#version 450

/*  uborder-reflections shader

*/


layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	uint FrameCount;
    float bezel_w, bezel_h;
    float bezel_w_hlen, bezel_h_wlen;
    float frame_w, frame_h;
    float bezel_center_x;
    float bezel_center_y;
    float reflection_strength;
    float reflection_scr_distance_x;
    float reflection_scr_distance_y;
    float AdjustView;
    float ub_border_top;
} params;

#pragma parameter border_nonono       "BORDER:"                           0.0  0.0 1.0 1.0
#pragma parameter ub_border_top       "    On top: [ Frame | Border ]"    0.0  0.0 1.0 1.0

#pragma parameter RF_NONONO              "REFLECTIONS:"                    0.0  0.0 1.0 1.0
#pragma parameter AdjustView             "    Reflection Adjust View"      0.0  0.0 1.0 1.0
#pragma parameter reflection_strength    "    Reflection Strengh"          0.25 0.0 1.0 0.01
#pragma parameter frame_w                "    Reflection Frame Width"      0.67 0.0 1.0 0.001
#pragma parameter frame_h                "    Reflection Frame Height"     0.87 0.0 1.0 0.001
#pragma parameter bezel_w                "    Vertical Bezel Thickness"    0.02 0.0 1.0 0.001
#pragma parameter bezel_h                "    Horizontal Bezel Thickness"  0.02 0.0 1.0 0.001
#pragma parameter bezel_center_x         "    Vertical Bezel Center"       0.0 -0.5 0.5 0.001
#pragma parameter bezel_center_y         "    Horizontal Bezel Center"     0.0 -0.5 0.5 0.001
#pragma parameter reflection_scr_distance_x     "    Bezel Reflection Screen Distance X" 0.00 0.0 0.04 0.001
#pragma parameter reflection_scr_distance_y     "    Bezel Reflection Screen Distance Y" 0.00 0.0 0.04 0.001

#define bezel_w     params.bezel_w
#define bezel_h     params.bezel_h
#define frame_w     params.frame_w
#define frame_h     params.frame_h
#define bezel_center_x     params.bezel_center_x
#define bezel_center_y     params.bezel_center_y
#define reflection_strength     params.reflection_strength
#define reflection_scr_distance_x     params.reflection_scr_distance_x
#define reflection_scr_distance_y     params.reflection_scr_distance_y

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
	vTexCoord = TexCoord.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D CRTPass;
layout(set = 0, binding = 3) uniform sampler2D BORDER;
layout(set = 0, binding = 4) uniform sampler2D BlurPass;


void main()
{
    vec4 border = texture(BORDER, vTexCoord);

    vec2 uv = vTexCoord.xy - vec2(bezel_center_x, bezel_center_y);

    vec4 frame = texture(CRTPass, vTexCoord.xy);
    
    vec2 c_frame = vec2(frame_w, frame_h);

    vec2 ouv = uv;

    vec4 reflex;

    if((abs(uv.x-0.5) >= (0.5*c_frame.x) && abs(uv.x-0.5) <= (0.5*c_frame.x+bezel_w)) && abs(uv.y-0.5) <= (0.5*c_frame.y+bezel_h))
    {
        uv.x = (uv.x >= 0.50) ? 1.0 + c_frame.x - uv.x + reflection_scr_distance_x : 1.0 - c_frame.x - uv.x - reflection_scr_distance_x;

        reflex.rgb = mix(texture(BlurPass, uv + vec2(bezel_center_x, bezel_center_y)).rgb, vec3(0.0, 1.0, 0.0), params.AdjustView);

        reflex.rgb = mix(reflex.rgb, frame.rgb, frame.a);
        reflex.rgb *= (1.0-smoothstep(0.5*c_frame.y-0.1, 0.5*c_frame.y, abs(uv.y-0.5)));

        border.rgb = clamp(border.rgb + reflection_strength*reflex.rgb, 0.0, 1.0);
    }
    

    if((abs(uv.y-0.5) >= (0.5*c_frame.y) && abs(uv.y-0.5) <= (0.5*c_frame.y+bezel_h)) && abs(ouv.x-0.5) <= (0.5*c_frame.x+bezel_w))
    {        

        uv.y = (uv.y >= 0.50) ? 1.0 + c_frame.y - uv.y + reflection_scr_distance_y : 1.0 - c_frame.y - uv.y - reflection_scr_distance_y;

        reflex.rgb = mix(texture(BlurPass, vec2(ouv.x, uv.y) + vec2(bezel_center_x, bezel_center_y)).rgb, vec3(0.0, 1.0, 0.0), params.AdjustView);

        reflex.rgb = mix(reflex.rgb, frame.rgb, frame.a);
        reflex.rgb *= (1.0-smoothstep(0.5*c_frame.x-0.1, 0.5*c_frame.x, abs(ouv.x-0.5)));

        border.rgb = clamp(border.rgb + reflection_strength*reflex.rgb, 0.0, 1.0);
    }
    
    FragColor = vec4(mix(mix(frame, border, border.a), frame, frame.a * (1.0-params.ub_border_top)));

//    FragColor = mix(mix(border, frame, frame.a), mix(frame, border, border.a), params.ub_border_top);

}

