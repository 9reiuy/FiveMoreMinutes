shader_type fog;

uniform float density = 0.050;

void fog() {
	vec2 offset = UVW.xz * 2.0 - 1.0;
	float height = clamp(UVW.y, 0.0, 1.0);
	vec2 width = mix(vec2(0.97, 0.92), vec2(0.60, 0.39), height);
	float cross_section = 1.0 - smoothstep(0.24, 1.0, length(offset / width));
	float near_floor = smoothstep(0.0, 0.27, height);
	float at_housing = 1.0 - smoothstep(0.83, 1.0, height);
	DENSITY = density * cross_section * near_floor * at_housing;
	ALBEDO = vec3(0.93, 0.96, 1.0);
}
