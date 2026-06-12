#version 450
/*
Author: djayjp aka CreativeForce (2026)

This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/
/*
  EWA / radial / cylindrical cubic family shader.

  Cubic Family:
    0 = Robidoux
        Intended full-precision source values:
          B = 0.37821575509399867
          C = 0.31089212245300067

    1 = Mitchell
        Intended exact values:
          B = 1/3
          C = 1/3

    2 = RobidouxSharp
        Intended full-precision source values:
          B = 0.2620145123990142
          C = 0.3689927438004929

  Implementation note:
    - For each mode, B is specified directly.
    - C is then derived as:
          C = 0.5 * (1.0 - B)
      so that the shader stays on the Keys cubic line B + 2C = 1,
      as closely as float arithmetic permits.

  Other notes:
    - Uses the cubic Keys-family kernel radially (EWA/cylindrical style),
      rather than separably.
    - Support radius is 2.0.
    - Compact 4x4 footprint, appropriate for radius-2 EWA cubic filtering.
*/

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float CubicMode;
} params;

#pragma parameter CubicMode "Cubic (0=Robidoux/Smooth; 1=Mitchell/Medium; 2=RobidouxSharp)" 0.00 0.00 2.00 1.00

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const float SUPPORT = 2.0;

void select_bc(float mode, out float B, out float C)
{
    if (mode < 0.5)
    {
        // Robidoux
        // Intended full-precision pair:
        //   B = 0.37821575509399867
        //   C = 0.31089212245300067
        B = 0.37821575509399867;
    }
    else if (mode < 1.5)
    {
        // Mitchell
        // Intended exact pair:
        //   B = 1/3
        //   C = 1/3
        B = 1.0 / 3.0;
    }
    else
    {
        // RobidouxSharp
        // Intended full-precision pair:
        //   B = 0.2620145123990142
        //   C = 0.3689927438004929
        B = 0.2620145123990142;
    }

    // Keep the shader on the Keys cubic line B + 2C = 1,
    // using the actual float value of B.
    C = 0.5 * (1.0 - B);
}

float cubic_bc_weight(float x, float B, float C)
{
    float ax = abs(x);
    float ax2 = ax * ax;
    float ax3 = ax2 * ax;

    if (ax < 1.0)
    {
        return ((12.0 - 9.0 * B - 6.0 * C) * ax3
              + (-18.0 + 12.0 * B + 6.0 * C) * ax2
              + (6.0 - 2.0 * B)) / 6.0;
    }
    else if (ax < 2.0)
    {
        return ((-B - 6.0 * C) * ax3
              + (6.0 * B + 30.0 * C) * ax2
              + (-12.0 * B - 48.0 * C) * ax
              + (8.0 * B + 24.0 * C)) / 6.0;
    }

    return 0.0;
}

vec3 sample_texel_center(vec2 center_px)
{
    return texture(Source, center_px * params.SourceSize.zw).rgb;
}

void main()
{
    float B, C;
    select_bc(params.CubicMode, B, C);

    vec2 pos = vTexCoord * params.SourceSize.xy;
    vec2 c = floor(pos - vec2(0.5)) + vec2(0.5);

    vec3 accum = vec3(0.0);
    float wsum = 0.0;

    // Radius-2 EWA cubic footprint.
    for (int j = -1; j <= 2; ++j)
    {
        for (int i = -1; i <= 2; ++i)
        {
            vec2 sample_center = c + vec2(float(i), float(j));
            vec2 delta = pos - sample_center;
            float r = length(delta);

            if (r >= SUPPORT)
                continue;

            float w = cubic_bc_weight(r, B, C);
            if (w == 0.0)
                continue;

            accum += sample_texel_center(sample_center) * w;
            wsum += w;
        }
    }

    if (wsum > 0.0)
        accum /= wsum;

    FragColor = vec4(accum, 1.0);
}
