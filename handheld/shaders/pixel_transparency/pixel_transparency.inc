/*
  ____  _          _
 |  _ \(_)_  _____| |
 | |_) | \ \/ / _ \ |
 |  __/| |>  <  __/ |
 |_|___|_/_/\_\___|_|
 |_   _| __ __ _ _ __  ___ _ __   __ _ _ __ ___ _ __   ___ _   _
   | || '__/ _` | '_ \/ __| '_ \ / _` | '__/ _ \ '_ \ / __| | | |
   | || | | (_| | | | \__ \ |_) | (_| | | |  __/ | | | (__| |_| |
   |_||_|  \__,_|_| |_|___/ .__/ \__,_|_|  \___|_| |_|\___|\__, |
                          |_|      TRANSPARENCY COMPOSITOR  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.

    With no backlight, the original devices didn't render white pixels. Light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.

    Load a preset from presets/pixel_transparency/ to get the effect with your favourite grid built in.

    Shared transparency rendering: paper backing, pixel alpha, shadows and tint.

*/

// Final-pass transparency shared by all six grids. Source sampling stays nearest.
// The five non-Authentic grids supply their LCD sample through sampleLCD().

#pragma name Pixel_Transparency
#include "pt-params.inc"

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    // Vertex-stage parameters
    float PT_ACCEL_ENABLE;
    float PT_ACCEL_SENSITIVITY;
    float PT_SHADOW_MOTION;
    float PT_SHADOW_MAX_OFFSET;
    float PT_SHADOW_MOTION_X;
    float PT_SHADOW_MOTION_Y;
    float PT_SHADOW_OFFSET_X;
    float PT_SHADOW_OFFSET_Y;
    // Hot fragment-stage parameters
    float PT_ENABLE;
    float PT_BRIGHTNESS_MODE;
    float PT_SHADOW_ENABLE;
    float PT_SHADOW_BLUR;
    float PT_SHADOW_OPACITY;
    float PT_THRESHOLD;
    float PT_SHADOW_FAST_BLUR;
    float PT_PIXEL_MODE;
    float PT_BASE_ALPHA;
    float PT_DEFER_DITHER;
#ifdef PT_LIGHT_FIELD
    float PT_RAINBOW_ENABLE;
    float PT_GLARE_ENABLE;
    float PT_LIGHT_RANGE;
    float PT_LIGHT_X;
    float PT_LIGHT_Y;
#endif
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 OriginalSize;
#ifdef PT_COMPOSITOR_UNIFORMS
    PT_COMPOSITOR_UNIFORMS
#endif
#ifdef PT_CUSTOM_LCD
    PT_LCD_UNIFORMS
#endif
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
    float PT_HIDE_CONTENT;
    float PT_PALETTE;
    float PT_PALETTE_INTENSITY;
    float PT_BACKING_BRIGHTNESS;
    float PT_POLARIZER;
    float PT_POLARIZER_TINT;
    float PT_SATURATION;
    float PT_HIGHLIGHTS;
    float PT_WHITE_BOOST;
    float PT_WHITE_TRANSPARENCY;
    float PT_GRID_COLOR_MIX;
    float PT_GRID_WHITE_MIX;
    float PT_PAPER_NOISE_FAST;
    float PT_SHADOW_EDGE_ENABLE;
#ifdef PT_LIGHT_FIELD
    float PT_SUNLIGHT_ENABLE;
    float PT_RAINBOW_INTENSITY;
    float PT_GLARE_INTENSITY;
    float PT_REFLECT_ENABLE;
    float PT_REFLECT_INTENSITY;
    float PT_REFLECT_SPREAD;
    float PT_REFLECT_BIAS;
    float PT_REFLECT_WARM;
#endif
} global;

#pragma stage vertex
layout(location = 8) flat out ivec2 shadow_origin;
layout(location = 11) flat out vec2 shadow_offset_uv;
layout(location = 9) flat out vec2 shadow_phase_low;
layout(location = 10) flat out vec2 shadow_phase_high;
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) flat out vec2 texel;
layout(location = 2) flat out float shadow_scale_factor;
layout(location = 3) flat out vec2 shadow_offset_raw;
#ifdef PT_LIGHT_FIELD
layout(location = 4) flat out vec2 light_pos;
layout(location = 7) out vec2 light_coord;
#endif

#ifdef PT_CUSTOM_LCD
void prepareLCD();
#endif

// Extract tilt as a normalized 2D vector.
// Returns values in -1 to 1 range. Returns vec2(0.0) if input is near-zero.
vec2 getOrientedTilt(vec3 accel) {
    float magnitude = length(accel);
    if (magnitude < 0.01) return vec2(0.0);
    vec3 dir = accel / magnitude;
    return vec2(-dir.x, dir.y);
}

layout(location = 5) flat out vec3 backing_palette;
layout(location = 6) flat out vec3 polarizer_color;
void main() {
    gl_Position = global.MVP * Position;
#ifdef PT_CUSTOM_LCD
    prepareLCD();
#endif
    if (global.PT_PALETTE < 1.5) backing_palette=vec3(0.651,0.675,0.518);
    else if (global.PT_PALETTE < 2.5) backing_palette=vec3(0.72,0.73,0.66);
    else if (global.PT_PALETTE < 3.5) backing_palette=vec3(0.766,0.73,0.763);
    else backing_palette=vec3(0.76); // Aluminum (spectrally neutral)
    // Normalize brightness across palette modes (match Warm1's max channel).
    backing_palette*=0.675/max(backing_palette.r,max(backing_palette.g,backing_palette.b));
    // Front polarizer tint for light crossing it twice: the single-pass tint
    // (0.97, 1.0, 0.93) squared. Intensity 0.5 approximates a single pass.
    polarizer_color=mix(vec3(1.0),vec3(0.94,1.0,0.865),global.PT_POLARIZER_TINT);

    vTexCoord = TexCoord;
    texel = param.OutputSize.zw;

    // Resolution scale for shadow compensation (reference: 640x480)
    float scale_x = param.OutputSize.x / 640.0;
    float scale_y = param.OutputSize.y / 480.0;
    shadow_scale_factor = sqrt(scale_x * scale_y);

    // Get raw gravity tilt (-1 to 1 per axis, or 0 if no sensor data)
    vec2 gravity = vec2(0.0);
    bool has_sensors = false;

    #ifdef _HAS_SENSOR_UNIFORMS
    if (param.PT_ACCEL_ENABLE > 0.5) {
        vec3 accel = global.Accelerometer;
        has_sensors = length(accel) > 0.01;
        if (has_sensors) {
            gravity = getOrientedTilt(accel);
            gravity = clamp(gravity * param.PT_ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));
        }
    }
    #endif


    // Shadow offset: motion or static.
    if (param.PT_SHADOW_MOTION > 0.5 && param.PT_ACCEL_ENABLE > 0.5 && has_sensors) {
        vec2 base = vec2(param.PT_SHADOW_MOTION_X, param.PT_SHADOW_MOTION_Y);
        shadow_offset_raw = base + gravity * param.PT_SHADOW_MAX_OFFSET;
    } else {
        shadow_offset_raw = vec2(param.PT_SHADOW_OFFSET_X, param.PT_SHADOW_OFFSET_Y);
    }
    vec2 native_offset = -shadow_offset_raw * shadow_scale_factor * texel * global.OriginalSize.xy;
    precise vec2 native_radius = param.PT_SHADOW_BLUR > 0.1
        ? param.PT_SHADOW_BLUR * shadow_scale_factor * texel * global.OriginalSize.xy : vec2(0.0);
    shadow_origin = ivec2(floor(native_offset));
    // The viewport-scaled offset is uniform across output pixels.
    shadow_offset_uv = -shadow_offset_raw * shadow_scale_factor * texel;
    vec2 fraction = fract(native_radius);
    shadow_phase_low = min(fraction, vec2(1.0) - fraction);
    shadow_phase_high = max(fraction, vec2(1.0) - fraction);
#ifdef PT_LIGHT_FIELD
    light_pos=vec2(param.PT_LIGHT_X,param.PT_LIGHT_Y)
        +vec2(gravity.x,-gravity.y)*param.PT_LIGHT_RANGE;
    light_coord=(TexCoord*(param.SourceSize.xy-vec2(1.0))+vec2(0.5))*param.SourceSize.zw;
#endif
}

#pragma stage fragment
layout(location = 8) flat in ivec2 shadow_origin;
layout(location = 11) flat in vec2 shadow_offset_uv;
layout(location = 9) flat in vec2 shadow_phase_low;
layout(location = 10) flat in vec2 shadow_phase_high;
layout(location = 5) flat in vec3 backing_palette;
layout(location = 6) flat in vec3 polarizer_color;

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) flat in vec2 texel;
layout(location = 2) flat in float shadow_scale_factor;
layout(location = 3) flat in vec2 shadow_offset_raw;
#ifdef PT_LIGHT_FIELD
layout(location = 4) flat in vec2 light_pos;
layout(location = 7) in vec2 light_coord;
layout(set = 0, binding = 5) uniform sampler2D LightField;
#endif
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D LCDInput;
layout(set=0,binding=4) uniform sampler2D PixelShadowCache;
layout(set = 0, binding = 3) uniform sampler2D Original;

// ITU-R BT.709 perceptual luminance weights
#define LUMA_R 0.2126
#define LUMA_G 0.7152
#define LUMA_B 0.0722

float getPerceptualBrightness(vec3 color) {
    return (LUMA_R * color.r) + (LUMA_G * color.g) + (LUMA_B * color.b);
}

float getGameBoyRGBSum(vec3 color) {
    return (color.r + color.g + color.b) / 3.0;
}

float getBrightness(vec3 color) {
    if (param.PT_BRIGHTNESS_MODE < 0.5) {
        return getGameBoyRGBSum(color);
    } else {
        return getPerceptualBrightness(color);
    }
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float paperNoise(vec2 uv, float scale) {
    vec2 p = uv * scale * 512.0;
    if (global.PT_PAPER_NOISE_FAST < 0.5) {
        float n = hash(p) * 0.5 + hash(p * 2.0) * 0.25;
        return n * (7.0 / 6.0);
    }
    float n = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 3; i++) {
        n += hash(p * frequency) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return n;
}

vec3 generateProceduralBackground(vec2 uv) {
    vec3 baseColor = vec3(global.PT_BACKING_BRIGHTNESS);
    const float grainIntensity = 0.065;
    const float scale = 0.25;
    float grain = paperNoise(uv, scale);
    float grainOffset = (grain - 0.4375) * grainIntensity;
    return baseColor + vec3(grainOffset);
}

// The cache window includes every shifted source cell, even beyond screen edges.

float cachedShadow(vec2 center) {
    ivec2 size = ivec2(global.OriginalSize.xy);
    vec2 native = center * global.OriginalSize.xy;
    ivec2 cell = clamp(ivec2(floor(native)) - shadow_origin, ivec2(0), size);
    vec2 position = fract(native);
    ivec2 phase = ivec2(greaterThanEqual(position, shadow_phase_low))
        + ivec2(greaterThanEqual(position, shadow_phase_high));
    vec4 values = texelFetch(PixelShadowCache, ivec2(3 * cell.x + phase.x, cell.y), 0);
    return values[phase.y];
}

#ifdef PT_CUSTOM_LCD
vec4 sampleLCD();
#endif

bool renderPixelTransparency(out vec3 original_pixel, out float original_brightness) {
    original_pixel=vec3(1.0);
    original_brightness=1.0;
#ifdef PT_CUSTOM_LCD
    vec4 lcd_color = sampleLCD();
#else
    vec4 lcd_color = texture(LCDInput, vTexCoord);
#endif

    vec4 output_color = lcd_color;

    if (param.PT_ENABLE < 0.5
    ) {
        FragColor = output_color;
        return false;
    }

    original_pixel = texture(Original, vTexCoord).rgb;

    // Debug: replace game image with white to isolate shader effects
    if (global.PT_HIDE_CONTENT > 0.5) {
        lcd_color = vec4(1.0);
        original_pixel = vec3(1.0);
        output_color = lcd_color;
    }

    float original_luma=getPerceptualBrightness(original_pixel);
    original_brightness=param.PT_BRIGHTNESS_MODE<0.5
        ? getGameBoyRGBSum(original_pixel) : original_luma;
    // Highlight adjustment — negative dims lcd_color before compositing
    if (global.PT_HIGHLIGHTS < -0.001) {
        float luma = getPerceptualBrightness(lcd_color.rgb);
        lcd_color.rgb *= max(1.0 + global.PT_HIGHLIGHTS * luma, 0.0);
        output_color.rgb = lcd_color.rgb;
    }

    bool current_is_white = (original_luma > param.PT_THRESHOLD && min(min(original_pixel.r,original_pixel.g),original_pixel.b) > param.PT_THRESHOLD*0.9);
    bool should_apply = (param.PT_PIXEL_MODE < 0.5) ? current_is_white : true;

    // Resolve transparency early so zero grid mix skips LCD brightness work.
    float grid_mix = current_is_white ? global.PT_GRID_WHITE_MIX : global.PT_GRID_COLOR_MIX;
    float pixel_alpha = 0.0;

    if (param.PT_PIXEL_MODE > 0.5 && param.PT_PIXEL_MODE < 1.5) {
        float no_grid_alpha = (param.PT_BASE_ALPHA * original_brightness) * 2.665;
        if (current_is_white && global.PT_WHITE_BOOST > 0.5) {
            no_grid_alpha = max(no_grid_alpha, global.PT_WHITE_TRANSPARENCY);
        }

        if (grid_mix <= 0.0) {
            pixel_alpha = clamp(no_grid_alpha, 0.0, 1.0);
        } else {
            float grid_alpha = (param.PT_BASE_ALPHA * getBrightness(lcd_color.rgb)) * 2.665;
            if (current_is_white && global.PT_WHITE_BOOST > 0.5) {
                grid_alpha = max(grid_alpha, global.PT_WHITE_TRANSPARENCY);
            }
            pixel_alpha = clamp(mix(no_grid_alpha, grid_alpha, grid_mix), 0.0, 1.0);
        }
    } else if (should_apply) {
        float no_grid_alpha = (original_brightness / 3.0) + param.PT_BASE_ALPHA;
        if (current_is_white && global.PT_WHITE_BOOST > 0.5) {
            no_grid_alpha = max(no_grid_alpha, global.PT_WHITE_TRANSPARENCY);
        }

        if (grid_mix <= 0.0) {
            pixel_alpha = clamp(no_grid_alpha, 0.0, 1.0);
        } else {
            float grid_alpha = (getBrightness(lcd_color.rgb) / 3.0) + param.PT_BASE_ALPHA;
            if (current_is_white && global.PT_WHITE_BOOST > 0.5) {
                grid_alpha = max(grid_alpha, global.PT_WHITE_TRANSPARENCY);
            }
            pixel_alpha = clamp(mix(no_grid_alpha, grid_alpha, grid_mix), 0.0, 1.0);
        }
    }

    vec4 background = vec4(0.0);
    if (should_apply && pixel_alpha > 0.0) {
        background = vec4(generateProceduralBackground(vTexCoord), 1.0);
    }

    // Drop shadows (suppressed in debug mode 2)
    if (should_apply && pixel_alpha > 0.0 && param.PT_SHADOW_OPACITY > 0.0 && param.PT_SHADOW_ENABLE > 0.5 && global.PT_HIDE_CONTENT < 1.5) {
        vec2 shadow_offset = shadow_offset_uv;

        float shadow_strength=cachedShadow(vTexCoord+shadow_offset)*param.PT_SHADOW_OPACITY;

        // Deadzone — suppress faint shadows from near-white pixels
        float deadzone = (1.0 - param.PT_THRESHOLD) * param.PT_SHADOW_OPACITY;
        if (deadzone > 0.001) {
            shadow_strength = smoothstep(0.0, deadzone, shadow_strength) * shadow_strength;
        }

        background.rgb = mix(background.rgb, background.rgb * 0.2, shadow_strength);
    }

    // Background tinting
    if (should_apply && pixel_alpha > 0.0 && global.PT_PALETTE > 0.5) {
        vec3 bg_palette_color = backing_palette;

        vec3 tinted_background = clamp(
                vec3(
                    bg_palette_color.r + mix(-1.0, 1.0, background.r),
                    bg_palette_color.g + mix(-1.0, 1.0, background.g),
                    bg_palette_color.b + mix(-1.0, 1.0, background.b)
                ), 0.0, 1.0
            );

        background.rgb = mix(background.rgb, tinted_background, global.PT_PALETTE_INTENSITY);
    }

    if (should_apply && pixel_alpha > 0.0) {
        output_color.rgb = mix(lcd_color.rgb, background.rgb, pixel_alpha);
    }

    // === Shared post-compositing ===

    // === Polarizer Tint ===
    // Iodine-PVA front polarizer, double-pass tint (set in the vertex stage).
    if (global.PT_POLARIZER > 0.5 && global.PT_POLARIZER_TINT > 0.001) {
        vec3 polarizer = polarizer_color;
        output_color.rgb *= polarizer;
    }

    // Highlight adjustment — positive brightens after compositing (pure visual lift)
    if (global.PT_HIGHLIGHTS > 0.001) {
        float luma = getPerceptualBrightness(output_color.rgb);
        output_color.rgb = clamp(output_color.rgb * (1.0 + global.PT_HIGHLIGHTS * luma), 0.0, 1.0);
    }

    // Saturation
    if (abs(global.PT_SATURATION - 1.0) > 0.001) {
        float luma = getPerceptualBrightness(output_color.rgb);
        output_color.rgb = clamp(mix(vec3(luma), output_color.rgb, global.PT_SATURATION), 0.0, 1.0);
    }

    // Anti-banding dither — breaks up 8-bit quantization artifacts in smooth gradients
    // Leave dither to the final light pass when used in the split Shimmer pipeline.

    FragColor = output_color;
    return true;
}
