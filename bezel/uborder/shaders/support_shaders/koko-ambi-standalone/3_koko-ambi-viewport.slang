#version 450

// Released under: See LICENSE.txt

layout(push_constant) uniform Push {
	mat4 MVP;
	vec4 SourceSize;
	vec4 FinalViewportSize;
} params;

layout(std140, set = 0, binding = 0) uniform UBO {
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vViewportCoords;
layout(location = 1) out vec2 vContentCoords;

vec2 zoom(vec2 in_coords, float zoom_factor) {
   float off = 1.0/(zoom_factor*2.0) - 0.5;
   return (in_coords/zoom_factor)-off;
}

float zoom1D(float in_coord, float zoom_factor) {
   float off = 1.0/(zoom_factor*2.0) - 0.5;
   return (in_coord/zoom_factor)-off;
}
vec2 get_scaled_coords_aspect(vec2 pTexCoord, vec4 destsize, float in_aspect , bool is_rotated){
	float scale_x = 1.0;
	float scale_y = 1.0;
	float offset_x = 0.0 ;
	float offset_y = 0.0 ;
	if (is_rotated) {
		scale_y = destsize.x/(destsize.y / in_aspect );
		offset_y = (0.5 * scale_y ) - 0.5 ;
	} else {
		//to fit width, use this:
			scale_x = destsize.x/(destsize.y * in_aspect);
			offset_x = (0.5 * scale_x ) - 0.5 ;
			
		//to fit height, use this:
			//scale_y = destsize.y/(destsize.x / in_aspect);
			//offset_y = (0.5 * scale_y ) - 0.5 ;
	}

	vec2 scale_coord=vec2(pTexCoord.x*scale_x - offset_x , pTexCoord.y*scale_y - offset_y);
	return scale_coord;
}

#define ASPECT 1.333333
void main() {
	
	gl_Position = global.MVP * Position;
	vViewportCoords = TexCoord;
	vContentCoords = get_scaled_coords_aspect(TexCoord,  params.FinalViewportSize, ASPECT, false);
	vContentCoords = zoom(vContentCoords, 0.8);
	//vViewportCoords.x = zoom1D(vViewportCoords.y, 1/ASPECT);
}

#pragma stage fragment
layout(location = 0) in vec2 vViewportCoords;
layout(location = 1) in vec2 vContentCoords;

layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Original;
layout(set = 0, binding = 2) uniform sampler2D Source;


void main() {
	vec3 pixel_out;
	if (vContentCoords.x < 0.0 || vContentCoords.x > 1.0 || vContentCoords.y < 0.0 || vContentCoords.y > 1.0)
		pixel_out = texture(Source, vViewportCoords).rgb; //Ambilight
			else
		pixel_out = texture(Original, vContentCoords).rgb; //Content 
		
	FragColor = vec4(pixel_out, 1.0);
}
 
  
