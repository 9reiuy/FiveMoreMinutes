class_name BloodAirborneCarrier3D
extends Node3D

## Presentation-only carrier for one BlackBloodEffect's airborne droplets.
## BlackBloodEffect owns all motion, gravity, collision and landing decisions;
## this node only snapshots the current particles into one batched MultiMesh.

const BLOOD_AIRBORNE_SHADER: Shader = preload("res://shaders/dream3d/blood_airborne_semantic.gdshader")

var source_effect_ref: WeakRef
var world_ref: WeakRef
var camera: Camera3D
var source_room_id: int = -1
# The owning Dream world supplies the formal gameplay-to-world scale during
# configure().  Keep an inert fallback for teardown/debug frames rather than
# introducing a Blood-specific pixel scale here.
var pixels_per_world_cell: float = 1.0
var floor_world_y: float = 0.0
var multi_instance: MultiMeshInstance3D
var multi_mesh: MultiMesh
var configured := false
var cleanup_queued := false


func configure(
	effect: Node,
	world: Node,
	room_id: int,
	world_camera: Camera3D,
	gameplay_to_world_scale: float,
	ground_y: float
) -> void:
	if effect == null or world == null:
		return
	source_effect_ref = weakref(effect)
	world_ref = weakref(world)
	camera = world_camera
	source_room_id = room_id
	pixels_per_world_cell = maxf(gameplay_to_world_scale, 0.001)
	floor_world_y = ground_y
	top_level = true
	global_transform = Transform3D.IDENTITY
	_create_multimesh()
	configured = multi_instance != null and multi_mesh != null
	if configured:
		set_process(true)
		sync_from_effect(effect)


func _create_multimesh() -> void:
	multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = false
	var quad := QuadMesh.new()
	# Keep a droplet close to the existing 2x2 gameplay blood pixel.  The
	# conversion is supplied by the formal world scale, never guessed per blood.
	quad.size = Vector2.ONE * (2.0 / pixels_per_world_cell)
	var material := ShaderMaterial.new()
	material.shader = BLOOD_AIRBORNE_SHADER
	quad.material = material
	multi_mesh.mesh = quad
	multi_mesh.instance_count = 0
	multi_instance = MultiMeshInstance3D.new()
	multi_instance.name = "AirborneBloodMultiMesh"
	multi_instance.multimesh = multi_mesh
	multi_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multi_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	multi_instance.visible = false
	add_child(multi_instance)


func _process(_delta: float) -> void:
	if not configured:
		return
	var effect := _source_effect()
	var world := _world()
	if effect == null or world == null or effect.is_queued_for_deletion():
		_cleanup()
		return
	if not effect.is_inside_tree() or not effect.visible:
		_cleanup()
		return
	if world.has_method("get_current_room_id") and int(world.call("get_current_room_id")) != source_room_id:
		_cleanup()
		return
	# BlackBloodEffect pushes a fresh snapshot after its simulation step. Keep
	# this callback as a lifetime watchdog, not a second per-particle upload.
	var sink_ref: Variant = effect.get("_airborne_visual_sink_ref")
	if sink_ref is WeakRef and sink_ref.get_ref() == self:
		return
	sync_from_effect(effect)


func sync_from_effect(effect: Node = null) -> void:
	if not configured or cleanup_queued:
		return
	if effect != null and is_instance_valid(effect):
		source_effect_ref = weakref(effect)
	var source := _source_effect()
	var world := _world()
	if source == null or world == null or not source.has_method("get_airborne_visual_snapshot"):
		_cleanup()
		return
	var snapshot_variant: Variant = source.call("get_airborne_visual_snapshot")
	if not snapshot_variant is Array:
		_cleanup()
		return
	var snapshot: Array = snapshot_variant
	if snapshot.is_empty():
		multi_instance.visible = false
		set_process(false)
		if source.has_method("unbind_airborne_visual_sink"):
			source.call("unbind_airborne_visual_sink", self)
		_cleanup()
		return
	# Landing used to reallocate the GPU buffer whenever one droplet vanished.
	# Retain bounded capacity for this short-lived carrier; visible_count keeps
	# every surviving droplet and hides all unused slots without changing motion.
	if multi_mesh.instance_count < snapshot.size():
		var capacity := maxi(8, multi_mesh.instance_count)
		while capacity < snapshot.size(): capacity *= 2
		multi_mesh.instance_count = capacity
	multi_mesh.visible_instance_count = snapshot.size()
	var camera_basis := Basis.IDENTITY
	if camera != null and is_instance_valid(camera):
		camera_basis = camera.global_basis.orthonormalized()
	for index in snapshot.size():
		var particle_variant: Variant = snapshot[index]
		if not particle_variant is Dictionary:
			_hide_instance(index)
			continue
		var particle: Dictionary = particle_variant
		if not bool(particle.get("visible", true)):
			_hide_instance(index)
			continue
		var local_position: Variant = particle.get("position", Vector2.ZERO)
		var local_offset := Vector2.ZERO
		if local_position is Vector2:
			local_offset = local_position
		var gameplay_position := source.global_position + local_offset
		var height_pixels := maxf(float(particle.get("height", 0.0)), 0.0)
		var world_position := _map_gameplay_position(world, gameplay_position, height_pixels)
		var droplet_size := maxf(float(particle.get("size", 2.0)), 1.0)
		var base_scale := droplet_size / 2.0
		var instance_basis := camera_basis

		var vel_2d: Vector2 = particle.get("velocity", Vector2.ZERO)
		var vert_vel: float = float(particle.get("vertical", 0.0))
		var vel_3d := Vector3(vel_2d.x, vert_vel, vel_2d.y) / pixels_per_world_cell

		var cam_right := camera_basis.x
		var cam_up := camera_basis.y
		var cam_normal := camera_basis.z

		var screen_vx := vel_3d.dot(cam_right)
		var screen_vy := vel_3d.dot(cam_up)
		var screen_speed := Vector2(screen_vx, screen_vy).length()

		if screen_speed > 0.08:
			var roll := atan2(screen_vx, screen_vy)
			var rotated_basis := camera_basis.rotated(cam_normal, -roll)
			var stretch := clampf(1.0 + screen_speed * 0.45, 1.0, 3.6)
			instance_basis = rotated_basis.scaled(Vector3(base_scale, base_scale * stretch, base_scale))
		else:
			instance_basis = camera_basis.scaled(Vector3.ONE * base_scale)

		multi_mesh.set_instance_transform(index, Transform3D(instance_basis, world_position))
	multi_instance.visible = true


func _hide_instance(index: int) -> void:
	# A zero-scale transform keeps the fixed MultiMesh slot from rendering an
	# accidental quad at the world origin when a snapshot entry is inactive.
	multi_mesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))


func _map_gameplay_position(world: Node, gameplay_position: Vector2, height_pixels: float) -> Vector3:
	var base_variant: Variant = null
	if world.has_method("get_gameplay_world_position"):
		base_variant = world.call("get_gameplay_world_position", gameplay_position, floor_world_y)
	if base_variant is Vector3:
		var mapped: Vector3 = base_variant
		mapped.y += height_pixels / pixels_per_world_cell
		return mapped
	# Formal 2D->3D scale is passed in by the world.  This fallback only covers
	# a teardown frame where the world adapter is no longer callable.
	return Vector3(
		gameplay_position.x / pixels_per_world_cell,
		floor_world_y + height_pixels / pixels_per_world_cell,
		gameplay_position.y / pixels_per_world_cell
	)


func _source_effect() -> Node2D:
	if source_effect_ref == null:
		return null
	var source: Variant = source_effect_ref.get_ref()
	return source as Node2D if source is Node2D and is_instance_valid(source) else null


func _world() -> Node:
	if world_ref == null:
		return null
	var world: Variant = world_ref.get_ref()
	return world if world is Node and is_instance_valid(world) else null


func _cleanup() -> void:
	if cleanup_queued:
		return
	cleanup_queued = true
	set_process(false)
	visible = false
	var source := _source_effect()
	if source != null and source.has_method("unbind_airborne_visual_sink"):
		source.call("unbind_airborne_visual_sink", self)
	if is_inside_tree():
		call_deferred("queue_free")
