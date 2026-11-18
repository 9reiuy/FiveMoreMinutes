extends Node3D

signal tutorial_finished

const CELL_PIXELS := 32.0
const ROOM_WIDTH := 13
const ROOM_HEIGHT := 24
const DOOR_OPENING_START := 3
const DOOR_OPENING_END := 5
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.1
const WALL_COLLISION_THICKNESS := 16.0
## The tutorial is authored along the 2D Y axis (mapped to 3D Z).  Keep the
## player a few cells inside the south wall, then lay every other waypoint out
## as a fraction of the real Spawn -> Door travel axis.  This makes the room
## lengthening a layout change rather than a root-scale trick.
const SPAWN_AXIS := 22.0
const DOOR_AXIS := -0.5
const WASD_PROGRESS := 0.16
const LIGHT_ONE_PROGRESS := 1.0 / 3.0
const LIGHT_TWO_PROGRESS := 2.0 / 3.0
const EXIT_TRIGGER_PROGRESS := 0.92
const PLAYER_SPAWN := Vector2(4.0, SPAWN_AXIS) * CELL_PIXELS
const EXIT_TRIGGER_POSITION := Vector2(11, 1.8) * CELL_PIXELS
const FLOOR_SECTIONS := [
	Rect2i(1,18,8,6), Rect2i(1,8,8,10), Rect2i(1,2,8,6),
	Rect2i(9,2,4,22),
]
const WORLD_WALL_LAYER := 4

const WALL_SCENE: PackedScene = preload("res://scenes/dream/3d/WallStraight3D.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const ACTOR_DEPTH_BRIDGE_SCENE: PackedScene = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const DASH_AIM_PRESENTATION_SCRIPT: Script = preload("res://scripts/dream/dream_dash_aim_presentation.gd")
const INTERACTION_RESOLVER_SCRIPT: Script = preload("res://scripts/dream/dream_interaction_resolver.gd")
const DIALOGUE_CAMERA_SCRIPT: Script = preload("res://scripts/dream/dream_3d_dialogue_camera.gd")
const CONFIG: DemoConfig = preload("res://resources/demo_config.tres")
const FORMAL_WORLD=preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const MAINTENANCE = preload("res://scripts/testing/maintenance_environment.gd")
const AUTHORED_CUTOUT := preload("res://scripts/dream/authored_occlusion_cutout.gd")
const TUTORIAL_WEAR = preload("res://scripts/story/tutorial_surface_wear.gd")
const FACILITY_ART = preload("res://scripts/story/tutorial_training_facility_art.gd")
const MONITOR_FEED=preload("res://scripts/story/tutorial_monitor_feed.gd")
const TV_SPEECH_AUDIO=preload("res://scripts/story/tutorial_tv_speech_audio.gd")
const DREAM_GUN_ATLAS := preload("res://scripts/data/dream_gun_atlas.gd")
const DIALOGUE_CONVERSATION_MODE := 0
const DIALOGUE_SPEAKER_FOCUS_MODE := 1
## Match the Random Dream gameplay framing without changing the fixed camera
## angle or follow authority.  Dialogue's 0.80 factor is composed afterwards.
const GAMEPLAY_CAMERA_SIZE_MULTIPLIER := 0.5
const GAMEPLAY_CAMERA_FOV := 35.0
const GAMEPLAY_CAMERA_YAW := -PI*.25

@onready var floor_root: Node3D = $TutorialGeometry/FloorRoot
@onready var wall_root: Node3D = $TutorialGeometry/WallRoot
@onready var door_root: Node3D = $TutorialGeometry/DoorRoot
@onready var gameplay_canvas: CanvasLayer = $GameplayCanvas
@onready var gameplay_world: Node2D = $GameplayCanvas/GameplayWorld
@onready var collision_root: Node2D = $GameplayCanvas/GameplayWorld/GeneratedCollisionRoot
@onready var player: CharacterBody2D = $GameplayCanvas/GameplayWorld/DreamPlayer
var terminal: Node2D
var active_terminal: Node2D
var config: DemoConfig
@onready var exit_trigger: Area2D = $GameplayCanvas/GameplayWorld/TutorialExitTrigger
@onready var actor_depth_viewport: SubViewport = $ActorDepthViewport
@onready var actor_depth_render_root: Node2D = $ActorDepthViewport/ActorDepthRenderRoot
@onready var player_depth_bridge: Node3D = $PlayerDepthVisual3D
@onready var actor_depth_bridges_root: Node3D = $ActorDepthBridges
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_3d: Camera3D = $CameraRig/Camera3D
var audio_listener_3d: AudioListener3D
@onready var interaction_prompt: DreamDialogueBubble = $GameplayUI/TalkPrompt
@onready var control_hint: Control = $GameplayUI/ControlHint
@onready var dialogue_dialog: BedroomConfirmationDialog = $DialogueLayer/ConfirmationDialog
@onready var dialogue_bubble: DreamDialogueBubble = $DialogueLayer/DreamDialogueBubble
@onready var lighting_root: Node3D = $Lighting

var dialogue_controller: DreamDialogueController
var authored_cutout := AUTHORED_CUTOUT.new()
var tv_speech_audio: AudioStreamPlayer
var _tv_speech_room := -1

var floor_cells: Dictionary = {}
## Shared floor batch renderer reads this flag to decide whether an empty
## presentation map is intentional.  Tutorial renders its authored floor
## immediately, so it is always the non-lazy path.
var lazy_room_presentation := false
var configured_weapon_id := "basic"
var profile_state: Dictionary = {}
var interaction_resolver: DreamInteractionResolver
var exit_sequence_started := false
var interaction_consumed_until_release := false
var camera_aim_offset := Vector3.ZERO
var night_lighting: Node3D
var tutorial_ceiling_lights: Node3D
var training_zone_states: Dictionary = {}
var dash_strip_completed := false
var monitor_feed: Node
var training_unlit_fixture: StandardMaterial3D
var dialogue_camera: Node
var authoritative_camera_size := 0.0
var authoritative_camera_fov := GAMEPLAY_CAMERA_FOV
var _unknown_dialogue_speakers: Dictionary = {}
var dash_aim_presentation: Node2D
var dash_aim_depth_bridge: Node3D
var _layout_generation := 1
var _shell_visual_rng := RandomNumberGenerator.new()
var enemy_root: Node2D:
	get: return gameplay_world

func _cell_for_gameplay_position(point: Vector2) -> Vector2i:
	return Vector2i((point/CELL_PIXELS).round())

func is_player_dash_landing_allowed(point: Vector2) -> bool:
	var training: Node=get_node_or_null("ChapterTraining")
	if training==null: return true
	var cell:=point/CELL_PIXELS
	for room in 3:
		var rect: Rect2i=FLOOR_SECTIONS[room]
		if Rect2(Vector2(rect.position)-Vector2.ONE*.5,Vector2(rect.size)).has_point(cell) and not training.can_enter_room(room):return false
	return true

func get_dream_enemies_snapshot() -> Array:
	return gameplay_world.get_children().filter(func(actor): return actor is EmployeeEnemy)

func resolve_player_hit(enemy: Node,damage: float,origin: Vector2,source: StringName=&"player_projectile") -> Dictionary:
	if not is_instance_valid(enemy) or not enemy is EmployeeEnemy or enemy.dead: return {}
	var result: Dictionary=player.calculate_player_damage(damage)
	enemy.take_damage(float(result.get("damage",damage)),origin,1.,source)
	return result

func resolve_player_melee_hit(enemy: Node2D, damage: float, origin: Vector2,
		source: StringName, point: Vector2, tangent: Vector2, drop: float) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy is EmployeeEnemy:
		return {}
	var target_origin := enemy.global_position
	var before: float = enemy.current_health
	var result := resolve_player_hit(enemy, damage, origin, source)
	if is_instance_valid(enemy) and enemy.current_health < before:
		var scale := DREAM_GUN_ATLAS.get_melee_range_multiplier(player.selected_weapon_id)
		preload("res://scripts/dream/melee_crescent_hit_3d.gd").spawn(self, enemy, tangent, scale,
			{"point": point, "target_origin": target_origin, "drop": drop})
	return result

func resolve_phase_dash_attack(start: Vector2,end: Vector2,radius: float,damage: float,source: StringName,handled: Variant=null,_feedback: bool=true) -> Dictionary:
	return preload("res://scripts/dream/phase_dash_combat.gd").resolve(self,player,start,end,radius,damage,source,handled)

func _tutorial_weapon_snapshot(point: Vector2, shooter: Node2D) -> Dictionary:
	var snapshot: Dictionary = {}
	if is_instance_valid(shooter):
		var reference: Variant = shooter.get_meta(&"depth_visual_bridge") if shooter.has_meta(&"depth_visual_bridge") else null
		var bridge: Node = reference.get_ref() if reference is WeakRef else null
		if is_instance_valid(bridge): snapshot = bridge.get_weapon_visual_snapshot(point)
	return {
		"world_origin": snapshot.get("world_origin", to_global(Vector3(point.x / CELL_PIXELS, .65, point.y / CELL_PIXELS))),
		"gameplay_origin": snapshot.get("gameplay_origin", point)
	}

func _capture_tutorial_shot_origin(effect: Node2D, shooter: Node2D) -> void:
	var snapshot := _tutorial_weapon_snapshot(effect.global_position, shooter)
	var origin: Vector3 = snapshot.world_origin
	effect.set_meta(&"shot_visual_origin", origin)
	effect.set_meta(&"shot_gameplay_origin", snapshot.get("gameplay_origin", effect.global_position))
	effect.set_meta(&"shot_height_pixels", to_local(origin).y * CELL_PIXELS)

func add_projectile(projectile: Node2D,source: Node2D=null) -> void:
	projectile.enable_office_ballistics()
	projectile.add_to_group(&"dream_projectiles")
	gameplay_world.add_child(projectile)
	var shooter: Node2D = source if is_instance_valid(source) else projectile._get_live_shooter()
	_capture_tutorial_shot_origin(projectile, shooter)
	projectile.limit_flight_to_camera(self, Vector2(0.65, 0.0))
	_tutorial_effect_bridge(projectile,[NodePath("BulletSprite")],.65)

func spawn_weapon_muzzle(point: Vector2,direction: Vector2,kind: StringName,source: Node2D=null) -> void:
	var snapshot := _tutorial_weapon_snapshot(point, source)
	var origin: Vector3 = snapshot.world_origin
	if is_instance_valid(night_lighting):
		night_lighting.flash_muzzle_world(origin, kind)
	_firearm_fx().muzzle(origin, global_basis * Vector3(direction.x, 0.0, direction.y), kind)

func _firearm_fx() -> Node3D:
	var fx := get_node_or_null("FirearmFlashFX") as Node3D
	if fx == null:
		fx = preload("res://scripts/dream/firearm_flash_fx_3d.gd").new()
		fx.name = "FirearmFlashFX"
		add_child(fx)
		fx.configure(camera_3d, preload("res://scripts/dream/floor_reflections.gd").EXCLUDED)
	return fx

func spawn_shell_ejection(point: Vector2,direction: Vector2,weapon_id: StringName=&"") -> void:
	if not DREAM_GUN_ATLAS.ejects_shell(String(weapon_id)): return
	var effect: Node2D = preload("res://scenes/entities/shell_effect.tscn").instantiate()
	gameplay_world.add_child(effect)
	effect.global_position = point - direction.normalized() * 3.
	effect.setup(DREAM_GUN_ATLAS.get_shell(String(weapon_id)), direction, _shell_visual_rng, CONFIG.shell_effect_lifetime, CONFIG.shell_effect_fake_gravity)
	var pool: Node3D = actor_depth_bridges_root.get_node_or_null(^"ShellCapturePool")
	if pool == null:
		pool = preload("res://scripts/dream/shell_capture_pool.gd").new()
		pool.name = "ShellCapturePool"; actor_depth_bridges_root.add_child(pool)
	pool.acquire(effect, camera_3d)

func spawn_combat_feedback(point: Vector2,direction: Vector2=Vector2.ZERO,is_kill: bool=false) -> void:
	var effect:=preload("res://scenes/entities/combat_feedback_effect.tscn").instantiate()
	gameplay_world.add_child(effect); effect.global_position=point
	effect.setup(direction,is_kill,.18); effect.enable_nyangeon_style()
	_tutorial_effect_bridge(effect,[NodePath(".")],.72)

func request_hit_stop(_level: StringName=&"small") -> void:
	# Safe exercises share damage/visuals without changing the world's time owner.
	pass

func project_player_death_weapon(drop: Node2D, rest_height: float) -> void:
	if is_instance_valid(drop) and not drop.is_queued_for_deletion():
		_tutorial_effect_bridge(drop, [^"WeaponSprite"], rest_height, Vector2(64, 64))


func _tutorial_effect_bridge(source: Node2D,paths: Array,height: float,offset: Vector2=Vector2(64,96)) -> void:
	var bridge: Node3D=ACTOR_DEPTH_BRIDGE_SCENE.instantiate()
	actor_depth_bridges_root.add_child(bridge)
	bridge.set_world_camera(camera_3d)
	source.set_meta(&"depth_visual_bridge", weakref(bridge))
	var viewport: SubViewport = bridge.get_node("ActorDepthViewport")
	if source.has_method(&"flush_office_tracer_update"):
		# Same full radial history extent as the formal projectile pool.
		viewport.size = Vector2i(512, 512)
		offset = Vector2(256, 256)
	bridge.configure(source,viewport,bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"),null,paths,height,0.,offset)


func configure_tutorial(weapon_id: String, profile: Dictionary) -> void:
	configured_weapon_id = DREAM_GUN_ATLAS.sanitize_weapon_id(weapon_id)
	profile_state = profile


func _enter_tree() -> void:
	set_meta(&"native_maintenance_environment",true)
	add_to_group(&"dream_world")

func uses_office_night_lighting() -> bool:
	return RenderingServer.get_current_rendering_method()=="forward_plus"


func _ready() -> void:
	camera_rig.rotation.y = GAMEPLAY_CAMERA_YAW
	config=CONFIG.duplicate(true)
	for property in ["basic_projectile_speed","assault_rifle_projectile_speed","shotgun_projectile_speed"]:
		config.set(property,FORMAL_WORLD.FIREARM_PROJECTILE_SPEED_3D)
	preload("res://scripts/app/game_input_actions.gd").configure()
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
	_configure_collage_layout()
	_apply_authored_layout()
	player.set("selected_weapon_id", configured_weapon_id)
	player.configure_weapon(configured_weapon_id, config, profile_state.get("permanent_upgrades", {}))
	player.set_meta(&"presentation_hand_direction",Callable(self,"get_hand_presentation_direction"))
	if player.has_method("configure_profile_stats"):
		player.call("configure_profile_stats", int(profile_state.get("character_hp_cells", CONFIG.character_card_default_hp_cells)))
	player.set_attacking_enabled(false)
	# The tutorial uses the office controls, with dialogue and exit locks below.
	player.set_dash_enabled(true)
	player.movement_enabled = true
	_enter_dream_time_mode()
	_configure_depth_visuals()
	var target_highlight := preload("res://scripts/dream/dream_3d_target_highlight.gd").new()
	target_highlight.name = "MeleeTargetHighlight"
	add_child(target_highlight)
	target_highlight.configure(self, false)
	_setup_dash_aim_presentation()
	_configure_lighting()
	# The authored equipment fixtures build their mesh children on a deferred call.
	_apply_equipment_wear.call_deferred()
	interaction_resolver = INTERACTION_RESOLVER_SCRIPT.new()
	interaction_resolver.name = "DreamInteractionResolver"
	add_child(interaction_resolver)
	interaction_resolver.configure(player, [&"tutorial_interaction_targets"])
	for index in 3:
		get_tutorial_terminal(index).interaction_requested.connect(_on_terminal_interaction_requested.bind(index))
	exit_trigger.body_entered.connect(_on_exit_trigger_entered)
	_setup_dialogue_controller()
	if dialogue_dialog != null:
		dialogue_dialog.session_started.connect(_on_dialogue_session_started)
		dialogue_dialog.session_ended.connect(_on_dialogue_session_ended)
		if dialogue_dialog.has_signal("line_presented"):
			dialogue_dialog.line_presented.connect(_on_dialogue_line_presented)
	_update_camera_and_projection(0.0)
	_setup_monitor_feed()
	_setup_3d_audio_listener()
	var liquid_health: Control = $GameplayUI/LiquidHealthMeter
	liquid_health.set_motion_source(player)
	player.health_changed.connect(liquid_health.set_health)
	liquid_health.set_health(player.current_health, player.maximum_health)
	var low_health_blood: Control = get_node_or_null("GameplayUI/LowHealthBloodOverlay") as Control
	if is_instance_valid(low_health_blood) and low_health_blood.has_method("set_health"):
		player.health_changed.connect(low_health_blood.set_health)
		low_health_blood.call("set_health", player.current_health, player.maximum_health, true)


func _exit_tree() -> void:
	if has_meta(&"display_reparenting"):
		return
	authored_cutout.clear_slots()
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
		dialogue_controller.progress_updated.connect(_on_tv_dialogue_progress)
		dialogue_controller.state_changed.connect(_on_tv_dialogue_state_changed)
	if tv_speech_audio == null:
		tv_speech_audio = TV_SPEECH_AUDIO.new()
		tv_speech_audio.name = "TelevisionSpeechAudio"
		add_child(tv_speech_audio)


func _on_controller_line_started(_line_index: int, line_data: Dictionary) -> void:
	var speaker_id := StringName(str(line_data.get("speaker", "terminal")))
	var speaker := _resolve_dialogue_speaker(speaker_id)
	if speaker != null:
		set_dialogue_speaker(speaker)
	# The line-start signal precedes the controller resetting its typing clock.
	_update_tv_speech_audio.call_deferred()


func _on_tv_dialogue_progress(_ratio: float, _typed_chars: int) -> void:
	_update_tv_speech_audio()


func _on_tv_dialogue_state_changed(_old: int, _new: int) -> void:
	_update_tv_speech_audio()


func _update_tv_speech_audio() -> void:
	if not is_instance_valid(tv_speech_audio): return
	var speaking := false
	var room := -1
	if not exit_sequence_started and is_instance_valid(player) and not player.dead and dialogue_controller != null:
		if dialogue_controller.is_active():
			room = _tv_speech_room
			speaking = dialogue_controller.is_typing() and not dialogue_controller._is_transitioning_line
		else:
			var lesson := get_node_or_null("ChapterTraining")
			if lesson != null:
				var call: Dictionary = lesson.get_call_state()
				if not call.is_empty() and bool(call.visible):
					room = int(call.room)
					speaking = true
	if speaking:
		speaking = is_instance_valid(monitor_feed) and room >= 0 and room < monitor_feed.stations.size()
		if speaking:
			var station: Node3D = monitor_feed.stations[room]
			speaking = station.power_available and station.screen_active
	tv_speech_audio.set_speaking(speaking)
	# The same lesson/typing decision drives both sound and the speaker's glass.
	# Keep the frame-copy feed alive so returning from snow shows a fresh frame.
	if is_instance_valid(monitor_feed):
		for index in monitor_feed.stations.size():
			monitor_feed.stations[index].set_speaking(speaking and index==room)


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
	var projectiles: Array[Node] = []
	if config.projectile_occlusion_cutout_enabled:
		projectiles = get_tree().get_nodes_in_group(&"dream_projectiles")
	authored_cutout.update_slots(camera_3d, projectiles, config.projectile_occlusion_cutout_radius,player_depth_bridge.actor_sprite,true)
	if is_instance_valid(monitor_feed):monitor_feed.update_frame()
	_update_dash_aim_presentation()

	if dialogue_controller != null and dialogue_controller.is_active():
		if not exit_sequence_started and player != null and is_instance_valid(active_terminal):
			var dist: float = player.global_position.distance_to(active_terminal.global_position)
			var training: Node = get_node_or_null("ChapterTraining")
			if dist > 160.0 and (training == null or not training.is_completion_dialogue()):
				dialogue_controller.dismiss_if_active()
		if dialogue_bubble != null and is_instance_valid(dialogue_bubble) and is_instance_valid(active_terminal) and player != null and camera_3d != null:
			var terminal_world_pos: Vector3 = Vector3(active_terminal.global_position.x / CELL_PIXELS, 1.8, active_terminal.global_position.y / CELL_PIXELS)
			var terminal_hud_pos: Vector2 = player.get_presentation_hud_position(camera_3d.unproject_position(terminal_world_pos))
			dialogue_bubble.set_speaker_hud_position(terminal_hud_pos)

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
	_update_tv_speech_audio()


func _setup_monitor_feed() -> void:
	monitor_feed=MONITOR_FEED.new();monitor_feed.name="TutorialMonitors";add_child(monitor_feed)
	var televisions: Array[Node3D]=[]
	for room in ["Preparation","Movement","Range"]:
		televisions.append(get_node("TutorialGeometry/ChapterLayout/"+room+"/TelevisionDesk"))
	monitor_feed.configure(camera_3d,player,FLOOR_SECTIONS.slice(0,3),televisions)


func _build_fixed_room() -> void:
	floor_cells.clear()
	for rect in FLOOR_SECTIONS:
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y): floor_cells[Vector2i(x,y)]=true
	for index in FLOOR_SECTIONS.size():
		var rect: Rect2i = FLOOR_SECTIONS[index]
		var finish := FACILITY_ART.floor_material(index >= 3,rect)
		var size := Vector3(rect.size.x, .2, rect.size.y)
		var centre := Vector3(rect.position.x + (rect.size.x - 1) * .5, -.1, rect.position.y + (rect.size.y - 1) * .5)
		MAINTENANCE.box(floor_root, "FacilityFloor", size, centre, finish)


func _apply_authored_layout() -> void:
	player.global_position = PLAYER_SPAWN
	exit_trigger.position = EXIT_TRIGGER_POSITION

func _configure_collage_layout() -> void:
	var layout: Node3D=$TutorialGeometry/ChapterLayout
	var section_material := authored_cutout.top_black
	var wall_finish := authored_cutout.material_for(FACILITY_ART.wall_material())
	for item in layout.find_children("*","Node3D",true,false):
		if FACILITY_ART.gallery_divider(item):
			item.hide()
			continue
		if item.name=="AmmunitionDesk": item.set_meta(&"furniture_surface",true)
		if item.has_meta("solid_size"):
			var at: Vector3=to_local(item.global_position)
			_spawn_wall_collision(Vector2(at.x,at.z)*CELL_PIXELS,Vector2(item.get_meta("solid_size")).rotated(item.global_rotation.y).abs()*CELL_PIXELS,"Collage_"+item.name,int(item.get_meta("solid_layer",4)))
		if item.has_method("bind_gameplay"): item.bind_gameplay(collision_root)
		if FACILITY_ART.bay_front(item):
			# Its authoritative 2D boundary remains; the old opaque visual and
			# shadow caster are replaced by an actual steel safety mesh.
			item.hide()
			continue
		if item.has_meta("cutaway"):
			item.office_section_material=section_material
			var exterior_front := String(item.name).ends_with("_S") or String(item.name).ends_with("_E")
			var shared := String(item.name).begins_with("SharedWall_")
			item.set_wall_materials(section_material if exterior_front else wall_finish,wall_finish if shared or exterior_front else section_material)
			item.set_cutaway_mode(bool(item.get_meta("cutaway")))
		if item is MeshInstance3D and item.has_meta("pixel_swatch") and item.name!="Indicator" and not item.has_meta("floor_light_strip"):
			var mat: StandardMaterial3D=item.material_override
			item.material_override=MAINTENANCE.concrete(true) if item.name=="Floor" else MAINTENANCE.metal(mat.albedo_color,.68)
		if item is MeshInstance3D and item.has_meta("floor_style"):
			item.material_override=MAINTENANCE.concrete(true)
		if item is MeshInstance3D and bool(item.get_meta(&"black_top",false)):
			item.material_override=section_material
		if item is MeshInstance3D and item.has_meta("floor_light_strip"):
			item.material_override=StandardMaterial3D.new()
			item.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		if item is MeshInstance3D and item.has_meta("painted_line"):
			var paint:=StandardMaterial3D.new();paint.albedo_color=Color(.8,.8,.77)
			paint.roughness=.96;paint.metallic_specular=.02;item.material_override=paint
	terminal=layout.get_node("Preparation/TelevisionDesk").interaction_target
	for wall in wall_root.get_children():
		if String(wall.name).begins_with("SouthWall") and wall.has_method("set_cutaway_mode"): wall.set_cutaway_mode(true)


func _apply_equipment_wear() -> void:
	var layout := $TutorialGeometry/ChapterLayout
	TUTORIAL_WEAR.apply(layout, tutorial_ceiling_lights)
	FACILITY_ART.new().install(self)
	for item in layout.get_node(^"Architecture").get_children():
		if item.has_meta(&"cutaway"):
			authored_cutout.register_mesh(item.wall_mesh)
		elif item.has_method("bind_gameplay"):
			authored_cutout.register_tree(item, true, [&"Indicator", &"Sill"])
	for room in [^"Preparation", ^"Movement", ^"Range"]:
		for item in layout.get_node(room).get_children():
			if item.name == &"TelevisionDesk" or item.has_meta(&"solid_size"):
				authored_cutout.register_tree(item, false, [&"Screen", &"StatusLED"])


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


func _spawn_wall_collision(center: Vector2, size: Vector2, node_name: String, layer: int=4) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	collision_root.add_child(body)
	body.position = center


func _configure_depth_visuals() -> void:
	player_depth_bridge.office_linear_lighting=uses_office_night_lighting()
	player_depth_bridge.configure(
		player,
		actor_depth_viewport,
		actor_depth_render_root,
		gameplay_canvas,
		[NodePath("CharacterVisual"),NodePath("WeaponRoot")]
	)
	player_depth_bridge.set_world_camera(camera_3d)
	configure_character_readability(player_depth_bridge)
	player.set_meta(&"depth_visual_bridge",weakref(player_depth_bridge))
	# The primary sprite is supplied explicitly with the lower-body probe,
	# so a foreground lintel cannot hide just the feet below a visible torso.


func configure_character_readability(bridge: Node3D) -> void:
	# Tutorial actors and their outlines require actual scene light.
	for field in ["lit_material","weapon_material"]:
		var material: ShaderMaterial=bridge.get(field)
		if material!=null:
			material.set_shader_parameter("character_emission_strength",0.0)
			material.set_shader_parameter("character_light_scale",1.0)
			material.set_shader_parameter("enemy_rim_self_emission",false)


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
	night_lighting.set_flashlight_enabled(false)
	var key_light := get_node_or_null("Lighting/KeyLight") as DirectionalLight3D
	if key_light != null:
		key_light.visible=false
	MAINTENANCE.configure_environment(self)
	var environment: Environment=get_node("Lighting/WorldEnvironment").environment
	environment.background_color=Color.BLACK
	environment.ambient_light_color=Color.BLACK;environment.ambient_light_energy=0.0
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
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
	if lighting_root==null:return
	if is_instance_valid(tutorial_ceiling_lights):tutorial_ceiling_lights.queue_free()
	tutorial_ceiling_lights=Node3D.new()
	tutorial_ceiling_lights.name="TutorialCeilingLightRoot"
	lighting_root.add_child(tutorial_ceiling_lights)
	var specs: Array[Dictionary] = []
	for zone in 3:
		var room: Rect2i = FLOOR_SECTIONS[zone]
		var at := Vector3(room.position.x + (room.size.x - 1) * .5, 2.35, room.position.y - .28)
		specs.append({"at":at,"zone":zone,"yaw":0.0})
	specs.append_array([
		{"at":Vector3(12.37,2.35,13.0),"zone":1,"yaw":-PI*.5},
		{"at":Vector3(12.37,2.35,5.0),"zone":2,"yaw":-PI*.5},
		{"at":Vector3(12.37,2.35,21.0),"zone":0,"yaw":-PI*.5},
	])
	for index in specs.size():
		var fixture := FACILITY_ART.fixture(tutorial_ceiling_lights,"ColdFixture_%02d"%index,specs[index].at,index,specs[index].yaw)
		fixture.set_meta(&"training_zone",specs[index].zone)
		if index == 1:
			var pool: OmniLight3D = fixture.get_node("ColdPool")
			pool.omni_range = 10.5
			pool.light_energy = 3.0
	# Start dark before the first rendered frame, including the dormant room art.
	for zone in 3:set_training_zone_enabled(zone,zone==0)


func set_training_zone_enabled(zone: int, enabled: bool) -> void:
	if training_zone_states.get(zone,null)==enabled: return
	training_zone_states[zone]=enabled
	if training_unlit_fixture==null:
		training_unlit_fixture=StandardMaterial3D.new()
		training_unlit_fixture.albedo_color=Color(.07,.09,.12)
		training_unlit_fixture.roughness=.9
	if is_instance_valid(tutorial_ceiling_lights):
		for holder in tutorial_ceiling_lights.get_children():
			if int(holder.get_meta(&"training_zone",-1))!=zone: continue
			for item in holder.find_children("*","Light3D",true,false):
				item.visible=enabled
			for item in holder.find_children("*","MeshInstance3D",true,false):
				if not item.has_meta(&"training_on_material"):
					var material: Material=item.material_override
					if material is StandardMaterial3D and material.emission_enabled:
						item.set_meta(&"training_on_material",material)
				if item.has_meta(&"training_on_material"):
					item.material_override=item.get_meta(&"training_on_material") if enabled else training_unlit_fixture
	var task: Light3D=get_node_or_null("TutorialGeometry/ChapterLayout/"+("RegistrationTask" if zone==0 else "WeaponTask")) as Light3D
	if task!=null and zone!=1: task.visible=enabled
	if zone==1:_apply_dash_strip_power(enabled)
	if zone==2:
		var training: Node=get_node_or_null("ChapterTraining")
		if training!=null: training.set_range_visible(enabled)



func set_dash_strip_complete(completed: bool) -> void:
	dash_strip_completed=completed
	_apply_dash_strip_power(bool(training_zone_states.get(1,false)))


func _apply_dash_strip_power(powered: bool) -> void:
	for key in ["StartGroove","DashStrip","FinishSensor"]:
		var strip: MeshInstance3D=get_node("TutorialGeometry/ChapterLayout/Movement/"+key)
		var material: StandardMaterial3D=strip.material_override
		var colour:=Color("5cf6b5") if dash_strip_completed else Color("f5bd58")
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=colour if powered else Color.BLACK
		material.emission_enabled=powered;material.emission=colour;material.emission_energy_multiplier=1.7
		# Optical glow only: no Light3D, GI injection or extra floor illumination.
		strip.gi_mode=GeometryInstance3D.GI_MODE_DISABLED


func _update_camera_and_projection(delta: float) -> void:
	if player == null or camera_3d == null:
		return
	var gameplay_position: Vector2 = player.global_position
	var ground_position := Vector3(gameplay_position.x / CELL_PIXELS, 0.0, gameplay_position.y / CELL_PIXELS)
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("advance", delta, ground_position)
	if delta > 0.0 and not player.dead:
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
	var zoom := lerpf(1.0, dialogue_zoom, dialogue_weight)
	var death_weight: float = player.get_death_camera_weight()
	if death_weight > 0.0:
		var point: Vector2 = player.get_death_camera_focus()
		composed_focus = composed_focus.lerp(Vector3(point.x / CELL_PIXELS, 0.26, point.y / CELL_PIXELS), death_weight)
		zoom *= lerpf(1.0, 0.68, death_weight)
	camera_rig.position = camera_rig.position.lerp(composed_focus,1.-exp(-delta*10.)) if delta>0 else composed_focus
	if camera_3d.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera_3d.fov = authoritative_camera_fov * zoom
	else:
		camera_3d.size = authoritative_camera_size * GAMEPLAY_CAMERA_SIZE_MULTIPLIER * zoom
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
		time_controller.call("enter_dream_time_mode", player, config, self)


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

func get_hand_presentation_direction() -> Vector2:
	var torso:=get_gameplay_world_position(player.global_position,.65)
	return player.get_presentation_pointer_position()-camera_3d.unproject_position(torso)

func get_tutorial_terminal(room: int) -> Node2D:
	return get_node("TutorialGeometry/ChapterLayout/"+["Preparation","Movement","Range"][room]+"/TelevisionDesk").interaction_target

func get_terminal_hud_position(room: int) -> Vector2:
	var source:=get_tutorial_terminal(room)
	return player.get_presentation_hud_position(camera_3d.unproject_position(get_gameplay_world_position(source.global_position,1.8)))


func get_vision_occluder_collision_mask() -> int:
	return WORLD_WALL_LAYER


func _update_interaction_prompt() -> void:
	var blocked: bool=exit_sequence_started or player.dead or dialogue_controller.is_active()
	if blocked:interaction_prompt.dismiss();return
	var lesson: Node=get_node_or_null("ChapterTraining")
	if lesson!=null:
		var call: Dictionary=lesson.get_call_state()
		if not call.is_empty():
			if call.visible:interaction_prompt.present_hint(get_terminal_hud_position(int(call.room)),String(call.text))
			else:interaction_prompt.dismiss()
			return
	var target: Node=interaction_resolver.current_target
	for index in 3:
		var source:=get_tutorial_terminal(index)
		if target==source and source.interaction_enabled:
			interaction_prompt.present_hint(get_terminal_hud_position(index),"交谈");return
	interaction_prompt.dismiss()


func _on_terminal_interaction_requested(room: int=0) -> void:
	if exit_sequence_started or player.dead or dialogue_controller.is_active():return
	$ChapterTraining.request_tv_interaction(room)


func show_tv_dialogue(room: int, dialogue_id: StringName) -> bool:
	var data: Dictionary=TextContent.get_dialogue(dialogue_id)
	var lines: Array=data.get("lines",[])
	if lines.is_empty() or dialogue_controller.is_active():return false
	active_terminal=get_tutorial_terminal(room)
	_tv_speech_room=room
	var finished: Array[bool]=[false]
	var on_finished:=func():finished[0]=true
	dialogue_controller.dialogue_sequence_finished.connect(on_finished,CONNECT_ONE_SHOT)
	player.movement_enabled=false;player.set_attacking_enabled(false);player.set_dash_enabled(false)
	var speaker_hud:=func() -> Vector2:return get_terminal_hud_position(room)
	var player_hud:=func() -> Vector2:
		return player.get_presentation_hud_position(camera_3d.unproject_position(get_gameplay_world_position(player.global_position,.65)))
	begin_dialogue_focus(active_terminal,DIALOGUE_CONVERSATION_MODE)
	dialogue_controller.start_dialogue_sequence(dialogue_bubble,lines,speaker_hud,{"compact_dialogue":true,"interrupt_text":"","countdown_extra":.85,"blip_sound":&""},player_hud)
	_update_tv_speech_audio()
	while is_inside_tree() and dialogue_controller.is_active():await get_tree().process_frame
	if not is_inside_tree():return false
	if dialogue_controller.dialogue_sequence_finished.is_connected(on_finished):
		dialogue_controller.dialogue_sequence_finished.disconnect(on_finished)
	end_dialogue_focus();active_terminal=null
	_tv_speech_room=-1
	_update_tv_speech_audio()
	player.movement_enabled=not exit_sequence_started and not player.dead
	return finished[0] and not player.dead


func _on_exit_trigger_entered(body: Node) -> void:
	if body == player and not exit_sequence_started:
		_begin_exit_sequence()


func _begin_exit_sequence() -> void:
	if has_node("ChapterTraining") and not $ChapterTraining.can_exit():return
	if exit_sequence_started:return
	exit_sequence_started=true
	control_hint.dismiss()
	dialogue_controller.dismiss_if_active()
	interaction_resolver.clear_target()
	if is_instance_valid(terminal):terminal.set_interaction_enabled(false)
	player.movement_enabled=false;player.set_attacking_enabled(false);player.set_dash_enabled(false)
	await get_tree().create_timer(.25,false).timeout
	tutorial_finished.emit()


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
		&"terminal":
			return active_terminal if is_instance_valid(active_terminal) else terminal
		&"player":
			return player if player != null and is_instance_valid(player) else null
		&"system", &"narrator", &"":
			return null
		_:
			return null
