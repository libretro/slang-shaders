#version 450

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
} global;

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

void main()
{
   vec2 texelSize = 1.0 / global.SourceSize.xy;

   vec2 range = vec2(abs(global.SourceSize.z / (global.OutputSize.x * global.SourceSize.x)), abs(global.SourceSize.w / (global.OutputSize.y * global.SourceSize.y)));
   range = range / 2.0 * 0.999;

   float left   = vTexCoord.x - range.x;
   float top    = vTexCoord.y + range.y;
   float right  = vTexCoord.x + range.x;
   float bottom = vTexCoord.y - range.y;

   vec3 topLeftColor     = texture(Source, (floor(vec2(left, top)     / texelSize) + 0.5) * texelSize).rgb;
   vec3 bottomRightColor = texture(Source, (floor(vec2(right, bottom) / texelSize) + 0.5) * texelSize).rgb;
   vec3 bottomLeftColor  = texture(Source, (floor(vec2(left, bottom)  / texelSize) + 0.5) * texelSize).rgb;
   vec3 topRightColor    = texture(Source, (floor(vec2(right, top)    / texelSize) + 0.5) * texelSize).rgb;

   vec2 border = clamp(round(vTexCoord / texelSize) * texelSize, vec2(left, bottom), vec2(right, top));

   float totalArea = 4.0 * range.x * range.y;

   vec3 averageColor;
   averageColor  = ((border.x - left)  * (top - border.y)    / totalArea) * topLeftColor;
   averageColor += ((right - border.x) * (border.y - bottom) / totalArea) * bottomRightColor;
   averageColor += ((border.x - left)  * (border.y - bottom) / totalArea) * bottomLeftColor;
   averageColor += ((right - border.x) * (top - border.y)    / totalArea) * topRightColor;

   FragColor = vec4(averageColor, 1.0);
}