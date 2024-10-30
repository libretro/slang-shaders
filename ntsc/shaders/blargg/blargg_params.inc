layout(push_constant) uniform Push
{
   vec4 SourceSize;
   uint FrameCount;
   float kernel_half, ntsc_sat, ntsc_res, ntsc_bri, ntsc_hue, ntsc_sharp, fring, afacts, ntsc_bleed, LUMA_CUTOFF, stat_ph, dummy, pi_mod, vert_scal;
} params;

#pragma parameter kernel_half "Kernel Half-Size (speed-up)" 16.0 1.0 16.0 1.0
#pragma parameter ntsc_sat "Saturation" 2.0 0.0 6.0 0.05
#pragma parameter ntsc_res "Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter ntsc_bri "Brightness" 1.0 0.0 2.0 0.01
#pragma parameter ntsc_hue "Hue" 0.0 -1.0 6.3 0.05
#pragma parameter fring "Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter ntsc_bleed "Chroma Bleed" 0.0 -0.75 2.0 0.05
#pragma parameter LUMA_CUTOFF "Luma Cutoff" 0.2 0.0 1.0 0.005
#pragma parameter stat_ph "Dot Crawl On/Off" 0.0 0.0 1.0 1.0
#pragma parameter dummy " [ System Specific Tweaks] " 0.0 0.0 0.0 0.0
#pragma parameter pi_mod "Phase-Horiz. Angle" 96.0 1.0 360.0 1.0
#pragma parameter vert_scal "Phase-Vertical Scale" 0.6667 0.0 2.0 0.05555

#define kernel_half params.kernel_half
#define ntsc_sat params.ntsc_sat
#define ntsc_res params.ntsc_res
#define ntsc_sharp params.ntsc_sharp
#define fring params.fring
#define afacts params.afacts
#define ntsc_bleed params.ntsc_bleed
#define LUMA_CUTOFF params.LUMA_CUTOFF
#define stat_ph params.stat_ph
#define dummy params.dummy
#define pi_mod params.pi_mod
#define vert_scal params.vert_scal
#define ntsc_bri params.ntsc_bri
#define ntsc_hue params.ntsc_hue

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OriginalSize;
   vec4 OutputSize;
} global;