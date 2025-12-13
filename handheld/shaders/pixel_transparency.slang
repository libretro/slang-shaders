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
                          |_|                              |___/
    v1.0 by mattakins
    Copyright (C) 2025 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.
    
    With no backlight, the original devices didn't render white pixels. These light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.
    
    Just append to your favorite LCD shader as the last pass to reduce eye strain and maximize nostalgia.

*/

#pragma parameter PT_ENABLE "=== Pixel Transparency v1.0 === (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter NOTE1 " *  Append to any LCD shader as last pass. Try with GBC & GBA." 0.0 0.0 1.0 1.0
#pragma parameter NOTE2 " *  Turn ON Core > Color Correction & Interframe Blending" 0.0 0.0 1.0 1.0

// Background tint
#pragma parameter PT_PALETTE "== Background tint == (0=OFF, 1=Pocket, 2=Gray, 3=White)" 1.0 0.0 3.0 1.0
#pragma parameter PT_PALETTE_INTENSITY "     ↳ Tint intensity" 1.0 0.0 2.0 0.05

// Transparency
#pragma parameter PT_PIXEL_MODE "== 1. Transparent pixels == (0=White only, 1=Bright, 2=All)" 1.0 0.0 2.0 1.0
#pragma parameter PT_BASE_ALPHA "     ↳ Transparency amount" 0.20 0.0 1.0 0.01
#pragma parameter PT_THRESHOLD "== 2. White pixel detection threshold ==" 0.90 0.0 1.0 0.01
#pragma parameter PT_WHITE_BOOST "== 3. Boost white transparency == (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_WHITE_TRANSPARENCY "     ↳ Boost amount" 0.50 0.0 1.0 0.01

#pragma parameter PT_BRIGHTNESS_MODE "== Brightness mode == (0=Simple, 1=Perceptual)" 1.0 0.0 1.0 1.0

#pragma parameter PT_DARK_FILTER_ENABLE "== Color harshness filter == (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_DARK_FILTER_LEVEL "     ↳ Filter amount" 10.0 0.0 100.0 1.0

// Shadows
#pragma parameter PT_SHADOW_ENABLE "== Drop shadows == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_SHADOW_OFFSET_X "     ↳ Shadow X offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OFFSET_Y "     ↳ Shadow Y offset" 3.0 -30.0 30.0 0.5
#pragma parameter PT_SHADOW_OPACITY "     ↳ Shadow opacity" 0.5 0.0 1.0 0.01
#pragma parameter PT_SHADOW_BLUR "     ↳ Shadow blur amount" 1.0 0.0 5.0 0.1

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float PT_ENABLE;
    float PT_PIXEL_MODE;
    float PT_BRIGHTNESS_MODE;
    float PT_WHITE_BOOST;
    float PT_WHITE_TRANSPARENCY;
    float PT_THRESHOLD;
    float PT_PALETTE;
    float PT_PALETTE_INTENSITY;
    float PT_BASE_ALPHA;
    float PT_DARK_FILTER_ENABLE;
    float PT_DARK_FILTER_LEVEL;
    float PT_SHADOW_ENABLE;
    float PT_SHADOW_OPACITY;
    float PT_SHADOW_OFFSET_X;
    float PT_SHADOW_OFFSET_Y;
    float PT_SHADOW_BLUR;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 texel;
layout(location = 2) out float shadow_scale_factor;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    texel = param.SourceSize.zw;

    // Calculate resolution scale for shadow compensation
    // Reference resolution: 640×480 (shadow offsets tuned for this resolution)
    float scale_x = param.OutputSize.x / 640.0;
    float scale_y = param.OutputSize.y / 480.0;
    shadow_scale_factor = sqrt(scale_x * scale_y);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 texel;
layout(location = 2) in float shadow_scale_factor;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;

// Gambatte luminance constants (ITU-R BT.709 standard)
#define LUMA_R 0.2126
#define LUMA_G 0.7152
#define LUMA_B 0.0722

// Perceptual brightness calculation using Gambatte luminance formula
float getPerceptualBrightness(vec3 color) {
    return (LUMA_R * color.r) + (LUMA_G * color.g) + (LUMA_B * color.b);
}

// Game Boy style RGB calculation (normalized to 0-1 range)
float getGameBoyRGBSum(vec3 color) {
    return (color.r + color.g + color.b) / 3.0;
}

// Unified brightness calculation based on mode parameter
float getBrightness(vec3 color) {
    if (param.PT_BRIGHTNESS_MODE < 0.5) {
        // Mode 0: Game Boy RGB calculation (normalized)
        return getGameBoyRGBSum(color);
    } else {
        // Mode 1: Perceptual calculation (already normalized)
        return getPerceptualBrightness(color);
    }
}

// White pixel detection helper - always use perceptual for threshold comparison
bool isWhitePixel(vec3 color, float threshold) {
    float brightness = getPerceptualBrightness(color);
    float min_channel = min(min(color.r, color.g), color.b);
    return (brightness > threshold && min_channel > threshold * 0.9);
}

// Gambatte darkenRgb function implementation
vec3 darkenRgb(vec3 color, float darkFilterLevel) {
    // Convert dark filter level from [0-100] to [0-1]
    float darkStrength = darkFilterLevel * 0.01;

    // Calculate luminosity using ITU-R BT.709 weights
    float luma = (LUMA_R * color.r) + (LUMA_G * color.g) + (LUMA_B * color.b);

    // Get 'darkness' scaling factor
    // User set 'dark filter' level scaled by current luminosity
    // (lighter colours affected more than darker colours)
    float darkFactor = 1.0 - (darkStrength * luma);
    darkFactor = max(darkFactor, 0.0);

    // Perform scaling
    return color * darkFactor;
}

// Procedural paper grain noise generation
float hash(vec2 p) {
    // High-quality hash for paper grain
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float paperNoise(vec2 uv, float scale) {
    // Multi-octave noise for paper texture
    vec2 p = uv * scale * 512.0; // Scale to approximate texture resolution

    float n = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    // 3 octaves of noise for paper-like grain
    for (int i = 0; i < 3; i++) {
        n += hash(p * frequency) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return n;
}

vec3 generateProceduralBackground(vec2 uv) {
    // Base gray matched to original paper texture (avg brightness 0.474)
    // Grain intensity 0.0135 matches original texture range of 3 RGB values
    const vec3 baseColor = vec3(0.474);
    const float grainIntensity = 0.0135;
    const float scale = 1.0;

    // Generate paper grain
    float grain = paperNoise(uv, scale);

    // Center the noise around 0 and apply intensity
    float grainOffset = (grain - 0.5) * grainIntensity;

    return baseColor + vec3(grainOffset);
}

void main() {
    // Cache texture samples to eliminate redundant reads
    vec4 lcd_color = texture(Source, vTexCoord);
    vec3 original_pixel = texture(Original, vTexCoord).rgb;

    // Apply gambatte luminance filter to LCD content if enabled
    if (param.PT_DARK_FILTER_ENABLE > 0.5) {
        lcd_color.rgb = darkenRgb(lcd_color.rgb, param.PT_DARK_FILTER_LEVEL);
    }

    // Default output is the LCD-processed color (with dark filter applied)
    vec4 output_color = lcd_color;

    // Early exit if shader is disabled - return LCD content only
    if (param.PT_ENABLE < 0.5) {
        FragColor = output_color;
        return;
    }

    // Pre-calculate white detection for current pixel
    bool current_is_white = isWhitePixel(original_pixel, param.PT_THRESHOLD);

    // Generate procedural background
    vec4 background = vec4(generateProceduralBackground(vTexCoord), 1.0);

    // Apply drop shadow to background if enabled (BEFORE tinting)
    if (param.PT_SHADOW_ENABLE > 0.5) {
        // Use static shadow offsets
        vec2 base_offset = vec2(-param.PT_SHADOW_OFFSET_X, -param.PT_SHADOW_OFFSET_Y);
        vec2 shadow_offset = base_offset * shadow_scale_factor * texel;

        // Sample the content at the shadow source position
        vec3 shadow_source = texture(Original, vTexCoord + shadow_offset).rgb;

        // Check if shadow source casts a shadow (only non-white pixels cast shadows)
        bool source_is_white = isWhitePixel(shadow_source, param.PT_THRESHOLD);

        if (!source_is_white) {
            // Create shadow using selected brightness calculation
            float shadow_source_brightness = getBrightness(shadow_source);
            float shadow_strength = (1.0 - shadow_source_brightness) * param.PT_SHADOW_OPACITY;

            // Apply optimized blur to shadow strength if enabled
            if (param.PT_SHADOW_BLUR > 0.1) {
                // Fixed 9-sample pattern for consistent performance
                // Blur distance also normalized to reference resolution
                float blur_distance = param.PT_SHADOW_BLUR * shadow_scale_factor * texel.x;
                vec2 sample_offsets[9] = vec2[](
                    vec2( 0.0,  0.0),  // Center
                    vec2(-1.0,  0.0),  // Left
                    vec2( 1.0,  0.0),  // Right
                    vec2( 0.0, -1.0),  // Up
                    vec2( 0.0,  1.0),  // Down
                    vec2(-1.0, -1.0),  // Top-left
                    vec2( 1.0, -1.0),  // Top-right
                    vec2(-1.0,  1.0),  // Bottom-left
                    vec2( 1.0,  1.0)   // Bottom-right
                );

                float blurred_shadow = 0.0;

                for (int i = 0; i < 9; i++) {
                    vec2 sample_pos = vTexCoord + shadow_offset + (sample_offsets[i] * blur_distance);
                    vec3 blur_sample = texture(Original, sample_pos).rgb;
                    float blur_brightness = getBrightness(blur_sample);
                    blurred_shadow += (1.0 - blur_brightness);
                }

                shadow_strength = (blurred_shadow / 9.0) * param.PT_SHADOW_OPACITY;
            }

            // Apply shadow to background (BEFORE tinting)
            background.rgb = mix(background.rgb, background.rgb * 0.2, shadow_strength);
        }
    }

    // Apply hardcoded background tint if enabled (AFTER shadows)
    if (param.PT_PALETTE > 0.5) {
        vec3 bg_palette_color;

        if (param.PT_PALETTE < 1.5) {
            bg_palette_color = vec3(0.651, 0.675, 0.518); // 1: #A6AC84
        } else if (param.PT_PALETTE < 2.5) {
            bg_palette_color = vec3(0.737, 0.737, 0.737); // 2: #BCBCBC
        } else {
            bg_palette_color = vec3(1.0, 1.0, 1.0); // 3: #FFFFFF
        }

        vec3 tinted_background = clamp(
            vec3(
                bg_palette_color.r + mix(-1.0, 1.0, background.r),
                bg_palette_color.g + mix(-1.0, 1.0, background.g),
                bg_palette_color.b + mix(-1.0, 1.0, background.b)
            ), 0.0, 1.0
        );

        // Mix between original and tinted based on intensity
        background.rgb = mix(background.rgb, tinted_background, param.PT_PALETTE_INTENSITY);
    }

    // PIXEL MODE TOGGLE: Choose between different transparency modes
    if (param.PT_PIXEL_MODE > 0.5 && param.PT_PIXEL_MODE < 1.5) {
        // === MODE 1: BRIGHT PIXEL TRANSPARENCY (different formula) ===
        float pixel_intensity = getBrightness(lcd_color.rgb);
        // Scale to match Mode 0/2 behavior: 0.20 BASE → 0.533 transparency
        float transparency = (param.PT_BASE_ALPHA * pixel_intensity) * 2.665;

        if (current_is_white && param.PT_WHITE_BOOST > 0.5) {
            transparency = max(transparency, param.PT_WHITE_TRANSPARENCY);
        }
        transparency = clamp(transparency, 0.0, 1.0);
        output_color.rgb = mix(lcd_color.rgb, background.rgb, transparency);
    } else {
        // === MODE 0 (White only) / MODE 2 (All) - same formula ===
        bool should_apply = (param.PT_PIXEL_MODE < 0.5) ? current_is_white : true;

        if (should_apply) {
            float pixel_intensity = getBrightness(lcd_color.rgb);
            float pixel_alpha = (pixel_intensity / 3.0) + param.PT_BASE_ALPHA;

            if (current_is_white && param.PT_WHITE_BOOST > 0.5) {
                pixel_alpha = max(pixel_alpha, param.PT_WHITE_TRANSPARENCY);
            }
            pixel_alpha = clamp(pixel_alpha, 0.0, 1.0);
            output_color.rgb = mix(lcd_color.rgb, background.rgb, pixel_alpha);
        }
    }

    FragColor = output_color;
}