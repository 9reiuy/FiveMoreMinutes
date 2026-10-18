extends Node3D
class_name PhysicalDoor3D

signal door_shattered(door)

## A single logical physical door owns two hinged leaves.  The 2D mirrors stay
## the gameplay collision authority; the rigid leaves only provide real hinge
## inertia/visual motion and are synchronised back to those mirrors.
const CONFIG := preload("res://resources/demo_config.tres")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const MATERIAL: Material = preload("res://materials/dream3d/interiors_a_door_pixel_light_material.tres")
const DOOR_SHADER: Shader = preload("res://shaders/dream3d/interiors_a_door_pixel_light.gdshader")
const DOOR_TEXTURE: Texture2D = preload("res://art/Dream/LoafbrrAssets/Interiors_A/texture/Door/Door_Diffuse_2K_B.png")
const AUTHORED_DOOR_SOURCE_SCENE: PackedScene = preload("res://art/Dream/LoafbrrAssets/Interiors_A/Scenes/Doors/door_b_grp.tscn")
const DEFAULT_WORLD_SCALE: float = 32.0
const LEFT_LEAF_INDEX: int = 0
const RIGHT_LEAF_INDEX: int = 1
static var authored_mesh: Mesh
static var authored_handle_mesh: Mesh
static var authored_handle_transform: Transform3D = Transform3D.IDENTITY
static var _visual_mesh_cache: Dictionary = {}
## Keep only the two actually used fragment shader variants alive, not floor nodes.
## Each burst still owns its original material, geometry and animation.
static var shard_shader_anchors: Dictionary = {}

## Legacy/editor fallback only. Generated doors pass their four-cell width
## explicitly from the authoritative gameplay cell-to-world mapping.
@export var door_width: float = 4.0
@export var door_height: float = 3.0
@export var wall_thickness: float = 0.25
@export var center_clearance: float = 0.04
@export var door_mass: float = 1.0
@export var door_angular_damping: float = 0.25
@export var door_max_angle_degrees: float = 100.0
@export var door_open_collision_angle_degrees: float = 35.0
@export var door_force_to_impulse: float = 0.05
@export var door_min_impact_impulse: float = 0.01
@export var door_max_impact_impulse: float = 24.0
@export var door_max_angular_velocity: float = 12.0
## Walking into / gently pushing a door must not make its mirrored 2D solid
## sweep faster than the player can walk away from it. Combat keeps the full
## angular speed above.
@export var door_passive_max_angular_velocity: float = 1.1
@export var door_impact_accumulation_window: float = 0.08
@export var door_max_accumulated_impulse: float = 32.0
@export var latch_closed_angle_degrees: float = 2.0
@export var latch_velocity_threshold: float = 0.12
@export var hinge_side: String = "left"
@export var door_id: int = -1
@export var locked: bool = false
@export var max_health: float = 100.0
var current_health: float = 100.0
var is_destroyed: bool = false
var is_boss_door: bool = false
var door_style: StringName = &"double"

## Compatibility aliases used by existing gameplay/tests.  They deliberately
## point at the left leaf rather than creating a second logical door.
var hinge_anchor: StaticBody3D
var door_leaf: RigidBody3D
var door_visual: MeshInstance3D
var hinge_joint: HingeJoint3D

var left_anchor: StaticBody3D
var right_anchor: StaticBody3D
var left_leaf: RigidBody3D
var right_leaf: RigidBody3D
var left_visual: MeshInstance3D
var right_visual: MeshInstance3D
var left_handle_visual: MeshInstance3D
var right_handle_visual: MeshInstance3D
var left_hinge_joint: HingeJoint3D
var right_hinge_joint: HingeJoint3D
var leaf_width: float = 0.98
var world_scale: float = DEFAULT_WORLD_SCALE
var latched: bool = true

var _anchors: Array[StaticBody3D] = []
var _leaves: Array[RigidBody3D] = []
var _visuals: Array[MeshInstance3D] = []
var _handle_visuals: Array[MeshInstance3D] = []
var _joints: Array[HingeJoint3D] = []
var _collision_bodies: Array[StaticBody2D] = []
var _collision_shapes: Array[CollisionShape2D] = []
var _last_angles: Array[float] = [0.0, 0.0]
var _swing_signs: Array[float] = [0.0, 0.0]
var _target_hit_times: Dictionary = {}
var _swing_hit_query: PhysicsShapeQueryParameters2D
var _outline_material: ShaderMaterial
var _gameplay_open: bool = false
var _gameplay_collision_requested: bool = true
var _collision_layer_2d: int = 4
var _collision_body_2d: StaticBody2D
var _collision_shape_2d: CollisionShape2D
var _impact_window_left: float = 0.0
var _impact_accumulated_impulse: float = 0.0
var _quiet_time: float = 1.0
var _swing_hits: Dictionary = {}
## Only a deliberate combat impulse may turn a moving leaf into an attack.
## Physics contact and ordinary player/enemy door pushes still open the door.
var _combat_swing_left: Array[float] = [0.0, 0.0]
var _combat_swing_instigator: Array[int] = [0, 0]
var _passive_swing: Array[bool] = [false, false]
var _passive_drive_left: Array[float] = [0.0, 0.0]
var _passive_drive_sign: Array[float] = [0.0, 0.0]
var _material_validation_reported: bool = false


func configure(width: float, height: float, thickness: float, side: String, id: int = -1, style: StringName = &"double") -> void:
	assert(not is_inside_tree(), "Door dimensions must be set before physics registration.")
	door_width = maxf(width, 0.1)
	door_height = maxf(height, 0.1)
	wall_thickness = maxf(thickness, 0.01)
	hinge_side = "right" if side == "right" else "left"
	door_id = id
	door_style = &"single" if style == &"single" else &"double"


func _enter_tree() -> void:
	# Set every local frame before children/joints register with the physics
	# server.  The two leaves share the same logical root and doorway width.
	left_anchor = get_node_or_null("LeftAnchor") as StaticBody3D
	right_anchor = get_node_or_null("RightAnchor") as StaticBody3D
	left_leaf = get_node_or_null("LeftLeaf") as RigidBody3D
	right_leaf = get_node_or_null("RightLeaf") as RigidBody3D
	left_visual = get_node_or_null("LeftLeaf/DoorVisual") as MeshInstance3D
	right_visual = get_node_or_null("RightLeaf/DoorVisual") as MeshInstance3D
	left_handle_visual = get_node_or_null("LeftLeaf/DoorHandleVisual") as MeshInstance3D
	right_handle_visual = get_node_or_null("RightLeaf/DoorHandleVisual") as MeshInstance3D
	# Keep older hand-authored copies of PhysicalDoor3D compatible.  The
	# handle is a visual-only child; it never owns a collider or a hinge.
	if left_handle_visual == null and left_leaf != null:
		left_handle_visual = MeshInstance3D.new()
		left_handle_visual.name = "DoorHandleVisual"
		left_leaf.add_child(left_handle_visual)
	if right_handle_visual == null and right_leaf != null:
		right_handle_visual = MeshInstance3D.new()
		right_handle_visual.name = "DoorHandleVisual"
		right_leaf.add_child(right_handle_visual)
	left_hinge_joint = get_node_or_null("LeftHingeJoint3D") as HingeJoint3D
	right_hinge_joint = get_node_or_null("RightHingeJoint3D") as HingeJoint3D
	_anchors.clear()
	_anchors.append(left_anchor)
	_anchors.append(right_anchor)
	_leaves.clear()
	_leaves.append(left_leaf)
	_leaves.append(right_leaf)
	_visuals.clear()
	_visuals.append(left_visual)
	_visuals.append(right_visual)
	_handle_visuals.clear()
	_handle_visuals.append(left_handle_visual)
	_handle_visuals.append(right_handle_visual)
	_joints.clear()
	_joints.append(left_hinge_joint)
	_joints.append(right_hinge_joint)
	hinge_anchor = left_anchor
	door_leaf = left_leaf
	door_visual = left_visual
	hinge_joint = left_hinge_joint
	leaf_width = maxf(door_width - maxf(center_clearance, 0.0), 0.05) if door_style == &"single" else maxf((door_width - maxf(center_clearance, 0.0)) * 0.5, 0.05)
	for index in range(2):
		_configure_leaf(index)
	if door_style == &"single" and right_leaf != null:
		right_leaf.collision_layer = 0
		right_leaf.collision_mask = 0
		right_visual.visible = false
		right_handle_visual.visible = false
	_last_angles.clear()
	_last_angles.append(0.0)
	_last_angles.append(0.0)
	_swing_signs.clear()
	_swing_signs.append(0.0)
	_swing_signs.append(0.0)
	_validate_leaf_materials()


func _configure_leaf(index: int) -> void:
	if index < 0 or index >= _leaves.size():
		return
	var anchor: StaticBody3D = _anchors[index]
	var leaf: RigidBody3D = _leaves[index]
	var visual: MeshInstance3D = _visuals[index]
	var joint: HingeJoint3D = _joints[index]
	if anchor == null or leaf == null or visual == null or joint == null:
		return
	var side_sign: float = 1.0 if index == 0 else -1.0
	var hinge_x: float = side_sign * door_width * 0.5
	var center_x: float = hinge_x - side_sign * leaf_width * 0.5
	anchor.position = Vector3(hinge_x, door_height * 0.5, 0.0)
	leaf.position = Vector3(center_x, door_height * 0.5, 0.0)
	leaf.rotation = Vector3.ZERO
	joint.position = anchor.position
	joint.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -deg_to_rad(door_max_angle_degrees))
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(door_max_angle_degrees))
	leaf.mass = door_mass
	leaf.gravity_scale = 0.0
	leaf.angular_damp = door_angular_damping
	leaf.freeze = true
	leaf.collision_layer = 8
	leaf.collision_mask = 0
	var collision_shape := leaf.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null:
		var shape := BoxShape3D.new()
		shape.size = Vector3(leaf_width, door_height, wall_thickness)
		collision_shape.shape = shape
	_load_authored_door_parts()
	# The authored Door_B panel puts its handle plate on local +X.  Runtime
	# slot 0 is the +X leaf, so its visual mesh is mirrored around the panel
	# centre to move the hardware to the centre seam.  This is a visual mesh
	# operation only; the RigidBody, CollisionShape and HingeJoint transforms
	# above remain untouched.
	var mirror_geometry: bool = index == LEFT_LEAF_INDEX
	var leaf_mesh: Mesh = _make_visual_mesh(authored_mesh, mirror_geometry)
	var leaf_material: Material = _make_leaf_material(index)
	if authored_mesh != null and leaf_mesh != null:
		visual.mesh = leaf_mesh
		var bounds: AABB = authored_mesh.get_aabb()
		if bounds.size.x > 0.001 and bounds.size.y > 0.001 and bounds.size.z > 0.001:
			visual.scale = Vector3(leaf_width, door_height, wall_thickness) / bounds.size
			visual.position = -(bounds.position + bounds.size * 0.5) * visual.scale
	visual.rotation = Vector3.ZERO
	visual.material_override = leaf_material
	_configure_handle_visual(index, leaf_material, visual.scale)
	if bool(get_meta(&"office_metal_door",false)):
		var window := bool(get_meta(&"office_observation_window",false))
		visual.mesh=preload("res://scripts/dream/office_metal_door_art.gd").panel(leaf_width,door_height,wall_thickness,window)
		visual.scale=Vector3.ONE
		visual.position=Vector3.ZERO
		if window:
			var glass := MeshInstance3D.new()
			glass.name="ObservationGlass"
			var pane := BoxMesh.new()
			pane.size=Vector3(leaf_width*.28,door_height*.24,.025)
			glass.mesh=pane
			glass.position.y=door_height*.18
			glass.material_override=leaf_material.duplicate()
			glass.material_override.set_shader_parameter("metal_glass",true)
			glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visual.add_child(glass)
	preload("res://scripts/dream/solid_shadow_caster_3d.gd").attach(visual)


func _load_authored_door_parts() -> void:
	if authored_mesh != null and authored_handle_mesh != null:
		return
	var source: Node = AUTHORED_DOOR_SOURCE_SCENE.instantiate()
	var source_door: MeshInstance3D = source.get_node_or_null("Door_B_Frame/Door_B_Door") as MeshInstance3D
	if source_door != null:
		if authored_mesh == null:
			authored_mesh = source_door.mesh
		var source_handle: MeshInstance3D = source_door.get_node_or_null("Door_B_Handle") as MeshInstance3D
		if source_handle != null:
			if authored_handle_mesh == null:
				authored_handle_mesh = source_handle.mesh
			authored_handle_transform = source_handle.transform
	source.free()


func _configure_handle_visual(index: int, material: Material, panel_scale: Vector3) -> void:
	if index < 0 or index >= _handle_visuals.size():
		return
	var handle_visual: MeshInstance3D = _handle_visuals[index]
	if handle_visual == null or not is_instance_valid(handle_visual):
		return
	if authored_handle_mesh == null or authored_mesh == null:
		handle_visual.mesh = null
		return
	var mirror_geometry: bool = index == LEFT_LEAF_INDEX
	handle_visual.mesh = _make_visual_mesh(authored_handle_mesh, mirror_geometry)
	handle_visual.scale = panel_scale
	var panel_bounds: AABB = authored_mesh.get_aabb()
	var handle_offset: Vector3 = authored_handle_transform.origin - (panel_bounds.position + panel_bounds.size * 0.5)
	if mirror_geometry:
		handle_offset.x = -handle_offset.x
	handle_visual.position = handle_offset * panel_scale
	handle_visual.rotation = Vector3.ZERO
	handle_visual.material_override = material
	handle_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_visual_mesh(source_mesh: Mesh, mirror_geometry: bool) -> Mesh:
	if source_mesh == null:
		return null
	var cache_key: String = "%s:%s" % [source_mesh.get_instance_id(), "mirror" if mirror_geometry else "uv"]
	var cached: Mesh = _visual_mesh_cache.get(cache_key) as Mesh
	if cached != null and is_instance_valid(cached):
		return cached
	var mirrored_mesh := ArrayMesh.new()
	var source_bounds: AABB = source_mesh.get_aabb()
	for surface_index in range(source_mesh.get_surface_count()):
		var arrays: Array = source_mesh.surface_get_arrays(surface_index).duplicate(true)
		if arrays.size() < Mesh.ARRAY_MAX:
			arrays.resize(Mesh.ARRAY_MAX)
		var vertices: PackedVector3Array = PackedVector3Array()
		if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if mirror_geometry and not vertices.is_empty():
			var mirrored_vertices := PackedVector3Array()
			mirrored_vertices.resize(vertices.size())
			var mirror_x: float = source_bounds.position.x + source_bounds.size.x * 0.5
			for vertex_index in range(vertices.size()):
				var vertex: Vector3 = vertices[vertex_index]
				vertex.x = mirror_x * 2.0 - vertex.x
				mirrored_vertices[vertex_index] = vertex
			arrays[Mesh.ARRAY_VERTEX] = mirrored_vertices
			var normals: PackedVector3Array = PackedVector3Array()
			if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			if mirror_geometry and normals.size() == vertices.size():
				for normal_index in range(normals.size()):
					var normal: Vector3 = normals[normal_index]
					normal.x = -normal.x
					normals[normal_index] = normal
				arrays[Mesh.ARRAY_NORMAL] = normals
			if mirror_geometry and arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
				if tangents.size() == vertices.size() * 4:
					for tangent_index in range(vertices.size()):
						tangents[tangent_index * 4] = -tangents[tangent_index * 4]
						tangents[tangent_index * 4 + 3] = -tangents[tangent_index * 4 + 3]
					arrays[Mesh.ARRAY_TANGENT] = tangents
			if mirror_geometry and not indices.is_empty():
				var mirrored_indices := indices.duplicate()
				for triangle_offset in range(0, mirrored_indices.size(), 3):
					if triangle_offset + 2 < mirrored_indices.size():
						var swap_index: int = mirrored_indices[triangle_offset + 1]
						mirrored_indices[triangle_offset + 1] = mirrored_indices[triangle_offset + 2]
						mirrored_indices[triangle_offset + 2] = swap_index
				arrays[Mesh.ARRAY_INDEX] = mirrored_indices
		var uvs: PackedVector2Array = PackedVector2Array()
		if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
			uvs = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		if not uvs.is_empty():
			arrays[Mesh.ARRAY_TEX_UV2] = _build_uv2_island_bounds(uvs, indices)
		var new_surface: int = mirrored_mesh.get_surface_count()
		mirrored_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var source_surface_material: Material = source_mesh.surface_get_material(surface_index)
		if source_surface_material != null:
			mirrored_mesh.surface_set_material(new_surface, source_surface_material)
	mirrored_mesh.resource_name = "%s_visual" % source_mesh.resource_name if not source_mesh.resource_name.is_empty() else "DoorVisualMesh"
	_visual_mesh_cache[cache_key] = mirrored_mesh
	return mirrored_mesh


func _build_uv2_island_bounds(uvs: PackedVector2Array, indices: PackedInt32Array) -> PackedVector2Array:
	var uv2 := PackedVector2Array()
	uv2.resize(uvs.size())
	for vertex_index in range(uv2.size()):
		uv2[vertex_index] = Vector2.ZERO
	var triangle_count: int = indices.size() / 3 if not indices.is_empty() else uvs.size() / 3
	var vertex_triangles: Array = []
	vertex_triangles.resize(uvs.size())
	for vertex_index in range(vertex_triangles.size()):
		vertex_triangles[vertex_index] = []
	for triangle_build_index in range(triangle_count):
		for corner in range(3):
			var vertex_index: int = int(indices[triangle_build_index * 3 + corner]) if not indices.is_empty() else triangle_build_index * 3 + corner
			if vertex_index >= 0 and vertex_index < vertex_triangles.size():
				(vertex_triangles[vertex_index] as Array).append(triangle_build_index)
	var visited := PackedByteArray()
	visited.resize(triangle_count)
	for seed in range(triangle_count):
		if visited[seed] != 0:
			continue
		var queue: Array[int] = []
		queue.append(seed)
		visited[seed] = 1
		var component: Array[int] = []
		while not queue.is_empty():
			var current_triangle_index: int = queue.pop_back()
			component.append(current_triangle_index)
			for corner in range(3):
				var vertex_index: int = int(indices[current_triangle_index * 3 + corner]) if not indices.is_empty() else current_triangle_index * 3 + corner
				if vertex_index < 0 or vertex_index >= vertex_triangles.size():
					continue
				for connected_variant in (vertex_triangles[vertex_index] as Array):
					var connected: int = int(connected_variant)
					if visited[connected] == 0:
						visited[connected] = 1
						queue.append(connected)
			var u_min: float = INF
			var u_max: float = -INF
			for component_triangle_index in component:
				for corner in range(3):
					var vertex_index: int = int(indices[component_triangle_index * 3 + corner]) if not indices.is_empty() else component_triangle_index * 3 + corner
					if vertex_index < 0 or vertex_index >= uvs.size():
						continue
					u_min = minf(u_min, uvs[vertex_index].x)
					u_max = maxf(u_max, uvs[vertex_index].x)
			for component_triangle_index in component:
				for corner in range(3):
					var vertex_index: int = int(indices[component_triangle_index * 3 + corner]) if not indices.is_empty() else component_triangle_index * 3 + corner
					if vertex_index >= 0 and vertex_index < uv2.size():
						uv2[vertex_index] = Vector2(u_min, u_max)
	return uv2


func _make_leaf_material(index: int) -> Material:
	var source_material: ShaderMaterial = MATERIAL as ShaderMaterial
	# Build a fresh ShaderMaterial instead of mutating the scene's shared
	# material resource.  The shader and texture remain shared immutable data,
	# while each leaf owns its mirror_u parameter storage.
	var leaf_material: ShaderMaterial = ShaderMaterial.new()
	leaf_material.shader = source_material.shader if source_material != null else DOOR_SHADER
	if source_material != null:
		leaf_material.render_priority = source_material.render_priority
	var albedo_texture: Variant = DOOR_TEXTURE
	if source_material != null:
		var configured_texture: Variant = source_material.get_shader_parameter("albedo_texture")
		if configured_texture != null:
			albedo_texture = configured_texture
	leaf_material.set_shader_parameter("albedo_texture", albedo_texture)
	leaf_material.resource_local_to_scene = true
	# Slot 0 is the runtime +X leaf and is the one whose authored hardware is
	# reflected visually into the centre seam.  Its texture must be mirrored as
	# well so the panel details stay attached to that reflected geometry.  Slot
	# 1 keeps the authored geometry/UV orientation.  The mapping is deliberately
	# local to these leaf slots and never depends on the door's world rotation.
	leaf_material.set_shader_parameter("mirror_u", index == LEFT_LEAF_INDEX)
	leaf_material.set_shader_parameter("mirror_u_use_uv2", true)
	leaf_material.set_shader_parameter("surface_tint", get_meta(&"surface_tint", Color.WHITE))
	leaf_material.set_shader_parameter("pixel_wood", preload("res://scripts/dream/office_pixel_materials.gd").swatch("wood"))
	leaf_material.set_shader_parameter("office_metal",bool(get_meta(&"office_metal_door",false)))
	leaf_material.set_shader_parameter("observation_window",bool(get_meta(&"office_observation_window",false)))
	leaf_material.set_shader_parameter("panel_size",Vector2(leaf_width,door_height))
	return leaf_material


func set_architectural_cutaway(enabled: bool, height: float) -> void:
	for index in range(_leaves.size()):
		var leaf: RigidBody3D = _leaves[index]
		if not is_instance_valid(leaf):
			continue
		# Single doors keep a dormant second rigid body for compatibility.  It
		# has no panel, and must not acquire a second black cut surface.
		if door_style == &"single" and index > 0:
			continue
		var cap := leaf.get_node_or_null("ArchitecturalCutSurface") as MeshInstance3D
		if enabled and cap == null:
			cap = preload("res://scripts/dream/architecture_slice_cap.gd").make(leaf_width, wall_thickness, height)
			leaf.add_child(cap)
		if cap != null:
			# The leaf origin is at mid-height. Its cap must lie on the same
			# floor-relative 30% slice plane as neighbouring wall segments, not
			# halfway up the door panel.
			cap.position.y = height * 0.30 - door_height * 0.5
			cap.visible = enabled and not is_destroyed and _visuals[index].visible
	for visual in _visuals:
		if is_instance_valid(visual) and visual.material_override is ShaderMaterial:
			visual.material_override.set_shader_parameter("architecture_cutaway", enabled)
			visual.material_override.set_shader_parameter("architecture_wall_height", height)
			var glass := visual.get_node_or_null("ObservationGlass") as MeshInstance3D
			if glass != null:
				glass.material_override.set_shader_parameter("architecture_cutaway",enabled)
				glass.material_override.set_shader_parameter("architecture_wall_height",height)


func _validate_leaf_materials() -> void:
	if _visuals.size() < 2:
		return
	var left: MeshInstance3D = _visuals[LEFT_LEAF_INDEX]
	var right: MeshInstance3D = _visuals[RIGHT_LEAF_INDEX]
	if left == null or right == null or not is_instance_valid(left) or not is_instance_valid(right):
		return
	var left_material: Material = left.material_override
	var right_material: Material = right.material_override
	if left_material == null or right_material == null:
		if not _material_validation_reported:
			push_warning("PhysicalDoor3D leaves are missing their per-leaf material override.")
			_material_validation_reported = true
		return
	var left_instance_id: int = left_material.get_instance_id()
	var right_instance_id: int = right_material.get_instance_id()
	var left_shader: ShaderMaterial = left_material as ShaderMaterial
	var right_shader: ShaderMaterial = right_material as ShaderMaterial
	var left_mirror: bool = false
	var right_mirror: bool = false
	if left_shader != null:
		left_mirror = bool(left_shader.get_shader_parameter("mirror_u"))
	if right_shader != null:
		right_mirror = bool(right_shader.get_shader_parameter("mirror_u"))
	set_meta(&"leaf_material_instance_ids", [left_instance_id, right_instance_id])
	set_meta(&"leaf_mirror_u", [left_mirror, right_mirror])
	var valid: bool = (
		left_instance_id != right_instance_id
		and left_shader != null
		and right_shader != null
		and left_mirror
		and not right_mirror
	)
	if not valid and not _material_validation_reported:
		push_warning("PhysicalDoor3D per-leaf mirror validation failed (slot0=true, slot1=false).")
		_material_validation_reported = true


func _ready() -> void:
	add_to_group(&"physical_door_3d")


func configure_gameplay_collision(root: Node2D, pixels_per_unit: float = DEFAULT_WORLD_SCALE, layer: int = 4) -> void:
	world_scale = maxf(pixels_per_unit, 0.001)
	_collision_layer_2d = layer
	for body in _collision_bodies:
		if is_instance_valid(body):
			body.queue_free()
	_collision_bodies.clear()
	_collision_shapes.clear()
	if root == null:
		return
	for index in range(1 if door_style == &"single" else 2):
		var body := StaticBody2D.new()
		body.name = "DoorLeafCollision2D_%d_%s" % [door_id, "L" if index == 0 else "R"]
		body.collision_layer = layer
		body.collision_mask = 0
		body.set_meta(&"physical_door", true)
		body.set_meta(&"generated_door_id", door_id)
		body.set_meta(&"generated_door_leaf_index", index)
		body.set_meta(&"physical_door_instance_id", get_instance_id())
		body.set_meta(&"physical_door_node", weakref(self))
		body.add_to_group(&"damageable_props")
		body.add_to_group(&"physical_doors")
		body.set_script(load("res://scripts/dream/breakable_door_collider_2d.gd"))
		body.set("door_owner", self)
		body.set("leaf_index", index)
		var collision_shape := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(leaf_width, wall_thickness) * world_scale
		collision_shape.shape = shape
		body.add_child(collision_shape)
		root.add_child(body)
		_collision_bodies.append(body)
		_collision_shapes.append(collision_shape)
	_collision_body_2d = _collision_bodies[0] if not _collision_bodies.is_empty() else null
	_collision_shape_2d = _collision_shapes[0] if not _collision_shapes.is_empty() else null
	_sync_gameplay_collision()


func set_gameplay_collision_enabled(enabled: bool) -> void:
	_gameplay_collision_requested = enabled
	if is_destroyed:
		return
	for body in _collision_bodies:
		if is_instance_valid(body):
			body.set_deferred("collision_layer", _collision_layer_2d if enabled else 0)


func wake_door_physics() -> void:
	if not is_physics_processing():
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	_impact_window_left = maxf(_impact_window_left - delta, 0.0)
	if _impact_window_left <= 0.0:
		_impact_accumulated_impulse = 0.0
	var max_angle: float = 0.0
	var any_swing: bool = false
	for index in range(_leaves.size()):
		_combat_swing_left[index] = maxf(_combat_swing_left[index] - delta, 0.0)
		_passive_drive_left[index] = maxf(_passive_drive_left[index] - delta, 0.0)
		var leaf: RigidBody3D = _leaves[index]
		if leaf == null or not is_instance_valid(leaf):
			continue
		var omega: float = leaf.angular_velocity.y
		# The hinge solver damps a one-frame gentle impulse heavily. Maintain a
		# modest angular speed briefly so one deliberate E push opens a doorway,
		# while its 2D solid never sweeps at combat-impulse speed.
		if _passive_swing[index] and _passive_drive_left[index] > 0.0 and absf(leaf.rotation.y) < deg_to_rad(door_max_angle_degrees - 5.0):
			omega = _passive_drive_sign[index] * door_passive_max_angular_velocity
			leaf.angular_velocity.y = omega
		var speed_limit: float = door_passive_max_angular_velocity if _passive_swing[index] else door_max_angular_velocity
		if absf(omega) > speed_limit:
			omega = clampf(omega, -speed_limit, speed_limit)
			leaf.angular_velocity.y = omega
		if _passive_swing[index] and _passive_leaf_sweeps_into_player(index, omega):
			omega = 0.0
			leaf.angular_velocity.y = 0.0
			_passive_drive_left[index] = 0.0
		var angle: float = wrapf(leaf.rotation.y, -PI, PI)
		max_angle = maxf(max_angle, absf(angle))
		if absf(omega) > 0.1:
			any_swing = true
			if _quiet_time > 0.25 or signf(omega) != _swing_signs[index]:
				_swing_hits.clear()
			_swing_signs[index] = signf(omega)
			_quiet_time = 0.0
			_apply_swing_hits(index, _last_angles[index], angle, omega)
		_last_angles[index] = angle
	if not any_swing:
		_quiet_time += delta
	_gameplay_open = max_angle >= deg_to_rad(door_open_collision_angle_degrees)
	_sync_gameplay_collision()
	if not locked and not latched and _impact_window_left <= 0.0 and max_angle < deg_to_rad(latch_closed_angle_degrees):
		var all_slow: bool = true
		for leaf in _leaves:
			if leaf != null and absf(leaf.angular_velocity.y) >= latch_velocity_threshold:
				all_slow = false
				break
		if all_slow:
			latched = true
			for leaf in _leaves:
				if leaf != null:
					leaf.freeze = true
					leaf.angular_velocity = Vector3.ZERO
	if latched and _impact_window_left <= 0.0 and not any_swing and _quiet_time > 0.35:
		set_physics_process(false)


func get_open_angle() -> float:
	var max_angle: float = 0.0
	for leaf in _leaves:
		if leaf != null and is_instance_valid(leaf):
			max_angle = maxf(max_angle, absf(wrapf(leaf.rotation.y, -PI, PI)))
	return max_angle


func set_target_highlight(_enabled: bool) -> void:
	# Door interaction is still handled by the gameplay resolver, but Doors are
	# never target-highlighted.  Clear any legacy overlay that may have been
	# assigned by an older scene instance without creating a new material.
	for visual in _visuals + _handle_visuals:
		if visual != null and is_instance_valid(visual):
			visual.material_overlay = null


func is_locked() -> bool:
	return locked


func set_locked(value: bool) -> void:
	locked = value
	if locked:
		_passive_drive_left.fill(0.0)
		for leaf in _leaves:
			if leaf != null:
				leaf.freeze = true
				leaf.angular_velocity = Vector3.ZERO
	else:
		for leaf in _leaves:
			if leaf != null:
				leaf.freeze = latched


func _get_map_parent() -> Node3D:
	return get_parent_node_3d()


func _get_map_basis() -> Basis:
	var parent_3d := get_parent_node_3d()
	if parent_3d != null:
		return parent_3d.global_basis
	return global_basis if is_inside_tree() else basis


func _to_map_local(global_point: Vector3) -> Vector3:
	var parent_3d := get_parent_node_3d()
	if parent_3d != null:
		return parent_3d.to_local(global_point)
	return to_local(global_point) if is_inside_tree() else global_point


func _to_map_global(local_point: Vector3) -> Vector3:
	var parent_3d := get_parent_node_3d()
	if parent_3d != null:
		return parent_3d.to_global(local_point)
	return to_global(local_point) if is_inside_tree() else local_point


func get_leaf_center_2d(leaf_index: int = 0) -> Vector2:
	var index: int = clampi(leaf_index, 0, _leaves.size() - 1)
	if index < 0 or index >= _leaves.size() or _leaves[index] == null:
		return Vector2.ZERO
	var leaf: RigidBody3D = _leaves[index]
	var leaf_pos: Vector3 = leaf.global_position if leaf.is_inside_tree() else (to_global(leaf.position) if is_inside_tree() else leaf.position)
	var map_point := _to_map_local(leaf_pos)
	return Vector2(map_point.x, map_point.z) * world_scale


func get_closest_leaf_index_2d(point: Vector2) -> int:
	var best_index: int = 0
	var best_distance: float = INF
	for index in range(_leaves.size()):
		var leaf: RigidBody3D = _leaves[index]
		if leaf == null or not is_instance_valid(leaf):
			continue
		var center: Vector2 = get_leaf_center_2d(index)
		var leaf_basis: Basis = leaf.global_basis if leaf.is_inside_tree() else (global_basis * leaf.basis if is_inside_tree() else leaf.basis)
		var tangent3: Vector3 = _get_map_basis().inverse() * leaf_basis.x
		var half: Vector2 = Vector2(tangent3.x, tangent3.z) * leaf_width * world_scale * 0.5
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, center - half, center + half)
		var distance: float = point.distance_squared_to(closest)
		# Strictly less means an exact tie deterministically keeps the left leaf.
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


func get_closest_leaf_point_2d(point: Vector2) -> Vector2:
	var index: int = get_closest_leaf_index_2d(point)
	if index < 0 or index >= _leaves.size() or _leaves[index] == null:
		return Vector2.ZERO
	var leaf: RigidBody3D = _leaves[index]
	var center: Vector2 = get_leaf_center_2d(index)
	var leaf_basis: Basis = leaf.global_basis if leaf.is_inside_tree() else (global_basis * leaf.basis if is_inside_tree() else leaf.basis)
	var tangent3: Vector3 = _get_map_basis().inverse() * leaf_basis.x
	var half: Vector2 = Vector2(tangent3.x, tangent3.z) * leaf_width * world_scale * 0.5
	return Geometry2D.get_closest_point_to_segment(point, center - half, center + half)


func _passive_leaf_sweeps_into_player(leaf_index: int, omega: float) -> bool:
	if absf(omega) < 0.001 or leaf_index >= _collision_bodies.size():
		return false
	var body: StaticBody2D = _collision_bodies[leaf_index]
	var anchor: StaticBody3D = _anchors[leaf_index]
	if body == null or anchor == null or not is_instance_valid(body) or not is_instance_valid(anchor):
		return false
	var anchor_pos: Vector3 = anchor.global_position if anchor.is_inside_tree() else anchor.position
	var hinge_local := _to_map_local(anchor_pos)
	var hinge_2d := Vector2(hinge_local.x, hinge_local.z) * world_scale
	var leaf: RigidBody3D = _leaves[leaf_index]
	var leaf_basis: Basis = leaf.global_basis if leaf.is_inside_tree() else leaf.basis
	var tangent3: Vector3 = _get_map_basis().inverse() * leaf_basis.x
	var half := Vector2(tangent3.x, tangent3.z).normalized() * leaf_width * world_scale * 0.5
	var center := get_leaf_center_2d(leaf_index)
	# One local player — prefer first-node over allocating the group Array on
	# every passive-swing physics tick across every door leaf.
	var actor := get_tree().get_first_node_in_group(&"dream_player") as Node2D
	if not is_instance_valid(actor):
		return false
	var player_center: Vector2 = actor.global_position + CONFIG.player_collision_offset
	var closest := Geometry2D.get_closest_point_to_segment(player_center, center - half, center + half)
	var separation := player_center - closest
	var clearance: float = CONFIG.player_collision_radius + wall_thickness * world_scale * 0.5 + 2.0
	if separation.length_squared() > clearance * clearance:
		return false
	var radial := closest - hinge_2d
	var point_velocity := Vector2(radial.y, -radial.x) * omega
	return point_velocity.dot(separation) > 0.0


func push_from_proxy(_position: Vector3, _motion: Vector3, _delta: float) -> void:
	pass # Passive body contact never releases either latch.


func request_proxy_impact(position_3d: Vector3, motion: Vector3, _delta: float, force: float = 260.0) -> bool:
	var map_position := _to_map_local(position_3d)
	var origin := Vector2(map_position.x, map_position.z) * world_scale
	var contact := get_closest_leaf_point_2d(origin)
	if origin.distance_to(contact) > 40.0:
		return false
	var leaf_index: int = get_closest_leaf_index_2d(origin)
	return apply_door_impact(&"enemy_push", _to_map_global(Vector3(contact.x / world_scale, door_height * 0.5, contact.y / world_scale)), motion, force, &"", leaf_index)


func prepare_enemy_passage(actor_position_2d: Vector2) -> bool:
	# The transit grant is the authority here. Stage the actor at the approach
	# point until the *solid* leaves have swung away from that side of the wall.
	# This keeps their 2D mirrors intact instead of allowing a collision shove.
	if is_destroyed:
		return true
	if locked:
		return false
	var local := to_local(_to_map_global(Vector3(actor_position_2d.x / world_scale, 0.0, actor_position_2d.y / world_scale)))
	var approach_side: float = signf(local.z)
	if absf(local.z) < 0.05:
		return false
	var all_clear := true
	var count: int = 1 if door_style == &"single" else 2
	for index in range(count):
		var leaf: RigidBody3D = _leaves[index]
		if leaf == null or not is_instance_valid(leaf):
			continue
		var away_sign: float = -approach_side if index == LEFT_LEAF_INDEX else approach_side
		var angle: float = wrapf(leaf.rotation.y, -PI, PI)
		if angle * away_sign >= deg_to_rad(65.0 if count == 2 else 78.0):
			continue
		all_clear = false
		latched = false
		wake_door_physics()
		leaf.freeze = false
		leaf.sleeping = false
		_passive_swing[index] = true
		_combat_swing_left[index] = 0.0
		_passive_drive_sign[index] = away_sign
		_passive_drive_left[index] = 0.25
	return all_clear


func apply_door_impact(source: StringName, point: Vector3, direction: Vector3, force: float, _type: StringName = &"", leaf_index: int = -1, instigator_id: int = 0) -> bool:
	if is_destroyed or locked or force <= 0.0:
		return false
	if current_health <= 0.0:
		var map_dir := _get_map_basis().inverse() * direction
		shatter(Vector2(map_dir.x, map_dir.z))
		return true
	if not is_boss_door and source != &"damage" and source != &"player_push" and source != &"enemy_push":
		var impact_damage := 0.0
		if source == &"dash":
			impact_damage = 50.0
		elif source == &"kick":
			impact_damage = 25.0
		elif source == &"punch":
			impact_damage = 20.0
		elif source.begins_with("melee_"):
			impact_damage = 50.0
		elif source.begins_with("projectile_"):
			impact_damage = maxf(force * 0.1, 25.0)
		elif source == &"thrown_furniture" or source == &"chair":
			impact_damage = 35.0
		if impact_damage > 0.0:
			current_health -= impact_damage
			if current_health <= 0.0:
				var map_direction := _get_map_basis().inverse() * direction
				shatter(Vector2(map_direction.x, map_direction.z))
				return true
	if current_health <= 0.0:
		var map_direction := _get_map_basis().inverse() * direction
		shatter(Vector2(map_direction.x, map_direction.z))
		return true
	if _leaves.is_empty():
		return true
	var point_in_map := _to_map_local(point)
	var selected_index: int = leaf_index if leaf_index >= 0 and leaf_index < _leaves.size() else get_closest_leaf_index_2d(Vector2(point_in_map.x, point_in_map.z) * world_scale)
	var leaf: RigidBody3D = _leaves[selected_index]
	var anchor: StaticBody3D = _anchors[selected_index]
	if leaf == null or anchor == null or not is_instance_valid(leaf) or not is_instance_valid(anchor):
		return false
	var planar := Vector3(direction.x, 0.0, direction.z).normalized()
	var anchor_pos: Vector3 = anchor.global_position if anchor.is_inside_tree() else anchor.position
	var lever := point - anchor_pos
	lever.y = 0.0
	if planar.length_squared() < 0.001 or absf(lever.cross(planar).y) < 0.005:
		return false
	if _impact_window_left <= 0.0:
		_impact_accumulated_impulse = 0.0
	var budget: float = maxf(door_max_accumulated_impulse - _impact_accumulated_impulse, 0.0)
	if budget < door_min_impact_impulse:
		return false
	var magnitude: float = minf(clampf(force * door_force_to_impulse, door_min_impact_impulse, door_max_impact_impulse), budget)
	# A moving rigid leaf is not automatically an attack. In particular, the
	# ordinary E push and AI doorway push must never hurt the actor touching it.
	var combat_source := source in [&"dash", &"kick", &"punch", &"thrown_furniture", &"chair", &"weapon_throw"] or source.begins_with("melee_") or source.begins_with("projectile_") or source.begins_with("thrown_")
	if combat_source:
		_passive_swing[selected_index] = false
		_passive_drive_left[selected_index] = 0.0
		_combat_swing_left[selected_index] = 0.65
		_combat_swing_instigator[selected_index] = instigator_id
	elif source in [&"player_push", &"enemy_push", &"push"]:
		_passive_swing[selected_index] = true
		_combat_swing_left[selected_index] = 0.0
		_combat_swing_instigator[selected_index] = 0
	latched = false
	wake_door_physics()
	set_meta(&"last_impact_source", source)
	leaf.freeze = false
	leaf.sleeping = false
	# The leaf is a hinge, not a freely sliding body. A planar impulse first
	# displaces its centre of mass; the joint pulls it back on a later physics
	# step, which appears as a door flying away and teleporting home. Apply only
	# the angular impulse implied by the contact lever. The 2D mirror continues
	# to follow the resulting leaf angle in _sync_gameplay_collision().
	var torque_scalar: float = lever.cross(planar).y * magnitude
	if absf(torque_scalar) > 0.001:
		if _passive_swing[selected_index]:
			_passive_drive_sign[selected_index] = signf(torque_scalar)
			_passive_drive_left[selected_index] = 0.9
		# RigidBody3D may still be registered as frozen in the physics server
		# during this callback. An immediate apply_torque_impulse() is then lost.
		# Seed the angular state directly; the next solver step enforces the
		# hinge without ever giving the leaf a free translational velocity.
		var hinge_inertia: float = maxf(door_mass * (leaf_width * leaf_width / 3.0 + wall_thickness * wall_thickness / 12.0), 0.01)
		var speed_limit: float = door_passive_max_angular_velocity if _passive_swing[selected_index] else door_max_angular_velocity
		var next_omega: float = clampf(leaf.angular_velocity.y + torque_scalar / hinge_inertia, -speed_limit, speed_limit)
		if _passive_swing[selected_index] and _passive_leaf_sweeps_into_player(selected_index, next_omega):
			leaf.angular_velocity.y = 0.0
			_passive_drive_left[selected_index] = 0.0
		else:
			leaf.angular_velocity.y = next_omega
	_impact_accumulated_impulse += magnitude
	_impact_window_left = door_impact_accumulation_window
	return true


func take_damage(amount: float, direction: Vector2 = Vector2.ZERO, force: float = 1.0, leaf_idx: int = -1) -> void:
	if is_destroyed or locked or is_boss_door:
		return
	wake_door_physics()
	current_health -= amount
	if current_health <= 0.0:
		shatter(direction)
		return
	var dir_3d := (_get_map_basis() * Vector3(direction.x, 0.0, direction.y)).normalized() if direction.length_squared() > 0.001 else _get_map_basis().z
	var base_pos: Vector3 = global_position if is_inside_tree() else position
	var impact_point := base_pos + Vector3(0, door_height * 0.5, 0)
	apply_door_impact(&"damage", impact_point, dir_3d, maxf(force * 50.0, 30.0), &"damage", leaf_idx)
	if current_health <= 0.0:
		shatter(direction)


func shatter(impact_direction: Vector2 = Vector2.ZERO) -> void:
	if is_destroyed:
		return
	is_destroyed = true

	door_shattered.emit(self)

	SFX.play_wood_shatter()

	# Clear 2D collisions
	for body in _collision_bodies:
		if is_instance_valid(body):
			body.collision_layer = 0
			body.collision_mask = 0
	for shape in _collision_shapes:
		if is_instance_valid(shape):
			shape.set_deferred(&"disabled", true)
			if not is_inside_tree():
				shape.disabled = true

	# Disable 3D leaves & visuals
	for leaf in _leaves:
		if is_instance_valid(leaf):
			leaf.freeze = true
			leaf.collision_layer = 0
			leaf.collision_mask = 0
			var cap := leaf.get_node_or_null("ArchitecturalCutSurface") as MeshInstance3D
			if cap != null:
				cap.visible = false
	for visual in _visuals:
		if is_instance_valid(visual):
			visual.visible = false
	for handle in _handle_visuals:
		if is_instance_valid(handle):
			handle.visible = false

	# Ensure leaf/visual references are directly hidden
	if is_instance_valid(left_visual):
		left_visual.visible = false
	if is_instance_valid(right_visual):
		right_visual.visible = false
	if is_instance_valid(left_handle_visual):
		left_handle_visual.visible = false
	if is_instance_valid(right_handle_visual):
		right_handle_visual.visible = false
	if is_instance_valid(door_visual):
		door_visual.visible = false
	if is_instance_valid(left_leaf):
		left_leaf.freeze = true
		left_leaf.collision_layer = 0
		left_leaf.collision_mask = 0
	if is_instance_valid(right_leaf):
		right_leaf.freeze = true
		right_leaf.collision_layer = 0
		right_leaf.collision_mask = 0

	if is_inside_tree():
		_spawn_wood_shards(impact_direction)


func _spawn_wood_shards(impact_direction: Vector2) -> void:
	var shard_count := 10
	var dir_3d := Vector3(impact_direction.x, 0.25, impact_direction.y).normalized() if impact_direction.length_squared() > 0.01 else Vector3(0, 0.25, 1)

	var shard_root := Node3D.new()
	shard_root.name = "DoorShards"
	shard_root.position = Vector3(0.0, door_height * 0.5, 0.0)
	add_child(shard_root)

	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.35, 0.22, 0.12, 1.0)
	if bool(get_meta(&"office_metal_door",false)):
		shard_mat.albedo_color=Color(.42,.49,.52)
		shard_mat.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
	shard_mat.roughness = 0.8
	if not bool(get_meta(&"test_legacy_door_shard_lifetime", false)):
		var metal := bool(get_meta(&"office_metal_door", false))
		if not shard_shader_anchors.has(metal):
			shard_shader_anchors[metal] = shard_mat

	for i in range(shard_count):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		var sz := randf_range(0.10, 0.28)
		box.size = Vector3(sz, sz * 0.4, 0.04)
		shard.mesh = box
		shard.material_override = shard_mat
		shard.position = Vector3(randf_range(-leaf_width, leaf_width), randf_range(-door_height * 0.3, door_height * 0.3), randf_range(-0.1, 0.1))
		shard.rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
		shard_root.add_child(shard)

	var tween := create_tween()
	tween.set_parallel(true)
	for shard in shard_root.get_children():
		var offset := dir_3d * randf_range(0.8, 2.2) + Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.4), randf_range(-0.6, 0.6))
		tween.tween_property(shard, "position", shard.position + offset, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.40).set_delay(0.25)
	tween.chain().tween_callback(shard_root.queue_free)


func _sync_gameplay_collision() -> void:
	if is_destroyed:
		return
	var target_layer: int = _collision_layer_2d if _gameplay_collision_requested else 0
	var map_basis_inv: Basis = _get_map_basis().inverse()
	for index in range(mini(_collision_bodies.size(), _leaves.size())):
		var body: StaticBody2D = _collision_bodies[index]
		var leaf: RigidBody3D = _leaves[index]
		if body == null or leaf == null or not is_instance_valid(body) or not is_instance_valid(leaf):
			continue
		var target_pos := get_leaf_center_2d(index)
		if not body.global_position.is_equal_approx(target_pos):
			body.global_position = target_pos
		var leaf_basis: Basis = leaf.global_basis if leaf.is_inside_tree() else leaf.basis
		var tangent: Vector3 = map_basis_inv * leaf_basis.x
		var target_rot := Vector2(tangent.x, tangent.z).angle()
		if not is_equal_approx(body.global_rotation, target_rot):
			body.global_rotation = target_rot
		if body.collision_layer != target_layer:
			body.collision_layer = target_layer


func _apply_swing_hits(leaf_index: int, previous_angle: float, angle: float, omega: float) -> void:
	if leaf_index < 0 or leaf_index >= _collision_bodies.size() or locked:
		return
	if _combat_swing_left[leaf_index] <= 0.0:
		return
	var body: StaticBody2D = _collision_bodies[leaf_index]
	var shape_node: CollisionShape2D = _collision_shapes[leaf_index]
	var leaf: RigidBody3D = _leaves[leaf_index]
	var hinge: StaticBody3D = _anchors[leaf_index]
	if body == null or shape_node == null or leaf == null or hinge == null:
		return
	var max_speed: float = absf(omega) * leaf_width * world_scale
	if max_speed < CONFIG.furniture_impact_minimum_speed:
		return
	var steps: int = maxi(1, int(ceili(absf(angle - previous_angle) / deg_to_rad(5.0))))
	var hinge_pos: Vector3 = hinge.global_position if hinge.is_inside_tree() else hinge.position
	var hinge_local := _to_map_local(hinge_pos)
	var hinge_2d := Vector2(hinge_local.x, hinge_local.z) * world_scale
	var side_sign: float = 1.0 if leaf_index == 0 else -1.0
	var space_state := body.get_world_2d().direct_space_state
	for i in range(steps + 1):
		var sample_angle: float = lerpf(previous_angle, angle, float(i) / float(steps))
		var current_basis: Basis = global_basis if is_inside_tree() else basis
		var tangent3: Vector3 = _get_map_basis().inverse() * (current_basis * (Basis(Vector3.UP, sample_angle) * Vector3(-side_sign, 0.0, 0.0)))
		var tangent := Vector2(tangent3.x, tangent3.z).normalized()
		if tangent.length_squared() < 0.001:
			continue
		var center := hinge_2d + tangent * leaf_width * world_scale * 0.5
		if _swing_hit_query == null:
			_swing_hit_query = PhysicsShapeQueryParameters2D.new()
			_swing_hit_query.collide_with_areas = true
			_swing_hit_query.collide_with_bodies = true
		_swing_hit_query.shape = shape_node.shape
		_swing_hit_query.transform = Transform2D(tangent.angle(), center)
		_swing_hit_query.collision_mask = 1 | 2 | 8 | 16
		_swing_hit_query.exclude = [body.get_rid()]
		for hit in space_state.intersect_shape(_swing_hit_query, 24):
			var target: Node = hit.get("collider") as Node
			if target != null and target.has_method("get_damage_owner"):
				target = target.get_damage_owner()
			elif target is Area2D and target.get_parent() != null:
				var parent_node: Node = target.get_parent()
				if parent_node.is_in_group(&"dream_enemies") or parent_node.is_in_group(&"dream_player") or parent_node.is_in_group(&"damageable_props"):
					target = parent_node
			if not is_instance_valid(target) or not target is Node2D:
				continue
			if not (target.is_in_group(&"dream_enemies") or target.is_in_group(&"dream_player") or target.is_in_group(&"damageable_props")):
				continue
			var id: int = target.get_instance_id()
			if id == _combat_swing_instigator[leaf_index]:
				continue
			if _swing_hits.has(id) or Time.get_ticks_msec() - int(_target_hit_times.get(id, -10000)) < 250:
				continue
			var target_position: Vector2 = (target as Node2D).global_position
			var radius: float = clampf((target_position - hinge_2d).dot(tangent), 0.0, leaf_width * world_scale)
			var effective_radius: float = clampf(radius + 8.0, radius, leaf_width * world_scale)
			var speed: float = absf(omega) * effective_radius
			if speed < CONFIG.furniture_impact_minimum_speed:
				continue
			var r := Vector3(tangent.x, 0.0, tangent.y) * effective_radius / world_scale
			var velocity3 := (Vector3.UP * omega).cross(r)
			var hit_direction := Vector2(velocity3.x, velocity3.z).normalized()
			_swing_hits[id] = true
			_target_hit_times[id] = Time.get_ticks_msec()
			_apply_actor_impact.call_deferred(id, hit_direction, speed)


func _apply_actor_impact(id: int, direction: Vector2, speed: float) -> void:
	if not is_instance_id_valid(id):
		return
	var target: Node = instance_from_id(id)
	if not is_instance_valid(target):
		return
	var force: float = minf(speed * door_mass * CONFIG.furniture_impact_knockdown_force_multiplier, CONFIG.maximum_knockback_speed)
	var ratio: float = speed / maxf(CONFIG.furniture_impact_minimum_speed, 1.0)
	var damage: float = CONFIG.furniture_impact_damage * clampf(ratio - 1.0, 0.0, 2.0)
	if target.is_in_group(&"dream_enemies"):
		if damage > 0.0:
			target.take_damage(damage, target.global_position - direction * 12.0, force, &"door_impact")
		if is_instance_valid(target) and not bool(target.get("dead")):
			target.start_knockdown(direction, &"door_impact", force)
	elif target.is_in_group(&"dream_player"):
		if damage > 0.0:
			var door_pos: Vector3 = global_position if is_inside_tree() else position
			var map_pos := _to_map_local(door_pos)
			target.receive_damage(
				damage,
				&"door_impact",
				Vector2(map_pos.x, map_pos.z) * world_scale
			)
	elif target.has_method("apply_combat_impulse"):
		target.apply_combat_impulse(direction, force)
	set_meta(&"last_swing_target", id)
	set_meta(&"last_swing_force", force)


func _exit_tree() -> void:
	if has_meta(&"display_reparenting"):
		return
	for body in _collision_bodies:
		if is_instance_valid(body):
			body.queue_free()
	_collision_bodies.clear()
	_collision_shapes.clear()
