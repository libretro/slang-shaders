
#define kMaxNitsFor2084     10000.0f

const mat3 k709to2020 = mat3 (
   0.6274040f, 0.3292820f, 0.0433136f,
   0.0690970f, 0.9195400f, 0.0113612f,
   0.0163916f, 0.0880132f, 0.8955950f);

/* START Converted from (Copyright (c) Microsoft Corporation - Licensed under the MIT License.)  https://github.com/microsoft/Xbox-ATG-Samples/tree/master/Kits/ATGTK/HDR */
const mat3 kExpanded709to2020 = mat3 (
    0.6274040f, 0.3292820f, 0.0433136f,
    0.0457456,  0.941777,   0.0124772,
   -0.00121055, 0.0176041,  0.983607);

vec3 LinearToST2084(vec3 normalizedLinearValue)
{
   vec3 ST2084 = pow((0.8359375f + 18.8515625f * pow(abs(normalizedLinearValue), vec3(0.1593017578f))) / (1.0f + 18.6875f * pow(abs(normalizedLinearValue), vec3(0.1593017578f))), vec3(78.84375f));
   return ST2084;  /* Don't clamp between [0..1], so we can still perform operations on scene values higher than 10,000 nits */
}
/* END Converted from (Copyright (c) Microsoft Corporation - Licensed under the MIT License.)  https://github.com/microsoft/Xbox-ATG-Samples/tree/master/Kits/ATGTK/HDR */

/* Convert into HDR10 */
vec3 Hdr10(vec3 hdr_linear, float paper_white_nits, float expand_gamut)
{
   vec3 rec2020       = expand_gamut > 0.0f ? hdr_linear * kExpanded709to2020 : hdr_linear * k709to2020;
   vec3 linearColour  = rec2020 * (paper_white_nits / kMaxNitsFor2084);
   vec3 hdr10         = LinearToST2084(linearColour);

   return hdr10;
}

