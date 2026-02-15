#version 450

// Filename: color-hdr.slang
//
// Copyright (C) 2026 W. M. Martinez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// Color converter (High dynamic range (HDR) version)
// ------------------------------------------------
// Input: Linear YrYgYb signal
// Output: sRGB PQ signal

#pragma name Color
// #pragma format A2B10G10R10_UNORM_PACK32
#pragma format R16G16B16A16_SFLOAT

#define WIDE_COLOR
#define HDR
#define SCRGB_OUTPUT

#define XYZ_TO_COLOR_SPACE XYZ_TO_BT2020
//#define XYZ_TO_COLOR_SPACE XYZ_TO_sRGB

#include "color-base.slang"