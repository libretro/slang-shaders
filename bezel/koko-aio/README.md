# Koko-aio

Koko-aio shader is meant to be an all-in one crt shader.<br>
It can be configured with many parameters, so that can be
scaled to run on even on modest gpus while still developed to
run with heavier presets on at least Haswell+ iGpus.<br>
On that gpu, as in version 3.5, it reaches about 85fps with all features enabled<br>
When dealing with lowres content on 1920x1080 resolution.<br>
While it is not meant to simulate the internal behaviour of CRT displays,<br>
it aims to give users "visual" parameters to make their monitors look similar.<br>
Several presets are included.<br>

***Additional documentation:***
* [See here](docs.md)

***Additional artwork:***
* https://github.com/kokoko3k/koko-aio-slang-presets-and-overlays

***Actually, it provides emulation for:***
* Scanlines
* Screenlines
* RGB phosphors
* RGB deconvergence
* NTSC/PAL CVBS color bleeding
* NTSC color artifacting (early stage)
* Aperture grille and slot mask.
* Input signal glowing
* Output signal glowing
* Blooming
* Gamma, contrast, saturation, luminance, color temperature adjustments
* Black frame insertions through alternate blanking
* Interlace flickering, forcing and emulation
* Antialiasing
* Curvature
* Ambient lights
* Vignette and Spotlight
* Bezel (Thank you HyperspaceMadness for allowing me to rip his automagically generated bezel!)
  https://github.com/HyperspaceMadness/
* Background images
* Full screen glowing

***External code by:***
* Nvidia (FXAA)
* EasyMode (curvature related code)
        
# Examples

***monitor-slotmask-bloom-bezelwider - Arcade - Final fight***
![alt text](https://github.com/kokoko3k/koko-aio-slang/blob/main/screenshots/screenshots.3.5/monitor-slotmask-bloom-bezelwider.mame.ffight.png?raw=true)

***monitor-Commodore_1084S-wider - Amiga - ProjectX SE***
![alt text](https://github.com/kokoko3k/koko-aio-slang/blob/main/screenshots/screenshots.3.5/monitor-Commodore_1084S-wider.puae.projectx.png?raw=true)

***tv-PAL-my-old - Master System - Trans Bot***
![alt text](https://github.com/kokoko3k/koko-aio-slang/blob/main/screenshots/screenshots.3.5/tv-PAL-my-old,mastersystem.transbot.png?raw=true)

***tv-NTSC-1 - Genesis - Sonic 2***
![alt text](https://github.com/kokoko3k/koko-aio-slang/blob/main/screenshots/screenshots.3.5/tv-NTSC-1.md.sonic2.png?raw=true)

***tv-NTSC-2 - Snes - Aladdin***
![alt text](https://github.com/kokoko3k/koko-aio-slang/blob/main/screenshots/screenshots.3.5/tv-NTSC-2.snes.aladdin.png?raw=true)

***tv-aperturegrille-bloom-bezel - Amiga - Leander***
![alt text](https://github.com/kokoko3k/koko-aio-slang/blob/main/screenshots/screenshots.3.5/tv-aperturegrille-bloom-bezel.puae.leander.png?raw=true)
