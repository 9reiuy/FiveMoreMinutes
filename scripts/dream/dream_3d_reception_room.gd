class_name Dream3DReceptionRoom
extends Node3D

signal elevator_entered
signal weapon_equipped(weapon_id: String)

const CELL_PIXELS := 32.0

# Room dimensions
const MAIN_HALL_WIDTH := 26
const MAIN_HALL_HEIGHT := 16
const CORRIDOR_WIDTH := 8
const CORRIDOR_HEIGHT := 4
const CORRIDOR_START_X := 9

# Wall & opening constants
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.1
const WALL_COLLISION_THICKNESS := 16.0
const ELEVATOR_OPENING_START := 2 # Exclude X: 2..5
const ELEVATOR_OPENING_END := 5
const WORLD_WALL_LAYER := 4

# Key positions
const PLAYER_SPAWN := Vector2(12.5, 18.5) * CELL_PIXELS
const ELEVATOR_POS_3D := Vector3(3.5, 0.0, -0.5)
const ELEVATOR_POS_2D := Vector2(3.5, -0.5) * CELL_PIXELS
const RECEPTION_DESK_POS_3D := Vector3(16.0, 0.0, 3.6)
const RECEPTION_DESK_POS_2D := Vector2(16.0, 3.6) * CELL_PIXELS
const WAITRESS_NPC_POS_2D := Vector2(16.0, 2.6) * CELL_PIXELS
const DIALOGUE_FOCUS_TARGET_3D := Vector3(RECEPTION_DESK_POS_3D.x, 0.0, RECEPTION_DESK_POS_3D.z + 0.5)

const INTERACTION_PROMPT_OFFSET := Vector2(-64.0, -32.0)
const CRISP_INTERACTION_FONT: Script = preload("res://scripts/ui/crisp_interaction_font.gd")
const COMPACT_PROMPT = preload("res://scripts/ui/compact_interaction_prompt.gd")
const GAMEPLAY_CAMERA_FOV := 40.0
const PHONE_CAMERA := preload("res://scripts/dream/phone_camera_presentation.gd")

# Preloaded scenes & scripts
const WALL_SCENE: PackedScene = preload("res://scenes/dream/3d/WallStraight3D.tscn")
const RECEPTION_DESK_SCENE: PackedScene = preload("res://scenes/dream/3d/props/reception_desk_3d.tscn")
const ACTOR_DEPTH_BRIDGE_SCENE: PackedScene = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const FLOOR_BATCH_RENDERER: Script = preload("res://scripts/dream/dream_3d_floor_batch_renderer.gd")
const DASH_AIM_PRESENTATION_SCRIPT: Script = preload("res://scripts/dream/dream_dash_aim_presentation.gd")
const INTERACTION_RESOLVER_SCRIPT: Script = preload("res://scripts/dream/dream_interaction_resolver.gd")
const CONFIG: DemoConfig = preload("res://resources/demo_config.tres")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const DREAM_GUN_ATLAS := preload("res://scripts/data/dream_gun_atlas.gd")
const TRANSITION_GRADIENT_SHADER: Shader = preload("res://shaders/dream3d/transition_corridor_gradient.gdshader")

const RECEPTION_WAITRESS_SCRIPT := preload("res://scripts/dream/reception_waitress_npc.gd")
const TAROT_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/tarot/tarot_overlay.tscn")
const TAROT_DRAW_CONTROLLER_SCRIPT: Script = preload("res://scripts/dream/tarot/tarot_draw_controller.gd")

# Node references
@onready var geometry_3d: Node3D = $Geometry3D
@onready var floor_root: Node3D = $Geometry3D/FloorRoot
@onready var wall_root: Node3D = $Geometry3D/WallRoot
@onready var door_root: Node3D = $Geometry3D/DoorRoot
@onready var props_root: Node3D = $Geometry3D/PropsRoot
@onready var gameplay_canvas: CanvasLayer = $GameplayCanvas
@onready var gameplay_world: Node2D = $GameplayCanvas/GameplayWorld
@onready var collision_root: Node2D = $GameplayCanvas/GameplayWorld/GeneratedCollisionRoot
@onready var player: CharacterBody2D = $GameplayCanvas/GameplayWorld/DreamPlayer
@onready var waitress_npc: Node2D = $GameplayCanvas/GameplayWorld/ReceptionWaitressNPC
@onready var actor_depth_viewport: SubViewport = $ActorDepthViewport
@onready var actor_depth_render_root: Node2D = $ActorDepthViewport/ActorDepthRenderRoot
@onready var player_depth_bridge: Node3D = $PlayerDepthVisual3D
@onready var actor_depth_bridges_root: Node3D = $ActorDepthBridges
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_3d: Camera3D = $CameraRig/Camera3D
@onready var lighting_root: Node3D = $Lighting
@onready var key_light: DirectionalLight3D = $Lighting/KeyLight
@onready var interaction_prompt: Label = $GameplayUI/InteractionPrompt
@onready var fade_overlay: ColorRect = $GameplayUI/FadeOverlay
@onready var dialogue_dialog: BedroomConfirmationDialog = $DialogueLayer/ConfirmationDialog
@onready var npc_hint_bubble = $DialogueLayer/NpcHintBubble
@onready var dialogue_bubble: DreamDialogueBubble = $DialogueLayer/DreamDialogueBubble
@onready var tarot_overlay: TarotOverlay = $TarotLayer/TarotOverlay

var dialogue_controller: DreamDialogueController
var waitress_approached_this_session := false
var audio_listener_3d: AudioListener3D
var floor_cells: Dictionary = {}
var room_cells: Dictionary = {}
var rooms: Array = [{"archetype":"reception", "sample_key":"reception", "grid_rect":Rect2i(0,0,MAIN_HALL_WIDTH,MAIN_HALL_HEIGHT), "office_visual_style":"approved_room", "authored_sample":false}]
var active_seed := 120
var room_layout_plans: Dictionary = {}
var lazy_room_presentation := false
var configured_weapon_id := "basic"
var profile_state: Dictionary = {}
var night_state: Dictionary = {}

var tarot_visit_state := {
	"hand_generated": false,
	"hand": [],
	"selected": false,
	"selected_result": null,
}
var active_tarot_overlay: TarotOverlay:
	get:
		return tarot_overlay if (tarot_overlay != null and tarot_overlay.visible) else null
	set(_value):
		pass

var interaction_resolver: DreamInteractionResolver
var interaction_consumed_until_release := false
var camera_aim_offset := Vector3.ZERO
var authoritative_camera_fov := GAMEPLAY_CAMERA_FOV
var phone_camera_weight := 0.0
var dialogue_camera_weight: float = 0.0
var _dialogue_camera_tween: Tween = null

var night_lighting: Node3D
var dash_aim_presentation: Node2D
var dash_aim_depth_bridge: Node3D

var elevator_floor_door: ElevatorFloorDoor3D
var elevator_approach_active := false
var elevator_transition_in_progress := false
var entry_cab: IndependentElevatorCab3D
var entry_return_position := Vector2.ZERO
var entry_ride_started_usec := 0
var entry_camera_weight := 0.0
var reception_desk: Node3D


func configure_reception(weapon_id: String, profile: Dictionary, night: Dictionary = {}) -> void:
	configured_weapon_id = DREAM_GUN_ATLAS.sanitize_weapon_id(weapon_id)
	profile_state = profile
	night_state = night


func _enter_tree() -> void:
	add_to_group(&"dream_world")
	set_meta(&"preserve_local_palette",true)


func _ready() -> void:
	preload("res://scripts/app/game_input_actions.gd").configure()
	SFX.play_safe_music(get_instance_id())
	interaction_prompt.add_theme_font_override(&"font", CRISP_INTERACTION_FONT.get_font())
	interaction_prompt.add_theme_font_size_override(&"font_size", 12)

	if camera_3d != null:
		camera_3d.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera_3d.fov = GAMEPLAY_CAMERA_FOV
		authoritative_camera_fov = camera_3d.fov

	_build_room_geometry()
	_setup_elevator()
	_setup_reception_desk()
	preload("res://scripts/dream/tarot_reception_dressing.gd").new().build(self)
	_apply_authored_layout()
	_setup_player()
	_enter_dream_time_mode()
	_configure_depth_visuals()
	_setup_dash_aim_presentation()
	_configure_lighting()
	_setup_interaction_system()
	_setup_dialogue_controller()
	_setup_tarot_system()
	_update_camera_and_projection(0.0)
	_setup_3d_audio_listener()
	preload("res://scripts/dream/combat_vfx.gd").install(self)
	preload("res://scripts/dream/floor_reflections.gd").install(self)


func _exit_tree() -> void:
	if has_meta(&"display_reparenting"):
		return
	if _dialogue_camera_tween != null and _dialogue_camera_tween.is_valid():
		_dialogue_camera_tween.kill()
		_dialogue_camera_tween = null
	_exit_dream_time_mode()
	if elevator_transition_in_progress:
		SFX.stop_elevator_music()
		SFX.stop_elevator_rumble()


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


func _setup_dialogue_controller() -> void:
	if dialogue_controller == null:
		dialogue_controller = DreamDialogueController.new()
		dialogue_controller.name = "DreamDialogueController"
		add_child(dialogue_controller)
		dialogue_controller.dialogue_interrupted.connect(_on_waitress_dialogue_interrupted)
		dialogue_controller.dialogue_finished.connect(_on_waitress_dialogue_finished)
		dialogue_controller.dialogue_option_selected.connect(_on_waitress_dialogue_option_selected)
		dialogue_controller.dialogue_line_started.connect(_on_waitress_emotion_line)


func _process(delta: float) -> void:
	_update_camera_and_projection(_get_presentation_delta(delta))
	_update_dash_aim_presentation()

	if interaction_resolver != null:
		interaction_resolver.update_target()

	_handle_waitress_proximity_dialogue()

	if dialogue_controller != null and dialogue_controller.is_active():
		if dialogue_bubble != null and is_instance_valid(dialogue_bubble) and player != null and camera_3d != null:
			var waitress_hud_pos: Vector2 = _get_waitress_hud_pos()
			dialogue_bubble.set_speaker_hud_position(waitress_hud_pos)

			var player_hud_pos: Vector2 = _get_player_hud_pos()
			dialogue_bubble.set_player_hud_position(player_hud_pos)

	if not Input.is_action_pressed("pickup_weapon"):
		interaction_consumed_until_release = false

	var is_ui_blocking: bool = elevator_transition_in_progress or (tarot_overlay != null and tarot_overlay.visible) or (dialogue_dialog != null and dialogue_dialog.visible) or (dialogue_controller != null and dialogue_controller.is_active()) or (dialogue_bubble != null and dialogue_bubble.visible)
	if not is_ui_blocking:
		if elevator_approach_active:
			if Input.is_action_just_pressed("pickup_weapon") and not interaction_consumed_until_release:
				interaction_consumed_until_release = true
				_start_elevator_entry()
		else:
			if Input.is_action_just_pressed("pickup_weapon") and not interaction_consumed_until_release:
				var target := interaction_resolver.current_target if interaction_resolver != null else null
				if target != null and target.has_method("request_interaction"):
					interaction_consumed_until_release = true
					target.call("request_interaction", player)

	_update_interaction_prompt()


func _get_waitress_hud_pos() -> Vector2:
	if player == null or camera_3d == null:
		return Vector2.ZERO
	var waitress_world_pos: Vector3
	if waitress_npc != null and is_instance_valid(waitress_npc):
		waitress_world_pos = Vector3(waitress_npc.global_position.x / CELL_PIXELS, 1.20, waitress_npc.global_position.y / CELL_PIXELS - 0.70710678)
	else:
		waitress_world_pos = RECEPTION_DESK_POS_3D + Vector3(0.0, 1.25, 0.0)
	return player.get_presentation_hud_position(camera_3d.unproject_position(waitress_world_pos))


func _get_player_hud_pos() -> Vector2:
	if player == null or camera_3d == null:
		return Vector2.ZERO
	var player_world_pos := Vector3(player.global_position.x / CELL_PIXELS, 0.65, player.global_position.y / CELL_PIXELS)
	return player.get_presentation_hud_position(camera_3d.unproject_position(player_world_pos))


func _handle_waitress_proximity_dialogue() -> void:
	if interaction_resolver == null or waitress_npc == null: return
	if interaction_resolver.current_target==waitress_npc:
		if waitress_npc.conversation_mode==waitress_npc.ConversationMode.ACTIVE and not waitress_approached_this_session and not elevator_transition_in_progress:
			waitress_approached_this_session=true
			_on_waitress_interaction_requested()
	else:
		waitress_approached_this_session=false
		if dialogue_controller != null and dialogue_controller.is_active():
			dialogue_controller.dismiss_if_active()
			_tween_dialogue_camera_weight(0.0,.45)

# =============================================================================
# Level Geometry Construction
# =============================================================================

func _build_room_geometry() -> void:
	# Reception floor uses the same approved-room theme as formal floor entry.
	floor_cells.clear()
	room_cells.clear()
	for x in range(MAIN_HALL_WIDTH):
		for y in range(MAIN_HALL_HEIGHT):
			floor_cells[Vector2i(x, y)] = true
			room_cells[Vector2i(x, y)] = 0

	for x in range(CORRIDOR_START_X, CORRIDOR_START_X + CORRIDOR_WIDTH):
		for y in range(MAIN_HALL_HEIGHT, MAIN_HALL_HEIGHT + CORRIDOR_HEIGHT):
			floor_cells[Vector2i(x, y)] = true
			room_cells[Vector2i(x, y)] = 0

	FLOOR_BATCH_RENDERER.build(self)
	var final_floor := preload("res://scripts/dream/preview/sample_floor_texture_review.gd").new()
	final_floor.world=self
	final_floor.production_mode=true
	final_floor.rebuild_floor_surfaces()
	final_floor.free()

	# 2. Three north elevator facades; only the first has a gameplay opening.
	for x in range(MAIN_HALL_WIDTH):
		if x < ELEVATOR_OPENING_START or x > 13:
			_spawn_wall(Vector3(x, 0.0, -0.5), 0.0, "NorthWall_%02d" % x)

	# 3. West & East Walls of Main Hall
	for y in range(MAIN_HALL_HEIGHT):
		_spawn_wall(Vector3(-0.5, 0.0, y), PI * 0.5, "MainWestWall_%02d" % y)
		_spawn_wall(Vector3(MAIN_HALL_WIDTH - 0.5, 0.0, y), PI * 0.5, "MainEastWall_%02d" % y)

	# 4. Main hall south walls beside the entrance, with cutaway mode.
	for x in range(0, CORRIDOR_START_X):
		var wall := _spawn_wall(Vector3(x, 0.0, MAIN_HALL_HEIGHT - 0.5), 0.0, "MainSouthWallLeft_%02d" % x)
		if wall != null and wall.has_method("set_cutaway_mode"):
			wall.call("set_cutaway_mode", true)

	for x in range(CORRIDOR_START_X + CORRIDOR_WIDTH, MAIN_HALL_WIDTH):
		var wall := _spawn_wall(Vector3(x, 0.0, MAIN_HALL_HEIGHT - 0.5), 0.0, "MainSouthWallRight_%02d" % x)
		if wall != null and wall.has_method("set_cutaway_mode"):
			wall.call("set_cutaway_mode", true)

	# 5. Entrance side walls.
	var corridor_west_x := float(CORRIDOR_START_X) - 0.5
	var corridor_east_x := float(CORRIDOR_START_X + CORRIDOR_WIDTH) - 0.5
	for y in range(MAIN_HALL_HEIGHT, MAIN_HALL_HEIGHT + CORRIDOR_HEIGHT):
		_spawn_wall(Vector3(corridor_west_x, 0.0, y), PI * 0.5, "CorridorWestWall_%02d" % y)
		_spawn_wall(Vector3(corridor_east_x, 0.0, y), PI * 0.5, "CorridorEastWall_%02d" % y)

	# 6. Entrance south wall with cutaway mode.
	var corridor_south_y := float(MAIN_HALL_HEIGHT + CORRIDOR_HEIGHT) - 0.5
	for x in range(CORRIDOR_START_X, CORRIDOR_START_X + CORRIDOR_WIDTH):
		var wall := _spawn_wall(Vector3(x, 0.0, corridor_south_y), 0.0, "CorridorSouthWall_%02d" % x)
		if wall != null and wall.has_method("set_cutaway_mode"):
			wall.call("set_cutaway_mode", true)

	# 7. Entrance corridor bottom atmospheric dark gradient
	_build_entrance_corridor_gradient()

	# 8. 2D Gameplay Collision Boundaries
	_build_gameplay_boundaries()


func _spawn_wall(position_3d: Vector3, yaw: float, node_name: String) -> Node3D:
	var wall := WALL_SCENE.instantiate() as Node3D
	if wall == null:
		return null
	wall.name = node_name
	wall.position = position_3d
	wall.rotation.y = yaw
	wall_root.add_child(wall)
	if wall.has_method("configure_wall"):
		wall.call("configure_wall", WALL_HEIGHT, WALL_THICKNESS)
	if wall.has_method("set_wall_materials"):
		wall.call("set_wall_materials",OfficePixelMaterials.make(Color(.39,.46,.54),"paint"))
	return wall


func _build_entrance_corridor_gradient() -> void:
	var gradient_mesh := MeshInstance3D.new()
	gradient_mesh.name = "EntranceCorridorFadeGradient"
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(CORRIDOR_WIDTH), 4.0)
	gradient_mesh.mesh = plane
	var corridor_center_x := float(CORRIDOR_START_X) + float(CORRIDOR_WIDTH) * 0.5 - 0.5
	gradient_mesh.position = Vector3(corridor_center_x, 0.045, float(MAIN_HALL_HEIGHT + CORRIDOR_HEIGHT) - 2.0)
	gradient_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gradient_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var mat := ShaderMaterial.new()
	mat.shader = TRANSITION_GRADIENT_SHADER
	mat.set_shader_parameter("black_color", Color(0.0, 0.0, 0.0, 1.0))
	mat.set_shader_parameter("fade_power", 1.4)
	gradient_mesh.material_override = mat
	geometry_3d.add_child(gradient_mesh)


func _build_gameplay_boundaries() -> void:
	# Main north boundary opens only around the functional elevator.
	var north_y := -0.5 * CELL_PIXELS
	var left_span := float(ELEVATOR_OPENING_START) * CELL_PIXELS + 0.5 * CELL_PIXELS # -16px to 96px
	_spawn_wall_collision(Vector2(left_span * 0.5 - 8.0, north_y), Vector2(left_span + 16.0, WALL_COLLISION_THICKNESS), "NorthWallCollisionLeft")

	var right_start := float(ELEVATOR_OPENING_END + 1) * CELL_PIXELS - 0.5 * CELL_PIXELS
	var room_right_px := float(MAIN_HALL_WIDTH) * CELL_PIXELS - 0.5 * CELL_PIXELS
	var right_width := room_right_px - right_start + 16.0
	_spawn_wall_collision(Vector2((right_start + room_right_px) * 0.5, north_y), Vector2(right_width, WALL_COLLISION_THICKNESS), "NorthWallCollisionRight")

	# Main Hall West & East Walls
	var main_center_y := (float(MAIN_HALL_HEIGHT) * 0.5 - 0.5) * CELL_PIXELS
	var main_height_px := float(MAIN_HALL_HEIGHT) * CELL_PIXELS
	_spawn_wall_collision(Vector2(-0.5 * CELL_PIXELS, main_center_y), Vector2(WALL_COLLISION_THICKNESS, main_height_px), "MainWestWallCollision")
	_spawn_wall_collision(Vector2((float(MAIN_HALL_WIDTH) - 0.5) * CELL_PIXELS, main_center_y), Vector2(WALL_COLLISION_THICKNESS, main_height_px), "MainEastWallCollision")

	# Main hall south walls beside the entrance.
	var main_south_y := (float(MAIN_HALL_HEIGHT) - 0.5) * CELL_PIXELS
	var left_south_width := float(CORRIDOR_START_X) * CELL_PIXELS
	_spawn_wall_collision(Vector2(left_south_width * 0.5 - 8.0, main_south_y), Vector2(left_south_width + 16.0, WALL_COLLISION_THICKNESS), "MainSouthWallCollisionLeft")

	var right_south_start := float(CORRIDOR_START_X + CORRIDOR_WIDTH) * CELL_PIXELS - 0.5 * CELL_PIXELS
	var right_south_width := room_right_px - right_south_start + 16.0
	_spawn_wall_collision(Vector2((right_south_start + room_right_px) * 0.5, main_south_y), Vector2(right_south_width, WALL_COLLISION_THICKNESS), "MainSouthWallCollisionRight")

	# Entrance west and east walls.
	var corridor_west_px := (float(CORRIDOR_START_X) - 0.5) * CELL_PIXELS
	var corridor_east_px := (float(CORRIDOR_START_X + CORRIDOR_WIDTH) - 0.5) * CELL_PIXELS
	var corridor_center_y := (float(MAIN_HALL_HEIGHT) + float(CORRIDOR_HEIGHT) * 0.5 - 0.5) * CELL_PIXELS
	var corridor_height_px := float(CORRIDOR_HEIGHT) * CELL_PIXELS
	_spawn_wall_collision(Vector2(corridor_west_px, corridor_center_y), Vector2(WALL_COLLISION_THICKNESS, corridor_height_px), "CorridorWestWallCollision")
	_spawn_wall_collision(Vector2(corridor_east_px, corridor_center_y), Vector2(WALL_COLLISION_THICKNESS, corridor_height_px), "CorridorEastWallCollision")

	# Corridor South Wall
	var corridor_south_px := (float(MAIN_HALL_HEIGHT + CORRIDOR_HEIGHT) - 0.5) * CELL_PIXELS
	var corridor_center_x := (float(CORRIDOR_START_X) + float(CORRIDOR_WIDTH) * 0.5 - 0.5) * CELL_PIXELS
	var corridor_width_px := float(CORRIDOR_WIDTH) * CELL_PIXELS
	_spawn_wall_collision(Vector2(corridor_center_x, corridor_south_px), Vector2(corridor_width_px, WALL_COLLISION_THICKNESS), "CorridorSouthWallCollision")


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


# =============================================================================
# Props & Entities Setup
# =============================================================================

func _setup_elevator() -> void:
	elevator_floor_door = ElevatorFloorDoor3D.new(ElevatorFloorDoor3D.Orientation.UP, 0)
	elevator_floor_door.position = ELEVATOR_POS_3D
	door_root.add_child(elevator_floor_door)
	elevator_floor_door.configure_entrance(Vector2.UP, camera_3d)
	elevator_floor_door.setup_gameplay_2d(collision_root, gameplay_world, ELEVATOR_POS_2D)
	elevator_floor_door.update_state(ElevatorFloorDoor3D.State.UNLOCKED)
	# Lobby bays have their own 01/02/03 labels; do not overlay a floor label.
	elevator_floor_door.indicator_label.hide()
	elevator_floor_door.industrial_facade.bay_number=1
	elevator_floor_door.industrial_facade.update_number()
	elevator_floor_door.approach_entered.connect(_on_elevator_approach_entered)
	elevator_floor_door.approach_exited.connect(_on_elevator_approach_exited)
	for i in [1,2]:
		var closed := ElevatorFloorDoor3D.new(ElevatorFloorDoor3D.Orientation.UP,0)
		closed.name="BackgroundElevator%d"%(i+1)
		closed.position=ELEVATOR_POS_3D+Vector3(float(i)*4,0,0)
		door_root.add_child(closed)
		closed.update_state(ElevatorFloorDoor3D.State.LOCKED)
		closed.indicator_label.hide()
		closed.industrial_facade.bay_number=i+1
		closed.industrial_facade.update_number()


func _setup_reception_desk() -> void:
	reception_desk = RECEPTION_DESK_SCENE.instantiate()
	reception_desk.name = "ReceptionDesk3D"
	reception_desk.position = RECEPTION_DESK_POS_3D
	props_root.add_child(reception_desk)
	if reception_desk.has_method("setup_gameplay_2d"):
		reception_desk.call("setup_gameplay_2d", collision_root, RECEPTION_DESK_POS_2D)
	for i in [1,2]:
		var desk := RECEPTION_DESK_SCENE.instantiate() as Node3D
		desk.name="EmptyReceptionDesk%d"%(i+1)
		desk.position=RECEPTION_DESK_POS_3D+Vector3(float(i)*3.4,0,0)
		props_root.add_child(desk)
		desk.call("setup_gameplay_2d",collision_root,RECEPTION_DESK_POS_2D+Vector2(float(i)*3.4,0)*CELL_PIXELS)


func _apply_authored_layout() -> void:
	player.global_position = PLAYER_SPAWN
	if waitress_npc != null:
		waitress_npc.global_position = WAITRESS_NPC_POS_2D


func _setup_player() -> void:
	player.set("selected_weapon_id", configured_weapon_id)
	player.configure_weapon(configured_weapon_id, CONFIG, profile_state.get("permanent_upgrades", {}))
	if player.has_method("configure_profile_stats"):
		player.call("configure_profile_stats", int(profile_state.get("character_hp_cells", CONFIG.character_card_default_hp_cells)))
	player.set_attacking_enabled(false)
	player.set_dash_enabled(true)
	player.movement_enabled = true


func _configure_depth_visuals() -> void:
	player_depth_bridge.configure(
		player,
		actor_depth_viewport,
		actor_depth_render_root,
		gameplay_canvas,
		[NodePath("CharacterVisual")]
	)
	player_depth_bridge.set_world_camera(camera_3d)

	if waitress_npc != null:
		var npc_bridge := ACTOR_DEPTH_BRIDGE_SCENE.instantiate() as Node3D
		actor_depth_bridges_root.add_child(npc_bridge)
		var viewport := npc_bridge.get_node("ActorDepthViewport") as SubViewport
		var render_root := npc_bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot") as Node2D
		npc_bridge.configure(waitress_npc, viewport, render_root, null, [NodePath("CharacterVisual")])
		npc_bridge.set_world_camera(camera_3d)
		waitress_npc.set_meta(&"depth_visual_bridge", weakref(npc_bridge))


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

	var world_env := get_node_or_null("Lighting/WorldEnvironment") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		var env: Environment = world_env.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.0, 0.0, 0.0, 1.0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.40, 0.44, 0.52, 1.0)
		env.ambient_light_energy = 0.38
		env.tonemap_mode = 1
		env.fog_enabled = false

	if key_light != null:
		key_light.light_cull_mask = night_lighting.WORLD_LIGHT_CULL_MASK
		key_light.light_energy = 0.025
		key_light.shadow_enabled = false

	var player_sprite := player_depth_bridge.get("actor_sprite") as Sprite3D
	if player_sprite != null:
		player_sprite.layers = night_lighting.PLAYER_VISUAL_LAYER
		player_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var player_shadow := player_depth_bridge.get("shadow_proxy") as Sprite3D
	if player_shadow != null:
		player_shadow.layers = night_lighting.PLAYER_SHADOW_LAYER
		player_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	_build_accent_lights()


func _build_accent_lights() -> void:
	# 1. Soft Warm Reception Desk Local Light (illuminates desk & Waitress cleanly without dark shadow bands)
	var desk_light := OmniLight3D.new()
	desk_light.name = "ReceptionDeskLight"
	desk_light.position = Vector3(RECEPTION_DESK_POS_3D.x, 2.2, RECEPTION_DESK_POS_3D.z + 0.4)
	desk_light.light_color = Color(0.96, 0.94, 0.90)
	desk_light.light_energy = 0.45
	desk_light.omni_range = 4.5
	desk_light.omni_attenuation = 1.2
	desk_light.shadow_enabled = false
	desk_light.light_cull_mask = night_lighting.WORLD_LIGHT_CULL_MASK
	lighting_root.add_child(desk_light)

	# 2. Soft Cool Elevator Indicator Accent Light (illuminates elevator doors and floor threshold)
	var elevator_light := OmniLight3D.new()
	elevator_light.name = "ElevatorAccentLight"
	elevator_light.position = Vector3(ELEVATOR_POS_3D.x, 2.8, 0.2)
	elevator_light.light_color = Color(0.85, 0.95, 1.0)
	elevator_light.light_energy = 0.5
	elevator_light.omni_range = 4.5
	elevator_light.omni_attenuation = 1.3
	elevator_light.shadow_enabled = false
	elevator_light.light_cull_mask = night_lighting.WORLD_LIGHT_CULL_MASK
	lighting_root.add_child(elevator_light)
	for point in [Vector2(4,5),Vector2(12,7),Vector2(20,6),Vector2(5,11.5),Vector2(14,14),Vector2(23,12)]:
		var light := SpotLight3D.new()
		light.name="LobbyAreaLight%d"%lighting_root.get_child_count()
		light.position=Vector3(point.x,3.1,point.y)
		light.rotation_degrees.x=-90
		light.light_color=Color(.87,.91,1.0)
		# Formal room lighting uses 0.5-energy localized ceiling cones with
		# a broad falloff shoulder, above the same dark night ambient.
		light.light_energy=.5; light.spot_range=8.0; light.spot_angle=95
		light.spot_attenuation=.20; light.spot_angle_attenuation=.15
		light.shadow_enabled=false
		light.light_cull_mask=night_lighting.WORLD_LIGHT_CULL_MASK
		lighting_root.add_child(light)



func _setup_interaction_system() -> void:
	interaction_resolver = INTERACTION_RESOLVER_SCRIPT.new()
	interaction_resolver.name = "DreamInteractionResolver"
	add_child(interaction_resolver)
	interaction_resolver.configure(player, [&"tutorial_interaction_targets", &"reception_interaction_targets"])


# =============================================================================
# Camera & Presentation
# =============================================================================

func _tween_dialogue_camera_weight(target_weight: float, duration: float) -> void:
	if not is_inside_tree():
		dialogue_camera_weight = target_weight
		return
	if _dialogue_camera_tween != null and _dialogue_camera_tween.is_valid():
		_dialogue_camera_tween.kill()
	_dialogue_camera_tween = create_tween()
	_dialogue_camera_tween.tween_property(self, "dialogue_camera_weight", target_weight, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_camera_and_projection(delta: float) -> void:
	if player == null or camera_3d == null:
		return
	var gameplay_position: Vector2 = player.global_position
	var ground_position := Vector3(gameplay_position.x / CELL_PIXELS, 0.0, gameplay_position.y / CELL_PIXELS)

	if delta > 0.0 and phone_camera_weight <= 0.0:
		var aim_delta: Vector2 = get_gameplay_aim_position() - gameplay_position
		var aim_direction: Vector2 = aim_delta.normalized() if aim_delta.length_squared() > 1.0 else player.last_aim_direction
		var strength := clampf(aim_delta.length() / maxf(CONFIG.camera_aim_distance_for_max_offset, 1.0), 0.0, 1.0)
		var target_pixels := Vector2(aim_direction.x * CONFIG.camera_aim_max_offset_x, aim_direction.y * CONFIG.camera_aim_max_offset_y) * strength
		var alpha := 1.0 - exp(-maxf(CONFIG.camera_aim_smoothing, 0.01) * delta)
		camera_aim_offset = camera_aim_offset.lerp(Vector3(target_pixels.x / CELL_PIXELS, 0.0, target_pixels.y / CELL_PIXELS), alpha)

	var normal_focus := ground_position + camera_aim_offset * (1.0 - phone_camera_weight)
	var composed_focus := normal_focus.lerp(DIALOGUE_FOCUS_TARGET_3D, dialogue_camera_weight)
	if is_instance_valid(entry_cab) and entry_ride_started_usec > 0:
		composed_focus = composed_focus.lerp(entry_cab.get_camera_focus_world(), entry_camera_weight)
	var phone_fov: float = authoritative_camera_fov * PHONE_CAMERA.zoom_factor(phone_camera_weight)
	phone_fov = lerpf(phone_fov, 24.0, entry_camera_weight)
	composed_focus += PHONE_CAMERA.focus_offset(camera_3d, phone_camera_weight, phone_fov)
	camera_rig.position = composed_focus

	if camera_3d.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera_3d.fov = phone_fov

	var screen_position := camera_3d.unproject_position(ground_position)
	gameplay_canvas.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, screen_position - gameplay_position)


func set_phone_camera_weight(weight: float) -> void:
	phone_camera_weight = clampf(weight, 0.0, 1.0)


func refresh_phone_camera_presentation(_delta: float = 0.0) -> void:
	# The host runs while paused. Only the formal projection authority executes;
	# proximity dialogue, AI, movement and the game clock remain untouched.
	_update_camera_and_projection(0.0)


func _map_gameplay_to_world(gameplay_position: Vector2) -> Vector3:
	return Vector3(gameplay_position.x / CELL_PIXELS, 0.0, gameplay_position.y / CELL_PIXELS)


func get_gameplay_world_position(gameplay_position: Vector2, height: float = 0.65) -> Vector3:
	var mapped := _map_gameplay_to_world(gameplay_position)
	mapped.y = height
	return mapped


func get_gameplay_aim_position() -> Vector2:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera_3d.project_ray_origin(mouse)
	var direction := camera_3d.project_ray_normal(mouse)
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if point is Vector3:
		return Vector2(point.x, point.z) * CELL_PIXELS
	var aim_dir: Vector2 = player.last_aim_direction if is_instance_valid(player) and "last_aim_direction" in player else Vector2.DOWN
	var base_pos: Vector2 = player.global_position if is_instance_valid(player) else Vector2.ZERO
	return base_pos + aim_dir * 100.0


func get_vision_occluder_collision_mask() -> int:
	return WORLD_WALL_LAYER


func _update_interaction_prompt() -> void:
	var is_ui_blocking: bool = elevator_transition_in_progress or (tarot_overlay != null and tarot_overlay.visible) or (dialogue_dialog != null and dialogue_dialog.visible) or (dialogue_controller != null and dialogue_controller.is_active()) or (dialogue_bubble != null and dialogue_bubble.visible)
	if is_ui_blocking:
		npc_hint_bubble.dismiss()
		interaction_prompt.dismiss(true)
		return

	if elevator_approach_active:
		npc_hint_bubble.dismiss()
		var world_pos := ELEVATOR_POS_3D + Vector3(0.0, 1.2, 0.4)
		var hud_point: Vector2 = player.get_presentation_hud_position(camera_3d.unproject_position(world_pos))
		interaction_prompt.present("进入", hud_point + INTERACTION_PROMPT_OFFSET, -1)
		return

	var target := interaction_resolver.current_target if interaction_resolver != null else null
	var state: Dictionary = {}
	if target==waitress_npc and is_instance_valid(waitress_npc) and waitress_npc.visible and waitress_npc.interaction_enabled:
		npc_hint_bubble.present_hint(_get_waitress_hud_pos(),StringName(waitress_npc.hint_emotion))
	else:
		npc_hint_bubble.dismiss()
	if target==waitress_npc and waitress_npc.conversation_mode==waitress_npc.ConversationMode.PASSIVE:
		interaction_prompt.present("交流",npc_hint_bubble.prompt_anchor(interaction_prompt.size),waitress_npc.get_instance_id())
		return
	if target != null and is_instance_valid(target) and target.has_method("get_interaction_prompt_state"):
		state = target.call("get_interaction_prompt_state")

	if state.is_empty():
		interaction_prompt.dismiss()
		return

	var anchor: Vector2 = state.get("position", Vector2.ZERO)
	var world_position := Vector3(anchor.x / CELL_PIXELS, 1.0, anchor.y / CELL_PIXELS)
	if target.is_in_group(&"reception_npc") or target == waitress_npc:
		world_position = RECEPTION_DESK_POS_3D + Vector3(0.0, 1.25, 0.0)

	var prompt_text := str(state.get("text", ""))
	if prompt_text in ["E 交谈","[E] 交谈"]:
		prompt_text = "交流"
	elif target.is_in_group(&"world_weapon_pickups") or target.is_in_group(&"employee_badge_pickup"):
		prompt_text = COMPACT_PROMPT.pickup_verb(target, player)
	var hud_point: Vector2 = player.get_presentation_hud_position(camera_3d.unproject_position(world_position))
	interaction_prompt.present(prompt_text, hud_point + INTERACTION_PROMPT_OFFSET, target.get_instance_id())


# =============================================================================
# Elevator Interaction Flow
# =============================================================================

func _on_elevator_approach_entered(body: Node) -> void:
	if body == player:
		elevator_approach_active = true


func _on_elevator_approach_exited(body: Node) -> void:
	if body == player:
		elevator_approach_active = false


func _start_elevator_entry() -> void:
	if elevator_transition_in_progress:
		return
	elevator_transition_in_progress = true
	interaction_prompt.dismiss(true)
	if dialogue_controller != null and dialogue_controller.is_active():
		dialogue_controller.dismiss_if_active()
	_tween_dialogue_camera_weight(0.0, 0.45)
	player.movement_enabled = false
	if player.has_method("set_dash_enabled"):
		player.set_dash_enabled(false)

	await elevator_floor_door.open_doors(0.45)

	entry_return_position = player.global_position
	# The existing cab sits physically behind the lobby door, open to its threshold.
	entry_cab = preload("res://scripts/dream/independent_elevator_cab_3d.gd").new(-1)
	entry_cab.name = "ReceptionEntryCab"
	entry_cab.position = ELEVATOR_POS_3D + Vector3(0, 0, -1.3)
	add_child(entry_cab)
	entry_cab.setup_gameplay_boundaries(gameplay_world, Vector2(entry_cab.position.x, entry_cab.position.z) * CELL_PIXELS)
	await entry_cab.open_cab_doors(.30)
	# Reuse actual locomotion so feet, body and hair receive real walking velocity.
	var threshold_pos := elevator_floor_door.get_doorway_threshold_position_2d()
	await _walk_into_elevator(threshold_pos)
	await _walk_into_elevator(entry_cab.boundary_root_2d.global_position)

	await elevator_floor_door.close_doors(0.45)
	await entry_cab.close_cab_doors(.30)
	entry_ride_started_usec = Time.get_ticks_usec()
	# Move the view inside the actual cab; the closed lobby facade must not
	# remain between the camera and the passenger. Blend real scene pixels.
	var layer := CanvasLayer.new()
	layer.layer = 37
	var picture := TextureRect.new()
	if DisplayServer.get_name() != "headless":
		picture.texture = ImageTexture.create_from_image(get_tree().root.get_texture().get_image())
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(picture)
	add_child(layer)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	geometry_3d.hide()
	actor_depth_bridges_root.hide()
	waitress_npc.hide()
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(self, "entry_camera_weight", 1.0, .4).set_trans(Tween.TRANS_SINE)
	reveal.tween_property(picture, "modulate:a", 0.0, .4)
	await reveal.finished
	layer.queue_free()
	player.movement_enabled = true
	SFX.play_elevator_music(get_instance_id())
	SFX.play_elevator_rumble()

	# Transition authority is delegated to global TransitionDirector in main.gd
	elevator_entered.emit()

func _walk_into_elevator(target: Vector2) -> void:
	var elapsed := 0.0
	while is_instance_valid(player) and player.global_position.distance_to(target) > 3.0 and elapsed < 4.0:
		player.set_scripted_locomotion(player.global_position.direction_to(target), 110.0)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	if is_instance_valid(player): player.clear_scripted_locomotion()

func rollback_elevator_entry() -> void:
	player.clear_scripted_locomotion()
	player.global_position = entry_return_position
	player.movement_enabled = true
	player.set_dash_enabled(true)
	entry_ride_started_usec = 0
	entry_camera_weight = 0.0
	geometry_3d.show()
	actor_depth_bridges_root.show()
	waitress_npc.show()
	if is_instance_valid(entry_cab):
		entry_cab.cleanup_gameplay()
		entry_cab.queue_free()
		entry_cab = null
	elevator_transition_in_progress = false
	SFX.stop_elevator_music()
	SFX.stop_elevator_rumble()
	SFX.play_safe_music(get_instance_id())
	_enter_dream_time_mode()
	_update_camera_and_projection(0.0)


# =============================================================================
# Time & System Helpers
# =============================================================================

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


# =============================================================================
# Tarot & NPC Interaction System
# =============================================================================

func _setup_tarot_system() -> void:
	if waitress_npc != null and waitress_npc.has_signal(&"interaction_requested"):
		if not waitress_npc.interaction_requested.is_connected(_on_waitress_interaction_requested):
			waitress_npc.interaction_requested.connect(_on_waitress_interaction_requested)

	if dialogue_dialog != null:
		if not dialogue_dialog.session_started.is_connected(_on_dialogue_session_started):
			dialogue_dialog.session_started.connect(_on_dialogue_session_started)
		if not dialogue_dialog.session_ended.is_connected(_on_dialogue_session_ended):
			dialogue_dialog.session_ended.connect(_on_dialogue_session_ended)
		if not dialogue_dialog.action_requested.is_connected(_on_dialogue_action_requested):
			dialogue_dialog.action_requested.connect(_on_dialogue_action_requested)

	if tarot_overlay != null:
		if not tarot_overlay.selection_finished.is_connected(_on_tarot_selection_finished):
			tarot_overlay.selection_finished.connect(_on_tarot_selection_finished)


func _on_waitress_interaction_requested() -> void:
	if elevator_transition_in_progress or (tarot_overlay != null and tarot_overlay.visible): return
	if dialogue_controller==null or dialogue_bubble==null or dialogue_controller.is_active(): return
	var lines: Array=[
		"电、电梯在左边……通往办公楼……今晚也请小心。",
		"只要撑到发奖金就好了……他们都这么说。可上去的人……怎么越来越少了……",
		"我、我没在数！只是名字要记好……万一奖金算漏了，我就真的……真的……",
		"啊？！我刚刚说出声了吗？！对不起！您没听见，对吧？对、对吧……？",
		"祝您今晚工作顺利！您一定会回来的……我、我在这里等……不！不是催您回来！"
	]
	dialogue_controller.start_dialogue_sequence(dialogue_bubble,lines,_get_waitress_hud_pos,
		{"compact_dialogue":true,"interrupt_text":"","countdown_extra":4.0},_get_player_hud_pos)
	_tween_dialogue_camera_weight(1.0,.40)

func _on_waitress_dialogue_interrupted() -> void:
	waitress_npc.hint_emotion="angry"
	tarot_visit_state.selected = true
	_tween_dialogue_camera_weight(0.0, 0.45)
	if player != null and is_instance_valid(player):
		player.movement_enabled = true
		if player.has_method("set_dash_enabled"):
			player.set_dash_enabled(true)


func _on_waitress_dialogue_option_selected(index: int, choice_data: Dictionary) -> void:
	var action_id: Variant = choice_data.get("action_id", "")
	if action_id is String:
		action_id = StringName(action_id)

	if action_id == &"start_tarot":
		if player != null and is_instance_valid(player):
			player.movement_enabled = false
			if player.has_method("set_dash_enabled"):
				player.set_dash_enabled(false)
		_start_tarot_sequence()
	elif action_id == &"skip_tarot":
		tarot_visit_state.selected = true
		if player != null and is_instance_valid(player):
			player.movement_enabled = true
			if player.has_method("set_dash_enabled"):
				player.set_dash_enabled(true)
	elif action_id == &"close":
		pass


func _on_waitress_emotion_line(index: int, _line: Dictionary) -> void:
	# Authored emotional beats, not a random face carousel.
	var feelings: Array[String]=["nervous","sad","nervous","surprised","happy"]
	waitress_npc.hint_emotion=feelings[clampi(index,0,feelings.size()-1)]

func _on_waitress_dialogue_finished(interrupted: bool, action_id: Variant) -> void:
	if not interrupted: waitress_npc.hint_emotion="happy"
	if interrupted:
		tarot_visit_state.selected = true
	var act_name := StringName(str(action_id))
	if act_name == &"skip_tarot":
		tarot_visit_state.selected = true
	_tween_dialogue_camera_weight(0.0, 0.45)
	if not (tarot_overlay != null and tarot_overlay.visible) and not elevator_transition_in_progress:
		if player != null and is_instance_valid(player):
			player.movement_enabled = true
			if player.has_method("set_dash_enabled"):
				player.set_dash_enabled(true)


func _on_dialogue_session_started() -> void:
	if player != null and is_instance_valid(player):
		player.movement_enabled = false
		if player.has_method("set_dash_enabled"):
			player.set_dash_enabled(false)


func _on_dialogue_session_ended() -> void:
	_tween_dialogue_camera_weight(0.0, 0.45)
	if not elevator_transition_in_progress and not (tarot_overlay != null and tarot_overlay.visible):
		if player != null and is_instance_valid(player):
			player.movement_enabled = true
			if player.has_method("set_dash_enabled"):
				player.set_dash_enabled(true)


func _on_dialogue_action_requested(action_id: StringName) -> void:
	if action_id == &"start_tarot":
		_start_tarot_sequence()


func _start_tarot_sequence() -> void:
	if tarot_overlay != null and tarot_overlay.visible:
		return

	if dialogue_controller != null and dialogue_controller.is_active():
		dialogue_controller.dismiss_if_active()
	_tween_dialogue_camera_weight(0.0, 0.45)

	if player != null and is_instance_valid(player):
		player.movement_enabled = false
		if player.has_method("set_dash_enabled"):
			player.set_dash_enabled(false)

	# Ensure hand is drawn once per visit (locked state)
	if not tarot_visit_state.hand_generated:
		var controller := TarotDrawController.new()
		tarot_visit_state.hand = controller.draw_three()
		tarot_visit_state.hand_generated = true

	if tarot_overlay != null:
		tarot_overlay.start_tarot_sequence(tarot_visit_state.hand)


func _on_tarot_selection_finished(selected_result: TarotDrawResult) -> void:
	tarot_visit_state.selected = true
	tarot_visit_state.selected_result = selected_result

	var card_id := selected_result.get_id()
	var is_reversed := selected_result.is_reversed

	profile_state["has_tarot_card"] = true
	profile_state["selected_tarot_card_id"] = card_id
	profile_state["selected_tarot_reversed"] = is_reversed

	if not night_state.is_empty():
		night_state["has_tarot_card"] = true
		night_state["selected_tarot_card_id"] = card_id
		night_state["selected_tarot_reversed"] = is_reversed

	if tarot_overlay != null and is_instance_valid(tarot_overlay):
		tarot_overlay.dismiss(0.3)

	if dialogue_controller != null and dialogue_controller.is_active():
		dialogue_controller.dismiss_if_active()

	if dialogue_dialog != null and is_instance_valid(dialogue_dialog) and dialogue_dialog.visible:
		dialogue_dialog.close_without_signal()

	if player != null and is_instance_valid(player):
		player.movement_enabled = true
		if player.has_method("set_dash_enabled"):
			player.set_dash_enabled(true)

	interaction_consumed_until_release = true



