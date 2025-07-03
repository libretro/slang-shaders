#pragma parameter ubo_nonono           "[ UBORDER USER PARAMS ]"                  1.0  0.0   1.0 1.0

#pragma parameter frame_nonono         "FRAME:"                                   0.0    0.0   1.0 1.0
#pragma parameter fr_aspect_x          "    Set Aspect Ratio Numerator"           8.0    1.0  32.0 0.02
#pragma parameter fr_aspect_y          "    Set Aspect Ratio Denominator"         6.0    1.0  32.0 0.02
#pragma parameter fr_zoom              "    Zoom %"                              50.0    2.0 200.0 0.1
#pragma parameter fr_i_scaling         "    Use Integer Scaling for Y"            0.0    0.0   1.0 1.0
#pragma parameter fr_i_scaling_fac     "    Integer Scaling Factor [ - / + ]"     0.0  -20.0   1.0 1.0
#pragma parameter fr_center_x          "    Center X"                             0.0 -200.0 200.0 0.1
#pragma parameter fr_center_y          "    Center Y"                             0.0 -200.0 200.0 0.1

#pragma parameter all_nonono           "ALL:"                                     0.0    0.0   1.0 1.0
#pragma parameter all_zoom             "    Zoom %"                             100.0   20.0 200.0 1.0

//#ifdef USE_BEZEL_REFLECTIONS_COMMON
#pragma parameter bz_nonono            "BEZEL:"                                   0.0   0.0   1.0  1.0
#pragma parameter bz_lights            "    Lights  [ OUT | ON ]"                 1.0   0.0   1.0  1.0
#pragma parameter bz_shine_enable      "    Shine   [ OFF | ON ]"                 1.0   0.0   1.0  1.0
#pragma parameter bz_ambient_enable    "    Ambient [ OFF | ON ]"                 1.0   0.0   1.0  1.0
#pragma parameter bz_blur_iter         "    Reflection Quality/Performance"       5.0   5.0  32.0  1.0
#pragma parameter bz_ref_str           "    Reflection Strength"                  0.25  0.0   1.0  0.01
#pragma parameter bz_inner_bezel_x     "    Bezel Inner Width"                    0.1   0.0   1.0  0.001
#pragma parameter bz_inner_bezel_y     "    Bezel Inner Height"                   0.1   0.0   1.0  0.001
#pragma parameter bz_middle_bezel_x    "    Bezel Middle Width"                   0.2   0.0   1.0  0.001
#pragma parameter bz_middle_bezel_y    "    Bezel Middle Height"                  0.2   0.0   1.0  0.001
#pragma parameter bz_outer_bezel_x     "    Bezel Outer Width"                    0.3   0.0   1.0  0.001
#pragma parameter bz_outer_bezel_y     "    Bezel Outer Height"                   0.3   0.0   1.0  0.001
#pragma parameter bz_transparent       "    Bezel Transparent [ OFF | ON ]"       0.0   0.0   1.0  1.0
#pragma parameter bz_outer_transparent "    Bezel Outer Transparent [ OFF | ON ]" 0.0   0.0   1.0  1.0
#pragma parameter bz_outer_curve       "    Bezel Outer Curvature [ OFF | ON ]"   0.0   0.0   1.0  1.0
#pragma parameter bz_curve_radius      "    Bezel Curvature Modifier"             0.0 -10.0  10.0  0.1
#pragma parameter bz_radius            "    Bezel Corner Radius"                  0.05  0.005 1.0  0.01
#pragma parameter bz_inner_curve       "    Bezel Inner Curvature [ OFF | ON ]"   1.0   0.0   1.0  1.0
#pragma parameter bz_in_curve_radius   "    Bezel Inner Curvature Modifier"       0.0 -10.0  10.0  0.1
#pragma parameter bz_center_x          "    Bezel Center X"                       0.0 -200.0 200.0 0.1
#pragma parameter bz_center_y          "    Bezel Center Y"                       0.0 -200.0 200.0 0.1
#pragma parameter bz_red               "    Bezel Color - Red"                  128.0   0.0 255.0  1.0
#pragma parameter bz_green             "    Bezel Color - Green"                128.0   0.0 255.0  1.0
#pragma parameter bz_blue              "    Bezel Color - Blue"                 128.0   0.0 255.0  1.0
#pragma parameter bz_ref_dist          "    Reflection Distance"                  0.0  -0.6   0.6  0.001
#pragma parameter bz_shine             "    Shine Intensity"                      0.25  0.0   1.0  0.01
#pragma parameter bz_shine_size        "    Shine Size"                           0.75  0.0   1.0  0.01
#pragma parameter bz_ambient           "    Ambient Intensity"                    0.15  0.0   1.0  0.01
#pragma parameter bz_ambient_size      "    Ambient Size"                         0.85  0.0   1.0  0.01
#pragma parameter bz_ang               "    Inflec. Point Angle"                  1.0   0.0  20.0  0.01
#pragma parameter bz_pos               "    Inflec. Point Position"               0.0 -20.0  20.0  0.002

#pragma parameter border_nonono        "BORDER:"                                  0.0  0.0 1.0 1.0
#pragma parameter ub_border_top        "    On top: [ Frame | Border ]"           0.0  0.0 1.0 1.0
#pragma parameter border_scale         "    Border Scale"                         1.0  0.5 5.0 0.002
#pragma parameter border_center_x      "    Border Center X"                      0.0 -0.5 0.5 0.001
#pragma parameter border_center_y      "    Border Center Y"                      0.0 -0.5 0.5 0.001
#pragma parameter border_mirror_y      "    Border Mirrored"                      0.0  0.0 1.0 1.0
#pragma parameter border_allow_rot     "    Border Rotation [ 0 <--> 270 ]"       0.0  0.0 3.0 1.0
#pragma parameter border_alpha         "    Border Alpha Over Content (BAOC)"     0.0  0.0 1.0 0.01
#pragma parameter black_baoc           "    (BAOC) Emphasis on Content"           0.0  0.0 1.0 1.0
#pragma parameter border_weight        "    Border to Ambient-Light Weight"       0.5  0.0 1.0 0.05
#pragma parameter border_dimming       "    Border Dimming (Lights OUT)"          0.5  0.0 1.0 0.05
#pragma parameter layer2_dimming       "    Layer2 Dimming (Lights OUT)"          0.5  0.0 1.0 0.05
//#endif

#pragma parameter h_nonono             "CURVATURE:"                               1.0  0.0   1.0 1.0
#pragma parameter h_curvature          "    Curvature Toggle"                     1.0  0.0   1.0 1.0
#pragma parameter h_shape              "    Shape [ Sphere | Cylinder ]"          0.0  0.0   1.0 1.0
#pragma parameter h_radius             "    Curvature Radius"                     4.0  1.8  10.0 0.1
#pragma parameter h_cornersize         "    Corner Size"                          0.05 0.01  1.0 0.01
#pragma parameter h_cornersmooth       "    Corner Smoothness"                    0.5  0.1   1.0 0.1
#pragma parameter h_x_tilt             "    Horizontal Tilt"                      0.0 -0.5 0.5 0.01
#pragma parameter h_y_tilt             "    Vertical Tilt"                        0.0 -0.5 0.5 0.01
#pragma parameter h_angle_x            "    Position X"                           0.0 -1.0   1.0 0.001
#pragma parameter h_angle_y            "    Position Y"                           0.0 -1.0   1.0 0.001
#pragma parameter h_overscan_x         "    Overscan X%"                        100.0 20.0 200.0 0.2
#pragma parameter h_overscan_y         "    Overscan Y%"                        100.0 20.0 200.0 0.2


#ifdef USE_BEZEL_REFLECTIONS_COMMON
#define bz_shine       global.bz_shine
#define bz_ambient     global.bz_ambient
#define bz_blur_iter   global.bz_blur_iter
#define bz_ref_str     global.bz_ref_str
#define bz_lights      global.bz_lights
#define bz_ref_dist    global.bz_ref_dist
#define bz_r           global.bz_radius
#define bz_ang         global.bz_ang
#define bz_pos         global.bz_pos

#define border_mirror_y  global.border_mirror_y
#endif

