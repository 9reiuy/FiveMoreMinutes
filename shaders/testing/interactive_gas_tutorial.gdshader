shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never;
#include "res://shaders/testing/interactive_gas_tutorial_vertex.gdshaderinc"

// All expanded contours draw before ALL white fills. Overlapping fills erase
// their shared contours, leaving ink only outside the combined silhouette.
void fragment() {
	if (dissolved_fragment()) discard;
	ALBEDO=vec3(1.0);
	ALPHA=1.0;
}
