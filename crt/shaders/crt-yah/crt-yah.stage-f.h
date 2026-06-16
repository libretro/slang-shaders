#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in vec2 ScanTexCoord;
layout(location = 2) in vec2 TexSize;
layout(location = 3) flat in int ScreenOrientation;
layout(location = 4) in float ScreenMultiple;
layout(location = 5) in float ScreenMultipleAuto;
layout(location = 6) in float BrightnessCompensation;
layout(location = 7) in vec4 MaskProfile;
layout(location = 8) in vec4 BeamProfile;
layout(location = 9) in float AntiRining;
layout(location = 10) in vec2 FloorProfile;
layout(location = 11) flat in uvec2 FrameCounts;
layout(location = 12) in mat4x4 BeamFilter;
layout(location = 0) out vec4 FragColor;

#ifdef IS_SINGLE_PASS

    layout(set = 0, binding = 2) uniform sampler2D Source;

    #define TextureSource Source

#else

    layout(set = 0, binding = 2) uniform sampler2D PhosphorPass;
    layout(set = 0, binding = 3) uniform sampler2D HalationBlurVPass;
    layout(set = 0, binding = 4) uniform sampler2D SharpBlurVPass;

    #define TextureSource PhosphorPass
    #define HalationSource HalationBlurVPass
    #define BlurSource SharpBlurVPass

#endif

// required by crt-yah.stage-f.core.h
#define INPUT_SCREEN_ORIENTATION ScreenOrientation
#define INPUT_SCREEN_MULTIPLE ScreenMultiple
#define INPUT_SCREEN_MULTIPLE_AUTO ScreenMultipleAuto
#define INPUT_BRIGHTNESS_COMPENSATION BrightnessCompensation
#define INPUT_MASK_PROFILE MaskProfile
#define INPUT_BEAM_PROFILE BeamProfile
#define INPUT_BEAM_FILTER BeamFilter
#define INPUT_ANTI_RINGING AntiRining
#define INPUT_FLOOR_PROFILE FloorProfile
#define INPUT_FRAME_COUNTS FrameCounts

#include "crt-yah.stage-f.core.h"

void main()
{
    vec2 tex_size = TexSize;
    vec2 tex_coord = TexCoord;
    vec2 tex_coord_curved = apply_cubic_lens_distortion(tex_coord);
    vec2 tex_coord_curved_sharpened = apply_sharp_bilinear_filtering(tex_coord_curved, tex_size);
    vec2 scan_coord = ScanTexCoord;
    vec2 scan_coord_curved = apply_cubic_lens_distortion(scan_coord);
    vec2 scan_coord_curved_sharpened = apply_sharp_bilinear_filtering(scan_coord_curved, tex_size);

    vec3 raw_color = get_raw_color(TextureSource, tex_coord_curved_sharpened, tex_size);
    vec3 scanlines_factor = vec3(0.0);
    vec3 scanlines_color = get_scanlines_color(TextureSource, scan_coord_curved, tex_size, scanlines_factor);

#ifndef IS_SINGLE_PASS
    scanlines_color = apply_details(scanlines_color, TextureSource, scan_coord_curved, BlurSource, tex_coord_curved);
#endif

    vec3 color = blend_colors(raw_color, scanlines_color);
    float color_luma = get_luminance(color);

    vec3 mask_factor = vec3(0.0);
    color = apply_mask(color, color_luma, tex_coord, mask_factor);  // use un-curved coordinates to avoid Moire-artifacts
    color = apply_noise(color, color_luma, tex_coord); // use un-curved coordinates to avoid Moire-artifacts
    color = apply_color_overflow(color);

#ifndef IS_SINGLE_PASS
    color = apply_halation(color, HalationSource, tex_coord_curved, scanlines_factor, mask_factor);
#endif

    color *= get_vignette_factor(tex_coord_curved);
    color *= get_round_corner_factor(tex_coord_curved);

    FragColor = vec4(OUTPUT(color, color_luma), 1.0);
}
