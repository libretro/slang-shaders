// Shared crt-1tap and crt-2tap uniforms and fragment functions.

layout(push_constant) uniform Push {
    vec4 OutputSize;
    vec4 OriginalSize;
    float MIN_THICK;
    float MAX_THICK;
    float H_SMOOTH;
    float V_SMOOTH;
    float SUBPX_POS;
    float THICK_FALLOFF;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
}
global;

vec3 get_beam_width(vec3 signal) {
    const vec3 shaped_signal = pow(clamp(signal, 0.0, 1.0), param.THICK_FALLOFF.xxx);
    return min(mix(param.MIN_THICK.xxx, param.MAX_THICK.xxx, shaped_signal), vec3(1.0));
}

vec3 get_beam_prefix(float y, vec3 width) {
    const float cell = floor(y);
    const float phase = y - cell;
    return cell * width + clamp(vec3(phase - 0.5) + 0.5 * width, vec3(0.0), width);
}

float get_sample_x(float src_x) {
    const float src_x_int = floor(src_x);
    const float src_x_fract = src_x - src_x_int;

    // Symmetric sigmoid with a configurable slope at the midpoint.
    const float h_slope = mix(6.0, 1.0, param.H_SMOOTH);
    const float x = 2.0 * src_x_fract - 1.0;
    const float src_x_offset =
        0.5 + 0.5 * h_slope * x * inversesqrt(1.0 + (h_slope * h_slope - 1.0) * x * x);
    return (src_x_int + src_x_offset + 0.5) * param.OriginalSize.z;
}
