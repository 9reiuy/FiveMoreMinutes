extends Node
## Runtime adapter for the 3D Dream HUD, card, save state and combat flow.
const SAVE = preload("res://scripts/app/game_save_store.gd")
const CONFIG = preload("res://resources/demo_config.tres")
const SFX = preload("res://scripts/audio/sfx_manager.gd")
const PERF=preload("res://scripts/app/performance_markers.gd")
var world: Node3D
var player: Node
var hud: Control
var card: Control
var crosshair: Control
var profile: Dictionary = {}
var kills := 0
var kill_streak_count := 0
var last_kill_timestamp := 0.0
const KILL_STREAK_WINDOW := 3.0
var seconds := 0.0
var host: Node
var death_label: Label
var death_layer: CanvasLayer
var death_effect: Node
var pause_manager: Node
## Kept as a null compatibility endpoint for older test harnesses.  The
## official Dream runtime no longer instantiates the slot-machine panel.
var upgrade_panel: Control = null
var skill_levels: Dictionary = {}
var auto_open_upgrades := false
var damage_flash: ColorRect
var damage_flash_left := 0.0
var rapid_eye_left := 0.0
var death_transition_finished := false
var death_sequence_generation := 0
var ui_layer: CanvasLayer

func configure(owner_world: Node3D, ui: CanvasLayer, cursor: Control) -> void:
	preload("res://scripts/app/game_input_actions.gd").configure()
	world = owner_world
	player = world.player
	pause_manager = get_node_or_null("/root/PauseManager")
	crosshair = cursor
	ui_layer = ui
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ancestor := world.get_parent()
	while ancestor != null:
		if ancestor.get("persistent_day_state") is Dictionary:
			host = ancestor
			profile = ancestor.get("persistent_day_state")
			break
		ancestor = ancestor.get_parent()
	if profile.is_empty() and world.persist_profile:
		profile = SAVE.load_game()
	if profile.is_empty():
		# Same save keys; Main merges missing story/day defaults on Continue.
		profile = {"save_version": CONFIG.game_version_text, "balance": CONFIG.initial_balance,
			"ram": 0, "melatonin_inventory": 0, "weekday_index": 0, "permanent_upgrades": {},
			"current_dream_layer": 1, "dream_layer_reached": 1, "defeated_boss_ids": []}
	# character_speed_cells intentionally absent: old saves may still carry it,
	# but nothing reads or writes it any more (movement is a fixed 200).
	for pair in [["character_hp_cells",4]]:
		if not profile.has(pair[0]):
			profile[pair[0]] = pair[1]
	if not profile.has("current_dream_layer"):
		profile.current_dream_layer = 1
	if not profile.has("dream_layer_reached"):
		profile.dream_layer_reached = 1
	if not profile.get("defeated_boss_ids", []) is Array:
		profile.defeated_boss_ids = []
	player.configure_weapon(player.selected_weapon_id, world.config, world.permanent_upgrades)
	player.configure_profile_stats(int(profile.character_hp_cells), false)
	player.configure_feedback_audio(CONFIG)
	hud = preload("res://scenes/ui/dream_hud.tscn").instantiate()
	ui.add_child(hud)
	player.health_changed.connect(hud.set_health)
	player.dash_state_changed.connect(hud.set_dash_state)
	player.skill_state_changed.connect(hud.set_skill_state)
	player.active_weapon_changed.connect(_on_player_active_weapon_changed)
	if player.has_signal("weapon_inventory_changed"):
		player.weapon_inventory_changed.connect(_on_player_weapon_inventory_changed)
	hud.set_health(player.current_health, player.maximum_health)
	hud.set_dash_state(
		float(player.get("dash_cooldown_left")),
		float(player.get("dash_cooldown")),
		bool(player.get("dashing")),
		int(player.get("dash_charges")),
		int(player.get("max_dash_charges"))
	)
	hud.set_weapon_state(
		str(player.get("ranged_weapon_id")),
		str(player.get("melee_weapon_id")),
		str(player.get("selected_weapon_id")),
		StringName(str(player.get("active_weapon_category")))
	)
	# The 3D run uses NightLighting's single toggleable SpotLight3D as its
	# flashlight.  The HUD mirrors availability only; it does not add a second
	# flashlight or toggle state.
	hud.set_flashlight_available(not bool(player.get("dead")))
	card = preload("res://scenes/ui/character_card.tscn").instantiate()
	ui.add_child(card)
	card.close_requested.connect(_close_card)
	card.reopen_requested.connect(_open_card)
	card.profile_change_requested.connect(_change_profile)
	player.died.connect(_on_death)
	player.effective_damage_taken.connect(_on_damage)
	player.healed.connect(_on_healed)
	damage_flash = ColorRect.new()
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.color = Color(0.72,0.08,0.11,0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(damage_flash)
	ui.move_child(damage_flash,0)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func configure_dungeon_minimap(
	rooms: Array,
	connections: Array,
	corridors: Array,
	cell_pixels: float = 32.0
) -> void:
	if hud != null and hud.has_method("set_dungeon_minimap_data"):
		hud.call("set_dungeon_minimap_data", rooms, connections, corridors, cell_pixels)


func set_dungeon_minimap_room_state(room_id: int, state: StringName) -> void:
	if hud != null and hud.has_method("set_dungeon_minimap_room_state"):
		hud.call("set_dungeon_minimap_room_state", room_id, state)


func set_dungeon_minimap_corridor_state(corridor_id: int, state: StringName) -> void:
	if hud != null and hud.has_method("set_dungeon_minimap_corridor_state"):
		hud.call("set_dungeon_minimap_corridor_state", corridor_id, state)


func set_dungeon_minimap_player(position: Vector2, room_id: int) -> void:
	if hud != null and hud.has_method("set_dungeon_minimap_player"):
		hud.call("set_dungeon_minimap_player", position, room_id)

func _process(delta: float) -> void:
	if not is_instance_valid(world) or get_tree().paused or player.dead:
		return
	seconds += delta
	hud.set_clock("%02d:%02d" % [int(seconds)/60, int(seconds)%60])
	damage_flash_left = maxf(0,damage_flash_left-delta)
	damage_flash.color.a = CONFIG.player_hurt_screen_flash_alpha * damage_flash_left / maxf(CONFIG.player_hurt_screen_flash_seconds,0.001)
	if rapid_eye_left > 0.0:
		rapid_eye_left = maxf(0,rapid_eye_left-delta)
		if rapid_eye_left <= 0:
			_set_enemy_slow(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_menu") and not player.dead:
		if card.visible and not card.is_closing():
			_close_card()
		else:
			_open_card()
		get_viewport().set_input_as_handled()
	if player.dead and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_R or event.physical_keycode == KEY_R):
		_restart_after_death()
		get_viewport().set_input_as_handled()

func _open_card() -> void:
	world.reset_hit_stop()
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	card.open(player, profile, CONFIG)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crosshair.hide()
	if CONFIG.tab_menu_pauses_tree:
		pause_manager.request_pause(&"SKILLS_MENU")

func _close_card() -> void:
	card.close()
	pause_manager.release_pause(&"SKILLS_MENU")
	player.set_attacking_enabled(not player.dead)
	player.set_dash_enabled(not player.dead)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	crosshair.show()
func _change_profile(next: Dictionary) -> void:
	if next.has("character_hp_cells"):
		profile["character_hp_cells"] = next["character_hp_cells"]
	player.configure_profile_stats(int(profile.character_hp_cells), true)
	card.refresh_data(player, profile, CONFIG)
	_save()

func record_kill() -> void:
	kills += 1
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_kill_timestamp <= KILL_STREAK_WINDOW:
		kill_streak_count += 1
	else:
		kill_streak_count = 1
	last_kill_timestamp = now

	if kill_streak_count >= 2:
		var reaction: StringName = &"golf_clap"
		if kill_streak_count == 3:
			reaction = &"canned_laughter"
		elif kill_streak_count >= 4:
			reaction = &"audience_applause" if (kill_streak_count % 2 == 0) else &"canned_laughter"
		SFX.trigger_multi_kill_reaction(reaction)

func _save() -> void:
	if not world.persist_profile:
		return
	if is_instance_valid(host):
		host.call("_on_dream_profile_changed", profile)
	else:
		SAVE.save_game(profile)


func complete_boss_layer(layer_id: int) -> void:
	var safe_layer := maxi(1, layer_id)
	var defeated: Array = profile.get("defeated_boss_ids", [])
	var boss_id := "employee_boss_layer_%d" % safe_layer
	if not defeated.has(boss_id):
		defeated.append(boss_id)
	profile.defeated_boss_ids = defeated
	profile.dream_layer_reached = maxi(int(profile.get("dream_layer_reached", 1)), safe_layer + 1)
	profile.current_dream_layer = safe_layer + 1
	_save()

func _on_death() -> void:
	var diagnostic_started:=PERF.begin(self)
	_clear_death_presentation()
	death_transition_finished = false
	PERF.end(self,"death_actor_cleanup",diagnostic_started)
	diagnostic_started=PERF.begin(self)
	SFX.finish_player_death_music()
	PERF.end(self,"death_audio_ctrl",diagnostic_started)
	diagnostic_started=PERF.begin(self)
	world.reset_hit_stop()
	var time_controller := get_node_or_null("/root/DreamTimeController")
	if time_controller != null:
		time_controller.set("slow_time_enabled", false)
		time_controller.set("tactical_planning_active", false)
		time_controller.set("dive_bullet_time_active", false)
		time_controller.set("hitstop_active", false)
	Engine.time_scale = 1.0
	if is_instance_valid(card) and card.visible:
		_close_card()
	if is_instance_valid(crosshair):
		crosshair.hide()
	PERF.end(self,"death_actor_cleanup",diagnostic_started)
	diagnostic_started=PERF.begin(self)
	_save()
	PERF.end(self,"death_save_io",diagnostic_started)
	diagnostic_started=PERF.begin(self)
	if hud != null:
		hud.set_flashlight_available(false)
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	damage_flash_left = 0.0
	if is_instance_valid(damage_flash):
		damage_flash.color.a = 0.0
	death_sequence_generation += 1
	var current_gen := death_sequence_generation
	PERF.end(self,"death_actor_cleanup",diagnostic_started)
	if player.last_damage_source == &"exterior_fall" and player.get_meta(&"exterior_fall_wilhelm", false):
		var start_msec: int = int(player.get_meta(&"wilhelm_scream_start_msec", 0))
		var elapsed := float(Time.get_ticks_msec() - start_msec) / 1000.0 if start_msec > 0 else 0.5
		var remaining := maxf(0.0, 1.62 - elapsed)
		if remaining > 0.05:
			await get_tree().create_timer(remaining, true, false, true).timeout
			if current_gen != death_sequence_generation or not is_instance_valid(player) or not player.dead or death_transition_finished:
				return
	diagnostic_started=PERF.begin(self)
	var crt := preload("res://scenes/ui/death_crt_effect.tscn").instantiate()
	death_effect = crt
	world.add_child(crt)
	crt.finished.connect(_finish_death_transition, CONNECT_ONE_SHOT)
	crt.play(CONFIG.death_crt_effect_seconds)
	PERF.end(self,"death_crt_init",diagnostic_started)

func _finish_death_transition() -> void:
	death_transition_finished = true
	if is_instance_valid(death_layer):
		death_layer.queue_free()
	death_layer = CanvasLayer.new()
	death_layer.name = "DeathTakeoverPromptLayer"
	death_layer.layer = 31
	world.add_child(death_layer)
	var black_bg := ColorRect.new()
	black_bg.name = "BlackScreen"
	black_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_bg.color = Color.BLACK
	black_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_layer.add_child(black_bg)
	death_label = Label.new()
	death_label.name = "DeathPromptLabel"
	death_label.text = "按 R 重新接管"
	death_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_override("font", PixelFont.get_font())
	death_label.add_theme_font_size_override("font_size", 16)
	death_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96, 1.0))
	death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_layer.add_child(death_label)

func _clear_death_presentation() -> void:
	death_sequence_generation += 1
	if is_instance_valid(death_effect):
		death_effect.queue_free()
	death_effect = null
	if is_instance_valid(death_layer):
		death_layer.queue_free()
	death_layer = null
	death_label = null

func _restart_after_death() -> void:
	_clear_death_presentation()
	death_transition_finished = false
	damage_flash_left = 0.0
	if is_instance_valid(damage_flash):
		damage_flash.color.a = 0.0
	if rapid_eye_left > 0.0:
		rapid_eye_left = 0.0
		_set_enemy_slow(1.0)
	SFX.play_battle_music(false, world.get_instance_id() if is_instance_valid(world) else 0)
	if is_instance_valid(world) and world.has_method("restart_current_floor_after_death"):
		world.call("restart_current_floor_after_death")
		if is_instance_valid(hud) and is_instance_valid(player):
			hud.set_health(player.current_health, player.maximum_health)
			hud.set_dash_state(
				float(player.get("dash_cooldown_left")),
				float(player.get("dash_cooldown")),
				bool(player.get("dashing")),
				int(player.get("dash_charges")),
				int(player.get("max_dash_charges"))
			)
			hud.set_weapon_state(
				str(player.get("ranged_weapon_id")),
				str(player.get("melee_weapon_id")),
				str(player.get("selected_weapon_id")),
				StringName(str(player.get("active_weapon_category")))
			)
			hud.set_flashlight_available(true)
		if is_instance_valid(crosshair):
			crosshair.show()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		return
	get_tree().reload_current_scene()

func _on_damage(_amount: float) -> void:
	damage_flash_left = 0.0 if player.has_meta(&"stylized_player_hurt") else CONFIG.player_hurt_screen_flash_seconds
	if int(skill_levels.get("rapid_eye",0)) > 0:
		rapid_eye_left = CONFIG.rapid_eye_duration_seconds
		_set_enemy_slow(CONFIG.rapid_eye_slow_multiplier)


func _on_player_active_weapon_changed(weapon_id: String) -> void:
	if hud == null or player == null:
		return
	hud.set_weapon_state(
		str(player.get("ranged_weapon_id")),
		str(player.get("melee_weapon_id")),
		weapon_id,
		StringName(str(player.get("active_weapon_category")))
	)


func _on_player_weapon_inventory_changed() -> void:
	# Auto pickup can fill a non-active slot. Refresh the slot indicators without
	# treating the unchanged selected weapon as a selection event.
	if player == null or hud == null:
		return
	hud.set_weapon_state(
		str(player.get("ranged_weapon_id")),
		str(player.get("melee_weapon_id")),
		str(player.get("selected_weapon_id")),
		StringName(str(player.get("active_weapon_category")))
	)

func _set_enemy_slow(multiplier: float) -> void:
	for enemy in world.enemy_root.get_children():
		if enemy.has_method("set_movement_speed_multiplier"):
			enemy.set_movement_speed_multiplier(multiplier)

func _on_healed(amount: float) -> void:
	if amount <= 0:
		return
	var number := preload("res://scenes/ui/damage_number.tscn").instantiate()
	world.world_effects_root.add_child(number)
	number.activate_heal(player.global_position,roundi(amount))
	number.finished.connect(number.queue_free, CONNECT_ONE_SHOT)
	world._spawn_depth_bridge(number,[^"."],Vector2(64,64),BaseMaterial3D.BILLBOARD_ENABLED,0.05,0.0)

func _exit_tree() -> void:
	if is_instance_valid(pause_manager):
		pause_manager.release_pause(&"SKILLS_MENU")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
