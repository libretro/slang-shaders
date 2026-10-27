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
                          |_|                 SHADOW CACHE  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Builds the source-cell shadow cache before LCD rendering.

*/

#include "pt-params.inc"

// Cache a source-cell window around the current offset, including screen edges.
#pragma name PixelShadowCache
#pragma format R32G32B32A32_SFLOAT

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 OriginalSize;
    vec4 FinalViewportSize;
#ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
#endif
    float PT_BRIGHTNESS_MODE;
    float PT_SHADOW_EDGE_ENABLE;
    float PT_SHADOW_FAST_BLUR;
    float PT_SHADOW_BLUR;
} global;
layout(push_constant) uniform Push {
    vec4 OutputSize;
    float PT_ACCEL_ENABLE;
    float PT_ACCEL_SENSITIVITY;
    float PT_SHADOW_MOTION;
    float PT_SHADOW_MAX_OFFSET;
    float PT_SHADOW_MOTION_X;
    float PT_SHADOW_MOTION_Y;
    float PT_SHADOW_OFFSET_X;
    float PT_SHADOW_OFFSET_Y;
} param;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) flat out ivec2 shadow_origin;
layout(location = 2) flat out precise vec2 native_radius;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    vec2 offset = vec2(param.PT_SHADOW_OFFSET_X, param.PT_SHADOW_OFFSET_Y);
#ifdef _HAS_SENSOR_UNIFORMS
    if (param.PT_ACCEL_ENABLE > 0.5 && param.PT_SHADOW_MOTION > 0.5) {
        float magnitude = length(global.Accelerometer);
        if (magnitude > 0.01) {
            vec2 gravity = clamp(vec2(-global.Accelerometer.x, global.Accelerometer.y)
                / magnitude * param.PT_ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));
            offset = vec2(param.PT_SHADOW_MOTION_X, param.PT_SHADOW_MOTION_Y)
                + gravity * param.PT_SHADOW_MAX_OFFSET;
        }
    }
#endif
    float scale = sqrt((global.FinalViewportSize.x / 640.0)
        * (global.FinalViewportSize.y / 480.0));
    vec2 native_offset = -offset * scale * global.FinalViewportSize.zw * global.OriginalSize.xy;
    shadow_origin = ivec2(floor(native_offset));
    native_radius = global.PT_SHADOW_BLUR > 0.1
        ? global.PT_SHADOW_BLUR * scale * global.FinalViewportSize.zw * global.OriginalSize.xy
        : vec2(0.0);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) flat in ivec2 shadow_origin;
layout(location = 2) flat in vec2 native_radius;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Original;
// Shared nearest-filtered kernel for cached cells and samples outside the image.
float adaptiveShadowCaster(ivec2 cell, ivec2 size) {
    if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, size)))
        return global.PT_SHADOW_EDGE_ENABLE > 0.5 ? 1.0 : 0.0;
    vec3 color = texelFetch(Original, cell, 0).rgb;
    float brightness = global.PT_BRIGHTNESS_MODE < 0.5
        ? (color.r + color.g + color.b) / 3.0
        : (0.2126 * color.r) + (0.7152 * color.g) + (0.0722 * color.b);
    return 1.0 - brightness;
}

float adaptiveShadowKernel(vec2 native, vec2 radius, ivec2 size) {
    if (global.PT_SHADOW_BLUR <= 0.1)
        return adaptiveShadowCaster(ivec2(floor(native)), size);
    // Fast blur: 5-tap cross, Gaussian weights center=4, cardinal=2 (total 12).
    float value = adaptiveShadowCaster(ivec2(floor(native)), size) * 4.0;
    value += adaptiveShadowCaster(ivec2(floor(native - vec2(radius.x, 0.0))), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(floor(native + vec2(radius.x, 0.0))), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(floor(native - vec2(0.0, radius.y))), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(floor(native + vec2(0.0, radius.y))), size) * 2.0;
    if (global.PT_SHADOW_FAST_BLUR < 0.5) return value / 12.0;
    // Smooth blur: full 3x3 grid, center=4, edge=2, corner=1 (total 16).
    value += adaptiveShadowCaster(ivec2(floor(native - radius)), size);
    value += adaptiveShadowCaster(ivec2(floor(native + vec2(radius.x, -radius.y))), size);
    value += adaptiveShadowCaster(ivec2(floor(native + vec2(-radius.x, radius.y))), size);
    value += adaptiveShadowCaster(ivec2(floor(native + radius)), size);
    return value / 16.0;
}


// Integer tap positions keep very narrow phase intervals stable at large sizes.
float shadowPhase(ivec2 cell, ivec2 phase, ivec2 size) {
    ivec2 whole = ivec2(floor(native_radius));
    bvec2 lower_first = lessThanEqual(fract(native_radius), vec2(0.5));
    ivec2 lower_cross = ivec2(greaterThanEqual(phase, ivec2(2)))
        + ivec2(equal(phase, ivec2(1))) * ivec2(lower_first);
    ivec2 upper_cross = ivec2(greaterThanEqual(phase, ivec2(2)))
        + ivec2(equal(phase, ivec2(1))) * (ivec2(1) - ivec2(lower_first));
    ivec2 low = cell - whole - ivec2(1) + lower_cross;
    ivec2 high = cell + whole + upper_cross;
    // Fast blur: 5-tap cross, Gaussian weights center=4, cardinal=2 (total 12).
    float value = adaptiveShadowCaster(cell, size) * 4.0;
    value += adaptiveShadowCaster(ivec2(low.x, cell.y), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(high.x, cell.y), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(cell.x, low.y), size) * 2.0;
    value += adaptiveShadowCaster(ivec2(cell.x, high.y), size) * 2.0;
    if (global.PT_SHADOW_FAST_BLUR < 0.5) return value / 12.0;
    // Smooth blur: full 3x3 grid, center=4, edge=2, corner=1 (total 16).
    value += adaptiveShadowCaster(low, size);
    value += adaptiveShadowCaster(ivec2(high.x, low.y), size);
    value += adaptiveShadowCaster(ivec2(low.x, high.y), size);
    value += adaptiveShadowCaster(high, size);
    return value / 16.0;
}

void main() {
    ivec2 output_cell = ivec2(floor(vTexCoord * param.OutputSize.xy));
    ivec2 size = textureSize(Original, 0);
    int phase = output_cell.x % 3;
    ivec2 window_cell = ivec2(output_cell.x / 3, output_cell.y);
    if (any(greaterThan(window_cell, size))) discard;
    ivec2 cell = shadow_origin + window_cell;
    vec2 radius = native_radius;
    if (global.PT_SHADOW_BLUR <= 0.1) {
        float value = adaptiveShadowCaster(cell, size);
        FragColor = vec4(value, value, value, 1.0);
        return;
    }
    if (all(lessThan(radius, vec2(0.499)))) {
        // Small kernels need only the current cell and its immediate neighbors.
        int side=phase-1;
        float middle=adaptiveShadowCaster(cell,size);
        float up=adaptiveShadowCaster(cell+ivec2(0,-1),size);
        float down=adaptiveShadowCaster(cell+ivec2(0,1),size);
        float other=adaptiveShadowCaster(cell+ivec2(side,0),size);
        if (global.PT_SHADOW_FAST_BLUR < 0.5) {
            float horizontal=6.0*middle+2.0*other;
            FragColor=vec4((horizontal+2.0*up+2.0*middle)/12.0,
                           (horizontal+4.0*middle)/12.0,
                           (horizontal+2.0*middle+2.0*down)/12.0,1.0);
        } else {
            float hmiddle=3.0*middle+other;
            float hup=3.0*up+adaptiveShadowCaster(cell+ivec2(side,-1),size);
            float hdown=3.0*down+adaptiveShadowCaster(cell+ivec2(side,1),size);
            FragColor=vec4((hup+3.0*hmiddle)/16.0,hmiddle/4.0,
                           (3.0*hmiddle+hdown)/16.0,1.0);
        }
        return;
    }
    FragColor = vec4(shadowPhase(cell, ivec2(phase, 0), size),
                     shadowPhase(cell, ivec2(phase, 1), size),
                     shadowPhase(cell, ivec2(phase, 2), size), 1.0);
}
