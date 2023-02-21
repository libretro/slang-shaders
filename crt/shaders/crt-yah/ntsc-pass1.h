/*
    NTSC-Adaptive pass 1 by Hunter K.
    Based on NTSC shader by The Maister
    Modified by Jezze
*/

#include "common/colorspace-yiq.h"

#define PI 3.1415926

vec3 pass1(vec3 yiq, vec2 pixCoord, int phase, mat3 mix, uint frameCount)
{
    float chromaModFreq = phase == 2
        ? PI / 4.0
        : PI / 3.0;

    float chroma_phase = phase == 2
        ? (mod(pixCoord.y, phase) + mod(frameCount, 2.0)) * PI
        : (mod(pixCoord.y, phase) + mod(frameCount, 2.0)) * PI * (2.0 / 3.0);
    float mod_phase = pixCoord.x * chromaModFreq + chroma_phase;

    float i_mod = cos(mod_phase);
    float q_mod = sin(mod_phase);

    yiq.yz *= vec2(i_mod, q_mod); // Modulate
    yiq *= mix; // Cross-talk
    yiq.yz *= vec2(i_mod, q_mod); // Demodulate

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
// @phase: the phase modulation in rangle of [2,3]
// @merge: whether the two subsequent frames shall be merged
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
vec3 pass1(sampler2D source, vec2 texCoord, vec2 pixCoord, int phase, bool merge, mat3 mix, uint frameCount)
{
    vec3 rgb = texture(source, texCoord).rgb;
    vec3 yiq = rgb_to_yiq(rgb);

    vec3 yiqMerge = yiq;
    if (merge)
    {
        yiqMerge = pass1(yiqMerge, pixCoord, phase, mix, frameCount + 1);
    }

    yiq = pass1(yiq, pixCoord, phase, mix, frameCount);

    if (merge)
    {
        yiq = (yiq + yiqMerge) * 0.5;
    }

    return yiq;
}
