#ifndef GEOMETRY_FUNCTIONS_H
#define GEOMETRY_FUNCTIONS_H

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale: A full-featured CRT shader, with cheese.
//  Copyright (C) 2014 TroggleMonkey <trogglemonkey@gmx.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA


//////////////////////////////////  INCLUDES  //////////////////////////////////

#include "../user-settings.h"
#include "derived-settings-and-constants.h"
#include "bind-shader-params.h"


////////////////////////////  MACROS AND CONSTANTS  ////////////////////////////

//  Curvature-related constants:
#define MAX_POINT_CLOUD_SIZE 9

/////////////////////////////  CURVATURE FUNCTIONS /////////////////////////////

vec2 quadratic_solve(const float a, const float b_over_2, const float c)
{
    //  Requires:   1.) a, b, and c are quadratic formula coefficients
    //              2.) b_over_2 = b/2.0 (simplifies terms to factor 2 out)
    //              3.) b_over_2 must be guaranteed < 0.0 (avoids a branch)
    //  Returns:    Returns vec2(first_solution, discriminant), so the caller
    //              can choose how to handle the "no intersection" case.  The
    //              Kahan or Citardauq formula is used for numerical robustness.
    const float discriminant = b_over_2*b_over_2 - a*c;
    const float solution0 = c/(-b_over_2 + sqrt(discriminant));
    return vec2(solution0, discriminant);
}

vec2 intersect_sphere(const vec3 view_vec, const vec3 eye_pos_vec)
{
    //  Requires:   1.) view_vec and eye_pos_vec are 3D vectors in the sphere's
    //                  local coordinate frame (eye_pos_vec is a position, i.e.
    //                  a vector from the origin to the eye/camera)
    //              2.) geom_radius is a global containing the sphere's radius
    //  Returns:    Cast a ray of direction view_vec from eye_pos_vec at a
    //              sphere of radius geom_radius, and return the distance to
    //              the first intersection in units of length(view_vec).
    //              http://wiki.cgsociety.org/index.php/Ray_Sphere_Intersection
    //  Quadratic formula coefficients (b_over_2 is guaranteed negative):
    const float a = dot(view_vec, view_vec);
    const float b_over_2 = dot(view_vec, eye_pos_vec);  //  * 2.0 factored out
    const float c = dot(eye_pos_vec, eye_pos_vec) - geom_radius*geom_radius;
    return quadratic_solve(a, b_over_2, c);
}

vec2 intersect_cylinder(const vec3 view_vec, const vec3 eye_pos_vec)
{
    //  Requires:   1.) view_vec and eye_pos_vec are 3D vectors in the sphere's
    //                  local coordinate frame (eye_pos_vec is a position, i.e.
    //                  a vector from the origin to the eye/camera)
    //              2.) geom_radius is a global containing the cylinder's radius
    //  Returns:    Cast a ray of direction view_vec from eye_pos_vec at a
    //              cylinder of radius geom_radius, and return the distance to
    //              the first intersection in units of length(view_vec).  The
    //              derivation of the coefficients is in Christer Ericson's
    //              Real-Time Collision Detection, p. 195-196, and this version
    //              uses LaGrange's identity to reduce operations.
    //  Arbitrary "cylinder top" reference point for an infinite cylinder:
    const vec3 cylinder_top_vec = vec3(0.0, geom_radius, 0.0);
    const vec3 cylinder_axis_vec = vec3(0.0, 1.0, 0.0);//vec3(0.0, 2.0*geom_radius, 0.0);
    const vec3 top_to_eye_vec = eye_pos_vec - cylinder_top_vec;
    const vec3 axis_x_view = cross(cylinder_axis_vec, view_vec);
    const vec3 axis_x_top_to_eye = cross(cylinder_axis_vec, top_to_eye_vec);
    //  Quadratic formula coefficients (b_over_2 is guaranteed negative):
    const float a = dot(axis_x_view, axis_x_view);
    const float b_over_2 = dot(axis_x_top_to_eye, axis_x_view);
    const float c = dot(axis_x_top_to_eye, axis_x_top_to_eye) -
        geom_radius*geom_radius;//*dot(cylinder_axis_vec, cylinder_axis_vec);
    return quadratic_solve(a, b_over_2, c);
}

vec2 cylinder_xyz_to_uv(const vec3 intersection_pos_local,
    const vec2 geom_aspect)
{
    //  Requires:   An xyz intersection position on a cylinder.
    //  Returns:    video_uv coords mapped to range [-0.5, 0.5]
    //  Mapping:    Define square_uv.x to be the signed arc length in xz-space,
    //              and define square_uv.y = -intersection_pos_local.y (+v = -y).
    //  Start with a numerically robust arc length calculation.
    const float angle_from_image_center = atan(intersection_pos_local.z,
		intersection_pos_local.x);
    const float signed_arc_len = angle_from_image_center * geom_radius;
    //  Get a uv-mapping where [-0.5, 0.5] maps to a "square" area, then divide
    //  by the aspect ratio to stretch the mapping appropriately:
    const vec2 square_uv = vec2(signed_arc_len, -intersection_pos_local.y);
    const vec2 video_uv = square_uv / geom_aspect;
    return video_uv;
}

vec3 cylinder_uv_to_xyz(const vec2 video_uv, const vec2 geom_aspect)
{
    //  Requires:   video_uv coords mapped to range [-0.5, 0.5]
    //  Returns:    An xyz intersection position on a cylinder.  This is the
    //              inverse of cylinder_xyz_to_uv().
    //  Expand video_uv by the aspect ratio to get proportionate x/y lengths,
    //  then calculate an xyz position for the cylindrical mapping above.
    const vec2 square_uv = video_uv * geom_aspect;
    const float arc_len = square_uv.x;
    const float angle_from_image_center = arc_len / geom_radius;
    const float x_pos = sin(angle_from_image_center) * geom_radius;
    const float z_pos = cos(angle_from_image_center) * geom_radius;
    //  Or: z = sqrt(geom_radius**2 - x**2)
    //  Or: z = geom_radius/sqrt(1.0 + tan(angle)**2), x = z * tan(angle)
    const vec3 intersection_pos_local = vec3(x_pos, -square_uv.y, z_pos);
    return intersection_pos_local;
}

vec2 sphere_xyz_to_uv(const vec3 intersection_pos_local,
    const vec2 geom_aspect)
{
    //  Requires:   An xyz intersection position on a sphere.
    //  Returns:    video_uv coords mapped to range [-0.5, 0.5]
    //  Mapping:    First define square_uv.x/square_uv.y ==
    //              intersection_pos_local.x/intersection_pos_local.y.  Then,
    //              length(square_uv) is the arc length from the image center
    //              at (0.0, 0.0, geom_radius) along the tangent great circle.
    //              Credit for this mapping goes to cgwg: I never managed to
    //              understand his code, but he told me his mapping was based on
    //              great circle distances when I asked him about it, which
    //              informed this very similar (almost identical) mapping.
    //  Start with a numerically robust arc length calculation between the ray-
    //  sphere intersection point and the image center using a method posted by
    //  Roger Stafford on comp.soft-sys.matlab:
    //  https://groups.google.com/d/msg/comp.soft-sys.matlab/zNbUui3bjcA/c0HV_bHSx9cJ
    const vec3 image_center_pos_local = vec3(0.0, 0.0, geom_radius);
    const float cp_len =
        length(cross(intersection_pos_local, image_center_pos_local));
    const float dp = dot(intersection_pos_local, image_center_pos_local);
    const float angle_from_image_center = atan(dp, cp_len);
    const float arc_len = angle_from_image_center * geom_radius;
    //  Get a uv-mapping where [-0.5, 0.5] maps to a "square" area, then divide
    //  by the aspect ratio to stretch the mapping appropriately:
    const vec2 square_uv_unit = normalize(vec2(intersection_pos_local.x,
        -intersection_pos_local.y));
    const vec2 square_uv = arc_len * square_uv_unit;
    const vec2 video_uv = square_uv / geom_aspect;
    return video_uv;
}

vec3 sphere_uv_to_xyz(const vec2 video_uv, const vec2 geom_aspect)
{
    //  Requires:   video_uv coords mapped to range [-0.5, 0.5]
    //  Returns:    An xyz intersection position on a sphere.  This is the
    //              inverse of sphere_xyz_to_uv().
    //  Expand video_uv by the aspect ratio to get proportionate x/y lengths,
    //  then calculate an xyz position for the spherical mapping above.
    const vec2 square_uv = video_uv * geom_aspect;
    //  Using length or sqrt here butchers the framerate on my 8800GTS if
    //  this function is called too many times, and so does taking the max
    //  component of square_uv/square_uv_unit (program length threshold?).
    //float arc_len = length(square_uv);
    const vec2 square_uv_unit = normalize(square_uv);
    const float arc_len = square_uv.y/square_uv_unit.y;
    const float angle_from_image_center = arc_len / geom_radius;
    const float xy_dist_from_sphere_center =
        sin(angle_from_image_center) * geom_radius;
    //vec2 xy_pos = xy_dist_from_sphere_center * (square_uv/FIX_ZERO(arc_len));
    const vec2 xy_pos = xy_dist_from_sphere_center * square_uv_unit;
    const float z_pos = cos(angle_from_image_center) * geom_radius;
    const vec3 intersection_pos_local = vec3(xy_pos.x, -xy_pos.y, z_pos);
    return intersection_pos_local;
}

vec2 sphere_alt_xyz_to_uv(const vec3 intersection_pos_local,
    const vec2 geom_aspect)
{
    //  Requires:   An xyz intersection position on a cylinder.
    //  Returns:    video_uv coords mapped to range [-0.5, 0.5]
    //  Mapping:    Define square_uv.x to be the signed arc length in xz-space,
    //              and define square_uv.y == signed arc length in yz-space.
    //  See cylinder_xyz_to_uv() for implementation details (very similar).
    const vec2 angle_from_image_center = atan((intersection_pos_local.zz),
        vec2(intersection_pos_local.x, -intersection_pos_local.y));
    const vec2 signed_arc_len = angle_from_image_center * geom_radius;
    const vec2 video_uv = signed_arc_len / geom_aspect;
    return video_uv;
}

vec3 sphere_alt_uv_to_xyz(const vec2 video_uv, const vec2 geom_aspect)
{
    //  Requires:   video_uv coords mapped to range [-0.5, 0.5]
    //  Returns:    An xyz intersection position on a sphere.  This is the
    //              inverse of sphere_alt_xyz_to_uv().
    //  See cylinder_uv_to_xyz() for implementation details (very similar).
    const vec2 square_uv = video_uv * geom_aspect;
    const vec2 arc_len = square_uv;
    const vec2 angle_from_image_center = arc_len / geom_radius;
    const vec2 xy_pos = sin(angle_from_image_center) * geom_radius;
    const float z_pos = sqrt(geom_radius*geom_radius - dot(xy_pos, xy_pos));
    return vec3(xy_pos.x, -xy_pos.y, z_pos);
}

vec2 intersect(const vec3 view_vec_local, const vec3 eye_pos_local,
    const float geom_mode)
{
    if (geom_mode < 2.5) return intersect_sphere(view_vec_local, eye_pos_local);
	else return intersect_cylinder(view_vec_local, eye_pos_local);
}

vec2 xyz_to_uv(const vec3 intersection_pos_local,
    const vec2 geom_aspect, const float geom_mode)
{
    if (geom_mode < 1.5) return sphere_xyz_to_uv(intersection_pos_local, geom_aspect);
	else if (geom_mode < 2.5) return sphere_alt_xyz_to_uv(intersection_pos_local, geom_aspect);
	else return cylinder_xyz_to_uv(intersection_pos_local, geom_aspect);
}

vec3 uv_to_xyz(const vec2 uv, const vec2 geom_aspect,
    const float geom_mode)
{
	if (geom_mode < 1.5) return sphere_uv_to_xyz(uv, geom_aspect);
	else if (geom_mode < 2.5) return sphere_alt_uv_to_xyz(uv, geom_aspect);
	else return cylinder_uv_to_xyz(uv, geom_aspect);
}

vec2 view_vec_to_uv(const vec3 view_vec_local, const vec3 eye_pos_local,
    const vec2 geom_aspect, const float geom_mode, out vec3 intersection_pos)
{
    //  Get the intersection point on the primitive, given an eye position
    //  and view vector already in its local coordinate frame:
    const vec2 intersect_dist_and_discriminant = intersect(view_vec_local,
        eye_pos_local, geom_mode);
    const vec3 intersection_pos_local = eye_pos_local +
        view_vec_local * intersect_dist_and_discriminant.x;
    //  Save the intersection position to an output parameter:
    intersection_pos = intersection_pos_local;
    //  Transform into uv coords, but give out-of-range coords if the
    //  view ray doesn't intersect the primitive in the first place:
	if (intersect_dist_and_discriminant.y > 0.005) return xyz_to_uv(intersection_pos_local, geom_aspect, geom_mode);
	else return vec2(1.0);
}

vec3 get_ideal_global_eye_pos_for_points(vec3 eye_pos,
    const vec2 geom_aspect, const vec3 global_coords[MAX_POINT_CLOUD_SIZE],
    const int num_points)
{
    //  Requires:   Parameters:
    //              1.) Starting eye_pos is a global 3D position at which the
    //                  camera contains all points in global_coords[] in its FOV
    //              2.) geom_aspect = get_aspect_vector(
    //                      IN.output_size.x / IN.output_size.y);
    //              3.) global_coords is a point cloud containing global xyz
    //                  coords of extreme points on the simulated CRT screen.
    //              Globals:
    //              1.) geom_view_dist must be > 0.0.  It controls the "near
    //                  plane" used to interpret flat_video_uv as a view
    //                  vector, which controls the field of view (FOV).
    //              Eyespace coordinate frame: +x = right, +y = up, +z = back
    //  Returns:    Return an eye position at which the point cloud spans as
    //              much of the screen as possible (given the FOV controlled by
    //              geom_view_dist) without being cropped or sheared.
    //  Algorithm:
    //  1.) Move the eye laterally to a point which attempts to maximize the
    //      the amount we can move forward without clipping the CRT screen.
    //  2.) Move forward by as much as possible without clipping the CRT.
    //  Get the allowed movement range by solving for the eye_pos offsets
    //  that result in each point being projected to a screen edge/corner in
    //  pseudo-normalized device coords (where xy ranges from [-0.5, 0.5]
    //  and z = eyespace z):
    //      pndc_coord = vec3(vec2(eyespace_xyz.x, -eyespace_xyz.y)*
    //      geom_view_dist / (geom_aspect * -eyespace_xyz.z), eyespace_xyz.z);
    //  Notes:
    //  The field of view is controlled by geom_view_dist's magnitude relative to
    //  the view vector's x and y components:
    //      view_vec.xy ranges from [-0.5, 0.5] * geom_aspect
    //      view_vec.z = -geom_view_dist
    //  But for the purposes of perspective divide, it should be considered:
    //      view_vec.xy ranges from [-0.5, 0.5] * geom_aspect / geom_view_dist
    //      view_vec.z = -1.0
    const int max_centering_iters = 1;  //  Keep for easy testing.
    for(int iter = 0; iter < max_centering_iters; iter++)
    {
        //  0.) Get the eyespace coordinates of our point cloud:
        vec3 eyespace_coords[MAX_POINT_CLOUD_SIZE];
        for(int i = 0; i < num_points; i++)
        {
            eyespace_coords[i] = global_coords[i] - eye_pos;
        }
        //  1a.)For each point, find out how far we can move eye_pos in each
        //      lateral direction without the point clipping the frustum.
        //      Eyespace +y = up, screenspace +y = down, so flip y after
        //      applying the eyespace offset (on the way to "clip space").
        //  Solve for two offsets per point based on:
        //      (eyespace_xyz.xy - offset_dr) * vec2(1.0, -1.0) *
        //      geom_view_dist / (geom_aspect * -eyespace_xyz.z) = vec2(-0.5)
        //      (eyespace_xyz.xy - offset_dr) * vec2(1.0, -1.0) *
        //      geom_view_dist / (geom_aspect * -eyespace_xyz.z) = vec2(0.5)
        //  offset_ul and offset_dr represent the farthest we can move the
        //  eye_pos up-left and down-right.  Save the min of all offset_dr's
        //  and the max of all offset_ul's (since it's negative).
        float abs_radius = abs(geom_radius);  //  In case anyone gets ideas. ;)
        vec2 offset_dr_min = vec2(10.0 * abs_radius, 10.0 * abs_radius);
        vec2 offset_ul_max = vec2(-10.0 * abs_radius, -10.0 * abs_radius);
        for(int i = 0; i < num_points; i++)
        {
            const vec2 flipy = vec2(1.0, -1.0);
            vec3 eyespace_xyz = eyespace_coords[i];
            vec2 offset_dr = eyespace_xyz.xy - vec2(-0.5) *
                (geom_aspect * -eyespace_xyz.z) / (geom_view_dist * flipy);
            vec2 offset_ul = eyespace_xyz.xy - vec2(0.5) *
                (geom_aspect * -eyespace_xyz.z) / (geom_view_dist * flipy);
            offset_dr_min = min(offset_dr_min, offset_dr);
            offset_ul_max = max(offset_ul_max, offset_ul);
        }
        //  1b.)Update eye_pos: Adding the average of offset_ul_max and
        //      offset_dr_min gives it equal leeway on the top vs. bottom
        //      and left vs. right.  Recalculate eyespace_coords accordingly.
        vec2 center_offset = 0.5 * (offset_ul_max + offset_dr_min);
        eye_pos.xy += center_offset;
        for(int i = 0; i < num_points; i++)
        {
            eyespace_coords[i] = global_coords[i] - eye_pos;
        }
        //  2a.)For each point, find out how far we can move eye_pos forward
        //      without the point clipping the frustum.  Flip the y
        //      direction in advance (matters for a later step, not here).
        //      Solve for four offsets per point based on:
        //      eyespace_xyz_flipy.x * geom_view_dist /
        //          (geom_aspect.x * (offset_z - eyespace_xyz_flipy.z)) =-0.5
        //      eyespace_xyz_flipy.y * geom_view_dist /
        //          (geom_aspect.y * (offset_z - eyespace_xyz_flipy.z)) =-0.5
        //      eyespace_xyz_flipy.x * geom_view_dist /
        //          (geom_aspect.x * (offset_z - eyespace_xyz_flipy.z)) = 0.5
        //      eyespace_xyz_flipy.y * geom_view_dist /
        //          (geom_aspect.y * (offset_z - eyespace_xyz_flipy.z)) = 0.5
        //      We'll vectorize the actual computation.  Take the maximum of
        //      these four for a single offset, and continue taking the max
        //      for every point (use max because offset.z is negative).
        float offset_z_max = -10.0 * geom_radius * geom_view_dist;
        for(int i = 0; i < num_points; i++)
        {
            vec3 eyespace_xyz_flipy = eyespace_coords[i] *
                vec3(1.0, -1.0, 1.0);
            vec4 offset_zzzz = eyespace_xyz_flipy.zzzz +
                (eyespace_xyz_flipy.xyxy * geom_view_dist) /
                (vec4(-0.5, -0.5, 0.5, 0.5) * vec4(geom_aspect, geom_aspect));
            //  Ignore offsets that push positive x/y values to opposite
            //  boundaries, and vice versa, and don't let the camera move
            //  past a point in the dead center of the screen:
            offset_z_max = (eyespace_xyz_flipy.x < 0.0) ?
                max(offset_z_max, offset_zzzz.x) : offset_z_max;
            offset_z_max = (eyespace_xyz_flipy.y < 0.0) ?
                max(offset_z_max, offset_zzzz.y) : offset_z_max;
            offset_z_max = (eyespace_xyz_flipy.x > 0.0) ?
                max(offset_z_max, offset_zzzz.z) : offset_z_max;
            offset_z_max = (eyespace_xyz_flipy.y > 0.0) ?
                max(offset_z_max, offset_zzzz.w) : offset_z_max;
            offset_z_max = max(offset_z_max, eyespace_xyz_flipy.z);
        }
        //  2b.)Update eye_pos: Add the maximum (smallest negative) z offset.
        eye_pos.z += offset_z_max;
    }
    return eye_pos;
}

vec3 get_ideal_global_eye_pos(const mat3x3 local_to_global,
    const vec2 geom_aspect, const float geom_mode)
{
    //  Start with an initial eye_pos that includes the entire primitive
    //  (sphere or cylinder) in its field-of-view:
    const vec3 high_view = vec3(0.0, geom_aspect.y, -geom_view_dist);
    const vec3 low_view = high_view * vec3(1.0, -1.0, 1.0);
    const float len_sq = dot(high_view, high_view);
    const float fov = abs(acos(dot(high_view, low_view)/len_sq));
    //  Trigonometry/similar triangles say distance = geom_radius/sin(fov/2):
    const float eye_z_spherical = geom_radius/sin(fov*0.5);
    vec3 eye_pos = vec3(0.0, 0.0, eye_z_spherical);
	if (geom_mode < 2.5) eye_pos = vec3(0.0, 0.0, max(geom_view_dist, eye_z_spherical));

    //  Get global xyz coords of extreme sample points on the simulated CRT
    //  screen.  Start with the center, edge centers, and corners of the
    //  video image.  We can't ignore backfacing points: They're occluded
    //  by closer points on the primitive, but they may NOT be occluded by
    //  the convex hull of the remaining samples (i.e. the remaining convex
    //  hull might not envelope points that do occlude a back-facing point.)
    const int num_points = MAX_POINT_CLOUD_SIZE;
    vec3 global_coords[MAX_POINT_CLOUD_SIZE];
    global_coords[0] = (uv_to_xyz(vec2(0.0, 0.0), geom_aspect, geom_mode) * local_to_global);
    global_coords[1] = (uv_to_xyz(vec2(0.0, -0.5), geom_aspect, geom_mode) * local_to_global);
    global_coords[2] = (uv_to_xyz(vec2(0.0, 0.5), geom_aspect, geom_mode) * local_to_global);
    global_coords[3] = (uv_to_xyz(vec2(-0.5, 0.0), geom_aspect, geom_mode) * local_to_global);
    global_coords[4] = (uv_to_xyz(vec2(0.5, 0.0), geom_aspect, geom_mode) * local_to_global);
    global_coords[5] = (uv_to_xyz(vec2(-0.5, -0.5), geom_aspect, geom_mode) * local_to_global);
    global_coords[6] = (uv_to_xyz(vec2(0.5, -0.5), geom_aspect, geom_mode) * local_to_global);
    global_coords[7] = (uv_to_xyz(vec2(-0.5, 0.5), geom_aspect, geom_mode) * local_to_global);
    global_coords[8] = (uv_to_xyz(vec2(0.5, 0.5), geom_aspect, geom_mode) * local_to_global);
    //  Adding more inner image points could help in extreme cases, but too many
    //  points will kille the framerate.  For safety, default to the initial
    //  eye_pos if any z coords are negative:
    float num_negative_z_coords = 0.0;
    for(int i = 0; i < num_points; i++)
    {
		if (global_coords[0].z < 0.0)
        {num_negative_z_coords += float(global_coords[0].z);}
    }
    //  Outsource the optimized eye_pos calculation:
	if (num_negative_z_coords > 0.5)
		return eye_pos;
	else
        return get_ideal_global_eye_pos_for_points(eye_pos, geom_aspect, global_coords, num_points);
}

mat3x3 get_pixel_to_object_matrix(const mat3x3 global_to_local,
    const vec3 eye_pos_local, const vec3 view_vec_global,
    const vec3 intersection_pos_local, const vec3 normal,
    const vec2 output_size_inv)
{
    //  Requires:   See get_curved_video_uv_coords_and_tangent_matrix for
    //              descriptions of each parameter.
    //  Returns:    Return a transformation matrix from 2D pixel-space vectors
    //              (where (+1.0, +1.0) is a vector to one pixel down-right,
    //              i.e. same directionality as uv texels) to 3D object-space
    //              vectors in the CRT's local coordinate frame (right-handed)
    //              ***which are tangent to the CRT surface at the intersection
    //              position.***  (Basically, we want to convert pixel-space
    //              vectors to 3D vectors along the CRT's surface, for later
    //              conversion to uv vectors.)
    //  Shorthand inputs:
    const vec3 pos = intersection_pos_local;
    const vec3 eye_pos = eye_pos_local;
    //  Get a piecewise-linear matrix transforming from "pixelspace" offset
    //  vectors (1.0 = one pixel) to object space vectors in the tangent
    //  plane (faster than finding 3 view-object intersections).
    //  1.) Get the local view vecs for the pixels to the right and down:
    const vec3 view_vec_right_global = view_vec_global +
        vec3(output_size_inv.x, 0.0, 0.0);
    const vec3 view_vec_down_global = view_vec_global +
        vec3(0.0, -output_size_inv.y, 0.0);
    const vec3 view_vec_right_local =
        (view_vec_right_global * global_to_local);
    const vec3 view_vec_down_local =
        (view_vec_down_global * global_to_local);
    //  2.) Using the true intersection point, intersect the neighboring
    //      view vectors with the tangent plane:
    const vec3 intersection_vec_dot_normal = vec3(dot(pos - eye_pos, normal));
    const vec3 right_pos = eye_pos + (intersection_vec_dot_normal /
        dot(view_vec_right_local, normal))*view_vec_right_local;
    const vec3 down_pos = eye_pos + (intersection_vec_dot_normal /
        dot(view_vec_down_local, normal))*view_vec_down_local;
    //  3.) Subtract the original intersection pos from its neighbors; the
    //      resulting vectors are object-space vectors tangent to the plane.
    //      These vectors are the object-space transformations of (1.0, 0.0)
    //      and (0.0, 1.0) pixel offsets, so they form the first two basis
    //      vectors of a pixelspace to object space transformation.  This
    //      transformation is 2D to 3D, so use (0, 0, 0) for the third vector.
    const vec3 object_right_vec = right_pos - pos;
    const vec3 object_down_vec = down_pos - pos;
    const mat3x3 pixel_to_object = mat3x3(
        object_right_vec.x, object_down_vec.x, 0.0,
        object_right_vec.y, object_down_vec.y, 0.0,
        object_right_vec.z, object_down_vec.z, 0.0);
    return pixel_to_object;
}

mat3x3 get_object_to_tangent_matrix(const vec3 intersection_pos_local,
    const vec3 normal, const vec2 geom_aspect, const float geom_mode)
{
    //  Requires:   See get_curved_video_uv_coords_and_tangent_matrix for
    //              descriptions of each parameter.
    //  Returns:    Return a transformation matrix from 3D object-space vectors
    //              in the CRT's local coordinate frame (right-handed, +y = up)
    //              to 2D video_uv vectors (+v = down).
    //  Description:
    //  The TBN matrix formed by the [tangent, bitangent, normal] basis
    //  vectors transforms ordinary vectors from tangent->object space.
    //  The cotangent matrix formed by the [cotangent, cobitangent, normal]
    //  basis vectors transforms normal vectors (covectors) from
    //  tangent->object space.  It's the inverse-transpose of the TBN matrix.
    //  We want the inverse of the TBN matrix (transpose of the cotangent
    //  matrix), which transforms ordinary vectors from object->tangent space.
    //  Start by calculating the relevant basis vectors in accordance with
    //  Christian Schüler's blog post "Followup: Normal Mapping Without
    //  Precomputed Tangents":  http://www.thetenthplanet.de/archives/1180
    //  With our particular uv mapping, the scale of the u and v directions
    //  is determined entirely by the aspect ratio for cylindrical and ordinary
    //  spherical mappings, and so tangent and bitangent lengths are also
    //  determined by it (the alternate mapping is more complex).  Therefore, we
    //  must ensure appropriate cotangent and cobitangent lengths as well.
    //  Base these off the uv<=>xyz mappings for each primitive.
    const vec3 pos = intersection_pos_local;
    const vec3 x_vec = vec3(1.0, 0.0, 0.0);
    const vec3 y_vec = vec3(0.0, 1.0, 0.0);
    //  The tangent and bitangent vectors correspond with increasing u and v,
    //  respectively.  Mathematically we'd base the cotangent/cobitangent on
    //  those, but we'll compute the cotangent/cobitangent directly when we can.
    vec3 cotangent_unscaled, cobitangent_unscaled;
    //  geom_mode should be constant-folded without RUNTIME_GEOMETRY_MODE.
    if(geom_mode < 1.5)
    {
        //  Sphere:
        //  tangent = normalize(cross(normal, cross(x_vec, pos))) * geom_aspect.x
        //  bitangent = normalize(cross(cross(y_vec, pos), normal)) * geom_aspect.y
        //  inv_determinant = 1.0/length(cross(bitangent, tangent))
        //  cotangent = cross(normal, bitangent) * inv_determinant
        //            == normalize(cross(y_vec, pos)) * geom_aspect.y * inv_determinant
        //  cobitangent = cross(tangent, normal) * inv_determinant
        //            == normalize(cross(x_vec, pos)) * geom_aspect.x * inv_determinant
        //  Simplified (scale by inv_determinant below):
        cotangent_unscaled = normalize(cross(y_vec, pos)) * geom_aspect.y;
        cobitangent_unscaled = normalize(cross(x_vec, pos)) * geom_aspect.x;
    }
    else if(geom_mode < 2.5)
    {
        //  Sphere, alternate mapping:
        //  This mapping works a bit like the cylindrical mapping in two
        //  directions, which makes the lengths and directions more complex.
        //  Unfortunately, I can't find much of a shortcut:
        const vec3 tangent = normalize(
            cross(y_vec, vec3(pos.x, 0.0, pos.z))) * geom_aspect.x;
        const vec3 bitangent = normalize(
            cross(x_vec, vec3(0.0, pos.yz))) * geom_aspect.y;
        cotangent_unscaled = cross(normal, bitangent);
        cobitangent_unscaled = cross(tangent, normal);
    }
    else
    {
        //  Cylinder:
        //  tangent = normalize(cross(y_vec, normal)) * geom_aspect.x;
        //  bitangent = vec3(0.0, -geom_aspect.y, 0.0);
        //  inv_determinant = 1.0/length(cross(bitangent, tangent))
        //  cotangent = cross(normal, bitangent) * inv_determinant
        //            == normalize(cross(y_vec, pos)) * geom_aspect.y * inv_determinant
        //  cobitangent = cross(tangent, normal) * inv_determinant
        //            == vec3(0.0, -geom_aspect.x, 0.0) * inv_determinant
        cotangent_unscaled = cross(y_vec, normal) * geom_aspect.y;
        cobitangent_unscaled = vec3(0.0, -geom_aspect.x, 0.0);
    }
    const vec3 computed_normal =
        cross(cobitangent_unscaled, cotangent_unscaled);
    const float inv_determinant = inversesqrt(dot(computed_normal, computed_normal));
    const vec3 cotangent = cotangent_unscaled * inv_determinant;
    const vec3 cobitangent = cobitangent_unscaled * inv_determinant;
    //  The [cotangent, cobitangent, normal] column vecs form the cotangent
    //  frame, i.e. the inverse-transpose TBN matrix.  Get its transpose:
    const mat3x3 object_to_tangent = mat3x3(cotangent, cobitangent, normal);
    return object_to_tangent;
}

vec2 get_curved_video_uv_coords_and_tangent_matrix(
    const vec2 flat_video_uv, const vec3 eye_pos_local,
    const vec2 output_size_inv, const vec2 geom_aspect,
    const float geom_mode, const mat3x3 global_to_local,
    out mat2x2 pixel_to_tangent_video_uv)
{
    //  Requires:   Parameters:
    //              1.) flat_video_uv coords are in range [0.0, 1.0], where
    //                  (0.0, 0.0) is the top-left corner of the screen and
    //                  (1.0, 1.0) is the bottom-right corner.
    //              2.) eye_pos_local is the 3D camera position in the simulated
    //                  CRT's local coordinate frame.  For best results, it must
    //                  be computed based on the same geom_view_dist used here.
    //              3.) output_size_inv = vec2(1.0)/IN.output_size
    //              4.) geom_aspect = get_aspect_vector(
    //                      IN.output_size.x / IN.output_size.y);
    //              5.) geom_mode is a static or runtime mode setting:
    //                  0 = off, 1 = sphere, 2 = sphere alt., 3 = cylinder
    //              6.) global_to_local is a 3x3 matrix transforming (ordinary)
    //                  worldspace vectors to the CRT's local coordinate frame
    //              Globals:
    //              1.) geom_view_dist must be > 0.0.  It controls the "near
    //                  plane" used to interpret flat_video_uv as a view
    //                  vector, which controls the field of view (FOV).
    //  Returns:    Return final uv coords in [0.0, 1.0], and return a pixel-
    //              space to video_uv tangent-space matrix in the out parameter.
    //              (This matrix assumes pixel-space +y = down, like +v = down.)
    //              We'll transform flat_video_uv into a view vector, project
    //              the view vector from the camera/eye, intersect with a sphere
    //              or cylinder representing the simulated CRT, and convert the
    //              intersection position into final uv coords and a local
    //              transformation matrix.
    //  First get the 3D view vector (geom_aspect and geom_view_dist are globals):
    //  1.) Center uv around (0.0, 0.0) and make (-0.5, -0.5) and (0.5, 0.5)
    //      correspond to the top-left/bottom-right output screen corners.
    //  2.) Multiply by geom_aspect to preemptively "undo" Retroarch's screen-
    //      space 2D aspect correction.  We'll reapply it in uv-space.
    //  3.) (x, y) = (u, -v), because +v is down in 2D screenspace, but +y
    //      is up in 3D worldspace (enforce a right-handed system).
    //  4.) The view vector z controls the "near plane" distance and FOV.
    //      For the effect of "looking through a window" at a CRT, it should be
    //      set equal to the user's distance from their physical screen, in
    //      units of the viewport's physical diagonal size.
    const vec2 view_uv = (flat_video_uv - vec2(0.5)) * geom_aspect;
    const vec3 view_vec_global =
        vec3(view_uv.x, -view_uv.y, -geom_view_dist);
    //  Transform the view vector into the CRT's local coordinate frame, convert
    //  to video_uv coords, and get the local 3D intersection position:
    const vec3 view_vec_local = (view_vec_global * global_to_local);
    vec3 pos;
    const vec2 centered_uv = view_vec_to_uv(
        view_vec_local, eye_pos_local, geom_aspect, geom_mode, pos);
    const vec2 video_uv = centered_uv + vec2(0.5);
    //  Get a pixel-to-tangent-video-uv matrix.  The caller could deal with
    //  all but one of these cases, but that would be more complicated.
    #ifdef DRIVERS_ALLOW_DERIVATIVES
        //  Derivatives obtain a matrix very fast, but the direction of pixel-
        //  space +y seems to depend on the pass.  Enforce the correct direction
        //  on a best-effort basis (but it shouldn't matter for antialiasing).
        const vec2 duv_dx = ddx(video_uv);
        const vec2 duv_dy = ddy(video_uv);
        #ifdef LAST_PASS
            pixel_to_tangent_video_uv = mat2x2(
                duv_dx.x, duv_dy.x,
                -duv_dx.y, -duv_dy.y);
        #else
            pixel_to_tangent_video_uv = mat2x2(
                duv_dx.x, duv_dy.x,
                duv_dx.y, duv_dy.y);
        #endif
    #else
        //  Manually define a transformation matrix.  We'll assume pixel-space
        //  +y = down, just like +v = down.
        if(geom_force_correct_tangent_matrix)
        {
            //  Get the surface normal based on the local intersection position:
            vec3 normal_base = pos;
			if (geom_mode > 2.5) normal_base = vec3(pos.x, 0.0, pos.z);
            const vec3 normal = normalize(normal_base);
            //  Get pixel-to-object and object-to-tangent matrices and combine
            //  them into a 2x2 pixel-to-tangent matrix for video_uv offsets:
            const mat3x3 pixel_to_object = get_pixel_to_object_matrix(
                global_to_local, eye_pos_local, view_vec_global, pos, normal,
                output_size_inv);
            const mat3x3 object_to_tangent = get_object_to_tangent_matrix(
                pos, normal, geom_aspect, geom_mode);
            const mat3x3 pixel_to_tangent3x3 =
                (pixel_to_object * object_to_tangent);
            pixel_to_tangent_video_uv = mat2x2(
                pixel_to_tangent3x3[0].xyz, pixel_to_tangent3x3[1].x);
        }
        else
        {
            //  Ignore curvature, and just consider flat scaling.  The
            //  difference is only apparent with strong curvature:
            pixel_to_tangent_video_uv = mat2x2(
                output_size_inv.x, 0.0, 0.0, output_size_inv.y);
        }
    #endif
    return video_uv;
}

float get_border_dim_factor(const vec2 video_uv, const vec2 geom_aspect)
{
    //  COPYRIGHT NOTE FOR THIS FUNCTION:
    //  Copyright (C) 2010-2012 cgwg, 2014 TroggleMonkey
    //  This function uses an algorithm first coded in several of cgwg's GPL-
    //  licensed lines in crt-geom-curved.cg and its ancestors.  The line
    //  between algorithm and code is nearly indistinguishable here, so it's
    //  unclear whether I could even release this project under a non-GPL
    //  license with this function included.

    //  Calculate border_dim_factor from the proximity to uv-space image
    //  borders; geom_aspect/border_size/border/darkness/border_compress are globals:
    const vec2 edge_dists = min(video_uv, vec2(1.0) - video_uv) *
        geom_aspect;
    const vec2 border_penetration =
        max(vec2(border_size) - edge_dists, vec2(0.0));
    const float penetration_ratio = length(border_penetration)/border_size;
    const float border_escape_ratio = max(1.0 - penetration_ratio, 0.0);
    const float border_dim_factor =
        pow(border_escape_ratio, border_darkness) * max(1.0, border_compress);
    return min(border_dim_factor, 1.0);
}

#endif  //  GEOMETRY_FUNCTIONS_H