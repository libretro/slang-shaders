// zebra.inc
//
// Copyright (C) 2025 W. M. Martinez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// Zebra pattern overlay for visualizing out-of-range values
// ----------------------------------------------------------
// Generates an animated checkerboard pattern to highlight values
// outside a specified range.

// Apply zebra pattern to visualize out-of-range colors
// Parameters:
//   color: Input color to check and potentially modulate
//   low: Minimum acceptable value (values below this are flagged)
//   high: Maximum acceptable value (values above this are flagged)
//   texCoord: Texture coordinates for spatial pattern
//   outputSize: Output resolution for spatial frequency calculation
//   frameCount: Frame counter for temporal animation
//   frequencyMult: Multiplier for spatial frequency (higher = finer pattern)
// Returns:
//   Color modulated by zebra pattern if out of range, otherwise unchanged
vec3 zebra(vec3 color, float low, float high, vec2 texCoord, vec2 outputSize, uint frameCount, float frequencyMult)
{
    bvec3 outOfRange = bvec3(
        color.r < low || color.r > high || isinf(color.r) || isnan(color.r),
        color.g < low || color.g > high || isinf(color.g) || isnan(color.g),
        color.b < low || color.b > high || isinf(color.b) || isnan(color.b)
    );
    
    if (!any(outOfRange)) {
        return color;
    }
    
    // Create animated temporal square wave (cycles over ~60 frames at 60fps)
    float temporalPhase = float(frameCount) * 0.1;
    float temporalSquare = sign(sin(temporalPhase)) * 0.5 + 0.5; // Square wave: 0.0 or 1.0
    
    // Create spatial square wave pattern (checkerboard-like)
    float spatialPhase = (texCoord.x + texCoord.y) * outputSize.x / 2.0 * frequencyMult;
    float spatialSquare = sin(spatialPhase) * 0.5 + 0.5; // Square wave: 0.0 or 1.0
    
    // Combine temporal and spatial patterns with XOR-like behavior
    float modulation = abs(temporalSquare - spatialSquare);
    
    // Modulate out-of-range channels with the combined pattern
    vec3 debugMask = vec3(
        outOfRange.r ? modulation : 1.0,
        outOfRange.g ? modulation : 1.0,
        outOfRange.b ? modulation : 1.0
    );
    
    return color * debugMask;
}
