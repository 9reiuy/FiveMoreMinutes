extends Node3D

signal tutorial_finished
signal guide_spawn_completed

const CELL_PIXELS := 32.0
const ROOM_WIDTH := 22
const ROOM_HEIGHT := 48
const DOOR_OPENING_START := 10
const DOOR_OPENING_END := 13
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.1
const WALL_COLLISION_THICKNESS := 16.0
## The tutorial is authored along the 2D Y axis (mapped to 3D Z).  Keep the
## player a few cells inside the south wall, then lay every other waypoint out
## as a fraction of the real Spawn -> Door travel axis.  This makes the room
## lengthening a layout change rather than a root-scale trick.
const SPAWN_AXIS := float(ROOM_HEIGHT) - 4.0
const DOOR_AXIS := -0.5
const WASD_PROGRESS := 0.16
const GUIDE_TRIGGER_PROGRESS := 0.44
const GUIDE_PROGRESS := 0.46
const LIGHT_ONE_PROGRESS := 1.0 / 3.0
const LIGHT_TWO_PROGRESS := 2.0 / 3.0
const EXIT_TRIGGER_PROGRESS := 0.92
const PLAYER_SPAWN := Vector2((ROOM_WIDTH - 1) * 0.5, SPAWN_AXIS) * CELL_PIXELS
const GUIDE_POSITION := Vector2((ROOM_WIDTH - 1) * 0.5, SPAWN_AXIS - (SPAWN_AXIS - DOOR_AXIS) * GUIDE_PROGRESS) * CELL_PIXELS
const GUIDE_TRIGGER_POSITION := Vector2((ROOM_WIDTH - 1) * 0.5, SPAWN_AXIS - (SPAWN_AXIS - DOOR_AXIS) * GUIDE_TRIGGER_PROGRESS) * CELL_PIXELS
const EXIT_TRIGGER_POSITION := Vector2((ROOM_WIDTH - 1) * 0.5, SPAWN_AXIS - (SPAWN_AXIS - DOOR_AXIS) * EXIT_TRIGGER_PROGRESS) * CELL_PIXELS
const INTERACTION_PROMPT_OFFSET := Vector2(-64.0, -32.0)
const INTERACTION_PROMPT_SIZE := Vector2(128.0, 18.0)
const WORLD_WALL_LAYER := 4

const WALL_SCENE: PackedScene = preload("res://scenes/dream/3d/WallStraight3D.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const ACTOR_DEPTH_BRIDGE_SCENE: PackedScene = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const DASH_AIM_PRESENTATION_SCRIPT: Script = preload("res://scripts/dream/dream_dash_aim_presentation.gd")
const INTERACTION_RESOLVER_SCRIPT: Script = preload("res://scripts/dream/dream_interaction_resolver.gd")
const CRISP_INTERACTION_FONT: Script = preload("res://scripts/ui/crisp_interaction_font.gd")
const SMOKE_SCRIPT: Script = preload("res://scripts/dream/tutorial_smoke_burst.gd")
const FLOOR_BATCH_RENDERER: Script = preload("res://scripts/dream/dream_3d_floor_batch_renderer.gd")
const CEILING_LIGHTING_SCRIPT: Script = preload("res://scripts/dream/dream_3d_ceiling_lighting.gd")
const DIALOGUE_CAMERA_SCRIPT: Script = preload("res://scripts/dream/dream_3d_dialogue_camera.gd")
const CONFIG: DemoConfig = preload("res://resources/demo_config.tres")
const DREAM_GUN_ATLAS := preload("res://scripts/data/dream_gun_atlas.gd")
const DIALOGUE_CONVERSATION_MODE := 0
const DIALOGUE_SPEAKER_FOCUS_MODE := 1
## Match the Random Dream gameplay framing without changing the fixed camera
## angle or follow authority.  Dialogue's 0.80 factor is composed afterwards.
const GAMEPLAY_CAMERA_SIZE_MULTIPLIER := 0.5
const GAMEPLAY_CAMERA_FOV := 40.0

@onready var floor_root: Node3D = $TutorialGeometry/FloorRoot
@onready var wall_root: Node3D = $TutorialGeometry/WallRoot
@onready var door_root: Node3D = $TutorialGeometry/DoorRoot
@onready var gameplay_canvas: CanvasLayer = $GameplayCanvas
@onready var gameplay_world: Node2D = $GameplayCanvas/GameplayWorld
@onready var collision_root: Node2D = $GameplayCanvas/GameplayWorld/GeneratedCollisionRoot
@onready var player: CharacterBody2D = $GameplayCanvas/GameplayWorld/DreamPlayer
@onready var guide: TutorialGuide = $GameplayCanvas/GameplayWorld/TutorialGuide
@onready var guide_spawn_trigger: Area2D = $GameplayCanvas/GameplayWorld/GuideSpawnTrigger
@onready var exit_trigger: Area2D = $GameplayCanvas/GameplayWorld/TutorialExitTrigger
@onready var actor_depth_viewport: SubViewport = $ActorDepthViewport
@onready var actor_depth_render_root: Node2D = $ActorDepthViewport/ActorDepthRenderRoot
@onready var player_depth_bridge: Node3D = $PlayerDepthVisual3D
@onready var actor_depth_bridges_root: Node3D = $ActorDepthBridges
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_3d: Camera3D = $CameraRig/Camera3D
var audio_listener_3d: AudioListener3D
@onready var tutorial_floor_prompt: Label3D = $TutorialGeometry/TutorialFloorPrompt
@onready var interaction_prompt: Label = $GameplayUI/InteractionPrompt
@onready var dialogue_dialog: BedroomConfirmationDialog = $DialogueLayer/ConfirmationDialog
@onready var dialogue_bubble: DreamDialogueBubble = $DialogueLayer/DreamDialogueBubble
@onready var lighting_root: Node3D = $Lighting

var dialogue_controller: DreamDialogueController

var floor_cells: Dictionary = {}
## Shared floor batch renderer reads this flag to decide whether an empty
## presentation map is intentional.  Tutorial renders its authored floor
## immediately, so it is always the non-lazy path.
var lazy_room_presentation := false
var configured_weapon_id := "basic"
var profile_state: Dictionary = {}
var interaction_resolver: DreamInteractionResolver
var guide_spawned := false
var exit_sequence_started := false
var interaction_consumed_until_release := false
var camera_aim_offset := Vector3.ZERO
var night_lighting: Node3D
var tutorial_ceiling_lights: Node3D
var dialogue_camera: Node
var authoritative_camera_size := 0.0
var authoritative_camera_fov := GAMEPLAY_CAMERA_FOV
var _unknown_dialogue_speakers: Dictionary = {}
var dash_aim_presentation: Node2D
var dash_aim_depth_bridge: Node3D


func configure_tutorial(weapon_id: String, profile: Dictionary) -> void:
	configured_weapon_id = DREAM_GUN_ATLAS.sanitize_weapon_id(weapon_id)
	profile_state = profile


func _enter_tree() -> void:
	add_to_group(&"dream_world")


func _ready() -> void:
	preload("res://scripts/app/game_input_actions.gd").configure()
	interaction_prompt.add_theme_font_override(&"font", CRISP_INTERACTION_FONT.get_font())
	interaction_prompt.add_theme_font_size_override(&"font_size", 12)
	if camera_3d != null:
		# Capture the scene-authored value before any dialogue modifier is applied.
		authoritative_camera_size = camera_3d.size
		camera_3d.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera_3d.fov = GAMEPLAY_CAMERA_FOV
		authoritative_camera_fov = camera_3d.fov
	dialogue_camera = DIALOGUE_CAMERA_SCRIPT.new()
	dialogue_camera.name = "DialogueCameraModifier"
	camera_rig.add_child(dialogue_camera)
	dialogue_camera.call("configure", player, Callable(self, "_map_gameplay_to_world"))
	_build_fixed_room()
	_apply_authored_layout()
	player.set("selected_weapon_id", configured_weapon_id)
	player.configure_weapon(configured_weapon_id, CONFIG, profile_state.get("permanent_upgrades", {}))
	if player.has_method("configure_profile_stats"):
		player.call("configure_profile_stats", int(profile_state.get("character_hp_cells", CONFIG.character_card_default_hp_cells)))
	player.set_attacking_enabled(false)
	# Normal tutorial control teaches WASD plus the same tap/hold Space Dash used
	# by both Dream modes. Dialogue/exit locks below still disable it explicitly.
	player.set_dash_enabled(true)
	player.movement_enabled = true
	_enter_dream_time_mode()
	_configure_depth_visuals()
	_setup_dash_aim_presentation()
	_configure_lighting()
	interaction_resolver = INTERACTION_RESOLVER_SCRIPT.new()
	interaction_resolver.name = "DreamInteractionResolver"
	add_child(interaction_resolver)
	interaction_resolver.configure(player, [&"tutorial_interaction_targets"])
	guide.interaction_requested.connect(_on_guide_interaction_requested)
	guide_spawn_trigger.body_entered.connect(_on_guide_spawn_trigger_entered)
	exit_trigger.body_entered.connect(_on_exit_trigger_entered)
	_setup_dialogue_controller()
	if dialogue_dialog != null:
		dialogue_dialog.session_started.connect(_on_dialogue_session_started)
		dialogue_dialog.session_ended.connect(_on_dialogue_session_ended)
		if dialogue_dialog.has_signal("line_presented"):
			dialogue_dialog.line_presented.connect(_on_dialogue_line_presented)
	_update_camera_and_projection(0.0)
	_setup_3d_audio_listener()


func _exit_tree() -> void:
	if has_meta(&"display_reparenting"):
		return
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("clear_dialogue_focus")
	if dialogue_controller != null and is_instance_valid(dialogue_controller):
		dialogue_controller.dismiss_if_active()
	_exit_dream_time_mode()


func _setup_dialogue_controller() -> void:
	if dialogue_controller == null:
		dialogue_controller = DreamDialogueController.new()
		dialogue_controller.name = "DreamDialogueController"
		add_child(dialogue_controller)
		dialogue_controller.dialogue_line_started.connect(_on_controller_line_started)


func _on_controller_line_started(_line_index: int, line_data: Dictionary) -> void:
	var speaker_id := StringName(str(line_data.get("speaker", "guide")))
	var speaker := _resolve_dialogue_speaker(speaker_id)
	if speaker != null:
		set_dialogue_speaker(speaker)
	if line_data.has("expression") and speaker == guide and guide != null and is_instance_valid(guide):
		guide.set_expression(StringName(str(line_data["expression"])))


func _setup_3d_audio_listener() -> void:
	if camera_rig != null and is_instance_valid(camera_rig):
		var existing := camera_rig.get_node_or_null("AudioListener3D") as AudioListener3D
		if existing == null:
			audio_listener_3d = AudioListener3D.new()
			audio_listener_3d.name = "AudioListener3D"
			camera_rig.add_child(audio_listener_3d)
			audio_listener_3d.make_current()
		else:
			audio_listener_3d = existing
			audio_listener_3d.make_current()
	var vp := get_viewport()
	if vp != null:
		vp.audio_listener_enable_3d = true


func _process(delta: float) -> void:
	_update_camera_and_projection(_get_presentation_delta(delta))
	_update_dash_aim_presentation()

	if dialogue_controller != null and dialogue_controller.is_active():
		if not exit_sequence_started and player != null and guide != null:
			var dist: float = player.global_position.distance_to(guide.global_position)
			if dist > 160.0:
				dialogue_controller.dismiss_if_active()
		if dialogue_bubble != null and is_instance_valid(dialogue_bubble) and guide != null and is_instance_valid(guide) and player != null and camera_3d != null:
			var guide_world_pos: Vector3 = Vector3(guide.global_position.x / CELL_PIXELS, 1.1, guide.global_position.y / CELL_PIXELS)
			var guide_hud_pos: Vector2 = player.get_presentation_hud_position(camera_3d.unproject_position(guide_world_pos))
			dialogue_bubble.set_speaker_hud_position(guide_hud_pos)

			var player_world_pos: Vector3 = Vector3(player.global_position.x / CELL_PIXELS, 0.65, player.global_position.y / CELL_PIXELS)
			var player_hud_pos: Vector2 = player.get_presentation_hud_position(camera_3d.unproject_position(player_world_pos))
			dialogue_bubble.set_player_hud_position(player_hud_pos)

	if not Input.is_action_pressed("pickup_weapon"):
		interaction_consumed_until_release = false
	var is_ui_blocking: bool = exit_sequence_started or (dialogue_dialog != null and dialogue_dialog.visible) or (dialogue_controller != null and dialogue_controller.is_active())
	if is_ui_blocking:
		interaction_resolver.clear_target()
	else:
		interaction_resolver.update_target()
		if Input.is_action_just_pressed("pickup_weapon") and not interaction_consumed_until_release:
			var target := interaction_resolver.current_target
			if target != null and target.has_method("request_interaction"):
				interaction_consumed_until_release = true
				target.call("request_interaction", player)
	_update_interaction_prompt()


func _build_fixed_room() -> void:
	floor_cells.clear()
	for x in ROOM_WIDTH:
		for y in ROOM_HEIGHT:
			floor_cells[Vector2i(x, y)] = true
	FLOOR_BATCH_RENDERER.build(self)
	for x in ROOM_WIDTH:
		if x < DOOR_OPENING_START or x > DOOR_OPENING_END:
			_spawn_wall(Vector3(x, 0.0, -0.5), 0.0, "NorthWall_%02d" % x)
		_spawn_wall(Vector3(x, 0.0, ROOM_HEIGHT - 0.5), 0.0, "SouthWall_%02d" % x)
	for y in ROOM_HEIGHT:
		_spawn_wall(Vector3(-0.5, 0.0, y), PI * 0.5, "WestWall_%02d" % y)
		_spawn_wall(Vector3(ROOM_WIDTH - 0.5, 0.0, y), PI * 0.5, "EastWall_%02d" % y)
	_build_gameplay_boundaries()
	var door := DOOR_SCENE.instantiate() as PhysicalDoor3D
	if door != null:
		door.name = "TutorialExitDoor"
		# Tutorial uses the same four-cell throat as every generated 3D door.
		door.configure(4.0, WALL_HEIGHT, WALL_THICKNESS, "left", 9001)
		door.position = Vector3(11.5, 0.0, -0.5)
		door_root.add_child(door)
		door.configure_gameplay_collision(collision_root, CELL_PIXELS, WORLD_WALL_LAYER)


func _apply_authored_layout() -> void:
	# All gameplay and presentation waypoints are derived from the same travel
	# axis.  Keeping this in one place prevents a longer floor from leaving an
	# old trigger, Guide, or exit prompt in the first 16-cell segment.
	player.global_position = PLAYER_SPAWN
	guide.global_position = GUIDE_POSITION
	guide_spawn_trigger.position = GUIDE_TRIGGER_POSITION
	exit_trigger.position = EXIT_TRIGGER_POSITION
	if tutorial_floor_prompt != null:
		tutorial_floor_prompt.position = Vector3(
			(ROOM_WIDTH - 1) * 0.5,
			0.018,
			SPAWN_AXIS - (SPAWN_AXIS - DOOR_AXIS) * WASD_PROGRESS
		)


func _axis_at_progress(progress: float) -> float:
	return lerpf(SPAWN_AXIS, DOOR_AXIS, clampf(progress, 0.0, 1.0))


func _spawn_wall(position_3d: Vector3, yaw: float, node_name: String) -> void:
	var wall := WALL_SCENE.instantiate() as Node3D
	if wall == null:
		return
	wall.name = node_name
	wall.position = position_3d
	wall.rotation.y = yaw
	wall_root.add_child(wall)
	if wall.has_method("configure_wall"):
		wall.call("configure_wall", WALL_HEIGHT, WALL_THICKNESS)


func _build_gameplay_boundaries() -> void:
	var room_width_pixels := ROOM_WIDTH * CELL_PIXELS
	var room_height_pixels := ROOM_HEIGHT * CELL_PIXELS
	var center := Vector2((ROOM_WIDTH - 1) * 0.5, (ROOM_HEIGHT - 1) * 0.5) * CELL_PIXELS
	_spawn_wall_collision(Vector2(-0.5 * CELL_PIXELS, center.y), Vector2(WALL_COLLISION_THICKNESS, room_height_pixels), "WestWallCollision")
	_spawn_wall_collision(Vector2((ROOM_WIDTH - 0.5) * CELL_PIXELS, center.y), Vector2(WALL_COLLISION_THICKNESS, room_height_pixels), "EastWallCollision")
	_spawn_wall_collision(Vector2(center.x, (ROOM_HEIGHT - 0.5) * CELL_PIXELS), Vector2(room_width_pixels, WALL_COLLISION_THICKNESS), "SouthWallCollision")
	var opening_left := DOOR_OPENING_START * CELL_PIXELS
	var opening_right := (DOOR_OPENING_END + 1) * CELL_PIXELS
	var north_y := -0.5 * CELL_PIXELS
	var room_left := -0.5 * CELL_PIXELS
	var room_right := (ROOM_WIDTH - 0.5) * CELL_PIXELS
	_spawn_wall_collision(Vector2((room_left + opening_left) * 0.5, north_y), Vector2(opening_left - room_left, WALL_COLLISION_THICKNESS), "NorthWallCollisionLeft")
	_spawn_wall_collision(Vector2((opening_right + room_right) * 0.5, north_y), Vector2(room_right - opening_right, WALL_COLLISION_THICKNESS), "NorthWallCollisionRight")


func _spawn_wall_collision(center: Vector2, size: Vector2, node_name: String) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.collision_layer = WORLD_WALL_LAYER
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	collision_root.add_child(body)
	body.position = center


func _configure_depth_visuals() -> void:
	player_depth_bridge.configure(
		player,
		actor_depth_viewport,
		actor_depth_render_root,
		gameplay_canvas,
		[NodePath("CharacterVisual")]
	)
	player_depth_bridge.set_world_camera(camera_3d)
	var guide_bridge := ACTOR_DEPTH_BRIDGE_SCENE.instantiate() as Node3D
	actor_depth_bridges_root.add_child(guide_bridge)
	var viewport := guide_bridge.get_node("ActorDepthViewport") as SubViewport
	var render_root := guide_bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot") as Node2D
	guide_bridge.configure(guide, viewport, render_root, null, [NodePath("CharacterVisual")])
	guide_bridge.set_world_camera(camera_3d)
	guide.set_meta(&"depth_visual_bridge", weakref(guide_bridge))


func _setup_dash_aim_presentation() -> void:
	if dash_aim_presentation != null and is_instance_valid(dash_aim_presentation):
		return
	if DASH_AIM_PRESENTATION_SCRIPT == null or gameplay_world == null:
		return
	dash_aim_presentation = DASH_AIM_PRESENTATION_SCRIPT.new() as Node2D
	if dash_aim_presentation == null:
		return
	dash_aim_presentation.name = "DashAimPresentation"
	dash_aim_presentation.z_index = 40
	dash_aim_presentation.set_meta(&"depth_visual_unshaded", true)
	gameplay_world.add_child(dash_aim_presentation)
	if actor_depth_bridges_root != null and ACTOR_DEPTH_BRIDGE_SCENE != null:
		dash_aim_depth_bridge = ACTOR_DEPTH_BRIDGE_SCENE.instantiate() as Node3D
		if dash_aim_depth_bridge != null:
			actor_depth_bridges_root.add_child(dash_aim_depth_bridge)
			var viewport := dash_aim_depth_bridge.get_node_or_null("ActorDepthViewport") as SubViewport
			var render_root := dash_aim_depth_bridge.get_node_or_null("ActorDepthViewport/ActorDepthRenderRoot") as Node2D
			if viewport != null and render_root != null:
				# The capture origin is (128, 96); match the dynamic bridge's
				# centered viewport so ground arrows are not clipped to the old
				# 128x128 default.
				viewport.size = Vector2i(256, 192)
				dash_aim_depth_bridge.call(
					"configure",
					dash_aim_presentation,
					viewport,
					render_root,
					gameplay_canvas,
					[NodePath(".")],
					0.025,
					0.0,
					Vector2(128.0, 96.0),
					BaseMaterial3D.BILLBOARD_DISABLED,
					Vector3(-PI * 0.5, 0.0, 0.0),
					true
				)
				dash_aim_depth_bridge.call("set_world_camera", camera_3d)
	dash_aim_presentation.call("clear")


func _update_dash_aim_presentation() -> void:
	if dash_aim_presentation == null or not is_instance_valid(dash_aim_presentation):
		_setup_dash_aim_presentation()
	if dash_aim_presentation == null or not is_instance_valid(dash_aim_presentation):
		return
	if (
		player != null
		and is_instance_valid(player)
		and player.has_method("is_dash_aim_active")
		and bool(player.call("is_dash_aim_active"))
		and player.has_method("get_dash_path_result")
	):
		dash_aim_presentation.global_position = player.global_position
		dash_aim_presentation.call("set_path", player.call("get_dash_path_result"))
	else:
		dash_aim_presentation.call("clear")


func _configure_lighting() -> void:
	night_lighting = preload("res://scripts/dream/dream_night_lighting.gd").new()
	night_lighting.name = "NightLighting"
	add_child(night_lighting)
	night_lighting.configure(self)
	var key_light := get_node_or_null("Lighting/KeyLight") as DirectionalLight3D
	if key_light != null:
		key_light.light_cull_mask = night_lighting.WORLD_LIGHT_CULL_MASK
	var player_sprite := player_depth_bridge.get("actor_sprite") as Sprite3D
	if player_sprite != null:
		player_sprite.layers = night_lighting.PLAYER_VISUAL_LAYER
		player_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var player_shadow := player_depth_bridge.get("shadow_proxy") as Sprite3D
	if player_shadow != null:
		player_shadow.layers = night_lighting.PLAYER_SHADOW_LAYER
		player_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_build_tutorial_ceiling_lights()


func _build_tutorial_ceiling_lights() -> void:
	if lighting_root == null:
		return
	if tutorial_ceiling_lights != null and is_instance_valid(tutorial_ceiling_lights):
		tutorial_ceiling_lights.queue_free()
	tutorial_ceiling_lights = CEILING_LIGHTING_SCRIPT.new() as Node3D
	if tutorial_ceiling_lights == null:
		return
	tutorial_ceiling_lights.name = "TutorialCeilingLightRoot"
	lighting_root.add_child(tutorial_ceiling_lights)
	# Reuse the formal fixture + SpotLight3D implementation and its exported
	# defaults, but deliberately create exactly two authored lights here.  The
	# random Dungeon's one-light-per-small-room rule is not consulted.
	var center_x := (ROOM_WIDTH - 1) * 0.5
	var ceiling_y := WALL_HEIGHT + 0.10
	for spec in [
		{"id": 9101, "progress": LIGHT_ONE_PROGRESS},
		{"id": 9102, "progress": LIGHT_TWO_PROGRESS},
	]:
		var axis := _axis_at_progress(float(spec.progress))
		var cell := Vector2i(roundi(center_x), roundi(axis))
		tutorial_ceiling_lights.call("_create_light", int(spec.id), cell, ceiling_y)
		# The formal helper is cell-based for random rooms.  Tutorial width is
		# even, so its authored center lies between cells; preserve that exact
		# center after the helper creates the fixture and SpotLight3D.
		var holder := tutorial_ceiling_lights.get_child(tutorial_ceiling_lights.get_child_count() - 1) as Node3D
		if holder != null:
			holder.position.x = center_x


func _update_camera_and_projection(delta: float) -> void:
	if player == null or camera_3d == null:
		return
	var gameplay_position: Vector2 = player.global_position
	var ground_position := Vector3(gameplay_position.x / CELL_PIXELS, 0.0, gameplay_position.y / CELL_PIXELS)
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("advance", delta, ground_position)
	if delta > 0.0:
		var aim_delta: Vector2 = get_gameplay_aim_position() - gameplay_position
		var aim_direction: Vector2 = aim_delta.normalized() if aim_delta.length_squared() > 1.0 else player.last_aim_direction
		var strength := clampf(aim_delta.length() / maxf(CONFIG.camera_aim_distance_for_max_offset, 1.0), 0.0, 1.0)
		var target_pixels := Vector2(aim_direction.x * CONFIG.camera_aim_max_offset_x, aim_direction.y * CONFIG.camera_aim_max_offset_y) * strength
		var alpha := 1.0 - exp(-maxf(CONFIG.camera_aim_smoothing, 0.01) * delta)
		camera_aim_offset = camera_aim_offset.lerp(Vector3(target_pixels.x / CELL_PIXELS, 0.0, target_pixels.y / CELL_PIXELS), alpha)
	var normal_focus := ground_position + camera_aim_offset
	var dialogue_focus := ground_position
	var dialogue_weight := 0.0
	var dialogue_zoom := 0.80
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		var focus_variant: Variant = dialogue_camera.call("get_focus_world", ground_position)
		if focus_variant is Vector3:
			dialogue_focus = focus_variant
		dialogue_weight = clampf(float(dialogue_camera.call("get_dialogue_weight")), 0.0, 1.0)
		dialogue_zoom = clampf(float(dialogue_camera.get("dialogue_zoom_factor")), 0.1, 1.0)
	# Look-ahead belongs to normal_focus and is blended out exactly once by this
	# interpolation.  Do not multiply camera_aim_offset by (1 - weight) again.
	var composed_focus := normal_focus.lerp(dialogue_focus, dialogue_weight)
	camera_rig.position = composed_focus
	if camera_3d.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera_3d.fov = authoritative_camera_fov * lerpf(1.0, dialogue_zoom, dialogue_weight)
	else:
		camera_3d.size = authoritative_camera_size * GAMEPLAY_CAMERA_SIZE_MULTIPLIER * lerpf(1.0, dialogue_zoom, dialogue_weight)
	var screen_position := camera_3d.unproject_position(ground_position)
	gameplay_canvas.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, screen_position - gameplay_position)


func _map_gameplay_to_world(gameplay_position: Vector2) -> Vector3:
	return Vector3(gameplay_position.x / CELL_PIXELS, 0.0, gameplay_position.y / CELL_PIXELS)


## Shared presentation adapter used by positional WorldSFX.  The 2D gameplay
## actor remains authoritative; only this scene performs the 2D→3D mapping.
func get_gameplay_world_position(gameplay_position: Vector2, height: float = 0.65) -> Vector3:
	var mapped := _map_gameplay_to_world(gameplay_position)
	mapped.y = height
	return mapped


func _get_dream_time_controller() -> Node:
	var root := get_tree().root
	if root == null:
		return null
	return root.get_node_or_null("DreamTimeController") as Node


func _enter_dream_time_mode() -> void:
	var time_controller: Node = _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("enter_dream_time_mode"):
		time_controller.call("enter_dream_time_mode", player, CONFIG, self)


func _exit_dream_time_mode() -> void:
	var time_controller: Node = _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("exit_dream_time_mode"):
		time_controller.call("exit_dream_time_mode", self)


func _get_presentation_delta(fallback: float) -> float:
	var time_controller: Node = _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("get_real_delta"):
		return maxf(float(time_controller.call("get_real_delta")), 0.0)
	return fallback


func begin_dialogue_focus(speaker: Node2D = null, mode: int = DIALOGUE_CONVERSATION_MODE) -> void:
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("begin_dialogue_focus", speaker, mode)


func set_dialogue_speaker(speaker: Node2D = null, mode_override: int = -1) -> void:
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("set_dialogue_speaker", speaker, mode_override)


func end_dialogue_focus() -> void:
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("end_dialogue_focus")


func clear_dialogue_focus() -> void:
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("clear_dialogue_focus")


func get_gameplay_aim_position() -> Vector2:
	var mouse: Vector2 = player.get_presentation_pointer_position()
	var origin := camera_3d.project_ray_origin(mouse)
	var direction := camera_3d.project_ray_normal(mouse)
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if point is Vector3:
		return Vector2(point.x, point.z) * CELL_PIXELS
	return player.global_position + player.last_aim_direction * 100.0


func get_vision_occluder_collision_mask() -> int:
	return WORLD_WALL_LAYER


func _update_interaction_prompt() -> void:
	var is_ui_blocking: bool = exit_sequence_started or (dialogue_dialog != null and dialogue_dialog.visible) or (dialogue_controller != null and dialogue_controller.is_active())
	if is_ui_blocking:
		interaction_prompt.visible = false
		return
	var target := interaction_resolver.current_target if interaction_resolver != null else null
	var state: Dictionary = {}
	if target != null and is_instance_valid(target) and target.has_method("get_interaction_prompt_state"):
		state = target.call("get_interaction_prompt_state")
	if state.is_empty():
		interaction_prompt.visible = false
		return
	var anchor: Vector2 = state.get("position", Vector2.ZERO)
	var world_position := Vector3(anchor.x / CELL_PIXELS, 0.0, anchor.y / CELL_PIXELS)
	interaction_prompt.text = str(state.get("text", ""))
	interaction_prompt.position = (player.get_presentation_hud_position(camera_3d.unproject_position(world_position)) + INTERACTION_PROMPT_OFFSET).round()
	interaction_prompt.visible = true


func _on_guide_spawn_trigger_entered(body: Node) -> void:
	if body == player:
		_spawn_guide_once()


func _spawn_guide_once() -> void:
	if guide_spawned:
		return
	guide_spawned = true
	var smoke := _start_smoke(guide.global_position)
	await get_tree().create_timer(0.10).timeout
	guide.visible = true
	await smoke.finished
	guide_spawn_completed.emit()


func _on_guide_interaction_requested() -> void:
	if not guide_spawned or exit_sequence_started or (dialogue_dialog != null and dialogue_dialog.visible) or (dialogue_controller != null and dialogue_controller.is_active()):
		return
	_run_optional_guide_dialogue()


func _run_optional_guide_dialogue() -> void:
	if dialogue_controller != null and dialogue_bubble != null:
		var dialogue_data: Dictionary = TextContent.get_dialogue(&"tutorial_guide_intro")
		var lines: Array = dialogue_data.get("lines", [])
		if lines.is_empty():
			return
		var get_guide_hud_pos := func() -> Vector2:
			var world_pos: Vector3 = Vector3(guide.global_position.x / CELL_PIXELS, 1.1, guide.global_position.y / CELL_PIXELS)
			return player.get_presentation_hud_position(camera_3d.unproject_position(world_pos))
		var get_player_hud_pos := func() -> Vector2:
			var world_pos: Vector3 = Vector3(player.global_position.x / CELL_PIXELS, 0.65, player.global_position.y / CELL_PIXELS)
			return player.get_presentation_hud_position(camera_3d.unproject_position(world_pos))
		begin_dialogue_focus(guide, DIALOGUE_CONVERSATION_MODE)
		dialogue_controller.start_dialogue_sequence(dialogue_bubble, lines, get_guide_hud_pos, {"interrupt_text": "闭嘴"}, get_player_hud_pos)
		while dialogue_controller != null and dialogue_controller.is_active():
			await get_tree().process_frame
		end_dialogue_focus()
	elif dialogue_dialog != null:
		begin_dialogue_focus(guide, DIALOGUE_CONVERSATION_MODE)
		await dialogue_dialog.open_dialogue(&"tutorial_guide_intro")
		if dialogue_dialog.visible:
			await dialogue_dialog.session_ended


func _on_exit_trigger_entered(body: Node) -> void:
	if body == player and not exit_sequence_started:
		_begin_exit_sequence()


func _begin_exit_sequence() -> void:
	if exit_sequence_started:
		return
	exit_sequence_started = true
	if dialogue_controller != null and dialogue_controller.is_active():
		dialogue_controller.dismiss_if_active()
	interaction_resolver.clear_target()
	guide.set_interaction_enabled(false)
	player.movement_enabled = false
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	if not guide_spawned:
		_spawn_guide_once()
		await guide_spawn_completed
	guide.set_expression(&"panic")
	begin_dialogue_focus(guide, DIALOGUE_SPEAKER_FOCUS_MODE)
	if dialogue_controller != null and dialogue_bubble != null:
		var dialogue_data: Dictionary = TextContent.get_dialogue(&"tutorial_exit_sequence")
		var lines: Array = dialogue_data.get("lines", [])
		var get_guide_hud_pos := func() -> Vector2:
			var world_pos: Vector3 = Vector3(guide.global_position.x / CELL_PIXELS, 1.1, guide.global_position.y / CELL_PIXELS)
			return player.get_presentation_hud_position(camera_3d.unproject_position(world_pos))
		var get_player_hud_pos := func() -> Vector2:
			var world_pos: Vector3 = Vector3(player.global_position.x / CELL_PIXELS, 0.65, player.global_position.y / CELL_PIXELS)
			return player.get_presentation_hud_position(camera_3d.unproject_position(world_pos))
		dialogue_controller.start_dialogue_sequence(dialogue_bubble, lines, get_guide_hud_pos, {"interrupt_text": "闭嘴"}, get_player_hud_pos)
		while dialogue_controller != null and dialogue_controller.is_active():
			await get_tree().process_frame
		end_dialogue_focus()
	elif dialogue_dialog != null:
		await dialogue_dialog.open_dialogue(&"tutorial_exit_sequence")
		if dialogue_dialog.visible:
			await dialogue_dialog.session_ended
		end_dialogue_focus()
	else:
		end_dialogue_focus()
	var smoke := _start_smoke(guide.global_position)
	await get_tree().create_timer(0.10).timeout
	guide.visible = false
	await smoke.finished
	tutorial_finished.emit()


func _start_smoke(gameplay_position: Vector2) -> TutorialSmokeBurst:
	var smoke := SMOKE_SCRIPT.new() as TutorialSmokeBurst
	add_child(smoke)
	smoke.global_position = Vector3(gameplay_position.x / CELL_PIXELS, 0.25, gameplay_position.y / CELL_PIXELS)
	smoke.call_deferred("play_once")
	return smoke


func _on_dialogue_session_started() -> void:
	player.movement_enabled = false
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)


func _on_dialogue_session_ended() -> void:
	end_dialogue_focus()
	if exit_sequence_started:
		return
	player.movement_enabled = true
	player.set_attacking_enabled(false)
	player.set_dash_enabled(true)


func _on_dialogue_line_presented(speaker_id: StringName) -> void:
	var speaker := _resolve_dialogue_speaker(speaker_id)
	if speaker == null:
		# System/narrator lines intentionally have no world focus.  Unknown IDs
		# are also non-fatal and retain the last valid focus.
		if speaker_id != &"" and speaker_id != &"system" and speaker_id != &"narrator" and not _unknown_dialogue_speakers.has(speaker_id):
			_unknown_dialogue_speakers[speaker_id] = true
			push_warning("3D Tutorial dialogue speaker '%s' could not be resolved; keeping current focus." % String(speaker_id))
		return
	set_dialogue_speaker(speaker)


func _resolve_dialogue_speaker(speaker_id: StringName) -> Node2D:
	match speaker_id:
		&"guide":
			return guide if guide != null and is_instance_valid(guide) else null
		&"player":
			return player if player != null and is_instance_valid(player) else null
		&"system", &"narrator", &"":
			return null
		_:
			return null
