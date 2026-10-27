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
                          |_|                  LIGHT CACHE  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Generates the smooth sunlight rainbow and glare field.
    Sunlight Shimmer only; the preset uses a 256 x 256 floating-point texture.

*/

// Interpolate the optical field; game and LCD detail remain at output resolution.
#include "pt-params.inc"
#include "pt-params-sunlight.inc"
#pragma name LightField
#pragma format R16G16B16A16_SFLOAT

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

// The light field is sized to the LCD framebuffer, which matches the final viewport.
#define PT_LIGHT_VIEWPORT LCDInputSize

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 PT_LIGHT_VIEWPORT;
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
layout(location = 1) flat out vec2 light_pos;

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
layout(location = 1) flat in vec2 light_pos;
layout(location = 0) out vec4 FragColor;


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
    vec2 field_uv=(vTexCoord*param.OutputSize.xy-vec2(0.5))/(param.OutputSize.xy-vec2(1.0));
    vec3 tint=vec3(1.0);
    float glare=0.0;
    if (param.PT_ENABLE >= 0.5 && global.PT_SUNLIGHT_ENABLE >= 0.5) {
        float aspect_ratio=global.PT_LIGHT_VIEWPORT.x/global.PT_LIGHT_VIEWPORT.y;
        vec2 to_light=(field_uv-light_pos)*vec2(aspect_ratio,1.0);
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
                vec2 noise_uv = vec2(field_uv.x * aspect_ratio, field_uv.y);
                float noise = filmNoise(noise_uv, global.PT_FILM_SCALE) - 0.4375;
                gamma_eff *= (1.0 + noise * global.PT_FILM_NOISE);
            }

            tint = qwpSpectralTint(gamma_eff, global.PT_RAINBOW_COLORS);

        }
        if (param.PT_GLARE_ENABLE > 0.5 && global.PT_GLARE_INTENSITY > 0.001) {
            float size_sq=global.PT_GLARE_SIZE*global.PT_GLARE_SIZE;
            glare=exp(-dot(to_light,to_light)/(2.0*size_sq))*global.PT_GLARE_INTENSITY;
        }
    }
    FragColor=vec4(tint,glare);
}
