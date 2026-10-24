class_name IndependentElevatorCab3D
extends Node3D

## Low-pixel Independent Elevator Cab (Reference Image 1 style)
## Exists independently of any floor tree during transitions.
## Provides an enclosed walkable cab interior (~3.6m x 2.6m) where player can walk freely.

signal cab_doors_opened
signal cab_doors_closed
signal player_guided_to_exit

const CAB_WIDTH := 3.6
const CAB_DEPTH := 2.6
const CAB_HEIGHT := 2.6
const WALL_THICKNESS := 0.14
const CELL_PIXELS := 32.0
const WORLD_WALL_LAYER := 4

@export var current_floor_index: int = 0
@export var total_indicator_floors: int = 10

var doors_open := false

# Visual nodes
var cab_visual_root: Node3D
var cab_floor_mesh: MeshInstance3D
var cab_ceiling_mesh: MeshInstance3D
var cab_light: OmniLight3D
var north_wall: MeshInstance3D
var west_wall: MeshInstance3D
var east_wall: MeshInstance3D
var south_return_left: MeshInstance3D
var south_return_right: MeshInstance3D
var inner_left_door: MeshInstance3D
var inner_right_door: MeshInstance3D
var indicator_root: Node3D
var indicator_label: Label3D
var indicator_leds: Array[MeshInstance3D] = []
var cab_camera_root: Node3D
var cab_reader_root: Node3D

# Handrails
var handrail_root: Node3D

# 2D Collision boundaries (keep player inside cab during free roam)
var boundary_root_2d: Node2D
var boundary_north: StaticBody2D
var boundary_south: StaticBody2D
var boundary_west: StaticBody2D
var boundary_east: StaticBody2D
var south_collider_shape: CollisionShape2D

# Materials
var mat_wall: Material
var mat_floor: Material
var mat_doors: Material
var mat_handrail: Material
var mat_housing: Material
var mat_led_off: Material
var mat_led_on: Material
var mat_camera: Material
var mat_reader: Material

# Tweens
var door_tween: Tween
var player_guide_tween: Tween
var _shadow_boundaries: Array[MeshInstance3D] = []
var managed_shadows := false


func set_managed_shadows(enabled: bool) -> void:
	managed_shadows = enabled
	if _shadow_boundaries.is_empty():
		_build_shadow_boundaries()
	for caster in _shadow_boundaries:
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		caster.visible = enabled
	cab_light.shadow_enabled = enabled
	cab_light.light_cull_mask = 7 | 8  # + furniture cutout layer
	cab_light.light_specular = 0.0
	cab_light.shadow_bias = 0.035
	cab_light.shadow_normal_bias = 0.6


func _build_shadow_boundaries() -> void:
	# The visible south returns and leaves are cut low for the camera. Their
	# complete architectural volumes still block light and move with each leaf.
	_shadow_box(cab_visual_root, Vector3(CAB_WIDTH, 0.08, CAB_DEPTH), Vector3(0.0, CAB_HEIGHT + 0.04, 0.0))
	_shadow_box(cab_visual_root, Vector3(CAB_WIDTH, 0.04, CAB_DEPTH), Vector3(0.0, 0.02, 0.0))
	for wall in [north_wall, west_wall, east_wall]:
		_shadow_box(wall, (wall.mesh as BoxMesh).size, Vector3.ZERO)
	for side in [south_return_left, south_return_right]:
		_shadow_box(side, Vector3(0.9, CAB_HEIGHT, WALL_THICKNESS), Vector3(0.0, CAB_HEIGHT * 0.5 - side.position.y, 0.0))
	for leaf in [inner_left_door, inner_right_door]:
		_shadow_box(leaf, Vector3(0.92, CAB_HEIGHT, 0.05), Vector3(0.0, CAB_HEIGHT * 0.5 - leaf.position.y, 0.0))


func _shadow_box(parent: Node3D, size: Vector3, offset: Vector3) -> void:
	var caster := MeshInstance3D.new()
	caster.name = "CabBoundaryShadow"
	var mesh := BoxMesh.new()
	mesh.size = size
	caster.mesh = mesh
	caster.position = offset
	caster.layers = 1
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(caster)
	_shadow_boundaries.append(caster)


func _init(p_floor_index: int = 0) -> void:
	name = "IndependentElevatorCab3D"
	current_floor_index = p_floor_index
	_init_materials()
	_build_cab_3d()


func _ready() -> void:
	update_indicator(current_floor_index)


func _init_materials() -> void:
	var pixel_mats := preload("res://scripts/dream/office_pixel_materials.gd")
	# Gray-blue metallic cab interior walls matching Image 1
	mat_wall = pixel_mats.make(Color(0.48, 0.54, 0.60), "metal", true)
	mat_floor = pixel_mats.make_floor(Color(0.38, 0.42, 0.46), "tile")
	mat_doors = pixel_mats.make(Color(0.58, 0.64, 0.70), "metal", true)
	mat_housing = pixel_mats.make(Color(0.24, 0.28, 0.34), "metal", true)
	mat_camera = pixel_mats.make(Color(0.18, 0.20, 0.24), "metal", true)
	mat_reader = pixel_mats.make(Color(0.30, 0.35, 0.42), "metal", true)

	var std_rail := StandardMaterial3D.new()
	std_rail.albedo_color = Color(0.85, 0.88, 0.92, 1.0)
	std_rail.metallic = 0.85
	std_rail.roughness = 0.25
	mat_handrail = std_rail

	var std_led_off := StandardMaterial3D.new()
	std_led_off.albedo_color = Color(0.28, 0.32, 0.38, 1.0)
	mat_led_off = std_led_off

	var std_led_on := StandardMaterial3D.new()
	std_led_on.albedo_color = Color(0.4, 0.95, 0.35, 1.0)
	std_led_on.emission_enabled = true
	std_led_on.emission = Color(0.4, 0.95, 0.35)
	std_led_on.emission_energy_multiplier = 2.2
	mat_led_on = std_led_on


func _build_cab_3d() -> void:
	cab_visual_root = Node3D.new()
	cab_visual_root.name = "CabVisualRoot"
	add_child(cab_visual_root)

	# 1. Cab Floor
	cab_floor_mesh = MeshInstance3D.new()
	cab_floor_mesh.name = "CabFloorMesh"
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(CAB_WIDTH, 0.04, CAB_DEPTH)
	cab_floor_mesh.mesh = floor_box
	cab_floor_mesh.position = Vector3(0.0, 0.02, 0.0)
	cab_floor_mesh.material_override = mat_floor
	cab_floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(cab_floor_mesh)

	# 2. North Wall (Back Wall)
	north_wall = MeshInstance3D.new()
	north_wall.name = "CabNorthWall"
	var north_box := BoxMesh.new()
	north_box.size = Vector3(CAB_WIDTH, CAB_HEIGHT, WALL_THICKNESS)
	north_wall.mesh = north_box
	north_wall.position = Vector3(0.0, CAB_HEIGHT * 0.5, -CAB_DEPTH * 0.5)
	north_wall.material_override = mat_wall
	north_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(north_wall)

	# Center Pilaster on North Wall
	var center_pilaster := MeshInstance3D.new()
	center_pilaster.name = "CenterPilaster"
	var pil_box := BoxMesh.new()
	pil_box.size = Vector3(0.85, CAB_HEIGHT, 0.04)
	center_pilaster.mesh = pil_box
	center_pilaster.position = Vector3(0.0, CAB_HEIGHT * 0.5, -CAB_DEPTH * 0.5 + WALL_THICKNESS * 0.5 + 0.02)
	center_pilaster.material_override = mat_doors
	center_pilaster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(center_pilaster)

	# 3. West Wall (Left Wall)
	west_wall = MeshInstance3D.new()
	west_wall.name = "CabWestWall"
	var west_box := BoxMesh.new()
	west_box.size = Vector3(WALL_THICKNESS, CAB_HEIGHT, CAB_DEPTH)
	west_wall.mesh = west_box
	west_wall.position = Vector3(-CAB_WIDTH * 0.5, CAB_HEIGHT * 0.5, 0.0)
	west_wall.material_override = mat_wall
	west_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(west_wall)

	# 4. East Wall (Right Wall)
	east_wall = MeshInstance3D.new()
	east_wall.name = "CabEastWall"
	var east_box := BoxMesh.new()
	east_box.size = Vector3(WALL_THICKNESS, CAB_HEIGHT, CAB_DEPTH)
	east_wall.mesh = east_box
	east_wall.position = Vector3(CAB_WIDTH * 0.5, CAB_HEIGHT * 0.5, 0.0)
	east_wall.material_override = mat_wall
	east_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(east_wall)

	# 5. South Front Wall (Cutaway silhouette matching isometric visibility rules)
	# South returns are cut low so they frame the entrance without blocking interior visibility
	var south_return_height := 0.45
	var ret_box := BoxMesh.new()
	ret_box.size = Vector3(0.9, south_return_height, WALL_THICKNESS)

	south_return_left = MeshInstance3D.new()
	south_return_left.name = "CabSouthReturnLeft"
	south_return_left.mesh = ret_box
	south_return_left.position = Vector3(-1.35, south_return_height * 0.5, CAB_DEPTH * 0.5)
	south_return_left.material_override = mat_wall
	south_return_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(south_return_left)

	south_return_right = MeshInstance3D.new()
	south_return_right.name = "CabSouthReturnRight"
	south_return_right.mesh = ret_box
	south_return_right.position = Vector3(1.35, south_return_height * 0.5, CAB_DEPTH * 0.5)
	south_return_right.material_override = mat_wall
	south_return_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(south_return_right)

	# (South lintel omitted to keep cinematic isometric camera view unobstructed)

	# 6. Inner Sliding Doors (South entrance)
	# Positioned at cutaway height or docked height
	var inner_leaf_box := BoxMesh.new()
	inner_leaf_box.size = Vector3(0.92, south_return_height, 0.05)

	inner_left_door = MeshInstance3D.new()
	inner_left_door.name = "InnerLeftDoor"
	inner_left_door.mesh = inner_leaf_box
	inner_left_door.position = Vector3(-0.46, south_return_height * 0.5, CAB_DEPTH * 0.5)
	inner_left_door.material_override = mat_doors
	inner_left_door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(inner_left_door)

	inner_right_door = MeshInstance3D.new()
	inner_right_door.name = "InnerRightDoor"
	inner_right_door.mesh = inner_leaf_box
	inner_right_door.position = Vector3(0.46, south_return_height * 0.5, CAB_DEPTH * 0.5)
	inner_right_door.material_override = mat_doors
	inner_right_door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_visual_root.add_child(inner_right_door)

	# 7. Handrails on 3 Walls (Matching Reference Image 1)
	handrail_root = Node3D.new()
	handrail_root.name = "HandrailRoot"
	cab_visual_root.add_child(handrail_root)
	_build_handrails()

	# 8. Indicator Panel on North Wall (Top center)
	indicator_root = Node3D.new()
	indicator_root.name = "IndicatorRoot"
	indicator_root.position = Vector3(0.0, CAB_HEIGHT - 0.5, -CAB_DEPTH * 0.5 + 0.06)
	cab_visual_root.add_child(indicator_root)

	var ind_housing := MeshInstance3D.new()
	var house_box := BoxMesh.new()
	house_box.size = Vector3(1.8, 0.12, 0.04)
	ind_housing.mesh = house_box
	ind_housing.material_override = mat_housing
	ind_housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	indicator_root.add_child(ind_housing)

	indicator_leds.clear()
	var dot_count := total_indicator_floors
	var dot_span := 1.5
	var dot_step := dot_span / float(maxi(1, dot_count - 1))
	var dot_start_x := -dot_span * 0.5
	var dot_mesh := BoxMesh.new()
	dot_mesh.size = Vector3(0.07, 0.05, 0.02)

	for i in dot_count:
		var led := MeshInstance3D.new()
		led.name = "CabLed_%d" % i
		led.mesh = dot_mesh
		led.position = Vector3(dot_start_x + i * dot_step, 0.0, 0.025)
		led.material_override = mat_led_off
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		indicator_root.add_child(led)
		indicator_leds.append(led)

	indicator_label = Label3D.new()
	indicator_label.name = "CabIndicatorLabel"
	indicator_label.text = "%dF" % (current_floor_index + 1)
	indicator_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	indicator_label.font_size = 20
	indicator_label.pixel_size = 0.007
	indicator_label.outline_size = 4
	indicator_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicator_label.position = Vector3(0.0, 0.18, 0.02)
	indicator_root.add_child(indicator_label)

	# 9. Surveillance Camera mounted from ceiling on North Wall
	cab_camera_root = Node3D.new()
	cab_camera_root.name = "CabCameraRoot"
	cab_camera_root.position = Vector3(0.08, CAB_HEIGHT - 0.18, -CAB_DEPTH * 0.5 + 0.15)
	cab_camera_root.rotation_degrees = Vector3(-45.0, 10.0, 0.0)
	cab_visual_root.add_child(cab_camera_root)

	var cam_arm := MeshInstance3D.new()
	var cam_arm_box := BoxMesh.new()
	cam_arm_box.size = Vector3(0.04, 0.12, 0.04)
	cam_arm.mesh = cam_arm_box
	cam_arm.position = Vector3(0.0, 0.06, -0.02)
	cam_arm.material_override = mat_camera
	cam_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_camera_root.add_child(cam_arm)

	var cam_body := MeshInstance3D.new()
	var cam_body_box := BoxMesh.new()
	cam_body_box.size = Vector3(0.12, 0.10, 0.20)
	cam_body.mesh = cam_body_box
	cam_body.material_override = mat_camera
	cam_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_camera_root.add_child(cam_body)

	# 10. Card Reader Panel on North center strip
	cab_reader_root = Node3D.new()
	cab_reader_root.name = "CabReaderRoot"
	cab_reader_root.position = Vector3(0.0, 1.25, -CAB_DEPTH * 0.5 + 0.08)
	cab_visual_root.add_child(cab_reader_root)

	var reader_body := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(0.18, 0.30, 0.04)
	reader_body.mesh = r_box
	reader_body.material_override = mat_reader
	reader_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_reader_root.add_child(reader_body)

	var reader_sensor := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.10, 0.10, 0.02)
	reader_sensor.mesh = s_box
	reader_sensor.position = Vector3(0.0, 0.04, 0.025)
	var std_yellow := StandardMaterial3D.new()
	std_yellow.albedo_color = Color(0.95, 0.75, 0.2, 1.0)
	std_yellow.emission_enabled = true
	std_yellow.emission = Color(0.95, 0.75, 0.2)
	std_yellow.emission_energy_multiplier = 1.5
	reader_sensor.material_override = std_yellow
	reader_sensor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_reader_root.add_child(reader_sensor)

	# 11. Interior Lighting (Ceiling remains open for isometric camera visibility)
	cab_light = OmniLight3D.new()
	cab_light.name = "CabInteriorLight"
	cab_light.position = Vector3(0.0, CAB_HEIGHT - 0.2, 0.0)
	cab_light.light_color = Color(0.92, 0.96, 1.0, 1.0)
	cab_light.light_energy = 2.2
	cab_light.omni_range = 5.5
	cab_light.omni_attenuation = 1.0
	cab_light.shadow_enabled = false
	cab_visual_root.add_child(cab_light)


func _build_handrails() -> void:
	var rail_height := 0.95
	var rail_thickness := 0.05
	var standoff_mesh := BoxMesh.new()
	standoff_mesh.size = Vector3(0.03, 0.03, 0.08)

	# North (Back) Handrail
	var north_rail := MeshInstance3D.new()
	north_rail.name = "NorthHandrail"
	var n_box := BoxMesh.new()
	n_box.size = Vector3(CAB_WIDTH - 0.4, rail_thickness, rail_thickness)
	north_rail.mesh = n_box
	north_rail.position = Vector3(0.0, rail_height, -CAB_DEPTH * 0.5 + 0.14)
	north_rail.material_override = mat_handrail
	north_rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	handrail_root.add_child(north_rail)

	# North Standoffs
	for sx in [-1.2, -0.4, 0.4, 1.2]:
		var so := MeshInstance3D.new()
		so.mesh = standoff_mesh
		so.position = Vector3(sx, rail_height, -CAB_DEPTH * 0.5 + 0.08)
		so.material_override = mat_handrail
		so.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		handrail_root.add_child(so)

	# West (Left) Handrail
	var west_rail := MeshInstance3D.new()
	west_rail.name = "WestHandrail"
	var w_box := BoxMesh.new()
	w_box.size = Vector3(rail_thickness, rail_thickness, CAB_DEPTH - 0.4)
	west_rail.mesh = w_box
	west_rail.position = Vector3(-CAB_WIDTH * 0.5 + 0.08, rail_height, 0.0)
	west_rail.material_override = mat_handrail
	west_rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	handrail_root.add_child(west_rail)

	# West Standoffs
	var so_side_mesh := BoxMesh.new()
	so_side_mesh.size = Vector3(0.08, 0.03, 0.03)
	for sz in [-0.8, 0.0, 0.8]:
		var so := MeshInstance3D.new()
		so.mesh = so_side_mesh
		so.position = Vector3(-CAB_WIDTH * 0.5 + 0.04, rail_height, sz)
		so.material_override = mat_handrail
		so.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		handrail_root.add_child(so)

	# East (Right) Handrail
	var east_rail := MeshInstance3D.new()
	east_rail.name = "EastHandrail"
	east_rail.mesh = w_box
	east_rail.position = Vector3(CAB_WIDTH * 0.5 - 0.08, rail_height, 0.0)
	east_rail.material_override = mat_handrail
	east_rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	handrail_root.add_child(east_rail)

	# East Standoffs
	for sz in [-0.8, 0.0, 0.8]:
		var so := MeshInstance3D.new()
		so.mesh = so_side_mesh
		so.position = Vector3(CAB_WIDTH * 0.5 - 0.04, rail_height, sz)
		so.material_override = mat_handrail
		so.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		handrail_root.add_child(so)


## Setup 2D boundaries in GameplayWorld so player is contained in cab
func setup_gameplay_boundaries(p_parent: Node, center_2d: Vector2) -> void:
	if boundary_root_2d != null and is_instance_valid(boundary_root_2d):
		boundary_root_2d.queue_free()

	boundary_root_2d = Node2D.new()
	boundary_root_2d.name = "CabGameplayBoundaries"
	boundary_root_2d.position = center_2d
	p_parent.add_child(boundary_root_2d)
	# Gameplay X/Y is projected through the rotated floor's X/Z basis. Cancel
	# that yaw in the 2D cab limits so movement/collision still matches this
	# screen-fixed 3D cabin, rather than the 45-degree building axes.
	var floor_x := get_parent_node_3d().global_basis.x.normalized()
	boundary_root_2d.rotation = -atan2(floor_x.z, floor_x.x)

	# North Boundary (-Y in 2D) - Inner edge at y = -38.0px
	boundary_north = _create_boundary_body(Vector2(0.0, -54.0), Vector2(200.0, 32.0))
	boundary_root_2d.add_child(boundary_north)

	# West Boundary (-X in 2D) - Inner edge at x = -53.0px
	boundary_west = _create_boundary_body(Vector2(-69.0, 0.0), Vector2(32.0, 160.0))
	boundary_root_2d.add_child(boundary_west)

	# East Boundary (+X in 2D) - Inner edge at x = +53.0px
	boundary_east = _create_boundary_body(Vector2(69.0, 0.0), Vector2(32.0, 160.0))
	boundary_root_2d.add_child(boundary_east)

	# South Boundary (+Y in 2D - the doorway barrier when closed) - Inner edge at y = +38.0px
	boundary_south = StaticBody2D.new()
	boundary_south.name = "CabBoundarySouth"
	boundary_south.position = Vector2(0.0, 54.0)
	boundary_south.collision_layer = WORLD_WALL_LAYER
	boundary_south.collision_mask = 0

	south_collider_shape = CollisionShape2D.new()
	var s_box := RectangleShape2D.new()
	s_box.size = Vector2(200.0, 32.0)
	south_collider_shape.shape = s_box
	boundary_south.add_child(south_collider_shape)
	boundary_root_2d.add_child(boundary_south)


func _create_boundary_body(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = WORLD_WALL_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	return body


func get_camera_focus_world() -> Vector3:
	return global_position + Vector3(0.0, 1.2, 0.0)


func get_player_initial_position_2d() -> Vector2:
	if boundary_root_2d != null and is_instance_valid(boundary_root_2d):
		# Start near south entrance facing north (y = +22.0 px relative to cab center)
		return boundary_root_2d.to_global(Vector2(0.0, 22.0))
	var map_position := get_parent_node_3d().to_local(global_position)
	return Vector2(map_position.x, map_position.z) * CELL_PIXELS


func get_door_threshold_2d() -> Vector2:
	if boundary_root_2d != null and is_instance_valid(boundary_root_2d):
		return boundary_root_2d.to_global(Vector2(0.0, 28.0))
	var map_position := get_parent_node_3d().to_local(global_position)
	return Vector2(map_position.x, map_position.z) * CELL_PIXELS


func update_indicator(floor_idx: int) -> void:
	current_floor_index = floor_idx
	if indicator_label != null:
		indicator_label.text = "%dF" % (floor_idx + 1)

	var active_slot := clampi(floor_idx, 0, indicator_leds.size() - 1)
	for i in indicator_leds.size():
		indicator_leds[i].material_override = mat_led_on if i == active_slot else mat_led_off


func step_indicator_to(target_floor_idx: int, duration: float = 0.8) -> void:
	var start_idx := current_floor_index
	current_floor_index = target_floor_idx
	var steps := absi(target_floor_idx - start_idx)
	if steps == 0:
		update_indicator(target_floor_idx)
		return

	var step_delay := duration / float(steps)
	var tween := create_tween()
	var dir := 1 if target_floor_idx > start_idx else -1
	for s in steps:
		var cur := start_idx + (s + 1) * dir
		tween.tween_callback(func(): update_indicator(cur))
		if s < steps - 1:
			tween.tween_interval(step_delay)


func set_south_gate_enabled(p_enabled: bool) -> void:
	if south_collider_shape != null and is_instance_valid(south_collider_shape):
		south_collider_shape.set_deferred("disabled", not p_enabled)


func open_cab_doors(duration: float = 0.45) -> Signal:
	if doors_open:
		return cab_doors_opened
	doors_open = true
	set_south_gate_enabled(false)

	if door_tween != null and door_tween.is_valid():
		door_tween.kill()
	door_tween = create_tween().set_parallel(true)
	door_tween.tween_property(inner_left_door, "position:x", -1.35, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	door_tween.tween_property(inner_right_door, "position:x", 1.35, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	door_tween.chain().tween_callback(func():
		cab_doors_opened.emit()
	)
	return cab_doors_opened


func close_cab_doors(duration: float = 0.45) -> Signal:
	if not doors_open:
		return cab_doors_closed
	doors_open = false

	if door_tween != null and door_tween.is_valid():
		door_tween.kill()
	door_tween = create_tween().set_parallel(true)
	door_tween.tween_property(inner_left_door, "position:x", -0.46, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	door_tween.tween_property(inner_right_door, "position:x", 0.46, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	door_tween.chain().tween_callback(func():
		set_south_gate_enabled(true)
		cab_doors_closed.emit()
	)
	return cab_doors_closed


## Auto-guide player from current position inside cab to the south exit door
func guide_player_to_exit(player: Node2D, duration: float = 0.5) -> Signal:
	if player_guide_tween != null and player_guide_tween.is_valid():
		player_guide_tween.kill()

	var target_pos := get_door_threshold_2d()
	player_guide_tween = create_tween()
	player_guide_tween.tween_property(player, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	player_guide_tween.tween_callback(func():
		# Ensure player faces South (+Y)
		if player.has_node("Sprite2D"):
			pass
		player_guided_to_exit.emit()
	)
	return player_guided_to_exit


## Spatially dock this cab directly behind a floor door
func dock_to_floor_door(floor_door: Node3D) -> void:
	if floor_door == null or not is_instance_valid(floor_door):
		return
	var door_yaw: float = floor_door.global_rotation.y
	# In cab local space: the door is on South (+Z).
	# To align cab door with floor door, cab is offset into the wall opposite to the door's outward normal.
	var inward_3d: Vector3 = -floor_door.global_transform.basis.z.normalized()
	# Position cab center set back by half cab depth so front returns sit flush against door frame plane
	var cab_pos: Vector3 = floor_door.global_position + inward_3d * (CAB_DEPTH * 0.5 + 0.05)
	global_position = cab_pos
	global_rotation.y = door_yaw
	if boundary_root_2d != null and is_instance_valid(boundary_root_2d):
		var map_position := get_parent_node_3d().to_local(cab_pos)
		boundary_root_2d.global_position = Vector2(map_position.x, map_position.z) * CELL_PIXELS


func cleanup_gameplay() -> void:
	if boundary_root_2d != null and is_instance_valid(boundary_root_2d):
		boundary_root_2d.queue_free()
		boundary_root_2d = null
