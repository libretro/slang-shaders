/*
    NTSC-Adaptive pass 1 by Hunter K.
    Based on NTSC shader by The Maister
    Modified by Jezze
*/

#include "common/colorspace-yiq.h"

#define PI 3.1415926

vec3 pass1(vec3 yiq, vec2 pixCoord, int phase, float phase_shift, mat3 mix3x3, uint frameCount)
{
    float chroma_frequency = phase == 2
        ? PI / (15.0 / 4.0)
        : PI / 3.0;
    float chroma_amplitude = phase == 2
        ? PI
        : PI * (2.0 / 3.0);
    float chroma_shift = phase == 2
        ? phase_shift + 1.0
        : (phase_shift * 1.5) + 1.5;
    
    float chroma_phase
        = chroma_amplitude * (mod(pixCoord.y, phase) + mod(frameCount, 2.0))
        * chroma_shift
        + chroma_frequency * pixCoord.x;

    float i = cos(chroma_phase);
    float q = sin(chroma_phase);

    yiq.yz *= vec2(i, q); // Modulate
    yiq *= mix3x3; // Cross-talk
    yiq.yz *= vec2(i, q); // Demodulate

    return yiq;
}

// Applies the first NTSC adaptive pass and returns a YIQ color.
//    This pass require a textute which has been up-scaled by 4 along the scan-direction.
// @source: the texture sampler
// @texCoord: the original texture coordinate
// @pixCoord: the modified pixel coordinate
//    If the texture has been unifomly up-scaled by 4, the pixel coordinat along the none-scan-direction has to be devided by 4. 
//    To simulate a differnt resolutuion than the original texture size, multiply the pixel coordinate along the scan-direction.
//    To change the scan-direction, swap the x- and y-axis of the pixel coordinate.
// @phase: the chroma phase in rangle of [2,3]
// @phaseShift: the choma phase shift
// @jitter: whether and how much jitter is applied
//    For 2-phase jitter is reduced by frame-count.
//    For 3-phase jitter is reduced by field-merge.
// @mix: a 3x3 mix matrix, with the following composition
//    b, f, f,
//    a, s, 0,
//    a, 0, s;
//    b = brightness (1 = neutral)
//    s = saturation (2 = neutral)
//    f = fringing (0 = neutral)
//    a = artifacting (0 = neutral)
//    0 = unused
// @frameCount: the current frame count
vec3 pass1(sampler2D source, vec2 texCoord, vec2 pixCoord, int phase, float phaseShift, float jitter, mat3 mix3x3, uint frameCount)
{
    vec3 rgb = texture(source, texCoord).rgb;
    vec3 yiq = rgb_to_yiq(rgb);

    if (phase == 2)
    {
        vec3 yiq0 = pass1(yiq, pixCoord, phase, phaseShift, mix3x3, frameCount);
        vec3 yiq1 = pass1(yiq, pixCoord, phase, phaseShift, mix3x3, 0);
        
        yiq = mix(
            yiq1,
            yiq0,
            jitter);
    }
    else
    {
        vec3 yiq0 = pass1(yiq, pixCoord, phase, phaseShift, mix3x3, frameCount);
        vec3 yiq1 = pass1(yiq, pixCoord, phase, phaseShift, mix3x3, frameCount + 1);
        
        yiq = mix(
            (yiq0 + yiq1) * 0.5, // field-merge when no jitter
            yiq0,
            jitter);
    }

    return yiq;
}
