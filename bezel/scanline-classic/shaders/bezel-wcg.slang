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
// Bezel with glow effect (WCG version)
// ------------------------------------------------
// Input: linear rec. BT.2020 signal
// Output: BT.2020 signal

#pragma name Bezel
#pragma format A2B10G10R10_UNORM_PACK32

#define WIDE_COLOR
#define WCG

#define COLOR_SPACE_TO_XYZ (GAMUT_SELECT < 0.5 ? BT2020_TO_XYZ : DCIP3_TO_XYZ)
#define XYZ_TO_COLOR_SPACE (GAMUT_SELECT < 0.5 ? XYZ_TO_BT2020 : XYZ_TO_DCIP3)

#pragma parameter GAMUT_SELECT "Output gamut (BT.2020, DCI-P3)" 0.0 0.0 1.0 1.0

#include "bezel-base.slang"