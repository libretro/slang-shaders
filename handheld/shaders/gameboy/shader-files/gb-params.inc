// GAME BOY DOT MATRIX SHADER v1.4 - Shared Parameters

#pragma parameter GAMEBOY_SHADER 				"=== GAME BOY DOT MATRIX SHADER v1.4 ===" 0.0 0.0 1.0 1.0
#pragma parameter NOTE1 						" *  Turn OFF Settings > Video > Scaling > Integer Scale" 0.0 0.0 1.0 1.0
#pragma parameter NOTE2 						" *  Turn OFF Core > Interframe Blending" 0.0 0.0 1.0 1.0
#pragma parameter NOTE3 						" *  Turn ON Core > Color Correction" 0.0 0.0 1.0 1.0

#pragma parameter integer_mode 					"== SCALE == (0=Full, 1=Pixel Perfect, 2=Scale factor)" 0.0 0.0 2.0 1.0
#pragma parameter video_scale 					"      ↳ Scale factor" 5.0 3.0 15.0 1.0

#pragma parameter color_toggle 					"== COLOR == (Grayscale / Color)" 0.0 0.0 1.0 1.0
#pragma parameter palette 						"     ↳ Palette (0=IMG, 1/2=Pocket, 3=B&W, 4/7=DMG, 5/6=Light)" 0.0 0.0 7.0 1.0
#pragma parameter grey_balance 					"      ↳ Contrast wheel" 3.0 0.05 10.0 0.05
#pragma parameter contrast 						"      ↳ Alpha" 0.95 0.0 1.0 0.05

#pragma parameter brightness_mode 				"== TRANSPARENCY == (Simple / Perceptual)" 0.0 0.0 1.0 1.0
#pragma parameter alpha_reference_scale 		"      ↳ Grid density" 6.0 3.0 15.0 1.0
#pragma parameter baseline_alpha 				"      ↳ Base pixel transparency" 0.10 0.0 1.0 0.01
#pragma parameter pixel_opacity 				"      ↳ Pixel opacity" 1.0 0.01 1.0 0.01
#pragma parameter blending_mode 				"      ↳ Pixel blending (Grid only / All pixels)" 0.0 0.0 1.0 1.0
#pragma parameter adjacent_texel_alpha_blending "          ↳ Blend amount" 0.1755 0.0 0.25 0.05

#pragma parameter sharp_mode 					"== FULLSCREEN PIXELS == (Soft / Sharp)" 1.0 0.0 1.0 1.0
#pragma parameter NOTE4							"  *  Soft, circular pixels = less grid distortion" 0.0 0.0 1.0 1.0
#pragma parameter fullscreen_match_pixel_size 	"      ↳ Pixel size (Manual / Auto)" 1.0 0.0 1.0 1.0
#pragma parameter pixel_size 					"          ↳ Size" 0.8 0.2 1.10 0.05
#pragma parameter auto_soften 					"      ↳ Pixel softness (Fixed / Adaptive)"  0.0 0.0 1.0 1.0
#pragma parameter NOTE5							"       *  Adaptive reduces distortion" 0.0 0.0 1.0 1.0
#pragma parameter pixel_softness 				"          ↳ Base softness" 1.0 0.20 5.0 0.05
#pragma parameter pixel_shape 					"      ↳ Pixel shape (Circle / Rectangle)" 1.0 0.0 1.30 0.05
#pragma parameter sharpening_amount 			"      ↳ Pixel edge sharpness" 1.0 0.0 1.0 0.05

#pragma parameter LCD_EFFECTS 					"== LCD EFFECTS ==" 0.0 0.0 1.0 1.0
#pragma parameter response_time 				"      ↳ Latency" 0.0 0.0 0.777 0.111
#pragma parameter screen_light 					"      ↳ Screen light" 1.0 0.0 2.0 0.05
#pragma parameter bg_smoothing 					"      ↳ Background texture smoothing" 0.75 0.0 1.0 0.05

#pragma parameter shadow_enable 				"== SHADOWS == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter shadow_motion 				"      ↳ Motion (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter shadow_max_offset 			"          ↳ Max offset" 2.50 0.0 30.0 0.5
#pragma parameter shadow_opacity 				"      ↳ Opacity" 0.55 0.01 1.0 0.01
#pragma parameter shadow_offset_x 				"      ↳ X offset" 2.0 -5.0 5.0 0.5
#pragma parameter shadow_offset_y 				"      ↳ Y offset" 2.0 -5.0 5.0 0.5
#pragma parameter shadow_blur_amount 			"      ↳ Blur" 1.0 0.0 3.0 0.05

#pragma parameter SCREEN_POSITIONING 			"== SCREEN OFFSET ==" 0.0 0.0 1.0 1.0
#pragma parameter screen_offset_x 				"      ↳ X offset" 0.0 -5.0 5.0 1.0
#pragma parameter screen_offset_y 				"      ↳ Y offset" 0.0 -5.0 5.0 1.0


const float max_adjacent_alpha_blend = 0.25; 	// Shared cap: four neighbors can contribute at most 1.0 alpha.
#define shadow_reference_scale 5.0