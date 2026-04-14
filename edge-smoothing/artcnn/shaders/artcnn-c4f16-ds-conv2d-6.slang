#version 450

// Based on ArtCNN_C4F16_DS.glsl.
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
    result = V4(0.07464532, 0.07390118, 0.07932574, 0.07740004);
    result += M4(-0.107434526, -0.061474796, -0.040092945, -0.0459723, 0.02761501, 0.01745644, 0.014482912, 0.0012696184, -0.061499584, -0.032264862, -0.048902947, -0.021928083, 0.14782473, 0.1002026, 0.073698446, 0.08206034) * inp_0_0_0;
    result += M4(-0.21699734, -0.28028283, -0.035895456, -0.021996958, 0.015112384, 0.032103192, -0.0639872, 0.020970946, -0.196755, -0.28698945, 8.651186e-05, -0.016814556, 0.024635803, 0.12802911, 0.057709377, 0.009329917) * inp_0_1_0;
    result += M4(-0.02673682, -0.07315494, -0.022984, -0.067974426, -0.1403615, -0.13398142, -0.11284074, -0.14634001, -0.07184698, 0.0023350518, -0.055745855, 0.028456453, 0.08811762, 0.046707124, 0.058221996, 0.033369727) * inp_0_2_0;
    result += M4(0.22360633, -0.023897279, 0.02986799, 0.055481493, 0.046479363, -0.03696558, 0.2653081, 0.022556303, 0.029489953, 0.0171766, 0.11842895, -0.01765957, 0.16629258, 0.11176335, 0.15456629, 0.111050345) * inp_0_0_1;
    result += M4(0.09095651, 0.28040722, -0.064491756, -0.11531522, -0.22851443, 0.13162698, -0.19715798, 0.3505701, -0.08218627, 0.10475915, -0.025233084, -0.028647343, 0.19340141, 0.19143164, 0.14294787, 0.22350201) * inp_0_1_1;
    result += M4(0.016548377, 0.11346367, 0.055276267, 0.04460949, 0.04593663, -0.088350855, 0.03431234, -0.13139, 0.028174222, 0.0011747417, 0.007646534, 0.15010545, 0.15213431, 0.17651626, 0.14111905, 0.21193625) * inp_0_2_1;
    result += M4(-0.0074117705, 0.008487716, 0.037963413, 0.024158146, -0.021835687, -0.01533567, -0.062308576, -0.023030387, 0.0599024, 0.025585424, 0.0949247, 0.048458036, 0.098259225, 0.034685653, 0.17735419, 0.008515868) * inp_0_0_2;
    result += M4(-0.041114856, -0.070740454, 0.122555494, 0.086333975, 0.017477524, -0.010050296, 0.035781797, -0.080852926, 0.041086763, 0.027439564, -0.11653388, 0.07662215, 0.043302838, 0.06700814, 0.06754964, 0.17169318) * inp_0_1_2;
    result += M4(-0.017194813, -0.011334355, -0.014161258, 0.066991776, 0.08990405, 0.069721244, 0.10751855, 0.010132857, -0.0051579652, 0.00568024, -0.02566956, -0.11493607, 0.062435575, 0.11594131, 0.07325794, 0.10697202) * inp_0_2_2;
    result += M4(-0.083234064, -0.01736622, -0.036758095, -0.04624929, -0.07172715, -0.119262755, -0.0222609, -0.026985189, -0.026658798, 0.036979225, 0.03812808, 0.0029649562, 0.08972136, 0.11921047, 0.03170066, 0.036108654) * inp_1_0_0;
    result += M4(0.022280466, -0.15311444, -0.15682934, -0.05723694, 0.24173974, 0.27569678, 0.2574501, 0.15145889, 0.058440883, -0.055165514, 0.04120775, 0.05850623, -0.0373792, -0.14673825, 0.0058482066, 0.014320311) * inp_1_1_0;
    result += M4(-0.09235279, 0.025638962, -0.04072422, -0.034978464, 0.0373231, 0.17699297, 0.05004326, 0.19857855, -0.026124245, 0.090998806, -0.006861609, 0.06986869, 0.003798819, -0.085976705, 0.0034036732, -0.037157945) * inp_1_2_0;
    result += M4(0.0063244975, -0.06491175, 0.093155615, -0.027621726, -0.27442387, -0.1863451, -0.29814664, -0.29802597, 0.1179918, 0.02857419, -0.02652872, 0.07792494, -0.0051430045, 0.08910532, 0.15716837, 0.13776807) * inp_1_0_1;
    result += M4(0.19929896, 0.020554777, 0.22380742, 0.04840272, 0.12036366, 0.12263616, -0.14700954, 0.04919207, -0.082653165, 0.0010076371, -0.080292076, -0.105691075, 0.1047072, -0.14630923, -0.137801, -0.010218593) * inp_1_1_1;
    result += M4(0.062929705, 0.13665918, 0.016087245, 0.06565361, -0.041692965, 0.011779583, -0.07814502, -0.11809729, 0.012785327, -0.11189223, 0.01410198, 0.03994371, 0.033155203, 0.05410498, 0.020141244, -0.040550947) * inp_1_2_1;
    result += M4(-0.012242995, -0.0067502, -0.04036773, 0.023715463, -0.12033609, -0.07752748, -0.19127072, -0.09910811, 0.001066824, -0.00021270462, -0.029544279, -0.004624266, -0.026621554, -0.0022408469, -0.054897767, -0.012781671) * inp_1_0_2;
    result += M4(0.0052375845, 0.06512375, 0.09097809, -0.03978876, 0.0018423167, -0.040242784, 0.17026952, 0.07727061, -0.03142935, -0.001241966, 0.020182231, -0.07429692, -0.021974515, -0.01685353, -0.04211016, -0.15381584) * inp_1_1_2;
    result += M4(0.026886392, -0.0138538405, 0.044098742, 0.03426663, 0.0031622655, -0.0036655362, 0.03818804, 0.11073062, 0.0492121, 0.0004361181, 0.047706895, -0.13048817, -0.0010547969, -0.009558771, 0.015013705, 0.048843324) * inp_1_2_2;
    result += M4(0.021643935, 0.035881847, 0.016666686, 0.036577456, -0.1662777, -0.09977182, -0.03908879, -0.040154546, 0.02468217, 0.08562714, 0.003477804, 0.013376654, 0.15883322, -0.0008079863, 0.0038057019, 0.025690475) * inp_2_0_0;
    result += M4(-0.15558125, -0.053722274, -0.007429018, -0.034054186, -0.17369546, -0.10761962, 0.0035728202, 0.0065433285, 0.0035669033, -0.15924114, -0.012128298, -0.009583443, -0.17912212, 0.06641109, -0.07176044, -0.13502866) * inp_2_1_0;
    result += M4(-0.024374478, -0.11947236, -0.042391077, -0.09398808, -0.0020263772, 0.008831307, -0.022480149, -0.007933876, 0.057767935, 0.0631978, 0.062013224, 0.051570114, 0.00020819916, 0.05376932, 0.012365956, 0.043214906) * inp_2_2_0;
    result += M4(0.021821465, 0.061372053, 0.030329496, 0.073883995, -0.24928251, -0.09148485, -0.33853588, -0.111346275, 0.037134554, 0.10227044, 0.050301112, 0.15772362, 0.13018247, 0.024757927, 0.1436202, -0.027260313) * inp_2_0_1;
    result += M4(-0.056964792, -0.22059062, -0.31152007, -0.25050268, -0.3495639, -0.3077987, -0.167267, -0.13496529, 0.031248473, -0.1437078, -0.07952797, -0.26769456, -0.007219653, -0.124543585, -0.006938436, 0.07118011) * inp_2_1_1;
    result += M4(-0.11743163, -0.03421903, -0.06631086, -0.042185992, 0.3704885, 0.0001417263, 0.38115436, 0.08162762, -0.09297784, -0.12730032, -0.05578877, -0.12742087, -0.047140025, -0.05407684, -0.00036818674, 0.034250893) * inp_2_2_1;
    result += M4(0.030308314, 0.014844215, 0.07084848, 0.010995604, -0.10634963, -0.03476981, -0.15406945, -0.012248272, 0.018516662, 0.018256461, 0.030250294, 0.05309553, -0.012794727, 0.0031848373, 0.006447016, 0.001344918) * inp_2_0_2;
    result += M4(-0.014160697, -0.03532994, 0.13144474, -0.00026352296, 0.04772014, 0.0071790908, -0.14690927, -0.13488056, 0.017247368, 0.075154245, 0.07095803, -0.11632203, -0.0047745123, -0.05720327, -0.020320535, -0.063812315) * inp_2_1_2;
    result += M4(0.010836789, 0.03654803, 0.0137605835, -0.008241026, 0.10062013, 0.120556265, 0.12962195, 0.07804546, 0.017024945, 0.026084676, -0.004509266, 0.07278677, -0.00497006, 0.040066175, -0.005818619, 0.06232713) * inp_2_2_2;
    result += M4(-0.056638226, -0.014636025, -0.039229833, -0.023937698, 0.0071998225, 0.006270476, 0.03453649, 0.008485455, 0.023115309, 0.016761675, 0.018807046, 0.008262102, -0.112472914, -0.08804051, -0.053496294, -0.059561256) * inp_3_0_0;
    result += M4(-0.048097163, -0.083740085, -0.007153653, -0.005329671, 0.025819454, 0.035302766, -0.0507558, -0.020351013, -0.018624973, -0.046828322, -0.045398995, -0.03204218, -0.07163138, -0.0895047, 0.01680595, 0.010678103) * inp_3_1_0;
    result += M4(0.026189093, 0.06621076, 0.018487725, 0.058483873, -0.16239485, 0.027597856, -0.081655666, -0.02271519, 0.03473658, 0.0637648, 0.033509936, 0.048784237, -0.0879195, -0.08722275, -0.052239154, -0.052761104) * inp_3_2_0;
    result += M4(-0.05702285, -0.07530138, 0.050887365, -0.028957656, -0.039279997, 0.023512175, -0.07892729, 0.0539064, 0.049006574, -0.036440436, 0.016188024, 0.026841642, -0.061047584, -0.0049187806, -0.098480225, 0.030135173) * inp_3_0_1;
    result += M4(0.245567, 0.30136076, -0.2306623, -0.06080821, 0.1491032, -0.2811624, 0.17079736, -0.13631457, -0.47227255, -0.36797953, -0.39324626, -0.35655284, 0.34119692, 0.30852947, 0.3328005, 0.2677234) * inp_3_1_1;
    result += M4(-0.00081570714, -0.025666406, 0.036232222, -0.044221822, -0.035065267, 0.19009437, -0.115261525, 0.09050988, 0.00850944, -0.03743462, -0.021475121, -0.03522739, -0.09951341, -0.10976146, -0.09866085, -0.12479215) * inp_3_2_1;
    result += M4(-0.035695568, -0.019111354, -0.059491113, -0.022139635, -0.010610637, 0.010300241, 0.015860146, 0.0015580617, 0.12600164, 0.055962678, 0.19334456, 0.051249225, -0.02728514, 0.0072604646, -0.04802921, 0.011995982) * inp_3_0_2;
    result += M4(0.011924981, -0.015144949, 0.14138313, 0.078566924, 0.017163014, -0.02807699, 0.0028008996, -0.120849, 0.16702725, 0.17699935, -0.05710145, 0.055325154, 0.1390905, 0.05821379, 0.09878961, -0.0071945614) * inp_3_1_2;
    result += M4(-0.030453999, -0.025468823, -0.027789716, -0.013781253, 0.018489737, 0.034405146, 0.06269092, 0.15312864, 0.10282099, 0.15343723, 0.09713119, 0.1130147, -0.020805998, 0.007987905, -0.035749104, -0.03274916) * inp_3_2_2;
    FragColor = result;
}
