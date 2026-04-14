#version 450

// Based on ArtCNN_C4F16_DS.glsl.
// Original ArtCNN shaders are MIT licensed by Joao Chrisostomo and Kacper Michajlow.
// ArtCNN project: https://github.com/Artoriuz/ArtCNN/
// See ../LICENSE for the ArtCNN license text.

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 artcnn_yuvSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D artcnn_yuv;

#define V4 vec4
#define M4 mat4
#include "artcnn-common.inc"

void main()
{
    ivec2 output_pixel = artcnn_output_pixel(params.OutputSize.xy);
    const ivec2 block_size = ivec2(2, 2);
    ivec2 base = output_pixel / block_size;
    ivec2 phase = output_pixel % block_size;
    int phase_index = phase.y * 2 + phase.x;
    float inp_0_0_0 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(-1, -1));
    float inp_0_1_0 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(0, -1));
    float inp_0_2_0 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(1, -1));
    float inp_0_0_1 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(-1, 0));
    float inp_0_1_1 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(0, 0));
    float inp_0_2_1 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(1, 0));
    float inp_0_0_2 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(-1, 1));
    float inp_0_1_2 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(0, 1));
    float inp_0_2_2 = artcnn_fetch_scalar(artcnn_yuv, params.artcnn_yuvSize, base + ivec2(1, 1));
    vec4 result = vec4(0.0);
    if (phase_index == 0)
    {
        result = V4(-0.006840266, -0.012440474, -0.012945435, -0.04645404);
        result += V4(-0.035472848, -0.14499138, 0.010996882, 0.043425154) * inp_0_0_0;
        result += V4(0.025666144, 0.15189208, 0.106125966, 0.12280825) * inp_0_1_0;
        result += V4(-0.0059361006, 0.12564982, -0.08410422, 0.061385795) * inp_0_2_0;
        result += V4(-0.032784533, 0.039960023, -0.007927497, 0.16533956) * inp_0_0_1;
        result += V4(-0.0575242, -0.08458494, -0.36564967, 0.2639598) * inp_0_1_1;
        result += V4(-0.22559616, -0.15471613, 0.08640329, 0.111541584) * inp_0_2_1;
        result += V4(0.02868958, 0.18487, -0.0071559404, 0.094328836) * inp_0_0_2;
        result += V4(0.12985429, -0.09587503, 0.22276698, -0.00030755106) * inp_0_1_2;
        result += V4(0.19284648, -0.0036720308, 0.046878424, 0.087355375) * inp_0_2_2;
    }
    else if (phase_index == 1)
    {
        result = V4(-0.03236463, -0.0050622425, -0.0045825113, 0.006420765);
        result += V4(0.074089326, -0.05675305, -0.09985263, -0.009709773) * inp_0_0_0;
        result += V4(-0.05789924, -0.043006446, 0.0020396519, -0.17014614) * inp_0_1_0;
        result += V4(0.04783098, 0.116548575, 0.04523142, 0.13470247) * inp_0_2_0;
        result += V4(-0.05063743, 0.08730553, 0.13439637, -0.026661385) * inp_0_0_1;
        result += V4(0.09525456, -0.16270195, 0.1547691, 0.15802628) * inp_0_1_1;
        result += V4(-0.11239273, 0.27577797, -0.20400351, -0.11836694) * inp_0_2_1;
        result += V4(0.04961805, -0.025907341, 0.004669451, 0.0224939) * inp_0_0_2;
        result += V4(0.10036262, -0.2565832, -0.10639526, 0.05117149) * inp_0_1_2;
        result += V4(-0.06141705, 0.0645962, 0.073470935, -0.05072495) * inp_0_2_2;
    }
    else if (phase_index == 2)
    {
        result = V4(0.030867014, -0.0024917293, 0.007428549, -0.0090537695);
        result += V4(-0.05530217, 0.10601906, -0.078338385, -0.06250365) * inp_0_0_0;
        result += V4(0.07705957, -0.047928665, 0.13465533, 0.007932151) * inp_0_1_0;
        result += V4(0.06636978, -0.00021219392, 0.024917463, -0.03883686) * inp_0_2_0;
        result += V4(-0.17326315, 0.26141313, 0.32149935, 0.15181658) * inp_0_0_1;
        result += V4(-0.2644004, -0.671686, -0.2870538, -0.059954405) * inp_0_1_1;
        result += V4(0.119587556, 0.112419866, -0.08982401, -0.049265414) * inp_0_2_1;
        result += V4(0.038703833, 0.11872192, -0.12390658, 0.0075279525) * inp_0_0_2;
        result += V4(0.18729559, 0.057575975, 0.070585884, 0.17390902) * inp_0_1_2;
        result += V4(-0.13925101, 0.0038511057, 0.015638566, -0.12646236) * inp_0_2_2;
    }
    else if (phase_index == 3)
    {
        result = V4(-0.0012738375, 0.013379571, 0.008391121, -0.06455159);
        result += V4(0.04861797, -0.12658298, 0.22940855, -0.092168994) * inp_0_0_0;
        result += V4(-0.17647275, 0.16706389, 0.3450641, 0.15214883) * inp_0_1_0;
        result += V4(-0.0019383872, -0.010804838, 0.061069414, 0.080609985) * inp_0_2_0;
        result += V4(0.04252093, -0.04149563, 0.02318568, -0.21245834) * inp_0_0_1;
        result += V4(0.011523845, -0.14079979, -0.37102658, -0.026639262) * inp_0_1_1;
        result += V4(0.057185087, 0.11133354, -0.17895421, 0.20168874) * inp_0_2_1;
        result += V4(-0.056966644, 0.16069722, -0.06554181, -0.08890916) * inp_0_0_2;
        result += V4(0.09564253, -0.08339483, -0.16765916, 0.026718881) * inp_0_1_2;
        result += V4(-0.01259612, -0.05284743, -0.03444009, 0.18512487) * inp_0_2_2;
    }
    FragColor = result;
}
