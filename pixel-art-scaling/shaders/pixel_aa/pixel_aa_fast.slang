#version 450

// See the main shader file for copyright and other information.

layout(push_constant) uniform Push {
  vec4 SourceSize;
  vec4 OutputSize;
}
param;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; }
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 tx_coord;
layout(location = 1) out vec2 px_per_tx;

void main() {
  gl_Position = global.MVP * Position;
  tx_coord = TexCoord * param.SourceSize.xy - 0.5;
  px_per_tx = param.OutputSize.xy * param.SourceSize.zw;
}

#pragma stage fragment
layout(location = 0) in vec2 tx_coord;
layout(location = 1) in vec2 px_per_tx;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
  vec2 period;
  const vec2 phase = modf(tx_coord, period);

  const vec2 t = clamp((phase - 0.5) * px_per_tx + 0.5, 0.0, 1.0);
  const vec2 offset = t * t * (3.0 - 2.0 * t);

  const vec3 res =
      texture(Source, (period + 0.5 + offset) * param.SourceSize.zw).rgb;
  FragColor = vec4(sqrt(res), 1.0);
}
