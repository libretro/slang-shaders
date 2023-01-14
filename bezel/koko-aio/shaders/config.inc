	//Consider content interlaced if lines are more than this
#define MIN_LINES_INTERLACED 380

	//Sort of dithering used in vignette, spot, backlight leds
#define NOISEPOWER ((params.OutputSize.z)*3)

	//Bezel reflection area size in relation to the game frame
	//Use the lowest possible value for best performance
	//It is also used to compute wrap/repeated coordinates.
#define BEZEL_REFLECTION_AREA_SIZE 0.175

	// 0.0-1.0: sensitivity to scene change (ambilike stuff), 0.0 changes more
#define AMBI_SCENE_CHG_THRSHLD 0.07  
	
	// The following will allow to sample at reduced interval
	// The scene change detection logic will take advantage of it
	// So that quick fades will still be treated as scene changes
#define AMBI_AVGLUM_DIVIDER 4

	// The following defines the speed of the color fades 
	// when changing scene. (range 0..1)
	// It is wise to correlate it with avglum_divider
	// try between (1/avglum_divider) and (1/avglum_divider)/3
#define AMBI_FAST_STEP 0.125 

	//Setting the glow/halo sharpness parameter to this
	//will skip the blurring phase and lowers the gpu use
	//Set this to the same value as used for the maximum
	//of IN_GLOW_W/H, HALO_W/H
#define GLOW_SHARP_MAX 7	        

	//Setting glow to blur bias parameter to this
	//will skip the glow/blur mix codem and just return
	//the blurred image
	//Set this to the same value as used for the maximum
	//of IN_GLOW_BIAS
#define IN_GLOW_BIAS_MAX 2.0

#define eps 1e-5
#define pi 3.141592654
#define TAU  6.28318530717958647693
#define alpha_mark 0.1


layout(push_constant) uniform Push {
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	vec4 final_passSize;
	uint FrameCount;

	float SCANLINE_DARK;
	float VMASK_OVERWHITE ;
	float VMASK_DARKLINE_SCALE;
	float VMASK_GAP;
	float VMASK_USE_GM;
	float DRKLN_OVERWHITE ;
	float DARKLINES_VOFFSET ;
	float DARKLINES_PERIOD ;
	float HALO_W ;
	float HALO_H ;
	float HALO_POWER ;
	float HALO_GAMMA ;
	float HALO_VS_SCAN ;
	float DO_BLOOM ; //4
 	float BLOOM_QUALITY ; //1

} params;

layout(std140, set = 0, binding = 0) uniform UBO {
	mat4 MVP;
	
	vec4 FinalViewportSize;
	vec4 in_glow_passSize;
	vec4 FXAA_passSize;
	//vec4 main_passSize;
	//vec4 monitor_bodySize;
	//vec4 bgSize;
	vec4 avglum_passSize;
	vec4 first_passSize;

	float DO_SCANLINES;
	float DO_IN_GLOW;
	float DO_VMASK_AND_DARKLINES ;
	float MASK_COMPENSATION ;
	float DO_HALO ;
	float DO_CCORRECTION;
	float DO_ALT_BLANK;
	float IN_GLOW_BIAS ;
	float SCANLINES_BLEEDING ;
	float IN_GLOW_W;
	float IN_GLOW_H;
	float IN_GLOW_POWER;
	float IN_GLOW_GAMMA;
	float BLOOM_MIX;
 	float BLOOM_SIZE;
	float BLOOM_GAMMA;
	float BLOOM_BYPASS;
	float BLOOM_POWER;
	float BLOOM_OVER_WHITE;
  	float BLOOM_GAMMA_OUT;
  	float ALT_BLANK_STRENGTH;
  	float ALT_BLANK_PERIOD;
	float DO_FXAA;
	float DO_SAT_BLEED;
	float SAT_BLEED_SIZE_LEFT;
	float SAT_BLEED_SIZE_RIGHT;
	float SAT_BLEED_FALLOFF;
	float SAT_BLEED_STRENGTH;
	float SAT_BLEED_PAL;
	float DO_NTSC_ARTIFACTS;
	float NTSC_FILTER_WIDTH;
	float NTSC_FILTER_SCF;
	float NTSC_FILTER_FC;
	float NTSC_MIX;
	float NTSC_PHASE_SHIFT;
	//float NTSC_DOT_CRAWL;
	float SCANLINE_FLICKERING ; //2
	float SCANLINE_FLICKERING_POWER;
	float SCANLINE_DISABLE_ON_INTERLACE;
	float SCANLINE_COMPENSATION;
	float SCANLINE_SM_STRENGTH;
	float SCANLINE_SM_TYPE;
	float SCANLINE_SM_VOFFSET;
	float RGB_MASK_STRENGTH;
	float DARKLINES_STRENGTH;
	float GAMMA_OUT ; //1
	float SATURATION;
	float LUMINANCE;
	float CONTRAST;
	float BRIGHTNESS;
	float TEMPERATURE;
	
	float DO_CURVATURE;

	float GEOM_WARP_X;
	float GEOM_WARP_Y;
	float GEOM_CORNER_SIZE;
	float GEOM_CORNER_SMOOTH;

	float DO_BEZEL;
	float BEZEL_R;
	float BEZEL_G;
	float BEZEL_B;
	float BEZEL_CON;
	float BEZEL_INNER_ZOOM;
	float BEZEL_IMAGE_BORDER;
	float BEZEL_REFL_ZOOM;
	float BEZEL_FRAME_ZOOM;

	float DO_SPOT;
	float S_POSITION; 
	float S_SIZE;
	float S_POWER;
	float S_BYPASS;

	float DO_VIGNETTE;
	float V_SIZE;
	float V_POWER;
	float V_BYPASS;

	float DO_DYNZOOM;
	float DYNZOOM_FACTOR;
	
	float DO_AMBILIGHT;
	float AMBI_FALLOFF;
	float AMBI_POWER;
	float ASPECT_X;
	float ASPECT_Y;
	float AMBI_STEPS;
	
	float DO_BG_IMAGE;
	float BG_IMAGE_OVER;
	float BG_IMAGE_OFFY;
	float BG_IMAGE_OFFX;
	float BG_IMAGE_ZOOM;
	float BG_IMAGE_ROTATION;
	
	float DO_SHIFT_RGB;
	float SHIFT_R;
	float SHIFT_G;
	float SHIFT_B;
	float OFFSET_STRENGTH;
	
} global;

// Color correction
#pragma parameter DO_CCORRECTION "★ Color corrections enable? ==>" 		0.0 	0.0 1.0 1.0
#pragma parameter LUMINANCE       "        Luminance push (>1.0=clip)"		0.0	 0.0 1.5 0.05
#pragma parameter SATURATION     "        Saturation in   (1.0=off)"		1.0	0.0  2.0 0.01
#pragma parameter CONTRAST       "        Contrast in     (0.0=off)"		0.0	-1.0 1.0 0.01
#pragma parameter BRIGHTNESS     "        Brightness in   (0.0=off)"		0.0	-1.0 1.0 0.01
#pragma parameter TEMPERATURE    "        Temperature in (6500=off)"		6500.0	3000 10000.0 50.0
#pragma parameter GAMMA_OUT      "        Gamma out"				0.69	0.1 	9.0  0.025



// FXAA
// Apply an antialiasing filter via FXAA from Nvidia.
#pragma parameter DO_FXAA "★ FXAA enable? ==>"	0.0 	0.0 1.0 1.0

// NTSC color artifacting
#pragma parameter DO_NTSC_ARTIFACTS "★ CVBS: NTSC color artifacts enable? ==>"	0.0 	0.0 1.0 1.0
#pragma parameter NTSC_FILTER_WIDTH "        Filter width"			17.0	5.0 21.0 4.0
#pragma parameter NTSC_FILTER_SCF   "        Subcarrier Frequency"		5.30	0.0 10.0 0.01
#pragma parameter NTSC_FILTER_FC    "        Frequency cutoff"			2.5	0.1 10.0 0.1
#pragma parameter NTSC_PHASE_SHIFT  "        Phase shift"			0.0	0.0 1.0  1.0
//#pragma parameter NTSC_DOT_CRAWL    "        Dot Crawl"			1.0	0.0 1.0  1.0
#pragma parameter NTSC_MIX          "        Strength"				0.5	0.0 3.0  0.05

// YIQ/YUV bandwidth limited chroma bleeding and NTSC color artifacts.
#pragma parameter DO_SAT_BLEED "★ CVBS: Bandwidth limited chroma enable? ==>"	0.0 	0.0 1.0 1.0
#pragma parameter SAT_BLEED_PAL           "        Use PAL colorspace, not NTSC"	0.0 	 0.0 1.0 1.0
#pragma parameter SAT_BLEED_STRENGTH      "        Strength"				1.0	 0.0 5.0  0.01
#pragma parameter SAT_BLEED_SIZE_LEFT     "        Size Left"				5.0 	 1.0 40.0  1.0
#pragma parameter SAT_BLEED_SIZE_RIGHT    "        Size Right"				5.0 	 1.0 40.0  1.0
#pragma parameter SAT_BLEED_FALLOFF  	  "        Falloff"				1.7 	 1.0 2.0 0.01

//Offset RGB
#pragma parameter DO_SHIFT_RGB       "★ RGB deconvergence enable? (bad with FXAA) ==>"	0.0	 0.0 1.0 1.0
#pragma parameter OFFSET_STRENGTH "        Strength"			0.5 	 0.0 1.0 0.1
#pragma parameter SHIFT_R         "        Red offset"			-40.0 	-210.0 189.0 1
#pragma parameter SHIFT_G         "        Green offset"		40.0 	-210.0 189.0 1
#pragma parameter SHIFT_B         "        Blue offset"			3.0 	-210.0 189.0 1


// Input glowing
#pragma parameter DO_IN_GLOW               "★ Glowing Input/power enable? ==>" 					0.0	0.0 1.0 1.0
#pragma parameter IN_GLOW_POWER            "        Input signal glow strength"					0.45 	0.0 5.0 0.05
#pragma parameter IN_GLOW_W                "        Sharpness, horizontal"					2.5	0.2 7.0 0.05
#pragma parameter IN_GLOW_H                "        Sharpness, vertical"					2.5	0.2 7.0 0.05
#pragma parameter IN_GLOW_GAMMA            "        Gamma, the higher, the less the glow on dark colors"	1.0 	1.0 10.0 0.1
#pragma parameter IN_GLOW_BIAS             "        Glow to blur bias"						2.0     0.0 2.0 0.05 



// Mask
#pragma parameter DO_VMASK_AND_DARKLINES "★  RGB Masks and/or Darklines enable? ==>"         	0.0 	0.0 1.0 1.0
#pragma parameter MASK_COMPENSATION      "        Compensate for brightness loss"		0.0 	0.0 1.0 0.05
#pragma parameter VMASK_DARKLINE_SCALE   "        (HiDPI) Vmask and Darklines multiplier"	1.0  	1.0 4.0 1.0
#pragma parameter RGB_MASK_STRENGTH      "        RGB Mask Strength (0.0 to disable)"		0.75  	0.0 1.0 0.05
#pragma parameter VMASK_USE_GM           "           . (LoDPI) Green,Magenta -> BGR"	0.0  	0.0 1.0 1.0
#pragma parameter VMASK_GAP              "           . Horizontal Gap between triads"	0.0  	0.0 1.0 1.0
#pragma parameter VMASK_OVERWHITE        "           . Affect bright colors"		1.0 	0.0 1.0 0.05

#pragma parameter DARKLINES_STRENGTH     "        Darklines strength (0.0 to disable)"				0.65 	0.0 1.0   0.05
#pragma parameter DARKLINES_VOFFSET      "           . Offset"							1.0 	0.0 1.0   1.0
#pragma parameter DARKLINES_PERIOD       "           . Height"							4.0 	2.0 16.0  2.0
#pragma parameter DRKLN_OVERWHITE        "           . Affect bright colors"					1.0 	0.0 1.0   0.05



// Halo
#pragma parameter DO_HALO       "★ Halo enable? ==>" 						0.0	0.0 1.0 1.0
#pragma parameter HALO_POWER    "        Strength"						0.9 	0.0  5.0 0.025
#pragma parameter HALO_W        "        Sharpness, horizontal"					1.75	0.2  7.0 0.05
#pragma parameter HALO_H        "        Sharpness, Vertical"					1.75	0.2  7.0 0.05
#pragma parameter HALO_GAMMA    "        Gamma, the higher, the less the halo on dark colors"	2.0 	1.0  10.0 0.1
#pragma parameter HALO_VS_SCAN  "        Light up scanlines too"				0.0	0.0  1.0  0.1


// Scanlines
#pragma parameter DO_SCANLINES	         "★ Scanlines enable? ==>"						0.0 	0.0  1.0 1.0
#pragma parameter SCANLINE_DARK          "        Scanlines gap brightness"			  		0.0 	-0.5 1.0 0.05
#pragma parameter SCANLINE_COMPENSATION  "        Compensate for brightness loss"				0.0	0.0 1.0 0.1
#pragma parameter SCANLINES_BLEEDING     "        Scanlines bleeding"						0.0 	0.0 3.0 0.05
#pragma parameter SCANLINE_FLICKERING    "        Interlace Flicker (0=off,1=on,2=if interlaced)"		2.0 	0.0 2.0 1.0
#pragma parameter SCANLINE_FLICKERING_POWER     "        Interlace Flicker power"		  		0.75 	0.0 4.0 0.1
#pragma parameter SCANLINE_DISABLE_ON_INTERLACE "        Disable on interlaced screen"			  	0.0 	0.0 1.0 1.0
#pragma parameter SCANLINE_SM_TYPE         "        Slotmask type (disable (0) with darklines!)"		0.0 	0.0 3.0 1.0
#pragma parameter SCANLINE_SM_STRENGTH     "           . Slotmask strength (type 1 and 2 only)"			0.0 	0.0 1.0 0.05
#pragma parameter SCANLINE_SM_VOFFSET      "           . Offset (type 1 only)"					45.0 	0.0 158.0 1.0



// Bloom
#pragma parameter DO_BLOOM           "★ Bloom enable? ==>" 				0.0  0.0  1.0  1.0
#pragma parameter BLOOM_MIX          "        Final mix, (0.0=off)"			0.2 0.0 1.0  0.01
#pragma parameter BLOOM_SIZE         "        Radius"					2.0  0.25 30.0 0.25
#pragma parameter BLOOM_QUALITY      "        Quality: more is better but slower"	1.0  1.0 32.0 1.0
#pragma parameter BLOOM_GAMMA        "        Input Gamma"				10.0  1.0 10.0 0.1
#pragma parameter BLOOM_POWER        "        Power multiplier"				10.0  1.0 100.0 0.5
#pragma parameter BLOOM_GAMMA_OUT    "        Output Gamma"				10.0  0.1 10.0 0.1
#pragma parameter BLOOM_OVER_WHITE   "        Strength on bright areas (0 = aura)"	0.5  0.0 1.0  0.05
#pragma parameter BLOOM_BYPASS       "        Bypass"					0.0  0.0 1.0  1.0



//Curvature parameters:
#pragma parameter DO_CURVATURE	     "★ Curvature enable? ==>"			0.0   0.0 1.0 1.0
#pragma parameter GEOM_WARP_X        "        Warp X"				0.3  0.0 6.0 0.05
#pragma parameter GEOM_WARP_Y        "        Warp Y"				0.0   0.0 6.0 0.05
#pragma parameter GEOM_CORNER_SIZE   "        Corner radius"			0.01  0.01 0.1 0.005
#pragma parameter GEOM_CORNER_SMOOTH "        Corner sharpness"			350.0 50.0 1000.0 25.0



//Bezel related
#pragma parameter DO_BEZEL	     "★ Bezel enable? ==>"			0.0   0.0 1.0 1.0
#pragma parameter BEZEL_R            "        Bezel color: Red"			-0.3   -0.5 0.5  0.01
#pragma parameter BEZEL_G            "        Bezel color: Green"		-0.3   -0.5 0.5  0.01
#pragma parameter BEZEL_B            "        Bezel color: Blue"		-0.3   -0.5 0.5  0.01
#pragma parameter BEZEL_CON          "        Bezel Contrast"			1.3   0.0  10.0 0.01
#pragma parameter BEZEL_INNER_ZOOM   "        Image zoom"			-0.18   -1.5 0.5 0.01
#pragma parameter BEZEL_FRAME_ZOOM   "        Frame zoom"			0.0   -1.5 0.5 0.01
#pragma parameter BEZEL_IMAGE_BORDER "        Image border"			1.01   1.0 1.2 0.01
#pragma parameter BEZEL_REFL_ZOOM    "        Reflections zoom"			0.965   0.0 2.0 0.005


//Background Image
#pragma parameter DO_BG_IMAGE	 "★ Backgound image enable? ==>"			0.0  0.0  1.0     1.0
#pragma parameter LABEL_WARNING1 "    ⚠ RetroArch aspect needs to be set to Full! ⚠"	1.0  1.0  1.0     1.0
#pragma parameter BG_IMAGE_OVER	 "        Image over content (alpha channel driven)?"	0.0  0.0  1.0     1.0
#pragma parameter BG_IMAGE_OFFX	 "        Shift Image over X axis"			0.0  -1.0  1.0    0.0005
#pragma parameter BG_IMAGE_OFFY	 "        Shift Image over Y axis"			0.0  -1.0  1.0    0.0005
#pragma parameter BG_IMAGE_ZOOM	 "        Zoom Image"					1.0  -1.0  3.0    0.0005
#pragma parameter BG_IMAGE_ROTATION "        Rotate image mode (-1 for auto)"	     	-1.0  -1.0  2.0    1.0



//Back leds
//Emulates leds under the monitor frame that slowly reacts to image contents
#pragma parameter DO_AMBILIGHT	 "★ Ambient light leds enable? ==> "					1.0  0.0  1.0     1.0
#pragma parameter LABEL_WARNING3 "    ⚠ RetroArch aspect needs to be set to Full! ⚠"			1.0  1.0  1.0     1.0
#pragma parameter LABEL_WARNING4 "    ⚠ Resize the window once if you see glitches! ⚠"			1.0  1.0  1.0     1.0
#pragma parameter AMBI_STEPS	 "        Slowness"							60.0 5.0  1000.0  5.0
#pragma parameter AMBI_FALLOFF   "        Light Falloff"						0.7  0.1  3.0     0.01
#pragma parameter AMBI_POWER     "        Led power"							1.5  1.0  7.0     0.05



//Aspect Ratio
#pragma parameter label_ar	 "★ Aspect Ratio "							0.0  0.0  1.0     1.0
#pragma parameter ASPECT_X       "        Aspect Ratio Numerator (-x for a preset below)"   		0.0  -6.0 256. 1.0
#pragma parameter ASPECT_Y       "        Aspect Ratio Denominator"	  				3.0   0.0 256. 1.0
#pragma parameter label_aspect_presets "        Presets reference list:" 0.0 0.0 0.0 1.0
#pragma parameter label_aspect_preset0 "          (0 =  MAME 1.33)" 0.0 0.0 0.0 1.0
#pragma parameter label_aspect_preset1 "          (-1 = NTSC 1.5)" 0.0 0.0 0.0 1.0
#pragma parameter label_aspect_preset2 "          (-2 = PAL 1.25)" 0.0 0.0 0.0 1.0
#pragma parameter label_aspect_preset3 "          (-3 = Snes 8/7)" 0.0 0.0 0.0 1.0
#pragma parameter label_aspect_preset4 "          (-4 = Megadrive 10/7)" 0.0 0.0 0.0 1.0
#pragma parameter label_aspect_preset5 "          (-5 = Uncorrected)" 0.0 0.0 0.0 1.0
#pragma parameter label_aspect_preset6 "          (-6 = MAME rotated/TATE 0.75)" 0.0 0.0 0.0 1.0



//Full screen glowing
//Modulate the image zooming depending on the image luminosity.
//You can lower the effect power through the DYNZOOM_FACTOR parameter.
#pragma parameter DO_DYNZOOM	     "★ Luminosity dependant zoom enable? ==>"		1.0   0.0   1.0  1.0
#pragma parameter DYNZOOM_FACTOR     "        Narrowness"				80.0  30.0  120.0 1.0



//Vignette and spot
#pragma parameter DO_VIGNETTE	"★ Vignette enable? ==>"	0.0  0.0  1.0  1.0
#pragma parameter V_BYPASS	"        bypass "	        0.0  0.0  1.0  1.0
#pragma parameter V_SIZE	"        size"			1.7  0.0  3.0  0.05
#pragma parameter V_POWER	"        power"			1.1  0.05 2.0  0.05

#pragma parameter DO_SPOT	"★ Spot enable? ==>"		0.0   0.0   1.0 1.0
#pragma parameter S_BYPASS	"        bypass"	        0.0   0.0   1.0 1.0
#pragma parameter S_POSITION 	"        Position"		0.0   -420.0 378.0 1
#pragma parameter S_SIZE	"        size"			0.4   0.0  1.0 0.01
#pragma parameter S_POWER	"        power" 		0.1  0.05  2.0 0.05



// Alternative blanking.
#pragma parameter DO_ALT_BLANK       "★ Alternate line blanking enable? ==>"			0.0 0.0 1.0 1.0
#pragma parameter ALT_BLANK_STRENGTH "        Alternate black frame insertion strength" 	0.5 0.0 1.0 0.1
#pragma parameter ALT_BLANK_PERIOD   "        Blank lines period" 				4.0 0.0 20.0 1.0






#define DO_FXAA        	global.DO_FXAA

#define DO_SAT_BLEED            global.DO_SAT_BLEED
#define SAT_BLEED_SIZE_LEFT     global.SAT_BLEED_SIZE_LEFT
#define SAT_BLEED_SIZE_RIGHT    global.SAT_BLEED_SIZE_RIGHT
#define SAT_BLEED_FALLOFF       global.SAT_BLEED_FALLOFF
#define SAT_BLEED_STRENGTH      global.SAT_BLEED_STRENGTH
#define SAT_BLEED_PAL           global.SAT_BLEED_PAL

#define DO_NTSC_ARTIFACTS global.DO_NTSC_ARTIFACTS
#define NTSC_FILTER_WIDTH global.NTSC_FILTER_WIDTH
#define NTSC_FILTER_SCF   global.NTSC_FILTER_SCF
#define NTSC_FILTER_FC    global.NTSC_FILTER_FC
#define NTSC_MIX          global.NTSC_MIX
#define NTSC_PHASE_SHIFT  global.NTSC_PHASE_SHIFT
//#define NTSC_DOT_CRAWL    global.NTSC_DOT_CRAWL

#define DO_SCANLINES                  global.DO_SCANLINES
#define SCANLINE_DARK                 params.SCANLINE_DARK
#define SCANLINE_OVERWHITE            global.SCANLINE_OVERWHITE
#define SCANLINE_FLICKERING           global.SCANLINE_FLICKERING
#define SCANLINE_FLICKERING_POWER     global.SCANLINE_FLICKERING_POWER
#define SCANLINE_DISABLE_ON_INTERLACE global.SCANLINE_DISABLE_ON_INTERLACE
#define SCANLINE_COMPENSATION         global.SCANLINE_COMPENSATION
#define SCANLINE_SM_TYPE              global.SCANLINE_SM_TYPE
#define SCANLINE_SM_STRENGTH          global.SCANLINE_SM_STRENGTH
#define SCANLINE_SM_VOFFSET           global.SCANLINE_SM_VOFFSET 

#define DO_IN_GLOW               global.DO_IN_GLOW
#define IN_GLOW_BIAS             global.IN_GLOW_BIAS
#define SCANLINES_BLEEDING       global.SCANLINES_BLEEDING
#define IN_GLOW_W                global.IN_GLOW_W
#define IN_GLOW_H                global.IN_GLOW_H
#define IN_GLOW_POWER            global.IN_GLOW_POWER
#define IN_GLOW_GAMMA            global.IN_GLOW_GAMMA

#define DO_VMASK_AND_DARKLINES  global.DO_VMASK_AND_DARKLINES
#define MASK_COMPENSATION	global.MASK_COMPENSATION
#define RGB_MASK_STRENGTH       global.RGB_MASK_STRENGTH
#define VMASK_OVERWHITE         params.VMASK_OVERWHITE
#define VMASK_DARKLINE_SCALE    params.VMASK_DARKLINE_SCALE
#define VMASK_GAP               params.VMASK_GAP
#define VMASK_USE_GM            params.VMASK_USE_GM

#define DARKLINES_STRENGTH   global.DARKLINES_STRENGTH
#define DRKLN_OVERWHITE      params.DRKLN_OVERWHITE
#define DARKLINES_VOFFSET    params.DARKLINES_VOFFSET
#define DARKLINES_PERIOD     params.DARKLINES_PERIOD

#define DO_HALO       global.DO_HALO
#define HALO_W        params.HALO_W
#define HALO_H        params.HALO_H
#define HALO_POWER    params.HALO_POWER
#define HALO_GAMMA    params.HALO_GAMMA
#define HALO_VS_SCAN  params.HALO_VS_SCAN

#define DO_BLOOM           params.DO_BLOOM
#define BLOOM_MIX          global.BLOOM_MIX
#define BLOOM_QUALITY      params.BLOOM_QUALITY
#define BLOOM_SIZE         global.BLOOM_SIZE
#define BLOOM_GAMMA        global.BLOOM_GAMMA
#define BLOOM_POWER        global.BLOOM_POWER
#define BLOOM_GAMMA_OUT    global.BLOOM_GAMMA_OUT
#define BLOOM_OVER_WHITE   global.BLOOM_OVER_WHITE
#define BLOOM_BYPASS       global.BLOOM_BYPASS


#define DO_CCORRECTION global.DO_CCORRECTION
#define GAMMA_OUT      global.GAMMA_OUT
#define SATURATION     global.SATURATION
#define LUMINANCE       global.LUMINANCE
#define CONTRAST       global.CONTRAST
#define BRIGHTNESS     global.BRIGHTNESS
#define TEMPERATURE    global.TEMPERATURE

#define DO_ALT_BLANK       global.DO_ALT_BLANK
#define ALT_BLANK_STRENGTH global.ALT_BLANK_STRENGTH
#define ALT_BLANK_PERIOD global.ALT_BLANK_PERIOD


#define DO_CURVATURE       global.DO_CURVATURE
#define GEOM_WARP_X        global.GEOM_WARP_X
#define GEOM_WARP_Y        global.GEOM_WARP_Y
#define GEOM_CORNER_SIZE   global.GEOM_CORNER_SIZE
#define GEOM_CORNER_SMOOTH global.GEOM_CORNER_SMOOTH


#define DO_BEZEL           global.DO_BEZEL
#define BEZEL_R            global.BEZEL_R
#define BEZEL_G            global.BEZEL_G
#define BEZEL_B            global.BEZEL_B
#define BEZEL_CON          global.BEZEL_CON
#define BEZEL_INNER_ZOOM   global.BEZEL_INNER_ZOOM
#define BEZEL_FRAME_ZOOM   global.BEZEL_FRAME_ZOOM
#define BEZEL_IMAGE_BORDER global.BEZEL_IMAGE_BORDER
#define BEZEL_REFL_ZOOM    global.BEZEL_REFL_ZOOM

#define DO_SPOT    global.DO_SPOT
#define S_BYPASS   global.S_BYPASS
#define S_POSITION global.S_POSITION
#define S_SIZE     global.S_SIZE
#define S_POWER    global.S_POWER

#define DO_DYNZOOM      global.DO_DYNZOOM
#define DYNZOOM_FACTOR  global.DYNZOOM_FACTOR

#define DO_VIGNETTE  global.DO_VIGNETTE
#define V_BYPASS     global.V_BYPASS
#define V_SIZE       global.V_SIZE
#define V_POWER      global.V_POWER

#define DO_AMBILIGHT global.DO_AMBILIGHT
#define AMBI_STEPS   global.AMBI_STEPS
#define AMBI_FALLOFF global.AMBI_FALLOFF
#define AMBI_POWER   global.AMBI_POWER
#define ASPECT_X     global.ASPECT_X
#define ASPECT_Y     global.ASPECT_Y

#define DO_BG_IMAGE        global.DO_BG_IMAGE
#define BG_IMAGE_OVER      global.BG_IMAGE_OVER
#define BG_IMAGE_OFFY      global.BG_IMAGE_OFFY
#define BG_IMAGE_OFFX      global.BG_IMAGE_OFFX
#define BG_IMAGE_ZOOM      global.BG_IMAGE_ZOOM
#define BG_IMAGE_ROTATION  global.BG_IMAGE_ROTATION

#define DO_SHIFT_RGB      global.DO_SHIFT_RGB
#define SHIFT_R           global.SHIFT_R
#define SHIFT_G           global.SHIFT_G
#define SHIFT_B           global.SHIFT_B
#define OFFSET_STRENGTH   global.OFFSET_STRENGTH
