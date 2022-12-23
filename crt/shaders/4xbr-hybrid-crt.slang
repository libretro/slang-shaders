#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#define mul(a, b) (b * a)

const float coef           = 2.0;
const vec4 eq_threshold  = vec4(15.0, 15.0, 15.0, 15.0);
const float y_weight        = 48.0;
const float u_weight        = 7.0;
const float v_weight        = 6.0;
const mat3 yuv          = mat3(0.299, 0.587, 0.114, -0.169, -0.331, 0.499, 0.499, -0.418, -0.0813);
const mat3 yuv_weighted = mat3(y_weight*yuv[0], u_weight*yuv[1], v_weight*yuv[2]);
const vec4 delta       = vec4(0.4, 0.4, 0.4, 0.4);
const float sharpness    = 0.65;

// Constants used with gamma correction.
const float InputGamma = 2.4;
const float OutputGamma = 2.2;

// 0.5 = the spot stays inside the original pixel
// 1.0 = the spot bleeds up to the center of next pixel
const float SPOT_HEIGHT = 0.58;

// Used to counteract the desaturation effect of weighting.
const float COLOR_BOOST = 1.45;
	
// Macro for weights computing
#define WEIGHT(w) \
	if(w>1.0) w=1.0; \
	w = 1.0 - w * w; \
	w = w * w;\
	
vec4 df(vec4 A, vec4 B)
{
	return vec4(abs(A-B));
}

float c_df(vec3 c1, vec3 c2)
{
	vec3 df = abs(c1 - c2);
	return df.r + df.g + df.b;
}

bvec4 eq(vec4 A, vec4 B)
{
    bool a = df(A, B).x < eq_threshold.x;
    bool b = df(A, B).y < eq_threshold.y;
    bool c = df(A, B).z < eq_threshold.z;
    bool d = df(A, B).w < eq_threshold.w;
	return bvec4(a, b, c, d);
}

bvec4 eq2(vec4 A, vec4 B)
{
    bool a = df(A, B).x < 2.0;
    bool b = df(A, B).y < 2.0;
    bool c = df(A, B).z < 2.0;
    bool d = df(A, B).w < 2.0;
	return bvec4(a, b, c, d);
}

vec4 weighted_distance(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e, vec4 f, vec4 g, vec4 h)
{
	return (df(a,b) + df(a,c) + df(d,e) + df(d,f) + 4.0*df(g,h));
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 t1;
layout(location = 2) out vec4 t2;
layout(location = 3) out vec4 t3;
layout(location = 4) out vec4 t4;
layout(location = 5) out vec4 t5;
layout(location = 6) out vec4 t6;
layout(location = 7) out vec4 t7;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;

	vec2 ps = vec2(params.SourceSize.zw);
	float dx = ps.x;
	float dy = ps.y;

	//    A1 B1 C1
	// A0  A  B  C C4
	// D0  D  E  F F4
	// G0  G  H  I I4
	//    G5 H5 I5

	t1 = vTexCoord.xxxy + vec4( -dx, 0, dx,-2.0*dy); // A1 B1 C1
	t2 = vTexCoord.xxxy + vec4( -dx, 0, dx,    -dy); //  A  B  C
	t3 = vTexCoord.xxxy + vec4( -dx, 0, dx,      0); //  D  E  F
	t4 = vTexCoord.xxxy + vec4( -dx, 0, dx,     dy); //  G  H  I
	t5 = vTexCoord.xxxy + vec4( -dx, 0, dx, 2.0*dy); // G5 H5 I5
	t6 = vTexCoord.xyyy + vec4(-2.0*dx,-dy, 0,  dy); // A0 D0 G0
	t7 = vTexCoord.xyyy + vec4( 2.0*dx,-dy, 0,  dy); // C4 F4 I4
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 t1;
layout(location = 2) in vec4 t2;
layout(location = 3) in vec4 t3;
layout(location = 4) in vec4 t4;
layout(location = 5) in vec4 t5;
layout(location = 6) in vec4 t6;
layout(location = 7) in vec4 t7;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

vec3 GAMMA_IN(vec3 color)   
{
    return pow(color, vec3(InputGamma, InputGamma, InputGamma));
}

vec3 GAMMA_OUT(vec3 color)
{
    return pow(color, vec3(1.0 / OutputGamma, 1.0 / OutputGamma, 1.0 / OutputGamma));
}

vec3 TEX2D(vec2 coords)
{
    return GAMMA_IN( texture(Source, coords).xyz );
}

vec4 xBR_hybrid_CRT(vec2 texture_size, vec2 texCoord, vec4 t1, vec4 t2, vec4 t3, vec4 t4, vec4 t5, vec4 t6, vec4 t7)
{
	bvec4 edr, edr_left, edr_up, px; // px = pixel, edr = edge detection rule
	bvec4 interp_restriction_lv1, interp_restriction_lv2_left, interp_restriction_lv2_up;
	bvec4 nc, nc30, nc60, nc45; // new_color
	vec4 fx, fx_left, fx_up, final_fx; // inequations of straight lines.
	vec3 res1, res2, pix1, pix2;
	float blend1, blend2;

	vec2 fp = fract(texCoord*texture_size);

	vec3 A1 = texture(Source, t1.xw).rgb;
	vec3 B1 = texture(Source, t1.yw).rgb;
	vec3 C1 = texture(Source, t1.zw).rgb;

	vec3 A  = texture(Source, t2.xw).rgb;
	vec3 B  = texture(Source, t2.yw).rgb;
	vec3 C  = texture(Source, t2.zw).rgb;

	vec3 D  = texture(Source, t3.xw).rgb;
	vec3 E  = texture(Source, t3.yw).rgb;
	vec3 F  = texture(Source, t3.zw).rgb;

	vec3 G  = texture(Source, t4.xw).rgb;
	vec3 H  = texture(Source, t4.yw).rgb;
	vec3 I  = texture(Source, t4.zw).rgb;

	vec3 G5 = texture(Source, t5.xw).rgb;
	vec3 H5 = texture(Source, t5.yw).rgb;
	vec3 I5 = texture(Source, t5.zw).rgb;

	vec3 A0 = texture(Source, t6.xy).rgb;
	vec3 D0 = texture(Source, t6.xz).rgb;
	vec3 G0 = texture(Source, t6.xw).rgb;

	vec3 C4 = texture(Source, t7.xy).rgb;
	vec3 F4 = texture(Source, t7.xz).rgb;
	vec3 I4 = texture(Source, t7.xw).rgb;

	vec4 b = mul( mat4x3(B, D, H, F), yuv_weighted[0] );
	vec4 c = mul( mat4x3(C, A, G, I), yuv_weighted[0] );
	vec4 e = mul( mat4x3(E, E, E, E), yuv_weighted[0] );
	vec4 a = c.yzwx;
	vec4 d = b.yzwx;
	vec4 f = b.wxyz;
	vec4 g = c.zwxy;
	vec4 h = b.zwxy;
	vec4 i = c.wxyz;

	vec4 i4 = mul( mat4x3(I4, C1, A0, G5), yuv_weighted[0] );
	vec4 i5 = mul( mat4x3(I5, C4, A1, G0), yuv_weighted[0] );
	vec4 h5 = mul( mat4x3(H5, F4, B1, D0), yuv_weighted[0] );
	vec4 f4 = h5.yzwx;


	vec4 Ao = vec4( 1.0, -1.0, -1.0, 1.0 );
	vec4 Bo = vec4( 1.0,  1.0, -1.0,-1.0 );
	vec4 Co = vec4( 1.5,  0.5, -0.5, 0.5 );
	vec4 Ax = vec4( 1.0, -1.0, -1.0, 1.0 );
	vec4 Bx = vec4( 0.5,  2.0, -0.5,-2.0 );
	vec4 Cx = vec4( 1.0,  1.0, -0.5, 0.0 );
	vec4 Ay = vec4( 1.0, -1.0, -1.0, 1.0 );
	vec4 By = vec4( 2.0,  0.5, -2.0,-0.5 );
	vec4 Cy = vec4( 2.0,  0.0, -1.0, 0.5 );

	// These inequations define the line below which interpolation occurs.
	fx      = (Ao*fp.y+Bo*fp.x); 
	fx_left = (Ax*fp.y+Bx*fp.x);
	fx_up   = (Ay*fp.y+By*fp.x);

	interp_restriction_lv1.x      = ((e.x!=f.x) && (e.x!=h.x) && ((eq2(e,b).x || eq2(e,d).x || !eq2(e,a).x) && (eq2(f,f4).x || eq2(f,c).x || eq2(h,h5).x || eq2(h,g).x))  && ( !eq(f,b).x && !eq(f,c).x || !eq(h,d).x && !eq(h,g).x || eq(e,i).x && (!eq(f,f4).x && !eq(f,i4).x || !eq(h,h5).x && !eq(h,i5).x) || eq(e,g).x || eq(e,c).x) );

	interp_restriction_lv1.y      = ((e.y!=f.y) && (e.y!=h.y) && ((eq2(e,b).y || eq2(e,d).y || !eq2(e,a).y) && (eq2(f,f4).y || eq2(f,c).y || eq2(h,h5).y || eq2(h,g).y))  && ( !eq(f,b).y && !eq(f,c).y || !eq(h,d).y && !eq(h,g).y || eq(e,i).y && (!eq(f,f4).y && !eq(f,i4).y || !eq(h,h5).y && !eq(h,i5).y) || eq(e,g).y || eq(e,c).y) );

	interp_restriction_lv1.z      = ((e.z!=f.z) && (e.z!=h.z) && ((eq2(e,b).z || eq2(e,d).z || !eq2(e,a).z) && (eq2(f,f4).z || eq2(f,c).z || eq2(h,h5).z || eq2(h,g).z))  && ( !eq(f,b).z && !eq(f,c).z || !eq(h,d).z && !eq(h,g).z || eq(e,i).z && (!eq(f,f4).z && !eq(f,i4).z || !eq(h,h5).z && !eq(h,i5).z) || eq(e,g).z || eq(e,c).z) );

	interp_restriction_lv1.w      = ((e.w!=f.w) && (e.w!=h.w) && ((eq2(e,b).w || eq2(e,d).w || !eq2(e,a).w) && (eq2(f,f4).w || eq2(f,c).w || eq2(h,h5).w || eq2(h,g).w))  && ( !eq(f,b).w && !eq(f,c).w || !eq(h,d).w && !eq(h,g).w || eq(e,i).w && (!eq(f,f4).w && !eq(f,i4).w || !eq(h,h5).w && !eq(h,i5).w) || eq(e,g).w || eq(e,c).w) );
	
	interp_restriction_lv2_left.x = ((e.x!=g.x) && (d.x!=g.x));
	interp_restriction_lv2_left.y = ((e.y!=g.y) && (d.y!=g.y));
	interp_restriction_lv2_left.z = ((e.z!=g.z) && (d.z!=g.z));
	interp_restriction_lv2_left.w = ((e.w!=g.w) && (d.w!=g.w));
	
	interp_restriction_lv2_up.x   = ((e.x!=c.x) && (b.x!=c.x));
	interp_restriction_lv2_up.y   = ((e.y!=c.y) && (b.y!=c.y));
	interp_restriction_lv2_up.z   = ((e.z!=c.z) && (b.z!=c.z));
	interp_restriction_lv2_up.w   = ((e.w!=c.w) && (b.w!=c.w));

	vec4 fx45 = smoothstep(Co - delta, Co + delta, fx);
	vec4 fx30 = smoothstep(Cx - delta, Cx + delta, fx_left);
	vec4 fx60 = smoothstep(Cy - delta, Cy + delta, fx_up);


	edr.x      = ((weighted_distance( e, c, g, i, h5, f4, h, f).x + 3.5) < weighted_distance( h, d, i5, f, i4, b, e, i).x) && interp_restriction_lv1.x;
	edr.y      = ((weighted_distance( e, c, g, i, h5, f4, h, f).y + 3.5) < weighted_distance( h, d, i5, f, i4, b, e, i).y) && interp_restriction_lv1.y;
	edr.z      = ((weighted_distance( e, c, g, i, h5, f4, h, f).z + 3.5) < weighted_distance( h, d, i5, f, i4, b, e, i).z) && interp_restriction_lv1.z;
	edr.w      = ((weighted_distance( e, c, g, i, h5, f4, h, f).w + 3.5) < weighted_distance( h, d, i5, f, i4, b, e, i).w) && interp_restriction_lv1.w;
	
	edr_left.x = ((coef*df(f,g).x) <= df(h,c).x) && interp_restriction_lv2_left.x;
	edr_left.y = ((coef*df(f,g).y) <= df(h,c).y) && interp_restriction_lv2_left.y;
	edr_left.z = ((coef*df(f,g).z) <= df(h,c).z) && interp_restriction_lv2_left.z;
	edr_left.w = ((coef*df(f,g).w) <= df(h,c).w) && interp_restriction_lv2_left.w;
	
	edr_up.x   = (df(f,g).x >= (coef*df(h,c).x)) && interp_restriction_lv2_up.x;
	edr_up.y   = (df(f,g).y >= (coef*df(h,c).y)) && interp_restriction_lv2_up.y;
	edr_up.z   = (df(f,g).z >= (coef*df(h,c).z)) && interp_restriction_lv2_up.z;
	edr_up.w   = (df(f,g).w >= (coef*df(h,c).w)) && interp_restriction_lv2_up.w;

	nc45.x = ( edr.x &&             bvec4(fx45).x);
	nc45.y = ( edr.y &&             bvec4(fx45).y);
	nc45.z = ( edr.z &&             bvec4(fx45).z);
	nc45.w = ( edr.w &&             bvec4(fx45).w);
	
	nc30.x = ( edr.x && edr_left.x && bvec4(fx30).x);
	nc30.y = ( edr.y && edr_left.y && bvec4(fx30).y);
	nc30.z = ( edr.z && edr_left.z && bvec4(fx30).z);
	nc30.w = ( edr.w && edr_left.w && bvec4(fx30).w);
	
	nc60.x = ( edr.x && edr_up.x   && bvec4(fx60).x);
	nc60.y = ( edr.y && edr_up.y   && bvec4(fx60).y);
	nc60.z = ( edr.z && edr_up.z   && bvec4(fx60).z);
	nc60.w = ( edr.w && edr_up.w   && bvec4(fx60).w);

	px.x = (df(e,f).x <= df(e,h).x);
	px.y = (df(e,f).y <= df(e,h).y);
	px.z = (df(e,f).z <= df(e,h).z);
	px.w = (df(e,f).w <= df(e,h).w);

	vec3 res = E;


    vec3 n1, n2, n3, n4, s, aa, bb, cc, dd;


    n1 = B1; n2 = B; s = E; n3 = H; n4 = H5;
    aa = n2-n1; bb = s-n2; cc = n3-s; dd = n4-n3;

    vec3 t = (7 * (bb + cc) - 3 * (aa + dd)) / 16;

    vec3 m = vec3(0.0);
    m.x =(s.x < 0.5) ? 2*s.x : 2*(1.0-s.x);
    m.y =(s.y < 0.5) ? 2*s.y : 2*(1.0-s.y);
    m.z =(s.z < 0.5) ? 2*s.z : 2*(1.0-s.z);

        m = min(m, sharpness*abs(bb));
        m = min(m, sharpness*abs(cc));

    t = clamp(t, -m, m);

   
    vec3 s1 = (2*fp.y-1)*t + s;

    n1 = D0; n2 = D; s = s1; n3 = F; n4 = F4;
    aa = n2-n1; bb = s-n2; cc = n3-s; dd = n4-n3;

    t = (7 * (bb + cc) - 3 * (aa + dd)) / 16;

    m.x = (s.x < 0.5) ? 2*s.x : 2*(1.0-s.x);
    m.y = (s.y < 0.5) ? 2*s.y : 2*(1.0-s.y);
    m.z = (s.z < 0.5) ? 2*s.z : 2*(1.0-s.z);

        m = min(m, sharpness*abs(bb));
        m = min(m, sharpness*abs(cc));

    t = clamp(t, -m, m);

    vec3 s0 = (2*fp.x-1)*t + s;


	nc.x = (nc30.x || nc60.x || nc45.x);
	nc.y = (nc30.y || nc60.y || nc45.y);
	nc.z = (nc30.z || nc60.z || nc45.z);
	nc.w = (nc30.w || nc60.w || nc45.w);

	blend1 = blend2 = 0.0;

	vec4 final45 = vec4(dot(vec4(nc45), fx45));
	vec4 final30 = vec4(dot(vec4(nc30), fx30));
	vec4 final60 = vec4(dot(vec4(nc60), fx60));

	vec4 maximo = max(max(final30, final60), final45);

	     if (nc.x) {pix1 = px.x ? F : H; blend1 = maximo.x;}
	else if (nc.y) {pix1 = px.y ? B : F; blend1 = maximo.y;}
	else if (nc.z) {pix1 = px.z ? D : B; blend1 = maximo.z;}
	else if (nc.w) {pix1 = px.w ? H : D; blend1 = maximo.w;}

	     if (nc.w) {pix2 = px.w ? H : D; blend2 = maximo.w;}
	else if (nc.z) {pix2 = px.z ? D : B; blend2 = maximo.z;}
	else if (nc.y) {pix2 = px.y ? B : F; blend2 = maximo.y;}
	else if (nc.x) {pix2 = px.x ? F : H; blend2 = maximo.x;}

	res1 = mix(s0, pix1, blend1);
	res2 = mix(s0, pix2, blend2);

	res = mix(res1, res2, step(c_df(E, res1), c_df(E, res2)));

// CRT-caligari - only vertical blend

            vec3 color = GAMMA_IN(res);

            float ddy = fp.y - 0.5;
            float v_weight_00 = ddy / SPOT_HEIGHT;
            WEIGHT(v_weight_00);
            color *= vec3( v_weight_00, v_weight_00, v_weight_00 );

	    // get closest vertical neighbour to blend
 	    vec3 coords10;
            if (ddy>0.0) {
            	coords10 = H;
                ddy = 1.0 - ddy;
            } else {
                coords10 = B;
                ddy = 1.0 + ddy;
            }
	    vec3 colorNB = GAMMA_IN(coords10);

            float v_weight_10 = ddy / SPOT_HEIGHT;
            WEIGHT( v_weight_10 );

            color += colorNB * vec3( v_weight_10, v_weight_10, v_weight_10 );

            color *= vec3( COLOR_BOOST, COLOR_BOOST, COLOR_BOOST );

	return vec4(clamp( GAMMA_OUT(color), 0.0, 1.0 ), 1.0);

	return vec4(res.x, res.y, res.z, 1.0);

}

void main()
{
   FragColor = xBR_hybrid_CRT(params.SourceSize.xy, vTexCoord, t1, t2, t3, t4, t5, t6, t7);
}
