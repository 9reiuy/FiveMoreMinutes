extends CompositorEffect
## Runs on the sample camera's lit opaque colour before the transparent carriers.
const ROOM_DARK_RGB := Vector3(25.0, 29.0, 46.0)
const ROOM_LIGHT_RGB := Vector3(255.0, 225.0, 232.0)
const COMPUTE := """
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D scene_color;
layout(set = 0, binding = 1) uniform sampler2D scene_depth;
layout(set = 0, binding = 2) uniform sampler2D scene_normals;
struct WindowProjection {
	vec4 depth;
	vec4 across;
};
layout(set = 0, binding = 3, std430) readonly buffer WindowProjections {
	WindowProjection panes[];
} windows;
layout(push_constant, std430) uniform Parameters {
	vec4 display_options;
	mat4 map_from_clip;
} params;

const float LIGHT_CUT = 0.0395;

float ordered_threshold(ivec2 pixel, int pitch) {
	// Match the 4x4 ranks in the sample's ink_points shader include.
	const int ranks[16] = int[16](
		0,  8,  2, 10,
		12, 4, 14,  6,
		3, 11,  1,  9,
		15, 7, 13,  5
	);
	ivec2 cell = (pixel / pitch) % 4;
	return (float(ranks[cell.y * 4 + cell.x]) + 0.5) / 16.0;
}

vec3 linear_ink(vec3 bytes) {
	vec3 srgb = bytes / 255.0;
	return mix(srgb / 12.92, pow((srgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), srgb));
}

float window_ink_gain(ivec2 pixel, ivec2 size) {
	vec2 ndc = ((vec2(pixel) + 0.5) / vec2(size)) * 2.0 - 1.0;
	float depth = texelFetch(scene_depth, pixel, 0).r;
	vec4 projected = params.map_from_clip * vec4(ndc, depth, 1.0);
	vec3 ground = vec3(projected.xz / projected.w, 1.0);
	float gain = 1.0;
	for (int i = 0; i < int(params.display_options.z); i++) {
		WindowProjection pane = windows.panes[i];
		float distance = dot(pane.depth.xyz, ground);
		if (distance < -0.04 || distance > 1.55) continue;
		float across = abs(dot(pane.across.xyz, ground));
		float footprint = (1.0 - smoothstep(pane.across.w, pane.across.w + 0.46, across))
			* (1.0 - smoothstep(1.02, 1.55, distance));
		gain = min(gain, 1.0 - 0.82 * smoothstep(0.14, 0.91, distance) * footprint);
	}
	return gain;
}

bool silhouette(float center, float neighbor, float opposite) {
	// Reversed depth changes smoothly on a plane. A discontinuity is
	// drawn on its near side only, keeping the line one sample wide.
	return center - neighbor > max(center * 0.006, 2.0 * abs(center - opposite));
}

bool structure_edge(ivec2 pixel, ivec2 size, vec3 packed_normal) {
	float center = texelFetch(scene_depth, pixel, 0).r;
	if (center < params.display_options.x) return false;
	ivec2 right = min(pixel + ivec2(1, 0), size - 1);
	ivec2 down = min(pixel + ivec2(0, 1), size - 1);
	float r = texelFetch(scene_depth, right, 0).r;
	float d = texelFetch(scene_depth, down, 0).r;
	float l = texelFetch(scene_depth, max(pixel - ivec2(1, 0), 0), 0).r;
	float u = texelFetch(scene_depth, max(pixel - ivec2(0, 1), 0), 0).r;
	if (silhouette(center, r, l) || silhouette(center, l, r)
			|| silhouette(center, d, u) || silhouette(center, u, d)) return true;

	// Only trace sharp folds. Check one side so two touching faces
	// contribute a single line, even when both faces have the same ink.
	vec3 normal = normalize(packed_normal * 2.0 - 1.0);
	vec3 normal_r = normalize(texelFetch(scene_normals, right, 0).xyz * 2.0 - 1.0);
	vec3 normal_d = normalize(texelFetch(scene_normals, down, 0).xyz * 2.0 - 1.0);
	float fold_gap = center * 0.009;
	return (abs(center - r) < fold_gap && dot(normal, normal_r) < 0.70)
		|| (abs(center - d) < fold_gap && dot(normal, normal_d) < 0.70);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(scene_color);
	if (any(greaterThanEqual(pixel, size))) return;
	vec4 source = imageLoad(scene_color, pixel);
	float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec4 surface = texelFetch(scene_normals, pixel, 0);
	// Forward+ uses the high half of the roughness channel for dynamic surfaces.
	// Sample marks reserve codes for floor ink, visible city and unit surfaces.
	int material_tag = int(round(min(surface.a, 1.0 - surface.a) * 255.0));
	bool own_wall = material_tag == 124;
	bool city_wall = own_wall || material_tag == 125;
	bool city = city_wall || material_tag == 123;
	bool floor_join = material_tag == 119;
	bool unit_body = material_tag == 121;
	bool unit_face = material_tag == 122;
	bool unit_signal = material_tag >= 116 && material_tag <= 118;
	// The mechanical units already have a whole-model silhouette. Avoid
	// drawing another line around every rotor, bolt and panel in their bodies.
	bool outline = !floor_join && !unit_body && !unit_face && !unit_signal && luma > 0.003 && structure_edge(pixel, size, surface.xyz);
	bool floor_surface = floor_join || material_tag == 120;
	// Matte ground reaches a lower linear value than furniture in window light.
	float light_cut = floor_surface ? 0.0285 : LIGHT_CUT;
	float band = floor_surface ? 0.0024 : 0.003;
	float coverage = smoothstep(light_cut - band, light_cut + band, luma);
	// Solid masses with a short transition at the real light/shadow boundary.
	if (unit_body) coverage = smoothstep(0.058, 0.071, luma);
	if (unit_face) coverage = step(0.45, luma);
	if (unit_signal) {
		float peak = max(source.r, max(source.g, source.b));
		coverage = smoothstep(0.012, material_tag == 118 ? 0.085 : 0.24, peak);
	}
	if (city_wall) {
		// Use the existing facade shading and height haze, with quieter
		// coverage on neighboring buildings so they recede behind our walls.
		coverage = own_wall ? smoothstep(0.009, 0.030, luma) * 0.52
			: smoothstep(0.008, 0.036, luma) * 0.40;
	}
	if (floor_surface && params.display_options.w > 0.5) {
		// Let weak, physically shadowed sky fill resolve to sparse dots.
		coverage = smoothstep(0.019, 0.046, luma);
		if (coverage > 0.0) coverage *= window_ink_gain(pixel, size);
	}
	float ink;
	// Fully masked room surfaces are black in the incoming color buffer.
	if (city && outline) {
		ink = 1.0 - step(LIGHT_CUT, luma);
	} else if (city && !city_wall) {
		ink = 0.0;
	} else if (floor_join) {
		ink = 1.0 - step(0.5, coverage);
	} else if (outline) {
		ink = 1.0 - step(light_cut, luma);
	} else {
		int pitch = max(1, int(round(float(size.y) / 360.0)));
		ink = step(ordered_threshold(pixel, pitch), coverage);
	}
	vec3 color = vec3(ink);
	if (params.display_options.y > 0.5) {
		// Preserve the city's existing line color and separate the facade
		// ink from the warmer indoor palette.
		bool room = !city && luma > 0.0001;
		vec3 dark_ink = room ? linear_ink(ROOM_DARK_RGB) : linear_ink(vec3(5.0, 6.0, 10.0));
		vec3 light_ink = room ? linear_ink(ROOM_LIGHT_RGB) : linear_ink(vec3(156.0, 170.0, 209.0));
		if (city_wall) {
			if (own_wall) dark_ink = linear_ink(vec3(10.0, 14.0, 24.0));
			if (!outline) light_ink = linear_ink(own_wall ? vec3(101.0, 114.0, 142.0) : vec3(72.0, 86.0, 112.0));
		}
		if (material_tag == 116) light_ink = linear_ink(vec3(150.0, 231.0, 249.0)); // Robot status ring.
		if (material_tag == 117) light_ink = linear_ink(vec3(247.0, 87.0, 73.0));   // Drone sensor.
		if (material_tag == 118) light_ink = linear_ink(vec3(221.0, 130.0, 64.0));  // Drone painted markers.
		color = mix(dark_ink, light_ink, ink);
	}
	if (material_tag == 115) color = vec3(1.0); // Native damage flash stays white.
	imageStore(scene_color, pixel, vec4(color, source.a));
}
"""

var _device: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID
var _window_buffer: RID
var _window_projection_data := PackedFloat32Array()
var _uploaded_window_data := PackedFloat32Array()
var _map_from_world := Transform3D.IDENTITY
var _compiled := false
var palette_enabled := false
var window_falloff_enabled := true

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
	access_resolved_depth = true
	needs_normal_roughness = true
	_device = RenderingServer.get_rendering_device()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _shader.is_valid(): _device.free_rid(_shader)
		if _sampler.is_valid(): _device.free_rid(_sampler)
		if _window_buffer.is_valid(): _device.free_rid(_window_buffer)

func configure_window_falloff(world: Node3D, lights: Array[DirectionalLight3D]) -> void:
	_map_from_world = world.global_transform.affine_inverse()
	var data := PackedFloat32Array()
	for light in lights:
		var ray := _map_from_world.basis * -light.global_basis.z
		var horizontal := Vector2(ray.x, ray.z)
		for wall: Node3D in world.wall_root.get_children():
			if not wall.get_meta(&"window_variant", false): continue
			var inward: Vector2 = wall.get_meta(&"window_inward_normal", Vector2.ZERO)
			var approach := inward.dot(horizontal)
			if approach < 0.12 or ray.y >= -0.01: continue
			var position := _map_from_world * wall.global_position
			var center := Vector2(position.x, position.z)
			var tangent := Vector2(-inward.y, inward.x)
			# Project the aperture's depth and width onto the floor along this ray.
			var reach := (float(wall.wall_height) - 0.05) * approach / -ray.y
			var depth := inward / reach
			var across := tangent - inward * (tangent.dot(horizontal) / approach)
			data.append_array(PackedFloat32Array([
				depth.x, depth.y, -depth.dot(center), 0.0,
				across.x, across.y, -across.dot(center), 0.72,
			]))
	_window_projection_data = data

func _render_callback(_callback: int, data: RenderData) -> void:
	if _device == null: return
	if not _compiled:
		_compiled = true
		var source := RDShaderSource.new()
		source.source_compute = COMPUTE.replace("ROOM_DARK_RGB", "vec3%s" % str(ROOM_DARK_RGB)) \
			.replace("ROOM_LIGHT_RGB", "vec3%s" % str(ROOM_LIGHT_RGB))
		var spirv := _device.shader_compile_spirv_from_source(source)
		if not spirv.compile_error_compute.is_empty():
			push_error(spirv.compile_error_compute)
			return
		_shader = _device.shader_create_from_spirv(spirv)
		if _shader.is_valid(): _pipeline = _device.compute_pipeline_create(_shader)
		_sampler = _device.sampler_create(RDSamplerState.new())
	if not _pipeline.is_valid(): return
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null: return
	var size := buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0: return
	if not buffers.has_texture(&"forward_clustered", &"normal_roughness"): return
	var window_data := _window_projection_data
	if not _window_buffer.is_valid() or _uploaded_window_data != window_data:
		if _window_buffer.is_valid(): _device.free_rid(_window_buffer)
		var payload := window_data.to_byte_array()
		if payload.is_empty(): payload.resize(32)
		_window_buffer = _device.storage_buffer_create(payload.size(), payload)
		_uploaded_window_data = window_data
	if not _window_buffer.is_valid(): return
	var scene := data.get_render_scene_data()
	var window_uniform := RDUniform.new()
	window_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	window_uniform.binding = 3
	window_uniform.add_id(_window_buffer)
	for view in buffers.get_view_count():
		# The compositor projection already uses the renderer's reversed depth.
		# Project the limit directly to leave the city backdrop out of the line pass.
		var projection := scene.get_view_projection(view)
		var clip := projection * Vector4(0.0, 0.0, -38.0, 1.0)
		var map_from_clip := Projection(_map_from_world * scene.get_cam_transform()) * projection.inverse()
		var options := PackedFloat32Array([
			clip.z / clip.w, float(palette_enabled), window_data.size() / 8.0, float(window_falloff_enabled),
		])
		for column: Vector4 in [map_from_clip.x, map_from_clip.y, map_from_clip.z, map_from_clip.w]:
			options.append_array(PackedFloat32Array([column.x, column.y, column.z, column.w]))
		var push := options.to_byte_array()
		var color := RDUniform.new()
		color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		color.binding = 0
		color.add_id(buffers.get_color_layer(view))
		var depth := RDUniform.new()
		depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		depth.binding = 1
		depth.add_id(_sampler)
		depth.add_id(buffers.get_depth_layer(view))
		var normals := RDUniform.new()
		normals.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		normals.binding = 2
		normals.add_id(_sampler)
		normals.add_id(buffers.get_texture_slice(&"forward_clustered", &"normal_roughness", view, 0, 1, 1))
		var uniforms := UniformSetCacheRD.get_cache(_shader, 0, [color, depth, normals, window_uniform])
		var commands := _device.compute_list_begin()
		_device.compute_list_bind_compute_pipeline(commands, _pipeline)
		_device.compute_list_bind_uniform_set(commands, uniforms, 0)
		_device.compute_list_set_push_constant(commands, push, push.size())
		_device.compute_list_dispatch(commands, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
		_device.compute_list_end()
