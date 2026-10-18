class_name BreakableGlassWindow3D
extends Node3D

## Breakable interior glass window partition (Hotline Miami / OTXO style).
## - Transparent to sightlines and vision (enemies and player can see and aim through it)
## - Solid to physical movement before breaking
## - Shatters upon taking damage from bullets, kicks, melee attacks, or player dashes
## - Shattering opens the full-height interior passage when both sides are floor.

signal window_shattered(window)

const SFX := preload("res://scripts/audio/sfx_manager.gd")

@export var max_health: float = 1.0
var current_health: float = 1.0
var is_shattered: bool = false
var edge_data: Dictionary = {}
var edge_key: String = ""
var structural_height: float = 2.6
var structural_thickness: float = 1.0
var cutaway_mode := false
var cutaway_materials: Array[ShaderMaterial] = []
const FLOOR_TRACK_HEIGHT: float = 0.06

var glass_pane: MeshInstance3D = null
var frame_mesh: MeshInstance3D = null
var frame_root: Node3D = null
var cutaway_caps: Array[MeshInstance3D] = []
var collision_body_2d: StaticBody2D = null
var collision_shape_2d: CollisionShape2D = null

static var glass_material: StandardMaterial3D = null
static var shard_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group(&"breakable_glass_windows")
	_init_materials()


static func _init_materials() -> void:
	if glass_material == null:
		glass_material = StandardMaterial3D.new()
		glass_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_material.albedo_color = Color(0.72, 0.80, 0.78, 0.15)
		glass_material.metallic = 0.2
		glass_material.roughness = 0.08
		glass_material.emission_enabled = false
		glass_material.emission = Color(0.15, 0.45, 0.65, 1.0)
		glass_material.emission_energy_multiplier = 0.35
		glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func configure_window(edge: Dictionary, key: String, wall_height: float, wall_thickness: float, collision_parent: Node2D) -> void:
	edge_data = edge.duplicate(true)
	edge_key = key
	structural_height = wall_height
	structural_thickness = wall_thickness
	current_health = max_health
	is_shattered = false

	_init_materials()

	var axis := String(edge.get("axis", "H"))
	var is_vertical := (axis == "V")
	if is_vertical:
		rotation.y = PI * 0.5

	# 1. Build 3D Window Frame (top, bottom, left, right borders)
	frame_root = Node3D.new()
	frame_root.name = "WindowFrame"
	add_child(frame_root)

	var frame_mat := preload("res://scripts/dream/office_pixel_materials.gd").make(Color(.27, .30, .31), "metal").duplicate() as ShaderMaterial
	var sill_mat := preload("res://scripts/dream/office_pixel_materials.gd").make(Color(.66, .68, .67), "paint").duplicate() as ShaderMaterial
	cutaway_materials.append(frame_mat)
	cutaway_materials.append(sill_mat)

	var bottom_h := FLOOR_TRACK_HEIGHT
	var top_h := wall_height - 0.05
	var open_h := top_h - bottom_h
	var window_depth := wall_thickness * 0.5

	# A visual floor track is not a masonry sill or a gameplay obstacle.
	var lower_box := MeshInstance3D.new()
	lower_box.name = "FloorTrack"
	var lower_mesh := BoxMesh.new()
	lower_mesh.size = Vector3(1.0, bottom_h, window_depth)
	lower_box.mesh = lower_mesh
	lower_box.material_override = sill_mat
	lower_box.position = Vector3(0.0, bottom_h * 0.5, 0.0)
	frame_root.add_child(lower_box)

	# Upper lintel
	var upper_box := MeshInstance3D.new()
	upper_box.name = "WindowHeader"
	var upper_mesh := BoxMesh.new()
	upper_mesh.size = Vector3(1.0, wall_height - top_h, window_depth)
	upper_box.mesh = upper_mesh
	upper_box.material_override = frame_mat
	upper_box.position = Vector3(0.0, top_h + (wall_height - top_h) * 0.5, 0.0)
	frame_root.add_child(upper_box)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(.05, open_h, window_depth)
		post.mesh = post_mesh
		post.material_override = frame_mat
		post.position = Vector3(side * .475, (bottom_h + top_h) * .5, 0)
		frame_root.add_child(post)

	preload("res://scripts/dream/solid_shadow_caster_3d.gd").protect_shader_meshes(frame_root)

	# 2. Build 3D Glass Pane
	glass_pane = MeshInstance3D.new()
	glass_pane.name = "GlassPane"
	var pane_material := ShaderMaterial.new()
	pane_material.shader = preload("res://shaders/dream3d/office_window_glass.gdshader")
	glass_pane.material_override = pane_material
	cutaway_materials.append(pane_material)
	var pane_mesh := BoxMesh.new()
	pane_mesh.size = Vector3(0.96, open_h * 0.98, window_depth)
	glass_pane.mesh = pane_mesh
	glass_pane.position = Vector3(0.0, (bottom_h + top_h) * 0.5, 0.0)
	glass_pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass_pane)

	# 3. Build 2D Collision Body
	if collision_parent != null and is_instance_valid(collision_parent):
		_build_2d_collision(collision_parent, is_vertical)


func set_cutaway_mode(enabled: bool) -> void:
	cutaway_mode = enabled
	if is_shattered:
		for cap in cutaway_caps:
			if is_instance_valid(cap):
				cap.visible = false
		return

	if enabled and cutaway_caps.is_empty():
		for side in [-1.0, 1.0]:
			var cap := preload("res://scripts/dream/architecture_slice_cap.gd").make(0.05, structural_thickness, structural_height)
			cap.name = "ArchitecturalCutSurface" if side < 0.0 else "ArchitecturalCutSurface_R"
			cap.position.x = side * 0.475
			add_child(cap)
			cutaway_caps.append(cap)

	for cap in cutaway_caps:
		if is_instance_valid(cap):
			cap.visible = enabled

	for material in cutaway_materials:
		material.set_shader_parameter("architecture_cutaway", enabled)
		material.set_shader_parameter("architecture_wall_height", structural_height)


func set_wall_opacity(value: float) -> void:
	set_cutaway_mode(value < .99)


func _build_2d_collision(collision_parent: Node2D, is_vertical: bool) -> void:
	collision_body_2d = StaticBody2D.new()
	collision_body_2d.name = "GlassCollision_%s" % edge_key.replace(":", "_")
	var edge_x := float(edge_data.get("x", 0))
	var edge_y := float(edge_data.get("y", 0))

	var pos_2d := Vector2.ZERO
	if is_vertical:
		pos_2d = Vector2((edge_x - 0.5) * 32.0, edge_y * 32.0)
	else:
		pos_2d = Vector2(edge_x * 32.0, (edge_y - 0.5) * 32.0)

	collision_body_2d.global_position = pos_2d
	collision_body_2d.collision_layer = 1 | 4 | 8
	collision_body_2d.collision_mask = 0

	collision_body_2d.add_to_group(&"damageable_props")
	collision_body_2d.add_to_group(&"glass_windows")
	collision_body_2d.set_meta(&"glass_window_3d", weakref(self))
	collision_body_2d.set_meta(&"breakable", true)

	collision_shape_2d = CollisionShape2D.new()
	collision_shape_2d.name = "CollisionShape2D"
	var rect_shape := RectangleShape2D.new()
	if is_vertical:
		rect_shape.size = Vector2(structural_thickness * 32.0, 32.0)
	else:
		rect_shape.size = Vector2(32.0, structural_thickness * 32.0)
	collision_shape_2d.shape = rect_shape
	collision_body_2d.add_child(collision_shape_2d)

	collision_body_2d.set_script(load("res://scripts/dream/breakable_glass_collider_2d.gd"))
	collision_body_2d.set("window_owner", self)

	collision_parent.add_child(collision_body_2d)


func take_damage(amount: float, direction: Vector2 = Vector2.ZERO, _force: float = 1.0) -> void:
	if is_shattered:
		return
	current_health -= amount
	if current_health <= 0.0:
		shatter(direction)


func shatter(impact_direction: Vector2 = Vector2.ZERO) -> void:
	if is_shattered:
		return
	is_shattered = true

	window_shattered.emit(self)

	SFX.play_glass_shatter()

	# The collision belongs to the intact pane only. Floor topology continues to
	# reject exterior openings with no legal landing cell.
	if collision_body_2d != null and is_instance_valid(collision_body_2d):
		collision_body_2d.set_deferred("collision_layer", 0)
	if collision_shape_2d != null and is_instance_valid(collision_shape_2d):
		collision_shape_2d.set_deferred("disabled", true)

	if glass_pane != null and is_instance_valid(glass_pane):
		glass_pane.visible = false
		if is_inside_tree():
			_spawn_shards(impact_direction)

	if frame_root != null and is_instance_valid(frame_root):
		frame_root.visible = false
	for cap in cutaway_caps:
		if is_instance_valid(cap):
			cap.visible = false


func _spawn_shards(impact_direction: Vector2) -> void:
	var shard_count := 8
	var dir_3d := Vector3(impact_direction.x, 0.2, impact_direction.y).normalized() if impact_direction.length_squared() > 0.01 else Vector3(0, 0.2, 1)

	var shard_root := Node3D.new()
	shard_root.name = "GlassShards"
	shard_root.position = glass_pane.position
	add_child(shard_root)

	var shard_mat := glass_material.duplicate() as StandardMaterial3D
	shard_mat.albedo_color = Color(0.4, 0.8, 1.0, 0.6)
	# Retain one actually rendered variant, not a shared draw material: fresh
	# per-burst materials preserve the original transparent material ordering.
	# Geometry, RNG order and the existing shrink tween remain unchanged.
	if shard_material == null and not bool(get_meta(&"test_legacy_shard_material",false)):
		shard_material = shard_mat

	for i in range(shard_count):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		var sz := randf_range(0.08, 0.22)
		box.size = Vector3(sz, sz * 0.7, 0.01)
		shard.mesh = box
		shard.material_override = shard_mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shard.position = Vector3(randf_range(-0.4, 0.4), randf_range(-0.5, 0.5), randf_range(-0.05, 0.05))
		shard.rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
		shard_root.add_child(shard)

	if is_inside_tree():
		var tween := create_tween()
		tween.set_parallel(true)
		for shard in shard_root.get_children():
			var offset := dir_3d * randf_range(0.6, 1.8) + Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3), randf_range(-0.5, 0.5))
			tween.tween_property(shard, "position", shard.position + offset, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(shard, "scale", Vector3.ZERO, 0.35).set_delay(0.20)
		tween.chain().tween_callback(shard_root.queue_free)
	else:
		shard_root.queue_free()
