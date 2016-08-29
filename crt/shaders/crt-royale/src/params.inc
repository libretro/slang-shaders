layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	float crt_gamma;
    float lcd_gamma;
    float levels_contrast;
    float halation_weight;
    float diffusion_weight;
    float bloom_underestimate_levels;
    float bloom_excess;
    float beam_min_sigma;
    float beam_max_sigma;
    float beam_spot_power;
    float beam_min_shape;
    float beam_max_shape;
    float beam_shape_power;
    float beam_horiz_filter;
    float beam_horiz_sigma;
    float beam_horiz_linear_rgb_weight;
    float convergence_offset_x_r;
    float convergence_offset_x_g;
    float convergence_offset_x_b;
    float convergence_offset_y_r;
    float convergence_offset_y_g;
    float convergence_offset_y_b;
    float mask_type;
    float mask_sample_mode_desired;
    float mask_specify_num_triads;
    float mask_triad_size_desired;
    float mask_num_triads_desired;
    float aa_subpixel_r_offset_x_runtime;
    float aa_subpixel_r_offset_y_runtime;
    float aa_cubic_c;
    float aa_gauss_sigma;
    float geom_mode_runtime;
    float geom_radius;
    float geom_view_dist;
    float geom_tilt_angle_x;
    float geom_tilt_angle_y;
    float geom_aspect_ratio_x;
    float geom_aspect_ratio_y;
    float geom_overscan_x;
    float geom_overscan_y;
    float border_size;
    float border_darkness;
    float border_compress;
    float interlace_1080i;
} params;

//  Set shader params for all passes here:
#pragma parameter crt_gamma "crt_gamma" 2.5 1.0 5.0 0.025
#pragma parameter lcd_gamma "lcd_gamma" 2.2 1.0 5.0 0.025
#pragma parameter levels_contrast "levels_contrast" 1.0 0.0 4.0 0.015625
#pragma parameter halation_weight "halation_weight" 0.0 0.0 1.0 0.005
#pragma parameter diffusion_weight "diffusion_weight" 0.075 0.0 1.0 0.005
#pragma parameter bloom_underestimate_levels "bloom_underestimate_levels" 0.8 0.0 5.0 0.01
#pragma parameter bloom_excess "bloom_excess" 0.0 0.0 1.0 0.005
#pragma parameter beam_min_sigma "beam_min_sigma" 0.02 0.005 1.0 0.005
#pragma parameter beam_max_sigma "beam_max_sigma" 0.3 0.005 1.0 0.005
#pragma parameter beam_spot_power "beam_spot_power" 0.33 0.01 16.0 0.01
#pragma parameter beam_min_shape "beam_min_shape" 2.0 2.0 32.0 0.1
#pragma parameter beam_max_shape "beam_max_shape" 4.0 2.0 32.0 0.1
#pragma parameter beam_shape_power "beam_shape_power" 0.25 0.01 16.0 0.01
#pragma parameter beam_horiz_filter "beam_horiz_filter" 0.0 0.0 2.0 1.0
#pragma parameter beam_horiz_sigma "beam_horiz_sigma" 0.35 0.0 0.67 0.005
#pragma parameter beam_horiz_linear_rgb_weight "beam_horiz_linear_rgb_weight" 1.0 0.0 1.0 0.01
#pragma parameter convergence_offset_x_r "convergence_offset_x_r" 0.0 -4.0 4.0 0.05
#pragma parameter convergence_offset_x_g "convergence_offset_x_g" 0.0 -4.0 4.0 0.05
#pragma parameter convergence_offset_x_b "convergence_offset_x_b" 0.0 -4.0 4.0 0.05
#pragma parameter convergence_offset_y_r "convergence_offset_y_r" 0.0 -2.0 2.0 0.05
#pragma parameter convergence_offset_y_g "convergence_offset_y_g" 0.0 -2.0 2.0 0.05
#pragma parameter convergence_offset_y_b "convergence_offset_y_b" 0.0 -2.0 2.0 0.05
#pragma parameter mask_type "mask_type" 1.0 0.0 2.0 1.0
#pragma parameter mask_sample_mode_desired "mask_sample_mode" 0.0 0.0 2.0 1.0   //  Consider blocking mode 2.
#pragma parameter mask_specify_num_triads "mask_specify_num_triads" 0.0 0.0 1.0 1.0
#pragma parameter mask_triad_size_desired "mask_triad_size_desired" 3.0 1.0 18.0 0.125
#pragma parameter mask_num_triads_desired "mask_num_triads_desired" 480.0 342.0 1920.0 1.0
#pragma parameter aa_subpixel_r_offset_x_runtime "aa_subpixel_r_offset_x" -0.333333333 -0.333333333 0.333333333 0.333333333
#pragma parameter aa_subpixel_r_offset_y_runtime "aa_subpixel_r_offset_y" 0.0 -0.333333333 0.333333333 0.333333333
#pragma parameter aa_cubic_c "antialias_cubic_sharpness" 0.5 0.0 4.0 0.015625
#pragma parameter aa_gauss_sigma "antialias_gauss_sigma" 0.5 0.0625 1.0 0.015625
#pragma parameter geom_mode_runtime "geom_mode" 0.0 0.0 3.0 1.0
#pragma parameter geom_radius "geom_radius" 2.0 0.16 1024.0 0.1
#pragma parameter geom_view_dist "geom_view_dist" 2.0 0.5 1024.0 0.25
#pragma parameter geom_tilt_angle_x "geom_tilt_angle_x" 0.0 -3.14159265 3.14159265 0.017453292519943295
#pragma parameter geom_tilt_angle_y "geom_tilt_angle_y" 0.0 -3.14159265 3.14159265 0.017453292519943295
#pragma parameter geom_aspect_ratio_x "geom_aspect_ratio_x" 432.0 1.0 512.0 1.0
#pragma parameter geom_aspect_ratio_y "geom_aspect_ratio_y" 329.0 1.0 512.0 1.0
#pragma parameter geom_overscan_x "geom_overscan_x" 1.0 0.00390625 4.0 0.00390625
#pragma parameter geom_overscan_y "geom_overscan_y" 1.0 0.00390625 4.0 0.00390625
#pragma parameter border_size "border_size" 0.015 0.0000001 0.5 0.005
#pragma parameter border_darkness "border_darkness" 2.0 0.0 16.0 0.0625
#pragma parameter border_compress "border_compress" 2.5 1.0 64.0 0.0625
#pragma parameter interlace_1080i "interlace_1080i" 0.0 0.0 1.0 1.0