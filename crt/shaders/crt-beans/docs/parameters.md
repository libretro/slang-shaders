# Parameters for crt-beans

## Output gamma

This should be set to the gamma of your TV or monitor. Most people will not need to change this. Most TVs and monitors are calibrated roughly to a pure power function gamma of 2.2, which is the default setting. Some monitors are calibrated to the actual sRGB gamma with a linear section near black. The difference is mostly noticeable in the glow, but can be significant. You can check which one your monitor uses with [this shadertoy](https://www.shadertoy.com/view/7sjBWD).

## Horizontal and vertical overscan

Set the overscan (the proportion of the image cropped vertically and horizontally). Most TVs had some amount of overscan. It is recommended that you turn overscan cropping _off_ in the core options and use the overscan cropping here. This makes the blurring filter more accurate.

The units are the total proportion of the image to crop, so a value of 0.06 means that 3% will be cropped on each side. The image will be stretched to fill the screen and match the expected aspect ratio after cropping.

## Maximum and minimum spot size

These parameters control the size of the scanline (the bright part of the line).

A maximum value of 1.0 will result in scanlines at maximum brightness being fully merged, with no dark area between them. Lower values will result in more defined scanlines. The value represents the full width at half maximum of the scanline in proportion to the distance between scanline centers.

A minumum value of 1.0 will result in scanlines that do not vary with brightness. Lower values will result in darker lines being narrower than brighter lines (which is common on CRT TVs). The value is in proportion to the maximum spot size, so a value of 1.0 means the minimum width is the same as the maximum, a value of 0.4 means the minimum width is 40% of the maximum, etc.

Note that the maximum spot size will affect the brightness of the overall image due to the dark gaps between the scanlines. A value of 1.0 will have no brightness cost, but a value of 0.9 will reduce the brightness by 10%, etc. The minimum spot size does not affect the overall image brightness.

## Mask type

This parameter sets the mask simulation type.

The dynamic mask is the default. It will have the specified number of phosphor triads regardless of the output monitor's resolution, for a consistent "look" across devices. It does not depend on the monitor's subpixel arrangement, so it can be used on OLEDs with non-standard subpixels, in TATE mode (rotated), etc. Very low resolution monitors (especially lower than 1080p) may have trouble with the dynamic mask.

The subpixel mask is an alternative for low resolution devices. Note that the number of phosphor triads that the subpixel mask simulates will vary depending on the output monitor's resolution. The "look" will therefore not be consistent across different resolutions. Because this mask type relies on awareness of the monitor's subpixel pattern, it will not work correctly for some monitors or orientations (e.g. TATE mode).

Currently, both mask types (subpixel and dynamic) simulate an [aperture grille](https://en.wikipedia.org/wiki/Aperture_grille).

Disabling the mask is recommended for low resolution devices with uncommon subpixel layouts (e.g. the Steam Deck OLED) or to simulate masks with very high phosphor density (e.g. good CRT monitors).

Masks have no brightness cost. The underlying scanline is blended into the image in bright areas so that the brightness is not reduced.

### Dynamic mask triads

This parameter controls the resolution of the phosphor mask for the dynamic mask type only. A value of 550 means that there will be 550 of each of the red, green, and blue phosphors across the simulated screen width.

This has no effect when the mask type is set to disabled or subpixel.

### Subpixel mask pattern and width

The monitor subpixel pattern should be set to match the monitor. If it is not, the mask may look distorted.

The subpixel mask width controls how many monitor pixels are used for each phosphor triad. For example, a value of 5.0 means that a 4k display would simulate `(2160 * (4/3)) / 5 = 576` phosphor triads across a 4:3 image.

## Glow amount and width

These parameters control the glow simulation. In this case, "glow" refers to the wide halos around bright parts of the image due to light scattering and refracting in the CRT glass. This is sometimes also called "bloom" or "diffusion."

Glow is implemented with an approximation of a gaussian blur mixed into the image. The width is the standard deviation of the gaussian to use (in proportion to screen height). The amount is the mix ratio of the blurred image to the original image. For example, a glow amount of 0.05 means the image is a mix of 5% blurred image and 95% original image.

## Interlacing

This parameter controls the [interlacing](https://en.wikipedia.org/wiki/Interlaced_video) simulation.

Note that some options are not available in crt-beans-rgb or crt-beans-s-video. These presets are not configured to handle high resolutions above 480i/576i (other than through using "weave" on 480p/576p content).

### Bob (0.0, 1.0)

These options display only the even or odd lines of a frame. When the value is 0.0, odd lines will be displayed for even frames and even lines will be displayed for odd frames. When the value is 1.0, even lines will be displayed for even frames and odd lines will be displayed for odd frames. If you are seeing artifacts during interlaced content, try switching this. Unfortunately, there does not seem to be any way of knowing which one is "correct" for a given core.

There may be noticeable flickering in this mode. In many cases, flickering was noticeable on the original systems and CRT TVs as well. However, some monitors and TVs can have excessive flickering in this mode, [due to the way they work](https://news.ycombinator.com/item?id=42507741), and the flickering may persist temporarily even after the interlaced content is gone.

When the vertical input resolution is less than or equal to 300, no interlacing effect is applied.

### Weave (2.0)

This option draws both the odd and even lines and then blends them together, avoiding the flickering and jittering of the bob options. On true interlaced (e.g. 480i) content, this will result in combing artifacts. For cores that output 480p, this will give a 480i "look." Note that there is a significant performance penalty for this option because twice as many scanlines need to be simulated.

When the vertical input resolution is less than or equal to 300, no interlacing effect is applied.

### VGA (3.0) (crt-beans-fast and crt-beans-vga only)

This option enables [VGA line doubling](https://github.com/dosbox-staging/dosbox-staging/issues/2283#issue-1589164907). When the vertical input resolution is below 350, each line is doubled. For example, [DOS mode 13h](https://en.wikipedia.org/wiki/Mode_13h) games have a vertical resolution of 200 and will be drawn with 400 scanlines. This was standard behavior for VGA output cards.</dd>

### Off (4.0) (crt-beans-fast and crt-beans-vga only)

Turns all interlacing simulation off. The number of scanlines in the output will be equal to the vertical resolution of the input.

## RGB/YIQ bandwidth

These options can simulate the limited bandwidth of an analog signal. This results in horizontal blurring of the final image. Lower bandwidths lead to more blurring. Different systems may have different quality outputs, and you may want to adjust these parameters based on your tastes.

The "Composite" parameter specifies whether to simulate an RGB connection (0.0) or a composite/s-video connection using the YIQ color space (1.0).

These options are only available for in the crt-beans-rgb and crt-beans-s-video presets.
