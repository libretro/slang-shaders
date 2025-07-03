
layout(push_constant) uniform Push
{
    float RSUBPIX_R;
    float RSUBPIX_G;
    float RSUBPIX_B;
    float GSUBPIX_R;
    float GSUBPIX_G;
    float GSUBPIX_B;
    float BSUBPIX_R;
    float BSUBPIX_G;
    float BSUBPIX_B;
    float gain;
    float gamma;
    float blacklevel;
    float ambient;
    float BGR;
} params;

#define USE_BEZEL_REFLECTIONS_COMMON

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;

#include "../../include/uborder_bezel_reflections_global_declarations.inc"

} global;


#include "../../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     global.OutputSize
#define ub_OriginalSize   global.OriginalSize
#define ub_Rotation       global.Rotation

#include "../../include/uborder_bezel_reflections_common.inc"

#pragma parameter lcd_grid_nonono       "LCD-GRID-V2:"                           0.0  0.0 1.0 1.0
#pragma parameter RSUBPIX_R  "Colour of R subpixel: R" 1.0 0.0 1.0 0.01
#pragma parameter RSUBPIX_G  "Colour of R subpixel: G" 0.0 0.0 1.0 0.01
#pragma parameter RSUBPIX_B  "Colour of R subpixel: B" 0.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_R  "Colour of G subpixel: R" 0.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_G  "Colour of G subpixel: G" 1.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_B  "Colour of G subpixel: B" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_R  "Colour of B subpixel: R" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_G  "Colour of B subpixel: G" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_B  "Colour of B subpixel: B" 1.0 0.0 1.0 0.01
#pragma parameter gain       "Gain"                    1.0 0.5 2.0 0.05
#pragma parameter gamma      "LCD Gamma"               3.0 0.5 5.0 0.1
#pragma parameter blacklevel "Black level"            0.05 0.0 0.5 0.01
#pragma parameter ambient    "Ambient"                 0.0 0.0 0.5 0.01
#pragma parameter BGR        "BGR"                     0 0 1 1

#define outgamma 2.2

#define fetch_offset(coord, offset) (pow(vec3(params.gain) * texelFetchOffset(Source, (coord), 0, (offset)).rgb + vec3(params.blacklevel), vec3(params.gamma)) + vec3(params.ambient))

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 uv;
layout(location = 2) out vec2 border_uv;
layout(location = 3) out vec2 bezel_uv;


void main()
{
    gl_Position = global.MVP * Position;
//   vTexCoord = TexCoord;

    vec2 diff    = TexCoord.xy * vec2(1.000001) - middle;
    vTexCoord    = middle + diff/fr_scale - fr_center;

    uv           = 2.0*vTexCoord - 1.0;
    bezel_uv  = uv - 2.0*bz_center;

    border_uv = get_unrotated_coords(get_unrotated_coords(TexCoord.xy, ub_Rotation), int(global.border_allow_rot));


    border_uv.y = mix(border_uv.y, 1.0-border_uv.y, border_mirror_y);

    border_uv = middle + (border_uv.xy - middle - border_pos) / (global.border_scale*all_zoom);

    border_uv = border_uv.xy * vec2(1.000001);

#ifdef KEEP_BORDER_ASPECT_RATIO
    border_uv -= 0.5.xx;
#endif
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec2 border_uv;
layout(location = 3) in vec2 bezel_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;
layout(set = 0, binding = 4) uniform sampler2D LAYER2;
#ifdef USE_AMBIENT_LIGHT
layout(set = 0, binding = 5) uniform sampler2D ambi_temporal_pass;
#endif
// integral of (1 - x^2 - x^4 + x^6)^2
float coeffs_x[7] = float[](1.0, -2.0/3.0, -1.0/5.0, 4.0/7.0, -1.0/9.0, -2.0/11.0, 1.0/13.0);
// integral of (1 - 2x^4 + x^6)^2
float coeffs_y[7] = float[](1.0,      0.0, -4.0/5.0, 2.0/7.0,  4.0/9.0, -4.0/11.0, 1.0/13.0);

float intsmear_func(float z, float coeffs[7])
{
    float z2 = z*z;
    float zn = z;
    float ret = 0.0;
    for (int i = 0; i < 7; i++) {
        ret += zn*coeffs[i];
        zn *= z2;
    }
    return ret;
}

float intsmear(float x, float dx, float d, float coeffs[7])
{
    float zl = clamp((x-dx*0.5)/d,-1.0,1.0);
    float zh = clamp((x+dx*0.5)/d,-1.0,1.0);
    return d * ( intsmear_func(zh,coeffs) - intsmear_func(zl,coeffs) )/dx;
}


vec3 get_content(vec2 vTex, vec2 uv)
{
    vec2 texelSize = global.SourceSize.zw;
    /* float2 range = IN.video_size / (IN.output_size * IN.texture_size); */
    vec2 range = global.OutputSize.zw;

    vec3 cred   = pow(vec3(params.RSUBPIX_R, params.RSUBPIX_G, params.RSUBPIX_B), vec3(outgamma));
    vec3 cgreen = pow(vec3(params.GSUBPIX_R, params.GSUBPIX_G, params.GSUBPIX_B), vec3(outgamma));
    vec3 cblue  = pow(vec3(params.BSUBPIX_R, params.BSUBPIX_G, params.BSUBPIX_B), vec3(outgamma));

    ivec2 tli = ivec2(floor(vTex/texelSize-vec2(0.4999)));

    vec3 lcol, rcol;
    float subpix = (vTex.x/texelSize.x - 0.4999 - float(tli.x))*3.0;
    float rsubpix = range.x/texelSize.x * 3.0;

    lcol = vec3(intsmear(subpix+1.0, rsubpix, 1.5, coeffs_x),
                intsmear(subpix    , rsubpix, 1.5, coeffs_x),
                intsmear(subpix-1.0, rsubpix, 1.5, coeffs_x));
    rcol = vec3(intsmear(subpix-2.0, rsubpix, 1.5, coeffs_x),
                intsmear(subpix-3.0, rsubpix, 1.5, coeffs_x),
                intsmear(subpix-4.0, rsubpix, 1.5, coeffs_x));

    if (params.BGR > 0.5) {
        lcol.rgb = lcol.bgr;
        rcol.rgb = rcol.bgr;
    }

    float tcol, bcol;
    subpix = vTex.y/texelSize.y - 0.4999 - float(tli.y);
    rsubpix = range.y/texelSize.y;
    tcol = intsmear(subpix    ,rsubpix, 0.63, coeffs_y);
    bcol = intsmear(subpix-1.0,rsubpix, 0.63, coeffs_y);

    vec3 topLeftColor     = fetch_offset(tli, ivec2(0,0)) * lcol * vec3(tcol);
    vec3 bottomRightColor = fetch_offset(tli, ivec2(1,1)) * rcol * vec3(bcol);
    vec3 bottomLeftColor  = fetch_offset(tli, ivec2(0,1)) * lcol * vec3(bcol);
    vec3 topRightColor    = fetch_offset(tli, ivec2(1,0)) * rcol * vec3(tcol);

    vec3 averageColor = topLeftColor + bottomRightColor + bottomLeftColor + topRightColor;

    averageColor = mat3(cred, cgreen, cblue) * averageColor;

   return pow(averageColor, vec3(1.0/outgamma));
}


#define ReflexSrc Source

// Yeah, an unorthodox 'include' usage.
#include "../../include/uborder_bezel_reflections_main.inc"
