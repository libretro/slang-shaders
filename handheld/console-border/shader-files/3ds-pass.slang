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
} params;

// 全局缩放参数
#pragma parameter video_scale "Video Scale" 3.0 2.0 20.0 1.0
#pragma parameter border_texture_scale "Border Scale" 4.0 1.0 20.0 0.01
#pragma parameter border_brightness "Border Brightness" 1.0 0.0 1.0 0.01

// 锚点偏移量设定 (绝对坐标域)
#pragma parameter top_x "Top Screen X Offset" 0.0 -2.0 2.0 0.001
#pragma parameter top_y "Top Screen Y Offset" 0.0 -2.0 2.0 0.001
#pragma parameter bot_x "Bottom Screen X Offset" 0.0 -2.0 2.0 0.001
#pragma parameter bot_y "Bottom Screen Y Offset" 0.0 -2.0 2.0 0.001

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
    
    // 向片段着色器传递原生 0-1 坐标
    vTexCoord = TexCoord.xy;
    
    // 计算边框的物理拉伸矩阵
    vec2 border_scale = vec2(3840.0, 2800.0) * params.video_scale / params.border_texture_scale;
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
    // 【核心数学修正】：提取当前边框与窗口的物理缩放比
    vec2 border_scale = vec2(3840.0, 2800.0) * params.video_scale / params.border_texture_scale;
    vec2 ratio = border_scale / params.OutputSize.xy;
    
    // 将用户的绝对偏移量除以(即乘以ratio)缩放比例，自动抵消几何漂移
    vec2 top_offset = vec2(params.top_x, params.top_y) * ratio;
    vec2 bot_offset = vec2(params.bot_x, params.bot_y) * ratio;
    
    vec2 top_sample = vec2(vTexCoord.x - top_offset.x, vTexCoord.y - top_offset.y);
    vec2 bot_sample = vec2(vTexCoord.x - bot_offset.x, vTexCoord.y - bot_offset.y);
    
    vec4 frame = vec4(0.0);
    
    // 渲染判定域 1：强行剥离上半部分画面
    if (top_sample.x >= 0.0 && top_sample.x <= 1.0 && top_sample.y >= 0.0 && top_sample.y <= 0.5) {
        frame = texture(Source, top_sample).rgba;
    }
    // 渲染判定域 2：强行剥离下半部分画面
    else if (bot_sample.x >= 0.0 && bot_sample.x <= 1.0 && bot_sample.y > 0.5 && bot_sample.y <= 1.0) {
        frame = texture(Source, bot_sample).rgba;
    }
    
    vec4 border = texture(BORDER, tex_border).rgba;
    
    // Alpha 通道混合
    FragColor = vec4(mix(frame, border * params.border_brightness, border.a));
}