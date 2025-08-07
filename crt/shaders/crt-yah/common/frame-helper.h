#ifndef FRAME_HELPER

#define FRAME_HELPER

#ifndef BASE_FRAME_RATE
    // The base frame rate.
    #define BASE_FRAME_RATE 60
#endif

#ifndef BASE_FRAME_TIME_DELTA
    // The base frame time delta (in microseconds) to compute the uniform frame rate.
    #define BASE_FRAME_TIME_DELTA 1000000 / BASE_FRAME_RATE
#endif

#ifndef FRAME_TIME_DELTA
    // The frame time delta (in microseconds).    
    #ifdef _HAS_FRAMETIME_UNIFORMS
        #define FRAME_TIME_DELTA global.FrameTimeDelta
    #else
        #define FRAME_TIME_DELTA BASE_FRAME_TIME_DELTA
    #endif
#endif

#ifndef FRAME_COUNT
    // The frame count.
    #define FRAME_COUNT global.FrameCount
#endif

/// Returns the uniform frame rate factor relative to the base frame rate of 60fps.
///   The actual frame rate is estimated by the frame time delta.
///     30fps = 2.0
///     60fps = 1.0
///     120fps = 0.5
///     240fps = 0.25
float GetUniformFrameFactor()
{
    float factor = float(FRAME_TIME_DELTA) / float(BASE_FRAME_TIME_DELTA);
    return factor > 1.0
        ? round(factor)
        : round(factor * 4.0) / 4.0;
}

/// Returns the uniform frame count based on the desired frame rate.
/// @frame_rate - The desired frame rate. 60fps will return the original frame count.
uint GetUniformFrameCount(float frame_rate)
{
    float frame_rate_factor = frame_rate / float(BASE_FRAME_RATE);

    return uint(round(GetUniformFrameFactor() * FRAME_COUNT * frame_rate_factor));
}

#endif // FRAME_HELPER