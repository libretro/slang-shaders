#version 450

/*
   something
*/


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
    vec4 OriginalSize;
	uint FrameCount;
	float DISTORTION,SCANLINE,MASK,LUM,SATURATION;
} params;

#pragma parameter DISTORTION "Curvature Radius" 0.08 0.0 0.30 0.01
#pragma parameter SCANLINE "Scanline Weight" 0.3 0.15 0.5 0.05
#pragma parameter MASK "Dot Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter LUM "Luminance" 0.05 0.0 1.0 0.01
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.01

#define DISTORTION params.DISTORTION
#define SCANLINE params.SCANLINE
#define INPUTGAMMA params.INPUTGAMMA
#define OUTPUTGAMMA params.OUTPUTGAMMA
#define MASK params.MASK

#define SourceSize params.SourceSize.xy
#define PI 3.1415926
layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;



#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord*1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


// Apply radial distortion to the given coordinate.
        vec2 radialDistortion(vec2 coord)
        {
                vec2 pos = coord;
                vec2 cc = pos - 0.5;
                float dist = dot(cc, cc) * DISTORTION;
                return coord * (pos + cc * (1.0 + dist) * dist) / pos;
        }

        // Calculate the influence of a scanline on the current pixel.
        //
        // 'distance' is the distance in texture coordinates from the current
        // pixel to the scanline in question.
        // 'color' is the colour of the scanline at the horizontal location of
        // the current pixel.
        vec3 scanlineWeights(float distance, vec3 color, float l)
        {
                // The "width" of the scanline beam 

                
                vec3 wid = vec3(mix(2.0,4.0,l));

                // The "weights" lines basically specify the formula that gives
                // you the profile of the beam, i.e. the intensity as
                // a function of distance from the vertical center of the
                // scanline. In this case, it is gaussian if width=2, and
                // becomes nongaussian for larger widths. Ideally this should
                // be normalized so that the integral across the beam is
                // independent of its width. That is, for a narrower beam
                // "weights" should have a higher peak at the center of the
                // scanline than for a wider beam.
                
    vec3 weights = vec3(distance / SCANLINE);
    vec3 scan = params.LUM + 1.4 * exp(-pow(weights * inversesqrt(0.5 * wid), wid)) / (0.6 + 0.2 * wid);
                return scan;
        }



void main()
{
   vec2 pos = radialDistortion(vTexCoord );
   vec2 ps = 1.0/SourceSize.xy;
   vec2 dx = vec2(ps.x, 0.0);
   vec2 dy = vec2(0.0, ps.y);
   vec2 ratio_scale = pos.xy * SourceSize.xy -0.5;
   vec2 uv_ratio = fract(ratio_scale);

   vec2 tc = (floor(pos.xy * SourceSize.xy) + vec2(0.5)) / SourceSize.xy;
   
   vec2 fp = fract(pos.xy * SourceSize.xy);
   
   vec3 c10 = texture(Source, tc -       dx).xyz;
   vec3 c11 = texture(Source, tc           ).xyz;
   vec3 c12 = texture(Source, tc +       dx).xyz;
   vec3 c13 = texture(Source, tc + 2.0 * dx).xyz;
    
   vec4 lobes = vec4(fp.x*fp.x*fp.x, fp.x*fp.x, fp.x, 1.0);

// Horizontal cubic filter - "Catmull rom"
    vec4 InvX;
    InvX.x = dot(vec4( -0.5, 1.0, -0.5, 0.0), lobes);
    InvX.y = dot(vec4(  1.5,-2.5,  0.0, 1.0), lobes);
    InvX.z = dot(vec4( -1.5, 2.0,  0.5, 0.0), lobes);
    InvX.w = dot(vec4(  0.5,-0.5,  0.0, 0.0), lobes);

    vec3 color = InvX.x*c10.xyz;
         color+= InvX.y*c11.xyz;
         color+= InvX.z*c12.xyz;
         color+= InvX.w*c13.xyz; 

    vec3 weights, weights2;
    float lum = dot(color,vec3(0.22,0.7,0.008));
    color *= mix(0.85,1.0,lum);
    color = mix(vec3(lum),color,params.SATURATION);

    if (params.OriginalSize.y > 400.0) color; else 
    {
    weights  = scanlineWeights(uv_ratio.y, color,lum);
    weights2 = scanlineWeights(1.0 - uv_ratio.y, color,lum);
    color  = color * weights + color * weights2;
    }
    
    float whichmask = floor(vTexCoord.x*params.OutputSize.x)*-0.5;
    float mask = 1.0 + float(fract(whichmask) < 0.5) * -MASK;
    color *= mask;

    FragColor = vec4(color,1.0);
        }