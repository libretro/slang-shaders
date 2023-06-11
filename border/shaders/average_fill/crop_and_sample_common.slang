// See compose.slang for copyright and other information.

layout(push_constant) uniform Push {
    vec4 InputSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float OS_CROP_TOP;
    float OS_CROP_BOTTOM;
    float OS_CROP_LEFT;
    float OS_CROP_RIGHT;
    float SAMPLE_SIZE;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord =
        mix(vec2(EFF_CROP_LEFT, EFF_CROP_TOP) * param.InputSize.zw,
            1.0 - vec2(EFF_CROP_RIGHT, EFF_CROP_BOTTOM) * param.InputSize.zw,
            TexCoord);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Input;

void main() { FragColor = vec4(texture(Input, vTexCoord).rgb, 1.0); }
