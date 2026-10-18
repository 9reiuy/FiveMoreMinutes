extends Node3D
class_name Furniture3DVisual

## Presentation-only 3D visual adapter for formal 2D Furniture (RigidBody2D).
## 2D physics remains 100% authoritative. 3D visual follows 2D transform strictly one-way.
## No RigidBody3D, no 3D colliders, no reverse sync.

const PIXELS_PER_WORLD_CELL: float = 32.0
const FURNITURE_3D_DEBRIS_SCRIPT := preload("res://scripts/dream/furniture_3d_debris.gd")

var target_furniture: Node2D
var visual_instance: Node3D
var debris_texture: Texture2D
var _debris_spawned: bool = false
var _cached_sprite: CanvasItem
var _cached_shadow: CanvasItem
var _room_presentation_active: bool = true
var _contact_shadow: MeshInstance3D
var _pixel_sample: bool = false
static var _contact_shadow_material: ShaderMaterial
static var _sample_contact_shadow_material: ShaderMaterial
static var _outline_material: ShaderMaterial

var _cached_actor_sprite: VisualInstance3D
var _cached_actor_sprite_resolved: bool = false
var _cached_seat_root: Node3D
var _cached_seat_root_resolved: bool = false
var _last_pos2d: Vector2 = Vector2(INF, INF)
var _last_rot2d: float = INF
var _last_fake_height: float = INF
var _last_seat_rot: float = INF
var _last_visible: int = -1
var _idle_frames: int = 0
const IDLE_SLEEP_FRAMES: int = 8

var source_actor: Node2D:
	get:
		return target_furniture

var actor_sprite: VisualInstance3D:
	get:
		if _cached_actor_sprite_resolved:
			return _cached_actor_sprite if is_instance_valid(_cached_actor_sprite) else null
		if visual_instance != null:
			_cached_actor_sprite_resolved = true
			var direct := visual_instance.get_node_or_null("MeshInstance3D") as VisualInstance3D
			if direct != null:
				_cached_actor_sprite = direct
				return direct
			var base := visual_instance.get_node_or_null("BaseMesh") as VisualInstance3D
			if base != null:
				_cached_actor_sprite = base
				return base
			var seat := visual_instance.get_node_or_null("SeatRoot/SeatMesh") as VisualInstance3D
			if seat != null:
				_cached_actor_sprite = seat
				return seat
		return null

func set_room_presentation_active(active: bool) -> void:
	_room_presentation_active = active
	var vis := (target_furniture != null and is_instance_valid(target_furniture) and target_furniture.visible)
	var vis_int := 1 if vis else 0
	if _last_visible != vis_int:
		_last_visible = vis_int
		visible = vis

func configure(source: Node2D, visual_scene: PackedScene, debris_tex: Texture2D = null, office_kind: String = "") -> void:
	target_furniture = source
	debris_texture = debris_tex
	_cached_actor_sprite = null
	_cached_actor_sprite_resolved = false
	_cached_seat_root = null
	_cached_seat_root_resolved = false
	_last_pos2d = Vector2(INF, INF)
	_last_rot2d = INF
	_last_fake_height = INF
	_last_seat_rot = INF
	_last_visible = -1

	if not office_kind.is_empty():
		var authored_sample: bool = source.get_meta(&"office_art_review", false) == true
		_pixel_sample = source.get_meta(&"office_pixel_sample", false) == true
		var style := String(source.get_meta(&"office_visual_style", ""))
		visual_instance = preload("res://scripts/dream/office_furniture_catalog.gd").make_visual_for_style(office_kind, style, authored_sample, _pixel_sample)
		if style in ["approved_office", "approved_room"]:
			authored_sample = true
			_pixel_sample = style == "approved_office"
		add_child(visual_instance)
		if _contact_shadow_material == null:
			_contact_shadow_material = ShaderMaterial.new()
			_contact_shadow_material.shader = preload("res://shaders/dream3d/office_contact_shadow.gdshader")
		if authored_sample and _sample_contact_shadow_material == null:
			_sample_contact_shadow_material = _contact_shadow_material.duplicate() as ShaderMaterial
			_sample_contact_shadow_material.set_shader_parameter("shadow_opacity", .28)
		_contact_shadow = MeshInstance3D.new()
		var shadow_quad := QuadMesh.new()
		var size: Vector3 = preload("res://scripts/dream/office_furniture_catalog.gd").size_of(office_kind)
		shadow_quad.size = Vector2(size.x, size.z) * (1.10 if authored_sample else 1.25)
		_contact_shadow.mesh = shadow_quad
		_contact_shadow.material_override = _sample_contact_shadow_material if authored_sample else _contact_shadow_material
		_contact_shadow.rotation.x = -PI * .5
		_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_contact_shadow)
	elif visual_scene != null:
		visual_instance = visual_scene.instantiate() as Node3D
		if visual_instance != null:
			add_child(visual_instance)

	if visual_instance != null:
		preload("res://scripts/dream/solid_shadow_caster_3d.gd").protect_shader_meshes(visual_instance)
		_apply_furniture_outline(visual_instance)
		_cached_seat_root = visual_instance.get_node_or_null("SeatRoot") as Node3D
		_cached_seat_root_resolved = true
		var _discard := actor_sprite

	if target_furniture != null and is_instance_valid(target_furniture):
		target_furniture.set_meta(&"has_3d_visual", true)
		target_furniture.set_meta(&"furniture_3d_visual", weakref(self))
		target_furniture.tree_exiting.connect(_on_source_tree_exiting)
		if target_furniture is RigidBody2D:
			var rb := target_furniture as RigidBody2D
			if not rb.sleeping_state_changed.is_connected(_on_target_sleeping_state_changed):
				rb.sleeping_state_changed.connect(_on_target_sleeping_state_changed)

		# Hide 2D visuals so they don't render on top of 3D world
		_cached_sprite = target_furniture.get_node_or_null("Sprite2D") as CanvasItem
		if _cached_sprite != null:
			_cached_sprite.visible = false

		_cached_shadow = target_furniture.get_node_or_null("Shadow") as CanvasItem
		if _cached_shadow != null:
			_cached_shadow.visible = false

		# Initial transform sync
		_sync_transform()

func _apply_furniture_outline(root_visual: Node3D) -> void:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = preload("res://shaders/dream3d/furniture_pixel_outline.gdshader")
	var stack: Array[Node] = [root_visual]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh != null and mesh_node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				# Existing damage/interaction overlays keep their own priority.
				if mesh_node.material_overlay == null:
					mesh_node.material_overlay = _outline_material
		for child in node.get_children():
			stack.append(child)

func _sync_transform() -> bool:
	if target_furniture == null or not is_instance_valid(target_furniture):
		return false
	var changed := false
	var vis := target_furniture.visible
	var vis_int := 1 if vis else 0
	if _last_visible != vis_int:
		_last_visible = vis_int
		visible = vis
		changed = true
	if not vis and _last_pos2d.x != INF:
		return changed

	var pos2d := target_furniture.global_position
	var rot2d := target_furniture.global_rotation
	var fake_height: float = 0.0
	var h_val: Variant = target_furniture.get("fake_height")
	if h_val is float or h_val is int:
		fake_height = float(h_val)
	var drop_height: Variant = target_furniture.get("sky_drop_height")
	if drop_height is float or drop_height is int:
		fake_height = maxf(fake_height, float(drop_height))

	if pos2d != _last_pos2d or fake_height != _last_fake_height:
		_last_pos2d = pos2d
		position = Vector3(
			pos2d.x / PIXELS_PER_WORLD_CELL,
			fake_height / PIXELS_PER_WORLD_CELL,
			pos2d.y / PIXELS_PER_WORLD_CELL
		)
		changed = true
	if rot2d != _last_rot2d:
		_last_rot2d = rot2d
		rotation.y = -rot2d
		changed = true
	if fake_height != _last_fake_height:
		_last_fake_height = fake_height
		if _contact_shadow != null:
			_contact_shadow.position.y = .015 - fake_height / PIXELS_PER_WORLD_CELL
			_contact_shadow.visible = fake_height < 32.0
		changed = true

	# Swivel chair seat independent rotation sync
	if not _cached_seat_root_resolved and visual_instance != null:
		_cached_seat_root = visual_instance.get_node_or_null("SeatRoot") as Node3D
		_cached_seat_root_resolved = true
	if _cached_seat_root != null:
		var seat_rot_val: Variant = target_furniture.get("seat_rotation")
		if seat_rot_val is float or seat_rot_val is int:
			var seat_rot := float(seat_rot_val)
			if seat_rot != _last_seat_rot:
				_last_seat_rot = seat_rot
				_cached_seat_root.rotation.y = -seat_rot
				changed = true
	return changed

func wake_visual_process() -> void:
	_idle_frames = 0
	if not is_processing():
		set_process(true)

func _on_target_sleeping_state_changed() -> void:
	if target_furniture == null or not is_instance_valid(target_furniture):
		return
	var rb := target_furniture as RigidBody2D
	if rb != null and not rb.sleeping:
		wake_visual_process()

func _process(_delta: float) -> void:
	if target_furniture == null or not is_instance_valid(target_furniture) or target_furniture.is_queued_for_deletion():
		_handle_destruction_or_exit()
		return

	# Keep 2D sprite hidden
	if _cached_sprite != null and is_instance_valid(_cached_sprite) and _cached_sprite.visible:
		_cached_sprite.visible = false
	if _cached_shadow != null and is_instance_valid(_cached_shadow) and _cached_shadow.visible:
		_cached_shadow.visible = false

	# Check destroyed state on 2D chair_01
	var is_destroyed: Variant = target_furniture.get("destroyed")
	if is_destroyed is bool and bool(is_destroyed):
		_handle_destruction_or_exit()
		return

	var changed := _sync_transform()
	var body := target_furniture as RigidBody2D
	var body_idle := body == null or body.sleeping or body.freeze
	if changed or not body_idle:
		_idle_frames = 0
	else:
		_idle_frames += 1
		if _idle_frames >= IDLE_SLEEP_FRAMES:
			set_process(false)

func _handle_destruction_or_exit() -> void:
	if not _debris_spawned and is_inside_tree():
		_debris_spawned = true
		var parent_node := get_parent()
		if parent_node != null and is_instance_valid(parent_node):
			var spawn_pos := position + Vector3(0.0, 0.2, 0.0)
			var last_dmg_dir: Vector3 = Vector3.ZERO
			if target_furniture != null and is_instance_valid(target_furniture):
				var dmg_dir_variant: Variant = target_furniture.get("last_damage_direction")
				if dmg_dir_variant is Vector2:
					var d2 := dmg_dir_variant as Vector2
					last_dmg_dir = Vector3(d2.x, 0.0, d2.y)
			FURNITURE_3D_DEBRIS_SCRIPT.spawn(parent_node, spawn_pos, debris_texture, 6, last_dmg_dir)

	queue_free()

func _on_source_tree_exiting() -> void:
	if not is_queued_for_deletion():
		queue_free()
