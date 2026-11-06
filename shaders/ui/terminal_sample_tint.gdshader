shader_type canvas_item;

// Applied only to the settings instances inside the review scene.
// Keep the existing control logic and recolor its blue interface artwork.
void fragment() {
	vec4 source = COLOR;
	float blue_excess = source.b - max(source.r, source.g);
	float is_blue = smoothstep(0.055, 0.19, blue_excess);
	vec3 cold = source.b * vec3(0.56, 0.76, 0.88);
	COLOR = vec4(mix(source.rgb, cold, is_blue), source.a);
}
