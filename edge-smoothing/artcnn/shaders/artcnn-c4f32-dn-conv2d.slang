#version 450

// Based on ArtCNN_C4F32_DN.glsl.
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
    const ivec2 block_size = ivec2(4, 2);
    ivec2 base = output_pixel / block_size;
    ivec2 phase = output_pixel % block_size;
    int phase_index = phase.y * 4 + phase.x;
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
        result = V4(7.495765e-05, -0.0023203518, 0.0010683014, -0.07975286);
        result += V4(-0.03570373, -0.04974733, 0.078635186, -0.041514464) * inp_0_0_0;
        result += V4(-0.011112914, 0.19792159, -0.049930084, 0.00438227) * inp_0_1_0;
        result += V4(-0.0030901667, -0.11708137, 0.03070753, 0.049058586) * inp_0_2_0;
        result += V4(0.0769325, -0.033364475, -0.02649383, -0.17395456) * inp_0_0_1;
        result += V4(0.0026865506, -0.025578458, -0.06837394, 0.10087977) * inp_0_1_1;
        result += V4(-0.009055238, 0.0224312, 0.00935371, 0.12083759) * inp_0_2_1;
        result += V4(-0.0051814276, 0.066048875, -0.020675866, -0.015261215) * inp_0_0_2;
        result += V4(-0.046797115, -0.14028992, 0.05778795, 0.05593655) * inp_0_1_2;
        result += V4(0.031569522, 0.08277344, -0.011099671, 0.08455338) * inp_0_2_2;
    }
    else if (phase_index == 1)
    {
        result = V4(-9.716643e-05, 0.0001570974, -0.0009230478, 0.0018054836);
        result += V4(0.036151167, 0.05645935, 0.09085994, 0.05220316) * inp_0_0_0;
        result += V4(0.049097903, -0.024618795, 0.046892624, -0.09522319) * inp_0_1_0;
        result += V4(-0.004383674, 0.0028532618, -0.12351979, -0.061777957) * inp_0_2_0;
        result += V4(-0.057622325, -0.042097077, -0.08736871, -0.1059344) * inp_0_0_1;
        result += V4(-0.07495609, 0.061473906, 0.055640165, 0.14065513) * inp_0_1_1;
        result += V4(0.00042645712, -0.07058754, 0.01415501, 0.09746624) * inp_0_2_1;
        result += V4(-0.005558767, -0.07763482, -0.0039113197, 0.025994664) * inp_0_0_2;
        result += V4(0.014089546, 0.03386774, -0.100114554, -0.044875022) * inp_0_1_2;
        result += V4(0.043179043, 0.060106594, 0.10887411, -0.010872061) * inp_0_2_2;
    }
    else if (phase_index == 2)
    {
        result = V4(0.0018513539, 0.005027636, -0.0009170945, 0.0061210385);
        result += V4(-0.017657062, -0.0015675842, 0.029777149, -0.035702836) * inp_0_0_0;
        result += V4(0.017378464, 0.10966926, -0.115515664, 0.011453726) * inp_0_1_0;
        result += V4(-0.025935896, -0.028305909, 0.009315001, -0.00368858) * inp_0_2_0;
        result += V4(-0.07412288, -0.16770089, -0.014774406, -0.0780523) * inp_0_0_1;
        result += V4(-0.2835538, 0.43891713, 0.3121928, 0.10533196) * inp_0_1_1;
        result += V4(-0.014220944, -0.27401698, -0.15575814, 0.11637928) * inp_0_2_1;
        result += V4(0.11473479, -0.07201933, -0.019571507, -0.030566962) * inp_0_0_2;
        result += V4(0.21722049, 0.030477216, -0.111413516, -0.10829303) * inp_0_1_2;
        result += V4(0.057954177, -0.02824293, 0.06688619, 0.01375251) * inp_0_2_2;
    }
    else if (phase_index == 3)
    {
        result = V4(-0.003201262, -0.04863984, 0.00053018885, 0.000115401126);
        result += V4(0.014593571, 0.044203863, -0.01981625, -0.00810036) * inp_0_0_0;
        result += V4(-0.05916893, 0.18103237, -0.0120892245, -0.0275978) * inp_0_1_0;
        result += V4(0.058521405, 0.034880023, 0.04514544, 0.010635129) * inp_0_2_0;
        result += V4(-0.0020088984, 0.11175892, -0.062938295, 0.017897151) * inp_0_0_1;
        result += V4(-0.04936099, 0.21899283, 0.030680338, 0.11181562) * inp_0_1_1;
        result += V4(0.06931973, 0.16956647, -0.030493366, -0.051961064) * inp_0_2_1;
        result += V4(0.03168479, 0.111395426, 0.05525832, -0.02463908) * inp_0_0_2;
        result += V4(-0.09979217, 0.029276766, -0.0058111227, -0.038222376) * inp_0_1_2;
        result += V4(0.043681435, 0.08519136, -0.0004008783, 0.009402451) * inp_0_2_2;
    }
    else if (phase_index == 4)
    {
        result = V4(-0.0006070945, 0.001496304, 0.0005340359, 4.4858072e-05);
        result += V4(-0.021705668, 0.034932584, 0.0070805545, -0.012109808) * inp_0_0_0;
        result += V4(0.025704058, -0.029076086, -0.03781604, 0.008906985) * inp_0_1_0;
        result += V4(-0.02889719, -0.00868395, 0.031782564, 0.029153654) * inp_0_2_0;
        result += V4(0.019705623, -0.02597372, 0.0012448177, -0.072326906) * inp_0_0_1;
        result += V4(-0.064308815, 0.055574425, 0.093530126, -0.00094692403) * inp_0_1_1;
        result += V4(0.07215649, -0.013891359, -0.08320043, 0.018650096) * inp_0_2_1;
        result += V4(0.020457428, -0.027717467, 0.021207608, 0.07117493) * inp_0_0_2;
        result += V4(0.02358356, -0.015348489, -0.044177037, 0.03320646) * inp_0_1_2;
        result += V4(-0.046496548, 0.027533306, 0.009782651, -0.07530169) * inp_0_2_2;
    }
    else if (phase_index == 5)
    {
        result = V4(0.0009915231, -0.0009294384, 0.0020618134, 0.00014796268);
        result += V4(-0.05451618, -0.034605518, 0.026223246, 0.060316697) * inp_0_0_0;
        result += V4(0.037825555, 0.015977537, 0.012924403, -0.021653835) * inp_0_1_0;
        result += V4(-0.014524195, -0.030115202, -0.00507601, -0.07093481) * inp_0_2_0;
        result += V4(-0.017963666, 0.03205644, 0.014696323, -0.09956015) * inp_0_0_1;
        result += V4(0.008687332, 0.041709784, -0.04235503, -0.0038690139) * inp_0_1_1;
        result += V4(0.013782496, 0.008072177, 0.055430975, 0.1424453) * inp_0_2_1;
        result += V4(0.054262903, -0.0035225002, -0.046158608, 0.02357535) * inp_0_0_2;
        result += V4(0.008374217, -0.012191438, 0.05503198, 0.033371817) * inp_0_1_2;
        result += V4(-0.038668092, -0.01703321, -0.07579983, -0.064310975) * inp_0_2_2;
    }
    else if (phase_index == 6)
    {
        result = V4(-0.000995561, 0.00044284284, 0.031616252, 0.03507456);
        result += V4(-0.044501234, 0.08414609, 0.027959887, -0.026663758) * inp_0_0_0;
        result += V4(0.024449563, -0.065979384, 0.20810296, -0.11153794) * inp_0_1_0;
        result += V4(0.07525417, -0.01628853, 0.12734154, 0.0050934474) * inp_0_2_0;
        result += V4(-0.12620823, -0.047110926, -0.22712338, -0.022882737) * inp_0_0_1;
        result += V4(0.16722333, 0.022124542, -0.3013066, -0.1679883) * inp_0_1_1;
        result += V4(-0.002208535, 0.019235918, 0.15553735, 0.019819167) * inp_0_2_1;
        result += V4(0.15096033, -0.020805517, -0.06605334, 0.037216745) * inp_0_0_2;
        result += V4(-0.16005418, 0.028736515, -0.016507791, 0.08210076) * inp_0_1_2;
        result += V4(-0.08276124, -0.0045010815, -0.008245106, 0.11177028) * inp_0_2_2;
    }
    else if (phase_index == 7)
    {
        result = V4(-0.0016439368, -0.005165706, 0.008995072, -0.0010015862);
        result += V4(0.010464709, -0.1967493, -0.06305589, 0.003749366) * inp_0_0_0;
        result += V4(-0.005973618, -0.15419626, 0.00070673594, 0.048765358) * inp_0_1_0;
        result += V4(0.05480607, -0.025529198, -0.051224455, -0.025418526) * inp_0_2_0;
        result += V4(-0.029477412, -0.17875457, 0.021352548, 0.05834687) * inp_0_0_1;
        result += V4(-0.085831344, 0.4279725, 0.09887064, -0.02802131) * inp_0_1_1;
        result += V4(-0.006788395, 0.11450105, 0.021999907, 0.011056973) * inp_0_2_1;
        result += V4(0.005724198, -0.050264426, -0.036152232, -0.080330625) * inp_0_0_2;
        result += V4(0.05483947, 0.10751334, 0.014210829, -0.0015998664) * inp_0_1_2;
        result += V4(0.005727417, 0.009807263, -0.022513956, 0.013759894) * inp_0_2_2;
    }
    FragColor = result;
}
