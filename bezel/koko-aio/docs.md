**koko-aio-slang parameters documentation**


**Shift RGB components:**
    Shift R,G,B components separately to mimic chroma
    dephasing and color aberrations.
    By varying Red, Green and Blue offsets, the relative component will be
    shifted column by column, row by row.
    
**Saturated color bleeding:**
    Will cause an horizontal chroma bleed which cheaply mimics the effect of
    poor composite video signals.
    It can be used with RGB shifting and image blurring to give the picture
    an ntsc look without dealing with specific encoding/decoding stuffs. 
    
**Color corrections:**
    Modify luminance, saturation, contrast, brightness and color temperature of the
    "input" signal.
    Gamma correction is applied to the final processed picture.
    
**FXAA:**
    Apply the well known antialiasing effect by Nvidia.
    Use it if you don't want to blur the image and you still don't like
    jagged or too much pixelated images.
    
**Scanlines:**
    Emulate CRT scanlines.
    
    Scanlines gap brightness:
        controls how "little" they will look pronunced.
        You can even use a negative value to make the scanline more evident,
        but graphical glitches may occour.
    Scanlines gap brightness:
        Controls how much the gap between scanlines is dark
    Compensate brightness loss:
        Will make scanlines brighter, where possible, to compensate for the loss of brightness
        gicen by the dark gap between them.
    Scanlines bleeding:
        will cause the scanline itself to light the scanline gap (dark) part. 
        You may use it to keep a good brightness overrall picture level.
    Interlace flicker:
        Emulates the flickerin issues present on crt interlaced screens
        where the brighter lines flickers wien they are near dark ones.
        You can choose to produce the flickering: never, always or only
        when the input picture is considered interlaced.
        The threshold for that is defined in config.inc 
        with the parameter: MIN\_LINES\_INTERLACED.
    Disable on interlaced screen:
        You can choose to completely disable scanline emulation when
        the input picture is considered interlaced.

**Input power/glowing:**
    Emulate the CRT glowing "feature", so that the brighter areas of
    the image will light their surroundings.
    
    Input signal glow strength:
        The input signal gain
    Sharpness:
        How much the glow will "spread".
        When pushed to its maximum value, no blurring will occour.
    Gamma:
        Controls how much the signal has to be bright to produce the glow.
    Post gain:
        This will cause the glowed image to be added to the input signal.
        This allows to emulate glow and haloing in a single pass.
        However the haloing should be applied after the mask emulation.
        Likely to be removed in a future release.
    
**RGB Masks and/or Darklines:**
    Emulates CRT RGB phosphors (RGB Mask),
    slotmasks and aperturegrille (Darklines).
    
    (HiDPI) Vmask and Darklines multiplier:
        This shader is tuned for 1080p, but ff you have an HiDPI display
        you may want to scale this filter by a factor.
    Vmask Strength:
        How much will the RGB mask be visible.
    RGB Mask: (LoDPI) Green,Magenta -> BGR:
        By exploiting common monitors RGB subpixel order, this causes
        the RGB mask, to be emulated by using just 2 pixels instead of 3.
        Very useful for 1080p (or lower) displays and to keep more brightness.
    RGB Mask: Horizontal Gap between triads:
        In real displays rgb triads are separated by a black space.
        You can emulate it by turning this feature on.
    RGB Mask: affect bright colors:
        Emulating RGB masks will lower the resulting image brightness and you
        just cant push input signal brightness without "burning" the signal.
        By using this option, the RGB mask will be less evident on brighter
        colors. However, since this will make the image to look somehow "dull",
        it is advised to use the "Halo" feature instead (see later).
    Darklines: strength:
        How much will the horizontal darklines be visible.
    Darklines: offset by triads:
        When drawing "straight" horizontal darklines, you can emulate CRT aperture grille.
        But if you want slotmasks instead, you need to vertically
        offset them every RGB triad.
    Darklines: period (triad height):
        Basically tells the shader how much a triad has to be high.
    Darklines: affect bright colors:
        See "RGB Mask: affect bright colors"

**Halo:**
    Emulates the effect of the brighter pixels reflected by the CRT glass
    that lights nearby zones (a sort of tight bloom).
    The light is meant to be spreaded in a way that it nulls the effect of the
    dark scanline parts, darklines and the RGB masks.
    So you can use this to restore the brightness and color saturation
    loss when using features like scanlines, darklines or RGB masks.

**Bloom:**
    Acts like Halo, but affects a much wider area and is more configurable.
    By using this effect and playing with its parameters, you can achieve funny
    or even artistic results.
    
    Final mix:
        Modulates between the original images and the bloomed one.
    Radius:
        Controls how much the bloom has to be wide.
    Quality:
        How much the shape of the bloomed picture will reflect the original one.
    Input Gamma:
        Use this as a threshold to control how much a pixel has to be bright
        to produce a bloom effect.
    Power multiplier:
        Just apply a gain to the final bloom.
    Output Gamma:
        Play with it.
    Strength on bright areas:
        Since the light produced by the bloom effect is added to the underlying
        image, it can produce burn effects on the already bright areas.
        This is actually an hack that will avoid to bloom them.
        Don't use too low values.
    Bypass:
        See how the bloomed image looks alone.

**Curvature:**
    Emulates a curved CRT display.
    
    WARP X, WARP Y:
        control how much the display is curved along its axes.
    Corner radius, Corner sharpness:
        Control the "smoothness" of the display corners.
        
**Bezel:**
    Draws a monitor frame with simulated reflections from the game content.
    The monitor frame is an image loaded by the shader and is shipped
    in the "textures" shader subdirectory, named "monitor\_body.png"
    It has been made with the following rules that may come handy
    only if you want to edit it; otherwise go on.
    - The red channel represents the luminance information
    - The green channel represents the highlights
    - The alpha channel in the inner frame represents the part of the bezel
      that will be filled by the game content
    - The blue channel represents the part of the bezel that will be filled by the game reflection.
    
    Bezel color (red,green,blue) and contrast:
        Allows to choose the color of the monitor frame.
    Image zoom:
        Allows to shrink or expand the game content to fit the monitor frame.
    Frame zoom:
        Allows to shrink or expand the monitor frame to fit the game content.
    Image Border:
        Draws a black border around the game content.
        
**Backgound image:**
    Draws an image on screen picked from the "textures" shader subdirectory,
    named: background.png<br>
    **-> It is needed that you set retroarch aspect to "Full" <-**
    ( Settings, Video, Scaling, Aspect Ratio = Full )
    The image is painted "under" the game content and under the monitor frame by
    default, and his alpha channel will let you see ambient lighs (see next).
    
    Image over content (alpha channel driven)?:
        ...however you can paint the image over the game content and over the
        monitor frame itself by selecting this option.
        If you do so, the alpha channel of the background image will be used to
        let you view the underlying content.

**Ambient light leds:**
    Emulates the presence of led strips under the monitor that lights the
    surroundings according to the edges of the game content.
    -**\> It is needed that you set retroarch aspect to "Full" <-**
    ( Settings, Video, Scaling, Aspect Ratio = Full )
    
    Slowness: 
        How much will the leds will take to reflect the game content.
        It may sound silly to make them slow, but if they reacts too fast,
        they may distract you.
        Keep in mynd that there is a scene detection logic that will make them
        react as fast as possible when a scene change is detected.
    Light Falloff:
        How wide is the area illuminated.
    Led power:
        Leds post gain.
    Note: To avoid burn-in effects, keep Light Falloff + Led power < 1.4


**Aspect Ratio:**
    When using effects that need Retroarch aspect ratio option
    to be set to "full", you have to provide the source aspect
    ratio to the shader.
    
    Aspect Ratio Numerator:
        Setting non positive value here will switch to a predefined
        aspect ratio from the following list:
        0  = 1.33 MAME
        -1 = 1.55 NTSC
        -2 = 1.25 PAL
        -3 = 8/7  Snes
        -4 = 10/7 Megadrive 
        -5 = Uncorrected
    Aspect Ratio Denominator:
        As long as Aspect Ratio Numerator is positive, this will
        be used as the denominator of the fraction.

**Luminosity dependant zoom:**
    On older CRT monitors, the picture gets bigger when the image was brighter.

**Vignette:**
    Will cause uneven brightness of the image, more at the center,
    less at the edges.
    
**Spot:**
    Simulates external light reflected by the monitor glass.

**Alternate line blanking:**
    CRT monitors \*real\* refresh was amazing, today is just "meh" in most cases.
    This emmulates the low pixel persistance of CRT monitors 
    and reduces the motion blur, typical of LCD displays, by blanking even/odd
    screen lines on even/odd frames, by sacrificing image brightness, ofc.
    
    Frame insertion strength:
        How much the line will be blanked.
    Dark lines period:
        You can blank single line or a group of them at once.
        See what performs better on your display.

