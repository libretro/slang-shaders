// SDR Colour output spaces

const mat3 k709_to_XYZ = mat3(
   0.412391f, 0.357584f, 0.180481f,
   0.212639f, 0.715169f, 0.072192f,
   0.019331f, 0.119195f, 0.950532f);

const mat3 kXYZ_to_DCIP3 = mat3 (
    2.4934969119f, -0.9313836179f, -0.4027107845f,
   -0.8294889696f,  1.7626640603f,  0.0236246858f,
    0.0358458302f, -0.0761723893f,  0.9568845240f);

float LinearTosRGB_1(const float channel)
{
	return (channel > 0.0031308f) ? (1.055f * pow(channel, 1.0f / HCRT_GAMMA_OUT)) - 0.055f : channel * 12.92f; 
}

vec3 LinearTosRGB(const vec3 colour)
{
	return vec3(LinearTosRGB_1(colour.r), LinearTosRGB_1(colour.g), LinearTosRGB_1(colour.b));
}

float LinearTo709_1(const float channel)
{
	return (channel >= 0.018f) ? pow(channel * 1.099f, 1.0f / (HCRT_GAMMA_OUT - 0.18f)) - 0.099f : channel * 4.5f;  // Gamma: 2.4 - 0.18 = 2.22
}

vec3 LinearTo709(const vec3 colour)
{
	return vec3(LinearTo709_1(colour.r), LinearTo709_1(colour.g), LinearTo709_1(colour.b));
}

vec3 LinearToDCIP3(const vec3 colour)
{
	return clamp(pow(colour, vec3(1.0f / (HCRT_GAMMA_OUT + 0.2f))), 0.0f, 1.0f);   // Gamma: 2.4 + 0.2 = 2.6
}

void GammaCorrect(const vec3 scanline_colour, inout vec3 gamma_out)
{
   if(HCRT_HDR < 1.0f)
   {
      if(HCRT_OUTPUT_COLOUR_SPACE == 0.0f)
      {
         gamma_out = LinearTo709(scanline_colour);
      }
      else if(HCRT_OUTPUT_COLOUR_SPACE == 1.0f)
      {
         gamma_out = LinearTosRGB(scanline_colour);
      }
      else
      {
         const vec3 dcip3_colour = (scanline_colour * k709_to_XYZ) * kXYZ_to_DCIP3; 
         gamma_out = LinearToDCIP3(dcip3_colour);
      }
   }
   else
   {
      gamma_out = Hdr10(scanline_colour, HCRT_PAPER_WHITE_NITS, HCRT_EXPAND_GAMUT);
   }
}