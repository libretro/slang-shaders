vec2 get_rotated_size(vec2 x, uint rotation) {
    if      (rotation == 0 || rotation == 2) return x;
    else                                     return x.yx;
}

vec4 get_rotated_crop(vec4 crop, uint rotation) {
    if      (rotation == 0) return crop;
    else if (rotation == 1) return crop.yzwx;
    else if (rotation == 2) return crop.zwxy;
    else                    return crop.wxyz;
}

vec2 get_rotated_vector(vec2 x, uint rotation) {
    if      (rotation == 0) return x;
    else if (rotation == 1) return vec2(-x.y, x.x);
    else if (rotation == 2) return -x;
    else                    return vec2(x.y, -x.x);
}

// Use to unrotate coordinates.
// It expects coordinates centered at (0.5,0.5).
vec2 get_unrotated_coords(vec2 x, uint rotation) {
    if      (rotation == 0) return x;
    else if (rotation == 1) return vec2(x.y, 1.0-x.x);
    else if (rotation == 2) return 1.0-x;
    else                    return vec2(1.0-x.y, x.x);
}
