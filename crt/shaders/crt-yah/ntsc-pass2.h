/*
    NTSC-Adaptive pass 2 by Hunter K.
    Based on NTSC shader by The Maister
    Modified by Jezze
*/

#include "common/colorspace-yiq.h"

const int TAPS_2_phase = 32;
const float luma_filter_2_phase[33] = float[33](
    -0.000174844,
    -0.000205844,
    -0.000149453,
    -0.000051693,
    0.000000000,
    -0.000066171,
    -0.000245058,
    -0.000432928,
    -0.000472644,
    -0.000252236,
    0.000198929,
    0.000687058,
    0.000944112,
    0.000803467,
    0.000363199,
    0.000013422,
    0.000253402,
    0.001339461,
    0.002932972,
    0.003983485,
    0.003026683,
    -0.001102056,
    -0.008373026,
    -0.016897700,
    -0.022914480,
    -0.021642347,
    -0.008863273,
    0.017271957,
    0.054921920,
    0.098342579,
    0.139044281,
    0.168055832,
    0.178571429);

const float chroma_filter_2_phase[33] = float[33](
    0.001384762,
    0.001678312,
    0.002021715,
    0.002420562,
    0.002880460,
    0.003406879,
    0.004004985,
    0.004679445,
    0.005434218,
    0.006272332,
    0.007195654,
    0.008204665,
    0.009298238,
    0.010473450,
    0.011725413,
    0.013047155,
    0.014429548,
    0.015861306,
    0.017329037,
    0.018817382,
    0.020309220,
    0.021785952,
    0.023227857,
    0.024614500,
    0.025925203,
    0.027139546,
    0.028237893,
    0.029201910,
    0.030015081,
    0.030663170,
    0.031134640,
    0.031420995,
    0.031517031);

const int TAPS_3_phase = 24;
const float luma_filter_3_phase[25] = float[25](
    -0.000012020,
    -0.000022146,
    -0.000013155,
    -0.000012020,
    -0.000049979,
    -0.000113940,
    -0.000122150,
    -0.000005612,
    0.000170516,
    0.000237199,
    0.000169640,
    0.000285688,
    0.000984574,
    0.002018683,
    0.002002275,
    -0.000909882,
    -0.007049081,
    -0.013222860,
    -0.012606931,
    0.002460860,
    0.035868225,
    0.084016453,
    0.135563500,
    0.175261268,
    0.190176552);

const float chroma_filter_3_phase[25] = float[25](
    -0.000118847,
    -0.000271306,
    -0.000502642,
    -0.000930833,
    -0.001451013,
    -0.002064744,
    -0.002700432,
    -0.003241276,
    -0.003524948,
    -0.003350284,
    -0.002491729,
    -0.000721149,
    0.002164659,
    0.006313635,
    0.011789103,
    0.018545660,
    0.026414396,
    0.035100710,
    0.044196567,
    0.053207202,
    0.061590275,
    0.068803602,
    0.074356193,
    0.077856564,
    0.079052396);

vec3 fetch_offset(sampler2D source, vec2 texCoord, vec2 scanTexelSize, float offset)
{
    return texture(source, texCoord + (scanTexelSize * vec2(offset))).xyz;
}

// Applies the second NTSC adaptive pass and returns a RGB color.
//    This pass require a textute which has been down-scaled by 4 along the scan-direction.
// @source: the texture sampler
// @texCoord: the original texture coordinate
// @scanTexelSize: the texel size in scan-direction
//    To simulate a differnt resolutuion than the original texture size, divide the texel size along the scan-direction.
//    The component in the none-scan-direction has to be 0.0.
// @phase: the phase modulation in rangle of [2,3]
vec3 pass2(sampler2D source, vec2 texCoord, vec2 scanTexelSize, int phase)
{
    vec3 yiq = vec3(0.0);

    if (phase == 2)
    {
        for (int i = 0; i < TAPS_2_phase; i++)
        {
            float offset = float(i);
            float count = float(TAPS_2_phase);

            vec3 sums =
                fetch_offset(source, texCoord, scanTexelSize, offset - count)
                + fetch_offset(source, texCoord, scanTexelSize, count - offset);
            yiq += sums * vec3(luma_filter_2_phase[i], chroma_filter_2_phase[i], chroma_filter_2_phase[i]);
        }

        yiq += texture(source, texCoord).xyz *
            vec3(luma_filter_2_phase[TAPS_2_phase], chroma_filter_2_phase[TAPS_2_phase], chroma_filter_2_phase[TAPS_2_phase]);
    }
    else
    {
        for (int i = 0; i < TAPS_3_phase; i++)
        {
            float offset = float(i);
            float count = float(TAPS_3_phase);

            vec3 sums =
                fetch_offset(source, texCoord, scanTexelSize, offset - count)
                + fetch_offset(source, texCoord, scanTexelSize, count - offset);
            yiq += sums * vec3(luma_filter_3_phase[i], chroma_filter_3_phase[i], chroma_filter_3_phase[i]);
        }

        yiq += texture(source, texCoord).xyz *
            vec3(luma_filter_3_phase[TAPS_3_phase], chroma_filter_3_phase[TAPS_3_phase], chroma_filter_3_phase[TAPS_3_phase]);
    }

    return yiq_to_rgb(yiq);
}
