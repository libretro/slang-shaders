#ifndef MATH_HELPER

#define MATH_HELPER

#define EPSILON 1e-6

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
//   The input parameters have to be in the range of [-1.0, 1.0].
// @value: the value to transform
// @slope: the slope to apply
// See: https://dinodini.wordpress.com/2010/04/05/normalized-tunable-sigmoid-functions/
float normalized_sigmoid(float value, float slope)
{
    return (value - value * slope) / (slope - abs(value) * 2.0 * slope + 1.0);
}

#endif // MATH_HELPER
