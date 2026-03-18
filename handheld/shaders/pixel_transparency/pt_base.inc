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
                          |_|                BASE #INCLUDE  |___/
    v2.1 by mattakins
    Copyright (C) 2025 Matt Akins.

    Expects before #include:

    - #define PT_SHIMMER (sunlight_shimmer.slang only — enables light_pos varying)
    - push_constant 'param' with shared members
    - UBO 'global' with shared members

    Fragment main() is left OPEN — the including file must close it.

*/

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 texel;
layout(location = 2) out float shadow_scale_factor;
layout(location = 3) out vec2 shadow_offset_raw;
#ifdef PT_SHIMMER
layout(location = 4) out vec2 light_pos;
#endif

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
    texel = param.SourceSize.zw;

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
            if (param.PT_ACCEL_RELATIVE > 0.5) {
                // Relative: normalize both, subtract — same scale as "from level"
                vec3 rest = global.AccelerometerRest;
                gravity = clamp(getOrientedTilt(accel) - getOrientedTilt(rest), vec2(-1.0), vec2(1.0));
            } else {
                gravity = getOrientedTilt(accel);
            }

            gravity = clamp(gravity * param.PT_ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));
        }
    }
    #endif

    #ifdef PT_SHIMMER
    // Light position: X/Y sets the fixed light position, motion adds tilt offset
    if (param.PT_RAINBOW_ENABLE > 0.5 || param.PT_GLARE_ENABLE > 0.5) {
        light_pos = vec2(param.PT_LIGHT_X, param.PT_LIGHT_Y);
        if (param.PT_ACCEL_ENABLE > 0.5 && has_sensors) {
            light_pos += vec2(gravity.x, -gravity.y) * param.PT_LIGHT_RANGE;
        }
    } else {
        light_pos = vec2(0.5, 0.5);
    }
    #endif

    // Shadow offset — motion centers on motion neutral X/Y, static uses offset X/Y
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
#ifdef PT_SHIMMER
layout(location = 4) in vec2 light_pos;
#endif
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

#ifdef PT_SHIMMER
// Smooth interpolated noise — neighboring pixels blend smoothly between
// hash values at grid corners. Produces broad, gradual spatial variation
// matching real QWP film manufacturing thickness gradients.
float smoothValue(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep interpolation

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float filmNoise(vec2 uv, float scale) {
    vec2 p = uv * scale * 8.0;
    float n = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 3; i++) {
        n += smoothValue(p * frequency) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return n;
}
#endif

vec3 generateProceduralBackground(vec2 uv) {
    vec3 baseColor = vec3(global.PT_BACKING_BRIGHTNESS);
    const float grainIntensity = 0.065;
    const float scale = 0.25;
    float grain = paperNoise(uv, scale);
    float grainOffset = (grain - 0.4375) * grainIntensity;
    return baseColor + vec3(grainOffset);
}

#ifdef PT_SHIMMER
// GBC Quarter-Wave Plate (QWP) chromatic dispersion model.
// Computes the spectral reflectance tint caused by the rear circular polarizer's
// QWP film. The film provides exact lambda/4 phase shift at its design wavelength
// (~550nm) but chromatic mismatch at other wavelengths causes angle-dependent
// spectral leakage — the rainbow seen on GBC screens in sunlight.
//
// Uses cos²(4π·γ/λ) — warm, vivid rainbow with rich color cycling.
// Returns a normalized RGB tint (peak channel = 1.0).
vec3 qwpSpectralTint(float gamma_eff) {
    vec3 tint = vec3(0.0);

    // 7 wavelengths with pre-computed spectral colors and phase factors (4π/λ)
    const vec3 s0 = vec3(0.000000, 0.000000, 0.026075); // 400.0nm
    const vec3 s1 = vec3(0.141223, 0.000000, 0.368894); // 442.9nm
    const vec3 s2 = vec3(0.000000, 0.480861, 0.473477); // 485.7nm
    const vec3 s3 = vec3(0.081095, 0.812848, 0.339825); // 528.6nm
    const vec3 s4 = vec3(0.783356, 0.793891, 0.134941); // 571.4nm
    const vec3 s5 = vec3(0.972432, 0.423991, 0.215476); // 614.3nm
    const vec3 s6 = vec3(0.648322, 0.114430, 0.000000); // 657.1nm
    const float k0 = 0.031415927; // 4π / 400.000
    const float k1 = 0.028399638; // 4π / 442.857
    const float k2 = 0.025874228; // 4π / 485.714
    const float k3 = 0.023809524; // 4π / 528.571
    const float k4 = 0.021991149; // 4π / 571.429
    const float k5 = 0.020462441; // 4π / 614.286
    const float k6 = 0.019138570; // 4π / 657.143
    float c0 = cos(k0 * gamma_eff); tint += s0 * c0 * c0;
    float c1 = cos(k1 * gamma_eff); tint += s1 * c1 * c1;
    float c2 = cos(k2 * gamma_eff); tint += s2 * c2 * c2;
    float c3 = cos(k3 * gamma_eff); tint += s3 * c3 * c3;
    float c4 = cos(k4 * gamma_eff); tint += s4 * c4 * c4;
    float c5 = cos(k5 * gamma_eff); tint += s5 * c5 * c5;
    float c6 = cos(k6 * gamma_eff); tint += s6 * c6 * c6;

    // Normalize so the peak channel = 1.0
    float peak = max(tint.r, max(tint.g, tint.b));
    if (peak > 0.001) {
        tint /= peak;
    }

    return tint;
}
#endif

void main() {
    vec4 lcd_color = texture(Source, vTexCoord);
    vec3 original_pixel = texture(Original, vTexCoord).rgb;

    vec4 output_color = lcd_color;

    if (param.PT_ENABLE < 0.5) {
        FragColor = output_color;
        return;
    }

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
    }

    bool current_is_white = isWhitePixel(original_pixel, param.PT_THRESHOLD);

    vec4 background = vec4(generateProceduralBackground(vTexCoord), 1.0);

    // Drop shadows (suppressed in debug mode 2)
    if (param.PT_SHADOW_ENABLE > 0.5 && global.PT_HIDE_CONTENT < 1.5) {
        vec2 shadow_offset = -shadow_offset_raw * shadow_scale_factor * texel;

        vec3 center_source = texture(Original, vTexCoord + shadow_offset).rgb;
        float shadow_strength = 0.0;

        if (param.PT_SHADOW_BLUR > 0.1) {
            vec2 blur_dist = param.PT_SHADOW_BLUR * shadow_scale_factor * texel;
            float blurred_shadow = 0.0;

            if (param.PT_SHADOW_FAST_BLUR < 0.5) {
                // 5-tap cross with Gaussian weights: center=4, cardinal=2 (total=12)
                vec2 sample_offsets[5] = vec2[](
                        vec2(0.0, 0.0),
                        vec2(-1.0, 0.0),
                        vec2(1.0, 0.0),
                        vec2(0.0, -1.0),
                        vec2(0.0, 1.0)
                    );
                for (int i = 0; i < 5; i++) {
                    vec2 sample_pos = vTexCoord + shadow_offset + (sample_offsets[i] * blur_dist);
                    vec3 blur_sample = texture(Original, sample_pos).rgb;
                    float w = (i == 0) ? 4.0 : 2.0;
                    float blur_brightness = getBrightness(blur_sample);
                    blurred_shadow += (1.0 - blur_brightness) * w;
                }
                shadow_strength = (blurred_shadow / 12.0) * param.PT_SHADOW_OPACITY;
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
                    vec3 blur_sample = texture(Original, sample_pos).rgb;
                    float w = (i == 0) ? 4.0 : (i < 5 ? 2.0 : 1.0);
                    float blur_brightness = getBrightness(blur_sample);
                    blurred_shadow += (1.0 - blur_brightness) * w;
                }
                shadow_strength = (blurred_shadow / 16.0) * param.PT_SHADOW_OPACITY;
            }
        } else {
            float shadow_source_brightness = getBrightness(center_source);
            shadow_strength = (1.0 - shadow_source_brightness) * param.PT_SHADOW_OPACITY;
        }

        // Deadzone — suppress faint shadows from near-white pixels
        float deadzone = (1.0 - param.PT_THRESHOLD) * param.PT_SHADOW_OPACITY;
        if (deadzone > 0.001) {
            shadow_strength = smoothstep(0.0, deadzone, shadow_strength) * shadow_strength;
        }

        background.rgb = mix(background.rgb, background.rgb * 0.2, shadow_strength);
    }

    // Background tinting
    if (global.PT_PALETTE > 0.5) {
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

    // Transparency compositing — gridline intensity
    // 0.0 = OFF: original pixel brightness for all (no grid effect).
    // 0.05 = grid on darks, whites fully bypass. Deadzone via smoothstep(0.05, 1.0).
    // 0.10–0.95 = grid on darks, whites partially blended.
    // 1.0 = full grid on all pixels.
    vec3 brightness_source = original_pixel;
    if (global.PT_BRIGHTNESS_GRID > 0.001) {
        brightness_source = lcd_color.rgb;
        if (current_is_white) {
            float white_blend = smoothstep(0.05, 1.0, global.PT_BRIGHTNESS_GRID);
            brightness_source = mix(original_pixel, lcd_color.rgb, white_blend);
        }
    }

    if (param.PT_PIXEL_MODE > 0.5 && param.PT_PIXEL_MODE < 1.5) {
        float pixel_intensity = getBrightness(brightness_source);
        float transparency = (param.PT_BASE_ALPHA * pixel_intensity) * 2.665;

        if (current_is_white && global.PT_WHITE_BOOST > 0.5) {
            transparency = max(transparency, global.PT_WHITE_TRANSPARENCY);
        }
        transparency = clamp(transparency, 0.0, 1.0);
        output_color.rgb = mix(lcd_color.rgb, background.rgb, transparency);
    } else {
        bool should_apply = (param.PT_PIXEL_MODE < 0.5) ? current_is_white : true;

        if (should_apply) {
            float pixel_intensity = getBrightness(brightness_source);
            float pixel_alpha = (pixel_intensity / 3.0) + param.PT_BASE_ALPHA;

            if (current_is_white && global.PT_WHITE_BOOST > 0.5) {
                pixel_alpha = max(pixel_alpha, global.PT_WHITE_TRANSPARENCY);
            }
            pixel_alpha = clamp(pixel_alpha, 0.0, 1.0);
            output_color.rgb = mix(lcd_color.rgb, background.rgb, pixel_alpha);
        }
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

    // === Sunlight Rainbow & Specular Glare (shimmer only) ===
#ifdef PT_SHIMMER
    if (param.PT_RAINBOW_ENABLE > 0.5 || param.PT_GLARE_ENABLE > 0.5) {
        float aspect_ratio = param.OutputSize.x / param.OutputSize.y;
        vec2 to_light = (vTexCoord - light_pos) * vec2(aspect_ratio, 1.0);
        float dist_xy = length(to_light);

        // Rainbow effect — QWP chromatic dispersion with 3D light source geometry.
        if (param.PT_RAINBOW_ENABLE > 0.5 && global.PT_RAINBOW_INTENSITY > 0.001) {
            const float GAMMA_BASE = 275.0; // Double-pass through 137.5nm QWP film
            const float N_FILM = 1.5; // Stretched polycarbonate

            float gamma_0 = GAMMA_BASE * global.PT_FILM_TUNING;

            // Angle of incidence: height=0 uses flat 2D distance,
            // height>0 uses 3D atan model (physically correct light source geometry)
            float angle_incidence;
            if (global.PT_LIGHT_HEIGHT < 0.01) {
                angle_incidence = dist_xy * global.PT_LIGHT_SPREAD; // Flat
            } else {
                angle_incidence = atan(dist_xy, global.PT_LIGHT_HEIGHT) * global.PT_LIGHT_SPREAD;
            }
            angle_incidence = clamp(angle_incidence, 0.0, 1.4);

            float sin_theta_r = sin(angle_incidence) / N_FILM;
            float cos_theta_r = sqrt(1.0 - sin_theta_r * sin_theta_r);
            float gamma_eff = gamma_0 * cos_theta_r;

            // Film thickness noise — manufacturing variations in the QWP film
            // produce the splotchy, irregular color bands seen on real hardware.
            if (global.PT_FILM_NOISE > 0.001) {
                vec2 noise_uv = vec2(vTexCoord.x * aspect_ratio, vTexCoord.y);
                float noise = filmNoise(noise_uv, global.PT_FILM_SCALE) - 0.4375;
                gamma_eff *= (1.0 + noise * global.PT_FILM_NOISE);
            }

            vec3 tint = qwpSpectralTint(gamma_eff);

            float tint_strength = global.PT_RAINBOW_INTENSITY;

            // Brightness gating — rainbow light double-passes through the LC layer,
            // so dark pixels attenuate the reflection. Linear with 0.03 floor from
            // ~30:1 contrast ratio of reflective TFT.
            float reflectivity = mix(0.03, 1.0, getBrightness(original_pixel));
            tint_strength *= reflectivity;

            // Color filter — rainbow light double-passes through RGB sub-pixel color filters
            // (in and out), so pixel color is squared for physical two-pass attenuation
            tint *= original_pixel * original_pixel;

            // Luminance-preserving tint blend:
            // Multiply by the spectral tint (shifts color), then restore original luminance.
            vec3 tinted = output_color.rgb * mix(vec3(1.0), tint, tint_strength);
            float orig_luma = getPerceptualBrightness(output_color.rgb);
            float tinted_luma = getPerceptualBrightness(tinted);
            if (tinted_luma > 0.001) {
                tinted *= orig_luma / tinted_luma;
            }
            output_color.rgb = tinted;
        }

        // Specular glare — soft white hotspot centered on the light source.
        if (param.PT_GLARE_ENABLE > 0.5 && global.PT_GLARE_INTENSITY > 0.001) {
            float size_sq = global.PT_GLARE_SIZE * global.PT_GLARE_SIZE;
            float glare_strength = exp(-dist_xy * dist_xy / (2.0 * size_sq)) * global.PT_GLARE_INTENSITY;

            output_color.rgb = mix(output_color.rgb, vec3(1.0), clamp(glare_strength, 0.0, 0.85));
        }
    }
#endif

    // Anti-banding dither — breaks up 8-bit quantization artifacts in smooth gradients
    output_color.rgb += (hash(gl_FragCoord.xy) - 0.5) / 255.0;

    // output_color is ready — main() continues in including file