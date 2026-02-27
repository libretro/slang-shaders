
#define kEpsilon            0.0001f

#ifdef SONY_MEGATRON_VERSION_2

vec3 InverseTonemap(const vec3 sdr_linear, const float max_nits, const float paper_white_nits)
{
   const float input_val = max(sdr_linear.r, max(sdr_linear.g, sdr_linear.b));

   if (input_val < kEpsilon) return sdr_linear;

   const float peak_ratio = max_nits / paper_white_nits;

   const float numerator = input_val;
   const float denominator = 1.0 - input_val * (1.0 - (1.0 / peak_ratio));
   const float tonemapped_val = numerator / max(denominator, kEpsilon);

   return sdr_linear * (tonemapped_val / input_val);
}

#else // !SONY_MEGATRON_VERSION_2

vec3 InverseTonemap(const vec3 sdr_linear, const float max_nits, const float paper_white_nits)
{
   const float luma                 = dot(sdr_linear, vec3(0.2126, 0.7152, 0.0722));  /* Rec BT.709 luma coefficients - https://en.wikipedia.org/wiki/Luma_(video) */

   /* Inverse reinhard tonemap */
   const float max_value            = (max_nits / paper_white_nits) + kEpsilon;
   const float elbow                = max_value / (max_value - 1.0f);                          
   const float offset               = 1.0f - ((0.5f * elbow) / (elbow - 0.5f));              
   
   const float hdr_luma_inv_tonemap = offset + ((luma * elbow) / (elbow - luma));
   const float sdr_luma_inv_tonemap = luma / ((1.0f + kEpsilon) - luma);                     /* Convert the srd < 0.5 to 0.0 -> 1.0 range */

   const float luma_inv_tonemap     = (luma > 0.5f) ? hdr_luma_inv_tonemap : sdr_luma_inv_tonemap;
   const vec3 hdr                   = sdr_linear / (luma + kEpsilon) * luma_inv_tonemap;

   return hdr;
}

#endif // SONY_MEGATRON_VERSION_2
