#ifndef SUBPIXEL_COLOR_DEFINED

#define SUBPIXEL_COLOR_DEFINED

#include "constants.h"
#include "geometry-helper.h"

// colors
const vec3 White = vec3(1.0, 1.0, 1.0);
const vec3 Gray = vec3(0.5, 0.5, 0.5);
const vec3 Black = vec3(0.0, 0.0, 0.0);
const vec3 Red = vec3(1.0, 0.0, 0.0);
const vec3 Blue = vec3(0.0, 0.0, 1.0);
const vec3 Green = vec3(0.0, 1.0, 0.0);
const vec3 Magenta = vec3(1.0, 0.0, 1.0);
const vec3 Yellow = vec3(1.0, 1.0, 0.0);
const vec3 Cyan = vec3(0.0, 1.0, 1.0);

// shorthands
const vec3 W = White;
const vec3 U = Gray;
const vec3 X = Black;
const vec3 R = Red;
const vec3 G = Green;
const vec3 B = Blue;
const vec3 M = Magenta;
const vec3 Y = Yellow;
const vec3 C = Cyan;

// lookup tables for three colors
//   row is the sub-pixel type
//     0: white, black
//     1: green, magenta
//     2: green, magenta, (black)
//     3: red, green, blue
//     4: red, green, blue, (black)
//   column is the sub-pixel order
//     0: red/green/blue, green/magenta
//     1: blue/green/red, magenta/green
//     3: red/blue/Green, blue/yellow
//     4: green/blue/red, yellow/blue
//     5: blue/red/Green, cyan/red
//     6: green/red/blue, red/cyan
const vec3 MaskColor1[30] = vec3[30](
    W,   W,   W,   W,   W,   W,
    G,   M,   B,   Y,   C,   R,
    G,   M,   B,   Y,   C,   R,
    R,   B,   R,   G,   B,   G,
    R,   B,   R,   G,   B,   G
);

const vec3 MaskColor2[30] = vec3[30](
    X,   X,   X,   X,   X,   X,
    M,   G,   Y,   B,   R,   C,
    M,   G,   Y,   B,   R,   C,
    G,   G,   B,   B,   R,   R,
    G,   G,   B,   B,   R,   R
);

const vec3 MaskColor3[30] = vec3[30](
    U,   U,   U,   U,   U,   U,   // unused
    U,   U,   U,   U,   U,   U,   // unused
    X,   X,   X,   X,   X,   X,
    B,   R,   G,   R,   G,   B,
    B,   R,   G,   R,   G,   B
);

const vec3 MaskColor4[30] = vec3[30](
    U,   U,   U,   U,   U,   U,   // unused
    U,   U,   U,   U,   U,   U,   // unused
    U,   U,   U,   U,   U,   U,   // unused
    U,   U,   U,   U,   U,   U,   // unused
    X,   X,   X,   X,   X,   X
);

const int SubpixelTypes = 6;
const int SubpixelCounts[5] = int[](2, 2, 3, 3, 4);

// Returns an offset to shift the given pixel coordinate by x-amount for every second y-block.
// @pixCoord - the pixel coordinate
// @amount - the amount to shift the x-coordinate
// @size - the size of a y-block
vec2 shift_x_every_y(vec2 pixCoord, float amount, float size)
{
    return vec2(
        amount * floor(mod(pixCoord.y / size, 2.0)),
        0.0);
}

// Returns an offset to shift the given pixel coordinate by y-amount for every second x-block.
// @pixCoord - the pixel coordinate
// @amount - the amount to shift the y-coordinate
// @size - the size of a x-block
vec2 shift_y_every_x(vec2 pixCoord, float amount, float size)
{
    return vec2(
        0.0,
        amount * floor(mod(pixCoord.x / size, 2.0)));
}

// Returns an offset to shift the given pixel coordinate by x-amount for each x-block.
// @pixCoord - the pixel coordinate
// @amount - the amount to shift the x-coordinate
// @size - the size of a x-block
vec2 shift_x_each_x(vec2 pixCoord, float amount, float size)
{
    return vec2(
        amount * floor((pixCoord.x / size)),
        0.0);
}

int get_index(float pixCoord, int count)
{
    return int(floor(mod(pixCoord, count)));
}

vec3 get_subpixel_color(vec2 pixCoord, vec3 c1, vec3 c2, vec3 c3, vec3 c4, int count)
{
    vec3 colors[4] = vec3[]( c1, c2, c3, c4 );

    return colors[get_index(pixCoord.x, count)];
}

// Gets the sub-pixel color of a mask with full saturation.
//   to apply a mask intensity add (1.0 - intensity) to the mask color.
// @pixCoord - the pixel coordinate
//   which is usually the texture coordinate multiplied by the output size.
// @size - the mask size
// @mask_type - the mask type [1, 3]
//   0: Off
//   1: Aperture-grille
//   2: Slot-mask
//   3: Shadow-mask
// @subpixel_type - the subpixel type [1, 5]
//   1: white, black
//   2: green, magenta
//   3: green, magenta, black
//   4: red, green, blue
//   5: red, green, blue, black
// @color_order - determines the order of sub-pixel colors
//   1: red/green/blue, green/magenta
//   2: blue/green/red, magenta/green
//   3: red/blue/Green, blue/yellow
//   4: green/blue/red, yellow/blue
//   5: blue/red/Green, cyan/red
//   6: green/red/blue, red/cyan
vec3 get_subpixel_color(vec2 pixCoord, int size, int mask_type, int subpixel_type, int color_order)
{
    if (mask_type == 0)
    {
        return White;
    }

    subpixel_type -= 1;
    color_order -= 1;

    pixCoord /= size;

    // Aperture-grille
    // Slot-mask
    if (mask_type == 1
        || mask_type == 2)
    {
        // change gap (black) between color-blocks (e.g. RGB) to "half" a sub-pixel
        float gap = floor((0.5 * size) + EPSILON) / size;

        // green, magenta, black
        if (subpixel_type == 2)
        {
            // for size larger 1
            pixCoord += float(size > 1) * shift_x_each_x(pixCoord, gap, 3.0 - gap);
        }
        // red, green, blue, black
        else if (subpixel_type == 4)
        {
            // for size larger 1
            pixCoord += float(size > 1) * shift_x_each_x(pixCoord, gap, 4.0 - gap);
        }
    }

    float color_factor = 1.0;

    // Aperture-grille
    if (mask_type == 1)
    {
        // no coordinate transformation
    }
    // Slot-mask
    else if (mask_type == 2)
    {
        // white, black
        // magenta, green
        if (subpixel_type == 0 || subpixel_type == 1)
        {
            pixCoord += shift_y_every_x(pixCoord, 2.0, 2.0);
        }
        // green, magenta, black
        // red, green, blue
        else if (subpixel_type == 2 || subpixel_type == 3)
        {
            pixCoord += shift_y_every_x(pixCoord, 2.0, 3.0);
        }
        // red, green, blue, black
        else if (subpixel_type == 4)
        {
            pixCoord += shift_y_every_x(pixCoord, 2.0, 4.0);
        }

        // set color to 0 for each 4th row
        color_factor -= float(get_index(pixCoord.y, 4) == 0);
    }
    // Shadow-mask
    else if (mask_type == 3)
    {
        // white, black
        // magenta, green
        if(subpixel_type == 0 || subpixel_type == 1)
        {
            pixCoord += shift_x_every_y(pixCoord, 1.0, 1.0);
        }
        // green, magenta, black
        // reg, green, blue
        else if (subpixel_type == 2 || subpixel_type == 3)
        {
            pixCoord += shift_x_every_y(pixCoord, 1.5, 1.0);
            pixCoord.x *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
        }
        // reg, green, blue, black
        else if (subpixel_type == 4)
        {
            pixCoord += shift_x_every_y(pixCoord, 2.0, 1.0);
        }
    }

    int lutIndex = (subpixel_type * SubpixelTypes) + color_order;

    vec3 color = get_subpixel_color(
        pixCoord,
        MaskColor1[lutIndex],
        MaskColor2[lutIndex],
        MaskColor3[lutIndex],
        MaskColor4[lutIndex],
        SubpixelCounts[subpixel_type]);

    return color * color_factor;
}

// Gets the sub-pixel color of a mask with full saturation.
//   to apply a mask intensity add (1.0 - intensity) to the mask color.
// @pixCoord - the pixel coordinate
//   which is usually the texture coordinate multiplied by the output size.
// @size - the mask size
// @mask_type - the mask type [1, 3]
//   0: Off
//   1: Aperture-grille
//   2: Slot-mask
//   3: Shadow-mask
// @subpixel_type - the subpixel type [1, 5]
//   1: white, black
//   2: green, magenta
//   3: green, magenta, black
//   4: red, green, blue
//   5: red, green, blue, black
// @color_order - determines the order of sub-pixel colors
//   1: red/green/blue, green/magenta
//   2: blue/green/red, magenta/green
//   3: red/blue/Green, blue/yellow
//   4: green/blue/red, yellow/blue
//   5: blue/red/Green, cyan/red
//   6: green/red/blue, red/cyan
// @radius - the corner radius of the sub-pixel
// @smoothness - the smoothness of the sub-pixel
vec3 get_subpixel_color(vec2 pixCoord, int size, int mask_type, int subpixel_type, int color_order, float radius, float smoothness)
{
    if (mask_type == 0)
    {
        return White;
    }

    subpixel_type -= 1;
    color_order -= 1;

    pixCoord /= size;

    // Aperture-grille
    // Slot-mask
    if (mask_type == 1
        || mask_type == 2)
    {
        // change gap (black) between color-blocks (e.g. RGB) to "half" a sub-pixel
        float gap = floor(0.5 * size) / size;

        // green, magenta, black
        if (subpixel_type == 2)
        {
            // for size larger 1
            pixCoord += float(size > 1) * shift_x_each_x(pixCoord, gap, 3.0 - gap);
        }
        // red, green, blue, black
        else if (subpixel_type == 4)
        {
            // for size larger 1
            pixCoord += float(size > 1) * shift_x_each_x(pixCoord, gap, 4.0 - gap);
        }
    }

    vec2 bounds = vec2(1.0, 1.0);
    vec2 scale = vec2(1.0, 1.0);

    // Aperture-grille
    if (mask_type == 1)
    {
        // no coordinate transformation

        // for max 8K vertical resolution
        bounds = vec2(1.0, 1080.0 * 8.0);
    }
    // Slot-mask
    else if (mask_type == 2)
    {
        float height =
            // correct shape for size 1
            size == 1 ? 4.0 :
            // default
            3.0;

        float offset =
            // correct shape for size 1
            size == 1 ? 1.0 / 2.0 :
            // correct shape for size 2
            size == 2 ? 1.0 / 4.0 :
            // default
            1.0 / 6.0;

        float shift =
            // correct shape for size 3
            size == 3 ? 1.0 / 6.0 :
            // default
            0.0;

        // white, black
        // magenta, green
        if (subpixel_type == 0 || subpixel_type == 1)
        {
            pixCoord += shift_y_every_x(pixCoord, 1.5 + shift, 2.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset;
        }
        // magenta, green, black
        // red, green, blue
        else if (subpixel_type == 2 || subpixel_type == 3)
        {
            pixCoord += shift_y_every_x(pixCoord, 1.5 + shift, 3.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset;
        }
        // red, green, blue, black
        else if (subpixel_type == 4)
        {
            pixCoord += shift_y_every_x(pixCoord, 1.5 + shift, 4.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset;
        }

        bounds = vec2(1.0, height);
        scale = vec2(1.0, (height - offset * 2.0) / height);
    }
    // Shadow-mask
    else if (mask_type == 3)
    {
        // white, black
        // magenta, green
        if(subpixel_type == 0 || subpixel_type == 1)
        {
            pixCoord += shift_x_every_y(pixCoord, 1.0, 1.0);
        }
        // magenta, green, black
        // reg, green, blue
        else if (subpixel_type == 2 || subpixel_type == 3)
        {
            float shift =
                // correct shape for size 3
                size == 3 ? 1.0 / 6.0 :
                // default
                0.0;

            pixCoord += shift_x_every_y(pixCoord, 1.5 + shift, 1.0);
            pixCoord.x *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
        }
        // reg, green, blue, black
        else if (subpixel_type == 4)
        {
            pixCoord += shift_x_every_y(pixCoord, 2.0, 1.0);
        }
    }

    int lutIndex = (subpixel_type * SubpixelTypes) + color_order;

    vec3 color = get_subpixel_color(
        pixCoord,
        MaskColor1[lutIndex],
        MaskColor2[lutIndex],
        MaskColor3[lutIndex],
        MaskColor4[lutIndex],
        SubpixelCounts[subpixel_type]);

    if (size > 2)
    {
        color *= smooth_round_box(
            fract(pixCoord / bounds),
            bounds * 1024.0, // virtually inflate bounds to be able to apply smoothness
            scale,
            radius,
            smoothness);
    }
    else
    {
        color *= sharp_box(
            fract(pixCoord / bounds),
            scale);
    }

    return color;
}

#endif // SUBPIXEL_COLOR_DEFINED
