layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main (void) {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float nnedi3_core(vec4 samples[8]);

// Interp-major window order: 4 consecutive taps form one samples[] slot.
#if NNEDI3_VERTICAL
const ivec2 nnedi3_tap_offsets[32] = ivec2[32](
	ivec2(-3, -1), ivec2(-2, -1), ivec2(-1, -1), ivec2( 0, -1),
	ivec2( 1, -1), ivec2( 2, -1), ivec2( 3, -1), ivec2( 4, -1),
	ivec2(-3,  0), ivec2(-2,  0), ivec2(-1,  0), ivec2( 0,  0),
	ivec2( 1,  0), ivec2( 2,  0), ivec2( 3,  0), ivec2( 4,  0),
	ivec2(-3,  1), ivec2(-2,  1), ivec2(-1,  1), ivec2( 0,  1),
	ivec2( 1,  1), ivec2( 2,  1), ivec2( 3,  1), ivec2( 4,  1),
	ivec2(-3,  2), ivec2(-2,  2), ivec2(-1,  2), ivec2( 0,  2),
	ivec2( 1,  2), ivec2( 2,  2), ivec2( 3,  2), ivec2( 4,  2));
#else
const ivec2 nnedi3_tap_offsets[32] = ivec2[32](
	ivec2(-1, -3), ivec2(-1, -2), ivec2(-1, -1), ivec2(-1,  0),
	ivec2(-1,  1), ivec2(-1,  2), ivec2(-1,  3), ivec2(-1,  4),
	ivec2( 0, -3), ivec2( 0, -2), ivec2( 0, -1), ivec2( 0,  0),
	ivec2( 0,  1), ivec2( 0,  2), ivec2( 0,  3), ivec2( 0,  4),
	ivec2( 1, -3), ivec2( 1, -2), ivec2( 1, -1), ivec2( 1,  0),
	ivec2( 1,  1), ivec2( 1,  2), ivec2( 1,  3), ivec2( 1,  4),
	ivec2( 2, -3), ivec2( 2, -2), ivec2( 2, -1), ivec2( 2,  0),
	ivec2( 2,  1), ivec2( 2,  2), ivec2( 2,  3), ivec2( 2,  4));
#endif

vec4 nnedi3_fetch_tap(ivec2 base, int tap, ivec2 src_size)
{
	return texelFetch(Source, clamp(base + nnedi3_tap_offsets[tap], ivec2(0), src_size - ivec2(1)), 0);
}

// Default gather path: the 8x4 window tiles into 8 2x2 quads, so one
// channel needs 8 textureGather calls instead of 32 fetches. Requires
// wrap_mode = clamp_to_edge on the pass (border texels are clamped by the
// sampler here, not by index math). Gather coordinates sit on texel
// corners: the corner (base + quadOrigin + 1) is the center of the quad's
// selection interval, maximally far from rounding boundaries (which lie on
// texel centers). Gather component order: w=(0,0) z=(1,0) x=(0,1) y=(1,1)
// relative to the quad origin.
#ifndef NNEDI3_USE_GATHER
#define NNEDI3_USE_GATHER 1
#endif

#if NNEDI3_USE_GATHER
#if NNEDI3_VERTICAL
// Quad origins: dx {-3,-1,1,3} x dy {-1,1}. Row pairs map to sample slots:
// dy=-1 -> s[0..1], 0 -> s[2..3], 1 -> s[4..5], 2 -> s[6..7].
#define NNEDI3_DEF_GATHER(fname, comp) \
float fname(vec2 gbase, vec2 pt) \
{ \
	vec4 q00 = textureGather(Source, gbase + vec2(-3.0, -1.0) * pt, comp); \
	vec4 q10 = textureGather(Source, gbase + vec2(-1.0, -1.0) * pt, comp); \
	vec4 q20 = textureGather(Source, gbase + vec2( 1.0, -1.0) * pt, comp); \
	vec4 q30 = textureGather(Source, gbase + vec2( 3.0, -1.0) * pt, comp); \
	vec4 q01 = textureGather(Source, gbase + vec2(-3.0,  1.0) * pt, comp); \
	vec4 q11 = textureGather(Source, gbase + vec2(-1.0,  1.0) * pt, comp); \
	vec4 q21 = textureGather(Source, gbase + vec2( 1.0,  1.0) * pt, comp); \
	vec4 q31 = textureGather(Source, gbase + vec2( 3.0,  1.0) * pt, comp); \
	vec4 s[8]; \
	s[0] = vec4(q00.w, q00.z, q10.w, q10.z); \
	s[1] = vec4(q20.w, q20.z, q30.w, q30.z); \
	s[2] = vec4(q00.x, q00.y, q10.x, q10.y); \
	s[3] = vec4(q20.x, q20.y, q30.x, q30.y); \
	s[4] = vec4(q01.w, q01.z, q11.w, q11.z); \
	s[5] = vec4(q21.w, q21.z, q31.w, q31.z); \
	s[6] = vec4(q01.x, q01.y, q11.x, q11.y); \
	s[7] = vec4(q21.x, q21.y, q31.x, q31.y); \
	return nnedi3_core(s); \
}
#else
// Transposed: quad origins dx {-1,1} x dy {-3,-1,1,3}. Column pairs map to
// sample slots: dx=-1 -> s[0..1], 0 -> s[2..3], 1 -> s[4..5], 2 -> s[6..7].
#define NNEDI3_DEF_GATHER(fname, comp) \
float fname(vec2 gbase, vec2 pt) \
{ \
	vec4 qa = textureGather(Source, gbase + vec2(-1.0, -3.0) * pt, comp); \
	vec4 qb = textureGather(Source, gbase + vec2(-1.0, -1.0) * pt, comp); \
	vec4 qc = textureGather(Source, gbase + vec2(-1.0,  1.0) * pt, comp); \
	vec4 qd = textureGather(Source, gbase + vec2(-1.0,  3.0) * pt, comp); \
	vec4 qe = textureGather(Source, gbase + vec2( 1.0, -3.0) * pt, comp); \
	vec4 qf = textureGather(Source, gbase + vec2( 1.0, -1.0) * pt, comp); \
	vec4 qg = textureGather(Source, gbase + vec2( 1.0,  1.0) * pt, comp); \
	vec4 qh = textureGather(Source, gbase + vec2( 1.0,  3.0) * pt, comp); \
	vec4 s[8]; \
	s[0] = vec4(qa.w, qa.x, qb.w, qb.x); \
	s[1] = vec4(qc.w, qc.x, qd.w, qd.x); \
	s[2] = vec4(qa.z, qa.y, qb.z, qb.y); \
	s[3] = vec4(qc.z, qc.y, qd.z, qd.y); \
	s[4] = vec4(qe.w, qe.x, qf.w, qf.x); \
	s[5] = vec4(qg.w, qg.x, qh.w, qh.x); \
	s[6] = vec4(qe.z, qe.y, qf.z, qf.y); \
	s[7] = vec4(qg.z, qg.y, qh.z, qh.y); \
	return nnedi3_core(s); \
}
#endif

NNEDI3_DEF_GATHER(nnedi3_gather_core_r, 0)
#if NNEDI3_RGB
NNEDI3_DEF_GATHER(nnedi3_gather_core_g, 1)
NNEDI3_DEF_GATHER(nnedi3_gather_core_b, 2)
#endif
#endif

// Every nnedi3_core call below is wrapped in a branch that is always true at
// runtime but that the compiler cannot fold (interpolant-based, and distinct
// per call so the regions don't merge). This is load-bearing for driver
// compile time, not a style choice: with the MLP bodies inlined into one
// branchless basic block, NVIDIA's pipeline compile goes superlinear
// (~70 s per pipeline at nns256 vs ~11 s with the branches; the legacy
// shaders were only fast to compile because the even/odd parity branch
// played this role by accident). Do not "simplify" these away.
vec4 nnedi3_predict()
{
	ivec2 src_size = ivec2(params.SourceSize.xy);
	ivec2 base = clamp(ivec2(floor(vTexCoord.xy * params.SourceSize.xy)), ivec2(0), src_size - ivec2(1));

#if NNEDI3_USE_GATHER
	vec2 pt = params.SourceSize.zw;
	vec2 gbase = (vec2(base) + 1.0) * pt;
#if NNEDI3_RGB
	vec3 rgb = vec3(0.0);
	if (vTexCoord.x >= -1.0) rgb.r = nnedi3_gather_core_r(gbase, pt);
	if (vTexCoord.y >= -1.0) rgb.g = nnedi3_gather_core_g(gbase, pt);
	if (vTexCoord.x >= -2.0) rgb.b = nnedi3_gather_core_b(gbase, pt);
	return vec4(rgb, 1.0);
#else
	float y = 0.0;
	if (vTexCoord.x >= -1.0) y = nnedi3_gather_core_r(gbase, pt);
	return vec4(y, 1.0, 1.0, 1.0);
#endif
#elif NNEDI3_RGB
	vec4 sr[8], sg[8], sb[8];
	for (int i = 0; i < 8; i++) {
		vec4 a = nnedi3_fetch_tap(base, 4 * i + 0, src_size);
		vec4 b = nnedi3_fetch_tap(base, 4 * i + 1, src_size);
		vec4 c = nnedi3_fetch_tap(base, 4 * i + 2, src_size);
		vec4 d = nnedi3_fetch_tap(base, 4 * i + 3, src_size);
		sr[i] = vec4(a.r, b.r, c.r, d.r);
		sg[i] = vec4(a.g, b.g, c.g, d.g);
		sb[i] = vec4(a.b, b.b, c.b, d.b);
	}

	vec3 rgb = vec3(0.0);
	if (vTexCoord.x >= -1.0) rgb.r = nnedi3_core(sr);
	if (vTexCoord.y >= -1.0) rgb.g = nnedi3_core(sg);
	if (vTexCoord.x >= -2.0) rgb.b = nnedi3_core(sb);
	return vec4(rgb, 1.0);
#else
	vec4 sy[8];
	for (int i = 0; i < 8; i++) {
		sy[i] = vec4(
			nnedi3_fetch_tap(base, 4 * i + 0, src_size).x,
			nnedi3_fetch_tap(base, 4 * i + 1, src_size).x,
			nnedi3_fetch_tap(base, 4 * i + 2, src_size).x,
			nnedi3_fetch_tap(base, 4 * i + 3, src_size).x);
	}

	float y = 0.0;
	if (vTexCoord.x >= -1.0) y = nnedi3_core(sy);
	return vec4(y, 1.0, 1.0, 1.0);
#endif
}
