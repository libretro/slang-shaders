
#define kColourSystems  3

#define kD50            5003.0f
#define kD55            5503.0f
#define kD65            6504.0f
#define kD75            7504.0f
#define kD93            9305.0f

const mat3 XYZ_to_sRGB = mat3(
    3.24081254005432130, -0.969243049621582000,  0.055638398975133896,
   -1.53730857372283940,  1.875966310501098600, -0.204007431864738460,
   -0.49858659505844116,  0.041555050760507584,  1.057129383087158200);

const mat3 sRGB_to_XYZ = mat3(
    0.41241079568862915, 0.21264933049678802, 0.019331756979227066,
    0.35758456587791443, 0.71516913175582890, 0.119194857776165010,
    0.18045382201671600, 0.07218152284622192, 0.950390160083770800);

// Phosphor transforms found in Dogway's Grade.slang shader

// SMPTE-C - Measured Average Phosphor (1979-1994)
const mat3 P22_transform = mat3(
   0.4665636420249939, 0.25661000609397890, 0.005832045804709196,
   0.3039233088493347, 0.66820019483566280, 0.105618737637996670,
   0.1799621731042862, 0.07518967241048813, 0.977465748786926300);

// SMPTE RP 145-1994 (SMPTE-C), 170M-1999
// SMPTE-C - Standard Phosphor (Rec.601 NTSC)
const mat3 SMPTE_transform = mat3(
   0.39354196190834045, 0.21238772571086884, 0.01874009333550930,
   0.36525884270668030, 0.70106136798858640, 0.11193416267633438,
   0.19164848327636720, 0.08655092865228653, 0.95824241638183590);

// SMPTE RP 145-1994 (SMPTE-C), 170M-1999
// NTSC-J - Standard Phosphor (https://web.archive.org/web/20130413104152/http://arib.or.jp/english/html/overview/doc/4-TR-B09v1_0.pdf)
const mat3 NTSC_J_transform = mat3(
   0.39603787660598755, 0.22429330646991730, 0.02050681784749031,
   0.31201449036598206, 0.67417418956756590, 0.12814880907535553,
   0.24496731162071228, 0.10153251141309738, 1.26512730121612550);

// ITU-R BT.470/601 (B/G)
// EBU Tech.3213-E PAL - Standard Phosphor for Studio Monitors
const mat3 EBU_transform = mat3(
   0.43194326758384705, 0.22272075712680817, 0.020247340202331543,
   0.34123489260673523, 0.70600330829620360, 0.129433929920196530,
   0.17818950116634370, 0.07127580046653748, 0.938464701175689700);

// CRT Phosphor Gamut
const mat3 kPhosphorGamut[kColourSystems] = { EBU_transform , P22_transform, NTSC_J_transform };

const float kTemperatures[kColourSystems] = { kD65, kD65, kD93 }; // 8942.0f 

  // Values from: http://blenderartists.org/forum/showthread.php?270332-OSL-Goodness&p=2268693&viewfull=1#post2268693   
const mat3 kWarmTemperature = mat3(
   vec3(0.0, -2902.1955373783176,   -8257.7997278925690),
	vec3(0.0,  1669.5803561666639,    2575.2827530017594),
	vec3(1.0,     1.3302673723350029,    1.8993753891711275));

const mat3 kCoolTemperature = mat3(
   vec3( 1745.0425298314172,      1216.6168361476490,    -8257.7997278925690),
   vec3(-2666.3474220535695,     -2173.1012343082230,     2575.2827530017594),
	vec3(    0.55995389139931482,     0.70381203140554553,    1.8993753891711275));

const mat4 kCubicBezier = mat4( 1.0f,  0.0f,  0.0f,  0.0f,
                               -3.0f,  3.0f,  0.0f,  0.0f,
                                3.0f, -6.0f,  3.0f,  0.0f,
                               -1.0f,  3.0f, -3.0f,  1.0f );

float Bezier(const float t0, const vec4 control_points)
{
   vec4 t = vec4(1.0, t0, t0*t0, t0*t0*t0);
   return dot(t, control_points * kCubicBezier);
}

vec3 WhiteBalance(float temperature, vec3 colour)
{
   const mat3 m = (temperature < kD65) ? kWarmTemperature : kCoolTemperature;

   const vec3 rgb_temperature = mix(clamp(vec3(m[0] / (vec3(clamp(temperature, 1000.0f, 40000.0f)) + m[1]) + m[2]), vec3(0.0f), vec3(1.0f)), vec3(1.0f), smoothstep(1000.0f, 0.0f, temperature));

   vec3 result = colour * rgb_temperature;

   result *= dot(colour, vec3(0.2126, 0.7152, 0.0722)) / max(dot(result, vec3(0.2126, 0.7152, 0.0722)), 1e-5); // Preserve luminance

   return result;
}

float r601r709ToLinear_1(const float channel)
{
	return (channel >= 0.081f) ? pow((channel + 0.099f) * (1.0f / 1.099f), (1.0f / 0.45f) + HCRT_GAMMA) : channel * (1.0f / 4.5f);
}

vec3 r601r709ToLinear(const vec3 colour)
{
	return vec3(r601r709ToLinear_1(colour.r), r601r709ToLinear_1(colour.g), r601r709ToLinear_1(colour.b));
}

float LinearTor601r709_1(const float channel)
{
	return (channel >= 0.018f) ? pow(channel * 1.099f, 0.45f) - 0.099f : channel * 4.5f;
}

vec3 LinearTor601r709(const vec3 colour)
{
	return vec3(LinearTor601r709_1(colour.r), LinearTor601r709_1(colour.g), LinearTor601r709_1(colour.b));
}

// SDR Colour output spaces
float sRGBToLinear_1(const float channel)
{
	return (channel > 0.04045f) ? pow((channel + 0.055f) * (1.0f / 1.055f), 2.4f + HCRT_GAMMA) : channel * (1.0f / 12.92f);
}

vec3 sRGBToLinear(const vec3 colour)
{
	return vec3(sRGBToLinear_1(colour.r), sRGBToLinear_1(colour.g), sRGBToLinear_1(colour.b));
}

float LinearTosRGB_1(const float channel)
{
	return (channel > 0.0031308f) ? (1.055f * pow(channel, 1.0f / 2.4f)) - 0.055f : channel * 12.92f;
}

vec3 LinearTosRGB(const vec3 colour)
{
	return vec3(LinearTosRGB_1(colour.r), LinearTosRGB_1(colour.g), LinearTosRGB_1(colour.b));
}

vec3 LinearToDCIP3(const vec3 colour)
{
	return pow(colour, vec3(1.0f / 2.6f));
}

// XYZ Yxy transforms found in Dogway's Grade.slang shader

vec3 XYZtoYxy(const vec3 XYZ)
{
   const float XYZrgb   = XYZ.r + XYZ.g + XYZ.b;
   const float Yxyg     = (XYZrgb <= 0.0f) ? 0.3805f : XYZ.r / XYZrgb;
   const float Yxyb     = (XYZrgb <= 0.0f) ? 0.3769f : XYZ.g / XYZrgb;
   return vec3(XYZ.g, Yxyg, Yxyb);
}

vec3 YxytoXYZ(const vec3 Yxy)
{
   const float Xs    = Yxy.r * (Yxy.g / Yxy.b);
   const float Xsz   = (Yxy.r <= 0.0f) ? 0.0f : 1.0f;
   const vec3 XYZ    = vec3(Xsz, Xsz, Xsz) * vec3(Xs, Yxy.r, (Xs / Yxy.g) - Xs - Yxy.r);
   return XYZ;
}

const vec4 kTopBrightnessControlPoints    = vec4(0.0f, 1.0f, 1.0f, 1.0f);
const vec4 kMidBrightnessControlPoints    = vec4(0.0f, 1.0f / 3.0f, (1.0f / 3.0f) * 2.0f, 1.0f);
const vec4 kBottomBrightnessControlPoints = vec4(0.0f, 0.0f, 0.0f, 1.0f);

float Brightness(const float luminance)
{
   if(HCRT_BRIGHTNESS >= 0.0f)
   {
      return Bezier(luminance, mix(kMidBrightnessControlPoints, kTopBrightnessControlPoints, HCRT_BRIGHTNESS));
   }
   else
   {
      return Bezier(luminance, mix(kMidBrightnessControlPoints, kBottomBrightnessControlPoints, abs(HCRT_BRIGHTNESS)));
   }
}

const vec4 kTopContrastControlPoints    = vec4(0.0f, 0.0f, 1.0f, 1.0f);
const vec4 kMidContrastControlPoints    = vec4(0.0f, 1.0f / 3.0f, (1.0f / 3.0f) * 2.0f, 1.0f);
const vec4 kBottomContrastControlPoints = vec4(0.0f, 1.0f, 0.0f, 1.0f);

float Contrast(const float luminance)
{
   if(HCRT_CONTRAST >= 0.0f)
   {
      return Bezier(luminance, mix(kMidContrastControlPoints, kTopContrastControlPoints, HCRT_CONTRAST));
   }
   else
   {
      return Bezier(luminance, mix(kMidContrastControlPoints, kBottomContrastControlPoints, abs(HCRT_CONTRAST)));
   }
}

vec3 Saturation(const vec3 colour)
{
   const float luma           = dot(colour, vec3(0.2125, 0.7154, 0.0721));
   const float saturation     = 0.5f + HCRT_SATURATION * 0.5f;

   return clamp(mix(vec3(luma), colour, vec3(saturation) * 2.0f), 0.0f, 1.0f);
}

vec3 BrightnessContrastSaturation(const vec3 linear)
{
   const vec3 xyz             = sRGB_to_XYZ * linear;
   const vec3 Yxy             = XYZtoYxy(xyz);
   const float Y_gamma        = clamp(LinearTosRGB_1(Yxy.x), 0.0f, 1.0f);
   
   const float Y_brightness   = Brightness(Y_gamma);

   const float Y_contrast     = Contrast(Y_brightness);

   const vec3 contrast_linear = vec3(sRGBToLinear_1(Y_contrast), Yxy.y, Yxy.z);
   const vec3 contrast_xyz    = YxytoXYZ(contrast_linear);
   const vec3 contrast        = clamp(XYZ_to_sRGB * contrast_xyz, 0.0f, 1.0f);

   const vec3 saturation      = Saturation(contrast);

   return saturation;
}

vec3 ColourGrade(const vec3 colour)
{
   const uint colour_system   = uint(HCRT_CRT_COLOUR_SYSTEM);

   const vec3 linear          = r601r709ToLinear(colour);

   const vec3 graded          = BrightnessContrastSaturation(linear); 

   const vec3 gamut           = kPhosphorGamut[colour_system] * graded;

   const vec3 white_point     = WhiteBalance(kTemperatures[colour_system] + HCRT_WHITE_TEMPERATURE, gamut);

   return clamp(XYZ_to_sRGB * white_point, 0.0f, 1.0f);
}
