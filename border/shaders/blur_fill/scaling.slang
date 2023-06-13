#define AREA_RENDER_PASS_SCALE 2.0

vec2 vp_to_blurred(vec2 coord) {
    return (coord - 0.5) * AREA_RENDER_PASS_SCALE + 0.5;
}

vec2 blurred_to_vp(vec2 coord) {
    return (coord - 0.5) / AREA_RENDER_PASS_SCALE + 0.5;
}
