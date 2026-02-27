
#define kPi    3.1415926536f
#define kEuler 2.718281828459f
#define kMax   1.0f

#define kBeamWidth 0.5f

const vec4 kFallOffControlPoints    = vec4(0.0f, 0.0f, 0.0f, 1.0f);
const vec4 kAttackControlPoints     = vec4(0.0f, 1.0f, 1.0f, 1.0f);
//const vec4 kScanlineControlPoints = vec4(1.0f, 1.0f, 0.0f, 0.0f);

const mat4 kCubicBezier = mat4( 1.0f,  0.0f,  0.0f,  0.0f,
                               -3.0f,  3.0f,  0.0f,  0.0f,
                                3.0f, -6.0f,  3.0f,  0.0f,
                               -1.0f,  3.0f, -3.0f,  1.0f );

float Bezier(const float t0, const vec4 control_points)
{
   vec4 t = vec4(1.0, t0, t0*t0, t0*t0*t0);
   return dot(t, control_points * kCubicBezier);
}

vec4 BeamControlPoints(const float beam_attack, const bool falloff)
{
   const float inner_attack = clamp(beam_attack, 0.0f, 1.0);
   const float outer_attack = clamp(beam_attack - 1.0f, 0.0f, 1.0);

   return falloff ? kFallOffControlPoints + vec4(0.0f, outer_attack, inner_attack, 0.0f) : kAttackControlPoints - vec4(0.0f, inner_attack, outer_attack, 0.0f);
}


#ifdef SONY_MEGATRON_VERSION_2

/* Single-channel scanline computation in Rec.709 space.
 * Scalar per-channel helper avoids dynamic vec3 l-value writes
 * that fail when SPIRV-Cross targets D3D11/fxc HLSL. */
float ScanlineChannel(const uint ch,
                      const vec2 tex_coord,
                      const vec2 source_size,
                      const float scanline_size,
                      const float source_tex_coord_x,
                      const float narrowed_source_pixel_offset,
                      const float vertical_convergence,
                      const float beam_attack,
                      const float scanline_min,
                      const float scanline_max,
                      const float scanline_attack,
                      const float vertical_bias)
{
   float current_source_position_y  = ((tex_coord.y * source_size.y) - vertical_convergence);
   float center_line                = floor(current_source_position_y) + 0.5 + vertical_bias;
   float distance_to_line           = current_source_position_y - center_line;

   if (abs(distance_to_line) > 1.5) return 0.0f;

   float source_tex_coord_y         = center_line / source_size.y;

   vec2 tc0                         = vec2(source_tex_coord_x, source_tex_coord_y);
   vec2 tc1                         = vec2(source_tex_coord_x + (1.0 / source_size.x), source_tex_coord_y);

   float sdr_channel_0              = COMPAT_TEXTURE(SourceSDR, tc0)[ch];
   float sdr_channel_1              = COMPAT_TEXTURE(SourceSDR, tc1)[ch];

   float horiz_interp               = Bezier(narrowed_source_pixel_offset, BeamControlPoints(beam_attack, sdr_channel_0 > sdr_channel_1));
   float sdr_channel                = mix(sdr_channel_0, sdr_channel_1, horiz_interp);

   float signal_strength            = clamp(sdr_channel, 0.0f, 1.0f);

   float beam_width_adjustment      = (kBeamWidth / scanline_size);
   float raw_distance               = abs(distance_to_line) - beam_width_adjustment;
   float distance_adjusted          = max(0.0f, raw_distance);
   float effective_distance         = distance_adjusted * 2.0f;

   float beam_width                 = mix(scanline_min, scanline_max, signal_strength);

   float channel_scanline_distance  = clamp(effective_distance / beam_width, 0.0f, 1.0f);

   vec4 channel_control_points      = vec4(1.0f, 1.0f, signal_strength * scanline_attack, 0.0f);
   float luminance                  = Bezier(channel_scanline_distance, channel_control_points);

   return luminance * sdr_channel;
}

/* Per-channel scanline generation in Rec.709 space.
 * Uses SourceSDR (Rec.709) for both beam width and output value.
 * This ensures chromaticity is preserved: a pure Rec.709 primary only has
 * one non-zero channel, so different beam widths cannot shift chromaticity.
 * The conversion to Rec.2020 and HDR brightness boost happen afterward. */
vec3 ScanlineColour(const vec2 tex_coord,
                    const vec2 source_size,
                    const float scanline_size,
                    const vec3 source_tex_coord_x,
                    const vec3 narrowed_source_pixel_offset,
                    const vec3 vertical_convergence,
                    const vec3 beam_attack,
                    const vec3 scanline_min,
                    const vec3 scanline_max,
                    const vec3 scanline_attack,
                    const float vertical_bias)
{
   return vec3(
      ScanlineChannel(0u, tex_coord, source_size, scanline_size,
                      source_tex_coord_x.x, narrowed_source_pixel_offset.x,
                      vertical_convergence.x, beam_attack.x,
                      scanline_min.x, scanline_max.x, scanline_attack.x, vertical_bias),
      ScanlineChannel(1u, tex_coord, source_size, scanline_size,
                      source_tex_coord_x.y, narrowed_source_pixel_offset.y,
                      vertical_convergence.y, beam_attack.y,
                      scanline_min.y, scanline_max.y, scanline_attack.y, vertical_bias),
      ScanlineChannel(2u, tex_coord, source_size, scanline_size,
                      source_tex_coord_x.z, narrowed_source_pixel_offset.z,
                      vertical_convergence.z, beam_attack.z,
                      scanline_min.z, scanline_max.z, scanline_attack.z, vertical_bias)
   );
}

vec3 GenerateScanline(const vec2 tex_coord,
                      const vec2 source_size,
                      const float scanline_size,
                      const vec3 horizontal_convergence,
                      const vec3 vertical_convergence,
                      const vec3 beam_sharpness,
                      const vec3 beam_attack,
                      const vec3 scanline_min,
                      const vec3 scanline_max,
                      const vec3 scanline_attack)
{
   /* Vectorised horizontal prep — native vec3 ops, no loop needed */
   vec3 current_source_position_x      = vec3(tex_coord.x * source_size.x) - horizontal_convergence;
   vec3 current_source_center_x        = floor(current_source_position_x) + vec3(0.5);
   vec3 source_tex_coord_x             = current_source_center_x / source_size.x;
   vec3 source_pixel_offset            = fract(current_source_position_x);
   vec3 narrowed_source_pixel_offset   = clamp(((source_pixel_offset - 0.5) * beam_sharpness) + 0.5, 0.0, 1.0);

   vec3 total_light = ScanlineColour(tex_coord, source_size, scanline_size, source_tex_coord_x,
                                     narrowed_source_pixel_offset, vertical_convergence, beam_attack,
                                     scanline_min, scanline_max, scanline_attack,
                                     0.0);

   total_light += ScanlineColour(tex_coord, source_size, scanline_size, source_tex_coord_x,
                                 narrowed_source_pixel_offset, vertical_convergence, beam_attack,
                                 scanline_min, scanline_max, scanline_attack,
                                 1.0);

   total_light += ScanlineColour(tex_coord, source_size, scanline_size, source_tex_coord_x,
                                 narrowed_source_pixel_offset, vertical_convergence, beam_attack,
                                 scanline_min, scanline_max, scanline_attack,
                                 -1.0);

   return total_light;
}

#else // !SONY_MEGATRON_VERSION_2

float ScanlineColour(const uint channel, 
                     const vec2 tex_coord,
                     const vec2 source_size, 
                     const float scanline_size, 
                     const float source_tex_coord_x, 
                     const float narrowed_source_pixel_offset, 
                     const float vertical_convergence, 
                     const float beam_attack, 
                     const float scanline_min, 
                     const float scanline_max, 
                     const float scanline_attack, 
                     inout float next_prev)
{
   const float current_source_position_y  = ((tex_coord.y * source_size.y) - vertical_convergence) + next_prev;
   const float current_source_center_y    = floor(current_source_position_y) + 0.5f; 
   
   const float source_tex_coord_y         = current_source_center_y / source_size.y; 

   const float scanline_delta             = fract(current_source_position_y) - 0.5f;

   // Slightly increase the beam width to get maximum brightness
   float beam_distance                    = abs(scanline_delta - next_prev) - (kBeamWidth / scanline_size);
   beam_distance                          = beam_distance < 0.0f ? 0.0f : beam_distance;
   const float scanline_distance          = beam_distance * 2.0f;

   next_prev = scanline_delta > 0.0f ? 1.0f : -1.0f;

   const vec2 tex_coord_0                 = vec2(source_tex_coord_x, source_tex_coord_y);
   const vec2 tex_coord_1                 = vec2(source_tex_coord_x + (1.0f / source_size.x), source_tex_coord_y);

   const float sdr_channel_0              = COMPAT_TEXTURE(SourceSDR, tex_coord_0)[channel];
   const float sdr_channel_1              = COMPAT_TEXTURE(SourceSDR, tex_coord_1)[channel];

   const float hdr_channel_0              = COMPAT_TEXTURE(SourceHDR, tex_coord_0)[channel];
   const float hdr_channel_1              = COMPAT_TEXTURE(SourceHDR, tex_coord_1)[channel];

   /* Horizontal interpolation between pixels */ 
   const float horiz_interp               = Bezier(narrowed_source_pixel_offset, BeamControlPoints(beam_attack, sdr_channel_0 > sdr_channel_1));  

   const float hdr_channel                = mix(hdr_channel_0, hdr_channel_1, horiz_interp);
   const float sdr_channel                = mix(sdr_channel_0, sdr_channel_1, horiz_interp);

   const float channel_scanline_distance  = clamp(scanline_distance / ((sdr_channel * (scanline_max - scanline_min)) + scanline_min), 0.0f, 1.0f);

   const vec4 channel_control_points      = vec4(1.0f, 1.0f, sdr_channel * scanline_attack,    0.0f);

   const float luminance                  = Bezier(channel_scanline_distance, channel_control_points);

   return luminance * hdr_channel;
}

float GenerateScanline( const uint channel, 
                        const vec2 tex_coord,
                        const vec2 source_size, 
                        const float scanline_size, 
                        const float horizontal_convergence, 
                        const float vertical_convergence, 
                        const float beam_sharpness, 
                        const float beam_attack, 
                        const float scanline_min, 
                        const float scanline_max, 
                        const float scanline_attack)
{
   const float current_source_position_x      = (tex_coord.x * source_size.x) - horizontal_convergence;
   const float current_source_center_x        = floor(current_source_position_x) + 0.5f; 
   
   const float source_tex_coord_x             = current_source_center_x / source_size.x; 

   const float source_pixel_offset            = fract(current_source_position_x);

   const float narrowed_source_pixel_offset   = clamp(((source_pixel_offset - 0.5f) * beam_sharpness) + 0.5f, 0.0f, 1.0f);

   float next_prev = 0.0f;

   const float scanline_colour0  = ScanlineColour( channel, 
                                                   tex_coord,
                                                   source_size, 
                                                   scanline_size, 
                                                   source_tex_coord_x, 
                                                   narrowed_source_pixel_offset, 
                                                   vertical_convergence,  
                                                   beam_attack, 
                                                   scanline_min, 
                                                   scanline_max, 
                                                   scanline_attack, 
                                                   next_prev);

   // Optionally sample the neighbouring scanline
   float scanline_colour1 = 0.0f;
   if(scanline_max > 1.0f)
   {
      scanline_colour1           = ScanlineColour( channel, 
                                                   tex_coord,
                                                   source_size, 
                                                   scanline_size, 
                                                   source_tex_coord_x, 
                                                   narrowed_source_pixel_offset,
                                                   vertical_convergence,  
                                                   beam_attack, 
                                                   scanline_min, 
                                                   scanline_max, 
                                                   scanline_attack,  
                                                   next_prev);
   }

   return scanline_colour0 + scanline_colour1;
}

#endif // SONY_MEGATRON_VERSION_2