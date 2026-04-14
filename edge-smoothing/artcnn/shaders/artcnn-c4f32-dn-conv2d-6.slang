#version 450

// Based on ArtCNN_C4F32_DN.glsl.
// Original ArtCNN shaders are MIT licensed by Joao Chrisostomo and Kacper Michajlow.
// ArtCNN project: https://github.com/Artoriuz/ArtCNN/
// See ../LICENSE for the ArtCNN license text.

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
    vec4 conv2dSize;
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
layout(set = 0, binding = 2) uniform sampler2D conv2d;
layout(set = 0, binding = 3) uniform sampler2D conv2d_5;

#define V4 vec4
#define M4 mat4
#include "artcnn-common.inc"

void main()
{
    ivec2 output_pixel = artcnn_output_pixel(params.OutputSize.xy);
    ivec2 base = output_pixel;
    ivec2 input_base = base * ivec2(4, 2);
    vec4 inp_0_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-4, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-4, -2));
    vec4 inp_0_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, -2));
    vec4 inp_0_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(4, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(4, -2));
    vec4 inp_0_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-4, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-4, 0));
    vec4 inp_0_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, 0));
    vec4 inp_0_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(4, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(4, 0));
    vec4 inp_0_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-4, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-4, 2));
    vec4 inp_0_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, 2));
    vec4 inp_0_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(4, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(4, 2));
    vec4 inp_1_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-3, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-3, -2));
    vec4 inp_1_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, -2));
    vec4 inp_1_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(5, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(5, -2));
    vec4 inp_1_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-3, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-3, 0));
    vec4 inp_1_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, 0));
    vec4 inp_1_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(5, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(5, 0));
    vec4 inp_1_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-3, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-3, 2));
    vec4 inp_1_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, 2));
    vec4 inp_1_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(5, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(5, 2));
    vec4 inp_2_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, -2));
    vec4 inp_2_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, -2));
    vec4 inp_2_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(6, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(6, -2));
    vec4 inp_2_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, 0));
    vec4 inp_2_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, 0));
    vec4 inp_2_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(6, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(6, 0));
    vec4 inp_2_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, 2));
    vec4 inp_2_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, 2));
    vec4 inp_2_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(6, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(6, 2));
    vec4 inp_3_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, -2));
    vec4 inp_3_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, -2));
    vec4 inp_3_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(7, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(7, -2));
    vec4 inp_3_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, 0));
    vec4 inp_3_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, 0));
    vec4 inp_3_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(7, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(7, 0));
    vec4 inp_3_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, 2));
    vec4 inp_3_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, 2));
    vec4 inp_3_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(7, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(7, 2));
    vec4 inp_4_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-4, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-4, -1));
    vec4 inp_4_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, -1));
    vec4 inp_4_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(4, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(4, -1));
    vec4 inp_4_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-4, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-4, 1));
    vec4 inp_4_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, 1));
    vec4 inp_4_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(4, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(4, 1));
    vec4 inp_4_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-4, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-4, 3));
    vec4 inp_4_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, 3));
    vec4 inp_4_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(4, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(4, 3));
    vec4 inp_5_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-3, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-3, -1));
    vec4 inp_5_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, -1));
    vec4 inp_5_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(5, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(5, -1));
    vec4 inp_5_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-3, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-3, 1));
    vec4 inp_5_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, 1));
    vec4 inp_5_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(5, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(5, 1));
    vec4 inp_5_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-3, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-3, 3));
    vec4 inp_5_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, 3));
    vec4 inp_5_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(5, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(5, 3));
    vec4 inp_6_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, -1));
    vec4 inp_6_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, -1));
    vec4 inp_6_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(6, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(6, -1));
    vec4 inp_6_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, 1));
    vec4 inp_6_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, 1));
    vec4 inp_6_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(6, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(6, 1));
    vec4 inp_6_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, 3));
    vec4 inp_6_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, 3));
    vec4 inp_6_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(6, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(6, 3));
    vec4 inp_7_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, -1));
    vec4 inp_7_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, -1));
    vec4 inp_7_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(7, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(7, -1));
    vec4 inp_7_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, 1));
    vec4 inp_7_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, 1));
    vec4 inp_7_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(7, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(7, 1));
    vec4 inp_7_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, 3));
    vec4 inp_7_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, 3));
    vec4 inp_7_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(7, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(7, 3));
    vec4 result = vec4(0.0);
    result = V4(0.080624826, 0.07593799, 0.081532195, 0.080970705);
    result += M4(-0.015694782, 0.0027984506, -0.02421363, -0.0027874813, -0.06901564, -0.04727905, -0.05258865, -0.03974979, 0.06889453, -0.03226026, 0.020652069, -0.038364362, -0.11118726, -0.016107326, -0.030249402, 0.004415387) * inp_0_0_0;
    result += M4(-0.038036466, -0.0051797074, 0.029854951, 0.02565397, 0.014543795, -0.0196189, -0.02613709, -0.051328395, 0.01331787, -0.0032242998, -0.0009300489, 0.039514177, -0.031965073, -0.08203451, -0.0018131016, -0.022699561) * inp_0_1_0;
    result += M4(0.012572404, -0.02329575, 0.043874852, 0.033668406, -0.0042276024, -0.008066597, 0.0056977933, 0.010132454, -0.0046677715, 0.02414294, 0.018640582, 0.0024213176, -0.057489816, -0.106680624, -0.01118137, -0.025141165) * inp_0_2_0;
    result += M4(0.042177983, -0.013872728, 0.046051256, -0.012291174, 0.017898956, 0.03963741, -0.058701526, -0.013734211, -0.02641158, 0.016982613, -0.04163611, -0.011891915, -0.01193528, 0.026931917, -0.00284293, 0.029268343) * inp_0_0_1;
    result += M4(0.031209823, -0.018061096, -0.031653665, -0.049088825, -0.11590648, 0.0114124855, 0.042980716, 0.05630318, -0.0008996456, 0.046405036, 0.05466982, -0.07809661, 0.2106655, 0.20267701, 0.2234757, 0.2234917) * inp_0_1_1;
    result += M4(0.00453081, -0.012778993, -0.06140402, -0.008382765, 0.038561046, 0.0001393781, -0.016231025, 0.045473896, -0.019050475, -0.08255334, 0.012290838, 0.04644339, -0.00094275863, -0.02739557, -0.016622344, -0.009808773) * inp_0_2_1;
    result += M4(-0.024709249, -0.0027139015, -0.011814307, 0.015454814, 0.07013189, 0.019297007, 0.13200225, 0.06217925, -0.048179783, -0.002828742, -0.0440713, 0.026038392, 0.0029575534, 0.017471153, -0.09469892, -0.004137581) * inp_0_0_2;
    result += M4(-0.0036395346, 0.032186132, -0.040467475, -0.0130174495, 0.04448132, 0.016557679, -0.04800158, -0.008847145, 0.03310655, 0.015259752, 0.020122144, 0.021965073, 0.048840117, 0.06864394, 0.017042287, 0.025873492) * inp_0_1_2;
    result += M4(-0.0076815546, 0.039834086, 0.04929285, 0.011757491, 0.0030525497, -0.0065432205, 0.020486463, -0.061162785, -0.006840825, 0.024979468, -0.043533042, -0.035098378, 0.013321346, -0.017600324, -0.030050222, -0.11178205) * inp_0_2_2;
    result += M4(-0.046010334, -0.01501303, -0.010515758, 0.0011213078, -0.055642966, -0.050521947, -0.11993215, -0.049467627, -0.061786793, 0.00013302563, -0.044816725, -0.0001283696, 0.022587208, -0.03830528, 0.021097839, -0.022312649) * inp_1_0_0;
    result += M4(0.033427104, -0.03267016, 0.016196024, 0.01179354, 0.002070095, -0.046160083, -0.0350621, -0.06050532, 0.060393393, 0.08167097, -0.02531124, -0.0022726366, 0.07666547, 0.0515552, 0.008585785, -0.024108939) * inp_1_1_0;
    result += M4(0.016282387, 0.028426707, -0.010502565, 0.02580733, -0.030089214, 0.034623615, 0.008034485, 0.017927239, 0.0043493393, -0.050969314, -0.0104303295, -0.026967853, -0.038719103, -0.11337068, 0.014442867, -0.07811106) * inp_1_2_0;
    result += M4(0.0056283004, -0.039674114, 0.010664788, -0.007585467, 0.094688386, 0.026612436, 0.115747884, 0.06140152, 0.087393865, 0.015162906, -0.011511859, -0.0052651847, -0.001403368, 0.013589528, -0.036005724, -0.025916325) * inp_1_0_1;
    result += M4(0.03362264, 0.028528653, -0.07993491, -0.046238482, 0.0256372, 0.09948653, 0.04734759, 0.011195686, -0.027100423, -0.09669529, 0.101576634, -0.0019390663, 0.024644533, 0.05771453, -0.010137688, 0.05746198) * inp_1_1_1;
    result += M4(-0.03978482, 0.02623949, 0.041617885, 0.065162644, -0.012816007, -0.034661677, -0.020234754, 0.026541375, -0.032319244, -0.009742865, -0.0010101445, -0.004244648, -0.032919414, 0.044180118, 0.0026209392, 0.04731575) * inp_1_2_1;
    result += M4(0.015907623, -0.0051920754, 0.07869039, 0.012747295, -0.03597984, -0.0057039782, -0.009526015, -0.031966805, 0.013329943, 0.026573442, 0.106299564, 0.046389326, -0.010341011, 0.002631461, -0.023609571, -0.03329991) * inp_1_0_2;
    result += M4(-0.023878723, 0.037398007, -0.06484367, 0.010876834, 0.01183712, -0.0072982926, 0.02397502, 0.05471044, 0.0051345406, -0.022396635, -0.032253984, -0.017085318, -0.03920912, -0.02300687, 0.014672342, 0.036828473) * inp_1_1_2;
    result += M4(0.007918246, -0.03118849, 0.009666915, -0.06397565, -0.017318388, -0.008853299, -0.005215012, -0.033239007, -0.00860726, 0.041709572, -0.06375282, -0.022012977, -0.00617207, -0.012168684, 0.008006112, 0.06385085) * inp_1_2_2;
    result += M4(-0.061888024, -0.054576155, -0.005524405, -0.00552835, 0.012842817, -0.004542139, 0.0375209, 0.044747565, -0.044146754, -0.043092936, -0.047718514, 0.00024245628, -0.020198137, 0.008730801, -0.036793202, 0.014823956) * inp_2_0_0;
    result += M4(-0.07207893, -0.009919309, 0.02393241, 0.07650912, -0.025161052, -0.015798332, -0.063558675, -0.004162595, 0.026818736, 0.056124624, -0.009727707, 0.02589375, 0.07903053, 0.004022702, -0.0055220737, -0.010753363) * inp_2_1_0;
    result += M4(0.0139756035, -0.05064841, -0.003096741, -0.018059704, -0.038878635, -0.0148671465, -0.029058922, -0.041704807, -0.00018905039, 0.030931437, 0.0055082766, -0.0020851244, 0.010236284, 0.101947434, -0.022671282, 0.015836762) * inp_2_2_0;
    result += M4(0.013251062, 0.033706646, 0.065155745, 0.03143516, 0.06986193, -0.047408573, 0.060637694, -0.019389179, -0.020070784, -0.052210968, -0.025805173, -0.030004658, -0.09438553, 0.026907912, -0.045405895, -0.011626638) * inp_2_0_1;
    result += M4(-0.024024215, -0.15341066, -0.020549206, -0.09571147, 0.18762667, 0.035205826, 0.19959386, 0.03676199, -0.021258382, 0.13038926, 0.051047612, 0.024312004, 0.113464504, -0.2368448, 0.23486604, -0.06053652) * inp_2_1_1;
    result += M4(0.0075529967, 0.025691278, 0.060687684, 0.024498623, -0.103043325, 0.023442375, -0.10537525, 0.05800267, 0.051046316, -0.0197792, -0.023883974, -0.006798989, -0.06195528, 0.05362327, -0.06488619, 0.04247078) * inp_2_2_1;
    result += M4(-0.013816588, -0.024103392, -0.037544522, -0.029624391, 0.05289947, 0.023379369, 0.058422506, 0.007019942, -0.022348955, -0.012816714, 0.016321003, -0.038580045, 0.011045859, 0.017236708, -0.038804617, 0.021794641) * inp_2_0_2;
    result += M4(0.008563726, 0.0035463993, -0.09133061, -0.04427953, 0.005425287, 0.014512284, 0.0007330219, -0.06498317, 0.01509129, -0.07514254, 0.026744146, 0.014062658, -0.016346658, 0.010460316, 0.051120177, -0.02780931) * inp_2_1_2;
    result += M4(-0.026053071, -0.028813168, -0.011652695, -0.056831177, -0.016731743, 0.025709283, -0.034162145, 0.06257126, 0.01847481, -0.0033557662, 0.013304942, -0.0028601422, -0.03592641, 0.003468139, -0.041722085, 0.024318274) * inp_2_2_2;
    result += M4(-0.038400967, -0.015297928, -0.01914916, -0.019829122, 0.09696019, 0.025501415, 0.04321369, 0.01944455, -0.05188078, 0.015448198, -0.023579467, 0.022971893, -0.017772833, -0.005822067, 0.00038654072, 0.008730085) * inp_3_0_0;
    result += M4(0.06128068, 0.036927804, 0.009261602, -0.028389126, 0.16244593, 0.18297893, 0.111735694, 0.13202, 0.0045009884, 0.0014839605, 0.009976661, -0.0013730886, 0.0623475, -0.0263572, 0.022278873, 0.0020890676) * inp_3_1_0;
    result += M4(0.00045932707, 0.009096548, 0.015347618, 0.02166806, 0.09839366, 0.14832935, 0.025173947, 0.014085937, 0.036318745, -0.056901086, -0.016171841, -0.03926594, -0.019377036, 0.032809284, 0.020838048, 0.04005107) * inp_3_2_0;
    result += M4(-0.10034193, 0.013414627, -0.05372, -0.0010851959, 0.17464592, 0.0929784, 0.16841476, 0.15655957, 0.045534197, 0.0018810913, 0.032345872, -0.014544803, -0.023351125, 0.003747968, 0.016102174, 0.02698542) * inp_3_0_1;
    result += M4(0.011031946, -0.024566015, 0.013464647, 0.09892539, 0.14614573, 0.20704289, 0.18375576, 0.17733823, -0.01977114, 0.0063442746, -0.014442647, -0.001036872, 0.08985391, -0.04339365, -0.06673354, -0.08362764) * inp_3_1_1;
    result += M4(-0.015101311, 0.029433126, -0.01828129, 0.01232359, 0.026363714, 0.06312535, 0.08310441, 0.13859265, -0.022491708, 0.046937842, 0.038557407, 0.08470863, -0.036204517, 0.010280595, 0.022997582, -0.04984066) * inp_3_2_1;
    result += M4(0.008672858, -0.004271227, -0.055568747, -0.022363614, 0.05412554, 0.058517557, 0.11170838, 0.05716976, -0.009092009, 0.0037470772, -0.06680116, 0.0029258537, -0.008782894, -0.0035336716, -0.018215073, 0.02638884) * inp_3_0_2;
    result += M4(0.033000577, 0.023113286, 0.03031661, -0.008474311, 0.17523155, 0.14018835, 0.18049316, 0.111770384, -0.001358863, -0.015679674, 0.00037790314, -0.004988974, -0.04498709, 0.026785629, 0.006817566, 0.015628047) * inp_3_1_2;
    result += M4(-0.013828982, -0.0033725158, -0.024028456, -0.008424562, 0.033175163, 0.0583053, 0.057668075, 0.15997145, 0.0012013859, 0.0013406974, 0.04826181, -0.04718633, -0.005736346, 0.018146766, 0.00022737155, 0.007355116) * inp_3_2_2;
    result += M4(0.027224401, 0.0063074576, -0.042877402, -0.01089408, -0.018205512, 0.06183576, -0.021333443, 0.006512136, 0.035182193, 0.02640569, -0.01944865, 0.027113605, 0.06356028, 0.014098231, 0.022255955, 0.004604285) * inp_4_0_0;
    result += M4(0.037131473, 0.002003085, -0.028988345, 0.016053047, 0.030679306, -0.0016299253, 0.010660896, 0.043504234, -0.057943106, 0.01929443, -0.011360261, -0.02155587, -0.0022923232, -0.040189832, 0.033730406, -0.007807499) * inp_4_1_0;
    result += M4(-0.025998317, -0.02845014, -0.02218897, 0.02989808, -0.014509838, 0.01340775, 0.027352078, 0.009899966, 0.01323762, -0.07467879, 0.03203016, 0.039170057, 0.015820073, -0.032280713, -0.0051010265, -0.050074965) * inp_4_2_0;
    result += M4(-0.009217301, -0.02436621, 0.024107538, -0.003473377, 0.03982655, 0.019158045, 0.024994835, -0.0051386063, -0.043199502, -0.0019381179, 0.020063376, -0.011217869, -0.051392302, -0.013023889, -0.0020201544, 0.043377873) * inp_4_0_1;
    result += M4(-0.013219451, -0.05852758, 0.099649906, -0.07258891, -0.05638155, 0.025138177, -0.045323946, -0.02896582, 0.06764066, -0.017722137, -0.1374806, 0.074767396, -0.001511866, 0.062196624, 0.048577387, -0.018203927) * inp_4_1_1;
    result += M4(0.014797506, 0.07039923, -0.005842946, -0.0367656, -0.013423364, -0.06684155, 0.027297245, 0.017533233, -0.012682284, 0.063645214, 0.041960046, -0.0820861, 0.03504871, 0.02425601, 0.017583596, 0.063788466) * inp_4_2_1;
    result += M4(0.0023840563, 0.022716755, -0.033614244, -0.00086421234, 0.028959837, 0.0037310082, -0.030542703, -0.008585729, 0.011831935, 0.002317461, 0.017095406, 0.005800205, 0.01583885, 0.0064531695, -0.007048931, -0.012813034) * inp_4_0_2;
    result += M4(-0.024555126, 0.009403804, 0.0027097492, 0.014528817, -0.006753117, -0.04388842, -0.009794302, -0.054198816, 0.014008969, -0.0075297724, 0.086939126, -0.036712516, -0.017900202, -0.0058936807, -0.07895054, 0.0111140665) * inp_4_1_2;
    result += M4(-0.010756671, -0.0006509647, 0.010855238, 0.06470651, 0.012677826, -0.00656679, 0.017104074, 0.01801689, -0.015458804, -0.0205607, -0.031172842, 0.0038421443, -0.039565463, -0.008114233, -0.028020743, -0.05643096) * inp_4_2_2;
    result += M4(0.08728728, -0.030804975, 0.0026790232, -0.037877947, -0.024835844, -0.01095019, 0.021938574, -0.0023340238, 0.00851406, 0.07992627, 0.094944336, 0.08113191, 0.06588399, 0.04809115, -0.01818017, 0.008360642) * inp_5_0_0;
    result += M4(0.01776917, -0.018196154, -0.0036168795, 0.017557938, 0.025679484, -0.0239697, -0.0068150843, 0.019800538, -0.0058165914, -0.104481556, -0.010301028, 0.021987524, -0.036184017, -0.017000215, 0.0045723342, 0.008487737) * inp_5_1_0;
    result += M4(-0.028211998, 0.003029629, 0.0036745302, 0.006224571, 0.017101232, 0.0031086525, 0.006960394, 0.019729385, 0.0016672115, 0.029549532, -0.008848763, 0.026610998, -0.022749174, -0.045433033, -0.0031735667, -0.040051714) * inp_5_2_0;
    result += M4(0.054610495, -0.0010337438, -0.04088433, 0.022924379, 0.03692914, 0.012763708, -0.01927017, 0.03907912, 0.05408268, 0.006239764, -0.08504864, 0.0038386376, -0.03304454, 0.042288177, -0.010379474, 0.030860187) * inp_5_0_1;
    result += M4(-0.09084974, -0.03540789, 0.0208299, 0.060675006, -0.071661025, 0.07936915, 0.03524633, -0.058033533, -0.10825422, 0.0004118362, 0.043499228, -0.11085395, 0.015691094, -0.0026184896, -0.0024282387, -0.010155577) * inp_5_1_1;
    result += M4(0.0012742117, 0.08242641, -0.014293072, 0.019195275, -0.016356891, 0.011555532, -0.0018970323, -0.03655368, 0.026479501, -0.0093721235, 0.01763175, -0.0240184, -0.016500926, -0.008853243, -0.022308914, 0.045630142) * inp_5_2_1;
    result += M4(-0.035190858, 0.015644602, 0.01419864, 0.032612044, -0.011799356, -0.009746455, -0.006168799, -0.0076720645, -0.0077225184, -0.0050982423, 0.021273479, -0.025914945, -0.023344023, -0.049974937, 0.06511288, -0.0070636133) * inp_5_0_2;
    result += M4(-0.01033882, 0.00863925, -0.0013628715, -0.07007067, 0.011701528, -0.011225419, 0.005624737, 0.007798648, 0.03942578, -0.014488255, -0.08124892, 0.013707921, 0.012991226, -0.009342794, -0.036514252, -0.017152762) * inp_5_1_2;
    result += M4(0.0048228004, -0.021904444, 0.021318594, -0.055431575, 0.0052957614, -0.013873913, -0.010850155, -0.0026140357, 0.000293071, 0.018478392, 0.003793567, 0.015788455, 0.028200006, 0.0358657, 0.033121187, -0.00887786) * inp_5_2_2;
    result += M4(0.04280599, 0.077129036, 0.041256312, 0.05601294, 0.0054911645, 0.0025763644, 0.04546859, 0.035288684, 0.022638788, 0.02258582, 0.0076959, 0.03219339, 0.012491349, 0.025966158, 0.02085662, 0.016688934) * inp_6_0_0;
    result += M4(0.010881702, 0.021431653, -0.040422484, -0.032821998, -0.008801704, 0.03824917, -0.0052108145, 0.04111981, -0.11523921, -0.0737427, -0.017567445, -0.020198634, 0.06314336, 0.010913344, 0.12255025, 0.09774901) * inp_6_1_0;
    result += M4(-0.083623946, -0.07919439, -0.016129337, -0.057592615, 0.008185325, 0.02797716, -0.013745716, 0.046620924, -0.0031240154, -0.034476496, -0.013716546, -0.010147287, 0.030844063, 0.058386832, 0.024683412, 0.01925473) * inp_6_2_0;
    result += M4(-0.012459126, -0.034623414, 0.011595973, -0.051216356, -0.013720241, 0.048272945, -0.026728988, 0.02648294, 0.008248318, 0.068647966, 0.019478869, 0.10317176, -0.020806609, 0.017271144, -0.006267348, 0.04253698) * inp_6_0_1;
    result += M4(0.060382802, 0.032664176, 0.04142416, -0.021853961, 0.04120915, -0.063247815, 0.048348065, -0.027418323, -0.22349426, -0.1445409, -0.36879572, -0.3055885, -0.24273908, -0.18070647, -0.10684778, -0.094931334) * inp_6_1_1;
    result += M4(-0.0028041857, 0.055832874, -0.037102785, 0.12184069, -0.0021262967, -0.06950446, -0.031027267, -0.010346156, -0.11787928, -0.1107874, -0.09529378, -0.09389775, -0.031179652, -0.063009344, -0.0308216, -0.0048123086) * inp_6_2_1;
    result += M4(-0.018503034, 0.0013063347, -0.037771408, -0.014643274, 0.014593403, 0.008755043, -0.033726986, -0.019617924, 0.09869283, 0.09532338, 0.08446307, 0.10753203, 0.011350606, 0.015246138, -0.0021937408, -0.00185287) * inp_6_0_2;
    result += M4(0.005591816, -0.018050304, 0.073187, 0.057073515, -0.033338323, -0.0032822955, -0.0027819313, 0.015201171, 0.15220281, 0.1342384, 0.07986018, 0.026344094, -0.0218832, -0.005528166, -0.030984214, 0.004399955) * inp_6_1_2;
    result += M4(0.0061185127, -0.03979605, -0.009951781, -0.09340412, -0.0025621206, 0.005289888, 0.02069726, -0.11132749, 0.023100948, 0.049413677, -0.015248753, 0.018200431, -0.004253594, -0.018831106, 0.0009874147, -0.019937944) * inp_6_2_2;
    result += M4(0.030052794, 0.01035262, -0.0028822343, -0.018438224, 0.041824315, 0.01637586, 0.005356457, 0.010197082, 0.07500377, -0.012366087, 0.009356775, -0.015911072, -0.005273326, -0.03652784, -0.0066323136, -0.016021209) * inp_7_0_0;
    result += M4(-0.054528706, -0.05146931, 0.008712025, -0.018316027, 0.07739784, 0.10553302, 0.042159732, 0.09026727, 0.03487811, 0.09814782, -0.039796825, -0.02358726, 0.038298763, -0.0047183717, 0.039241288, -0.008139571) * inp_7_1_0;
    result += M4(0.025003185, -0.036907468, 0.0016937735, 0.013664151, -0.043681018, -0.018008685, -0.011148441, -0.016937451, 0.01098553, 0.035754446, -0.013058176, 0.008777089, 0.012561569, -0.0011803127, 0.011522383, 0.049887452) * inp_7_2_0;
    result += M4(-0.0026782316, 0.03781157, 0.043110307, -0.0069933077, 0.15748739, 0.031557154, 0.08678889, -0.020304183, 2.715033e-05, -0.0065343394, 0.101653054, -0.022469413, -0.031018522, 0.014520576, -0.026857786, 0.00838662) * inp_7_0_1;
    result += M4(-0.053730264, 0.0050318292, 0.03299609, 0.13951205, 0.29574254, 0.41569364, 0.20012224, 0.3806968, -0.24821138, -0.06555929, 0.062292993, 0.25441456, 0.089019395, 0.10505667, -0.024019988, 0.0021124063) * inp_7_1_1;
    result += M4(-0.027115371, 0.021641577, 0.0059523867, -0.07703892, -0.12925863, 0.016407307, -0.12746093, -0.077202484, 0.0029687278, -0.080125876, -0.004832494, -0.027594144, -0.069550335, -0.029068002, -0.005921241, -0.0766755) * inp_7_2_1;
    result += M4(0.012836159, 0.009362633, -0.02696169, -0.011232103, -0.084095776, -0.06843029, 0.03533937, -0.031978514, 0.03347511, 0.01692637, -0.00357671, 0.0010234107, -0.0062344386, 0.003031405, 0.031756014, 0.016962182) * inp_7_0_2;
    result += M4(0.008978897, -0.007612565, 0.0029875261, 0.012819657, -0.15910861, -0.16312556, 0.03147902, 0.046847582, 0.027546898, 0.0059726564, -0.11084151, -0.07037886, -0.012980756, -0.033751003, -0.06900609, -0.012628596) * inp_7_1_2;
    result += M4(0.010006697, 0.0327328, -0.046801776, -0.035235465, -0.12791584, -0.11627126, -0.16093741, -0.09615695, 0.040230624, 0.022752294, 0.020276414, -0.05575017, 0.010372106, -0.009365253, 0.037893448, 0.014156526) * inp_7_2_2;
    FragColor = result;
}
