/*
  ____  _          _
 |  _ \(_)_  _____| |
 | |_) | \ \/ / _ \ |
 |  __/| |>  <  __/ |
 |_|___|_/_/\_\___|_|
 |_   _| __ __ _ _ __  ___ _ __   __ _ _ __ ___ _ __   ___ _   _
   | || '__/ _` | '_ \/ __| '_ \ / _` | '__/ _ \ '_ \ / __| | | |
   | || | | (_| | | | \__ \ |_) | (_| | | |  __/ | | | (__| |_| |
   |_||_|  \__,_|_| |_|___/ .__/ \__,_|_|  \___|_| |_|\___|\__, |
                          |_|              GRID PARAMETERS  |___/
    v3.0 by mattakins
    Copyright (C) 2025-2026 Matt Akins.

    Grid controls shared by all six grids. Each family's parameters.inc holds
    its own controls and uniform layout, then includes this file.

*/

// Each family declares PT_GRID first so it heads the grid section, and
// includes this file after its own controls so these close the section. They
// mix grid brightness into pixel transparency. In Accurate placement the LCD
// input is grid-free, so they have no effect there.
#pragma parameter PT_GRID_COLOR_MIX		"      ↳ Line visibility on color pixels (Soft only)" 0.0 0.0 1.0 0.05
#pragma parameter PT_GRID_WHITE_MIX		"      ↳ Line visibility on white pixels (Soft only)" 0.0 0.0 1.0 0.05
