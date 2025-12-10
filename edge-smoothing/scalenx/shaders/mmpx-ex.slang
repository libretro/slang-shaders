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

 // (Switched to BT.601 standard from the CRT era) Only affects the luma decision mechanism
float luma(vec3 col){
   return dot(col, vec3(0.299, 0.587, 0.114));
   //return dot(col, vec3(0.3333333)); // Average of RGB
}

bool checkblack(vec3 col) {
    return col.g < 0.078 && col.r < 0.1 && col.b < 0.1;
}

//bool checkwhite(vec3 col) {
// if (col.r < 0.9 || col.g < 0.92 || col.b < 0.9) return false;
//    return true;
//}

// pin zz
bool sim1(vec3 col1, vec3 col2) {

    vec3 diff = col1 - col2;
    vec3 absdiff = abs(col1 - col2);

    // fast chanels check
    if ( absdiff.r > 0.1 || absdiff.g > 0.1 || absdiff.b > 0.1 ) return false;

    // fast dot_distence check
	float dot_diff = dot(diff, diff);
    if (dot_diff < 0.001359312) return true;


    float min_diff = min(diff.r, min(diff.g, diff.b));
    float max_diff = max(diff.r, max(diff.g, diff.b));
    if ( max_diff-min_diff>0.096 ) return false;
    if ( max_diff-min_diff<0.024 && dot_diff<0.024391856)  return true;

	// 4. grey pixel check
    float sum1 = dot(col1, vec3(1.0));
    float sum2 = dot(col2, vec3(1.0));
    float avg1 = sum1 * 0.3333333;
    float avg2 = sum2 * 0.3333333;

	vec3 graydiff1 = col1 - vec3(avg1);
	vec3 graydiff2 = col2 - vec3(avg2);
	float dotgray1 = dot(graydiff1,graydiff1);
	float dotgray2 = dot(graydiff2,graydiff2);

	float tolerance1 = avg1<0.08 ? 0.002 : 0.0004;
	float tolerance2 = avg2<0.08 ? 0.002 : 0.0004;

    bool Col1isGray = sum1<0.078||dotgray1<tolerance1;
    bool Col2isGray = sum2<0.078||dotgray2<tolerance2;


    if ( Col1isGray && Col2isGray && dot_diff<0.024391856 ) return true;


    if ( Col1isGray != Col2isGray ) return false;


    float team_pos = abs(dot(max(diff, 0.0), vec3(1.0)));
    float team_neg = abs(dot(min(diff, 0.0), vec3(1.0)));

    float team_rebel = min(team_pos, team_neg);

    return dot_diff + team_rebel*team_rebel*3 < 0.00931686;
}

bool sim23(vec3 col1, vec3 col2, int Lv) {

    // 1. Clamp dark areas
    vec3 clampCol1 = max(col1, vec3(0.078));
    vec3 clampCol2 = max(col2, vec3(0.078));

    vec3 clampdiff = clampCol1 - clampCol2;

	// Euclidean distance between two points: 2 short + 1, 2nd shortest golden ratio
    float dotdist = Lv==2 ? 0.024391856 : 0.0638587;

    return dot(clampdiff, clampdiff) < dotdist;
}

bool sim2(vec3 v3C, uint C1, uint C2) {
    if (C1==C2) return true;
    return sim23(v3C, unpackUnorm4x8(C2).rgb, 2);
}

bool sim3(vec3 col1, vec3 col2) {
    return sim23(col1, col2, 3);
}

bool mixcheck(vec3 col1, vec3 col2) {

    vec3 diff = col1 - col2;


    float min_diff = min(diff.r, min(diff.g, diff.b));
    float max_diff = max(diff.r, max(diff.g, diff.b));
    if ( max_diff-min_diff>0.618034 ) return false;    // 超过24
	float dot_diff = dot(diff, diff);
    if( max_diff-min_diff<0.024 && dot_diff<0.75)  return true;  //  0.02不超过5    0.024 不超过6


    float team_pos = abs(dot(max(diff, 0.0), vec3(1.0)));
    float team_neg = abs(dot(min(diff, 0.0), vec3(1.0)));

    float team_rebel = min(team_pos, team_neg);

    return dot_diff + team_rebel*team_rebel*3 < 0.4377;
}
//bool eq(vec3 col1, vec3 col2) {
//    vec3 diff = abs(col1 - col2);
//    return diff.r < 0.004 && diff.g < 0.004 && diff.b < 0.004;
//}

// In practice, the following solution has slightly lower system usage and is more reasonable. (Adding 2 points in a single channel is less noticeable than adding 1 point across three channels)
#define v3eq(a,b) (dot(abs(a-b), vec3(1.0)) < 0.008)
#define v3noteq(a,b) (dot(abs(a-b), vec3(1.0)) > 0.008)
#define eq(a,b) (a==b)
#define noteq(a,b) (a!=b)

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


///////////////////////     Test Colors     ///////////////////////
#define testcolor vec3(1.0, 0.0, 1.0)  // Magenta
#define testcolor2 vec3(0.0, 1.0, 1.0)  // Cyan
#define testcolor3 vec3(1.0, 1.0, 0.0)  // Yellow
#define testcolor4 vec3(1.0, 1.0, 1.0)  // White

// Pre-define types of mix
#define slopeBAD vec3(2.0)
#define theEXIT vec3(8.0)
#define slopOFF vec3(33.0)
#define Mix382 mix(v3X,v3E,0.381966)
#define Mix618 mix(v3X,v3E,0.618034)
#define Mix854 mix(v3X,v3E,0.8541)
#define Mix382off Mix382+slopOFF
#define Mix618off Mix618+slopOFF
#define Mix854off Mix854+slopOFF
#define Xoff v3X+slopOFF

// pin zz   "Concave + Cross" type Weak blend (Weak/None)
vec3 admixC(vec3 v3X, vec3 v3E) {

	bool mixok = mixcheck(v3X, v3E);

	return mixok ? Mix618 : v3E;

}

// K-type Forced weak blend (Weak/Weaker)
vec3 admixK(vec3 v3X, vec3 v3E) {

	bool mixok = mixcheck(v3X, v3E);

	return mixok ? Mix618 : Mix854;

}

// L-type 2:1 Slope   Main corner extension
// In practice: This rule requires all 4 pixels on the strict slope to be identical. Otherwise, various glitches appear!
vec3 admixL(vec3 v3X, vec3 v3E, vec3 v3S) {

    //if (eq(X, E)) return E; // Originally, this would catch many duplicate pixels, but it's now invalidated after the slopebad filter.

	// If target X and reference S(sample) are different, it means blending has already occurred once, so just copy the target.
	if (v3noteq(v3X, v3S)) return v3X;

	bool mixok = mixcheck(v3X, v3E);

    return mixok ? Mix382 : v3X;
}

/********************************************************************************************************************************************
 *               												main slope + X cross-processing mechanism					                *
 ************************************************************************************************************************************** zz  */
vec3 admixX(uint A, uint B, uint C, uint D, uint E, uint F, uint G, uint H, uint I, uint P, uint PA, uint PC, uint Q, uint QA, uint QG, uint R, uint RC, uint RI, uint S, uint SG, uint SI, uint AA, uint CC, uint GG, float El, float Bl, float Dl, float Fl, float Hl, vec3 v3E, vec3 v3B, vec3 v3D) {

	//pre-cal
	bool eq_B_C = eq(B, C);
	bool eq_D_G = eq(D, G);

    // Squeezed by straight walls on both sides -> Exit
    if (eq_B_C && eq_D_G) return slopeBAD;

	bool eq_B_D = eq(B,D);
    vec3 v3X;

	if (eq_B_D) {

        v3X = v3B;
    } else {
        // E-A equality does not conform to preset logic, exit
        if (eq(E,A)) return slopeBAD;

        // D B are not equal, and the difference between them is greater than either's difference to center E, exit
        float diffBD = abs(Bl-Dl);
        float diffEB = abs(El-Bl);
        float diffED = abs(El-Dl);
        if (diffBD > diffEB || diffBD > diffED) return slopeBAD;

        v3X = mix(v3B,v3D,0.5);
    }

	// Avoid single-pixel font edges being squeezed by black background on both sides (luma difference between font and background typically exceeds 0.5)
	// Note: If B and D are not equal, cannot use average to judge; both must satisfy black condition
	bool Xisblack = eq_B_D ? checkblack(v3B) : checkblack(v3B)&&checkblack(v3D);
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


//  Exclusion rules before the original rules (triangle vertices cannot protrude)
	eq_A_B = eq(A,B);
	if ( !Xisblack && eq_A_B && eq_D_G && eq(B,P) ) return slopeBAD;

	eq_A_D = eq(A,D);
	if ( !Xisblack && eq_A_D && eq_B_C && eq(D,Q) ) return slopeBAD;

    // B and D touch nothing? Not applicable here. (Can eliminate some glitches, but will also lose some shapes, especially in non-native pixel art, e.g., Double Dragon's opening character portraits)


	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
	comboA3 = eq_A_P && eq_A_Q;
	mixok = mixcheck(v3X,v3E);

	// A-side three-in-a-row, high priority
    if (comboA3) return mixok ? Mix382off : Xoff;

    // Official original rule
    if ( eq(E,C) || eq(E,G) ) return mixok ? Mix382off : Xoff;

    // Original rule enhancement 1: catches trends well, but enhancement 2 cannot be used because it can't bypass wall issues
    if ( !eq_D_G&&eq(E,QG)&&sim2(v3E,E,G) || !eq_B_C&&eq(E,PC)&&sim2(v3E,E,C) ) return mixok ? Mix382off : Xoff;


    // Exclude the "three-cell single-side wall" case
    if (!Xisblack){
        if ( eq_A_B&&eq_B_C || eq_A_D&&eq_D_G ) return slopeBAD;
    }

    // F-H inline trend, includes En3, placed after three-cell single-side wall rule as it would be blocked
    if ( eq(F,H) ) return mixok ? Mix382off : Xoff;
    // Remaining "two-cell single-side wall" and logic-less single pixels, give up

    return slopeBAD;
} // B != D

	//pre-cal B == D
    bool eq_E_A = eq(E,A);
    bool eq_E_C = eq(E,C);
    bool eq_E_G = eq(E,G);
	bool sim_EC = eq_E_C || sim23(v3E,unpackUnorm4x8(C).rgb,2);
	bool sim_EG = eq_E_G || sim23(v3E,unpackUnorm4x8(G).rgb,2);

	bool ThickBorder;

// Original main rule with sim enhancement
if ( (sim_EC || sim_EG) && !eq_E_A ){

/* Concept:
    1. Handle continuous border shapes without blending
    2. Special handling for long slopes
    3. Original rules
    4. Handle E-area inline patterns like En4, En3, F-H, leaving a single strip and single pixels
    5. Handle L-shaped internal and external single strips
    5. Normal fallback
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

    // step1:
    // B + D + their respective continuation shapes
    // Note: Only for judging X as no-blend; different from the "catch rule and return" logic in the final section

    if ( (B_slope||B_tower) && (D_slope||D_tower) && !eq_A_B) return Xoff;


	eq_A_P = eq(A, P);
	eq_A_Q = eq(A, Q);
	comboA3 = eq_A_P && eq_A_Q;
	mixok = mixcheck(v3X,v3E);
    ThickBorder = eq_A_B && (eq_A_P||eq_A_Q|| eq(A,AA)&&(eq_B_PA||eq_D_QA));
	if (ThickBorder && !Xisblack) mixok=false;

    // A-side three-in-a-row
    if (comboA3) {
        if (!eq_A_B) return Xoff;
        else mixok=false;
    }

    // XE_messL B-D-E L-type highly similar sim2   WIP
    // bool XE_messL = (eq_B_C && !sim_EG || eq_D_G && !sim_EC) ;

    eq_E_F = eq(E, F);
	B_wall = eq_B_C && !eq_B_PC && !eq_B_P;

    // Clear long slope (Not thick solid edge. Strong trend!)
    // Long slope case is slightly special, handled in separate condition
	if ( B_wall && D_tower ) {
        if (eq_E_G || sim_EG&&eq(E,QG) ) {   // Original rule + Original enhancement
            if (eq_A_B) return mixok ? Mix382 : v3X;    // Has thickness
            return v3X;                                           // Hollow
        }
        // Clear Z-shaped serpentine, exclude XE_messL ???
        //if (eq_A_B  && !XE_messL) return slopeBAD;                    // WIP
        if (eq_A_B) return slopeBAD;
        //  Two-cell with subsequent long slope
        if (eq_E_F ) return v3X;
        //  Single-cell without subsequent long slope
        return Xoff;
    }

    eq_E_H = eq(E, H);
	D_wall = eq_D_G && !eq_D_QG&& !eq_D_Q;

	if ( B_tower && D_wall ) {
        if (eq_E_C || sim_EC&&eq(E,PC) ) {   // Original rule + Original enhancement
            if (eq_A_B) return mixok ? Mix382 : v3X;    // Has thickness
            return v3X;                                           // Hollow
        }
        // Clear Z-shaped serpentine, exclude XE_messL ???
        //if (eq_A_B  && !XE_messL) return slopeBAD;                    // WIP
        if (eq_A_B) return slopeBAD;
        //  Two-cell with subsequent long slope
        if (eq_E_H ) return v3X;
        //  Single-cell without subsequent long slope
        return Xoff;
    }


    // Official original rules (placed after above special shapes, which specify no blend!)
    if (eq_E_C || eq_E_G) return mixok ? Mix382 : v3X;

    // Original rule enhancement 1
    if (sim_EG&&!eq_D_G&&eq(E,QG) || sim_EC&&!eq_B_C&&eq(E,PC)) return mixok ? Mix382off : Xoff;

    // Original rule enhancement 2
    if (sim_EC && sim_EG) return mixok ? Mix382off : Xoff;


    // F-H inline trend (Skip En4 En3)
    if ( eq(F,H) )  return mixok ? Mix382off : Xoff;

	// Relaxed rule to finally clean up two long slopes (non-clear shapes)
    // In practice: This section cleans long slopes and differs from F-H. Default is draw, unless cube
	if (eq_B_C && eq_D_Q) {
        // Double-cube -> exit
		if (eq_B_P && eq_B_PC && eq_A_B && eq_D_QA && !eq_D_QG && eq_E_F && eq(H,I) ) return theEXIT;

		return mixok ? Mix382off : Xoff;
	}

	if ( eq_D_G && eq_B_P) {
        // Double-cube -> exit
		if (eq_D_Q && eq_D_QG && eq_A_B && eq_B_PA && !eq_B_PC && eq_E_H && eq(F,I) ) return theEXIT;

		return mixok ? Mix382off : Xoff;
	}

    eq_E_I = eq(E, I);

    // L-shaped corner (clear) internal single strip (parallel), exit
    if (eq_A_B && !ThickBorder && !eq_E_I ) {
	    if (B_wall && eq_E_F) return theEXIT;
	    if (D_wall && eq_E_H) return theEXIT;
	}

    // Similar colors, skip to next step and return early
    if (mixok) return Mix382off;

    // L-shaped corner (hollow corner) external single strip (any direction), exit (solves font edge issues)
    if ( !eq_A_B && (eq_E_F||eq_E_H) && !eq_E_I) {
        if (B_tower && !eq_D_Q && !eq_D_QG) return theEXIT;
        if (D_tower && !eq_B_P && !eq_B_PC) return theEXIT;
    }

    // Fallback handling
    return mixok ? Mix382off : Xoff;

} // sim2 base


/*===================================================
                    E - A Crossover
  ============================================== zz */

if (eq_E_A) {

	// When judging cross ✕, need concepts of "area" and "trend". Conditions need tightening for different areas

    // B D touch nothing? Not needed here!!!

    eq_E_F = eq(E, F);
    eq_E_H = eq(E, H);
    eq_E_I = eq(E, I);
    En3 = eq_E_F&&eq_E_H;
    En4square = En3 && eq_E_I;

	// Special shape: Square
	if ( En4square ) {
        if( noteq(G,H) && noteq(C,F)                      //  Independent clear 4-cell square / 6-cell rectangle (both sides satisfied simultaneously)
		&& (eq(H,S) == eq(I,SI) && eq(F,R) == eq(I,RI)) ) return theEXIT;
        //else return mixok ? mix(X,E,0.381966) : X;    Note: cannot return directly. Must enter checkerboard decision rule, because adjacent B, D areas might also form squares making bubbles
    }

    //  Special shape: Dithering
	// Practice 1: !eq_E_F, !eq_E_H. Not using !sim, as it would lose some shapes
    //  Practice 2: Force blend, otherwise shapes are lost. (Gouketsuji Ichizoku horse, WWF Superstars 2)

	bool Eisblack = checkblack(v3E);
	mixok = mixcheck(v3X,v3E);

	//  1. Dithering center
    if ( eq_E_C && eq_E_G && eq_E_I && !eq_E_F && !eq_E_H ) {

		// Exit if center E is black (King of Fighters '96 power gauge, Punisher's belt) to avoid too high contrast blending
		if (Eisblack) return theEXIT;
		// Practice 1: Cannot catch black B point, B points entering here all satisfy the shape
		//if (Xisblack) return testcolor2;
		// Option 1 Layered pattern (eq_F_H occurrence 95%) + progressive layers inside health bar, remaining 0.5 fallback blend
		// if (eq_F_H) return Mix382off : Mix618off;
        // return mix(X, E, 0.5)+slopeOFF;
		// Finally decided to unify it
		return mixok ? Mix382off : Mix618off;
	}

	eq_A_P = eq(A,P);
	eq_A_Q = eq(A,Q);
    eq_B_PA = eq(B,PA);

	//  2. Dithering edge
    if ( eq_A_P && eq_A_Q && eq(A,AA) && noteq(A,PA) && noteq(A,QA) )  {
		if (Eisblack) return theEXIT;

        // Progressive layered edge, use strong blend
		if ( !eq_B_PA && eq(PA,QA) ) return mixok ? Mix382off : Mix618off;
        // Remaining 1. Perfect cross, must be dithering edge, use weak blend
        // Remaining 2. Fallback weak blend
		return mixok ? Mix618off : Mix854off;
		// Note: No need to specify health bar border case separately
	}

    eq_D_QA = eq(D,QA);
    eq_D_QG = eq(D,QG);
    eq_B_PC = eq(B,PC);

  //   3. Half dithering, usually for shadow expression on contour edges. Use weak blend
	if ( eq_E_C && eq_E_G && eq_A_P && eq_A_Q &&
		(eq_B_PC || eq_D_QG) &&
		 eq_D_QA && eq_B_PA) {
		//if (Eisblack) return testcolor;

        return mixok ? Mix618off : Mix854off;
		}

    //   4. Quarter dithering, prone to causing ugly "little finger" artifacts

	if ( eq_E_C && eq_E_G && eq_A_P
		 && eq_B_PA &&eq_D_QA && eq_D_QG
		 && eq_E_H
		) return mixok ? Mix618off : Mix854off;

	if ( eq_E_C && eq_E_G && eq_A_Q
		 && eq_B_PA &&eq_D_QA && eq_B_PC
		 && eq_E_F
		) return mixok ? Mix618off : Mix854off;


    // E-side three-in-a-row (Must be after dithering)
    if ( eq_E_C && eq_E_G ) return Xoff;

    comboA3 = eq_A_P && eq_A_Q;

    // A-side three-in-a-row (Must be after dithering) Since E-A are the same, prefer blend over direct copy
	if (comboA3) return mixok ? Mix382off : Xoff;


    // B-D  part of long slope
	eq_B_P = eq(B,P);
	eq_D_Q = eq(D,Q);
	B_wall = eq_B_C && !eq_B_P;
	B_tower = eq_B_P && !eq_B_C;
	D_tower = eq_D_Q && !eq_D_G;
	D_wall = eq_D_G && !eq_D_Q;

    int scoreE = 0; int scoreB = 0; int scoreD = 0; int scoreZ = 0;


// E B D Area Checkerboard Scoring Rules

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
        // Single strip
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
		scoreB -= int(eq_B_P);    // Replaces eq(P,PA)
	}

//        D Zone
	scoreD -= int(Dn3);
	scoreD -= int(eq(G,Q));
    if (scoreD < 0) scoreZ = 0;

    if (eq_D_QA) {
		scoreD -= 1;
		scoreD -= int(eq_D_Q);    // Replaces eq(Q,QA)
	}

    int scoreFinal = scoreE + scoreB + scoreD + scoreZ ;

    if (scoreE >= 1 && scoreB >= 0 && scoreD >=0) scoreFinal += 1;

    if (scoreFinal >= 2) return v3X;

    if (scoreFinal == 1) return mixok ? Mix382 : v3X;

    // Final addition: Total score zero, B, D zones not penalized, forming a long slope shape
    if (scoreB >= 0 && scoreD >=0) {
        if (B_wall&&D_tower) return v3X;
        if (B_tower&&D_wall) return v3X;
    }

    return slopeBAD;

}	// eq_E_A



/*=========================================================
                    F - H / -B - D- Extension New Rules
  ==================================================== zz */

// This section differs from the sim section. The center point and related En4square and BD logic are naturally separated by a wall
// Judgment rules differ from the sim side

	eq_B_P = eq(B, P);
    eq_B_PC = eq(B, PC);
	eq_D_Q = eq(D, Q);
    eq_D_QG = eq(D, QG);

    // B D touch nothing -> exit (Practice: needed for this branch section)
    if ( !eq_B_C && !eq_B_P && !eq_B_PC && !eq_D_G && !eq_D_Q && !eq_D_QG ) return slopeBAD;

	mixok = mixcheck(v3X,v3E);
    eq_E_I = eq(E, I);

	// Center point E is high-contrast pixel, visually very different from surrounding pixels -> exit
	float E_lumDiff = El > 0.92 ? 0.145898 : 0.381966;
	bool E_ally = mixok || eq_E_I || abs(El-Fl)<E_lumDiff || abs(El-Hl)<E_lumDiff;
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
        // B + D + their respective continuation shapes
        // Practice 1: One side is definite clear shape, other side can be more lenient
        // Practice 2: "厂" shaped edge draws on outside but not inside, (can be tower but not wall)
        if ( (B_slope||B_tower) && (eq_D_QG&&!eq_D_G||D_tower) ) return Xoff;
        if ( (D_slope||D_tower) && (eq_B_PC&&!eq_B_C||B_tower) ) return Xoff;

        // A-side three-in-a-row, high priority
        if (comboA3) return Xoff;

        // combo 2x2 as supplement to previous one
        if ( B_slope && eq_A_P ) return mixok ? Mix382off : Xoff;
        if ( D_slope && eq_A_Q ) return mixok ? Mix382off : Xoff;
    }

    eq_E_F = eq(E, F);
	B_wall = eq_B_C && !eq_B_PC && !eq_B_P;

    // Clear long slope (Not thick solid edge. Strong trend!)
    // Long slope case slightly special, handled in separate condition
	if ( B_wall && D_tower ) {
        if (eq_A_B ) return slopeBAD;
        if (eq_E_F ) return v3X;  //wip: Test direct X no-blend
        return mixok ? Mix382off : Xoff;
    }

    eq_E_H = eq(E, H);
	D_wall = eq_D_G && !eq_D_QG&& !eq_D_Q;

	if ( B_tower && D_wall ) {
        if (eq_A_B ) return slopeBAD;
        if (eq_E_H ) return v3X;
        return mixok ? Mix382off : Xoff;
    }


    En3 = eq_E_F&&eq_E_H;
    En4square = En3 && eq_E_I;
    bool sim_X_E = sim3(v3X,v3E);
    bool eq_G_H = eq(G, H);
    bool eq_C_F = eq(C, F);
    bool eq_H_S = eq(H, S);
    bool eq_F_R = eq(F, R);

    // Wall-enclosed 4-cell rectangle
	if ( En4square ) {  // This square detection must be placed after previous rule
		if (sim_X_E) return mixok ? Mix382off : Xoff;
        // Solid L enclosed -> exit (Fix some font edge corners and building corners that shouldn't be rounded (Mega Man 7)
        if ( (eq_B_C || eq_D_G) && eq_A_B ) return theEXIT;
        //if (eq_H_S && eq_F_R) return theEXIT; // Both sides extend simultaneously
        //  L enclosed (hollow corner) / High contrast independent clear 4-cell square / 6-cell rectangle (Note: judge rectangle's two edges)
        if ( ( eq_B_C&&!eq_G_H || eq_D_G&&!eq_C_F || !eq_G_H&&!eq_C_F&&abs(El-Bl)>0.5) && (eq_H_S == eq(I, SI) && eq_F_R == eq(I, RI)) ) return theEXIT;

        return mixok ? Mix382off : Xoff;
    }

    // Wall-enclosed triangle
 	if ( En3 ) {
		if (sim_X_E) return mixok ? Mix382off : Xoff;
        if (eq_H_S && eq_F_R) return theEXIT; // Both sides extend simultaneously (building edges)
       // Inside curve
        if (eq_B_C || eq_D_G) return mixok ? Mix382off : Xoff;
		// Has thickness, return directly (Z-shaped serpentine can draw outside curve below)
        if (eq_A_B) return mixok ? Mix382off : Xoff;
        // Outside curve
        if (eq_B_P || eq_D_Q) return theEXIT;

        return mixok ? Mix382off : Xoff;
        // Last two rules based on experience. Principle: Connect L inside curve, not L outside (Double Dragon Jimmy's eyebrows)
	}

    // F - H
	// Principle: Connect L inside curve, not L outside
	if ( eq(F,H) ) {
    	if (sim_X_E) return mixok ? Mix382off : Xoff;
        // Solid L enclosed, avoid bilateral symmetrical full squeeze on single pixel
		if ( eq_B_C && eq_A_B && (eq_G_H||!eq_F_R) &&eq(F, I) ) return slopeBAD;
		if ( eq_D_G && eq_A_B && (eq_C_F||!eq_H_S) &&eq(F, I) ) return slopeBAD;

		//Inside curve
        if (eq_B_C && (eq_F_R||eq_G_H||eq(F, I))) return mixok ? Mix382off : Xoff;
        if (eq_D_G && (eq_C_F||eq_H_S||eq(F, I))) return mixok ? Mix382off : Xoff;
		// E-I F-H crossover destroys trend
		if (eq_E_I) return slopeBAD;
        // Z-shaped outside
		if (eq_B_P && eq_A_B) return mixok ? Mix382off : Xoff;
        if (eq_D_Q && eq_A_B) return mixok ? Mix382off : Xoff;
		// Outside curve, unless opposite side forms long L-shaped trend
		if (eq_B_P && (eq_C_F&&eq_H_S)) return mixok ? Mix382off : Xoff;
        if (eq_D_Q && (eq_F_R&&eq_G_H)) return mixok ? Mix382off : Xoff;

        return slopeBAD;
	}


	// Relaxed rule to finally clean up two long slopes (non-clear shapes)
    // Note: This section cleans long slopes and differs from sim2 section. Solid corners exit
	if ( eq_B_C && eq_D_Q || eq_D_G && eq_B_P) {
        // Must first clear eq_A_B, otherwise edge single pixels will be eroded (Eternal Filena)
		if (eq_A_B) return theEXIT;
		return mixok ? Mix382off : Xoff;
	}


    //	A-side three-in-a-row, absolutely cannot be used without !eq_A_B !!!!!!!!!
    //  if (comboA3) return X+slopeOFF;


	// Use B + D bilateral continuation to capture once more, priority higher than L internal/external single strip below
        if ( (B_slope||B_tower) && (eq_D_QG&&!eq_D_G||D_tower) ) return Xoff;
        if ( (D_slope||D_tower) && (eq_B_PC&&!eq_B_C||B_tower) ) return Xoff;


    // L-shaped corner (clear) internal single strip, exit (sim_X_E also cannot pardon)
    if (eq_A_B && !ThickBorder && !eq_E_I ) {

	    if (B_wall && eq_E_F) return theEXIT;
	    if (D_wall && eq_E_H) return theEXIT;
	}

if (sim_X_E) return mixok ? Mix382off : Xoff;
    // L-shaped corner (hollow corner) external single strip, exit (corner connects inside, not outside)
	// Practice: Can avoid font edge being shaved (Captain Commando)
	if ( (B_tower || D_tower) && (eq_E_F||eq_E_H) && !eq_A_B && !eq_E_I) return theEXIT;

    // Final B or D individual extension judgment

    // Farthest distance slope can utilize
    if ( B_slope && !eq_A_B && eq(PC,CC) && noteq(PC,RC)) return mixok ? Mix382off : Xoff;
    if ( D_slope && !eq_A_B && eq(QG,GG) && noteq(QG,SG)) return mixok ? Mix382off : Xoff;

    // When X E are close, slope can have one less judgment point, with some restrictions in internal logic
  	if ( mixok && !eq_A_B ) {
        if ( B_slope && (!eq_C_F||eq(F,RC)) ) return Mix382off;
        if ( D_slope && (!eq_G_H||eq(H,SG)) ) return Mix382off;
    }

    // First exclude single strip for Z-shaped serpentine below (necessary)
    if ((eq_E_F||eq_E_H) && !eq_E_I ) return theEXIT;

    // Z-shaped serpentine (eq_A_B has thickness, one side is tower (can be wall, slope) but other side cannot be tower or wall (naturally prohibited))
    if ( eq_B_P && !eq_B_PA && !eq_D_Q && eq_A_B) return mixok ? Mix382off : Xoff;
    if ( eq_D_Q && !eq_D_QA && !eq_B_P && eq_A_B) return mixok ? Mix382off : Xoff;

	return theEXIT;

}	// admixX

vec3 admixS(uint A, uint B, uint C, uint D, uint E, uint F, uint G, uint H, uint I, uint R, uint RC, uint RI, uint S, uint SG, uint SI, uint II, bool eq_B_D, bool eq_E_D, float El, float Bl, vec3 v3E, vec3 v3F) {

			//                                    A B C .
			//                                  Q D 🄴 🅵 🆁       Zone 4
			//					                  🅶 🅷 I
			//					                    S
    // Practice 2: sim E B(C) conforms to original logic. In practice, when E is single pixel, won't be too strange due to jagged insertion
    // E cannot equal I           TEST ??? no!
    // if ( eq(E, I) ) return E;

    if (any_eq2(F,C,I)) return v3E;
    //if (any_eq3(F,A,C,I)) return v3E;

    if (eq(R, RI) && noteq(R,I)) return v3E;
    if (eq(H, S) && noteq(H,I)) return v3E;

    if ( eq(R, RC) || eq(G,SG) ) return v3E;

    if ( ( eq_B_D&&eq(B,C)&&abs(El-Bl)<0.381966 || eq_E_D&&sim2(v3E,E,C) ) &&
    (any_eq3(I,H,S,RI) || eq(SI,RI)&&noteq(I,II)) ) return v3F;

    return v3E;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////// zz

void main()
{
#define srcf(c,d) texture(Source, vTexCoord + vec2(c,d) * params.SourceSize.zw).rgb
#define src(c,d) packUnorm4x8(vec4(srcf(c,d), 1.0))  // Explicit RGB core, padding 1.0 has no performance cost
#define finalExit FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);return
	vec3 v3E = srcf(0, 0);
    vec3 v3B = srcf(+0, -1);
    vec3 v3D = srcf(-1, +0);
    vec3 v3F = srcf(+1, +0);
    vec3 v3H = srcf(+0, +1);

// Pre-set for quick return
	FragColor = vec4(v3E, 1.0);

    uint E = packUnorm4x8(vec4(v3E, 1.0));
    uint B = packUnorm4x8(vec4(v3B, 1.0));
    uint D = packUnorm4x8(vec4(v3D, 1.0));
    uint F = packUnorm4x8(vec4(v3F, 1.0));
    uint H = packUnorm4x8(vec4(v3H, 1.0));


    bool eq_E_D = eq(E,D);
    bool eq_E_F = eq(E,F);
    bool eq_E_B = eq(E,B);
    bool eq_E_H = eq(E,H);


// Skip horizontal/vertical 3x1
if (eq_E_D && eq_E_F) return;
if (eq_E_B && eq_E_H) return;

    bool eq_B_H = eq(B,H);
    bool eq_D_F = eq(D,F);
// Skip mirrored blocks surrounding center point
if ( eq_B_H && eq_D_F ) return;


    // Grab 5x5
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
   uint QG = src(-2, +1); //             AA  PA  [P]  PC  CC
   uint RC = src(+2, -1); //                ┌───┬───┬───┐
   uint RI = src(+2, +1); //             QA │ A │ B │ C │ RC
   uint SG = src(-1, +2); //                ├───┼───┼───┤
   uint SI = src(+1, +2); //            [Q] │ D │ E │ F │ [R]
   uint AA = src(-2, -2); //                ├───┼───┼───┤
   uint CC = src(+2, -2); //             QG │ G │ H │ I │ RI
   uint GG = src(-2, +2); //                └───┴───┴───┘
   uint II = src(+2, +2); //             GG   SG [S]  SI  II

// Default to nearest-neighbor upscaling
    vec3 J = v3E;    vec3 K = v3E;    vec3 L = v3E;    vec3 M = v3E;

    // ------------------------ Border Detection --------------------------
    // Define a non-existent fake pixel
    #define fakeColor vec3(1.234)
    // 1. Pre-calc integer coordinates of current pixel (uv -> pixel coordinates, floor to get pixel index)
    vec2 pixelPos = vTexCoord * params.SourceSize.xy;
    ivec2 currPixel = ivec2(floor(pixelPos)); // Current pixel's integer coordinates (0-based)
    ivec2 texSize = ivec2(params.SourceSize.xy); // Texture actual pixel dimensions

    // 3. Determine if four directions are out of bounds, change to fakeColor if out of bounds (based on integer pixel coordinate judgment, no floating point error)
    if (currPixel.y - 1 < 0) v3B = fakeColor;          // Upper pixel out of bounds (y-1 < 0)
    if (currPixel.x - 1 < 0) v3D = fakeColor;          // Left pixel out of bounds (x-1 < 0)
    if (currPixel.x + 1 >= texSize.x) v3F = fakeColor; // Right pixel out of bounds (x+1 >= width)
    if (currPixel.y + 1 >= texSize.y) v3H = fakeColor; // Lower pixel out of bounds (y+1 >= height)
    // ----------------------------------------------------------------------

// Pre-calc luma
   float Bl = luma(v3B);
   float Dl = luma(v3D);
   float El = luma(v3E);
   float Fl = luma(v3F);
   float Hl = luma(v3H);


// 1:1 slope rules (P95)
    bool eq_B_D = eq(B,D);
    bool eq_B_F = eq(B,F);
    bool eq_D_H = eq(D,H);
    bool eq_F_H = eq(F,H);

    // Any mirrored blocks surrounding center point
    bool oppoPix =  eq_B_H || eq_D_F;
	// Flag indicating entry into admixX function if caught by 1:1 slope rule
    bool slope1 = false;    bool slope2 = false;    bool slope3 = false;    bool slope4 = false;
	// Standard pixel successfully passed through 1:1 slope rule, normal return
    bool slope1ok = false;  bool slope2ok = false;  bool slope3ok = false;  bool slope4ok = false;
	// slopeBAD entered admixX, but (at least one of JKLM) returned E point
    // slopOFF  returned with OFF mark, subsequent steps do not participate in long slope calculation

    // B - D
	if ( (!eq_E_B&&!eq_E_D&&!oppoPix) && (!eq_D_H&&!eq_B_F) && (El>=Dl&&El>=Bl || eq(E,A)) && ( (El<Dl&&El<Bl) || none_eq2(A,B,D) || noteq(E,P) || noteq(E,Q) ) && ( eq_B_D&&(eq_F_H||eq(E,A)||eq(B,PC)||eq(D,QG)) || sim1(v3B,v3D)&&(sim2(v3E,E,C)||sim2(v3E,E,G)) ) ) {
		J=admixX(A,B,C,D,E,F,G,H,I,P,PA,PC,Q,QA,QG,R,RC,RI,S,SG,SI,AA,CC,GG, El,Bl,Dl,Fl,Hl,v3E,v3B,v3D);
		slope1 = true;
		if (J.b > 1.0 ) {
            if (J.b > 30.0 ) J=J-33.0; 	//slopOFF
			if (J.b == 8.0 ) return;
			if (J.b == 2.0 ) J=v3E;		//slopeBAD
		} else slope1ok = true;
	}
    // B - F
	if ( !slope1 && (!eq_E_B&&!eq_E_F&&!oppoPix) && (!eq_B_D&&!eq_F_H) && (El>=Bl&&El>=Fl || eq(E,C)) && ( (El<Bl&&El<Fl) || none_eq2(C,B,F) || noteq(E,P) || noteq(E,R) ) && ( eq_B_F&&(eq_D_H||eq(E,C)||eq(B,PA)||eq(F,RI)) || sim1(v3B,v3F)&&(sim2(v3E,E,A)||sim2(v3E,E,I)) ) )  {
		K=admixX(C,F,I,B,E,H,A,D,G,R,RC,RI,P,PC,PA,S,SI,SG,Q,QA,QG,CC,II,AA, El,Fl,Bl,Hl,Dl,v3E,v3F,v3B);
		slope2 = true;
		if (K.b > 1.0 ) {
            if (K.b > 30.0 ) K=K-33.0;
			if (K.b == 8.0 ) return;
			if (K.b == 2.0 ) K=v3E;
		} else {slope2ok = true;}
	}
    // D - H
	if ( !slope1 && (!eq_E_D&&!eq_E_H&&!oppoPix) && (!eq_F_H&&!eq_B_D) && (El>=Hl&&El>=Dl || eq(E,G))  &&  ((El<Hl&&El<Dl) || none_eq2(G,D,H) || noteq(E,S) || noteq(E,Q))  &&  ( eq_D_H&&(eq_B_F||eq(E,G)||eq(D,QA)||eq(H,SI)) || sim1(v3D,v3H) && (sim2(v3E,E,A)||sim2(v3E,E,I)) ) )  {
		L=admixX(G,D,A,H,E,B,I,F,C,Q,QG,QA,S,SG,SI,P,PA,PC,R,RI,RC,GG,AA,II, El,Dl,Hl,Bl,Fl,v3E,v3D,v3H);
		slope3 = true;
		if (L.b > 1.0 ) {
            if (L.b > 30.0 ) L=L-33.0;
			if (L.b == 8.0 ) return;
			if (L.b == 2.0 ) L=v3E;
		} else {slope3ok = true;}
	}
    // F - H
	if ( !slope2 && !slope3 && (!eq_E_F&&!eq_E_H&&!oppoPix) && (!eq_B_F&&!eq_D_H) && (El>=Fl&&El>=Hl || eq(E,I))  &&  ((El<Fl&&El<Hl) || none_eq2(I,F,H) || noteq(E,R) || noteq(E,S))  &&  ( eq_F_H&&(eq_B_D||eq(E,I)||eq(F,RC)||eq(H,SG)) || sim1(v3F,v3H) && (sim2(v3E,E,C)||sim2(v3E,E,G)) ) )  {
		M=admixX(I,H,G,F,E,D,C,B,A,S,SI,SG,R,RI,RC,Q,QG,QA,P,PC,PA,II,GG,CC, El,Hl,Fl,Dl,Bl,v3E,v3H,v3F);
		slope4 = true;
		if (M.b > 1.0 ) {
            if (M.b > 30.0 ) M=M-33.0;
			if (M.b == 8.0 ) return;
			if (M.b == 2.0 ) M=v3E;
		} else {slope4ok = true;}
	}


//  long gentle 2:1 slope  (P100)

	bool longslope = false;

    if (slope4ok && eq_F_H) { //zone4 long slope
        // Original rule extension 1. admixL third argument passes adjacent pixel for comparison, ensures no double blending
        // Original rule extension 2. The two pixels on opposite side within interval cannot form L shape again, unless forming wall
        if (eq(G,H) && eq(F,R) && noteq(R, RC) && (noteq(Q,G)||eq(Q, QA))) {L=admixL(M,L,v3H); longslope = true;}
        // vertical
		if (eq(C,F) && eq(H,S) && noteq(S, SG) && (noteq(P,C)||eq(P, PA))) {K=admixL(M,K,v3F); longslope = true;}
    }


    if (slope3ok && eq_D_H) { //zone3 long slope
        // horizontal
        if (eq(D,Q) && eq(H,I) && noteq(Q, QA) && (noteq(R,I)||eq(R, RC))) {M=admixL(L,M,v3H); longslope = true;}
        // vertical
		if (eq(A,D) && eq(H,S) && noteq(S, SI) && (noteq(A,P)||eq(P, PC))) {J=admixL(L,J,v3D); longslope = true;}
    }

    if (slope2ok && eq_B_F) { //zone2 long slope
        // horizontal
        if (eq(A,B) && eq(F,R) && noteq(R, RI) && (noteq(A,Q)||eq(Q, QG))) {J=admixL(K,J,v3B); longslope = true;}
        // vertical
		if (eq(F,I) && eq(B,P) && noteq(P, PA) && (noteq(I,S)||eq(S, SG))) {M=admixL(K,M,v3F); longslope = true;}
    }

    if (slope1ok && eq_B_D) { //zone1 long slope
        // horizontal
        if (eq(B,C) && eq(D,Q) && noteq(Q, QG) && (noteq(C,R)||eq(R, RI))) {K=admixL(J,K,v3B); longslope = true;}
        // vertical
		if (eq(D,G) && eq(B,P) && noteq(P, PC) && (noteq(G,S)||eq(S, SI))) {L=admixL(J,L,v3D); longslope = true;}
    }

// longslope formed can exit, basically won't form sawslope on diagonal
bool skiprest = longslope;

bool slopeok = slope1ok||slope2ok||slope3ok||slope4ok;


// Note: sawslope cannot exclude slopeOFF (few) and slopeBAD (very few), but can exclude slopeok (strong shapes)
if (!skiprest && !oppoPix && !slopeok) {


        // horizontal bottom
		if (!eq_E_H && none_eq2(H,A,C)) {

			//                                    A B C .
			//                                  Q D 🄴 🅵 🆁       Zone 4
			//					                  🅶 🅷 I
			//					                    S
			// (!slope3 && !eq_D_H) This kind of combined usage is clever
			if ( (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H)  && !eq_F_H &&
                !eq_E_F && (eq_B_D || eq_E_D) && eq(R,H) && eq(F,G) ) {
                M = admixS(A,B,C,D,E,F,G,H,I,R,RC,RI,S,SG,SI,II,eq_B_D,eq_E_D,El,Bl,v3E,v3F);
                skiprest = true;}

			//                                  . A B C
			//                                  🆀 🅳 🄴 F R       Zone 3
			//                                    G 🅷 🅸
			//					                    S
			if ( !skiprest && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_D_H &&
                 !eq_E_D && (eq_B_F || eq_E_F) && eq(Q,H) && eq(D,I) ) {
                L = admixS(C,B,A,F,E,D,I,H,G,Q,QA,QG,S,SI,SG,GG,eq_B_F,eq_E_F,El,Bl,v3E,v3D);
                skiprest = true;}
		}

        // horizontal up
		if ( !skiprest && !eq_E_B && none_eq2(B,G,I)) {

			//					                    P
			//                                    🅐 🅑 C
			//                                  Q D 🄴 🅵 🆁       Zone 2
			//                                    G H I .
			if ( (!slope1 && !eq_B_D)  && (!slope4 && !eq_F_H) && !eq_B_F &&
				  !eq_E_F && (eq_D_H || eq_E_D) && eq(B,R) && eq(A,F) ) {
                K = admixS(G,H,I,D,E,F,A,B,C,R,RI,RC,P,PA,PC,CC,eq_D_H,eq_E_D,El,Hl,v3E,v3F);
                skiprest = true;}

			//					                    P
			//                                    A 🅑 🅲
			//                                  🆀 🅳 🄴 F R        Zone 1
			//                                  . G H I
			if ( !skiprest && (!slope2 && !eq_B_F) && (!slope3 && !eq_D_H) && !eq_B_D &&
				 !eq_E_D && (eq_F_H || eq_E_F) && eq(B,Q) && eq(C,D) ) {
                J = admixS(I,H,G,F,E,D,C,B,A,Q,QG,QA,P,PC,PA,AA,eq_F_H,eq_E_F,El,Hl,v3E,v3D);
                skiprest = true;}

		}

        // vertical left
        if ( !skiprest && !eq_E_D && none_eq2(D,C,I) ) {

			//                                    🅐 B C
			//                                  Q 🅳 🄴 F R
			//                                    G 🅷 I        Zone 3
			//                                      🆂 .
            if ( (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_D_H &&
				  !eq_E_H && (eq_B_F || eq_E_B) && eq(D,S) && eq(A,H) ) {
                L = admixS(C,F,I,B,E,H,A,D,G,S,SI,SG,Q,QA,QG,GG,eq_B_F,eq_E_B,El,Fl,v3E,v3H);
                skiprest = true;}

			//                                      🅟 .
			//                                    A 🅑 C
			//                                  Q 🅳 🄴 F R       Zone 1
			//                                    🅶 H I
			if ( !skiprest && (!slope3 && !eq_D_H) && (!slope2 && !eq_B_F) && !eq_B_D &&
				  !eq_E_B && (eq_F_H || eq_E_H) && eq(P,D) && eq(B,G) ) {
                J = admixS(I,F,C,H,E,B,G,D,A,P,PC,PA,Q,QG,QA,AA,eq_F_H,eq_E_H,El,Fl,v3E,v3B);
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
                M = admixS(A,D,G,B,E,H,C,F,I,S,SG,SI,R,RC,RI,II,eq_B_D,eq_E_B,El,Dl,v3E,v3H);
                skiprest = true;}

			//                                    . 🅟
			//                                    A 🅑 C
			//                                  Q D 🄴 🅵 R        Zone 2
			//                                    G H 🅸
			if ( !skiprest && (!slope1 && !eq_B_D) && (!slope4 && !eq_F_H) && !eq_B_F &&
				 !eq_E_B && (eq_D_H || eq_E_H) && eq(P,F) && eq(B,I) ) {
                K = admixS(G,D,A,H,E,B,I,F,C,P,PA,PC,R,RI,RC,CC,eq_D_H,eq_E_H,El,Dl,v3E,v3B);
                skiprest = true;}

		} // vertical right
} // sawslope

// sawslope formed can exit, old scheme: skiprest||slopeBAD (would still utilize slopeOFF (weak shapes) and slopeok (strong shapes) but effect was mediocre)
skiprest = skiprest||slope1||slope2||slope3||slope4;

/**************************************************
 *     "Concave + Cross" type	（P100）	  *
 *************************************************/
//  Cross star's far end uses approximate pixels, useful for some horizontal line + jagged and layered gradient shapes. E.g., glowing letters in Street Fighter III 3rd Strike intro, sfz3mix Japanese houses, Garou: Mark of the Wolves intro

	vec3 v3X;

    if (!skiprest &&
        Bl<El && !eq_E_D && !eq_E_F && eq_E_H && none_eq2(E,A,C) && all_eq2(G,H,I) && sim2(v3E,E,S) ) { // TOP

        if (eq_B_D||eq_B_F) { J=admixK(v3B,J);    K=J;
            if (eq_D_F) { L=mix(J,L, 0.61804);   M=L; }
        } else { v3X = El-Bl < abs(El-Dl) ? v3B : v3D;  J=admixC(v3X,J);
			if (eq_D_F) { K=J;  L=mix(J,L, 0.61804);    M=L; }
			else {v3X = El-Bl < abs(El-Fl) ? v3B : v3F; 		K=admixC(v3X,K); }
            }

	   skiprest = true;
	}

    if (!skiprest &&
		Hl<El && !eq_E_D && !eq_E_F && eq_E_B && none_eq2(E,G,I) && all_eq2(A,B,C) && sim2(v3E,E,P) ) { // BOTTOM

        if (eq_D_H||eq_F_H) { L=admixK(v3H,L);    M=L;
            if (eq_D_F) { J=mix(L,J, 0.61804);   K=J; }
        } else { v3X = El-Hl < abs(El-Dl) ? v3H : v3D;  L=admixC(v3X,L);
			if (eq_D_F) { M=L;  J=mix(L,J, 0.61804);    K=J; }
			else { v3X = El-Hl < abs(El-Fl) ? v3H : v3F;    M=admixC(v3X,M); }
            }

	   skiprest = true;
	}

   if (!skiprest &&
		Fl<El && !eq_E_B && !eq_E_H && eq_E_D && none_eq2(E,C,I) && all_eq2(A,D,G) && sim2(v3E,E,Q) ) { // RIGHT

        if (eq_B_F||eq_F_H) { K=admixK(v3F,K);    M=K;
            if (eq_B_H) { J=mix(K,J, 0.61804);   L=J; }
        } else { v3X = El-Fl < abs(El-Bl) ? v3F : v3B;  K=admixC(v3X,K);
			if (eq_B_H) { M=K;  J=mix(K,J, 0.61804);    L=J; }
			else { v3X = El-Fl < abs(El-Hl) ? v3F : v3H;    M=admixC(v3X,M); }
            }

	   skiprest = true;
	}

    if (!skiprest &&
		Dl<El && !eq_E_B && !eq_E_H && eq_E_F && none_eq2(E,A,G) && all_eq2(C,F,I) && sim2(v3E,E,R) ) { // LEFT

        if (eq_B_D||eq_D_H) { J=admixK(v3D,J);    L=J;
            if (eq_B_H) { K=mix(J,K, 0.61804);   M=K; }
        } else { v3X = El-Dl < abs(El-Bl) ? v3D : v3B;  J=admixC(v3X,J);
			if (eq_B_H) { L=J;   K=mix(J,K, 0.61804);    M=K; }
			else { v3X = El-Dl < abs(El-Hl) ? v3D : v3H;    L=admixC(v3X,L); }
            }

	   skiprest = true;
	}

/*
       ㇿО
     ОООㇿ
	   ㇿО    Scorpion shape (P99). Looks like tracking bug from The Matrix. Can smooth some regularly interleaved pixels
*/
// Practice: 1. Scorpion claws use approximation, otherwise prone to becoming small C shape and causing graphical glitches
// Practice: 2. Remove one segment from scorpion tail to capture more shapes
// Among four shapes, only scorpion is exclusive; once caught by preceding rules (entered), this shape won't appear. Also least noticeable shape. So placed last


   if (!skiprest && !eq_E_F &&eq_E_D&&eq_B_F&&eq_F_H && all_eq2(E,C,I) && noteq(F,src(+3, 0)) ) {K=admixK(v3F,K); M=K;J=mix(K,J, 0.61804); L=J;skiprest=true;}	// RIGHT
   if (!skiprest && !eq_E_D &&eq_E_F&&eq_B_D&&eq_D_H && all_eq2(E,A,G) && noteq(D,src(-3, 0)) ) {J=admixK(v3D,J); L=J;K=mix(J,K, 0.61804); M=K;skiprest=true;}	// LEFT
   if (!skiprest && !eq_E_H &&eq_E_B&&eq_D_H&&eq_F_H && all_eq2(E,G,I) && noteq(H,src(0, +3)) ) {L=admixK(v3H,L); M=L;J=mix(L,J, 0.61804); K=J;skiprest=true;}	// BOTTOM
   if (!skiprest && !eq_E_B &&eq_E_H&&eq_B_D&&eq_B_F && all_eq2(E,A,C) && noteq(B,src(0, -3)) ) {J=admixK(v3B,J); K=J;L=mix(J,L, 0.61804); M=L;}				// TOP

	// final Exit
	vec2 a = fract(pixelPos);	// Reuse pixelPos defined during out-of-bounds check (vTexCoord * params.SourceSize.xy)
	FragColor.rgb = (a.x < 0.5) ? (a.y < 0.5 ? J : L) : (a.y < 0.5 ? K : M);
}
