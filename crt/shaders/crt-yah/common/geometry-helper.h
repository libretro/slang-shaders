#ifndef GEOMETRY_HELPER

#define GEOMETRY_HELPER

// Returns a value determining whether the given point is inside an axis-align box
//   of the given size and corner radius.
// @point: the point to check.
// @size: the size of the box.
// @radius: the corner radius of the box.
// See: https://iquilezles.org/articles/distfunctions/
float round_box(vec2 point, vec2 size, float radius)
{
    return length(max(abs(point) - size + radius, 0.0)) - radius;
}

// Returns the intensity of a smooth rounded box at the given coordinate.
// @coord: the texture coordinate of the box.
// @bounds: the bounds of the box.
// @scale: the scale of the box within it's bounds.
// @radius: the corner radius of the box.
// @smoothness: the smoothness the box borders.
float smooth_round_box(vec2 coord, vec2 bounds, vec2 scale, float radius, float smoothness)
{
    // center coordinates
    coord -= 0.5;
    // full bounds
    coord *= 2.0;
    // individual scale
    coord /= scale;

    // compute round box
    float boxMinimum = min(bounds.x, bounds.y);
    float boxRadius = boxMinimum * max(radius, 1.0 / boxMinimum);
    float box = round_box(coord * bounds, bounds, boxRadius);

    // apply smoothness
    float boxSmooth = 1.0 / (boxRadius * smoothness);
    box *= boxSmooth;
    box += 1.0 - pow(boxSmooth * 0.5, 0.5);

    return clamp(smoothstep(1.0, 0.0, box), 0.0, 1.0);
}

#endif // GEOMETRY_HELPER
