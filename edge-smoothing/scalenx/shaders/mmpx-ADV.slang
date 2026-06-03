#version 450
precision mediump float;

/* =========================================================================
 * MMPX
 * by Morgan McGuire and Mara Gagiu
 * https://casual-effects.com/research/McGuire2021PixelArt/
 * License: MIT
 * adapted for slang by hunterk
 * =========================================================================
 * MMPX Advanced v3.1
 * =========================================================================
 * An optimized and heavily expanded derivative of the MMPX algorithm.
 * 
 * The baseline MMPX implementation relies on a minimalist rule-set, which 
 * inherently suffers from topological conflicts at complex intersections, 
 * manifesting as jarring structural artifacts, "bubbles," and "spurs." 
 * 
 * MMPX Advanced introduces comprehensive morphological analysis, utilizing a 
 * vast array of high-precision conditional predicates to expand the 
 * architectural logic by an order of magnitude. Through exhaustive conflict-
 * scenario analysis and granular edge-case resolution, this refinement 
 * completely eliminates morphological glitches. 
 * 
 * Furthermore, the integration of approximate pixel-matching logic effectively 
 * addresses unmapped topological configurations overlooked by the baseline 
 * specification, thereby delivering flawless detail reconstruction while 
 * preserving the authentic pixel-art aesthetic.

 * 
 * Copyright (c) 2025-2026 by crashGG.
 * ========================================================================= */

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

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


float luma(vec3 col){
   // BT.601 standard
   return dot(col, vec3(0.299, 0.587, 0.114));
}

/* Constant Descriptions:
 * 0.145898    : (~0.382) ^2
 * 0.8541      : 1.0 -(~0.382) ^2
 * 0.0638587   : (RGB Euclidean distance scaled by ~0.382 twice) ^2
 * 0.75        : (RGB Euclidean distance scaled by  0.500) ^2
 */

bool simb(vec3 col1, vec3 col2) {

	highp vec3 diff = col1 - col2;

	// （max_diff - min_diff）
	float delta_range = max(diff.r, max(diff.g, diff.b)) - min(diff.r, min(diff.g, diff.b));

	highp float dot_diff = dot(diff, diff);

	// Eq to (delta_range ÷ 0.145898 )²
	highp float factor = (delta_range * delta_range) * 46.9787;

	return dot_diff < mix(0.0638587, 0.0, factor);
}

bool sim(vec3 col1, vec3 col2) {

	highp vec3 diff = col1 - col2;

	float delta_range = max(diff.r, max(diff.g, diff.b)) - min(diff.r, min(diff.g, diff.b));

	highp float dot_diff = dot(diff, diff);

	// Eq to (delta_range ÷ 0.382 )²
	highp float factor = (delta_range * delta_range) * 6.8541;

	return dot_diff < mix(0.0638587, 0.0, factor);
}

float mixGate(vec3 col1, vec3 col2) {

	highp vec3 diff = col1 - col2;

	float delta_range = max(diff.r, max(diff.g, diff.b)) - min(diff.r, min(diff.g, diff.b));

	highp float dot_diff = dot(diff, diff);

	// Eq to (delta_range ÷ 0.618 )²
	highp float factor = (delta_range * delta_range) * 2.618034;

	return step(dot_diff, mix(0.75, 0.0, factor));
}

#define eq(a,b) (a==b)

#define neq(a,b) (a!=b)

#define all_eq2(a, b1, b2) \
	( eq(a,b1) && eq(a,b2))

#define all_eq3(a, b1, b2, b3) \
	( eq(a,b1) && eq(a,b2) && eq(a,b3))

#define all_eq4(a, b1, b2, b3, b4) \
	( eq(a,b1) && eq(a,b2) && eq(a,b3) && eq(a,b4))

#define any_eq2(a, b1, b2) (eq(a,b1)||eq(a,b2))
#define any_eq3(a, b1, b2, b3) (eq(a,b1)||eq(a,b2)||eq(a,b3))
#define none_eq2(a, b1, b2) !any_eq2(a, b1, b2)
// Pre-define
const vec3 testcolor  = vec3(1.0, 0.0, 1.0);  // magenta
const vec3 testcolor2 = vec3(0.0, 1.0, 1.0);  // cyan
const vec3 testcolor3 = vec3(1.0, 1.0, 0.0);  // yellow
const vec3 testcolor4 = vec3(1.0, 1.0, 1.0);  // white
const vec3 slopOFF   = vec3(2.0);
const vec3 slopeBAD  = vec3(4.0);
const vec3 theEXIT   = vec3(8.0);

#define mixXE mix(vX,vE,mixFactor)
#define mixXEoff mixXE+slopOFF
#define Xoff vX+slopOFF
#define checkblack(col) all(lessThan((col).rgb, vec3(0.1, 0.078, 0.1)))
#define checkwhite(col) all(greaterThan((col).rgb, vec3(0.92, 0.92, 0.92)))

//pin zz
vec3 admixC(vec3 vX, vec3 vE) {
	float mixFactor = mixGate(vX, vE) * (-0.381966) + 1.0;

	return mixXE;
}

vec3 admixK(vec3 vX, vec3 vE) {
    vec3 diff = vX - vE;
	float mixFactor = dot(diff, diff) * 0.16666 + 0.5;
	//float mixFactor = distance(vX, vE) * 0.28867 + 0.5;
	return mixXE;
}

vec3 admixL(vec3 vE, vec3 vX) {

	float mixFactor = 0.381966 * mixGate(vX,vE);

    return mixXE;
}

/**************************************************************************************************************************************
 * 												main slope + X cross-processing mechanism						                *
 ******************************************************************************************************************************** zz  */
vec3 admixX( uint A, uint B, uint C, uint D, uint E, uint F, uint G, uint H, uint I
		  , uint P, uint PA, uint PC, uint Q, uint QA, uint QG, uint R, uint RC, uint RI, uint S, uint SG, uint SI, uint AA, uint CC, uint GG
		  , float El, float Bl, float Dl, float Fl, float Hl
		  , vec3 vE, vec3 vB, vec3 vD, vec3 vC, vec3 vG
		  ) {


	bool eq_B_C = eq(B,C);
	bool eq_D_G = eq(D,G);

    if (eq_B_C && eq_D_G) return slopeBAD;

	//Pre-declare
	bool eq_B_P;		bool eq_B_PA;	bool eq_B_PC;
	bool eq_D_Q;		bool eq_D_QA;	bool eq_D_QG;
	bool eq_E_F;		bool eq_E_H;		bool eq_A_AA;

	vec3 vX;
	float mixFactor;

	bool eq_E_C = eq(E,C);
	bool eq_E_G = eq(E,G);
    bool eq_A_P = eq(A,P);
    bool eq_A_Q = eq(A,Q);
    bool comboE3 = eq_E_C && eq_E_G;
    bool comboA3 = eq_A_P && eq_A_Q;

/*=========================================
                    B != D
  ==================================== zz */
if (neq(B,D)){

	if (eq(E,A)) return slopeBAD;

	float diffBD = abs(Bl-Dl);
	if (diffBD > El-Bl || diffBD > El-Dl) return slopeBAD;


	vX = mix(vB, vD, 0.5);

	mixFactor = 0.381966 * mixGate(vX,vE);

	eq_B_PC = eq(B,PC);
	eq_D_QG = eq(D,QG);
 
    if (none_eq2(A,B,D)){
		if (comboA3) return mixXEoff;
		if ( eq_A_P && eq_B_PC && !eq_B_C ) return mixXEoff;
		if ( eq_A_Q && eq_D_QG && !eq_D_G ) return mixXEoff;

		if ( eq_A_P && eq_E_G ) return mixXEoff;
		if ( eq_A_Q && eq_E_C ) return mixXEoff;

		if ( eq_E_C && eq_D_G ) return mixXEoff;
		if ( eq_E_G && eq_B_C ) return mixXEoff;

}
    if ( comboE3 ) return mixXEoff;

    if ( eq_E_C && eq_B_PC && neq(B,P)) return mixXEoff;
	if ( eq_E_G && eq_D_QG && neq(D,Q)) return mixXEoff;

	eq_E_F = eq(E,F);

	if (eq(F,H)) {

		if ( eq_E_C && !eq_D_G && (!eq_E_F||neq(E,P)) ) return mixXEoff;
		if ( eq_E_G && !eq_B_C && (!eq_E_F||neq(E,Q)) ) return mixXEoff;

		if ( !eq_E_F && eq_B_PC && eq(F,RC) ) return mixXEoff;
		if ( !eq_E_F && eq_D_QG && eq(H,SG) ) return mixXEoff;
	}

    return slopeBAD;
} // B != D


						/*********  B == D  *********/
  
	bool Xisblack = checkblack(vB);
	if ( Xisblack && El >0.5 && (Fl<0.078 || Hl<0.078) ) return theEXIT;

	vX = vB;

	mixFactor = 0.381966 * mixGate(vX,vE);

	bool B_slope;	bool B_tower;	bool B_wall;
    bool D_slope;	bool D_tower;	bool D_wall;
	bool En3;
    #define En4square En3&&eq(E,I)

/*===================================================
                    E - A  x cross
  ============================================== zz */
if (eq(E,A)) {

	eq_E_F = eq(E,F);
	eq_E_H = eq(E,H);

	bool Eisblack = checkblack(vE);

    if ( comboE3 && !eq_E_F && !eq_E_H && eq(E,I) ) {

		if (Eisblack) return theEXIT;
		mixFactor = 0.618034 * (1.0 - mixFactor);
		return mixXEoff;
	}

	eq_A_AA = eq(A,AA);

    if ( comboA3 && eq_A_AA && none_eq2(A,PA,QA) )  {	
		if (Eisblack) return theEXIT;
		mixFactor = 0.618034 * (1.0 - mixFactor);
		if ( neq(B,PA) && eq(PA,QA) ) return mixXEoff;
        mixFactor += 0.236068;
		return mixXEoff;
	}

    eq_B_PC = eq(B,PC);
    eq_B_PA = eq(B,PA);
    eq_D_QG = eq(D,QG);
    eq_D_QA = eq(D,QA);

	if ( comboE3 && comboA3 &&
		(eq_B_PC || eq_D_QG) && eq_D_QA && eq_B_PA) {
		mixFactor = mixFactor * (-0.618034) + 0.8541;
        return mixXEoff;
	}

	if ( comboE3 && eq_A_P
		 && eq_B_PA && eq_D_QA && eq_D_QG
		 && eq_E_H
		) {
		mixFactor = mixFactor * (-0.618034) + 0.8541;
        return mixXEoff;
		}

	if ( comboE3 && eq_A_Q
		 && eq_B_PA && eq_D_QA && eq_B_PC
		 && eq_E_F
		) {
		mixFactor = mixFactor * (-0.618034) + 0.8541;
        return mixXEoff;
		}


	if (comboA3) return Xoff;

    if (comboE3) return mixXEoff;

	eq_B_P = eq(B, P);
	eq_D_Q = eq(D, Q);

	B_slope = eq_B_PC && !eq_B_P && !eq_B_C && !eq_B_PA;
	D_slope = eq_D_QG && !eq_D_Q && !eq_D_G && !eq_D_QA;

	B_wall = eq_B_C && !eq_B_PC && !eq_B_P;
	D_wall = eq_D_G && !eq_D_QG && !eq_D_Q;
	
	B_tower = eq_B_P && !eq_B_PC && !eq_B_C && !eq_B_PA;
	D_tower = eq_D_Q && !eq_D_QG && !eq_D_G && !eq_D_QA;


	if ( B_slope && eq_E_G ) return mixXEoff;
	if ( D_slope && eq_E_C ) return mixXEoff;


    float scoreE = 0.0; float scoreB = 0.0; float scoreD = 0.0; float scoreZ = 0.0;

    if (eq_E_C) {
		scoreE += 1.0 +float(eq(F,H)) +float(B_slope);
		scoreE -= float(all_eq2(E,P,PC)&&!D_wall);
	}

    if (eq_E_G) {
        scoreE += 1.0 +float(eq(F,H)) +float(D_slope);
		scoreE -= float(all_eq2(E,Q,QG)&&!B_wall);
    }

	scoreE += float(B_slope && eq_A_Q || D_slope && eq_A_P);

    En3 = eq_E_F && eq_E_H;

	if ( scoreE<0.1 && mixFactor<0.1 && En4square && eq(E,S)==eq(E,SI) && eq(E,R)==eq(E,RI) ) return theEXIT;

	if ( scoreE<0.1 && !En3 && neq(E,I) ) {
		if ( B_wall && eq_E_F ) return theEXIT;
		if ( D_wall && eq_E_H ) return theEXIT;
    }

	scoreE += float(B_slope && eq_A_P || D_slope && eq_A_Q);

    if ( !En3 && eq(F,H) ) {
		if (Eisblack) return slopeBAD;
		bool condZ1 = B_wall && (eq(F,R) || eq(F,RC) || eq(G,H) || eq(F,I));
		bool condZ2 = D_wall && (eq(C,F) || eq(H,SG) || eq(H,S) || eq(F,I));
		scoreZ = float(condZ1 || condZ2);
    }


    if (eq_B_PA) {
		scoreB -= 1.0 +float(eq(P,C)) +float(eq_A_AA);
	}

	if (eq(P,C)){
		scoreB -= float(eq_A_AA);
		scoreZ *= float(scoreE < 0.1);
	}

    if (eq_D_QA) {
		scoreD -= 1.0 +float(eq(G,Q)) +float(eq_A_AA);
	}

	if (eq(G,Q)){
		scoreD -= float(eq_A_AA);
		scoreZ *= float(scoreE < 0.1);
	}

    float scoreFinal = scoreE + scoreB + scoreD + scoreZ ;

	scoreFinal += float(min(scoreB,scoreD) > -0.1 && (B_wall && D_tower || B_tower && D_wall)) *2.0;

	mixFactor *= (1.0 - step(1.9, scoreFinal));
	return mixXE + slopeBAD*(1.0 - step(0.9, scoreFinal));

}	// E == A

	
/*===============================================
             	E - C - G     main rules
  ========================================== zz */

    if (eq_E_C ) {
		if (comboA3) return vX;
		if (comboE3) return mixXE;
		if (all_eq2(B,A,PA) && all_eq3(E,F,P,PC)) return theEXIT;
		return mixXE;
	}

	if (eq_E_G) {
		if (comboA3) return vX;
		if (comboE3) return mixXE;
		if (all_eq2(D,A,QA) && all_eq3(E,H,Q,QG)) return theEXIT;
		return mixXE;
	}


/*=========================================================
                   F - H / B+ D+ ex new rules
  ==================================================== zz */

    bool eq_A_B = eq(A,B);
    bool eq_F_H = eq(F,H);

	eq_B_P  = eq(B,P);
	eq_B_PC = eq(B,PC);
	eq_B_PA = eq(B,PA);
	eq_D_Q  = eq(D,Q);
	eq_D_QG = eq(D,QG);
	eq_D_QA = eq(D,QA);

	B_slope = eq_B_PC && !eq_B_P && !eq_B_C;
	D_slope = eq_D_QG && !eq_D_Q && !eq_D_G;
	B_tower = eq_B_P && !eq_B_PC && !eq_B_C && !eq_B_PA;
	D_tower = eq_D_Q && !eq_D_QG && !eq_D_G && !eq_D_QA;
	B_wall = eq_B_C && !eq_B_PC && !eq_B_P;
	D_wall = eq_D_G && !eq_D_QG && !eq_D_Q;


	if (!eq_A_B) {

        if (comboA3) return Xoff;

        if ( (B_slope||B_tower) && (D_slope||D_tower) ) return Xoff;

        if ( B_slope && eq_A_P ) return mixXEoff;
        if ( D_slope && eq_A_Q ) return mixXEoff;

        if ( (B_slope || D_slope) && eq_F_H ) return mixXEoff;

        if ( B_slope && eq(H,SG) ) return mixXEoff;
        if ( D_slope && eq(F,RC) ) return mixXEoff;

        if ( B_slope && eq_A_Q && eq(Q,QG) ) return mixXEoff;
        if ( D_slope && eq_A_P && eq(P,PC) ) return mixXEoff;

    }


	bool sim_EC = sim(vE, vC);
	bool sim_EG = sim(vE, vG);

	float E_lumDiff = mix(0.381966, 0.145898, max((El - 0.8541),0.0) * 6.8541);

    if ( mixFactor<0.1 && !sim_EC && !sim_EG && neq(E,I) && abs(El-Fl)>E_lumDiff && abs(El-Hl)>E_lumDiff ) return slopeBAD;


	eq_E_F = eq(E,F);
	eq_E_H = eq(E,H);

	if ( eq_B_C && eq_D_Q ) {
		if ( eq(P,PC) && eq(A,QA) && !eq_D_QG && eq_E_F && !eq_E_H && eq(H,I)) return theEXIT;
		if ( eq_A_B ) return slopeBAD;
		if ( B_wall && D_tower && eq_E_F) return vX;
		return mixXEoff;
	}

	if ( eq(D,G) && eq(B,P)) {
		if ( eq(Q,QG) && eq(A,PA) && !eq_B_PC && eq_E_H && !eq_E_F && eq(F,I)) return theEXIT;
		if ( eq_A_B ) return slopeBAD;
		if ( B_tower && D_wall && eq_E_H) return vX;
		return mixXEoff;
	}


    En3 = eq_E_F && eq_E_H;

	if ( En4square ) {
        if ( ( eq_B_C || eq_D_G) && eq_A_B) return theEXIT;
        if ( ( eq_B_C || eq_D_G || mixFactor<0.1) && (eq(E,S) == eq(E, SI) && eq(E,R) == eq(E, RI)) ) return theEXIT;
        return mixXEoff;
    }

	if (!eq_B_C && !eq_D_G ) {
		 if ( comboA3 && eq_F_H ) return Xoff;

		if ( comboA3&&eq_B_PC&&eq(C,CC) ) return Xoff;
		if ( comboA3&&eq_D_QG&&eq(G,GG) ) return Xoff;

		if ( !eq_B_P && !eq_B_PC && !eq_D_Q && !eq_D_QG && !En3 ) return slopeBAD;

		if (eq_A_Q&&sim_EC) return mixXEoff;
		if (eq_A_P&&sim_EG) return mixXEoff;
		if (sim_EC&&sim_EG ) return mixXEoff;
	}
	
 	if ( En3 && eq_A_B) return theEXIT;

	if (eq_F_H) {

		if ( eq_B_PC&&eq(F,RC) || eq_D_QG&&eq(H,SG) ) return mixXEoff;

		if (eq_A_B) return slopeBAD;

		if ( eq_B_C || eq_D_G) return mixXEoff;
		if ( eq_B_PC || eq_D_QG) return mixXEoff;

	}

	return slopeBAD;

}	// admixX


vec3 admixS( uint A, uint B, uint C, uint D, uint E, uint F, uint G, uint H, uint I
		   , uint R, uint RC, uint RI, uint S, uint SG, uint SI, uint II, uint CC
		   , vec3 vE, vec3 vF, vec3 vC
		   ) {

			//                                   Ａ B Ｃ .
			//                                 ＱＤ 🄴 🅵 🆁       Zone 4
			//                                   🅶 🅷 Ｉ
			//                                      S


    if (any_eq2(F,C,I)) return vE;

	if ( (eq(F,RI) || eq(G,S) || eq(R, RI)) && neq(R,I) ) return vE;

    if (eq(H, S) && none_eq2(H,I,SG)) return vE;

    if ( eq(R, RC) || eq(G,SG) ) return vE;

	if ( checkwhite(vE) && all_eq2(E,C,D) && none_eq2(E,RC,CC)) return vE;


	#define vX vF
	float mixFactor = 0.381966 * mixGate(vX,vE);

	if ( eq(E,C) && (eq(E,D)||eq(B,D)) ) return mixXE;

	bool sim_E_C = sim(vE,vC);

	if ( sim_E_C && eq(E,D) && eq(B,C) ) return mixXE;

	if ( (sim_E_C || mixFactor>0.1) && all_eq2(B,C,D) ) return mixXE;

    return vE;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////// zz //

void main()
{
#define srcf(c,d) texture(Source, vTexCoord + vec2(c,d) * params.SourceSize.zw).rgb
#define src(c,d) packUnorm4x8(vec4(srcf(c,d), 1.0))

	vec3 vE = srcf(0.0, 0.0);
	vec3 vB = srcf(0.0, -1.0);
	vec3 vD = srcf(-1.0, 0.0);
	vec3 vF = srcf(+1.0, 0.0);
	vec3 vH = srcf(0.0, +1.0);

    FragColor = vec4(vE, 1.0);

    uint E = packUnorm4x8(vec4(vE, 1.0));
    uint B = packUnorm4x8(vec4(vB, 1.0));
    uint D = packUnorm4x8(vec4(vD, 1.0));
    uint F = packUnorm4x8(vec4(vF, 1.0));
    uint H = packUnorm4x8(vec4(vH, 1.0));


    bool eq_E_D = eq(E,D);
    bool eq_E_F = eq(E,F);
    bool eq_E_B = eq(E,B);
    bool eq_E_H = eq(E,H);
    bool eq_B_H = eq(B,H);
    bool eq_D_F = eq(D,F);

bool skiprest = (eq_E_D && eq_E_F) || (eq_E_B && eq_E_H) || (eq_B_H && eq_D_F);
if (!skiprest) {



    vec3 vA = srcf(-1.0, -1.0);
	vec3 vC = srcf(+1.0, -1.0);
	vec3 vG = srcf(-1.0, +1.0);
	vec3 vI = srcf(+1.0, +1.0);

    uint A = packUnorm4x8(vec4(vA, 1.0));
    uint C = packUnorm4x8(vec4(vC, 1.0));
    uint G = packUnorm4x8(vec4(vG, 1.0));
    uint I = packUnorm4x8(vec4(vI, 1.0));

	uint P  = src( 0.0, -2.0);
	uint Q  = src(-2.0,  0.0);
	uint R  = src(+2.0,  0.0);
	uint S  = src( 0.0, +2.0);

	uint PA = src(-1.0, -2.0);
	uint PC = src(+1.0, -2.0);
	uint QA = src(-2.0, -1.0);
	uint QG = src(-2.0, +1.0); //             AA    PA    [P]   PC    CC
	uint RC = src(+2.0, -1.0); //                ┌──┬──┬──┐
	uint RI = src(+2.0, +1.0); //             QA │  A │  B │ C  │ RC
	uint SG = src(-1.0, +2.0); //                ├──┼──┼──┤
	uint SI = src(+1.0, +2.0); //            [Q] │  D │  E │ F  │ [R]
	uint AA = src(-2.0, -2.0); //                ├──┼──┼──┤
	uint CC = src(+2.0, -2.0); //             QG │  G │  H │ I  │ RI
	uint GG = src(-2.0, +2.0); //                └──┴──┴──┘
	uint II = src(+2.0, +2.0); //             GG    SG    [S]   SI    II

    vec3 J = vE;    vec3 K = vE;    vec3 L = vE;    vec3 M = vE;

    // ------------------------ border check --- Libretro -----------------------
    #define fakeColor vec3(1.234)
    vec2 pixelPos = vTexCoord * params.SourceSize.xy;
    ivec2 currPixel = ivec2(floor(pixelPos));
    ivec2 texSize = ivec2(params.SourceSize.xy);

    if (currPixel.y - 1 < 0) vB = fakeColor;
    if (currPixel.x - 1 < 0) vD = fakeColor;
    if (currPixel.x + 1 >= texSize.x) vF = fakeColor;
    if (currPixel.y + 1 >= texSize.y) vH = fakeColor;
    // ----------------------------------------------------------------------

    float Bl = luma(vB);
    float Dl = luma(vD);
    float El = luma(vE);
    float Fl = luma(vF);
    float Hl = luma(vH);


// 	pre-cal
    bool eq_B_D = eq(B,D);
    bool eq_B_F = eq(B,F);
    bool eq_D_H = eq(D,H);
    bool eq_F_H = eq(F,H);

    bool oppoPix =  eq_B_H || eq_D_F;
    bool slope1 = false;    bool slope2 = false;    bool slope3 = false;    bool slope4 = false;
    bool slope1ok = false;  bool slope2ok = false;  bool slope3ok = false;  bool slope4ok = false;
    bool slope1end = false;  bool slope2end = false;  bool slope3end = false;  bool slope4end = false;


// B - D
	if (
		(!eq_E_B && !eq_E_D && !oppoPix) && (!eq_D_H && !eq_B_F)
	 && (eq(E,A) || El>=Dl&&El>=Bl) && ( (El<Dl&&El<Bl) || none_eq2(A,B,D) || neq(E,P) || neq(E,Q) )
	 && ( eq_B_D &&(eq(E,A)||eq(B,PC)||eq(D,QG)||sim(vE,vC)||sim(vE,vG)) || simb(vB,vD)&&(eq_F_H||eq(E,C)||eq(E,G)) )
		) {
		J=admixX(A,B,C,D,E,F,G,H,I
				,P,PA,PC,Q,QA,QG,R,RC,RI,S,SG,SI,AA,CC,GG
				,El, Bl, Dl, Fl, Hl
				,vE, vB, vD, vC, vG
				);
		slope1 = true;
		slope1ok = (J.b < 1.1);
		slope1end = (J.b < 3.1);
		skiprest = (J.b > 7.1);
		J = (J.b > 3.1) ? vE :
			(J.b > 1.1) ? (J - 2.0) :
			J;
	}
// B - F
	if ( !slope1
	 && (!eq_E_B && !eq_E_F && !oppoPix) && (!eq_B_D && !eq_F_H)
	 && (eq(E,C) || El>=Bl&&El>=Fl) && ( (El<Bl&&El<Fl) || none_eq2(C,B,F) || neq(E,P) || neq(E,R) )
	 && ( eq_B_F &&(eq(E,C)||eq(B,PA)||eq(F,RI)||sim(vE,vA)||sim(vE,vI)) || simb(vB,vF)&&(eq_D_H||eq(E,A)||eq(E,I)) ) 
	 ) {
		K=admixX(C,F,I,B,E,H,A,D,G
				,R,RC,RI,P,PC,PA,S,SI,SG,Q,QA,QG,CC,II,AA
				,El,Fl,Bl,Hl,Dl
				,vE,vF,vB,vI,vA
				);
		slope2 = true;
		slope2ok = (K.b < 1.1);
		slope2end = (K.b < 3.1);
		skiprest = (K.b > 7.1);
		K = (K.b > 3.1) ? vE :	
			(K.b > 1.1) ? (K - 2.0) :
			K;
	}
// D - H
	if ( !slope1 && !skiprest
	 && (!eq_E_D && !eq_E_H && !oppoPix) && (!eq_F_H && !eq_B_D)
	 && (eq(E,G) || El>=Hl&&El>=Dl)  &&  ((El<Hl&&El<Dl) || none_eq2(G,D,H) || neq(E,S) || neq(E,Q))
	 &&	( eq_D_H &&(eq(E,G)||eq(D,QA)||eq(H,SI)||sim(vE,vA)||sim(vE,vI)) || simb(vD,vH)&&(eq_B_F||eq(E,A)||eq(E,I)) )
	 ) {
		L=admixX(G,D,A,H,E,B,I,F,C
				,Q,QG,QA,S,SG,SI,P,PA,PC,R,RI,RC,GG,AA,II
				,El,Dl,Hl,Bl,Fl
				,vE,vD,vH,vA,vI
				);
		slope3 = true;
		slope3ok = (L.b < 1.1);
		slope3end = (L.b < 3.1);
		skiprest = (L.b > 7.1);
		L = (L.b > 3.1) ? vE :	
			(L.b > 1.1) ? (L - 2.0) :
			L;
	}
// F - H
	if ( !slope2 && !slope3 && !skiprest
	 && (!eq_E_F && !eq_E_H && !oppoPix) && (!eq_B_F && !eq_D_H)
	 && (eq(E,I) || El>=Fl&&El>=Hl)  &&  ((El<Fl&&El<Hl) || none_eq2(I,F,H) || neq(E,R) || neq(E,S))
	 && ( eq_F_H &&(eq(E,I)||eq(F,RC)||eq(H,SG)||sim(vE,vC)||sim(vE,vG)) || simb(vF,vH)&&(eq_B_D||eq(E,C)||eq(E,G)) )
	  ) {
		M=admixX(I,H,G,F,E,D,C,B,A
				,S,SI,SG,R,RI,RC,Q,QG,QA,P,PC,PA,II,GG,CC
				,El,Hl,Fl,Dl,Bl
				,vE,vH,vF,vG,vC
				);
		slope4 = true;
		slope4ok = (M.b < 1.1);
		slope4end = (M.b < 3.1);
		skiprest = (M.b > 7.1);
		M = (M.b > 3.1) ? vE :	
			(M.b > 1.1) ? (M - 2.0) :
			M;
	}


//  long gentle 2:1 slope  (P100)

	if (slope4ok) {
		if (all_eq2(R,F,G) && neq(R, RC) && (neq(Q,G)||eq(Q, QA))) {L=admixL(vE,vH); skiprest = true;}
		if (all_eq2(S,H,C) && neq(S, SG) && (neq(P,C)||eq(P, PA))) {K=admixL(vE,vF); skiprest = true;}
	}

	if (slope3ok) {
		if (all_eq2(Q,D,I) && neq(Q, QA) && (neq(R,I)||eq(R, RC))) {M=admixL(vE,vH); skiprest = true;}
		if (all_eq2(S,H,A) && neq(S, SI) && (neq(A,P)||eq(P, PC))) {J=admixL(vE,vD); skiprest = true;}
	}

	if (slope2ok) {
		if (all_eq2(R,F,A) && neq(R, RI) && (neq(A,Q)||eq(Q, QG))) {J=admixL(vE,vB); skiprest = true;}
		if (all_eq2(P,B,I) && neq(P, PA) && (neq(I,S)||eq(S, SG))) {M=admixL(vE,vF); skiprest = true;}
	}

	if (slope1ok) {
		if (all_eq2(Q,D,C) && neq(Q, QG) && (neq(C,R)||eq(R, RI))) {K=admixL(vE,vB); skiprest = true;}
		if (all_eq2(P,B,G) && neq(P, PC) && (neq(G,S)||eq(S, SI))) {L=admixL(vE,vD); skiprest = true;}
	}

if (!skiprest && !oppoPix) {


    if (!eq_E_H && none_eq2(H,A,C)) {

        if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && (!slope4end && !eq_F_H) &&
            !eq_E_F && eq(R,H) && eq(F,G) ) {
            M = admixS( A, B, C, D, E, F, G, H, I
                      , R, RC, RI, S, SG, SI, II, CC
                      , vE, vF, vC
                      );
            skiprest = true;}

        if ( !skiprest && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && (!slope3end && !eq_D_H) &&
             !eq_E_D && eq(Q,H) && eq(D,I) ) {
            L = admixS( C, B, A, F, E, D, I, H, G
                      , Q, QA, QG, S, SI, SG, GG, AA
                      , vE, vD, vA
                      );
            skiprest = true;}
    }

    if ( !skiprest && !eq_E_B && none_eq2(B,G,I)) {

        if ( (!slope1 && !eq_B_D)  && (!slope4 && !eq_F_H) && (!slope2end && !eq_B_F) &&
              !eq_E_F && eq(B,R) && eq(A,F) ) {
            K = admixS( G, H, I, D, E, F, A, B, C
                      , R, RI, RC, P, PA, PC, CC, II
                      , vE, vF, vI
                      );
            skiprest = true;}

        if ( !skiprest && (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && (!slope1end && !eq_B_D) &&
             !eq_E_D && eq(B,Q) && eq(C,D) ) {
            J = admixS( I, H, G, F, E, D, C, B, A
                      , Q, QG, QA, P, PC, PA, AA, GG
                      , vE, vD, vG
                      );
            skiprest = true;}

    }

    if ( !skiprest && !eq_E_D && none_eq2(D,C,I) ) {

        if ( (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && (!slope3end && !eq_D_H) &&
              !eq_E_H && eq(D,S) && eq(A,H) ) {
            L = admixS( C, F, I, B, E, H, A, D, G
                      , S, SI, SG, Q, QA, QG, GG, II
                      , vE, vH, vI
                      );
            skiprest = true;}

        if ( !skiprest && (!slope3 && !eq_D_H) && (!slope2 && !eq_B_F) && (!slope1end && !eq_B_D) &&
              !eq_E_B && eq(P,D) && eq(B,G) ) {
            J = admixS( I, F, C, H, E, B, G, D, A
                      , P, PC, PA, Q, QG, QA, AA, CC
                      , vE, vB, vC
                      );
            skiprest = true;}

    }

    if ( !skiprest && !eq_E_F && none_eq2(F,A,G) ) {

        if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && (!slope4end && !eq_F_H) &&
              !eq_E_H && eq(S,F) && eq(H,C) ) {
            M = admixS( A, D, G, B, E, H, C, F
                      , I, S, SG, SI, R, RC, RI, II, GG
                      , vE, vH, vG
                      );
            skiprest = true;}

        if ( !skiprest && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && (!slope2end && !eq_B_F) &&
             !eq_E_B && eq(P,F) && eq(B,I) ) {
            K = admixS( G, D, A, H, E, B, I, F, C
                      , P, PA, PC, R, RI, RC, CC, AA
                      , vE, vB, vA
                      );
            skiprest = true;}

    }
}

skiprest = skiprest||slope1||slope2||slope3||slope4;

/**************************************************
        Concave + Cross	（P100）	   
 *************************************************/
vec3 vT;		float maxl;

if (!skiprest &&
    Bl<El && !eq_E_D && !eq_E_F && eq_E_H && none_eq2(E,A,C) && all_eq3(E,G,I,S) ) {

	Bl -= (float(eq(B, A))+float(eq(B, C))) *0.145898;
	Dl += step(El, Dl) * 2.0 * (El - Dl) - float(eq(A, D)) *0.145898;
	Fl += step(El, Fl) * 2.0 * (El - Fl) - float(eq(C, F)) *0.145898;

	maxl = max(Bl, max(Dl, Fl));

	vT = eq_B_D || eq_B_F ? vB :
		 maxl <= Dl      ? vD :
		 maxl <= Fl      ? vF : 
						   vB ;

	J=admixC(vT,vE);
    K=J;

   skiprest = true;
}

if (!skiprest &&
    Hl<El && !eq_E_D && !eq_E_F && eq_E_B && none_eq2(E,G,I) && all_eq3(E,A,C,P) ) {

	Hl -= (float(eq(H, G))+float(eq(H, I))) *0.145898;
	Dl += step(El, Dl) * 2.0 * (El - Dl) - float(eq(D, G)) *0.145898;
	Fl += step(El, Fl) * 2.0 * (El - Fl) - float(eq(F, I)) *0.145898;

	maxl = max(Hl, max(Dl, Fl));

	vT = eq_D_H || eq_F_H ? vH :
		 maxl <= Dl      ? vD :
		 maxl <= Fl      ? vF : 
						   vH ;

	L=admixC(vT,vE);
    M=L;

   skiprest = true;
}

if (!skiprest &&
    Fl<El && !eq_E_B && !eq_E_H && eq_E_D && none_eq2(E,C,I) && all_eq3(E,A,G,Q) ) {

	Fl -= (float(eq(C, F))+float(eq(F, I))) *0.145898;
	Bl += step(El, Bl) * 2.0 * (El - Bl) - float(eq(B, C)) *0.145898;
	Hl += step(El, Hl) * 2.0 * (El - Hl) - float(eq(H, I)) *0.145898;

	maxl = max(Fl, max(Bl, Hl));

	vT = eq_B_F || eq_F_H ? vF :
		 maxl <= Bl      ? vB :
		 maxl <= Hl      ? vH : 
						   vF ;

	K=admixC(vT,vE);
    M=K;


   skiprest = true;
}

if (!skiprest &&
    Dl<El && !eq_E_B && !eq_E_H && eq_E_F && none_eq2(E,A,G) && all_eq3(E,C,I,R) ) {

	Dl -= (float(eq(A, D))+float(eq(D, G))) *0.145898;
	Bl += step(El, Bl) * 2.0 * (El - Bl) - float(eq(A, B)) *0.145898;
	Hl += step(El, Hl) * 2.0 * (El - Hl) - float(eq(G, H)) *0.145898;

	maxl = max(Dl, max(Bl, Hl));

	vT = eq_B_D || eq_D_H ? vD :
		 maxl <= Bl      ? vB :
		 maxl <= Hl      ? vH : 
						   vD ;

	J=admixC(vT,vE);
    L=J;

   skiprest = true;
}

/*
     ✕О
 ООО✕
     ✕О
*/
if (!skiprest && !eq_E_F&&eq_E_D&&eq_B_F&&eq_F_H && all_eq2(E,C,I) && (eq(E,Q)||El>Fl) && neq(F,src(+3.0, 0.0)) ) {K=admixK(vF,vE); M=K; skiprest=true;}
if (!skiprest && !eq_E_D&&eq_E_F&&eq_B_D&&eq_D_H && all_eq2(E,A,G) && (eq(E,R)||El>Dl) && neq(D,src(-3.0, 0.0)) ) {J=admixK(vD,vE); L=J; skiprest=true;}
if (!skiprest && !eq_E_H&&eq_E_B&&eq_D_H&&eq_F_H && all_eq2(E,G,I) && (eq(E,P)||El>Hl) && neq(H,src(0.0, +3.0)) ) {L=admixK(vH,vE); M=L; skiprest=true;}
if (!skiprest && !eq_E_B&&eq_E_H&&eq_B_D&&eq_B_F && all_eq2(E,A,C) && (eq(E,S)||El>Bl) && neq(B,src(0.0, -3.0)) ) {J=admixK(vB,vE); K=J;}

	//final write
	vec2 a = fract(pixelPos);

	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);


}	
}