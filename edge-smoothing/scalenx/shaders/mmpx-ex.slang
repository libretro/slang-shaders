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

 // Switch to CRT-era BT.601 standard - only affects luma decision mechanism
float luma(vec3 col){
   return dot(col, vec3(0.299, 0.587, 0.114));
   //return dot(col, vec3(0.3333333)); // RGB average
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

    // 1. Quick component difference check
    if ( diff.r > 0.145898 || diff.g > 0.145898 || diff.b > 0.145898 ) return false;

    // 2. Fast filter for same pixels and very dark/bright pixels after clamping
    vec3 clampCol1 = clamp(col1, vec3(0.078),vec3(0.92));
    vec3 clampCol2 = clamp(col2, vec3(0.078),vec3(0.92));
    vec3 clampdiff = clampCol1 - clampCol2;
    vec3 absclampdiff = abs(clampdiff);
    if ( absclampdiff.r < 0.05572809 && absclampdiff.g < 0.021286 && absclampdiff.b < 0.05572809 ) return true;

    float dotdist = 0.00931686;			// 3x short golden ratio of Euclidean distance
	if (Lv==2) dotdist = 0.024391856;	// 2x short golden ratio + 1x golden ratio of Euclidean distance
	if (Lv==3) dotdist = 0.0638587;		// 3x short golden ratio of Euclidean distance

    // 3. Quick squared distance check
	float dot_diff = dot(diff, diff);
    if (dot_diff > dotdist) return false;

	// 4. Re-check with opposite channels added to squared distance
	float teamA = 0.0;
	float teamB = 0.0;

	if (clampdiff.r > 0.0) teamA += absclampdiff.r; else teamB += absclampdiff.r;
	if (clampdiff.g > 0.0) teamA += absclampdiff.g; else teamB += absclampdiff.g;
	if (clampdiff.b > 0.0) teamA += absclampdiff.b; else teamB += absclampdiff.b;
	float team = min(teamA,teamB);
	// Testing shows at least 3x opposite channel value is needed (+1x draws, +2x creates increasing trend)
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

    // 1. Quick component difference check
    if ( absdiff.r > 0.618034 || absdiff.g > 0.618034 || absdiff.b > 0.618034 ) return false;
    // Quick filter for similar pixels (0.4377 divided by 6 then sqrt max can be 0.27)
    if ( absdiff.r < 0.27 && absdiff.g < 0.27 && absdiff.b < 0.27 ) return true;

    // 3. Quick squared distance check
	float dot_diff = dot(diff, diff);
    if (dot_diff > 0.4377) return false;

	// 4. Re-check with opposite channels added to squared distance
	float teamA = 0.0;
	float teamB = 0.0;

	if (diff.r > 0.0) teamA += absdiff.r; else teamB += absdiff.r;
	if (diff.g > 0.0) teamA += absdiff.g; else teamB += absdiff.g;
	if (diff.b > 0.0) teamA += absdiff.b; else teamB += absdiff.b;
	float team = min(teamA,teamB);
	// Testing shows at least 3x opposite channel value is needed (+1x draws, +2x creates increasing trend)
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
//const vec3 testcolor = vec3(1.0, 0.0, 1.0);  // Purple
//const vec3 testcolor2 = vec3(0.0, 1.0, 1.0);  // Cyan
//const vec3 testcolor3 = vec3(1.0, 1.0, 0.0);  // Yellow
//const vec3 testcolor4 = vec3(1.0, 1.0, 1.0);  // White


// pin zz   "Concave + Cross" type Weak blending (Weak mix/None)
vec3 admixC(vec3 X1, vec3 X2, vec3 E) {

    // Bilateral black clamping case return? Not necessary, E will also be dark in mixable cases
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

// K-type Forced weak blending (Weak mix/Weaker)
vec3 admixK(vec3 X, vec3 E) {

	bool mixok = mixcheck(X, E);

	return mixok ? mix(X, E, 0.618034) : mix(X, E, 0.8541);

}

// L-type 2:1 slope  Main corner extension
// Practice: This rule requires all 4 pixels on the strict slope to be identical. Otherwise various glitches occur!
vec3 admixL(vec3 X, vec3 E, vec3 S) {

    //if (eq(X, E)) return E; // This original rule would catch many duplicate pixels, but becomes invalid after slopebad filtering

	// If target X and reference S(sample) are different, it means blending already occurred once, just copy target
	if (noteq(X, S)) return X;

	bool mixok = mixcheck(X, E);

    return mixok ? mix(X, E, 0.381966) : X;
}

/********************************************************************************************************************************************
 *               												main slope + X cross-processing mechanism					                *
 pin zz **********************************************************************************************************************************  */
vec3 admixX(vec3 A, vec3 B, vec3 C, vec3 D, vec3 E, vec3 F, vec3 G, vec3 H, vec3 I, vec3 P, vec3 PA, vec3 PC, vec3 Q, vec3 QA, vec3 QG, vec3 R, vec3 RC, vec3 RI, vec3 S, vec3 SG, vec3 SI, vec3 AA, float Bl, float Dl, float El) {

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
        // Bilateral straight wall clamping - exit
        if (eq_B_C && eq_D_G) return slopeBAD;
        X = B;
    } else {
        // E-A equal doesn't match preset logic, exit
        if (eq(E,A)) return slopeBAD;

        // D B not equal, and difference between them is large, greater than either side with center E, exit.
        float diffBD = abs(Bl-Dl);
        float diffEB = abs(El-Bl);
        float diffED = abs(El-Dl);
        if (diffBD > diffEB || diffBD > diffED) return slopeBAD;

        X = mix(B,D,0.5);
    }

	// Avoid opposite side compression when E is at black edge (for fonts with contrast over half)
	bool Bisblack = checkblack(B);
	// When BD not equal, can't use average to judge X black
	bool Xisblack = eq_B_D ? Bisblack : Bisblack&&checkblack(D);
    float Xl = eq_B_D ? Bl : (Bl+Dl)*0.5;
	if ( Xisblack && abs(El - Xl) >0.5 ) {

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

// B != D
if (!eq_B_D){


	eq_A_B = eq(A,B);
	eq_A_D = eq(A,D);

	// B D not equal (non-black), one side straight line, other side must be single pixel
	// Practice: avoids blending at parallel line corners where BD are each continuous
    if (!Xisblack){
        if ( eq_A_B && (eq_D_G||eq(D,Q)) ) return slopeBAD;
        if ( eq_A_D && (eq_B_C||eq(B,P)) ) return slopeBAD;
    }


    // B D three unconnected? Not applicable here (can eliminate some faults but also lose some forms, especially non-native pixel art like Double Dragon character portraits)

	// Treat black-like same as DB?
    // Practice: Special treatment for black easily causes glitches in dark areas (Samurai Shodown 2 Charlotte)
	//if (Xisblack) return X +slopEND;

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
	comboA3 = eq_A_P && eq_A_Q;
	mixok = mixcheck(X,E);

	// A-side three-star connection, high priority
    if (comboA3) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    // Official original rule
    if ( eq(E,C) || eq(E,G) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Enhanced original rule - Practice: beneficial for non-native pixel art but harmful for native pixel art (JoJo's wall and clock)
    // if (sim_EC && sim_EG) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    En3 = eq_E_F && eq_E_H;

    if (En3) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Exclude "single stick" cases, including eq_E_I bent stick cases
    if ( eq_E_F || eq_E_H ) return slopeBAD;
    // Exclude "three-grid unilateral wall" cases
    if ( eq_A_B&&eq_B_C || eq_A_D&&eq_D_G ) return slopeBAD;
    // F-H inner link trend, placed after three-grid unilateral wall rule since it would be blocked
    if ( eq(F,H) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;
    // Exclude "two-grid unilateral wall" cases, merged with next rule
    //if (eq_A_B||eq_A_D) return slopeBAD;
    // Remaining are single pixels with no logic but similar in sim2 range, so use weak mixing??? Just give up!
    return slopeBAD;
} // B != D

	//pre-cal B == D
    bool eq_E_A = eq(E,A);
    bool eq_E_C = eq(E,C);
    bool eq_E_G = eq(E,G);
	bool sim_EC = eq_E_C || sim2(E,C);
	bool sim_EG = eq_E_G || sim2(E,G);

	bool ThickBorder;

// Enhanced original main rule with sim
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

	// B + D + respective continuation form highest priority. Initial screening.
	// Practice: need to add !eq_A_B case (E side is continuous step edge, opposite side is black background)
	if ( (linkB1||linkB2)&&!eq_B_C && (linkD1||linkD2)&&!eq_D_G && !eq_A_B ) return X +slopEND;

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
	comboA3 = eq_A_P && eq_A_Q;
	mixok = mixcheck(X,E);

	// A-side three-star connection, high priority
    if (comboA3) {
		// Non-border direct copy
		if (!eq_A_B) return X + slopEND;
		// Border disable mixing
		mixok=false;
	}

    // When A-side is border, and A has a support on diagonal (has thickness), copy without mixing.
    // Without thickness detection, if D B A same then copy, will increase thickness at edges,destroy original design feel
    // Exclude black, too thick black borders affect appearance. Keep some transition near black edges,add scanlines later for better hierarchy.
    ThickBorder = eq_A_B && (eq_A_P||eq_A_Q|| eq(A,AA)&&(eq(B,PA)||eq(D,QA)));
	if (ThickBorder && !Xisblack) mixok=false;

    // Official original rule
    if (eq_E_C || eq_E_G) return mixok ? mix(X,E,0.381966) : X;
    // Enhanced original rule
    if (sim_EC && sim_EG) return mixok ? mix(X,E,0.381966) : X;

    // En3 skip

    // F-H inner link trend
    if ( eq(F,H) ) return mixok ? mix(X,E,0.381966) : X;

    // When one side is wall, besides official rule and inner link trend, need opposite side sim, otherwise exit (exclude cases where wall itself is similar to center E)
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

    //	Use A-side three-star connection again to accelerate return
    if (comboA3) return X +slopEND;

	// Use B + D + respective continuation capture again, priority above L + single stick
  	if ( (linkB1 || linkB2) && (linkD1 || linkD2) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    // X E Lv3 similar can ignore below two exit rules
    if ( sim3(X,E) ) return mixok ? mix(X,E,0.381966) +slopEND : X +slopEND;

    // L-type corner (hollow corner) inner single stick, exit
    if (eq_A_B && !ThickBorder && !eq_E_I) {
	    if (eq_B_C && eq_E_F) return theEXIT;
	    if (eq_D_G && eq_E_H) return theEXIT;
	}

    // L-type corner (hollow corner) outer single stick, exit (corner links inside not outside)
	// Practice: can avoid font edges being shaved (Captain Commando)
	if ( (linkB2 || linkD2) && (eq_E_F||eq_E_H) && !ThickBorder && !eq_E_I) return theEXIT;

    return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

} // sim2 base


/*===================================================
                    E - A Cross
  ===============================================zz */

if (eq_E_A) {

	// When judging cross ✕, need "area" and "trend" concepts. Different areas need tighter conditions.

    // B D three unconnected exit? Not needed here!!!
    // Sometimes two separate pixel connections are abrupt. But many cases lose form!
    //if ( !eq_B_C && !eq_B_P && !eq_B_PC && !eq_D_G && !eq_D_Q && !eq_D_QG ) return slopeBAD;

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    eq_E_I = eq(E, I);
    En3 = eq_E_F&&eq_E_H;
    En4square = En3 && eq_E_I;

	// Special form: Square
	if ( En4square ) {
        if( noteq(G,H) && noteq(C,F)                      //  Independent clear 4-grid square / 6-grid rectangle (both sides satisfy)
		&& (eq(H,S) == eq(I,SI) && eq(F,R) == eq(I,RI)) ) return theEXIT;
        //else return mixok ? mix(X,E,0.381966) : X;    Note: cannot return directly. Need to enter checkerboard decision rule because adjacent B, D areas might also form square bubbles
    }

    //  Special form: Halftone dot
	//	Practice 1: !eq_E_F，!eq_E_H not using !sim, because will lose some forms
    //  Practice 2: Force mixing, otherwise lose forms. (Gouketsuji Ichizoku horse, Saturday Night Slam Masters 2)

	bool Eisblack = checkblack(E);
	mixok = mixcheck(X,E);

	//  1. Halftone dot center
    if ( eq_E_C && eq_E_G && eq_E_I && !eq_E_F && !eq_E_H ) {

		// Center E is black exit (KOF96 power gauge, Punisher's belt) avoid too high contrast mixing
		if (Eisblack) return theEXIT;
		// Practice 1: cannot catch black B point, B points entering all satisfy form
		//if (Xisblack) return testcolor2;
		// Option 1 layered五花肉 (eq_F_H occurrence 95%) + progressive inside power gauge, remaining 0.5 fallback mixing
		// if (eq_F_H) return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
        // return mix(X, E, 0.5)+slopEND;
		// Final decision: unify
		return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
	}

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
    eq_B_PA = eq(B,PA);

	//  2. Halftone dot edge
    if ( eq_A_P && eq_A_Q && eq(A,AA) && noteq(A,PA) && noteq(A,QA) )  {
		if (Eisblack) return theEXIT;

        // Progressive layered edge, use strong mixing
		if ( !eq_B_PA && eq(PA,QA) ) return mixok ? mix(X, E, 0.381966)+slopEND : mix(X, E, 0.618034)+slopEND;
        // Remaining 1. Perfect cross, must be halftone dot edge, use weak mixing.
        // Remaining 2. Fallback weak mixing
		return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;
		// Note: no need to specify power gauge border cases separately.
	}

    eq_D_QA = eq(D,QA);
    eq_D_QG = eq(D,QG);
    eq_B_PC = eq(B,PC);

  //   3. Semi-halftone Usually shadow expression at contour edges, use weak mixing
	if ( eq_E_C && eq_E_G && eq_A_P && eq_A_Q &&
		(eq_B_PC || eq_D_QG) &&
		 eq_D_QA && eq_B_PA) {
		//if (Eisblack) return testcolor;

        return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;
		}

    //   4. Quarter halftone,easy to effect (ugly pinky finger effect)

	if ( eq_E_C && eq_E_G && eq_A_P
		 && eq_B_PA &&eq_D_QA && eq_D_QG
		 && eq_E_H
		) return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;

	if ( eq_E_C && eq_E_G && eq_A_Q
		 && eq_B_PA &&eq_D_QA && eq_B_PC
		 && eq_E_F
		) return mixok ? mix(X, E, 0.618034)+slopEND : mix(X, E, 0.8541)+slopEND;


    // E-side three-star connection (must be after halftone)
    if ( eq_E_C && eq_E_G ) return X+slopEND;

    comboA3 = eq_A_P && eq_A_Q;

    // A-side three-star connection (must be after halftone) Since E-A same, prefer mixing over direct copy
	if (comboA3) return mixok ? mix(X, E, 0.381966)+slopEND : X+slopEND;


    // B-D  part of long slope
	eq_B_P = eq(B,P);
	eq_D_Q = eq(D,Q);
	bool B_hori = eq_B_C && !eq_B_P;
	bool B_vert = eq_B_P && !eq_B_C;
	bool D_hori = eq_D_Q && !eq_D_G;
	bool D_vert = eq_D_G && !eq_D_Q;

    int scoreE = 0; int scoreB = 0; int scoreD = 0; int scoreZ = 0;


// E B D area checkerboard scoring rules

//	E Zone
    if (En3) {
        scoreE += 1;
        if (B_hori || B_vert || D_hori || D_vert) scoreZ = 1;
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
        if ( scoreZ==0 && B_hori && (eq(F,R) || eq(G,H) || eq(F,I)) ) scoreZ = 1;
        if ( scoreZ==0 && D_vert && (eq(C,F) || eq(H,S) || eq(F,I)) ) scoreZ = 1;
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

    // Final supplement: total score zero, B, D zones no deduction, forming long slope form
    if (scoreB >= 0 && scoreD >=0) {
        if (B_hori&&D_hori) return X;
        if (B_vert&&D_vert) return X;
    }

    return slopeBAD;

}	// eq_E_A



/*=========================================================
                    F - H / -B - D- Extension new rules
  ==================================================== zz*/

// This side is different from sim side. Since inner pixels mostly have high contrast with surroundings without sim.
// Sometimes more licky use B-D as boundary, sim's opponent side, so judgment rules differ from sim side.

	eq_B_P = eq(B, P);
    eq_B_PC = eq(B, PC);
	eq_D_Q = eq(D, Q);
    eq_D_QG = eq(D, QG);

    // B D three unconnected exit (Practice: indeed needed)
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


	// B + D + respective continuation form highest priority. Initial screening.
	// Practice: need to add !eq_A_B case (E side is continuous step edge, opposite side is black background)
	if ( (linkB1||linkB2)&&!eq_B_C && (linkD1||linkD2)&&!eq_D_G && !eq_A_B ) return X +slopEND;

	comboA3 = eq_A_P && eq_A_Q;

	// A-side three-star connection, high priority
    if (comboA3) {
		// Non-border direct copy
		if (!eq_A_B) return X + slopEND;
		// Border disable mixing
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

    // Special form: Independent clear 4-grid/6-grid rectangle
    // Practice: detecting rectangle from this branch is necessary (building, font edges)
	if ( En4square ) {  // This square detection needs to be after above rule
		if (sim_X_E) return mixok ? mix(X,E,0.381966) : X;
        if( !eq_G_H && !eq_C_F                      //  Independent clear 4-grid square / 6-grid rectangle (both sides satisfy)
		&& (eq_H_S == eq(I, SI) && eq_F_R == eq(I, RI)) ) return theEXIT;
        else return mixok ? mix(X,E,0.381966) : X;
    }

    // Triangle
 	if ( En3 ) {
		if (sim_X_E) return mixok ? mix(X,E,0.381966) : X;

        if (eq_H_S && eq_F_R) return theEXIT; // Both sides extended simultaneously (building edges)
		// Has thickness return directly (can balance below outer bend, equivalent to Z-shaped outer)
        if (eq_A_B) return mixok ? mix(X,E,0.381966) : X;
        // Inner bend
        if (eq_B_C || eq_D_G) return mixok ? mix(X,E,0.381966) : X;
        // Outer bend
        if (eq_B_P || eq_D_Q) return theEXIT;

        return mixok ? mix(X,E,0.381966) : X;
        // Last two rules based on experience, principle: connect L inner bend not L outer (Double Dragon Jimmy's eyebrow)
	}

    // F - H
	// Principle: connect L inner bend not L outer
	// Practice: E single pixel better to use long slope rule following.
	if ( eq(F,H) ) {
    	if (sim_X_E) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        // Avoid bilateral symmetric full clamping squeezing single pixel
		if ( eq_B_C && eq_A_B && eq_G_H &&eq(F, I) ) return theEXIT;
		if ( eq_D_G && eq_A_B && eq_C_F &&eq(F, I) ) return theEXIT;
		//Inner bend
        if (eq_B_C && (eq_F_R||eq_G_H||eq(F, I))) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        if (eq_D_G && (eq_C_F||eq_H_S||eq(F, I))) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		// E-I F-H cross destroy trend
		if (eq_E_I) return slopeBAD;
        // Z-shaped outer
		if (eq_B_P && eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        if (eq_D_Q && eq_A_B) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		// Outer bend unless opposite side forms long L trend
		if (eq_B_P && (eq_C_F&&eq_H_S)) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
        if (eq_D_Q && (eq_F_R&&eq_G_H)) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

        return slopeBAD;
	}

	BDlong = eq_B_C && eq_D_Q;
	DBlong = eq_D_G && eq_B_P;

	// Clean up two long slopes (long slopes not caught by early simE2 rules and above three forms, cannot use here!)
	if ( BDlong ) {
		if (eq_D_QG) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		return theEXIT;
	}
	if ( DBlong ) {
		if (eq_B_PC) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;
		return theEXIT;
	}
    //	Use A-side three-star connection again to accelerate return
    if (comboA3) return X+slopEND;

    // X E similar can ignore all rules below and return directly???
    if (sim_X_E) return mixok ? mix(X,E,0.381966) : X;

	// Use B + D + respective continuation capture again, priority above L + single stick
  	if ( (linkB1 || linkB2) && (linkD1 || linkD2) ) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

    // L-type corner (hollow corner) inner single stick, exit
    if (eq_A_B && !eq_E_I) {

	    if (eq_B_C && eq_E_F) return theEXIT;
	    if (eq_D_G && eq_E_H) return theEXIT;
	}

    // L-type corner (hollow corner) outer single stick, exit (corner links inside not outside)
	// Practice: can avoid font edges being shaved (Captain Commando)
	if ( (linkB2 || linkD2) && (eq_E_F||eq_E_H) && !eq_E_I) return theEXIT;

    // Finally use B or D extension rules screening, rules tightened
	linkB1 =  eq_B_PC && !eq_B_C  && (!eq_C_F||eq(F,RC));
	linkD1 =  eq_D_QG && !eq_D_G  && (!eq_G_H||eq(H,SG));

  	if ( (linkB1 || linkD1 )&& !eq_A_B ) return mixok ? mix(X,E,0.381966)+slopEND : X+slopEND;

	return slopeBAD;

}	// admixX


////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main()
{
   vec3 E = src(0, 0);
// Preset for quick return
   FragColor = vec4(E, 1.0);

// Default to nearest neighbor scaling
    vec3 J = E;    vec3 K = E;    vec3 L = E;    vec3 M = E;

    vec3 D = src(-1, +0);
    vec3 F = src(+1, +0);
    bool eq_E_D = eq(E,D);
    bool eq_E_F = eq(E,F);

// Skip same color horizontal 3x1 block
if ( eq_E_D && eq_E_F ) return;

    vec3 B = src(+0, -1);
    vec3 H = src(+0, +1);
    bool eq_E_B = eq(E,B);
    bool eq_E_H = eq(E,H);

// Skip same color vertical 3x1 block
if ( eq_E_B && eq_E_H ) return;

   bool eq_B_H = eq(B,H);
   bool eq_D_F = eq(D,F);

// Skip mirrored blocks surrounding center point
if ( eq_B_H && eq_D_F ) return;


    // ------------------------ Boundary Detection --------------------------
    // Define an impossible fake pixel
    const vec3 fakeColor = vec3(1.234);
    // 1. Pre-calculate integer coordinates of current pixel (uv → pixel coordinates, floor to get pixel index)
    vec2 pixelPos = vTexCoord * params.SourceSize.xy;
    ivec2 currPixel = ivec2(floor(pixelPos)); // Current pixel integer coordinates (0-based)
    ivec2 texSize = ivec2(params.SourceSize.xy); // Texture actual pixel dimensions

    // 2. Batch check four directions for out-of-bounds (integer judgment based on pixel coordinates, no float error)
    bool isBOutOfBounds = (currPixel.y - 1 < 0); // Top pixel out-of-bounds (y-1 < 0)
    bool isDOutOfBounds = (currPixel.x - 1 < 0); // Left pixel out-of-bounds (x-1 < 0)
    bool isFOutOfBounds = (currPixel.x + 1 >= texSize.x); // Right pixel out-of-bounds (x+1 >= width)
    bool isHOutOfBounds = (currPixel.y + 1 >= texSize.y); // Bottom pixel out-of-bounds (y+1 >= height)

    // 3. Assign fake color if out-of-bounds (no need for sequential judgment, batch process directly, reduce branches)
    if (isBOutOfBounds) B = fakeColor;
    if (isDOutOfBounds) D = fakeColor;
    if (isFOutOfBounds) F = fakeColor;
    if (isHOutOfBounds) H = fakeColor;
    // ----------------------------------------------------------------------

	// Second last line moved up for JLKM modification exit and reuse pixelPos
	//vec2 a = fract(vTexCoord * params.SourceSize.xy);
	vec2 a = fract(pixelPos);

// Pre-calculate luminance
   float Bl = luma(B);
   float Dl = luma(D);
   float El = luma(E);
   float Fl = luma(F);
   float Hl = luma(H);


   vec3 A = src(-1, -1);
   vec3 C = src(+1, -1);
   vec3 G = src(-1, +1);
   vec3 I = src(+1, +1);


// Extend 3x3 grid to 4 edges
   vec3 P  = src(+0, -2);
   vec3 Q  = src(-2, +0);
   vec3 R  = src(+2, +0);
   vec3 S  = src(+0, +2);

// Extend to 5x5
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

    // Any mirrored blocks surrounding center point
    bool oppoPix =  eq_B_H || eq_D_F;
	// Flag indicating entry into admixX function if caught by 1:1 slope rules
    bool slope1 = false;    bool slope2 = false;    bool slope3 = false;    bool slope4 = false;
	// Standard pixel正常 returned through 1:1 slope rules
    bool slope1ok = false;  bool slope2ok = false;  bool slope3ok = false;  bool slope4ok = false;
	// slopeBAD entered admixX but (at least one of JKLM) returned E point
    bool slopeBAD = false;  bool slopEND = false;

    // B - D
	if ( (!eq_E_B&&!eq_E_D&&!oppoPix) && (!eq_D_H&&!eq_B_F) && (El>=Dl&&El>=Bl || eq(E,A)) && ( (El<Dl&&El<Bl) || none_eq2(A,B,D) || noteq(E,P) || noteq(E,Q) ) && ( eq_B_D&&(eq_F_H||eq(E,A)||eq(B,PC)||eq(D,QG)) || sim1(B,D)&&(sim2(E,C)||sim2(E,G)) ) ) {
		J=admixX(A,B,C,D,E,F,G,H,I,P,PA,PC,Q,QA,QG,R,RC,RI,S,SG,SI,AA, Bl,Dl,El);
		slope1 = true;
		if (J.b > 1.0 ) {
            if (J.b > 30.0 ) {J=J-33.0; slopEND=true;}
			if (J.b == 8.0 ) return;
			if (J.b == 2.0 ) {slopeBAD=true; J=E;}
		} else slope1ok = true;
	}
    // B - F
	if ( !slope1 && (!eq_E_B&&!eq_E_F&&!oppoPix) && (!eq_B_D&&!eq_F_H) && (El>=Bl&&El>=Fl || eq(E,C)) && ( (El<Bl&&El<Fl) || none_eq2(C,B,F) || noteq(E,P) || noteq(E,R) ) && ( eq_B_F&&(eq_D_H||eq(E,C)||eq(B,PA)||eq(F,RI)) || sim1(B,F)&&(sim2(E,A)||sim2(E,I)) ) )  {
		K=admixX(C,F,I,B,E,H,A,D,G,R,RC,RI,P,PC,PA,S,SI,SG,Q,QA,QG,CC, Bl,Fl,El);
		slope2 = true;
		if (K.b > 1.0 ) {
            if (K.b > 30.0 ) {K=K-33.0; slopEND=true;}
			if (K.b == 8.0 ) return;
			if (K.b == 2.0 ) {slopeBAD=true; K=E;}
		} else {slope2ok = true;}
	}
    // D - H
	if ( !slope1 && (!eq_E_D&&!eq_E_H&&!oppoPix) && (!eq_F_H&&!eq_B_D) && (El>=Hl&&El>=Dl || eq(E,G))  &&  ((El<Hl&&El<Dl) || none_eq2(G,D,H) || noteq(E,S) || noteq(E,Q))  &&  ( eq_D_H&&(eq_B_F||eq(E,G)||eq(D,QA)||eq(H,SI)) || sim1(D,H) && (sim2(E,A)||sim2(E,I)) ) )  {
		L=admixX(G,D,A,H,E,B,I,F,C,Q,QG,QA,S,SG,SI,P,PA,PC,R,RI,RC,GG, Dl,Hl,El);
		slope3 = true;
		if (L.b > 1.0 ) {
            if (L.b > 30.0 ) {L=L-33.0; slopEND=true;}
			if (L.b == 8.0 ) return;
			if (L.b == 2.0 ) {slopeBAD=true; L=E;}
		} else {slope3ok = true;}
	}
    // F - H
	if ( !slope2 && !slope3 && (!eq_E_F&&!eq_E_H&&!oppoPix) && (!eq_B_F&&!eq_D_H) && (El>=Fl&&El>=Hl || eq(E,I))  &&  ((El<Fl&&El<Hl) || none_eq2(I,F,H) || noteq(E,R) || noteq(E,S))  &&  ( eq_F_H&&(eq_B_D||eq(F,RC)||eq(H,SG)||eq(E,I)) || sim1(F,H) && (sim2(E,C)||sim2(E,G)) ) )  {
		M=admixX(I,H,G,F,E,D,C,B,A,S,SI,SG,R,RI,RC,Q,QG,QA,P,PC,PA,II, Fl,Hl,El);
		slope4 = true;
		if (M.b > 1.0 ) {
            if (M.b > 30.0 ) {M=M-33.0; slopEND=true;}
			if (M.b == 8.0 ) return;
			if (M.b == 2.0 ) {slopeBAD=true; M=E;}
		} else {slope4ok = true;}
	}


//  long gentle 2:1 slope  (P100) and saw-tooth slope

	bool longslope = false;

    if (slope4ok && eq_F_H) { //zone4 long slope
        // Original rule extension 1. admixL third parameter passes adjacent pixel comparison to ensure no double blending
        // Original rule extension 2. No L form should appear again within opposite two pixel interval unless forming a wall
        if (eq(G,H) && eq(F,R) && noteq(R, RC) && (noteq(Q,G)||eq(Q, QA))) {L=admixL(M,L,H); longslope = true;}
        // virtical
		if (eq(C,F) && eq(H,S) && noteq(S, SG) && (noteq(P,C)||eq(P, PA))) {K=admixL(M,K,F); longslope = true;}
    }


    if (slope3ok && eq_D_H) { //zone3 long slope
        // horizontal
        if (eq(D,Q) && eq(H,I) && noteq(Q, QA) && (noteq(R,I)||eq(R, RC))) {M=admixL(L,M,H); longslope = true;}
        // virtical
		if (eq(A,D) && eq(H,S) && noteq(S, SI) && (noteq(A,P)||eq(P, PC))) {J=admixL(L,J,D); longslope = true;}
    }

    if (slope2ok && eq_B_F) { //zone2 long slope
        // horizontal
        if (eq(A,B) && eq(F,R) && noteq(R, RI) && (noteq(A,Q)||eq(Q, QG))) {J=admixL(K,J,B); longslope = true;}
        // virtical
		if (eq(F,I) && eq(B,P) && noteq(P, PA) && (noteq(I,S)||eq(S, SG))) {M=admixL(K,M,F); longslope = true;}
    }

    if (slope1ok && eq_B_D) { //zone1 long slope
        // horizontal
        if (eq(B,C) && eq(D,Q) && noteq(Q, QG) && (noteq(C,R)||eq(R, RI))) {K=admixL(J,K,B); longslope = true;}
        // virtical
		if (eq(D,G) && eq(B,P) && noteq(P, PC) && (noteq(G,S)||eq(S, SI))) {L=admixL(J,L,D); longslope = true;}
    }


// longslope formed can exit, basically no sawslope formed diagonally
if (longslope) {
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
	return;
}

bool sawslope = false;

bool slopeok = slope1ok||slope2ok||slope3ok||slope4ok;

// Note: sawslope cannot exclude slopEND (few) and slopeBAD (very few), but can exclude slopeok (strong form)
if (!oppoPix && !slopeok) {


        // horizontal bottom
		if (!eq_E_H && none_eq2(H,A,C)) {

			//                                    A B C .
			//                                  Q D 🄴 🅵 🆁       Zone 4
			//					                  🅶 🅷 I
			//					                    S
			// (!slope3 && !eq_D_H) Such combined use is clever
			if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H)  && !eq_F_H &&
                // Practice 1: E cannot equal I, otherwise will form bubbles with F branch!
				// Practice 2: sim E B(C) In accordance with the original logic
                 !eq_E_F && noteq(E,I) && none_eq2(F,C,I) &&
                 (eq_B_D&&eq(B,C)&&sim3(E,B) || eq_E_D&&(eq(E,C)||eq(H,I)||eq(I,S)&&eq(I,RI))) &&
                 eq(R,H) && eq(F,G) &&
                 (noteq(R, RI)||eq(R,I)) && noteq(R, RC) && noteq(G,SG)) {M=F; sawslope = true;}

			//                                  . A B C
			//                                  🆀 🅳 🄴 F R       Zone 3
			//                                    G 🅷 🅸
			//					                    S
			if ( !sawslope && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_D_H &&
                 !eq_E_D && noteq(E,G) && none_eq2(D,A,G) &&
                 (eq_B_F&&eq(B,A)&&sim3(E,B) || eq_E_F&&(eq(E,A)||eq(H,G)||eq(G,S)&&eq(G,QG))) &&
                 eq(Q,H) && eq(D,I) &&
                 (noteq(Q, QG)||eq(Q,G)) && noteq(Q, QA) && noteq(I,SI)) {L=D; sawslope = true;}

		}

        // horizontal up
		if ( !sawslope && !eq_E_B && none_eq2(B,G,I)) {

			//					                    P
			//                                    🅐 🅑 C
			//                                  Q D 🄴 🅵 🆁       Zone 2
			//                                    G H I .
			if ( (!slope1 && !eq_B_D)  && (!slope4 && !eq_F_H) && !eq_B_F &&
				  !eq_E_F && noteq(E,C) && none_eq2(F,C,I) &&
                  (eq_D_H&&eq(H,I)&&sim3(E,H) || eq_E_D&&(eq(E,I)||eq(B,C)||eq(C,P)&&eq(C,RC))) &&
                  eq(B,R) && eq(A,F) &&
                  (noteq(R, RC)||eq(R,C)) && noteq(R, RI) && noteq(A,PA)) {K=F; sawslope = true;}

			//					                    P
			//                                    A 🅑 🅲
			//                                  🆀 🅳 🄴 F R        Zone 1
			//                                  . G H I
			if ( !sawslope && (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && !eq_B_D &&
				 !eq_E_D && noteq(E,A) && none_eq2(D,A,G) &&
                 (eq_F_H&&eq(H,G)&&sim3(E,H) || eq_E_F&&(eq(E,G)||eq(B,A)||eq(A,P)&&eq(A,QA))) &&
                 eq(B,Q) && eq(C,D) &&
                 (noteq(Q, QA)||eq(Q,A)) && noteq(Q, QG) && noteq(C,PC)) {J=D; sawslope = true;}

		}

        // vertical left
        if ( !sawslope && !eq_E_D && none_eq2(D,C,I) ) {

			//                                    🅐 B C
			//                                  Q 🅳 🄴 F R
			//                                    G 🅷 I        Zone 3
			//                                      🆂 .
            if ( (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_D_H &&
				  !eq_E_H && noteq(E,G) && none_eq2(H,G,I) &&
                  (eq_B_F&&eq(F,I)&&sim3(E,F) || eq_E_B&&(eq(E,I)||eq(D,G)||eq(G,Q)&&eq(G,SG))) &&
                   eq(D,S) && eq(A,H) &&
                  (noteq(S, SG)||eq(S,G)) && noteq(S, SI) && noteq(A,QA)) {L=H; sawslope = true;}

			//                                      🅟 .
			//                                    A 🅑 C
			//                                  Q 🅳 🄴 F R       Zone 1
			//                                    🅶 H I
			if ( !sawslope && (!slope3 && !eq_D_H) && (!slope2 && !eq_B_F) && !eq_B_D &&
				  !eq_E_B && noteq(E,A) && none_eq2(B,A,C) &&
                  (eq_F_H&&eq(F,C)&&sim3(E,H) || eq_E_H&&(eq(E,C)||eq(D,A)||eq(A,Q)&&eq(A,PA))) &&
                  eq(P,D) && eq(B,G) &&
                  (noteq(P, PA)||eq(P,A)) && noteq(P, PC) && noteq(G,QG)) {J=B; sawslope = true;}

		}

        // vertical right
		if ( !sawslope && !eq_E_F && none_eq2(F,A,G) ) { // right

			//                                    A B 🅲
			//                                  Q D 🄴 🅵 R
			//                                    G 🅷 I        Zone 4
			//                                    . 🆂
			if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && !eq_F_H &&
				  !eq_E_H && noteq(E,I) && none_eq2(H,G,I) &&
                  (eq_B_D&&eq(D,G)&&sim3(E,D) || eq_E_B&&(eq(E,G)||eq(F,I)||eq(I,R)&&eq(I,SI))) &&
                  eq(S,F) && eq(H,C) &&
                  (noteq(S, SI)||eq(S,I)) && noteq(S, SG) &&  noteq(C,RC)) {M=H; sawslope = true;}

			//                                    . 🅟
			//                                    A 🅑 C
			//                                  Q D 🄴 🅵 R        Zone 2
			//                                    G H 🅸
			if ( !sawslope && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_B_F &&
				 !eq_E_B && noteq(E,C) && none_eq2(B,A,C) &&
                 (eq_D_H&&eq(D,A)&&sim3(E,D) || eq_E_H&&(eq(E,A)||eq(F,C)||eq(C,R)&&eq(C,PC))) &&
                 eq(P,F) && eq(B,I) &&
                 (noteq(P, PC)||eq(P,C)) && noteq(P, PA) && noteq(I,RI)) {K=B; sawslope = true;}

		} // vertical right
} // sawslope

// sawslope formed can exit, slopeBAD not suitable for below CnC
if (sawslope||slopeBAD) {
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
	return;
}

/**************************************************
 *     "Concave + Cross" type (P100)	  *
 *************************************************/
//  Cross Using approximate pixels at the far end is useful for some horizontal lines with jagged edges and layered gradient shapes.
// Practice: CnC cannot exclude slopEND (weak form) and slopok (strong form) but can exclude slopeBAD !!!

bool cnc = false;
    if (!slope3 && !slope4 &&
        Bl<El && !eq_E_D && !eq_E_F && eq_E_H && none_eq2(E,A,C) && all_eq2(G,H,I) && sim1(E,S) ) { // TOP
	    if (eq_D_F){
            J= eq_B_D ? admixK(B,J) : admixC(D,B,J);
			K=J;
            L=mix(J,L, 0.61804);
			M=L;
        } else {
            if (!slope1) J=admixC(D,B,J);
            if (!slope2) K=admixC(B,F,K);
            }
	   cnc = true;
	}
    if (!slope1 && !slope2 && !cnc &&
		Hl<El && !eq_E_D && !eq_E_F && eq_E_B && none_eq2(E,G,I) && all_eq2(A,B,C) && sim1(E,P) ) { // BOTTOM
	    if (eq_D_F){
            L=eq_D_H ? admixK(H,L) : admixC(D,H,L);
			M=L;
            J=mix(L,J, 0.61804);
			K=J;
        } else {
            if (!slope3) L=admixC(D,H,L);
            if (!slope4) M=admixC(F,H,M);
            }
	   cnc = true;
	}
    if (!slope1 && !slope3 && !cnc &&
		Fl<El && !eq_E_B && !eq_E_H && eq_E_D && none_eq2(E,C,I) && all_eq2(A,D,G) && sim1(E,Q) ) { // RIGHT
        if (eq_B_H) {
            K=eq_B_F ? admixK(F,K) : admixC(B,F,K);
			M=K;
            J=mix(K,J, 0.61804);
			L=J;
        } else {
            if (!slope2) K=admixC(B,F,K);
            if (!slope4) M=admixC(F,H,M);
            }
	   cnc = true;
	}
    if (!slope2 && !slope4 && !cnc &&
		Dl<El && !eq_E_B && !eq_E_H && eq_E_F && none_eq2(E,A,G) && all_eq2(C,F,I) && sim1(E,R) ) { // LEFT
        if (eq_B_H) {
            J=eq_B_D ? admixK(D,J) : admixC(D,B,J);
			L=J;
            K=mix(J,K, 0.61804);
			M=K;
        } else {
            if (!slope1) J=admixC(D,B,J);
            if (!slope3) L=admixC(D,H,L);
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
	   ㇿО    Scorpion type (P99). Looks like the tracking bug in The Matrix. It can flatten out some regularly intersecting pixels.
*/
// Practice: 1. Scorpion pincers use approximation, otherwise It can easily turn into a small C-shape and cause graphic glitches.
// Practice: 2. Remove one segment from scorpion tail to capture more forms.
// Among the four forms, only scorpion is exclusive. Once caught by previous rules (entered), this form won't appear. Also the least noticeable form. So placed last.

bool scorpion = false;
                if (!eq_E_F &&eq_E_D&&eq_B_F&&eq_F_H && all_eq2(E,C,I) && noteq(F,src(+3, 0)) ) {K=admixK(F,K); M=K;J=mix(K,J, 0.61804); L=J;scorpion=true;}	// RIGHT
   if (!scorpion && !eq_E_D &&eq_E_F&&eq_B_D&&eq_D_H && all_eq2(E,A,G) && noteq(D,src(-3, 0)) ) {J=admixK(D,J); L=J;K=mix(J,K, 0.61804); M=K;scorpion=true;}	// LEFT
   if (!scorpion && !eq_E_H &&eq_E_B&&eq_D_H&&eq_F_H && all_eq2(E,G,I) && noteq(H,src(0, +3)) ) {L=admixK(H,L); M=L;J=mix(L,J, 0.61804); K=J;scorpion=true;}	// BOTTOM
   if (!scorpion && !eq_E_B &&eq_E_H&&eq_B_D&&eq_B_F && all_eq2(E,A,C) && noteq(B,src(0, -3)) ) {J=admixK(B,J); K=J;L=mix(J,L, 0.61804); M=L;}				// TOP

// Determine which of our 4 output pixels we need to use
   FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
}
