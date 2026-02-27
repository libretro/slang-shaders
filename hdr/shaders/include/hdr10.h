
#define kMaxNitsFor2084     10000.0f

const mat3 k2020_to_sRGB = mat3(
    1.660491f, -0.587641f, -0.072850f,
   -0.124550f,  1.132900f, -0.008349f,
   -0.018151f, -0.100579f,  1.118730f
);

const mat3 k2020_to_P3 = mat3(
    1.343578f, -0.282180f, -0.061399f,
   -0.065297f,  1.075788f, -0.010490f,
    0.002822f, -0.019598f,  1.016777f
);

const mat3 k2020_to_Adobe = mat3(
    1.151978f, -0.097503f, -0.054475f,
   -0.124550f,  1.132900f, -0.008349f,
   -0.022530f, -0.049807f,  1.072337f
);

// ------------------------------------------------------------------------------------------------
// Rec.709 / sRGB Matrices
// ------------------------------------------------------------------------------------------------

/* Standard Rec.709/sRGB to Rec.2020 conversion */
const mat3 k709_to_2020 = mat3 (
   0.6274040f, 0.3292820f, 0.0433136f,
   0.0690970f, 0.9195400f, 0.0113612f,
   0.0163916f, 0.0880132f, 0.8955950f);

/* Rec.709 to DCI-P3 (= k709_to_2020 * k2020_to_P3) */
const mat3 k709_to_P3 = mat3 (
    0.8215873f,  0.1763479f,  0.0020641f,
    0.0328261f,  0.9695096f, -0.0023367f,
    0.0188038f,  0.0725063f,  0.9086907f);

/* START Converted from (Copyright (c) Microsoft Corporation - Licensed under the MIT License.)  https://github.com/microsoft/Xbox-ATG-Samples/tree/master/Kits/ATGTK/HDR */
const mat3 kExpanded709_to_2020 = mat3 (
    0.6274040f,  0.3292820f, 0.0433136f,
    0.0457456f,  0.941777f,  0.0124772f,
   -0.00121055f, 0.0176041f, 0.983607f);
/* END Converted from (Copyright (c) Microsoft Corporation - Licensed under the MIT License.)  https://github.com/microsoft/Xbox-ATG-Samples/tree/master/Kits/ATGTK/HDR */

/* Rec.709 to Expanded Rec.709 (= k709_to_2020 * k2020_to_Expanded709) */
const mat3 k709_to_Expanded709 = mat3 (
    1.0000025f, -0.0000016f, -0.0000001f,
    0.0399515f,  0.9624604f, -0.0024178f,
    0.0228872f,  0.0684669f,  0.9086437f);

#ifdef SONY_MEGATRON_VERSION_2

// ------------------------------------------------------------------------------------------------
// DCI-P3 Matrices
// ------------------------------------------------------------------------------------------------

/* Standard DCI-P3 (D65 White Point) to Rec.2020 conversion */
const mat3 kP3_to_2020 = mat3 (
    0.753833f, 0.198597f, 0.047570f,
    0.045744f, 0.941777f, 0.012479f,
   -0.001210f, 0.017602f, 0.983609f);

/* Expanded DCI-P3 to Rec.2020 ("Color Boost")
   Hybrid: Uses DCI-P3 Red, but Rec.2020 Green and Blue */
const mat3 kExpandedP3_to_2020 = mat3 (
    0.753833f, 0.198597f, 0.047570f,
    0.000000f, 1.000000f, 0.000000f,
    0.000000f, 0.000000f, 1.000000f);

// ------------------------------------------------------------------------------------------------
// NTSC (SMPTE C) Matrices - Standard for US/Japan Retro Consoles
// ------------------------------------------------------------------------------------------------

const mat3 kNtsc_to_2020 = mat3 (
    0.595254f, 0.349314f, 0.055432f,
    0.081244f, 0.891503f, 0.027253f,
    0.015512f, 0.081912f, 0.902576f);

/* Expanded: Uses NTSC Red, but DCI-P3 Green and Blue */
const mat3 kExpandedNtsc_to_2020 = mat3 (
    0.595254f, 0.349314f, 0.055432f,
    0.045744f, 0.941777f, 0.012479f,
   -0.001210f, 0.017602f, 0.983609f);

// ------------------------------------------------------------------------------------------------
// PAL (EBU Tech. 3213-E) Matrices - Standard for European Retro Consoles
// ------------------------------------------------------------------------------------------------

const mat3 kPal_to_2020 = mat3 (
    0.655037f, 0.302161f, 0.042802f,
    0.072141f, 0.916631f, 0.011228f,
    0.017113f, 0.097853f, 0.885033f);

/* Expanded: Uses PAL Red, but DCI-P3 Green and Blue */
const mat3 kExpandedPal_to_2020 = mat3 (
    0.655037f, 0.302161f, 0.042802f,
    0.045744f, 0.941777f, 0.012479f,
   -0.001210f, 0.017602f, 0.983609f);

// ------------------------------------------------------------------------------------------------
// Adobe RGB (1998) Matrices
// ------------------------------------------------------------------------------------------------

const mat3 kAdobe_to_2020 = mat3 (
    0.877334f, 0.077494f, 0.045172f,
    0.096623f, 0.891527f, 0.011850f,
    0.022921f, 0.043037f, 0.934042f);

/* Expanded: Uses Adobe Red, but Rec.2020 Green and Blue */
const mat3 kExpandedAdobe_to_2020 = mat3 (
    0.877334f, 0.077494f, 0.045172f,
    0.000000f, 1.000000f, 0.000000f,
    0.000000f, 0.000000f, 1.000000f);

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

mat3 GamutMatrix(uint colour_space, uint expand_gamut)
{
    // ColourSpace: 0=709, 1=sRGB, 2=DCI-P3, 3=NTSC, 4=PAL, 5=AdobeRGB
    // ExpandGamut: 0=Standard, 1=Expanded
    
    switch(colour_space)
    {
        case 2: // DCI-P3
        {
            return (expand_gamut > 0) ? kExpandedP3_to_2020 : kP3_to_2020;
        }
        case 3: // NTSC
        {
            return (expand_gamut > 0) ? kExpandedNtsc_to_2020 : kNtsc_to_2020;
        }
        case 4: // PAL
        {
            return (expand_gamut > 0) ? kExpandedPal_to_2020 : kPal_to_2020;
        }
        case 5: // AdobeRGB
        {
            return (expand_gamut > 0) ? kExpandedAdobe_to_2020 : kAdobe_to_2020;
        }
        default: // 0 & 1 (Rec.709 / sRGB)
        {
            return (expand_gamut > 0) ? kExpanded709_to_2020 : k709_to_2020;
        }
    }
}

/* Convert into HDR10 */
vec3 Hdr10(const vec3 hdr_linear, float paper_white_nits, float colour_space, float expand_gamut)
{
   const vec3 rec2020       = hdr_linear * GamutMatrix(uint(colour_space), uint(expand_gamut));
   const vec3 linearColour  = rec2020 * (paper_white_nits / kMaxNitsFor2084);
   vec3 hdr10               = LinearToST2084(linearColour);

   return hdr10;
}

#else // !SONY_MEGATRON_VERSION_2

const mat3 k2020Gamuts[2] = { k709_to_2020, kExpanded709_to_2020 };

float LinearToST2084_1(const float channel)
{
   float ST2084 = pow((0.8359375f + 18.8515625f * pow(abs(channel), 0.1593017578f)) / (1.0f + 18.6875f * pow(abs(channel), 0.1593017578f)), 78.84375f);
   return ST2084;  /* Don't clamp between [0..1], so we can still perform operations on scene values higher than 10,000 nits */
}

vec3 LinearToST2084(const vec3 colour)
{
	return vec3(LinearToST2084_1(colour.r), LinearToST2084_1(colour.g), LinearToST2084_1(colour.b));
}

/* Convert into HDR10 */
vec3 Hdr10(const vec3 hdr_linear, float paper_white_nits, float expand_gamut)
{
   const vec3 rec2020       = hdr_linear * k2020Gamuts[uint(expand_gamut)];
   const vec3 linearColour  = rec2020 * (paper_white_nits / kMaxNitsFor2084);
   vec3 hdr10               = LinearToST2084(linearColour);

   return hdr10;
}
#endif // SONY_MEGATRON_VERSION_2




