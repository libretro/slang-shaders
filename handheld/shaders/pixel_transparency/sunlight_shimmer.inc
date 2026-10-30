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
                          |_|             SUNLIGHT SHIMMER  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Grid shaders look great on Game Boy Color games - except for one glaring issue.

    With no backlight, the original devices didn't render white pixels. Light pixels
    appeared as transparent areas where the backing material of the screen showed through.
    Many games relied on this effect for transparent backgrounds that now render on modern
    displays as eye-searing white pixels. No more! Pixel Transparency simulates this unique effect.

    SUNLIGHT SHIMMER EDITION: Light and shadows move with your device!
    Tilt your device and shadows shift with it. Glare sweeps across your screen. And just like the
    Game Boy Color in sunlight, you see a brilliant rainbow shimmer in the background.

    Load a preset from presets/pixel_transparency/ to get the effect with your favourite grid built in.

    Applies the cached optical field to the full-resolution transparency result.
    Keeps reflection handling and final-dither hooks in the output stage.

*/

// Apply optical tint to full-resolution game pixels and LCD detail.
// Screen order: the rainbow tints light that passes through the pixels, the
// opaque grid gaps block it, and the front sheen and glare sit on top.
vec4 applyCachedSunlight(vec4 output_color, vec3 original_pixel, float original_brightness, bool effects_enabled) {
    bool lit = effects_enabled && global.PT_SUNLIGHT_ENABLE > 0.5 &&
        (param.PT_RAINBOW_ENABLE > 0.5 || param.PT_GLARE_ENABLE > 0.5 || global.PT_REFLECT_ENABLE > 0.5);
    vec4 light_sample = vec4(0.0);
    float dist_sq = 0.0;
    if (lit) {
        light_sample = texture(LightField, light_coord);
        float aspect_ratio = param.OutputSize.x / param.OutputSize.y;
        vec2 to_light = (vTexCoord - light_pos) * vec2(aspect_ratio, 1.0);
        if (global.PT_REFLECT_ENABLE > 0.5) {
            dist_sq = dot(to_light, to_light);
        }

        // Rainbow effect — QWP chromatic dispersion with 3D light source geometry.
        if (param.PT_RAINBOW_ENABLE > 0.5 && global.PT_RAINBOW_INTENSITY > 0.001 && any(notEqual(output_color.rgb,vec3(0.0)))) {
            vec3 tint = light_sample.rgb;

            float tint_strength = global.PT_RAINBOW_INTENSITY;

            // Brightness gating — rainbow light double-passes through the LC layer,
            // so dark pixels attenuate the reflection. Linear with 0.03 floor from
            // ~30:1 contrast ratio of reflective TFT.
            float reflectivity = mix(0.03, 1.0, original_brightness);
            tint_strength *= reflectivity;

            // Color filter: the rainbow light crosses the pixel's colour filter
            // twice, in and out.
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
    }

    output_color = finishGrid(output_color);

    if (lit) {
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
            float glare_strength = light_sample.a;

            output_color.rgb = mix(output_color.rgb, vec3(1.0), clamp(glare_strength, 0.0, 0.85));
        }
    }

    return output_color;
}
