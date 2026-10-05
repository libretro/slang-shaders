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
                          |_|     SUNLIGHT SHIMMER EDITION  |___/
    v2.3 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.

    With no backlight, the original devices didn't render white pixels. Light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.

    SUNLIGHT SHIMMER EDITION: Light and shadows move with your device!
    Tilt your device and shadows shift with it. Glare sweeps across your screen. And just like the
    Game Boy Color in sunlight, you see a brilliant rainbow shimmer in the background.

    Just append the preset to your favorite LCD shader as the last pass to reduce eye strain and maximize nostalgia.

*/

#pragma parameter PT_ENABLE 			"=== Pixel Transparency v2.3 === (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_HIDE_CONTENT 		" *  Append to any LCD shader as last pass. Try with GBC & GBA." 0.0 0.0 2.0 1.0
#pragma parameter PT_BRIGHTNESS_MODE 	"      • Brightness mode (Simple / Natural)" 1.0 0.0 1.0 1.0
#pragma parameter PT_ACCEL_ENABLE 		"== MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_ACCEL_SENSITIVITY 	"      • Tilt sensitivity" 1.0 0.1 5.0 0.05

#pragma parameter PT_RAINBOW_COLORS 	"      • Rainbow colors (3=Fast, 7=Full)" 7.0 3.0 7.0 2.0

#pragma parameter PT_SUNLIGHT_ENABLE 	"== SUNLIGHT SHIMMER == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GLARE_ENABLE 		"      • Glare (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_GLARE_INTENSITY 	"         ↳ Strength" 0.15 0.0 1.0 0.05
#pragma parameter PT_GLARE_SIZE			"         ↳ Spread" 0.25 0.05 1.0 0.05
#pragma parameter PT_RAINBOW_ENABLE 	"      • Rainbow shimmer (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter PT_RAINBOW_INTENSITY 	"         ↳ Intensity" 0.18 0.0 1.0 0.01
#pragma parameter PT_FILM_TUNING 		"         ↳ Color shift" 1.0 0.5 2.0 0.05
#pragma parameter PT_LIGHT_SPREAD 		"         ↳ Band density" 1.8 0.5 4.0 0.1
#pragma parameter PT_FILM_NOISE 		"         ↳ Film splotchiness" 0.5 0.0 1.0 0.05
#pragma parameter PT_FILM_SCALE 		"         ↳ Splotch size" 0.6 0.1 3.0 0.05
#pragma parameter PT_REFLECT_ENABLE     "      • Reflection (OFF/ON)" 0.0 0.0 1.0 1.0
#pragma parameter PT_REFLECT_INTENSITY  "         ↳ Strength" 0.08 0.0 0.5 0.01
#pragma parameter PT_REFLECT_SPREAD     "         ↳ Spread (lower = sharper)" 0.6 0.1 1.0 0.05
#pragma parameter PT_REFLECT_BIAS       "         ↳ Ambient floor" 0.02 0.0 0.2 0.005
#pragma parameter PT_REFLECT_WARM       "         ↳ Warm tint" 0.3 0.0 1.0 0.05
#pragma parameter PT_LIGHT_HEIGHT 		"      • Light source distance (0=Flat, 1=Far)" 0.0 0.0 1.0 0.05
#pragma parameter PT_LIGHT_RANGE 		"         ↳ Tilt range" 0.6 0.0 2.0 0.05
#pragma parameter PT_LIGHT_X 			"         ↳ X" 0.5 -1.0 2.0 0.01
#pragma parameter PT_LIGHT_Y 			"         ↳ Y" 0.5 -1.0 2.0 0.01

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    // Frequently accessed fragment-stage parameters
    float PT_ENABLE;
    float PT_BRIGHTNESS_MODE;
    float PT_RAINBOW_ENABLE;
    float PT_GLARE_ENABLE;
    // Vertex-stage light-position parameters
    float PT_LIGHT_RANGE;
    float PT_LIGHT_X;
    float PT_LIGHT_Y;
    float PT_ACCEL_ENABLE;
    float PT_ACCEL_SENSITIVITY;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
    // Remaining parameters
    float PT_RAINBOW_COLORS;
    float PT_HIDE_CONTENT;
    float PT_SUNLIGHT_ENABLE;
    float PT_GLARE_INTENSITY;
    float PT_GLARE_SIZE;
    float PT_REFLECT_ENABLE;
    float PT_REFLECT_INTENSITY;
    float PT_REFLECT_SPREAD;
    float PT_REFLECT_BIAS;
    float PT_REFLECT_WARM;
    float PT_RAINBOW_INTENSITY;
    float PT_FILM_TUNING;
    float PT_LIGHT_SPREAD;
    float PT_FILM_NOISE;
    float PT_FILM_SCALE;
    float PT_LIGHT_HEIGHT;
} global;


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 light_pos;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    // Compute final light position (static + motion tilt)
    light_pos = vec2(param.PT_LIGHT_X, param.PT_LIGHT_Y);
    // Light position: X/Y sets the fixed light position, motion adds tilt offset
    #ifdef _HAS_SENSOR_UNIFORMS
    if (param.PT_ACCEL_ENABLE > 0.5) {
        vec3 accel = global.Accelerometer;
        float magnitude = length(accel);
        if (magnitude > 0.01) {
            vec2 gravity = clamp(vec2(-accel.x, accel.y) / magnitude * param.PT_ACCEL_SENSITIVITY,
                                 vec2(-1.0), vec2(1.0));
            light_pos += vec2(gravity.x, -gravity.y) * param.PT_LIGHT_RANGE;
        }
    }
    #endif
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 light_pos;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Pixel_Transparency;
layout(set = 0, binding = 3) uniform sampler2D Original;
layout(set = 0, binding = 4) uniform sampler2D FilmNoiseCache;

float getPerceptualBrightness(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float getBrightness(vec3 color) {
    if (param.PT_BRIGHTNESS_MODE < 0.5) {
        return (color.r + color.g + color.b) / 3.0;
    } else {
        return getPerceptualBrightness(color);
    }
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Smooth interpolated noise — neighboring pixels blend smoothly between
// hash values at grid corners. Produces broad, gradual spatial variation
// matching real QWP film manufacturing thickness gradients.
//
// The 128x128 cache stores the four exact procedural hash values for each lattice cell.
// Interpolation remains at output resolution; out-of-range cells use the original direct hashes.
float smoothValueCached(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep interpolation

    ivec2 cell = ivec2(i);
    ivec2 size = textureSize(FilmNoiseCache, 0);
    vec4 corners;
    if (all(greaterThanEqual(cell, ivec2(0))) && all(lessThan(cell, size))) {
        corners = texelFetch(FilmNoiseCache, cell, 0);
    } else {
        corners = vec4(hash(i), hash(i + vec2(1.0, 0.0)),
                       hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)));
    }

    return mix(mix(corners.x, corners.y, f.x), mix(corners.z, corners.w, f.x), f.y);
}

float filmNoise(vec2 uv, float scale) {
    vec2 p = uv * scale * 8.0;
    float n = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 3; i++) {
        n += smoothValueCached(p * frequency) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return n;
}


// GBC Quarter-Wave Plate (QWP) chromatic dispersion model.
// Computes the spectral reflectance tint caused by the rear circular polarizer's
// QWP film. The film provides exact lambda/4 phase shift at its design wavelength
// (~550nm) but chromatic mismatch at other wavelengths causes angle-dependent
// spectral leakage — the rainbow seen on GBC screens in sunlight.
//
// Uses cos²(4π·γ/λ) — warm, vivid rainbow with rich color cycling.
// Wavelength count supports 3/5/7 samples. 7 preserves the original path exactly.
// Returns a normalized RGB tint (peak channel = 1.0).
vec3 qwpSpectralTint(float gamma_eff, float wavelengths) {
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
    if (wavelengths > 6.5) {
        float c0 = cos(k0 * gamma_eff); tint += s0 * c0 * c0;
        float c1 = cos(k1 * gamma_eff); tint += s1 * c1 * c1;
        float c2 = cos(k2 * gamma_eff); tint += s2 * c2 * c2;
        float c3 = cos(k3 * gamma_eff); tint += s3 * c3 * c3;
        float c4 = cos(k4 * gamma_eff); tint += s4 * c4 * c4;
        float c5 = cos(k5 * gamma_eff); tint += s5 * c5 * c5;
        float c6 = cos(k6 * gamma_eff); tint += s6 * c6 * c6;
    } else {
        float c1 = cos(k1 * gamma_eff); tint += s1 * c1 * c1;
        float c3 = cos(k3 * gamma_eff); tint += s3 * c3 * c3;
        float c5 = cos(k5 * gamma_eff); tint += s5 * c5 * c5;

        if (wavelengths > 4.5) {
            float c2 = cos(k2 * gamma_eff); tint += s2 * c2 * c2;
            float c4 = cos(k4 * gamma_eff); tint += s4 * c4 * c4;
        }
    }

    // Normalize so the peak channel = 1.0
    float peak = max(tint.r, max(tint.g, tint.b));
    if (peak > 0.001) {
        tint /= peak;
    }

    return tint;
}

void main() {
    vec4 output_color = texture(Pixel_Transparency, vTexCoord);
    // Match the original master bypass: no lighting or dither when disabled.
    if (param.PT_ENABLE < 0.5) {
        FragColor = output_color;
        return;
    }
    if (global.PT_SUNLIGHT_ENABLE < 0.5 ||
        (param.PT_RAINBOW_ENABLE < 0.5 && param.PT_GLARE_ENABLE < 0.5 &&
         global.PT_REFLECT_ENABLE < 0.5)) {
        // Keep final dither when the light effects are bypassed.
        output_color.rgb += (hash(gl_FragCoord.xy) - 0.5) / 255.0;
        FragColor = output_color;
        return;
    }
    vec3 original_pixel = global.PT_HIDE_CONTENT > 0.5
        ? vec3(1.0) : texture(Original, vTexCoord).rgb;
    {
        float aspect_ratio = param.OutputSize.x / param.OutputSize.y;
        vec2 to_light = (vTexCoord - light_pos) * vec2(aspect_ratio, 1.0);
        float dist_sq = 0.0;
        if (global.PT_REFLECT_ENABLE > 0.5 || param.PT_GLARE_ENABLE > 0.5) {
            dist_sq = dot(to_light, to_light);
        }

        // Rainbow effect — QWP chromatic dispersion with 3D light source geometry.
        if (param.PT_RAINBOW_ENABLE > 0.5 && global.PT_RAINBOW_INTENSITY > 0.001) {
            float dist_xy = length(to_light);
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

            vec3 tint = qwpSpectralTint(gamma_eff, global.PT_RAINBOW_COLORS);

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

        // Ambient front-surface reflection — broad sheen centered on the light source.
        if (global.PT_REFLECT_ENABLE > 0.5) {
            float spread_sq = global.PT_REFLECT_SPREAD * global.PT_REFLECT_SPREAD;
            float reflect_strength = exp(-dist_sq / (2.0 * spread_sq));
            reflect_strength = reflect_strength * global.PT_REFLECT_INTENSITY + global.PT_REFLECT_BIAS;

            vec3 reflect_color = mix(vec3(1.0), vec3(1.0, 0.95, 0.85), global.PT_REFLECT_WARM);
            output_color.rgb += reflect_color * reflect_strength;
        }

        // Specular glare — soft white hotspot centered on the light source.
        if (param.PT_GLARE_ENABLE > 0.5 && global.PT_GLARE_INTENSITY > 0.001) {
            float size_sq = global.PT_GLARE_SIZE * global.PT_GLARE_SIZE;
            float glare_strength = exp(-dist_sq / (2.0 * size_sq)) * global.PT_GLARE_INTENSITY;

            output_color.rgb = mix(output_color.rgb, vec3(1.0), clamp(glare_strength, 0.0, 0.85));
        }
    }

    // Anti-banding dither runs after light optics, before quantization.
    output_color.rgb += (hash(gl_FragCoord.xy) - 0.5) / 255.0;

    FragColor = output_color;
}