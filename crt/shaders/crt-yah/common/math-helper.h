#ifndef MATH_HELPER_DEFINED

#define MATH_HELPER_DEFINED

// Returns a semi-random value based on the given seed.
// @seed: the seed value
// See: https://www.stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader/
float random(vec2 seed)
{
    const float gelfond = 23.140692; // e^pi (Gelfond constant)
    const float gelfondSchneider = 2.6651442; // 2^sqrt(2) (Gelfond-Schneider constant)

    // use irrationals for pseudo randomness
    vec2 i = vec2(gelfond, gelfondSchneider);

    return fract(cos(dot(seed, i)) * 123456.0);
}

// Applies a normalized sigmoid function to the given value.
//   The value and slope have to be in the range of [-1.0, 1.0].
// @value: the value to transform
// @slope: the slope to apply
// See: https://dinodini.wordpress.com/2010/04/05/normalized-tunable-sigmoid-functions/
float normalized_sigmoid(float value, float slope)
{
    float numerator = (1.0f - slope) * value;
    float denominator = (1.0f + slope) - (abs(value) * slope * 2.0f);

    return numerator / denominator;
}

// Applies a normalized sigmoid function to the given value.
//   The value has to be in the given range, the slope in range of [-1.0, 1.0].
// @value: the value to transform
// @value: the range to normalize
// @slope: the slope to apply
float normalized_sigmoid(float value, float range, float slope)
{
    return normalized_sigmoid(value / range, slope) * range;
}

#endif // MATH_HELPER_DEFINED
