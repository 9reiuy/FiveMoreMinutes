shader_type spatial;
render_mode cull_disabled;

uniform sampler2D liquid_sheet : source_color, filter_nearest, repeat_disable;
instance uniform vec2 tile;
instance uniform float spread = 1.0;
instance uniform float grid = 80.0;

void fragment() {
	vec2 local = (UV - 0.5) / max(spread, 0.01) + 0.5;
	if (any(lessThan(local, vec2(0.0))) || any(greaterThanEqual(local, vec2(1.0)))) {
		discard;
	}
	vec2 cell = (floor(local * grid) + 0.5) / grid;
	vec4 liquid = texture(liquid_sheet, (tile + cell) * 0.5);
	if (liquid.a < 0.5) { discard; }
	ALBEDO = liquid.rgb;
	EMISSION = liquid.rgb * 0.16;
	ROUGHNESS = 0.46;
	SPECULAR = 0.28;
}
