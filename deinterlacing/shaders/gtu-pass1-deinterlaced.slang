#version 450

layout(push_constant) uniform Push
{
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    float compositeConnection;
    float interlaceMode;
} params;

#pragma parameter interlaceMode "Deinterlacer: Off | Trilinear | Bicubic | Lanczos | Gaussian" 1.0 0.0 4.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

////////////////////////////////////////////////////////
// GTU version 0.50 (deinterlaced pass)
// Author: aliaspider - aliaspider@gmail.com
// License: GPLv3
// Note: Deinterlacer added by cyanosin
////////////////////////////////////////////////////////

#include "../../crt/shaders/gtu-v050/config.h"

#define RGB_to_YIQ mat3x3( \
    0.299    ,  0.595716 ,  0.211456 , \
    0.587    , -0.274453 , -0.522591 , \
    0.114    , -0.321263 ,  0.311135 )

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord   = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

/* DEINTERLACE BEGIN */
float bicubic1D(float x)
{
    // MITCHELL-NETRAVALI COEFFICIENTS
    const float B = 1.0 / 3.0;
    const float C = 1.0 / 3.0;

    x = abs(x);
    float x2 = x * x;
    float x3 = x2 * x;

    if (x < 1.0)
    {
        return ((12.0 - 9.0*B - 6.0*C)*x3 +
                (-18.0 + 12.0*B + 6.0*C)*x2 +
                (6.0 - 2.0*B)) / 6.0;
    }
    else if (x < 2.0)
    {
        return ((-B - 6.0*C)*x3 +
                (6.0*B + 30.0*C)*x2 +
                (-12.0*B - 48.0*C)*x +
                (8.0*B + 24.0*C)) / 6.0;
    }

    return 0.0;
}

vec4 bicubicSample4(vec4 Cm1, vec4 C0, vec4 C1, vec4 C2, float t)
{
    float w0 = bicubic1D(1.0 + t);
    float w1 = bicubic1D(t);
    float w2 = bicubic1D(1.0 - t);
    float w3 = bicubic1D(2.0 - t);

    float wsum = w0 + w1 + w2 + w3;
    vec4  c    = (Cm1*w0 + C0*w1 + C1*w2 + C2*w3) / max(wsum, 1e-6);

    return clamp(c, 0.0, 1.0);
}

const float PI = 3.14159265358979323846;

float sinc1(float x)
{
    if (abs(x) < 1e-6) return 1.0;
    float pix = PI * x;
    return sin(pix) / pix;
}

float lanczos25(float x)
{
    x = abs(x);
    if (x >= 2.5) return 0.0;
    return sinc1(x) * sinc1(x / 2.5);
}

vec4 lanczosSample5(vec4 Cm2, vec4 Cm1, vec4 C0, vec4 C1, vec4 C2, float t)
{
    float w0 = lanczos25(2.0 + t);
    float w1 = lanczos25(1.0 + t);
    float w2 = lanczos25(t);
    float w3 = lanczos25(1.0 - t);
    float w4 = lanczos25(2.0 - t);

    float sum = w0 + w1 + w2 + w3 + w4;

    vec4 col =
        Cm2 * w0 +
        Cm1 * w1 +
        C0  * w2 +
        C1  * w3 +
        C2  * w4;

    col /= max(sum, 1e-6);

    // ANTI-RINGING CLAMP
    vec4 cmin = min(min(min(min(Cm2, Cm1), C0), C1), C2);
    vec4 cmax = max(max(max(max(Cm2, Cm1), C0), C1), C2);

    return clamp(col, cmin, cmax);
}

float gaussianW(float x)
{
    const float inv2sig2 = 0.78125;
    return exp(-(x * x) * inv2sig2);
}

vec4 gaussianSample7(vec4 Cm3, vec4 Cm2, vec4 Cm1,
                     vec4 C0,
                     vec4 C1, vec4 C2, vec4 C3,
                     float t)
{
    float w0 = gaussianW(3.0 + t);
    float w1 = gaussianW(2.0 + t);
    float w2 = gaussianW(1.0 + t);
    float w3 = gaussianW(t);
    float w4 = gaussianW(1.0 - t);
    float w5 = gaussianW(2.0 - t);
    float w6 = gaussianW(3.0 - t);

    float sum = w0 + w1 + w2 + w3 + w4 + w5 + w6;

    vec4 col =
        Cm3 * w0 +
        Cm2 * w1 +
        Cm1 * w2 +
        C0  * w3 +
        C1  * w4 +
        C2  * w5 +
        C3  * w6;

    col /= max(sum, 1e-6);

    vec4 cmin = min(min(min(min(min(min(Cm3, Cm2), Cm1), C0), C1), C2), C3);
    vec4 cmax = max(max(max(max(max(max(Cm3, Cm2), Cm1), C0), C1), C2), C3);

    return clamp(col, cmin, cmax);
}

void main()
{
    vec2 uv = vTexCoord;
    vec4 c  = texture(Source, uv);

    float src_h   = params.OriginalSize.y;
    float trigger = 375.0; // TRIGGER RESOLUTION

    float mode = floor(params.interlaceMode + 0.5);

    if (mode > 0.5 && src_h >= trigger)
    {
        float dy = params.SourceSize.w;

        vec4 Sm2 = texture(Source, vec2(uv.x, clamp(uv.y - 2.0*dy, 0.0, 1.0)));
        vec4 Sm1 = texture(Source, vec2(uv.x, clamp(uv.y - 1.0*dy, 0.0, 1.0)));
        vec4 S0  = c;
        vec4 S1  = texture(Source, vec2(uv.x, clamp(uv.y + 1.0*dy, 0.0, 1.0)));
        vec4 S2  = texture(Source, vec2(uv.x, clamp(uv.y + 2.0*dy, 0.0, 1.0)));

        // TRILINEAR
        vec4 c_tri =
        (Sm1 * 0.25) +
        (S0  * 0.50) +
        (S1  * 0.25);

        // BICUBIC
        vec4 c_bic = bicubicSample4(Sm1, S0, S1, S2, 0.5);

        // LANCZOS
        vec4 c_lnz = lanczosSample5(Sm2, Sm1, S0, S1, S2, 0.5);

        // GAUSSIAN
        vec4 c_gau = c_lnz;
        if (mode >= 3.5)
        {
            vec4 Sm3 = texture(Source, vec2(uv.x, clamp(uv.y - 3.0*dy, 0.0, 1.0)));
            vec4 S3  = texture(Source, vec2(uv.x, clamp(uv.y + 3.0*dy, 0.0, 1.0)));
            c_gau = gaussianSample7(Sm3, Sm2, Sm1, S0, S1, S2, S3, 0.5);
        }

        if (mode >= 3.5)      c = c_gau;
        else if (mode >= 2.5) c = c_lnz;
        else if (mode >= 1.5) c = c_bic;
        else                  c = c_tri;
    }
/* DEINTERLACE END */

    if (params.compositeConnection > 0.0)
        c.rgb = c.rgb * RGB_to_YIQ;

    FragColor = c;
}
