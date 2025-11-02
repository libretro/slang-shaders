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
   //return dot(col, vec3(0.3333333)); // RGB average
}


bool checkblack(vec3 col) {
  if (col.r > 0.1 || col.g > 0.078 || col.b > 0.1) return false;

    return true;
}

bool checkwhite(vec3 col) {
 if (col.r < 0.9 || col.g < 0.92 || col.b < 0.9) return false;

    return true;
}

// pin zz
bool sim(vec3 col1, vec3 col2, int Lv) {

    vec3 diff = abs(col1 - col2);

    // 1. Fast component difference check
    if ( diff.r > 0.145898 || diff.g > 0.145898 || diff.b > 0.145898 ) return false;

    // 2. Fast filter for identical pixels and very dark/very bright pixels after clamping
    vec3 clampCol1 = clamp(col1, vec3(0.078),vec3(0.92));
    vec3 clampCol2 = clamp(col2, vec3(0.078),vec3(0.92));
    vec3 clampdiff = clampCol1 - clampCol2;
    vec3 absclampdiff = abs(clampdiff);
    if ( absclampdiff.r < 0.05572809 && absclampdiff.g < 0.021286 && absclampdiff.b < 0.05572809 ) return true;

    float dotdist = 0.00931686;
	if (Lv==2) dotdist = 0.024391856;
	if (Lv==3) dotdist = 0.0638587;

    // 3. Fast squared distance check
	float dot_diff = dot(diff, diff);
    if (dot_diff > dotdist) return false;

	// 4. Re-check with opposite channels added to squared distance
	float teamA = 0.0;
	float teamB = 0.0;

	if (clampdiff.r > 0.0) teamA += absclampdiff.r; else teamB += absclampdiff.r;
	if (clampdiff.g > 0.0) teamA += absclampdiff.g; else teamB += absclampdiff.g;
	if (clampdiff.b > 0.0) teamA += absclampdiff.b; else teamB += absclampdiff.b;
	float team = min(teamA,teamB);
	// Tested: at least 3x the opposite channel value is needed. (+1x ties, +2x starts a trend)
	if (dot_diff + team*team*3.0 > dotdist) return false;

	if (Lv==3) return true;

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
    // Fast filter for similar pixels (0.4377 divided by 6, square root max can be 0.27)
    if ( absdiff.r < 0.27 && absdiff.g < 0.27 && absdiff.b < 0.27 ) return true;

    // 3. Fast squared distance check
	float dot_diff = dot(diff, diff);
    if (dot_diff > 0.4377) return false;

	// 4. Re-check with opposite channels added to squared distance
	float teamA = 0.0;
	float teamB = 0.0;

	if (diff.r > 0.0) teamA += absdiff.r; else teamB += absdiff.r;
	if (diff.g > 0.0) teamA += absdiff.g; else teamB += absdiff.g;
	if (diff.b > 0.0) teamA += absdiff.b; else teamB += absdiff.b;
	float team = min(teamA,teamB);
	// Tested: at least 3x the opposite channel value is needed. (+1x ties, +2x starts a trend)
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

// Check if texture coordinates are within valid bounds
bool isInBounds(vec2 texCoord) {
    return all(greaterThanEqual(texCoord, vec2(0.0))) && all(lessThanEqual(texCoord, vec2(1.0)));
}

///////////////////////     Test Colors     ///////////////////////
 //vec3 testcolor = vec3(1.0, 0.0, 1.0);  // Magenta
 //vec3 testcolor2 = vec3(0.0, 1.0, 1.0);  // Cyan
 //vec3 testcolor3 = vec3(1.0, 1.0, 0.0);  // Yellow
 //vec3 testcolor4 = vec3(1.0, 1.0, 1.0);  // White


// pin zz   "Concave + Cross" shaped Weak Mixing (Weak Mix/None)
vec3 admixC(vec3 X1, vec3 X2, vec3 E) {

    // Case of black pincers? Not necessary, if mixing is possible, E is also dark.
    //if (checkblack(X1) && checkblack(X2)) return E;

	bool mix1ok = mixcheck(X1, E);
	bool mix2ok = mixcheck(X2, E);

	if (mix1ok&&!mix2ok) return mix(X1, E, 0.618034);
	if (!mix1ok&&mix2ok) return mix(X2, E, 0.618034);
	if (mix1ok&&mix2ok) {
		float rgbDist1 = dot(X1 - E, X1 - E);
		float rgbDist2 = dot(X2 - E, X2 - E);

		// Choose the closer reference color
		vec3 X = rgbDist1 < rgbDist2 ? X1 : X2;
		return mix(X, E, 0.618034);
	}

	return E;

}

// K-shaped Forced Weak Mixing (Weak Mix/Weaker)
vec3 admixK(vec3 X, vec3 E) {

	bool mixok = mixcheck(X, E);

	return mixok ? mix(X, E, 0.618034) : mix(X, E, 0.8541);

}

// L-shaped 2:1 Slope  Main corner extension
// Practice: This rule requires all 4 pixels on the strict slope to be identical. Otherwise, various glitches appear!
vec3 admixL(vec3 X, vec3 E, vec3 S) {

    //if (eq(X, E)) return E; // Originally this would catch many duplicate pixels, but after slopeBAD filtering, it's disabled.

	// If target X and reference S(sample) are different, it means mixing has already occurred once, just copy the target.
	if (noteq(X, S)) return X;

	bool mixok = mixcheck(X, E);

    return mixok ? mix(X, E, 0.381966) : X;
}

/********************************************************************************************************************************************
 *               												main slope + X cross-processing mechanism					                *
 pin zz **********************************************************************************************************************************  */
vec3 admixX(vec3 A, vec3 B, vec3 C, vec3 D, vec3 E, vec3 F, vec3 G, vec3 H, vec3 I, vec3 P, vec3 PA, vec3 PC, vec3 Q, vec3 QA, vec3 QG, vec3 R, vec3 RC, vec3 RI, vec3 S, vec3 SG, vec3 SI, vec3 AA) {

    // Pre-define 3 types of special exits
    vec3 slopeBAD = vec3(2.0);
    vec3 theEXIT = vec3(8.0);
    vec3 slopEND = vec3(33.0);

	//pre-cal
	bool eq_B_D = eq(B, D);
	bool eq_B_C = eq(B, C);
	bool eq_D_G = eq(D, G);

	// Exit if sandwiched by bilateral straight walls
	if (eq_B_D && eq_B_C && eq_D_G) return slopeBAD;

	// Merge D B into X
    vec3 X = eq_B_D ? B : mix(B,D,0.5);

	// Avoid opposite side squeezing when E is on the black edge (for fonts with contrast over half)
	bool Bisblack = checkblack(B);
	// When BD are not equal, cannot use average to judge if X is black
	bool Xisblack = eq_B_D ? Bisblack : Bisblack&&checkblack(D);
	if ( Xisblack && abs((E.r + E.g + E.b) - (X.r + X.g + X.b)) >1.5 ) {

		if ( checkblack(F) || checkblack(H) ) return theEXIT;
	}

	//Pre-declare
	bool eq_A_B;	bool eq_A_D;	bool eq_A_P;	bool eq_A_Q;
	bool eq_B_P;    bool eq_B_PA;   bool eq_B_PC;
	bool eq_D_Q;    bool eq_D_QA;   bool eq_D_QG;
    bool eq_E_F;    bool eq_E_H;    bool eq_E_I;    bool En3;	bool En4square;
	bool linkB1;	bool linkB2;	bool linkD1;	bool linkD2;
	bool BDlong;	bool DBlong;
    bool comboA3;	bool mixok;

	//pre-cal
    bool eq_E_A = eq(E,A);

// B != D
if (!eq_B_D){
    // Exit if preset logic is not met
	if (eq_E_A) return slopeBAD;

	eq_A_B = eq(A,B);
	eq_A_D = eq(A,D);

	// B D are different (not black), one side is straight, the other must be a single pixel.
	// Practice: Avoids mixing at the corners of parallel lines where BD are each continuous.
    if (!Xisblack){
        if ( eq_A_B && (eq_D_G||eq(D,Q)) ) return slopeBAD;
        if ( eq_A_D && (eq_B_C||eq(B,P)) ) return slopeBAD;
    }

    // When D B are different and their difference is larger than either one's difference to the center point, exit.
    vec3 diffBD = B - D;
    vec3 diffEB = E - B;
    vec3 diffED = E - D;
	float distBD = dot(diffBD,diffBD);
	if (distBD > dot(diffEB,diffEB) || distBD > dot(diffED,diffED)) return slopeBAD;

    // B D not connected to anything? Not applicable here. (Can eliminate some artifacts but also lose some shapes, especially in non-native pixel art, e.g., character portraits in Double Dragon intro)

	// Treat near-black like DB?
    // Practice: Special treatment for non-black in dark areas can cause glitches (Samurai Shodown 2 Charlotte)
	//if (Xisblack) return X +slopEND;

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
	comboA3 = eq_A_P && eq_A_Q;
	mixok = mixcheck(X,E);

	// A-side three-in-a-row, high priority
    if (comboA3) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    // Original official rule
    if ( eq(E,C) || eq(E,G) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Enhanced original rule. Practice: Beneficial for non-native pixel art, but harmful for native pixel art (JoJo's wall and clock)
    // if (sim_EC && sim_EG) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    En3 = eq_E_F && eq_E_H;

    if (En3) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Exclude "single stick" cases, including eq_E_I single bent stick cases
    if ( eq_E_F || eq_E_H ) return slopeBAD;
    // Exclude "three-cell unilateral wall" cases
    if ( eq_A_B&&eq_B_C || eq_A_D&&eq_D_G ) return slopeBAD;
    // F-H inline trend, placed after the three-cell unilateral wall rule as it might be blocked by it
    if ( eq(F,H) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Exclude "two-cell unilateral wall" cases, merged with next rule
    //if (eq_A_B||eq_A_D) return slopeBAD;
    // The rest are single pixels that are similar within sim2 range but have no logic, so use weak mixing??? Just give up!
    return slopeBAD;
} // B != D

	//pre-cal B == D
    bool eq_E_C = eq(E,C);
    bool eq_E_G = eq(E,G);
	bool sim_EC = eq_E_C || sim2(E,C);
	bool sim_EG = eq_E_G || sim2(E,G);

	bool ThickBorder;

// Original main rule enhanced with sim
if ( (sim_EC || sim_EG) && !eq_E_A ){

	eq_A_B = eq(A,B);
	eq_B_P = eq(B,P);
    eq_B_PC = eq(B,PC);
	eq_D_Q = eq(D,Q);
    eq_D_QG = eq(D,QG);

	linkB1 = eq_B_PC;
	linkB2 = eq_B_P;
	linkD1 = eq_D_QG;
	linkD2 = eq_D_Q;

	// B + D + their respective extension forms, highest priority. Initial screening.
	// Practice: Need to add the !eq_A_B case (E side is continuous step edge, opposite side is black background)
	if ( (linkB1||linkB2)&&!eq_B_C && (linkD1||linkD2)&&!eq_D_G && !eq_A_B ) return X +slopEND;

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
	comboA3 = eq_A_P && eq_A_Q;
	mixok = mixcheck(X,E);

	// A-side three-in-a-row, high priority
    if (comboA3) {
		// If not border, copy directly
		if (!eq_A_B) return X + slopEND;
		// Disable mixing at border
		mixok=false;
	}

    // When A-side is border and A has a support on the diagonal (has thickness), copy without mixing.
    // Without thickness check, if D B A are the same, copying will add thickness at the edge, damaging the original design.
    // Exclude black, overly thick black borders affect appearance. Keep some transition near black edges, adding scanlines later gives better layering.
    ThickBorder = eq_A_B && (eq_A_P||eq_A_Q|| eq(A,AA)&&(eq(B,PA)||eq(D,QA)));
	if (ThickBorder && !Xisblack) mixok=false;

    // Original official rule
    if (eq_E_C || eq_E_G) return mixok ? mix(X,E,0.381966) : X;
    // Enhanced original rule
    if (sim_EC && sim_EG) return mixok ? mix(X,E,0.381966) : X;

    // En3 skip

    // F-H inline trend
    if ( eq(F,H) ) return mixok ? mix(X,E,0.381966) : X;

    // When one side is a wall, besides the official rule and inline trend, the opposite side needs sim, otherwise exit (exclude cases where the wall itself is similar to center E)
    if (eq_B_C && !sim_EG) return slopeBAD;
    if (eq_D_G && !sim_EC) return slopeBAD;

	BDlong = eq_B_C && eq_D_Q;
	DBlong = eq_D_G && eq_B_P;
    eq_E_F = eq(E,F);
    eq_E_H = eq(E,H);
    eq_E_I = eq(E,I);

	if ( BDlong ) {
		if (eq_D_QG) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		if (eq_E_F && !eq_E_I) return mixok ? mix(X,E,0.381966) : X;
		return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		}

	if ( DBlong ) {
		if (eq_B_PC) return mixok ? mix(X,E,0.381966) +slopEND : X+slopEND;
		if (eq_E_H && !eq_E_I) return mixok ? mix(X,E,0.381966) : X;
		return mixok ? mix(X,E,0.381966) +slopEND : X+slopEND;
		}

    //	Use A-side three-in-a-row again for faster return.
    if (comboA3) return X +slopEND;

	// Use B + D + their respective extension again, priority higher than L + single stick below
  	if ( (linkB1 || linkB2) && (linkD1 || linkD2) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    // If X E are Lv3 similar, can ignore the next two exit rules
    if ( sim3(X,E) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    // L-shaped corner (hollow corner) inner single stick, exit
    if (eq_A_B && !ThickBorder && !eq_E_I) {
	    if (eq_B_C && eq_E_F) return theEXIT;
	    if (eq_D_G && eq_E_H) return theEXIT;
	}

    // L-shaped corner (hollow corner) outer single stick, exit (corner connects inward, not outward)
	// Practice: Can avoid font edges being shaved (Cadillacs and Dinosaurs)
	if ( (linkB2 || linkD2) && (eq_E_F||eq_E_H) && !ThickBorder && !eq_E_I) return theEXIT;

    return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

} // sim2 base


/*===================================================
                    E - A Cross
  ===============================================zz */

if (eq_E_A) {

	// When judging cross (✕), have concepts of "region" and "trend". Conditions need tightening for different regions.

    // B D not connected to anything exit? Not needed here!!!
    // In some cases, connecting two separate pixels is abrupt. But in many cases, shapes are lost!
    //if ( !eq_B_C && !eq_B_P && !eq_B_PC && !eq_D_G && !eq_D_Q && !eq_D_QG ) return slopeBAD;

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    eq_E_I = eq(E, I);
    En3 = eq_E_F&&eq_E_H;
    En4square = En3 && eq_E_I;

	// Special shape: Square
	if ( En4square ) {
        if( noteq(G,H) && noteq(C,F)                      //  Independent clear 4-cell square / 6-cell rectangle (both sides satisfied)
		&& (eq(H,S) == eq(I,SI) && eq(F,R) == eq(I,RI)) ) return theEXIT;
        //else return mixok ? mix(X,E,0.381966) : X;    Note: Cannot return directly. Need to enter the checkerboard decision rule because the opposite shore might also be a square forming a bubble.
    }

    //  Special shape: Halftone dot pattern
	//	Practice 1: !eq_E_F, !eq_E_H Not using !sim, because it loses some shapes.
    //  Practice 2: Force mixing, otherwise shapes are lost. (Gouketsuji Ichizoku Matrimelee, Saturday Night Slam Masters)

	bool Eisblack = checkblack(E);
	mixok = mixcheck(X,E);

	//  1. Dot pattern center
    if ( eq_E_C && eq_E_G && eq_E_I && !eq_E_F && !eq_E_H ) {

		// Exit if center E is black (KOF96 power gauge, Punisher's belt) Avoid mixing when contrast is too high.
		if (Eisblack) return theEXIT;
		// Practice 1: Cannot catch black B point, B points entering here already satisfy the shape.
		//if (Xisblack) return testcolor2;
		// Option 1 layered pattern (eq_F_H occurrence 95%) + layered progression inside health bar, remaining 0.5 fallback mix
		// if (eq_F_H) return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
        // return mix(X, E, 0.5)+slopEND;
		// Final decision: unify.
		return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
	}

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
    eq_B_PA = eq(B,PA);

	//  2. Dot pattern edge
    if ( eq_A_P && eq_A_Q && eq(A,AA) && noteq(A,PA) && noteq(A,QA) )  {
		if (Eisblack) return theEXIT;

        // Layered progressive edge, use strong mixing
		if ( !eq_B_PA && eq(PA,QA) ) return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
        // Remainder 1. Perfect cross, must be dot pattern edge, use weak mixing.
        // Remainder 2. Fallback weak mixing
		return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;
		// Note: No need to specify health bar border cases separately.
	}

    eq_D_QA = eq(D,QA);
    eq_D_QG = eq(D,QG);
    eq_B_PC = eq(B,PC);

  //   3. Half dot pattern, usually shadow expression on contour edges, use weak mixing
	if ( eq_E_C && eq_E_G && eq_A_P && eq_A_Q &&
		(eq_B_PC || eq_D_QG) &&
		 eq_D_QA && eq_B_PA) {
		//if (Eisblack) return testcolor;

        return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;
		}

    //   4. Quarter dot pattern, prone to ugly pinky finger effect

	if ( eq_E_C && eq_E_G && eq_A_P
		 && eq_B_PA &&eq_D_QA && eq_D_QG
		 && eq_E_H
		) return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;

	if ( eq_E_C && eq_E_G && eq_A_Q
		 && eq_B_PA &&eq_D_QA && eq_B_PC
		 && eq_E_F
		) return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;


    // E-side three-in-a-row (must be after dot pattern)
    if ( eq_E_C && eq_E_G ) return X+slopEND;

    comboA3 = eq_A_P && eq_A_Q;

    // A-side three-in-a-row (must be after dot pattern) Since E-A are same, prefer mixing over direct copy
	if (comboA3) return mixok ? mix(X, E, 0.381966)+slopEND : X+slopEND;


    // B-D  part of long slope
	eq_B_P = eq(B,P);
	eq_D_Q = eq(D,Q);
	bool B_hori = eq_B_C && !eq_B_P;
	bool B_vert = eq_B_P && !eq_B_C;
	bool D_hori = eq_D_Q && !eq_D_G;
	bool D_vert = eq_D_G && !eq_D_Q;

    int scoreE = 0; int scoreB = 0; int scoreD = 0; int scoreZ = 0;


// E B D Zone Checkerboard Scoring Rule

//	E Zone
    if (En3) {
        scoreE += 1;
        if (B_hori || D_vert) scoreZ = 1;
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
        // Single stick
        if (eq_E_F ||eq_E_H) return theEXIT;
    }

    if ( eq(F,H) ) {
		scoreE += 1;
        if ( B_hori && eq(F,R) || D_hori && eq(G,H) || B_vert && eq(C,F) || D_vert && eq(H,S)) scoreZ = 1;
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

    return slopeBAD;

	}	// eq_E_A



/*=========================================================
                    F - H / -B - D- Extension New Rules
  ==================================================== zz*/

// This side is different from the sim side. Since the inner pixels mostly contrast with the surroundings without sim.
// Sometimes it's more like the opposite side of sim with B-D as the boundary, so the judgment rules are different from the sim side.

	eq_B_P = eq(B, P);
    eq_B_PC = eq(B, PC);
	eq_D_Q = eq(D, Q);
    eq_D_QG = eq(D, QG);

    // B D not connected to anything exit (Practice: Indeed needed)
    if ( !eq_B_C && !eq_B_P && !eq_B_PC && !eq_D_G && !eq_D_Q && !eq_D_QG ) return slopeBAD;

    eq_A_B = eq(A, B);
	eq_A_P = eq(A, P);
	eq_A_Q = eq(A, Q);

	mixok = mixcheck(X,E);
    ThickBorder = eq_A_B && (eq_A_P||eq_A_Q|| eq(A,AA)&&(eq(B,PA)||eq(D,QA)));

	if (ThickBorder && !Xisblack) mixok=false;

	linkB1 = eq_B_PC;
	linkB2 = eq_B_P;
	linkD1 = eq_D_QG;
	linkD2 = eq_D_Q;


	// B + D + their respective extension forms, highest priority. Initial screening.
	// Practice: Need to add the !eq_A_B case (E side is continuous step edge, opposite side is black background)
	if ( (linkB1||linkB2)&&!eq_B_C && (linkD1||linkD2)&&!eq_D_G && !eq_A_B ) return X +slopEND;

	comboA3 = eq_A_P && eq_A_Q;

	// A-side three-in-a-row, high priority
    if (comboA3) {
		// If not border, copy directly
		if (!eq_A_B) return X + slopEND;
		// Disable mixing at border
		mixok=false;
	}

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    eq_E_I = eq(E, I);
    En3 = eq_E_F&&eq_E_H;
    En4square = En3 && eq_E_I;
    bool sim_X_E = sim3(X,E);
    bool eq_G_H = eq(G, H);
    bool eq_C_F = eq(C, F);
    bool eq_H_S = eq(H, S);
    bool eq_F_R = eq(F, R);

    // Special shape: Independent clear 4-cell/6-cell rectangle
    // Practice: Detecting rectangles from this branch is necessary (edges of buildings, fonts)
	if ( En4square ) {  // This square detection needs to be after the previous rule
		if (sim_X_E) return mixok ? mix(X,E,0.381966) : X;
        if( !eq_G_H && !eq_C_F                      //  Independent clear 4-cell square / 6-cell rectangle (both sides satisfied)
		&& (eq_H_S == eq(I, SI) && eq_F_R == eq(I, RI)) ) return theEXIT;
        else return mixok ? mix(X,E,0.381966) : X;
    }

    // Triangle
 	if ( En3 ) {
		if (sim_X_E) return mixok ? mix(X,E,0.381966) : X;

        if (eq_H_S && eq_F_R) return theEXIT; // Both sides extended simultaneously (building edge)

        if (eq_A_B) return  X;
        // Inner bend
        if (eq_B_C || eq_D_G) return mixok ? mix(X,E,0.381966) : X;
        // Outer bend
        if (eq_B_P || eq_D_Q) return theEXIT;

        return mixok ? mix(X,E,0.381966) : X;
        // The last two rules are based on experience. Principle: When encountering a triangle, only blend the inner bend, leave the outer bend untouched (Double Dragon Jimmy's eyebrows)
		// Also, there are very few cases, purely derived from extensive testing.

	}

    // F - H
	if ( eq(F,H) ) {
    	if (sim_X_E) return mixok ? mix(X,E,0.381966) : X;
        // Principle: Peripheral same side forms extension shape
        if (eq_B_C && eq_F_R) return mixok ? mix(X,E,0.381966) : X;
        if (eq_D_Q && eq_G_H) return mixok ? mix(X,E,0.381966) : X;
        if (eq_B_P && eq_C_F) return mixok ? mix(X,E,0.381966) : X;
        if (eq_D_G && eq_H_S) return mixok ? mix(X,E,0.381966) : X;
		// B D long slope is already covered in the above 4, this is the last peripheral case: if not forming an extension shape, at least need a triangle.
        if ( (eq_B_C || eq_B_P) && (eq_D_Q || eq_D_G) && eq(F, I) ) return mixok ? mix(X,E,0.381966) : X;

        return slopeBAD;
	}

	BDlong = eq_B_C && eq_D_Q;
	DBlong = eq_D_G && eq_B_P;

// Filter out two long slopes (long slopes not caught by simE2 rule, cannot use here!)
	if ( BDlong ) {
		if (eq_D_QG) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		return theEXIT;
	}
	if ( DBlong ) {
		if (eq_B_PC) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		return theEXIT;
	}
    //	Use A-side three-in-a-row again for faster return.
    if (comboA3) return X+slopEND;

    // Can X E similarity override all rules below and return directly???
    if (sim_X_E) return mixok ? mix(X,E,0.381966) : X;

	// Use B + D + their respective extension again, priority higher than L + single stick below
  	if ( (linkB1 || linkB2) && (linkD1 || linkD2) ) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

    // L-shaped corner (hollow corner) inner single stick, exit
    if (eq_A_B && !eq_E_I) {

	    if (eq_B_C && eq_E_F) return theEXIT;
	    if (eq_D_G && eq_E_H) return theEXIT;
	}

    // L-shaped corner (hollow corner) outer single stick, exit (corner connects inward, not outward)
	// Practice: Can avoid font edges being shaved (Cadillacs and Dinosaurs)
	if ( (linkB2 || linkD2) && (eq_E_F||eq_E_H) && !eq_E_I) return theEXIT;

    // Finally use B or D extension rule for screening, tighten rules
	linkB1 =  eq_B_PC && !eq_B_C  && (!eq_C_F||eq(F,RC));
	linkD1 =  eq_D_QG && !eq_D_G  && (!eq_G_H||eq(H,SG));

  	if ( (linkB1 || linkD1 )&& !eq_A_B ) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

	return slopeBAD;

}	// admixX


////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main()
{
   vec3 E = src(0, 0);

   vec3 A = src(-1, -1);
   vec3 B = src(+0, -1);
   vec3 C = src(+1, -1);
   vec3 D = src(-1, +0);
   vec3 F = src(+1, +0);
   vec3 G = src(-1, +1);
   vec3 H = src(+0, +1);
   vec3 I = src(+1, +1);

// Boundary check, check and copy the 4 adjacent pixels (excessive copying damages shapes, RA out-of-bounds adds extra row/column of black pixels)

   vec2 tcB = vTexCoord + vec2(0., -1.) * params.SourceSize.zw;
   if (!isInBounds(tcB)) B = E;

   vec2 tcD = vTexCoord + vec2(-1., 0.) * params.SourceSize.zw;
   if (!isInBounds(tcD)) D = E;

   vec2 tcF = vTexCoord + vec2(1., 0.) * params.SourceSize.zw;
   if (!isInBounds(tcF)) F = E;

   vec2 tcH = vTexCoord + vec2(0., 1.) * params.SourceSize.zw;
   if (!isInBounds(tcH)) H = E;

// Default to nearest-neighbor upscaling
   vec3 J = E;
   vec3 K = E;
   vec3 L = E;
   vec3 M = E;

// Place this statement here so we can use an early return in the next line to save some cycle time
   FragColor = vec4(E, 1.0);

// Skip entire 3x3 blocks of same color
// Provides good speedup for sprite sheets with large fills and areas with large constant regions (like sky)
//if(eq(E,A) && eq(E,B) && eq(E,C) && eq(E,D) && eq(E,F) && eq(E,G) && eq(E,H) && eq(E,I)) return;

   bool eq_E_B = eq(E,B);
   bool eq_E_D = eq(E,D);
   bool eq_E_F = eq(E,F);
   bool eq_E_H = eq(E,H);

// New skip acceleration, skip if three consecutive pixels horizontally or vertically are equal.
if ( eq_E_D&&eq_E_F || eq_E_B&&eq_E_H ) return;

	// Move the penultimate statement up here
	vec2 a = fract(vTexCoord * params.SourceSize.xy);

// Precompute luma
   float Bl = luma(B);
   float Dl = luma(D);
   float El = luma(E);
   float Fl = luma(F);
   float Hl = luma(H);

// Extend 3x3 grid to 4 edges                  [P]
   vec3 P  = src(+0, -2); //       A B C
   vec3 Q  = src(-2, +0); //    [Q]D E F[R]
   vec3 R  = src(+2, +0); //       G H I
   vec3 S  = src(+0, +2); //        [S]

// Extend further to 5x5
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

	// other side
   bool eq_B_H = eq(B,H);
   bool eq_D_F = eq(D,F);

    bool slopeBAD = false;  bool slopEND = false;
//        .------------------- 1st ---------------------.      .---- New ----.      .-------- 3rd ----------.        .~~~~~New Pocket Rule------ 4th ------------.         .------------------------ 5th ----------------------------.
    // B - D
    bool slope1 = false;
	if ( (!eq_E_B&&!eq_E_D) && (!eq_D_H&&!eq_D_F && !eq_B_H&&!eq_B_F) && (El>=Dl&&El>=Bl || eq(E,A)) && ( (El<Dl&&El<Bl) || none_eq2(A,B,D) || noteq(E,P) || noteq(E,Q) ) && ( eq_B_D&&(eq_F_H||eq(E,A)||eq(B,PC)||eq(D,QG)) || sim1(B,D)&&(sim2(E,C)||sim2(E,G)) ) ) {
		J=admixX(A,B,C,D,E,F,G,H,I,P,PA,PC,Q,QA,QG,R,RC,RI,S,SG,SI,AA);
		if (J.b > 1.0 ) {
            if (J.b > 30.0 ) {J=J-33.0; slopEND=true;}
			if (J.b == 8.0 ) return;
			if (J.b == 2.0 ) {slopeBAD=true; J=E;}
		} else slope1 = true;
	}
    // B - F
    bool slope2 = false;
	if ( (!eq_E_B&&!eq_E_F) && (!eq_B_D&&!eq_B_H && !eq_D_F&&!eq_F_H) && (El>=Bl&&El>=Fl || eq(E,C)) && ( (El<Bl&&El<Fl) || none_eq2(C,B,F) || noteq(E,P) || noteq(E,R) ) && ( eq_B_F&&(eq_D_H||eq(E,C)||eq(B,PA)||eq(F,RI)) || sim1(B,F)&&(sim2(E,A)||sim2(E,I)) ) )  {
		K=admixX(C,F,I,B,E,H,A,D,G,R,RC,RI,P,PC,PA,S,SI,SG,Q,QA,QG,CC);
		if (K.b > 1.0 ) {
            if (K.b > 30.0 ) {K=K-33.0; slopEND=true;}
			if (K.b == 8.0 ) return;
			if (K.b == 2.0 ) {slopeBAD=true; K=E;}
		} else {slope2 = true;slopeBAD = false;}
	}
    // D - H
    bool slope3 = slope1;
	if ( !slope1 && (!eq_E_D&&!eq_E_H)  &&  (!eq_F_H&&!eq_B_H && !eq_D_F&&!eq_B_D) && (El>=Hl&&El>=Dl || eq(E,G))  &&  ((El<Hl&&El<Dl) || none_eq2(G,D,H) || noteq(E,S) || noteq(E,Q))  &&  ( eq_D_H&&(eq_B_F||eq(E,G)||eq(D,QA)||eq(H,SI)) || sim1(D,H) && (sim2(E,A)||sim2(E,I)) ) )  {
		L=admixX(G,D,A,H,E,B,I,F,C,Q,QG,QA,S,SG,SI,P,PA,PC,R,RI,RC,GG);
		if (L.b > 1.0 ) {
            if (L.b > 30.0 ) {L=L-33.0; slopEND=true;}
			if (L.b == 8.0 ) return;
			if (L.b == 2.0 ) {slopeBAD=true; L=E;}
		} else {slope3 = true;slopeBAD = false;}
	}
    // F - H
    bool slope4 = slope2;
	if ( !slope2 && (!eq_E_F&&!eq_E_H)  &&  (!eq_B_F&&!eq_D_F && !eq_B_H&&!eq_D_H) && (El>=Fl&&El>=Hl || eq(E,I))  &&  ((El<Fl&&El<Hl) || none_eq2(I,F,H) || noteq(E,R) || noteq(E,S))  &&  ( eq_F_H&&(eq_B_D||eq(F,RC)||eq(H,SG)||eq(E,I)) || sim1(F,H) && (sim2(E,C)||sim2(E,G)) ) )  {
		M=admixX(I,H,G,F,E,D,C,B,A,S,SI,SG,R,RI,RC,Q,QG,QA,P,PC,PA,II);
		if (M.b > 1.0 ) {
            if (M.b > 30.0 ) {M=M-33.0; slopEND=true;}
			if (M.b == 8.0 ) return;
			if (M.b == 2.0 ) {slopeBAD=true; M=E;}
		} else {slope4 = true;slopeBAD = false;}
	}

if (slopEND) {
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
	return;
}

	bool slope = slope1 || slope2 || slope3 || slope4;

//  long gentle 2:1 slope  (P100) and saw-tooth slope

	bool longslope1 = false; bool longslope2 = false; bool longslope3 = false; bool longslope4 = false; bool sawslope = false;

	if (!eq_B_H) { // horizontal

		if (!eq_E_H && none_eq2(H,A,C)) {

			//                                    A B C .
			//                                  Q D 🄴 🅵 🆁       Zone 4
			//					                  🅶 🅷 I
			//					                    S
			// (!slope3 && !eq_D_H) This combination is better than direct !sim_D_H, catches more shapes that are "close but different, failed the main slope rule for some reason"
			if ( (!slope3 && !eq_D_H) && noteq(R, RC)) {	// H ≠ RC replaced because H = R
                if (slope4) {	// Divert based on current main slope formation marker
                    // Original rule extension 1. Pass adjacent pixel for comparison to ensure no double mixing.
                    // Original rule extension 2. L-shape cannot appear again within the two-pixel gap on the opposite side.
                    if (eq_F_H && eq(G,H) && eq(F,R) && (noteq(Q,G)||eq(Q, QA))) {L=admixL(M,L,H); longslope4 = true;}
                    // Practice: Finally decided to replace !sim_F_H with !eq_F_H (because added any_eq3(I,H,S,SG) condition)
                    // Practice 2: E cannot equal I, otherwise it forms bubbles with the F side!
					// sim2(E,B) prevents single-pixel E from being too突兀 when锯齿插入.
                } else if (!eq_F_H && !eq_B_F && !eq_E_F && noteq(E,I) && none_eq2(F,C,I) && (eq_B_D&&eq(B,C)&&sim2(E,B) || eq_E_D&&(eq(E,C)||eq(H,I)||eq(I,S)&&eq(I,RI))) && (noteq(R, RI)||eq(R,I)) && eq(R,H) && eq(F,G) && noteq(G,SG)) {M=F; sawslope = true;}

			}
			//                                  . A B C
			//                                  🆀 🅳 🄴 F R       Zone 3
			//                                    G 🅷 🅸
			//					                    S
			if ( (!longslope4 && !sawslope) && (!slope4 && !eq_F_H) && noteq(Q, QA) ) {	// H ≠ QA replaced because H = Q next
                if (slope3) {
                    if (eq_D_H && eq(D,Q) && eq(H,I) && (noteq(R,I)||eq(R, RC))) {M=admixL(L,M,H); longslope3 = true;}
                } else if (!eq_D_H && !eq_B_D && !eq_E_D && noteq(E,G) && none_eq2(D,A,G) && (eq_B_F&&eq(B,A)&&sim2(E,B) || eq_E_F&&(eq(E,A)||eq(H,G)||eq(G,S)&&eq(G,QG))) && (noteq(Q, QG)||eq(Q,G)) && eq(Q,H) && eq(D,I) && noteq(I,SI)) {L=D; sawslope = true;}
			}
		}

		if ( (!sawslope) && !eq_E_B && none_eq2(B,G,I)) {

			//					                    P
			//                                    🅐 🅑 C
			//                                  Q D 🄴 🅵 🆁       Zone 2
			//                                    G H I .
			if ( (!longslope4) && (!slope1 && !eq_B_D) && noteq(R, RI)) {	// B ≠ RI replaced because B = R next
				if (slope2) {
					if (eq_B_F && eq(A,B) && eq(F,R) && (noteq(A,Q)||eq(Q, QG))) {J=admixL(K,J,B); longslope2 = true;}
				} else if (!eq_B_F && !eq_F_H && !eq_E_F && noteq(E,C) && none_eq2(F,C,I) && (eq_D_H&&eq(H,I)&&sim2(E,H) || eq_E_D&&(eq(E,I)||eq(B,C)||eq(I,S)&&eq(I,RI)||eq(C,P)&&eq(C,RC))) && (noteq(R, RC)||eq(R,C)) && eq(B,R) && eq(A,F) && noteq(A,PA)) {K=F; sawslope = true;}
			}
			//					                    P
			//                                    A 🅑 🅲
			//                                  🆀 🅳 🄴 F R        Zone 1
			//                                  . G H I
			if ( (!longslope2 && !longslope3 && !sawslope) && (!slope2 && !eq_B_F) && noteq(Q, QG)) {	// B ≠ QG replaced
				if (slope1) {
					if (eq_B_D && eq(B,C) && eq(D,Q) && (noteq(C,R)||eq(R, RI))) {K=admixL(J,K,B); longslope1 = true;}
				} else if (!eq_B_D && !eq_D_H && !eq_E_D && noteq(E,A) && none_eq2(D,A,G) && (eq_F_H&&eq(H,G)&&sim2(E,H) || eq_E_F&&(eq(E,G)||eq(B,A)||eq(A,P)&&eq(A,QA))) && (noteq(Q, QA)||eq(Q,A)) && eq(B,Q) && eq(C,D) && noteq(C,PC)) {J=D; sawslope = true;}
			}
		}

    }

	bool longslope = longslope1||longslope2||longslope3||longslope4;
	longslope1 = false; longslope2 = false; longslope3 = false; longslope4 = false;	// reset

	if ( (!longslope && !sawslope) && !eq_D_F ) { // vertical

                       // E point is on the right
        if ( !eq_E_D && none_eq2(D,C,I) ) { // left

			//                                    🅐 B C
			//                                  Q 🅳 🄴 F R
			//                                    G 🅷 I        Zone 3
			//                                      🆂 .
            if ( (!slope1 && !eq_B_D) && noteq(S, SI) ) {	// D ≠ SI replaced
				if (slope3) {
					if(eq_D_H && eq(A,D) && eq(H,S) && (noteq(A,P)||eq(P, PC))) {J=admixL(L,J,D); longslope3 = true;}
				} else if (!eq_D_H && !eq_F_H && !eq_E_H && noteq(E,G) && none_eq2(H,G,I) && (eq_B_F&&eq(F,I)&&sim2(E,F) || eq_E_B&&(eq(E,I)||eq(D,G)||eq(G,Q)&&eq(G,SG))) && (noteq(S, SG)||eq(S,G)) && eq(D,S) && eq(A,H) && noteq(A,QA)) {L=H; sawslope = true;}
            }
			//                                      🅟 .
			//                                    A 🅑 C
			//                                  Q 🅳 🄴 F R       Zone 1
			//                                    🅶 H I
			if ( (!longslope3 && !sawslope) && (!slope3 && !eq_D_H) && noteq(P, PC) ) {	// D ≠ PC replaced
				if (slope1) {
					if (eq_B_D && eq(D,G) && eq(B,P) && (noteq(G,S)||eq(S, SI))) {L=admixL(J,L,D); longslope1 = true;}
				} else if (!eq_B_D && !eq_B_F && !eq_E_B && noteq(E,A) && none_eq2(B,A,C) && (eq_F_H&&eq(F,C)&&sim2(E,H) || eq_E_H&&(eq(E,C)||eq(D,A)||eq(A,Q)&&eq(A,PA))) && (noteq(P, PA)||eq(P,A)) && eq(P,D) && eq(B,G) && noteq(G,QG)) {J=B; sawslope = true;}
			}

		}

		if ( (!sawslope) && !eq_E_F && none_eq2(F,A,G) ) { // right

			//                                    A B 🅲
			//                                  Q D 🄴 🅵 R
			//                                    G 🅷 I        Zone 4
			//                                    . 🆂
			if ( (!longslope3) && (!slope2 && !eq_B_F) && noteq(S, SG)) {	// F ≠ SG replaced
				if (slope4) {
					if (eq_F_H && eq(C,F) && eq(H,S) && (noteq(P,C)||eq(P, PA))) {K=admixL(M,K,F); longslope4 = true;}
				} else if (!eq_F_H && !eq_D_H && !eq_E_H && noteq(E,I) && none_eq2(H,G,I) && (eq_B_D&&eq(D,G)&&sim2(E,D) || eq_E_B&&(eq(E,G)||eq(F,I)||eq(I,R)&&eq(I,SI))) && (noteq(S, SI)||eq(S,I)) && eq(S,F) && eq(H,C) && noteq(C,RC)) {M=H; sawslope = true;}
			}
			//                                    . 🅟
			//                                    A 🅑 C
			//                                  Q D 🄴 🅵 R        Zone 2
			//                                    G H 🅸
			if ( (!longslope1 && !longslope4 && !sawslope) && (!slope4 && !eq_F_H) && noteq(P, PA)) {	// F ≠ PA replaced
				if (slope2) {
					if (eq_B_F && eq(F,I) && eq(B,P) && (noteq(I,S)||eq(S, SG))) {M=admixL(K,M,F); longslope2 = true;}
			 		 // B -> K
				} else if (!eq_B_F && !eq_B_D && !eq_E_B && noteq(E,C) && none_eq2(B,A,C) && (eq_D_H&&eq(D,A)&&sim2(E,D) || eq_E_H&&(eq(E,A)||eq(F,C)||eq(C,R)&&eq(C,PC))) && (noteq(P, PC)||eq(P,C)) && eq(P,F) && eq(B,I) && noteq(I,RI)) {K=B; sawslope = true;}
			}
		}
	} // F ≠ D

longslope = longslope||longslope1||longslope2||longslope3||longslope4;

if (slopeBAD||longslope||sawslope) {
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
	return;
}

/**************************************************
 *     "Concave + Cross" shaped (P100)	  *
 *************************************************/
//  Cross star distant end uses approximate pixels, useful for some horizontal line + jigsaw and layered gradient shapes. e.g., SFIII 3rd Strike intro glowing text, SFZ3Mix Japanese houses, Garou: Mark of the Wolves intro.
bool cnc = false;
    if (!slope3 && !slope4 &&
        Bl<El && !eq_E_D && !eq_E_F && eq_E_H && none_eq2(E,A,C) && all_eq2(G,H,I) && sim1(E,S) ) { // TOP
	    if (eq_B_D && eq_B_F) {
            J=admixK(B,J); K=J;
            L=mix(J,L, 0.61804); M=L;
        } else {
            if (!slope1) J=admixC(D,B,J);
            if (!slope2) K=admixC(B,F,K);
            }
	   cnc = true;
	}
    if (!slope1 && !slope2 && !cnc &&
		Hl<El && !eq_E_D && !eq_E_F && eq_E_B && none_eq2(E,G,I) && all_eq2(A,B,C) && sim1(E,P) ) { // BOTTOM
	    if (eq_D_H && eq_F_H) {
            L=admixK(H,L); M=L;
            J=mix(L,J, 0.61804); K=J;
        } else {
            if (!slope3) L=admixC(D,H,L);
            if (!slope4) M=admixC(F,H,M);
            }
	   cnc = true;
	}
    if (!slope1 && !slope3 && !cnc &&
		Fl<El && !eq_E_B && !eq_E_H && eq_E_D && none_eq2(E,C,I) && all_eq2(A,D,G) && sim1(E,Q) ) { // RIGHT
        if (eq_B_F && eq_F_H) {
            K=admixK(F,K); M=K;
            J=mix(K,J, 0.61804); L=J;
        } else {
            if (!slope2) K=admixC(B,F,K);
            if (!slope4) M=admixC(F,H,M);
            }
	   cnc = true;
	}
    if (!slope2 && !slope4 && !cnc &&
		Dl<El && !eq_E_B && !eq_E_H && eq_E_F && none_eq2(E,A,G) && all_eq2(C,F,I) && sim1(E,R) ) { // LEFT
        if (eq_B_D && eq_D_H) {
            J=admixK(D,J); L=J;
            K=mix(J,K, 0.61804); M=K;
        } else {
            if (!slope1) J=admixC(D,B,J);
            if (!slope3) L=admixC(D,H,L);
            }
	   cnc = true;
	}

if (slope||cnc) {
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
	return;
}

/*
       ㇿО
     ОООㇿ
	   ㇿО    Scorpion shape (P99). Looks like the tracking bug from The Matrix. Can resolve some regular interleaved pixels.
*/
// Practice: 1. Scorpion pincers use approximation, otherwise easy to turn to a little C-type, and cause graphic glitches.
// Practice: 2. Remove one segment from the scorpion tail to catch more shapes.
// Among the four shapes, only the scorpion is exclusive. Once caught by previous rules (entered), this shape won't appear. Also the least noticeable shape. So placed last.

bool scorpion = false;
                if (!eq_E_F &&eq_E_D&&eq_B_F&&eq_F_H && all_eq2(E,C,I) && noteq(F,src(+3, 0)) ) {K=admixK(F,K); M=K;J=mix(K,J, 0.61804); L=J;scorpion=true;}	// RIGHT
   if (!scorpion && !eq_E_D &&eq_E_F&&eq_B_D&&eq_D_H && all_eq2(E,A,G) && noteq(D,src(-3, 0)) ) {J=admixK(D,J); L=J;K=mix(J,K, 0.61804); M=K;scorpion=true;}	// LEFT
   if (!scorpion && !eq_E_H &&eq_E_B&&eq_D_H&&eq_F_H && all_eq2(E,G,I) && noteq(H,src(0, +3)) ) {L=admixK(H,L); M=L;J=mix(L,J, 0.61804); K=J;scorpion=true;}	// BOTTOM
   if (!scorpion && !eq_E_B &&eq_E_H&&eq_B_D&&eq_B_F && all_eq2(E,A,C) && noteq(B,src(0, -3)) ) {J=admixK(B,J); K=J;L=mix(J,L, 0.61804); M=L;}					// TOP

// Determine which of our 4 output pixels we need to use
   FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
}
