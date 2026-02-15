#version 450

// Filename: bezel-wcg.slang
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
// Input: sRGB signal
// Output: sRGB signal

#pragma name Bezel
#pragma format A2B10G10R10_UNORM_PACK32
//#pragma format R16G16B16A16_SFLOAT

#define HDR
#define SCRGB_OUTPUT

#include "bezel-base.slang"