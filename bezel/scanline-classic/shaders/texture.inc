// Texture sampling helpers (shared)

#ifndef TEXTURE_INC
#define TEXTURE_INC

#define clamp01(uv) clamp((uv), 0.0, 1.0 - EPS)

float bicubic(const float x, const float B, const float C)
{
	float dx = abs(x);

	if (dx < 1.0) {
		float P1 = 2.0 - 3.0 / 2.0 * B - C;
		float P2 = -3.0 + 2.0 * B + C;
		float P3 = 1.0 - 1.0 / 3.0 * B;

		return P1 * cb(dx) + P2 * sq(dx) + P3;
	} else if ((dx >= 1.0) && (dx < 2.0)) {
		float P1 = -1.0 / 6.0 * B - C;
		float P2 = B + 5.0 * C;
		float P3 = -2.0 * B - 8.0 * C;
		float P4 = 4.0 / 3.0 * B + 4.0 * C;

		return P1 * cb(dx) + P2 * sq(dx) + P3 * dx + P4;
	} else
		return 0.0;
}

vec4 bicubic4(const float x, const float B, const float C)
{
	return vec4(bicubic(x - 2.0, B, C),
	            bicubic(x - 1.0, B, C),
	            bicubic(x, B, C),
	            bicubic(x + 1.0, B, C));
}

vec3 sample_clamped(sampler2D source, vec2 uv)
{
    return texture(source, clamp01(uv)).rgb;
}

// Bicubic texture sampling (4x4 Mitchell-Netravali), clamp-to-zero
vec3 sample_bicubic(sampler2D source, vec2 uv, vec2 stepxy, float B, float C)
{
    vec2 pos = uv + stepxy / 2.0;
    vec2 f = fract(pos / stepxy);

    vec4 xtaps = bicubic4(1.0 - f.x, B, C);
    vec4 ytaps = bicubic4(1.0 - f.y, B, C);
    xtaps /= (xtaps.r + xtaps.g + xtaps.b + xtaps.a);
    ytaps /= (ytaps.r + ytaps.g + ytaps.b + ytaps.a);

    vec2 xystart = (-1.5 - f) * stepxy + pos;

    vec4 xpos = vec4(xystart.x,
        xystart.x + stepxy.x,
        xystart.x + stepxy.x * 2.0,
        xystart.x + stepxy.x * 3.0);

    vec3 col = vec3(0.0);

    float y0 = xystart.y;
    col += (texture(source, vec2(xpos.r, y0)).rgb * xtaps.r +
        texture(source, vec2(xpos.g, y0)).rgb * xtaps.g +
        texture(source, vec2(xpos.b, y0)).rgb * xtaps.b +
        texture(source, vec2(xpos.a, y0)).rgb * xtaps.a) * ytaps.r;

    float y1 = xystart.y + stepxy.y;
    col += (texture(source, vec2(xpos.r, y1)).rgb * xtaps.r +
        texture(source, vec2(xpos.g, y1)).rgb * xtaps.g +
        texture(source, vec2(xpos.b, y1)).rgb * xtaps.b +
        texture(source, vec2(xpos.a, y1)).rgb * xtaps.a) * ytaps.g;

    float y2 = xystart.y + stepxy.y * 2.0;
    col += (texture(source, vec2(xpos.r, y2)).rgb * xtaps.r +
        texture(source, vec2(xpos.g, y2)).rgb * xtaps.g +
        texture(source, vec2(xpos.b, y2)).rgb * xtaps.b +
        texture(source, vec2(xpos.a, y2)).rgb * xtaps.a) * ytaps.b;

    float y3 = xystart.y + stepxy.y * 3.0;
    col += (texture(source, vec2(xpos.r, y3)).rgb * xtaps.r +
        texture(source, vec2(xpos.g, y3)).rgb * xtaps.g +
        texture(source, vec2(xpos.b, y3)).rgb * xtaps.b +
        texture(source, vec2(xpos.a, y3)).rgb * xtaps.a) * ytaps.a;

    return col;
}

#endif
