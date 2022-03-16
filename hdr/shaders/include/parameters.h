

#pragma parameter hcrt_title                         "SONY PVM/BVM HDR SHADER"                                   0.0      0.0   0.0001   0.0
#pragma parameter hcrt_space0                        " "                                                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_support0                      "SUPPORTED: RGB/BGR LCD, QD-OLED Displays"                  0.0      0.0   0.0001   0.0
#pragma parameter hcrt_support1                      "NOT SUPPORTED: WRGB OLED Displays"                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_support2                      "MIN SPEC: DisplayHDR 600, 4K, RetroArch v1.10"             0.0      0.0   0.0001   0.0
#pragma parameter hcrt_support3                      "REC SPEC: DisplayHDR 1000, 4K+, RetroArch v1.10"           0.0      0.0   0.0001   0.0
#pragma parameter hcrt_space1                        " "                                                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_instructions0                 "HDR: Enable HDR: On"                                       0.0      0.0   0.0001   0.0
#pragma parameter hcrt_instructions1                 "SCALING: Integer Scale: ON"                                0.0      0.0   0.0001   0.0
#pragma parameter hcrt_instructions2                 "SCALING: Integer Overscale: ON"                            0.0      0.0   0.0001   0.0
#pragma parameter hcrt_instructions3                 "SCALING: Apect Ratio: Core Provided"                       0.0      0.0   0.0001   0.0
#pragma parameter hcrt_space2                        " "                                                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_user_settings                 "USER SETTINGS:"                                            0.0      0.0   0.0001   0.0
#pragma parameter hcrt_hdr                           "    HDR | SDR"                                             0.0      0.0   1.0      1.0
#pragma parameter hcrt_max_nits                      "    HDR: Display's Peak Luminance"                         700.0    0.0   10000.0  10.0
#pragma parameter hcrt_paper_white_nits              "    HDR: Display's Paper White Luminance"                  700.0    0.0   10000.0  10.0
#pragma parameter hcrt_colour_space                  "    SDR: Display's Colour Space: sRGB | DCI-P3"            0.0      0.0   1.0      1.0
#pragma parameter hcrt_lcd_resolution                "    Display's Resolution: 4K | 8K"                         0.0      0.0   1.0      1.0
#pragma parameter hcrt_lcd_subpixel                  "    Display's Subpixel Layout: RGB | BGR"                  0.0      0.0   1.0      1.0
#pragma parameter hcrt_red_vertical_convergence      "    Red Vertical Convergence"                              0.00     -10.0 10.0     0.01
#pragma parameter hcrt_green_vertical_convergence    "    Green Vertical Convergence"                            0.00     -10.0 10.0     0.01
#pragma parameter hcrt_blue_vertical_convergence     "    Blue Vertical Convergence"                             0.00     -10.0 10.0     0.01
#pragma parameter hcrt_red_horizontal_convergence    "    Red Horizontal Convergence"                            0.00     -10.0 10.0     0.01
#pragma parameter hcrt_green_horizontal_convergence  "    Green Horizontal Convergence"                          0.00     -10.0 10.0     0.01
#pragma parameter hcrt_blue_horizontal_convergence   "    Blue Horizontal Convergence"                           0.00     -10.0 10.0     0.01

#pragma parameter hcrt_space3                        " "                                                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_developer_settings            "DEVELOPER SETTINGS:"                                       0.0      0.0   0.0001   0.0
#pragma parameter hcrt_crt_screen_type               "    CRT Type: APERTURE GRILLE | SHADOW MASK | SLOT MASK"   0.0      0.0   2.0      1.0
#pragma parameter hcrt_crt_resolution                "    CRT Resolution: 600TVL | 800TVL | 1000TVL"             0.0      0.0   2.0      1.0
#pragma parameter hcrt_colour_system                 "    CRT Colour System: PAL | NTSC-U | NTSC-J"              1.0      0.0   2.0      1.0
#pragma parameter hcrt_white_temperature             "    White Point: (PAL:D65, NTSC-U:D65, NTSC-J:D93)"        0.0      -5000.0  12000.0      100.0
#pragma parameter hcrt_expand_gamut                  "    HDR: Original/Vivid"                                   0.0      0.0   1.0      1.0
#pragma parameter hcrt_brightness                    "    Brightness"                                            0.0      -1.0  1.0      0.01
#pragma parameter hcrt_contrast                      "    Contrast"                                              0.0      -1.0  1.0      0.01
#pragma parameter hcrt_saturation                    "    Saturation"                                            0.0      -1.0   1.0     0.01
#pragma parameter hcrt_gamma                         "    Gamma"                                                 0.0      -1.0   1.0     0.01

#pragma parameter hcrt_developer_settings0           "    VERTICAL SETTINGS:"                                    0.0      0.0   0.0001   0.0
#pragma parameter hcrt_red_scanline_min              "        Red Scanline Min"                                  0.50     0.0   2.0      0.01 
#pragma parameter hcrt_red_scanline_max              "        Red Scanline Max"                                  1.00     0.0   2.0      0.01 
#pragma parameter hcrt_red_scanline_attack           "        Red Scanline Attack"                               0.20     0.0   1.0      0.01
#pragma parameter hcrt_green_scanline_min            "        Green Scanline Min"                                0.50     0.0   2.0      0.01 
#pragma parameter hcrt_green_scanline_max            "        Green Scanline Max"                                1.00     0.0   2.0      0.01 
#pragma parameter hcrt_green_scanline_attack         "        Green Scanline Attack"                             0.20     0.0   1.0      0.01
#pragma parameter hcrt_blue_scanline_min             "        Blue Scanline Min"                                 0.50     0.0   2.0      0.01 
#pragma parameter hcrt_blue_scanline_max             "        Blue Scanline Max"                                 1.00     0.0   2.0      0.01 
#pragma parameter hcrt_blue_scanline_attack          "        Blue Scanline Attack"                              0.20     0.0   1.0      0.01
#pragma parameter hcrt_developer_settings1           "    HORIZONTAL SETTINGS:"                                  0.0      0.0   0.0001   0.0
#pragma parameter hcrt_red_beam_sharpness            "        Red Beam Sharpness"                                1.75     0.0   5.0      0.05
#pragma parameter hcrt_red_beam_attack               "        Red Beam Attack"                                   0.50     0.0   2.0      0.01
#pragma parameter hcrt_green_beam_sharpness          "        Green Beam Sharpness"                              1.75     0.0   5.0      0.05
#pragma parameter hcrt_green_beam_attack             "        Green Beam Attack"                                 0.50     0.0   2.0      0.01
#pragma parameter hcrt_blue_beam_sharpness           "        Blue Beam Sharpness"                               1.75     0.0   5.0      0.05
#pragma parameter hcrt_blue_beam_attack              "        Blue Beam Attack"                                  0.50     0.0   2.0      0.01


