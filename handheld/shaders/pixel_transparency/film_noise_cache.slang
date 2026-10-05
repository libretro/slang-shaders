#version 450

/*
  ____  _          _
 |  _ \(_)_  _____| |
 | |_) | \ \/ / _ \ |
 |  __/| |>  <  __/ |
 |_|___|_/_/\_\___|_|
 |_   _| __ __ _ _ __  ___ _ __   __ _ _ __ ___ _ __   ___ _   _
   | || '__/ _` | '_ \/ __| '_ \ / _` | '__/ _ \ '_ \ / __| | | |
   | || | | (_| | | | \__ \ |_) | (_| | | |  __/ | | | (__| |_| |
   |_||_|  \__,_|_| |_|___/ .__/ \__,_|_|  \___|_| |_|\___|\__, |
                          |_|             FILM NOISE CACHE  |___/
    v2.3 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Generates the four procedural film-noise corner values for each lattice cell.
    The final Sunlight Shimmer pass interpolates these values at output resolution.

*/

#pragma name FilmNoiseCache

// Store noise corners as 32-bit floats, avoiding 8-bit color quantization.
#pragma format R32G32B32A32_SFLOAT

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;
layout(push_constant) uniform Push { vec4 OutputSize; } param;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

// Match the procedural field used by the original Sunlight Shimmer path and
// the final pass's out-of-range fallback.
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    // The absolute 128x128 target maps one fragment to one noise lattice cell.
    vec2 cell = floor(vTexCoord * param.OutputSize.xy);

    // Store bilinear corners as R=(0,0), G=(1,0), B=(0,1), A=(1,1).
    // sunlight_shimmer.slang fetches this texel and performs the original
    // full-resolution smooth interpolation.
    FragColor = vec4(hash(cell), hash(cell + vec2(1.0, 0.0)),
                     hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)));
}