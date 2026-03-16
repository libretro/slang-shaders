layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 InputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
    uint FrameTimeDelta;
    float GLOBAL_MASTER;
    float SCREEN_RESOLUTION_SCALE;
    float SCREEN_ORIENTATION;
    float SCREEN_SCALE;
    float SCREEN_FREQUENCY;
} global;

layout (push_constant) uniform Push
{
    float NTSC_PROFILE;
    float NTSC_QUALITY;
    float NTSC_SCALE;
    float NTSC_SHIFT;
    float NTSC_JITTER;
} param;
