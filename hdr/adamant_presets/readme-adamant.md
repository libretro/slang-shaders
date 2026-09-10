Adamant is the next iteration of my AzMods project, centered on CRT Adamant, a fork of Sony Megatron Colour Video Monitor v2.6.1 (2026.01.21) by MajorPainTheCactus, and hdr-config-adamant, an enhanced backport of the hdr-config shader from v2.6.2 (2026.01.26) to match the structure of v2.6.1.

Changes in Megatron v2.6.5+ have radically reduced color accuracy on at least WOLED displays, while also making the simulated phosphor patterns less similar to those seen on real CRTs, with no actual benefit that i can see. As a result, i have continued using and modifying v2.6.1, and i have decided it is time to officially fork.

Unless otherwise labeled, all included presets were made on made on my LG C1, targeting ~800 nit WOLEDs.
My personal philosophy for preset creation is what i consider a "best of all worlds" approach.
While i've never been a fan of things like CRT curvature or RF noise, bringing together the color gamut and pixel blending of a CRT, the perfectly tuned geometry of flat panels, and perfect OLED black, can give results that are quite magnificent in my opinion.

Presets in the adamant_presets_WOLED folder should be used *only on OLEDs*.
Please use the presets in the adamant_presets_LCD_SAFE folder if you are using an LCD display.

Additionally, i have made the following modifications and improvements:

**Content Color Gamut**

This setting allows you to change the simulated phosphor primaries, better matching the colors seen on actual CRTs and panels of various types from different regions and eras.

When using this setting in CRT Adamant, Colour System should be left set to the default of 0/r709, and Phosphors to 0/NONE for maximum color accuracy.

Options are as follows:

* 0:CBS field-sequential color (A slightly silly inclusion, but this should approximate the gamut of CBS's short lived color mechanical television system, which was technically the first consumer color television format. They only sold ~100 receivers, and purportedly bought most of them back to avoid lawsuits, but that is beside the point. The most fascinating aspect to me is how close the gamut is to Display P3. History rhyming and such.) [https://www.earlytelevision.org/Deksnis/1951_cbs_color_2004.html]

* 1:NTSC 1953 Paper Standard (The NTSC 1953 paper standard. According to "TV Display Phosphors/Primaries — Some History", the blue phosphor it standardized is incorrect, perhaps as the result of a typo or a contaminated sample, and it was never actually contemporaneously used for real displays. See 1953RP for the true 1953 NTSC Receiver phosphors.)

* 2:1953 Receiver Phosphors (The actual OG consumer color system... that was still only really used for 5-8ish years back when basically no one owned a color TV anyway. If you are Brazilian or from a SECAM region, it may also match some old CRT TVs you’ve used with really weirdly intense greens? Hard to say. This sort of thing is kind of underdocumented. Sometimes called XXA)

* 3:1961 Receiver Phosphors (Receiver phosphors used starting somewhen around 1958-1961, as documented by TV Display Phosphors/Primaries — Some History. Sometimes called XXB. Millennial’s grandparent’s old TV with weird colors #1.)

* 4:1964 Receiver Phosphors (~1964 receiver phosphors, sometimes called XXC, as documented by Phosphor Handbook, CRC Press, 2006. Millennials' grandparents' old TV with weird colors #2.)

* 5:PAL/EBU (The Baseline standard gamut for Analog PAL finalised in 1967.)

* 6:Rec601 (A set of controlled phosphors developed by Conrac and RCA circa 1968-1969, which ultimately became the baseline standard gamut for Analog NTSC.)

* 7:Dogway’s NTSC-J (Baseline standard gamut for Analog NTSC-J that evolved over the course of the late 60 and 70s. There may have been two or three semi-distinct NTSC-J gamuts: ~1971-1976, ~1977+, and maybe ~1960-1970, with Dogway's presumably most closely capturing the version seen from ~1977+.)

* 8:1970s Receiver Phosphors (Receiver phosphors used starting around the early 70s.)

* 9:1980s Receiver Phosphors (Receiver phosphors used starting somewhere in the 80s.)

* 10:AppleRGB/Trinitron (This is the approximate gamut of Trinitron TVs and Monitors made starting from no later than 1987. Possibly even from the very begining in 1968. The standard it inspired is named Apple RGB, derived from the AppleColor High-Resolution RGB Monitor, which was a Trinitron.)

* 11:guest's Philips PC (Gamut used by a number of extremely popular monitors that used Philips tubes, including Philips CM8533, Philips VS-0080, and Commodore 1084)

* 12:P22-80 (Dogway’s Grade gamut for 1980s-early 1990s TVs.)

* 13:P22-90 (Dogway’s Grade gamut for mid 1990s TVs with tinted phosphors. Likely not representative of any actual displays based on research done by ChthonVII.)

* 14:Dogway's RPTV (Gamut for late 90s, early 00s NTSC-U Rear Projection TVs. The ones that game manuals said you shouldn’t play games on due to burn in risk.)

* 15:GBA (The approximate gamut used by the GBA AGB-001, GBA SP AGS-001, DS, and GBA Micro. Red and green primaries are derived from VisualBoyAdvance's "Gameboy Colors" option, with the blue primary from the [2023-07-24][Top][Pokefan531] colorimeter reading.)

* 16:PSP (PSP 1000 and 2000's approximate gamut.)

* 17:Rec709 (The standard SDR HDTV/PC gamut.)

* 18:AdobeRGB (The first modern wide color gamut. Standardized in 1998, with displays actually supporting it appearing as early as 2005.)

* 19:DSLite (The approximate gamut used by the GBA SP AGS-101, DS Lite, DSi, DSi XL, 3DS, 3DS XL, Wii U Gamepad, New 3DS, and New 3DS XL.)

* 20:iPhone(PH) (The iPhone 1-4/iPad 1-2 gamut. Currently undocumented. A repeat of Rec709 has been used as a placeholder.)

* 21:PSP3K(PH) (PSP 3000, Go, and Street's gamut. Currently undocumented. A repeat of Rec709 has been used as a placeholder.)

* 22:DisplayP3 (Probably the most common wide color gamut. A variant on the gamut used for film with shared primaries.)

* 23:AMOLED(PH) (AMOLED mobile phone screen gamut. Currently undocumented. A repeat of Rec709 has been used as a placeholder.)

* 24:PSV(PH) (The original Vita "Phat"/OLED gamut. Currently undocumented. A repeat of Rec709 has been used as a placeholder.)

* 25:PSV2K(PH) (The Vita Slim/LCD gamut. Currently undocumented. A repeat of Rec709 has been used as a placeholder.)

* 26:Expanded 709 (A custom color space which seems to have been generated at Microsoft circa 2015-2017 to "enhance" colors, purportedly to compensate for poor tonemapping on some early HDR displays.)

* 27:Rec2020 (Standard HDR container gamut.)

**(CRT Adamant) New Display Subpixel Layout for BWRG and BRG displays**

The LG G5 has an BWRG subpixel layout, necessitating the addition of this option.

**(CRT Adamant) Downsample Pseudo Hi-Res compatibility**

As i understand it, 15KHz CRT displays would treat double-horizontal resolution modes (512x224, 640x240, etc) as tho they were not doubled, resulting in a blending effect, called pseudo hi-res. A number of SFC/SNES games are known to have used this behavior for transparency effects, including Breath of Fire II, Jurassic Park, and Kirby's Dream Land 3, and as far as i know it is the correct behavior for any device originally meant to be displayed on a 15KHz CRT TV/monitor.

This setting has been built to integrate seamlessly with the setting of the same name in decoupled-guest-advanced-ntsc and decoupled-guest-advanced-pal.

* 1 = off

* 2 = Triggers the blending effect whenever the horizontal resolution is more than twice the vertical resolution. This works well with cores that either always output a pseudo hi-res image for compatibility (such as bsnes-jg), or cores that only use pseudo hi-res for pseudo hi-res content (such as SwanStation). True high-resolution/interlaced content is not effected.

* 3 = Triggers the blending effect whenever the horizontal resolution is 480 or higher. This is needed for cores that display pseudo hi-res content in a true high-resolution container (such as Mesen-S and a number of bsnes variants). Unfortunately, this halves the resolution of true high-resolution/interlaced content, as there is no way to differentiate pseudo hi-res and true high-resolution/interlaced content in these cores.

**(CRT Adamant) Scanline Multiplier/Divisor**

Multiplies or divides the number of scanlines.

Useful for cases like DOS games meant for 31KHz displays, which output 320x200 that was then double scanned to 640x400.

The divisor options are handy for displaying increased internal resolution output from 3D cores that don't include a good downsample option, such as PPSSPP. I strongly recommend using this setting in conjunction with decoupled-guest's Internal Resolution setting to reduce shimmering.

* -1,0,1=1x (Default/off)
* 2=2x (Doublescan)
* 3=Auto 2x (Automatically doublescans any content with a vertical resolution of less than 300, while leaving higher resolution content unchanged)
* -2=1/2 (Reduces the scanline count to one half default)
* -3=1/3 (Reduces the scanline count to one third default)
* -4=1/4 (Reduces the scanline count to one quarter default)
* -5=1/5 (etc.)
* -6=1/6
* -7=1/7
* -8=1/8
* -9=1/9
* -10=1/10
* -11=1/11
* -12=1/12
* -13=1/13
* -14=1/14
* -15=1/15
* -16=1/16

**(GBA Adamant) VisualBoyAdvance "Gameboy Colors" LUT-based Approximation**

I was not satisfied with any of the existing replacement options for this setting, so i made my own LUT by utilizing the GBA 240p test suite, an image viewer, and a 15-bit palette test image. It isn't quite a perfect recreation, but it is *extremely* close in my opinion.

**Additional Notes**

Test versions may also include some or all of the following, sometimes in modified form:

* Image Adjustment (2024.02.07) by hunterk
* decoupled-guest-advanced-ntsc/pal by Azurfel, based on crt-guest-advanced by guest.r and Dr. Venom, based in part on Themaister's NTSC shader
* bfi-simple by hunterk

I have used no AI/LLM tools, programs, sites, or applications in the preparation of these shaders, or in the process of preparing any text. I remain deeply, fundamentally skeptical of their actual utility and value, especially when taking full account of downstream negative effects.