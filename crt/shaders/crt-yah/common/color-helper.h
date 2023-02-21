#ifndef COLOR_HELPER

#define COLOR_HELPER

#include "colorspace-srgb.h"

#define EPSILON 1e-6
#define PI 3.1415926

// Returns the maximum value of the given color.
// @color - the color.
float max_color(vec3 color)
{
    return max(max(color.r, color.g), color.b);
}

// Applies a new scale to the given color.
// @color - the color.
// @scale - the new scale.
vec3 apply_scale(vec3 color, float scale)
{
    vec3 normalized_color = color / (max_color(color) + EPSILON);
    
    return normalized_color * scale;
}

// Applies the contrast to the given color.
// @color - the color.
// @contrast - the contrast to apply.
//   <0.0 - decreasing
//    0.0 - unchanged
//   >0.0 - increasing
vec3 apply_contrast(vec3 color, float contrast)
{
    float linear = min(1.0, max_color(color));
    
    float nonlinear = linear;

    // move range [0, 1] to [-1, 1]
    nonlinear = 2.0 * nonlinear - 1.0;

    // apply non-linear mapping
    nonlinear = sin(nonlinear * PI * 0.5);

    // move range [-1, 1] to [0, 1]
    nonlinear = (nonlinear + 1.0) * 0.5;

    return apply_scale(
        color,
        mix(linear, nonlinear, contrast));
}

// Applies the brightness to the given color.
// @color - the color.
// @brightness - the brightness to apply.
vec3 apply_brightness(vec3 color, float brightness)
{
    return color * (1.0 + brightness);
}

// Applies a minimum value to the given color.
// @color - the color.
// @floot - the minimum value.
vec3 apply_floor(vec3 color, float floor)
{
    float luminance = get_luminance(color);
    floor *= 1.0 - luminance;

    return (color + floor) / (1.0 + floor);
}

// Applies the saturation to the given color.
// @color - the color.
// @saturation - the saturation to apply.
//   <0.0 - decreasing
//    0.0 - unchanged
//   >0.0 - increasing
vec3 apply_saturation(vec3 color, float saturation)
{
    float luminance = get_luminance(color);

    return saturation > 1.0
        // increase
        ? apply_scale(pow(color, vec3(saturation)), max_color(color))
        // decrease
        : mix(vec3(luminance), color, saturation);
}

// Applies the temperature to the given color based on the given white point.
// @color - the color.
// @white_point_relative - the relative white point to apply.
//   -1.0 - D55
//    0.0 - D65
//    1.0 - D75
vec3 apply_temperature(vec3 color, float white_point_relative)
{
    mat3 white_point = white_point_relative < 0.0
        // warmer
        ? D65toD55
        // cooler
        : D65toD75;

    return mix(
        color,
        color * RGBtoXYZ * white_point * XYZtoRGB,
        abs(white_point_relative));
}

#endif // COLOR_HELPER
