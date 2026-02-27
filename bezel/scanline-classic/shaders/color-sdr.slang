#version 450

// Filename: color-sdr.slang
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
// Color converter (SDR version)
// ------------------------------------------------
// Input: Linear RGB signal
// Output: sRGB signal

#pragma name Color
#pragma format R16G16B16A16_SFLOAT

#define SDR
#define XYZ_TO_COLOR_SPACE XYZ_TO_sRGB

#pragma parameter GAMUT_COMPRESSION "Gamut mapping (off, basic, advanced)" 2.0 0.0 2.0 1.0

#include "color-base.slang"