
#define kMaxNitsFor2084     10000.0f

const mat3 k709_to_2020 = mat3 (
//   0.6274040f, 0.3292820f, 0.0433136f,
//   0.0690970f, 0.9195400f, 0.0113612f,
//   0.0163916f, 0.0880132f, 0.8955950f);
   
   0.627403895934699f, 0.329283038377884f, 0.043313065687417f,
   0.069097289358232f, 0.919540395075458f, 0.011362315566309f,
   0.016391438875150f, 0.088013307877226f, 0.895595253247624f);

/* START Converted from (Copyright (c) Microsoft Corporation - Licensed under the MIT License.)  https://github.com/microsoft/Xbox-ATG-Samples/tree/master/Kits/ATGTK/HDR */
const mat3 kExpanded709_to_2020 = mat3 (
    0.6274040f,  0.3292820f, 0.0433136f,
    0.0457456f,  0.941777f,  0.0124772f,
   -0.00121055f, 0.0176041f, 0.983607f);

//NTSC (1953)/ITU-R BT.470 - 525
 const mat3 kNTSC1953_to_2020 = mat3 (
//   0.924130283352921f, 0.058040878058827f, 0.017828838588251f,
//   0.081832452209371f, 0.839996416103710f, 0.078171131686919f,
//   -0.003138728266940f, 0.033216715568834f, 0.969922012698106f);

   0.906538f, 0.074810f, 0.018652f,
   0.076155f, 0.860656f, 0.063189f,
   -0.002015f, 0.041546f, 0.960469f);

//NTSC (1987)/SMPTE 240M/SMPTE C
 const mat3 k601_to_2020 = mat3 (
   0.595254206376441f, 0.349313919749775f, 0.055431873873783f,
   0.081243661805292f, 0.891503295602217f, 0.027253042592490f,
   0.015512341244385f, 0.081911642143068f, 0.902576016612547f);

//Pal/Secam/ITU-R BT.470 - 625
 const mat3 kPAL_to_2020 = mat3 (
   0.655036776701967f, 0.302160964978908f, 0.042802258319126f,
   0.072140555698383f, 0.916631128820964f, 0.011228315480653f,
   0.017113370439452f, 0.097853469923833f, 0.885033159636715f);

//EBU Tech. 3213-E
 const mat3 k3213E_to_2020 = mat3 (
   0.656656353779129f, 0.300719063748279f, 0.042624582472592f,
   0.072525428085101f, 0.916271070705580f, 0.011203501209319f,
   0.017188500243598f, 0.097872586557247f, 0.884938913199155f);

//ITU-R BT.709
 const mat3 kalt709_to_2020 = mat3 (
   0.627403895934699f, 0.329283038377884f, 0.043313065687417f,
   0.069097289358232f, 0.919540395075458f, 0.011362315566309f,
   0.016391438875150f, 0.088013307877226f, 0.895595253247624f);

//DCI-P3
 const mat3 kaDCIP3_to_2020 = mat3 (
   0.707334754484899f, 0.247569002167623f, 0.045096243347478f,
   0.036801714143967f, 0.965390705258538f, -0.002192419402504f,
   0.000222194187031f, 0.029426016456367f, 0.970351789356603f);

//Display P3/P3-D65
 const mat3 kaDisplayP3_to_2020 = mat3 (
   0.753833034361721f, 0.198597369052617f, 0.047569596585662f,
   0.045743848965358f, 0.941777219811693f, 0.012478931222948f,
   -0.001210340354518f, 0.017601717301090f, 0.983608623053428f);

//sRGB
 const mat3 ksRGB_to_2020 = mat3 (
   0.627441372057978f, 0.329297459521909f, 0.043351458394495f,
   0.069027617147078f, 0.919580666887028f, 0.011361422575401f,
   0.016364235071681f, 0.088017162471727f, 0.895564972725983f);

//Adobe RGB (1998)
 const mat3 kAdobeRGB1998_to_2020 = mat3 (
   0.877337599133789f, 0.077497709099687f, 0.045174670424343f,
   0.096613889523141f, 0.891520398792844f, 0.011846866967978f,
   0.022920009813905f, 0.043037949654269f, 0.934044659100325f);

//Adobe Wide Gamut RGB
 const mat3 kAdobeWGRGB_to_2020 = mat3 (
//   1.107073553496249f, -0.153227847929002f, 0.046154294432753f,
//   -0.050931551529117f, 1.130629708912274f, -0.079698157383157f,
//   0.004751406104069f, 0.043194090984263f, 0.952054502911668f);

   1.032815f, -0.099761f, 0.066946f,
   -0.053957f, 1.132758f, -0.078800f,
   0.001428f, 0.019514f, 0.979059f);

//Apple RGB
 const mat3 kAppleRGB_to_2020 = mat3 (
   0.678529391873470f, 0.268103222741389f, 0.053367385385141f,
   0.096031750282729f, 0.877730211467603f, 0.026238038249668f,
   0.021192740493379f, 0.109846519921590f, 0.868960739585031f);

//ITU-R BT.2020
 const mat3 k2020_to_2020 = mat3 (
   1.000000000000000f, 0.000000000000000f, 0.000000000000000f,
   0.000000000000000f, 1.000000000000000f, -0.000000000000000f,
   0.000000000000000f, 0.000000000000000f, 1.000000000000000f);

// NTSC-J P22
 const mat3 kNTSCJP22_to_2020 = mat3 (
   0.691014f, 0.261287f, 0.047700f,
   0.109646f, 0.876813f, 0.013541f,
   0.014382f, 0.096629f, 0.888989f);

// P22_80
 const mat3 kP2280_to_2020 = mat3 (
   0.702409f, 0.260434f, 0.037157f,
   0.087800f, 0.889849f, 0.022351f,
   0.004390f, 0.077212f, 0.918398f);

// P22 improved with tinted phosphors
 const mat3 kP2290_to_2020 = mat3 (
   0.621792f, 0.339128f, 0.039080f,
   0.057073f, 0.919420f, 0.023508f,
   -0.000938f, 0.035014f, 0.965924f);

// RPTV (Rear Projection TV) for NTSC-U late 90s, early 00s
 const mat3 kRPTV_to_2020 = mat3 (
   0.504405f, 0.451465f, 0.044129f,
   0.059729f, 0.908159f, 0.032112f,
   0.010633f, 0.062627f, 0.926741f);

// XXA (P22 sul?de/silicate/phosphate)
 const mat3 kXXA_to_2020 = mat3 (
   0.867034f, 0.096021f, 0.036945f,
   0.064650f, 0.936157f, -0.000808f,
   -0.001711f, 0.036583f, 0.965127f);

// XXB (P22 all-sul?de)/1958
 const mat3 kXXB_to_2020 = mat3 (
//   0.747111f, 0.224558f, 0.028332f,
//   0.075382f, 0.925237f, -0.000619f,
//   -0.001995f, 0.261872f, 0.740122f);

   0.651821f, 0.292537f, 0.055642f,
   0.065768f, 0.926913f, 0.007319f,
   -0.001740f, 0.104000f, 0.897740f);

// XXC (P22 sul?de/vanadate)/1964
 const mat3 kXXC_to_2020 = mat3 (
//   0.661541f, 0.304499f, 0.033961f,
//   0.047782f, 0.952961f, -0.000742f,
//   -0.001264f, 0.114094f, 0.887170f);

   0.706425f, 0.235501f, 0.058074f,
   0.065679f, 0.952661f, -0.018340f,
   0.015010f, 0.132171f, 0.852819f);

// XXD (P22 sul?de/oxysul?de)
 const mat3 kXXD_to_2020 = mat3 (
//   0.526084f, 0.418310f, 0.055607f,
//   0.073322f, 0.901471f, 0.025207f,
//   0.001097f, 0.052624f, 0.946279f);

   0.639371f, 0.317872f, 0.042756f,
   0.085284f, 0.887675f, 0.027041f,
   0.019961f, 0.084963f, 0.895076f);

//Conrac 7211N19
 const mat3 kConrac_to_2020 = mat3 (
   0.848016f, 0.103509f, 0.048476f,
   0.090261f, 0.893984f, 0.015755f,
   0.030765f, 0.064658f, 0.904577f);

//Sony Trinitron KV-20M20
 const mat3 kTT96_to_2020 = mat3 (
   0.678529f, 0.268103f, 0.053367f,
   0.096032f, 0.877730f, 0.026238f,
   0.021193f, 0.109847f, 0.868961f);

//SMPTE-C - Measured Average Phosphor (1979-1994)
 const mat3 kMA7994_to_2020 = mat3 (
   0.708152f, 0.257311f, 0.034538f,
   0.103842f, 0.879177f, 0.016980f,
   0.002749f, 0.076286f, 0.920965f);

//NTSC-J - Standard Phosphor
 const mat3 kNTSCJSt_to_2020 = mat3 (
   0.693529f, 0.259060f, 0.047411f,
   0.115249f, 0.869342f, 0.015409f,
   0.019484f, 0.095806f, 0.884711f);

//Philips Monitors
 const mat3 kPhilips_to_2020 = mat3 (
   0.634936f, 0.310278f, 0.054786f,
   0.082458f, 0.909159f, 0.008382f,
   0.013977f, 0.061264f, 0.924759f);
   
//CBS field-sequential color
const mat3 kCBS1951_to_2020 = mat3 (
   0.783661f,  0.174126f, 0.042214,
   0.046420f,  0.977702f, -0.024122,
   -0.001088f,  0.033960f, 0.967129);
   
//1953 Reciever Phosphors Matrices (TV Display Phosphors/Primaries — Some History)
const mat3 k1953RP_to_2020 = mat3 (
    0.849799f, 0.093430f, 0.056770f,
    0.063365f, 0.910900f, 0.025734f,
    0.001677f, 0.035596f, 0.966080f);
	
//1961 Reciever Phosphors Matrices (TV Display Phosphors/Primaries — Some History)
const mat3 k1961RP_to_2020 = mat3 (
	0.662328f, 0.294562f, 0.043110f,
	0.066828f, 0.921863f, 0.011309f,
	0.001768f, 0.110371f, 0.891397f);
	
//1970s Reciever Phosphors Matrices (TV Display Phosphors/Primaries — Some History)
const mat3 k1970sRP_to_2020 = mat3 (
    0.550286f, 0.404906f, 0.044808f,
    0.076695f, 0.911550f, 0.011755f,
    0.001148f, 0.072336f, 0.926516f);
	
//1980s Reciever Phosphors Matrices (TV Display Phosphors/Primaries — Some History)
const mat3 k1980sRP_to_2020 = mat3 (
    0.486929f, 0.460664f, 0.052407f,
    0.068735f, 0.924036f, 0.007230f,
    0.017765f, 0.055913f, 0.926322f);   

const mat3 kGBC_to_2020 = mat3 (
    0.480664f, 0.030999f, 0.488336f,
    0.254689f, 0.039603f, 0.705707f,
    0.201495f, 0.020874f, 0.777631f);

const mat3 kGBA_to_2020 = mat3 (
    0.613887f, 0.241502f, 0.144611f,
    0.225416f, 0.376913f, 0.397672f,
    0.213884f, 0.160997f, 0.625119f);

const mat3 kVBA_to_2020 = mat3 (
    0.511009f, 0.370072f, 0.118920f,
    0.147996f, 0.640980f, 0.211024f,
    0.113711f, 0.259285f, 0.627004f);

const mat3 kVBANDStopB_to_2020 = mat3 (
    0.574458f, 0.378632f, 0.046910f,
    0.166372f, 0.655806f, 0.177822f,
    0.127830f, 0.265282f, 0.606888f);

const mat3 kGBASP001_to_2020 = mat3 (
    0.657312f, 0.129653f, 0.213034f,
    0.276151f, 0.172264f, 0.551585f,
    0.219421f, 0.071942f, 0.708637f);

const mat3 kNDStop_to_2020 = mat3 (
    0.505180f, 0.449925f, 0.044895f,
    0.135502f, 0.694312f, 0.170186f,
    0.128643f, 0.290528f, 0.580829f);

const mat3 kNDSbot_to_2020 = mat3 (
    0.552550f, 0.400108f, 0.047343f,
    0.158357f, 0.634676f, 0.206967f,
    0.135599f, 0.250715f, 0.613686f);

const mat3 kPSP_to_2020 = mat3 (
    0.616974f, 0.370480f, 0.012546f,
    0.110186f, 0.742632f, 0.147183f,
    0.042149f, 0.086750f, 0.871101f);

const mat3 kGBAMic_to_2020 = mat3 (
    0.527771f, 0.440056f, 0.032174f,
    0.156245f, 0.699673f, 0.144082f,
    0.165485f, 0.205985f, 0.628531f);

const mat3 kGBASP101_to_2020 = mat3 (
    0.601413f, 0.369949f, 0.028638f,
    0.097055f, 0.833935f, 0.069010f,
    0.021480f, 0.043474f, 0.935046f);

const mat3 kNDSLtop_to_2020 = mat3 (
    0.559068f, 0.394156f, 0.046776f,
    0.086367f, 0.848814f, 0.064820f,
    0.032753f, 0.048467f, 0.918780f);

const mat3 kNDSLbot_to_2020 = mat3 (
    0.588690f, 0.369212f, 0.042098f,
    0.091811f, 0.822779f, 0.085410f,
    0.029350f, 0.047630f, 0.923020f);

const mat3 k3DStop_to_2020 = mat3 (
    0.617901f, 0.348510f, 0.033588f,
    0.120870f, 0.846257f, 0.032874f,
    0.044942f, 0.045950f, 0.909108f);

const mat3 k3DSbot_to_2020 = mat3 (
    0.609204f, 0.356901f, 0.033896f,
    0.119225f, 0.848015f, 0.032760f,
    0.051185f, 0.052276f, 0.896540f);

const mat3 k3DStop2_to_2020 = mat3 (
    0.578434f, 0.384236f, 0.037330f,
    0.103178f, 0.853935f, 0.042887f,
    0.041183f, 0.042332f, 0.916485f);

const mat3 kN3DSXLtop_to_2020 = mat3 (
    0.642314f, 0.324900f, 0.032786f,
    0.123906f, 0.801357f, 0.074737f,
    0.027595f, 0.041134f, 0.931271f);

const mat3 kLaterDSavg_to_2020 = mat3 (
    0.599544f, 0.364028f, 0.036429f,
    0.105486f, 0.837465f, 0.057049f,
    0.035303f, 0.045922f, 0.918776f);


// const mat3 k2020Gamuts[2] = { k709_to_2020, kExpanded709_to_2020 };
// const mat3 k2020Gamuts[15] = { k709_to_2020, kExpanded709_to_2020, kNTSC1953_to_2020, kXXB_to_2020, kXXC_to_2020, k601_to_2020, kPAL_to_2020, kNTSCJP22_to_2020, kP2280_to_2020, kAppleRGB_to_2020, kPhilips_to_2020, kP2290_to_2020, kRPTV_to_2020, kaDisplayP3_to_2020, k2020_to_2020 };

const mat3 k2020Gamuts[28] = { kCBS1951_to_2020, kNTSC1953_to_2020, k1953RP_to_2020, k1961RP_to_2020, kXXC_to_2020, kPAL_to_2020, k601_to_2020, kNTSCJP22_to_2020, k1970sRP_to_2020, k1980sRP_to_2020, kAppleRGB_to_2020, kPhilips_to_2020, kP2280_to_2020, kP2290_to_2020, kRPTV_to_2020, kVBANDStopB_to_2020, kPSP_to_2020, k709_to_2020, kAdobeRGB1998_to_2020, kLaterDSavg_to_2020, k709_to_2020, k709_to_2020, kaDisplayP3_to_2020, k709_to_2020, k709_to_2020, k709_to_2020, kExpanded709_to_2020, k2020_to_2020 };

#ifdef ADAMANT

float LinearToST2084_1(const float channel)
{
   float ST2084 = pow((0.8359375f + 18.8515625f * pow(channel, 0.1593017578f)) / (1.0f + 18.6875f * pow(channel, 0.1593017578f)), 78.84375f);
   return ST2084;  /* Don't clamp between [0..1], so we can still perform operations on scene values higher than 10,000 nits */
}

vec3 LinearToST2084(const vec3 colour)
{
	const vec3 positive = max(colour, vec3(0.0f));
	
	return vec3(LinearToST2084_1(positive.r), LinearToST2084_1(positive.g), LinearToST2084_1(positive.b));
}

#else // !ADAMANT

float LinearToST2084_1(const float channel)
{
   float ST2084 = pow((0.8359375f + 18.8515625f * pow(abs(channel), 0.1593017578f)) / (1.0f + 18.6875f * pow(abs(channel), 0.1593017578f)), 78.84375f);
   return ST2084;  /* Don't clamp between [0..1], so we can still perform operations on scene values higher than 10,000 nits */
}

vec3 LinearToST2084(const vec3 colour)
{
	return vec3(LinearToST2084_1(colour.r), LinearToST2084_1(colour.g), LinearToST2084_1(colour.b));
}

#endif // ADAMANT

/* END Converted from (Copyright (c) Microsoft Corporation - Licensed under the MIT License.)  https://github.com/microsoft/Xbox-ATG-Samples/tree/master/Kits/ATGTK/HDR */

/* Convert into HDR10 */
vec3 Hdr10(const vec3 hdr_linear, float paper_white_nits, float content_gamut)
{
   const vec3 rec2020       = hdr_linear * k2020Gamuts[uint(content_gamut)];
   const vec3 linearColour  = rec2020 * (paper_white_nits / kMaxNitsFor2084);
   vec3 hdr10               = LinearToST2084(linearColour);

   return hdr10;
}

