// Bounded screen-space pressure fronts. No texture or independent TIME clock.
uniform int air_count = 0;
uniform vec4 air_shape[8];
uniform vec4 air_motion[8];

vec2 explosion_air_displacement(vec2 uv, vec2 pixel_size) {
	vec2 displacement = vec2(0.0);
	vec2 pixel = uv / pixel_size;
	for (int i = 0; i < 8; i++) {
		if (i >= air_count) break;
		vec4 shape = air_shape[i];
		vec4 motion = air_motion[i];
		vec2 delta = pixel - shape.xy;
		float distance_px = length(delta);
		float q = (distance_px - shape.z) / max(shape.w, 1.0);
		if (abs(q) > 3.1) continue;
		vec2 direction = delta / max(distance_px, 0.1);
		float angle = atan(direction.y, direction.x);
		float broad_noise = 0.90 + 0.09 * sin(angle * 7.0 - motion.y * 9.0)
			+ 0.06 * sin(angle * 13.0 + motion.y * 12.0);
		float envelope = exp(-q * q * 0.90) * (1.0 - smoothstep(2.1, 3.1, abs(q)));
		float pressure = sin(q * 2.1) * envelope;
		vec2 tangent = vec2(-direction.y, direction.x);
		displacement += (direction * pressure * broad_noise
			+ tangent * sin(angle * 9.0 - motion.y * 17.0) * envelope * 0.13) * motion.x;
	}
	float magnitude = length(displacement);
	displacement *= min(1.0, 7.0 / max(magnitude, 0.001));
	return displacement * pixel_size;
}
