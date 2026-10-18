shader_type canvas_item;
render_mode unshaded;

// Enemy ranged windup pixels are an identity marker for the final screen
// palette pass.  Keep the source alpha/shape, but do not let the source art's
// orange highlights or room lighting decide the visible warning colour. Pure
// red is intentional: it remains exact through Compatibility colour conversion.
uniform vec4 semantic_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // #FF0000

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	if (source.a <= 0.001) {
		discard;
	}
	COLOR = vec4(semantic_color.rgb, source.a);
}
