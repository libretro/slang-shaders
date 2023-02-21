#ifndef SUBPIXEL_COLOR_DEFINDED

#define SUBPIXEL_COLOR_DEFINDED

#include "geometry-helper.h"

#define EPSILON 1e-6

const vec3 White = vec3(1.0, 1.0, 1.0);
const vec3 Black = vec3(0.0, 0.0, 0.0);
const vec3 Red = vec3(1.0, 0.0, 0.0);
const vec3 Blue = vec3(0.0, 0.0, 1.0);
const vec3 Green = vec3(0.0, 1.0, 0.0);
const vec3 Magenta = vec3(1.0, 0.0, 1.0);
const vec3 Yellow = vec3(1.0, 1.0, 0.0);
const vec3 Cyan = vec3(0.0, 1.0, 1.0);

// Returns an offset to shift the given pixel coordinate by the amount of x for every second y-block.
// @pixCoord - the pixel coordinate
// @x - the amount to shift the x-coordinate 
// @y - the size of a y-block
vec2 shift_x_every_y(vec2 pixCoord, float x, float y)
{
    return vec2(
        mix(0.0, x, floor(mod(pixCoord.y / y, 2.0))),
        0.0);
}

// Returns an offset to shift the given pixel coordinate by the amount of y for every second x-block.
// @pixCoord - the pixel coordinate
// @y - the amount to shift the y-coordinate 
// @x - the size of a x-block
vec2 shift_y_every_x(vec2 pixCoord, float y, float x)
{
    return vec2(
        0.0,
        mix(0.0, y, floor(mod(pixCoord.x / x, 2.0))));
}

int get_index(float pixCoord, int count)
{
    return int(floor(mod(pixCoord, count)));
}

vec3 get_subpixel_color(vec2 pixCoord, vec3 c1, vec3 c2)
{
    vec3 colors[2] = { c1, c2 };
    return colors[get_index(pixCoord.x, 2)];
}

vec3 get_subpixel_color(vec2 pixCoord, vec3 c1, vec3 c2, vec3 c3)
{
    vec3 colors[3] = { c1, c2, c3 };
    return colors[get_index(pixCoord.x, 3)];
}

vec3 get_subpixel_color(vec2 pixCoord, vec3 c1, vec3 c2, vec3 c3, vec3 c4)
{
    vec3 colors[4] = { c1, c2, c3, c4 };
    return colors[get_index(pixCoord.x, 4)];
}

// Gets the sub-pixel color of a mask with full saturation.
//    to apply a mask intensity add (1.0 - intensity) to the mask color.
// @pixCoord - the pixel coordinate
//    which is usually the texture coordinate multiplied by the output size.
// @size - the mask size
// @mask_type - the mask type [1, 3]
//    1: Aperture-grille
//    2: Slot-mask
//    3: Shadow-mask
// @subpixel_type - the subpixel type [1, 5]
//    1: white, black
//    2: green, magenta
//    3: green, magenta, black
//    4: red, green, blue
//    5: red, green, blue, black
// @color_swap - whether the sub-pixel colors shall be swapped
//    0: red/green/blue, green/magenta
//    1: blue/green/red, blue/yellow
vec3 get_subpixel_color(vec2 pixCoord, int size, int mask_type, int subpixel_type, bool color_swap)
{
    vec3 color = White;

    if (mask_type == 0 || subpixel_type == 0)
    {
        return color;
    }

    pixCoord /= size;

    vec3 c1 = color_swap ? Red : Blue;
    vec3 c2 = Green;
    vec3 c3 = color_swap ? Blue : Red;
    vec3 c4 = Black;

    if (subpixel_type == 1)
    {
        c1 = White;
        c2 = Black;
    }
    else if (subpixel_type == 2)
    {
        c1 = color_swap ? Yellow : Magenta;
        c2 = color_swap ? Blue : Green;
    }
    else if (subpixel_type == 3)
    {
        c1 = color_swap ? Yellow : Magenta;
        c2 = color_swap ? Blue : Green;
        c3 = Black;
    }

    // Aperture-grille
    if (mask_type == 1)
    {
        // white, black
        // green, magenta
        if (subpixel_type == 1 || subpixel_type == 2)
        {
            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // green, magenta, black
        // red, green, blue
        else if (subpixel_type == 3 || subpixel_type == 4)
        {
            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // red, green, blue, black
        else if (subpixel_type == 5)
        {
            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }
    }
    // Slot-mask
    else if (mask_type == 2)
    {
        // white, black
        // magenta, green
        if (subpixel_type == 1 || subpixel_type == 2)
        {
            pixCoord += shift_y_every_x(pixCoord, 2.0, 2.0);

            color = get_index(pixCoord.y, 4) == 0
                ? c4
                : get_subpixel_color(pixCoord, c1, c2);
        }
        // green, magenta, black
        // red, green, blue
        else if (subpixel_type == 3 || subpixel_type == 4)
        {
            pixCoord += shift_y_every_x(pixCoord, 2.0, 3.0);

            color = get_index(pixCoord.y, 4) == 0
                ? c4
                : get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // red, green, blue, black
        else if (subpixel_type == 5)
        {
            pixCoord += shift_y_every_x(pixCoord, 2.0, 4.0);

            color = get_index(pixCoord.y, 4) == 0
                ? c4
                : get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }
    }
    // Shadow-mask
    else if (mask_type == 3)
    {
        // white, black
        // magenta, green
        if(subpixel_type == 1 || subpixel_type == 2)
        {
            pixCoord += shift_x_every_y(pixCoord, 1.0, 1.0);

            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // green, magenta, black
        // reg, green, blue
        else if (subpixel_type == 3 || subpixel_type == 4)
        {
            pixCoord += shift_x_every_y(pixCoord, 1.5, 1.0);
            pixCoord.x *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift

            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // reg, green, blue, black
        else if (subpixel_type == 5)
        {
            pixCoord += shift_x_every_y(pixCoord, 2.0, 1.0);

            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }
    }

    return color;
}

// Gets the sub-pixel color of a mask with full saturation.
//    to apply a mask intensity add (1.0 - intensity) to the mask color.
// @pixCoord - the pixel coordinate
//    which is usually the texture coordinate multiplied by the output size.
// @size - the mask size
// @mask_type - the mask type [1, 3]
//    1: Aperture-grille
//    2: Slot-mask
//    3: Shadow-mask
// @subpixel_type - the subpixel type [1, 5]
//    1: white, black
//    2: green, magenta
//    3: green, magenta, black
//    4: red, green, blue
//    5: red, green, blue, black
// @color_swap - whether the sub-pixel colors shall be swapped
//    0: red/green/blue, green/magenta
//    1: blue/green/red, blue/yellow
// @radius - the corner radius of the sub-pixel
// @smoothness - the smoothness of the sub-pixel
vec3 get_subpixel_color(vec2 pixCoord, int size, int mask_type, int subpixel_type, bool color_swap, float radius, float smoothness)
{
    vec3 color = White;

    if (mask_type == 0 || subpixel_type == 0)
    {
        return color;
    }
    
    pixCoord /= size;

    vec2 bounds = vec2(1.0, 1.0);
    vec2 scale = vec2(1.0, 1.0);

    vec3 c1 = color_swap ? Red : Blue;
    vec3 c2 = Green;
    vec3 c3 = color_swap ? Blue : Red;
    vec3 c4 = Black;

    if (subpixel_type == 1)
    {
        c1 = White;
        c2 = Black;
    }
    else if (subpixel_type == 2)
    {
        c1 = color_swap ? Yellow : Magenta;
        c2 = color_swap ? Blue : Green;
    }
    else if (subpixel_type == 3)
    {
        c1 = color_swap ? Yellow : Magenta;
        c2 = color_swap ? Blue : Green;
        c3 = Black;
    }

    // Aperture-grille
    if (mask_type == 1)
    {
        // white, black
        // magenta, green
        if (subpixel_type == 1 || subpixel_type == 2)
        {
            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // magenta, green, black
        // red, green, blue
        else if (subpixel_type == 3 || subpixel_type == 4)
        {
            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // red, green, blue, black
        else if (subpixel_type == 5)
        {
            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }

        // for max 8K vertical resolution
        bounds = vec2(1.0, 1080.0 * 8.0);
    }
    // Slot-mask
    else if (mask_type == 2)
    {
        // correct shape for size 1
        float height = size == 1
            ? 4.0
            : 3.0;

        float offset =
            // correct shape for size 1
            size == 1 ? 0.5 :
            // correct shape for size 2
            size == 2 ? 0.25 :
            // default
            0.125;

        // white, black
        // magenta, green
        if (subpixel_type == 1 || subpixel_type == 2)
        {
            pixCoord += shift_y_every_x(pixCoord, 1.5, 2.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset;

            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // magenta, green, black
        // red, green, blue
        else if (subpixel_type == 3 || subpixel_type == 4)
        {
            pixCoord += shift_y_every_x(pixCoord, 1.5, 3.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset;

            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // red, green, blue, black
        else if (subpixel_type == 5)
        {
            pixCoord += shift_y_every_x(pixCoord, 1.5, 4.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset;

            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }

        bounds = vec2(1.0, height);
        scale = vec2(1.0, (height - offset * 2.0) / height);
    }
    // Shadow-mask
    else if (mask_type == 3)
    {
        // white, black
        // magenta, green
        if(subpixel_type == 1 || subpixel_type == 2)
        {
            pixCoord += shift_x_every_y(pixCoord, 1.0, 1.0);

            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // magenta, green, black
        // reg, green, blue
        else if (subpixel_type == 3 || subpixel_type == 4)
        {
            float shift =
                // correct shape for size 3
                size == 3 ? 1.0 / 6.0 :
                // default
                0.0;

            pixCoord += shift_x_every_y(pixCoord, 1.5 + shift, 1.0);
            pixCoord.x *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift

            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // reg, green, blue, black
        else if (subpixel_type == 5)
        {
            pixCoord += shift_x_every_y(pixCoord, 2.0, 1.0);

            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }
    }

    color *= smooth_round_box(
        fract(pixCoord / bounds),
        bounds * 1024.0, // virtually inflate bounds to be able to apply smoothness
        scale,
        radius,
        smoothness);

    return color;
}

#endif // SUBPIXEL_COLOR_DEFINDED
