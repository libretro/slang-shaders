#version 450

// Filename: menu.slang
//
// Copyright (C) 2023, 2025 W. M. Martinez
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
// Menu shader
// ------------
// Input: Passthrough
// Output: Passthrough
//
// Helper shader for loading parameters in the appropriate order.

#include "parameters/user-common.inc"
#include "parameters/user-video.inc"
#include "parameters/user-uncommon.inc"
#include "parameters/output-curve.inc"
#include "parameters/output-tonemap.inc"
#include "parameters/output-color.inc"
#include "parameters/output-color-sdr.inc"
#include "parameters/output-bezel.inc"
#include "parameters/service-geometry.inc"
#include "parameters/scanraster.inc"
#include "parameters/composite.inc"
#include "parameters/display-rgb.inc"
#include "parameters/factory-geometry.inc"
#include "parameters/mask.inc"
#include "parameters/colorimetry.inc"
#include "parameters/phosphor.inc"
#include "parameters/limiter.inc"
#include "parameters/rf.inc"
#include "parameters/sys-timing.inc"
#include "parameters/sys-rgb.inc"
#include "parameters/sys-encode.inc"
#include "parameters/sys-yc.inc"
#include "parameters/debug-common.inc"

#include "menu-base.slang"