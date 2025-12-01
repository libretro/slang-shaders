#version 450

layout(push_constant) uniform Push
{
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    float compositeConnection;
    float interlaceMode;
} params;

#pragma parameter interlaceMode "Deinterlacer: Off | Trilinear | Bicubic" 1.0 0.0 2.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

////////////////////////////////////////////////////////
// GTU version 0.50 (deinterlaced pass)
// Author: aliaspider - aliaspider@gmail.com
// License: GPLv3
// Note: Optional deinterlacing added by Cyanosin
////////////////////////////////////////////////////////

#include "config.h"

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
float bic1D(float x)
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

vec4 bicSample4(vec4 Cm1, vec4 C0, vec4 C1, vec4 C2, float t)
{
    float w0 = bic1D(1.0 + t);
    float w1 = bic1D(t);
    float w2 = bic1D(1.0 - t);
    float w3 = bic1D(2.0 - t);

    float wsum = w0 + w1 + w2 + w3;
    vec4  c    = (Cm1*w0 + C0*w1 + C1*w2 + C2*w3) / max(wsum, 1e-6);

    return clamp(c, 0.0, 1.0);
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

        // TRILINEAR
        vec4 Tm1 = texture(Source, vec2(uv.x, clamp(uv.y - 1.0*dy, 0.0, 1.0)));
        vec4 T0  = c;
        vec4 T1  = texture(Source, vec2(uv.x, clamp(uv.y + 1.0*dy, 0.0, 1.0)));
        vec4 c_tri = (Tm1 * 0.25) + (T0 * 0.50) + (T1 * 0.25);

        // BICUBIC
        vec4 Cm1 = Tm1;
        vec4 C0  = c;
        vec4 C1  = T1;
        vec4 C2  = texture(Source, vec2(uv.x, clamp(uv.y + 2.0*dy, 0.0, 1.0)));
        vec4 c_bic = bicSample4(Cm1, C0, C1, C2, 0.5);

        float use_bic = step(1.5, mode);
        c = mix(c_tri, c_bic, use_bic);
    }
    /* DEINTERLACE END */

    if (params.compositeConnection > 0.0)
        c.rgb = c.rgb * RGB_to_YIQ;

    FragColor = c;
}
