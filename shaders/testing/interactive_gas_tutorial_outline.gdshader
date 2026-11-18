shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled, blend_mix, depth_draw_never;
#include "res://shaders/testing/interactive_gas_tutorial_vertex.gdshaderinc"
uniform vec4 ink_color : source_color=vec4(.34,.41,.51,1.0);
void fragment() {
	if (dissolved_fragment()) discard;
	ALBEDO=ink_color.rgb;
	ALPHA=1.0;
}
