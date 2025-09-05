#version 450


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
    float size;
    float warp;
    float border;
    float hheld_mode;
} params;

// Parameter lines go here:

#pragma parameter size "Mask Size" 2.0 2.0 3.0 1.0
#pragma parameter warp "Curvature" 0.12 0.0 0.3 0.01
#pragma parameter border "Border Smoothness" 0.02 0.0 0.2 0.005
#pragma parameter hheld_mode "Handheld mode" 0.0 0.0 1.0 1.0



#define OriginalSize params.OriginalSize
#define OutputSize params.OutputSize
#define SourceSize params.SourceSize
#define size params.size
#define warp params.warp
#define border params.border
#define hheld_mode params.hheld_mode

#define PI   3.14159265358979323846
#define tau  6.283185
	
layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out  vec2 screenscale;
layout(location = 2) out  float maskpos;


void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord * 1.0001;
    screenscale = SourceSize.xy/OriginalSize.xy;
    maskpos = vTexCoord.x*OutputSize.x*screenscale.x;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(location = 1) in  vec2 screenscale;
layout(location = 2) in  float maskpos;


layout(set = 0, binding = 1) uniform sampler2D Source;

void main() 
{
vec2 pos = vTexCoord*screenscale; // 0.0 to 1.0 range

// curve horizontally & vertically
float cx = pos.x - 0.5; // -0.5 to 0.5
float cy = pos.y - 0.5; // -0.5 to 0.5
pos.x = pos.x + (cy * cy * warp * cx);
pos.y = pos.y + (cx * cx * warp * cy);
vec2 cpos = pos;

pos /= screenscale; 

vec2 spos = pos*SourceSize.xy;
vec2 near = floor(spos)+0.5;
vec2 f = spos - near;

pos.y = (near.y + 16.0*f.y*f.y*f.y*f.y*f.y)*SourceSize.w;    

vec3 res = texture(Source,pos).rgb;
    
float l = dot(vec3(0.25),res);

// get pixel position in screen space
float pix = floor(maskpos);
// Mask out every other line
if (mod(pix, size) == 0.0) {
    res.rgb *= 0.7; // mask
}

float scan_pow = 1.0;
float scn = 1.0;

if (hheld_mode == 0.0){
scan_pow = mix(0.5,0.2,l);    
scn = scan_pow*sin((spos.y-0.25)*tau)+1.0-scan_pow;
res *= scn;    
}

res *= mix(1.45,1.25,l);
res = sqrt(res);
// fade screen edges (linear falloff)
float fade_x = smoothstep(0.0, border, cpos.x) *
               smoothstep(0.0, border, 1.0 - cpos.x);
float fade_y = smoothstep(0.0, border, cpos.y) *
               smoothstep(0.0, border, 1.0 - cpos.y);
// combine fades
float fade = fade_x * fade_y;
res *= fade;
FragColor.rgb = res;
}
