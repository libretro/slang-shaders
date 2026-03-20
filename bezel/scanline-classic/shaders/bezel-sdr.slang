#version 450

// Filename: bezel-sdr.slang
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
// Bezel with glow effect (SDR version)
// ------------------------------------------------
// Input: linear rec. 709 signal
// Output: rec. 709/sRGB signal

#pragma name Bezel
#pragma format R8G8B8A8_UNORM

#define SDR

#define COLOR_SPACE_TO_XYZ sRGB_TO_XYZ
#define XYZ_TO_COLOR_SPACE XYZ_TO_sRGB

#include "bezel-base.slang"