shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform sampler2D detail_atlas : source_color, filter_nearest, repeat_disable;
void fragment() {
	vec4 ink = texture(detail_atlas, UV);
	if (ink.a < 0.5) { discard; }
	ALBEDO = ink.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
