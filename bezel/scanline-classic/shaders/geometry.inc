/* Filename: geometry.h

   Copyright (C) 2023 W. M. Martinez

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>. */ 

// ==== CRT Geometry Simulation and Correction ====
//
// This header provides functions to simulate CRT display geometry distortions
// and the correction techniques used in real CRT monitors.
//
// DISTORTION TYPES:
// 
// 1. Pincushion Distortion (linear/electrostatic)
//    - Simulates electron beam deflection in CRTs
//    - Creates inward curvature at edges (corners pinched inward)
//    - Two variants: linear (electrostatic) and non-linear (magnetic)
//
// 2. Magnetic Pincushion Correction
//    - Simulates correction magnets on the deflection yoke
//    - Applies inverse pincushion to partially cancel deflection distortion
//    - Applied AFTER initial pincushion, BEFORE barrel distortion
//    - Typical correction strength: 0.3-0.7 (partial correction, not full)
//
// 3. Barrel Distortion
//    - Simulates curved CRT screen surface
//    - Creates outward curvature (edges bowed outward)
//    - Mathematical inverse of pincushion for the same THETA parameter
//    - Applied AFTER deflection corrections
//
// TYPICAL CRT GEOMETRY PIPELINE:
//
// 1. Pincushion (deflection yoke) -> creates initial distortion
// 2. Magnetic correction (correction magnets) -> partially cancels pincushion
// 3. Barrel (screen curvature) -> further compensation from curved screen
// 4. Electronic corrections (trapezoid, S-correction, corner) -> final tweaks
//
// CORRECTION HIERARCHY:
//
// Physical corrections (happen in the CRT hardware):
//   - Magnetic correction: Adjustable magnets on deflection yoke
//     Typical strength: 30-70% (full correction would require impractical magnet strength)
//
// Electronic corrections (happen in the monitor's digital processor):
//   - Trapezoid: Coarse horizontal width adjustment
//   - S-correction: Fine parabolic compensation (most important)
//   - Corner correction: Localized corner adjustments
//
// High-end CRT monitors combined all these techniques to achieve near-perfect
// geometry. Consumer CRTs typically used only magnetic + basic electronic corrections.
//
// CORRECTION TECHNIQUES:
//
// 1. Trapezoid Correction
//    - Adjusts horizontal scan width based on vertical position
//    - Compensates for top/bottom edge distortion
//    - Simple, fast, effective for basic correction
//
// 2. S-Correction (Parabolic Correction)
//    - Most common in real CRT monitors
//    - Independent horizontal and vertical compensation
//    - Uses quadratic relationship to match deflection characteristics
//
// 3. Corner Correction
//    - Localized correction for the four corners
//    - Uses fourth-order term (x²y²) for corner-specific adjustment
//    - Fine-tunes after broader corrections
//
// USAGE NOTES:
//
// - All distortion functions expect normalized coordinates in "square space"
//   (aspect ratio compensation applied before distortion)
// - Pincushion and barrel are approximate inverses; perfect inversion only
//   occurs near the center due to cross-coupled terms
// - Corrections should be applied AFTER distortions to simulate real CRT
//   geometry correction pipeline
// - THETA parameter is in radians; typical range: 0 to π/2
//
// ==== End Documentation ====

// Pincushion distortion (linear/electrostatic)
// uv: coordinates in square space (aspect ratio pre-applied)
// Inverse of barrel distortion for the same THETA value
vec2 pincushion(vec2 uv)
{
    float distorted_x = uv.x;
    float distorted_y = uv.y;

    distorted_x = atan(uv.x * cos(uv.y));
    distorted_y = atan(uv.y * cos(uv.x));
    return vec2(distorted_x, distorted_y);
}

// Pincushion distortion non-linear (magnetic)
// uv: coordinates in square space (aspect ratio pre-applied)
vec2 pincushion_nl(vec2 uv)
{
    float distorted_x = uv.x;
    float distorted_y = uv.y;

    distorted_x = atan(asin(uv.x) * cos(asin(uv.y)));
    distorted_y = atan(asin(uv.y) * cos(asin(uv.x)));
    return vec2(distorted_x, distorted_y);
}

vec2 barrel(vec2 uv)
{
    float distorted_x = uv.x;
    float distorted_y = uv.y;

    distorted_x = tan(uv.x) / cos(uv.y);
    distorted_y = tan(uv.y) / cos(uv.x);
    return vec2(distorted_x, distorted_y);
}

// Magnetic pincushion correction (inverse pincushion)
// Simulates correction magnets placed around the CRT deflection yoke
// These generate compensating magnetic fields that partially cancel deflection distortion
// uv: coordinates in square space (aspect ratio pre-applied)
// strength: correction strength (0.0 = no correction, 1.0 = full inverse of THETA distortion)
// THETA: the deflection angle parameter being corrected
//
// Physics: Real CRTs use permanent magnets or electromagnets to create opposite
// distortion fields. This function applies a partial inverse of pincushion distortion.
// Unlike barrel distortion (which corrects for screen curvature), this specifically
// targets the electromagnetic deflection distortion itself.
vec2 magnetic_correction(vec2 uv, const float strength, const float THETA)
{
    // Apply inverse pincushion at reduced strength
    // This is essentially a scaled version of barrel distortion
    // but applied in the deflection phase rather than for screen curvature
    float effective_theta = THETA * strength;
    
    if (effective_theta < 0.001) return uv;
    
    // Apply inverse transformation (same math as barrel, but scaled by correction strength)
    vec2 uv_corrected = uv * effective_theta;
    uv_corrected.x = tan(uv_corrected.x) / cos(uv_corrected.y);
    uv_corrected.y = tan(uv_corrected.y) / cos(uv_corrected.x);
    
    return uv_corrected / effective_theta;
}

// ==== Geometric Correction Functions ====
// These simulate the correction circuits used in real CRT monitors
// to compensate for residual pincushion distortion

// Trapezoidal correction - adjusts horizontal width based on vertical position
// Simulates dynamic horizontal scan width adjustment used in CRT monitors
// Positive strength expands the top/bottom, negative compresses them
vec2 trapezoid(vec2 uv, const float strength)
{
    // Adjust horizontal scale based on vertical position
    // Uses quadratic relationship to match CRT deflection characteristics
    float scale = 1.0 + strength * uv.y * uv.y;
    uv.x *= scale;
    return uv;
}

// Corner correction - adds localized distortion to square up corners
// Simulates corner magnets or digital corner correction circuits
// Pushes corners outward (positive) or inward (negative) to compensate for pincushion
vec2 corner_correction(vec2 uv, const float strength)
{
    // Calculate squared distance for each axis
    float x2 = uv.x * uv.x;
    float y2 = uv.y * uv.y;
    
    // Apply correction that's strongest at corners (where both x and y are large)
    // Fourth-order term (x²y²) ensures correction is localized to corners
    float corner_factor = x2 * y2;
    
    // Push corners outward to counteract pincushion
    uv.x *= 1.0 + strength * corner_factor;
    uv.y *= 1.0 + strength * corner_factor;
    
    return uv;
}

// S-correction (parabolic correction) - most common in CRT monitors
// Simulates the analog S-correction circuit found in CRT geometry processors
// Each axis can be corrected independently with different strengths
vec2 s_correction(vec2 uv, const float h_strength, const float v_strength)
{
    // Parabolic correction applied independently to each axis
    // Counteracts the natural parabolic distortion of CRT electron beam deflection
    // Horizontal width varies with vertical position (and vice versa)
    uv.x *= 1.0 + h_strength * uv.y * uv.y;
    uv.y *= 1.0 + v_strength * uv.x * uv.x;
    return uv;
}

// Combined geometric correction - applies multiple correction techniques in sequence
// This is what high-end CRT monitors did with their digital geometry processors
// Order of operations matters due to interaction between corrections
vec2 geometric_correction(vec2 uv, 
                          const float trap_strength, 
                          const float corner_strength, 
                          const float s_h_strength, 
                          const float s_v_strength)
{
    // Early exit if no corrections are needed (optimization)
    if (abs(trap_strength) < 0.001 && abs(corner_strength) < 0.001 && 
        abs(s_h_strength) < 0.001 && abs(s_v_strength) < 0.001)
        return uv;
    
    // Apply corrections in order (mimics real CRT correction pipeline)
    // 1. Trapezoid correction - coarse adjustment of horizontal edges
    if (abs(trap_strength) > 0.001)
        uv = trapezoid(uv, trap_strength);
    
    // 2. S-correction - fine adjustment for parabolic distortion
    if (abs(s_h_strength) > 0.001 || abs(s_v_strength) > 0.001)
        uv = s_correction(uv, s_h_strength, s_v_strength);
    
    // 3. Corner correction - final localized adjustment for corners
    if (abs(corner_strength) > 0.001)
        uv = corner_correction(uv, corner_strength);
    
    return uv;
}
