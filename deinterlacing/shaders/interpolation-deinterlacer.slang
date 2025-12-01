#version 450

/////////////////////////////////////////////////////////////////////////////
//  INTERPOLATION DEINTERLACER v1.0                                        //
//                                                                         //
//  Trilinear: 3-tap vertical interpolation                                //
//  Bicubic (Mitchell-Netravali): 4-tap vertical interpolation             //
//                                                                         //
//  Author: Cyanosin                                                       //
//  License: Public domain                                                 //
//                                                                         //
//  Note: This shader is intended for emulator-style interlaced output,	   //
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

#pragma parameter deint_mode     "Deinterlace Mode: Trilinear | Bicubic"       0.0   0.0  1.0   1.0
#pragma parameter deint_trigger  "Deinterlace Trigger Resolution"              400.0 0.0 800.0 20.0
#pragma parameter deint_strength "Deinterlace Strength"                        1.00  0.0  1.0  0.01

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#define SourceSize   params.SourceSize
#define OriginalSize params.OriginalSize
#define OutputSize   params.OutputSize

// COEFFICIENTS
const float B = 1.0 / 3.0;
const float C = 1.0 / 3.0;

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

float bic1D(float x)
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

vec4 bicSample4(vec4 Cm1, vec4 C0, vec4 C1, vec4 C2, float t)
{
    float w0 = bic1D(1.0 + t);
    float w1 = bic1D(t);
    float w2 = bic1D(1.0 - t);
    float w3 = bic1D(2.0 - t);

    float wsum = (w0 + w1 + w2 + w3);
    vec4  c    = (Cm1*w0 + C0*w1 + C1*w2 + C2*w3) / max(wsum, 1e-6);

    return clamp(c, 0.0, 1.0);
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

        // TRILINEAR
        vec4 Tm1 = texture(Source, vec2(uv.x, clamp(uv.y - 1.0*dy, 0.0, 1.0)));
        vec4 T0  = c_orig;
        vec4 T1  = texture(Source, vec2(uv.x, clamp(uv.y + 1.0*dy, 0.0, 1.0)));

        vec4 c_tri = (Tm1 * 0.25) + (T0 * 0.50) + (T1 * 0.25);

        // BICUBIC
        vec4 Cm1 = texture(Source, vec2(uv.x, clamp(uv.y - 1.0*dy, 0.0, 1.0)));
        vec4 C0  = c_orig;
        vec4 C1  = texture(Source, vec2(uv.x, clamp(uv.y + 1.0*dy, 0.0, 1.0)));
        vec4 C2  = texture(Source, vec2(uv.x, clamp(uv.y + 2.0*dy, 0.0, 1.0)));

        vec4 c_bic = bicSample4(Cm1, C0, C1, C2, 0.5);

        float use_bic = step(0.5, params.deint_mode);
        vec4  c_deint = mix(c_tri, c_bic, use_bic);

        c_final = mix(c_orig, c_deint, clamp(params.deint_strength, 0.0, 1.0));
    }

    FragColor = c_final;
}
