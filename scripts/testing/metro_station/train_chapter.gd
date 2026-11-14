extends RefCounted
## 0-6 progression. The linked world keeps the same player, weapons and camera.

const ART := preload("res://scripts/testing/metro_station/train_chapter_art.gd")
const BOSS_ART := preload("res://scripts/testing/metro_station/metro_boss_art.gd")
const BOSS_HEALTH_UI := preload("res://scripts/testing/metro_station/metro_boss_health.gd")
const BOSS_BUBBLE := preload("res://scenes/ui/dialogue/growing_dialogue_bubble.tscn")
const ADAPTER := preload("res://scripts/dream/office_skeleton_layout_adapter.gd")
const METRO_AUDIO := preload("res://scripts/testing/metro_station/metro_train_audio.gd")
const CONSIST := ART.CONSIST
const DERAILMENT := preload("res://scripts/testing/metro_station/train_derailment.gd")
const FRONT := CONSIST.CAR_COUNT - 1
const BOSS_TRIGGER_CAR := 2
const RIVAL_OVERTAKE_SPEED := 2.1
const BOSS_WINDOW_Z := CONSIST.TRACK_GAP-.30
const BOSS_TRIGGER_CENTER := CONSIST.FIRST_CENTER+BOSS_TRIGGER_CAR*CONSIST.D.CAR_SPACING
const BOSS_TRIGGER_X := BOSS_TRIGGER_CENTER+4.25
const BOSS_TRIGGER_AREA := Rect2(BOSS_TRIGGER_CENTER-5.0,.58,10.0,.72)
const BOSS_DEFEAT_DELAY := 2.0
const PLATFORM_ROOM := CONSIST.CAR_COUNT
const RIVAL_ROOM := PLATFORM_ROOM + 1
const ENTRY := Vector2(3.60, 0.0)
const ROLL_SPEED := 18.0
const RIDE_CAMERA_YAW := -PI * .75
const ARRIVAL_CAMERA_YAW := -PI * .5
const COAST_SECONDS := 2.0
const DOCK_SECONDS := 3.2
const DOCK_RUN := ROLL_SPEED * DOCK_SECONDS * .5
const APPROACH_SECONDS := 3.4
const APPROACH_RUN := 22.0
const TAUNTS := ["我以为你已经被处理了", "真是没用"]
const TAUNT_SECONDS := [1.9, 1.3]
const TAUNT_CAMERA_OFFSET := Vector3(0.0, 0.0, 1.05)
const TAUNT_ZOOM := .74
const TAUNT_ENTER_SECONDS := .38
const TAUNT_EXIT_SECONDS := .28
const DODGE_CUE := "快躲开"
const BOSS_WEAPON := "mp5"
const SPLIT_SECONDS := 2.85
const SWITCH_SCROLL_SPEED := 12.6
const RIVAL_PULL_AHEAD_SPEED := 5.4
const BOSS_HEALTH := 72.0
const BOSS_START_X := CONSIST.FIRST_CENTER + FRONT * CONSIST.D.CAR_SPACING + 4.25
const CREWS := [
	[],
	[["lucille", Vector2(-4.3, .24)], ["basic", Vector2(1.62, -.26)]],
	[["lucille", Vector2(-3.5, -.24)], ["basic", Vector2(3.12, .26)]],
	[["lucille", Vector2(-4.5, .22)], ["lucille", Vector2(.40, -.25)], ["shotgun", Vector2(5.8, .26)]],
	[["lucille", Vector2(-2.6, -.25)], ["basic", Vector2(5.80, .30)]],
	[["lucille", Vector2(-3.5, .24)], ["shotgun", Vector2(4.30, -.26)]],
]

enum Phase { RIDE, APPROACH, BOSS, FALL, SPLIT, CLEAR_CARS, COAST, DOCK, OPEN_DOOR, PLATFORM, CLIMB, COMPLETE }

var world: Node3D
var art: ART
var phase := Phase.RIDE
var active_car := 0
var derailment: DERAILMENT
var _boss_defeated_pending := false
var _boss_defeated_usec := 0
var _intro_frozen: Array[Dictionary] = []
var crews: Array[Array] = []
var boss: EmployeeEnemy
var travel := 0.0
var _yaw := 0.0
var _phase_elapsed := 0.0
var _rival_intro_offset := 0.0
var _roll: AudioStreamPlayer
var _boss_bar: BOSS_HEALTH_UI
var _boss_speech_canvas: Node2D
var _boss_bubble: DreamDialogueBubble
var _taunt_line := -1
var _taunt_left := 0.0
var _taunt_camera_started := false
var _saved_taunt_zoom := 1.0
var _saved_taunt_enter := 0.0
var _slow_owner: Node
var _intro_roll := false
var _boss_carriage: Node3D
var _boss_seat := Vector3.ZERO
var _turn_x := 0.0
var _split_reference := 0.0
var _exit_car := FRONT
var _exit_x := BOSS_START_X
var _platform_gate: Dictionary
var _dock_shift := 0.0
var _walk_shape_offset := Vector2.ZERO
var _saved_aim: Variant
var _stage_controls := Vector3i.ONE
var _controls_held := false
var _aim_ray := PhysicsRayQueryParameters2D.new()


func _init(owner: Node3D) -> void:
	world = owner


func build(whitebox := false) -> void:
	_yaw = world.camera_rig.rotation.y
	_install_layout(true)
	ART.M.configure_environment(world)
	var environment: Environment = world.get_node(^"Lighting/WorldEnvironment").environment
	environment.background_color = Color.BLACK
	environment.ambient_light_color = Color("93bbb4")
	environment.ambient_light_energy = .19 if not whitebox else .52
	art = ART.new(world, whitebox)
	art.build()
	derailment = DERAILMENT.new()
	art.root.add_child(derailment)
	derailment.configure(world,art.player_train)
	world.authored_cutout = art.cutout
	world.camera_rig.rotation.y = _yaw + RIDE_CAMERA_YAW
	world.player.collision_mask |= ART.ACTOR_EDGE
	# Align the walk circle with the rendered feet in the original narrow gangways.
	_walk_shape_offset = world.player.body_collision.position
	world.player.body_collision.position = Vector2.ZERO
	world.player.global_position = _pixels(ENTRY)
	world.player.velocity = Vector2.ZERO
	world.camera_aim_offset = Vector3.ZERO
	world.camera_impulse_offset = Vector3.ZERO
	world._clear_camera_shake()
	world.set_current_room_id(0)
	world._update_camera_and_actor_projection(0.0)
	_prepare_crews()
	if world.spawn_content:
		_weapon_pickup(0, "basic", Vector2(4.38, -.28))
	_roll = _play_sound(METRO_AUDIO.ROLL, -16.0, true)


func reset() -> void:
	_finish_dodge_intro()
	_clear_taunt_presentation()
	if is_instance_valid(world.player):
		_release_controls()
	if is_instance_valid(derailment): derailment.queue_free()
	world.camera_rig.rotation.y = _yaw
	if is_instance_valid(world.player):
		world.player.body_collision.position = _walk_shape_offset
		world.player.clear_scripted_locomotion()
		if phase == Phase.CLIMB:
			_restore_stair_aim()
		if is_instance_valid(world.player_depth_bridge):
			world.player_depth_bridge.ground_surface_height = 0.0


func advance(delta: float) -> void:
	if world.player.dead:
		_finish_dodge_intro()
		_clear_taunt_presentation()
		if is_instance_valid(_roll) and _roll.playing:
			_roll.stop()
		return
	_phase_elapsed += delta
	var local := _local(world.player.global_position)
	if phase in [Phase.RIDE,Phase.BOSS,Phase.CLEAR_CARS]:
		derailment.update_clock(true)
		if world.player.dead: return
	else: derailment.update_clock(false)
	match phase:
		Phase.RIDE:
			travel += ROLL_SPEED * delta
			_advance_cars(local, delta)
			if _at_boss_glass():
				_start_approach()
		Phase.APPROACH:
			_advance_approach(delta)
		Phase.BOSS:
			travel += ROLL_SPEED * delta
			_advance_cars(local,delta)
			_advance_boss(delta)
		Phase.FALL:
			travel += ROLL_SPEED * delta
			_sync_boss_carriage()
			boss.death_ground_velocity = Vector2.ZERO
			boss.death_presentation_left = maxf(boss.death_presentation_left,2.0)
			if _phase_elapsed >= BOSS_DEFEAT_DELAY and Time.get_ticks_usec()-_boss_defeated_usec >= int(BOSS_DEFEAT_DELAY*1000000.0):
				_start_split()
		Phase.SPLIT:
			_advance_split()
		Phase.CLEAR_CARS:
			travel += ROLL_SPEED * delta
			_advance_cars(local,delta)
			if _ready_for_station(local):
				_hold_controls(true)
				_freeze_intro_combat()
				phase = Phase.COAST
				_phase_elapsed = 0.0
		Phase.COAST:
			_scroll_past_turnout(ROLL_SPEED * delta)
			# Rejoin the original arrival shot during the existing pre-braking wait.
			var turn := smoothstep(0.0, COAST_SECONDS, _phase_elapsed)
			world.camera_rig.rotation.y = _yaw + lerpf(RIDE_CAMERA_YAW, ARRIVAL_CAMERA_YAW, turn)
			if _phase_elapsed >= COAST_SECONDS:
				_start_docking()
		Phase.DOCK:
			var t := minf(_phase_elapsed / DOCK_SECONDS, 1.0)
			var ease := smoothstep(0.0, 1.0, t)
			world.camera_rig.rotation.y = _yaw + ARRIVAL_CAMERA_YAW * (1.0 - ease)
			var station_x := _dock_shift + DOCK_RUN * (1.0 - t) * (1.0 - t)
			_scroll_past_turnout(art.station.position.x - station_x)
			art.station.position.x = station_x
			if _phase_elapsed >= DOCK_SECONDS:
				art.set_travel(travel, false, false)
				phase = Phase.OPEN_DOOR
				_play_sound(METRO_AUDIO.DOOR_OPEN, -6.0)
		Phase.OPEN_DOOR:
			if CONSIST.open_gate(_platform_gate, delta):
				phase = Phase.PLATFORM
				_restore_intro_combat()
				_release_controls()
		Phase.PLATFORM:
			if absf(local.x - (_dock_shift + ART.STAIR_X)) < 1.02 and local.y <= ART.STAIR_BASE + .47:
				_begin_stairs()
		Phase.CLIMB:
			_advance_stairs(local, delta)


func present() -> void:
	derailment.set_travel(travel)
	if phase <= Phase.DOCK:
		art.set_travel(travel, phase < Phase.DOCK or _phase_elapsed < DOCK_SECONDS, phase == Phase.RIDE)
	if phase == Phase.BOSS and is_instance_valid(_boss_bar) and is_instance_valid(boss):
		_boss_bar.set_health_ratio(boss.current_health / boss.maximum_health)


func update_speech_anchor() -> void:
	if phase == Phase.APPROACH and is_instance_valid(_boss_bubble) and is_instance_valid(boss):
		var camera: Camera3D = world.camera_3d
		_boss_speech_canvas.scale = _speech_canvas_scale(camera)
		_boss_bubble.set_speaker_hud_position(camera.unproject_position(_speech_world_anchor()) / _boss_speech_canvas.scale)


func _speech_world_anchor() -> Vector3:
	return world.get_gameplay_world_position(boss.global_position, 1.04)


func _speech_canvas_scale(camera: Camera3D) -> Vector2:
	# The bubble lays out in 640x360 UI units, even when the world is native size.
	return camera.get_viewport().get_visible_rect().size / DreamDialogueBubble.SCREEN_SIZE


func _advance_cars(local: Vector2, delta: float) -> void:
	for enemy in crews[active_car]:
		if is_instance_valid(enemy) and not enemy.dead:
			return
	if active_car == FRONT:
		return
	var gate := art.player_train.car_gates[active_car]
	if gate.fraction <= 0.0 and local.x < CONSIST.joint(active_car) - 1.65:
		return
	if CONSIST.open_gate(gate, delta):
		active_car += 1
		world.room_states[active_car] = &"ACTIVE"
		for enemy in crews[active_car]:
			if is_instance_valid(enemy) and not enemy.dead:
				_activate_crew(enemy, active_car)


func _prepare_crews() -> void:
	for index in CREWS.size():
		var crew: Array[EmployeeEnemy] = []
		crews.append(crew)
		if not world.spawn_content:
			continue
		for entry: Array in CREWS[index]:
			var mark: Vector2 = entry[1] + Vector2(CONSIST.center(index), 0.0)
			var enemy: EmployeeEnemy = world._spawn_regular_employee(index, _pixels(mark), &"employee", false, entry[0])
			if enemy == null:
				continue
			enemy.name = "TrainCar%dGuard%d" % [index + 1, crew.size() + 1]
			enemy.set_room_runtime_active(false)
			enemy.set_room_preview_visible(true)
			enemy._apply_live_facing(Vector2.LEFT)
			crew.append(enemy)
	world.room_states[0] = &"ACTIVE"
	if world.spawn_content:
		_weapon_pickup(FRONT, "assault_rifle", Vector2(CONSIST.center(FRONT) + 5.8, -.38))


func _activate_crew(enemy: EmployeeEnemy, index: int) -> void:
	enemy.set_room_runtime_active(true)
	enemy.collision_mask |= CONSIST.ACTOR_EDGE
	enemy.hostile = true
	enemy._remember_target_position(world.player.global_position, index)
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER


func _weapon_pickup(room: int, weapon: String, at: Vector2) -> void:
	world._spawn_room_drop(room, {"type":&"weapon", "weapon_id":weapon, "ground_position":_pixels(at)})


func _at_boss_glass() -> bool:
	var contact := _local(world.player.body_collision.global_position)
	if active_car < BOSS_TRIGGER_CAR or not BOSS_TRIGGER_AREA.has_point(contact):
		return false
	# Match the actual facing panes, including the restored central half-window.
	# Keep the solid infills, door jambs and end vestibules outside the trigger.
	var along := absf(contact.x-BOSS_TRIGGER_CENTER)
	var side_pane: Vector2 = CONSIST.WINDOW_SPANS[4]
	return (along > side_pane.x and along < side_pane.y) or (along > CONSIST.WINDOW_FRAME_HALF and along < CONSIST.MIDDLE_WINDOW_HALF-CONSIST.WINDOW_FRAME_HALF)


func _start_approach() -> void:
	if phase != Phase.RIDE: return
	phase = Phase.APPROACH
	_phase_elapsed = 0.0
	# Align the speaker's window with the player's actual trigger position,
	# rather than aligning carriage centers and leaving the speaker ahead.
	_rival_intro_offset = minf(0.0,_local(world.player.body_collision.global_position).x-BOSS_START_X)
	art.rival_train.set_relative_x(_rival_intro_offset-APPROACH_RUN)
	art.rival_train.set_cutaway(true)
	art.rival_train.root.show()
	_freeze_intro_combat()
	if not world.spawn_content:
		return
	boss = world._spawn_regular_employee(RIVAL_ROOM, _pixels(Vector2(BOSS_START_X + art.rival_train.root.position.x,BOSS_WINDOW_Z)),
		&"employee", false, BOSS_WEAPON)
	if boss == null:
		push_error("The rival train Boss could not spawn")
		return
	boss.name = "MetroBoss"
	boss.set_meta(&"content_kind", &"boss")
	var config: DemoConfig = world.config
	boss.configure(world.player, BOSS_HEALTH, 0.0, world._room_bounds_pixels(RIVAL_ROOM, 2.0),
		config.enemy_separation_strength, config.enemy_separation_radius, config)
	boss.configure_boss(true)
	boss.set_room_runtime_active(false)
	boss.set_room_preview_visible(true)
	boss.hurtbox_collision.set_deferred("disabled", true)
	boss._apply_live_facing(Vector2.UP)
	BOSS_ART.apply(boss)
	_boss_carriage = art.rival_train._car(FRONT)
	# The source floor is at +.12 in the carriage, cancelling DECK_OFFSET.
	# Anchor the walking/visual contact inside the aisle, clear of the seat
	# and window wall; the actor's sprite origin has a different local offset.
	_boss_seat = Vector3(BOSS_START_X-CONSIST.center(FRONT),-CONSIST.DECK_OFFSET,BOSS_WINDOW_Z-CONSIST.TRACK_GAP)
	_sync_boss_carriage()
	boss.defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)
	world.boss_enemy = boss
	world.boss_room_id = RIVAL_ROOM
	world.boss_defeated = false
	_hold_controls(true)


func _advance_approach(delta: float) -> void:
	travel += ROLL_SPEED * delta
	var ease := smoothstep(0.0, APPROACH_SECONDS, _phase_elapsed)
	art.rival_train.set_relative_x(lerpf(_rival_intro_offset-APPROACH_RUN,_rival_intro_offset,ease))
	var aligned := _phase_elapsed >= APPROACH_SECONDS
	if not is_instance_valid(boss):
		if aligned:
			_begin_boss()
		return
	_sync_boss_carriage()
	var camera: Camera3D = world.camera_3d
	var head := _speech_world_anchor()
	var canvas_scale := _speech_canvas_scale(camera)
	var at := camera.unproject_position(head) / canvas_scale
	var dialogue_camera: Dream3DDialogueCamera = world.dialogue_camera
	if _taunt_line < 0:
		if not _taunt_camera_started:
			if aligned:
				_focus_taunt_camera(dialogue_camera)
			return
		if dialogue_camera.state == Dream3DDialogueCamera.FocusState.ACTIVE:
			_show_taunt_bubble(canvas_scale, at)
		return
	_taunt_left -= delta
	if _taunt_left > 0.0:
		return
	if _taunt_line < TAUNTS.size():
		_next_taunt(at)
	elif aligned and dialogue_camera.state == Dream3DDialogueCamera.FocusState.INACTIVE:
		_begin_boss()


func _focus_taunt_camera(camera: Dream3DDialogueCamera) -> void:
	_taunt_camera_started = true
	_saved_taunt_zoom = camera.dialogue_zoom_factor
	_saved_taunt_enter = camera.dialogue_enter_duration
	camera.dialogue_zoom_factor = TAUNT_ZOOM
	camera.dialogue_enter_duration = TAUNT_ENTER_SECONDS
	world.begin_dialogue_focus(boss, Dream3DDialogueCamera.FocusMode.SPEAKER_FOCUS)


func _show_taunt_bubble(canvas_scale: Vector2, at: Vector2) -> void:
	_show_boss_bar()
	_boss_speech_canvas = Node2D.new()
	_boss_speech_canvas.name = "BossSpeech"
	_boss_speech_canvas.scale = canvas_scale
	_boss_bar.get_parent().add_child(_boss_speech_canvas)
	_boss_bubble = BOSS_BUBBLE.instantiate() as DreamDialogueBubble
	_boss_speech_canvas.add_child(_boss_bubble)
	_boss_bubble.background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_boss_bubble.margin_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_boss_bubble.scale = Vector2.ONE * 1.22
	_next_taunt(at)


func _clear_taunt_presentation() -> void:
	_restore_intro_combat()
	if is_instance_valid(_boss_speech_canvas):
		_boss_speech_canvas.queue_free()
		_boss_speech_canvas = null
		_boss_bubble = null
	if _taunt_camera_started:
		var camera: Dream3DDialogueCamera = world.dialogue_camera
		if is_instance_valid(camera):
			camera.clear_dialogue_focus()
			camera.dialogue_zoom_factor = _saved_taunt_zoom
			camera.dialogue_enter_duration = _saved_taunt_enter
		_taunt_camera_started = false


func _freeze_intro_combat() -> void:
	# The old intro ran after every guard was dead. It now happens in car three,
	# so live guards and existing shots must wait while player controls are held.
	var actors: Array[Node] = []
	actors.assign(world.enemy_root.get_children())
	for projectile: Node in world.get_tree().get_nodes_in_group(&"dream_projectiles"): actors.append(projectile)
	for actor: Node in actors:
		if actor == boss: continue
		_intro_frozen.append({"node":weakref(actor),"process":actor.is_processing(),"physics":actor.is_physics_processing()})
		actor.set_process(false)
		actor.set_physics_process(false)


func _restore_intro_combat() -> void:
	for entry: Dictionary in _intro_frozen:
		var actor: Node = entry.node.get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): continue
		actor.set_process(entry.process)
		actor.set_physics_process(entry.physics)
	_intro_frozen.clear()


func _next_taunt(at: Vector2) -> void:
	_taunt_line += 1
	if _taunt_line == TAUNTS.size():
		world.dialogue_camera.end_dialogue_focus(TAUNT_EXIT_SECONDS)
		_boss_bubble.dismiss(TAUNT_EXIT_SECONDS)
		_taunt_left = TAUNT_EXIT_SECONDS
		return
	_boss_bubble.call("present_hint", at, TAUNTS[_taunt_line])
	_boss_bubble.pivot_offset = Vector2(_boss_bubble.size.x * .5, _boss_bubble.size.y)
	_taunt_left = TAUNT_SECONDS[_taunt_line]


func _begin_boss() -> void:
	_clear_taunt_presentation()
	if not is_instance_valid(boss):
		art.rival_train.root.hide()
		_start_docking()
		return
	phase = Phase.BOSS
	_phase_elapsed = 0.0
	world._update_camera_and_actor_projection(0.0)
	art.rival_train.install_collision(world.collision_root, _pixels(Vector2.ZERO), world.CELL_PIXELS, true)
	boss.set_room_runtime_active(true)
	boss.collision_mask |= CONSIST.ACTOR_EDGE
	boss.set_physics_process(false)
	_release_controls()
	_aim_ray.collision_mask = world.WORLD_WALL_LAYER
	_aim_ray.collide_with_bodies = true
	_show_boss_bar()
	_start_dodge_intro()
	var target: Vector2 = world.player.body_collision.global_position
	_aim_boss(target)
	_fire_boss_round(target)


func _show_boss_bar() -> void:
	if is_instance_valid(_boss_bar):
		return
	var layer := CanvasLayer.new()
	layer.name = "MetroBossHealth"
	layer.layer = 25
	layer.set_meta(&"world_post_effect", true)
	art.root.add_child(layer)
	_boss_bar = BOSS_HEALTH_UI.new()
	layer.add_child(_boss_bar)


func _advance_boss(delta: float) -> void:
	art.rival_train.set_relative_x(minf(0.0,art.rival_train.root.position.x+RIVAL_OVERTAKE_SPEED*delta))
	if not is_instance_valid(boss): return
	# The actor stays at one window in its own carriage; only the train advances.
	_sync_boss_carriage()
	boss.velocity = Vector2.ZERO
	if boss.dead:
		return
	if boss.state in [EmployeeEnemy.State.KNOCKED_DOWN,EmployeeEnemy.State.GETTING_UP]: return
	var target: Vector2 = world.player.body_collision.global_position
	_aim_boss(target)
	if boss.attack_cooldown_left <= 0.0 and boss.reload_left <= 0.0 and _shot_path_clear(target):
		_fire_boss_round(target)


func _sync_boss_carriage() -> void:
	var contact := world.to_local(_boss_carriage.to_global(_boss_seat))
	var body_offset: Vector2 = boss.body_collision.global_position-boss.global_position
	boss.global_position = Vector2(contact.x,contact.z)*world.CELL_PIXELS-body_offset


func _ready_for_station(local: Vector2) -> bool:
	if local.x < CONSIST.joint(FRONT-1)+.15:
		return false
	for crew: Array in crews:
		for enemy in crew:
			if is_instance_valid(enemy) and not enemy.dead:
				return false
	return true


func _aim_boss(target: Vector2) -> void:
	boss._remember_target_position(target, world.get_current_room_id())
	boss.state = EmployeeEnemy.State.ATTACK_PLAYER
	boss._update_weapon_aim()


func _fire_boss_round(target: Vector2) -> void:
	boss.can_see_target = true
	boss.ranged_attack_target_snapshot = target
	boss.ranged_attack_fire_locked = true
	boss._fire_held_weapon()
	boss.ranged_attack_fire_locked = false


func _shot_path_clear(target: Vector2) -> bool:
	_aim_ray.from = boss.get_projectile_origin()
	_aim_ray.to = target
	return boss.get_world_2d().direct_space_state.intersect_ray(_aim_ray).is_empty()


func _start_dodge_intro() -> void:
	var clock: Node = world._get_dream_time_controller()
	if clock == null:
		return
	_slow_owner = Node.new()
	_slow_owner.name = "MetroDodgeSlowMotion"
	art.root.add_child(_slow_owner)
	if not clock.request_fullscreen_cue_time(_slow_owner):
		_slow_owner.queue_free()
		_slow_owner = null
		return
	world.run_interface.play_player_cue(DODGE_CUE, .72)
	world.player.projectile_hit.connect(_finish_dodge_intro, CONNECT_DEFERRED)
	world.player.dash_state_changed.connect(_on_intro_roll_state)


func _on_intro_roll_state(_left: float, _total: float, active: bool, _charges: int, _capacity: int) -> void:
	var player: CharacterBody2D = world.player
	var roll: Node = player.phase_dash
	if not is_instance_valid(roll) or not roll.dive_roll:
		return
	if active and not _intro_roll:
		_intro_roll = true
		# The world and its bullets stay at 0.05x while the committed roll
		# completes in its usual real duration.
		player.active_dash_duration *= Engine.time_scale
		player.dash_invulnerability_left = player.active_dash_duration
	elif not active and _intro_roll and roll.landed:
		_finish_dodge_intro()


func _finish_dodge_intro() -> void:
	if not is_instance_valid(_slow_owner):
		return
	if is_instance_valid(world.run_interface):
		var cue: CanvasLayer = world.run_interface.player_cue
		if is_instance_valid(cue) and cue.current_message == DODGE_CUE:
			world.run_interface.cancel_player_cue()
	var clock: Node = world._get_dream_time_controller()
	if is_instance_valid(clock):
		clock.clear_reaction_time()
		clock.release_fullscreen_cue_time(_slow_owner)
	_slow_owner.queue_free()
	_slow_owner = null
	if is_instance_valid(world.player):
		world.player.projectile_hit.disconnect(_finish_dodge_intro)
		world.player.dash_state_changed.disconnect(_on_intro_roll_state)
	if phase == Phase.FALL:
		_hold_controls()


func _on_boss_defeated(_at: Vector2, _legacy: int) -> void:
	_boss_defeated_pending = true
	_boss_defeated_usec = Time.get_ticks_usec()
	_finish_dodge_intro()
	if is_instance_valid(_boss_bar):
		_boss_bar.dismiss()
	boss.death_ground_velocity = Vector2.ZERO
	world.boss_defeated = true
	EmployeeEnemy.SFX.finish_combat_music()
	_begin_boss_fall()


func _begin_boss_fall() -> void:
	phase = Phase.FALL
	_phase_elapsed = 0.0
	_freeze_intro_combat()
	_hold_controls(true)


func _start_split() -> void:
	phase = Phase.SPLIT
	_phase_elapsed = 0.0
	boss.set_physics_process(false)
	boss.set_process(false)
	# Put the switch at the rival's actual leading bogie, including its current
	# relative offset. Turning starts now even if it was defeated in car three.
	_turn_x = CONSIST.center(FRONT)+art.rival_train.root.position.x+CONSIST.BOGIE_OFFSET
	_split_reference = 0.0
	art.build_turnout(_turn_x)
	art.rival_train.release_collision()
	for child in world.world_effects_root.get_children():
		if int(child.get_meta(&"dream_room_id", -1)) == RIVAL_ROOM:
			child.hide()
			child.queue_free()
	for child in world.world_weapon_root.get_children():
		if int(child.get_meta(&"dream_room_id", -1)) == RIVAL_ROOM:
			child.hide()
			child.queue_free()


func _advance_split() -> void:
	# The switch belongs to the track. It passes the player's train as the
	# other consist follows the same curve, beginning with its leading car.
	var reference := _phase_elapsed*SWITCH_SCROLL_SPEED
	_scroll_past_turnout(reference - _split_reference)
	art.rival_train.follow_turnout(_turn_x, reference + _phase_elapsed*RIVAL_PULL_AHEAD_SPEED, reference)
	_sync_boss_carriage()
	if _phase_elapsed >= SPLIT_SECONDS:
		art.rival_train.root.hide()
		boss.queue_free()
		boss = null
		if _ready_for_station(_local(world.player.global_position)):
			phase = Phase.COAST
		else:
			_restore_intro_combat()
			phase = Phase.CLEAR_CARS
			_release_controls()
		_phase_elapsed = 0.0


func _scroll_past_turnout(distance: float) -> void:
	travel += distance
	_split_reference += distance
	art.scroll_turnout(_turn_x - _split_reference)


func _start_docking() -> void:
	if phase != Phase.COAST:
		_hold_controls()
	phase = Phase.DOCK
	_phase_elapsed = 0.0
	var at := _local(world.player.global_position)
	_platform_gate = art.player_train.platform_doors[0]
	for gate in art.player_train.platform_doors:
		if absf(gate.at.x - at.x) < absf(_platform_gate.at.x - at.x):
			_platform_gate = gate
	_exit_x = _platform_gate.at.x
	_exit_car = _platform_gate.car
	_dock_shift = _exit_x - ART.EXIT_X
	_install_layout(false)
	art.build_station(_dock_shift)
	art.station.position.x += DOCK_RUN
	_play_sound(METRO_AUDIO.BRAKE, -9.0)
	if is_instance_valid(_roll):
		var fade := world.create_tween()
		fade.tween_property(_roll, "volume_db", -36.0, DOCK_SECONDS)
		fade.tween_callback(_roll.stop)


func _hold_controls(keep_weapon_pose := false) -> void:
	var player: CharacterBody2D = world.player
	if not _controls_held:
		_stage_controls = Vector3i(int(player.movement_enabled), int(player.attacking_enabled), int(player.dash_enabled))
		_controls_held = true
	player.movement_enabled = false
	player.set_attacking_enabled(false, keep_weapon_pose)
	player.set_dash_enabled(false)
	player.velocity = Vector2.ZERO


func _release_controls() -> void:
	if not _controls_held:
		return
	world.player.movement_enabled = bool(_stage_controls.x)
	world.player.set_attacking_enabled(bool(_stage_controls.y))
	world.player.set_dash_enabled(bool(_stage_controls.z))
	_controls_held = false


func _begin_stairs() -> void:
	phase = Phase.CLIMB
	_hold_controls()
	_saved_aim = world.player.get_meta(&"aim_direction_override", Vector2.ZERO)
	world.player.set_meta(&"aim_direction_override", Vector2.UP)
	world.player.set_scripted_locomotion(Vector2.UP, 83.0)


func _advance_stairs(local: Vector2, delta: float) -> void:
	var foot := _local(world.player.body_collision.global_position)
	var height := ART.stair_height(foot.y)
	var bridge: Node3D = world.player_depth_bridge
	bridge.ground_surface_height = move_toward(bridge.ground_surface_height, height, delta * 2.0)
	if local.y <= ART.STAIR_TOP + .14:
		phase = Phase.COMPLETE
		world.player.clear_scripted_locomotion()
		world.player.velocity = Vector2.ZERO
		_restore_stair_aim()
		world.finish_train_chapter()
		return
	var to := Vector2(_dock_shift + ART.STAIR_X, ART.STAIR_TOP - .32) - local
	world.player.set_scripted_locomotion(to, 83.0)


func _restore_stair_aim() -> void:
	if _saved_aim == Vector2.ZERO:
		world.player.remove_meta(&"aim_direction_override")
	else:
		world.player.set_meta(&"aim_direction_override", _saved_aim)


func dash_landing_allowed(position: Vector2) -> bool:
	var cell: Vector2i = world._cell_for_gameplay_position(position)
	var room := int(world.room_cells.get(cell, -1))
	if room < 0 or room == RIVAL_ROOM or phase in [Phase.FALL, Phase.SPLIT, Phase.COAST, Phase.DOCK, Phase.CLIMB, Phase.COMPLETE]:
		return false
	if room == PLATFORM_ROOM:
		if phase != Phase.PLATFORM:
			return false
		var start := _local(world.player.global_position)
		var end := _local(position)
		if start.y >= -ART.CABIN_EDGE:
			var crossing := start.lerp(end, inverse_lerp(start.y, end.y, -ART.CABIN_EDGE))
			return absf(crossing.x - _exit_x) <= .49
		return true
	return room <= active_car


func rooms_open(a: int, b: int) -> bool:
	if is_instance_valid(derailment) and (derailment.retired.has(a) or derailment.retired.has(b)): return false
	if a == b:
		return true
	var first := mini(a, b)
	var last := maxi(a, b)
	if last == PLATFORM_ROOM:
		return first == _exit_car and phase >= Phase.PLATFORM
	if first < 0 or last > FRONT or last - first != 1:
		return false
	return art.player_train.car_gates[first].fraction >= 1.0


func _pixels(at: Vector2) -> Vector2:
	return (at + Vector2(ART.OFFSET)) * world.CELL_PIXELS


func _local(at: Vector2) -> Vector2:
	return at / world.CELL_PIXELS - Vector2(ART.OFFSET)


func _play_sound(stream: AudioStreamWAV, db: float, loop := false) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.bus = &"Environment"
	voice.volume_db = db
	if loop:
		var copy := stream.duplicate() as AudioStreamWAV
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		voice.stream = copy
	else:
		voice.stream = stream
		voice.finished.connect(voice.queue_free)
	art.root.add_child(voice)
	voice.play()
	return voice


func _install_layout(initial: bool) -> void:
	var source := {"type":"METRO_TRAIN_06", "checks":{"ok":true}, "rooms":[], "anchors":{},
		"doors":[], "furniture":[], "enemies":[], "bounds":{}}
	var cabin_left := 0
	for index in CONSIST.CAR_COUNT:
		var key := "entry" if index == 0 else "car%d" % index
		var cabin_right := CONSIST.cell_limit(index)
		var cabin := Rect2i(cabin_left, -1, cabin_right - cabin_left, 3)
		source.rooms.append(_room_source(key, "车厢 %d" % (index + 1), cabin, []))
		source.anchors[key] = _cell_text(cabin.get_center() + ART.OFFSET)
		if index > 0:
			var prior := "entry" if index == 1 else "car%d" % (index - 1)
			source.doors.append({"a":prior, "b":key, "vertical":true, "line":cabin_left + ART.OFFSET.x,
				"start":ART.OFFSET.y, "width":1, "glass":false, "open":true})
		cabin_left = cabin_right
	var bridge := Rect2i(roundi(_exit_x), -2, 1, 1)
	var platform := ART.PLATFORM
	platform.position.x += roundi(_dock_shift)
	var stairs := ART.STAIRS
	stairs.position.x += roundi(_dock_shift)
	source.rooms.append(_room_source("terminal", "终点站台", platform, [bridge, stairs]))
	source.anchors.terminal = _cell_text(platform.get_center() + ART.OFFSET)
	var boarding_car := "entry" if _exit_car == 0 else "car%d" % _exit_car
	source.doors.append({"a":boarding_car, "b":"terminal", "vertical":false, "line":-1 + ART.OFFSET.y,
		"start":bridge.position.x + ART.OFFSET.x, "width":1, "glass":false, "open":true})
	var rival := Rect2i(0, 3, cabin_left, 3)
	source.rooms.append(_room_source("rival", "并行列车", rival, []))
	source.anchors.rival = _cell_text(rival.get_center() + ART.OFFSET)
	var bounds := Rect2i(0, -1, cabin_left, 3).merge(platform).merge(stairs).merge(rival)
	bounds.position += ART.OFFSET
	source.bounds = _rect_source(bounds)
	var plan := ADAPTER.compile(source)
	world.rooms.assign(plan.rooms)
	world.connections.assign(plan.connections)
	world.corridors.clear()
	world.corridor_states.clear()
	world.building_rect = plan.building_rect
	world.floor_shape = plan.floor_shape
	world.floor_cells = plan.floor_cells
	world.presentation_floor_cells = plan.floor_cells.duplicate()
	world.room_cells = plan.room_cells
	world.corridor_cells = plan.corridor_cells
	world.edge_states = plan.edge_states
	world.wall_edges = plan.wall_edges
	world.internal_wall_edges = plan.internal_wall_edges
	world.door_edges = plan.door_edges
	world.door_opening_edges = plan.door_opening_edges
	world.glass_wall_edges = plan.glass_wall_edges
	world.window_wall_edges.clear()
	world._open_connected_rooms_cache.clear()
	world._open_boundary_edges_cache.clear()
	world.employee_path_cache.clear()
	if initial:
		world.room_states.clear()
		world.room_encounters.clear()
		world.spawn_room_id = 0
		world.spawn_cell = ART.OFFSET + Vector2i(roundi(ENTRY.x), 0)
		world.boss_room_id = -1
		world.enemy_count = 0
		for room: Dictionary in world.rooms:
			world.room_states[int(room.id)] = &"UNSEEN"
	elif is_instance_valid(derailment):
		derailment.restore_retired_floor_mask()


static func _room_source(key: String, label: String, rectangle: Rect2i, extras: Array) -> Dictionary:
	var cells: Array[String] = []
	var bounds := rectangle
	for region: Rect2i in [rectangle] + extras:
		bounds = bounds.merge(region)
		for z in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				cells.append(_cell_text(Vector2i(x, z) + ART.OFFSET))
	bounds.position += ART.OFFSET
	return {"id":key, "label":label, "kind":"corridor", "cells":cells, "bounds":_rect_source(bounds)}


static func _cell_text(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func _rect_source(rect: Rect2i) -> Dictionary:
	return {"x":rect.position.x, "y":rect.position.y, "w":rect.size.x, "h":rect.size.y}
