#version 450

/*
	Scale3xSFX
	by Sp00kyFox, 2015

Filter:	Nearest
Scale:	3x

Scale3SFX improves upon the original Scale3x by avoiding the occurence of artifacts and smoothing out 45° edges.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float YTR;
	float UTR;
	float VTR;
} params;

#pragma parameter YTR "SCALE3xSFX Y Threshold" 48.0 0.0 255.0 1.0
#pragma parameter UTR "SCALE3xSFX U Threshold"  7.0 0.0 255.0 1.0
#pragma parameter VTR "SCALE3xSFX V Threshold"  6.0 0.0 255.0 1.0

#define YTR params.YTR
#define UTR params.UTR
#define VTR params.VTR

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#define saturate(c) clamp(c, 0.0, 1.0)
#define lerp(a,b,c) mix(a,b,c)
#define mul(a,b) (b*a)
#define fmod(c,d) mod(c,d)
#define frac(c) fract(c)
#define tex2D(c,d) texture(c,d)
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define int2 ivec2
#define int3 ivec3
#define int4 ivec4
#define bool2 bvec2
#define bool3 bvec3
#define bool4 bvec4
#define float2x2 mat2x2
#define float3x3 mat3x3
#define float4x4 mat4x4
#define float4x3 mat4x3

#define decal Source

const float3x3 YUV  = float3x3(0.299, -0.168736, 0.5, 0.587, -0.331264, -0.418688, 0.114, 0.5, -0.081312);	// transponed
bool eq(float3 A, float3 B)
{
    return all(lessThanEqual(abs(A-B), float3(YTR, UTR, VTR)/255.0));
}

bool neq(float3 A, float3 B)
{
    return any(greaterThan(abs(A-B), float3(YTR, UTR, VTR)/255.0));
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 texCoord;
layout(location = 1) out vec4 t1;
layout(location = 2) out vec4 t2;
layout(location = 3) out vec4 t3;
layout(location = 4) out vec4 t4;
layout(location = 5) out vec4 t5;

void main()
{
   gl_Position = global.MVP * Position;
   texCoord = TexCoord;
   
   	float2 ps = float2(params.SourceSize.z, params.SourceSize.w);
	float dx = ps.x;
	float dy = ps.y;

	t1 = texCoord.xxxy + float4(-dx,  0, dx,-dy);	// A, B, C
	t2 = texCoord.xxxy + float4(-dx,  0, dx,  0);	// D, E, F
	t3 = texCoord.xxxy + float4(-dx,  0, dx, dy);	// G, H, I
	t4 = texCoord.xyxy + float4(    0,-2*dy,-2*dx,    0);	// J, K
	t5 = texCoord.xyxy + float4( 2*dx,    0,    0, 2*dy);	// L, M
}

#pragma stage fragment
layout(location = 0) in vec2 texCoord;
layout(location = 1) in vec4 t1;
layout(location = 2) in vec4 t2;
layout(location = 3) in vec4 t3;
layout(location = 4) in vec4 t4;
layout(location = 5) in vec4 t5;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
	// subpixel determination
	float2 fp = floor(3.0 * frac(texCoord*params.SourceSize.xy));

	/*
		    J
		  A B C		E0 E1 E2
		K D E F L	E3 E4 E5
		  G H I		E6 E7 E8
		    M
	*/

	// reading the texels & color space conversion
	float3 b = tex2D(decal, t1.yw).xyz;
	float3 d = tex2D(decal, t2.xw).xyz;
	float3 e = tex2D(decal, t2.yw).xyz;
	float3 f = tex2D(decal, t2.zw).xyz;
	float3 h = tex2D(decal, t3.yw).xyz;

	float4x3 tmp = mul(float4x3(b,d,e,f), YUV);
	float3 B = tmp[0], D = tmp[1], E = tmp[2], F = tmp[3], H = mul(h, YUV);

	float3 A = tex2D(decal, t1.xw).xyz;
	float3 C = tex2D(decal, t1.zw).xyz;
	float3 G = tex2D(decal, t3.xw).xyz;
	float3 I = tex2D(decal, t3.zw).xyz;

	tmp = mul(float4x3(A,C,G,I), YUV);
	A = tmp[0], C = tmp[1], G = tmp[2], I = tmp[3];

	float3 J = tex2D(decal, t4.xy).xyz;
	float3 K = tex2D(decal, t4.zw).xyz;
	float3 L = tex2D(decal, t5.xy).xyz;
	float3 M = tex2D(decal, t5.zw).xyz;

	tmp = mul(float4x3(J,K,L,M), YUV);
	J = tmp[0], K = tmp[1], L = tmp[2], M = tmp[3];



	// equality checks
	bool AE = eq(A,E), AJ = eq(A,J), AK = eq(A,K), BD = eq(B,D), BF = eq(B,F), CE = eq(C,E), CJ = eq(C,J), CL = eq(C,L), DH = eq(D,H), EG = eq(E,G), EI = eq(E,I), FH = eq(F,H), GK = eq(G,K), GM = eq(G,M), IL = eq(I,L), IM = eq(I,M);

	// parent condition
	bool par0 = !(BF || DH);
	bool par1 = !(BD || FH);

	// diagonal condition
	bool dia0 = AE || EI;
	bool dia1 = CE || EG;

	// artifact prevention
	bool art0 = BD && par0 && (!AE || dia1 || AJ || AK);
	bool art2 = BF && par1 && (!CE || dia0 || CJ || CL);
	bool art6 = DH && par1 && (!EG || dia0 || GK || GM);
	bool art8 = FH && par0 && (!EI || dia1 || IL || IM);



	// rules
	float3 E0 = art0 || BD && (CE && !CJ && !AE || EG && !AE && !GK) ? 0.5*(b+d) : e;
	float3 E2 = art2 || BF && (AE && !AJ && !CE || EI && !CE && !IL) ? 0.5*(b+f) : e;
	float3 E6 = art6 || DH && (AE && !AK && !EG || EI && !EG && !IM) ? 0.5*(h+d) : e;
	float3 E8 = art8 || FH && (CE && !CL && !EI || EG && !EI && !GM) ? 0.5*(h+f) : e;

	float3 E1 = art0 && !CE || art2 && !AE ? b : e;
	float3 E3 = art0 && !EG || art6 && !AE ? d : e;
	float3 E5 = art8 && !CE || art2 && !EI ? f : e;
	float3 E7 = art8 && !EG || art6 && !EI ? h : e;


	// subpixel output
	FragColor = vec4(fp.y == 0 ? (fp.x == 0 ? E0 : fp.x == 1 ? E1 : E2) : (fp.y == 1 ? (fp.x == 0 ? E3 : fp.x == 1 ? e : E5) : (fp.x == 0 ? E6 : fp.x == 1 ? E7 : E8)), 1.0);
}