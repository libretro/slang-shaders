// Filename: bezel-base.slang
//
// Copyright (C) 2025 W. M. Martinez
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
// Bezel functions to be used with #include

#include "common.inc"

#include "menus/parameters/factory-geometry.inc"
#include "menus/parameters/output-bezel.inc"

#pragma parameter BEZEL_BYPASS "Bypass bezel" 0.0 0.0 1.0 1.0
#pragma parameter GLOW_BYPASS "Bypass glow" 0.0 0.0 1.0 1.0
#pragma parameter KEY_THRESH "Bezel chroma key threshold" 0.18 0.0 0.5 0.01
#pragma parameter KEY_SOFT "Bezel chroma key softness" 0.08 0.0 0.5 0.01

layout(push_constant) uniform Push
{
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    float ASPECT;
    float VIEWPORT_H_POS;
    float VIEWPORT_V_POS;
    float BEZEL_BYPASS;
    float BEZEL_GAIN;
    float BEZEL_BIAS;
    float GLOW_BYPASS;
    float GLOW_RADIUS;
    float GLOW_WEIGHT;
    float GLOW_DIFFUSION;
    float GLOW_VERTICAL_BIAS;
    float GLOW_COMPRESSION;
    float GLOW_JITTER;
    float GLOW_FALLOFF;
    float GLOW_TEMPERATURE;
    float KEY_THRESH;
    float KEY_SOFT;
} config;

#define ASPECT config.ASPECT
#define VIEWPORT_H_POS config.VIEWPORT_H_POS
#define VIEWPORT_V_POS config.VIEWPORT_V_POS
#define BEZEL_BYPASS config.BEZEL_BYPASS
#define BEZEL_GAIN config.BEZEL_GAIN
#define BEZEL_BIAS config.BEZEL_BIAS
#define GLOW_BYPASS config.GLOW_BYPASS
#define GLOW_RADIUS config.GLOW_RADIUS
#define GLOW_WEIGHT config.GLOW_WEIGHT
#define GLOW_DIFFUSION config.GLOW_DIFFUSION
#define GLOW_VERTICAL_BIAS config.GLOW_VERTICAL_BIAS
#define GLOW_COMPRESSION config.GLOW_COMPRESSION
#define GLOW_JITTER config.GLOW_JITTER
#define GLOW_FALLOFF config.GLOW_FALLOFF
#define GLOW_TEMPERATURE config.GLOW_TEMPERATURE

#define KEY_THRESH config.KEY_THRESH
#define KEY_SOFT config.KEY_SOFT

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 screen_coord;
layout(location = 2) out float AspectRatio;
layout(location = 3) out vec2 viewport_scale; // Precomputed scale of aspect-corrected viewport
layout(location = 4) out vec2 viewport_offset; // Precomputed offset for centered/shifted viewport
layout(location = 5) out vec2 viewport_max_dist; // Precomputed normalization distances for radial falloff

/**
 * Vertex shader: Transforms the vertex position and calculates texture coordinates
 * for both the full output and the aspect-corrected screen viewport.
 * Supports independent horizontal and vertical sizing.
 */
void main()
{
    // Selected target aspect ratio for framing
    AspectRatio = (ASPECT < 0.5)   ? (4.0 / 3.0)
        : (ASPECT < 1.5) ? (16.0 / 9.0)
        : (ASPECT < 2.5) ? (5.0 / 4.0)
        : (16.0 / 10.0);
    gl_Position = global.MVP * Position;

    // Calculate aspect-corrected viewport size
    vec2 corrected_size = AspectRatio > 1.0 ?
        vec2(config.OutputSize.y * AspectRatio, config.OutputSize.y):
        vec2(config.OutputSize.x, config.OutputSize.x / AspectRatio);

    // Calculate scale factor and centering offset for the independently-sized viewport
    vec2 scale = config.OutputSize.xy / corrected_size;

    // Normalize viewport position offsets to texture coordinate space
    float h_shift = VIEWPORT_H_POS / config.OutputSize.x;
    float v_shift = VIEWPORT_V_POS / config.OutputSize.y;

    // Center the viewport, then apply user shift (in normalized texture space)
    vec2 offset = (1.0 - scale) * 0.5 + vec2(-h_shift, v_shift) * scale;

    // Precompute max outside distances used for radial glow falloff normalization
    vec2 max_dist = vec2(
        max(offset.x / scale.x, (1.0 - offset.x - scale.x) / scale.x),
        max(offset.y / scale.y, (1.0 - offset.y - scale.y) / scale.y)
    );

    // Export precomputed values to fragment stage
    viewport_scale = scale;
    viewport_offset = offset;
    viewport_max_dist = max_dist;

    // Map texture coordinates to the scaled and shifted screen viewport
    screen_coord = TexCoord.xy * scale + offset;
    vTexCoord = TexCoord.xy;  // Unmodified coords for background/border sampling
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 screen_coord;
layout(location = 2) in float AspectRatio;
layout(location = 3) in vec2 viewport_scale;
layout(location = 4) in vec2 viewport_offset;
layout(location = 5) in vec2 viewport_max_dist;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;
layout(set = 0, binding = 4) uniform sampler2D BORDER;

/**
 * Blends two colors using multiply blend mode.
 * This creates a darkening effect where overlapping colors become darker.
 * 
 * @param col1 Base color
 * @param col2 Blend color
 * @return Multiplied color (col1 * col2)
 */
vec3 blend(vec3 col1, vec3 col2)
{
    return col1 * col2;
}

/**
 * Compresses color dynamic range to reduce extreme highlights and shadows.
 * Uses a power curve to soften the visual impact of bright/dark areas in the glow effect.
 * 
 * @param color Input color to compress
 * @param compression Compression amount [0-1]: 0=maximum compression, 1=no compression
 * @return Compressed color with reduced dynamic range
 */
vec3 compress_color(vec3 color, float compression)
{
    // Map compression [0,1] to power curve exponent [0.3, 1.0]
    // Lower exponents compress bright values more aggressively
    float power = mix(0.3, 1.0, compression);
    return pow(color, vec3(power));
}

/**
 * Shifts color temperature of the input color.
 * Negative values make colors warmer, positive values make them cooler.
 * This simulates the psychological perception of CRT glow which appears bluish due to
 * reflections and the contrast between the bright screen and darker surroundings.
 * 
 * @param color Input color in linear RGB space
 * @param temperature Temperature shift [-0.5 to 0.5]: negative=warmer, positive=cooler
 * @return Color with shifted temperature
 */
vec3 shift_temperature(vec3 color, float temperature)
{
    // Color temperature matrix coefficients
    // Cooler (positive): reduce red, boost blue
    // Warmer (negative): boost red, reduce blue
    
    // Calculate RGB multipliers based on temperature
    // This uses a simplified approximation of blackbody radiation color shifts
    float red_shift = 1.0 - temperature * 0.8;   // Red decreases when cooling
    float green_shift = 1.0 - abs(temperature) * 0.2;  // Green slightly affected
    float blue_shift = 1.0 + temperature * 1.2;  // Blue increases when cooling
    
    vec3 shifted = color * vec3(red_shift, green_shift, blue_shift);
    
    // Preserve overall luminance by normalizing to maintain perceived brightness
    float original_luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float shifted_luma = dot(shifted, vec3(0.2126, 0.7152, 0.0722));
    
    if (shifted_luma > 0.0001)
    {
        shifted *= original_luma / shifted_luma;
    }
    
    return shifted;
}

/**
 * Hash function for generating pseudo-random values from 2D coordinates.
 * Uses a simple but effective fractional pattern to generate deterministic randomness.
 * 
 * @param p Input 2D coordinate
 * @return Pseudo-random value in range [0, 1)
 */
float hash(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/**
 * Generates a random 2D offset vector for jittering.
 * Uses the hash function to create a random direction and distance.
 * 
 * @param seed Input coordinate used as random seed
 * @param magnitude Maximum offset distance
 * @return Random 2D offset vector
 */
vec2 random_offset(vec2 seed, float magnitude)
{
    float angle = hash(seed) * 2.0 * PI;
    float distance = hash(seed + vec2(1.0)) * magnitude;
    return vec2(cos(angle), sin(angle)) * distance;
}

// ==== Mirrored sampling with soft edge guard ====
// Tunables for edge protection (guard band and soft fade width)
#define EDGE_MARGIN   0.06   // How far from 0/1 to keep samples (0..0.25 is sensible)
#define EDGE_SOFTNESS 0.02   // Fade width into the margin (0 = hard, >0 = smooth)

// Mirror a continuous UV into [0,1] using mirrored repeat, robust for negative UVs too
vec2 mirror01(vec2 uv)
{
    vec2 t = mod(uv, 2.0);
    return 1.0 - abs(t - 1.0);
}

// Smoothly keep mirrored UV away from edges by EDGE_MARGIN, with a soft ramp of EDGE_SOFTNESS
vec2 soft_guard01(vec2 uv01, float margin, float softness)
{
    // Distance to nearest edge per axis
    vec2 d = min(uv01, 1.0 - uv01);

    // s = 0 near edges (d <= margin), s = 1 past margin+softness
    vec2 s = smoothstep(vec2(margin), vec2(margin + max(softness, 1e-5)), d);

    // Hard-clamped safe coordinate
    vec2 clamped = clamp(uv01, margin, 1.0 - margin);

    // Blend from clamped (near edges) to original (away from edges)
    return mix(clamped, uv01, s);
}

// Optional: edge factor to fade contributions near mirrored seams
float edge_guard_factor(vec2 uv01, float margin, float softness)
{
    vec2 d = min(uv01, 1.0 - uv01);
    vec2 s = smoothstep(vec2(margin), vec2(margin + max(softness, 1e-5)), d);
    return s.x * s.y;
}

// Convenience: safe mirrored sampling
vec3 sample_mirror_safe(sampler2D tex, vec2 uv)
{
    vec2 m = mirror01(uv);
    vec2 safe = soft_guard01(m, EDGE_MARGIN, EDGE_SOFTNESS);
    return texture(tex, safe).rgb;
}

/**
 * Calculates a glow effect by sampling surrounding pixels in multiple directions.
 * Uses an 8-directional sampling pattern with configurable diffusion steps.
 * Supports anisotropic scaling and vertical bias for more natural-looking CRT glow.
 * 
 * Features:
 * - Multi-step diffusion: samples at varying distances for smooth falloff
 * - Anisotropic scaling: more perpendicular spread
 * - Vertical bias: emphasizes vertical glow (CRT scanline characteristic)
 * - Jitter: randomized offsets to eliminate banding artifacts
 * - Color compression: reduces extreme brightness impact
 * 
 * @param coord Base texture coordinate to sample around
 * @param radius Maximum sampling radius in texture space
 * @param diffusion_steps Number of distance steps per direction (higher = smoother)
 * @return Accumulated glow color
 */
vec3 calculate_glow(vec2 coord, float radius, float diffusion_steps)
{
    // Define 8 cardinal and intercardinal directions (N, NE, E, SE, S, SW, W, NW)
    const vec2 directions[8] = vec2[8](
        vec2(0.0, 1.0),       // North
        vec2(0.707, 0.707),   // Northeast
        vec2(1.0, 0.0),       // East
        vec2(0.707, -0.707),  // Southeast
        vec2(0.0, -1.0),      // South
        vec2(-0.707, -0.707), // Southwest
        vec2(-1.0, 0.0),      // West
        vec2(-0.707, 0.707)   // Northwest
    );
    
    vec3 glow = vec3(0.0);
    float total_weight = 0.0;
    int num_steps = int(diffusion_steps);
    
    // Sample in each direction with multiple distance steps for smooth diffusion
    for (int step = 1; step <= num_steps; step++)
    {
        float distance_factor = float(step) / float(num_steps);
        
        // Closer samples contribute more (linear falloff)
        float diffusion_weight = 1.0 - (distance_factor - 1.0 / float(num_steps));
        
        for (int i = 0; i < 8; i++)
        {
            vec2 dir = directions[i];
            
            // Decompose direction into horizontal and vertical components
            float horizontal_component = abs(dir.x);
            float vertical_component = abs(dir.y);
            
            // Anisotropic scaling: increase perpendicular diffusion
            // Horizontal rays spread vertically, vertical rays spread horizontally
            vec2 anisotropic_scale = vec2(
                1.0 + vertical_component * 2.0,    // Expand X when moving vertically
                1.0 + horizontal_component * 2.0   // Expand Y when moving horizontally
            );
            
            // Calculate sample offset with anisotropic scaling
            float step_radius = radius * distance_factor;
            vec2 base_offset = dir * step_radius * anisotropic_scale;
            
            // Add jitter to eliminate banding and shadow line artifacts
            vec2 jitter = random_offset(coord * 100.0 + vec2(float(step), float(i)), GLOW_JITTER * radius);
            vec2 offset = base_offset + jitter;
            
            // Sample and compress color to reduce extreme brightness impact
            vec3 sample_color = compress_color(
                sample_mirror_safe(Source, coord + offset),
                GLOW_COMPRESSION
            );
            
            // Apply vertical bias to emphasize vertical glow (CRT scanline characteristic)
            float vertical_boost = 1.0;
            if (abs(dir.x) < 0.1)  // Pure vertical (N/S)
            {
                vertical_boost = GLOW_VERTICAL_BIAS;
            }
            else if (abs(dir.y) > abs(dir.x))  // Mostly vertical diagonals (NE/NW/SE/SW)
            {
                vertical_boost = mix(1.0, GLOW_VERTICAL_BIAS, 0.5);
            }
            
            // Combine weights and accumulate
            float weight = diffusion_weight * vertical_boost;
            glow += sample_color * weight;
            total_weight += weight;
        }
    }
    
    // Normalize to maintain consistent brightness regardless of sample count
    return total_weight > 0.0 ? glow / total_weight : glow;
}

/**
 * Fragment shader: Composites the CRT screen with bezel/background and glow effect.
 * 
 * Pipeline:
 * 1. Sample screen content (with viewport bounds checking)
 * 2. If bypass is enabled, return screen content directly
 * 3. Sample background/bezel texture
 * 4. Calculate glow effect from screen content
 * 5. Shift glow color temperature (cooler/bluer for realistic CRT reflection)
 * 6. Apply radial falloff to glow based on distance from viewport
 * 7. Blend glow with background
 * 8. Composite screen over glowing background
 */
void main()
{
    // Sample the main CRT screen content
    vec4 screen = texture(Source, screen_coord);
    screen.a = max(screen.a, 1.0);  // Ensure opaque screen

    // Bypass mode: pass through screen content without bezel/glow processing
    if (BEZEL_BYPASS > 0.5)
    {
        FragColor = vec4(screen.rgb, 1.0);
        return;
    }

    // Sample background/bezel texture
    vec4 background = texture(BORDER, vTexCoord);

    // Color key against green to create transparency in bezel when JPEG is used
    // Smooth chroma key: alpha is 0 for pure green, 1 for non-green, smooth in between
    float key_thresh = KEY_THRESH; // Tolerance for keying (tweak as needed)
    float key_soft = KEY_SOFT;   // Soft edge width for smooth transition
    vec3 key_color = vec3(0.0, 1.0, 0.0);
    float key_dist = distance(background.rgb, key_color);
    float key_alpha = smoothstep(key_thresh, key_thresh + key_soft, key_dist);
    background.a *= key_alpha;

    // Transform glow sampling coordinates (centered on screen viewport)
    vec2 glow_coord = screen_coord;

    vec3 glow;
    float effective_glow_weight;

    // === GLOW_BYPASS implementation ===
    if (GLOW_BYPASS > 0.5)
    {
        glow = vec3(0.0);
        effective_glow_weight = 0.0;
    }
    else
    {
        // Calculate glow effect
        glow = calculate_glow(glow_coord, GLOW_RADIUS, GLOW_DIFFUSION);

        // Shift glow color temperature to simulate bluish CRT reflection
        glow = shift_temperature(glow, GLOW_TEMPERATURE);

        // === Calculate radial falloff for glow intensity ===
        // Use precomputed viewport scale and offset from vertex stage
        vec2 viewport_pos = (vTexCoord - viewport_offset) / viewport_scale;
        vec2 clamped_pos = clamp(viewport_pos, 0.0, 1.0);
        vec2 outside_dist = abs(viewport_pos - clamped_pos);
        // Normalize outside distance using precomputed maximum distances
        vec2 normalized_dist = outside_dist / max(viewport_max_dist, vec2(0.0001));
        float radial_dist = length(normalized_dist);

        float falloff = exp(-radial_dist * GLOW_FALLOFF);
        effective_glow_weight = GLOW_WEIGHT * falloff;
    }

    // === Blend glow with background ===
    vec3 background_adjusted = srgb_linear(background.rgb);
    vec3 background_with_glow = blend(background_adjusted, glow);

    background.rgb = mix(background_adjusted, background_with_glow, effective_glow_weight);

    // Final composite: blend CRT screen over background using alpha
    float bezel_gain = pow(10.0, BEZEL_GAIN / 20.0);
    float bezel_bias = BEZEL_BIAS / 100.0;
    vec3 final_color = mix(
        srgb_linear(screen.rgb),
        (background.rgb + bezel_bias) * bezel_gain,
        background.a
    );

    FragColor = vec4(srgb_gamma(final_color), 1.0);
}