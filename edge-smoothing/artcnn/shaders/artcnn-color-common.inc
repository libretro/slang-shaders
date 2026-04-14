vec4 artcnn_rgb_to_yuva(vec4 rgba)
{
	vec4 yuva = vec4(0.0);

	yuva.x = rgba.r * 0.299 + rgba.g * 0.587 + rgba.b * 0.114;
	yuva.y = rgba.r * -0.169 + rgba.g * -0.331 + rgba.b * 0.5 + 0.5;
	yuva.z = rgba.r * 0.5 + rgba.g * -0.419 + rgba.b * -0.081 + 0.5;
	yuva.w = 1.0;

	return yuva;
}

vec4 artcnn_yuva_to_rgba(vec4 yuva)
{
	vec4 rgba = vec4(0.0);

	rgba.r = yuva.x * 1.0 + yuva.y * 0.0 + yuva.z * 1.4;
	rgba.g = yuva.x * 1.0 + yuva.y * -0.343 + yuva.z * -0.711;
	rgba.b = yuva.x * 1.0 + yuva.y * 1.765 + yuva.z * 0.0;
	rgba.a = 1.0;

	return rgba;
}
