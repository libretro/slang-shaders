#version 450

// Based on ArtCNN_C4F16_DN.glsl.
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
    result = V4(0.07271819, 0.07408561, 0.07958637, 0.07517085);
    result += M4(-0.11052887, -0.07697451, -0.006262107, -0.008855362, -0.003626129, -0.014807857, -0.0031811814, -0.008162876, -0.0035636881, 0.01288355, -0.0025423856, 0.010605611, 0.14204222, 0.10337986, 0.07260029, 0.07481801) * inp_0_0_0;
    result += M4(-0.22344403, -0.27549806, -0.0054420936, 0.01298951, -0.006403426, 0.012560562, -0.06436685, -0.0015406028, -0.075257435, -0.18355387, 0.066717714, 0.027680533, 0.023645515, 0.13078682, 0.061577693, 0.014555285) * inp_0_1_0;
    result += M4(-0.010880208, -0.05555989, -0.0016314732, -0.009418431, -0.0637804, -0.07077896, -0.04127708, -0.07141868, -0.06028899, 0.013831819, -0.018538343, 0.05493195, 0.08652545, 0.0462384, 0.059484288, 0.042846415) * inp_0_2_0;
    result += M4(0.19552194, -0.009633629, 0.0184625, -0.012037606, 0.07602969, -0.069619924, 0.1593734, -0.05729545, 0.018906403, 0.04209646, 0.07573993, 0.029780095, 0.17108138, 0.111199856, 0.15905194, 0.110970214) * inp_0_0_1;
    result += M4(0.05016589, 0.2279535, -0.121738926, -0.13402493, -0.24290715, 0.14992028, -0.1408541, 0.32835025, -0.16157764, -0.018112838, -0.13210484, -0.10627683, 0.19480368, 0.18954037, 0.14365369, 0.22168672) * inp_0_1_1;
    result += M4(0.019234665, 0.10734386, 0.06970447, 0.05047115, 0.016147712, -0.11809574, 0.026651476, -0.12163402, 0.0027371563, -0.040244758, -0.025878316, 0.074350275, 0.14819853, 0.17685336, 0.1396654, 0.21519417) * inp_0_2_1;
    result += M4(-0.0021193644, 0.015825957, 0.0094249, -0.0020462363, 0.0015233255, 0.0026083353, -0.013203229, -0.009530751, 0.045554053, 0.021221293, 0.056164518, 0.0438064, 0.10312659, 0.028968854, 0.1811472, 0.012346328) * inp_0_0_2;
    result += M4(0.006628667, -0.017926425, 0.12260225, 0.07392818, 0.067719795, 0.028340915, 0.08378757, -0.023936274, 0.022562867, 0.023725968, -0.13231404, 0.040477663, 0.043604765, 0.06736832, 0.067457795, 0.16776384) * inp_0_1_2;
    result += M4(-0.0051788255, 0.0041696993, -0.012309292, 0.053527154, 0.058346972, 0.065110356, 0.064430885, 0.011086612, 0.010099725, 0.01896994, -0.013210603, -0.08213418, 0.059180517, 0.114863895, 0.06993585, 0.10959468) * inp_0_2_2;
    result += M4(-0.11064285, -0.046025235, -0.05533973, -0.052432343, -0.0014481689, -0.048249394, -0.036527276, -0.028274043, -0.060719475, -0.0015808593, -0.0003527875, -0.0040547615, 0.034501992, 0.057392165, 0.011225125, 0.007050131) * inp_1_0_0;
    result += M4(0.02653982, -0.17030618, -0.12056442, -0.025082339, 0.17117025, 0.16521132, 0.11793986, 0.0072816517, 0.10802516, -0.041749265, 0.018026298, 0.009324859, 0.03031558, -0.050473776, 0.021880977, 0.0068390947) * inp_1_1_0;
    result += M4(-0.07158384, 0.049813397, -0.032333646, -0.026022488, -1.7584209e-05, 0.12895854, -0.006877865, 0.10035208, -0.04955792, 0.06555474, -0.016377443, 0.035125718, 0.010668563, -0.023090232, 0.007869214, -0.0094331205) * inp_1_2_0;
    result += M4(0.00067774905, -0.10407797, 0.055904485, -0.047745354, -0.1890952, -0.06710201, -0.20372243, -0.14966783, 0.13191131, 0.010246681, -0.01815384, 0.011779004, -0.017254144, 0.013290562, 0.10028235, 0.048043754) * inp_1_0_1;
    result += M4(0.19216534, 0.06417686, 0.22366552, 0.036800906, 0.09332922, 0.11766825, -0.11517164, -0.04274507, -0.041144982, 0.035578478, -0.025101721, -0.045496177, 0.12836005, -0.013541115, -0.016936697, 0.11902651) * inp_1_1_1;
    result += M4(0.03914219, 0.12133629, 0.007049254, 0.06718766, -0.025751773, -0.026819643, -0.050741676, -0.13672985, 0.018762344, -0.07456111, -0.017892253, 0.025676029, 0.020884115, 0.030332875, 0.013759702, -0.022487322) * inp_1_2_1;
    result += M4(-0.031400107, -0.00758405, -0.06486476, -0.012059706, -0.06977188, -0.041464116, -0.07648823, -0.0028541824, 0.008078981, 0.0010211513, 0.0076195626, -0.030062709, -0.030346613, -0.018186508, -0.060373902, -0.034212597) * inp_1_0_2;
    result += M4(0.023702748, 0.07458331, 0.07968132, 0.0014261048, 0.0112605775, -0.02659619, 0.1424807, 0.084615074, -0.017425252, 0.004562479, 0.0390508, -0.062455457, -0.0780076, -0.053377103, -0.06846882, -0.1426072) * inp_1_1_2;
    result += M4(0.020173749, -0.0129420385, 0.01681474, 0.039360076, -0.005459472, -0.017207736, 0.01362342, 0.07577378, 0.034591917, 0.0037711556, 0.033172652, -0.073326394, -0.0077665304, -0.031631965, 0.0033790749, -0.006301254) * inp_1_2_2;
    result += M4(0.013083165, 0.034154475, 0.025614286, 0.03139089, -0.1413365, -0.082499556, -0.043219004, -0.04719983, 0.029777477, 0.061117973, 0.0047203363, 0.0022017923, 0.12330046, -0.0048554074, 0.0075573656, 0.004187335) * inp_2_0_0;
    result += M4(-0.1602344, -0.05905934, 0.028250353, 0.013459905, -0.17247726, -0.083132066, 0.03193639, 0.016519472, 0.023434801, -0.06390237, 0.02209028, -0.00053547224, -0.12736855, 0.06542147, 0.020078529, -0.023709863) * inp_2_1_0;
    result += M4(-0.012959428, -0.12338614, -0.00810836, -0.026653918, 0.04978496, 0.0748422, 0.0336254, 0.0485389, 0.03398226, 0.035850268, 0.028866226, 0.027670028, -0.00587918, 0.07028672, -0.0010275246, 0.0722516) * inp_2_2_0;
    result += M4(0.027973281, 0.07572117, 0.006771348, 0.08127684, -0.22449759, -0.023798523, -0.28257576, -0.051694185, -0.028261956, 0.013541968, 0.060502384, 0.10552989, 0.033905968, -0.031837028, 0.07281349, -0.071909115) * inp_2_0_1;
    result += M4(-0.08009671, -0.21595009, -0.28178242, -0.26800653, -0.44602138, -0.3758408, -0.23921145, -0.21635108, 0.0071607353, -0.20857185, -0.18601577, -0.21349259, -0.015367647, -0.08957724, -0.014101079, 0.026888022) * inp_2_1_1;
    result += M4(-0.12394569, -0.05230506, -0.06969546, -0.06226867, 0.37334234, 0.046758395, 0.38907847, 0.059717365, 0.018366504, 0.0028442962, 0.033769175, -0.006013132, 0.01707536, 0.006596491, 0.05326109, 0.07743139) * inp_2_2_1;
    result += M4(0.034684036, 0.00754263, 0.089671604, 0.024472205, -0.07107379, -0.019766891, -0.13100386, 0.022800472, 0.0005258315, -0.0037487745, 0.019303946, 0.006672416, -0.017788958, 0.0046294746, -0.052216258, -0.009869868) * inp_2_0_2;
    result += M4(0.016474392, -0.03568857, 0.12841606, 0.0045111165, 0.06310754, 0.029309828, -0.13135292, -0.118457764, 0.012217446, 0.06634226, 0.03782437, -0.099642165, -0.01644281, -0.044345483, -0.060020033, -0.065026216) * inp_2_1_2;
    result += M4(0.00071679585, 0.044558905, -0.012215743, 0.0027069089, 0.108876586, 0.121081196, 0.12522358, 0.077328525, 0.010120945, -0.0018939214, 0.02202548, 0.055934835, 0.0004609579, 0.023280632, -0.012411851, 0.00853768) * inp_2_2_2;
    result += M4(-0.044885118, -0.0043905643, -0.031385314, -0.01542357, -0.013951076, 0.019043041, 0.009709691, -0.0017127702, 0.019437317, 0.012032936, 0.016434522, 0.0047549233, -0.10754678, -0.055641238, -0.039444465, -0.04248104) * inp_3_0_0;
    result += M4(0.00037009746, -0.052082922, 0.036785655, 0.019489769, 0.038895205, -0.00095879706, -0.0045939577, 0.0018091998, -0.028269527, -0.064318754, -0.072977915, -0.04789887, -0.070526175, -0.091885485, 0.019623667, 0.02267402) * inp_3_1_0;
    result += M4(0.013514295, 0.050747994, 0.00783876, 0.028317524, -0.102624774, 0.019744175, -0.037904106, 0.02806474, 0.03270408, 0.05844836, 0.027982773, 0.027863946, -0.07076939, -0.0903884, -0.04131429, -0.028999286) * inp_3_2_0;
    result += M4(-0.018297665, -0.059446804, 0.06000978, 4.2880365e-05, -0.056170322, 0.030379962, -0.07320575, 0.07109784, 0.024477813, -0.040817976, 0.014381656, 0.01748121, -0.04967369, 0.0013691587, -0.08493897, 0.025795482) * inp_3_0_1;
    result += M4(0.13520333, 0.25901404, -0.22616078, -0.04321116, 0.09231137, -0.20430428, 0.13897236, -0.16301434, -0.47063208, -0.38243693, -0.40296456, -0.35352623, 0.32733408, 0.32106978, 0.3462488, 0.24352162) * inp_3_1_1;
    result += M4(0.025929468, -0.012797406, 0.039035384, -0.058699243, -0.04971871, 0.118507594, -0.09156245, 0.064601004, 0.022143906, -0.03970071, -0.0072154184, -0.023678243, -0.11779652, -0.121469386, -0.10123547, -0.13811521) * inp_3_2_1;
    result += M4(-0.048197895, -0.018932771, -0.07062681, -0.01378064, 0.00356286, 0.0084597515, 0.0234383, 0.0011797515, 0.12672411, 0.063356735, 0.16087574, 0.0074442565, -0.023697801, 0.014501549, -0.052783508, 0.009866516) * inp_3_0_2;
    result += M4(-0.0007714689, -0.034123003, 0.1099913, 0.0427165, 0.036767494, 0.0040027383, -0.0015076951, -0.09645526, 0.18582019, 0.20294748, -0.03859839, 0.07184512, 0.1416856, 0.055417456, 0.08189293, -0.027125463) * inp_3_1_2;
    result += M4(-0.03168433, -0.032534044, -0.027452188, -5.8044236e-05, 0.017230647, 0.03138485, 0.023622097, 0.08155887, 0.109860465, 0.17336306, 0.09693941, 0.13778093, -0.02176953, 0.006647579, -0.046749473, -0.028793886) * inp_3_2_2;
    FragColor = result;
}
