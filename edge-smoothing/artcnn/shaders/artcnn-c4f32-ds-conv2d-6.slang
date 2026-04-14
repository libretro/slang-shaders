#version 450

// Based on ArtCNN_C4F32_DS.glsl.
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
    result = V4(0.08947147, 0.08528175, 0.09143897, 0.088739716);
    result += M4(-0.030004593, -0.0015731476, -0.029154608, -0.0039004358, -0.0627111, -0.035505254, -0.034215953, -0.022748977, 0.0700521, -0.015362208, 0.02759041, -0.020647367, -0.119912416, -0.012278255, -0.035904054, 0.004582784) * inp_0_0_0;
    result += M4(-0.0058119968, 0.0065449765, 0.040359534, 0.041060638, 0.03984736, -0.00080121204, -0.01728307, -0.021660095, 0.0044556456, 0.010959069, 0.007816643, 0.0521178, -0.031048326, -0.0880394, -0.0038433073, -0.031199658) * inp_0_1_0;
    result += M4(0.00023577544, -0.013563567, 0.03626446, 0.0357907, -0.004454704, -0.020657627, 0.00714733, 0.0065515786, -0.017171007, 0.00408016, 0.015145936, 0.0040100035, -0.06372799, -0.11448658, -0.009111416, -0.010646396) * inp_0_2_0;
    result += M4(0.032253575, -0.0142340455, 0.04183921, -0.015866023, 0.009826365, 0.042421527, -0.06068209, -0.018416716, -0.02320531, 0.017201416, -0.024718167, 0.014000975, -0.0034007672, 0.040062994, -0.0016874236, 0.033647016) * inp_0_0_1;
    result += M4(0.022416474, -0.0054776073, -0.039017484, -0.025972163, -0.11346841, 0.030732162, 0.054749675, 0.051763996, -0.05661015, 0.035573553, 0.0465254, -0.08330385, 0.21980493, 0.2074788, 0.23752865, 0.21710563) * inp_0_1_1;
    result += M4(-0.008285338, -0.030409923, -0.05599016, -0.020059386, 0.025444644, 0.017813869, -0.014549556, 0.032442063, 0.008388761, -0.08381629, -0.0016093521, 0.013114501, -0.00064698287, -0.028405042, -0.020408977, -0.016582668) * inp_0_2_1;
    result += M4(-0.008751998, -0.004238979, 0.019289756, 0.013751824, 0.04565314, -0.006700068, 0.114347346, 0.037455685, -0.028276209, -0.018014558, -0.03913771, 0.020905875, 0.011642546, 0.02039049, -0.08799903, 0.0021931534) * inp_0_0_2;
    result += M4(-0.015526486, 0.027945712, -0.057486787, -0.026817478, 0.030729393, -0.021491367, -0.044305295, -0.0206159, 0.04009747, 0.03104874, 0.0028349312, 0.022064267, 0.04795331, 0.06314799, 0.024671195, 0.022217797) * inp_0_1_2;
    result += M4(0.014568868, 0.03196688, 0.04672232, 0.0040951646, 0.012573305, -0.0038477893, 0.0051254425, -0.031414345, 0.0015838607, 0.019921517, -0.027218975, -0.048833065, 0.015431581, -0.008320843, -0.031078687, -0.1259068) * inp_0_2_2;
    result += M4(-0.033069875, -0.021300228, -0.0065187686, -0.009949803, -0.0567274, -0.038185213, -0.0933868, -0.025285572, -0.08906452, -0.008913687, -0.054048974, -0.013139342, 0.025590071, -0.024032086, 0.02245896, -0.016094036) * inp_1_0_0;
    result += M4(0.019657329, -0.030300803, 0.0059207818, -0.001200231, 0.024070485, -0.042843927, -0.029716851, -0.03886257, 0.06353145, 0.07128137, -0.010882281, 0.009906614, 0.077983126, 0.04942193, 0.000943964, -0.023301417) * inp_1_1_0;
    result += M4(0.016758818, 0.03857895, -0.015891522, 0.019711053, -0.009489836, 0.060102183, 0.030537996, 0.02148896, 0.0041876133, -0.037326843, -0.014489371, -0.015368507, -0.019683473, -0.09663282, 0.020469455, -0.07441322) * inp_1_2_0;
    result += M4(-0.0033885813, -0.02595995, 0.014750893, -0.0085825855, 0.07623415, -0.00068525225, 0.09127336, 0.023290623, 0.06532816, -0.00177584, -0.023777364, -0.02129528, -0.03090121, 0.002872976, -0.039348, -0.030771766) * inp_1_0_1;
    result += M4(0.04242089, 0.013168192, -0.08543258, -0.046468448, 0.024531702, 0.085784666, 0.026233463, 0.0077083977, 4.6293622e-05, -0.068981916, 0.11853215, -0.0036803645, 0.05425023, 0.05863932, 0.0016000307, 0.05666464) * inp_1_1_1;
    result += M4(-0.029866053, 0.014328901, 0.046047386, 0.07251515, -0.020787843, -0.069439635, -0.018059378, 0.0017427843, -0.019360648, 0.011817072, 0.0017820984, 0.012173173, -0.04293986, 0.026350396, 0.0166443, 0.03911748) * inp_1_2_1;
    result += M4(0.01994314, 0.002834874, 0.06874394, 0.009670533, -0.030618962, 0.0011082786, -0.008449687, -0.023679491, 0.024919068, 0.027556222, 0.11239082, 0.027776906, -0.010388382, 0.008914328, -0.017154321, -0.021868506) * inp_1_0_2;
    result += M4(-0.046012808, 0.026829962, -0.07673378, 0.0061430302, 0.008920284, 0.009520536, 0.0036837757, 0.06804432, -0.011016729, -0.025047997, -0.047789693, 0.0018050775, -0.04513013, -0.018129174, 0.021497717, 0.031453725) * inp_1_1_2;
    result += M4(0.016829599, -0.009190648, 0.024938649, -0.033474695, -0.012181542, -0.00696297, -0.0046235975, -0.04055315, -0.0075506186, 0.024523037, -0.05501264, -0.047036394, -0.015161416, -0.0126573825, -0.016754298, 0.042271733) * inp_1_2_2;
    result += M4(-0.061303444, -0.046612944, -0.004403407, -0.012718834, -0.000651492, -0.019493079, 0.011257026, 0.023540989, -0.051233433, -0.048981097, -0.03545537, -0.006142467, -0.0063429154, 0.01593084, -0.025969254, 0.015219801) * inp_2_0_0;
    result += M4(-0.06697053, -0.018654896, 0.014841177, 0.0671598, -0.035441212, -0.032564454, -0.061039016, -0.0020784, 0.039248556, 0.040309735, -0.0011484621, 0.027644243, 0.07734936, 0.010505864, 0.0021979378, -0.0043682153) * inp_2_1_0;
    result += M4(0.01638558, -0.055754777, 0.0025129714, -0.022927908, -0.022930352, -0.006136692, -0.018699875, -0.035124347, 0.022159461, 0.03497524, 0.019061081, 0.00055171724, 0.023221381, 0.10721273, -0.0149165485, 0.028449617) * inp_2_2_0;
    result += M4(0.030379053, 0.03736345, 0.057160564, 0.010641819, 0.09820827, -0.021856934, 0.08144525, -0.0018581558, -0.0133436555, -0.044186816, -0.00987469, -0.01789185, -0.081915565, 0.027638728, -0.03521642, 0.0012080851) * inp_2_0_1;
    result += M4(0.03651415, -0.12772016, -0.022615822, -0.10011278, 0.13168481, 0.017161032, 0.16832812, 0.0037055954, -0.03170371, 0.12676366, 0.03646424, 0.008009451, 0.09323051, -0.23666604, 0.21892208, -0.05530327) * inp_2_1_1;
    result += M4(0.0401332, 0.08533489, 0.06287609, 0.04467937, -0.09481299, 0.023499826, -0.10140579, 0.064789966, 0.025163535, -0.017415311, -0.034384288, -0.013069719, -0.07789051, 0.019816844, -0.073962204, 0.021214291) * inp_2_2_1;
    result += M4(-0.016319891, -0.015839096, -0.02775838, -0.028307391, 0.0345713, 0.033828873, 0.05172797, 0.012289901, -0.0046355845, 0.0010042293, 0.016374141, -0.008792285, 0.008044106, 0.0139649315, -0.03223371, 0.011939477) * inp_2_0_2;
    result += M4(0.011466738, -0.0026509298, -0.06214844, -0.041826032, -0.0057522613, -0.00040824892, -0.017241675, -0.099167526, 0.022217734, -0.07444041, 0.0057829195, 0.01518003, -0.015362616, 0.015349405, 0.054561935, -0.02060886) * inp_2_1_2;
    result += M4(-0.015469987, -0.009818769, -0.0141615495, -0.023090012, -0.01628779, 0.03432145, -0.04362606, 0.06523379, 0.005847413, -0.015848743, 0.002371985, -0.0069911424, -0.034895245, 0.004314687, -0.039997928, 0.033385854) * inp_2_2_2;
    result += M4(-0.036165323, -0.007041924, -0.012538892, -0.014344905, 0.096525356, 0.02022204, 0.038157824, 0.011500813, -0.043681946, 0.0024758838, -0.030242901, 0.009902446, 0.0013969583, -0.013335812, -0.010550402, -0.0056430525) * inp_3_0_0;
    result += M4(0.04489979, 0.027113046, 0.012969342, -0.011278866, 0.17044413, 0.18902388, 0.11825375, 0.13708735, 0.0037821552, -0.0008746408, -0.014359843, -0.00029987792, 0.074933134, -0.0074290335, 0.015710002, 0.014258211) * inp_3_1_0;
    result += M4(0.00097532466, 0.012448787, 0.004703278, 0.0182591, 0.097864784, 0.15578516, 0.018518329, 0.0053612487, 0.033978965, -0.049391676, -0.028283082, -0.04381307, -0.0058831545, 0.038383484, 0.037524235, 0.03746494) * inp_3_2_0;
    result += M4(-0.093746714, 0.029351206, -0.056497153, 0.0005444776, 0.18207563, 0.0932533, 0.17777275, 0.16558535, 0.04725527, 0.002236607, 0.04360964, -0.018300986, -0.03693455, -0.0063840607, 0.011455245, 0.02954513) * inp_3_0_1;
    result += M4(0.0016974922, -0.014786011, 0.011212849, 0.082628906, 0.14981672, 0.21046248, 0.18583412, 0.18128295, 0.020747501, 0.023275878, -0.0021458624, -0.010139717, 0.074079365, -0.062292613, -0.060126532, -0.07511568) * inp_3_1_1;
    result += M4(-0.021152262, 0.011479562, -0.023757596, 0.010842078, 0.017988432, 0.059102867, 0.07950973, 0.14663899, -0.04628502, 0.05263901, 0.047685158, 0.1034225, -0.052277926, 0.0023470353, 0.0374898, -0.060948946) * inp_3_2_1;
    result += M4(0.01461715, 0.003758344, -0.034800243, -0.018191382, 0.051374592, 0.059109125, 0.115898676, 0.05701599, -0.024852172, -0.02013624, -0.06466161, -0.0026267944, -0.0066716704, -0.020324077, -0.023777297, 0.030430252) * inp_3_0_2;
    result += M4(0.03360078, 0.020691773, 0.015677521, -0.005567045, 0.18286733, 0.14825872, 0.18732561, 0.11175385, 0.0041101365, -0.0090033, 0.023411086, 0.0083955545, -0.026867721, 0.05483253, 0.0018874821, 0.04189366) * inp_3_1_2;
    result += M4(-0.0055411044, 0.0019479878, -0.019279448, -0.017712425, 0.029996783, 0.05428077, 0.05662926, 0.16965425, 0.0006010009, -0.007452191, 0.028911598, -0.04351144, -0.011134252, 0.01681262, -0.017017871, -0.012195508) * inp_3_2_2;
    result += M4(0.034483485, 0.010692717, -0.03650792, -0.0015353455, -0.023796415, 0.048095718, -0.032162603, 0.006914164, 0.015162789, 0.02523689, -0.014931391, 0.033107962, 0.0893379, 0.023694173, 0.024012996, 0.006224947) * inp_4_0_0;
    result += M4(0.027237065, -0.010939726, -0.03436576, 0.013434255, 0.0344536, 0.0032019794, 0.0002947951, 0.047871474, 0.0046123248, 0.015037929, 0.00049911026, -0.018277079, -0.033583663, -0.02444969, 0.017979633, 0.01318391) * inp_4_1_0;
    result += M4(-0.017502328, -0.033693783, -0.01786791, 0.029300803, -0.0003726559, 0.025934843, 0.011428066, 0.019165259, 0.027413676, -0.03720742, 0.029354908, 0.038766604, 0.012583712, -0.055630375, -0.0046680993, -0.048373573) * inp_4_2_0;
    result += M4(-0.007895302, -0.025103815, 0.039923247, -0.005014626, 0.025530318, 0.011537634, 0.020197185, -0.020653887, -0.017074062, 0.013401351, 0.03739193, -0.016889842, -0.0491312, -0.0070437957, 0.0021036135, 0.05542551) * inp_4_0_1;
    result += M4(-0.016293166, -0.020224137, 0.10220098, -0.052386016, -0.08008584, 0.007965962, -0.060614508, -0.0616905, 0.02223504, -0.05592166, -0.15531117, 0.06790909, -0.0645069, 0.03988116, 0.01910745, -0.08621987) * inp_4_1_1;
    result += M4(0.0014731727, 0.05232377, -0.021584615, -0.033138126, 0.0110650025, -0.03368937, 0.029963534, -0.0013585242, -0.06470263, 0.038558397, 0.05210469, -0.085672915, 0.047982607, 0.05563209, 0.030405108, 0.056874227) * inp_4_2_1;
    result += M4(0.0058477637, 0.020386776, -0.018367458, -0.014743663, 0.034198254, 0.001584384, -0.01673711, -0.0049835118, 0.0019004071, 0.009170936, 0.010460252, 0.008635298, 0.027926682, 0.015772954, -0.007222646, -0.0018508091) * inp_4_0_2;
    result += M4(-0.034553707, 0.002406317, -0.01637335, 0.007981146, 0.008640141, -0.027361732, 0.0360824, -0.01516628, 0.034238197, 0.014237742, 0.0818499, -0.030550838, 0.004837471, 0.00078949187, -0.06812332, 0.008188279) * inp_4_1_2;
    result += M4(0.0050553656, -0.0013708374, 0.009891363, 0.05683542, -0.00059057714, -0.0144433575, 0.0041653123, 0.010177811, -0.007177681, -0.026936563, -0.03661886, -0.013446424, -0.029569522, -0.016388359, -0.0139102135, -0.054040726) * inp_4_2_2;
    result += M4(0.07154902, -0.0035142663, -0.0022397072, -0.01370053, -0.02340221, -0.012321922, 0.01261497, -0.007996893, 0.017293941, 0.079222664, 0.06979193, 0.071843855, 0.061344024, 0.055352036, -0.021621829, 0.02449881) * inp_5_0_0;
    result += M4(0.0115780635, -0.022451844, -0.032917812, -0.0013676313, 0.015900588, -0.010899379, -0.017476434, 0.021382041, -0.009986278, -0.07481382, -0.021689424, 0.015004522, -0.023401545, -0.027738947, 0.0007025316, 0.009733803) * inp_5_1_0;
    result += M4(-0.012057948, -0.0027022867, 0.01020842, 0.0035411827, 0.010888136, -0.0027013123, -0.0064119785, 0.0031252766, 0.0032666067, 0.031879034, -0.00040985047, 0.023913015, -0.013626653, -0.027109347, 0.00674447, -0.027580077) * inp_5_2_0;
    result += M4(0.06411331, -0.013562752, -0.058104426, 0.023065697, 0.017339254, 0.006045395, -0.023114558, 0.039894745, 0.053918038, 0.019324234, -0.038261626, 0.019687928, -0.024047378, 0.031340137, -0.00976368, 0.020090738) * inp_5_0_1;
    result += M4(-0.060450576, -0.051953327, 0.01485351, -0.009885225, -0.060130797, 0.0839866, 0.06368008, -0.09528564, -0.07692284, -0.007846886, 0.044162236, -0.10636785, -0.0052158837, -0.0072596096, 0.0066762664, -0.0072892867) * inp_5_1_1;
    result += M4(-0.013472836, 0.07388315, 0.022587176, 0.04693725, -0.024526723, 0.017449029, 0.009889797, -0.01733149, -0.0048503997, -0.037898097, -0.00048300737, -0.021204425, -0.012212735, -0.015767472, -0.025590284, 0.030705083) * inp_5_2_1;
    result += M4(-0.026551586, 0.032488994, 0.026287744, 0.01758824, -0.0055294996, -0.012822946, -0.0006608732, -0.0045656124, -0.010339627, 0.0066284225, 0.0140217785, -0.019795466, 0.0037851518, -0.022613438, 0.06507098, -0.0016448649) * inp_5_0_2;
    result += M4(-0.033454806, 0.002931881, 0.0057532736, -0.02868566, 0.013428234, -0.0008317616, 0.0058062277, 0.017188473, 0.020288283, -0.026829038, -0.07896476, 0.013014098, -0.0052191927, -0.03885012, -0.037226845, -0.021621732) * inp_5_1_2;
    result += M4(0.00035935256, -0.014591379, 0.01625766, -0.038638268, 0.004638637, -0.00434326, -0.0098234005, 0.00055474683, 0.010048366, 0.016685873, 0.006638284, 0.005538103, 0.028960103, 0.03093128, 0.011596754, -0.010172888) * inp_5_2_2;
    result += M4(0.07073951, 0.054179564, 0.041881222, 0.049408622, -0.0026960594, -0.012131778, 0.038560055, 0.013675256, 0.026268328, 0.03176827, 0.010732897, 0.034018353, 0.00085582206, 0.013526423, 0.02101539, 0.00838843) * inp_6_0_0;
    result += M4(0.03851508, 0.07221275, -0.0009976795, -0.009452466, -0.011144624, 0.030711602, 0.001660615, 0.0375269, -0.11128167, -0.08422571, -0.018789433, -0.010027052, 0.059544552, 0.014200705, 0.11338941, 0.10331942) * inp_6_1_0;
    result += M4(-0.0809503, -0.0999018, -0.028335987, -0.06528316, 0.022371907, 0.023568982, -0.012777889, 0.028258402, 0.0104328925, -0.0184964, -0.006274039, -0.0071548005, 0.035809845, 0.061435197, 0.02986943, 0.020500291) * inp_6_2_0;
    result += M4(-0.024496643, -0.024602575, 0.03240869, -0.031253662, -0.016924543, 0.043051068, -0.016789962, 0.02453462, 0.028969849, 0.08179733, 0.030667325, 0.13070992, -0.0068302797, 0.020724904, -0.004906422, 0.03670295) * inp_6_0_1;
    result += M4(0.012566977, -0.020920869, 0.009105579, -0.043079518, -0.0027505928, -0.059201717, 0.0014850668, -0.030546257, -0.22347087, -0.16320504, -0.36785048, -0.32642555, -0.23342781, -0.17829487, -0.11746487, -0.10929649) * inp_6_1_1;
    result += M4(0.010402138, 0.054522593, -0.030450832, 0.115654476, 0.0013587362, -0.07542337, -0.029055273, -0.007718926, -0.13036448, -0.108861834, -0.10166778, -0.08440321, -0.018815855, -0.045792066, -0.03416143, -0.0034775643) * inp_6_2_1;
    result += M4(-0.025385978, -0.006614915, -0.062069103, -0.017118499, 0.016675297, 0.02824821, -0.023830986, -0.008855554, 0.096695766, 0.09217743, 0.087099336, 0.10208863, 0.0004339145, 0.018190783, -4.7568552e-05, -0.0031788177) * inp_6_0_2;
    result += M4(0.009120112, -0.00964094, 0.05602231, 0.05474819, -0.004526478, -0.001159284, 0.02040206, 0.018712059, 0.18200725, 0.16026051, 0.124416746, 0.02781883, -0.021442564, -0.0131293265, -0.015993366, -0.0018760399) * inp_6_1_2;
    result += M4(0.0061082756, -0.011320619, -0.012043556, -0.06903184, 0.015436201, 0.013368524, 0.018495163, -0.08522054, 0.024163635, 0.056511864, -0.008702639, 0.034555115, -0.01820125, -0.028427614, -0.0004017382, -0.0024336139) * inp_6_2_2;
    result += M4(0.02406422, 0.008850736, -0.0040336917, -0.017834459, 0.029106408, 0.010515548, 0.0017782253, 0.007123664, 0.0579898, -0.0004491886, 0.006108635, -0.009491629, 0.007215305, -0.015772413, 0.0049563763, -0.01358519) * inp_7_0_0;
    result += M4(-0.050077196, -0.0877767, -0.014103858, -0.035576567, 0.078482285, 0.08150492, 0.042960938, 0.089516334, 0.026833879, 0.062627114, -0.04640933, -0.04297094, 0.084308736, 0.0066560744, 0.036175046, -0.014317176) * inp_7_1_0;
    result += M4(0.0326727, -0.014104146, -0.011262507, 0.016295604, -0.03284853, -0.012160939, -0.0060559716, -0.005964357, 0.018825525, 0.03541127, -0.011295591, 0.0046733143, 0.01552449, 0.028770588, -0.003924568, 0.03221572) * inp_7_2_0;
    result += M4(0.0056505282, 0.018861143, 0.024530495, -0.022367839, 0.13704729, 0.019812666, 0.07447826, -0.03379103, 0.026504282, -0.0044378, 0.095551655, -0.030713676, -0.015589242, 0.02215109, -0.008316749, 0.018738452) * inp_7_0_1;
    result += M4(-0.044298954, 0.0009678786, 0.037281077, 0.1319151, 0.32161832, 0.41769817, 0.19521464, 0.36779317, -0.25710136, -0.079282254, 0.048788033, 0.25214535, 0.044179246, 0.059477996, -0.040096153, -0.002793336) * inp_7_1_1;
    result += M4(-0.03392292, 0.027277283, 0.020537196, -0.056286383, -0.13069765, 0.016281618, -0.14455627, -0.09395626, 0.0002268927, -0.077031665, -0.0036877187, -0.015804801, -0.06346147, -0.046998646, -0.01345166, -0.06065179) * inp_7_2_1;
    result += M4(0.012766825, 0.013007147, -0.030027306, -0.019284874, -0.094856754, -0.07205098, 0.023138395, -0.035138372, 0.016866434, 0.0073410524, -0.007265036, -0.0037356857, 0.0044795717, 0.0021523552, 0.014826314, 0.013813149) * inp_7_0_2;
    result += M4(0.034667708, -0.009423443, 0.019348526, 0.042988934, -0.19185412, -0.19004583, 0.0074844775, 0.02342701, 0.052801892, 0.023565823, -0.087170504, -0.052786328, -0.01914305, -0.054027084, -0.093627326, -0.037169114) * inp_7_1_2;
    result += M4(0.015810225, 0.038279276, -0.044465072, -0.03653877, -0.15560408, -0.12545009, -0.15969598, -0.09085525, 0.042739257, 0.02520271, 0.015196757, -0.05503811, 0.022435103, 0.007616369, 0.04923656, 0.026990006) * inp_7_2_2;
    FragColor = result;
}
