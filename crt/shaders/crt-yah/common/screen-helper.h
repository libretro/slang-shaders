#ifndef SCREEN_HELPER_DEFINED

#define SCREEN_HELPER_DEFINED

#ifndef BASE_SIZE
    // The base size to compute the multiple from the source size.
    #define BASE_SIZE 240.0
#endif

#ifndef OUTPUT_SIZE
    // The output size.
    #define OUTPUT_SIZE global.FinalViewportSize
#endif

#ifndef MIN_PIXEL_SIZE
    // The allowed pixel size after the multiple has been applied.
    #define MIN_PIXEL_SIZE 3.0
#endif

#ifndef OFFSET_PRECISION
    // The precision of the multiple offset.
    #define OFFSET_PRECISION 0.05
#endif

#ifndef ALLOW_AUTO_SCALE
    // Whether the resolution shall be auto scaled.
    #define ALLOW_AUTO_SCALE true
#endif

#ifndef ALLOW_AUTO_UP_SCALE
    // Whether the resolution can be up scaled when auto scaled.
    #define ALLOW_AUTO_UP_SCALE false
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
int get_orientation(vec2 size)
{
    return int(is_portrait(size));
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
int get_orientation(vec2 size, int orientation)
{
    return orientation > 0
        ? orientation - 1
        : get_orientation(size);
}

// Returns the ratio of the size based on the dominant dimension.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation of the dominant dimension
//   0 - horizontal
//   1 - vertical
float get_ratio(vec2 size, int orientation)
{
    return orientation > 0
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
float get_base_size(vec2 size, int orientation)
{
    return orientation > 0
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

// Returns the multiple of the source size for the defined base size.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @source_size: the source size to test
//   e.g. global.SourceSize
// @orientation: the orientation
//   0 - horizontal
//   1 - vertical
float get_multiple(vec2 source_size, int orientation)
{
    float ratio = get_ratio(source_size, orientation);

    float portrait = float(is_portrait(source_size));

    float base_size = BASE_SIZE;
    base_size = orientation > 0
        ? mix(base_size * ratio, base_size, portrait)
        : mix(base_size, base_size * ratio, portrait);

    return orientation > 0
        ? source_size.x / base_size
        : source_size.y / base_size;
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

// Offsets the given multiple, limited by the given pixel size.
// @multiple: the multiple to offset
// @pixel_size: the limiting pixel size to apply the multiple
// @multiple_offset: the multiple offset
//   = 0.0 - the multiple will be rounded to the next integer greater equal to 1.
//   > 0.0 - in addition the multiple will be incremented by the offset.
//   < 0.0 - in addition the multiple will be decremented by the offset.
float offset_multiple(float multiple, float pixel_size, float multiple_offset)
{
    bool upscale = (multiple < 1.0 && ALLOW_AUTO_UP_SCALE);

    float index = upscale ? 1.0 / multiple : multiple;
    float sign = upscale ? -1.0 : 1.0;

    float multiple_index = sign * (max(1.0, round(index)) - 1.0);

    multiple_index += multiple_base;
    multiple_index += multiple_offset;

    for (multiple_index; multiple_index < multiple_count; multiple_index += OFFSET_PRECISION)
    {
        multiple = get_multiple_factor(multiple_index);

        // break at a multiple which results in a pixel size larger/equal the given limit
        if ((pixel_size * multiple) >= MIN_PIXEL_SIZE)
        {
            break;
        }
    }

    return multiple;
}

// Returns the auto-multiple of the given source size for the defined base size, scaled by the specified offset.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @source_size: the size to test
//   e.g. global.SourceSize
// @source_orientation: the orientation
//   0 - horizontal
//   1 - vertical
// @multiple_offset: the multiple offset
//   = 0.0 - the multiple will be rounded to the next integer greater equal to 1.
//   > 0.0 - in addition the multiple will be incremented by the offset.
//   < 0.0 - in addition the multiple will be decremented by the offset.
float get_auto_multiple(vec2 source_size, int source_orientation, float multiple_offset)
{
    float multiple = get_multiple(source_size, source_orientation);

    float pixel_size = source_orientation > 0
        ? OUTPUT_SIZE.x / source_size.x
        : OUTPUT_SIZE.y / source_size.y;

    return offset_multiple(multiple, pixel_size, multiple_offset);
}

// Returns the fixed-multiple of the given source size for the defined base size, scaled by the specified offset.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @source_size: the size to test
//   e.g. global.SourceSize
// @source_orientation: the orientation
//   0 - horizontal
//   1 - vertical
// @multiple_offset: the multiple offset
//   = 0.0 - the multiple will be rounded to the next integer greater equal to 1.
//   > 0.0 - in addition the multiple will be incremented by the offset.
//   < 0.0 - in addition the multiple will be decremented by the offset.
float get_fixed_multiple(vec2 source_size, int source_orientation, float multiple_offset)
{
    float multiple = 1.0;

    float pixel_size = source_orientation > 0
        ? OUTPUT_SIZE.x / source_size.x
        : OUTPUT_SIZE.y / source_size.y;

    return offset_multiple(multiple, pixel_size, multiple_offset);
}

float get_screen_multiple(vec2 source_size, int source_orientation, float multiple_offset)
{
    return ALLOW_AUTO_SCALE
        ? get_auto_multiple(source_size, source_orientation, multiple_offset)
        : get_fixed_multiple(source_size, source_orientation, multiple_offset);
}

#endif // SCREEN_HELPER_DEFINED
