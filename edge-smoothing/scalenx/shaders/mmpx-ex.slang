#version 450

// MMPX
// by Morgan McGuire and Mara Gagiu
// https://casual-effects.com/research/McGuire2021PixelArt/
// License: MIT
// adapted for slang by hunterk
// 2025 Enhanced by CrashGG.

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
   // Uses BT.601 standard from the CRT era
   return dot(col, vec3(0.299, 0.587, 0.114));
   // RGB average
   //return dot(col, vec3(0.3333333));
}


/* Explanation of constants:
0.145898	：			Double short golden ratio of 1.0
0.0638587	：		Squared double short golden ratio of RGB Euclidean distance
0.024391856	：		Squared (double short + single) golden ratio of RGB Euclidean distance
0.00931686	：		Squared triple short golden ratio of RGB Euclidean distance
0.001359312	：		Squared quadruple short golden ratio of RGB Euclidean distance
0.4377		：		Squared single golden ratio of RGB Euclidean distance
0.75			：		Squared half of RGB Euclidean distance
*/
// Pixel Similarity Detection LV1
// pin zz
bool sim1(vec3 col1, vec3 col2) {

    vec3 diff = col1 - col2;
    vec3 absdiff = abs(diff);

    // 1. Fast component difference check
    if ( absdiff.r > 0.1 || absdiff.g > 0.1 || absdiff.b > 0.1 ) return false;

    // 2. Fast squared distance check
	float dot_diff = dot(diff, diff);
    if (dot_diff < 0.001359312) return true;

    // 3. Progressive pixel check
    float min_diff = min(diff.r, min(diff.g, diff.b));
    float max_diff = max(diff.r, max(diff.g, diff.b));
    if ( max_diff-min_diff>0.096 ) return false;    // Exit if difference exceeds int24
    if ( max_diff-min_diff<0.024 && dot_diff<0.024391856)  return true;  //  Classify as progressive pixel if difference ≤ int6. Relax threshold by one level.

	// 4. Gray pixel check
    float sum1 = dot(col1, vec3(1.0));  // Sum of three channels
    float sum2 = dot(col2, vec3(1.0));
    float avg1 = sum1 * 0.3333333;
    float avg2 = sum2 * 0.3333333;

	vec3 graydiff1 = col1 - vec3(avg1);
	vec3 graydiff2 = col2 - vec3(avg2);
	float dotgray1 = dot(graydiff1,graydiff1);
	float dotgray2 = dot(graydiff2,graydiff2);
    // 0.002: Allows max single-channel difference of int13 when avg=20. 0.0004: Allows max single-channel difference of int6, or int3+4 for dual channels
	float tolerance1 = avg1<0.08 ? 0.002 : 0.0004;
	float tolerance2 = avg2<0.08 ? 0.002 : 0.0004;
    // 0.078 Limits max green channel value to 19, the perceptual threshold for human vision
    bool Col1isGray = sum1<0.078||dotgray1<tolerance1;
    bool Col2isGray = sum2<0.078||dotgray2<tolerance2;

	// Relax to Lv2 if both are gray
    if ( Col1isGray && Col2isGray && dot_diff<0.024391856 ) return true;

	// Exit if only one is gray
    if ( Col1isGray != Col2isGray ) return false;

    // Accumulate positive/negative values separately using max/min
    float team_pos = abs(dot(max(diff, 0.0), vec3(1.0)));
    float team_neg = abs(dot(min(diff, 0.0), vec3(1.0)));
    // Find opposing channels and add to squared distance for judgment
    float team_rebel = min(team_pos, team_neg);
    // Implementation note: At least 3x opposing channel value needs to be added. (+1x to break even, +2x to form increasing trend)
    return dot_diff + team_rebel*team_rebel*3.0 < 0.00931686;

}

// Pixel Similarity Detection LV2 and LV3
bool sim2n3(vec3 col1, vec3 col2, int Lv) {

    // 1. Clamp dark regions
    vec3 clampCol1 = max(col1, vec3(0.078));
    vec3 clampCol2 = max(col2, vec3(0.078));

    vec3 clampdiff = clampCol1 - clampCol2;

	// Euclidean distance between two points: (2 short + 1), double short golden ratio
    float dotdist = Lv==2 ? 0.024391856 : 0.0638587;

    return dot(clampdiff, clampdiff) < dotdist;
}

bool sim2(vec3 colC1, uint C1, uint C2) {
    if (C1==C2) return true;
    return sim2n3(colC1, unpackUnorm4x8(C2).rgb, 2);	// Note: Exclude alpha channel
}

bool sim3(vec3 col1, vec3 col2) {
    return sim2n3(col1, col2, 3);
}

bool mixcheck(vec3 col1, vec3 col2) {

    vec3 diff = col1 - col2;

    // Progressive pixel check
    float min_diff = min(diff.r, min(diff.g, diff.b));
    float max_diff = max(diff.r, max(diff.g, diff.b));
    if ( max_diff-min_diff>0.618034 ) return false;

	float dot_diff = dot(diff, diff);
    if( max_diff-min_diff<0.024 && dot_diff<0.75)  return true;  //  0.020 ≤ int5    0.024 ≤ int6

    // Accumulate positive/negative values separately using max/min
    float team_pos = abs(dot(max(diff, 0.0), vec3(1.0)));
    float team_neg = abs(dot(min(diff, 0.0), vec3(1.0)));
    // Find opposing channels and add to squared distance for judgment
    float team_rebel = min(team_pos, team_neg);
    // Implementation note: At least 3x opposing channel value needs to be added. (+1x to break even, +2x to form increasing trend)
    return dot_diff + team_rebel*team_rebel*3.0 < 0.4377;
}



#define eq(a,b) (a==b)
#define noteq(a,b) (a!=b)
//    Note: Legacy approach allowed int1 difference per channel, which is less efficient and effective than total int2 across three channels

#define vec_noteq(a,b) (dot(abs(a-b), vec3(1.0)) > 0.008)
bool all_eq2(uint B, uint A0, uint A1) {
    return ((B ^ A0) | (B ^ A1)) == 0u;
}

bool any_eq2(uint B, uint A0, uint A1) {
    return B == A0 || B == A1;
}

bool any_eq3(uint B, uint A0, uint A1, uint A2) {
    return B == A0 || B == A1 || B == A2;
}

bool none_eq2(uint B, uint A0, uint A1) {
    return (B != A0) && (B != A1);
}


// Pre-define
//#define testcolor vec3(1.0, 0.0, 1.0)  // Magenta
//#define testcolor2 vec3(0.0, 1.0, 1.0)  // Cyan
//#define testcolor3 vec3(1.0, 1.0, 0.0)  // Yellow
//#define testcolor4 vec3(1.0, 1.0, 1.0)  // White

#define slopeBAD vec3(2.0)
#define theEXIT vec3(4.0)
#define slopOFF vec3(8.0)
#define Mix382 mix(colX,colE,0.381966)
#define Mix618 mix(colX,colE,0.618034)
#define Mix854 mix(colX,colE,0.8541)
#define Mix382off Mix382+slopOFF
#define Mix618off Mix618+slopOFF
#define Mix854off Mix854+slopOFF
#define Xoff colX+slopOFF
#define checkblack(col) ((col).g < 0.078 && (col).r < 0.1 && (col).b < 0.1)
#define diffEB abs(El-Bl)
#define diffED abs(El-Dl)

//pin zz
// "Concave + Cross" weak blending (weak blend / none)
vec3 admixC(vec3 colX, vec3 colE) {

	bool mixok = mixcheck(colX, colE);

	return mixok ? Mix618 : colE;

}

// K-shape forced weak blending (weak blend / weaker)
vec3 admixK(vec3 colX, vec3 colE) {

	bool mixok = mixcheck(colX, colE);

	return mixok ? Mix618 : Mix854;

}

// L-shape 2:1 slope  Main corner extension
// Implementation note: This rule requires exactly identical 4 pixels on the slope. Otherwise various artifacts will appear!
vec3 admixL(vec3 colX, vec3 colE, vec3 colS) {

    // Judging eqX,E originally captured numerous duplicate pixels, now filtered by slopeok in main logic.

	// Return colX directly if target X differs from reference S (sample), indicating already blended once
	if (vec_noteq(colX, colS)) return colX;

	bool mixok = mixcheck(colX, colE);

    return mixok ? Mix382 : colX;
}

/********************************************************************************************************************************************
 *               												main slope + X cross-processing mechanism					                *
 ************************************************************************************************************************************** zz  */
vec3 admixX(uint A, uint B, uint C, uint D, uint E, uint F, uint G, uint H, uint I, uint P, uint PA, uint PC, uint Q, uint QA, uint QG, uint R, uint RC, uint RI, uint S, uint SG, uint SI, uint AA, uint CC, uint GG, float El, float Bl, float Dl, float Fl, float Hl, vec3 colE, vec3 colB, vec3 colD) {

	//pre-cal
	bool eq_B_C = eq(B, C);
	bool eq_D_G = eq(D, G);

    // Exit if sandwiched by double-sided straight walls
    if (eq_B_C && eq_D_G) return slopeBAD;

	//Pre-declare
	bool eq_A_B;		bool eq_A_D;		bool eq_A_P;	bool eq_A_Q;
	bool eq_B_P;		bool eq_B_PA;	bool eq_B_PC;
	bool eq_D_Q;		bool eq_D_QA;	bool eq_D_QG;
    bool eq_E_F;		bool eq_E_H;		bool eq_E_I;    bool En3;
	bool B_slope;	bool B_tower;	bool B_wall;
    bool D_slope;	bool D_tower;	bool D_wall;
	vec3 colX;		bool Xisblack;
    bool mixok;

	bool eq_B_D = eq(B,D);
    bool eq_E_A = eq(E,A);
	
    #define comboA3  eq_A_P && eq_A_Q
    #define En4square  En3 && eq_E_I

/*=========================================
                    B != D
  ==================================== zz */
if (!eq_B_D){

	// Exit if E-A match (violates preset logic)
	if (eq_E_A) return slopeBAD;

	// Exit if B and D differ significantly, more than either's difference from center E
	float diffBD = abs(Bl-Dl);
	if (diffBD > diffEB || diffBD > diffED) return slopeBAD;

	// Avoid single-pixel font edges squeezed by black background (luminance difference usually exceeds 0.5)
	// Note: If BD differ, use dual black check instead of average
	Xisblack = checkblack(colB) && checkblack(colD);
	if ( Xisblack && El >0.5 && (Fl<0.078 || Hl<0.078) ) return theEXIT;

// Exclusion rules before legacy logic (triangle vertices cannot be convex)
	eq_A_B = eq(A,B);
	if ( !Xisblack && eq_A_B && eq_D_G && eq(B,P) ) return slopeBAD;

	eq_A_D = eq(A,D);
	if ( !Xisblack && eq_A_D && eq_B_C && eq(D,Q) ) return slopeBAD;

    // Are B and D unrelated? Not applicable here (eliminates some artifacts but loses shapes, especially non-native pixel art like Double Dragon attract mode sprites)
	// Blend B and D for X
	colX = mix(colB, colD, 0.5);

	mixok = mixcheck(colX,colE);

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
	// High priority for A-side triple consecutive pixels (eq_A_P && eq_A_Q)
    if (comboA3) return mixok ? Mix382off : Xoff;

    // Official legacy rule
    if ( eq(E,C) || eq(E,G) ) return mixok ? Mix382off : Xoff;

    // Enhanced legacy rule 1 (good for trend detection), but not rule 2 (wall bypass issue)
    if ( !eq_D_G&&eq(E,QG)&&sim2(colE,E,G) || !eq_B_C&&eq(E,PC)&&sim2(colE,E,C) ) return mixok ? Mix382off : Xoff;


    // Exclude "3-pixel single-side wall" cases
    if (!Xisblack){
        if ( eq_A_B&&eq_B_C || eq_A_D&&eq_D_G ) return slopeBAD;
    }

    // F-H inline trend (including En3), placed after wall rules
    if ( eq(F,H) ) return mixok ? Mix382off : Xoff;
    // Abandon remaining "2-pixel single-side wall" and unpatterned single pixels

    return slopeBAD;
} // B != D

/*******  B == D prepare *******/
  
	// Avoid single-pixel font edges squeezed by black background
	Xisblack = checkblack(colB);
	if ( Xisblack && El >0.5 && (Fl<0.078 || Hl<0.078) ) return theEXIT;

    colX = colB;
    bool eq_E_C = eq(E,C);
    bool eq_E_G = eq(E,G);
	bool sim_EC = eq_E_C || sim2n3(colE,unpackUnorm4x8(C).rgb,2);	//Note: Exclude alpha channel
	bool sim_EG = eq_E_G || sim2n3(colE,unpackUnorm4x8(G).rgb,2);	//Note: Exclude alpha channel

	bool ThickBorder;


/*===============================================
                 Core legacy rule with sim2 enhancement
  ========================================== zz */
if ( (sim_EC || sim_EG) && !eq_E_A ){

/* Logic:
    1. Handle continuous border shapes without blending
    2. Special handling for long slopes
    3. Legacy rules
    4. Handle E inline patterns (En4, En3, F-H), remaining single bars and pixels
    5. Handle L-shaped inner single bar and outer single bar
    5. Default fallback return
*/

	eq_A_B = eq(B,A);
	eq_B_P = eq(B,P);
    eq_B_PC = eq(B,PC);
    eq_B_PA = eq(B,PA);
	eq_D_Q = eq(D,Q);
    eq_D_QG = eq(D,QG);
    eq_D_QA = eq(D,QA);
	B_slope = eq_B_PC && !eq_B_P && !eq_B_C;
	B_tower = eq_B_P && !eq_B_PC && !eq_B_C && !eq_B_PA;
	D_slope = eq_D_QG && !eq_D_Q && !eq_D_G;
	D_tower = eq_D_Q && !eq_D_QG && !eq_D_G && !eq_D_QA;


    // Return Xoff for strong continuous B+ D+ shapes (no blending)
    if ( (B_slope||B_tower) && (D_slope||D_tower) && !eq_A_B) return Xoff;


	eq_A_P = eq(A, P);
	eq_A_Q = eq(A, Q);
	mixok = mixcheck(colX,colE);
    ThickBorder = eq_A_B && (eq_A_P||eq_A_Q|| eq(A,AA)&&(eq_B_PA||eq_D_QA));
	if (ThickBorder && !Xisblack) mixok=false;

    // A-side triple consecutive pixels (eq_A_P && eq_A_Q)
    if (comboA3) {
        if (!eq_A_B) return Xoff;
        else mixok=false;
    }

    // XE_messL B-D-E L-shape with sim2 high similarity		WIP 
    // bool XE_messL = (eq_B_C && !sim_EG || eq_D_G && !sim_EC) ;

    eq_E_F = eq(E, F);
	B_wall = eq_B_C && !eq_B_PC && !eq_B_P;

    // Long clear slope (not thick solid edge. Strong trend!)
    // Special condition for long slopes
	if ( B_wall && D_tower ) {
        if (eq_E_G || sim_EG&&eq(E,QG) ) {   // Legacy rule + enhanced legacy
            if (eq_A_B) return mixok ? Mix382 : colX;    // With thickness
            return colX;                               // Hollow
        }
        // Clear zigzag shape, exclude eq_A_B + XE_messL ???
        //if (eq_A_B  && !XE_messL) return ; // Poor effect
        if (eq_A_B) return slopeBAD;
        // Double-pixel with subsequent long slope
        if (eq_E_F ) return colX;
        // Single-pixel without subsequent long slope
        return Xoff;
    }

    eq_E_H = eq(E, H);
	D_wall = eq_D_G && !eq_D_QG&& !eq_D_Q;

	if ( B_tower && D_wall ) {
        if (eq_E_C || sim_EC&&eq(E,PC) ) {   // Legacy rule + enhanced legacy
            if (eq_A_B) return mixok ? Mix382 : colX;    // With thickness
            return colX;                                           // Hollow
        }
        // Clear zigzag shape, exclude eq_A_B + XE_messL ???
        //if (eq_A_B  && !XE_messL) return ; // Poor effect
        if (eq_A_B) return slopeBAD;
        // Double-pixel with subsequent long slope
        if (eq_E_H ) return colX;
        // Single-pixel without subsequent long slope
        return Xoff;
    }


    // Official legacy rule (after special shapes which have explicit no-blending)
    if (eq_E_C || eq_E_G) return mixok ? Mix382 : colX;

    // Enhanced legacy rule 1
    if (sim_EG&&!eq_D_G&&eq(E,QG) || sim_EC&&!eq_B_C&&eq(E,PC)) return mixok ? Mix382off : Xoff;

    // Enhanced legacy rule 2
    if (sim_EC && sim_EG) return mixok ? Mix382off : Xoff;


    // F-H inline trend (skip En4, En3)
    if ( eq(F,H) )  return mixok ? Mix382off : Xoff;

	// Relaxed final cleanup for two long slopes (non-clear shapes)
    // Implementation note: This section differs from F-H cleanup. Default to neutral unless cube shape
	if (eq_B_C && eq_D_Q) {
        // Exit for double cube shape
		if (eq_B_P && eq_B_PC && eq_A_B && eq_D_QA && !eq_D_QG && eq_E_F && eq(H,I) ) return theEXIT;

		return mixok ? Mix382off : Xoff;
	}

	if ( eq_D_G && eq_B_P) {
        // Exit for double cube shape
		if (eq_D_Q && eq_D_QG && eq_A_B && eq_B_PA && !eq_B_PC && eq_E_H && eq(F,I) ) return theEXIT;

		return mixok ? Mix382off : Xoff;
	}

    eq_E_I = eq(E, I);

    // Exit for clear L-turn with inner parallel single bar
    if (eq_A_B && !ThickBorder && !eq_E_I ) {
	    if (B_wall && eq_E_F) return theEXIT;
	    if (D_wall && eq_E_H) return theEXIT;
	}

    // Early return if colors are similar
    if (mixok) return Mix382off;

    // Exit for hollow L-turn with outer single bar (fix font edge issues)
    if ( !eq_A_B && (eq_E_F||eq_E_H) && !eq_E_I) {
        if (B_tower && !eq_D_Q && !eq_D_QG) return theEXIT;
        if (D_tower && !eq_B_P && !eq_B_PC) return theEXIT;
    }

    // Fallback handling
    return mixok ? Mix382off : Xoff;

} // sim2 base


/*===================================================
                    E - A cross
  ============================================== zz */
if (eq_E_A) {

	// Cross ✕ judgment requires "region" and "trend" concepts - tighter conditions for different regions

    // No need to exit for unrelated B/D!

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    eq_E_I = eq(E, I);

    En3 = eq_E_F&&eq_E_H;

	// Special shape: Square (En3 && eq_E_I)
	if ( En4square ) {
        if( noteq(G,H) && noteq(C,F)                      //  Independent clear 4-pixel square / 6-pixel rectangle (both sides)
		&& (eq(H,S) == eq(I,SI) && eq(F,R) == eq(I,RI)) ) return theEXIT;
        //else return mixok ? mix(X,E,0.381966) : X;    Note: Do not return directly. Need board decision rules as adjacent B/D may form bubbles with squares
    }

    //  Special shape: Dot pattern
	//	Implementation 1: !eq_E_F, !eq_E_H (avoid !sim to prevent shape loss)
    //  Implementation 2: Force blending to preserve shapes (Akuma from Gouketsuji Ichizoku, Saturday Night Slam Masters 2)

	bool Eisblack = checkblack(colE);
	mixok = mixcheck(colX,colE);

	//  1. Dot pattern center
    if ( eq_E_C && eq_E_G && eq_E_I && !eq_E_F && !eq_E_H ) {

		// Exit if center E is black (KOF '96 power bar, Punisher's belt) to avoid high-contrast blending
		if (Eisblack) return theEXIT;
		// Implementation 1: Do not capture black B (normal logic entry)
		// Implementation 2: No need for separate eq_F_H check (>95% probability) + layered progression in power bars, 0.5 fallback blend
		return mixok ? Mix382off : Mix618off;
	}

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
    eq_B_PA = eq(B,PA);

	//  2. Dot pattern edge
    if ( eq_A_P && eq_A_Q && eq(A,AA) && noteq(A,PA) && noteq(A,QA) )  {
		if (Eisblack) return theEXIT;

        // Use strong blend for layered progressive edges
		if ( !eq_B_PA && eq(PA,QA) ) return mixok ? Mix382off : Mix618off;
        // Remaining perfect cross (definite dot edge) - use weak blend
        // Fallback weak blend. No need for separate power bar border handling
		return mixok ? Mix618off : Mix854off;
	}

    eq_D_QA = eq(D,QA);
    eq_D_QG = eq(D,QG);
    eq_B_PC = eq(B,PC);

  //   3. Half dot pattern (usually shadow on contour edges) - use weak blend
	if ( eq_E_C && eq_E_G && eq_A_P && eq_A_Q &&
		(eq_B_PC || eq_D_QG) &&
		 eq_D_QA && eq_B_PA) {
		//if (Eisblack) return ; Unnecessary

        return mixok ? Mix618off : Mix854off;
		}

    //   4. Quarter dot pattern (prone to unsightly pinky effect - Guile's Sonic Boom in SF2, Dino Crisis character select)

	if ( eq_E_C && eq_E_G && eq_A_P
		 && eq_B_PA &&eq_D_QA && eq_D_QG
		 && eq_E_H
		) return mixok ? Mix618off : Mix854off;

	if ( eq_E_C && eq_E_G && eq_A_Q
		 && eq_B_PA &&eq_D_QA && eq_B_PC
		 && eq_E_F
		) return mixok ? Mix618off : Mix854off;


    // E-side triple consecutive pixels (must come after dot patterns)
    if ( eq_E_C && eq_E_G ) return Xoff;

    // A-side triple consecutive pixels (eq_A_P && eq_A_Q) - must come after dot patterns. Blend first since E-A match
	if (comboA3) return mixok ? Mix382off : Xoff;


    // B-D part of long slope
	eq_B_P = eq(B,P);
	eq_D_Q = eq(D,Q);
	B_wall = eq_B_C && !eq_B_P;
	B_tower = eq_B_P && !eq_B_C;
	D_tower = eq_D_Q && !eq_D_G;
	D_wall = eq_D_G && !eq_D_Q;

    int scoreE = 0; int scoreB = 0; int scoreD = 0; int scoreZ = 0;


// E B D region board scoring rules

//	E Zone
    if (En3) {
        scoreE += 1;
        if (B_wall || B_tower || D_tower || D_wall) scoreZ = 1;
    }

    if (eq_E_C) {
		scoreE += 1;
		scoreE += int(eq_E_F);
	}

    if (eq_E_G) {
        scoreE += 1;
		scoreE += int(eq_E_H);

    }

	if (scoreE==0) {
        // Single bar
        if (eq_E_F ||eq_E_H) return theEXIT;
    }

    if ( eq(F,H) ) {
		scoreE += 1;
        if ( scoreZ==0 && B_wall && (eq(F,R) || eq(G,H) || eq(F,I)) ) scoreZ = 1;
        if ( scoreZ==0 && D_wall && (eq(C,F) || eq(H,S) || eq(F,I)) ) scoreZ = 1;
    }


	#define Bn3  eq_B_P&&eq_B_C
	#define Dn3  eq_D_G&&eq_D_Q

//	B Zone
	scoreB -= int(Bn3);
	scoreB -= int(eq(C,P));
    if (scoreB < 0) scoreZ = 0;

    if (eq_B_PA) {
		scoreB -= 1;
		scoreB -= int(eq_B_P);    //Replace eq(P,PA)
	}

//        D Zone
	scoreD -= int(Dn3);
	scoreD -= int(eq(G,Q));
    if (scoreD < 0) scoreZ = 0;

    if (eq_D_QA) {
		scoreD -= 1;
		scoreD -= int(eq_D_Q);    //Replace eq(Q,QA)
	}

    int scoreFinal = scoreE + scoreB + scoreD + scoreZ ;

    if (scoreE >= 1 && scoreB >= 0 && scoreD >=0) scoreFinal += 1;

    if (scoreFinal >= 2) return colX;

    if (scoreFinal == 1) return mixok ? Mix382 : colX;

    // Final addition: Zero total score with no B/D penalties (forms long slope)
    if (scoreB >= 0 && scoreD >=0) {
        if (B_wall&&D_tower) return colX;
        if (B_tower&&D_wall) return colX;
    }

    return slopeBAD;

}	// eq_E_A



/*=========================================================
                   F - H / B+ D+ extension new rules
  ==================================================== zz */

// This section differs from sim section - natural wall isolation between center and En4square/BD logic
// Different judgment rules from sim side

	eq_B_P = eq(B, P);
    eq_B_PC = eq(B, PC);
	eq_D_Q = eq(D, Q);
    eq_D_QG = eq(D, QG);

    // Exit for unrelated B/D (Implementation note: Required for this branch)
    if ( !eq_B_C && !eq_B_P && !eq_B_PC && !eq_D_G && !eq_D_Q && !eq_D_QG ) return slopeBAD;

	mixok = mixcheck(colX,colE);
    eq_E_I = eq(E, I);

	// Exit if center E is single high-contrast pixel
	// Tighter threshold for bright E
	float E_lumDiff = El > 0.92 ? 0.145898 : 0.381966;
	// High difference with surroundings
    if ( !mixok && !eq_E_I && abs(El-Fl)>E_lumDiff && abs(El-Hl)>E_lumDiff ) return slopeBAD;


    eq_A_B = eq(A, B);
	eq_A_P = eq(A, P);
	eq_A_Q = eq(A, Q);
    eq_B_PA = eq(B,PA);
    eq_D_QA = eq(D,QA);

    ThickBorder = eq_A_B && (eq_A_P||eq_A_Q|| eq(A,AA)&&(eq_B_PA||eq_D_QA));

	if (ThickBorder && !Xisblack) mixok=false;

	B_slope = eq_B_PC && !eq_B_P && !eq_B_C;
	B_tower = eq_B_P && !eq_B_PC && !eq_B_C && !eq_B_PA;
	D_slope = eq_D_QG && !eq_D_Q && !eq_D_G;
	D_tower = eq_D_Q && !eq_D_QG && !eq_D_G && !eq_D_QA;

    if (!eq_A_B) {
        // B + D + respective extended shapes
        // Implementation 1: Lenient for one side if other has clear shape
        // Implementation 2: Flat outer edge, inner edge can be tower (not wall) for "厂" shape
        if ( (B_slope||B_tower) && (eq_D_QG&&!eq_D_G||D_tower) ) return Xoff;
        if ( (D_slope||D_tower) && (eq_B_PC&&!eq_B_C||B_tower) ) return Xoff;

        // High priority A-side triple consecutive pixels (eq_A_P && eq_A_Q)
        if (comboA3) return Xoff;

        // 2x2 combo as supplement
        if ( B_slope && eq_A_P ) return mixok ? Mix382off : Xoff;
        if ( D_slope && eq_A_Q ) return mixok ? Mix382off : Xoff;
    }

    eq_E_F = eq(E, F);
	B_wall = eq_B_C && !eq_B_PC && !eq_B_P;

    // Long clear slope (not solid edge. Strong trend!)
    // Special condition for long slopes
	if ( B_wall && D_tower ) {
        if (eq_A_B ) return slopeBAD;
        if (eq_E_F ) return colX;  //wip: Test direct X no blend
        return mixok ? Mix382off : Xoff;
    }

    eq_E_H = eq(E, H);
	D_wall = eq_D_G && !eq_D_QG&& !eq_D_Q;

	if ( B_tower && D_wall ) {
        if (eq_A_B ) return slopeBAD;
        if (eq_E_H ) return colX;
        return mixok ? Mix382off : Xoff;
    }


    bool sim_X_E = sim3(colX,colE);
    bool eq_G_H = eq(G, H);
    bool eq_C_F = eq(C, F);
    bool eq_H_S = eq(H, S);
    bool eq_F_R = eq(F, R);

    En3 = eq_E_F&&eq_E_H;

    // 4-pixel rectangle inside wall (En3 && eq_E_I)
	if ( En4square ) {  // This square check must come after previous rule
		if (sim_X_E) return mixok ? Mix382off : Xoff;
        // Exit for solid L inner shape (fix font edge corners and non-round building corners - Mega Man 7)
        if ( (eq_B_C || eq_D_G) && eq_A_B ) return theEXIT;
        //if (eq_H_S && eq_F_R) return theEXIT; // Extended on both sides
        //  L inner (hollow corner) / high-contrast independent clear 4-pixel square / 6-pixel rectangle (check rectangle edges)
        if ( ( eq_B_C&&!eq_G_H || eq_D_G&&!eq_C_F || !eq_G_H&&!eq_C_F&&diffEB>0.5) && (eq_H_S == eq(I, SI) && eq_F_R == eq(I, RI)) ) return theEXIT;

        return mixok ? Mix382off : Xoff;
    }

    // Triangle inside wall
 	if ( En3 ) {
		if (sim_X_E) return mixok ? Mix382off : Xoff;
        if (eq_H_S && eq_F_R) return theEXIT; // Extended on both sides (building edges)
       // Inner curve
        if (eq_B_C || eq_D_G) return mixok ? Mix382off : Xoff;
		// Direct return for thick shapes (zigzag can flatten outer curve below)
        if (eq_A_B) return mixok ? Mix382off : Xoff;
        // Outer curve
        if (eq_B_P || eq_D_Q) return theEXIT;

        return mixok ? Mix382off : Xoff;
        // Final two rules based on experience: Connect inner L curves, not outer (Jimmy's eyebrows in Double Dragon)
	}

    // F - H
	// Principle: Connect inner L curves, not outer
	if ( eq(F,H) ) {
    	if (sim_X_E) return mixok ? Mix382off : Xoff;
        // Solid L inner shape - avoid single pixel squeezed by symmetric double enclosure
		if ( eq_B_C && eq_A_B && (eq_G_H||!eq_F_R) &&eq(F, I) ) return slopeBAD;
		if ( eq_D_G && eq_A_B && (eq_C_F||!eq_H_S) &&eq(F, I) ) return slopeBAD;

		//Inner curve
        if (eq_B_C && (eq_F_R||eq_G_H||eq(F, I))) return mixok ? Mix382off : Xoff;
        if (eq_D_G && (eq_C_F||eq_H_S||eq(F, I))) return mixok ? Mix382off : Xoff;
		// E-I F-H cross breaks trend
		if (eq_E_I) return slopeBAD;
        // Outer zigzag
		if (eq_B_P && eq_A_B) return mixok ? Mix382off : Xoff;
        if (eq_D_Q && eq_A_B) return mixok ? Mix382off : Xoff;
		// Outer curve - unless opposite side forms long L trend
		if (eq_B_P && (eq_C_F&&eq_H_S)) return mixok ? Mix382off : Xoff;
        if (eq_D_Q && (eq_F_R&&eq_G_H)) return mixok ? Mix382off : Xoff;

        return slopeBAD;
	}


	// Relaxed final cleanup for two long slopes (non-clear shapes)
    // Note: Differs from sim2 cleanup - exit for solid corners
	if ( eq_B_C && eq_D_Q || eq_D_G && eq_B_P) {
        // Clear eq_A_B first to avoid edge pixel excavation (Eternal Secret)
		if (eq_A_B) return theEXIT;
		return mixok ? Mix382off : Xoff;
	}


    //	A-side triple consecutive pixels - NEVER use without !eq_A_B !!!!!!!!!!!
    //  if (comboA3) return X+slopeOFF;


	// One more B + D bidirectional extension check (higher priority than L inner/outer bars)
        if ( (B_slope||B_tower) && (eq_D_QG&&!eq_D_G||D_tower) ) return Xoff;
        if ( (D_slope||D_tower) && (eq_B_PC&&!eq_B_C||B_tower) ) return Xoff;


    // Exit for clear L-turn with inner single bar (even sim_X_E can't override)
    if (eq_A_B && !ThickBorder && !eq_E_I ) {

	    if (B_wall && eq_E_F) return theEXIT;
	    if (D_wall && eq_E_H) return theEXIT;
	}

if (sim_X_E) return mixok ? Mix382off : Xoff;
    // Exit for hollow L-turn with outer single bar (connect inner corners only)
	// Implementation note: Prevents font edge erosion (Captain Commando)
	if ( (B_tower || D_tower) && (eq_E_F||eq_E_H) && !eq_A_B && !eq_E_I) return theEXIT;

    // Final B or D individual extension check

    // Maximum reachable distance for slopes
    if ( B_slope && !eq_A_B && eq(PC,CC) && noteq(PC,RC)) return mixok ? Mix382off : Xoff;
    if ( D_slope && !eq_A_B && eq(QG,GG) && noteq(QG,SG)) return mixok ? Mix382off : Xoff;

    // Fewer check points for slopes when X-E are close, with internal restrictions
  	if ( mixok && !eq_A_B ) {
        if ( B_slope && (!eq_C_F||eq(F,RC)) ) return Mix382off;
        if ( D_slope && (!eq_G_H||eq(H,SG)) ) return Mix382off;
    }

    // Pre-exclude single bars for zigzag below (necessary)
    if ((eq_E_F||eq_E_H) && !eq_E_I ) return theEXIT;

    // Zigzag shape (eq_A_B with thickness, one side tower (or wall/slope) but other side cannot be tower/wall (naturally prohibited))
    if ( eq_B_P && !eq_B_PA && !eq_D_Q && eq_A_B) return mixok ? Mix382off : Xoff;
    if ( eq_D_Q && !eq_D_QA && !eq_B_P && eq_A_B) return mixok ? Mix382off : Xoff;

	return theEXIT;

}	// admixX

vec3 admixS(uint A, uint B, uint C, uint D, uint E, uint F, uint G, uint H, uint I, uint R, uint RC, uint RI, uint S, uint SG, uint SI, uint II, bool eq_B_D, bool eq_E_D, float El, float Bl, vec3 colE, vec3 colF) {

			//                                    ＡＢＣ  .
			//                                  ＱＤ🄴 🅵 🆁       Zone 4
			//					                  🅶 🅷 Ｉ
			//					                  Ｓ
    // Implementation 1: sim E B(C) aligns with original logic - prevents jarring saw insertion for single-pixel E in practice
    // Implementation 2: Can E equal I? Yes!

    if (any_eq2(F,C,I)) return colE;
    //if (any_eq3(F,A,C,I)) return colE;

    if (eq(R, RI) && noteq(R,I)) return colE;
    if (eq(H, S) && noteq(H,I)) return colE;

    if ( eq(R, RC) || eq(G,SG) ) return colE;

    if ( ( eq_B_D&&eq(B,C)&&diffEB<0.381966 || eq_E_D&&sim2(colE,E,C) ) &&
    (any_eq3(I,H,S,RI) || eq(SI,RI)&&noteq(I,II)) ) return colF;

    return colE;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////// zz

void main()
{
#define srcf(c,d) texture(Source, vTexCoord + vec2(c,d) * params.SourceSize.zw).rgb
#define src(c,d) packUnorm4x8(vec4(srcf(c,d), 1.0))
#define finalExit FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);return
    vec3 colE = srcf(0, 0);
    vec3 colB = srcf(+0, -1);
    vec3 colD = srcf(-1, +0);
    vec3 colF = srcf(+1, +0);
    vec3 colH = srcf(+0, +1);

    // Preset for quick return
    FragColor = vec4(colE, 1.0);

    uint E = packUnorm4x8(vec4(colE, 1.0));
    uint B = packUnorm4x8(vec4(colB, 1.0));
    uint D = packUnorm4x8(vec4(colD, 1.0));
    uint F = packUnorm4x8(vec4(colF, 1.0));
    uint H = packUnorm4x8(vec4(colH, 1.0));


    bool eq_E_D = eq(E,D);
    bool eq_E_F = eq(E,F);
    bool eq_E_B = eq(E,B);
    bool eq_E_H = eq(E,H);


// Skip horizontal/vertical 3x1
if (eq_E_D && eq_E_F) return;
if (eq_E_B && eq_E_H) return;

    bool eq_B_H = eq(B,H);
    bool eq_D_F = eq(D,F);
// Skip mirror blocks surrounding center
if ( eq_B_H && eq_D_F ) return;


    //Capture 5x5 area
    uint A = src(-1, -1);
    uint C = src(+1, -1);
    uint G = src(-1, +1);
    uint I = src(+1, +1);

    uint P  = src(+0, -2);
    uint Q  = src(-2, +0);
    uint R  = src(+2, +0);
    uint S  = src(+0, +2);

    uint PA = src(-1, -2);
    uint PC = src(+1, -2);
    uint QA = src(-2, -1);
    uint QG = src(-2, +1); //             AA    PA    [P]   PC    CC
    uint RC = src(+2, -1); //                ┌──┬──┬──┐
    uint RI = src(+2, +1); //             QA │  A │  B │ C  │ RC
    uint SG = src(-1, +2); //                ├──┼──┼──┤
    uint SI = src(+1, +2); //            [Q] │  D │  E │ F  │ [R]
    uint AA = src(-2, -2); //                ├──┼──┼──┤
    uint CC = src(+2, -2); //             QG │  G │  H │ I  │ RI
    uint GG = src(-2, +2); //                └──┴──┴──┘
    uint II = src(+2, +2); //             GG    SG    [S]   SI    II

    // Default to nearest-neighbor scaling
    vec3 J = colE;    vec3 K = colE;    vec3 L = colE;    vec3 M = colE;

    // ------------------------ Boundary Detection --------------------------
    // Define impossible fake pixel
    #define fakeColor vec3(1.234)
    // 1. Precompute integer coordinates of current pixel (uv → pixel coords, floor for index)
    vec2 pixelPos = vTexCoord * params.SourceSize.xy;
    ivec2 currPixel = ivec2(floor(pixelPos)); // Integer coords of current pixel (0-based)
    ivec2 texSize = ivec2(params.SourceSize.xy); // Actual texture pixel dimensions

    // 3. Check out-of-bounds in four directions, set alpha to transparent (integer check, no float error)
    if (currPixel.y - 1 < 0) colB = fakeColor;          // Out-of-bounds above (y-1 < 0)
    if (currPixel.x - 1 < 0) colD = fakeColor;          // Out-of-bounds left (x-1 < 0)
    if (currPixel.x + 1 >= texSize.x) colF = fakeColor; // Out-of-bounds right (x+1 >= width)
    if (currPixel.y + 1 >= texSize.y) colH = fakeColor; // Out-of-bounds below (y+1 >= height)
    // ----------------------------------------------------------------------

// Precompute luminance
   float Bl = luma(colB);
   float Dl = luma(colD);
   float El = luma(colE);
   float Fl = luma(colF);
   float Hl = luma(colH);


// 1:1 slope rules (P95)
    bool eq_B_D = eq(B,D);
    bool eq_B_F = eq(B,F);
    bool eq_D_H = eq(D,H);
    bool eq_F_H = eq(F,H);

    // Any mirror blocks surrounding center
    bool oppoPix =  eq_B_H || eq_D_F;
	// Flag for admixX entry via 1:1 slope rules
    bool slope1 = false;    bool slope2 = false;    bool slope3 = false;    bool slope4 = false;
	// Valid pixel returned via 1:1 slope rules
    bool slope1ok = false;  bool slope2ok = false;  bool slope3ok = false;  bool slope4ok = false;
	// slopeBAD: Entered admixX but returned E for (at least one of) JKLM
    // slopOFF: Returned with OFF flag - no long slope calculation

    // B - D
	if ( (!eq_E_B&&!eq_E_D&&!oppoPix) && (!eq_D_H&&!eq_B_F) && (El>=Dl&&El>=Bl || eq(E,A)) && ( (El<Dl&&El<Bl) || none_eq2(A,B,D) || noteq(E,P) || noteq(E,Q) ) && ( eq_B_D&&(eq_F_H||eq(E,A)||eq(B,PC)||eq(D,QG)) || sim1(colB,colD)&&(sim2(colE,E,C)||sim2(colE,E,G)) ) ) {
		J=admixX(A,B,C,D,E,F,G,H,I,P,PA,PC,Q,QA,QG,R,RC,RI,S,SG,SI,AA,CC,GG, El,Bl,Dl,Fl,Hl,colE,colB,colD);
		slope1 = true;
		if (J.b > 1.0 ) {
            if (J.b > 7.0 ) J=J-8.0; 	//slopOFF
			if (J.b == 4.0 ) return;
			if (J.b == 2.0 ) J=colE;		//slopeBAD
		} else slope1ok = true;
	}
    // B - F
	if ( !slope1 && (!eq_E_B&&!eq_E_F&&!oppoPix) && (!eq_B_D&&!eq_F_H) && (El>=Bl&&El>=Fl || eq(E,C)) && ( (El<Bl&&El<Fl) || none_eq2(C,B,F) || noteq(E,P) || noteq(E,R) ) && ( eq_B_F&&(eq_D_H||eq(E,C)||eq(B,PA)||eq(F,RI)) || sim1(colB,colF)&&(sim2(colE,E,A)||sim2(colE,E,I)) ) )  {
		K=admixX(C,F,I,B,E,H,A,D,G,R,RC,RI,P,PC,PA,S,SI,SG,Q,QA,QG,CC,II,AA, El,Fl,Bl,Hl,Dl,colE,colF,colB);
		slope2 = true;
		if (K.b > 1.0 ) {
            if (K.b > 7.0 ) K=K-8.0;
			if (K.b == 4.0 ) return;
			if (K.b == 2.0 ) K=colE;
		} else {slope2ok = true;}
	}
    // D - H
	if ( !slope1 && (!eq_E_D&&!eq_E_H&&!oppoPix) && (!eq_F_H&&!eq_B_D) && (El>=Hl&&El>=Dl || eq(E,G))  &&  ((El<Hl&&El<Dl) || none_eq2(G,D,H) || noteq(E,S) || noteq(E,Q))  &&  ( eq_D_H&&(eq_B_F||eq(E,G)||eq(D,QA)||eq(H,SI)) || sim1(colD,colH) && (sim2(colE,E,A)||sim2(colE,E,I)) ) )  {
		L=admixX(G,D,A,H,E,B,I,F,C,Q,QG,QA,S,SG,SI,P,PA,PC,R,RI,RC,GG,AA,II, El,Dl,Hl,Bl,Fl,colE,colD,colH);
		slope3 = true;
		if (L.b > 1.0 ) {
            if (L.b > 7.0 ) L=L-8.0;
			if (L.b == 4.0 ) return;
			if (L.b == 2.0 ) L=colE;
		} else {slope3ok = true;}
	}
    // F - H
	if ( !slope2 && !slope3 && (!eq_E_F&&!eq_E_H&&!oppoPix) && (!eq_B_F&&!eq_D_H) && (El>=Fl&&El>=Hl || eq(E,I))  &&  ((El<Fl&&El<Hl) || none_eq2(I,F,H) || noteq(E,R) || noteq(E,S))  &&  ( eq_F_H&&(eq_B_D||eq(E,I)||eq(F,RC)||eq(H,SG)) || sim1(colF,colH) && (sim2(colE,E,C)||sim2(colE,E,G)) ) )  {
		M=admixX(I,H,G,F,E,D,C,B,A,S,SI,SG,R,RI,RC,Q,QG,QA,P,PC,PA,II,GG,CC, El,Hl,Fl,Dl,Bl,colE,colH,colF);
		slope4 = true;
		if (M.b > 1.0 ) {
            if (M.b > 7.0 ) M=M-8.0;
			if (M.b == 4.0 ) return;
			if (M.b == 2.0 ) M=colE;
		} else {slope4ok = true;}
	}


//  long gentle 2:1 slope  (P100)

	bool longslope = false;

    if (slope4ok && eq_F_H) { //zone4 long slope
        // Enhanced legacy rule 1: Pass adjacent pixel to admixL third param to prevent double blending
        // Enhanced legacy rule 2: No L-shape in opposite pixel interval unless wall formed
        if (eq(G,H) && eq(F,R) && noteq(R, RC) && (noteq(Q,G)||eq(Q, QA))) {L=admixL(M,L,colH); longslope = true;}
        // vertical
		if (eq(C,F) && eq(H,S) && noteq(S, SG) && (noteq(P,C)||eq(P, PA))) {K=admixL(M,K,colF); longslope = true;}
    }


    if (slope3ok && eq_D_H) { //zone3 long slope
        // horizontal
        if (eq(D,Q) && eq(H,I) && noteq(Q, QA) && (noteq(R,I)||eq(R, RC))) {M=admixL(L,M,colH); longslope = true;}
        // vertical
		if (eq(A,D) && eq(H,S) && noteq(S, SI) && (noteq(A,P)||eq(P, PC))) {J=admixL(L,J,colD); longslope = true;}
    }

    if (slope2ok && eq_B_F) { //zone2 long slope
        // horizontal
        if (eq(A,B) && eq(F,R) && noteq(R, RI) && (noteq(A,Q)||eq(Q, QG))) {J=admixL(K,J,colB); longslope = true;}
        // vertical
		if (eq(F,I) && eq(B,P) && noteq(P, PA) && (noteq(I,S)||eq(S, SG))) {M=admixL(K,M,colF); longslope = true;}
    }

    if (slope1ok && eq_B_D) { //zone1 long slope
        // horizontal
        if (eq(B,C) && eq(D,Q) && noteq(Q, QG) && (noteq(C,R)||eq(R, RI))) {K=admixL(J,K,colB); longslope = true;}
        // vertical
		if (eq(D,G) && eq(B,P) && noteq(P, PC) && (noteq(G,S)||eq(S, SI))) {L=admixL(J,L,colD); longslope = true;}
    }

// Exit if longslope formed (rare diagonal sawslope)
bool skiprest = longslope;

bool slopeok = slope1ok||slope2ok||slope3ok||slope4ok;


// Note: sawslope cannot exclude slopeOFF (few) and slopeBAD (very rare), but can exclude slopeok (strong shapes)
if (!skiprest && !oppoPix && !slopeok) {


        // horizontal bottom
		if (!eq_E_H && none_eq2(H,A,C)) {

			//                                    A B Ｃ ・
			//                                  Q D 🄴 🅵 🆁       Zone 4
			//					                  🅶 🅷 I
			//					                  Ｓ
			// (!slope3 && !eq_D_H) good combination
			if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H)  && !eq_F_H &&
                !eq_E_F && (eq_B_D || eq_E_D) && eq(R,H) && eq(F,G) ) {
                M = admixS(A,B,C,D,E,F,G,H,I,R,RC,RI,S,SG,SI,II,eq_B_D,eq_E_D,El,Bl,colE,colF);
                skiprest = true;}

			//                                  ・  A Ｂ C
			//                                  🆀 🅳 🄴 Ｆ R       Zone 3
			//                                     G 🅷 🅸
			//					                   Ｓ
			if ( !skiprest && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_D_H &&
                 !eq_E_D && (eq_B_F || eq_E_F) && eq(Q,H) && eq(D,I) ) {
                L = admixS(C,B,A,F,E,D,I,H,G,Q,QA,QG,S,SI,SG,GG,eq_B_F,eq_E_F,El,Bl,colE,colD);
                skiprest = true;}
		}

        // horizontal up
		if ( !skiprest && !eq_E_B && none_eq2(B,G,I)) {

			//					                   Ｐ
			//                                    🅐 🅑 Ｃ
			//                                  ＱＤ 🄴 🅵 🆁       Zone 2
			//                                    Ｇ H  I  .
			if ( (!slope1 && !eq_B_D)  && (!slope4 && !eq_F_H) && !eq_B_F &&
				  !eq_E_F && (eq_D_H || eq_E_D) && eq(B,R) && eq(A,F) ) {
                K = admixS(G,H,I,D,E,F,A,B,C,R,RI,RC,P,PA,PC,CC,eq_D_H,eq_E_D,El,Hl,colE,colF);
                skiprest = true;}

			//					                  Ｐ
			//                                    A 🅑 🅲
			//                                 🆀 🅳 🄴 Ｆ R        Zone 1
			//                                  . G Ｈ I
			if ( !skiprest && (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && !eq_B_D &&
				 !eq_E_D && (eq_F_H || eq_E_F) && eq(B,Q) && eq(C,D) ) {
                J = admixS(I,H,G,F,E,D,C,B,A,Q,QG,QA,P,PC,PA,AA,eq_F_H,eq_E_F,El,Hl,colE,colD);
                skiprest = true;}

		}

        // vertical left
        if ( !skiprest && !eq_E_D && none_eq2(D,C,I) ) {

			//                                    🅐 B Ｃ
			//                                  Q 🅳 🄴 Ｆ R
			//                                    Ｇ 🅷 I        Zone 3
			//                                       🆂 ・
            if ( (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_D_H &&
				  !eq_E_H && (eq_B_F || eq_E_B) && eq(D,S) && eq(A,H) ) {
                L = admixS(C,F,I,B,E,H,A,D,G,S,SI,SG,Q,QA,QG,GG,eq_B_F,eq_E_B,El,Fl,colE,colH);
                skiprest = true;}

			//                                      🅟 ・
			//                                    A 🅑 C
			//                                  Q 🅳 🄴 F R       Zone 1
			//                                    🅶 ＨＩ
			if ( !skiprest && (!slope3 && !eq_D_H) && (!slope2 && !eq_B_F) && !eq_B_D &&
				  !eq_E_B && (eq_F_H || eq_E_H) && eq(P,D) && eq(B,G) ) {
                J = admixS(I,F,C,H,E,B,G,D,A,P,PC,PA,Q,QG,QA,AA,eq_F_H,eq_E_H,El,Fl,colE,colB);
                skiprest = true;}

		}

        // vertical right
		if ( !skiprest && !eq_E_F && none_eq2(F,A,G) ) { // right

			//                                    A B 🅲
			//                                  Q D 🄴 🅵 R
			//                                    G 🅷 I        Zone 4
			//                                    . 🆂
			if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && !eq_F_H &&
				  !eq_E_H && (eq_B_D || eq_E_B) && eq(S,F) && eq(H,C) ) {
                M = admixS(A,D,G,B,E,H,C,F,I,S,SG,SI,R,RC,RI,II,eq_B_D,eq_E_B,El,Dl,colE,colH);
                skiprest = true;}

			//                                    ・ 🅟
			//                                    A 🅑 C
			//                                  Q D 🄴 🅵 R        Zone 2
			//                                    G H 🅸
			if ( !skiprest && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_B_F &&
				 !eq_E_B && (eq_D_H || eq_E_H) && eq(P,F) && eq(B,I) ) {
                K = admixS(G,D,A,H,E,B,I,F,C,P,PA,PC,R,RI,RC,CC,eq_D_H,eq_E_H,El,Dl,colE,colB);
                skiprest = true;}

		} // vertical right
} // sawslope

// Exit if sawslope formed. Legacy: skiprest||slopeBAD (also uses slopeOFF (weak) and slopok (strong) - poor effect)
skiprest = skiprest||slope1||slope2||slope3||slope4;

/**************************************************
       "Concave + Cross" shape	（P100）	   
 *************************************************/
//  Use approximate pixels for cross far ends - useful for line+zigzag and layered gradient shapes (e.g. glowing text in SFIII:N2 intro, Japanese houses in SFZ3 Mix, Fatal Fury: Wild Ambition intro)

	vec3 colX;		//Define temp X

    if (!skiprest &&
        Bl<El && !eq_E_D && !eq_E_F && eq_E_H && none_eq2(E,A,C) && all_eq2(G,H,I) && sim2(colE,E,S) ) { // TOP

        if (eq_B_D||eq_B_F) { J=admixK(colB,J);    K=J;
            if (eq_D_F) { L=mix(J,L, 0.61804);   M=L; }
        } else { colX = El-Bl < abs(El-Dl) ? colB : colD;  J=admixC(colX,J);
			if (eq_D_F) { K=J;  L=mix(J,L, 0.61804);    M=L; }
			else {colX = El-Bl < abs(El-Fl) ? colB : colF; 		K=admixC(colX,K); }
            }

	   skiprest = true;
	}

    if (!skiprest &&
		Hl<El && !eq_E_D && !eq_E_F && eq_E_B && none_eq2(E,G,I) && all_eq2(A,B,C) && sim2(colE,E,P) ) { // BOTTOM

        if (eq_D_H||eq_F_H) { L=admixK(colH,L);    M=L;
            if (eq_D_F) { J=mix(L,J, 0.61804);   K=J; }
        } else { colX = El-Hl < abs(El-Dl) ? colH : colD;  L=admixC(colX,L);
			if (eq_D_F) { M=L;  J=mix(L,J, 0.61804);    K=J; }
			else { colX = El-Hl < abs(El-Fl) ? colH : colF;    M=admixC(colX,M); }
            }

	   skiprest = true;
	}

   if (!skiprest &&
		Fl<El && !eq_E_B && !eq_E_H && eq_E_D && none_eq2(E,C,I) && all_eq2(A,D,G) && sim2(colE,E,Q) ) { // RIGHT

        if (eq_B_F||eq_F_H) { K=admixK(colF,K);    M=K;
            if (eq_B_H) { J=mix(K,J, 0.61804);   L=J; }
        } else { colX = El-Fl < abs(El-Bl) ? colF : colB;  K=admixC(colX,K);
			if (eq_B_H) { M=K;  J=mix(K,J, 0.61804);    L=J; }
			else { colX = El-Fl < abs(El-Hl) ? colF : colH;    M=admixC(colX,M); }
            }

	   skiprest = true;
	}

    if (!skiprest &&
		Dl<El && !eq_E_B && !eq_E_H && eq_E_F && none_eq2(E,A,G) && all_eq2(C,F,I) && sim2(colE,E,R) ) { // LEFT

        if (eq_B_D||eq_D_H) { J=admixK(colD,J);    L=J;
            if (eq_B_H) { K=mix(J,K, 0.61804);   M=K; }
        } else { colX = El-Dl < abs(El-Bl) ? colD : colB;  J=admixC(colX,J);
			if (eq_B_H) { L=J;   K=mix(J,K, 0.61804);    M=K; }
			else { colX = El-Dl < abs(El-Hl) ? colD : colH;    L=admixC(colX,L); }
            }

	   skiprest = true;
	}

/*
	   ✕О
     ООО✕
	   ✕О    Scorpion shape (P99). Resembles Sentinel bug from The Matrix. Flattens regular staggered pixels.
*/
// Implementation notes: 1. Approximate scorpion pincers? Prone to artifacts
// Implementation notes: 2. Remove one segment from scorpion tail to capture more shapes
// Scorpion is exclusive - won't trigger if previous rules matched

   if (!skiprest && !eq_E_F &&eq_E_D&&eq_B_F&&eq_F_H && all_eq2(E,C,I) && noteq(F,src(+3, 0)) ) {K=admixK(colF,K); M=K;J=mix(K,J, 0.61804); L=J;skiprest=true;}	// RIGHT
   if (!skiprest && !eq_E_D &&eq_E_F&&eq_B_D&&eq_D_H && all_eq2(E,A,G) && noteq(D,src(-3, 0)) ) {J=admixK(colD,J); L=J;K=mix(J,K, 0.61804); M=K;skiprest=true;}	// LEFT
   if (!skiprest && !eq_E_H &&eq_E_B&&eq_D_H&&eq_F_H && all_eq2(E,G,I) && noteq(H,src(0, +3)) ) {L=admixK(colH,L); M=L;J=mix(L,J, 0.61804); K=J;skiprest=true;}	// BOTTOM
   if (!skiprest && !eq_E_B &&eq_E_H&&eq_B_D&&eq_B_F && all_eq2(E,A,C) && noteq(B,src(0, -3)) ) {J=admixK(colB,J); K=J;L=mix(J,L, 0.61804); M=L;}				// TOP

	// final Exit
	vec2 a = fract(pixelPos);
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
}
