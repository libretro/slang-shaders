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

 // (Switched to CRT-era BT.601 standard) Only affects luma decision mechanism
float luma(vec3 col){
   return dot(col, vec3(0.299, 0.587, 0.114));
   //return dot(col, vec3(0.3333333)); // rgb average
}


bool checkblack(vec3 col) {
  if (col.r > 0.1 || col.g > 0.078 || col.b > 0.1) return false;

    return true;
}

//bool checkwhite(vec3 col) {
// if (col.r < 0.9 || col.g < 0.92 || col.b < 0.9) return false;

//    return true;
//}

// pin zz
bool sim(vec3 col1, vec3 col2, int Lv) {

    vec3 diff = abs(col1 - col2);

    // 1. Fast component difference check
    float chDiff = Lv==1 ? 0.09652388 : Lv==2 ? 0.145898 : 0.2527;
    if ( diff.r > chDiff || diff.g > chDiff || diff.b > chDiff ) return false;

    // 2.Quickly filter out identical pixels and very dark/bright pixels after clamping
    vec3 clampCol1 = clamp(col1, vec3(0.078),vec3(0.92));
    vec3 clampCol2 = clamp(col2, vec3(0.078),vec3(0.92));
    vec3 clampdiff = clampCol1 - clampCol2;
    vec3 absclampdiff = abs(clampdiff);
    if ( absclampdiff.r < 0.05572809 && absclampdiff.g < 0.021286 && absclampdiff.b < 0.05572809 ) return true;

    //dotdist = 0.00931686;            // 3rd short golden ratio of Euclidean distance
	//dotdist = 0.024391856;	// 2nd short golden ratio + 1st golden ratio of Euclidean distance
	//dotdist = 0.0638587;		// 2nd short golden ratio of Euclidean distance
    float dotdist = Lv==1 ? 0.00931686 : Lv==2 ? 0.024391856 : 0.0638587;

    // 3. Fast squared distance check
	float dot_diff = dot(diff, diff);
    if (dot_diff > dotdist) return false;

	// 4. Re-check by adding squared opposite channels
	float teamA = 0.0;
	float teamB = 0.0;

	if (clampdiff.r > 0.0) teamA += absclampdiff.r; else teamB += absclampdiff.r;
	if (clampdiff.g > 0.0) teamA += absclampdiff.g; else teamB += absclampdiff.g;
	if (clampdiff.b > 0.0) teamA += absclampdiff.b; else teamB += absclampdiff.b;
	float team = min(teamA,teamB);
	// Empirical: requires at least 3x the squared opposite channel value. (+1x ties, +2x starts increasing trend)
	if (dot_diff + team*team*3.0 > dotdist) return false;

	// 5. Check for gray pixels
    float sum1 = col1.r + col1.g + col1.b;
	float avg1 = sum1 * 0.3333333;
    float threshold1 = avg1 * 0.08;

    float sum2 = col2.r + col2.g + col2.b;
	float avg2 = sum2 * 0.3333333;
    float threshold2 = avg2 * 0.08;

    bool Col1isGray = all(lessThan(abs(col1 - vec3(avg1)), vec3(threshold1)));
	bool Col2isGray = all(lessThan(abs(col2 - vec3(avg2)), vec3(threshold2)));

	// Return true if both are gray or both are not gray
	return Col1isGray == Col2isGray;
}

bool sim1(vec3 col1, vec3 col2) {
    return sim(col1, col2, 1);
}
bool sim2(vec3 col1, vec3 col2) {
    return sim(col1, col2, 2);
}
bool sim3(vec3 col1, vec3 col2) {
    return sim(col1, col2, 3);
}

bool mixcheck(vec3 col1, vec3 col2) {

    vec3 diff = col1 - col2;
    vec3 absdiff = abs(diff);

    // 1. Fast component difference check
    if ( absdiff.r > 0.618034 || absdiff.g > 0.618034 || absdiff.b > 0.618034 ) return false;
    // Quickly filter out similar pixels (0.4377 divided by 6, sqrt max can be 0.27)
    if ( absdiff.r < 0.27 && absdiff.g < 0.27 && absdiff.b < 0.27 ) return true;

    // 3. Fast squared distance check
	float dot_diff = dot(diff, diff);
    if (dot_diff > 0.4377) return false;

	// 4. Re-check by adding squared opposite channels
	float teamA = 0.0;
	float teamB = 0.0;

	if (diff.r > 0.0) teamA += absdiff.r; else teamB += absdiff.r;
	if (diff.g > 0.0) teamA += absdiff.g; else teamB += absdiff.g;
	if (diff.b > 0.0) teamA += absdiff.b; else teamB += absdiff.b;
	float team = min(teamA,teamB);
	// Empirical: requires at least 3x the squared opposite channel value. (+1x ties, +2x starts increasing trend)
	if (dot_diff + team*team*3.0 > 0.4377) return false;

    return true;
}

bool eq(vec3 col1, vec3 col2) {
    vec3 diff = abs(col1 - col2);

    if (diff.r > 0.004 || diff.g > 0.004 || diff.b > 0.004) return false;

    return true;
}

bool noteq(vec3 col1, vec3 col2) {
    vec3 diff = abs(col1 - col2);

    if (diff.r > 0.004 || diff.g > 0.004 || diff.b > 0.004) return true;

    return false;
}

bool all_eq2(vec3 B, vec3 A0, vec3 A1) {
    return (eq(B,A0) && eq(B,A1));
}

bool any_eq2(vec3 B, vec3 A0, vec3 A1) {
    return (eq(B,A0) || eq(B,A1));
}

bool any_eq3(vec3 B, vec3 A0, vec3 A1, vec3 A2) {
    return (eq(B,A0) || eq(B,A1)|| eq(B,A2));
}

bool none_eq2(vec3 B, vec3 A0, vec3 A1) {
   return (noteq(B,A0) && noteq(B,A1));
}

#define src(c,d) texture(Source, vTexCoord + vec2(c,d) * params.SourceSize.zw).rgb


///////////////////////     Test Colors     ///////////////////////
//const vec3 testcolor = vec3(1.0, 0.0, 1.0);  // Magenta
//const vec3 testcolor2 = vec3(0.0, 1.0, 1.0);  // Cyan
//const vec3 testcolor3 = vec3(1.0, 1.0, 0.0);  // Yellow
//const vec3 testcolor4 = vec3(1.0, 1.0, 1.0);  // White


// pin zz   "Concave + Cross" shape Weak Mixing (Weak Mix/None)
vec3 admixC(vec3 X, vec3 E) {

	bool mixok = mixcheck(X, E);

	return mixok ? mix(X, E, 0.618034) : E;

}

// K shape Forced Weak Mixing (Weak Mix/Weaker)
vec3 admixK(vec3 X, vec3 E) {

	bool mixok = mixcheck(X, E);

	return mixok ? mix(X, E, 0.618034) : mix(X, E, 0.8541);

}

// L shape 2:1 slope Main corner extension
// Practice: This rule requires all 4 pixels on the strict slope to be identical. Otherwise, various glitches occur!
vec3 admixL(vec3 X, vec3 E, vec3 S) {

    //if (eq(X, E)) return E; // Originally this would catch many duplicate pixels, but filtered by slopebad, now invalid.

	// If target X and reference S(sample) are different, it means mixing has already occurred once, just copy target.
	if (noteq(X, S)) return X;

	bool mixok = mixcheck(X, E);

    return mixok ? mix(X, E, 0.381966) : X;
}

/********************************************************************************************************************************************
 *               												main slope + X cross-processing mechanism					                *
 ************************************************************************************************************************************** zz  */
vec3 admixX(vec3 A, vec3 B, vec3 C, vec3 D, vec3 E, vec3 F, vec3 G, vec3 H, vec3 I, vec3 P, vec3 PA, vec3 PC, vec3 Q, vec3 QA, vec3 QG, vec3 R, vec3 RC, vec3 RI, vec3 S, vec3 SG, vec3 SI, vec3 AA, vec3 CC, vec3 GG, float El, float Bl, float Dl, float Fl, float Hl) {

    // Pre-define 3 types of special exits
    const vec3 slopeBAD = vec3(2.0);
    const vec3 theEXIT = vec3(8.0);
    const vec3 slopEND = vec3(33.0);

	//pre-cal
	bool eq_B_D = eq(B, D);
	bool eq_B_C = eq(B, C);
	bool eq_D_G = eq(D, G);

    vec3 X;

	if (eq_B_D) {
        // Bilateral straight wall pincer, exit
        if (eq_B_C && eq_D_G) return slopeBAD;
        X = B;
    } else {
        // E-A equality does not conform to preset logic, exit
        if (eq(E,A)) return slopeBAD;

        // B D unequal, and their difference is larger than either's difference with center E, exit.
        float diffBD = abs(Bl-Dl);
        float diffEB = abs(El-Bl);
        float diffED = abs(El-Dl);
        if (diffBD > diffEB || diffBD > diffED) return slopeBAD;

        X = mix(B,D,0.5);
    }

	// Avoid single-pixel font edges being squeezed by black background on both sides (font/background luma diff usually >0.5)
	// Note: If BD unequal, cannot use average to judge, both must satisfy black condition.
	bool Xisblack = eq_B_D ? checkblack(B) : checkblack(B)&&checkblack(D);
	if ( Xisblack && El >0.5 ) {
        // Use Fl Hl to save cost
		if ( Fl<0.078 || Hl<0.078 ) return theEXIT;
	}

	//Pre-declare
	bool eq_A_B;	bool eq_A_D;	bool eq_A_P;	bool eq_A_Q;
	bool eq_B_P;    bool eq_B_PA;   bool eq_B_PC;
	bool eq_D_Q;    bool eq_D_QA;   bool eq_D_QG;
    bool eq_E_F;    bool eq_E_H;    bool eq_E_I;    bool En3;	bool En4square;
	bool B_slope;	bool B_tower;	bool B_wall;
    bool D_slope;	bool D_tower;	bool D_wall;
    bool comboA3;	bool mixok;

// B != D
if (!eq_B_D){

	eq_A_B = eq(A,B);
	eq_A_D = eq(A,D);

	// B D unequal (non-black), one side straight line, the other must be single pixel.
	// Practice: Avoids mixing at parallel line corners where BD are each continuous.
    if (!Xisblack){
        if ( eq_A_B && (eq_D_G||eq(D,Q)) ) return slopeBAD;
        if ( eq_A_D && (eq_B_C||eq(B,P)) ) return slopeBAD;
    }


    // B D three-no-stick? Not applicable here (Can eliminate some artifacts, but also lose some shapes, especially non-native pixel art, e.g., Double Dragon intro character portrait)

	// Treat near-black like DB?
    // Practice: Special treatment for non-black in dark areas easily causes glitches (Samurai Shodown 2 Charlotte)
	//if (Xisblack) return X +slopEND;

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
	comboA3 = eq_A_P && eq_A_Q;
	mixok = mixcheck(X,E);

	// A-side three-star alignment, high priority
    if (comboA3) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    // Official original rule
    if ( eq(E,C) || eq(E,G) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Enhanced original rule Practice: Beneficial for non-native pixel art, harmful for native (JoJo's wall and clock)
    // if (sim_EC && sim_EG) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    En3 = eq_E_F && eq_E_H;

    if (En3) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Exclude "single stick" cases, including eq_E_I bent stick
    if ( eq_E_F || eq_E_H ) return slopeBAD;
    // Exclude "three-cell unilateral wall" cases
    if ( eq_A_B&&eq_B_C || eq_A_D&&eq_D_G ) return slopeBAD;
    // F-H inline trend, placed after three-cell wall rule as it might be blocked
    if ( eq(F,H) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Exclude "two-cell unilateral wall" cases, merged with next rule
    //if (eq_A_B||eq_A_D) return slopeBAD;
    // Remaining are single pixels with no logic but approximate within sim2 range, so use weak mixing??? Just give up!
    return slopeBAD;
} // B != D

	//pre-cal B == D
    bool eq_E_A = eq(E,A);
    bool eq_E_C = eq(E,C);
    bool eq_E_G = eq(E,G);
	bool sim_EC = eq_E_C || sim2(E,C);
	bool sim_EG = eq_E_G || sim2(E,G);

	bool ThickBorder;

// Original main rule enhanced with sim
if ( (sim_EC || sim_EG) && !eq_E_A ){

/* Approach:
    1. Handle continuous border shapes without mixing
    2. Special handling for long slopes
    3. Original rules
    4. Handle E-zone inlines like En4 En3 F-H, remaining single stick and single pixel
    5. Handle L-inward stick and L-outward stick
    5. Normal fallback
*/

	eq_A_B = eq(A,B);
	eq_B_P = eq(B,P);
    eq_B_PC = eq(B,PC);
	eq_D_Q = eq(D,Q);
    eq_D_QG = eq(D,QG);
    eq_B_PA = eq(B,PA);
    eq_D_QA = eq(D,QA);
	B_slope = eq_B_PC && !eq_B_P && !eq_B_C;
	B_tower = eq_B_P && !eq_B_PC && !eq_B_C && !eq_B_PA;
	D_slope = eq_D_QG && !eq_D_Q && !eq_D_G;
	D_tower = eq_D_Q && !eq_D_QG && !eq_D_G && !eq_D_QA;

    // step1:
    // B + D + respective continuation shapes
    // Note: Only for X no-mix judgment, different from the "rule capture return" logic in the final section.

    if ( (B_slope||B_tower) && (D_slope||D_tower) && !eq_A_B) return X +slopEND;


	eq_A_P = eq(A, P);
	eq_A_Q = eq(A, Q);
	comboA3 = eq_A_P && eq_A_Q;
	mixok = mixcheck(X,E);
    ThickBorder = eq_A_B && (eq_A_P||eq_A_Q|| eq(A,AA)&&(eq_B_PA||eq_D_QA));
	if (ThickBorder && !Xisblack) mixok=false;

    // A-side three-star alignment
    if (comboA3) {
        if (!eq_A_B) return X + slopEND;
        else mixok=false;
    }

    // XE_messL B-D-E L shape sim2 highly similar   WIP
    // bool XE_messL = (eq_B_C && !sim_EG || eq_D_G && !sim_EC) ;

    eq_E_F = eq(E, F);
	B_wall = eq_B_C && !eq_B_PC && !eq_B_P;

    // long slope Clear long slope (Not thick solid edge. Strong trend!)
    // Long slope case is slightly special, separate condition check
	if ( B_wall && D_tower ) {
        if (eq_E_G || sim_EG&&eq(E,QG) ) {   // Original rule + original enhancement
            if (eq_A_B) return mixok ? mix(X,E,0.381966): X;    // Has thickness
            return X;                                           // Hollow
        }
        // Clear Z-shape snake, exclude XE_messL ???
        //if (eq_A_B  && !XE_messL) return slopeBAD;                    // WIP
        if (eq_A_B) return slopeBAD;
        //  2-cell with subsequent long slope
        if (eq_E_F ) return X;
        //  1-cell without subsequent long slope
        return X +slopEND;
    }

    eq_E_H = eq(E, H);
	D_wall = eq_D_G && !eq_D_QG&& !eq_D_Q;

	if ( B_tower && D_wall ) {
        if (eq_E_C || sim_EC&&eq(E,PC) ) {   // Original rule + original enhancement
            if (eq_A_B) return mixok ? mix(X,E,0.381966): X;    // Has thickness
            return X;                                           // Hollow
        }
        // Clear Z-shape snake, exclude XE_messL ???
        //if (eq_A_B  && !XE_messL) return slopeBAD;                    // WIP
        if (eq_A_B) return slopeBAD;
        //  2-cell with subsequent long slope
        if (eq_E_H ) return X;
        //  1-cell without subsequent long slope
        return X +slopEND;
    }


    // Official original rule (After the above special shapes, special shapes have specified no-mix!)
    if (eq_E_C || eq_E_G) return mixok ? mix(X,E,0.381966) : X;

    // Original rule Enhancement 1
    if (sim_EG&&!eq_D_G&&eq(E,QG) || sim_EC&&!eq_B_C&&eq(E,PC)) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

    // Original rule Enhancement 2
    if (sim_EC && sim_EG) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;


    // F-H inline trend (Skip En4 En3)
    if ( eq(F,H) )  return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

	// Final cleanup of two long slopes (non-clear shapes) with relaxed rules
    // Practice: This section handles long slopes differently from F-H. Default is tie, unless cube.
	if ( eq_B_C && eq_D_Q) {
        // Double cube exit
		if (eq_B_P && eq_B_PC && eq_A_B && eq_D_QA && !eq_D_QG && eq_E_F && eq(H,I) ) return theEXIT;

		return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
	}

	if ( eq_D_G && eq_B_P) {
        // Double cube exit
		if (eq_D_Q && eq_D_QG && eq_A_B && eq_B_PA && !eq_B_PC && eq_E_H && eq(F,I) ) return theEXIT;

		return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
	}

    eq_E_I = eq(E, I);

    // L-corner (clear) inward stick (parallel), exit
    if (eq_A_B && !ThickBorder && !eq_E_I ) {
	    if (B_wall && eq_E_F) return theEXIT;
	    if (D_wall && eq_E_H) return theEXIT;
	}

    // Skip next step and return early if colors are similar
    if (mixok) return mix(X,E,0.381966)+slopEND;

    // L-corner (hollow corner) outward stick (any direction), exit (solves font edge issues)
    if ( !eq_A_B && (eq_E_F||eq_E_H) && !eq_E_I) {
        if (B_tower && !eq_D_Q && !eq_D_QG) return theEXIT;
        if (D_tower && !eq_B_P && !eq_B_PC) return theEXIT;
    }

    // Fallback processing
    return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

} // sim2 base


/*===================================================
                    E - A Cross
  ============================================== zz */

if (eq_E_A) {

	// When judging cross ✕, have concepts of "region" and "trend". Different regions require tighter conditions.

    // B D three-no-stick exit? Not needed here!!!

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    eq_E_I = eq(E, I);
    En3 = eq_E_F&&eq_E_H;
    En4square = En3 && eq_E_I;

	// Special shape: Square
	if ( En4square ) {
        if( noteq(G,H) && noteq(C,F)                      //  Independent clear 4-cell square / 6-cell rectangle (both sides satisfy simultaneously)
		&& (eq(H,S) == eq(I,SI) && eq(F,R) == eq(I,RI)) ) return theEXIT;
        //else return mixok ? mix(X,E,0.381966) : X;    Note: Cannot return directly. Need to enter checkerboard decision rule because adjacent B, D zones might also form bubble with square structure.
    }

    //  Special shape: Halftone dot pattern
	//	Practice 1: !eq_E_F, !eq_E_H not using !sim, because it loses some shapes.
    //  Practice 2: Force mixing, otherwise shapes are lost. (Gouketsuji Ichizoku Matrimelee, Saturday Night Slam Masters 2)

	bool Eisblack = checkblack(E);
	mixok = mixcheck(X,E);

	//  1. Halftone dot center
    if ( eq_E_C && eq_E_G && eq_E_I && !eq_E_F && !eq_E_H ) {

		// Exit if center E is black (KOF96 power gauge, Punisher's belt) Avoid mixing with too high contrast.
		if (Eisblack) return theEXIT;
		// Practice 1: Cannot catch black B point, B points entering here already satisfy the shape.
		//if (Xisblack) return testcolor2;
		// Option 1 Layered (eq_F_H occurrence 95%) + layered progression inside health bar, remaining 0.5 fallback mix.
		// if (eq_F_H) return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
        // return mix(X, E, 0.5)+slopEND;
		// Final decision: just unify.
		return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
	}

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
    eq_B_PA = eq(B,PA);

	//  2. Halftone dot edge
    if ( eq_A_P && eq_A_Q && eq(A,AA) && noteq(A,PA) && noteq(A,QA) )  {
		if (Eisblack) return theEXIT;

        // Layered progressive edge, use strong mix.
		if ( !eq_B_PA && eq(PA,QA) ) return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
        // Remainder 1. Perfect cross, must be halftone dot edge, use weak mix.
        // Remainder 2. Fallback weak mix.
		return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;
		// Note: No need to specify health bar border cases separately.
	}

    eq_D_QA = eq(D,QA);
    eq_D_QG = eq(D,QG);
    eq_B_PC = eq(B,PC);

  //   3. Half halftone Usually shadow expression on contour edges, use weak mixing.
	if ( eq_E_C && eq_E_G && eq_A_P && eq_A_Q &&
		(eq_B_PC || eq_D_QG) &&
		 eq_D_QA && eq_B_PA) {

        return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;
		}

    //   4. Quarter halftone, easily causes ugly pinky finger effect.

	if ( eq_E_C && eq_E_G && eq_A_P
		 && eq_B_PA &&eq_D_QA && eq_D_QG
		 && eq_E_H
		) return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;

	if ( eq_E_C && eq_E_G && eq_A_Q
		 && eq_B_PA &&eq_D_QA && eq_B_PC
		 && eq_E_F
		) return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;


    // E-side three-star alignment (Must be after halftone)
    if ( eq_E_C && eq_E_G ) return X+slopEND;

    comboA3 = eq_A_P && eq_A_Q;

    // A-side three-star alignment (Must be after halftone) Since E-A same, prefer mixing over direct copy.
	if (comboA3) return mixok ? mix(X, E, 0.381966)+slopEND : X+slopEND;


    // B-D  part of long slope
	eq_B_P = eq(B,P);
	eq_D_Q = eq(D,Q);
	B_wall = eq_B_C && !eq_B_P;
	B_tower = eq_B_P && !eq_B_C;
	D_tower = eq_D_Q && !eq_D_G;
	D_wall = eq_D_G && !eq_D_Q;

    int scoreE = 0; int scoreB = 0; int scoreD = 0; int scoreZ = 0;


// E B D zone checkerboard scoring rules

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
        // 1 stick
        if (eq_E_F ||eq_E_H) return theEXIT;
    }

    if ( eq(F,H) ) {
		scoreE += 1;
        if ( scoreZ==0 && B_wall && (eq(F,R) || eq(G,H) || eq(F,I)) ) scoreZ = 1;
        if ( scoreZ==0 && D_wall && (eq(C,F) || eq(H,S) || eq(F,I)) ) scoreZ = 1;
    }

	bool Bn3 = eq_B_P&&eq_B_C;
	bool Dn3 = eq_D_G&&eq_D_Q;

//	B Zone
	scoreB -= int(Bn3);
	scoreB -= int(eq(C,P));
    if (scoreB < 0) scoreZ = 0;

    if (eq_B_PA) {
		scoreB -= 1;
		scoreB -= int(eq(P,PA));
	}

//        D Zone
	scoreD -= int(Dn3);
	scoreD -= int(eq(G,Q));
    if (scoreD < 0) scoreZ = 0;

    if (eq_D_QA) {
		scoreD -= 1;
		scoreD -= int(eq(Q,QA));
	}

    int scoreFinal = scoreE + scoreB + scoreD + scoreZ ;

    if (scoreE >= 1 && scoreB >= 0 && scoreD >=0) scoreFinal += 1;

    if (scoreFinal >= 2) return X;

    if (scoreFinal == 1) return mixok ? mix(X,E,0.381966) : X;

    // Final addition: Total score zero, B, D zones no deduction, forming long slope shape.
    if (scoreB >= 0 && scoreD >=0) {
        if (B_wall&&D_tower) return X;
        if (B_tower&&D_wall) return X;
    }

    return slopeBAD;

}	// eq_E_A



/*=========================================================
                    F - H / -B - D- Extension New Rules
  ==================================================== zz */

// This section is different from the sim section. The center point and related En4square and BD logic naturally have a wall separating them.
// Judgment rules differ from the sim side.

	eq_B_P = eq(B, P);
    eq_B_PC = eq(B, PC);
	eq_D_Q = eq(D, Q);
    eq_D_QG = eq(D, QG);

    // B D three-no-stick exit (Practice: This branch section needs it)
    if ( !eq_B_C && !eq_B_P && !eq_B_PC && !eq_D_G && !eq_D_Q && !eq_D_QG ) return slopeBAD;

	mixok = mixcheck(X,E);
    eq_E_I = eq(E, I);

	// Center point E is high contrast pixel, visually large gap with surrounding pixels, exit.
	float E_lumDiff = El>0.92 ? 0.145898 : 0.381966;
	bool E_ally = mixok || abs(El-Fl)<E_lumDiff || abs(El-Hl)<E_lumDiff || eq_E_I;
    if (!E_ally) return slopeBAD;

    eq_A_B = eq(A, B);
	eq_A_P = eq(A, P);
	eq_A_Q = eq(A, Q);
    eq_B_PA = eq(B,PA);
    eq_D_QA = eq(D,QA);
	comboA3 = eq_A_P && eq_A_Q;
    ThickBorder = eq_A_B && (eq_A_P||eq_A_Q|| eq(A,AA)&&(eq_B_PA||eq_D_QA));

	if (ThickBorder && !Xisblack) mixok=false;

	B_slope = eq_B_PC && !eq_B_P && !eq_B_C;
	B_tower = eq_B_P && !eq_B_PC && !eq_B_C && !eq_B_PA;
	D_slope = eq_D_QG && !eq_D_Q && !eq_D_G;
	D_tower = eq_D_Q && !eq_D_QG && !eq_D_G && !eq_D_QA;

    if (!eq_A_B) {
        // B + D + respective continuation shapes
        // Practice 1: One side is definite clear shape, the other can be looser.
        // Practice 2: "厂" shape edge flattens outside not inside (can be tower but not wall).
        if ( (B_slope||B_tower) && (eq_D_QG&&!eq_D_G||D_tower) ) return X +slopEND;
        if ( (D_slope||D_tower) && (eq_B_PC&&!eq_B_C||B_tower) ) return X +slopEND;

        // A-side three-star alignment, high priority
        if (comboA3) return X + slopEND;

        // combo 2x2 as supplement to previous one.
        if ( B_slope && eq_A_P ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
        if ( D_slope && eq_A_Q ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    }

    eq_E_F = eq(E, F);
	B_wall = eq_B_C && !eq_B_PC && !eq_B_P;

    // long slope Clear long slope (Not solid edge. Strong trend!)
    // Long slope case slightly special, separate condition check.
	if ( B_wall && D_tower ) {
        if (eq_A_B ) return slopeBAD;
        if (eq_E_F ) return X;  //wip: Test direct X no-mix.
        return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
    }

    eq_E_H = eq(E, H);
	D_wall = eq_D_G && !eq_D_QG&& !eq_D_Q;

	if ( B_tower && D_wall ) {
        if (eq_A_B ) return slopeBAD;
        if (eq_E_H ) return X;
        return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
    }


    En3 = eq_E_F&&eq_E_H;
    En4square = En3 && eq_E_I;
    bool sim_X_E = sim3(X,E);
    bool eq_G_H = eq(G, H);
    bool eq_C_F = eq(C, F);
    bool eq_H_S = eq(H, S);
    bool eq_F_R = eq(F, R);

    // Wall enclosed 4-cell rectangle
	if ( En4square ) {  // This square detection needs to be after the previous rule.
		if (sim_X_E) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        // Solid L enclosed exit (Fixes some font edge corners and building corners that shouldn't be rounded (Mega Man 7))
        if ( (eq_B_C || eq_D_G) && eq_A_B ) return theEXIT;
        //if (eq_H_S && eq_F_R) return theEXIT; // Both sides extend simultaneously.
        //  L enclosed (hollow corner) / High contrast independent clear 4-cell square / 6-cell rectangle (Note judge both edges of rectangle)
        if ( ( eq_B_C&&!eq_G_H || eq_D_G&&!eq_C_F || !eq_G_H&&!eq_C_F&&abs(El-Bl)>0.5) && (eq(H,S) == eq(I, SI) && eq(F,R) == eq(I, RI)) ) return theEXIT;

        return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
    }

    // Wall enclosed triangle
 	if ( En3 ) {
		if (sim_X_E) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        if (eq_H_S && eq_F_R) return theEXIT; // Both sides extend simultaneously (building edges).
       // Inward bend
        if (eq_B_C || eq_D_G) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		// Has thickness, return directly (Z-shape snake can tie the outward bend below).
        if (eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        // Outward bend
        if (eq_B_P || eq_D_Q) return theEXIT;

        return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        // Last two rules based on experience, principle: Connect L inward bend, not L outward (Double Dragon Jimmy's eyebrows).
	}

    // F - H
	// Principle: Connect L inward bend, not L outward.
	if ( eq(F,H) ) {
    	if (sim_X_E) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        // Solid L enclosed, avoid bilateral symmetric full enclosure squeezing single pixel.
		if ( eq_B_C && eq_A_B && (eq_G_H||!eq_F_R) &&eq(F, I) ) return slopeBAD;
		if ( eq_D_G && eq_A_B && (eq_C_F||!eq_H_S) &&eq(F, I) ) return slopeBAD;

		//Inward bend
        if (eq_B_C && (eq_F_R||eq_G_H||eq(F, I))) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        if (eq_D_G && (eq_C_F||eq_H_S||eq(F, I))) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		// E-I F-H cross kill the trend
		if (eq_E_I) return slopeBAD;
        // Z-shape outward
		if (eq_B_P && eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        if (eq_D_Q && eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		// Outward bend unless the opposite side forms long L trend.
		if (eq_B_P && (eq_C_F&&eq_H_S)) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        if (eq_D_Q && (eq_F_R&&eq_G_H)) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

        return slopeBAD;
	}

	// Final cleanup of two long slopes (non-clear shapes) with relaxed rules.
    // Note: This section handles long slopes differently from sim2 section, solid corners exit.
	if ( eq_B_C && eq_D_Q || eq_D_G && eq_B_P) {
        // Note: Must clear eq_A_B first, otherwise edge single pixels get chipped (Evermore).
		if (eq_A_B) return theEXIT;
		return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
	}


    //	A-side three-star alignment, MUST NOT be used separately without !eq_A_B !!!!!!!!!
    //  if (comboA3) return X+slopEND;


	// Use B + D bidirectional continuation to capture once more, priority higher than L inward/outward stick below.
        if ( (B_slope||B_tower) && (eq_D_QG&&!eq_D_G||D_tower) ) return X +slopEND;
        if ( (D_slope||D_tower) && (eq_B_PC&&!eq_B_C||B_tower) ) return X +slopEND;


    // L-corner (clear) inward stick, exit.
    if (eq_A_B && !ThickBorder && !eq_E_I ) {

	    if (B_wall && eq_E_F) return theEXIT;
	    if (D_wall && eq_E_H) return theEXIT;
	}


    // L-corner (hollow corner) outward stick, exit (Corner connects inward, not outward).
	// Practice: Can avoid font edges being shaved (Captain Commando).
	if ( (B_tower || D_tower) && (eq_E_F||eq_E_H) && !eq_A_B && !eq_E_I) return theEXIT;

    // Final B or D individual extension judgment.

    // Farthest distance a slope can utilize.
    if ( B_slope && eq(PC,CC) && noteq(PC,RC) && !eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
    if ( D_slope && eq(QG,GG) && noteq(QG,SG) && !eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

    // When X E are close, slope can have one less judgment point, with some restrictions in internal logic.
  	if ( mixok && !eq_A_B ) {
        if ( B_slope && (!eq_C_F||eq(F,RC)) ) return mix(X,E,0.381966)+slopEND;
        if ( D_slope && (!eq_G_H||eq(H,SG)) ) return mix(X,E,0.381966)+slopEND;
    }

    // Tower type relax eq_A_B to form Z-shape snake, and one side can be wall, slope. But the other side cannot be tower and wall (naturally forbidden).
    if ( eq_B_P && !eq_B_PA && !eq_D_Q && eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
    if ( eq_D_Q && !eq_D_QA && !eq_B_P && eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

	return theEXIT;

}	// admixX

vec3 admixS(vec3 A, vec3 B, vec3 C, vec3 D, vec3 E, vec3 F, vec3 G, vec3 H, vec3 I, vec3 R, vec3 RC, vec3 RI, vec3 S, vec3 SG, vec3 SI, vec3 II, bool eq_B_D, bool eq_E_D, float El, float Bl) {
			//                                    A B C .
			//                                  Q D 🄴 🅵 🆁       Zone 4
			//					                  🅶 🅷 I
			//					                    S
    // Practice 2: sim E B(C) conforms to original logic. In practice, when E is single pixel, it won't be too strange due to jagged insertion.
    // E cannot equal I           TEST ??? no!
    // if ( eq(E, I) ) return E;

    if (any_eq2(F,C,I)) return E;
    //if (any_eq3(F,A,C,I)) return E;

    if (eq(R, RI) && noteq(R,I)) return E;
    if (eq(H, S) && noteq(H,I)) return E;

    if ( eq(R, RC) || eq(G,SG) ) return E;

    if ( ( eq_B_D&&eq(B,C)&&abs(El-Bl)<0.381966 || eq_E_D&&sim2(E,C) ) &&
    (any_eq3(I,H,S,RI) || eq(SI,RI)&&noteq(I,II)) ) return F;

    return E;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main()
{
   vec3 E = src(0, 0);
// Preset one for quick return.
   FragColor = vec4(E, 1.0);

// Default to nearest-neighbor magnification.
    vec3 J = E;    vec3 K = E;    vec3 L = E;    vec3 M = E;

    vec3 D = src(-1, +0);
    vec3 F = src(+1, +0);
    bool eq_E_D = eq(E,D);
    bool eq_E_F = eq(E,F);

// Skip same-color horizontal block 3x1.
if ( eq_E_D && eq_E_F ) return;

    vec3 B = src(+0, -1);
    vec3 H = src(+0, +1);
    bool eq_E_B = eq(E,B);
    bool eq_E_H = eq(E,H);

// Skip same-color vertical block 3x1.
if ( eq_E_B && eq_E_H ) return;

   bool eq_B_H = eq(B,H);
   bool eq_D_F = eq(D,F);

// Skip mirrored block surrounding center point.
if ( eq_B_H && eq_D_F ) return;


    // ------------------------ Boundary Detection --------------------------
    // Define an impossible fake pixel.
    const vec3 fakeColor = vec3(1.234);
    // 1. Pre-calc integer coords of current pixel (uv -> pixel coords, floor to get pixel index).
    vec2 pixelPos = vTexCoord * params.SourceSize.xy;
    ivec2 currPixel = ivec2(floor(pixelPos)); // Current pixel integer coords (0-based).
    ivec2 texSize = ivec2(params.SourceSize.xy); // Texture actual pixel dimensions.

    // 2. Batch check four directions for out-of-bounds (integer based on pixel coords, no float error).
    bool isBOutOfBounds = (currPixel.y - 1 < 0); // Top pixel OOB (y-1 < 0).
    bool isDOutOfBounds = (currPixel.x - 1 < 0); // Left pixel OOB (x-1 < 0).
    bool isFOutOfBounds = (currPixel.x + 1 >= texSize.x); // Right pixel OOB (x+1 >= width).
    bool isHOutOfBounds = (currPixel.y + 1 >= texSize.y); // Bottom pixel OOB (y+1 >= height).

    // 3. Assign fake pixel if OOB (No need for sequential判断, batch process directly, reduce branches).
    if (isBOutOfBounds) B = fakeColor;
    if (isDOutOfBounds) D = fakeColor;
    if (isFOutOfBounds) F = fakeColor;
    if (isHOutOfBounds) H = fakeColor;
    // ----------------------------------------------------------------------

	// Moved second last line up for JLKM modification exit and reuse pixelPos.
	//vec2 a = fract(vTexCoord * params.SourceSize.xy);
	vec2 a = fract(pixelPos);

// Pre-calc luma.
   float Bl = luma(B);
   float Dl = luma(D);
   float El = luma(E);
   float Fl = luma(F);
   float Hl = luma(H);


   vec3 A = src(-1, -1);
   vec3 C = src(+1, -1);
   vec3 G = src(-1, +1);
   vec3 I = src(+1, +1);


// Extend 3x3 to 4 edges.
   vec3 P  = src(+0, -2);
   vec3 Q  = src(-2, +0);
   vec3 R  = src(+2, +0);
   vec3 S  = src(+0, +2);

// Extend further to 5x5.
   vec3 PA = src(-1, -2);
   vec3 PC = src(+1, -2);
   vec3 QA = src(-2, -1);
   vec3 QG = src(-2, +1); //             AA  PA  [P]  PC  CC
   vec3 RC = src(+2, -1); //                ┌───┬───┬───┐
   vec3 RI = src(+2, +1); //             QA │ A │ B │ C │ RC
   vec3 SG = src(-1, +2); //                ├───┼───┼───┤
   vec3 SI = src(+1, +2); //            [Q] │ D │ E │ F │ [R]
   vec3 AA = src(-2, -2); //                ├───┼───┼───┤
   vec3 CC = src(+2, -2); //             QG │ G │ H │ I │ RI
   vec3 GG = src(-2, +2); //                └───┴───┴───┘
   vec3 II = src(+2, +2); //             GG   SG [S]  SI  II


// 1:1 slope rules (P95)

    // main slops
    bool eq_B_D = eq(B,D);
    bool eq_B_F = eq(B,F);
    bool eq_D_H = eq(D,H);
    bool eq_F_H = eq(F,H);

    // Any mirrored block surrounding center point.
    bool oppoPix =  eq_B_H || eq_D_F;
	// Flag indicating entry into admixX function by 1:1 slope rule.
    bool slope1 = false;    bool slope2 = false;    bool slope3 = false;    bool slope4 = false;
	// Standard pixel successfully returned normally via 1:1 slope rule.
    bool slope1ok = false;  bool slope2ok = false;  bool slope3ok = false;  bool slope4ok = false;
	// slopeBAD entered admixX, but (at least one of JKLM) returned E point.
    bool slopeBAD = false;  bool slopEND = false;

    // B - D
	if ( (!eq_E_B&&!eq_E_D&&!oppoPix) && (!eq_D_H&&!eq_B_F) && (El>=Dl&&El>=Bl || eq(E,A)) && ( (El<Dl&&El<Bl) || none_eq2(A,B,D) || noteq(E,P) || noteq(E,Q) ) && ( eq_B_D&&(eq_F_H||eq(E,A)||eq(B,PC)||eq(D,QG)) || sim1(B,D)&&(sim2(E,C)||sim2(E,G)) ) ) {
		J=admixX(A,B,C,D,E,F,G,H,I,P,PA,PC,Q,QA,QG,R,RC,RI,S,SG,SI,AA,CC,GG, El,Bl,Dl,Fl,Hl);
		slope1 = true;
		if (J.b > 1.0 ) {
            if (J.b > 30.0 ) {J=J-33.0; slopEND=true;}
			if (J.b == 8.0 ) return;
			if (J.b == 2.0 ) {slopeBAD=true; J=E;}
		} else slope1ok = true;
	}
    // B - F
	if ( !slope1 && (!eq_E_B&&!eq_E_F&&!oppoPix) && (!eq_B_D&&!eq_F_H) && (El>=Bl&&El>=Fl || eq(E,C)) && ( (El<Bl&&El<Fl) || none_eq2(C,B,F) || noteq(E,P) || noteq(E,R) ) && ( eq_B_F&&(eq_D_H||eq(E,C)||eq(B,PA)||eq(F,RI)) || sim1(B,F)&&(sim2(E,A)||sim2(E,I)) ) )  {
		K=admixX(C,F,I,B,E,H,A,D,G,R,RC,RI,P,PC,PA,S,SI,SG,Q,QA,QG,CC,II,AA, El,Fl,Bl,Hl,Dl);
		slope2 = true;
		if (K.b > 1.0 ) {
            if (K.b > 30.0 ) {K=K-33.0; slopEND=true;}
			if (K.b == 8.0 ) return;
			if (K.b == 2.0 ) {slopeBAD=true; K=E;}
		} else {slope2ok = true;}
	}
    // D - H
	if ( !slope1 && (!eq_E_D&&!eq_E_H&&!oppoPix) && (!eq_F_H&&!eq_B_D) && (El>=Hl&&El>=Dl || eq(E,G))  &&  ((El<Hl&&El<Dl) || none_eq2(G,D,H) || noteq(E,S) || noteq(E,Q))  &&  ( eq_D_H&&(eq_B_F||eq(E,G)||eq(D,QA)||eq(H,SI)) || sim1(D,H) && (sim2(E,A)||sim2(E,I)) ) )  {
		L=admixX(G,D,A,H,E,B,I,F,C,Q,QG,QA,S,SG,SI,P,PA,PC,R,RI,RC,GG,AA,II, El,Dl,Hl,Bl,Fl);
		slope3 = true;
		if (L.b > 1.0 ) {
            if (L.b > 30.0 ) {L=L-33.0; slopEND=true;}
			if (L.b == 8.0 ) return;
			if (L.b == 2.0 ) {slopeBAD=true; L=E;}
		} else {slope3ok = true;}
	}
    // F - H
	if ( !slope2 && !slope3 && (!eq_E_F&&!eq_E_H&&!oppoPix) && (!eq_B_F&&!eq_D_H) && (El>=Fl&&El>=Hl || eq(E,I))  &&  ((El<Fl&&El<Hl) || none_eq2(I,F,H) || noteq(E,R) || noteq(E,S))  &&  ( eq_F_H&&(eq_B_D||eq(F,RC)||eq(H,SG)||eq(E,I)) || sim1(F,H) && (sim2(E,C)||sim2(E,G)) ) )  {
		M=admixX(I,H,G,F,E,D,C,B,A,S,SI,SG,R,RI,RC,Q,QG,QA,P,PC,PA,II,GG,CC, El,Hl,Fl,Dl,Bl);
		slope4 = true;
		if (M.b > 1.0 ) {
            if (M.b > 30.0 ) {M=M-33.0; slopEND=true;}
			if (M.b == 8.0 ) return;
			if (M.b == 2.0 ) {slopeBAD=true; M=E;}
		} else {slope4ok = true;}
	}


//  long gentle 2:1 slope  (P100) and saw-tooth slope.

	bool longslope = false;

    if (slope4ok && eq_F_H) { //zone4 long slope.
        // Original rule extension 1. admixL third parameter passes adjacent pixel for comparison, ensures no double mixing.
        // Original rule extension 2. Cannot have L shape again within the two-pixel gap opposite, unless forming a wall.
        if (eq(G,H) && eq(F,R) && noteq(R, RC) && (noteq(Q,G)||eq(Q, QA))) {L=admixL(M,L,H); longslope = true;}
        // virtical.
		if (eq(C,F) && eq(H,S) && noteq(S, SG) && (noteq(P,C)||eq(P, PA))) {K=admixL(M,K,F); longslope = true;}
    }


    if (slope3ok && eq_D_H) { //zone3 long slope.
        // horizontal.
        if (eq(D,Q) && eq(H,I) && noteq(Q, QA) && (noteq(R,I)||eq(R, RC))) {M=admixL(L,M,H); longslope = true;}
        // virtical.
		if (eq(A,D) && eq(H,S) && noteq(S, SI) && (noteq(A,P)||eq(P, PC))) {J=admixL(L,J,D); longslope = true;}
    }

    if (slope2ok && eq_B_F) { //zone2 long slope.
        // horizontal.
        if (eq(A,B) && eq(F,R) && noteq(R, RI) && (noteq(A,Q)||eq(Q, QG))) {J=admixL(K,J,B); longslope = true;}
        // virtical.
		if (eq(F,I) && eq(B,P) && noteq(P, PA) && (noteq(I,S)||eq(S, SG))) {M=admixL(K,M,F); longslope = true;}
    }

    if (slope1ok && eq_B_D) { //zone1 long slope.
        // horizontal.
        if (eq(B,C) && eq(D,Q) && noteq(Q, QG) && (noteq(C,R)||eq(R, RI))) {K=admixL(J,K,B); longslope = true;}
        // virtical.
		if (eq(D,G) && eq(B,P) && noteq(P, PC) && (noteq(G,S)||eq(S, SI))) {L=admixL(J,L,D); longslope = true;}
    }


// longslope formed can exit, basically won't form sawslope on diagonal.
if (longslope) {
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
	return;
}

bool sawslope = false;

bool slopeok = slope1ok||slope2ok||slope3ok||slope4ok;

// Note: sawslope cannot exclude slopEND (few) and slopeBAD (very few), but can exclude slopeok (strong shape).
if (!oppoPix && !slopeok) {


        // horizontal bottom.
		if (!eq_E_H && none_eq2(H,A,C)) {

			//                                    A B C .
			//                                  Q D 🄴 🅵 🆁       Zone 4.
			//					                  🅶 🅷 I
			//					                    S
			// (!slope3 && !eq_D_H) Such combined usage is good.
			if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H)  && !eq_F_H &&
                !eq_E_F && (eq_B_D || eq_E_D) && eq(R,H) && eq(F,G) ) {
                M = admixS(A,B,C,D,E,F,G,H,I,R,RC,RI,S,SG,SI,II,eq_B_D,eq_E_D,El,Bl);
                sawslope = true;}

			//                                  . A B C
			//                                  🆀 🅳 🄴 F R       Zone 3.
			//                                    G 🅷 🅸
			//					                    S
			if ( !sawslope && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_D_H &&
                 !eq_E_D && (eq_B_F || eq_E_F) && eq(Q,H) && eq(D,I) ) {
                L = admixS(C,B,A,F,E,D,I,H,G,Q,QA,QG,S,SI,SG,GG,eq_B_F,eq_E_F,El,Bl);
                sawslope = true;}
		}

        // horizontal up.
		if ( !sawslope && !eq_E_B && none_eq2(B,G,I)) {

			//					                    P
			//                                    🅐 🅑 C
			//                                  Q D 🄴 🅵 🆁       Zone 2.
			//                                    G H I .
			if ( (!slope1 && !eq_B_D)  && (!slope4 && !eq_F_H) && !eq_B_F &&
				  !eq_E_F && (eq_D_H || eq_E_D) && eq(B,R) && eq(A,F) ) {
                K = admixS(G,H,I,D,E,F,A,B,C,R,RI,RC,P,PA,PC,CC,eq_D_H,eq_E_D,El,Hl);
                sawslope = true;}

			//					                    P
			//                                    A 🅑 🅲
			//                                  🆀 🅳 🄴 F R        Zone 1.
			//                                  . G H I
			if ( !sawslope && (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && !eq_B_D &&
				 !eq_E_D && (eq_F_H || eq_E_F) && eq(B,Q) && eq(C,D) ) {
                J = admixS(I,H,G,F,E,D,C,B,A,Q,QG,QA,P,PC,PA,AA,eq_F_H,eq_E_F,El,Hl);
                sawslope = true;}

		}

        // vertical left.
        if ( !sawslope && !eq_E_D && none_eq2(D,C,I) ) {

			//                                    🅐 B C
			//                                  Q 🅳 🄴 F R
			//                                    G 🅷 I        Zone 3.
			//                                      🆂 .
            if ( (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_D_H &&
				  !eq_E_H && (eq_B_F || eq_E_B) && eq(D,S) && eq(A,H) ) {
                L = admixS(C,F,I,B,E,H,A,D,G,S,SI,SG,Q,QA,QG,GG,eq_B_F,eq_E_B,El,Fl);
                sawslope = true;}

			//                                      🅟 .
			//                                    A 🅑 C
			//                                  Q 🅳 🄴 F R       Zone 1.
			//                                    🅶 H I
			if ( !sawslope && (!slope3 && !eq_D_H) && (!slope2 && !eq_B_F) && !eq_B_D &&
				  !eq_E_B && (eq_F_H || eq_E_H) && eq(P,D) && eq(B,G) ) {
                J = admixS(I,F,C,H,E,B,G,D,A,P,PC,PA,Q,QG,QA,AA,eq_F_H,eq_E_H,El,Fl);
                sawslope = true;}

		}

        // vertical right.
		if ( !sawslope && !eq_E_F && none_eq2(F,A,G) ) { // right.

			//                                    A B 🅲
			//                                  Q D 🄴 🅵 R
			//                                    G 🅷 I        Zone 4.
			//                                    . 🆂
			if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && !eq_F_H &&
				  !eq_E_H && (eq_B_D || eq_E_B) && eq(S,F) && eq(H,C) ) {
                M = admixS(A,D,G,B,E,H,C,F,I,S,SG,SI,R,RC,RI,II,eq_B_D,eq_E_B,El,Dl);
                sawslope = true;}

			//                                    . 🅟
			//                                    A 🅑 C
			//                                  Q D 🄴 🅵 R        Zone 2.
			//                                    G H 🅸
			if ( !sawslope && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_B_F &&
				 !eq_E_B && (eq_D_H || eq_E_H) && eq(P,F) && eq(B,I) ) {
                K = admixS(G,D,A,H,E,B,I,F,C,P,PA,PC,R,RI,RC,CC,eq_D_H,eq_E_H,El,Dl);
                sawslope = true;}

		} // vertical right.
} // sawslope.

// sawslope formed can exit, slopeBAD not applicable to CnC below.
if (sawslope||slopeBAD) {
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
	return;
}

/**************************************************
 *     "Concave + Cross" shape (P100)	          *
 *************************************************/
//  Cross star uses approximate pixels, useful for some horizontal line+jagged and layered gradient shapes. e.g., SFIII 3rd Strike intro glow text, sfz3mix Japanese house, Garou: Mark of the Wolves intro.
// Practice: CnC cannot exclude slopEND (weak shape) and slopok (strong shape) but can exclude slopeBAD !!!

bool cnc = false;	vec3 X;

    if (!slope3 && !slope4 &&
        Bl<El && !eq_E_D && !eq_E_F && eq_E_H && none_eq2(E,A,C) && all_eq2(G,H,I) && sim1(E,S) ) { // TOP
	    if (eq_D_F){
			if (eq_B_D) J=admixK(B,J);
			else { X = abs(El-Bl) < abs(El-Dl) ? B : D;		J=admixC(X,J); }
			K=J;
            L=mix(J,L, 0.61804);
			M=L;
        } else {
				if (!slope1) { X = abs(El-Bl) < abs(El-Dl) ? B : D;		J=admixC(X,J); }
				if (!slope2) { X = abs(El-Bl) < abs(El-Fl) ? B : F; 		K=admixC(X,K); }
		}

	   cnc = true;
	}

    if (!slope1 && !slope2 && !cnc &&
		Hl<El && !eq_E_D && !eq_E_F && eq_E_B && none_eq2(E,G,I) && all_eq2(A,B,C) && sim1(E,P) ) { // BOTTOM
	    if (eq_D_F){
			if (eq_D_H) L=admixK(H,L);
			else { X = abs(El-Dl) < abs(El-Hl) ? D : H;		L=admixC(X,L); }
			M=L;
            J=mix(L,J, 0.61804);
			K=J;
        } else {
				if (!slope3) { X = abs(El-Dl) < abs(El-Hl) ? D : H;		L=admixC(X,L); }
				if (!slope4) { X = abs(El-Fl) < abs(El-Hl) ? F : H; 		M=admixC(X,M); }
		}

	   cnc = true;
	}

   if (!slope1 && !slope3 && !cnc &&
		Fl<El && !eq_E_B && !eq_E_H && eq_E_D && none_eq2(E,C,I) && all_eq2(A,D,G) && sim1(E,Q) ) { // RIGHT
        if (eq_B_H) {
			if (eq_B_F) K=admixK(F,K);
			else { X = abs(El-Bl) < abs(El-Fl) ? B : F;		K=admixC(X,K); }
			M=K;
            J=mix(K,J, 0.61804);
			L=J;
        } else {
				if (!slope2) { X = abs(El-Bl) < abs(El-Fl) ? B : F;		K=admixC(X,K); }
				if (!slope4) { X = abs(El-Fl) < abs(El-Hl) ? F : H; 		M=admixC(X,M); }
		}

	   cnc = true;
	}
    if (!slope2 && !slope4 && !cnc &&
		Dl<El && !eq_E_B && !eq_E_H && eq_E_F && none_eq2(E,A,G) && all_eq2(C,F,I) && sim1(E,R) ) { // LEFT
        if (eq_B_H) {
			if (eq_B_D) J=admixK(B,J);
			else { X = abs(El-Bl) < abs(El-Dl) ? B : D;		J=admixC(X,J); }
			L=J;
            K=mix(J,K, 0.61804);
			M=K;
        } else {
				if (!slope1) { X = abs(El-Bl) < abs(El-Dl) ? B : D;		J=admixC(X,J); }
				if (!slope3) { X = abs(El-Dl) < abs(El-Hl) ? D : H; 		L=admixC(X,L); }
		}

	   cnc = true;
	}

	bool slope = slope1 || slope2 || slope3 || slope4;

if (slope||cnc) {
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
	return;
}

/*
       ㇿО
     ОООㇿ
	   ㇿО    Scorpion shape (P99). Looks like the sentinels from The Matrix. Can flatten some regular pixels.
*/
// Practice: 1. Scorpion pincers use approximation, otherwise easily become small C-shape and cause graphical glitches.
// Practice: 2. Remove one segment from scorpion tail to capture more shapes.
// Among the four shapes, only scorpion is exclusive. Once caught by previous rules (entered), this shape won't appear. Also the least noticeable shape. So placed last.

bool scorpion = false;
                if (!eq_E_F &&eq_E_D&&eq_B_F&&eq_F_H && all_eq2(E,C,I) && noteq(F,src(+3, 0)) ) {K=admixK(F,K); M=K;J=mix(K,J, 0.61804); L=J;scorpion=true;}	// RIGHT.
   if (!scorpion && !eq_E_D &&eq_E_F&&eq_B_D&&eq_D_H && all_eq2(E,A,G) && noteq(D,src(-3, 0)) ) {J=admixK(D,J); L=J;K=mix(J,K, 0.61804); M=K;scorpion=true;}	// LEFT.
   if (!scorpion && !eq_E_H &&eq_E_B&&eq_D_H&&eq_F_H && all_eq2(E,G,I) && noteq(H,src(0, +3)) ) {L=admixK(H,L); M=L;J=mix(L,J, 0.61804); K=J;scorpion=true;}	// BOTTOM.
   if (!scorpion && !eq_E_B &&eq_E_H&&eq_B_D&&eq_B_F && all_eq2(E,A,C) && noteq(B,src(0, -3)) ) {J=admixK(B,J); K=J;L=mix(J,L, 0.61804); M=L;}			// TOP

// Determine which of our 4 output pixels we need to use
   FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
}
