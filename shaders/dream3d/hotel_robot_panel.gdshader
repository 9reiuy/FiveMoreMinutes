shader_type spatial;
// Painted front panel for the hotel robot.  The cabinet door is drawn into this
// texture instead of being modelled, so the front stays one flat face.
//
// UVs are derived from local vertex position rather than the BoxMesh UV set:
// the slab is exactly 0.30 x 0.90, so the mapping is explicit and cannot drift
// with mesh/UV conventions.
render_mode blend_mix, depth_draw_always, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D panel_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.12;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.55;
uniform vec2 panel_size = vec2(0.300, 0.900);

varying vec2 panel_uv;

void vertex() {
	// v = 0 at the top of the slab, matching the image's first row.
	panel_uv = vec2(
		VERTEX.x / panel_size.x + 0.5,
		0.5 - VERTEX.y / panel_size.y
	);
}

void fragment() {
	ALBEDO = texture(panel_texture, panel_uv).rgb * tint.rgb;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	SPECULAR = 0.35;
}
