// SPDX-License-Identifier: MIT

struct lines_t {
    // Sample locations in [0,1] coordinate space, snapped to the middle of a
    // source texel.
    float upper_sample_y;
    float lower_sample_y;
    // Distance units are *scanlines heights*.
    float upper_distance_y;
    float lower_distance_y;
};

// Get the two closest lines to the given position.
lines_t get_closest_lines(float v, vec4 sourceSize) {
    float upper_sample_y = round(v * sourceSize.y) + 0.5;
    float lower_sample_y = upper_sample_y - 1.0;
    float upper_distance_y = upper_sample_y - v * sourceSize.y;
    float lower_distance_y = upper_distance_y - 1.0;

    // Transform *_sample_y into [0,1] coordinate space. We need them for the
    // texture sampling below.
    upper_sample_y *= sourceSize.w;
    lower_sample_y *= sourceSize.w;

    return lines_t(upper_sample_y, lower_sample_y, upper_distance_y, lower_distance_y);
}

// Get the two closest lines from the *even* field to the given position.
lines_t get_even_lines(float v, vec4 sourceSize) {
    float upper_sample_y = ceil(0.5 * v * sourceSize.y - 0.25) * 2.0 + 0.5;
    float lower_sample_y = upper_sample_y - 2.0;
    float upper_distance_y = 0.5 * (upper_sample_y - v * sourceSize.y);
    float lower_distance_y = upper_distance_y - 1.0;

    // Transform *_sample_y into [0,1] coordinate space. We need them for the
    // texture sampling below.
    upper_sample_y *= sourceSize.w;
    lower_sample_y *= sourceSize.w;

    return lines_t(upper_sample_y, lower_sample_y, upper_distance_y, lower_distance_y);
}

// Get the two closest lines from the *odd* field to the given position.
lines_t get_odd_lines(float v, vec4 sourceSize) {
    float upper_sample_y = ceil(0.5 * v * sourceSize.y + 0.25) * 2.0 - 0.5;
    float lower_sample_y = upper_sample_y - 2.0;
    float upper_distance_y = 0.5 * (upper_sample_y - v * sourceSize.y);
    float lower_distance_y = upper_distance_y - 1.0;

    // Transform *_sample_y into [0,1] coordinate space. We need them for the
    // texture sampling below.
    upper_sample_y *= sourceSize.w;
    lower_sample_y *= sourceSize.w;

    return lines_t(upper_sample_y, lower_sample_y, upper_distance_y, lower_distance_y);
}

// Get the two closest lines as if the source was line-doubled. Note that this
// means that the sample coordinates for the upper and lower lines may be the
// same, even though the distances are different.
lines_t get_doubled_lines(float v, vec4 sourceSize) {
    float upper_distance_y = ceil(2.0 * (v * sourceSize.y) - 0.5) + 0.5 - 2.0 * (v * sourceSize.y);
    float lower_distance_y = upper_distance_y - 1.0;
    float upper_sample_y = (ceil(v * sourceSize.y + 0.25) - 0.5) * sourceSize.w;
    float lower_sample_y = (ceil(v * sourceSize.y - 0.25) - 0.5) * sourceSize.w;

    return lines_t(upper_sample_y, lower_sample_y, upper_distance_y, lower_distance_y);
}
