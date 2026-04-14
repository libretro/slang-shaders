#version 450

// Based on ArtCNN_C4F32.glsl.
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
    result = V4(0.09878782, 0.09473654, 0.09866235, 0.09544336);
    result += M4(0.021845995, 0.00923297, -0.014651779, -0.0005667969, -0.023344567, -0.01833543, -0.011601852, -0.0020169015, 0.045326777, -0.032315172, 0.007078589, -0.020654466, -0.11703377, -0.011664843, -0.02867888, 0.0016418267) * inp_0_0_0;
    result += M4(-0.030409543, -0.01275331, 0.03163342, 0.008023201, -0.0063992543, -0.0284605, -0.046062823, -0.046731375, 0.013351812, 0.021334628, 0.011847752, 0.040223304, -0.02904078, -0.10056173, -0.0070626857, -0.0431445) * inp_0_1_0;
    result += M4(0.0039925133, -0.013273887, 0.024387475, 0.031861275, 0.008615945, 0.0074427924, 0.008972938, 0.027460922, -0.032001305, 0.0031068195, 0.009632848, 0.013365713, -0.058926478, -0.12789509, -0.00612882, -0.011997772) * inp_0_2_0;
    result += M4(0.009170344, -0.0324075, 0.004619318, -0.034588158, 0.0018333842, 0.051718693, -0.049646277, -0.01178411, 0.002353625, -0.001988641, -0.01177594, -0.021371564, 0.010874673, 0.046233833, 0.0061872797, 0.030681292) * inp_0_0_1;
    result += M4(0.013369006, 0.012099311, 0.0011759301, 0.0048387344, -0.08040615, -0.008611932, 0.054661606, 0.045823786, -0.042669304, 0.02729385, 0.015340368, -0.07672151, 0.23866998, 0.21135826, 0.25820324, 0.21249358) * inp_0_1_1;
    result += M4(0.0068678367, -0.006582608, -0.04242511, 0.0067600315, 0.04003407, 0.023596024, -0.040863767, 0.00013780208, 0.011312975, -0.034471445, 0.0010264408, 0.045765247, 0.0036205058, -0.043013114, -0.020834597, -0.037008144) * inp_0_2_1;
    result += M4(-0.006931655, -0.0037352392, 0.0047042053, 0.005864766, 0.0031939682, -0.022786241, 0.060393747, 0.009342759, -0.0069679413, -0.014066365, -0.0020358474, 0.017902795, 0.02122528, 0.018485093, -0.07797075, 0.012235483) * inp_0_0_2;
    result += M4(-0.006360104, 0.020608008, -0.037814878, -0.024628675, 0.054318395, 0.021033965, 0.01898423, 0.017190056, 0.016437622, 0.0072630853, -0.007951118, 0.020473938, 0.049010765, 0.049702216, 0.033800196, 0.014753147) * inp_0_1_2;
    result += M4(-0.011965985, 0.027404882, 0.02935067, 0.0021004486, 0.0022131826, -0.025667844, 0.005243409, -0.039458003, -0.0074959868, 0.023709431, -0.022327172, -0.019713128, 0.018060282, -0.017483944, -0.021819854, -0.14553426) * inp_0_2_2;
    result += M4(-0.020909442, -0.008989111, -0.0021687713, -0.0069194324, -0.040283523, -0.025767792, -0.061803088, 0.0076894625, -0.038674932, 0.02617475, -0.012287884, 0.013908166, 0.006555676, -0.025049394, 0.0214629, -0.009989944) * inp_1_0_0;
    result += M4(0.02582961, -0.0068905153, 0.00027230143, 0.014628823, 0.04316013, -0.015099009, 0.0050969617, -0.028622165, 0.03956802, 0.029235221, -0.012187185, -0.008831148, 0.023902493, 0.013305333, -0.009518938, -0.010144944) * inp_1_1_0;
    result += M4(0.0104014985, 0.012121211, -0.009303343, 0.013048964, -0.03256103, 0.019941146, 0.012937486, 0.008066967, 0.012465702, -0.047337092, -0.0074795485, -0.011997537, 0.0038883304, -0.044082843, 0.028101234, -0.028852245) * inp_1_2_0;
    result += M4(0.006129608, -0.029761057, 0.020156607, -0.003944418, 0.053577717, 0.011727514, 0.044621803, 0.019679843, 0.037838075, 0.016743049, -0.02557201, 0.007592878, 0.0017753294, 0.033697546, -0.009347553, -0.015898146) * inp_1_0_1;
    result += M4(0.01766015, 0.0041769426, -0.060872417, -0.036149625, 0.0033517217, 0.051414177, 0.0072023966, -0.026097808, -0.004782113, -0.047765225, 0.06063902, -0.03142622, 0.07265865, 0.04818854, 0.030932182, 0.053911157) * inp_1_1_1;
    result += M4(-0.028035065, 0.01271305, 0.017770875, 0.040135622, -0.016889933, -0.041969404, -0.001332217, 0.022146843, -0.029414564, 0.012494689, 0.0051135183, 0.022950288, -0.05793264, -0.01467772, 0.0044534863, -0.0069829407) * inp_1_2_1;
    result += M4(-0.013476227, -0.010227336, 0.035730336, -0.007607085, -0.009037083, 0.011669305, -0.024595153, -0.024000788, -0.01305629, 0.010675441, 0.062531665, 0.0058305357, -0.0035399124, 0.013548699, -0.017104633, -0.025176737) * inp_1_0_2;
    result += M4(-0.02265931, 0.033375267, -0.018153738, 0.031275585, 0.011745682, -0.014601294, 0.0025895135, 0.02577678, 0.0033817946, -0.028464083, -0.033894673, 0.016219346, -0.051407386, -0.025466394, -0.044046972, -0.013803419) * inp_1_1_2;
    result += M4(0.025124358, -0.006627566, 0.018165471, -0.045887575, -0.013303172, 0.00233562, 0.014297578, -0.004453115, -0.0072876206, 0.027656792, -0.03509256, -0.014018425, 0.0042956136, -0.0003635888, -0.0038194112, 0.05571797) * inp_1_2_2;
    result += M4(-0.045293126, -0.009507033, -0.020958012, 0.0028741835, -0.028892173, -0.013422339, -0.01375965, 0.015121977, -0.026627388, -0.026482955, -0.00880384, 0.018158864, 0.01903999, 0.0047557238, -0.004414449, 0.019542456) * inp_2_0_0;
    result += M4(0.04765631, 0.08073932, 0.04718635, 0.10314033, -0.0497485, -0.03233656, -0.052061938, 0.013144127, -0.034823216, -0.018248862, -0.011374393, 0.010479364, 0.049451914, -0.027185217, 0.0057518627, -0.014667739) * inp_2_1_0;
    result += M4(0.0682864, 0.0014723825, 0.017564783, -0.020534838, -0.0072129145, -0.033394653, -0.023130465, -0.06629361, 0.020750413, 0.029277522, 0.011851179, -0.0038010993, 0.007314412, 0.08797337, -0.019982358, 0.018098628) * inp_2_2_0;
    result += M4(0.059612896, 0.048109267, 0.015829114, -0.016320577, -0.029167362, -0.08519065, -0.03226275, -0.041980375, -0.060908087, -0.052325465, -0.070109524, -0.044936456, -0.020929731, 0.042971224, -0.0021150808, 0.0029793526) * inp_2_0_1;
    result += M4(0.0059181005, -0.12868848, -0.1428892, -0.20816758, 0.21199383, 0.1365571, 0.25739637, 0.13362871, 0.0453919, 0.16896047, 0.10884528, 0.07509096, 0.10747506, -0.22761816, 0.21628167, -0.05490478) * inp_2_1_1;
    result += M4(0.036632143, 0.10728248, -0.012191513, -0.027990773, -0.13214794, -0.05118176, -0.10765409, 0.00035716637, 0.047775343, -0.034511272, -0.0006371164, -0.03463688, -0.07406134, -0.011930151, -0.07452722, -0.012726115) * inp_2_2_1;
    result += M4(-0.018006856, -0.024927055, -0.039779406, -0.034424353, 0.008507468, 0.0399062, 0.00968349, 0.021581966, -0.011046537, -0.00012341797, 0.020918565, -0.014472872, 0.02436196, 0.013794884, -0.00067718164, 0.009589558) * inp_2_0_2;
    result += M4(0.020470805, 0.019855456, -0.043477852, -0.043963335, 0.03349275, 0.043551378, -0.006940629, -0.08597366, -0.0044056503, -0.07239349, -0.05716467, -0.00083604624, -0.0015783524, 0.00075090653, 0.0605259, -0.052989032) * inp_2_1_2;
    result += M4(-0.014607917, -0.006769994, -0.0026060787, -0.010657442, -0.018661296, 0.0012874923, -0.02776995, 0.041963838, 0.023855781, 0.006731541, 0.008845393, -0.007686197, -0.04012487, -0.02294487, -0.043985743, 0.0011835934) * inp_2_2_2;
    result += M4(-0.021677352, -0.0117401695, 0.004518356, -0.009685185, 0.094834596, 0.013126099, 0.033670343, 0.004231779, -0.029283414, 0.012214747, -0.022137742, 0.016818568, 0.00095621543, -0.014504671, 0.0045239134, 0.011290582) * inp_3_0_0;
    result += M4(0.02804712, -0.0113771595, 0.007347934, -0.027659193, 0.17502117, 0.19472298, 0.123926565, 0.14307262, -0.013111147, 0.008779482, -0.009959132, 0.005732099, 0.028414708, -0.04436345, 0.011360493, -0.010027618) * inp_3_1_0;
    result += M4(-0.003838526, 0.011423468, -0.0011499735, 0.024384381, 0.09888151, 0.15951113, 0.013506597, -0.002353069, 0.06127302, -0.014568737, -0.011889662, -0.023750147, -0.026105855, 0.01895885, 0.011877856, 0.022671351) * inp_3_2_0;
    result += M4(-0.018721849, 0.033940632, -0.0058633573, -0.0006167294, 0.1878491, 0.093363136, 0.18128133, 0.17116942, 0.012423489, -0.010392725, 0.019000173, -0.0169145, -0.035966814, 0.004880984, 0.011222432, 0.023008749) * inp_3_0_1;
    result += M4(0.017326716, -0.031237172, 0.03410064, 0.044671513, 0.15124398, 0.2144302, 0.18934388, 0.18356955, -0.00025861885, 0.008206613, -0.009892421, -0.010072149, 0.07948794, -0.013292945, -0.014529488, 0.008760314) * inp_3_1_1;
    result += M4(-0.029952483, 0.012424221, -0.021917323, 0.014153385, 0.010196946, 0.054626264, 0.07610725, 0.15059759, -0.048268948, 0.01518732, 0.003959537, 0.019882564, -0.034728136, 0.020078616, 0.023970602, -0.054023765) * inp_3_2_1;
    result += M4(0.018374931, 0.00496525, -0.021751571, -0.025935546, 0.04511196, 0.06007452, 0.11724879, 0.054520566, 0.008097092, -0.009317496, -0.030522656, 0.03273854, 0.012870774, -0.022377662, -0.018366655, 0.033529308) * inp_3_0_2;
    result += M4(0.026773151, 0.009335391, 0.02321184, -0.0072314255, 0.1914924, 0.15432239, 0.19257082, 0.11107709, 0.020814097, -0.0065054037, 0.025610423, -0.0074282633, -0.018777713, 0.032589786, -0.0071435496, -0.009558263) * inp_3_1_2;
    result += M4(-0.01614204, -0.013995716, -0.024556905, -0.010945395, 0.025782371, 0.04715687, 0.052295957, 0.17307253, -0.012228171, -0.0034974797, 0.03626981, -0.01724794, -0.0063924934, 0.018752439, -0.025179146, -0.023961835) * inp_3_2_2;
    result += M4(0.019233782, -0.015165059, -0.038414046, 0.0044954726, 0.011204252, 0.04189584, -0.021014044, 0.0009775371, 0.04242332, 0.012255439, -0.0007449484, 0.02052313, 0.03485092, -0.012134074, 0.004389388, -0.0014908464) * inp_4_0_0;
    result += M4(0.028782545, 0.009470256, -0.01541961, 0.015471757, 0.009774452, -0.014652784, 0.0007463575, 0.031451415, -0.07373567, -0.024669297, -0.01780204, -0.03869637, -0.013541652, -0.016476562, 0.02350204, 0.0055448296) * inp_4_1_0;
    result += M4(0.005574446, -0.0156076485, -0.012073491, 0.021793216, -0.025638446, -0.0064817294, 0.004325301, 0.0032413984, 0.016225765, -0.018339487, 0.009920945, 0.04658623, 0.036285006, -0.012757719, 0.01668213, -0.025542723) * inp_4_2_0;
    result += M4(0.009313834, -0.022023713, 0.054740716, -0.0046449453, -0.0038328264, -0.004731104, -0.0030217846, -0.009901582, -0.04144257, 0.0039868546, -0.0009157865, -0.023685891, -0.04189296, -0.008065431, -0.0018986162, 0.034864567) * inp_4_0_1;
    result += M4(-0.033850703, -0.02981953, 0.044203404, -0.05170425, -0.019150872, 0.038871318, -0.011871686, -0.014906511, 0.08776331, 0.010405535, -0.06530442, 0.10109231, -0.01247806, 0.030118234, 0.018255925, -0.04644983) * inp_4_1_1;
    result += M4(0.013363665, 0.05365835, -0.0080188615, -0.04533615, -0.010505944, -0.019319572, 0.012085702, 0.018746953, -0.030789211, 0.035555065, 0.048638955, -0.060334958, 0.03077203, 0.03312572, -0.003593782, 0.029485438) * inp_4_2_1;
    result += M4(0.0051345294, 0.023436071, -0.0077538597, 0.0029680484, 0.031210141, -0.016144648, -0.007804191, -0.000639, 0.0038666534, 0.013053829, 0.019085327, 0.006428825, 0.015040178, 0.011052756, -0.0061197295, 0.00064434315) * inp_4_0_2;
    result += M4(-0.027774539, 0.010080438, -0.007904666, 0.025843294, -0.001809348, -0.0052564964, 0.010171315, -0.036257602, 0.007382936, 0.000710884, 0.03675937, -0.054207988, -0.0033079379, -0.007492857, -0.036551356, 0.037562624) * inp_4_1_2;
    result += M4(-0.020291371, -0.0135067245, -0.009745377, 0.031590693, 0.009073487, -0.014500891, 0.017604554, 0.006615444, -0.010812366, -0.033496596, -0.030757034, 0.003623485, -0.045518775, -0.018312827, -0.012984233, -0.035579395) * inp_4_2_2;
    result += M4(0.021392154, -0.04481118, -0.025659792, -0.018115979, -0.0162344, -0.0031181679, 0.0048183156, -0.012093688, 0.014172713, 0.05281507, 0.044272874, 0.015096085, 0.03004133, 0.0078117596, -0.040290818, 0.011920343) * inp_5_0_0;
    result += M4(0.003935762, -0.016772285, 0.0074610407, 0.020580398, 0.012782687, -0.014274959, -0.013686723, 0.020124272, -0.026106529, -0.06202789, -0.028806278, 0.017611576, -0.0063033686, -0.009796388, 0.017634671, 0.021701822) * inp_5_1_0;
    result += M4(-0.01126909, 0.020495001, 0.002539927, 0.009516308, 0.010247538, -0.0006374959, -0.005510141, 0.010154715, -0.014088566, 0.014521846, -0.011839686, 0.004684481, 0.004166807, -0.012444833, 0.006424152, -0.023572352) * inp_5_2_0;
    result += M4(0.040388003, -0.029881483, -0.057309493, 0.046086986, 0.019913333, 0.0007068011, 0.00027581103, 0.040743127, 0.05739379, 0.0063867355, -0.020870255, 0.020377604, -0.004864155, 0.046745323, 0.009826212, 0.02760339) * inp_5_0_1;
    result += M4(-0.029892137, 0.010040926, 0.028237386, 0.022597332, -0.064409144, 0.058986817, 0.042260945, -0.0625515, -0.050471894, 0.021828845, 0.058564726, -0.054811925, 0.017653879, 0.007535327, 0.0055531706, -0.022872955) * inp_5_1_1;
    result += M4(-0.009040554, 0.03354936, -0.011932947, -0.020966467, -0.024817932, 0.014737554, 0.0004824739, -0.011072206, 0.0060642264, -0.041654542, 0.008506339, -0.0116498135, -0.03797305, -0.050029065, -0.012251583, 0.010174026) * inp_5_2_1;
    result += M4(-0.02201589, 0.029991172, 0.025814207, 0.0199784, -0.002038181, -0.007519278, -0.011738085, -0.0076679164, -0.024628848, 0.01716019, 0.0042316145, -0.022639744, -0.025593556, -0.034525767, 0.021443795, -0.03779618) * inp_5_0_2;
    result += M4(-0.023332486, 0.0075709624, 0.016141376, -0.01976806, 0.01827179, -0.003539572, 0.018100504, -0.0037530842, 0.038870916, -0.021204714, -0.06045873, 0.022238068, -0.002437607, -0.0025254504, -0.04341895, -0.010414948) * inp_5_1_2;
    result += M4(0.030545482, -0.010887457, 0.014306388, -0.05985375, 0.007032392, -0.0074627553, -0.005134922, -0.0021265035, -0.0015534473, 0.013533022, 0.005196969, 0.009838008, 0.025642194, 0.047146488, 0.035174802, 0.02292211) * inp_5_2_2;
    result += M4(0.04895621, 0.033444706, 0.022162106, 0.026694214, 0.0021245852, -0.005840921, 0.022099504, 0.0002869935, 0.050674517, 0.023502694, 0.028487528, 0.031746116, 0.03148947, 0.036248755, 0.021912456, 0.010571573) * inp_6_0_0;
    result += M4(-0.052591007, -0.0017953392, -0.050473, -0.031431798, -0.017156571, 0.00080332335, -0.015072964, 0.0118451025, -0.093807325, -0.10117188, 0.005661041, -0.0040574246, 0.09849568, 0.046757482, 0.12010055, 0.103599615) * inp_6_1_0;
    result += M4(-0.03765376, -0.029832983, -0.011725054, -0.012807199, 0.008137142, 0.0031612592, -0.018345634, 0.028766897, 0.01990054, -0.026210047, -0.0023832824, -0.021838618, 0.057052597, 0.082380325, 0.016509969, 0.002374868) * inp_6_2_0;
    result += M4(-0.031158147, -0.012876452, 0.024566712, -0.025070176, -0.0054019196, 0.046503052, -0.0097213015, 0.012948774, 0.062119573, 0.075426705, 0.10073122, 0.1607912, 0.029890282, 0.029083041, -0.008166052, 0.030011285) * inp_6_0_1;
    result += M4(0.051949676, 0.0026599355, 0.06839426, 0.035303876, 0.043927867, -0.020438084, 0.023172678, -0.011855767, -0.22268605, -0.22342284, -0.33833888, -0.34882563, -0.20737693, -0.16748215, -0.14986652, -0.1511559) * inp_6_1_1;
    result += M4(-0.008782758, 0.031245582, -0.06797611, 0.03258001, 0.013847654, -0.051280174, -0.021121792, -0.028629825, -0.15271252, -0.15525945, -0.09532162, -0.09459921, -0.017235694, -0.029691847, -0.046402782, -0.02710881) * inp_6_2_1;
    result += M4(-0.007705225, 0.01562444, -0.027051156, 0.019640312, 0.015288926, 0.0095897615, -0.009082686, -0.011777561, 0.111967355, 0.101920836, 0.13098808, 0.11525785, 0.021068454, 0.014203576, 0.010398689, -0.012018553) * inp_6_0_2;
    result += M4(0.0025176252, -0.021547073, 0.053279445, 0.03631143, -0.029470364, -0.009878799, 0.0047456236, 0.017005615, 0.20778167, 0.1522982, 0.18931435, 0.02524994, -0.011741181, -0.018575177, -0.017983139, -0.018387204) * inp_6_1_2;
    result += M4(0.033195987, -0.018054826, -0.0082814535, -0.08218203, -0.031923074, 0.027260855, 0.023896065, -0.018352447, 0.020977572, 0.0142076425, 0.01884883, 0.03549403, -0.012022381, -0.009845198, -0.0018749286, -4.8127735e-05) * inp_6_2_2;
    result += M4(0.009165479, -0.008698953, -0.021462748, -0.020848881, 0.016930848, -0.0018519993, -0.0026254382, 0.009120888, 0.060157303, -0.004048518, 0.005259344, -0.0062268097, 0.015395012, -0.020801028, 0.016654074, -0.009187287) * inp_7_0_0;
    result += M4(-0.009528176, -0.04606582, 0.002827408, -0.0070309443, 0.10304533, 0.061039165, 0.063341014, 0.07237408, 0.013601314, 0.048085064, -0.031053858, -0.023337703, 0.02948484, -0.016950078, 0.013391826, -0.019121265) * inp_7_1_0;
    result += M4(0.0325016, -0.007798743, -0.022440113, 0.012150947, -0.032955628, -0.03427973, -0.015344162, -0.04266901, 0.017220825, 0.02218315, -0.011773896, 0.001618144, -0.0072916434, -0.0053652897, -0.010072158, 0.029030822) * inp_7_2_0;
    result += M4(0.025213646, 0.02245886, 0.039504524, -0.025092835, 0.15036894, 0.023286892, 0.06597429, -0.045287404, 0.016733807, 0.005125903, 0.07001157, -0.031541523, -0.02124107, 0.017432276, -0.012416234, 0.0007289886) * inp_7_0_1;
    result += M4(-0.04779597, -0.018533265, 0.002221774, 0.06374125, 0.37603468, 0.42516834, 0.23503834, 0.3698628, -0.23278037, -0.05660784, 0.049247917, 0.22647466, -0.012263151, 0.03471921, -0.030884063, 0.0038005607) * inp_7_1_1;
    result += M4(-0.0456132, 0.03916306, 0.004180005, -0.047036458, -0.14230324, -0.03966774, -0.17610934, -0.17105536, 0.004771039, -0.08297986, -0.0018637177, -0.029170942, -0.03435574, 0.021944506, 0.007175809, -0.015327818) * inp_7_2_1;
    result += M4(0.017349165, 0.0053192223, -0.0091194725, -0.016326236, -0.07863331, -0.067475334, 0.018275704, -0.062506095, 0.029034514, 0.02288371, -0.008628643, -0.0024705012, -0.0093607, -0.002580434, 0.020385062, 0.0037343465) * inp_7_0_2;
    result += M4(0.010348636, -0.03127588, 0.022416286, 0.042963654, -0.17467192, -0.2233974, -0.009850513, -0.04556525, 0.04829571, 0.017565792, -0.086523086, -0.07105858, 0.037150603, -0.0181264, -0.04215805, -0.0015138985) * inp_7_1_2;
    result += M4(0.010021619, 0.044416822, -0.020417435, -0.0011495892, -0.15771282, -0.14838748, -0.17133443, -0.14307828, 0.042705785, 0.02880333, 0.011857535, -0.06327709, 0.0028345648, -0.011308451, 0.038270682, 0.008408807) * inp_7_2_2;
    FragColor = result;
}
