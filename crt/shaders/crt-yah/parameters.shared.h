
#define PARAM_GLOBAL_MASTER global.GLOBAL_MASTER
#define PARAM_SCREEN_RESOLUTION_SCALE global.SCREEN_RESOLUTION_SCALE
#define PARAM_SCREEN_ORIENTATION global.SCREEN_ORIENTATION
#define PARAM_SCREEN_SCALE global.SCREEN_SCALE
#define PARAM_SCREEN_FREQUENCY global.SCREEN_FREQUENCY
#define PARAM_SCREEN_INTERLACED global.SCREEN_INTERLACED

float mix_master(float value, float off_value, float min_value, float max_value)
{
    float master = PARAM_GLOBAL_MASTER;

    float scaled_value = clamp(
        (value - off_value * 0.5) * master,
        min_value,
        max_value
    );

    float low = mix(off_value, value, master);
    float high = mix(value, scaled_value, master - 1.0);

    return mix(low, high, step(1.0, master));
}

#define PARAM_COLOR_FLOOR max(PARAM_SCANLINES_STRENGTH, PARAM_MASK_INTENSITY) * (1.0 / 256.0)
#define PARAM_COLOR_COMPENSATION param.COLOR_COMPENSATION
#define PARAM_COLOR_BRIGHTNESS mix_master(param.COLOR_BRIGHTNESS, 0.0, -1.0, 2.0)
#define PARAM_COLOR_BRIGHTNESS_FLICKER param.COLOR_BRIGHTNESS_FLICKER
#define PARAM_COLOR_OVERFLOW mix_master(param.COLOR_OVERFLOW, 0.0, 0.0, 2.0)
#define PARAM_COLOR_CONTRAST mix_master(param.COLOR_CONTRAST, 0.0, -1.0, 1.0)
#define PARAM_COLOR_SATURATION mix_master(param.COLOR_SATURATION, 1.0, 0.0, 2.0)
#define PARAM_COLOR_PROFILE mix_master(param.COLOR_PROFILE, 0.0, -1.0, 1.0)
#define PARAM_COLOR_TEMPERATUE mix_master(param.COLOR_TEMPERATUE * -1.0, 0.0, -1.0, 1.0)
#define PARAM_COLOR_BLACK_LIGHT param.COLOR_BLACK_LIGHT

#define PARAM_MASK_INTENSITY mix_master(param.MASK_INTENSITY, 0.0, 0.0, 1.0)
#define PARAM_MASK_BLEND param.MASK_BLEND
#define PARAM_MASK_SCALE param.MASK_SCALE
#define PARAM_MASK_TYPE param.MASK_TYPE
#define PARAM_MASK_SUBPIXEL param.MASK_SUBPIXEL
#define PARAM_MASK_SUBPIXEL_SHAPE param.MASK_SUBPIXEL_SHAPE
#define PARAM_MASK_COLOR_BLEED mix_master(param.MASK_COLOR_BLEED, 0.0, 0.0, 1.0)

#define PARAM_SCANLINES_STRENGTH mix_master(param.SCANLINES_STRENGTH, 0.0, 0.0, 1.0)
#define PARAM_SCANLINES_COLOR_BURN mix_master(param.SCANLINES_COLOR_BURN, 0.0, 0.0, 1.0)
#define PARAM_SCANLINES_OFFSET param.SCANLINES_OFFSET
#define PARAM_BEAM_WIDTH_MIN param.BEAM_WIDTH_MIN
#define PARAM_BEAM_WIDTH_MAX param.BEAM_WIDTH_MAX
#define PARAM_BEAM_SHAPE param.BEAM_SHAPE
#define PARAM_BEAM_FILTER mix_master(param.BEAM_FILTER, 0.0, -1.0, 1.0)
#define PARAM_ANTI_RINGING param.ANTI_RINGING

#define PARAM_CRT_CURVATURE_AMOUNT mix_master(param.CRT_CURVATURE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_VIGNETTE_AMOUNT mix_master(param.CRT_VIGNETTE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_NOISE_AMOUNT mix_master(param.CRT_NOISE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_CORNER_RAIDUS mix_master(param.CRT_CORNER_RAIDUS, 0.0, 0.0, 0.25)
#define PARAM_CRT_CORNER_SMOOTHNESS param.CRT_CORNER_SMOOTHNESS

#define PARAM_NTSC_PROFILE param.NTSC_PROFILE
#define PARAM_NTSC_JITTER param.NTSC_JITTER
#define PARAM_NTSC_SHIFT param.NTSC_SHIFT
#define PARAM_NTSC_QUALITY param.NTSC_QUALITY
#define PARAM_NTSC_SCALE param.NTSC_SCALE

#define PARAM_DECONVERGE_LINEAR mix_master(param.DECONVERGE_LINEAR, 0.0, -2.0, 2.0)
#define PARAM_DECONVERGE_RADIAL mix_master(param.DECONVERGE_RADIAL, 0.0, -2.0, 2.0)

#define PARAM_PHOSPHOR_AMOUNT mix_master(param.PHOSPHOR_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_PHOSPHOR_DECAY param.PHOSPHOR_DECAY

#define PARAM_HALATION_INTENSITY mix_master(param.HALATION_INTENSITY, 0.0, 0.0, 1.0)
#define PARAM_HALATION_DIFFUSION param.HALATION_DIFFUSION
