#version 450
#include "config.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#include "includes/functions.include.slang"

#define SourceTexture Source
#define SourceTextureSize params.SourceSize

#define b_offset_x -0.05
#define Pi2 6.28318530717959
vec3 blur(float Quality, float Directions, float Size, vec2 co) {
    vec4 iResolution = SourceTextureSize;
    vec2 Radius = Size/iResolution.xy ;
    vec3 color  = vec3(0.0,0.0,0.0);
    vec3 lookup = vec3(0.0,0.0,0.0);
    float steps=0.0;
    for( float d=0.0; d<Pi2; d+=Pi2/Directions) {
        for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality) {
            lookup = texture( SourceTexture, co + vec2(cos(d)  + b_offset_x , sin(d))*Radius*i  ).rgb ;
            color +=lookup.rgb;
            steps+=1.0;
        }
    }
    color /= steps;
    return color;
}

void main() {
    if (DO_BEZEL == 0.0) return;
    
    if (is_useless(texture(Source, vTexCoord))) return;

    vec2 res = vec2(params.SourceSize.x, params.SourceSize.y);
    vec2 dir = vec2(0.0,1.0);
    ///Quality, Directions, Size, coords
    FragColor = vec4(blur(1,4,2,vTexCoord),1.0);
}
 
 
  
