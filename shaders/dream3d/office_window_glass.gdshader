shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
#include "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
void vertex() { architecture_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (architecture_cutaway && architecture_visibility(architecture_world) < 0.5) { discard; }
	ALBEDO = vec3(.55, .65, .63);
	ROUGHNESS = .8;
	SPECULAR = .05;
	ALPHA = .16;
}
