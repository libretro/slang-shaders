**-KOKO-AIO DOCUMENTAION-**
---------------------------
---------------------------

**REQUIREMENTS** <br>
    koko-aio needs at least retroarch 1.16 <br>
    Also it expects the following options set in Retroarch:
    
    Settings -> Core -> Allow Rotation: ON
    Settings -> Video -> Scaling -> Aspect Ratio: Full
    

**RETROARCH OUTPUT DRIVERS** <br>
    koko-aio does not work by default on d3d12 and d3d11.<br>
    If you absolutely need it (Xbox?), you can edit the file <br>
    config\config-user-optional.txt by writing in it:<br>
    #define D3D_WORKAROUND <br>
    <br>
    Vulkan ang Glcore have no problems, you can test both to see<br>
    which performs better.<br>
    <br>
    d3d10 is completely unsupported.
    <br>
    Be warned that the following functions do not work if you enable the workaround: <br>
        * CRT glitch on resolution changes <br>
        * Adaptive Black <br>
        * CVBS Bleed size is limited to 5.0 <br>
        * Ambientlight scene change detection <br>
        * Halving border updates refresh <br>
        * Lcd antighosting <br>
        * Delta render <br>
        * Possibly others (?) <br>
    
---------------------------
    
**USEFUL LOCATIONS/FILES:**
        
    config/config-user-optional.txt:    
        Shader parameters that can be changed within Retroarch.
        can be set within this file too.
        PRO: The shader will be faster
        CON: The parameters can no longer be modified within Retroarch. 
        Please read config-user-optional-template.txt for instructions.
               
    textures/background_under.png
        This is the image shown by default under the game and the bezel.
        Read further for details. 
        
    textures/background_over.png
        This is the image shown by default over the game and the bezel.
        Read further for details.
        
    textures/monitor_body_curved.png, textures/monitor_body_straight.png
        This is the image used to draw the bezel.
        Read further in the bezel section of this document for details.
        
    textures/side_shade-helper.png
        This file helps the shader to cast different shadows on different sides of the reflective part of the bezel (so, the inner area).
        Green color represents the side, while blue and red represents upper and lower side.
        Color blue<->green<->red color transitions are smoothed to produce smoothed shadows, you can tweak that to alter the shadows look.
        The file is also useful to overcome a bug in Retroarch, where some 3D accelerated cores like flycast, if coupled with GLCore video driver, flips the bezel upside down. In those cases, you should/could flip the image itself.
    config/config-static.inc:
        Some obscure shader parameters can't be changed within retroarch,
        use this file instead.
        
Texture "sources", including the main gimp project file for the <br>
default curved and straight monitor frame are on the following repo: <br>
https://github.com/kokoko3k/koko-aio-slang-misc/tree/main


---------------------------

**PARAMETERS:**<br>
*koko-aio as tons of configurable parameters, and for this reason it comes with a lot of pre-configured presets.<br>
My advice is to start with a preset you like, and then tweak it by following this documentation, rather than starting from scratch.*


**Gamma in:**<br>
Input Gamma: set it around 2.2 to linearize values.
        
**Gamma out:**<br>
Output Gamma: set it around "1/Gamma in"; small tweaks allowed.
        
**Clip to white:**<br>
Human brain perceives strong colors as white, but <br>
in crt shaders you don't want this to preserve colors.<br>
However nice effects may be obtained (eg: with vector games). <br>
        

**Color corrections:**<br>
    Modify signal color at "input" stage.<br>

    Luminance, brightness, contrast and temperature:
        self explanatory.
    Input signal gain:
        Gain applied in the chain just before the crt emulation stages.
    Adaptive black level range:
        On old CRTs the contrast was higher on high luminosity content,
        and lower on low luminosity content.
        This setting modulate the range of the effect; 0.0 disables it.

    It is also possible to emulate a monochrome display with custom colors:
    
        Monochrome screen colorization:
            The amount of (de) colorization applied.
        Hue bright, Hue dark:
            Set the hue for bright and dark colors. in [0..1] range.
            To emulate different monochrome models, the process is quite easy:
            . Provided you have screenshots, use a color picker tool with hue expressed in 1…360
              range and identify the hue of the original naked background hue1
            . Do the same for the darkest pixel on the screen, hue2
            . Then report them in the shader with the formula hue1/360 and hue2/360.
        Hue bright-dark bias:
            Controls the distribution of dark and bright hues.


**Antialiasing enable:**<br>
    Apply an edge smoothing/antialiasing algotithm.<br>
    Use it if you don't want to blur the image and you still don't like<br>
    jagged or too much pixelated images.<br>


**Dedither:**<br>
	Try to smooth dithering patterns.<br>
    Dedithering does not work as long as NTSC color artifacts are enabled.
    
    Sensitivity: Avoid to dedither "legit" zones by lowering this.
    Basic search strength: Blends basic dedithering and original image.
    Extensive search strength: Blends extensive dedithering and original image .
                               may produce posterization effects.


**CVBS: NTSC color artifacts:**<br>
    Emulate typical NTSC color artifacting<br>
    It is able to emulate straight rainbowing effects as seen on Megadrive<br>
    or oblique as seen on NES, and specific color generation from repeating
    B/W patterns as seen on CGA or Apple II composite systems.
    
	Strength: 
	    Self explanatory.
	Filter Width, Subcarrier Frequency mul, Frequency cutoff
	    Completely alters artifacts rendering, please see already cooked presets for interesting values.
	Phase shift
		Set to 0.0 to emulate straight rainbowing (Megadrive), or 1.0 to have 45 degree rainbowing.
    Artifacts upper threshold:
        Tune this to select more or less artifacts, depending on their strength.
    Cancel artifacts under the threshold
        How much of the artifacts under the threshold will be completely removed.
    Show selected artifacts mask.
        This will show only the part of the image that contains artifacts.
        Use it to for a better visual feedback of the following parameters.
        "glow/blur shader parameter" needs to be enabled for this to work.
        
    
**CVBS: Bandwidth limited chroma:**<br>
    Will cause an horizontal chroma bleed typical of band constrained composite signals.
    
	Colorspace (NTSC, PAL)
		Switch bandwidths to match different standards.
	Strength
		Self explanatory.
	Size
		Maximum bleed size.
	Falloff
		The bleed falloff speed.


**CVBS: Dot crawl**<br>
    Emulates rolling chroma->luma crosstalks observed in composite signals.<br>
    
    Colorspace: You can switch between pal and ntsc behaviour.
    Speed:
        Lower absolute values gives a more visible effect.
        A negative value will switch to verically crawling artifacts.
    
    
**Persistence of phosphors:**<br>
    This emulates the unexcited phosphors that continue to emit light.

    Early decay: is the immediate light cut after the phosphor is no more/less excited.
    Late persistence: modulates the time the residual light will stay on screen


**Deconvergence:**<br>
    Shift R,G,B components separately to mimic channel deconvergence.<br>
    
    Red,Green,Blue X,Y:
        The channels deconvergence offsets
    Deconvergence increases near edges:
        Increase the offsets near screen edge
    Blur screen edges
        Screen edges are blurred
    Focused Area:
        The area of the screen that will be in focus (affects previous 2 settings)

        
**RF Noise:**<br>
    Emulates radio frequency noise with a given strength<br>
    1 produce noise before the Glow/Blur pass, while -1 will move it after.
    Suggestions:
    If you're blurring the image, is better to use 1.<br>
    If you're glowing the image, prefer -1.<br>
    
    Uniform noise: Balanced noise that ranges from -x to +x.
    Snow noise: Sparkling/Rarefied noise 
        
**Megadrive fake transparencies:**<br>
    Detect patterns used in some Megadrive/Genesis games to
    fake transparent colors and blends them.
    
    Overridden X(Y)-sharpness: The lower, the blurrier.


        
**Glow/Blur:**<br>
	Blur the image and/or embolds bright pixels.

    Glow to blur bias:
        Higher negative values -> more glow : brighter colors expands over darker ones.
        Higher positive values -> means blur: all the colors are blurred.
        0.0 means no blur, no glow.
    Glow spread amount:
        The higher, the more the bright colors will smoothly expand.
        It emulates the natural antialiasing you see on CRTs on bright areas.
        More pronunced as "Glow to blur bias" approaches 0.

    Sharpness (horizontal, vertical):
        Modulates the sharpness of the image.
        - Max (actually 7.0) will not alter the image sharpness.
        - More than 0: will use gauss blur
        - Less than 0: will use box blur and will progressively
          add visual sharpness to image when approaching lower values.

    Warped glow (X,Y):
        Embolds bright pixels near dark ones using a warpsharp like algorithm.
        This is a cheap way to emulate phosphor glowing.
        The Y parameter will also allow scanlines to be higher.
        It will also help (if coupled with) antialiasing to stay sharp.

    Warped Dynamics:
        Change the amount of warpsharp applied based on the contrast between 
        nearby pixels, thereby altering their "Warped" shape.


**Tate mode:**<br>
    Rotates (or not) mask and scanlines by 90°<br>
    
    0: Never rotate.
    1: Rotate only for rotated content (typical 3:4 aspect arcade games)
    2: Always rotate/Force rotation.
        
**Glitch if vertical resolution changes:**<br>
    Emulates the crt circuits syncing to the new signal timing.<br>
    Will shake the screen for a while when the resolution changes.<br>
    The Hiher the value, the more the amplitude.
    
**Hi-resolution scanlines handling:**<br>
        There you can choose how to handle scanlines when a game is Hi-Resolution.<br>
        Special handling may be needed to mitigate glitches/moire at 1080p or lower resolutions.
        
    Consider Hi-Resolution above # lines:
        A value of 0.0 means that it will never consider anything hi-res.
        A value of 1.0 means that it will always consider game hi-res.
        With values > 1.0, it will consider a frame as Hi-resolution if the lines number is above the configured value.

    Real interlacing:
        This convert progressive input to interlaced one.
        And will display previous odd/even lines alternating on even/odd frames.
    
    Hi-Res scanlines type
       -1: Use a number of scanlines that perfectly fits the screen, a good glitches/moire free tradeoff.
       -2: As above, but tighter (~1.5x), another good glitches/moire free tradeoff.
        0: Use interlaced scanlines, may need >1080p screen to avoid moire or weavy glitches
        1: Avoid drawing scanlines gaps at all.
        2: Use scanlines, but don't interlace them (bad for 1080p and low resolutions)
        
    Interlaced brighness push
        When emulating interlaced scanlines (see above modes: -1, -2, 0),
        the resulting brightness is usually diminished.
        This is due to the latency some panels have when changing open/close state.
        *Lowering* this parameter compensates that and usually
        Values around 0.8 to 0.95 usually work good, for affected monitors.
        On low latency panels such as OLEDs, microleds, this is not an issue,
        so you should keep it to 1.0, possibly locking its value too in config-user-optional.txt
         
    Scanlines flicker (0=off,1=on,2=if Hi-res):
        This setting emulates the flickering issues present on crt interlaced screens
        where the brighter lines flickers when they are near dark ones.
        You can choose to produce the flickering: never, always or only 
        when the input picture is considered High resolution.
    Interlace Flicker power: The strength of the effect.
        
        
**Low level phosphor grid:**<br>
    This section contains parameters to emulate scanlines and phosphors layouts such as, but not limited to: aperturegrille,slotmasks,shadowmasks. <br>
    By reading the following explanaitions, you will realize that this section can also be used to emulate<br>
    handhelds screens, where pixels you see on screen have to be sized proportionally to the game one.<br>
    
    Overmask (1.0 = neutral):
        Values > 1.0 give a gritty/gariny look to the whole mask.
          It may cause moire if combined with curvature, dedot, or sparkling look punch.
        Values < 1.0 tend to nullify the whole mask effect.
        
        
    Scanlines (*4)
            Scanlines emulation, set the strength of the effect here.
        Double-scan low input resolutions
            Activate this if you want to double the number of scanlines when the game is low-res.
            "low-res is defined via "Consider Hi-Resolution above # lines" parameter above.
            This option is useful if you want to emulate 30khz VGA CRT monitors.
            If you are on 1080p or lower, consider to activate 
            Fake integer scanlines or integer scaling.
        Use fake integer scanlines
            Use a number of scanlines that perfectly fits the lines on the screen, not accurate,
            but avoids moire and weavy artifacts.
            A negative value will cause the shader to choose when it is appropriate to activate them.
              The decision will be based on the ratio of output dimensions and the core.
        Phosphors height Min, Max:
            Try to keep scanline height between those values, depending on game brightness.
        Phosphors width min->max gamma:
            Since emulating phosphors with high Min-Max range changes the apparent gamma of the final image,
            it is advised, if needed, to use this option to compensate, instead of the main gamma correction.
            It is also a quick way to make the image brighter or darker.
        Inter-line extra steepness (good for integer scaling, nice when Phosphors height max > 1.0)
            When you set maximum height to anything > 0.5, the phosphor light will bleed over
            the adiacent (up/down) ones so that they will start to blend togheter.
            Setting this option to anything >1.0 will avoid the bleeding.
            You may want them to blend or not, depending on your preference to keep scanlines separated.
            This function is useful when you want to emulate handhelds screens using integer scaling, 
            where cells are well separated.
        Anti-moire sweet spot:
            When dealing with curvature and deep scanlines gaps, moire patterns could appear on screen.
            This setting staggers screen phosphors by the configured amount and that halps in mitigating
            the disturbing effect.
            I observed that a value of 0.17 does a good job for low-res games rendered at 1080p height.
            Any value > 0.0 disables the, following functions: Slotmask(fake) and Deconvergence Y
        Slotmask(fake) offset(*):
            This will cause every triad to be vertically shifted by the configured amount to
            fake a slotmask phosphors layout.
            It is true that for accurate reproduction of them, slotmasks are commonly emulated
            at screen size, but on low resolution displays this may cause weird artifacts.
            Here there is an added value given by the fact that the shift itself
            can be made relative to game pixel height. (**)
            By selecting Y resolution=0 (so core coordinates**) and enabling this slotmask offset,
            you will have a staggered scanline.
            This allows you to not drawing a scanline -and- a slotmask, but to draw a "slotmasked"
            scanline.
            While this does not exist at all in crt technology, it greatly mitigates the afromentioned
            artifacts, and produces a fairly convincing scanlined+slotmasked effect.
        Slotmask(fake) width override (0=no override)
            The previous effect staggers scanlines at "triad width interval", but here you can alter
            that interval.
            Setting an interval of 1.0 can be used to hide moire patterns.
        Deconvergence Y: R,G,B phosphor" 
            This emulates Y deconvergence on phosphor level rather than on image level as seen in
            the previous deconvergence section.
            Emulating deconvergence here is good because phosphors will be able to brighten the
            dark gap left by scanlines.
        Dedot mask between scanlines
            When using Horizontal masks, you mai notice a disturbing dot pattern left between high
            scanlines, that's the residual of horizontal mask.
            Use this parameter to clear it and use it only if needed or it would have counter-effects.
            Also, mutating dots to straight lines would make moiree more visible when using curvature.
    
    
    Horizontal mask (rgb subpixel mask strength)
        X resolution: (core or screen) (**):
            0: Phosphors width will be relative to the pixel width of the core (game).
            1: Phosphors width will be relative to the pixel width of the screen.
        Cell size multiplier x (neg=divider):
            Multiplies (or divide if the parameter is < 0) the phosphors width by a factor.
            As stated(**), the width may be relative to screen or core.
            For example, you may choose to use screen relative width and enlarge phosphors
            by 2 or 3 to allow them to visually grow in width as signel gets stronger/brighter.
            Likewise, you can use core/game(**) sized masks to emulate LCD screens as seen in
            handhelds consoles.
        TVL: core resolution only. >0 overrrides previous
            If you use core resolution and this parameter is not 0.0,
            the phosphor width will be computed so that the screen will
            contain the specified rgb triads amount.
            Using core resolution means that the triads will follow the
            screen curvature, hence possibly exposing moire artifacts at higher TVLs.
            To mitigate that, it is advised to set a proper
            "Phosphor width min" value.
            Tests shows that on a 1080p screen you can easilly target a typical of mid-range consumer TVs
            with a TVL of 410, provided that you set minimum phosphor width of at least 30
            and a phosphor width min->max less than 5.0.

        Mask type preset:
            You can have the shader generate a preconfigured mask for you:
            1:gm 2:gmx 3:rgb 4:rgbx 5:rbg 6:rbgx 7:wx 8:rgxb 9:wwx
            1:GreenMagenta, 2:GreenMagentaGap, 3:RedGreenBlue, 4:RedGreenBlueGap, 5:RedBlueGreen, 6:RedBlueGreenGap
            7:WhiteGap (means r,g and b phosphors are completely overlapped, nice with scanline deconvergence)
            8:RedGreenGapBlue 9:WhiteWhiteGap
            
            (beware that due to limitations of the actual implementation, masks ending in "x")
            works reliable when emulating slotmasks only at screen coordinates with multiplier = 1.0)
            bh selecting preset = 0, you can draft your own by using the following knobs:
                Phosphors+gap count (mask size):
                    How much phosphors or blank spaces the final mask will have.
                R,G,B, Phosphor position:
                    The position of every phosphor.
                Example 1: Phosphors+gap count=4 and R=0 G=1 B=2
                ...will give you a mask with red,green,blue and a blank space.
                Example 2: Phosphors+gap count=2 and R=1 G=0 B=1
                ...will give a mask with green + a mix of blue and red (magenta)
                Example 3: Phosphors+gap count=3 and R=1 G=1 B=1
                ...will give a mask with a blank space, the neutral white color and another blank space
                Example 4: Phosphors+gap count=1 and R=0 G=0 B=0
                ...like the previous one, but without any blank spaces.
        Phosphors width Min, Max:
            The width of each phosphors can grow or shrink, depending on the
            luminosity of the underlying pixel luminance.
            1.0 refers to the full mask width, so stay around 0.2 if you want
            avoid them to blend.
            Use Min and Max parameter to limit the minimum and maximum size
            they can reach.
        Phosphors width min->max gamma:
                Since emulating phosphors with high Min-Max range changes the apparent gamma of the final image,
                it is advised, if needed, to use this option to compensate, instead of the main gamma correction.
                It is also a quick way to make the image brighter or darker.
        Black level of the unexcided phosphor grid
            Draw the vertical grid that hosts phosphors.
            This is likely to produce moiree when using X resolution = core
            
    
    Vertical cell Mask:
        The shape of the mask generated ny this function is "boxed", while the one
        generated by the previous function ("scanlines or vertical mask1") is more rounded.
        Phosphor masks are usually vertically delimited by thin lines.
        This parameter will set the visibility of them.

        Resolution: (core or screen) (*1)
            Should the vertical interval (height) between those likes be relative to screen or core pixel size?
        Height divider (neg=multiplier) (*2):
            The more, the less that intervall will be.
            Interesting values for screen resolution: 1.0, 0.75, 0.5
        Fadeout under light: How much they will be visible over bright pixels.
        Even/odd offset (slotmask) (*3):
            If you not used, the previous section to emulate scanlines(*), but still want to emulate
            slotmasks layouts, you can set this to 1.0.
            You can draw slotmasks at screen coordinates to emulate real crts or choose to paint
            them at core coordinates to have a more defined slotmask
            ...if you like slotmasks so much :-)
        Clears "hives" patterns (slotmask)
            When using steep/high visible slotmasks alongside visible scanlines, there could be
            weird hive-like patterns on screen. Use this function to hide them.
        Vertical shift (neg = auto):
            This parameter allows you to move the whole vertical mask along the Y axis.
            * When used with core resolution(*1) and integer divider/multiplier(*2), it is useful to mitigate
              weird patterns from the screen when using slotmasks (*3) alongside scanline emulation (*4).
            * The auto setting works with screen resolution(*1), and integer divider/multiplier(*2).
              It will auto-select a shift that gives the sharpest result.
            
        Steepness: 
            The more, the thinner they will be.
            Setting this to very high values, may make them disappear unevenly.
        Sparkling look punch:
            Makes the "Vertical cell Mask" effect more pronunced and "pinchy/Sparky" by highering its contrast.
            Beware, this may produce moiree.

    Shadowmask:
        Emulates crt's shadowmask.
        X staggering
            how much even rows have to be shifted, probably you want 1.0 or 1.5 here
            for 2 or 4 sized masks (gm,rgbx,rbgx,wx): use 1.5
            for 3 sized masks (gmx,rgb,rbg): use 1.0
        X staggering fin
        Phosphor height
            If you are using a very High definition screen, you may want to set this higher than 1.0
            I also observed nice results by setting this to 3 when using 4 sized masks like rgbx or rbgx.
            In those scenarios, you can use the "Vertical cell Mask" in the section above 
            (without slot mask effect) to round the phosphors.
            
**Dot matrix emulation:**<br>
    Emulates low refresh "boxed" screens used in old handheld consoles.<br>
    
    Grid strength: How much the grid is visible.
        Gap brightness:
            You may want to use a white grid eg: for gameboy mono emulation.
        Grid sharpness: 
            Modulates the thickness of the grid around cells.
        Paint on bright:
            How much should the grid be visible on background?
            More positive values -> more grid on bright
            More negative values -> more grid on dark
    Ghosting:
        Emulates a low refresh screen, set the power of the effect.<br>
        Apply on:
            0: display is always slow to refresh (Game gear)
            1: display is slow to refresh bright pixels (??)
            2: display is slow to refresh dark pixels (Game Boy)
    Shadow strength:
        Emulates the typical shadow seen on Gameboy mono handhelds
        casted by on the underlying screen.
        Shadow offset:
            Moves the shadow left or right.
        
**Halo:**<br>
    Emulates the effect of the brighter pixels reflected by the CRT glass<br>
    that lights nearby zones (a sort of tight bloom).<br>
    The light is meant to be spreaded in a way that it nulls the effect of the<br>
    dark scanline parts, darklines and the RGB masks.<br>
    So you can use this to restore the brightness and color saturation<br>
    loss when using features like scanlines, darklines or RGB masks.<br>
    
    (Halo): Pre-attenuate input signal gain to 1x:
        Nullifies the input gain applied in the color correction section.
        This way the halo effect will be consistent and will not depend on 
        it, avoiding hard to manage cascading effects.
    (Halo): Strength (negative = 10x precision)
        The effect strength.
        Negative values are interpreted as positive ones, divided by 10,
        when fine tuning is needed.
    (Halo): Sharpness
        The lower, the wider the halo.
    (Halo): Gamma in
        Act like a soft treshold; the higher, the less the darker colors
        will be "haloed"
    (Halo): Gamma out
        Post-gamma correction applied to the halo.
    Mask Helper: Additional brighness if horizontal mask clips
        This function will add more color to the subpixel mask (eg: RGB, RBGX...)
        when it is unable to reach the enough brightness.
        This will allow to fully exploit subpixel mask capacity while retaining
        the desidered brightness.
        Please note that a well calibrated monitor is needed.
        
        How to Use Mask Helper:
        -----------------------
            Adjust "Input signal gain" based on mask size:
               ~2.0..3.0 for 2-sized (gm, wx)
               ~3.0..4.0 for 3-sized (gmx, rgb,rbg)
               ~4.0..5.0 for 4-sized (rgbx, rbgx)
                
            Activate the "Horizontal mask" parameter.
               Set "Phosphors width Min, Max" to the minimum.
               Set "Phosphors width min->max gamma" to the maximum.
               
    Light up scanline gaps and dot grid gaps too:
        Theoretically Halo has to be applied
        "over" everything, because that is the way it works in nature.
        But you can choose to cheat and prefer to see more scanlines gaps, instead.
        Do this if you like much more pronunced scanlines, even at the
        cost of some graphical artifacts visible on high contrasted areas.
        The same apply for the grid emulated via dot matrix emulation feature.
 
**Bloom:**<br>
    Acts like Halo, but affects a much wider area and is more configurable.<br>
    By using this effect and playing with its parameters, you can achieve funny<br>
    or even artistic results.<br>
    
    Final mix:
        Modulates between the original images and the bloomed one.
    Radius:
        Controls how much the bloom has to be wide.
    Quality:
        How much the shape of the bloomed picture will reflect the original one.
    Input Gamma (threshold):
        Use this as a threshold to control how much a pixel has to be bright
        to produce a bloom effect.
    Output Gamma (contour smoothness):
        Lowering it will make the bloom contour more pronunced.
        Handy to simulate well defined "Aura" effects.
    Power multiplier:
        Just apply a gain to the final bloom.
    Modulate: Local exposure eye adaption strength
        Simulate the process through which the pupil adapt itself to different
        light conditions.
    Modulate: Strength on bright areas (0 = aura)
        Since the light produced by the bloom effect is added to the underlying
        image, it can produce clipping effects on the already bright areas.
        This is actually an hack that will avoid to bloom them.
    Bypass/Solo:
        See how the bloomed image looks alone.
        Use 1.0 to see naked bloom without any modulation applied
        Use 2.0 to see naked bloom with modulation applied 

**Curvature:**<br>
    Emulates a curved CRT display.<br>
    
    WARP X, WARP Y:
        control how much the display is curved along its axes.
        
**Corners/Edges:**<br>

    Corner radius, Edge sharpness:
        Control the "smoothness" of the display edges.

        
**Bezel:**<br>
    Draws a monitor frame with simulated reflections from the game.<br>
    The monitor frame is an image loaded by the shader and is shipped<br>
    in the "textures" shader subdirectory, named:<br>
    monitor_body_curved.png and monitor_body_straight.png<br>
    It has been made with the following rules that may come handy
    only if you want to edit it; otherwise go on:<br>
    * The red channel represents the luminance information<br>
    * The green channel represents the highlights<br>
    * The alpha channel in the inner frame represents the part of the bezel that will be filled by the game.<br>
    * The blue channel represents the part of the bezel that will be filled by the game reflection.<br>
    
    Straight
        Use a straight bezel instead of a curved one.
    Frame alignment:
        Allows to shrink or expand the monitor frame to fit the game and align reflections.
        "Aligning the reflections" is the ONLY scope of this option.
    Bezel color (red,green,blue) and contrast:
        Allows to choose the color of the monitor frame.
    Reflections strength
        The amount of reflections
    Less reflections in corners
        Show less reflections in corners
    Reflections sharpness
        Modulates from totally blurred to totally sharp reflection appearance.
    Inner surface roughness
        The amount of material roughness in reflection area
    Inner shadows contrast
        Add or remove contrast to the reflection area.
    Diffusion strength
        Mix an amount of high blurred reflection to simulate light diffusion
    Light fadeout distance
        Modulates the reflected and diffused light fadeout. higher numbers -> no fadeout.
    Specularity strength
        The amount of specular reflection

    
**Global shift/zoom:**<br>
    Zoom and shift everything on screen, but background pictures.<br>

    
**Mid Overlay image (backdrop, scratches):**<br>
    Display an image over the content.<br>
    The image used by default, picked from the "textures" shader subdirectory,<br>
    is named: backdrop.jpg<br>
    Of course you can use other path/names, but then you have to edit the preset <br>
    by modifying the "backdrop =" line.<br>
    <br>
    You can choose to emulate a "backdrop", as seen in some old arcades which 
    used a mirror trick to overlay the game over an high definition printed image.<br>
    Or you can use some image representing tube glass reflections, scratches and so on.
    
        Shift(Zoom) Backdrop over X(Y) axis:
            move or zoom the whole background image.
        Display only on content (no shift/zoom)
            Choose to display the image just over the content
            ...that way it will be tied to the content geometry 
            and no zoom/shift will be allowed
    
        
**Backgound image:**<br>
    Draws an image on screen picked from the "textures" shader subdirectory,<br>
    named by default background_over.png and background_under.png<br>
    <br>
    Of course you can use other path/names, but then you have to edit the preset by modifying<br>
    "bg_over=" and/or "bg_under=" lines.
    <br>
    **-> It is needed that you set retroarch aspect to "Full" <-**<br>
    ( Settings, Video, Scaling, Aspect Ratio = Full )<br>
    The image is painted "under" the game and under the monitor frame by<br>
    default, and his alpha channel will let you see ambient lighs (see next).<br>

    Image over game (alpha channel driven)?:
        ...however you can paint the image over the game and over the
        monitor frame itself by selecting this option.
        If you do so, the alpha channel of the background image will be used to
        let you view the underlying game.
    Shift(Zoom) Image over X(Y) axis:
        move or zoom the whole background image.
    Rotate/flip image
        This could be needed when dealing with vertical games
        or when the core flips the image for whatever reason.
        0     =  let the shader guess if the game is rotated.
        1, -1 = no change
        >+1   = manual rotation for straight games
        <-1   = manual rotation for rotated games

    Wrap mode:      
        What to do outside the image:
        0  Mirrored repeat because so is configured in main .slangp.
        1  Clamp to border and it means black.
        2  Clamp to edge and means that it repeats the edge color.
        3  Plain repeat without mirroring.

        
**Ambient light leds:**<br>
    Emulates the presence of led strips behind the monitor that lights the<br>
    surroundings according to the edges of the game.<br>
    **-> It is needed that you set retroarch aspect to "Full" <-**<br>
    ( Settings, Video, Scaling, Aspect Ratio = Full )<br>
    
    Slowness: 
        How much will the leds will take to adapt to the game.
        It may sound silly to make them slow, but if they reacts too fast,
        they may distract you.
        Keep in mynd that there is a scene detection logic that will make them
        react as fast as possible when a scene change is detected.
    Led power/Falloff:
        How input gain is applied to a single led, affects light wideness.
    Led saturation:
        Leds saturation post gain.      
    Internalness (Led position):
        The distance between the virtual led strip and the game area.
        High values will move leds behind it, while lower values will move
        leds around it.
    Internalness (Sampling point):
        Where the leds should take their color from, highering the value will make the color
        follow the color of what is in the center of the screen, lowering the value will
        color the leds as the edge of the screen.
    Widen lights:
        Dumb stretch of the visible texture, operates on the whole light, instead of the
        single led.
        Note: To avoid burn-in effects, keep Light Falloff + Led power not too high.
    Bezel Colorization intensity:
        Allow to add an amount of the ambient light over the bezel frame
        Please use this only if you are using a bezel.
    Bezel Colorization Size:
        How much the ambient light should bleed over the monitor.
        Pushing this too high would make it bleed over the tube.
        This is not supported.
    Back/Foreground image alpha blend:
        When displaying background or foreground images, ambient lights are
        shown on their transparent areas (alpha channel)
        Switching this you can choose if you want to emulate leds:
        under the image (0/mix) or over the image (1/add)
    Foggy (power on dark colors, add mode only)
        When using add mode or when colorizing the bezel via led lights, you may want
        to lessen the foggy effect to turn it into a more realistic illumination.
        Think to this as a way to turn the light target from the spectator (foggy)
        to the background (not foggy).
    Always colorize Back/Foreground image (add mode only)
        When "Back/Foreground image alpha blend" is set to 1/add,
        you can choose to always colorize the foreground image by a certain amount.
        This can be used to produce big haloes all around the tube.
        This internally works by adding the amount of your choice to the alpha channel
        of the foreground image.
        
**Vignette:**<br>
    Will cause uneven brightness of the image, more at the center,<br>
    less at the edges.<br>
    
    Vignette size:
        Modulates the size of the circular shade.
        Pillow/Tube
           * Add a pillow shape to vignette with values near 0.0.
           * Negative values will Render the vignette with a tube shape.
    Screen brightness uniformity:
        Modulates the strength of random uneven brightness across the screen.
        
**Spot:**<br>
    Simulates external light reflected by the monitor glass.<br>
      
**Tilt:**<br>
    Put the bezel and the game into perspective.<br>
    
    Tilt along X axis:
        Rotate the image in space
    Fov: Modulates the field of view
    Bezel multiplier:
        Can be used to adjust the bezel rotation
        in relation to the game tilt amount
      
**Aspect (applies to virtual screen and bezel):**<br>
    Manually forces an aspect for the virtual output screen.
    
    Use -6 for MAME cores that pre-rotates the game (TATE mode)<br>
    With Mame 2003 plus and fbneo cores, koko-aio detects if the<br>
    game is rotated or not without any user intervention.<br>
    
    -7 and -8 will take the value as set by the core itself and
    requires at least retroarch 1.20.
    -7 will ignore aspect set by the core and returns 1.333
    if a background or foreground image is used.
    
    Aspect Ratio Numerator:
        Setting non positive value here will switch to a predefined
        aspect ratio from the following list:
         0 = 1.33 MAME
        -1 = 1.55 NTSC
        -2 = 1.25 PAL
        -3 = 8/7  Snes
        -4 = 10/7 Megadrive 
        -5 = Uncorrected
        -6 = 0.75 MAME rotated 1.33 games in TATE mode
        -7 = Use Core provided Aspect Ratio auto-off
        -8 = Use Core provided Aspect Ratio always on
        -9 = Stretch to window
    Aspect Ratio Denominator:
        As long as Aspect Ratio Numerator is positive, this will
        be used as the denominator of the fraction.

**Breathing (Luminosity tied zoom):**<br>
    On older CRT monitors, the picture gets bigger when the image was brighter.<br>
    The higher, the more prominent the effect.
    This is ignored if integer scaling is selected.
    
**Autocrop**: 
    Clears solid bars around the frame.
    
    Autocrop maximum amount:
        The higher, the more solid borders wil be cropped around the image.
        0.3 means 30%
    
    Number of mandatory lines to crop:
        The minimum lines to always crop; this is useful because sometimes
        games have one or two "spurious" lines at the very edge of the screen that
        won't allow autocrop to work at all.
        This can be used to ignore them.
    
    Samples per frame:
        Higher values makes the shader search more in a single frame for solid areas.
        This leads to more accurate result in less time, however it will also stress the gpu more.
        Fortunately even low/lighter values like 10 will work good if you're ok
        in waiting 2..3 seconds for the final crop value to be found.
        
    Sample size:
        Search multiple pixels at once, this provide a big performance boost, but less accuracy.
        It means that some solid bar could remain around the image.
    
    Scene change treshold
        When autocrop finds a maximum crop value, it only tries to crop more when the scene changes.
        By lowering this value, you tell the shader to try higher the crop more often.
        Use 0.0 is probably useful only to trigger a new search.
        
    Transition speed
        This modulates the smoothness of the animation between various crop values.

**Override game geometry:**<br>
    Contrary to the aspect ratio control that affects the virtual screen dimensions,
    this changes only the game geometry, so bezel stays the same.<br>
    
    Integer scale:
        Game zoom height is rounded to nearest integer.
        Maximum integer scale: 
            Dont allow integer scaling more than this
            * beware: the following options in this group overrides the integer scale.
        Permit integer overscale by:
            When doing integer scaling, allow the image to be slightly overscanned (goes off screen).
        Sharp hack through offset:
            When using integer scaling, it may be not possible to draw sharp rounded lines.
            This hack add a small offset to the image that allows for sharp lines 
            at the cost of a slightly lower draw precision.
            Use 0.0 to disable the hack.
    Aspect:
        Forces an aspect ratio.
        Use a negative value to use Core provided aspect ratio (requires RetroArch > 1.19.1)
        Note that when 
    Vertical/Horizontal position:
        Shifts the game position
    Zoom: 
        Change the size
    

---------------------------
        
        
**Static features**
---------------------------

*The following shader functionalities are disabled by default and cannot be enabled by using runtime shader parameters.<br>
To enable them, you have to edit the file config/config-user-optional.txt (use config-user-optional-template).txt as a guide.<br>
Changes are applied after a shader reload.*<br>

---------------------------
     
**Delta Render:**<br>
    Koko-aio can render only the part of the screen that has been changed,<br>
    leading to a measurable power consumption reduction and mitigate throttling
    on mobile devices and laptops.<br>
    This feature can, however, produce artifacts in some cases.<br>
    Also, please be aware that enabling delta render disables some effects like rf noise,
    interlace flickering screen breathing, possibly more.
    To use it, in file config-user-optional.txt, write:<br>
    ```#define DELTA_RENDER```
    
**Delta Render configuration:**<br>
    To configure delta render, write/uncomment DELTA_RENDER_FORCE_REFRESH and/or DELTA_RENDER_CHECK_AREA.

    #define DELTA_RENDER_FORCE_REFRESH 10.0
        Forces a full screen refresh every 10.0 frames;
        if there was artifacts on the screen, they will be cleared.
        The higher the number, the less the power consumption.
        
        
    #define DELTA_RENDER_CHECK_AREA 3.0
        If you see artifacts, try to make 3.0 higher.
        Artifacts come basically from bloom.
        By highering this value, Delta render can take higher blur radiouses
        into account.
        The higher the number the more the power consumption.
        

**Higher quality defocus:**<br>
    Use higher quality deconvergence by flattering rgb scanlines when <br>
    deconvergence is high and by syncing them to the deconvergence settings.<br>
    This has a measurable performance impact on lower spec GPUs.<br><br>
    To use it, in file config-user-optional.txt, write:
    ```#define HQ_DECON```<br>
    
**FXAA tuning:**<br>
    To change fxaa behaviour, in file config-user-optional.txt, write: <br>
    ```#define FXAA_PRESET 2```<br>
    You can use values from 1 to 5, where:<br>
    1 is the fastest one, limited effect.<br>
    2 is the default one, still fast, good for low resolution content.<br>
    3 to 5 smooth the image more and are good for high resolution games.<br>

**Halve border update:**<br>
    You can halve the frequency at which the shader updates everything around the<br>
    content area (eg: ambient lights, reflections) to gain some fps.<br>
    To activate that ffeature, in config-user-optional.txt, write:<br>
    ```#define HALVE_BORDER_UPDATE```<br>
  
** Adaptive strobe (not compatible with LCD_ANTIGHOSTING):**
    Similar to black frame insertion, this works by alternating the image 
    brightness across frames and subframes (enabling the latter is recommended).
    Doing so, will reduce the motion induced blur and image clarity, hopefully
    approaching CRT behaviour.
    To use it, in file config-user-optional.txt, write:<br>
    ```#define DO_ADPT_STROBE```<br><br>
    Once you do that, the following parameters can be changed runtime:
    
    Strength:
        This modulates the clarity and the perceived flickering.
    Gain adjustment, post gamma adjustment, Less gain on dark colors:
        Since the perceived image depends on the display pixel refresh speed,
        it may be needed to adjust this.
    LCD Retention workaround cadence (frames):
        Some (IPS?) panels may suffer from temporary image retention when BFI/like is used.
        This parameter will invert the flipping every number of frames configured
        hopefully preventing that issue.
  
**LCD antighosting:**
    . Not compatible Direct3D<br>
    . Disabled with DELTA_RENDER)<br>
    . Disabled with Adaptive strobe<br>
    
    LCD displays often suffer from high pixel refresh times <br>
    which produces ghosting when game changes on screen.<br>
    By inducing larger color transitions, it prompts the LCD cells <br>
    to adjust their states more rapidly, thereby reducing ghosting.<br><br>
    To use it, in file config-user-optional.txt, write:<br>
    ```#define DO_LCD_ANTIGHOSTING```<br><br>
    Once you do that, the following parameters can be changed runtime:
    
    Strength:
        The effect strength; it has to be tuned depending on your LCD response time.
    Ceil:
        The effect is proportional to the color difference over time,
        however you can set an hard maximum here.
    Flip Mask:
        Enabling this will cause the horizontal mask to be flipped at every frame.
        It is an experimental measure to mitigate ghosting that could work or not,
        depending on your display.
    
**Conditional FPS Halver**<br>
    *[Warning:] Only on retroarch > 1.19.1*<br>
    *[Warning:] This feature is not compatible with HALVE_BORDER_UPDATE* <br>
    *[Warning:] This feature is not compatible with DELTA_RENDER* <br>
    To optimize performance and battery life, this function halves the shader <br>
    frame rate whenever the core frame rate surpasses 49 FPS.<br>
    This is particularly useful for devices with weaker GPUs <br>
    that may struggle to render shader at full speed. <br>
    Furthermore, the shader frame rate will remain capped at 30 (/25) FPS <br>
    if the core frame rate alternates between 60 (/50) and 30 (/25) FPS.<br><br>
    To use it, in file config-user-optional.txt, write:<br>
    ```#define FPS_HALVER```<br><br>
    
**Subframes rendering optimizations**<br>
    By enabling this options, shader will take steps to speed-up subframes processing.
    It could  display the previous rendered frame if possible or just part of it.
    Enable it only if using subframes, as it has a performance cost itself.
    To use it, in file config-user-optional.txt, write:<br>
    ```#define SUBFRAMES_OPTIMIZATIONS```<br><br>
    
**Antiburn protection**<br>
    By enabling this options, shader will slowly shake the content over Y/X axis to
    prevent image retention on affected screens like OLEDs.<br>
    To use it, in file config-user-optional.txt, write one or both:<br>
    ```#define ANTIBURN_Y 1.0```<br>
    ```#define ANTIBURN_X 1.0```<br><br>
    (1.0 is the effect speed).<br>