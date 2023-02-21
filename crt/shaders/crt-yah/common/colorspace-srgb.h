#ifndef COLORSPACE_SRGB_DEFINDED

#define COLORSPACE_SRGB_DEFINDED

// XYZ to RGB for sRGB working space (D65 white point reference)
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const mat3 XYZtoRGB = mat3(
     3.2404542, -0.9692660,  0.0556434,
    -1.5371385,  1.8760108, -0.2040259,
    -0.4985314,  0.0415560,  1.0572252);

// RGB to XYZ for sRGB working space (D65 white point reference)
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const mat3 RGBtoXYZ = mat3(
     0.4124564,  0.2126729,  0.0193339,
     0.3575761,  0.7151522,  0.1191920,
     0.1804375,  0.0721750,  0.9503041);

// D65 to D55 in XYZ working space
// http://www.brucelindbloom.com/index.html?Eqn_ChromAdapt.html
const mat3 D65toD55 = mat3(
     1.0285405,  0.0172109, -0.0058993,
     0.0135022,  0.9952227,  0.0096778,
    -0.0314825, -0.0106363,  0.8425735);

// D65 to D75 in XYZ working space
// http://www.brucelindbloom.com/index.html?Eqn_ChromAdapt.html
const mat3 D65toD75 = mat3(
     0.9799401, -0.0112490,  0.0049195,
    -0.0091708,  1.0015532, -0.0081963,
     0.0252447,  0.0083931,  1.1295615);

const float LumaR = 0.2126;
const float LumaG = 0.7152;
const float LumaB = 0.0722;
const vec3 LumaC = vec3(LumaR, LumaG, LumaB);

// Returns the luminance of the given color by the default sRGB coefficients.
// @color - the color.
float get_luminance(vec3 color)
{
    return dot(color, LumaC);
}

// Converts the given color value from sRGB to linearized sRGB by the specified gamma.
// @value - the color value.
// @gamma - the gamma.
float srgb_to_linear(float value, float gamma)
{
    return value <= 0.0404482
        ? value / 12.92
        : pow((value + 0.055) / 1.055, gamma);
}

// Converts the given color from sRGB to linearized sRGB by the specified gamma.
// @color - the color.
// @gamma - the gamma.
vec3 srgb_to_linear(vec3 color, float gamma)
{
    return vec3(
        srgb_to_linear(color.r, gamma),
        srgb_to_linear(color.g, gamma),
        srgb_to_linear(color.b, gamma));
}

// Converts the given color value from linearized sRGB to sRGB by the specified gamma.
// @value - the color value.
// @gamma - the gamma.
float linear_to_srgb(float value, float gamma)
{
    return value <= 0.0031307
        ? value * 12.92
        : 1.055 * pow(value, 1.0 / gamma) - 0.055;
}

// Converts the given color from linearized sRGB to sRGB by the specified gamma.
// @color - the color.
// @gamma - the gamma.
vec3 linear_to_srgb(vec3 color, float gamma)
{
    return vec3(
        linear_to_srgb(color.r, gamma),
        linear_to_srgb(color.g, gamma),
        linear_to_srgb(color.b, gamma));
}

// Decodes the gamma of the given color.
// @color - the color.
vec3 decode_gamma(vec3 color)
{
    return srgb_to_linear(color, 2.4);
}

// Encodes the gamma of the given color.
// @color - the color.
vec3 encode_gamma(vec3 color)
{
    return linear_to_srgb(color, 2.4);
}

#endif // COLORSPACE_SRGB_DEFINDED
