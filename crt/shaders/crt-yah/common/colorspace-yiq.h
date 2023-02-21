#ifndef COLORSPACE_YIQ_DEFINDED

#define COLORSPACE_YIQ_DEFINDED

vec3 rgb_to_yiq(vec3 rgb)
{
    const mat3 matrix = mat3(
       0.2989, 0.5870, 0.1140,
       0.5959, -0.2744, -0.3216,
       0.2115, -0.5229, 0.3114);

    return rgb * matrix;
}

vec3 yiq_to_rgb(vec3 yiq)
{
    const mat3 matrix = mat3(
       1.0, 0.956, 0.6210,
       1.0, -0.2720, -0.6474,
       1.0, -1.1060, 1.7046);

    return yiq * matrix;
}

#endif // COLORSPACE_YIQ_DEFINDED
