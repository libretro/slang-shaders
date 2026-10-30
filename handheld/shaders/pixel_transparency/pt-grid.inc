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
                          |_|     GRID SETUP AND FUNCTIONS  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Shared vertex setup, LCD coverage and colour functions for input and output.
    Original grid authors and licences are retained below.

   	Grid code adapted from these shaders in handheld/shaders/:

   	lcd3x.slang
      Author: Gigaherz
      License: Public domain

    lcd1x.slang
      A slightly tweaked version of lcd3x, original code written by Gigaherz
      and released into the public domain. Edited by jdgleaver.

    zfast_lcd.slang (zfast_lcd_standard)
      Copyright (C) 2017 Greg Hogan (SoltanGris42)

    simpletex_lcd/simpletex_lcd.slang
       Makes use of the 'line weighting' equation from zfast_lcd_standard
       [original zfast_lcd_standard code copyright (C) 2017 Greg Hogan
       (SoltanGris42)]. Other code by jdgleaver.

    lcd1x, zfast_lcd and simpletex_lcd carry this notice:
      This program is free software; you can redistribute it and/or modify it
      under the terms of the GNU General Public License as published by the
      Free Software Foundation; either version 2 of the License, or (at your
      option) any later version.

    lcd-cgwg/lcd-grid-v2.slang
      Geometry and colour reconstruction follow this shader.

*/

#pragma stage vertex
#ifndef PT_GRID_AUTHENTIC_GBC_FAST
#ifdef PT_GRID_LCD_GRID_V2
layout(location = 12) flat out vec3 grid_red;
layout(location = 13) flat out vec3 grid_green;
layout(location = 14) flat out vec3 grid_blue;
layout(location = 15) flat out float grid_line_linear;
#endif
void prepareLCD() {
#ifdef PT_GRID_LCD_GRID_V2
    grid_red = pow(vec3(global.RSUBPIX_R, global.RSUBPIX_G, global.RSUBPIX_B), vec3(2.2));
    grid_green = pow(vec3(global.GSUBPIX_R, global.GSUBPIX_G, global.GSUBPIX_B), vec3(2.2));
    grid_blue = pow(vec3(global.BSUBPIX_R, global.BSUBPIX_G, global.BSUBPIX_B), vec3(2.2));
    grid_line_linear = pow(global.PT_GRID_BRIGHTNESS, 2.2);
#endif
}
#endif
#pragma stage fragment
#ifndef PT_GRID_AUTHENTIC_GBC_FAST
#ifdef PT_GRID_LCD_GRID_V2
layout(location = 12) flat in vec3 grid_red;
layout(location = 13) flat in vec3 grid_green;
layout(location = 14) flat in vec3 grid_blue;
layout(location = 15) flat in float grid_line_linear;
#endif

/*

*/

#ifdef PT_GRID_SIMPLETEX_LCD
layout(set = 0, binding = 6) uniform sampler2D BACKGROUND;
#endif
#ifdef PT_GRID_LCD_GRID_V2
layout(set = 0, binding = 6) uniform sampler2D PTIntegratedX;
layout(set = 0, binding = 7) uniform sampler2D PTIntegratedY;
vec3 gridLinear(vec3 color) {
    return pow(global.gain * color + vec3(global.blacklevel), vec3(global.gamma)) + vec3(global.ambient);
}
// Inverse of gridLinear.
vec3 gridDisplay(vec3 color) {
    vec3 encoded = pow(max(color - vec3(global.ambient), vec3(0.0)), vec3(1.0 / global.gamma));
    return (encoded - vec3(global.blacklevel)) / global.gain;
}
vec3 gridEncode(vec3 color) {
    return pow(mat3(grid_red, grid_green, grid_blue) * color, vec3(1.0 / 2.2));
}
// Fill only the uncovered subpixel area; retain the original dark-line path.
vec3 gridEncodeLines(vec3 color, vec4 left, vec4 right, vec4 vertical) {
    if (global.PT_GRID_BRIGHTNESS > 0.0) {
        vec3 coverage = (left.rgb + right.rgb) * (vertical.x + vertical.y);
        vec3 gaps = clamp(vec3(1.0) - coverage, 0.0, 1.0);
        vec3 linear = mat3(grid_red, grid_green, grid_blue) * color;
        return pow(linear + grid_line_linear * gaps, vec3(1.0 / 2.2));
    }
    return gridEncode(color);
}
void gridWeights(vec2 uv, out vec4 left, out vec4 right, out vec4 vertical) {
    ivec2 extent = ivec2(textureSize(PTIntegratedX, 0).x, textureSize(PTIntegratedY, 0).y);
    ivec2 pixel = clamp(ivec2(uv * vec2(extent)), ivec2(0), extent - 1);
    left = texelFetch(PTIntegratedX, ivec2(pixel.x, 0), 0);
    right = texelFetch(PTIntegratedX, ivec2(pixel.x, 1), 0);
    vertical = texelFetch(PTIntegratedY, ivec2(0, pixel.y), 0);
}
#endif

// The same operator runs either on native colour or the full-resolution effects.
vec3 applyGrid(vec3 color, vec2 uv, vec2 outputSize) {
#if defined(PT_GRID_LCD1X) || defined(PT_GRID_LCD3X)
#ifdef PT_GRID_LCD1X
    vec2 angle = 2.0 * 3.141592654 * (uv * global.OriginalSize.xy - 0.25);
    float y = (global.BRIGHTEN_SCANLINES + sin(angle.y)) / (global.BRIGHTEN_SCANLINES + 1.0);
    vec3 x = vec3((global.BRIGHTEN_LCD + sin(angle.x)) / (global.BRIGHTEN_LCD + 1.0));
#else
    vec2 angle = uv * (vec2(3.141592654) * vec2(2.0) * global.OriginalSize.xy);
    const vec3 offsets = vec3(3.141592654) * vec3(0.5, 0.5 - 2.0 / 3.0, 0.5 - 4.0 / 3.0);
    float y = (global.brighten_scanlines + sin(angle.y)) / (global.brighten_scanlines + 1.0);
    vec3 x = (global.brighten_lcd + sin(angle.x + offsets)) / (global.brighten_lcd + 1.0);
#endif
    return y * x * (color - vec3(global.PT_GRID_BRIGHTNESS))
         + vec3(global.PT_GRID_BRIGHTNESS);
#elif defined(PT_GRID_SIMPLETEX_LCD) || defined(PT_GRID_ZFAST_LCD)
    vec2 coordinate = uv * global.OriginalSize.xy;
    vec2 distance = abs(floor(coordinate) + vec2(0.5) - coordinate);
    float d2 = max(distance.x, distance.y);
    d2 *= d2;
    float d4 = d2 * d2;
#ifdef PT_GRID_SIMPLETEX_LCD
    color = pow(color, vec3(1.0 + global.DARKEN_COLOUR));
    float weight = 48.0 * (d4 - (8.0 / 3.0 * d4 * d2));
    weight *= (weight + (1.0 - weight) * global.GRID_WIDTH) * global.GRID_INTENSITY;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    weight *= luma + (1.0 - luma) * (1.0 - global.GRID_BIAS);
    color = mix(color, vec3(1.0 - global.DARKEN_GRID), weight);
    if (global.BACKGROUND_INTENSITY > 0.0) {
        vec2 paper = (floor(uv * outputSize) + vec2(0.5)) / 2048.0;
        vec3 background = texture(BACKGROUND, paper).rgb * color;
        color = mix(color, background, dot(color, vec3(0.2126, 0.7152, 0.0722)) * global.BACKGROUND_INTENSITY);
    }
#else
    float d6 = d4 * d2;
    float lineWeight = global.BORDERMULT * (d4 - 2.7 * d6);
    color = (color - vec3(global.PT_GRID_BRIGHTNESS)) * (1.0 - lineWeight)
          + vec3(global.PT_GRID_BRIGHTNESS);
    if (global.GBAGAMMA > 0.5) color *= 0.6 + 0.4 * color;
#endif
    return color;
#else
    vec4 left, right, vertical;
    gridWeights(uv, left, right, vertical);
    vec3 linearColor = gridLinear(color);
    // Preserve the source shader's summation order, including non-diagonal matrices.
    vec3 weighted = linearColor * left.rgb * vertical.x + linearColor * right.rgb * vertical.y
                  + linearColor * left.rgb * vertical.y + linearColor * right.rgb * vertical.x;
    return gridEncodeLines(weighted, left, right, vertical);
#endif
}
#endif
