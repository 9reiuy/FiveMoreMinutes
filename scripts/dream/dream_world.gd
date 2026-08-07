extends Node2D

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal dream_finished(summary: Dictionary)

const ENEMY_SCENE := preload("res://scenes/entities/basic_enemy.tscn")
const XP_GEM_SCENE := preload("res://scenes/entities/xp_gem.tscn")
const CORRECTION_SCENE := preload("res://scenes/entities/correction_tape_enemy.tscn")
const STAPLER_SCENE := preload("res://scenes/entities/stapler_enemy.tscn")
const LARGE_CORRECTION_SCENE := preload("res://scenes/entities/large_correction_tape_enemy.tscn")
const ALARM_CLOCK_SCENE := preload("res://scenes/entities/alarm_clock_enemy.tscn")
const MAILBOX_SCENE := preload("res://scenes/entities/mailbox_enemy.tscn")
const STAPLE_SCENE := preload("res://scenes/entities/staple_projectile.tscn")
const MUZZLE_EFFECT_SCENE := preload("res://scenes/entities/weapon_muzzle_effect.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/ui/damage_number.tscn")
const DEATH_CRT_SCENE := preload("res://scenes/ui/death_crt_effect.tscn")
const WAKE_POINT := Vector2(88, 273)
const ARENA_BOUNDS := Rect2(30, 54, 580, 258)

enum RunPhase { RUNNING, ALARM, ENDING }

@export var config: DemoConfig

@onready var player: CharacterBody2D = $Player
@onready var clock: Node = $DreamClock
@onready var spawner: Node = $EnemySpawner
@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var pickup_container: Node2D = $PickupContainer
@onready var hud: Control = $UILayer/DreamHUD
@onready var wake_overlay: Control = $UILayer/WakeOverlay
@onready var upgrade_panel: Control = $UILayer/UpgradePanel
@onready var crosshair: Control = $UILayer/Crosshair
@onready var skills_menu: Control = $UILayer/SkillsMenu
@onready var stress_vision_overlay: ColorRect = $StressVisionLayer/StressVisionOverlay

var phase := RunPhase.RUNNING
var kills := 0
var level := 1
var experience := 0
var pending_upgrades := 0
var wake_hold_progress := 0.0
var holding_to_wake := false
var alarm_real_elapsed_seconds := 0.0
var selected_weapon_id := "basic"
var total_experience_earned := 0
var run_elapsed_seconds := 0.0
var elite_spawned := false
var permanent_upgrades: Dictionary = {}
var skill_levels: Dictionary = {}
var experience_fractional_carry := 0.0
var rapid_eye_left := 0.0
var is_sunday := false
var sleepwalk_mode := false
var is_endless_mode := false
var random := RandomNumberGenerator.new()
var damage_flash_left := 0.0
var hit_stop_in_progress := false
var last_hit_stop_msec := -1000000
var hit_stop_token := 0
var is_hungry_run := false
var run_stress_value := 0
var stress_spawn_multiplier := 1.0
var stress_enemy_speed_multiplier := 1.0
var rapid_eye_speed_multiplier := 1.0
var dream_game_speed_multiplier := 1.0
var damage_number_pool: Array[Node2D] = []

@onready var damage_flash: ColorRect = $UILayer/DamageFlash


func _ready() -> void:
	dream_game_speed_multiplier = config.fast_sleep_game_speed_multiplier if SettingsManager.get_fast_sleep_enabled() else 1.0
	Engine.time_scale = dream_game_speed_multiplier
	SFX.play_battle_music()
	random.randomize()
	player.arena_bounds = ARENA_BOUNDS
	player.configure_weapon(selected_weapon_id, config, permanent_upgrades)
	player.configure_run_modifiers(is_hungry_run, config)
	player.configure_aim(sleepwalk_mode, config)
	player.configure_feedback_audio(config)
	player.start_invulnerability(config.player_spawn_invulnerability_duration, &"dream_spawn")
	crosshair.config = config
	crosshair.configure(player)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	crosshair.visible = not sleepwalk_mode
	clock.alarm_enabled = not is_endless_mode
	spawner.player = player
	spawner.endless_mode = is_endless_mode
	spawner.arena_bounds = ARENA_BOUNDS.grow(-14.0)
	_configure_stress_difficulty()
	wake_overlay.config = config
	player.health_changed.connect(_on_player_health_changed)
	player.dash_state_changed.connect(_on_dash_state_changed)
	player.skill_state_changed.connect(_on_skill_state_changed)
	player.effective_damage_taken.connect(_on_effective_damage_taken)
	player.died.connect(_on_player_died)
	clock.time_changed.connect(_on_time_changed)
	clock.alarm_started.connect(_on_alarm_started)
	spawner.spawn_requested.connect(_on_spawn_requested)
	upgrade_panel.upgrade_chosen.connect(_on_upgrade_chosen)
	upgrade_panel.refresh_requested.connect(_on_upgrade_refresh_requested)
	skills_menu.close_requested.connect(_close_skills_menu)
	PauseManager.pause_state_changed.connect(_on_pause_state_changed)
	hud.set_health(player.current_health, player.maximum_health)
	hud.set_progression(level, experience, get_experience_requirement(level), kills)
	hud.set_skill_state(false, false)
	hud.set_hungry_run(is_hungry_run)
	queue_redraw()
	for _index in range(32):
		var number := DAMAGE_NUMBER_SCENE.instantiate()
		number.finished.connect(_recycle_damage_number.bind(number))
		$DamageNumberPool.add_child(number)
		damage_number_pool.append(number)


func _exit_tree() -> void:
	SFX.clear_music_duck(&"UPGRADE_UI", config.upgrade_music_duck_fade_duration)
	SFX.stop_music(config.music_fade_duration)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_restore_normal_time()
	Engine.time_scale = 1.0
	PauseManager.release_pause(PauseManager.UPGRADE)
	PauseManager.release_pause(PauseManager.SKILLS_MENU)


func _process(delta: float) -> void:
	queue_redraw()
	_update_stress_vision()
	_update_damage_flash(delta)
	if phase == RunPhase.ENDING:
		return
	var frame_time_scale := maxf(Engine.time_scale, 0.001)
	var unscaled_delta := delta / frame_time_scale
	run_elapsed_seconds += delta
	spawner.set_run_elapsed(run_elapsed_seconds)
	if not elite_spawned and run_elapsed_seconds >= config.large_correction_unlock_seconds:
		_spawn_large_correction()
	_update_rapid_eye(delta)
	if phase != RunPhase.ALARM:
		spawner.set_alarm_state(false, 0.0)
		return
	alarm_real_elapsed_seconds += unscaled_delta
	spawner.set_alarm_state(true, alarm_real_elapsed_seconds)
	var near_wake_point := player.global_position.distance_to(WAKE_POINT) <= config.wake_interaction_radius
	var growth_interval := maxf(config.extra_hold_every_seconds, 0.001)
	var required_hold: float = config.base_wake_hold_seconds + floor(alarm_real_elapsed_seconds / growth_interval) * config.extra_hold_seconds
	var wants_to_wake := near_wake_point and Input.is_action_pressed("interact")
	if wants_to_wake:
		if not holding_to_wake:
			holding_to_wake = true
			player.set_attacking_enabled(false)
			player.set_dash_enabled(false)
			Engine.time_scale = _wake_time_scale()
		wake_hold_progress += unscaled_delta
	else:
		if holding_to_wake:
			_cancel_wake_hold()
		wake_hold_progress = maxf(0.0, wake_hold_progress - config.wake_progress_regress_per_second * unscaled_delta)
	wake_overlay.update_alarm(alarm_real_elapsed_seconds, near_wake_point, wake_hold_progress, required_hold)
	if wake_hold_progress >= required_hold:
		_complete_wake()


func add_projectile(projectile: Node2D) -> void:
	projectile_container.add_child(projectile)


func resolve_player_hit(enemy: Node, base_damage: float, hit_origin: Vector2) -> Dictionary:
	if not is_instance_valid(enemy) or bool(enemy.get("dead")):
		return {}
	var result: Dictionary = player.calculate_player_damage(base_damage)
	enemy.take_damage(float(result.damage), hit_origin)
	_show_damage_number(enemy.global_position + Vector2(0, -18), int(result.damage), bool(result.is_critical))
	return result


func _show_damage_number(at_position: Vector2, amount: int, is_critical: bool) -> void:
	var number: Node2D
	if damage_number_pool.is_empty():
		number = DAMAGE_NUMBER_SCENE.instantiate()
		number.finished.connect(_recycle_damage_number.bind(number))
		$DamageNumberPool.add_child(number)
	else:
		number = damage_number_pool.pop_back()
	number.activate(at_position, amount, is_critical)


func _recycle_damage_number(number: Node2D) -> void:
	if not damage_number_pool.has(number):
		damage_number_pool.append(number)


func add_beam(beam: Node2D) -> void:
	projectile_container.add_child(beam)


func add_weapon_effect(effect: Node2D) -> void:
	projectile_container.add_child(effect)


func spawn_weapon_muzzle(at_position: Vector2, direction: Vector2, effect_kind: StringName) -> void:
	var effect := MUZZLE_EFFECT_SCENE.instantiate()
	effect.global_position = at_position
	var duration := config.beam_charge_seconds if effect_kind == &"beam_charge" else config.weapon_muzzle_flash_seconds
	effect.setup(direction, effect_kind, duration, config.weapon_effect_primary_color, config.weapon_effect_secondary_color)
	add_weapon_effect(effect)


func spawn_combat_feedback(at_position: Vector2, direction: Vector2, is_kill: bool) -> void:
	var effect := preload("res://scenes/entities/combat_feedback_effect.tscn").instantiate()
	effect.global_position = at_position
	effect.setup(direction, is_kill, config.kill_pop_animation_seconds if is_kill else config.weapon_hit_effect_seconds, config.weapon_effect_primary_color, config.weapon_effect_secondary_color, config.weapon_effect_warning_color)
	add_weapon_effect(effect)


func request_hit_stop() -> void:
	if phase == RunPhase.ENDING or holding_to_wake or get_tree().paused or hit_stop_in_progress:
		return
	var now := Time.get_ticks_msec()
	if now - last_hit_stop_msec < int(config.hit_stop_minimum_interval * 1000.0):
		return
	last_hit_stop_msec = now
	hit_stop_in_progress = true
	hit_stop_token += 1
	var token := hit_stop_token
	var previous_scale := Engine.time_scale
	Engine.time_scale = minf(previous_scale, config.hit_stop_time_scale)
	await get_tree().create_timer(config.hit_stop_duration, false, false, true).timeout
	if token != hit_stop_token:
		return
	hit_stop_in_progress = false
	if get_tree().paused:
		Engine.time_scale = 1.0
	elif holding_to_wake:
		Engine.time_scale = _wake_time_scale()
	elif phase != RunPhase.ENDING:
		Engine.time_scale = previous_scale


func spawn_staple(origin: Vector2, direction: Vector2, damage: float, speed: float, distance: float, radius: float, target: Node2D) -> void:
	var staple := STAPLE_SCENE.instantiate()
	staple.position = origin
	staple.setup(direction, damage, speed, distance, radius, target)
	projectile_container.add_child(staple)


func _on_spawn_requested(spawn_position: Vector2, health_multiplier: float, damage_multiplier: float, enemy_type: String = "basic") -> void:
	if phase == RunPhase.ENDING:
		return
	var enemy_scene: PackedScene = ENEMY_SCENE
	if enemy_type == "correction": enemy_scene = CORRECTION_SCENE
	elif enemy_type == "stapler": enemy_scene = STAPLER_SCENE
	elif enemy_type == "alarm_clock": enemy_scene = ALARM_CLOCK_SCENE
	elif enemy_type == "mailbox": enemy_scene = MAILBOX_SCENE
	var enemy := enemy_scene.instantiate()
	var health := config.base_enemy_health * health_multiplier
	var damage := config.base_enemy_damage * damage_multiplier
	if enemy_type == "alarm_clock":
		health = config.alarm_enemy_max_hp * health_multiplier
		damage = 0.0
	elif enemy_type == "mailbox":
		health = config.mailbox_enemy_max_hp * health_multiplier
		damage = config.mailbox_enemy_contact_damage * damage_multiplier
	_configure_enemy(enemy, spawn_position, health, damage)
	if enemy.has_signal("special_defeated"):
		enemy.special_defeated.connect(_on_special_enemy_defeated)
	else:
		enemy.defeated.connect(_on_enemy_defeated)
	if enemy.has_signal("split_requested"):
		enemy.split_requested.connect(_on_mailbox_split_requested)
	enemy_container.add_child(enemy)
	_apply_slow_to_enemy(enemy)


func _configure_enemy(enemy: Node, spawn_position: Vector2, health: float, damage: float) -> void:
	enemy.position = spawn_position
	enemy.configure(player, health, damage, ARENA_BOUNDS, config.enemy_separation_strength, config.enemy_separation_radius, config)
	if enemy.has_method("configure_special"):
		enemy.configure_special(config)


func _spawn_large_correction() -> void:
	elite_spawned = true
	var spawn_position: Variant = spawner.request_valid_spawn_position()
	if spawn_position == null:
		spawn_position = ARENA_BOUNDS.position + Vector2(18, 18)
	var elite := LARGE_CORRECTION_SCENE.instantiate()
	_configure_enemy(elite, spawn_position, config.base_enemy_health * config.large_correction_health_multiplier, config.base_enemy_damage)
	elite.defeated.connect(_on_elite_defeated)
	enemy_container.add_child(elite)
	_apply_slow_to_enemy(elite)


func _on_enemy_defeated(at_position: Vector2, drop_count: int = 1) -> void:
	kills += 1
	for drop_index in range(maxi(1, drop_count)):
		var gem := XP_GEM_SCENE.instantiate()
		var angle := TAU * float(drop_index) / float(maxi(1, drop_count))
		gem.position = at_position + Vector2.RIGHT.rotated(angle) * (6.0 if drop_count > 1 else 0.0)
		gem.target = player
		gem.collected.connect(_on_experience_collected)
		pickup_container.add_child(gem)
	hud.set_progression(level, experience, get_experience_requirement(level), kills)


func _on_elite_defeated(_at_position: Vector2, _drop_count: int = 1) -> void:
	kills += 1
	var reward := int(floor(get_experience_requirement(level) * config.large_correction_experience_ratio))
	_grant_experience(reward)


func _on_special_enemy_defeated(at_position: Vector2, experience_value: int, rarity: String) -> void:
	kills += 1
	var gem := XP_GEM_SCENE.instantiate()
	gem.position = at_position
	gem.target = player
	gem.configure(experience_value, rarity)
	gem.collected.connect(_on_experience_collected)
	pickup_container.add_child(gem)
	hud.set_progression(level, experience, get_experience_requirement(level), kills)


func _on_mailbox_split_requested(at_position: Vector2, count: int) -> void:
	var reserved_positions: Array[Vector2] = []
	for split_index in range(maxi(0, count)):
		var spawn_position: Variant = null
		for attempt in range(maxi(1, config.enemy_spawn_position_max_retries)):
			var angle := TAU * float(split_index * config.enemy_spawn_position_max_retries + attempt) / float(maxi(1, count * config.enemy_spawn_position_max_retries))
			var candidate := at_position + Vector2.RIGHT.rotated(angle) * (34.0 + attempt * 3.0)
			if _is_split_position_valid(candidate, reserved_positions):
				spawn_position = candidate
				reserved_positions.append(candidate)
				break
		if spawn_position == null:
			continue
		var tape := CORRECTION_SCENE.instantiate()
		_configure_enemy(tape, spawn_position, config.base_enemy_health, config.base_enemy_damage)
		tape.defeated.connect(_on_enemy_defeated)
		enemy_container.add_child(tape)
		_apply_slow_to_enemy(tape)


func _is_split_position_valid(candidate: Vector2, reserved_positions: Array[Vector2]) -> bool:
	if not ARENA_BOUNDS.grow(-14.0).has_point(candidate) or candidate.distance_to(player.global_position) < 28.0:
		return false
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if is_instance_valid(enemy) and candidate.distance_to(enemy.global_position) < 26.0:
			return false
	for reserved in reserved_positions:
		if candidate.distance_to(reserved) < 26.0:
			return false
	return true


func _on_experience_collected(raw_amount: int) -> void:
	if phase == RunPhase.ENDING or raw_amount <= 0:
		return
	SFX.play_event(&"experience")
	_grant_experience(raw_amount)


func _grant_experience(raw_amount: int) -> void:
	if phase == RunPhase.ENDING:
		return
	var multiplier := 1.0 + int(permanent_upgrades.get("brainstem", 0)) * config.brainstem_experience_per_level
	var scaled := raw_amount * multiplier + experience_fractional_carry
	var amount := int(floor(scaled))
	experience_fractional_carry = scaled - amount
	experience += amount
	total_experience_earned += amount
	var required := get_experience_requirement(level)
	while experience >= required:
		experience -= required
		level += 1
		pending_upgrades += 1
		required = get_experience_requirement(level)
	hud.set_progression(level, experience, required, kills)
	if pending_upgrades > 0 and not upgrade_panel.visible:
		_begin_upgrade_sequence()


func _on_upgrade_chosen(option: Dictionary) -> void:
	if pending_upgrades <= 0:
		return
	_apply_upgrade(option)
	pending_upgrades -= 1
	if pending_upgrades > 0:
		_open_next_upgrade()
	else:
		PauseManager.release_pause(PauseManager.UPGRADE)
		SFX.clear_music_duck(&"UPGRADE_UI", config.upgrade_music_duck_fade_duration)
		_restore_normal_time()
		_set_menu_pointer(false)
		player.set_attacking_enabled(true)
		player.set_dash_enabled(true)
	hud.set_progression(level, experience, get_experience_requirement(level), kills)


func _apply_upgrade(option: Dictionary) -> void:
	var family := str(option.family)
	if int(option.get("replace_rank", 0)) > 0:
		skill_levels[family] = int(option.replace_rank)
	else:
		skill_levels[family] = int(skill_levels.get(family, 0)) + 1
	match str(option.id):
		"damage_boost": player.apply_damage_upgrade(config.damage_upgrade_multiplier)
		"attack_speed_boost": player.apply_attack_speed_upgrade(config.normal_attack_speed_upgrade_multiplier)
		"range_boost": player.apply_range_upgrade(config.normal_range_upgrade_pixels)
		"sleep_paralysis_blue": player.configure_sleep_paralysis(config.sleep_paralysis_blue_still_seconds, config.sleep_paralysis_blue_heal_per_second)
		"sleep_paralysis_purple": player.configure_sleep_paralysis(config.sleep_paralysis_purple_still_seconds, config.sleep_paralysis_purple_heal_per_second)
		"sleep_paralysis_gold": player.configure_sleep_paralysis(config.sleep_paralysis_gold_still_seconds, config.sleep_paralysis_gold_heal_per_second)
		"sleep_spindle_blue": player.configure_sleep_spindle(config.sleep_spindle_blue_interval, config.sleep_spindle_max_layers)
		"sleep_spindle_purple": player.configure_sleep_spindle(config.sleep_spindle_purple_interval, config.sleep_spindle_max_layers)
		"sleep_spindle_gold": player.configure_sleep_spindle(config.sleep_spindle_gold_interval, config.sleep_spindle_max_layers)
		"hypnic_jerk": player.add_dash_charge_capacity(config)
		"consciousness_drift": player.configure_consciousness_drift(int(skill_levels[family]), config)
		"dissociation": player.enable_dissociation(config)


func get_experience_requirement(for_level: int) -> int:
	var cap := maxi(1, config.experience_requirement_cap)
	if for_level <= 1:
		return clampi(config.first_level_experience_requirement, 1, cap)
	var growth_base := maxi(2, config.experience_growth_base)
	var required := 1
	for _power in range(for_level):
		if required > cap / growth_base:
			return cap
		required *= growth_base
	return mini(required, cap)


func _begin_upgrade_sequence() -> void:
	_cancel_wake_hold()
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	_set_menu_pointer(true)
	SFX.set_music_duck(&"UPGRADE_UI", config.upgrade_music_duck_db, config.upgrade_music_duck_fade_duration)
	PauseManager.request_pause(PauseManager.UPGRADE)
	_open_next_upgrade()


func _open_next_upgrade() -> void:
	var options := UpgradeCatalog.generate_options(config, skill_levels, random, 3)
	upgrade_panel.open(level - pending_upgrades + 1, options, config.upgrade_refreshes_per_level)


func _on_upgrade_refresh_requested() -> void:
	var options := UpgradeCatalog.generate_options(config, skill_levels, random, 3)
	upgrade_panel.replace_options(options)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_menu") and not PauseManager.has_pause_reason(PauseManager.ESC_MENU) and not upgrade_panel.visible and phase != RunPhase.ENDING:
		_open_skills_menu()
		get_viewport().set_input_as_handled()


func _open_skills_menu() -> void:
	if skills_menu.visible or upgrade_panel.visible:
		return
	_cancel_wake_hold()
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	skills_menu.open(
		UpgradeCatalog.get_owned_cards(config, skill_levels),
		_get_character_stats(),
		{"shield": player.has_shield, "revive": player.dissociation_ready, "rapid_eye": int(skill_levels.get("rapid_eye", 0)) > 0}
	)
	_set_menu_pointer(true)
	if config.tab_menu_pauses_tree:
		PauseManager.request_pause(PauseManager.SKILLS_MENU)


func _close_skills_menu() -> void:
	if not skills_menu.visible:
		return
	skills_menu.close()
	if config.tab_menu_pauses_tree:
		PauseManager.release_pause(PauseManager.SKILLS_MENU)
	_set_menu_pointer(false)
	if phase != RunPhase.ENDING:
		player.set_attacking_enabled(true)
		player.set_dash_enabled(true)


func _set_menu_pointer(menu_active: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_active else Input.MOUSE_MODE_HIDDEN
	crosshair.visible = not menu_active and not sleepwalk_mode


func _get_character_stats() -> Array[Dictionary]:
	var weapon: Node = player.get_active_weapon()
	var weapon_name := "小手枪"
	var base_damage := config.basic_weapon_damage
	var base_range := config.basic_weapon_range
	var base_interval := config.basic_weapon_attack_interval
	match selected_weapon_id:
		"beam":
			weapon_name = "光束武器"
			base_damage = config.beam_damage
			base_range = config.beam_range
			base_interval = config.beam_attack_interval
		"shotgun":
			weapon_name = "霰弹枪"
			base_damage = config.shotgun_pellet_damage
			base_range = config.shotgun_max_distance
			base_interval = config.shotgun_attack_interval
		"katana":
			weapon_name = "太刀"
			base_damage = config.katana_melee_damage
			base_range = config.katana_melee_radius
			base_interval = config.katana_attack_interval
		"grenade":
			weapon_name = "榴弹"
			base_damage = config.grenade_enemy_damage
			base_range = config.grenade_explosion_radius
			base_interval = config.grenade_attack_interval
	var permanent_range := int(permanent_upgrades.get("visual_cortex", 0)) * config.visual_cortex_range_per_level
	var permanent_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	var permanent_health := int(permanent_upgrades.get("hippocampus", 0)) * config.hippocampus_health_per_level
	var experience_multiplier := 1.0 + int(permanent_upgrades.get("brainstem", 0)) * config.brainstem_experience_per_level
	var after_permanent_interval := base_interval / permanent_speed
	var final_speed := base_interval / maxf(float(weapon.attack_interval), 0.001)
	return [
		{"name":"当前武器", "base":weapon_name, "permanent":"—", "cards":"—", "final":weapon_name},
		_stat("最大生命", config.player_base_maximum_health, permanent_health, player.maximum_health - config.player_base_maximum_health - permanent_health, player.maximum_health, ""),
		{"name":"当前生命", "base":"—", "permanent":"—", "cards":"—", "final":"%.0f/%.0f" % [player.current_health, player.maximum_health]},
		_stat("基础伤害", base_damage, 0.0, float(weapon.damage) - base_damage, weapon.damage, ""),
		_stat("攻击范围", base_range, permanent_range, float(weapon.attack_range) - base_range - permanent_range, weapon.attack_range, "px"),
		_stat("攻击间隔", base_interval, after_permanent_interval - base_interval, float(weapon.attack_interval) - after_permanent_interval, weapon.attack_interval, "s"),
		_stat("攻击速度倍率", 1.0, permanent_speed - 1.0, final_speed - permanent_speed, final_speed, "×"),
		_stat("移动速度", config.player_movement_speed, 0.0, player.movement_speed - config.player_movement_speed, player.movement_speed, "px/s"),
		_stat("冲刺距离", config.dash_distance, 0.0, player.dash_distance - config.dash_distance, player.dash_distance, "px"),
		_stat("最大冲刺充能", 1.0, 0.0, player.max_dash_charges - 1.0, player.max_dash_charges, ""),
		_stat("冲刺冷却", config.dash_cooldown, 0.0, player.dash_cooldown - config.dash_cooldown, player.dash_cooldown, "s"),
		_stat("经验获取倍率", 1.0, experience_multiplier - 1.0, 0.0, experience_multiplier, "×"),
		{"name":"暴击率", "base":"%d%%" % roundi(config.player_base_critical_chance * 100.0), "permanent":"—", "cards":"—", "final":"%d%%" % roundi(player.critical_chance * 100.0)},
		{"name":"暴击伤害", "base":"%d%%" % roundi(config.player_critical_damage_multiplier * 100.0), "permanent":"—", "cards":"—", "final":"%d%%" % roundi(player.critical_damage_multiplier * 100.0)}
	]


func _stat(name: String, base: float, permanent: float, cards: float, final: float, suffix: String) -> Dictionary:
	return {
		"name": name,
		"base": _format_stat_value(base, suffix, false),
		"permanent": _format_stat_value(permanent, suffix, true),
		"cards": _format_stat_value(cards, suffix, true),
		"final": _format_stat_value(final, suffix, false)
	}


func _format_stat_value(value: float, suffix: String, signed: bool) -> String:
	var format := "%+.2f" if signed else "%.2f"
	if is_equal_approx(value, roundf(value)):
		format = "%+d" if signed else "%d"
		return (format % int(roundf(value))) + suffix
	return (format % value) + suffix


func _on_time_changed(total_minutes: float) -> void:
	spawner.set_dream_time(total_minutes)
	hud.set_clock(clock.get_formatted_time())


func _on_alarm_started() -> void:
	if phase != RunPhase.RUNNING:
		return
	phase = RunPhase.ALARM
	alarm_real_elapsed_seconds = 0.0
	wake_overlay.start_alarm()
	queue_redraw()


func _on_player_health_changed(current: float, maximum: float) -> void:
	hud.set_health(current, maximum)
	if holding_to_wake and current < maximum:
		_cancel_wake_hold()


func _on_dash_state_changed(remaining: float, total: float, active: bool, charges: int, maximum_charges: int) -> void:
	hud.set_dash_state(remaining, total, active, charges, maximum_charges)


func _on_skill_state_changed(shielded: bool, dissociation_available: bool) -> void:
	hud.set_skill_state(shielded, dissociation_available)


func _on_effective_damage_taken(_amount: float) -> void:
	damage_flash_left = config.player_hurt_screen_flash_seconds
	damage_flash.color.a = config.player_hurt_screen_flash_alpha
	if int(skill_levels.get("rapid_eye", 0)) <= 0:
		return
	rapid_eye_left = config.rapid_eye_duration_seconds
	_set_enemy_slow_multiplier(config.rapid_eye_slow_multiplier)


func _update_damage_flash(delta: float) -> void:
	if damage_flash_left <= 0.0:
		damage_flash.color.a = 0.0
		return
	damage_flash_left = maxf(0.0, damage_flash_left - delta)
	var ratio := damage_flash_left / maxf(config.player_hurt_screen_flash_seconds, 0.001)
	damage_flash.color.a = config.player_hurt_screen_flash_alpha * ratio


func _update_rapid_eye(delta: float) -> void:
	if rapid_eye_left <= 0.0:
		return
	rapid_eye_left = maxf(0.0, rapid_eye_left - delta)
	if rapid_eye_left <= 0.0:
		_set_enemy_slow_multiplier(1.0)


func _set_enemy_slow_multiplier(multiplier: float) -> void:
	rapid_eye_speed_multiplier = maxf(0.0, multiplier)
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if is_instance_valid(enemy) and enemy.has_method("set_movement_speed_multiplier"):
			enemy.set_movement_speed_multiplier(stress_enemy_speed_multiplier * rapid_eye_speed_multiplier)


func _apply_slow_to_enemy(enemy: Node) -> void:
	if enemy.has_method("set_movement_speed_multiplier"):
		enemy.set_movement_speed_multiplier(stress_enemy_speed_multiplier * rapid_eye_speed_multiplier)


func _configure_stress_difficulty() -> void:
	run_stress_value = clampi(run_stress_value, 0, config.stress_max)
	stress_spawn_multiplier = 1.0
	stress_enemy_speed_multiplier = 1.0
	if run_stress_value > config.stress_threshold_vision:
		stress_spawn_multiplier = config.stress_spawn_multiplier_over_70
		stress_enemy_speed_multiplier = config.stress_enemy_speed_multiplier_over_70
	elif run_stress_value > config.stress_threshold_speed:
		stress_spawn_multiplier = config.stress_spawn_multiplier_over_50
		stress_enemy_speed_multiplier = config.stress_enemy_speed_multiplier_over_50
	elif run_stress_value > config.stress_threshold_spawn:
		stress_spawn_multiplier = config.stress_spawn_multiplier_over_30
	spawner.set_stress_spawn_multiplier(stress_spawn_multiplier)
	stress_vision_overlay.visible = run_stress_value > config.stress_threshold_vision
	if stress_vision_overlay.material is ShaderMaterial:
		var material := stress_vision_overlay.material as ShaderMaterial
		material.set_shader_parameter("viewport_size", Vector2(640, 360))
		material.set_shader_parameter("darkness", config.stress_vision_darkness)
		material.set_shader_parameter("edge_softness_ratio", config.stress_vision_edge_softness_ratio)


func _update_stress_vision() -> void:
	if not stress_vision_overlay.visible or not is_instance_valid(player):
		return
	var material := stress_vision_overlay.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("player_screen_position", player.global_position)
	material.set_shader_parameter("vision_radius", minf(player.get_effective_attack_range(), config.stress_vision_max_radius))


func _on_player_died() -> void:
	if phase == RunPhase.ENDING:
		return
	phase = RunPhase.ENDING
	spawner.running = false
	_cancel_wake_hold()
	Engine.time_scale = 1.0
	wake_overlay.stop_alarm()
	var summary := _build_summary("梦中倒下")
	# CRT power-off transition: squeeze the whole screen into a line and die out.
	var wait_time := 0.35 if is_endless_mode else config.death_crt_effect_seconds
	var crt := DEATH_CRT_SCENE.instantiate()
	add_child(crt)
	crt.play(wait_time)
	await get_tree().create_timer(wait_time, false).timeout
	dream_finished.emit(summary)


func _complete_wake() -> void:
	if phase == RunPhase.ENDING:
		return
	phase = RunPhase.ENDING
	spawner.running = false
	player.movement_enabled = false
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	_cancel_wake_hold(false)
	Engine.time_scale = 1.0
	await wake_overlay.play_hand_transition()
	dream_finished.emit(_build_summary("主动醒来"))


func _cancel_wake_hold(restore_attack: bool = true) -> void:
	holding_to_wake = false
	_restore_normal_time()
	if restore_attack and is_instance_valid(player) and phase != RunPhase.ENDING:
		player.set_attacking_enabled(true)
		player.set_dash_enabled(true)


func _restore_normal_time() -> void:
	hit_stop_token += 1
	hit_stop_in_progress = false
	Engine.time_scale = dream_game_speed_multiplier


func _wake_time_scale() -> float:
	return dream_game_speed_multiplier * clampf(config.bullet_time_scale, 0.05, 1.0)


func _on_pause_state_changed(paused: bool) -> void:
	if phase == RunPhase.ENDING:
		Engine.time_scale = 1.0
	elif paused:
		Engine.time_scale = 1.0
	elif holding_to_wake:
		Engine.time_scale = _wake_time_scale()
	else:
		_restore_normal_time()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and holding_to_wake:
		_cancel_wake_hold()


func _build_summary(reason: String) -> Dictionary:
	var dream_end_minutes: float = clock.current_minutes
	var wake_minutes := dream_end_minutes
	if reason == "梦中倒下" and not is_endless_mode:
		wake_minutes += randi_range(config.death_wake_delay_min_minutes, config.death_wake_delay_max_minutes)
	return {
		"wake_time": RunSettlement.format_time(wake_minutes),
		"wake_minutes": wake_minutes,
		"dream_end_minutes": dream_end_minutes,
		"alarm_minutes": config.alarm_start_minutes,
		"kills": kills,
		"level": level,
		"total_experience": total_experience_earned,
		"late": not is_sunday and wake_minutes > config.alarm_start_minutes,
		"reason": reason,
		"is_sunday": is_sunday,
		"is_endless_mode": is_endless_mode,
		"survival_seconds": run_elapsed_seconds
	}


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("11101a"))
	draw_rect(Rect2(24, 46, 592, 274), Color("24202e"))
	draw_rect(Rect2(31, 53, 578, 260), Color("191824"))
	for x in range(48, 610, 56):
		for y in range(70, 314, 48):
			draw_circle(Vector2(x, y), 1.5, Color("393143"))
	draw_rect(Rect2(24, 46, 592, 274), Color("53475f"), false, 2.0)
	if phase == RunPhase.ALARM:
		draw_rect(Rect2(46, 251, 84, 49), Color("59505e"))
		draw_rect(Rect2(54, 242, 33, 15), Color("989098"))
		draw_circle(WAKE_POINT, config.wake_interaction_radius, Color(0.6, 0.48, 0.55, 0.09))
