# Scanline Classic

Copyright (c)  2025-2026  W. M. Martinez.

Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.  This file is offered as-is,
without any warranty.

Full, up-to-date source code is available at
https://github.com/anikom15/scanline-classic

A general purpose RetroArch shader with an emphasis on realism while
maintaining a high degree of flexibility and aesthetic quality. 

Version 10.1

README Edition 11

## Quick Start

### Users

1. Install Scanline Classic presets to your RetroArch slang shader path (typically `shaders/shaders_slang/bezel/scanline-classic`).
2. In RetroArch, load a preset, then run **Quick Menu > Shaders > Apply Changes**.
3. Recommended RetroArch scaling defaults: **Aspect Ratio = Full**, **Integer Scale = Off**.

### Developers

1. Build presets: `python build.py`
2. Build with shader lint gate: `python build.py --lint-shaders`
3. Build with strict shader-structure gate: `python build.py --lint-shaders --strict-structure`

Generated presets are written to `out/`.

### Global Options

Scanline Classic ships with a global options skeleton at `config/options.skel.cfg`.
To use it, copy it to `config/options.cfg` in your Scanline Classic install, then uncomment the `#define` lines you want to enable.
This lets you turn on global compile-time options such as disabling bezel rendering and forcing flat geometry.

## Prerequisites

- RetroArch with Slang shader support.
- Python 3 for local builds (`python build.py`).

## User Performance Requirements

Use this quick guide when choosing a preset/resolution target.

| Requirement Tier | GPU Target | Target Resolution |
| --- | --- | --- |
| Minimum | NVIDIA GeForce GTX 1050 (or equivalent) | 1280x800 |
| Recommended | NVIDIA GeForce RTX 3060 | 3840x2160 (4K) |

These are practical baseline targets for full Scanline Classic pipelines (e.g. composite, RF, glow). Lighter presets (fewer signal-processing stages, reduced effects, or no bezel) generally run faster.

## Baseline Performance (Estimated, Developer Notes)

Performance depends on the selected preset, output resolution, driver stack, RetroArch settings, and emulator/core load. As a baseline reference:

- **Minimum practical target:** NVIDIA GeForce GTX 1050 (or equivalent) at **1280x800**
- **Recommended target:** NVIDIA GeForce RTX 3060 at **3840x2160 (4K)**

These estimates are anchored to the `professional/famicom-av.slangp` chain (16 shader passes including Rcomposite simulation, CRT, mask, and bezel), which has been verified to run full speed at 4K on an RTX 4060 Ti.

Rough scaling expectation:

- 4K renders about **8.1x** as many pixels as 1280x800.
- The `famicom-av` preset is one of the heavier pipelines due to its multi-stage analog encode/decode path before CRT/output passes (RF pipelines are heavier, however).
- Given the 4060 Ti 4K full-speed reference, a GTX 1050 at 1280x800 is a realistic minimum baseline for similar presets, while an RTX 3060 is a realistic 4K target with useful headroom.

For lighter presets (fewer signal-processing passes, no bezel, or reduced effects), expected performance is typically better than this baseline.

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

The Super Nintendo presets are representative for other systems. For other systems, the distribution included with Libretro/slang-shaders is limited to a consumer and a professional preset for each major region (Japan, America, and Europe). A full set of presets can be downloaded from the EXTRAS distribution.

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

## Global configuration options

The distribution includes `config/options.skel.cfg` as a template for optional global shader defines.
To use global options:

1. Copy `config/options.skel.cfg` to `config/options.cfg`.
2. Uncomment the `#define` lines you want to enable.
3. Keep `options.skel.cfg` unchanged; keep your customizations in `options.cfg`.

Global options are compile-time toggles, so they affect shader behavior globally rather than per-preset.

Available options in the skeleton include:

- `OPTION_DEBUG`: enables debug parameters in shaders
- `OPTION_NOBEZEL`: disables bezel and glow rendering
- `OPTION_NOGLOW`: disables glow rendering when bezel is enabled
- `OPTION_NOBEZEL_ZOOM <value>`: zoom compensation when bezel is disabled (default `1.07`)
- `OPTION_NOCOLOR`: disables color correction (effectively Rec.709 behavior)
- `OPTION_NOCAT`: disables chromatic adaptation
- `OPTION_FLAT`: forces flat geometry with no curvature or distortion
- `OPTION_NOSCANLINES`: disables blank scanlines
- `OPTION_NOMASK`: disables mask effects
- `OPTION_NOPHOSPHOR`: disables phosphor decay effects
- `OPTION_CRISPY`: disables R/G/B/Y bandwidth filters (and sharpening circuit), while keeping chroma/special filters active

## Installing additional presets

Download the latest EXTRAS release from GitHub and copy the files to your installation folder. For RetroArch, this is typically `shaders/shaders_slang/bezel/scanline-classic`.

## Building the Shader Presets

The presets are built dynamically from a Python script, `build.py`.  See `external/presetgen` for dependency information.
After building, the shaders can be found in the `out` directory.

## Linting shader formatting

To keep `.slang` and `.inc` formatting consistent in `shaders/`, run:

- `python scripts/lint_shaders.py`

For stricter structural checks (stage flow, universal declaration placement, and push/UBO structure checks), run:

- `python scripts/lint_shaders.py --strict-structure`

For safe automatic cleanup (trailing whitespace, excessive blank lines, EOF newline):

- `python scripts/lint_shaders.py --fix`

To gate builds on shader lint, run:

- `python build.py --lint-shaders`

To gate builds on strict structural shader lint, run:

- `python build.py --lint-shaders --strict-structure`

To enable local pre-commit shader lint in this repo, run once:

- `git config core.hooksPath .githooks`

Default lint checks include:

- Spaces-only policy (tab characters are not allowed)

Strict-mode lint checks (`--strict-structure`) include:

- Enforced order in `.slang` files: parameter pragmas -> push block definition -> push semantic defines -> UBO definition -> UBO semantic defines
- Push-constant size budgeting against a 128-byte limit
- Push/UBO optimization warning when push constants are below 128 bytes and non-`MVP` semantics still live in UBO (evaluated against max possible push size across conditional paths)
- Stage flow in `.slang`: exactly 1 vertex section and 1 fragment section, ordered as universal declarations -> vertex -> fragment
- `.inc` files must not declare shader stages (`#pragma stage vertex|fragment`)
- Universal functions/variables in `.slang` are expected to be shared by both vertex and fragment; stage-specific declarations are flagged for relocation into their respective section
- Intentional exceptions can be explicitly marked with `// lint: allow-stage-local` immediately above a declaration when stage-local placement is required

For day-to-day authoring guidance, see `doc/SHADER_AUTHORING_CHECKLIST.md`.

Continuous integration runs build-path lint gating via `.github/workflows/shader-lint.yml`.
CI executes `python build.py --lint-shaders --jobs 1` by default, and uses `python build.py --lint-shaders --strict-structure --jobs 1` for `master` pushes and pull requests targeting `master`.

## Usage

### Shaders

The shader pipeline is modular and grouped by function (system signal path, encoding/decoding, CRT simulation, output transform, and bezel/glow composition).
See the `shaders/` directory for the complete and current pass set.

### Parameters

For details about all the parameters available in the shader, see `doc/PARAMETERS.md`

### SDR, WCG, and HDR Shaders

**SDR (Standard Dynamic Range) shaders** (e.g., `*-sdr.slang`) are designed for typical displays with standard color gamuts and brightness. **WCG (Wide Color Gamut) shaders** (e.g., `*-wcg.slang`) are optimized for displays that support a wider color space and higher dynamic range, providing richer and more accurate color reproduction. **HDR (High Dynamic Range) shaders** (e.g., `*-hdr.slang`) target HDR-capable displays and are currently in beta; expect occasional changes and verify results on your own display. Use the WCG or HDR variants if your display supports BT.2020, otherwise use the SDR versions for best compatibility.

## Bugs

Report bugs to [anikom15](mailto:anikom15@outlook.com).

## Credits

Design and Programming
* W. M. Martinez

Original Mitchell-Netravali Shader Authors
* [Team XBMC](http://www.xbmc.org)
* [Stefanos A.](http://www.opentk.com)