/* There yoy have a chance to boost your FPS.
 * 
 * The more lines you edit, the more your FPS will be high.
 * 
 * Edit lines that way, eg:
 * 
 * 	#define SCANLINE_DARK	params.SCANLINE_DARK
 * 	turns to:
 * 	#define SCANLINE_DARK	0.2
 * 
 * or:
 * 	#define DO_CCORRECTION	global.DO_CCORRECTION
 * 	turns to
 * 	#define DO_CCORRECTION	0.0
 * 
 * 
 * Since everything after "//" is ignored,
 * you can even do something like:
 * 	#define DO_CCORRECTION	0.0 //global.DO_CCORRECTION
 * 
 * 
 * ...that's it, you just need to copy the values from the
 * preset you like to the right setting here.
 * 
 * The downside of using this method is that every setting
 * you turn, will be static and you will not be able to
 * modify it "on-the-fly" in retroarch.
 * 
 * The only way to change that values will be to edit this file
 * again, so maybe doing multiple copies of this file
 * or even of the whole koko-shader would be a good idea.
 * 
 * 
 * I suggest you to start from the easy ones, the ones that
 * starts with DO_****, like DO_SCANLINES.
 * it takes a value = 0 or 1, where 0 means no, 1 means yes.
 * I repeat: if you always wants scanlines, just use:
 * 
 * 	#define DO_SCANLINES		1.0
 * 	instead of
 * 	#define #DO_SCANLINES	global.DO_SCANLINES
 * 
 * 
 * Also, take a copy of this (modified) file, because it would be overwritten by
 * updates.
 * 
 */



#define DO_CCORRECTION	global.DO_CCORRECTION
	#define GAMMA_OUT	global.GAMMA_OUT
	#define SATURATION	global.SATURATION
	#define LUMINANCE	global.LUMINANCE
	#define CONTRAST	global.CONTRAST
	#define BRIGHTNESS	global.BRIGHTNESS
	#define TEMPERATURE	global.TEMPERATURE



	#define DO_FXAA	global.DO_FXAA



#define DO_NTSC_ARTIFACTS	global.DO_NTSC_ARTIFACTS
	#define NTSC_FILTER_WIDTH		global.NTSC_FILTER_WIDTH
	#define NTSC_FILTER_SCF			global.NTSC_FILTER_SCF
	#define NTSC_FILTER_FC			global.NTSC_FILTER_FC
	#define NTSC_MIX				global.NTSC_MIX
	#define NTSC_PHASE_SHIFT		global.NTSC_PHASE_SHIFT



#define DO_RF_NOISE		global.DO_RF_NOISE
	#define RF_NOISE_STRENGTH	global.RF_NOISE_STRENGTH



#define DO_SAT_BLEED		global.DO_SAT_BLEED
	#define SAT_BLEED_SIZE_LEFT	global.SAT_BLEED_SIZE_LEFT
	#define SAT_BLEED_SIZE_RIGHT	global.SAT_BLEED_SIZE_RIGHT
	#define SAT_BLEED_FALLOFF	global.SAT_BLEED_FALLOFF
	#define SAT_BLEED_STRENGTH	global.SAT_BLEED_STRENGTH
	#define SAT_BLEED_PAL		global.SAT_BLEED_PAL



#define DO_SHIFT_RGB		global.DO_SHIFT_RGB
	#define SHIFT_R			global.SHIFT_R
	#define SHIFT_G			global.SHIFT_G
	#define SHIFT_B			global.SHIFT_B
	#define OFFSET_STRENGTH	global.OFFSET_STRENGTH



#define DO_IN_GLOW		global.DO_IN_GLOW
	#define IN_GLOW_BIAS			global.IN_GLOW_BIAS
	#define IN_GLOW_SPREAD			global.IN_GLOW_SPREAD
	#define IN_GLOW_W				global.IN_GLOW_W
	#define IN_GLOW_H				global.IN_GLOW_H
	#define IN_GLOW_POWER			global.IN_GLOW_POWER
	#define IN_GLOW_GAMMA			global.IN_GLOW_GAMMA
	#define IN_GLOW_NTSC_ARTF_MULT	global.IN_GLOW_NTSC_ARTF_MULT
	#define IN_GLOW_NTSC_ARTF_TRSH	global.IN_GLOW_NTSC_ARTF_TRSH
	#define IN_GLOW_SHOW_ARTF_MASK  global.IN_GLOW_SHOW_ARTF_MASK


#define DO_VMASK_AND_DARKLINES	global.DO_VMASK_AND_DARKLINES
	#define MASK_COMPENSATION	global.MASK_COMPENSATION
	#define RGB_MASK_STRENGTH	global.RGB_MASK_STRENGTH
	#define VMASK_OVERWHITE		params.VMASK_OVERWHITE
	#define VMASK_DARKLINE_SCALE	params.VMASK_DARKLINE_SCALE
	#define VMASK_GAP			params.VMASK_GAP
	#define VMASK_USE_GM		params.VMASK_USE_GM
	#define DARKLINES_STRENGTH	global.DARKLINES_STRENGTH
	#define DRKLN_OVERWHITE		params.DRKLN_OVERWHITE
	#define DARKLINES_VOFFSET	params.DARKLINES_VOFFSET
	#define DARKLINES_PERIOD	params.DARKLINES_PERIOD



#define DO_HALO		global.DO_HALO
	#define HALO_W		params.HALO_W
	#define HALO_H		params.HALO_H
	#define HALO_POWER	params.HALO_POWER
	#define HALO_GAMMA	params.HALO_GAMMA
	#define HALO_VS_SCAN	params.HALO_VS_SCAN


#define DO_SCANLINES			global.DO_SCANLINES
	#define SCANLINE_DARK			params.SCANLINE_DARK
	#define SCANLINE_MIN			global.SCANLINE_MIN
	#define SCANLINE_MAX			global.SCANLINE_MAX
	#define SCANLINES_BLEEDING	global.SCANLINES_BLEEDING
	#define SCANLINE_FLICKERING		global.SCANLINE_FLICKERING
	#define SCANLINE_FLICKERING_POWER	global.SCANLINE_FLICKERING_POWER
	#define SCANLINE_DISABLE_ON_INTERLACE	global.SCANLINE_DISABLE_ON_INTERLACE
	#define SCANLINE_COMPENSATION		global.SCANLINE_COMPENSATION
	#define SCANLINE_SM_TYPE		global.SCANLINE_SM_TYPE
	#define SCANLINE_SM_STRENGTH		global.SCANLINE_SM_STRENGTH
	#define SCANLINE_SM_VOFFSET		global.SCANLINE_SM_VOFFSET 



#define DO_BLOOM		params.DO_BLOOM
	#define BLOOM_MIX		global.BLOOM_MIX
	#define BLOOM_EYE_ADPT_SRT	global.BLOOM_EYE_ADPT_SRT
	#define BLOOM_EYE_INERTIA	global.BLOOM_EYE_INERTIA
	#define BLOOM_QUALITY		params.BLOOM_QUALITY
	#define BLOOM_SIZE		global.BLOOM_SIZE
	#define BLOOM_GAMMA		global.BLOOM_GAMMA
	#define BLOOM_POWER		global.BLOOM_POWER
	#define BLOOM_GAMMA_OUT		global.BLOOM_GAMMA_OUT
	#define BLOOM_OVER_WHITE	global.BLOOM_OVER_WHITE
	#define BLOOM_BYPASS		global.BLOOM_BYPASS



#define DO_CURVATURE		global.DO_CURVATURE
	#define GEOM_WARP_X		global.GEOM_WARP_X
	#define GEOM_WARP_Y		global.GEOM_WARP_Y
	#define GEOM_CORNER_SIZE	global.GEOM_CORNER_SIZE
	#define GEOM_CORNER_SMOOTH	global.GEOM_CORNER_SMOOTH



#define DO_BEZEL		global.DO_BEZEL
	#define BEZEL_R			global.BEZEL_R
	#define BEZEL_G			global.BEZEL_G
	#define BEZEL_B			global.BEZEL_B
	#define BEZEL_CON		global.BEZEL_CON
	#define BEZEL_INNER_ZOOM	global.BEZEL_INNER_ZOOM
	#define BEZEL_FRAME_ZOOM	global.BEZEL_FRAME_ZOOM
	#define BEZEL_IMAGE_BORDER	global.BEZEL_IMAGE_BORDER
	#define BEZEL_USE_STRAIGHT	global.BEZEL_USE_STRAIGHT
	#define BEZEL_RFL_BLR_SHD	global.BEZEL_RFL_BLR_SHD
	#define BEZEL_RFL_OFFSET	global.BEZEL_RFL_OFFSET
	#define BEZEL_REFL_ZOOM		global.BEZEL_REFL_ZOOM
	#define BEZEL_REFL_STRENGTH	global.BEZEL_REFL_STRENGTH
	
#define DO_SPOT		global.DO_SPOT
	#define S_POSITION	global.S_POSITION
	#define S_SIZE		global.S_SIZE
	#define S_POWER		global.S_POWER



#define DO_VIGNETTE	global.DO_VIGNETTE
	#define V_SIZE		global.V_SIZE
	#define V_POWER		global.V_POWER



#define DO_BG_IMAGE		global.DO_BG_IMAGE
	#define BG_IMAGE_OVER		global.BG_IMAGE_OVER
	#define BG_IMAGE_OFFY		global.BG_IMAGE_OFFY
	#define BG_IMAGE_OFFX		global.BG_IMAGE_OFFX
	#define BG_IMAGE_ZOOM		global.BG_IMAGE_ZOOM
	#define BG_IMAGE_ROTATION	global.BG_IMAGE_ROTATION
	#define BG_IMAGE_WRAP_MODE	global.BG_IMAGE_WRAP_MODE


#define DO_AMBILIGHT		global.DO_AMBILIGHT
	#define AMBI_STEPS	global.AMBI_STEPS
	#define AMBI_FALLOFF	global.AMBI_FALLOFF
	#define AMBI_POWER	global.AMBI_POWER
	#define AMBI_OVER_BEZEL global.AMBI_OVER_BEZEL
	#define ASPECT_X	global.ASPECT_X
	#define ASPECT_Y	global.ASPECT_Y



#define DO_DYNZOOM		global.DO_DYNZOOM
	#define DYNZOOM_FACTOR		global.DYNZOOM_FACTOR



#define DO_ALT_BLANK		global.DO_ALT_BLANK
	#define ALT_BLANK_STRENGTH	global.ALT_BLANK_STRENGTH
	#define ALT_BLANK_PERIOD	global.ALT_BLANK_PERIOD


#define DO_GLOBAL_SHZO	global.DO_GLOBAL_SHZO
	#define GLOBAL_ZOOM	global.GLOBAL_ZOOM
	#define GLOBAL_OFFX	global.GLOBAL_OFFX
	#define GLOBAL_OFFY	global.GLOBAL_OFFY
