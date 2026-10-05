#version 450

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
                          |_|                               |___/
    v2.3 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.

    With no backlight, the original devices didn't render white pixels. Light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.

    Just append the preset to your favorite LCD shader as the last pass to reduce eye strain and maximize nostalgia.

*/

#pragma name Pixel_Transparency

#pragma parameter PT_ENABLE 			"=== Pixel Transparency v2.3 === (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_HIDE_CONTENT 		" *  Append to any LCD shader as last pass. Try with GBC & GBA." 0.0 0.0 2.0 1.0
#pragma parameter PT_DEFER_DITHER 		" *  Turn ON Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0
#pragma parameter NOTE3 				" *  Motion enabled on latest RetroArch nightly build." 0.0 0.0 1.0 1.0

#pragma parameter SECTION1 				"== COLOR ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PALETTE 			"      • Backing tint (0=OFF, 1/2=Warm, 3/4=Neutral)" 3.0 0.0 4.0 1.0
#pragma parameter PT_PALETTE_INTENSITY 	"         ↳ Intensity" 1.0 0.0 2.0 0.05
#pragma parameter PT_BACKING_BRIGHTNESS "         ↳ Brightness" 0.48 0.20 0.65 0.01
#pragma parameter PT_POLARIZER 			"      • Front polarizer tint (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_POLARIZER_TINT 	"         ↳ Intensity" 1.0 0.0 1.0 0.05
#pragma parameter PT_SATURATION 		"      • Color saturation" 1.0 0.5 1.5 0.05
#pragma parameter PT_HIGHLIGHTS 		"      • Pixel brightness (0=OFF, -Dim / +Bright)" 0.05 -1.0 1.0 0.01

#pragma parameter SECTION2 				"== TRANSPARENCY ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PIXEL_MODE 		"      • Transparent pixels (0=White only, 1=Bright, 2=All)" 1.0 0.0 2.0 1.0
#pragma parameter PT_BASE_ALPHA 		"         ↳ Transparency amount" 0.20 0.0 1.0 0.01
#pragma parameter PT_THRESHOLD 			"      • White pixel detection threshold" 0.90 0.0 1.0 0.01
#pragma parameter PT_WHITE_BOOST 		"      • Boost white pixel transparency (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_WHITE_TRANSPARENCY "         ↳ Boost amount" 0.50 0.0 1.0 0.01
#pragma parameter PT_BRIGHTNESS_MODE 	"      • Brightness mode (Simple / Natural)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GRID_COLOR_MIX 	"      • Grid visibility on color pixels" 0.0 0.0 1.0 0.05
#pragma parameter PT_GRID_WHITE_MIX 	"      • Grid visibility on white pixels" 0.0 0.0 1.0 0.05

#pragma parameter PT_SHADOW_ENABLE 		"== SHADOWS == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_EDGE_ENABLE "      • Screen edge shadow (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MOTION 		"      • Motion (OFF/ON) " 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_MAX_OFFSET	"         ↳ Max offset" 2.50 0.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_X 	"         ↳ Neutral X" 2.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_MOTION_Y 	"         ↳ Neutral Y" 2.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OFFSET_X 	"      • X offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OFFSET_Y 	"      • Y offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OPACITY 	"      • Opacity" 0.50 0.0 1.0 0.01
#pragma parameter PT_SHADOW_BLUR 		"      • Blur" 1.0 0.0 5.0 0.1

#pragma parameter PT_ACCEL_ENABLE 		"== MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_ACCEL_SENSITIVITY 	"      • Tilt sensitivity" 1.0 0.1 5.0 0.05

#pragma parameter SECTION_PERF 			"== PERFORMANCE ==" 0.0 0.0 1.0 1.0
#pragma parameter PT_PAPER_NOISE_FAST 	"      • Background texture (0=Fast, 1=Full)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_FAST_BLUR 	"      • Shadow blur (Fast / Smooth)" 1.0 0.0 1.0 1.0

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
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
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
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 texel;
layout(location = 2) out float shadow_scale_factor;
layout(location = 3) out vec2 shadow_offset_raw;

// Extract tilt as a normalized 2D vector.
// Returns values in -1 to 1 range. Returns vec2(0.0) if input is near-zero.
vec2 getOrientedTilt(vec3 accel) {
    float magnitude = length(accel);
    if (magnitude < 0.01) return vec2(0.0);
    vec3 dir = accel / magnitude;
    return vec2(-dir.x, dir.y);
}

void main() {
    gl_Position = global.MVP * Position;
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
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 texel;
layout(location = 2) in float shadow_scale_factor;
layout(location = 3) in vec2 shadow_offset_raw;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
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

float getShadowCasterStrength(vec2 uv) {
    bool out_of_bounds = any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)));
    if (out_of_bounds) {
        return global.PT_SHADOW_EDGE_ENABLE > 0.5 ? 1.0 : 0.0;
    }
    return 1.0 - getBrightness(texture(Original, uv).rgb);
}

// Merge samples within half-texel cells. Nearest filtering is constant and
// linear filtering is affine along an axis there, so weighted positions
// preserve either sampler's result. Returns positions in xy, weights in zw.
vec4 collapseShadowAxis(vec3 positions, ivec3 cells, float center_weight) {
    float center_in_low = cells.y == cells.x ? 1.0 : 0.0;
    float high_in_low = cells.z == cells.x ? 1.0 : 0.0;
    float low_weight = 1.0 + center_weight * center_in_low + high_in_low;
    float high_weight = center_weight + 2.0 - low_weight;
    float low_position = (positions.x + positions.y * center_weight * center_in_low
                          + positions.z * high_in_low) / low_weight;
    float high_position = (positions.y * center_weight * (1.0 - center_in_low)
                           + positions.z * (1.0 - high_in_low)) / max(high_weight, 1.0);
    return vec4(low_position, high_position, low_weight, high_weight);
}

bool isWhitePixel(vec3 color, float threshold) {
    float brightness = getPerceptualBrightness(color);
    float min_channel = min(min(color.r, color.g), color.b);
    return (brightness > threshold && min_channel > threshold * 0.9);
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


void main() {
    vec4 lcd_color = texture(Source, vTexCoord);

    vec4 output_color = lcd_color;

    if (param.PT_ENABLE < 0.5) {
        FragColor = output_color;
        return;
    }

    vec3 original_pixel = texture(Original, vTexCoord).rgb;

    // Debug: replace game image with white to isolate shader effects
    if (global.PT_HIDE_CONTENT > 0.5) {
        lcd_color = vec4(1.0);
        original_pixel = vec3(1.0);
        output_color = lcd_color;
    }

    // Highlight adjustment — negative dims lcd_color before compositing
    if (global.PT_HIGHLIGHTS < -0.001) {
        float luma = getPerceptualBrightness(lcd_color.rgb);
        lcd_color.rgb *= max(1.0 + global.PT_HIGHLIGHTS * luma, 0.0);
        output_color.rgb = lcd_color.rgb;
    }

    bool current_is_white = isWhitePixel(original_pixel, param.PT_THRESHOLD);
    bool should_apply = (param.PT_PIXEL_MODE < 0.5) ? current_is_white : true;

    // Resolve transparency early so zero grid mix skips LCD brightness work.
    float grid_mix = current_is_white ? global.PT_GRID_WHITE_MIX : global.PT_GRID_COLOR_MIX;
    float pixel_alpha = 0.0;

    if (param.PT_PIXEL_MODE > 0.5 && param.PT_PIXEL_MODE < 1.5) {
        float no_grid_alpha = (param.PT_BASE_ALPHA * getBrightness(original_pixel)) * 2.665;
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
        float no_grid_alpha = (getBrightness(original_pixel) / 3.0) + param.PT_BASE_ALPHA;
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
    if (should_apply) {
        background = vec4(generateProceduralBackground(vTexCoord), 1.0);
    }

    // Drop shadows (suppressed in debug mode 2)
    if (should_apply && param.PT_SHADOW_ENABLE > 0.5 && global.PT_HIDE_CONTENT < 1.5) {
        vec2 shadow_offset = -shadow_offset_raw * shadow_scale_factor * texel;

        float shadow_strength = 0.0;

        if (param.PT_SHADOW_BLUR > 0.1) {
            vec2 blur_dist = param.PT_SHADOW_BLUR * shadow_scale_factor * texel;
            float blurred_shadow = 0.0;

            if (param.PT_SHADOW_FAST_BLUR < 0.5) {
                // 5-tap cross with Gaussian weights: center=4, cardinal=2 (total=12).
                vec2 sample_cells = vec2(textureSize(Original, 0)) * 2.0;
                vec2 center = vTexCoord + shadow_offset;
                ivec2 low = ivec2(floor((center - blur_dist) * sample_cells));
                ivec2 middle = ivec2(floor(center * sample_cells));
                ivec2 high = ivec2(floor((center + blur_dist) * sample_cells));
                if (all(lessThanEqual(high - low, ivec2(1)))) {
                    // Split the center weight between the two axes, retaining
                    // the 4:2:2:2:2 cross while honoring Original's filtering.
                    vec4 horizontal = collapseShadowAxis(
                        vec3(center.x - blur_dist.x, center.x, center.x + blur_dist.x),
                        ivec3(low.x, middle.x, high.x), 1.0);
                    vec4 vertical = collapseShadowAxis(
                        vec3(center.y - blur_dist.y, center.y, center.y + blur_dist.y),
                        ivec3(low.y, middle.y, high.y), 1.0);
                    blurred_shadow = 2.0 * (
                        getShadowCasterStrength(vec2(horizontal.x, center.y)) * horizontal.z +
                        getShadowCasterStrength(vec2(horizontal.y, center.y)) * horizontal.w +
                        getShadowCasterStrength(vec2(center.x, vertical.x)) * vertical.z +
                        getShadowCasterStrength(vec2(center.x, vertical.y)) * vertical.w);
                } else {
                    vec2 sample_offsets[5] = vec2[](
                            vec2(0.0, 0.0),
                            vec2(-1.0, 0.0),
                            vec2(1.0, 0.0),
                            vec2(0.0, -1.0),
                            vec2(0.0, 1.0)
                    );
                    for (int i = 0; i < 5; i++) {
                        vec2 sample_pos = vTexCoord + shadow_offset + (sample_offsets[i] * blur_dist);
                        float w = (i == 0) ? 4.0 : 2.0;
                        blurred_shadow += getShadowCasterStrength(sample_pos) * w;
                    }
                }
                shadow_strength = (blurred_shadow / 12.0) * param.PT_SHADOW_OPACITY;
            } else {
                vec2 sample_cells = vec2(textureSize(Original, 0)) * 2.0;
                vec2 center = vTexCoord + shadow_offset;
                ivec2 low = ivec2(floor((center - blur_dist) * sample_cells));
                ivec2 middle = ivec2(floor(center * sample_cells));
                ivec2 high = ivec2(floor((center + blur_dist) * sample_cells));
                if (all(lessThanEqual(high - low, ivec2(1)))) {
                    // The separable 1:2:1 weights retain the full 3x3 kernel.
                    vec4 horizontal = collapseShadowAxis(
                        vec3(center.x - blur_dist.x, center.x, center.x + blur_dist.x),
                        ivec3(low.x, middle.x, high.x), 2.0);
                    vec4 vertical = collapseShadowAxis(
                        vec3(center.y - blur_dist.y, center.y, center.y + blur_dist.y),
                        ivec3(low.y, middle.y, high.y), 2.0);
                    blurred_shadow =
                        getShadowCasterStrength(vec2(horizontal.x, vertical.x)) * horizontal.z * vertical.z +
                        getShadowCasterStrength(vec2(horizontal.y, vertical.x)) * horizontal.w * vertical.z +
                        getShadowCasterStrength(vec2(horizontal.x, vertical.y)) * horizontal.z * vertical.w +
                        getShadowCasterStrength(vec2(horizontal.y, vertical.y)) * horizontal.w * vertical.w;
                } else {
                    // Full 3x3 grid with Gaussian weights: center=4, edge=2, corner=1 (total=16)
                    vec2 sample_offsets[9] = vec2[](
                            vec2(0.0, 0.0),
                            vec2(-1.0, 0.0),
                            vec2(1.0, 0.0),
                            vec2(0.0, -1.0),
                            vec2(0.0, 1.0),
                            vec2(-1.0, -1.0),
                            vec2(1.0, -1.0),
                            vec2(-1.0, 1.0),
                            vec2(1.0, 1.0)
                    );
                    for (int i = 0; i < 9; i++) {
                        vec2 sample_pos = vTexCoord + shadow_offset + (sample_offsets[i] * blur_dist);
                        float w = (i == 0) ? 4.0 : (i < 5 ? 2.0 : 1.0);
                        blurred_shadow += getShadowCasterStrength(sample_pos) * w;
                    }
                }
                shadow_strength = (blurred_shadow / 16.0) * param.PT_SHADOW_OPACITY;
            }
        } else {
            shadow_strength = getShadowCasterStrength(vTexCoord + shadow_offset) * param.PT_SHADOW_OPACITY;
        }

        // Deadzone — suppress faint shadows from near-white pixels
        float deadzone = (1.0 - param.PT_THRESHOLD) * param.PT_SHADOW_OPACITY;
        if (deadzone > 0.001) {
            shadow_strength = smoothstep(0.0, deadzone, shadow_strength) * shadow_strength;
        }

        background.rgb = mix(background.rgb, background.rgb * 0.2, shadow_strength);
    }

    // Background tinting
    if (should_apply && global.PT_PALETTE > 0.5) {
        vec3 bg_palette_color;

        if (global.PT_PALETTE < 1.5) {
            bg_palette_color = vec3(0.651, 0.675, 0.518); // Warm1
        } else if (global.PT_PALETTE < 2.5) {
            bg_palette_color = vec3(0.72, 0.73, 0.66); // Warm2
        } else if (global.PT_PALETTE < 3.5) {
            bg_palette_color = vec3(0.766, 0.73, 0.763); // Neutral
        } else {
            bg_palette_color = vec3(0.76); // Aluminum (spectrally neutral)
        }

        // Normalize brightness across palette modes (match Warm1's max channel)
        float max_ch = max(bg_palette_color.r, max(bg_palette_color.g, bg_palette_color.b));
        bg_palette_color *= 0.675 / max_ch;

        vec3 tinted_background = clamp(
                vec3(
                    bg_palette_color.r + mix(-1.0, 1.0, background.r),
                    bg_palette_color.g + mix(-1.0, 1.0, background.g),
                    bg_palette_color.b + mix(-1.0, 1.0, background.b)
                ), 0.0, 1.0
            );

        background.rgb = mix(background.rgb, tinted_background, global.PT_PALETTE_INTENSITY);
    }

    if (should_apply) {
        output_color.rgb = mix(lcd_color.rgb, background.rgb, pixel_alpha);
    }

    // === Shared post-compositing ===

    // === Polarizer Tint ===
    // Iodine-PVA front polarizer — double-pass (0.94, 1.0, 0.865) for reflective display.
    // Light passes through the polarizer twice (in and out), so values are squared from
    // single-pass (0.97, 1.0, 0.93).
    if (global.PT_POLARIZER > 0.5 && global.PT_POLARIZER_TINT > 0.001) {
        vec3 polarizer = mix(vec3(1.0), vec3(0.94, 1.0, 0.865), global.PT_POLARIZER_TINT);
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
    if (param.PT_DEFER_DITHER < 0.5) {
        output_color.rgb += (hash(gl_FragCoord.xy) - 0.5) / 255.0;
    }

    FragColor = output_color;
}