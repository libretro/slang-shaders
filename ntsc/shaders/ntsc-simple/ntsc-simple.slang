#version 450
/*
   Simple S-video like shader by DariusG 2023
   This program is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the Free
   Software Foundation; either version 2 of the License, or (at your option)
   any later version.
*/

layout(push_constant) uniform Push
{
  float CHR_BLUR, L_BLUR, CHROMA_SATURATION, BRIGHTNESS, IHUE, QHUE;
} params;



#pragma parameter CHR_BLUR "CHROMA RESOLUTION" 2.3 1.0 10.0 0.1
#pragma parameter L_BLUR "LUMA RESOLUTION" 10.5 10.0 20.0 0.5
#pragma parameter CHROMA_SATURATION "CHROMA SATURATION" 5.0 0.0 15.0 0.1
#pragma parameter BRIGHTNESS "LUMA BRIGHTNESS" 0.55 0.0 2.0 0.01
#pragma parameter IHUE "I SHIFT (blue to orange)" 0.0 -1.0 1.0 0.01
#pragma parameter QHUE "Q SHIFT (green to purple)" 0.0 -1.0 1.0 0.01



#define CHR_BLUR params.CHR_BLUR
#define L_BLUR params.L_BLUR
#define CHROMA_SATURATION params.CHROMA_SATURATION
#define BRIGHTNESS params.BRIGHTNESS
#define IHUE params.IHUE
#define QHUE params.QHUE


layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   uint FrameCount;

} global;


#define OutputSize global.OutputSize
#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
#define FrameCount global.FrameCount


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define PI   3.14159265358979323846
#define TAU  6.28318530717958647693
#define FSC  3.57945

// Size of the decoding FIR filter
#define FIR_SIZE 20

// YIQ to RGB matrices
const mat3 yiq_to_rgb = mat3(1.000, 1.000, 1.000,
                             0.956,-0.272,-1.106,
                             0.621,-0.647, 1.703);

const mat3 rgb_to_yiq = mat3(0.299, 0.596, 0.211,
                             0.587,-0.274,-0.523,
                             0.114,-0.322, 0.312);

float blackman(float pos, float FIR) {
    float a0 = 0.42;
    float a1 = 0.50;
    float a2 = 0.08;
    
    return a0 - (a1 * cos((2.0 * PI * pos) / FIR)) + (a2 * cos((4.0 * PI * pos) / FIR));
}

void main() {

// moved due to GLES fix. 
    mat3 mix_mat = mat3(
        1.0, 0.0, 0.0,
        IHUE, 1.0, 0.0,
        QHUE, 0.0, 1.0
        );

    // Chroma decoder oscillator frequency
    float fc = SourceSize.x*TAU;

    float counter = 0.0;
    vec3 yiq = vec3(0.0);

for (int d = -FIR_SIZE; d < FIR_SIZE; d++) {
        float odd = mod(vTexCoord.y*SourceSize.y,2.0)*SourceSize.z*0.25;
        float offset = float(d);
        float phase = fc*vTexCoord.x+11.0*PI/60.0;
        // LUMA encode
        vec2 pos = vec2((vTexCoord.x + (offset/2.0/L_BLUR)*SourceSize.z)+odd, vTexCoord.y);
        vec3 s = texture(Source, pos).rgb; 
        s = rgb_to_yiq*s;
        // LUMA encode end

        // LUMA decode
        // Apply Blackman window for smoother colors
        float window = blackman((offset/2.0 + 10.0), float(FIR_SIZE/2)); 
        yiq.r += s.r * BRIGHTNESS * window;
        // LUMA decode end!

        // CHROMA encode
        pos = vec2(vTexCoord.x + (offset/CHR_BLUR)*SourceSize.z+odd, vTexCoord.y);
        s = texture(Source, pos).rgb;
        
        s = rgb_to_yiq*s;
        s.yz *= vec2(cos(phase),sin(phase)); 
        // CHROMA encode end

        // CHROMA decode
        // Apply Blackman window for smoother colors
        window = blackman( offset + float(FIR_SIZE), float(FIR_SIZE * 2 + 1)); 
        float wt = fc*(vTexCoord.x + offset*SourceSize.z)+11.0*PI/60.0;

        yiq.yz += s.yz * vec2(cos(wt), sin(wt)) * window;
        // CHROMA decode end!

        counter++;
    }

    yiq.yz /= counter;
    yiq.r /= counter/4.0;

    // Saturate chroma (IQ)
    yiq.yz *= CHROMA_SATURATION;
    // Control CHROMA Hue
    yiq *= mix_mat;
    // return to RGB
    FragColor = vec4((yiq_to_rgb * yiq), 1.0);
}
