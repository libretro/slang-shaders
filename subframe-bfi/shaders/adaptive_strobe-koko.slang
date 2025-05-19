#version 450

// Adaptive Strobe BFI
// Alternate bright and dark gainss across (sub)Frames
// to reduce Sample and hold induced blur without impacting
// brightness.
// License: GNU GPL V3.

#define pi 3.1415926535898

layout(push_constant) uniform Push {
  uint FrameCount, CurrentSubFrame, TotalSubFrames;
  float _ADPT_STROBE_STR, _ADPT_STROBE_GAIN_ADJ, _ADPT_STROBE_GAMMA_ADJ;
  float _ADPT_LCD_RETENTION_FIX, _ADPT_STROBE_GAIN_ADJ_NODARK, _ADPT_DEBUG_ONOFF;
} params;


#pragma parameter _ADPT_STROBE_STR               "[ Adaptive Strobe (≈BFI) Strength: ]"   0.8   0.0  1.0  0.05
#pragma parameter _ADPT_STROBE_GAIN_ADJ          "   .   Gain adjustment"    0.9   0.0  1.0  0.05
#pragma parameter _ADPT_STROBE_GAIN_ADJ_NODARK       "          Less gain on dark colors"    1.0   0.0  1.0  0.05
#pragma parameter _ADPT_STROBE_GAMMA_ADJ         "   .   Post Gamma adjustment"   0.9   0.5  4.0  0.05
#pragma parameter _ADPT_LCD_RETENTION_FIX        "   .   LCD Retention workaround cadence (frames)"    3600  0.0  300000.0  50.0
#pragma parameter _ADPT_DEBUG_ONOFF              "   .   Debug: Flip effect ON/OFF every (frames)"     0.0   0.0  100000.0  10.0


layout(std140, set = 0, binding = 0) uniform UBO {
  mat4 MVP;
} global;

uint frame_subframe() {
  return params.FrameCount * params.TotalSubFrames + params.CurrentSubFrame;
}

bool frame_subframe_is_even() {
  return (frame_subframe() & 1) == 0;
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float vOsc;

void main() {
  gl_Position = global.MVP * Position;
  vTexCoord = TexCoord;
  float iFrameMod = 0.0;
  //+1 should take care of oscillator invertion to avoid voltage accumuation in IPS panels (?)
  if (params._ADPT_LCD_RETENTION_FIX > 0.0)
    iFrameMod = mod(frame_subframe(), params.TotalSubFrames * params._ADPT_LCD_RETENTION_FIX + 1) ;
  else
    iFrameMod = mod(frame_subframe(), params.TotalSubFrames * 300.0); //mod needed to avoid drifting sin precision errors
  
  vOsc = cos(iFrameMod * pi);
  
  
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float vOsc;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;



vec3 adaptive_strobe(vec3 c) {

  //Debug/Test
    if (params._ADPT_DEBUG_ONOFF!=0.0)
      if (mod(params.FrameCount, params._ADPT_DEBUG_ONOFF*2) > params._ADPT_DEBUG_ONOFF)
        return c;

  c = clamp(c, vec3(0.0), vec3(1.0));
  
  vec3 osc = vec3(vOsc);
  float gain_adj =  mix(1.0, params._ADPT_STROBE_GAIN_ADJ,  params._ADPT_STROBE_STR);
  
  // less gain on dark colors
  // On my oled LG-C2, the gain needs to be higher(lower) when the image is brighter(darker), not sure why. (?)
    if (vOsc > 0.0) {
      osc = mix(osc*gain_adj, osc * gain_adj * c, params._ADPT_STROBE_GAIN_ADJ_NODARK) ;
    }

  vec3 room = (0.5 - abs(0.5-c));
  c += room * osc * params._ADPT_STROBE_STR ;

  //post gamma
  float gamma_adj = mix(1.0, params._ADPT_STROBE_GAMMA_ADJ, params._ADPT_STROBE_STR);
  c = pow(c, vec3(gamma_adj));
  
  return c;
}


void main() {
  vec3 c = texture(Source, vTexCoord).rgb;

  //c = vec3(  (sin( vTexCoord.x*50.0 +frame_subframe()*0.5   ))  );
  //c=step(0.0  , c)*vec3(0.5,1,1);

  FragColor.rgb = adaptive_strobe(c);
}
