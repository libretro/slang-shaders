#ifndef CURV
#define CURV

/*
Curvature code - Hyllian 2024

Public Domain

*/

#pragma parameter h_nonono        "HYLLIAN'S CURVATURE:"             1.0  0.0 1.0 1.0
#pragma parameter h_shape         "    Shape [ Sphere | Cylinder ]"  0.0  0.0 1.0 1.0
#pragma parameter h_radius        "    Curvature Radius"             4.0 1.5 10.0 0.1
#pragma parameter h_cornersize    "    Corner Size"                  0.05 0.01 1.0 0.01
#pragma parameter h_cornersmooth  "    Corner Smoothness"            0.5 0.1 1.0 0.1

float r2           = h_radius * h_radius;
vec2  max_size     = vec2(sqrt( (r2 - 2.0) / (r2 - 1.0) ), 1.0);
vec2  aspect       = vec2(1.0, 0.75); // It must be exchanged for the real aspect = vec2(1.0, OutputSize.y/OutputSize.x)
float cornersize   = h_cornersize * min(aspect.x, aspect.y);
float cornersmooth = h_cornersmooth/100.0;

vec2 h_warp(vec2 uv)
{
    uv = 2.0*uv - 1.0;

    vec2 cylinder = sqrt( (r2 - uv.x*uv.x) / (r2 - 2.0*uv.x*uv.x) )*max_size;
    vec2 sphere   = sqrt( (r2 - 1.0      ) / (r2 - dot(uv, uv))   ).xx;

    uv *= mix(sphere, cylinder, h_shape);

    return uv*0.5 + 0.5;
}

float h_corner(vec2 uv)
{
    vec2  d          = abs((2.0*uv - 1.0) * aspect) - (aspect - cornersize.xx);
    float borderline = length(max(d, 0.0.xx)) + min(max(d.x, d.y), 0.0) - cornersize;

    return smoothstep(cornersmooth, -cornersmooth, borderline);
}

#endif
