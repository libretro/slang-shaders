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
                          |_|             FINAL COMPOSITOR  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Final-pass entry logic for all six grid families. Combines transparency,
    optional sunlight, Accurate placement and final dither. Authentic's grid
    geometry stays in separate cache passes; it only blends here.

*/

#ifdef PT_GRID_AUTHENTIC_GBC_FAST
#define PT_COMPOSITOR_UNIFORMS \
    float PT_GRID; \
    float PT_GRID_STRENGTH; \
    float PT_GRID_BRIGHTNESS;
#else
#define PT_CUSTOM_LCD
#endif
#include "pixel_transparency.inc"
// Stage pragmas are split as plain text, so they stay outside #ifdef blocks.
#include "pt-grid.inc"
#pragma stage fragment

#ifdef PT_GRID_AUTHENTIC_GBC_FAST
// Authentic GBC by fishku, Copyright (C) 2024-2025, public domain (CC0).
// Coverage was rendered separately; only the layer blend runs here.
layout(set = 0, binding = 6) uniform sampler2D PTGridX;
layout(set = 0, binding = 7) uniform sampler2D PTGridY;
vec4 finishGrid(vec4 color) {
    if (global.PT_GRID > 0.5 &&
        (global.PT_HIDE_CONTENT < 0.5 || param.PT_ENABLE < 0.5)) {
        ivec2 pixel = ivec2(floor(vTexCoord * param.OutputSize.xy));
        vec4 xFirst = texelFetch(PTGridX, ivec2(pixel.x, 4), 0);
        vec3 xSecond = texelFetch(PTGridX, ivec2(pixel.x, 5), 0).rgb;
        vec3 yFirst = texelFetch(PTGridY, ivec2(4, pixel.y), 0).rgb;
        vec3 ySecond = texelFetch(PTGridY, ivec2(5, pixel.y), 0).rgb;
        vec3 coverage = clamp((xFirst.rgb * yFirst + xSecond * ySecond) / xFirst.a, 0.0, 1.0);
        float strength = global.PT_GRID_STRENGTH;
        coverage = mix(vec3(1.0), coverage, strength);
        vec3 line = vec3(global.PT_GRID_BRIGHTNESS);
        vec3 linear = max(color.rgb, vec3(0.0));
        color.rgb = sqrt(linear * linear * coverage + line * line * (vec3(1.0) - coverage));
    }
    return color;
}
#else
vec4 finishGrid(vec4 color) {
    if (global.PT_GRID > 0.5) {
        // Gamma-based grids require nonnegative display colour.
        color.rgb = applyGrid(max(color.rgb, vec3(0.0)), vTexCoord, param.OutputSize.xy);
#ifdef PT_GRID_LCD_GRID_V2
        color.a = 1.0;
#endif
    }
    return color;
}
#endif
#ifdef PT_LIGHT_FIELD
#include "sunlight_shimmer.inc"
#endif
#ifndef PT_GRID_AUTHENTIC_GBC_FAST
vec4 sampleLCD() { return texture(LCDInput, vTexCoord); }
#endif
void main() {
    vec3 original_pixel;
    float original_brightness;
    bool effects_enabled = renderPixelTransparency(original_pixel, original_brightness);
#ifdef PT_LIGHT_FIELD
    // Sunlight places the grid between the rainbow and the front-surface glare.
    FragColor = applyCachedSunlight(FragColor, original_pixel, original_brightness, effects_enabled);
#else
    FragColor = finishGrid(FragColor);
#endif
    // Dither whenever Pixel Transparency runs, including with Sunlight off; nothing when it is disabled.
#ifdef PT_LIGHT_FIELD
    if (effects_enabled)
#else
    if (effects_enabled && param.PT_DEFER_DITHER < 0.5)
#endif
        FragColor.rgb += (hash(floor(vTexCoord * param.OutputSize.xy) + vec2(0.5)) - 0.5) / 255.0;
}
