// Rotation functions borrowed from fishku
// See misc/shaders/input_transform/input_transform.inc for copyright and other information.
// This path will be used eventually.
//#include "../../../../../misc/shaders/input_transform/rotation.inc"
#include "rotation.inc"
#include "uborder_bezel_reflections_user_static_params.inc"


#ifdef KEEP_BORDER_ASPECT_RATIO
    #define RECALC_BORDER_ASPECT_RATIO                                                           \
        vec2 border_size    = textureSize(BORDER, 0);                                            \
        float border_aspect = border_size.y/border_size.x;                                       \
        float asp_ratio     = border_aspect/aspect.y;                                            \
        vec2 b_uv = border_uv * (asp_ratio > 1.0 ? vec2(1.0, 1.0/asp_ratio) : vec2(asp_ratio, 1.0)) + 0.5.xx;
#endif

float is_rotated  = mod(ub_Rotation, 2.);

vec2  fr_center   = get_rotated_vector(vec2(global.fr_center_x, global.fr_center_y)/100.0, ub_Rotation);
float all_zoom    = global.all_zoom/100.0;

vec2 OutputRotSize      = get_rotated_size(  ub_OutputSize.xy, ub_Rotation);
vec2 OriginalRotInvSize = get_rotated_size(ub_OriginalSize.zw, ub_Rotation);

vec2  int_ar            = vec2(global.fr_aspect_y / global.fr_aspect_x, 1.0);
vec2  rot_ar            = mix(int_ar, 1.0 / int_ar.yx, is_rotated);
float int_scale_factor  = max(floor(OutputRotSize.y * OriginalRotInvSize.y) + global.fr_i_scaling_fac-is_rotated, 1.0);
vec2  int_scale         = OutputRotSize.xy * OriginalRotInvSize.y * rot_ar / int_scale_factor;

vec2  float_scale       = OutputRotSize.x * global.fr_zoom * all_zoom / (OutputRotSize.xy  * 100.0
                          * rot_ar);


vec2 overscan         = 100.0/(get_rotated_size(vec2(global.h_overscan_x, global.h_overscan_y), ub_Rotation));
vec2 content_position = 2.0*get_rotated_vector(vec2(global.h_angle_x, global.h_angle_y), ub_Rotation);

//vec2  aspect       = vec2(1.0, OutputRotSize.y/OutputRotSize.x);

#ifdef KEEP_BORDER_ASPECT_RATIO
//    float b_aux = ASPECT_TEX_Y/(aspect.y*ASPECT_TEX_X);
    float b_aux = ASPECT_TEX_Y/((OutputRotSize.y/OutputRotSize.x)*ASPECT_TEX_X);
    float border_to_output = max(b_aux, 1.0/b_aux);
    vec2 fr_scale = border_to_output*get_rotated_size(mix(float_scale, 1.0/int_scale, global.fr_i_scaling), ub_Rotation);
#else
    vec2 fr_scale = get_rotated_size(mix(float_scale, 1.0/int_scale, global.fr_i_scaling), ub_Rotation);
#endif

float r2           = global.h_radius * global.h_radius;
//vec2  c_aspect     = vec2(1.0, OutputRotSize.y/OutputRotSize.x);
//float cornersize   = global.h_cornersize * min(aspect.x, aspect.y);
//vec2  c_aspect     = min((fr_scale.y*OutputRotSize.y),(OutputRotSize.x*fr_scale.x)).xx;
vec2  aspect       = min(1.0, (OutputRotSize.x*fr_scale.x)/(fr_scale.y*OutputRotSize.y)).xx;
float cornersize   = global.h_cornersize * min(aspect.x, aspect.y);

float cornersmooth = global.h_cornersmooth/100.0;
vec2  tilt         = global.h_radius*sin(get_rotated_vector(vec2(global.h_x_tilt, global.h_y_tilt), ub_Rotation));

const vec2  middle = 0.5.xx;

// Fast when two first params are constants.
float fsmoothstep(float a, float b, float x) {
    return clamp(x*(1.0/(b - a)) - (a/(b - a)), 0.0, 1.0);
//    return smoothstep(a, b, x);
}

vec2 fsmoothstep(vec2 a, vec2 b, vec2 x) {
    return clamp(x*(1.0/(b - a)) - (a/(b - a)), 0.0, 1.0);
//    return smoothstep(a, b, x);
}


/*
vec4 h_warp(vec4 uv)
{
    vec4 uvt = uv + vec4(tilt, 0.0.xx);

    vec4 cylinder = sqrt( (r4 - uvt.xz*uvt.xz) / (r4 - 2.0*uvt.xz*uvt.xz) )*max_size;
    vec2 sphere   = sqrt( (r4 - 1.0) / ( r4 - vec2(dot(uvt.xy, uvt.xy), dot(uvt.zw, uvt.zw)) ) );

    uv.xy *= mix(sphere.xx, cylinder.xy, global.h_shape);
    uv.zw *= mix(sphere.yy, cylinder.zw, global.h_shape2);

    return uv;
}
*/

#ifdef USE_BEZEL_REFLECTIONS_COMMON

#define BLVL(c) max(abs(c), 2e-2)  // Black Level for Arcade Vector Games
#define FIX(c)  max(abs(c), 1e-5);
#define PI 3.141592653589

#define R_BLUR_SIZE 0.02

float bz_curv_rad  = clamp(global.h_radius + global.bz_curve_radius, 1.8, 10.0);
float rz           = bz_curv_rad * bz_curv_rad;
//vec2  max_size_z   = vec2(sqrt( (rz - 2.0) / (rz - 1.0) ), 1.0);

float bz_in_curv_rad  = clamp(global.h_radius + global.bz_in_curve_radius, 1.8, 10.0);
float rz_in           = bz_in_curv_rad * bz_in_curv_rad;

vec2  bz_center   = get_rotated_vector(vec2(global.bz_center_x, global.bz_center_y)/100.0, ub_Rotation);

float shine_size = (1.0 - global.bz_shine_size  );
float amb_size   = (1.0 - global.bz_ambient_size);

vec2  shine_position = get_rotated_vector(vec2(0.0, 1.0), ub_Rotation);
const float SMTH     = 0.004;
vec2  bz_shadow      = get_rotated_vector(vec2(0.0, -0.06), ub_Rotation);

vec3 BZ_COLOR = vec3(global.bz_red, global.bz_green, global.bz_blue)/255.0;

vec2 INN_BZ = get_rotated_size(vec2(global.bz_inner_bezel_x, global.bz_inner_bezel_y), ub_Rotation) + 1.0.xx;
vec2 MID_BZ = get_rotated_size(vec2(global.bz_middle_bezel_x, global.bz_middle_bezel_y), ub_Rotation) + INN_BZ;
vec2 OUT_BZ = get_rotated_size(vec2(global.bz_outer_bezel_x, global.bz_outer_bezel_y), ub_Rotation) + MID_BZ;

float cyl_shape = (1.0-global.bz_outer_curve)*global.h_shape*global.h_curvature;

float mb_aspect = (MID_BZ.y-INN_BZ.y)/(MID_BZ.x-INN_BZ.x);

vec2  border_pos = vec2(global.border_center_x,global.border_center_y);

/*
vec2 bz_warp(vec2 uv)
{
    

    vec2 cylinder = sqrt( (rz - uv.x*uv.x) / (rz - 2.0*uv.x*uv.x) )*max_size_z;
    float sphere   =  sqrt( (rz - 1.0) / ( rz - dot(uv, uv) ) );

    uv *= mix(sphere.xx, cylinder, global.h_shape);

    return uv;
}*/

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}


// uv must be in the interval (-1.0, 1.0)
float RoundedRect(vec2 uv, vec2 size, float radius, vec2 blur)
{
    radius = radius * min(size.x, size.y);
    vec2 d = (abs(uv) - (size-radius.xx));
    float shape = length(max(d, 0.0.xx)) + min(max(d.x, d.y),  0.0) - radius;

    return fsmoothstep(-blur.x, blur.y, shape);
}

// uv must be in the interval (-1.0, 1.0)
vec2 RoundedRectVec(vec4 uv, vec4 size, vec2 radius, vec2 blur)
{
    radius = radius * min(size.xz, size.yw);
    vec4 d = (abs(uv) - (size-radius.xxyy));
    vec4 d4 = max(d, 0.0.xxxx);

    vec2 shape = vec2(length(d4.xy), length(d4.zw)) + min(max(d.xz, d.yw),  0.0.xx) - radius;

    return fsmoothstep(-blur, blur, shape);
}


// Calculate distance to get reflection coords
vec2 ReflectionCoords(vec2 uv, float r)
{
    vec2 ref_coord;
    vec2 size = (1.0-r).xx;

    vec2 maxs = uv - max(0.0.xx, 2.0*(uv - size));
    vec2 mins = uv - min(0.0.xx, 2.0*(uv + size));

    ref_coord.x = (uv.x >= 0.0) ? maxs.x : mins.x;
    ref_coord.y = (uv.y >= 0.0) ? maxs.y : mins.y;

    return 0.5*ref_coord + 0.5;
}

#endif


float h_corner(vec2 uv)
{
    vec2  d          = abs((2.0*uv - 1.0) * aspect) - (aspect - cornersize.xx);
    float borderline = length(max(d, 0.0.xx)) + min(max(d.x, d.y), 0.0) - cornersize;

    return fsmoothstep(cornersmooth, -cornersmooth, borderline);
}

vec2 h_warp(vec2 uv, float r, vec2 tilt)
{
    vec2 uvt = uv + tilt;
    vec2 max_size = vec2(sqrt( (r - 2.0) / (r - 1.0) ), 1.0);

    vec2 cylinder = sqrt( (r - uvt.x*uvt.x) / (r - 2.0*uvt.x*uvt.x) )*max_size;
    float sphere  = sqrt( (r - 1.0)         / (r - dot(uvt, uvt)  ) );

    uv *= mix(sphere.xx, cylinder, global.h_shape);

    return uv;
}
