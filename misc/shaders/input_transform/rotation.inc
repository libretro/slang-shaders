// See input_transform.inc for copyright and other information.

vec2 get_rotated_size(vec2 x, uint rotation) {
    switch (rotation) {
        case 0:
        case 2:
        default:
            return x;
        case 1:
        case 3:
            return x.yx;
    }
}

vec4 get_rotated_crop(vec4 crop, uint rotation) {
    switch (rotation) {
        case 0:
        default:
            return crop;
        case 1:
            return crop.yzwx;
        case 2:
            return crop.zwxy;
        case 3:
            return crop.wxyz;
    }
}

vec2 get_rotated_vector(vec2 x, uint rotation) {
    switch (rotation) {
        case 0:
        default:
            return x;
        case 1:
            return vec2(-x.y, x.x);
        case 2:
            return -x;
        case 3:
            return vec2(x.y, -x.x);
    }
}

// Use to unrotate coordinates.
// It expects coordinates centered at (0.5,0.5).
vec2 get_unrotated_coords(vec2 x, uint rotation) {
    switch (rotation) {
        case 0:
        default:
            return x;
        case 1:
            return vec2(x.y, 1.0-x.x);
        case 2:
            return 1.0-x;
        case 3:
            return vec2(1.0-x.y, x.x);
    }
}
