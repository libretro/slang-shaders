layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    float GLOBAL_MASTER;
} global;

layout (push_constant) uniform Push
{
    float HALATION_INTENSITY;
    float HALATION_DIFFUSION;
} param;
