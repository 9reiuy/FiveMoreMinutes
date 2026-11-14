shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/dream3d/light_boundary_dither.gdshaderinc"

void fragment() {
	// A known light field independent of the deliberately hard albedo seam.
	float incoming = UV.x < 0.25 ? 0.0 : (UV.x < 0.5 ? 0.37 : mix(0.1,0.9,(UV.x-0.5)*2.0));
	vec3 tint = UV.x < 0.375 ? vec3(0.3,0.5,0.7) : vec3(0.7,0.5,0.3);
	COLOR = vec4(tint * edge_light_attenuation(incoming,FRAGCOORD.xy),1.0);
}
