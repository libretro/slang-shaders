#ifndef GEOMETRY_HELPER_DEFINED

#define GEOMETRY_HELPER_DEFINED

// Returns a value determining whether the given point is inside an axis-align box
//   of the given size and corner radius.
// @point: the point to check.
// @size: the size of the box.
// @radius: the corner radius of the box.
// See: https://iquilezles.org/articles/distfunctions/
float round_box(vec2 point, vec2 size, float radius)
{
    vec2 distance  = abs(point) - size + radius;

    return length(max(distance, 0.0))
         + min(max(distance.x, distance.y), 0.0)
         - radius;
}

// Returns the intensity of a smooth rounded box at the given coordinate.
// @coord: the texture coordinate of the box.
// @bounds: the bounds of the box.
// @scale: the scale of the box within it's bounds.
// @radius: the corner radius of the box.
// @smoothness: the smoothness the box borders.
float smooth_round_box(vec2 coord, vec2 bounds, vec2 scale, float radius, float smoothness)
{
    // center, scale and position coordinate
    coord = (coord - 0.5) * (2.0 / scale);

    // compute round box
    float boxMinimum = min(bounds.x, bounds.y);
    float boxRadius = max(radius * boxMinimum, 1.0);
    float box = round_box(coord * bounds, bounds, boxRadius);

    // compute smoothness
    float boxSmoothness = 1.0 / (boxRadius * smoothness);
    float boxEdgeOffset = 1.0 - sqrt(boxSmoothness * 0.5);

    return smoothstep(1.0, 0.0, box * boxSmoothness + boxEdgeOffset);
}

// Returns the intensity of a sharp box at the given coordinate.
// @coord: the texture coordinate of the box.
// @scale: the scale of the box.
float sharp_box(vec2 coord, vec2 scale)
{
    // center, scale and mirror coordinate
    coord = abs((coord - 0.5) * 2.0) - scale;

    return step(max(coord.x, coord.y), 0.0);
}

#endif // GEOMETRY_HELPER_DEFINED
