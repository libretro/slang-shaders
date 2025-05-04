
layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

   float tp_test_pattern;
   float tp_test_pattern_split;
   float tp_split_brightness;
   float tp_bars_stepcount;
   float tp_bars_spacing;
   float tp_bars_genesis;
   float tp_spectrum_zoom;
   float tp_nespal_palette;
   float tp_univ_border_left;
   float tp_univ_border_right;
   float tp_univ_border_top;
   float tp_univ_border_bottom;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter tp_dummy_header "=== Test pattern settings ===" 0 0 0 1
#pragma parameter tp_test_pattern "##### Test pattern selector #####" 0 0 8 1
#pragma parameter tp_test_pattern_split "Toggle split mode" 1 0 1 1
#pragma parameter tp_split_brightness "Split brightness" 1 0 1 0.025
#pragma parameter tp_bars_stepcount "1-5: # steps (including black)" 16 2 256 1
#pragma parameter tp_bars_spacing "1-5: Spacing" 0.35 0.0 1.0 0.05
#pragma parameter tp_bars_genesis "1-5: Genesis/MegaDrive palette (limits # steps)" 0 0 1 1
#pragma parameter tp_spectrum_zoom "7: Zoom key points (0=no zoom, 1=max zoom)" 0.5 0 1 0.1
#pragma parameter tp_nespal_palette "8: NES palette (List in palettes_table.txt)" -1 -1 308 1
#pragma parameter tp_univ_border_left "Border left" 0.1 0 1 0.01
#pragma parameter tp_univ_border_right "Border right" 0.1 0 1 0.01
#pragma parameter tp_univ_border_top "Border top" 0.1 0 1 0.01
#pragma parameter tp_univ_border_bottom "Border bottom" 0.1 0 1 0.01
#pragma parameter tp_dummy_footer "=== End test pattern settings ===" 0 0 0 1

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
layout(set = 0, binding = 3) uniform sampler2D tpAllPalettes;

vec3 colorRamps(vec2 pos, int rampType) {
   int rampCounts[] = {7, 6, 6, 6, 6};
   vec3 rampLists[5][7][2] = {
      { // Brightness
         {vec3(0, 0, 0), vec3(1, 1, 1)},
         {vec3(0, 0, 0), vec3(1, 0, 0)},
         {vec3(0, 0, 0), vec3(0, 1, 0)},
         {vec3(0, 0, 0), vec3(0, 0, 1)},
         {vec3(0, 0, 0), vec3(0, 1, 1)},
         {vec3(0, 0, 0), vec3(1, 0, 1)},
         {vec3(0, 0, 0), vec3(1, 1, 0)},
      },
      { // Saturation 50%
         {vec3(.5, .5, .5), vec3(.5, 0, 0)},
         {vec3(.5, .5, .5), vec3(0, .5, 0)},
         {vec3(.5, .5, .5), vec3(0, 0, .5)},
         {vec3(.5, .5, .5), vec3(0, .5, .5)},
         {vec3(.5, .5, .5), vec3(.5, 0, .5)},
         {vec3(.5, .5, .5), vec3(.5, .5, 0)},
         {vec3(0), vec3(0)} // Dummy entry
      },
      { // Saturation 100%
         {vec3(1, 1, 1), vec3(1, 0, 0)},
         {vec3(1, 1, 1), vec3(0, 1, 0)},
         {vec3(1, 1, 1), vec3(0, 0, 1)},
         {vec3(1, 1, 1), vec3(0, 1, 1)},
         {vec3(1, 1, 1), vec3(1, 0, 1)},
         {vec3(1, 1, 1), vec3(1, 1, 0)},
         {vec3(0), vec3(0)} // Dummy entry
      },
      { // Hue 50%
         {vec3(.5, 0, 0), vec3(.5, .5, 0)},
         {vec3(.5, .5, 0), vec3(0, .5, 0)},
         {vec3(0, .5, 0), vec3(0, .5, .5)},
         {vec3(0, .5, .5), vec3(0, 0, .5)},
         {vec3(0, 0, .5), vec3(.5, 0, .5)},
         {vec3(.5, 0, .5), vec3(.5, 0, 0)},
         {vec3(0), vec3(0)} // Dummy entry
      },
      { // Hue 100%
         {vec3(1, 0, 0), vec3(1, 1, 0)},
         {vec3(1, 1, 0), vec3(0, 1, 0)},
         {vec3(0, 1, 0), vec3(0, 1, 1)},
         {vec3(0, 1, 1), vec3(0, 0, 1)},
         {vec3(0, 0, 1), vec3(1, 0, 1)},
         {vec3(1, 0, 1), vec3(1, 0, 0)},
         {vec3(0), vec3(0)} // Dummy entry
      }
   };

   int mdStepCounts[] = {15, 8, 15, 8, 15};

   // Taken from BlastEm
   float mdLevels[] = {0, 27, 49, 71, 87, 103, 119, 130, 146, 157, 174, 190, 206, 228, 255};

   int numRamps = rampCounts[rampType];
   int numSteps = params.tp_bars_genesis < 0.5 ? int(params.tp_bars_stepcount + 0.5) : mdStepCounts[rampType];

   // It is already guaranteed that pos.x and pos.y will be in bounds.
   int x = int(pos.x * numSteps);
   int y = int(pos.y * numRamps);

   float portion = mod(pos.y * numRamps, 1.0);

#ifdef APPEND_PASS
   if(portion > 0.5 * (1 - params.tp_bars_spacing))
      return vec3(-1);
#else
   if(portion > 1 - params.tp_bars_spacing)
      return vec3(0);
#endif
   
   vec3 result = mix(rampLists[rampType][y][0], rampLists[rampType][y][1], float(x) / float(numSteps - 1));

   if(params.tp_bars_genesis > 0.5) {
      for(int i = 0; i < 3; i++) {
         result[i] = mdLevels[int(clamp(result[i], 0, 1) * 14 + 0.5)] / 255.0;
      }
   }

   return result;
}

vec3 hsvSpectrum(vec2 pos, bool widenKeyAreas) {

#ifdef PREPEND_PASS
   vec3 black = vec3(0);
   vec3 white = vec3(1);
   vec3 primaries[] = {
      vec3(1, 0, 1),
      vec3(1, 0, 0),
      vec3(1, 1, 0),
      vec3(0, 1, 0),
      vec3(0, 1, 1),
      vec3(0, 0, 1),
      vec3(1, 0, 1), // Colors are repeated intentionally
      vec3(1, 0, 0),
      vec3(1, 1, 0),
   };

   float scaledY = pos.y * 7.0 + 0.5;
   int lowIndex = int(floor(scaledY) + 0.1);
   int highIndex = int(ceil(scaledY) + 0.1);
   float interpolation = scaledY - lowIndex;
   if(widenKeyAreas)
      interpolation = params.tp_spectrum_zoom < 1 ? min(interpolation / (1 - params.tp_spectrum_zoom), 1.0) : 1.0;
   vec3 mixedCenter = mix(primaries[lowIndex], primaries[highIndex], interpolation);

   float scaledX = pos.x * 2;
   if(scaledX < 1) {
      if(widenKeyAreas)
         scaledX = params.tp_spectrum_zoom < 1 ? min(scaledX / (1 - params.tp_spectrum_zoom), 1.0) : 1.0;
      return mix(black, mixedCenter, scaledX);
   } else {
      return mix(mixedCenter, white, scaledX - 1);
   }
#else
   return vec3(-1);
#endif
}

vec3 nesFullPalette(vec2 pos) {
#ifdef APPEND_PASS
   if(mod(pos.x, 1.0 / 16.0) > 1.0 / 32.0) {
      return vec3(-1);
   }
#endif

   float hue = floor(pos.x * 16.0) / 15.0;
   float emphasis = floor(pos.y * 8.0) / 7.0;
   float level = floor(4.0 * (pos.y * 8.0 - floor(pos.y * 8.0))) / 3.0;
   if(params.tp_nespal_palette < -0.5) {
      return vec3(hue, level, emphasis);
   } else {
      int index = int(0.5 + hue * 15) + 16 * int(0.5 + level * 3) + 64 * int(0.5 + emphasis * 7);
      return texture(tpAllPalettes, vec2((index + 0.5) / textureSize(tpAllPalettes, 0).x, (params.tp_nespal_palette + 0.5) / textureSize(tpAllPalettes, 0).y)).rgb;
   }
}

void main()
{

#ifdef APPEND_PASS
   if(params.tp_test_pattern_split < 0.5) {
      FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
      return;
   }
#endif

   if(params.tp_test_pattern < 0.5) {
      // 0: No test patterns
      FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
      return;
   }

   vec2 pos = vec2((vTexCoord.x - params.tp_univ_border_left) / (1 - params.tp_univ_border_right - params.tp_univ_border_left),
                  (vTexCoord.y - params.tp_univ_border_top) / (1 - params.tp_univ_border_bottom - params.tp_univ_border_top));
   if(pos.x <= 0 || pos.x >= 1
      || pos.y <= 0 || pos.y >= 1) {
#ifdef PREPEND_PASS
         FragColor = vec4(vec3(0), 1);
#else
         FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
#endif
         return;
      }
   vec3 result;
   if(params.tp_test_pattern < 5.5) {
      // 1: Brightness scales
      // 2: Saturation scales (50% brightness)
      // 3: Saturation scales (100% brightness)
      // 4: Hue scales (50% brightness)
      // 5: Hue scales (100% brightness)
      result = colorRamps(pos, int(params.tp_test_pattern - 1 + 0.5));
   } else if(params.tp_test_pattern < 7.5) {
      // 6: HSL spectrum unmodified
      // 7: HSL spectrum with optional zooming on key points
      result = hsvSpectrum(pos, params.tp_test_pattern > 6.5);
   } else {
      // 8: Full NES palette
      result = nesFullPalette(pos);
   }
#ifdef APPEND_PASS
   if(result == vec3(-1)) {
      FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
      return;
   }

   result *= params.tp_split_brightness;
#endif

   FragColor = vec4(result, 1.0);
}