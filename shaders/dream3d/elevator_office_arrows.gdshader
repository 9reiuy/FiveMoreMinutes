shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec4 dormant_color : source_color = vec4(0.095, 0.14, 0.175, 1.0);
uniform vec4 pulse_color : source_color = vec4(0.67, 0.82, 0.90, 1.0);
instance uniform vec3 arrow_levels = vec3(0.0);

void fragment() {
	vec2 texel = min(floor(UV * vec2(17.0, 15.0)), vec2(16.0, 14.0));
	float rise = floor(abs(texel.x - 8.0) / 2.5);
	float stroke = mod(texel.y, 5.0) - rise;
	if (stroke < 0.0 || stroke >= 2.0) {
		discard;
	}
	int row = int(floor(texel.y / 5.0));
	ALBEDO = mix(dormant_color.rgb, pulse_color.rgb, arrow_levels[row]);
}
