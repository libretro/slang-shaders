#version 450

// Based on ArtCNN_C4F16.glsl.
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
    ivec2 input_base = base * ivec2(2, 2);
    vec4 inp_0_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, -2));
    vec4 inp_0_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, -2));
    vec4 inp_0_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, -2));
    vec4 inp_0_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, 0));
    vec4 inp_0_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, 0));
    vec4 inp_0_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, 0));
    vec4 inp_0_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, 2));
    vec4 inp_0_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, 2));
    vec4 inp_0_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, 2));
    vec4 inp_1_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, -2));
    vec4 inp_1_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, -2));
    vec4 inp_1_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, -2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, -2));
    vec4 inp_1_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, 0));
    vec4 inp_1_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, 0));
    vec4 inp_1_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, 0)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, 0));
    vec4 inp_1_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, 2));
    vec4 inp_1_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, 2));
    vec4 inp_1_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, 2)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, 2));
    vec4 inp_2_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, -1));
    vec4 inp_2_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, -1));
    vec4 inp_2_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, -1));
    vec4 inp_2_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, 1));
    vec4 inp_2_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, 1));
    vec4 inp_2_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, 1));
    vec4 inp_2_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-2, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-2, 3));
    vec4 inp_2_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(0, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(0, 3));
    vec4 inp_2_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(2, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(2, 3));
    vec4 inp_3_0_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, -1));
    vec4 inp_3_1_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, -1));
    vec4 inp_3_2_0 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, -1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, -1));
    vec4 inp_3_0_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, 1));
    vec4 inp_3_1_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, 1));
    vec4 inp_3_2_1 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, 1)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, 1));
    vec4 inp_3_0_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(-1, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(-1, 3));
    vec4 inp_3_1_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(1, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(1, 3));
    vec4 inp_3_2_2 = artcnn_fetch4(conv2d, params.conv2dSize, input_base + ivec2(3, 3)) + artcnn_fetch4(conv2d_5, params.conv2dSize, input_base + ivec2(3, 3));
    vec4 result = vec4(0.0);
    result = V4(0.08412104, 0.07971554, 0.08434169, 0.076244);
    result += M4(-0.079171985, -0.0069937697, -0.0210708, -0.033105504, -0.023817735, -0.011238646, -0.043035787, -0.02440147, 0.016872514, 0.03719572, -0.0036019788, 0.012509292, 0.1484504, 0.10084735, 0.06727001, 0.09289472) * inp_0_0_0;
    result += M4(-0.090545304, -0.16164127, 0.019691145, 0.045617487, 0.0029133197, -0.011457896, -0.1087185, -0.022287082, 0.007693777, -0.1557534, 0.119432844, 0.048796117, 0.01886607, 0.13466214, 0.055788144, 0.011069647) * inp_0_1_0;
    result += M4(0.019721841, -0.04018983, -0.010603011, -0.041139323, -0.013923174, -0.0069041494, -0.03181753, -0.07459869, -0.032918666, 0.004894833, -0.01307685, 0.038587816, 0.092926815, 0.04549454, 0.06285106, 0.03428836) * inp_0_2_0;
    result += M4(0.1622716, -0.07768257, -0.013204322, 0.026763849, 0.0012736389, -0.09754597, 0.13953719, -0.07492267, 0.016014466, 0.055583894, 0.07073988, 0.007828915, 0.17086188, 0.109315015, 0.16700633, 0.119697236) * inp_0_0_1;
    result += M4(0.079182394, 0.2656691, -0.13238232, -0.17505214, -0.23513712, 0.16317949, -0.18635502, 0.3353578, -0.10498728, 0.011073413, -0.10075553, -0.17032194, 0.19368632, 0.19305302, 0.15070842, 0.23248452) * inp_0_1_1;
    result += M4(-0.002185805, 0.11091493, 0.051263936, 0.041181523, 0.062277913, -0.062091295, 0.03607194, -0.10375673, -0.010489046, -0.01102331, -0.041805126, 0.065893725, 0.15395595, 0.18233144, 0.15172338, 0.21679255) * inp_0_2_1;
    result += M4(-0.030508783, -0.004990037, 0.0329664, 0.010637486, 0.005623188, -0.003358061, 0.0080712475, 0.00046784236, 0.040540207, 0.004353267, 0.0534382, -0.010169058, 0.10396432, 0.025561178, 0.18441953, 0.004519026) * inp_0_0_2;
    result += M4(-0.04412904, -0.07338797, 0.06732339, 0.061310094, 0.08977347, 0.04197968, 0.10037899, -0.03313243, 0.029916203, 0.021829529, -0.08954633, 0.08445129, 0.035676997, 0.06716942, 0.06353302, 0.1767009) * inp_0_1_2;
    result += M4(-0.016475134, -0.01597473, -0.006870764, 0.07254226, 0.052580874, 0.030486876, 0.078329995, 0.02920045, 0.024402283, 0.02916857, 0.008138189, -0.07570842, 0.061067346, 0.12795751, 0.07376389, 0.10487863) * inp_0_2_2;
    result += M4(-0.10219679, -0.0016633151, -0.08416798, -0.06091891, -0.023262773, -0.126822, 0.0497739, -0.001825667, -0.03078599, 0.04718741, 0.0043902365, -0.0053807287, 0.032797694, 0.06849138, -0.02102451, 0.0029395863) * inp_1_0_0;
    result += M4(0.029171623, -0.119060196, -0.15731424, -0.010288389, 0.044039175, 0.03523954, 0.19108313, 0.0034680488, 0.022408625, -0.100109026, 0.013178398, 0.021233274, 0.02033905, -0.1076448, 0.05507044, 0.042807907) * inp_1_1_0;
    result += M4(-0.058946244, 0.07518282, -0.0218126, -0.008712151, -0.076766334, 0.05434428, -0.022394644, 0.11280125, -0.07020608, 0.064211406, -0.01466337, 0.04543824, 0.04098286, -0.05094307, 0.017451143, -0.015480388) * inp_1_2_0;
    result += M4(-0.050165318, -0.11767163, 0.037600912, -0.0783747, -0.04539349, -0.031150874, -0.08755638, -0.14933577, 0.07179043, -0.00836788, -0.08889254, 0.024585087, -0.08558388, 0.006760057, 0.05268061, 0.03279828) * inp_1_0_1;
    result += M4(0.194146, 0.026081745, 0.22553095, 0.055226117, 0.09558362, 0.056916, -0.14006428, 0.009533805, -0.048172764, 0.06694457, 0.016996864, 0.010374402, 0.1303292, -0.0043800916, -0.06218835, 0.15707439) * inp_1_1_1;
    result += M4(0.035268318, 0.11117023, -0.0024920474, 0.053387403, 0.0001125205, 0.03284727, -0.041436322, -0.11381764, 0.036874335, -0.05483726, 0.01669829, 0.047346413, 0.01582249, 0.024571301, 0.03841291, 0.0001531784) * inp_1_2_1;
    result += M4(-0.039766025, -0.013582949, -0.047067195, 0.019274479, -0.0064281444, -0.028889643, -0.03691507, -0.025142971, -0.009235927, -0.014399523, 0.0068894643, 0.018320393, -0.009533652, 0.0047507705, -0.051280286, -0.006059686) * inp_1_0_2;
    result += M4(-0.008069688, 0.06869032, 0.06720618, -0.039600242, 0.01939327, -0.04401731, 0.16278408, 0.050619956, -0.011940157, -9.242871e-06, -0.005613433, -0.06478905, -0.04764991, -0.00894034, -0.023979772, -0.14476714) * inp_1_1_2;
    result += M4(0.034411438, -0.023818584, 0.036871288, 0.0619627, -0.02687395, -0.024658777, -0.009806786, 0.098166026, 0.04545056, -0.0035166715, 0.04391233, -0.09520481, -0.022824388, -0.02932159, -0.019960575, -0.013126476) * inp_1_2_2;
    result += M4(0.042513143, 0.036193915, 0.009267334, 0.02318279, -0.08882127, -0.06790481, -0.025598435, -0.055786755, 0.003923015, 0.08367141, -0.02124261, -0.0036895827, 0.0665154, -0.061491456, -0.010962831, 0.016966973) * inp_2_0_0;
    result += M4(-0.08984092, 0.014150137, 0.0010094845, -0.0013944331, -0.05288092, 0.014116327, 0.035593804, 0.020797336, 0.04860784, -0.100140445, 0.043347888, 0.03942333, -0.06728835, 0.14273663, 0.026525293, -0.07449118) * inp_2_1_0;
    result += M4(0.037428003, -0.08130763, -0.010963262, -0.066873446, 0.05335851, 0.13654499, 0.032492008, 0.045801986, 0.009653935, 0.021689994, 0.025831793, 0.03277937, -0.025519112, 0.043301772, -0.0030657381, 0.046498533) * inp_2_2_0;
    result += M4(0.0417986, 0.08424531, 0.04000319, 0.09104747, -0.16142552, -0.021476395, -0.19967215, -0.037973598, -0.048555277, 0.032703213, -0.033633802, 0.10496307, 0.057205033, -0.055697214, 0.097497426, -0.08111985) * inp_2_0_1;
    result += M4(-0.061038256, -0.24523515, -0.3324259, -0.2994336, -0.41386676, -0.3934725, -0.2869577, -0.27902487, -0.053344678, -0.14278612, -0.15018024, -0.20823519, -0.034474645, -0.116564386, -0.0512445, 0.043638732) * inp_2_1_1;
    result += M4(-0.11793706, -0.024524925, -0.07900098, -0.06977263, 0.4436866, 0.095661, 0.44399175, 0.16541167, 0.017248677, 0.017089522, 0.0531066, 0.044330012, 0.0172881, 0.015262031, 0.06628099, 0.11591024) * inp_2_2_1;
    result += M4(0.034315176, 0.012758982, 0.098702334, 0.017511975, -0.06429503, 0.010301114, -0.1138796, 0.018430594, -0.011578993, 0.0050334428, 0.022777617, 0.036444314, -0.021219404, 0.022264466, -0.036809668, -0.015400894) * inp_2_0_2;
    result += M4(0.018624214, -0.04151733, 0.14313662, 0.023933941, 0.12591304, 0.046684355, -0.065231994, -0.067107506, 0.017609427, 0.10223146, 0.07743975, -0.12169869, 0.009158939, -0.025597682, -0.08834877, -0.079456866) * inp_2_1_2;
    result += M4(-0.0021108948, 0.014920775, 0.00642783, -0.022019196, 0.12250748, 0.1506987, 0.16710696, 0.15760566, -0.01257941, 0.0050026863, -0.00019434035, 0.066300645, -0.00047425524, 0.03707401, 0.001639517, 0.026377758) * inp_2_2_2;
    result += M4(-0.03845043, 0.008121379, -0.04463431, -0.021435143, -0.0154112475, 0.008068699, 0.005275401, -0.008412226, 0.011113799, -0.0042059543, 0.021885974, 0.0046847453, -0.097053245, -0.07207643, -0.016230254, -0.057805564) * inp_3_0_0;
    result += M4(0.020068355, -0.059013963, 0.042093556, 0.007965266, 0.006641936, 0.0053823865, -0.04869122, -0.023604743, -0.05277748, -0.08194451, -0.059982788, -0.052345853, -0.033831976, -0.07052958, 0.027305871, 0.022747202) * inp_3_1_0;
    result += M4(-0.03663662, 0.027668301, -0.005128969, 0.04180462, -0.07902732, 0.07694945, -0.037715025, 0.025260974, 0.017048629, 0.05412875, 0.029637456, 0.04848225, -0.055232473, -0.090560995, -0.052049804, -0.053691596) * inp_3_2_0;
    result += M4(-0.041993283, -0.06591007, 0.06993194, -0.014823973, -0.029537756, 0.02038244, -0.05351582, 0.07256843, 0.01772454, -0.04179623, 0.019432299, 0.023107331, -0.03684704, 0.012458426, -0.06536513, 0.03873883) * inp_3_0_1;
    result += M4(0.19751841, 0.2748706, -0.24543872, -0.079816476, 0.11848018, -0.26794544, 0.11034708, -0.16498065, -0.51390487, -0.41391793, -0.39137235, -0.3589357, 0.37141094, 0.3205968, 0.35281453, 0.25800362) * inp_3_1_1;
    result += M4(0.03477724, 0.005542787, 0.0653558, -0.0044532754, -0.06219415, 0.13614522, -0.113096826, 0.04641227, 0.047544006, -0.011667869, 0.0035703634, 0.006406095, -0.10998655, -0.14912339, -0.102509305, -0.1656886) * inp_3_2_1;
    result += M4(-0.015407814, -0.016495913, -0.036472354, -0.009568684, -0.0074188295, 0.021021923, 0.011698857, 0.019404247, 0.09597954, 0.059281915, 0.2022051, 0.05709749, -0.034792032, 0.014734844, -0.041519232, 0.02060852) * inp_3_0_2;
    result += M4(-0.026737554, -0.05625069, 0.069094196, 0.013394634, 0.06341689, -0.005378102, 0.101725005, -0.05227663, 0.18010192, 0.17765583, 0.042139824, 0.15793523, 0.14893357, 0.057833694, 0.09549699, -0.004848631) * inp_3_1_2;
    result += M4(-0.015824724, -0.022639401, -0.011159335, -0.0022217152, 0.0025551994, 0.0073573054, 0.011508081, 0.09528377, 0.09761966, 0.17366165, 0.11282759, 0.1593583, -0.014511227, -0.007068555, -0.021812135, -0.03897337) * inp_3_2_2;
    FragColor = result;
}
