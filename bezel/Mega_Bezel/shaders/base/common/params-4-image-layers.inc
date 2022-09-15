/*
    Mega Bezel - Creates a graphic treatment for the game play area to give a retro feel
    Copyright (C) 2019-2022 HyperspaceMadness - HyperspaceMadness@outlook.com

    Incorporates much great feedback from the libretro forum, and thanks 
    to Hunterk who helped me get started

    See more at the libretro forum
    https://forums.libretro.com/t/hsm-mega-bezel-reflection-shader-feedback-and-updates

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see [http://www.gnu.org/licenses/].
*/

#define HAS_IMAGE_LAYER_PARAMS

//---------------------------------------------------------------------------------------------------
//    IMAGE LAYERING START
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_LAYER_ORDER_TITLE			  "[ LAYER ORDER ]:" 0 0 0.01 0.01

#pragma parameter HSM_BG_LAYER_ORDER              "          Background Image"  0 0 12 1
float HSM_BG_LAYER_ORDER = global.HSM_BG_LAYER_ORDER;

#pragma parameter HSM_VIEWPORT_VIGNETTE_LAYER_ORDER "          Viewport Vignette"  1 0 12 1
float HSM_VIEWPORT_VIGNETTE_LAYER_ORDER = global.HSM_VIEWPORT_VIGNETTE_LAYER_ORDER;

#pragma parameter HSM_LED_LAYER_ORDER             "          LED Image"  2 0 12 1
float HSM_LED_LAYER_ORDER = global.HSM_LED_LAYER_ORDER;

#pragma parameter HSM_DEVICE_LAYER_ORDER         "          Device Image"  3 0 12 1
float HSM_DEVICE_LAYER_ORDER = global.HSM_DEVICE_LAYER_ORDER;

#pragma parameter HSM_CRT_LAYER_ORDER             "          CRT Screen Bezel & Frame"  5 0 12 1
float HSM_CRT_LAYER_ORDER = global.HSM_CRT_LAYER_ORDER;

#pragma parameter HSM_DECAL_LAYER_ORDER           "          DECAL Image"  7 0 12 1
float HSM_DECAL_LAYER_ORDER = global.HSM_DECAL_LAYER_ORDER;

#pragma parameter HSM_CAB_GLASS_LAYER_ORDER       "          Cabinet Glass Image"  9 0 12 1
float HSM_CAB_GLASS_LAYER_ORDER = global.HSM_CAB_GLASS_LAYER_ORDER;

#pragma parameter HSM_TOP_LAYER_ORDER             "          Top Image"  12 0 12 1
float HSM_TOP_LAYER_ORDER = global.HSM_TOP_LAYER_ORDER;


//---------------------------------------------------------------------------------------------------
//    CutOut in Image Layers
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_CUTOUT_TITLE			    "[ CUTOUT ]:" 0 0 0.01 0.01

#pragma parameter HSM_CUTOUT_ASPECT_MODE      "         Cutout Aspect- FULL | EXPL. | 4:3 | 3:4 | 16:9 | 9:16" 4 0 5 1
float HSM_CUTOUT_ASPECT_MODE = global.HSM_CUTOUT_ASPECT_MODE;

#pragma parameter HSM_CUTOUT_EXPLICIT_ASPECT  "          Explicit Aspect" 1.33333 0.01 3 0.01
float HSM_CUTOUT_EXPLICIT_ASPECT = global.HSM_CUTOUT_EXPLICIT_ASPECT;

#pragma parameter HSM_CUTOUT_SCALE_MODE               " Inherit Scale - FULL | TUBE | BZL | BG | DEVICE | DECAL"  0 0 5 1
float HSM_CUTOUT_SCALE_MODE = global.HSM_CUTOUT_SCALE_MODE;

#pragma parameter HSM_CUTOUT_SCALE_FULL_WITH_ZOOM     "          Zoom FULL Scale Mode" 1 0 1 1
float HSM_CUTOUT_SCALE_FULL_WITH_ZOOM = global.HSM_CUTOUT_SCALE_FULL_WITH_ZOOM;

#pragma parameter HSM_CUTOUT_KEEP_ASPECT        "        Scale Aspect - INHERIT FROM SCALE MODE | KEEP ASPECT"  1 0 1 1
float HSM_CUTOUT_KEEP_ASPECT = global.HSM_CUTOUT_KEEP_ASPECT;

#pragma parameter HSM_CUTOUT_SCALE 				"          Scale" 100 -100 200 0.1
float HSM_CUTOUT_SCALE = global.HSM_CUTOUT_SCALE / 100;

#pragma parameter HSM_CUTOUT_SCALE_X 		    "          Scale X" 100 -100 200 0.1
float HSM_CUTOUT_SCALE_X = global.HSM_CUTOUT_SCALE_X / 100;

#pragma parameter HSM_CUTOUT_POS_X 		        "          Position XY" 0 -100 200 0.05
float HSM_CUTOUT_POS_X = global.HSM_CUTOUT_POS_X / -100;

#pragma parameter HSM_CUTOUT_POS_Y 		        "          Position Y" 0 -100 200 0.05
float HSM_CUTOUT_POS_Y = global.HSM_CUTOUT_POS_Y / 100;

#pragma parameter HSM_CUTOUT_CORNER_RADIUS 		"          Corner Radius - Def 0" 0 0 70 1
float HSM_CUTOUT_CORNER_RADIUS = global.HSM_CUTOUT_CORNER_RADIUS;


//---------------------------------------------------------------------------------------------------
//    MASK DEBUG
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_MASK_DEBUG_TITLE			"[ MASK DEBUG ]:" 0 0 0.01 0.01

#pragma parameter HSM_LAYERING_DEBUG_MASK_MODE    "    Mask - ALL | SCRN | TUBE | BZ- | BZ | BZ+ | FRM | FRM+ | BG" -1 -2 8 1
float HSM_LAYERING_DEBUG_MASK_MODE = global.HSM_LAYERING_DEBUG_MASK_MODE;

//---------------------------------------------------------------------------------------------------
//    BG IMAGE
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_BACKGROUND_TITLE			"[ BACKGROUND LAYER ]:" 0 0 0.01 0.01

#pragma parameter HSM_BG_OPACITY                  "          Opacity" 100 0 100 0.1
float HSM_BG_OPACITY = global.HSM_BG_OPACITY / 100;

#pragma parameter HSM_BG_COLORIZE_ON              "          Colorize On" 0 0 1 1
float HSM_BG_COLORIZE_ON = global.HSM_BG_COLORIZE_ON;

#pragma parameter HSM_BG_HUE                       "          Hue Offset" 0 0 360 1
float HSM_BG_HUE = global.HSM_BG_HUE / 360;

#pragma parameter HSM_BG_SATURATION                "          Saturation" 100 0 200 1
float HSM_BG_SATURATION = global.HSM_BG_SATURATION / 100;

#pragma parameter HSM_BG_BRIGHTNESS                "          Brightness" 100 0 200 1
float HSM_BG_BRIGHTNESS = global.HSM_BG_BRIGHTNESS / 100;

#pragma parameter HSM_BG_GAMMA                     "          Gamma Adjust" 1 0 5 0.01
float HSM_BG_GAMMA = global.HSM_BG_GAMMA;

#pragma parameter HSM_BG_AMBIENT_LIGHTING_MULTIPLIER         "          Ambient Lighting Multiplier"  0 0 100 1
float HSM_BG_AMBIENT_LIGHTING_MULTIPLIER = global.HSM_BG_AMBIENT_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_BG_AMBIENT2_LIGHTING_MULTIPLIER         "          Ambient 2nd Image Lighting Multiplier"  100 0 100 1
float HSM_BG_AMBIENT2_LIGHTING_MULTIPLIER = global.HSM_BG_AMBIENT2_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_BG_APPLY_AMBIENT_IN_ADD_MODE         "          Apply Ambient Lighting in ADD Blend Mode"  0 0 1 1
float HSM_BG_APPLY_AMBIENT_IN_ADD_MODE = global.HSM_BG_APPLY_AMBIENT_IN_ADD_MODE;

#pragma parameter HSM_BG_BLEND_MODE               "          Blend Mode - OFF | NORMAL | ADD | MULTIPLY"  1 -1 3 1
float HSM_BG_BLEND_MODE = global.HSM_BG_BLEND_MODE;

#pragma parameter HSM_BG_SOURCE_MATTE_TYPE        "          Source Matte Color - BLACK | WHITE | NONE"  0 0 2 1
float HSM_BG_SOURCE_MATTE_TYPE = global.HSM_BG_SOURCE_MATTE_TYPE;

#pragma parameter HSM_BG_MASK_MODE                "    Mask - ALL | SCRN | TUBE | BZ- | BZ | BZ+ | FRM | FRM+ | BG" 0 0 8 1
float HSM_BG_MASK_MODE = global.HSM_BG_MASK_MODE;

#pragma parameter HSM_BG_CUTOUT_MODE              "          Cutout Mask - OFF | ON | INVERT" 0 0 2 1
float HSM_BG_CUTOUT_MODE = global.HSM_BG_CUTOUT_MODE;

#pragma parameter HSM_BG_DUALSCREEN_VIS_MODE      "          Dual Screen Visibility - BOTH | SCREEN 1 | SCREEN 2" 0 0 2 1
float HSM_BG_DUALSCREEN_VIS_MODE = global.HSM_BG_DUALSCREEN_VIS_MODE;

#pragma parameter HSM_BG_SCALE_MODE               "          Inherit Scale - FULL | TUBE | BEZEL" 0 0 2 1
float HSM_BG_SCALE_MODE = global.HSM_BG_SCALE_MODE;

#pragma parameter HSM_BG_SCALE_FULL_WITH_ZOOM     "          Zoom FULL Scale Mode" 1 0 1 1
float HSM_BG_SCALE_FULL_WITH_ZOOM = global.HSM_BG_SCALE_FULL_WITH_ZOOM;

#pragma parameter HSM_BG_SCALE_KEEP_ASPECT        "        Scale Aspect - INHERIT FROM SCALE MODE | USE TEX ASPECT"  1 0 1 1
float HSM_BG_SCALE_KEEP_ASPECT = global.HSM_BG_SCALE_KEEP_ASPECT;

#pragma parameter HSM_BG_FILL_MODE                "          Image Fill Mode - STRETCH | SPLIT HORIZONTAL"  0 0 1 1
float HSM_BG_FILL_MODE = global.HSM_BG_FILL_MODE;

#pragma parameter HSM_BG_SPLIT_PRESERVE_CENTER    "          Split Mode Preserve Center %"  0 0 500 1
float HSM_BG_SPLIT_PRESERVE_CENTER = global.HSM_BG_SPLIT_PRESERVE_CENTER / 1000;

#pragma parameter HSM_BG_SPLIT_REPEAT_WIDTH       "          Split Mode Repeat Width %"  0 0 100 1
float HSM_BG_SPLIT_REPEAT_WIDTH = global.HSM_BG_SPLIT_REPEAT_WIDTH / 1000;

#pragma parameter HSM_BG_SCALE                    "          Scale" 100 0 1000 0.1
float HSM_BG_SCALE = global.HSM_BG_SCALE / 100;

#pragma parameter HSM_BG_SCALE_X                  "          Scale X" 100 0 1000 0.1
float HSM_BG_SCALE_X = global.HSM_BG_SCALE_X / 100;

#pragma parameter HSM_BG_POS_X                    "          Position X"  0 -1000 1000 0.05
float HSM_BG_POS_X = global.HSM_BG_POS_X / -100;

#pragma parameter HSM_BG_POS_Y                    "          Position Y"  0 -1000 1000 0.05
float HSM_BG_POS_Y = global.HSM_BG_POS_Y / 100;

#pragma parameter HSM_BG_MIRROR_WRAP              "          Mirror Wrap" 1 0 1 1
float HSM_BG_MIRROR_WRAP = global.HSM_BG_MIRROR_WRAP;

#pragma parameter HSM_BG_MIPMAPPING_BLEND_BIAS    "          Mipmapping Blend Bias" 0 -5 5 0.1
float HSM_BG_MIPMAPPING_BLEND_BIAS = global.HSM_BG_MIPMAPPING_BLEND_BIAS;



//---------------------------------------------------------------------------------------------------
//    VIEWPORT VIGNETTE
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_VIEWPORT_VIGNETTE_TITLE		"[ VIEWPORT VIGNETTE LAYER ]:" 0 0 0.01 0.01

#pragma parameter HSM_VIEWPORT_VIGNETTE_OPACITY     "          Opacity" 0 0 100 2
float HSM_VIEWPORT_VIGNETTE_OPACITY = global.HSM_VIEWPORT_VIGNETTE_OPACITY / 100;

#pragma parameter HSM_VIEWPORT_VIGNETTE_MASK_MODE   "Mask - ALL | SCRN | TUBE | BZ- | BZ | BZ+ | FRM | FRM+ | BG" 5 0 8 1
float HSM_VIEWPORT_VIGNETTE_MASK_MODE = global.HSM_VIEWPORT_VIGNETTE_MASK_MODE;

#pragma parameter HSM_VIEWPORT_VIGNETTE_CUTOUT_MODE  "          Cutout Mask - OFF | ON | INVERT" 0 0 2 1
float HSM_VIEWPORT_VIGNETTE_CUTOUT_MODE = global.HSM_VIEWPORT_VIGNETTE_CUTOUT_MODE;

#pragma parameter HSM_VIEWPORT_VIGNETTE_SCALE_MODE   "          Inherit Scale- FULL | BG | TUBE | BZL" 0 0 5 1
float HSM_VIEWPORT_VIGNETTE_SCALE_MODE = global.HSM_VIEWPORT_VIGNETTE_SCALE_MODE;

#pragma parameter HSM_VIEWPORT_VIGNETTE_SCALE        "          Scale" 100 0 1000 0.1
float HSM_VIEWPORT_VIGNETTE_SCALE = global.HSM_VIEWPORT_VIGNETTE_SCALE / 100;

#pragma parameter HSM_VIEWPORT_VIGNETTE_SCALE_X      "          Scale X" 100 0 1000 0.1
float HSM_VIEWPORT_VIGNETTE_SCALE_X = global.HSM_VIEWPORT_VIGNETTE_SCALE_X / 100;

#pragma parameter HSM_VIEWPORT_VIGNETTE_POS_X        "          Position X"  0 -1000 1000 0.05
float HSM_VIEWPORT_VIGNETTE_POS_X = global.HSM_VIEWPORT_VIGNETTE_POS_X / -100;

#pragma parameter HSM_VIEWPORT_VIGNETTE_POS_Y        "          Position Y"  0 -1000 1000 0.05
float HSM_VIEWPORT_VIGNETTE_POS_Y = global.HSM_VIEWPORT_VIGNETTE_POS_Y / 100;


//---------------------------------------------------------------------------------------------------
//    LED IMAGE
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_LED_TITLE		                "[ LED LAYER ]:" 0 0 0.01 0.01

#pragma parameter HSM_LED_OPACITY                   "          Opacity"  100 0 100 1
float HSM_LED_OPACITY = global.HSM_LED_OPACITY / 100;

#pragma parameter HSM_LED_COLORIZE_ON               "          Colorize" 0 0 1 1
float HSM_LED_COLORIZE_ON = global.HSM_LED_COLORIZE_ON;

#pragma parameter HSM_LED_HUE                       "          Hue Offset" 0 0 360 1
float HSM_LED_HUE = global.HSM_LED_HUE / 360;

#pragma parameter HSM_LED_SATURATION                "          Saturation" 100 0 200 1
float HSM_LED_SATURATION = global.HSM_LED_SATURATION / 100;

#pragma parameter HSM_LED_BRIGHTNESS                "          Brightness" 100 0 200 1
float HSM_LED_BRIGHTNESS = global.HSM_LED_BRIGHTNESS / 100;

#pragma parameter HSM_LED_GAMMA                     "          Gamma Adjust" 1 0 5 0.01
float HSM_LED_GAMMA = global.HSM_LED_GAMMA;

#pragma parameter HSM_LED_AMBIENT_LIGHTING_MULTIPLIER   "          Ambient Lighting Multiplier"  100 0 100 1
float HSM_LED_AMBIENT_LIGHTING_MULTIPLIER = global.HSM_LED_AMBIENT_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_LED_AMBIENT2_LIGHTING_MULTIPLIER         "          Ambient 2nd Image Lighting Multiplier"  0 0 100 1
float HSM_LED_AMBIENT2_LIGHTING_MULTIPLIER = global.HSM_LED_AMBIENT2_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_LED_APPLY_AMBIENT_IN_ADD_MODE     "          Apply Ambient Lighting in ADD Blend Mode"  0 0 1 1
float HSM_LED_APPLY_AMBIENT_IN_ADD_MODE = global.HSM_LED_APPLY_AMBIENT_IN_ADD_MODE;

#pragma parameter HSM_LED_BLEND_MODE                    "          Blend Mode - OFF | NORMAL | ADD | MULTIPLY"  2 0 3 1
float HSM_LED_BLEND_MODE = global.HSM_LED_BLEND_MODE;

#pragma parameter HSM_LED_SOURCE_MATTE_TYPE             "          Source Matte Color - BLACK | WHITE | NONE"  0 0 2 1
float HSM_LED_SOURCE_MATTE_TYPE = global.HSM_LED_SOURCE_MATTE_TYPE;

#pragma parameter HSM_LED_MASK_MODE                     "    Mask - ALL | SCRN | TUBE | BZ- | BZ | BZ+ | FRM | FRM+ | BG"   0 0 8 1
float HSM_LED_MASK_MODE = global.HSM_LED_MASK_MODE;

#pragma parameter HSM_LED_CUTOUT_MODE                   "          Cutout Mask - OFF | ON | INVERT" 0 0 2 1
float HSM_LED_CUTOUT_MODE = global.HSM_LED_CUTOUT_MODE;

#pragma parameter HSM_LED_DUALSCREEN_VIS_MODE           "          Dual Screen Visibility - BOTH | SCREEN 1 | SCREEN 2" 0 0 2 1
float HSM_LED_DUALSCREEN_VIS_MODE = global.HSM_LED_DUALSCREEN_VIS_MODE;

#pragma parameter HSM_LED_SCALE_MODE                    "       Inherit Scale - FULL | TUBE | BEZEL | BG | DEVICE"  3 0 4 1
float HSM_LED_SCALE_MODE = global.HSM_LED_SCALE_MODE;

#pragma parameter HSM_LED_SCALE_FULL_WITH_ZOOM          "          Zoom FULL Scale Mode" 1 0 1 1
float HSM_LED_SCALE_FULL_WITH_ZOOM = global.HSM_LED_SCALE_FULL_WITH_ZOOM;

#pragma parameter HSM_LED_SCALE_KEEP_ASPECT             "        Scale Aspect - INHERIT FROM SCALE MODE | USE TEX ASPECT"  1 0 1 1
float HSM_LED_SCALE_KEEP_ASPECT = global.HSM_LED_SCALE_KEEP_ASPECT;

#pragma parameter HSM_LED_FILL_MODE                     "          Image Fill Mode - STRETCH | SPLIT HORIZONTAL"  0 0 1 1
float HSM_LED_FILL_MODE = global.HSM_LED_FILL_MODE;

#pragma parameter HSM_LED_SPLIT_PRESERVE_CENTER         "          Split Mode Preserve Center %"  0 0 500 1
float HSM_LED_SPLIT_PRESERVE_CENTER = global.HSM_LED_SPLIT_PRESERVE_CENTER / 1000;

#pragma parameter HSM_LED_SPLIT_REPEAT_WIDTH            "          Split Mode Repeat Width %"  0 0 100 1
float HSM_LED_SPLIT_REPEAT_WIDTH = global.HSM_LED_SPLIT_REPEAT_WIDTH / 1000;

#pragma parameter HSM_LED_SCALE                         "          Scale" 100 0 1000 0.1
float HSM_LED_SCALE = global.HSM_LED_SCALE / 100;

#pragma parameter HSM_LED_SCALE_X                       "          Scale X" 100 0 1000 0.1
float HSM_LED_SCALE_X = global.HSM_LED_SCALE_X / 100;

#pragma parameter HSM_LED_POS_X                         "          Position X"  0 -1000 1000 0.05
float HSM_LED_POS_X = global.HSM_LED_POS_X / -100;

#pragma parameter HSM_LED_POS_Y                         "          Position Y"  0 -1000 1000 0.05
float HSM_LED_POS_Y = global.HSM_LED_POS_Y / 100;

#pragma parameter HSM_LED_MIPMAPPING_BLEND_BIAS         "          Mipmapping Blend Bias" 0 -5 5 0.1
float HSM_LED_MIPMAPPING_BLEND_BIAS = global.HSM_LED_MIPMAPPING_BLEND_BIAS;


//---------------------------------------------------------------------------------------------------
//    DEVICE IMAGE
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_DEVICE_TITLE			           "[ DEVICE IMAGE LAYER ]:" 0 0 0.01 0.01

#pragma parameter HSM_DEVICE_OPACITY                   "          Opacity" 100 0 100 1
float HSM_DEVICE_OPACITY = global.HSM_DEVICE_OPACITY / 100;

#pragma parameter HSM_DEVICE_COLORIZE_ON               "          Colorize" 0 0 1 1
float HSM_DEVICE_COLORIZE_ON = global.HSM_DEVICE_COLORIZE_ON;

#pragma parameter HSM_DEVICE_HUE                       "          Hue Offset" 0 0 360 1
float HSM_DEVICE_HUE = global.HSM_DEVICE_HUE / 360;

#pragma parameter HSM_DEVICE_SATURATION                "          Saturation" 100 0 200 1
float HSM_DEVICE_SATURATION = global.HSM_DEVICE_SATURATION / 100;

#pragma parameter HSM_DEVICE_BRIGHTNESS                "          Brightness" 100 0 200 1
float HSM_DEVICE_BRIGHTNESS = global.HSM_DEVICE_BRIGHTNESS / 100;

#pragma parameter HSM_DEVICE_GAMMA                     "          Gamma Adjust" 1 0 5 0.01
float HSM_DEVICE_GAMMA = global.HSM_DEVICE_GAMMA;

#pragma parameter HSM_DEVICE_AMBIENT_LIGHTING_MULTIPLIER         "          Ambient Lighting Multiplier"  100 0 100 1
float HSM_DEVICE_AMBIENT_LIGHTING_MULTIPLIER = global.HSM_DEVICE_AMBIENT_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_DEVICE_AMBIENT2_LIGHTING_MULTIPLIER         "          Ambient 2nd Image Lighting Multiplier"  0 0 100 1
float HSM_DEVICE_AMBIENT2_LIGHTING_MULTIPLIER = global.HSM_DEVICE_AMBIENT2_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_DEVICE_APPLY_AMBIENT_IN_ADD_MODE         "          Apply Ambient Lighting in ADD Blend Mode"  0 0 1 1
float HSM_DEVICE_APPLY_AMBIENT_IN_ADD_MODE = global.HSM_DEVICE_APPLY_AMBIENT_IN_ADD_MODE;

#pragma parameter HSM_DEVICE_BLEND_MODE                "          Blend Mode - OFF | NORMAL | ADD | MULTIPLY"  1 0 3 1
float HSM_DEVICE_BLEND_MODE = global.HSM_DEVICE_BLEND_MODE;

#pragma parameter HSM_DEVICE_SOURCE_MATTE_TYPE         "          Source Matte Color - BLACK | WHITE | NONE"  0 0 2 1
float HSM_DEVICE_SOURCE_MATTE_TYPE = global.HSM_DEVICE_SOURCE_MATTE_TYPE;

#pragma parameter HSM_DEVICE_MASK_MODE                 "    Mask - ALL | SCRN | TUBE | BZ- | BZ | BZ+ | FRM | FRM+ | BG" 0 0 8 1
float HSM_DEVICE_MASK_MODE = global.HSM_DEVICE_MASK_MODE;

#pragma parameter HSM_DEVICE_CUTOUT_MODE               "          Cutout Mask - OFF | ON | INVERT" 0 0 2 1
float HSM_DEVICE_CUTOUT_MODE = global.HSM_DEVICE_CUTOUT_MODE;

#pragma parameter HSM_DEVICE_DUALSCREEN_VIS_MODE           "          Dual Screen Visibility - BOTH | SCREEN 1 | SCREEN 2" 0 0 2 1
float HSM_DEVICE_DUALSCREEN_VIS_MODE = global.HSM_DEVICE_DUALSCREEN_VIS_MODE;

#pragma parameter HSM_DEVICE_SCALE_MODE                "          Inherit Scale - FULL | TUBE | BEZEL | BG"  1 0 3 1
float HSM_DEVICE_SCALE_MODE = global.HSM_DEVICE_SCALE_MODE;

#pragma parameter HSM_DEVICE_SCALE_FULL_WITH_ZOOM      "          Zoom FULL Scale Mode" 1 0 1 1
float HSM_DEVICE_SCALE_FULL_WITH_ZOOM = global.HSM_DEVICE_SCALE_FULL_WITH_ZOOM;

#pragma parameter HSM_DEVICE_COPY_INHERITED_COORD      "      Copy Inherited Coord (Keeps Curvature, No Aspect or Fill)"  0 0 1 1
float HSM_DEVICE_COPY_INHERITED_COORD = global.HSM_DEVICE_COPY_INHERITED_COORD;

#pragma parameter HSM_DEVICE_SCALE_KEEP_ASPECT         "        Scale Aspect - INHERIT FROM SCALE MODE | USE TEX ASPECT"  1 0 1 1
float HSM_DEVICE_SCALE_KEEP_ASPECT = global.HSM_DEVICE_SCALE_KEEP_ASPECT;

#pragma parameter HSM_DEVICE_FILL_MODE                 "          Image Fill Mode - STRETCH | SPLIT HORIZONTAL"  0 0 1 1
float HSM_DEVICE_FILL_MODE = global.HSM_DEVICE_FILL_MODE;

#pragma parameter HSM_DEVICE_SPLIT_PRESERVE_CENTER    "          Split Mode Preserve Center %"  0 0 500 1
float HSM_DEVICE_SPLIT_PRESERVE_CENTER = global.HSM_DEVICE_SPLIT_PRESERVE_CENTER / 1000;

#pragma parameter HSM_DEVICE_SPLIT_REPEAT_WIDTH     "          Split Mode Repeat Width %"  0 0 100 1
float HSM_DEVICE_SPLIT_REPEAT_WIDTH = global.HSM_DEVICE_SPLIT_REPEAT_WIDTH / 1000;

#pragma parameter HSM_DEVICE_SCALE                     "          Scale" 100 0 1000 0.1
float HSM_DEVICE_SCALE = global.HSM_DEVICE_SCALE / 100;

#pragma parameter HSM_DEVICE_SCALE_X                   "          Scale X" 100 0 1000 0.1
float HSM_DEVICE_SCALE_X = global.HSM_DEVICE_SCALE_X / 100;

#pragma parameter HSM_DEVICE_POS_X                     "          Position X"  0 -1000 1000 0.05
float HSM_DEVICE_POS_X = global.HSM_DEVICE_POS_X / -100;

#pragma parameter HSM_DEVICE_POS_Y                     "          Position Y"  0 -1000 1000 0.05
float HSM_DEVICE_POS_Y = global.HSM_DEVICE_POS_Y / 100;

#pragma parameter HSM_DEVICE_MIPMAPPING_BLEND_BIAS          "          Mipmapping Blend Bias" 0 -5 5 0.1
float HSM_DEVICE_MIPMAPPING_BLEND_BIAS = global.HSM_DEVICE_MIPMAPPING_BLEND_BIAS;



//---------------------------------------------------------------------------------------------------
//    DECAL IMAGE
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_DECAL_TITLE			          "[ DECAL LAYER ]:" 0 0 0.01 0.01

#pragma parameter HSM_DECAL_OPACITY                   "          Opacity"  100 0 100 0.1
float HSM_DECAL_OPACITY = global.HSM_DECAL_OPACITY / 100;

#pragma parameter HSM_DECAL_COLORIZE_ON               "          Colorize" 0 0 1 1
float HSM_DECAL_COLORIZE_ON = global.HSM_DECAL_COLORIZE_ON;

#pragma parameter HSM_DECAL_HUE                       "          Hue Offset" 0 0 360 1
float HSM_DECAL_HUE = global.HSM_DECAL_HUE / 360;

#pragma parameter HSM_DECAL_SATURATION                "          Saturation" 100 0 200 1
float HSM_DECAL_SATURATION = global.HSM_DECAL_SATURATION / 100;

#pragma parameter HSM_DECAL_BRIGHTNESS                "          Brightness" 100 0 200 1
float HSM_DECAL_BRIGHTNESS = global.HSM_DECAL_BRIGHTNESS / 100;

#pragma parameter HSM_DECAL_GAMMA               "          Gamma Adjust" 1 0 5 0.01
float HSM_DECAL_GAMMA = global.HSM_DECAL_GAMMA;

#pragma parameter HSM_DECAL_AMBIENT_LIGHTING_MULTIPLIER         "          Ambient Lighting Multiplier"  100 0 100 1
float HSM_DECAL_AMBIENT_LIGHTING_MULTIPLIER = global.HSM_DECAL_AMBIENT_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_DECAL_AMBIENT2_LIGHTING_MULTIPLIER         "          Ambient 2nd Image Lighting Multiplier"  0 0 100 1
float HSM_DECAL_AMBIENT2_LIGHTING_MULTIPLIER = global.HSM_DECAL_AMBIENT2_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_DECAL_APPLY_AMBIENT_IN_ADD_MODE         "          Apply Ambient Lighting in ADD Blend Mode"  0 0 1 1
float HSM_DECAL_APPLY_AMBIENT_IN_ADD_MODE = global.HSM_DECAL_APPLY_AMBIENT_IN_ADD_MODE;

#pragma parameter HSM_DECAL_BLEND_MODE                  "          Blend Mode -  OFF | NORMAL | ADD | MULTIPLY"  1 0 3 1
float HSM_DECAL_BLEND_MODE = global.HSM_DECAL_BLEND_MODE;

#pragma parameter HSM_DECAL_SOURCE_MATTE_TYPE           "          Source Matte Color - BLACK | WHITE | NONE"  0 0 2 1
float HSM_DECAL_SOURCE_MATTE_TYPE = global.HSM_DECAL_SOURCE_MATTE_TYPE;

#pragma parameter HSM_DECAL_MASK_MODE                   "    Mask - ALL | SCRN | TUBE | BZ- | BZ | BZ+ | FRM | FRM+ | BG"   0 0 8 1
float HSM_DECAL_MASK_MODE = global.HSM_DECAL_MASK_MODE;

#pragma parameter HSM_DECAL_CUTOUT_MODE                 "          Cutout Mask - OFF | ON | INVERT" 0 0 2 1
float HSM_DECAL_CUTOUT_MODE = global.HSM_DECAL_CUTOUT_MODE;

#pragma parameter HSM_DECAL_DUALSCREEN_VIS_MODE         "          Dual Screen Visibility - BOTH | SCREEN 1 | SCREEN 2" 0 0 2 1
float HSM_DECAL_DUALSCREEN_VIS_MODE = global.HSM_DECAL_DUALSCREEN_VIS_MODE;

#pragma parameter HSM_DECAL_SCALE_MODE                  "       Inherit Scale - FULL | TUBE | BEZEL | BG | DEVICE"  0 0 4 1
float HSM_DECAL_SCALE_MODE = global.HSM_DECAL_SCALE_MODE;

#pragma parameter HSM_DECAL_SCALE_FULL_WITH_ZOOM        "          Zoom FULL Scale Mode" 1 0 1 1
float HSM_DECAL_SCALE_FULL_WITH_ZOOM = global.HSM_DECAL_SCALE_FULL_WITH_ZOOM;

#pragma parameter HSM_DECAL_SCALE_KEEP_ASPECT           "        Scale Aspect - INHERIT FROM SCALE MODE | USE TEX ASPECT"  1 0 1 1
float HSM_DECAL_SCALE_KEEP_ASPECT = global.HSM_DECAL_SCALE_KEEP_ASPECT;

#pragma parameter HSM_DECAL_FILL_MODE                   "          Image Fill Mode - STRETCH | SPLIT HORIZONTAL"  0 0 1 1
float HSM_DECAL_FILL_MODE = global.HSM_DECAL_FILL_MODE;

#pragma parameter HSM_DECAL_SPLIT_PRESERVE_CENTER       "          Split Mode Preserve Center %"  0 0 500 1
float HSM_DECAL_SPLIT_PRESERVE_CENTER = global.HSM_DECAL_SPLIT_PRESERVE_CENTER / 1000;

#pragma parameter HSM_DECAL_SPLIT_REPEAT_WIDTH          "          Split Mode Repeat Width %"  0 0 100 1
float HSM_DECAL_SPLIT_REPEAT_WIDTH = global.HSM_DECAL_SPLIT_REPEAT_WIDTH / 1000;

#pragma parameter HSM_DECAL_SCALE                       "          Scale"  100 1 500 0.1
float HSM_DECAL_SCALE = global.HSM_DECAL_SCALE / 100;

#pragma parameter HSM_DECAL_SCALE_X                     "          Scale X"  100 50 500 0.1
float HSM_DECAL_SCALE_X = global.HSM_DECAL_SCALE_X / 100;

#pragma parameter HSM_DECAL_POS_X                       "          Position X"  0 -1000 1000 0.05
float HSM_DECAL_POS_X = global.HSM_DECAL_POS_X / -100;

#pragma parameter HSM_DECAL_POS_Y                       "          Position Y"  0 -1000 1000 0.05
float HSM_DECAL_POS_Y = global.HSM_DECAL_POS_Y / 100;

#pragma parameter HSM_DECAL_MIPMAPPING_BLEND_BIAS       "          Mipmapping Blend Bias" 0 -5 5 0.1
float HSM_DECAL_MIPMAPPING_BLEND_BIAS = global.HSM_DECAL_MIPMAPPING_BLEND_BIAS;


//---------------------------------------------------------------------------------------------------
//    CAB GLS IMAGE
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_CAB_GLASS_TITLE			            "[ CABINET OR CABINET GLASS LAYER ]:" 0 0 0.01 0.01

#pragma parameter HSM_CAB_GLASS_OPACITY                     "          Opacity" 100 0 100 1
float HSM_CAB_GLASS_OPACITY = global.HSM_CAB_GLASS_OPACITY / 100;

#pragma parameter HSM_CAB_GLASS_COLORIZE_ON               "          Colorize" 0 0 1 1
float HSM_CAB_GLASS_COLORIZE_ON = global.HSM_CAB_GLASS_COLORIZE_ON;

#pragma parameter HSM_CAB_GLASS_HUE                       "          Hue Offset" 0 0 360 1
float HSM_CAB_GLASS_HUE = global.HSM_CAB_GLASS_HUE / 360;

#pragma parameter HSM_CAB_GLASS_SATURATION                "          Saturation" 100 0 200 1
float HSM_CAB_GLASS_SATURATION = global.HSM_CAB_GLASS_SATURATION / 100;

#pragma parameter HSM_CAB_GLASS_BRIGHTNESS                  "          Brightness" 100 0 400 1
float HSM_CAB_GLASS_BRIGHTNESS = global.HSM_CAB_GLASS_BRIGHTNESS / 100;

#pragma parameter HSM_CAB_GLASS_GAMMA                     "          Gamma Adjust" 1 0 5 0.01
float HSM_CAB_GLASS_GAMMA = global.HSM_CAB_GLASS_GAMMA;

#pragma parameter HSM_CAB_GLASS_AMBIENT_LIGHTING_MULTIPLIER         "          Ambient Lighting Multiplier"  100 0 100 1
float HSM_CAB_GLASS_AMBIENT_LIGHTING_MULTIPLIER = global.HSM_CAB_GLASS_AMBIENT_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_CAB_GLASS_AMBIENT2_LIGHTING_MULTIPLIER         "          Ambient 2nd Image Lighting Multiplier"  0 0 100 1
float HSM_CAB_GLASS_AMBIENT2_LIGHTING_MULTIPLIER = global.HSM_CAB_GLASS_AMBIENT2_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_CAB_GLASS_APPLY_AMBIENT_IN_ADD_MODE         "          Apply Ambient Lighting in ADD Blend Mode"  0 0 1 1
float HSM_CAB_GLASS_APPLY_AMBIENT_IN_ADD_MODE = global.HSM_CAB_GLASS_APPLY_AMBIENT_IN_ADD_MODE;

#pragma parameter HSM_CAB_GLASS_BLEND_MODE                  "          Blend Mode - OFF | NORMAL | ADD | MULTIPLY"  1 0 3 1
float HSM_CAB_GLASS_BLEND_MODE = global.HSM_CAB_GLASS_BLEND_MODE;

#pragma parameter HSM_CAB_GLASS_SOURCE_MATTE_TYPE           "          Source Matte Color - BLACK | WHITE | NONE"  0 0 2 1
float HSM_CAB_GLASS_SOURCE_MATTE_TYPE = global.HSM_CAB_GLASS_SOURCE_MATTE_TYPE;

#pragma parameter HSM_CAB_GLASS_MASK_MODE                   "    Mask - ALL | SCRN | TUBE | BZ- | BZ | BZ+ | FRM | FRM+ | BG" 0 0 8 1
float HSM_CAB_GLASS_MASK_MODE = global.HSM_CAB_GLASS_MASK_MODE;

#pragma parameter HSM_CAB_GLASS_CUTOUT_MODE                 "          Cutout Mask - OFF | ON | INVERT" 0 0 2 1
float HSM_CAB_GLASS_CUTOUT_MODE = global.HSM_CAB_GLASS_CUTOUT_MODE;

#pragma parameter HSM_CAB_GLASS_DUALSCREEN_VIS_MODE         "          Dual Screen Visibility - BOTH | SCREEN 1 | SCREEN 2" 0 0 2 1
float HSM_CAB_GLASS_DUALSCREEN_VIS_MODE = global.HSM_CAB_GLASS_DUALSCREEN_VIS_MODE;

#pragma parameter HSM_CAB_GLASS_SCALE_MODE                  "Inherit Scale- FULL | TUBE | BEZEL | BG | DEVICE | DECAL" 0 0 5 1
float HSM_CAB_GLASS_SCALE_MODE = global.HSM_CAB_GLASS_SCALE_MODE;

#pragma parameter HSM_CAB_GLASS_SCALE_FULL_WITH_ZOOM      "          Zoom FULL Scale Mode" 1 0 1 1
float HSM_CAB_GLASS_SCALE_FULL_WITH_ZOOM = global.HSM_CAB_GLASS_SCALE_FULL_WITH_ZOOM;

#pragma parameter HSM_CAB_GLASS_SCALE_KEEP_ASPECT           "        Scale Aspect - INHERIT FROM SCALE MODE | USE TEX ASPECT"  1 0 1 1
float HSM_CAB_GLASS_SCALE_KEEP_ASPECT = global.HSM_CAB_GLASS_SCALE_KEEP_ASPECT;

#pragma parameter HSM_CAB_GLASS_FILL_MODE                   "          Image Fill Mode - STRETCH | SPLIT HORIZONTAL"  0 0 1 1
float HSM_CAB_GLASS_FILL_MODE = global.HSM_CAB_GLASS_FILL_MODE;

#pragma parameter HSM_CAB_GLASS_SPLIT_PRESERVE_CENTER       "          Split Mode Preserve Center %"  0 0 500 1
float HSM_CAB_GLASS_SPLIT_PRESERVE_CENTER = global.HSM_CAB_GLASS_SPLIT_PRESERVE_CENTER / 1000;

#pragma parameter HSM_CAB_GLASS_SPLIT_REPEAT_WIDTH          "          Split Mode Repeat Width %"  0 0 100 1
float HSM_CAB_GLASS_SPLIT_REPEAT_WIDTH = global.HSM_CAB_GLASS_SPLIT_REPEAT_WIDTH / 1000;

#pragma parameter HSM_CAB_GLASS_SCALE                       "          Scale" 100 10 500 0.1
float HSM_CAB_GLASS_SCALE = global.HSM_CAB_GLASS_SCALE / 100;

#pragma parameter HSM_CAB_GLASS_SCALE_X                     "          Scale X" 100 0 500 0.1
float HSM_CAB_GLASS_SCALE_X = global.HSM_CAB_GLASS_SCALE_X / 100;

#pragma parameter HSM_CAB_GLASS_POS_X                       "          Position X"  0 -1000 1000 0.05
float HSM_CAB_GLASS_POS_X = global.HSM_CAB_GLASS_POS_X / -100;

#pragma parameter HSM_CAB_GLASS_POS_Y                       "          Position Y"  0 -1000 1000 0.05
float HSM_CAB_GLASS_POS_Y = global.HSM_CAB_GLASS_POS_Y / 100;

#pragma parameter HSM_CAB_GLASS_MIPMAPPING_BLEND_BIAS          "          Mipmapping Blend Bias" 0 -5 5 0.1
float HSM_CAB_GLASS_MIPMAPPING_BLEND_BIAS = global.HSM_CAB_GLASS_MIPMAPPING_BLEND_BIAS;


//---------------------------------------------------------------------------------------------------
//    TOP IMAGE
//---------------------------------------------------------------------------------------------------
#pragma parameter HSM_TOP_TITLE			                "[ TOP EXTRA LAYER ]:" 0 0 0.01 0.01

#pragma parameter HSM_TOP_OPACITY                       "          Opacity"  100 0 100 0.1
float HSM_TOP_OPACITY = global.HSM_TOP_OPACITY / 100;

#pragma parameter HSM_TOP_COLORIZE_ON               "          Colorize" 0 0 1 1
float HSM_TOP_COLORIZE_ON = global.HSM_TOP_COLORIZE_ON;

#pragma parameter HSM_TOP_HUE                       "          Hue Offset" 0 0 360 1
float HSM_TOP_HUE = global.HSM_TOP_HUE / 360;

#pragma parameter HSM_TOP_SATURATION                "          Saturation" 100 0 200 1
float HSM_TOP_SATURATION = global.HSM_TOP_SATURATION / 100;

#pragma parameter HSM_TOP_BRIGHTNESS                "          Brightness" 100 0 200 1
float HSM_TOP_BRIGHTNESS = global.HSM_TOP_BRIGHTNESS / 100;

#pragma parameter HSM_TOP_GAMMA                     "          Gamma Adjust" 1 0 5 0.01
float HSM_TOP_GAMMA = global.HSM_TOP_GAMMA;

#pragma parameter HSM_TOP_AMBIENT_LIGHTING_MULTIPLIER   "          Ambient Lighting Multiplier"  100 0 100 1
float HSM_TOP_AMBIENT_LIGHTING_MULTIPLIER = global.HSM_TOP_AMBIENT_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_TOP_AMBIENT2_LIGHTING_MULTIPLIER  "          Ambient 2nd Image Lighting Multiplier"  0 0 100 1
float HSM_TOP_AMBIENT2_LIGHTING_MULTIPLIER = global.HSM_TOP_AMBIENT2_LIGHTING_MULTIPLIER / 100;

#pragma parameter HSM_TOP_APPLY_AMBIENT_IN_ADD_MODE     "          Apply Ambient Lighting in ADD Blend Mode"  0 0 1 1
float HSM_TOP_APPLY_AMBIENT_IN_ADD_MODE = global.HSM_TOP_APPLY_AMBIENT_IN_ADD_MODE;

#pragma parameter HSM_TOP_BLEND_MODE                    "          Blend Mode - OFF | NORMAL | ADD | MULTIPLY"  1 0 3 1
float HSM_TOP_BLEND_MODE = global.HSM_TOP_BLEND_MODE;

#pragma parameter HSM_TOP_SOURCE_MATTE_TYPE             "          Source Matte Color - BLACK | WHITE | NONE"  0 0 2 1
float HSM_TOP_SOURCE_MATTE_TYPE = global.HSM_TOP_SOURCE_MATTE_TYPE;

#pragma parameter HSM_TOP_MASK_MODE                     "    Mask - ALL | SCRN | TUBE | BZ- | BZ | BZ+ | FRM | FRM+ | BG"   0 0 8 1
float HSM_TOP_MASK_MODE = global.HSM_TOP_MASK_MODE;

#pragma parameter HSM_TOP_CUTOUT_MODE                   "          Cutout Mask - OFF | ON | INVERT" 0 0 2 1
float HSM_TOP_CUTOUT_MODE = global.HSM_TOP_CUTOUT_MODE;

#pragma parameter HSM_TOP_DUALSCREEN_VIS_MODE           "          Dual Screen Visibility - BOTH | SCREEN 1 | SCREEN 2" 0 0 2 1
float HSM_TOP_DUALSCREEN_VIS_MODE = global.HSM_TOP_DUALSCREEN_VIS_MODE;

#pragma parameter HSM_TOP_SCALE_MODE                    "Inherit Scale- FULL | TUBE | BEZEL | BG | DEVICE | DECAL" 0 0 5 1
float HSM_TOP_SCALE_MODE = global.HSM_TOP_SCALE_MODE;

#pragma parameter HSM_TOP_SCALE_FULL_WITH_ZOOM      "          Zoom FULL Scale Mode" 1 0 1 1
float HSM_TOP_SCALE_FULL_WITH_ZOOM = global.HSM_TOP_SCALE_FULL_WITH_ZOOM;

#pragma parameter HSM_TOP_SCALE_KEEP_ASPECT             "        Scale Aspect - INHERIT FROM SCALE MODE | USE TEX ASPECT"  1 0 1 1
float HSM_TOP_SCALE_KEEP_ASPECT = global.HSM_TOP_SCALE_KEEP_ASPECT;

#pragma parameter HSM_TOP_FILL_MODE                     "          Image Fill Mode - STRETCH | SPLIT HORIZONTAL"  0 0 1 1
float HSM_TOP_FILL_MODE = global.HSM_TOP_FILL_MODE;

#pragma parameter HSM_TOP_SPLIT_PRESERVE_CENTER       "          Split Mode Preserve Center %"  0 0 500 1
float HSM_TOP_SPLIT_PRESERVE_CENTER = global.HSM_TOP_SPLIT_PRESERVE_CENTER / 1000;

#pragma parameter HSM_TOP_SPLIT_REPEAT_WIDTH            "          Split Mode Repeat Width %"  0 0 100 1
float HSM_TOP_SPLIT_REPEAT_WIDTH = global.HSM_TOP_SPLIT_REPEAT_WIDTH / 1000;

#pragma parameter HSM_TOP_SCALE                         "          Scale" 100 0 1000 0.1
float HSM_TOP_SCALE = global.HSM_TOP_SCALE / 100;

#pragma parameter HSM_TOP_SCALE_X                       "          Scale X" 100 0 1000 0.1
float HSM_TOP_SCALE_X = global.HSM_TOP_SCALE_X / 100;

#pragma parameter HSM_TOP_POS_X                         "          Position X"  0 -1000 1000 0.05
float HSM_TOP_POS_X = global.HSM_TOP_POS_X / -100;

#pragma parameter HSM_TOP_POS_Y                         "          Position Y"  0 -1000 1000 0.05
float HSM_TOP_POS_Y = global.HSM_TOP_POS_Y / 100;

#pragma parameter HSM_TOP_MIRROR_WRAP                   "          Mirror Wrap" 1 0 1 1
float HSM_TOP_MIRROR_WRAP = global.HSM_TOP_MIRROR_WRAP;

#pragma parameter HSM_TOP_MIPMAPPING_BLEND_BIAS         "          Mipmapping Blend Bias" 0 -5 5 0.1
float HSM_TOP_MIPMAPPING_BLEND_BIAS = global.HSM_TOP_MIPMAPPING_BLEND_BIAS;


#pragma parameter HSM_RENDER_FOR_SIMPLIFIED_TITLE       "[ RENDER FOR SIMPLIFIED PRESETS ]:" 1 0 1 1

#pragma parameter HSM_RENDER_SIMPLE_MODE                "     Mode:  NORM | BLACK-SCREEN | BLACK-BG | PINK-MASK| BW-MASK" 0 0 4 1
float HSM_RENDER_SIMPLE_MODE = global.HSM_RENDER_SIMPLE_MODE;

#pragma parameter HSM_RENDER_SIMPLE_MASK_TYPE           "      Mask Type:  SCREEN | TUBE | BEZEL & FRAME | BEZEL | FRAME" 0 0 4 1
float HSM_RENDER_SIMPLE_MASK_TYPE = global.HSM_RENDER_SIMPLE_MASK_TYPE;
