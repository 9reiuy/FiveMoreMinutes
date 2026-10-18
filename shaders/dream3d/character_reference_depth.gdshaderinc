// Colour stays on the camera-facing capture. Only its spatial reference changes.
// Mode 0 preserves all existing non-character carriers.
uniform bool reference_depth_enabled = false;
uniform vec3 reference_plane_origin = vec3(0.0);
uniform vec3 reference_plane_normal = vec3(0.0, 0.0, 1.0);

vec3 reference_view_position(vec3 colour_view_position, mat4 inverse_view, mat4 view) {
	if (!reference_depth_enabled) { return colour_view_position; }
	vec3 eye = inverse_view[3].xyz;
	vec3 colour_world = (inverse_view * vec4(colour_view_position, 1.0)).xyz;
	vec3 ray = colour_world - eye;
	float divisor = dot(reference_plane_normal, ray);
	if (abs(divisor) < 0.00001) { discard; }
	float distance_ratio = dot(reference_plane_normal, reference_plane_origin - eye) / divisor;
	if (distance_ratio <= 0.0) { discard; }
	return (view * vec4(eye + ray * distance_ratio, 1.0)).xyz;
}

float reference_fragment_depth(vec3 reference_view_position_value, float original_depth, mat4 projection) {
	if (!reference_depth_enabled) { return original_depth; }
	vec4 clip = projection * vec4(reference_view_position_value, 1.0);
	float depth = clip.z / clip.w;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		depth = depth * 0.5 + 0.5;
	#endif
	return depth;
}
