vec4 HSM_TextureOffset(in sampler2D in_sampler, vec2 in_coord, vec2 pixel_offset, vec2 texture_size)
{
	vec2 uv_offset = pixel_offset / params.SourceSize.xy;
	return texture(in_sampler, in_coord + uv_offset);
}

#pragma parameter HSM_SCALEFX_TITLE	                                "[ --- SMOOTHING - SCALEFX ---- ]:" 0 0 0.01 0.01
#pragma parameter HSM_SCALEFX_ON 	                        "          ScaleFx ON - Must Increase Core Res Sampling" 0 0 1 1
#define HSM_SCALEFX_ON params.HSM_SCALEFX_ON