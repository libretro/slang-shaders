// Filename: digital.inc
//
// Copyright (C) 2026 W. M. Martinez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// Digital Helper Functions
// -------------------------
// Quantization functions for simulating fixed-point bit depth encodings.

#ifndef __DIGITAL_INC__
#define __DIGITAL_INC__

// Quantize a value to 6-bit linear precision (64 levels)
// Input: normalized value in range [0.0, 1.0]
// Output: quantized value in range [0.0, 1.0]
float quantize_6bit(float value)
{
    const float levels = 63.0;  // 2^6 - 1
    return round(value * levels) / levels;
}

// Quantize a value to 8-bit linear precision (256 levels)
// Input: normalized value in range [0.0, 1.0]
// Output: quantized value in range [0.0, 1.0]
float quantize_8bit(float value)
{
    const float levels = 255.0;  // 2^8 - 1
    return round(value * levels) / levels;
}

// Quantize a value to 10-bit linear precision (1024 levels)
// Input: normalized value in range [0.0, 1.0]
// Output: quantized value in range [0.0, 1.0]
float quantize_10bit(float value)
{
    const float levels = 1023.0;  // 2^10 - 1
    return round(value * levels) / levels;
}

// Quantize a value to arbitrary bit depth linear precision
// Input: normalized value in range [0.0, 1.0], bit depth
// Output: quantized value in range [0.0, 1.0]
float quantize(float value, int bits)
{
    float levels = pow(2.0, float(bits)) - 1.0;
    return round(value * levels) / levels;
}

// Quantize a vector to 6-bit linear precision
vec3 quantize_6bit(vec3 value)
{
    return vec3(quantize_6bit(value.r), quantize_6bit(value.g), quantize_6bit(value.b));
}

// Quantize a vector to 8-bit linear precision
vec3 quantize_8bit(vec3 value)
{
    return vec3(quantize_8bit(value.r), quantize_8bit(value.g), quantize_8bit(value.b));
}

// Quantize a vector to 10-bit linear precision
vec3 quantize_10bit(vec3 value)
{
    return vec3(quantize_10bit(value.r), quantize_10bit(value.g), quantize_10bit(value.b));
}

// Quantize a vector to 6-bit linear precision (alpha channel preserved)
vec4 quantize_6bit(vec4 value)
{
    return vec4(quantize_6bit(value.rgb), value.a);
}

// Quantize a vector to 8-bit linear precision (alpha channel preserved)
vec4 quantize_8bit(vec4 value)
{
    return vec4(quantize_8bit(value.rgb), value.a);
}

// Quantize a vector to 10-bit linear precision (alpha channel preserved)
vec4 quantize_10bit(vec4 value)
{
    return vec4(quantize_10bit(value.rgb), value.a);
}

// Quantize a vector to arbitrary bit depth linear precision
vec3 quantize(vec3 value, int bits)
{
    return vec3(quantize(value.r, bits), quantize(value.g, bits), quantize(value.b, bits));
}

// Quantize a vector to arbitrary bit depth linear precision (alpha channel preserved)
vec4 quantize(vec4 value, int bits)
{
    return vec4(quantize(value.rgb, bits), value.a);
}

// Limit YCbCr to legal broadcast range and optionally offset chroma to positive range.
// Input: YCbCr in working space (Y [0-1], C [-0.5, 0.5])
// Output: Normalized values suitable for unorm storage with limited dynamic range
// 8-bit: Y [16-235]/255, C [16-240]/255 (centered at 128/255)
// 10-bit: Y [64-940]/1023, C [64-960]/1023 (centered at 512/1023)
vec3 limit_ycbcr(vec3 ycbcr, int bits)
{
    float y = ycbcr.x;
    float cb = ycbcr.y;
    float cr = ycbcr.z;
    
    if (bits <= 8) {
        const float inv255 = 1.0 / 255.0;
        // Y: [16, 235] out of 255
        y = (16.0 + y * 219.0) * inv255;
        // C: [16, 240] out of 255, center at 128
        // C range is ±112 centered at 128
        cb = (128.0 + cb * 112.0) * inv255;
        cr = (128.0 + cr * 112.0) * inv255;
    } else { // 10-bit
        const float inv1023 = 1.0 / 1023.0;
        // Y: [64, 940] out of 1023
        y = (64.0 + y * 876.0) * inv1023;
        // C: [64, 960] out of 1023, center at 512
        // C range is ±448 centered at 512
        cb = (512.0 + cb * 448.0) * inv1023;
        cr = (512.0 + cr * 448.0) * inv1023;
    }
    
    return vec3(y, cb, cr);
}

// Inverse of limit_ycbcr: map from limited range back to working space.
// Input: Normalized YCbCr values with limited dynamic range (from unorm storage)
// Output: YCbCr in working space (Y [0-1], C [-0.5, 0.5])
vec3 unlimit_ycbcr(vec3 ycbcr, int bits)
{
    float y = ycbcr.x;
    float cb = ycbcr.y;
    float cr = ycbcr.z;
    
    if (bits <= 8) {
        // Y: [16, 235] -> [0, 1]
        y = (y * 255.0 - 16.0) / 219.0;
        // C: [16, 240] centered at 128 -> [-0.5, 0.5]
        cb = (cb * 255.0 - 128.0) / 112.0;
        cr = (cr * 255.0 - 128.0) / 112.0;
    } else { // 10-bit
        // Y: [64, 940] -> [0, 1]
        y = (y * 1023.0 - 64.0) / 876.0;
        // C: [64, 960] centered at 512 -> [-0.5, 0.5]
        cb = (cb * 1023.0 - 512.0) / 448.0;
        cr = (cr * 1023.0 - 512.0) / 448.0;
    }
    
    return vec3(y, cb, cr);
}

// Generate blue noise dither pattern using hash-based pseudo-random function
// Input: screen coordinates (pixel position), frame count for temporal variation
// Output: dither value in range [-0.5, 0.5]
float blue_noise(vec2 coord, uint frame)
{
    // Hash function for blue noise with temporal variation
    vec2 p = fract(coord * 0.3183099 + vec2(0.71, 0.113) + sin(vec2(frame) * 0.1));
    p *= 17.0;
    float result = fract(p.x * p.y * (p.x + p.y));
    return result - 0.5;  // Center around 0
}

// Apply blue noise dithering before quantization
// Input: value to dither, working bit depth, output bit depth, screen coordinates, frame count
// Output: dithered value
float apply_dither(float value, int working_bits, int output_bits, vec2 coord, uint frame)
{
    if (working_bits <= output_bits) {
        // No dithering needed if working bits are less than or equal to output bits
        return value;
    }
    
    // Dither amplitude
    float dither_amount;

    // Noise is half LSB of output bit depth
    if (output_bits == 6) {
        dither_amount = 0.5 / 63.0;
    } else if (output_bits == 8) {
        dither_amount = 0.5 / 255.0;
    } else if (output_bits == 10) {
        dither_amount = 0.5 / 1023.0;
    } else {
        dither_amount = 0.5 / (pow(2.0, float(output_bits)) - 1.0);
    }
    
    // Add blue noise dither with temporal variation
    float dither = blue_noise(coord, frame) * dither_amount;
    return value + dither;
}

// Apply blue noise dithering to a vector
vec3 apply_dither(vec3 value, int working_bits, int output_bits, vec2 coord, uint frame)
{
    return vec3(
        apply_dither(value.r, working_bits, output_bits, coord + vec2(0.0, 0.0), frame),
        apply_dither(value.g, working_bits, output_bits, coord + vec2(1.0, 0.0), frame),
        apply_dither(value.b, working_bits, output_bits, coord + vec2(2.0, 0.0), frame)
    );
}

#endif  // __DIGITAL_INC__
