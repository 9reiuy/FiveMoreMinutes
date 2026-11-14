shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/ui/tutorial_control_hint_reveal.gdshaderinc"

varying float panel_x;

void vertex() {
	panel_x = VERTEX.x + 8.0;
}

void fragment() {
	COLOR.a *= tutorial_hint_reveal(panel_x);
}
