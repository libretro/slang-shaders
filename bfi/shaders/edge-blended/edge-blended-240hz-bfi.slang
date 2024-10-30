#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   uint CurrentSubFrame;
   uint TotalSubFrames;
   float favor_black;
} params;

// setting this to 1 makes 75% of the screen black at all times
// while setting it to 0 makes it only 25% black
#pragma parameter favor_black "Favor Black" 1.0 0.0 1.0 1.0

// set a macro here for debugging purposes since there's no way to advance subframes
#define debugFrame params.CurrentSubFrame

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 check;
layout(location = 2) out vec2 lutCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
// TODO/FIXME: figure out some good way to make the seams roll
   lutCoord = TexCoord;// + vec2(0., mod(float(params.FrameCount), 250.)/1000.);
// set up a bool to check which sub-frame we're currently on
   bvec4 checkbool = bvec4(debugFrame == 1,
                           debugFrame == 2,
                           debugFrame == 3,
                           debugFrame == 4);
// flip the check bool if we want to blackout on all but one sub-frame
   bvec4 boolflip = bvec4(params.favor_black);
   check.x = boolflip.x ? float(!checkbool.x) : float(checkbool.x);
   check.y = boolflip.y ? float(!checkbool.y) : float(checkbool.y);
   check.z = boolflip.z ? float(!checkbool.z) : float(checkbool.z);
   check.w = boolflip.w ? float(!checkbool.w) : float(checkbool.w);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 check;
layout(location = 2) in vec2 lutCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D top;
layout(set = 0, binding = 4) uniform sampler2D bot;
layout(set = 0, binding = 5) uniform sampler2D midtop;
layout(set = 0, binding = 6) uniform sampler2D midbot;

void main()
{
   FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
// early return if we don't have subframes enabled
   if(params.TotalSubFrames == 1) return;

// use a nonstandard approximation of linear gamma to blend transitions better
// going higher makes the transitions blend better but creates harsh lines elsewhere
   FragColor = pow(FragColor, vec4(2.5));

// sample the LUTs, "linearize" them
   vec4 Top = texture(top, lutCoord);
   Top = pow(Top, vec4(2.5));
   vec4 Bot = texture(bot, lutCoord);
   Bot = pow(Bot, vec4(2.5));
   vec4 MidTop = texture(midtop, lutCoord);
   MidTop = pow(MidTop, vec4(2.5));
   vec4 MidBot = texture(midbot, lutCoord);
   MidBot = pow(MidBot, vec4(2.5));

// based on the subframe, apply the blackout LUTs
   FragColor = (bool(check.x)) ? mix(FragColor, Top, Top.a) : FragColor;
   FragColor = (bool(check.y)) ? mix(FragColor, MidTop, MidTop.a) : FragColor;
   FragColor = (bool(check.z)) ? mix(FragColor, MidBot, MidBot.a) : FragColor;
   FragColor = (bool(check.w)) ? mix(FragColor, Bot, Bot.a) : FragColor;

// black-out the other transitions when preferring black
   FragColor *= (params.favor_black > 0.5 && debugFrame == 1 && vTexCoord.y > 0.3333) ? vec4(0.0) : vec4(1.0);
   FragColor *= (params.favor_black > 0.5 && debugFrame == 3 && (vTexCoord.y > 0.8 || vTexCoord.y < 0.3333)) ? vec4(0.0) : vec4(1.0);
   FragColor *= (params.favor_black > 0.5 && debugFrame == 2 && (vTexCoord.y > 0.6667 || vTexCoord.y < 0.2)) ? vec4(0.0) : vec4(1.0);
   FragColor *= (params.favor_black > 0.5 && debugFrame == 4 && vTexCoord.y < 0.6667) ? vec4(0.0) : vec4(1.0);

// de-"linearize"
   FragColor = pow(FragColor, vec4(1./2.5));
}
