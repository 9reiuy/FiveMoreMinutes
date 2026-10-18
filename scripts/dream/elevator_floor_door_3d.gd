class_name ElevatorFloorDoor3D
extends Node3D

## Low-pixel 3D Elevator Floor Door (Reference Image 2 style)
## Supports UP (North entrance) and DOWN (South entrance) orientations.
## Includes a shallow lit doorway; the transition cab remains a separate scene.

signal approach_entered(player: Node)
signal approach_exited(player: Node)
signal doors_opened
signal doors_closed

enum Orientation {
	UP,   ## North entrance (player walks UP/-Y into door from corridor)
	DOWN  ## South entrance (player walks DOWN/+Y into door from corridor)
}

enum State {
	LOCKED,     ## Closed, requires badge
	UNLOCKED,   ## Closed, badge held or floor completed
	OPENING,
	OPEN,
	CLOSING,
	CLOSED
}

const CELL_PIXELS := 32.0
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 2.6
const WALL_THICKNESS := 0.5
const WORLD_WALL_LAYER := 4

@export var door_orientation: int = Orientation.UP
@export var current_floor_index: int = 0
@export var total_indicator_floors: int = 10

var current_state: State = State.LOCKED
var doors_open := false
var doorway_inward_2d := Vector2.UP
var _doorway_inward_explicit := false
var opening_width := DOOR_WIDTH
var wall_depth := WALL_THICKNESS
var _gameplay_door_position_2d := Vector2.ZERO
var _has_gameplay_door_position := false

# 3D Node references
var frame_root: Node3D
var sliding_door_root: Node3D
var left_door_mesh: MeshInstance3D
var right_door_mesh: MeshInstance3D
var indicator_root: Node3D
var indicator_label: Label3D
var indicator_leds: Array[MeshInstance3D] = []
var card_reader_root: Node3D
var card_reader_sensor: MeshInstance3D
var camera_root: Node3D
var industrial_facade: Node3D

# 2D Gameplay references
var door_collider_2d: StaticBody2D
var door_shape_2d: CollisionShape2D
var approach_trigger_2d: Area2D
var approach_shape_2d: CollisionShape2D

# Animation tween
var door_tween: Tween

# Materials
var mat_frame: Material
var mat_doors: Material
var mat_housing: Material
var mat_led_off: Material
var mat_led_on: Material
var mat_reader: Material
var mat_sensor_locked: Material
var mat_sensor_unlocked: Material
var mat_camera: Material
var mat_shaft: Material


func _init(p_orientation: int = Orientation.UP, p_floor_index: int = 0) -> void:
	name = "ElevatorFloorDoor3D"
	door_orientation = p_orientation as Orientation
	doorway_inward_2d = Vector2.UP if door_orientation == Orientation.UP else Vector2.DOWN
	current_floor_index = p_floor_index
	_init_materials()
	_build_3d_visuals()
	industrial_facade=preload("res://scripts/dream/elevator_freight_facade.gd").new()
	add_child(industrial_facade)
	industrial_facade.configure(self)


func _ready() -> void:
	# Only structural panels enter the shadow map; LEDs, reader, camera and
	# other small decorations keep their deliberately disabled shadow setting.
	for panel_name in ["ShaftBacking", "ShaftReturnLeft", "ShaftReturnRight", "FramePostLeft", "FramePostRight", "FrameLintelTop"]:
		var panel := frame_root.get_node_or_null(panel_name) as MeshInstance3D
		if panel != null:
			preload("res://scripts/dream/solid_shadow_caster_3d.gd").attach(panel)
	preload("res://scripts/dream/solid_shadow_caster_3d.gd").attach(left_door_mesh)
	preload("res://scripts/dream/solid_shadow_caster_3d.gd").attach(right_door_mesh)
	_update_orientation_transforms()
	update_state(current_state)
	update_indicator(current_floor_index)


func _init_materials() -> void:
	var pixel_mats := preload("res://scripts/dream/office_pixel_materials.gd")
	mat_frame = pixel_mats.make(Color(0.20, 0.26, 0.31), "metal", true)
	mat_doors = pixel_mats.make(Color(0.16, 0.20, 0.24), "metal", true)
	mat_housing = pixel_mats.make(Color(0.24, 0.28, 0.34), "metal", true)
	mat_reader = pixel_mats.make(Color(0.30, 0.35, 0.42), "metal", true)
	mat_camera = pixel_mats.make(Color(0.18, 0.20, 0.24), "metal", true)

	var std_shaft := StandardMaterial3D.new()
	std_shaft.albedo_color = Color(0.07, 0.08, 0.10, 1.0)
	std_shaft.roughness = 0.9
	mat_shaft = std_shaft

	var std_led_off := StandardMaterial3D.new()
	std_led_off.albedo_color = Color(0.28, 0.32, 0.38, 1.0)
	std_led_off.roughness = 0.5
	mat_led_off = std_led_off

	var std_led_on := StandardMaterial3D.new()
	std_led_on.albedo_color = Color(0.4, 0.95, 0.35, 1.0)
	std_led_on.emission_enabled = true
	std_led_on.emission = Color(0.4, 0.95, 0.35)
	std_led_on.emission_energy_multiplier = 2.0
	mat_led_on = std_led_on

	var std_sensor_locked := StandardMaterial3D.new()
	std_sensor_locked.albedo_color = Color(0.9, 0.3, 0.25, 1.0)
	std_sensor_locked.emission_enabled = true
	std_sensor_locked.emission = Color(0.9, 0.3, 0.25)
	std_sensor_locked.emission_energy_multiplier = 1.2
	mat_sensor_locked = std_sensor_locked

	var std_sensor_unlocked := StandardMaterial3D.new()
	std_sensor_unlocked.albedo_color = Color(0.3, 0.85, 0.4, 1.0)
	std_sensor_unlocked.emission_enabled = true
	std_sensor_unlocked.emission = Color(0.3, 0.85, 0.4)
	std_sensor_unlocked.emission_energy_multiplier = 1.2
	mat_sensor_unlocked = std_sensor_unlocked


func _build_3d_visuals() -> void:
	# 1. Door Frame / Architrave
	frame_root = Node3D.new()
	frame_root.name = "FrameRoot"
	add_child(frame_root)

	# Dark Shaft Backing (Clean recessed dark elevator shaft behind the door frame)
	var shaft_backing := MeshInstance3D.new()
	shaft_backing.name = "ShaftBacking"
	var shaft_plane := QuadMesh.new()
	# A one-sided recessed shaft plane: the corridor sees a dark interior,
	# while a camera behind the shaft can still see the actual moving leaves.
	shaft_plane.size = Vector2(DOOR_WIDTH + 0.02, DOOR_HEIGHT)
	shaft_backing.mesh = shaft_plane
	shaft_backing.position = Vector3(0.0, DOOR_HEIGHT * 0.5, -WALL_THICKNESS * 0.40)
	shaft_backing.material_override = mat_shaft
	shaft_backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame_root.add_child(shaft_backing)
	for side in [-1.0, 1.0]:
		var return_mesh := MeshInstance3D.new()
		return_mesh.name = "ShaftReturnLeft" if side < 0.0 else "ShaftReturnRight"
		var return_box := BoxMesh.new()
		return_box.size = Vector3(0.035, DOOR_HEIGHT, WALL_THICKNESS)
		return_mesh.mesh = return_box
		return_mesh.position = Vector3(side * DOOR_WIDTH * 0.5, DOOR_HEIGHT * 0.5, 0.0)
		return_mesh.material_override = mat_shaft
		return_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frame_root.add_child(return_mesh)

	# Left Post
	var left_post := MeshInstance3D.new()
	left_post.name = "FramePostLeft"
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.24, DOOR_HEIGHT, WALL_THICKNESS)
	left_post.mesh = post_mesh
	left_post.position = Vector3(-1.62, DOOR_HEIGHT * 0.5, 0.0)
	left_post.material_override = mat_frame
	left_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame_root.add_child(left_post)

	# Right Post (wider on right to seat card reader, like Image 2)
	var right_post := MeshInstance3D.new()
	right_post.name = "FramePostRight"
	var r_post_mesh := BoxMesh.new()
	r_post_mesh.size = Vector3(0.34, DOOR_HEIGHT, WALL_THICKNESS)
	right_post.mesh = r_post_mesh
	right_post.position = Vector3(1.67, DOOR_HEIGHT * 0.5, 0.0)
	right_post.material_override = mat_frame
	right_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame_root.add_child(right_post)

	# Top Lintel
	var top_lintel := MeshInstance3D.new()
	top_lintel.name = "FrameLintelTop"
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(3.64, 0.38, WALL_THICKNESS)
	top_lintel.mesh = lintel_mesh
	top_lintel.position = Vector3(0.025, DOOR_HEIGHT + 0.19, 0.0)
	top_lintel.material_override = mat_frame
	top_lintel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame_root.add_child(top_lintel)

	# 2. Sliding Double Doors
	sliding_door_root = Node3D.new()
	sliding_door_root.name = "SlidingDoorRoot"
	add_child(sliding_door_root)

	var door_leaf_width := 1.52
	var door_leaf_mesh := BoxMesh.new()
	door_leaf_mesh.size = Vector3(door_leaf_width, DOOR_HEIGHT - 0.04, 0.06)
	var leaf_depth := WALL_THICKNESS * 0.5 - door_leaf_mesh.size.z * 0.5

	left_door_mesh = MeshInstance3D.new()
	left_door_mesh.name = "LeftDoorMesh"
	left_door_mesh.mesh = door_leaf_mesh
	left_door_mesh.position = Vector3(-0.75, DOOR_HEIGHT * 0.5, leaf_depth)
	left_door_mesh.material_override = mat_doors
	left_door_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sliding_door_root.add_child(left_door_mesh)

	right_door_mesh = MeshInstance3D.new()
	right_door_mesh.name = "RightDoorMesh"
	right_door_mesh.mesh = door_leaf_mesh
	right_door_mesh.position = Vector3(0.75, DOOR_HEIGHT * 0.5, leaf_depth)
	right_door_mesh.material_override = mat_doors
	right_door_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sliding_door_root.add_child(right_door_mesh)

	# 3. Horizontal Indicator Panel (mounted on front face of top lintel)
	indicator_root = Node3D.new()
	indicator_root.name = "IndicatorRoot"
	# Mount the indicator just outside the shared wall/frame front plane.
	indicator_root.position = Vector3(0.0, DOOR_HEIGHT + 0.19, WALL_THICKNESS * 0.5 + 0.105)
	add_child(indicator_root)

	var ind_housing := MeshInstance3D.new()
	ind_housing.name = "IndicatorHousing"
	var house_mesh := BoxMesh.new()
	house_mesh.size = Vector3(2.4, 0.14, 0.04)
	ind_housing.mesh = house_mesh
	ind_housing.material_override = mat_housing
	ind_housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	indicator_root.add_child(ind_housing)

	# Segmented LED dots array
	indicator_leds.clear()
	var dot_count := total_indicator_floors
	var dot_span := 2.0
	var dot_step := dot_span / float(maxi(1, dot_count - 1))
	var dot_start_x := -dot_span * 0.5
	var dot_mesh := BoxMesh.new()
	dot_mesh.size = Vector3(0.08, 0.06, 0.02)

	for i in dot_count:
		var led := MeshInstance3D.new()
		led.name = "LedDot_%d" % i
		led.mesh = dot_mesh
		led.position = Vector3(dot_start_x + i * dot_step, 0.0, 0.022)
		led.material_override = mat_led_off
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		indicator_root.add_child(led)
		indicator_leds.append(led)

	# Indicator Text Label above panel
	indicator_label = Label3D.new()
	indicator_label.name = "IndicatorLabel"
	indicator_label.text = "%dF" % (current_floor_index + 1)
	indicator_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	indicator_label.font_size = 20
	indicator_label.pixel_size = 0.007
	indicator_label.outline_size = 4
	indicator_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicator_label.position = Vector3(0.0, 0.16, 0.04)
	indicator_root.add_child(indicator_label)

	# 4. Card Reader (Mounted on front face of Right frame post)
	card_reader_root = Node3D.new()
	card_reader_root.name = "CardReaderRoot"
	# Right post front face shares the wall plane; only the reader protrudes.
	card_reader_root.position = Vector3(1.67, 1.15, WALL_THICKNESS * 0.5 + 0.125)
	add_child(card_reader_root)

	var reader_mesh := BoxMesh.new()
	reader_mesh.size = Vector3(0.18, 0.32, 0.05)
	var reader_body := MeshInstance3D.new()
	reader_body.name = "ReaderBody"
	reader_body.mesh = reader_mesh
	reader_body.material_override = mat_reader
	reader_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card_reader_root.add_child(reader_body)

	var sensor_mesh := BoxMesh.new()
	sensor_mesh.size = Vector3(0.10, 0.10, 0.02)
	card_reader_sensor = MeshInstance3D.new()
	card_reader_sensor.name = "ReaderSensor"
	card_reader_sensor.mesh = sensor_mesh
	card_reader_sensor.position = Vector3(0.0, 0.04, 0.03)
	card_reader_sensor.material_override = mat_sensor_locked
	card_reader_sensor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card_reader_root.add_child(card_reader_sensor)

	# 5. Surveillance Camera (Mounted above lintel)
	camera_root = Node3D.new()
	camera_root.name = "SurveillanceCameraRoot"
	camera_root.position = Vector3(0.4, DOOR_HEIGHT + 0.38, WALL_THICKNESS * 0.5 + 0.05)
	camera_root.rotation_degrees = Vector3(-35.0, 15.0, 0.0)
	add_child(camera_root)

	var cam_arm_mesh := BoxMesh.new()
	cam_arm_mesh.size = Vector3(0.05, 0.14, 0.05)
	var cam_arm := MeshInstance3D.new()
	cam_arm.mesh = cam_arm_mesh
	cam_arm.position = Vector3(0.0, 0.07, -0.04)
	cam_arm.material_override = mat_camera
	cam_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera_root.add_child(cam_arm)

	var cam_body_mesh := BoxMesh.new()
	cam_body_mesh.size = Vector3(0.14, 0.12, 0.24)
	var cam_body := MeshInstance3D.new()
	cam_body.mesh = cam_body_mesh
	cam_body.material_override = mat_camera
	cam_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera_root.add_child(cam_body)

	var lens_mesh := BoxMesh.new()
	lens_mesh.size = Vector3(0.09, 0.09, 0.02)
	var cam_lens := MeshInstance3D.new()
	cam_lens.mesh = lens_mesh
	cam_lens.position = Vector3(0.0, 0.0, 0.121)
	var std_lens := StandardMaterial3D.new()
	std_lens.albedo_color = Color(0.3, 0.6, 0.8, 1.0)
	cam_lens.material_override = std_lens
	cam_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera_root.add_child(cam_lens)
	_update_opening_geometry()


func configure_opening(width_world: float, wall_thickness_world: float = WALL_THICKNESS) -> void:
	# The generator's opening may be two, three or four cells wide. Keep the
	# facade, leaves, wall returns and gameplay throat on that same span.
	opening_width = maxf(width_world, 1.0)
	wall_depth = maxf(wall_thickness_world, 0.1)
	_update_opening_geometry()
	if is_instance_valid(door_shape_2d):
		var door_box := door_shape_2d.shape as RectangleShape2D
		if door_box != null:
			door_box.size = Vector2(opening_width * CELL_PIXELS + 8.0, wall_depth * CELL_PIXELS + 8.0)
	if is_instance_valid(approach_shape_2d):
		var approach_box := approach_shape_2d.shape as RectangleShape2D
		if approach_box != null:
			approach_box.size = Vector2(opening_width * CELL_PIXELS + 16.0, approach_box.size.y)


func _update_opening_geometry() -> void:
	if frame_root == null or left_door_mesh == null:
		return
	var half_width := opening_width * 0.5
	var leaf_box := left_door_mesh.mesh as BoxMesh
	var leaf_width := half_width + 0.02
	leaf_box.size = Vector3(leaf_width, leaf_box.size.y, leaf_box.size.z)
	# The sliding panels sit just behind the shared corridor-side wall plane.
	var leaf_z := wall_depth * 0.5 - leaf_box.size.z * 0.5 - 0.02
	var leaf_x := _door_leaf_open_offset() if doors_open else opening_width * 0.25
	left_door_mesh.position = Vector3(-leaf_x, DOOR_HEIGHT * 0.5, leaf_z)
	right_door_mesh.position = Vector3(leaf_x, DOOR_HEIGHT * 0.5, leaf_z)

	var backing := frame_root.get_node(^"ShaftBacking") as MeshInstance3D
	(backing.mesh as QuadMesh).size.x = opening_width + 0.02
	backing.position.z = -wall_depth * 0.40
	for side in [-1.0, 1.0]:
		var side_name := ^"ShaftReturnLeft" if side < 0.0 else ^"ShaftReturnRight"
		var shaft_return := frame_root.get_node(side_name) as MeshInstance3D
		(shaft_return.mesh as BoxMesh).size.z = wall_depth
		shaft_return.position.x = side * half_width

	# Each jamb projects slightly into the opening, rather than disappearing
	# behind the wall's last full-height segment.
	var left_post := frame_root.get_node(^"FramePostLeft") as MeshInstance3D
	var right_post := frame_root.get_node(^"FramePostRight") as MeshInstance3D
	(left_post.mesh as BoxMesh).size.z = wall_depth
	(right_post.mesh as BoxMesh).size.z = wall_depth
	left_post.position.x = -half_width + 0.06
	right_post.position.x = half_width - 0.06
	var lintel := frame_root.get_node(^"FrameLintelTop") as MeshInstance3D
	(lintel.mesh as BoxMesh).size = Vector3(opening_width + 0.17, 0.38, wall_depth)
	lintel.position.x = 0.025

	indicator_root.position.z = wall_depth * 0.5 + 0.105
	var indicator_housing := indicator_root.get_node(^"IndicatorHousing") as MeshInstance3D
	var housing_width := minf(2.4, opening_width - 0.3)
	var housing_box := indicator_housing.mesh as BoxMesh
	housing_box.size = Vector3(housing_width, housing_box.size.y, housing_box.size.z)
	var dot_span := housing_width - 0.4
	for i in indicator_leds.size():
		indicator_leds[i].position.x = -dot_span * 0.5 + float(i) * dot_span / float(maxi(1, indicator_leds.size() - 1))
	card_reader_root.position.x = half_width - 0.06
	card_reader_root.position.z = wall_depth * 0.5 + 0.125
	camera_root.position.x = minf(0.4, opening_width * 0.15)
	camera_root.position.z = wall_depth * 0.5 + 0.05
	if is_instance_valid(industrial_facade): industrial_facade.refresh()


func _door_leaf_open_offset() -> float:
	return opening_width * 0.5 + (opening_width * 0.5 + 0.02) * 0.5 - 0.10


func configure_entrance(inward_2d: Vector2, _screen_camera: Camera3D = null) -> void:
	# Keep the former camera argument for callers, but derive the facade's plane
	# from the same map-local doorway direction used by its gameplay collision.
	if inward_2d.length_squared() > 0.5:
		doorway_inward_2d = inward_2d.normalized()
		_doorway_inward_explicit = true
	if is_inside_tree():
		_update_orientation_transforms()
		_update_gameplay_2d_transforms()


func _update_orientation_transforms() -> void:
	if not _doorway_inward_explicit:
		doorway_inward_2d = Vector2.UP if door_orientation == Orientation.UP else Vector2.DOWN
	# The visible +Z face points toward the corridor (-inward). Use a local yaw
	# so the facade inherits the floor's 45-degree map rotation with the wall.
	rotation.y = atan2(-doorway_inward_2d.x, -doorway_inward_2d.y)
	# The dark shaft is always on the inward side of the leaves, including when
	# the doorway faces south; it must never cover the corridor-facing panels.
	var backing := frame_root.get_node_or_null(^"ShaftBacking") as Node3D
	if backing != null:
		backing.position.z = -wall_depth * 0.40


func get_inward_2d() -> Vector2:
	return doorway_inward_2d


func _get_gameplay_door_position_2d() -> Vector2:
	if _has_gameplay_door_position:
		return _gameplay_door_position_2d
	var map_position := get_parent_node_3d().to_local(global_position)
	return Vector2(map_position.x, map_position.z) * CELL_PIXELS


func get_doorway_threshold_position_2d() -> Vector2:
	# Position just inside the door threshold for walk-in target
	var inward := get_inward_2d()
	return _get_gameplay_door_position_2d() + inward * 0.8 * CELL_PIXELS


func get_corridor_approach_position_2d() -> Vector2:
	# Safe drop point outside in corridor for walk-out landing
	var inward := get_inward_2d()
	return _get_gameplay_door_position_2d() - inward * 1.5 * CELL_PIXELS


func _update_gameplay_2d_transforms() -> void:
	if not _has_gameplay_door_position:
		return
	var door_angle := doorway_inward_2d.angle() + PI * 0.5
	if is_instance_valid(door_collider_2d):
		door_collider_2d.position = _gameplay_door_position_2d
		door_collider_2d.rotation = door_angle
	if is_instance_valid(approach_trigger_2d):
		approach_trigger_2d.position = _gameplay_door_position_2d - doorway_inward_2d * 1.3 * CELL_PIXELS
		approach_trigger_2d.rotation = door_angle


## Connect 2D Gameplay Collision and Approach Trigger
func setup_gameplay_2d(p_collision_parent: Node, p_trigger_parent: Node, door_pos_2d: Vector2) -> void:
	# Clean up previous if any
	if door_collider_2d != null and is_instance_valid(door_collider_2d):
		door_collider_2d.queue_free()
	if approach_trigger_2d != null and is_instance_valid(approach_trigger_2d):
		approach_trigger_2d.queue_free()

	var inward := get_inward_2d()
	_gameplay_door_position_2d = door_pos_2d
	_has_gameplay_door_position = true
	var door_angle := inward.angle() + PI * 0.5

	# 1. 2D Collider for closed door (blocks player/bullets when closed)
	door_collider_2d = StaticBody2D.new()
	door_collider_2d.name = "ElevatorDoorCollider2D"
	door_collider_2d.position = door_pos_2d
	door_collider_2d.rotation = door_angle
	door_collider_2d.collision_layer = 0 if doors_open else WORLD_WALL_LAYER
	door_collider_2d.collision_mask = 0

	door_shape_2d = CollisionShape2D.new()
	door_shape_2d.name = "CollisionShape2D"
	var col_box := RectangleShape2D.new()
	col_box.size = Vector2(opening_width * CELL_PIXELS + 8.0, wall_depth * CELL_PIXELS + 8.0)
	door_shape_2d.shape = col_box
	door_shape_2d.disabled = doors_open
	door_collider_2d.add_child(door_shape_2d)
	p_collision_parent.add_child(door_collider_2d)

	# 2. 2D Approach Trigger in corridor
	approach_trigger_2d = Area2D.new()
	approach_trigger_2d.name = "ElevatorApproachTrigger2D"
	approach_trigger_2d.position = door_pos_2d - inward * 1.3 * CELL_PIXELS
	approach_trigger_2d.rotation = door_angle
	approach_trigger_2d.collision_layer = 0
	approach_trigger_2d.collision_mask = 1 # Player layer

	approach_shape_2d = CollisionShape2D.new()
	approach_shape_2d.name = "CollisionShape2D"
	var app_box := RectangleShape2D.new()
	app_box.size = Vector2(opening_width * CELL_PIXELS + 16.0, 2.0 * CELL_PIXELS)
	approach_shape_2d.shape = app_box
	approach_trigger_2d.add_child(approach_shape_2d)
	p_trigger_parent.add_child(approach_trigger_2d)

	approach_trigger_2d.body_entered.connect(_on_approach_body_entered)
	approach_trigger_2d.body_exited.connect(_on_approach_body_exited)


func _on_approach_body_entered(body: Node) -> void:
	approach_entered.emit(body)


func _on_approach_body_exited(body: Node) -> void:
	approach_exited.emit(body)


func update_state(p_state: State) -> void:
	current_state = p_state
	match current_state:
		State.LOCKED:
			card_reader_sensor.material_override = mat_sensor_locked
			if indicator_label != null:
				indicator_label.text = "需要员工工牌"
				indicator_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		State.UNLOCKED:
			card_reader_sensor.material_override = mat_sensor_unlocked
			if indicator_label != null:
				indicator_label.text = "%dF [READY]" % (current_floor_index + 1)
				indicator_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
		State.OPENING, State.OPEN:
			card_reader_sensor.material_override = mat_sensor_unlocked
			if indicator_label != null:
				indicator_label.text = "%dF" % (current_floor_index + 1)
				indicator_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
		State.CLOSING, State.CLOSED:
			card_reader_sensor.material_override = mat_sensor_locked


func update_indicator(floor_idx: int) -> void:
	current_floor_index = floor_idx
	if industrial_facade!=null: industrial_facade.update_number()
	if indicator_label != null:
		if current_state == State.LOCKED:
			indicator_label.text = "需要员工工牌"
			indicator_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		else:
			indicator_label.text = "%dF" % (floor_idx + 1)
			indicator_label.modulate = Color(0.4, 1.0, 0.5, 1.0)

	var active_slot := clampi(floor_idx, 0, indicator_leds.size() - 1)
	for i in indicator_leds.size():
		indicator_leds[i].material_override = mat_led_on if i == active_slot else mat_led_off


func open_doors(duration: float = 0.45) -> Signal:
	if doors_open and current_state == State.OPEN:
		return doors_opened
	current_state = State.OPENING
	if industrial_facade != null and industrial_facade.has_method("wake_facade_process"):
		industrial_facade.call("wake_facade_process")
	doors_open = true

	if door_collider_2d != null and is_instance_valid(door_collider_2d):
		door_collider_2d.set_deferred("collision_layer", 0)
	if door_shape_2d != null and is_instance_valid(door_shape_2d):
		door_shape_2d.set_deferred("disabled", true)

	if door_tween != null and door_tween.is_valid():
		door_tween.kill()
	door_tween = create_tween().set_parallel(true)
	door_tween.tween_property(left_door_mesh, "position:x", -_door_leaf_open_offset(), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	door_tween.tween_property(right_door_mesh, "position:x", _door_leaf_open_offset(), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	door_tween.chain().tween_callback(func():
		current_state = State.OPEN
		doors_opened.emit()
	)
	return doors_opened


func close_doors(duration: float = 0.45) -> Signal:
	if not doors_open and current_state == State.CLOSED:
		return doors_closed
	current_state = State.CLOSING
	if industrial_facade != null and industrial_facade.has_method("wake_facade_process"):
		industrial_facade.call("wake_facade_process")
	doors_open = false

	if door_tween != null and door_tween.is_valid():
		door_tween.kill()
	door_tween = create_tween().set_parallel(true)
	door_tween.tween_property(left_door_mesh, "position:x", -opening_width * 0.25, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	door_tween.tween_property(right_door_mesh, "position:x", opening_width * 0.25, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	door_tween.chain().tween_callback(func():
		current_state = State.CLOSED
		if door_collider_2d != null and is_instance_valid(door_collider_2d):
			door_collider_2d.set_deferred("collision_layer", WORLD_WALL_LAYER)
		if door_shape_2d != null and is_instance_valid(door_shape_2d):
			door_shape_2d.set_deferred("disabled", false)
		doors_closed.emit()
	)
	return doors_closed
