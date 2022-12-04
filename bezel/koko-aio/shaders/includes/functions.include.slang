#define alpha_mark 0.1
#define pi 3.141592654

vec3 pixel_push_luminance(vec3 c, float strength) {
	//if (strength == 0.0) return c; //lighter without the check.
	float whiteness = max(max(c.r, c.g), c.b);
	whiteness = clamp(whiteness, 0.0, 1.0);
	return c * (1+vec3((1-whiteness) * strength));
}

vec3 apply_fuzzy_main_pass(vec3 color) {
   if (DO_IN_GLOW == 1.0)
      color = pow(color,vec3(IN_GLOW_GAMMA))*IN_GLOW_POWER;
   if (DO_VMASK_AND_DARKLINES == 1.0)
      color *= mix (  (1.0 -  ((RGB_MASK_STRENGTH*0.5)+(DARKLINES_STRENGTH*0.2))), 1.0, MASK_COMPENSATION)                  ;
   if (DO_HALO == 1.0)
      color += pow(color,vec3(HALO_GAMMA))*HALO_POWER;
   if (DO_SCANLINES == 1.0)
      color *=  mix(0.5 + (SCANLINE_DARK*0.5), 1.0, SCANLINE_COMPENSATION);
   if (DO_CCORRECTION == 1.0)
      color = pow(color, vec3(GAMMA_OUT));
   if (DO_VIGNETTE == 1.0)
      color *= 0.8 * (V_POWER);
   return color;
}


vec2 offsets_from_float(float in_param, int range){
    return vec2(  
                  (int(in_param) % range) - range*0.5,
                  floor(in_param / range) - range*0.5 
	        );
}

/*vec2 circles(float param, float c_radius, float aspect, float directions) {
   //given a 1d input param return full circles increasing radius.
   param = param*(pi/directions);
   float m = (c_radius * floor(param/pi)) * 100;
   return vec2(m * sin(param) * aspect, m * cos(param)) * vec2(aspect,1.0);
}

vec2 spiral(float param,float spr_radius,vec2 spr_offset, vec2 spr_scale) {
   //given a 1d input param returns a spiral
   float m = spr_radius * param;
   return vec2(m * sin(param), m * cos(param)) * spr_scale + spr_offset;
}
*/
bool similar(float a, float b, float threshold) {
   return abs(a-b) < threshold;
}

bool vec2_similar(vec2 a, vec2 b, float threshold) {
   return abs(a.x-b.x) < threshold  && abs(a.y-b.y) < threshold;
}


vec2 zoom(vec2 in_coords, float zoom_factor) {
   float off = 1.0/(zoom_factor*2.0) - 0.5;
   return (in_coords/zoom_factor)-off;
}

vec2 zoomxy(vec2 in_coords, vec2 zoom_factor) {
   vec2 off = 1.0/(zoom_factor*2.0) - 0.5;
   return (in_coords/zoom_factor)-off;
}

vec2 zoomout_coords(vec2 in_coords, float zoom_out, float aspect) {
   vec2 zoom   = vec2( 1 + zoom_out, 
                       1 + (zoom_out * aspect) 
                     );
                     
   vec2 offset = vec2( (zoom.x-1.0) / 2.0,
                       (zoom.y-1.0) / 2.0 
                     );
   return (in_coords * zoom) - offset;
}

bool scanline_have_to_flicker(bool is_interlaced) {
    return ((SCANLINE_FLICKERING == 1.0) || ((SCANLINE_FLICKERING==2.0) && is_interlaced ));
}

bool is_interlaced() {
	return (params.OriginalSize.y > MIN_LINES_INTERLACED);
}

float scale_to_range(float x, float dmin, float dmax) {
    //Scales 0..1 range to a..b range
    return ( (dmax-dmin) * x ) + dmin;
}

vec3 scale_to_range_vec3(vec3 x, float dmin, float dmax) {
    //Scales 0..1 range to a..b range
    return ( (dmax-dmin) * x ) + dmin;
}

vec2 scale_to_range_vec2(vec2 x, float dmin, float dmax) {
    //Scales 0..1 range to a..b range
    return ( (dmax-dmin) * x ) + dmin;
}

#define RND_A 12.9898
#define RND_B 78.233
#define RND_C 43758.5453

float random(float power, vec2 seed) {
    //From pal-singlepass.slang 
    //https://github.com/svofski/CRT
    //Copyright (c) 2016, Viacheslav Slavinsky
    //All rights reserved.
    float dt = dot(seed.xy, vec2(RND_A, RND_B));
    float sn = mod(dt,3.14);

    float noise_out = fract(sin(sn) * RND_C) - 0.5;
    noise_out = clamp(noise_out, -power, power);
    return noise_out ;
}


//CURVATURE
	#define corner_aspect vec2(1.0,  0.75)
	float border(vec2 coord)
	{
		coord = (coord - vec2(0.5)) + vec2(0.5, 0.5);
		coord = min(coord, vec2(1.0) - coord) * corner_aspect;
		vec2 cdist = vec2(GEOM_CORNER_SIZE);
		coord = (cdist - min(coord, cdist));
		float dist = sqrt(dot(coord, coord));
		return clamp((cdist.x - dist)*GEOM_CORNER_SMOOTH, 0.0, 1.0);
	}


	vec2 Warp(vec2 uv,float wx, float wy){
		uv = uv * 2.0 - 1.0;
		vec2 CRT_Distortion = vec2(wx, wy);
		float curvedCoordsDistance = length(uv);
		uv /= curvedCoordsDistance;
		uv *= (1.0-pow(vec2(1.0-(curvedCoordsDistance/1.4142135623730950488016887242097)),(1.0/(1.0+CRT_Distortion*0.2))));
		uv /= (1.0-pow(vec2(0.29289321881345247559915563789515),(1.0/(vec2(1.0)+CRT_Distortion*0.2))));
		uv = uv* 0.5 + 0.5;
		return uv;
	}


//VIGNETTE - SPOT
/*	float gauss(float x, float x0, float sx, float size, float power){
		float arg = x-x0;
		arg = -(1/size)/2.*arg*arg/sx;
		float a = 1./(pow(2.*3.1415*sx, 0.5));
		return a*exp(arg) * power;
	}

	float gauss_xy(float pos_x, float pos_y, float size, float power, float gmin, float gmax) {
		vec2 uv = vTexCoord.xy + vec2(pos_x,pos_y);
		float scale_uv = params.SourceSize.x / params.SourceSize.y;
		float gx = gauss(uv.x* scale_uv,  0.5*scale_uv,  0.1,    size, power);
		float gy = gauss(uv.y,            0.5,           0.1,    size, power);
		float light = gx*gy;
		return clamp(light,gmin,gmax);
	}
*/

//AMBILIGHT RELATED
	bool border_needed() {
		//returns if we need to draw on the border
		return (DO_AMBILIGHT + DO_BG_IMAGE > 0.0);
	}

	
	#define mark_useless(x) mark_outer_frame(x)	
	vec4 mark_outer_frame(vec3 pixel) {
		return vec4(pixel.rgb,0.0) ;
		//For my mental sanity, I use a specific alpha channel value to mark a frame as a border
		return vec4(pixel.r,pixel.g,pixel.b,alpha_mark) ;
	}
	#define is_useless(x) is_outer_frame(x)
	bool is_outer_frame(vec4 pixel) {
		return pixel.a == 0.0;
		/*Check if a pixel is marked as border by comparing the value of its alpha channel
		Tolerance is needed, because precision can be as low as 1/256; since I don't need
		alpha channel, use an even large tolerance.
		*/
		return  abs(pixel.a - alpha_mark) < 0.05; //<-- 0.05 allow about 20 alpha levels (1*0.05)
	}

	#define ar_tolerance 0.1 //To compensate when comparing different A/R 
	bool is_rotated() {
		/*
			For some reason, probably retroarch rotates the view only on final viewport stage, transparent to the shader passes,
			The OutputSize of a pass that scales to viewport will have different aspect from the real final viewport.
			We exploit this to understand when a game is rotated.
			-->> This function only works if the calling pass scales to viewport.
			This will fail for very particular cases, eg: when output window is extremely tall 
		*/
		return (abs((params.OutputSize.x/params.OutputSize.y) - (global.FinalViewportSize.x/global.FinalViewportSize.y)) > ar_tolerance);
	}

	float get_in_aspect() {
			if (ASPECT_X ==  -1) return 1.5;   // ntsc
			if (ASPECT_X ==  -2) return 1.25;  // pal
			if (ASPECT_X ==  -3) return 1.143; // 8/7 snes
			if (ASPECT_X ==  -4) return 1.428; // 10/7 megadrive
			if (ASPECT_X ==  -5) return params.OriginalSize.x/params.OriginalSize.y; //uncorrected

			if (ASPECT_X == 0) {
				return 1.3333333333333; //all mame games, not rotated
			}

			return ASPECT_X / ASPECT_Y ;
	}

	vec2 get_scaled_coords_aspect(vec2 pTexCoord, vec4 destsize, float in_aspect , bool is_rotated){
		if (!border_needed()) return pTexCoord;
			//else
		float scale_x = 1.0;
		float scale_y = 1.0;
		float offset_x = 0.0 ;
		float offset_y = 0.0 ;
		if (is_rotated) {
			scale_y = destsize.x/(destsize.y / in_aspect );
			offset_y = (0.5 * scale_y ) - 0.5 ;
		} else {
			scale_x = destsize.x/(destsize.y * in_aspect);
			offset_x = (0.5 * scale_x ) - 0.5 ;
		}

		vec2 scale_coord=vec2(pTexCoord.x*scale_x - offset_x , pTexCoord.y*scale_y - offset_y);
		return scale_coord;
	}
	
	vec2 get_scaled_coords(vec2 pTexCoord, vec4 destsize, bool is_rotated){
		if (!border_needed()) return pTexCoord;
			//else
		float scale_x = 1.0;
		float scale_y = 1.0;
		float offset_x = 0.0 ;
		float offset_y = 0.0 ;
		float in_aspect = get_in_aspect();
		if (is_rotated) {
			//I'm doing ping pong between th the following 2:
			//FIXME: verify if it depends on destsize being outputsize or finalviewportsize!!
			//scale_y = destsize.y/(destsize.x / in_aspect );
			scale_y = destsize.x/(destsize.y / in_aspect );
			
			offset_y = (0.5 * scale_y ) - 0.5 ;
			
			
		} else {
			//scale_x = params.OutputSize.x/(params.OutputSize.y * in_aspect);
			//scale_x = global.FinalViewportSize.x/(global.FinalViewportSize.y * in_aspect);
			scale_x = destsize.x/(destsize.y * in_aspect);
			offset_x = (0.5 * scale_x ) - 0.5 ;
		}

		vec2 scale_coord=vec2(pTexCoord.x*scale_x - offset_x , pTexCoord.y*scale_y - offset_y);
		return scale_coord;
	}
	


