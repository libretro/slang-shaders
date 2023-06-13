#version 450


layout(push_constant) uniform Push
{

    float SHARPNESSX,SHARPNESSY,WARPX,WARPY,CORNER_ROUND,BORDER,SHADOWMASK,MASKLOW,MASKHIGH,DOTMASK_STRENGTH,
MASKDARK,MASKLIGHT,GAMMAIN,GAMMAOUT,SAT,SCANLOW,SCANHIGH,MINSCAN,VIGNETTE,VPOWER,VSTR,TEMP,SEGA,
BLACK,GLOW,SIZE,quality,nois,BGR,INTERLACE;
} params;

// Parameter lines go here:
#pragma parameter SHARPNESSX "   Horizontal Sharpness"  0.25 0.0 1.0 0.05
#pragma parameter SHARPNESSY "   Vertical Sharpness"  0.7 0.0 1.0 0.05
#pragma parameter WARPX "Curvature Horizontal" 0.03 0.0 0.2 0.01
#pragma parameter WARPY "Curvature Vertical" 0.05 0.0 0.2 0.01
#pragma parameter CORNER_ROUND "Corner Roundness" 0.02 0.005 0.2 0.01
#pragma parameter BORDER "Border Smoothness" 400.0 100.0 1000.0 25.0
#pragma parameter INTERLACE "Interlace On/Off" 1.0 0.0 1.0 1.0
#pragma parameter SCANLOW "   Scanline Low Brightness" 0.15 0.01 1.0 0.05
#pragma parameter SCANHIGH "   Scanline High Brightness" 0.20 0.01 1.0 0.05
#pragma parameter MINSCAN "   Scanline Min Brightness" 0.04 0.01 1.0 0.01
#pragma parameter SHADOWMASK "Mask Type, CGWG, Lottes 1-4" 5.0 -1.0 5.0 1.0
#pragma parameter BGR "RGB/BGR subpixels" 1.0 0.0 1.0 1.0 
#pragma parameter MASKLOW "Mask Strength Low" 1.0 0.0 1.0 0.05
#pragma parameter MASKHIGH "Mask Strength High" 0.75 0.0 1.0 0.05
#pragma parameter DOTMASK_STRENGTH "CGWG Dot Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter MASKDARK "Lottes Mask Dark" 0.5 0.0 2.0 0.1
#pragma parameter MASKLIGHT "Lottes Mask Light" 1.5 0.0 2.0 0.1
#pragma parameter GAMMAIN "   Gamma In" 2.4 1.0 4.0 0.05
#pragma parameter GAMMAOUT "   Gamma Out" 2.25 1.0 4.0 0.05
#pragma parameter BLACK "   Black Level" 0.0 -0.20 0.20 0.01 
#pragma parameter TEMP "   Color Temperature in Kelvins"  9311.0 1031.0 12047.0 72.0
#pragma parameter SAT "   Saturation" 1.0 0.0 2.0 0.01
#pragma parameter SEGA "   SEGA Lum Fix" 0.0 0.0 1.0 1.0
#pragma parameter GLOW "   Glow Strength" 0.12 0.0 1.0 0.01
#pragma parameter quality "   Glow Size" 1.0 0.0 1.5 0.05
#pragma parameter VIGNETTE "Vignette On/Off" 1.0 0.0 1.0 1.0
#pragma parameter VPOWER "Vignette Power" 0.1 0.0 1.0 0.01
#pragma parameter VSTR "Vignette Strength" 45.0 0.0 50.0 1.0
#pragma parameter nois "Noise strength" 0.4 0.0 1.0 0.01

#define SHARPNESSX params.SHARPNESSX
#define SHARPNESSY params.SHARPNESSY
#define WARPX params.WARPX
#define WARPY params.WARPY
#define CORNER_ROUND params.CORNER_ROUND
#define BORDER params.BORDER
#define SHADOWMASK params.SHADOWMASK
#define MASKLOW params.MASKLOW
#define MASKHIGH params.MASKHIGH
#define DOTMASK_STRENGTH params.DOTMASK_STRENGTH
#define MASKDARK params.MASKDARK
#define MASKLIGHT params.MASKLIGHT
#define GAMMAIN params.GAMMAIN
#define GAMMAOUT params.GAMMAOUT
#define SAT params.SAT
#define SCANLOW params.SCANLOW
#define SCANHIGH params.SCANHIGH
#define MINSCAN params.MINSCAN
#define VIGNETTE params.VIGNETTE
#define VPOWER params.VPOWER
#define VSTR params.VSTR
#define TEMP params.TEMP
#define SEGA params.SEGA
#define BLACK params.BLACK
#define GLOW params.GLOW
#define SIZE params.SIZE
#define quality params.quality
#define nois params.nois
#define BGR params.BGR
#define INTERLACE params.INTERLACE


#define CURVATURE        
#define PI 3.141592654

layout(std140, set = 0, binding = 0) uniform UBO
{
        vec4 SourceSize;
        vec4 OriginalSize;
        vec4 OutputSize;
        uint FrameCount;
	mat4 MVP;
} global;

#define SourceSize global.SourceSize
#define OriginalSize global.OriginalSize
#define OutputSize global.OutputSize
#define mod_factor vTexCoord.x * OutputSize.x/OriginalSize.x*SourceSize.x 
#define scale vec4(SourceSize.xy/OriginalSize.xy,OriginalSize.xy/SourceSize.xy)
#define filterWidth (OriginalSize.y / OutputSize.y) / 3.0
        
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

layout(set = 0, binding = 1) uniform sampler2D Source;


#define iTimer (float(global.FrameCount) / 60.0)


vec2 curve(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*WARPX, 
        1.0 + (pos.x*pos.x)*WARPY);
    
    return pos*0.5 + 0.5;
}

float corner(vec2 coord)
{
                coord *= scale.xy;
                coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
                coord = min(coord, vec2(1.0)-coord) * vec2(1.0, OriginalSize.y/OriginalSize.x);
                vec2 cdist = vec2(CORNER_ROUND);
                coord = (cdist - min(coord,cdist));
                float dist = sqrt(dot(coord,coord));
                return clamp((cdist.x-dist)*BORDER,0.0, 1.0);
}  



float CalcScanLineWeight(float dist, float scan)
{
    return max(1.0-dist*dist/scan, MINSCAN);
}

float ScanLine(float dy, float l)
{
    float scan = mix(SCANLOW, SCANHIGH, l);
    float scanLineWeight = CalcScanLineWeight(dy, scan);
    scanLineWeight += CalcScanLineWeight(dy-filterWidth, scan);
    scanLineWeight += CalcScanLineWeight(dy+filterWidth, scan);
    scanLineWeight *= 0.3333333;
    return scanLineWeight;
}


// Shadow mask.
vec3 Mask(vec2 pos)
{
   vec3 mask = vec3(MASKDARK, MASKDARK, MASKDARK);
   
   // Very compressed TV style shadow mask.
   if (SHADOWMASK == 1.0)
   {
      float line = MASKLIGHT;
      float odd  = 0.0;

      if (fract(pos.x/6.0) < 0.5)
         odd = 1.0;
      if (fract((pos.y + odd)/2.0) < 0.5)
         line = MASKDARK;

      pos.x = fract(pos.x/3.0);
    
      if      (pos.x < 0.333) (BGR == 1.0) ? mask.b = MASKLIGHT : mask.r = MASKLIGHT;
      else if (pos.x < 0.666) mask.g = MASKLIGHT;
      else                    (BGR == 1.0) ? mask.r = MASKLIGHT : mask.b = MASKLIGHT;
      mask*=line;  
   } 

   // Aperture-grille.
   else if (SHADOWMASK == 2.0)
   {
      pos.x = fract(pos.x/3.0);

      if      (pos.x < 0.333) (BGR == 1.0) ? mask.b = MASKLIGHT : mask.r = MASKLIGHT;
      else if (pos.x < 0.666) mask.g = MASKLIGHT;
      else                   (BGR == 1.0) ? mask.r = MASKLIGHT : mask.b = MASKLIGHT;
   } 

   // Stretched VGA style shadow mask (same as prior shaders).
   else if (SHADOWMASK == 3.0)
   {
      pos.x += pos.y*3.0;
      pos.x  = fract(pos.x/6.0);

      if      (pos.x < 0.333) (BGR == 1.0) ? mask.b = MASKLIGHT : mask.r = MASKLIGHT;
      else if (pos.x < 0.666) mask.g = MASKLIGHT;
      else                    (BGR == 1.0) ? mask.r = MASKLIGHT : mask.b = MASKLIGHT;
   }

   // VGA style shadow mask.
   else if (SHADOWMASK == 4.0)
   {
      pos.xy = floor(pos.xy*vec2(1.0, 0.5));
      pos.x += pos.y*3.0;
      pos.x  = fract(pos.x/6.0);

      if      (pos.x < 0.333) (BGR == 1.0) ? mask.b = MASKLIGHT : mask.r = MASKLIGHT;
      else if (pos.x < 0.666) mask.g = MASKLIGHT;
      else                    (BGR == 1.0) ? mask.r = MASKLIGHT : mask.b = MASKLIGHT;
   }
   else if (SHADOWMASK == 5.0)
    {
        float line = MASKLIGHT;
        float odd  = 0.0;

        if (fract(pos.x/4.0) < 0.5)
            odd = 1.0;
        if (fract((pos.y + odd)/2.0) < 0.5)
            line = MASKDARK;

        pos.x = fract(pos.x/2.0);
    
        if  (pos.x < 0.5) {mask.r = MASKLIGHT; mask.b = MASKLIGHT;}
        else  mask.g = MASKLIGHT;   
        mask*=line;  
    } 



   else if (SHADOWMASK == -1.0) mask = vec3(1.0);
   return mask;
}

mat3 vign()
{
    vec2 vpos = vTexCoord * SourceSize.xy/OriginalSize.xy;
    vpos *= 1.0 - vpos;    

    float vig = vpos.x * vpos.y * VSTR;

    vig = min(pow(vig, VPOWER), 1.0); 
    
    if (VIGNETTE == 0.0) vig=1.0;
   
    return mat3(vig, 0, 0,
                 0,   vig, 0,
                 0,    0, vig);
}

float saturate(float v) 
    { 
        return clamp(v, 0.0, 1.0);       
    }

// https://www.shadertoy.com/view/lsSXW1
vec3 ColorTemperatureToRGB(float temperatureInKelvins)
{
    vec3 retColor;
    temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;
    
    if (temperatureInKelvins <= 66.0)
    {
        retColor.r = 1.0;
        retColor.g = saturate(0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098);
    }
    else
    {
        float t = temperatureInKelvins - 60.0;
        retColor.r = saturate(1.29293618606274509804 * pow(t, -0.1332047592));
        retColor.g = saturate(1.12989086089529411765 * pow(t, -0.0755148492));
    }
    
    if (temperatureInKelvins >= 66.0)
        retColor.b = 1.0;
    else if(temperatureInKelvins <= 19.0)
        retColor.b = 0.0;
    else
        retColor.b = saturate(0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914);

    return retColor;
}


vec3 glow0 (vec2 uv)
{
   vec3 sum = vec3(0.0);
   float x = uv.x;
   float y = uv.y;
   float xx = SourceSize.z*quality;
   float yy = SourceSize.w*quality;

   sum += texture(Source, vec2(x-xx,y)).rgb*0.1;
   sum += texture(Source,vec2(x-xx,y-yy)).rgb*0.1;
   sum += texture(Source,vec2(x,y-yy)).rgb*0.1;
   sum += texture(Source,vec2(x+xx,y-yy)).rgb*0.1;
   sum += texture(Source,vec2(x+xx,y)).rgb*0.1;
   sum += texture(Source,vec2(x+xx,y+yy)).rgb*0.1;
   sum += texture(Source,vec2(x, y-yy)).rgb*0.1;
   sum += texture(Source,vec2(x+xx,y+yy)).rgb*0.1;

   sum += texture(Source,vec2(x-2.0*xx,y)).rgb*0.05;
   sum += texture(Source,vec2(x-2.0*xx,y-yy)).rgb*0.05;
   sum += texture(Source,vec2(x-xx,y-2.0*yy)).rgb*0.05;
   sum += texture(Source,vec2(x,y-2.0*yy)).rgb*0.05;
   sum += texture(Source,vec2(x+xx,y-2.0*yy)).rgb*0.05;
   sum += texture(Source,vec2(x+2.0*xx,y-yy)).rgb*0.05;
   sum += texture(Source,vec2(x+2.0*xx,y)).rgb*0.05;
   sum += texture(Source,vec2(x+2.0*xx,y+yy)).rgb*0.05;
   sum += texture(Source,vec2(x+xx,y+2.0*yy)).rgb*0.05;
   sum += texture(Source,vec2(x,y+2.0*yy)).rgb*0.05;
   sum += texture(Source,vec2(x-xx,y+2.0*yy)).rgb*0.05;
   sum += texture(Source,vec2(x-2.0*xx,y-yy)).rgb*0.05;

   return sum * GLOW; 
}

float noise(vec2 co)
{
return fract(sin(iTimer * dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main()
{

// FILTER
        vec2 stepxy = SourceSize.zw;
     if (OriginalSize.y > 400.0 && INTERLACE == 0.0) stepxy.y *=2.0;

    vec2 texCoord = curve(vTexCoord.xy*(SourceSize.xy/OriginalSize.xy))*(OriginalSize.xy/SourceSize.xy.xy);
    
    vec2 pos = texCoord.xy + stepxy * 0.5;
    vec2 OGL2Pos = texCoord * SourceSize.xy;
    vec2 pC4 = floor(OGL2Pos) + 0.5;
    vec2 coord = pC4 / SourceSize.xy;
    vec2 f = fract(pos / stepxy);
    if (OriginalSize.y > 400.0 && INTERLACE == 1.0) f = vec2(1.0);
    else if (OriginalSize.y > 400.0 && INTERLACE == 0.0) f;

    float x = mix(texCoord.x,coord.x,SHARPNESSX);
    float y = mix(texCoord.y,coord.y,SHARPNESSY);
    vec4 color = texture(Source,vec2(x,y)); 

    float lum2 = dot(color.rgb,vec3(0.29,0.60,0.11));

//gamma in    
    color = pow(color, vec4(GAMMAIN));
    
//Color temp    
    color.rgb *= ColorTemperatureToRGB(TEMP);
    
    float lum = max(max(color.r,color.g),color.b);
// noise    
    color.rgb *= mix(1.0 + noise(texCoord)*nois,1.0,lum);
//scanlines
float ss = ScanLine(f.y, lum)+ScanLine(1.0-f.y, lum);
    color *= ss;
//mask
    float mask = 1.0 - DOTMASK_STRENGTH;
    vec3 dotMaskWeights = mix(vec3(1.0, mask, 1.0),
                             vec3(mask, 1.0, mask),
                             floor(mod(mod_factor, 2.0)));
    float msk = mix(MASKLOW,MASKHIGH,lum2);

 if (SHADOWMASK == 0.0) 
   {
      color.rgb *= mix(vec3(1.0),dotMaskWeights, msk);
   }
   else 
   {

      color.rgb *= mix(vec3(1.0),Mask(floor(1.000001 * vTexCoord.xy*OutputSize.xy + vec2(0.5,0.5))), msk);
   }

//gamma out
    color = pow(color, vec4(1.0/GAMMAOUT));  
//glow    
    color.rgb += glow0(pos);
//saturation
    color.rgb = mix(vec3(lum2)*ss,color.rgb, SAT);
//black level    
    color.rgb -= vec3(BLACK);
    color.rgb *= vec3(1.0)/vec3(1.0-BLACK);
//corner    
    color *= corner(texCoord);

    if (SEGA == 1.0) color.rgb *= 1.0625;

// vignette    
    color.rgb *= vign();
    FragColor = color;
}