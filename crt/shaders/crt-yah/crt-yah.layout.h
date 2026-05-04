layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
    uint FrameTimeDelta;
    float GLOBAL_MASTER;
    float SCREEN_RESOLUTION_SCALE;
    float SCREEN_ORIENTATION;
    float SCREEN_SCALE;
    float SCREEN_FREQUENCY;
    float SCREEN_INTERLACED;
    float SHARP_AMOUNT;
} global;

layout (push_constant) uniform Push
{
    float COLOR_BRIGHTNESS;
    float COLOR_BRIGHTNESS_FLICKER;
    float COLOR_COMPENSATION;
    float COLOR_SATURATION;
    float COLOR_OVERFLOW;
    float COLOR_CONTRAST;
    float COLOR_PROFILE;
    float COLOR_TEMPERATUE;
    float COLOR_BLACK_LIGHT;
    float SCANLINES_STRENGTH;
    float SCANLINES_OFFSET;
    float BEAM_WIDTH_MIN;
    float BEAM_WIDTH_MAX;
    float BEAM_SHAPE;
    float BEAM_FILTER;
    float ANTI_RINGING;
    float SCANLINES_COLOR_BURN;
    float MASK_INTENSITY;
    float MASK_BLEND;
    float MASK_SCALE;
    float MASK_TYPE;
    float MASK_SUBPIXEL;
    float MASK_SUBPIXEL_SHAPE;
    float MASK_COLOR_BLEED;
    float HALATION_INTENSITY;
    float HALATION_DIFFUSION;
    float CRT_CURVATURE_AMOUNT;
    float CRT_VIGNETTE_AMOUNT;
    float CRT_NOISE_AMOUNT;
    float CRT_CORNER_RAIDUS;
    float CRT_CORNER_SMOOTHNESS;
} param;
