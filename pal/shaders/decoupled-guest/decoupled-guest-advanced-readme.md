Derived from and built on crt-guest-advanced. Fully updated for crt-guest-advanced-2025-11-30-release1.

Relevant sections have been decoupled from the CRT portion of the shader for more granular utility (such as use with other CRT shaders, with use with Megatron as a primary focus).

A number of additional features have also been added:

**GPGX MS color fix**

Corrects Genesis Plus GX's Master System color output, which includes minor errors i discovered while implementing the Sega MS Nonlinear Blue Fix.

* 0=off
* 1=on (color saturation scaled to a maximum value of RGB 255)
* 2=sat239 (scaled to a maximum value of RGB 239)
* 3=sat210 (scaled to a maximum value of RGB 210)
* 4=sat165 (scaled to a maximum value of RGB 165)

**Sega MS Nonlinear Blue Fix**

An implementation of the behavior described in [Notes & Measures: Nonlinear Blue on Sega Master System 1 & Other Findings by bfbiii](https://docs.google.com/document/d/1MrPrSDpp6PmHPx45LzxTVJt2uCfl0MajA8GVtpWcois/edit?tab=t.0).

This setting automatically adjusts to work with the GPGX MS color fix settings.

**Sega MD RGB Palette**

An implementation/approximation of the Mega Drive/Genesis RGB palette as discussed [here](https://github.com/ekeeke/Genesis-Plus-GX/issues/345#issuecomment-1675658598).

**0 IRE Device on 7.5 IRE Display**

This setting automatically modifies the "Raise Black Level" setting to simulate what would have happened if a device with 0 IRE black (NTSC-J standard) were connected to a display calibrated for 7.5 IRE black (NTSC standard). This applies to both the Japanese and US versions of literally every single CRT targeted Japanese designed console other than the PS1 and PS2*, which had regional IRE. (*I haven’t been able to find absolute confirmation that the GameCube and the Wii used 0 IRE universally, but that is the general consensus.)

Note that this issue did not apply for component/YPbPr and RGB connections.

**Downsample Pseudo Hi-Res**

As i understand it, 15KHz CRT displays would treat double-horizontal resolution modes (512x224, 640x240, etc) as tho they were not doubled, resulting in a blending effect, called pseudo hi-res. A number of SFC/SNES games are known to have used this behavior for transparency effects, including Breath of Fire II, Jurassic Park, and Kirby's Dream Land 3, and as far as i know it is the correct behavior for any device originally meant to be displayed on a 15KHz CRT TV/monitor.

* 1 = off

* 2 = Triggers the blending effect whenever the horizontal resolution is more than twice the vertical resolution. This works well with cores that either always output a pseudo hi-res image for compatibility (such as bsnes-jg), or cores that only use pseudo hi-res for pseudo hi-res content (such as SwanStation). True high-resolution/interlaced content is not effected.

* 3 = Triggers the blending effect whenever the horizontal resolution is 480 or higher. This is needed for cores that display pseudo hi-res content in a true high-resolution container (such as Mesen-S and a number of bsnes variants). Unfortunately, this halves the resolution of true high-resolution/interlaced content, as there is no way to differentiate pseudo hi-res and true high-resolution/interlaced content in these cores.

**Horizontal Filtering Resolution**

Modified to allow up to 1/16th downsampling.