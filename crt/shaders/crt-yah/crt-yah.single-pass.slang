#version 450

/*    
    Yah! - Yet Another Hyllian
    Based on CRT shader by Hyllian
    Modified by Jezze
*/

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
    uint FrameTimeDelta;
} global;

layout (push_constant) uniform Push
{
    float GLOBAL_MASTER;
    float SCREEN_SCALE;
    float SCREEN_ORIENTATION;
    float COLOR_BRIGHTNESS;
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
    float MASK_SIZE;
    float MASK_TYPE;
    float MASK_SUBPIXEL;
    float MASK_COLOR_BLEED;
    float CRT_CURVATURE_AMOUNT;
    float CRT_VIGNETTE_AMOUNT;
    float CRT_NOISE_AMOUNT;
    float CRT_CORNER_RAIDUS;
    float CRT_CORNER_SMOOTHNESS;
} param;

#include "parameters.single-pass.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out float ScreenOrientation;
layout(location = 2) out float ScreenMultiple;
layout(location = 3) out float ScreenMultipleAuto;
layout(location = 4) out float BrightnessCompensation;
layout(location = 5) out vec2 MaskProfile;
layout(location = 6) out vec4 BeamProfile;
layout(location = 7) out mat4x4 BeamFilter;

// required by crt-yah.vs.h
#define INPUT_SCREEN_MULTIPLE ScreenMultiple
#define INPUT_MASK_PROFILE MaskProfile

#include "crt-yah.vs.h"

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    ScreenOrientation = get_orientation(global.OutputSize.xy, PARAM_SCREEN_ORIENTATION);
    ScreenMultiple = get_multiple(global.OriginalSize.xy, ScreenOrientation, -PARAM_SCREEN_SCALE);
    ScreenMultipleAuto = get_multiple(global.OriginalSize.xy, ScreenOrientation, 0);
    MaskProfile = get_mask_profile();
    BeamProfile = get_beam_profile();
    BeamFilter = get_beam_filter();
    BrightnessCompensation = get_brightness_compensation();
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in float ScreenOrientation;
layout(location = 2) in float ScreenMultiple;
layout(location = 3) in float ScreenMultipleAuto;
layout(location = 4) in float BrightnessCompensation;
layout(location = 5) in vec2 MaskProfile;
layout(location = 6) in vec4 BeamProfile;
layout(location = 7) in mat4x4 BeamFilter;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// required by crt-yah.fs.h
#define INPUT_SCREEN_ORIENTATION ScreenOrientation
#define INPUT_SCREEN_MULTIPLE ScreenMultiple
#define INPUT_SCREEN_MULTIPLE_AUTO ScreenMultipleAuto
#define INPUT_BRIGHTNESS_COMPENSATION BrightnessCompensation
#define INPUT_MASK_PROFILE MaskProfile
#define INPUT_BEAM_PROFILE BeamProfile
#define INPUT_BEAM_FILTER BeamFilter

#include "crt-yah.fs.h"

void main()
{
    vec2 tex_coord = TexCoord;
    vec2 tex_coord_curved = apply_cubic_lens_distortion(tex_coord);
    vec2 tex_coord_curved_sharpend = apply_sharp_bilinear_filtering(tex_coord_curved);

    vec3 raw_color = get_raw_color(Source, tex_coord_curved_sharpend);
    vec3 scanlines_color = get_scanlines_color(Source, tex_coord_curved);

    vec3 color = blend_colors(raw_color, scanlines_color);
    float color_luma = get_luminance(color);

    color = apply_noise(color, color_luma, tex_coord); // use un-curved coordinates to avoid Moire-artefacts
    color = apply_mask(color, color_luma, tex_coord);  // use un-curved coordinates to avoid Moire-artefacts
    color = apply_color_overflow(color);

    color *= get_vignette_factor(tex_coord_curved);
    color *= get_round_corner_factor(tex_coord_curved);

    FragColor = vec4(OUTPUT(color, color_luma), 1.0);
}
