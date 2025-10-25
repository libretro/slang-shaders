// GAME BOY DOT MATRIX SHADER v1.1 - Shared Parameters

// Display mode
#pragma parameter integer_mode "== Display mode == (0=Full, 1=Pixel Perfect, 2=Scale factor)" 0.0 0.0 2.0 1.0
#pragma parameter video_scale "     ↳ Integer scale factor" 5.0 2.0 15.0 1.0

// Color & Palette
#pragma parameter color_toggle "== Color mode == (0=Grayscale, 1=Color)" 0.0 0.0 1.0 1.0
#pragma parameter palette "     ↳ Palette (0=IMG, 1/2=Pocket, 3=B&W, 4=DMG, 5/6=Light)" 0.0 0.0 6.0 1.0
#pragma parameter grey_balance "     ↳ Grey balance" 3.0 0.0 4.0 0.1
#pragma parameter contrast "     ↳ Contrast" 0.95 0.0 1.0 0.05

// Pixel transparency
#pragma parameter brightness_mode "== Pixel transparency detection == (0=Simple, 1=Perceptual)" 0.0 0.0 1.0 1.0
#pragma parameter baseline_alpha "     ↳ Base pixel transparency" 0.10 0.0 1.0 0.01
#pragma parameter pixel_opacity "     ↳ Pixel opacity" 1.0 0.01 1.0 0.01

// Pixel blending
#pragma parameter blending_mode "== Pixel blending mode == (0=Blend gaps, 1=Blend all)" 0.0 0.0 1.0 1.0
#pragma parameter adjacent_texel_alpha_blending "     ↳ Blend amount" 0.1755 0.0 1.0 0.05

// Fullscreen pixel appearance
#pragma parameter sharp_mode "== Fullscreen pixel appearance == (0=Softer, 1=Sharper)" 1.0 0.0 1.0 1.0
#pragma parameter NOTE4 " *  TIP: Adjust these settings to fix grid distortion" 0.0 0.0 1.0 1.0
#pragma parameter NOTE5 " *  Soft pixels / sharp pixels + circles = less distortion" 0.0 0.0 1.0 1.0
#pragma parameter pixel_softness "     ↳ Pixel softness (higher = less distortion)" 1.0 0.20 5.0 0.05
#pragma parameter pixel_shape "     ↳ Pixel shape [Sharp mode only] (Circle/Rectangle)" 1.0 0.0 1.30 0.05
#pragma parameter sharpening_amount "     ↳ Sharpening amount" 1.0 0.0 1.0 0.05
#pragma parameter pixel_size "     ↳ Pixel size" 0.80 0.2 1.10 0.05

// LCD effects
#pragma parameter LCD_EFFECTS "== LCD effects ==" 0.0 0.0 1.0 1.0
#pragma parameter response_time "     ↳ Latency" 0.0 0.0 0.777 0.111
#pragma parameter screen_light "     ↳ Screen light" 1.0 0.0 2.0 0.05
#pragma parameter bg_smoothing "     ↳ Background texture smoothing" 0.75 0.0 1.0 0.05

// Drop shadows
#pragma parameter shadow_enable "== Drop shadows == (OFF/ON)" 1.0 0.0 1.0 1.0
#pragma parameter shadow_opacity "     ↳ Shadow opacity" 0.55 0.01 1.0 0.01
#pragma parameter shadow_offset_x "     ↳ Shadow offset horizontal" 1.0 -5.0 5.0 0.5
#pragma parameter shadow_offset_y "     ↳ Shadow offset vertical" 1.0 -5.0 5.0 0.5
#pragma parameter shadow_scale "     ↳ Scale with display output (OFF/ON)" 1.0 0.0 1.0 1.0

// Screen positioning
#pragma parameter SCREEN_POSITIONING "== Screen position ==" 0.0 0.0 1.0 1.0
#pragma parameter screen_offset_x "     ↳ Screen offset horizontal" 0.0 -5.0 5.0 1.0
#pragma parameter screen_offset_y "     ↳ Screen offset vertical" 0.0 -5.0 5.0 1.0