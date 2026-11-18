shader_type spatial;
render_mode unshaded, fog_disabled;
#include "res://shaders/testing/interactive_gas_tutorial_vertex.gdshaderinc"
void fragment() {
	if (dissolved_fragment()) discard;
	ALBEDO=vec3(1.0);
}
