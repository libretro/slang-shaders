#version 450

/*
    Glare
    v1.0 by mattakins
    Copyright (C) 2026 Matt Akins.

    Append to any shader as the last pass. Reflections and glare move with device.

    Shared namespace: LIGHT_X, LIGHT_Y, LIGHT_RANGE, ACCEL_*
    Use these same parameters so light moves together across multi-pass presets.
*/

#pragma parameter REFLECT_GLARE_ENABLE  "=== Glare + Reflections === (OFF/ON)" 1.0 0.0 1.0 1.0

#pragma parameter GLARE_ENABLE          "--- Glare (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter GLARE_INTENSITY       "      ↳ Strength" 0.15 0.0 1.0 0.05
#pragma parameter GLARE_SIZE            "      ↳ Spread" 0.25 0.05 1.0 0.05
#pragma parameter GLARE_DITHER          "      ↳ Dither strength" 1.0 0.0 2.0 0.05

#pragma parameter REFLECT_ENABLE        "--- Reflections (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter REFLECT_INTENSITY     "      ↳ Strength" 0.08 0.0 0.5 0.01
#pragma parameter REFLECT_SPREAD        "      ↳ Spread (lower=sharper)" 0.6 0.1 1.0 0.05
#pragma parameter REFLECT_BIAS          "      ↳ Ambient floor" 0.02 0.0 0.2 0.005
#pragma parameter REFLECT_WARM          "      ↳ Warm tint" 0.3 0.0 1.0 0.05

#pragma parameter SECTION_LIGHT 		"--- Light" 0.0 0.0 1.0 1.0
#pragma parameter LIGHT_X               "      ↳ Light source X" 0.5 -1.0 2.0 0.01
#pragma parameter LIGHT_Y               "      ↳ Light source Y" 0.5 -1.0 2.0 0.01
#pragma parameter LIGHT_RANGE           "      ↳ Tilt range" 0.6 0.0 2.0 0.05

#pragma parameter ACCEL_ENABLE          "== MOTION == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter ACCEL_RELATIVE        "      ↳ Tilt neutral (0=Device flat, 1=From hold)" 0.0 0.0 1.0 1.0
#pragma parameter ACCEL_SENSITIVITY     "      ↳ Tilt sensitivity" 1.0 0.1 5.0 0.05

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    float REFLECT_GLARE_ENABLE;
    float REFLECT_ENABLE;
    float REFLECT_INTENSITY;
    float REFLECT_SPREAD;
    float REFLECT_BIAS;
    float REFLECT_WARM;
    float GLARE_ENABLE;
    float GLARE_INTENSITY;
    float GLARE_SIZE;
    float GLARE_DITHER;
    float LIGHT_X;
    float LIGHT_Y;
    float LIGHT_RANGE;
    float ACCEL_ENABLE;
    float ACCEL_RELATIVE;
    float ACCEL_SENSITIVITY;
} param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    #ifdef _HAS_SENSOR_UNIFORMS
    vec3 Gyroscope;
    vec3 Accelerometer;
    vec3 AccelerometerRest;
    #endif
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 light_pos;

vec2 getOrientedTilt(vec3 accel) {
    float magnitude = length(accel);
    if (magnitude < 0.01) return vec2(0.0);
    vec3 dir = accel / magnitude;
    return vec2(-dir.x, dir.y);
}

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    light_pos = vec2(param.LIGHT_X, param.LIGHT_Y);

    #ifdef _HAS_SENSOR_UNIFORMS
    if (param.REFLECT_GLARE_ENABLE > 0.5 && param.ACCEL_ENABLE > 0.5 &&
        (param.REFLECT_ENABLE > 0.5 || param.GLARE_ENABLE > 0.5)) {
        vec3 accel = global.Accelerometer;
        if (length(accel) > 0.01) {
            vec2 gravity;
            if (param.ACCEL_RELATIVE > 0.5) {
                vec3 rest = global.AccelerometerRest;
                gravity = clamp(getOrientedTilt(accel) - getOrientedTilt(rest), vec2(-1.0), vec2(1.0));
            } else {
                gravity = getOrientedTilt(accel);
            }
            gravity = clamp(gravity * param.ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));
            light_pos += vec2(gravity.x, -gravity.y) * param.LIGHT_RANGE;
        }
    }
    #endif
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 light_pos;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 triangularDither(vec2 p) {
    vec3 a = vec3(
        hash(p + vec2(17.0,  3.0)),
        hash(p + vec2(29.0, 11.0)),
        hash(p + vec2(43.0, 19.0))
    );
    vec3 b = vec3(
        hash(p + vec2(59.0, 23.0)),
        hash(p + vec2(71.0, 31.0)),
        hash(p + vec2(83.0, 37.0))
    );
    return a - b;
}

void main() {
    vec3 color = texture(Source, vTexCoord).rgb;

    if (param.REFLECT_GLARE_ENABLE > 0.5) {
        float aspect_ratio = param.OutputSize.x / param.OutputSize.y;
        vec2 to_light = (vTexCoord - light_pos) * vec2(aspect_ratio, 1.0);
        float dist_sq = dot(to_light, to_light);

        if (param.REFLECT_ENABLE > 0.5) {
            float spread_sq = param.REFLECT_SPREAD * param.REFLECT_SPREAD;
            float reflect_strength = exp(-dist_sq / (2.0 * spread_sq));
            reflect_strength = reflect_strength * param.REFLECT_INTENSITY + param.REFLECT_BIAS;

            vec3 reflect_color = mix(vec3(1.0), vec3(1.0, 0.95, 0.85), param.REFLECT_WARM);
            color += reflect_color * reflect_strength;
        }

        if (param.GLARE_ENABLE > 0.5 && param.GLARE_INTENSITY > 0.001) {
            float size_sq = param.GLARE_SIZE * param.GLARE_SIZE;
            float glare_strength = exp(-dist_sq / (2.0 * size_sq)) * param.GLARE_INTENSITY;
            color = mix(color, vec3(1.0), clamp(glare_strength, 0.0, 0.85));
        }

        // Triangular output dither breaks up 8-bit banding in smooth glare gradients.
        color += triangularDither(gl_FragCoord.xy) * (param.GLARE_DITHER / 255.0);
    }

    FragColor = vec4(color, 1.0);
}
