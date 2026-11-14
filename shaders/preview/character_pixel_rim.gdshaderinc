// Sample-only: exposed source texels, lit by actual 3D lights and shadows.
// The opaque silhouette and the ordinary character NORMAL stay unchanged.
uniform bool actor_pixel_rim_enabled = true;
uniform float actor_pixel_rim_strength : hint_range(0.0, 8.0) = 1.8;
uniform float actor_pixel_rim_width : hint_range(0.5, 2.0) = 1.0;
uniform float actor_pixel_rim_backscatter : hint_range(0.0, 1.0) = 0.4;
uniform bool actor_pixel_rim_has_other_capture = false;
uniform sampler2D actor_pixel_rim_other_capture : filter_nearest, repeat_disable;
varying vec4 actor_pixel_rim_sides;

float actor_pixel_rim_coverage(vec2 uv) {
	float a = texture(capture_texture,uv).a;
	if (actor_pixel_rim_has_other_capture) a = max(a,texture(actor_pixel_rim_other_capture,uv).a);
	return step(0.05,a);
}

vec4 actor_pixel_rim_fragment(vec2 uv, float alpha) {
	if (!actor_pixel_rim_enabled || alpha < 0.05 || texture(capture_texture,uv).a < 0.05 || smoke_silhouette || hurt_flash_amount > 0.5 || enemy_rim_enabled) {
		return vec4(0.0);
	}
	vec2 step_uv = actor_pixel_rim_width / vec2(textureSize(capture_texture, 0));
	// L/R/top/bottom. Keeping the four exposures avoids cancelled gradients on
	// one-texel fingers, loose hair and thin weapon barrels.
	return vec4(
		1.0 - actor_pixel_rim_coverage(uv - vec2(step_uv.x, 0.0)),
		1.0 - actor_pixel_rim_coverage(uv + vec2(step_uv.x, 0.0)),
		1.0 - actor_pixel_rim_coverage(uv - vec2(0.0, step_uv.y)),
		1.0 - actor_pixel_rim_coverage(uv + vec2(0.0, step_uv.y))
	);
}

vec3 actor_pixel_rim_light(vec4 sides, vec3 light, vec3 normal, vec3 color, float attenuation) {
	float edge = max(max(sides.x, sides.y), max(sides.z, sides.w));
	float facing = max(
		max(sides.x * max(-light.x, 0.0), sides.y * max(light.x, 0.0)),
		max(sides.z * max(light.y, 0.0), sides.w * max(-light.y, 0.0))
	);
	float wrap = edge * max(-dot(normal, light), 0.0) * actor_pixel_rim_backscatter;
	float response = pow(max(facing, wrap), 1.25);
	// An independent lit highlight keeps black ink from swallowing the rim.
	// ATTENUATION retains real distance, cone and shadow-map occlusion. No emission.
	return color * attenuation * (response * actor_pixel_rim_strength / PI);
}
