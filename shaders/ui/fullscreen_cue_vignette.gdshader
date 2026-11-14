shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.75, 1.55);
	float edge = smoothstep(0.18, 0.91, length(p));
	vec3 neutral_black = vec3(0.012);
	vec3 tint = mix(neutral_black, vec3(0.24), flash * (1.0 - edge) * 0.55);
	COLOR = vec4(tint, mix(0.12, 0.84, edge) * strength);
}
