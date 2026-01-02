# Scanline Classic

Copyright (c)  2025  W. M. Martinez.

Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.  This file is offered as-is,
without any warranty.

Full, up-to-date source code is available at
https://github.com/anikom15/scanline-classic

A general purpose RetroArch shader with an emphasis on realism while
maintaining a high degree of flexibility and aesthetic quality. 

Version 6.2

README Edition 8

## Quick start

## Preset Overview

Scanline Classic provides a wide range of presets tailored for both consumer and professional video systems. Presets are organized by system and signal type, and are found in the `presets` folder of your install location. Below is an overview of the available presets:

### Consumer Presets

- **sfc.slangp**: Super Famicom (Japan) base preset
- **snes.slangp**: Super Nintendo (North America) base preset
- **snes-br.slangp**: Super Nintendo (Brazil) base preset
- **snes-eu.slangp**: Super Nintendo (Europe) base preset

### Professional Presets

- **sfc-composite.slangp**: Super Famicom (Japan) with composite video signal simulation
- **sfc-rf.slangp**: Super Famicom (Japan) with RF signal simulation
- **sfc.slangp**: Super Famicom (Japan) with RGB signal simulation
- **sfc-svideo.slangp**: Super Famicom (Japan) with S-Video signal simulation
- **snes-composite.slangp**: Super Nintendo (North America) with composite video
- **snes-svideo.slangp**: Super Nintendo (North America) with S-Video
- **snes-rf.slangp**: Super Nintendo (North America) with RF
- **snes-eu-composite.slangp**: Super Nintendo (Europe) with composite video
- **snes-eu-rf.slangp**: Super Nintendo (Europe) with RF
- **snes-gb-rf.slangp**: Super Nintendo (Great Britain) with RF
- **snes-br.slangp**: Super Nintendo (Brazil) professional preset

The Super Nintendo presets are representative for other systems.  For other systems, the distribution included with Libretro/slang-shaders is limited to a consumer and a professional preset for each major region (Japan, America, and Europe).  A full set of presets can downloaded from the EXTRAS distribution.

Each preset is designed to closely match the characteristics of the original hardware and signal path, including colorimetry, geometry, and signal artifacts. Use these as starting points for your own customizations or as reference-quality emulation targets.

For more details on each preset and its intended use, see the corresponding `.json` file in `presetdata/input/consumer/` or `presetdata/input/professional/`
in the source code distribution.

## RetroArch Usage Guidance

For best results with Scanline Classic presets in RetroArch:

- Set **Aspect Ratio** to **16:9** in Video > Scaling. This ensures correct geometry for most presets and modern displays.
- Set **Integer Scale** to **Off**. This allows the shader's geometry and curvature controls to work as intended and avoids unwanted cropping or pillarboxing.
- After loading a preset, go to **Quick Menu > Shaders > Apply Changes** to activate it.
- To save your configuration for future sessions, use **Quick Menu > Shaders > Save > Save Game Preset** (for per-game) or **Save Core Preset** (for all games on the current core).

These settings help ensure the presets display as designed and make it easy to recall your preferred look.

## Installing additional presets

Download the latest EXTRAS release from github and copy the files your installation folder.  For Retroarch, this would be shaders/shaders_slang/bezel/scanline-classic.

## Building the Shader Presets

The presets are built dynamically from a Python script, `build.py`.  See `external/presetgen` for dependency information.
After building, the shaders can be found in the `out` directory.

## Usage

### Shaders

* **beam-mask.slang**: Beam mask simulation for CRT effects.
* **bezel-base.slang, bezel-sdr.slang, bezel-wcg.slang**: Bezel overlay shaders for standard dynamic range (SDR) and wide color gamut (WCG) displays.
* **color-base.slang, color-sdr.slang, color-wcg.slang**: Color processing shaders for SDR and WCG output.
* **composite-demod.slang, composite-iq.slang, composite-mod.slang, composite-prefilter.slang**: Composite video signal simulation and processing.
* **crt-linear.slang**: Linear CRT simulation pass.
* **curve.slang**: Screen curvature simulation.
* **display-component.slang, display-rgb-bandlimit.slang**: Output stage and bandlimiting for component/RGB signals.
* **frame.slang**: Frame effects and overlays.
* **iq-demod.slang, iq-filter.slang, iq-noise.slang**: I/Q demodulation and noise simulation for analog signals.
* **limiter.slang**: Output limiter for signal range.
* **phosphor-chroma.slang, phosphor-luma.slang, phosphor-trichrome.slang**: Phosphor decay and color simulation.
* **stock.slang**: Stock/utility shader pass.
* **svideo.slang, yc-composite.slang, yc-svideo.slang**: S-Video and Y/C signal simulation.
* **sys-component.slang, sys-display-rgb-bandlimit.slang, sys-rgb-amp.slang, sys-rgb-bandlimit.slang, sys-yc.slang**: System-level signal and bandlimit simulation.

### Parameters

For details about all the parameters available in the shader, see `doc/PARAMETERS.md`

### SDR and WCG Shaders

**SDR (Standard Dynamic Range) shaders** (e.g., `*-sdr.slang`) are designed for typical displays with standard color gamuts and brightness. **WCG (Wide Color Gamut) shaders** (e.g., `*-wcg.slang`) are optimized for displays that support a wider color space and higher dynamic range, providing richer and more accurate color reproduction. Use the WCG variants if your display supports wide color gamuts (such as DCI-P3 or BT.2020), otherwise use the SDR versions for best compatibility.

## Bugs

Report bugs to [W. M. Martinez](mailto:anikom15@outlook.com).

## Credits

Design and Programming
* W. M. Martinez

Original Mitchell-Netravali Shader Authors
* [Team XBMC](http://www.xbmc.org)
* [Stefanos A.](http://www.opentk.com)