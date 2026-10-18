shader_type canvas_item;
render_mode unshaded;
uniform sampler2D environment_texture : filter_nearest, repeat_disable;
uniform sampler2D reference_texture : filter_nearest, repeat_disable;
uniform sampler2D visibility_texture : filter_nearest, repeat_disable;
uniform bool native_bypass = false;
void fragment() {
	vec4 native = texture(reference_texture, UV);
	vec4 environment = texture(environment_texture, UV);
	float character = step(0.5, texture(visibility_texture, UV).r);
	COLOR = vec4(native_bypass ? native.rgb : mix(environment.rgb, native.rgb, character), 1.0);
}
