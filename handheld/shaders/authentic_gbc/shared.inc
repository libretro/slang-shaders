// See the main shader file for copyright and other information.

// This is the bulk of the shared vertex shader.
void calculate_lcd_params(vec2 source_size, vec2 output_size, uint rotation, float use_subpx,
                          uint subpx_orientation, float brightness_boost, vec2 tex_coord,
                          inout vec4 lcd_subpx_rect1, inout vec4 lcd_subpx_rect2,
                          inout vec2 subpx_offset_in_px, inout vec2 tx_coord, inout vec2 tx_to_px,
                          inout vec2 tx_orig_offs) {
    const vec4 rot_corr = vec4(1.0, 0.0, -1.0, 0.0);
    subpx_offset_in_px = use_subpx / 3.0 *
                         vec2(rot_corr[(rotation + subpx_orientation) % 4],
                              rot_corr[(rotation + subpx_orientation + 3) % 4]);

    tx_coord = tex_coord * source_size;
    tx_to_px = output_size / source_size;

    // As determined by counting pixels on a photo.
    const vec2 subpx_ratio = vec2(0.296, 0.910);
    const vec2 notch_ratio = vec2(0.115, 0.166);

    // Scale the subpixel and notch sizes with the brightness parameter.
    // The maximally bright numbers are chosen manually.
    vec2 lcd_subpx_size_in_px = tx_to_px * mix(subpx_ratio, vec2(0.75, 0.93), brightness_boost);
    vec2 notch_size_in_px = tx_to_px * mix(notch_ratio, vec2(0.29, 0.17), brightness_boost);
    lcd_subpx_rect1 = vec4(vec2(0.0), lcd_subpx_size_in_px - vec2(0.0, notch_size_in_px.y));
    lcd_subpx_rect2 =
        vec4(notch_size_in_px.x, lcd_subpx_size_in_px.y - notch_size_in_px.y, lcd_subpx_size_in_px);

    tx_orig_offs = (tx_to_px - lcd_subpx_size_in_px) * 0.5;
}
