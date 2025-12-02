#version 450

/////////////////////////////////////////////////////////////////////////////
//  INTERPOLATION DEINTERLACER v1.2                                        //
//                                                                         //
//  Trilinear: 3-tap vertical interpolation                                //
//  Bicubic (Mitchell-Netravali): 4-tap vertical interpolation             //
//  Lanczos2.5: 5-tap vertical interpolation                               //
//  Gaussian (sigma=0.8): 7-tap vertical interpolation                     //
//                                                                         //
//  Author: cyanosin                                                       //
//  License: Public domain                                                 //
//                                                                         //
//  Note: This shader is intended for emulator-style interlaced output,    //
//  where both fields are displayed sequentially and woven together.       //
//                                                                         //
//  It is not suitable for general interlaced video sources such as        //
//  broadcast, capture cards, or encoded media.                            //
/////////////////////////////////////////////////////////////////////////////

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;

    float deint_mode;
    float deint_trigger;
    float deint_strength;
} params;

#pragma parameter deint_mode     "Deinterlace Mode: Trilinear | Bicubic | Lanczos | Gaussian"    0.0   0.0  3.0   1.0
#pragma parameter deint_trigger  "Deinterlace Trigger Resolution"                                400.0 0.0 800.0 20.0
#pragma parameter deint_strength "Deinterlace Strength"                                          1.00  0.0  1.0  0.01

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#define SourceSize   params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize   params.OutputSize

// MITCHELL-NETRAVALI COEFFICIENTS
const float B = 1.0 / 3.0;
const float C = 1.0 / 3.0;

const float PI = 3.14159265358979323846;

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

float bicubic1D(float x)
{
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

    float sum = w0 + w1 + w2 + w3;
    vec4 col = (Cm1*w0 + C0*w1 + C1*w2 + C2*w3) / max(sum, 1e-6);

    return clamp(col, 0.0, 1.0);
}

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
    vec2 uv      = vTexCoord;
    vec4 c_orig  = texture(Source, uv);
    vec4 c_final = c_orig;

    float src_h = OriginalSize.y;

    if (src_h >= params.deint_trigger && params.deint_strength > 0.0)
    {
        float dy = SourceSize.w;

        vec4 Sm2 = texture(Source, vec2(uv.x, clamp(uv.y - 2.0*dy, 0.0, 1.0)));
        vec4 Sm1 = texture(Source, vec2(uv.x, clamp(uv.y - 1.0*dy, 0.0, 1.0)));
        vec4 S0  = c_orig;
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
        if (params.deint_mode >= 2.5)
        {
            vec4 Sm3 = texture(Source, vec2(uv.x, clamp(uv.y - 3.0*dy, 0.0, 1.0)));
            vec4 S3  = texture(Source, vec2(uv.x, clamp(uv.y + 3.0*dy, 0.0, 1.0)));
            c_gau = gaussianSample7(Sm3, Sm2, Sm1, S0, S1, S2, S3, 0.5);
        }

        float m = params.deint_mode;

        vec4 c_deint = c_tri;
        if (m >= 2.5)      c_deint = c_gau;
        else if (m >= 1.5) c_deint = c_lnz;
        else if (m >= 0.5) c_deint = c_bic;

        c_final = mix(c_orig, c_deint, clamp(params.deint_strength, 0.0, 1.0));
    }

    FragColor = c_final;
}
