#define _prec 32.0
#define mul_low (pow(_prec,0.0))
#define mul_mid (pow(_prec,2.0))
#define mul_hi  (pow(_prec,3.0))

#define color_quant (2.0/_prec)

float pack_21(vec2 color) {
    color = clamp(color,0.0,1.0-color_quant);
    color = floor(color*_prec)/_prec;
    return (color.g * mul_mid) + (color.r * mul_hi) ;
}

vec2 unpack_21(float result, float compensation) {
    float hi =  floor(result/mul_mid)*mul_mid;
    float mid = floor((result - hi)/mul_low)*mul_low;
    vec2 o = vec2( hi/mul_hi, mid/mul_mid ) * compensation;
	return clamp(o,0.0,1.0);
}



#define pack_floats_precision 31.0
#define pack_floats_clamp 1-(1/pack_floats_precision)
float _pack_21(vec2 in_float){
	//Clamp and round to 1/255 needed:
	in_float = clamp(in_float, 0.0 , pack_floats_clamp);
	in_float = floor(in_float*pack_floats_precision)/pack_floats_precision;
	return in_float.x*pack_floats_precision + in_float.y;
}

float get_lod(vec2 smp_size, vec2 out_size) {
	vec2 ratio = out_size/smp_size;
    float maxRatio = max(ratio.x, ratio.y);
    return log2(maxRatio);
}

bool low_fps(sampler2D estimatesampler) {
	/* returns if core fps is inside [25..30] interval */

	//Can't do anything without frametime uniforms.
	#ifndef _HAS_FRAMETIME_UNIFORMS
		return false;
	#endif
		
	 //No need to estimate if we trust frametime uniforms.
	#ifdef ORIGINAL_FPS_TRUSTED
		return (global.OriginalFPS < 40);
	#endif
			
	#ifndef D3D_WORKAROUND
		//To estimate we need to poll an alpha from a future
		//pass feedback, so no D3D support.
		return texture(estimatesampler, vec2(0.5)).a < FPS_MEAN;
	#else
		return false;
	#endif
}

vec2 _unpack_21(float f){
	float fr = fract(f);
	float fg = floor(f)/pack_floats_precision;
	return vec2(fg,fr);
}
	

/*
#define _scale float(floor(SERVICE1*10000))
float pack_21(vec2 ab) {
  const float scale = _scale;
  const float bias = 0.5 / scale;
  return fract(ab.x * scale) + floor(ab.y * scale) / scale + bias;
}


vec2 unpack_21(float packed) {
  const float scale = _scale;
  float a = fract(packed * scale);
  float b = floor(packed * scale) / scale;  // Calcolo di 'b'
  return vec2(a, b);
}
*/

float max3(vec3 v){
	return max((v.x,v.y),v.z);
}

float min3(vec3 v){
	return max((v.x,v.y),v.z);
}


vec3 mask_enhance(vec3 mask, vec3 ref, float factor) {
 return mix( factor * (mask - 0.5) + 0.5, mask, abs(ref - vec3(0.5)*2) );
}

float mask_enhance_float(float mask, vec3 ref, float factor) {
	float fref = dot(ref, vec3(0.3333));
 return mix( factor * (mask - 0.5) + 0.5, mask, abs(fref - 0.5*2) );
}

bool line_is_even(float co_y, float size_y) {
	float line = floor(co_y*size_y);
	return (int(line) & 1) == 0;
}

bool frame_is_even() {
	return ((int(params.FrameCount) & 1) == 0);
}

uint frame_subframe() {
  return params.FrameCount * global.TotalSubFrames + global.CurrentSubFrame;
}

bool frame_subframe_is_even() {
  return (frame_subframe() & 1) == 0;
}

bool is_subframe() {
    return global.CurrentSubFrame > 1;
}

bool is_rotated_new(){
	return (params.Rotation == 1.0 || params.Rotation == 3.0);
}


bool fps_halver_is_skipped_frame()  {
	#ifdef FPS_HALVER
		#ifdef _HAS_FRAMETIME_UNIFORMS
			if (global.OriginalFPS >= 49) {
				if ( frame_is_even() ) {
					return true;
				}
			}
		#endif
	#endif
    return false;
}

bool skip_subframe() {
	#ifdef DO_ADPT_STROBE
		return false;
	#endif
		
	#ifdef SUBFRAMES_OPTIMIZATIONS
		if (is_subframe()) return true;
	#endif
	
	return false;
}

bool is_skipped_frame() {
	if (skip_subframe()) return true;
	if (fps_halver_is_skipped_frame()) return true;
	return false;
}


bool is_rotated_old(){
	//Keep this to retain some sort of compatibility with Retroarch pre 1.17
	const float ar_tolerance = 0.005;
	/*
		For some reason, probably retroarch rotates the view only on final viewport stage, transparent to the shader passes,
		The OutputSize of a pass that scales to viewport will have different aspect from the real final viewport.
		We exploit this to understand when a game is rotated.
		-->> This function only works if the calling pass scales to viewport.
		This will fail for very particular cases, eg: when output window is extremely tall 
	*/
	return (abs((params.OutputSize.x/params.OutputSize.y) - (global.FinalViewportSize.x/global.FinalViewportSize.y)) > ar_tolerance);
}
	
bool is_rotated() {
	#ifdef _HAS_ROTATION_UNIFORM
		return is_rotated_new();
	#else
		return is_rotated_old();
	#endif
}


//	Colorspace conversion matrix for YIQ-to-RGB
const mat3 YIQ2RGB = mat3(1.000, 1.000, 1.000,
                          0.956,-0.272,-1.106,
                          0.621,-0.647, 1.703);

const mat3 RGB2YIQ = mat3(
         0.2989, 0.5959, 0.2115,
         0.5870, -0.2744, -0.5229,
         0.1140, -0.3216, 0.3114);

float need_tate(bool is_rotated) {
    if ( (TATE == 1.0 && is_rotated) || TATE == 2.0)
        return 1.0;
            else
        return 0.0;
    //return float(TATE+vIsRotated > 1.001); //<<-- reported problems with amd (?)
}

vec3 smoothstep_fast(vec3 edge0, vec3 edge1, vec3 x) {
  return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
}

float smoothstep_fast(float edge0, float edge1, float x) {
  return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
}

vec2 smoothstep_fast(vec2 edge0, vec2 edge1, vec2 x) {
  return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
}

vec2 smoothstep_fast(float edge0, float edge1, vec2 x) {
  return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
}

float smoothstep_cos(float edge0, float edge1, float x) {
  float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  return cos(t * pi) * -0.5 + 0.5;
}

vec3 texture_BILINEAR(sampler2D t, vec2 uv, vec4 texSize, float k) {
	uv = uv -texSize.zw*0.5*k;
	vec2 texelSize = texSize.zw * k;
    vec2 f = fract( uv * texSize.xy );
    uv += ( .5 - f ) * texelSize;    // move uv to texel centre
    vec3 tl = texture(t, uv).rgb;
    vec3 tr = texture(t, uv + vec2(texelSize.x, 0.0)).rgb;
    vec3 bl = texture(t, uv + vec2(0.0, texelSize.y)).rgb;
    vec3 br = texture(t, uv + vec2(texelSize.x, texelSize.y)).rgb;
    vec3 tA = mix( tl, tr, f.x );
    vec3 tB = mix( bl, br, f.x );
    return mix( tA, tB, f.y );
}


vec3 texture_BILINEAR_X(sampler2D t, vec2 uv, vec4 texSize, float k) {
       uv = uv -texSize.zw*0.5*vec2(k,1.0);
       vec2 texelSize = texSize.zw * vec2(k, 1.0);
    vec2 f = fract( uv * texSize.xy );
    uv += ( .5 - f ) * texelSize;    // move uv to texel centre
    vec3 tl = texture(t, uv).rgb;
    vec3 tr = texture(t, uv + vec2(texelSize.x, 0.0)).rgb;
    return  mix( tl, tr, f.x );
}


float clamp_smooth(float x, float amin, float amax) {
	float sharp = 0.0;
    return mix(amin, amax, smoothstep(amin-sharp, amax+sharp, x));
}

vec3 clamp_smooth(vec3 x, vec3 amin, vec3 amax) {
	float sharp = 0.0;
    return mix(amin, amax, smoothstep(amin-sharp, amax+sharp, x));
}

vec2 clamp_smooth(vec2 x, vec2 a, vec2 b) {
	float sharp = 0.0;
    return mix(a, b, smoothstep(a-sharp, b+sharp, x));
}

vec2 coords_QULEZ_faster(vec2 co, vec4 texsize){
	//based on idea: https://iquilezles.org/articles/texture/
	co = co * texsize.xy + vec2(0.5);
	vec2 i = floor(co);
    vec2 f = sin((co - i - 0.5) * pi) * 0.5 + 0.5 ;
	co = i + f;
	co = (co - vec2(0.5) ) * texsize.zw;
	return co;
}

vec2 coords_QULEZ(vec2 co, vec4 texsize){
	//https://iquilezles.org/articles/texture/
	co = co * texsize.xy + vec2(0.5);
	vec2 i = floor(co);
	vec2 f = co - i;
	f = (f * f) *
	    (f * (f * (f * 6.0 - vec2(15.0, 15.0)) + vec2(10.0, 10.0)));
	co = i + f;
	co = (co - vec2(0.5, 0.5)) * (texsize.zw);
	return co;
}

vec4 texture_QUILEZ(sampler2D tex, vec2 co, vec4 texsize) {
	co = coords_QULEZ(co, texsize);
	return texture(tex, co);
}

vec2 coords_NEAREST(vec2 co, vec4 texsize) {
   vec2 integerCoords = floor(co.xy * texsize.xy);
   return (integerCoords + 0.5) * texsize.zw;
}

float coords_NEAREST_y(vec2 co, vec4 texsize) {
   float integerCoords = floor(co.y * texsize.y);
   return (integerCoords + 0.5) * texsize.w;
}

vec4 texture_NEAREST(sampler2D tex, vec2 co_linear, vec4 tex_size) {
   //return nearest sampling from a linear filtered texture
   vec2 integerCoords = floor(co_linear.xy * tex_size.xy);
   vec2 co_nearest = (integerCoords + 0.5) * tex_size.zw; // Aggiungi 0.5 per centrare il texel
   return texture(tex, co_nearest);
}

vec4 texture_NEAREST_lod(sampler2D tex, vec2 co_linear, vec4 tex_size, float lod) {
	   //return nearest sampling from a linear filtered texture
   vec2 integerCoords = floor(co_linear.xy * tex_size.xy);
   vec2 co_nearest = (integerCoords + 0.5) * tex_size.zw; // Aggiungi 0.5 per centrare il texel
   return textureLod(tex, co_nearest, 0.0);
}

float DigitBin( const int x ) {
    return x==0?480599.0:x==1?139810.0:x==2?476951.0:x==3?476999.0:x==4?350020.0:x==5?464711.0:x==6?464727.0:x==7?476228.0:x==8?481111.0:x==9?481095.0:0.0;
}


float PrintValue( vec2 vStringCoords, float fValue, float fMaxDigits, float fDecimalPlaces ) {       
    if ((vStringCoords.y < 0.0) || (vStringCoords.y >= 1.0)) return 0.0;
    
    bool bNeg = ( fValue < 0.0 );
	fValue = abs(fValue);
    
	float fLog10Value = log2(abs(fValue)) / log2(10.0);
	float fBiggestIndex = max(floor(fLog10Value), 0.0);
	float fDigitIndex = fMaxDigits - floor(vStringCoords.x);
	float fCharBin = 0.0;
	if(fDigitIndex > (-fDecimalPlaces - 1.01)) {
		if(fDigitIndex > fBiggestIndex) {
			if((bNeg) && (fDigitIndex < (fBiggestIndex+1.5))) fCharBin = 1792.0;
		} else {		
			if(fDigitIndex == -1.0) {
				if(fDecimalPlaces > 0.0) fCharBin = 2.0;
			} else {
                float fReducedRangeValue = fValue;
                if(fDigitIndex < 0.0) { fReducedRangeValue = fract( fValue ); fDigitIndex += 1.0; }
				float fDigitValue = (abs(fReducedRangeValue / (pow(10.0, fDigitIndex))));
                fCharBin = DigitBin(int(floor(mod(fDigitValue, 10.0))));
			}
        }
	}
    return floor(mod((fCharBin / pow(2.0, floor(fract(vStringCoords.x) * 4.0) + (floor(vStringCoords.y * 5.0) * 4.0))), 2.0));
}

vec3 PrintValueVec3( vec2 vStringCoords, vec2 FragCoord,  float fValue, float fMaxDigits, float fDecimalPlaces ) {
	vec3 vColour = vec3(0.0);

	// Multiples of 4x5 work best
	vec2 vFontSize = vec2(8.0, 15.0);

	// Print a custom value
	vec2 vPixelCoord1 = vec2(5.0, 5.0);

	FragCoord.y = (vFontSize.y*2.0) - FragCoord.y;
	//FragCoord.y = (vFontSize.y*2.0) - FragCoord.y;
	//FragCoord.x -= 100;
	
    float customDigit = PrintValue( (  FragCoord - vPixelCoord1    ) / vFontSize, fValue, fMaxDigits, fDecimalPlaces);
	vColour = mix( vColour, vec3(0.0, 1.0, 1.0), customDigit);

	return vColour;
}

// mix_step returns a or b, depending on the mix value.
// mix is supposed to have just 2 values, 1.0 or 0.0; //FIXME: mix argument could be vec.

		vec2 mix_step(vec2 a, vec2 b, float m){
			return mix(a,b,m);  //114
			//return ( b-a )* m + a; //113.5
			//if (m==0.0) return a ; return b; //113.5
			//return (a * (1 - m)) + (b * m) ; //112
		}
		vec3 mix_step(vec3 a, vec3 b, float m){
			return mix(a,b,m);
			//return ( b-a )* m + a;
			//if (m==0.0) return a ; return b;
			//return (a * (1 - m)) + (b * m) ;
		}
		vec3 mix_step3(vec3 a, vec3 b, float m){
			return mix(a,b,m);
			//return ( b-a )* m + a;
			//if (m==0.0) return a ; return b;
			//return (a * (1 - m)) + (b * m) ;
		}
		vec4 mix_step(vec4 a, vec4 b, float m){
			return mix(a,b,m);
			//return ( b-a )* m + a;
			//if (m==0.0) return a ; return b;
			//return (a * (1 - m)) + (b * m) ;
		}
		float mix_step(float a, float b, float m){
			return mix(a,b,m);
			//return ( b-a )* m + a;
			//if (m==0.0) return a ; return b;
			//return (a * (1 - m)) + (b * m) ;
		}


//REFLECTION RELATED START
	float circle_smooth(vec2 coords, vec2 middle, float f_radius, float FALLOFF) {
	//Draw a circle with smoothed borders:
	float fdistance=distance(middle, vec2(coords.x, coords.y));
	float circle = (1-smoothstep(f_radius, f_radius+FALLOFF, fdistance));
	return circle;
	}

	float square_smooth(vec2 co, vec2 corner, float size, float smoothshade) {
	//Draws a square with smooth borders:
	vec4 rect = vec4(corner.x, corner.y, corner.x+size, corner.y+size);
	vec2 hv = smoothstep(rect.xy - smoothshade, rect.xy, co) * smoothstep(co - smoothshade, co, rect.zw);
	return  hv.x * hv.y;
	}

	float corners_shade(vec2 co, float size_multiplier){
		//Draw 4 smooth squares or circles in the corners.

		#define GRAD_START (BEZEL_REFL_CORNER_BLANK_SIZE*size_multiplier)
		#define GRAD_END (GRAD_START+BEZEL_REFL_CORNER_BLANK_SHADE*size_multiplier)	
		float gradient_start = (1-GRAD_END);
		float gradient_end = (1-GRAD_START);
		vec2 gradients = smoothstep_fast(gradient_start-0.5, gradient_end-0.5,abs(co-0.5));
		float squares = gradients.x * gradients.y;		
		return squares;
			
		
		/*vec4 circles;
		float circle_radius = BEZEL_REFL_CORNER_BLANK_SIZE * size_multiplier;
		float circle_falloff = BEZEL_REFL_CORNER_BLANK_SHADE * size_multiplier;
		circles.x = circle_smooth(co, vec2(0.0,0.0), circle_radius, circle_falloff) ;
		circles.y = circle_smooth(co, vec2(0.0,1.0), circle_radius, circle_falloff) ;
		circles.z = circle_smooth(co, vec2(1.0,0.0), circle_radius, circle_falloff) ;
		circles.w = circle_smooth(co, vec2(1.0,1.0), circle_radius, circle_falloff) ;
		float circle = dot(circles, vec4(1.0));
		return circle;
		*/
		
		/*vec4 squares;
		float squaresize = BEZEL_REFL_CORNER_BLANK_SIZE * size_multiplier;
		float squarefade = BEZEL_REFL_CORNER_BLANK_SHADE * size_multiplier;
		//(vec2 co, vec2 corner, float size, float smoothshade) {
		squares.x = square_smooth(co, vec2(0.0,0.0), squaresize, squarefade);
		squares.y = square_smooth(co, vec2(1.0 - squaresize, 0.0), squaresize, squarefade);
		squares.z = square_smooth(co, vec2(0.0, 1-squaresize), squaresize, squarefade);
		squares.w = square_smooth(co, vec2(1-squaresize, 1-squaresize), squaresize, squarefade);
		return max(max(max(squares.x, squares.y), squares.z), squares.w);
		*/
	}
//REFLECTION RELATED ENDS


vec3 pixel_push_luminance(vec3 c, float strength) {
	//return c;
	//if (strength == 0.0) return c; //lighter without the check.
	float whiteness = clamp(max3(c), 0.0, 1.0);
	//return c * (1 + ( (1-whiteness) * strength)	);
	return fma(c,   vec3(fma(strength, -whiteness, strength)), c); //ASM PROOF
}

float get_halo_ungain_factor() {
	return mix(1.0, 
			   max(IN_GLOW_POWER, 1.0), 
			   DO_CCORRECTION
			   );
}

vec2 apply_fuzzy_main_pass_stage_1() {
	//This simulates the final pass pixel processing so that previous passes like 
	//reflections, full screen luminance zoom and ambient light 
	//can react accordingly without doing the same thing twice.
	//For speed reasons, this lives in vertex shader and will output
	//a vec2(mul factor, pow factor)
	//in fragment shader one will pow(pow factor)*multiply factor;
	
	float color_in = 1.0;
	float color_out = 1.0;
	float gamma_out = 1.0;
	
	float halo_power_adapted;
	halo_power_adapted = HALO_POWER;
	if (HALO_NO_PREGAIN == 1.0) {
		halo_power_adapted /= get_halo_ungain_factor();
	}
	if (HALO_POWER < 0.0) 
		halo_power_adapted = -halo_power_adapted/10.0;

	color_out = pow(color_in, GAMMA_OUT); //<- nonsense ?
	gamma_out = gamma_out * GAMMA_OUT;
	gamma_out = gamma_out * IN_GLOW_GAMMA;
	color_out = pow(color_out,IN_GLOW_GAMMA);
	
	if (DO_CCORRECTION == 1.0) {
		color_out *= IN_GLOW_POWER;
	}


	if (DO_PIXELGRID == 1.0) {
		color_out *= 1- DO_PIXELGRID_H * 0.5   ; //Half color if scanline.
		color_out *= 1- DO_PIXELGRID_W * 0.5   ; //Half color if Hmask.
		color_out *= 1- PIXELGRID_Y_MASK * 0.2 ; //Strip at most 20% if level 2 ymask.
	}


	if (DO_HALO == 1.0) {
		color_out += color_in*halo_power_adapted / HALO_GAMMA;
		gamma_out = gamma_out * mix(1.0, HALO_GAMMA_OUT, halo_power_adapted*0.25) ;
	}
	
	if (DO_VIGNETTE == 1.0)
		color_out *= 0.8;
	
	return vec2(color_out/color_in, gamma_out );
}


vec2 apply_fuzzy_main_pass_stage_1_no_gamma_in() {
	//This simulates the final pass pixel processing so that previous passes like 
	//reflections, full screen luminance zoom and ambient light 
	//can react accordingly without doing the same thing twice.
	//For speed reasons, this lives in vertex shader and will output
	//a vec2(mul factor, pow factor)
	//in fragment shader one will pow(pow factor)*multiply factor;
	
	float color_in = 1.0;
	float color_out = 1.0;
	float gamma_out = 1.0;
	
	float halo_power_adapted;
	halo_power_adapted = HALO_POWER;
	if (HALO_NO_PREGAIN == 1.0) {
		halo_power_adapted /= get_halo_ungain_factor();
	}
	if (HALO_POWER < 0.0) 
		halo_power_adapted = -halo_power_adapted/10.0;
	
	color_out = pow(color_in, GAMMA_OUT); //<- nonsense ?
	gamma_out = gamma_out * GAMMA_OUT;

	if (DO_CCORRECTION == 1.0) {
		color_out = color_out * IN_GLOW_POWER;
	}
	
	if (DO_PIXELGRID == 1.0) {
		color_out *= 1- DO_PIXELGRID_H * 0.5   ; //Half color if scanline.
		color_out *= 1- DO_PIXELGRID_W * 0.5   ; //Half color if Hmask.
		color_out *= 1- PIXELGRID_Y_MASK * 0.2 ; //Strip at most 20% if level 2 ymask.
	}

	if (DO_HALO == 1.0) {
		color_out += color_in*halo_power_adapted / HALO_GAMMA;
		gamma_out = gamma_out * mix(1.0, HALO_GAMMA_OUT, halo_power_adapted*0.25) ;
	}
	
	if (DO_VIGNETTE == 1.0)
		color_out *= 0.8;
	
	return vec2(color_out/color_in, gamma_out );
}

vec3 apply_fuzzy_main_pass_stage_2(vec3 pixel_in, vec2 stage1 ) {
	//This gets the output of stage_1 to apply its pow and mul.
	return pow(pixel_in, vec3(stage1.y)) * stage1.x;
}

vec2 offsets_from_float(float in_param, int range){
	vec2 mul_factor = vec2(0.5);
	//mul_factor.x = NEW_SCALEMOD_X * 2;
    vec2 offsets = vec2(  
                  (int(in_param) % range) - range* 0.5,
                  floor(in_param / range) - range* 0.5
	        );
	offsets *= params.OutputSize.xy/vec2(NEW_SCALEMOD_REF_X, NEW_SCALEMOD_REF_Y)*0.5;
	return offsets;
}

/*
   vec2 circles(float param, float c_radius, float aspect, float directions) {
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

vec2 zoom(vec2 co, float zoom_factor) {
	return  0.5 + (co - 0.5) / zoom_factor;
}

float zoom1D(float co, float zoom_factor) {
	return  0.5 + (co - 0.5) / zoom_factor;
}

vec2 zoomxy(vec2 co, vec2 zoom_factor) {
	return  0.5 + (co - 0.5) / zoom_factor;
}

vec2 zoomout_coords_aspect(vec2 in_coords, float zoom_out, float aspect) {
   // to convert to standard zoom:
   // zoomout_coords(x) = zoom( 1/(x+1) );

   vec2 zoom   = vec2( 1 + zoom_out, 
                       1 + (zoom_out * aspect) 
                     );
                     
   vec2 offset = vec2( (zoom.x-1.0) / 2.0,
                       (zoom.y-1.0) / 2.0 
                     );
   
   return (in_coords * zoom) - offset;
}

vec2 zoomout_coords(vec2 in_coords, float zoom_out) {
   // to convert to standard zoom:
   // zoomout_coords(x) = zoom( 1/(x+1) );
   float zoom =  1 + zoom_out;
   float zoffset = zoom_out * 0.5;
   return (in_coords * zoom) - zoffset;
}

bool need_doublescan() {
	return (PIXELGRID_DOUBLESCAN == 1.0) && 
	       (params.OriginalSize.y < MIN_LINES_INTERLACED) ;
}

bool is_interlaced() {
	return                                                 // Content is interlaced if:
	       (MIN_LINES_INTERLACED) != 0.0 &&                // user wants interlacing and
		   (params.OriginalSize.y > MIN_LINES_INTERLACED); // content has a lot of lines
}

bool scanline_have_to_flicker(bool is_interlaced) {
	float scanline_flickering = PIXELGRID_INTR_FLICK_MODE;	
    return ((scanline_flickering == 1.0) || ((scanline_flickering==2.0) && is_interlaced ));
}

bool scanlines_will_alternate(bool is_interlaced) {
	return is_interlaced && PIXELGRID_INTR_DISABLE_Y != 2.0;
}

bool pixelgrid_h_needed() {
	return DO_PIXELGRID > 0.0 && DO_PIXELGRID_H > 0.0 && !(PIXELGRID_INTR_DISABLE_Y==1.0 && is_interlaced() );
}

float scale_to_range(float x, float dmin, float dmax) {
    //Scales 0..1 range to a..b range
    return ( (dmax-dmin) * x ) + dmin;
}

vec3 scale_to_range_vec3(vec3 x, float dmin, float dmax) {
    //Scales 0..1 range to a..b range
    return ( x * (dmax-dmin) ) + dmin; //ASM PROOF (fma slower)
}

vec3 scale_to_range_vec3(vec3 x, vec3 dmin, vec3 dmax) {
    //Scales 0..1 range to a..b range
    return ( (dmax-dmin) * x ) + dmin;
}

vec2 scale_to_range_vec2(vec2 x, float dmin, float dmax) {
    //Scales 0..1 range to a..b range
    return ( (dmax-dmin) * x ) + dmin;
}

float map_range(float value, float min_in, float max_in, float min_out, float max_out) {
	//Scales value in [min_in - max_in] to [min_out - max_out]
	return min_out + (value - min_in) * (max_out - min_out) / (max_in - min_in);
}

vec3 map_range(vec3 value, float min_in, float max_in, float min_out, float max_out) {
	//Scales value in [min_in - max_in] to [min_out - max_out]
	return min_out + (value - min_in) * (max_out - min_out) / (max_in - min_in);
}

float normalize_range(float value, float min_in, float max_in) {
	//Scales value in [min_in - max_in] to 0..1
	return (value - min_in)  / (max_in - min_in);
}

vec3 contrast_with_pivot(vec3 x, float c, float p){
	//c=1-->neutral
	return (x-1+p) * c + p;
}

vec3 apply_contrast_brightness(vec3 c, float contrast, float brightness) {
   return scale_to_range_vec3(c, -contrast, 1+contrast) + brightness;
}

float apply_contrast_brightness(float c, float contrast, float brightness) {
   return scale_to_range(c, -contrast, 1+contrast) + brightness;
}

float round_step(float x, float p) {
	return round(x*p)/p;
}

vec2 round_step(vec2 x, vec2 p) {
	return round(x*p)/p;
}

#define VEC2_RND_A_B vec2(12.9898, 78.233)
#define RND_C 43758.5453

float random(float power, vec2 seed) {
	#ifdef SKIP_RANDOM 
		return 0.0;
	#endif
    //From pal-singlepass.slang 
    //https://github.com/svofski/CRT
    //Copyright (c) 2016, Viacheslav Slavinsky
    //All rights reserved.
    float dt = dot(seed.xy, VEC2_RND_A_B);
    float sn = mod(dt,3.14);

    float noise_out = fract(sin(sn) * RND_C);

    noise_out = scale_to_range(noise_out, -power, power);
    return noise_out;
}

float deband_static(vec2 co, float power) {
	#define PI_HALF 1.5707963267949
	vec2 d = sin(co* PI_HALF * params.OutputSize.xy);
	float r = d.x * d.y * power;
	return r;
}

float deband_temporal(vec2 co, float power) {
	#define PI_HALF 1.5707963267949
	vec2 d = sin(co* PI_HALF * params.OutputSize.xy);
	float r = d.x * d.y * power;
	r= mix(r,-r, mod(params.FrameCount, 2.0));
	return r;
}

//The following produces weird results when with dynamic seed like framecount.
float random_fast(vec2 seed) {
	#ifdef SKIP_RANDOM 
		return 0.0;
	#endif
	//return 0.0;
	//return deband_static(seed, 0.001);
	
	float noise_out = fract(sin(dot(seed.xy, VEC2_RND_A_B)) * RND_C);
    return noise_out;
}

vec3 screen_space_dither(vec2 frag_coord) { 
	// Iestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified for VR. 
	vec3 dither = vec3(dot(vec2(171.0, 231.0), frag_coord)); 
	dither.rgb = fract(dither.rgb / vec3(103.0, 71.0, 97.0)); 

	// Subtract 0.5 to avoid slightly brightening the whole viewport. 
	return (dither.rgb - 0.5) / 255.0; 
} 

vec2 screen_space_displacement(vec2 co, vec2 outputsize, float size) { 
	// Based on // Iestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified for VR. 
	vec2 d = vec2(dot(vec2(171.0, 231.0), co*outputsize.xy)); 
	d.xy = fract(d.xy / vec2(97.0, 71.0)); 
	return d*size;
} 

float curvature_needed() {
	return DO_CURVATURE * (GEOM_WARP_X + GEOM_WARP_Y);
}

#define corner_aspect vec2(1.0,  0.75)
float fn_border(vec2 coord) {	
	//SIMD8 shader: 1271 instructions. 0 loops. 20568 cycles. 0:0 spills:fills, 23 sends, scheduled with mode top-down. Promoted 19 constants. Compacted 20336 to 15040 bytes (26%)
	//SIMD16 shader: 1271 instructions. 0 loops. 22328 cycles. 0:0 spills:fills, 23 sends, scheduled with mode top-down. Promoted 19 constants. Compacted 20336 to 15040 bytes (26%)
	coord = min(coord, vec2(1.0) - coord) * corner_aspect;
	vec2 delta = GEOM_CORNER_SIZE - coord;
	float dist = length(max(delta, vec2(0.0)));
	float o = clamp( (GEOM_CORNER_SIZE - dist) * GEOM_CORNER_SMOOTH + 0.75, 0.0, 1.0);
	return o;
}

//warp full new
vec2 Warp(vec2 uv,float wx, float wy){
	// Transform coordinates to range [-1, 1]
	uv = uv * 2.0 - 1.0;
	vec2 pow_exp = 1.0/(1.0+vec2(wx, wy) * 0.2 ) ;
	//float curvedCoordsDistance = length(uv);
	float curvedCoordsDistance = sqrt(uv.x*uv.x+uv.y*uv.y);
	curvedCoordsDistance = clamp(curvedCoordsDistance, 0.0, 1.4142);
	vec2 pow_base = vec2(1.0-(curvedCoordsDistance/1.4142135623730950488016887242097));
	pow_base = abs(pow_base); // <-- this way intel and nvidia (probably amd) acts the same.
	uv /= curvedCoordsDistance;
	uv *= (1.0-pow(pow_base,  pow_exp ));
	uv /= (1.0-pow(vec2(0.29289321881345247559915563789515),  pow_exp ));
	// Transform coordinates back to [0, 1]
	return uv* 0.5 + 0.5;
}

vec2 Warp_koko(vec2 co, vec2 w, float protrusion) {
	vec2 coff    = w * 0.625;
	float czoom  = 1 - distance(co, vec2(0.5));
	czoom        = mix(czoom, czoom * 0.5, czoom);
	vec2 czoom2d = mix(vec2(1.0), vec2(czoom), w);
	return zoomxy(co, coff + czoom2d );
}
	
float get_in_aspect() {	
	if (ASPECT_X ==  0) return 1.333333; //all mame games, not rotated
	if (ASPECT_X == -1) return 1.5;   // ntsc
	if (ASPECT_X == -2) return 1.25;  // pal
	if (ASPECT_X == -3) return 1.143; // 8/7 snes
	if (ASPECT_X == -4) return 1.428; // 10/7 megadrive
	if (ASPECT_X == -5) return params.OriginalSize.x/params.OriginalSize.y; //uncorrected
	if (ASPECT_X == -6) return 0.75;  // 3/4, pre-rotated (TATE) 1.33 games.
	
	//Handle cases when core aspect cannot be retrived and just return 4/3.
	float OriginalAspectRotated = 1.33333;
	float StretchedAspect = global.FinalViewportSize.x/global.FinalViewportSize.y;
	if ( is_rotated() )
		StretchedAspect = global.FinalViewportSize.y/global.FinalViewportSize.x;
	
	#ifdef _HAS_ORIGINALASPECT_UNIFORMS
		OriginalAspectRotated = global.OriginalAspectRotated;
	#endif
	
	if (ASPECT_X == -7) {
		if (DO_BG_IMAGE==0.0)
			return OriginalAspectRotated;
		else
			return 1.333333; //fallback to 4:3 when using background or foreground images.
	}
	
	if (ASPECT_X == -8)
			return OriginalAspectRotated;

	if (ASPECT_X == -9)
			return StretchedAspect;
	
	return ASPECT_X / ASPECT_Y ;
}

vec2 get_scaled_coords_aspect(vec2 pTexCoord, vec4 destsize, float in_aspect , bool is_rotated){
	vec2 scale = vec2(1.0);
	vec2 offst = vec2(0.0);

	if (is_rotated)
		destsize.xy=destsize.yx;

	if (destsize.x > destsize.y*in_aspect) {
		// fit width
		scale.x = destsize.x/(destsize.y * in_aspect);
	} else {
		// fit height
		scale.y = destsize.y/(destsize.x / in_aspect);
	}	

	offst = 0.5 * scale - 0.5;
	vec2 scale_coord = pTexCoord * scale - offst;
	return scale_coord;
}


vec2 get_scaled_coords_aspect_fgbg(vec2 pTexCoord, vec4 destsize, float aspect_image , bool is_rotated, float aspect_content){
	vec2 scale = vec2(1.0);
	vec2 offst = vec2(0.0);

	if (is_rotated)
		destsize.xy=destsize.yx;

	vec2 off_adj = vec2(0.0);
	
	if (destsize.x > destsize.y*aspect_content) {
		// fit width
		scale.x = destsize.x/(destsize.y * aspect_image);
					
		off_adj.x = -BG_IMAGE_OFFX *
						(1 - destsize.x/destsize.y) /
						aspect_image /
						BG_IMAGE_ZOOM;
	} else {
		// fit height
		scale.x = aspect_content * (1.0/aspect_image);
		scale.y = (destsize.y/destsize.x) * aspect_content ;			  
		
		off_adj.x = -BG_IMAGE_OFFX *
					(1-aspect_content) /
					aspect_image /
					BG_IMAGE_ZOOM;
		
		off_adj.y = -BG_IMAGE_OFFY *
						(1 - (destsize.y*aspect_content)/destsize.x) /
						BG_IMAGE_ZOOM;
	}	
	
	offst = 0.5 * scale + off_adj - 0.5;

	vec2 scale_coord = pTexCoord * scale - offst;
	return scale_coord;
}


vec2 integer_scale(vec2 in_coords, float target_aspect, bool is_rotated, float do_tate, float uncorrected_aspect) {

	float raw_in_aspect;

	if (do_tate == 1.0) {
		target_aspect = 1/target_aspect;
		raw_in_aspect = params.OriginalSize.y/params.OriginalSize.x;
	} else {
		raw_in_aspect = params.OriginalSize.x/params.OriginalSize.y;
	}

	float adapted_aspect = target_aspect / raw_in_aspect;

	//Keep aspect?
	adapted_aspect = mix_step(adapted_aspect, 1.0, uncorrected_aspect);
	if (do_tate == 0.0)
		in_coords.x = zoom1D(in_coords.x, adapted_aspect);
			else
		in_coords.y = zoom1D(in_coords.y, adapted_aspect);

	vec2 izoom;
	if (!is_rotated) {
		//This is 1X integer zoom:
		izoom = params.OriginalSize.xy / global.FinalViewportSize.xy;
		//Find the maximum zoom allowed
		vec2 int_zoom = floor(global.FinalViewportSize.yx / (params.OriginalSize.yx/(GAME_GEOM_INT_SCALE_OVR) ));
		int_zoom = clamp(int_zoom, 1.0, GAME_GEOM_INT_SCALE_MAX);
		
		if (raw_in_aspect < target_aspect)
			izoom *= min(int_zoom.x*adapted_aspect, int_zoom.y);
		else
			izoom *= min(int_zoom.x, int_zoom.y/adapted_aspect);
		
	} else {
		izoom = params.OriginalSize.xy / global.FinalViewportSize.yx;
		vec2 int_zoom = floor(global.FinalViewportSize.yx / (  (params.OriginalSize.xy*adapted_aspect)/(GAME_GEOM_INT_SCALE_OVR) ));
		int_zoom = clamp(int_zoom, 1.0, GAME_GEOM_INT_SCALE_MAX);
		izoom *= min(int_zoom.x, int_zoom.y*adapted_aspect);
	}
	return zoomxy(in_coords, izoom);
}

bool need_NO_integer_scale() {
	//returns if no integer scaling is requested.
	return DO_GAME_GEOM_OVERRIDE * GAME_GEOM_INT_SCALE == 0.0;
}

bool need_integer_scale() {
	//return if integer scaling is requested.
	//return DO_GAME_GEOM_OVERRIDE == 1.0 && GAME_GEOM_INT_SCALE > 0.01;
	return DO_GAME_GEOM_OVERRIDE * GAME_GEOM_INT_SCALE != 0.0;
}

vec2 content_geom_override_shift(vec2 co, float aspect, float in_aspect, float vshift, float hshift, float out_zoom){
	//Aspect (ASM PROOF: IFTHEN is better)
	//shift
	vec2 shift = round_step(vec2(hshift, vshift)*0.1, params.OriginalSize.xy);
	co -= shift;
	return co;
}

vec2 content_geom_override_zoom(vec2 co, float aspect, float in_aspect, float vshift, float hshift, float out_zoom){
	// see next (**)
	float scale_y;
	
	#ifdef _HAS_ORIGINALASPECT_UNIFORMS
		/* for aspect < 0.0, just use core aspect */
		if (aspect < 0.0) {
			aspect = global.OriginalAspectRotated;
			scale_y = aspect/in_aspect;
		} else		
	#endif

	if (aspect > 0.01) 
		scale_y = aspect/in_aspect;
	else
		scale_y = 1.0;

	
	float offset_y = (0.5 * scale_y ) - 0.5 ;
	co.y = co.y*scale_y - offset_y;
	//zoom
	return zoom(co, out_zoom);
}	

vec2 content_geom_override_zoom_inv(vec2 co, float aspect, float in_aspect, float vshift, float hshift, float out_zoom){
	// (**) This has to be exactly has the not _inv version, it returns the same but with zoom counteracted, inverted. 
	float scale_y;
	if (aspect > 0.01) 
		scale_y = aspect/in_aspect;
			else
		scale_y = 1.0;
	
	float offset_y = (0.5 * scale_y ) - 0.5 ;
	co.y = co.y*scale_y - offset_y;
	//zoom
	return zoom(co, 1/out_zoom);
}	

vec2 content_geom_override(vec2 co, float aspect, float in_aspect, float vshift, float hshift, float out_zoom){
	//cheap cardboard emulation:
	//co = co*2.0 - vec2(0.0,0.5);
	//if (co.x > 1.0) co.x -= 1;
	vec2 co_shifted = content_geom_override_shift( co,  aspect,  in_aspect,  vshift,  hshift,  out_zoom);
	vec2 co_shifted_zoomed = content_geom_override_zoom( co_shifted,  aspect,  in_aspect,  vshift,  hshift,  out_zoom);
	return co_shifted_zoomed;
}
	
//Blur/Glow
#define PI 3.14159265359

vec2 radius_blur_adapt_ext_inaspect(float bsize, float aspect){
    vec2 r;
    r.x = bsize / BLOOM_AND_HALO_SCALE_FACTOR;
    r.y = r.x * aspect;
    return r;
}

vec2 radius_blur_adapt(float bsize){
    vec2 r;
    r.x = bsize / BLOOM_AND_HALO_SCALE_FACTOR;
    r.y = r.x *  get_in_aspect();
    return r;
}

vec2 radius_blur_adapt(vec2 bsize){
    vec2 r;
    r.x = bsize.x / BLOOM_AND_HALO_SCALE_FACTOR;
    r.y = r.x *  get_in_aspect();
    return r;
}

float sinc_lanczos(float x) {
    if (abs(x) < 0.001)
        return 1.0;

    x *= pi;
    return sin(x) / x;
}

//Lanczos kinda broken, problematic.
vec3 lanczos(sampler2D sampler_in, vec2 co, vec4 texsize, float sharpness ) {
   
   float data_pix_no = co.x * texsize.x;
   float data_one    = texsize.z;
   
   float texel      = floor(data_pix_no);
   float phase      = data_pix_no - texel;
   float base_phase = phase - 0.5;
   vec2 tex         = vec2((texel + 0.5) * texsize.z, co.y);

   vec3 col = vec3(0.0);
   for (int i = -2; i <= 2; i++) {
      float phase = base_phase - float(i);
      phase*= sharpness;
      if (abs(phase) < 2.0) { //FIXME check needed?
         float g = sinc_lanczos(phase);
         col += texture(sampler_in, tex + vec2(float(i) * data_one, 0.0)).rgb * g;
      }
   }

   return col * sharpness;
} 

vec3 blur9_x_box(sampler2D image, vec2 uv, vec2 sourcesize, float sharpness_x, float sharp_sub) {
	//sharp_sub = -2*sharp_sub+1;
	float resolution = sourcesize.x * sharpness_x;
	vec3 color = vec3(0.0);
	
	vec2 off1 = vec2(1.0 / resolution, 0.0)  ;
	vec2 off2 = vec2(2.0 / resolution, 0.0)  ;
		
	color += texture(image, uv).rgb        ;
	color += texture(image, uv + off1).rgb ;
	color += texture(image, uv - off1).rgb ;
	color += texture(image, uv + off2).rgb * sharp_sub;
	color += texture(image, uv - off2).rgb * sharp_sub;
	color = color/(3.0 + sharp_sub*2);
	return max(vec3(0.0), color);
	}

vec3 blur9_y_box(sampler2D image, vec2 uv, vec2 sourcesize, float sharpness_y, float sharp_sub) {
	//sharp_sub = -2*sharp_sub+1;
	float resolution = sourcesize.y * sharpness_y;
	vec3 color = vec3(0.0);
	vec2 off1 = vec2(0.0, 1.0 / resolution) ;
	vec2 off2 = vec2(0.0, 2.0 / resolution) ;
	color += texture(image, uv).rgb                       ;
	color += texture(image, uv + off1).rgb ;
	color += texture(image, uv - off1).rgb ;
	color += texture(image, uv + off2).rgb * sharp_sub;
	color += texture(image, uv - off2).rgb * sharp_sub;
	color = color/(3.0 + sharp_sub*2);
	return max(vec3(0.0), color);
}

vec3 glow_dumb(sampler2D in_texture, float glow_power, float gamma, vec2 coords) {
	return pow( texture(in_texture, coords).rgb, vec3(gamma) ) * glow_power;
}

vec3 blur9_x(sampler2D image, vec2 uv, vec2 sourcesize, float sharpness_x) {
	float resolution = sourcesize.x * sharpness_x;
	vec3 color = vec3(0.0);
	vec2 off1 = vec2(1.3846153846 / resolution, 0.0);
	vec2 off2 = vec2(3.2307692308 / resolution, 0.0);
	color += texture(image, uv).rgb                       * 0.2270270270;
	color += texture(image, uv + off1).rgb * 0.3162162162;
	color += texture(image, uv - off1).rgb * 0.3162162162;
	color += texture(image, uv + off2).rgb * 0.0702702703;
	color += texture(image, uv - off2).rgb * 0.0702702703;
	return color;
}

vec3 blur9_x_gamma(sampler2D image, vec2 uv, vec2 sourcesize, float sharpness_x, vec3 gamma) {
	float resolution = sourcesize.x * sharpness_x;
	vec3 color = vec3(0.0);
	vec2 off1 = vec2(1.3846153846 / resolution, 0.0);
	vec2 off2 = vec2(3.2307692308 / resolution, 0.0);
	vec3 lookup = texture(image, uv).rgb;
	color += pow(lookup, gamma) * 0.2270270270;
	lookup = texture(image, uv + off1).rgb;
	color += pow(lookup, gamma) * 0.3162162162;
	lookup = texture(image, uv - off1).rgb;
	color += pow(lookup, gamma) * 0.3162162162;
	lookup = texture(image, uv + off2).rgb;
	color += pow(lookup, gamma) *  0.0702702703;
	lookup = texture(image, uv - off2).rgb;
	color += pow(lookup, gamma) *  0.0702702703;
	return color;
}

vec3 blur9_y_gamma(sampler2D image, vec2 uv, vec2 sourcesize, float sharpness_x, vec3 gamma) {
	float resolution = sourcesize.x * sharpness_x;
	vec3 color = vec3(0.0);
	vec2 off1 = vec2(0.0, 1.3846153846 / resolution) ;
	vec2 off2 = vec2(0.0, 3.2307692308 / resolution) ;
	vec3 lookup = texture(image, uv).rgb;
	color += pow(lookup, gamma) * 0.2270270270;
	lookup = texture(image, uv + off1).rgb;
	color += pow(lookup, gamma) * 0.3162162162;
	lookup = texture(image, uv - off1).rgb;
	color += pow(lookup, gamma) * 0.3162162162;
	lookup = texture(image, uv + off2).rgb;
	color += pow(lookup, gamma) *  0.0702702703;
	lookup = texture(image, uv - off2).rgb;
	color += pow(lookup, gamma) *  0.0702702703;
	return color;
}

vec3 blur9_y(sampler2D image, vec2 uv, vec2 sourcesize, float sharpness_y) {
	float resolution = sourcesize.y * sharpness_y;
	vec3 color = vec3(0.0);
	vec2 off1 = vec2(0.0, 1.3846153846 / resolution) ;
	vec2 off2 = vec2(0.0, 3.2307692308 / resolution) ;
	color += texture(image, uv).rgb       * 0.2270270270;
	color += texture(image, uv + off1).rgb * 0.3162162162;
	color += texture(image, uv - off1).rgb * 0.3162162162;
	color += texture(image, uv + off2).rgb * 0.0702702703;
	color += texture(image, uv - off2).rgb * 0.0702702703;
	return color;
}

vec3 blur9_x_box1tap(sampler2D image, vec2 uv, vec2 sourcesize, float sharpness_x) {
	float resolution = sourcesize.x * sharpness_x;
	vec3 color = vec3(0.0);
	
	vec2 off1 = vec2(1.0 / resolution, 0.0)  ;
	vec2 off2 = vec2(2.0 / resolution, 0.0)  ;
		
	color += texture(image, uv).rgb        ;
	color += texture(image, uv + off1).rgb ;
	color += texture(image, uv - off1).rgb ;
	color = color/3.0;
	return color;
}
	
vec3 blur_px(sampler2D smp, vec2 co, vec2 r) {
    vec3 c=vec3(0.0);
    //float c1 = 0.75;
    //float c2 = 1.25;

	#define KAIO_c1 1.0
	#define KAIO_c2 1.0

    c += texture(smp, co + vec2(0.0, 1.0) * r).rgb * KAIO_c1;
    c += texture(smp, co + vec2(0.7071, 0.7071) * r).rgb * KAIO_c2;
    c += texture(smp, co + vec2(1.0, 0.0) * r).rgb * KAIO_c1 ;
    c += texture(smp, co + vec2(0.7071, -0.7071) * r).rgb * KAIO_c2;
    c += texture(smp, co + vec2(0.0, -1.0) * r).rgb * KAIO_c1;
    c += texture(smp, co + vec2(-0.7071, -0.7071) * r).rgb * KAIO_c2;
    c += texture(smp, co + vec2(-1.0, 0.0) * r).rgb * KAIO_c1;
    c += texture(smp, co + vec2(-0.7071, 0.7071) * r).rgb * KAIO_c2;

    //vec3 c0 = texture(smp, co + vec2(0.0, 0.0) * r).rgb;
    //return min(c0, c/8.0);
    return c/8.0;
}

vec3 blur5_x(sampler2D image, vec2 uv, float sourcesize_x, float sharpness_x, float lod) {
	float resolution = sourcesize_x * sharpness_x;
	vec3 color = vec3(0.0);
	vec2 off1 = vec2(1.333333333333 / resolution, 0.0);
	color += textureLod(image, uv, lod).rgb   * 0.29411764705882354;
	color += textureLod(image, uv + off1, lod).rgb   * 0.35294117647058826;
	color += textureLod(image, uv - off1, lod).rgb   * 0.35294117647058826;
	return color;
}

vec3 blur5_y(sampler2D image, vec2 uv, float sourcesize_y, float sharpness_y, float lod) {
	float resolution = sourcesize_y * sharpness_y;
	vec3 color = vec3(0.0);
	vec2 off1 = vec2(0.0, 1.333333333333 / resolution) ;
	color += textureLod(image, uv, lod).rgb   * 0.29411764705882354;
	color += textureLod(image, uv + off1, lod).rgb   * 0.35294117647058826;
	color += textureLod(image, uv - off1, lod).rgb   * 0.35294117647058826;
	return color;
}

#define RGB2GRAY_VEC3 vec3(0.299, 0.587, 0.114)
float rgb_to_gray(vec3 rgb) {
    return dot(rgb, RGB2GRAY_VEC3);
}
	

vec3 hsv2rgb(vec3 c){
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

#define eps10 1.0e-10
vec3 rgb2hsv(vec3 c){
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + eps10)), d / (q.x + eps10), q.x);
}
	
vec2 rgb2hv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    return vec2(abs(q.z + (q.w - q.y) / (6.0 * d + 0.0001)), q.x);
}

float delta_render_enabled(){
    #ifdef DELTA_RENDER
        return 1.0;
    #else
        return 0.0;
    #endif
}

bool bdelta_render_enabled(){
    #ifdef DELTA_RENDER
        return true;
    #else
        return false;
    #endif
}

float delta_render_get_force_refresh() {
	#ifdef DELTA_RENDER_FORCE_REFRESH
		return DELTA_RENDER_FORCE_REFRESH;
	#else
		return 4.0;
	#endif
}

float delta_render_get_check_area() {
	#ifdef DELTA_RENDER_CHECK_AREA
		return DELTA_RENDER_CHECK_AREA;
	#else
		return 1.0;
	#endif
}

float get_dyn_zoom(sampler2D tex) {
	if (delta_render_enabled() == 0.0)
		return texture(tex, DYN_ZOOM_SAMPLING_POINT ).a * DO_DYNZOOM + 1.0 ;
	else
		return 1.0;
}

float get_autocrop_zoom(sampler2D tex) {
	if (delta_render_enabled() == 0.0)
		return texture(tex, AUTOCROP_SAMPLING_POINT).a;
	else
		return 1.0;
}

vec2 tilt2D(vec2 co, float is_rotated, vec2 tilt) {

	vec2 r_tilt = vec2( mix_step(tilt.x, tilt.y, is_rotated),
	                    mix_step(tilt.y, -tilt.x, is_rotated)
					);
	
	vec2 tilt_min = 1 - r_tilt;
	vec2 tilt_max = 1 + r_tilt;
	
	// X Tilt
		float tilt_x_range = scale_to_range(co.y, tilt_min.x, tilt_max.x);
		co = vec2( zoom1D(co.x, tilt_x_range),
		           zoom1D(co.y, tilt_x_range)
			);

		
	// Y Tilt
		float tilt_y_range = scale_to_range(co.x, tilt_min.y, tilt_max.y);
		co = vec2( zoom1D(co.x, tilt_y_range),
		           zoom1D(co.y, tilt_y_range)
			);
	
		co.xy += mix_step(tilt.yx, -tilt.xy, is_rotated) * 0.5;
		
	return co;

}
	
vec2 tilt(vec2 co, float is_rotated, float tilt) {

	vec2 r_tilt = vec2( mix_step(tilt, 0.0, is_rotated),
	                    mix_step(0.0, -tilt, is_rotated)
					);
	
	vec2 tilt_min = 1 - r_tilt;
	vec2 tilt_max = 1 + r_tilt;

	// X Tilt
		float tilt_x_range = scale_to_range(co.y, tilt_min.x, tilt_max.x);
	// Y Tilt
		float tilt_y_range = scale_to_range(co.x, tilt_min.y, tilt_max.y);
		
	// Zoom:
		co = 0.5 + (co - 0.5) / (tilt_y_range * tilt_x_range);
		
	if (is_rotated > 0.5) //ASM PROOF
		co.xy -= vec2(tilt, 0.0) * 0.5;
	else
		co.xy += vec2(0.0, tilt) * 0.5;
		
	return co;
}
	
vec2 tilt_bezel(vec2 co, float is_rotated, float btilt ) {
	
	btilt*=BEZEL_TILT_MULTIPLIER;
	
	//ASM PROOF: if then is worse.
	vec2 r_tilt = vec2( mix_step(btilt, 0.0, is_rotated),
	                    mix_step(0.0, -btilt, is_rotated)
					);
	
	vec2 tilt_min = 1 - r_tilt;
	vec2 tilt_max = 1 + r_tilt;

	// X Tilt
		float tilt_x_range = scale_to_range(co.y, tilt_min.x, tilt_max.x);
	// Y Tilt
		float tilt_y_range = scale_to_range(co.x, tilt_min.y, tilt_max.y);

	// Zoom:
		co = 0.5 + (co - 0.5) / (tilt_y_range * tilt_x_range);
		
	if (is_rotated > 0.5) { //ASM PROOF
		co.xy -= vec2( (btilt - btilt*BEZEL_TILT_Y_SHIFT)*0.5 , 0.0);
	} else {
		co.xy += vec2(0.0, (btilt-btilt*BEZEL_TILT_Y_SHIFT)*0.5);
	}
	
	return co;
}
	
//Following is faster (ASM proof)
bool is_first_inside_rect(vec2 point, vec4 rect) {
	vec2 bounded = clamp(point, rect.xy, rect.zw);
	return point == bounded;
}
bool is_first_outside_rect(vec2 point, vec4 rect) {
	vec2 bounded = clamp(point, rect.xy, rect.zw);
	return point != bounded;
}

// COLOR TOOLS

#define W_C_TO_GRAY vec3(0.2125, 0.7154, 0.0721)

float saturation_get(vec3 rgb) {
    float Cmax = max(max(rgb.r, rgb.g), rgb.b);
    float Cmin = min(min(rgb.r, rgb.g), rgb.b);
    return (Cmax - Cmin) / (Cmax+eps);
}

vec3 saturation_set_gain(vec3 c, float s) {
    float gray = dot(c, W_C_TO_GRAY);
    return mix( vec3(gray), c, s);
}

vec3 vibrance_set(vec3 c, float v) {
    //Usefult v values from 0.0 to about 4.0
    float start_saturation = saturation_get(c);
    float saturation_compressed = pow(start_saturation, v+eps);
    float saturation_gain = 2 - saturation_compressed;
    return saturation_set_gain(c, saturation_gain );
}


vec3 kelvin2rgb(float k) {
	//Convert kelvin temperature to rgb factors
	k = clamp(k,1000,40000);
	k=k/100.0;
	float tmpCalc;
		vec3 pixel_out;
	if (k<=66) {
		pixel_out.r = 255;
		pixel_out.g = 99.47080258612 * log(k) - 161.11956816610;
	} else {
		pixel_out.r = 329.6987274461 * pow(k - 60 ,-0.13320475922);
		pixel_out.g = 288.12216952833 * pow(k-60, -0.07551484921);
	}

	if (k >= 66)
		pixel_out.b = 255;
	else if (k<=19)
		pixel_out.b = 0;
	else
		pixel_out.b = 138.51773122311 * log(k - 10) - 305.04479273072;

	return pixel_out/255.0;
}

vec3 adaptive_black(vec3 c_in, float lum_in, float range) {
	//the less the brightness, the less the gamma.
	
	float contrast = mix(range*0.5, 0.0, pow(lum_in*8, 0.25));
	contrast = clamp(contrast,0.0,1.0);
	return apply_contrast_brightness(c_in, -contrast , +contrast);
	
	
	
	
	
	/*
	float luminance_adapt = mix( 1-range, 1+range, lum_in);
	return c_in * luminance_adapt - luminance_adapt + 1;
	return fma(c_in, vec3(luminance_adapt), vec3(-luminance_adapt + 1)); //ASM_PROOF: SAME
	*/
	
}

vec3 color_tools(vec3 pixel_out, vec3 Temperature_rgb) {
	//Apply color corrections to input signal.

	//Push luminance without clipping
		pixel_out = pixel_push_luminance(pixel_out,LUMINANCE);

	//Modify contrast and brightness
		//if (CONTRAST != 0.0 || BRIGHTNESS != 0.0) // TESTME which is faster?
		if (abs(CONTRAST) + abs(BRIGHTNESS) > 0.0) //<- one of them is != 0.0
			pixel_out.rgb = apply_contrast_brightness(pixel_out.rgb, CONTRAST, BRIGHTNESS);

	//Modify color temperature
		if (TEMPERATURE != 6500.0) pixel_out.rgb = pixel_out.rgb * Temperature_rgb;

	//Colorization for monochrome display on hsv colorspace.
	//Select different hues for dark and bright pixels and mix them depending on the brightness
	if (COLOR_MONO_COLORIZE > 0.01) {
		vec3 pixel_grayscale = vec3(dot(pixel_out.rgb, W_C_TO_GRAY));
		vec3 pixel_in_hsv = rgb2hsv(pixel_grayscale); //FIXME needed? yes, checked.
		float lum = pixel_in_hsv.z * pixel_in_hsv.z; //<-- looks way better!

		//vec2 bias = mix_step( vec2(0.0, abs(COLOR_MONO_HUE_BIAS)), vec2(abs(COLOR_MONO_HUE_BIAS), 0.0), float(COLOR_MONO_HUE_BIAS > 0.0));
		//Following should be faster (ASM PROOF)
		vec2 bias;
		if (COLOR_MONO_HUE_BIAS > 0.0) 
			bias = vec2(abs(COLOR_MONO_HUE_BIAS),0.0);
		else
			bias = vec2(0.0,abs(COLOR_MONO_HUE_BIAS));
			
		lum=scale_to_range(lum, 0.0-bias.x, 1.0+bias.y);
		pixel_in_hsv.y=1.0; //sat

		//Mix hues in rgb colorspace:
			vec3 pixel_rgb_hue1 = hsv2rgb( vec3(COLOR_MONO_HUE1, 1.0, pixel_in_hsv.z ) );
			vec3 pixel_rgb_hue2 = hsv2rgb( vec3(COLOR_MONO_HUE2, 1.0, pixel_in_hsv.z ) );
			vec3 pixel_rgb_hue12 = mix(pixel_rgb_hue2, pixel_rgb_hue1, vec3(lum));
		//Mix original and colorized with a specified strength
			pixel_out = mix(pixel_out, pixel_rgb_hue12, COLOR_MONO_COLORIZE);
	}

//Modify Vibrance
	if (VIBRANCE > 0.0) {
		pixel_out.rgb = vibrance_set(pixel_out.rgb, VIBRANCE);
	}
	
//Modify saturation
	if (SATURATION != 1.0) {
		vec3 intensity = vec3(dot(pixel_out.rgb, W_C_TO_GRAY));
		pixel_out.rgb = mix(intensity, pixel_out.rgb, SATURATION);
	}

	return pixel_out;
}

vec4 PG_get_hmask_preset_wrapped() {
	
	vec3 gm, gmx, rgb, rgbx, rbg, rbgx, wx, rgxb, wwx;
	
	/* "snapped" masks acts like floored ones, they are fine centered so they looks
	 * sharp at screen/pixel coordinates.
	 * Contrary, not snapped/relaxed masks are centered in the RGB cell so that tey can
	 * "bleed" better.
	 * 
	 * We use snapped positioning only when screen coords and multiplicator = 1.0 are both used-
	 * is 1.0 (-1.0 is not) or either a TVL is requested.
	*/
	bool snap = PIXELGRID_SIZE_W == 1.0 && PIXELGRID_MUL_X == 1.0;
	
	 if (snap) {
		gm   = vec3(0.5, -0.5, 0.5);
		gmx  = vec3(0, 2, 0);
		rgb  = vec3(2, 3, 1);
		rgbx = vec3(2.5, 3.5, 0.5); 
		rbg  = vec3(2, 1, 3);
		rbgx = vec3(2.5, 0.5, 3.5); 
		wx   = vec3(0.5, 0.5, 0.5);
		rgxb = vec3(2.5, 3.5, 1.5);
		wwx  = vec3(0.5, 0.5, 0.5); //not possible with snapping
	 } else {
		gm   = vec3(0.5, -0.5, 0.5);
		gmx  = vec3(0.5, -0.5, 0.5);
		rgb  = vec3(-1, 0, 1);
		rgbx  = vec3(-1, 0, 1);
		rbg  = vec3(-1, 1, 0);
		rbgx  = vec3(-1, 1, 0);
		wx   = vec3(0,  0, 0);
		rgxb = vec3(0, 1, -1);
		wwx  = vec3(0, 0, 0); 
	 }
	
    if (PIXELGRID_H_PRST == 0.0) // manual mask and size
        return vec4( PIXELGRID_R_SHIFT, PIXELGRID_G_SHIFT, PIXELGRID_B_SHIFT, PIXELGRID_H_COUNT);

    if (PIXELGRID_H_PRST == 1.0) return vec4( gm  , 2);
    if (PIXELGRID_H_PRST == 2.0) return vec4( gmx , 3);
    if (PIXELGRID_H_PRST == 3.0) return vec4( rgb , 3);
    if (PIXELGRID_H_PRST == 4.0) return vec4( rgbx, 4);
	if (PIXELGRID_H_PRST == 5.0) return vec4( rbg , 3);
    if (PIXELGRID_H_PRST == 6.0) return vec4( rbgx, 4);
    if (PIXELGRID_H_PRST == 7.0) return vec4( wx  , 2);
    if (PIXELGRID_H_PRST == 8.0) return vec4( rgxb, 4);		
	                             return vec4( wwx,  2);
}

vec4 PG_get_hmask_preset() {
	vec4 c = PG_get_hmask_preset_wrapped();
	//alternate submask color positions to help sample-and-hold induced blurring
	#ifndef D3D_WORKAROUND
		#ifdef DO_LCD_ANTIGHOSTING
			if (LCD_ANTIGHOSTING_FLIP_MASK == 1.0) {
				if (frame_is_even())
				c.xyz = c.zxy;
			}
		#endif
	#endif
	return c;
}


vec3 strobe( vec3 c) {
    #define STRENGTH_1 0.075 //effect strength

    if ( frame_is_even() ) {
       return c * (1+STRENGTH_1);
    }else {
       return c * (1-STRENGTH_1);
    }
}


vec3 adaptive_strobe(vec3 c, float osc) {

	#ifndef DO_ADPT_STROBE
		return c;
	#endif

	c = clamp(c, vec3(0.0), vec3(1.0));

	float gain_adj =  mix(1.0, ADPT_STROBE_GAIN_ADJ,  ADPT_STROBE_STR);

	vec3 osc3 = vec3(osc);
	if (osc > 0.0) {		
		osc3 = mix( osc3*gain_adj, osc3 * gain_adj * c, ADPT_STROBE_GAIN_ADJ_NODARK) ;
	}

	vec3 room = (0.5 - abs(0.5-c));
	c += room * osc3 * ADPT_STROBE_STR ;

	float gamma_adj = mix(1.0, ADPT_STROBE_GAMMA_ADJ, ADPT_STROBE_STR);
	c = pow(c, vec3(gamma_adj));

	return c;
}

vec3 adaptive_strobe_old( vec3 c) {
    #define STRENGTH 0.1375; //effect strength
    #define BRIGHT_BIAS 1.0 //brightness compensation
    #define CONTRAST_COMPENSATION 0.5 //maximum contrast compensation
    #define GAIN_COMPENSATION 0.5 //maximum gain compensation

    vec3 c_temp = c.rgb;
    c_temp = clamp(c_temp, vec3(0.0), vec3(1.0));
    vec3 room = (0.5 - abs(0.5-c_temp)) * STRENGTH;

    vec3 contrast_adj = mix(vec3(0.0), vec3(-CONTRAST_COMPENSATION), room);
    vec3 gain_adj = mix(vec3(1.0), vec3(GAIN_COMPENSATION), room);

     //Adjust brightness/contrast
    c = ( (1+contrast_adj+contrast_adj)* c)-contrast_adj;
    c *= gain_adj;

    if ( frame_is_even() ) {
       return c +  room / BRIGHT_BIAS;
    }else {
       return c -  room * BRIGHT_BIAS;
    }
}

vec3 adaptive_strobe_checkerboard(vec3 pixel_out, vec2 co, vec2 outputsize) {

	
	float strength = 0.5;		//0.5 is good
    float square_size = 3;      //checkerboard squares border size (1.0 = full screen blank)
    float period_blank = 1.0;   //draw checkerboard every "period_blank" frames
    float period_flip = 2.0 ;   //invert checkerboard colors every # frames, usually/try period_blank*2.
    
    
    bool is_blank_time = (mod(params.FrameCount, period_blank) == 0.0);

	if (is_blank_time) {
		vec3 checkerboard = vec3(1.0);
		if (mod( floor(co.x * outputsize.x), square_size) >= square_size/2.0)
				checkerboard = vec3(1.0);
					else
				checkerboard = vec3(-1.0);

		if (mod( floor(co.y * outputsize.y), square_size) >= square_size/2.0)
			checkerboard = -checkerboard;
		
		if (mod(params.FrameCount, period_flip) >= period_flip/2.0) 
			checkerboard = -checkerboard;

		checkerboard *= min( pixel_out, 1-(pixel_out)  ) * strength;
		
		//#define SPLIT_SCREEN
		#ifdef SPLIT_SCREEN
		if (co.x > 0.5)
			pixel_out.rgb = pixel_out.rgb+ checkerboard;
		#else
			pixel_out.rgb = pixel_out.rgb+ checkerboard;
		#endif

	}
   
    
    return pixel_out;
    
}

vec2 r2(vec2 p0, int n) {
    
    //return fract(p0 + float(n)*vec2(0.754877669, 0.569840296));
    return fract(p0 + vec2(n*12664745, n*9560333)/exp2(24.));	// integer mul to avoid round-off
}

float lodmax(vec2 texsize) {
	//lod needed to average all texture points.
    return log2(max(texsize.x, texsize.y));
}

bool deltarender_frame_is_forced_refresh() {
	 // - We are in a frame that is forced for full refresh
	return params.FrameCount % int(delta_render_get_force_refresh()) == 0.0 ;
}

bool deltarender_frame_is_not_forced_refresh() {
	 // - We are in a frame that is forced for full refresh
	return params.FrameCount % int(delta_render_get_force_refresh()) != 0.0 ;
}

bool deltarender_preconditions_met(bool is_interlaced) {
	return ( (! is_interlaced) || PIXELGRID_INTR_DISABLE_Y >= 1.0 || DO_PIXELGRID_H == 0.0);
}


float is_deltarender_allowed(bool is_interlaced) {
	// Delta render, mandatory conditions:
    return float(deltarender_frame_is_not_forced_refresh() &&   // - We are in a frame that is not forced for full refresh
           deltarender_preconditions_met(is_interlaced)); // - screen is not interlaced or we disabled scanlines on interlaced content
}

float delta_render_changed(sampler2D smp_past, sampler2D smp_now, vec2 co, float lod) {
   vec3 s1 = textureLod(smp_now,  co, 1.0).rgb; // It is important that this is with lod = 1.0
   vec3 s2 = textureLod(smp_past, co, 1.0).rgb; // It is important that this is with lod = 1.0
   vec3 m1 = textureLod(smp_now,  co, lod).rgb;
   vec3 m2 = textureLod(smp_past, co, lod).rgb;
   
   if (m1 == m2 && s1==s2 )
      return 0.0;
   else
      return 1.0;

}

float distance_from_edge(vec2 co, float gamma) {
	float aoe=0.2;
	vec2 s = smoothstep_fast( vec2(0.5), vec2(aoe), abs(co-0.5));
	float dfe=(s.x*s.y);
	return dfe;
	
	vec2 sinpi = sin(co*pi);
	float dist_from_edge = (sinpi.x*sinpi.y);
	return pow(dist_from_edge, gamma);
}


float distance_from_edge_linear(vec2 co, float aoe_inv) {
	vec2 s = smoothstep_fast( vec2(0.5+eps), vec2(aoe_inv), abs(co-0.5));
	float dfe=(s.x*s.y);
	return dfe;
}

float get_rf_noise(vec2 seed) {
	// Eg: seed = vTexCoord * mod(params.FrameCount, 120.0001);
	float anoise = random_fast(seed);
	return scale_to_range(anoise, - RF_NOISE_STRENGTH * RF_NOISE_STRENGTH, RF_NOISE_STRENGTH * RF_NOISE_STRENGTH)
	       + smoothstep_fast(0.98, 1.0, anoise) * RF_NOISE_SPARK;
}

vec3 clip_to_white_maybe(vec3 c) {
	vec3 clips = max(vec3(0), c - 1 );
	c.rgb += vec3(  clips.g+clips.b, clips.r+clips.b, clips.r+clips.g ) * CLIP_TO_WHITE;
	return c;
}
