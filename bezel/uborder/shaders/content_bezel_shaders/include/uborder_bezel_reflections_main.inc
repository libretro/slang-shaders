void main()
{
// Bezels and border begins...

    vec2 uvFC = mix(uv, h_warp(uv), global.h_curvature); // Frame content area
    vec2 uvIB = uvFC;                                    // Inner bezel area
    vec2 uvMB = mix(bezel_uv, h_warp(bezel_uv), global.bz_outer_curve);    // In Between bezel area
    vec2 uvOB = bezel_uv;                                    // Outer bezel area

    uvFC = uvFC*overscan - content_position;

    vec2 area_out = RoundedRectVec(vec4(uvMB, uvOB), vec4(MID_BZ, OUT_BZ), bz_r.xx, vec2(SMTH, -SMTH));

//    vec4 border = texture(BORDER, border_uv);

#ifdef KEEP_BORDER_ASPECT_RATIO
    RECALC_BORDER_ASPECT_RATIO
#else
    vec2 b_uv = border_uv;
#endif

    vec4 border = texture(BORDER, b_uv);
    vec4 layer2 = texture(LAYER2, b_uv);


    if (bz_lights < 0.5){
        layer2.rgb *= global.layer2_dimming;
	border.rgb *= global.border_dimming;
    }

    border.rgb = mix(border.rgb, layer2.rgb, layer2.a);


#ifdef USE_AMBIENT_LIGHT
    vec3 ambi  = texture(ambi_temporal_pass, b_uv).rgb;
    border.rgb = border.rgb*(ambi + (global.border_weight).xxx);
#endif

    if (area_out.y < 1.0) {FragColor = vec4(border.rgb, 1.0); return;}

// Bezels pause...

    vec2 fcTex = 0.5*uvFC + 0.5;

    float cval = h_corner(fcTex)  *  step(0.0, fract(fcTex.y));  // Discard off limit pixels

// Call to content shader here.
    vec3 content = get_content(fcTex, uv) * vec3(cval);

// Bezels continue...

    vec2  area_inn      = RoundedRectVec(vec4(uvIB, uvMB), vec4(INN_BZ, MID_BZ), bz_r.xx, vec2(SMTH, -SMTH));

    content = mix(content, mix(content.rgb, border.rgb, border.a), global.ub_border_top);

    const float ambient     = bz_ambient;
    const float ambient_out = 1.4*bz_ambient;
    vec3 shine_content      = 0.0.xxx;
    vec3 ambient_content    = 0.0.xxx;

    if (bz_lights == 1.0)
    {
        vec2 rct = RoundedRectVec(vec4(uvIB + bz_shadow, uvIB), INN_BZ.xyxy, bz_r.xx, vec2(-SMTH/2.0, -SMTH));
    	shine_content += max(0.0, bz_shine - shine_size*length(uvIB + shine_position)) * rct.x; // Glass Shine
	ambient_content += max(0.0, ambient - amb_size*length(uvIB)) * rct.y; // Ambient Light
    }
    else
    {
        // Ambient Light
	ambient_content += max(0.0, ambient - amb_size*length(uvIB)) * RoundedRect(uvIB, INN_BZ, bz_r, -SMTH.xx);
    }

    vec3  frame_content = content + (global.bz_ambient_enable*ambient_content + global.bz_shine_enable*shine_content);

    if (area_inn.x < 0.5)
    {
        vec3 content_emphasis = clamp(border.rgb*border.a * global.border_alpha + frame_content, 0.0, 1.0);

        vec3 baoc = mix(frame_content, border.rgb, global.border_alpha);

        FragColor = vec4(mix(baoc, content_emphasis, global.black_baoc), 1.0);

        return;
    }

    float bezel_inner_area = area_inn.x * area_inn.y;
    float bezel_outer_area = area_out.x * area_out.y;

    vec3 bezels = 0.0.xxx;

    // Inner Bezel Reflection Coords
    vec2 uvR = ReflectionCoords(uvFC, bz_ref_dist);

    vec3 Blur = 0.0.xxx;

    for(int i = 0; i < clamp(bz_blur_iter, 5.0, 32.0); i++) // clamp needed to fix D3D compatibility
        Blur += texture(ReflexSrc, uvR + (vec2(rand(uvR+float(i)),rand(uvR+float(i)+0.00625))-0.5)*R_BLUR_SIZE).rgb;

    Blur /= bz_blur_iter;

    // Blur in cheap linear gamma (2.0)
    Blur = sqrt(Blur);

    Blur *= ((1.0 - fsmoothstep(0.8, 1.0, abs(uvFC.x))*fsmoothstep(0.8, 1.0, abs(uvFC.y))) * bz_ref_str );


    // This is a hack. Still needs analytical solution.
    vec2 IB = abs(uvIB);
    IB = vec2(IB.x*mb_aspect, IB.y - MID_BZ.y + mb_aspect*MID_BZ.x);
    float corner = fsmoothstep(-bz_r, bz_r, IB.y - mix(IB.x, bz_ang*IB.x + bz_pos, cyl_shape));

    if (global.bz_transparent > 0.5) BZ_COLOR = border.rgb;

    if (bz_lights == 1.0)
    {
        // Bezel texture 
        vec3 bz_color = clamp(BZ_COLOR + rand(uvIB)*0.0125-0.00625, 0.0, 1.0) + 
                                         rand(uvIB+1.0.xx)*0.0625 * cos(0.75*PI*uvIB.x);
        // Inner Bezel and Reflections
        bezels += (bz_color + Blur) * bezel_inner_area * (0.25*(1.0 + corner));

    	// Outer Bezel
   	bezels +=  mix(bz_color, BZ_COLOR, global.bz_transparent) * bezel_outer_area;

    }
    else
    {
        // Middle Bezel
        bezels -= (BZ_COLOR ) * RoundedRect(uvOB, MID_BZ, bz_r, vec2(SMTH*2.0, -SMTH*10.0)) * 
                                RoundedRect(uvOB, MID_BZ, bz_r, vec2(SMTH*2.0, -SMTH* 2.0));

        // Inner Bezel and Reflections
        bezels += (BZ_COLOR + Blur) * bezel_inner_area * (ambient_out * (0.7 + 0.35*(1.0 - corner)) + Blur);

        // Outer Bezel
        bezels += BZ_COLOR * bezel_outer_area * mix(ambient_out, 1.0, global.bz_transparent);

    }

    bezels = mix(bezels+border.rgb*bezel_inner_area*global.bz_transparent, mix(bezels, border.rgb, border.a), global.ub_border_top);

    FragColor = vec4(bezels, 1.0);
}
