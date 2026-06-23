#version 450

layout(push_constant) uniform Push
{
    vec4 OutputSize;
    vec4 SourceSize;
    vec4 OriginalSize;
    float video_scale;
    float border_texture_scale;
    float border_brightness;
    float top_x, top_y;
    float bot_x, bot_y;
    float flip_border_y;
} params;

// Global scale parameters
#pragma parameter video_scale "Video Scale" 3.0 2.0 20.0 1.0
#pragma parameter border_texture_scale "Border Scale" 4.0 1.0 20.0 0.01
#pragma parameter border_brightness "Border Brightness" 1.0 0.0 1.0 0.01

// Anchor offset settings (absolute coordinate domain)
#pragma parameter top_x "Top Screen X Offset" 0.0 -2.0 2.0 0.001
#pragma parameter top_y "Top Screen Y Offset" 0.0 -2.0 2.0 0.001
#pragma parameter bot_x "Bottom Screen X Offset" 0.0 -2.0 2.0 0.001
#pragma parameter bot_y "Bottom Screen Y Offset" 0.0 -2.0 2.0 0.001
#pragma parameter flip_border_y "Flip Border Vertically" 0.0 0.0 1.0 1.0

vec2 middle = vec2(0.5, 0.5);

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 tex_border;

void main()
{
    gl_Position = global.MVP * Position;
    
    // Pass native 0-1 coordinates to the fragment shader
    vTexCoord = TexCoord.xy;
    
    // Compute the physical stretch matrix for the border
    vec2 border_scale = vec2(3840.0, 2400.0) * params.video_scale / params.border_texture_scale;
    vec2 diff = vTexCoord.xy - middle;
    tex_border = middle + diff * params.OutputSize.xy / border_scale;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 tex_border;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;

void main()
{
    // Core math fix: derive the physical scaling ratio between the current border and the window
    vec2 border_scale = vec2(3840.0, 2400.0) * params.video_scale / params.border_texture_scale;
    vec2 ratio = border_scale / params.OutputSize.xy;
    
    // Scale the user's absolute offset by this ratio to automatically compensate geometric drift
    vec2 top_offset = vec2(params.top_x, params.top_y) * ratio;
    vec2 bot_offset = vec2(params.bot_x, params.bot_y) * ratio;
    
    vec2 top_sample = vec2(vTexCoord.x - top_offset.x, vTexCoord.y - top_offset.y);
    vec2 bot_sample = vec2(vTexCoord.x - bot_offset.x, vTexCoord.y - bot_offset.y);
    
    vec4 frame = vec4(0.0);
    
    // Render decision region 1: forcibly extract the upper half of the scene
    if (top_sample.x >= 0.0 && top_sample.x <= 1.0 && top_sample.y >= 0.0 && top_sample.y <= 0.5) {
        frame = texture(Source, top_sample).rgba;
    }
    // Render decision region 2: forcibly extract the lower half of the scene
    else if (bot_sample.x >= 0.0 && bot_sample.x <= 1.0 && bot_sample.y > 0.5 && bot_sample.y <= 1.0) {
        frame = texture(Source, bot_sample).rgba;
    }

    vec2 final_tex_border = tex_border;
    if (params.flip_border_y > 0.5) {
        final_tex_border.y = 1.0 - final_tex_border.y;
    }
    vec4 border = texture(BORDER, final_tex_border).rgba;

    // Alpha 通道混合
    FragColor = vec4(mix(frame, border * params.border_brightness, border.a));
}