#ifndef SCREEN_HELPER

#define SCREEN_HELPER

#ifndef BASE_SIZE
    // The base size to compute the multiple from the source size.
    #define BASE_SIZE 240.0
#endif

#ifndef OUTPUT_SIZE
    // The output size.
    #define OUTPUT_SIZE global.FinalViewportSize
#endif

#ifndef PIXEL_SIZE_LIMIT
    // The allowed pixel size after the multiple has been applied.
    #define PIXEL_SIZE_LIMIT 3.0
#endif

#ifndef OFFSET_PRECISTION
    // The precistion of the multiple offset.
    #define OFFSET_PRECISTION 0.05
#endif

// Returns whether the x-axis is the largest dimension of the given size.
//   0 - horizontal
//   1 - vertical
// @size: the size to test
bool is_landscape(vec2 size)
{
    return size.x >= size.y;
}

// Returns whether the y-axis is the largest dimension of the given size.
//   0 - horizontal
//   1 - vertical
// @size: the size to test
bool is_portrait(vec2 size)
{
    return size.y > size.x;
}

// Returns the orientation based on the largest dimension of the given size.
//   0 - horizontal
//   1 - vertical
// @size: the size to test
//   e.g. global.OutputSize
float get_orientation(vec2 size)
{
    return float(is_portrait(size));
}

// Returns the orientation based on the largest dimension of the given size.
//   0 - horizontal
//   1 - vertical
// @size: the size to test
//   e.g. global.OutputSize
// @orientation: the preferred orientation
//   0 - auto
//   1 - horizontal
//   2 - vertical
float get_orientation(vec2 size, float orientation)
{
    return orientation > 0.0
        ? orientation - 1.0
        : get_orientation(size);
}

// Returns the ratio of the size based on the dominant dimension.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation of the dominant dimension
//   0 - horizontal
//   1 - vertical
float get_ratio(vec2 size, float orientation)
{
    return orientation > 0.0
        ? size.x / size.y
        : size.y / size.x;
}

// Returns the ratio of the size based on the dominant orientation.
// @size: the size to test
//   e.g. global.SourceSize
float get_ratio(vec2 size)
{
    return get_ratio(size, get_orientation(size));
}

// Returns the base size based on the dominant orientation.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation of the dominant dimension
//   0 - horizontal
//   1 - vertical
float get_base_size(vec2 size, float orientation)
{
    return orientation > 0.0
        ? size.x
        : size.y;
}

// Returns the base size based on the dominant orientation.
// @size: the size to test
//   e.g. global.SourceSize
float get_base_size(vec2 size)
{
    return get_base_size(size, get_orientation(size));
}

// Returns the multiple of the size for the defined base size.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation
//   0 - horizontal
//   1 - vertical
float get_multiple(vec2 size, float orientation)
{
    float ratio = get_ratio(size, orientation);

    float portrait = float(is_portrait(size));

    float base_size = BASE_SIZE;
    base_size = orientation > 0.0
        ? mix(base_size * ratio, base_size, portrait)
        : mix(base_size, base_size * ratio, portrait);

    return orientation > 0.0
        ? size.x / base_size
        : size.y / base_size;
}

// Returns the multiple of the size for the defined base size.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @size: the size to test
//   e.g. global.SourceSize
float get_multiple(vec2 size)
{
    return get_multiple(size, get_orientation(size));
}

const int multiple_base = 8;
const int multiple_count = 17;
const float multiple_factors[multiple_count] = float[multiple_count](
    1.0 / 9.0,
    1.0 / 8.0,
    1.0 / 7.0,
    1.0 / 6.0,
    1.0 / 5.0,
    1.0 / 4.0,
    1.0 / 3.0,
    1.0 / 2.0,
    1.0, // base
    2.0,
    3.0,
    4.0,
    5.0,
    6.0,
    7.0,
    8.0,
    9.0);

float get_multiple_factor(float index)
{
    // interpolate for index with fractional part
    return mix(
        multiple_factors[int(clamp(floor(index), 0.0, multiple_count - 1.0))],
        multiple_factors[int(clamp(ceil(index), 0.0, multiple_count - 1.0))],
        fract(index));
}

// Returns the multiple of the size for the defined base size, scaled by the specified offset.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation
//   0 - horizontal
//   1 - vertical
// @offset: the scaling offset
//   = 0.0 - the multiple will be rounded to the next integer greater equal to 1.
//   > 0.0 - in addition the multiple will be incremented by the offset.
//   < 0.0 - in addition the multiple will be decremented by the offset.
float get_multiple(vec2 size, float orientation, float offset)
{
    float multiple = get_multiple(size, orientation);
    float multiple_index = max(1.0, round(multiple)) - 1.0;

    multiple_index += multiple_base;
    multiple_index += offset;

    float scale = orientation > 0.0
        ? OUTPUT_SIZE.x / size.x
        : OUTPUT_SIZE.y / size.y;
    for (multiple_index; multiple_index < multiple_count; multiple_index += OFFSET_PRECISTION)
    {
        multiple = get_multiple_factor(multiple_index);
        
        // break at a multiple which results in a pixel size larger/equal the given limit
        if ((scale * multiple) >= PIXEL_SIZE_LIMIT)
        {
            break;
        }
    }

    return multiple;
}

#endif // SCREEN_HELPER
