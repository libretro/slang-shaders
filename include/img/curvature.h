#ifndef CURV
#define CURV

// A collection of 2D curvature/warp functions

// torridgristle
vec2 tg_warp(vec2 texCoord){
  vec2 Distortion = vec2(warpX, warpY) * 15.;
  vec2 curvedCoords = texCoord * 2.0 - 1.0;
  float curvedCoordsDistance = sqrt(curvedCoords.x*curvedCoords.x+curvedCoords.y*curvedCoords.y);

  curvedCoords = curvedCoords / curvedCoordsDistance;

  curvedCoords = curvedCoords * (1.0-pow(vec2(1.0-(curvedCoordsDistance/1.4142135623730950488016887242097)),(1.0/(1.0+Distortion*0.2))));

  curvedCoords = curvedCoords / (1.0-pow(vec2(0.29289321881345247559915563789515),(1.0/(vec2(1.0)+Distortion*0.2))));

  curvedCoords = curvedCoords * 0.5 + 0.5;
  return curvedCoords;
}

// lottes
// Distortion of scanlines, and end of screen alpha.
vec2 tl_warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*warpX, 1.0 + (pos.x*pos.x)*warpY);
    
    return pos*0.5 + 0.5;
}

/* Curvature by kokoko3k, GPL-3.0 license
 * w.x and w.y are global warp parameters
 * protrusion is the rounded shape near the middle
 * keep protrusion higher than ~0.5 
*/
vec2 Warp_koko(vec2 co, vec2 w, float protrusion) {
    float czoom  = 1 - distance(co, vec2(0.5));
    czoom        = mix(czoom, czoom * protrusion, czoom);
    vec2 czoom2d = mix(vec2(1.0), vec2(czoom), w);
    vec2 coff    = mix( vec2(0.0), vec2(0.625), w);
    return 0.5 + (co - 0.5) / (coff + czoom2d);
}

// cgwg's geom
// license: GPLv2

const float d = 1.5;
const vec2 sinangle = vec2(1.0);
const vec2 cosangle = vec2(1.0);
const vec2 aspect   = vec2(1.0,  0.75);
float R = max(warpX, warpY);
#define FIX(c) max(abs(c), 1e-5);

float intersect(vec2 xy)
{
    float A = dot(xy,xy) + d*d;
    float B = 2.0*(R*(dot(xy,sinangle) - d*cosangle.x*cosangle.y) - d*d);
    float C = d*d + 2.0*R*d*cosangle.x*cosangle.y;
    
    return (-B-sqrt(B*B - 4.0*A*C))/(2.0*A);
}

vec2 fwtrans(vec2 uv)
{
    float r = FIX(sqrt(dot(uv,uv)));
    uv *= sin(r/R)/r;
    float x = 1.0-cos(r/R);
    float D = d/R + x*cosangle.x*cosangle.y+dot(uv,sinangle);
    
    return d*(uv*cosangle-x*sinangle)/D;
}

vec3 maxscale()
{
    vec2 c  = bkwtrans(-R * sinangle / (1.0 + R/d*cosangle.x*cosangle.y));
    vec2 a  = vec2(0.5,0.5)*aspect;
    
    vec2 lo = vec2(fwtrans(vec2(-a.x,  c.y)).x,
                   fwtrans(vec2( c.x, -a.y)).y)/aspect;

    vec2 hi = vec2(fwtrans(vec2(+a.x,  c.y)).x,
                   fwtrans(vec2( c.x, +a.y)).y)/aspect;
    
    return vec3((hi+lo)*aspect*0.5,max(hi.x-lo.x,hi.y-lo.y));
}

vec2 bkwtrans(vec2 xy)
{
    float c     = intersect(xy);
    vec2 point  = (vec2(c, c)*xy - vec2(-R, -R)*sinangle) / vec2(R, R);
    vec2 poc    = point/cosangle;
    vec2 tang   = sinangle/cosangle;

    float A     = dot(tang, tang) + 1.0;
    float B     = -2.0*dot(poc, tang);
    float C     = dot(poc, poc) - 1.0;

    float a     = (-B + sqrt(B*B - 4.0*A*C)) / (2.0*A);
    vec2 uv     = (point - a*sinangle) / cosangle;
    float r     = FIX(R*acos(a));
    
    return uv*r/sin(r/R);
}

vec2 cgwg_warp(vec2 coord)
{
    vec3 stretch = maxscale();
    coord = (coord - vec2(0.5, 0.5))*aspect*stretch.z + stretch.xy;
    
    return (bkwtrans(coord) /
        vec2(1.0, 1.0)/aspect + vec2(0.5, 0.5));
}



float corner(vec2 coord)
{
    coord = (coord - vec2(0.5)) + vec2(0.5, 0.5);
    coord = min(coord, vec2(1.0) - coord) * aspect;
    vec2 cdist = vec2(cornersize);
    coord = (cdist - min(coord, cdist));
    float dist = sqrt(dot(coord, coord));
    
    return clamp((cdist.x - dist)*cornersmooth, 0.0, 1.0);
}

// Hyllian's Curvature

const float h_radius       = 4.0; // Should be a user param.
const float h_shape        = 0.0; // Sphere=0.0, Cylinder=1.0 // Should be a user param.
const float h_cornersize   = 0.05; // Should be a user param.
const float h_cornersmooth = 0.005; // Should be a user param.
const vec2  h_aspect       = vec2(1.0, 0.75); // Use (params.OutputSize.y/params.OutputSize.x) instead 0.75
float r2                   = h_radius * h_radius;
float h_csize              = h_cornersize * min(h_aspect.x, h_aspect.y);
vec2  max_size             = vec2(sqrt( (r2 - 2.0) / (r2 - 1.0) ), 1.0);

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
    vec2  d          = abs((2.0*uv - 1.0) * h_aspect) - (h_aspect - h_csize.xx);
    float borderline = length(max(d, 0.0.xx)) + min(max(d.x, d.y), 0.0) - h_csize;

    return smoothstep(h_cornersmooth, -h_cornersmooth, borderline);
}


#endif
