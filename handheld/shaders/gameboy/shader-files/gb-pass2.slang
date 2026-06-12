#version 450

  /////////////////////////////////////////////////////////////////////////
//    _________    __  _________   ____  ______  __                      //
//   / ____/   |  /  |/  / ____/  / __ )/ __ \ \/ /                      //
//  / / __/ /| | / /|_/ / __/    / __  / / / /\  /                       //
// / /_/ / ___ |/ /  / / /___   / /_/ / /_/ / / /                        //
// \____/_/  |_/_/  /_/_____/  /_____/\____/ /_/                         //
//  ==================== DOT MATRIX SHADER v1.4                          //
//                                                                       //
// Copyright (C) 2013 Harlequin : unknown92835@gmail.com                 //
// Copyright (C) 2024-2026 Matt Akins                                    //
//                                                                       //
// This program is free software: you can redistribute it and/or modify  //
// it under the terms of the GNU General Public License as published by  //
// the Free Software Foundation, either version 3 of the License, or     //
// (at your option) any later version.                                   //
//                                                                       //
// This program is distributed in the hope that it will be useful,       //
// but WITHOUT ANY WARRANTY; without even the implied warranty of        //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         //
// GNU General Public License for more details.                          //
//                                                                       //
// You should have received a copy of the GNU General Public License     //
// along with this program.  If not, see <http://www.gnu.org/licenses/>. //
//                                                                       //
/////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////
 // gb-pass2 - Horizontal shadow alpha blur                             //
/////////////////////////////////////////////////////////////////////////

#include "gb-params.inc"
#include "gb-shared.inc"

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 OriginalSize;
	vec4 SourceSize;
	float integer_mode;
	float video_scale;
	float baseline_alpha;
	float shadow_blur_amount;
	float alpha_reference_scale;
	float pixel_size;
	float fullscreen_match_pixel_size;
	float pixel_softness;
	float sharpening_amount;
	float pixel_shape;
	float sharp_mode;
	float auto_soften;
	float blending_mode;
	float adjacent_texel_alpha_blending;
} registers;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

  /////////////////////////////////////////////////////////////////////////
 // Vertex shader                                                       //
/////////////////////////////////////////////////////////////////////////

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 texel;
layout(location = 2) out vec2 lower_bound;
layout(location = 3) out vec2 upper_bound;
layout(location = 4) out vec2 blur_step;
layout(location = 5) out float effective_baseline_alpha;

vec2 get_current_gb_scale() {
    if (registers.integer_mode > 1.5) {
        return vec2(registers.video_scale);
    } else if (registers.integer_mode > 0.5) {
        return vec2(floor(registers.OutputSize.y * registers.OriginalSize.w));
    }
    return registers.OutputSize.xy * registers.OriginalSize.zw;
}

float get_alpha_normalization_factor() {
    float reference_coverage = integer_post_blend_coverage(
        registers.alpha_reference_scale,
        registers.blending_mode,
        registers.adjacent_texel_alpha_blending
    );

    if (registers.integer_mode > 0.5) {
        float current_scale = get_current_gb_scale().y;
        float current_coverage = integer_post_blend_coverage(
            current_scale,
            registers.blending_mode,
            registers.adjacent_texel_alpha_blending
        );
        return alpha_normalization_factor(reference_coverage,
                                          current_coverage);
    }

    if (registers.integer_mode < 0.5) {
        vec2 tx_to_px = registers.OutputSize.xy * registers.OriginalSize.zw;
        float effective_pixel_size = get_effective_pixel_size(
            tx_to_px,
            registers.pixel_size,
            registers.fullscreen_match_pixel_size
        );
        float effective_softness = get_effective_pixel_softness(
            tx_to_px,
            registers.pixel_softness,
            registers.auto_soften
        );
        float current_coverage = sample_scale_average_coverage(
            tx_to_px,
            registers.OutputSize.xy,
            registers.OriginalSize.xy,
            effective_pixel_size,
            effective_softness,
            registers.sharpening_amount,
            registers.pixel_shape,
            registers.sharp_mode
        );
        return alpha_normalization_factor(reference_coverage,
                                          current_coverage);
    }

    return 1.0;
}

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord * 1.0001;

    texel = registers.SourceSize.zw;
    blur_step = texel * (get_current_gb_scale() / shadow_reference_scale) * registers.shadow_blur_amount;
    effective_baseline_alpha =
        registers.baseline_alpha * get_alpha_normalization_factor();
    lower_bound = vec2(0.0);
    upper_bound = vec2(texel * (registers.OutputSize.xy - 1.0));
}

  /////////////////////////////////////////////////////////////////////////
 // Fragment shader                                                     //
/////////////////////////////////////////////////////////////////////////

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 texel;
layout(location = 2) in vec2 lower_bound;
layout(location = 3) in vec2 upper_bound;
layout(location = 4) in vec2 blur_step;
layout(location = 5) in float effective_baseline_alpha;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

/*
sigma = 4.0, normalized for 5 pixel offset       sigma = 4.0, normalized for 4 pixel offset
Raw Gaussian weights:                            Raw Gaussian weights:
0.09973561222190091607086808117254 @position0    0.09973561222190091607086808117254 @position0
0.09666707205829167156101677393475 @position1    0.09666707205829167156101677393475 @position1
0.08801637626376240452162358324964 @position2    0.08801637626376240452162358324964 @position2
0.07528440407628116669052257071979 @position3    0.07528440407628116669052257071979 @position3
0.06049272702308815188099267447364 @position4    0.06049272702308815188099267447364 @position4
0.04566231462789672460813692086928 @position5

sum [p0 + 2(p1 + p2 + p3 + p4 + p5)]:            sum [p0 + 2(p1 + p2 + p3 + p4)]:
0.83198140032054115459545312766674               0.74065677106474770537917928592818

Normalizing factor [1 / sum]:                    Normalizing factor [1 / sum]:
1.2019499469756482251051310195171                1.350153052084338115052273748029

Normalized Gaussian weights:                     Normalized Gaussian weights:
0.11987721382169761913280166382392 @position0    0.13465834124289953661305802732548 @position0
0.11618898213475484076479592086597 @position1    0.13051534237555914090930704141833 @position1
0.10579127878321792515352079488329 @position2    0.11883557904592230273554609080014 @position2
0.09048808548757942339961181362524 @position3    0.10164546793794160274995705611009 @position3
0.07270923003781316665844409497651 @position4    0.08167444001912718529866079800870 @position4
0.05488381664578583445722654373702 @position5
*/
float shadow_sample_alpha(vec2 coord, vec2 texel, vec2 lower_bound, vec2 upper_bound) {
    float alpha = texture(Source, clamp(coord, lower_bound, upper_bound)).a;
    return max(alpha - effective_baseline_alpha, 0.0);
}

void main()
{
    // Define offsets and weights - change this for both the X and Y passes if you change the sigma value or number of texels sampled
    float offsets[5] = float[](0.0, 1.0, 2.0, 3.0, 4.0);

    /*
    Precalculated using the Gaussian function:
    G(x) = (1 / sqrt(2 * pi * sigma^2)) * e^(-x^2 / (2 * sigma^2))

    Where sigma = 4.0 and x = offset in range [0, 5]
    Normalized to 1 to prevent image darkening by multiplying each weight by:
    1 / sum(all weights)
    */
    float weights[5] = float[]( 0.13465834124289953661305802732548,
                                0.13051534237555914090930704141833,
                                0.11883557904592230273554609080014,
                                0.10164546793794160274995705611009,
                                0.08167444001912718529866079800870 );

    // Sample the current fragment and apply its weight
    vec4 center = texture(Source, clamp(vTexCoord, lower_bound, upper_bound));
    vec4 out_color = center * weights[0];
    out_color.a = max(center.a - effective_baseline_alpha, 0.0) * weights[0];

    // Iterate across the offsets in both directions sampling texels
    // and adding their weighted alpha values to the total
    for (int i = 1; i < 5; i++)
    {
        vec2 right = vTexCoord + vec2(offsets[i] * blur_step.x, 0.0);
        vec2 left = vTexCoord - vec2(offsets[i] * blur_step.x, 0.0);
        out_color.a += shadow_sample_alpha(right, texel, lower_bound, upper_bound) * weights[i];
        out_color.a += shadow_sample_alpha(left, texel, lower_bound, upper_bound) * weights[i];
    }

    FragColor = out_color;
}