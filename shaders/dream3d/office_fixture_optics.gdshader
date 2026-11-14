shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D lens_dirt : filter_linear, repeat_disable;
uniform vec4 fixture_tint : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform float half_length = 0.55;
uniform float luminous_gain = 0.0;
uniform bool reveals_dirt = false;
uniform float dirt_strength : hint_range(0.0, 1.0) = 1.0;
varying flat vec3 lamp_view;
varying flat vec3 tube_axis;

vec2 project_uv(vec3 point, mat4 projection) {
	vec4 clip = projection * vec4(point, 1.0);
	return clip.xy / max(clip.w, 0.001) * 0.5 + 0.5;
}

void vertex() {
	mat4 local_to_view = VIEW_MATRIX * MODEL_MATRIX;
	lamp_view = local_to_view[3].xyz;
	tube_axis = normalize(local_to_view[0].xyz);
	vec2 middle = project_uv(lamp_view, PROJECTION_MATRIX);
	vec2 end = project_uv(lamp_view + tube_axis * half_length, PROJECTION_MATRIX);
	vec2 start = project_uv(lamp_view - tube_axis * half_length, PROJECTION_MATRIX);
	float radius = reveals_dirt ? 154.0 : 48.0;
	vec2 extent = max(abs(end - middle), abs(start - middle)) + vec2(radius) * (VIEWPORT_SIZE.y / 360.0) / VIEWPORT_SIZE;
	POSITION = vec4((middle + VERTEX.xy * extent) * 2.0 - 1.0, 1.0, 1.0);
	if (lamp_view.z > -0.15 || luminous_gain <= 0.001) {
		POSITION = vec4(2.0, 2.0, 1.0, 1.0);
	}
}

float visible_piece(vec3 point, mat4 projection, mat4 inverse_projection) {
	vec2 uv = project_uv(point, projection);
	vec2 frame = min(uv, 1.0 - uv);
	float edge = smoothstep(0.0, 0.047, min(frame.x, frame.y));
	vec4 surface = inverse_projection * vec4(uv * 2.0 - 1.0, texture(scene_depth, uv).r, 1.0);
	return edge * (1.0 - smoothstep(0.028, 0.105, surface.z / surface.w - point.z));
}

void fragment() {
	vec3 side = tube_axis * half_length * 0.72;
	float visibility = (
		visible_piece(lamp_view - side, PROJECTION_MATRIX, INV_PROJECTION_MATRIX)
		+ 2.0 * visible_piece(lamp_view, PROJECTION_MATRIX, INV_PROJECTION_MATRIX)
		+ visible_piece(lamp_view + side, PROJECTION_MATRIX, INV_PROJECTION_MATRIX)
	) * 0.25;
	if (visibility <= 0.001) {
		discard;
	}

	vec2 logical_size = VIEWPORT_SIZE * (360.0 / VIEWPORT_SIZE.y);
	vec2 start = project_uv(lamp_view - tube_axis * half_length, PROJECTION_MATRIX) * logical_size;
	vec2 end = project_uv(lamp_view + tube_axis * half_length, PROJECTION_MATRIX) * logical_size;
	vec2 line = end - start;
	vec2 delta = SCREEN_UV * logical_size - start;
	delta -= line * clamp(dot(delta, line) / max(dot(line, line), 0.001), 0.0, 1.0);
	float d2 = dot(delta, delta);
	float halo = 0.28 * exp2(-d2 / 8.0) + 0.098 * exp2(-d2 / 54.0) + 0.039 * exp2(-d2 / 230.0);
	float dirt = 0.0;
	if (reveals_dirt) {
		float veil = 0.21 * exp2(-d2 / 1480.0) + 0.13 * exp2(-d2 / 8500.0) + 0.032 * exp2(-d2 / 23200.0);
		veil *= 1.0 - smoothstep(106.0, 153.0, sqrt(d2));
		dirt = min(0.050, texture(lens_dirt, SCREEN_UV).r * veil * 0.67 * luminous_gain * visibility) * dirt_strength;
	}
	ALBEDO = fixture_tint.rgb;
	ALPHA = halo * luminous_gain * visibility + dirt;
}
