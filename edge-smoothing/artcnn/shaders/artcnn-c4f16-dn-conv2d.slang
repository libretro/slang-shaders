#version 450

// Based on ArtCNN_C4F16_DN.glsl.
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
        result = V4(0.005000432, -0.010236794, -0.014935676, -0.046207584);
        result += V4(-0.031936917, -0.12498426, 0.019247064, 0.043321293) * inp_0_0_0;
        result += V4(0.0324228, 0.15786779, 0.093572296, 0.12223211) * inp_0_1_0;
        result += V4(-0.008010341, 0.11386231, -0.07220623, 0.062144116) * inp_0_2_0;
        result += V4(-0.017256076, 0.051489502, -0.021640493, 0.16445197) * inp_0_0_1;
        result += V4(-0.05208898, -0.06893944, -0.34209797, 0.26306182) * inp_0_1_1;
        result += V4(-0.22330455, -0.13612887, 0.070612304, 0.11175349) * inp_0_2_1;
        result += V4(0.032759942, 0.1523859, 0.009016861, 0.094373636) * inp_0_0_2;
        result += V4(0.10492912, -0.10173742, 0.19048259, -0.00072423404) * inp_0_1_2;
        result += V4(0.16503376, -0.017707495, 0.051095057, 0.0885737) * inp_0_2_2;
    }
    else if (phase_index == 1)
    {
        result = V4(-0.028179219, -0.004517557, 0.00014788302, 0.0035856056);
        result += V4(0.075178064, -0.053005736, -0.1116903, 0.01338327) * inp_0_0_0;
        result += V4(-0.05177772, -0.03640289, 0.010358838, -0.18368039) * inp_0_1_0;
        result += V4(0.02753785, 0.112010606, 0.042722113, 0.117747955) * inp_0_2_0;
        result += V4(-0.04285177, 0.076704614, 0.11607434, -0.0305754) * inp_0_0_1;
        result += V4(0.099548064, -0.15293168, 0.12925005, 0.1437974) * inp_0_1_1;
        result += V4(-0.116974674, 0.23881362, -0.1826676, -0.091472775) * inp_0_2_1;
        result += V4(0.043361172, -0.013535253, 0.0058491337, 0.02681981) * inp_0_0_2;
        result += V4(0.08957939, -0.22580828, -0.08981081, 0.043160103) * inp_0_1_2;
        result += V4(-0.07271555, 0.051607724, 0.08303654, -0.040631983) * inp_0_2_2;
    }
    else if (phase_index == 2)
    {
        result = V4(0.032914076, 0.00020142968, -0.0065285224, -0.0065012206);
        result += V4(-0.05472001, 0.11004032, -0.06848912, -0.052433632) * inp_0_0_0;
        result += V4(0.07194944, -0.05754198, 0.11013715, 0.004388367) * inp_0_1_0;
        result += V4(0.06442394, 0.0031591335, 0.043304957, -0.0030882147) * inp_0_2_0;
        result += V4(-0.17313306, 0.24899231, 0.28330398, 0.134953) * inp_0_0_1;
        result += V4(-0.264359, -0.6773203, -0.28650266, -0.05620836) * inp_0_1_1;
        result += V4(0.12131029, 0.10487222, -0.07395276, -0.042340226) * inp_0_2_1;
        result += V4(0.04348287, 0.12302039, -0.076906785, -0.0013286016) * inp_0_0_2;
        result += V4(0.18425512, 0.056919117, 0.043003965, 0.14221072) * inp_0_1_2;
        result += V4(-0.13485871, 0.008584932, 0.025013693, -0.11905144) * inp_0_2_2;
    }
    else if (phase_index == 3)
    {
        result = V4(0.002272252, 0.010490689, 0.014113876, -0.06348713);
        result += V4(0.054048687, -0.12823541, 0.22114806, -0.097227745) * inp_0_0_0;
        result += V4(-0.15910593, 0.15280719, 0.33969763, 0.158814) * inp_0_1_0;
        result += V4(-0.010616162, -0.00083789544, 0.062508926, 0.06668837) * inp_0_2_0;
        result += V4(0.036678676, -0.04860102, 0.016965836, -0.19173586) * inp_0_0_1;
        result += V4(0.01301608, -0.13192666, -0.39674488, -0.0031523537) * inp_0_1_1;
        result += V4(0.05387914, 0.1256965, -0.17243183, 0.19979002) * inp_0_2_1;
        result += V4(-0.056761082, 0.17714313, -0.053538978, -0.08099346) * inp_0_0_2;
        result += V4(0.09195001, -0.09233287, -0.16082087, 0.021915846) * inp_0_1_2;
        result += V4(-0.023340184, -0.06604176, -0.02217975, 0.15662381) * inp_0_2_2;
    }
    FragColor = result;
}
