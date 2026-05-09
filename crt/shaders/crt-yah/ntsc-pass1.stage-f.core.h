/*
    NTSC-Adaptive pass 1 by Hunter K.
    Based on NTSC shader by The Maister
    Modified by Jezze
*/

#include "common/colorspace-yiq.h"

vec3 pass1(vec3 yiq, vec2 pixCoord, int phase, vec3 chromaProfile, uint frameCount, mat3 mix3x3)
{
    float chromaFrequency = chromaProfile.x;
    float chromaAmplitude = chromaProfile.y;
    float chromaShift = chromaProfile.z;

    float chromaPhase
        = chromaAmplitude * (mod(pixCoord.y, phase) + mod(frameCount, 2.0))
        * chromaShift
        + chromaFrequency * pixCoord.x;

    float i = cos(chromaPhase);
    float q = sin(chromaPhase);

    yiq.yz *= vec2(i, q); // Modulate
    yiq *= mix3x3; // Cross-talk
    yiq.yz *= vec2(i, q); // Demodulate

    return yiq;
}

// Applies the first NTSC adaptive pass and returns a YIQ color.
//    This pass require a texture which has been up-scaled by 4 along the scan-direction.
// @source: the texture sampler
// @texCoord: the original texture coordinate
// @pixCoord: the modified pixel coordinate
//    If the texture has been uniformly up-scaled by 4, the pixel coordinate along the none-scan-direction has to be divided by 4.
//    To simulate a different resolution than the original texture size, multiply the pixel coordinate along the scan-direction.
//    To change the scan-direction, swap the x- and y-axis of the pixel coordinate.
// @phase: the chroma phase in rangle of [2,3]
// @chromaProfile: the chroma profile (frequency, amplitude, shift)
// @jitter: whether and how much jitter is applied
// @frameCount: the current frame count
// @mix: a 3x3 mix matrix, with the following composition
//    b, f, f,
//    a, s, 0,
//    a, 0, s;
//    b = brightness (1 = neutral)
//    s = saturation (2 = neutral)
//    f = fringing (0 = neutral)
//    a = artifacting (0 = neutral)
//    0 = unused
vec3 pass1(sampler2D source, vec2 texCoord, vec2 pixCoord, int phase, vec3 chromaProfile, float jitter, uint frameCount, mat3 mix3x3)
{
    vec3 rgb = texture(source, texCoord).rgb;
    vec3 yiq = rgb_to_yiq(rgb);

    uint frame0 = 0; // static
    uint frame1 = jitter > 0.0
        ? frameCount // jitter
        : 1; // static
    vec3 yiq0 = pass1(yiq, pixCoord, phase, chromaProfile, frame0, mix3x3);
    vec3 yiq1 = pass1(yiq, pixCoord, phase, chromaProfile, frame1, mix3x3);

    if (jitter > 0.0)
    {
        yiq = mix(
            yiq0, // static
            yiq1, // jitter
            jitter);
    }
    else
    {
        yiq = mix(
            yiq0, // static
            (yiq0 + yiq1) * 0.5, // merge
            abs(jitter));
    }

    return yiq;
}
