// Enable this option only if background image and display have different aspect ratios.
//#define KEEP_BORDER_ASPECT_RATIO

// Define the border texture aspect. If you don't know, put the texture size as the comment below. Default is 16:9.
#ifdef KEEP_BORDER_ASPECT_RATIO
    #define ASPECT_TEX_X  16.0   // It's equivalent to texture size, it could be X=1920.0 and Y=1080.
    #define ASPECT_TEX_Y   9.0
#endif

