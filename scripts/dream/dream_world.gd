extends Node2D

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal dream_finished(summary: Dictionary)
signal weapon_equipped(weapon_id: String)
signal story_card_progress_changed(levels: Dictionary)

const ENEMY_SCENE := preload("res://scenes/entities/basic_enemy.tscn")
const XP_GEM_SCENE := preload("res://scenes/entities/xp_gem.tscn")
const HEART_PICKUP_SCENE := preload("res://scenes/entities/heart_pickup.tscn")
const CORRECTION_SCENE := preload("res://scenes/entities/correction_tape_enemy.tscn")
const STAPLER_SCENE := preload("res://scenes/entities/stapler_enemy.tscn")
const LARGE_CORRECTION_SCENE := preload("res://scenes/entities/large_correction_tape_enemy.tscn")
const ALARM_CLOCK_SCENE := preload("res://scenes/entities/alarm_clock_enemy.tscn")
const MAILBOX_SCENE := preload("res://scenes/entities/mailbox_enemy.tscn")
const TENTACLE_SCENE := preload("res://scenes/entities/tentacle_enemy.tscn")
const STAPLE_SCENE := preload("res://scenes/entities/staple_projectile.tscn")
const MUZZLE_EFFECT_SCENE := preload("res://scenes/entities/weapon_muzzle_effect.tscn")
const PROJECTILE_SEQUENCE_SCENE := preload("res://scenes/entities/projectile_sequence_effect.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/ui/damage_number.tscn")
const DEATH_CRT_SCENE := preload("res://scenes/ui/death_crt_effect.tscn")
const ARENA_BOUNDS := Rect2(24, 24, 992, 432)
const WORLD_SIZE := Vector2(1040, 480)

enum RunPhase { RUNNING, ALARM, ENDING }

@export var config: DemoConfig

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/DreamCamera
@onready var clock: Node = $DreamClock
@onready var spawner: Node = $EnemySpawner
@onready var tentacle_spawner: Node = $TentacleSpawner
@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var pickup_container: Node2D = $PickupContainer
@onready var hud: Control = $UILayer/DreamHUD
@onready var wake_overlay: Control = $UILayer/WakeOverlay
@onready var upgrade_panel: Control = $UILayer/UpgradePanel
@onready var crosshair: Control = $UILayer/Crosshair
@onready var skills_menu: Control = $UILayer/SkillsMenu
@onready var dream_canvas_modulate: CanvasModulate = $DreamLighting/CanvasModulate

var phase := RunPhase.RUNNING
var kills := 0
var level := 1
var experience := 0
var pending_upgrades := 0
var wake_hold_progress := 0.0
var holding_to_wake := false
var alarm_real_elapsed_seconds := 0.0
var selected_weapon_id := "basic"
var unlocked_weapon_ids: Array[String] = []
var used_weapon_reward_ids: Dictionary = {}
var total_experience_earned := 0
var run_elapsed_seconds := 0.0
var elite_spawned := false
var permanent_upgrades: Dictionary = {}
var story_upgrade_levels: Dictionary = {}
var skill_levels: Dictionary = {}
var experience_fractional_carry := 0.0
var rapid_eye_left := 0.0
var is_sunday := false
var sleepwalk_mode := false
var is_endless_mode := false
var difficulty_day := 1
var endless_day := 1
var completed_endless_days := 0
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
# 每个敌人的总伤累计窗口：instance_id → 当前活跃的总伤数字节点。
var damage_totals: Dictionary = {}
var slot_rerolls_remaining := 1

@onready var damage_flash: ColorRect = $UILayer/DamageFlash


func _ready() -> void:
	add_to_group("dream_world")
	dream_game_speed_multiplier = config.fast_sleep_game_speed_multiplier if SettingsManager.get_fast_sleep_enabled() else 1.0
	Engine.time_scale = dream_game_speed_multiplier
	SFX.play_battle_music(false, get_instance_id())
	random.randomize()
	used_weapon_reward_ids.clear()
	used_weapon_reward_ids[selected_weapon_id] = true
	slot_rerolls_remaining = maxi(0, config.slot_rerolls_per_run)
	player.arena_bounds = ARENA_BOUNDS
	player.configure_weapon(selected_weapon_id, config, permanent_upgrades)
	player.configure_run_modifiers(is_hungry_run, config)
	# 每个Dream都从Player/Weapon基础值重建；剧情卡片只在基础和眠网加成之后恢复一次。
	skill_levels.clear()
	if not is_endless_mode:
		skill_levels = UpgradeCatalog.normalize_owned_levels(config, story_upgrade_levels)
		_apply_restored_story_upgrades()
	player.configure_aim(sleepwalk_mode, config)
	dream_canvas_modulate.color = config.dream_ambient_color
	player.configure_feedback_audio(config)
	player.start_invulnerability(config.player_spawn_invulnerability_duration, &"dream_spawn")
	crosshair.config = config
	crosshair.configure(player)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	crosshair.visible = not sleepwalk_mode
	clock.alarm_enabled = not is_endless_mode
	spawner.player = player
	spawner.endless_mode = is_endless_mode
	spawner.set_difficulty_day(difficulty_day)
	spawner.arena_bounds = ARENA_BOUNDS.grow(-14.0)
	_configure_stress_difficulty()
	wake_overlay.config = config
	player.health_changed.connect(_on_player_health_changed)
	player.healed.connect(_on_player_healed)
	player.dash_state_changed.connect(_on_dash_state_changed)
	player.skill_state_changed.connect(_on_skill_state_changed)
	player.effective_damage_taken.connect(_on_effective_damage_taken)
	player.died.connect(_on_player_died)
	clock.time_changed.connect(_on_time_changed)
	clock.alarm_started.connect(_on_alarm_started)
	spawner.spawn_requested.connect(_on_spawn_requested)
	tentacle_spawner.player = player
	tentacle_spawner.arena_bounds = ARENA_BOUNDS
	tentacle_spawner.running = difficulty_day >= int(config.enemy_unlock_days.get("tentacle", 1))
	tentacle_spawner.tentacle_spawn_requested.connect(_on_tentacle_spawn_requested)
	upgrade_panel.upgrade_chosen.connect(_on_upgrade_chosen)
	upgrade_panel.jackpot_chosen.connect(_on_upgrade_jackpot)
	upgrade_panel.reroll_requested.connect(_on_upgrade_reroll_requested)
	upgrade_panel.exit_finished.connect(_on_upgrade_panel_exited)
	skills_menu.close_requested.connect(_close_skills_menu)
	PauseManager.pause_state_changed.connect(_on_pause_state_changed)
	hud.set_health(player.current_health, player.maximum_health)
	hud.set_progression(level, experience, get_experience_requirement(level), kills)
	hud.set_skill_state(player.has_shield, player.dissociation_ready)
	hud.set_hungry_run(is_hungry_run)
	hud.configure_endless_mode(is_endless_mode, config.endless_day_duration)
	hud.set_endless_day_progress(endless_day, 0.0)
	queue_redraw()
	for _index in range(32):
		var number := DAMAGE_NUMBER_SCENE.instantiate()
		number.finished.connect(_recycle_damage_number.bind(number))
		$DamageNumberPool.add_child(number)
		damage_number_pool.append(number)


func _exit_tree() -> void:
	SFX.clear_music_duck(&"UPGRADE_UI", config.upgrade_music_duck_fade_duration)
	SFX.stop_music(config.music_fade_duration, get_instance_id())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_restore_normal_time()
	Engine.time_scale = 1.0
	PauseManager.release_pause(PauseManager.UPGRADE)
	PauseManager.release_pause(PauseManager.SKILLS_MENU)


func _process(delta: float) -> void:
	queue_redraw()
	_update_damage_flash(delta)
	if phase == RunPhase.ENDING:
		return
	var frame_time_scale := maxf(Engine.time_scale, 0.001)
	var unscaled_delta := delta / frame_time_scale
	run_elapsed_seconds += delta
	spawner.set_run_elapsed(run_elapsed_seconds)
	if is_endless_mode:
		_update_endless_day_state()
	if not elite_spawned and difficulty_day >= int(config.enemy_unlock_days.get("large_correction", 5)):
		_spawn_large_correction()
	_update_rapid_eye(delta)
	if phase != RunPhase.ALARM:
		spawner.set_alarm_state(false, 0.0)
		return
	alarm_real_elapsed_seconds += unscaled_delta
	spawner.set_alarm_state(true, alarm_real_elapsed_seconds)
	var growth_interval := maxf(config.extra_hold_every_seconds, 0.001)
	var required_hold: float = config.base_wake_hold_seconds + floor(alarm_real_elapsed_seconds / growth_interval) * config.extra_hold_seconds
	# 剧情统一06:00后不再生成/寻找床；玩家在梦境任意位置按住F即可尝试醒来。
	var wants_to_wake := Input.is_action_pressed("interact")
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
	wake_overlay.update_alarm(alarm_real_elapsed_seconds, wake_hold_progress, required_hold)
	if wake_hold_progress >= required_hold:
		_complete_wake()


func add_projectile(projectile: Node2D) -> void:
	projectile_container.add_child(projectile)


func resolve_player_hit(enemy: Node, base_damage: float, hit_origin: Vector2) -> Dictionary:
	if not is_instance_valid(enemy) or bool(enemy.get("dead")):
		return {}
	var result: Dictionary = player.calculate_player_damage(base_damage)
	enemy.take_damage(float(result.damage), hit_origin)
	# 伤害数字锚点随敌人新视觉高度自动上移（基类 get_damage_number_offset）。
	var number_offset: Vector2 = enemy.get_damage_number_offset() if enemy.has_method("get_damage_number_offset") else Vector2(0.0, -18.0)
	var anchor: Vector2 = enemy.global_position + number_offset
	# 所有伤害（含暴击）计入同一敌人的总伤累计窗口；
	# 暴击额外弹一个不带数值的“暴击”文字，位置侧移避免与总伤数字重叠。
	_register_total_damage(enemy, anchor, int(result.damage))
	if bool(result.is_critical):
		_show_critical_indicator(anchor)
	return result


func _register_total_damage(enemy: Node, anchor: Vector2, amount: int) -> void:
	var enemy_id := enemy.get_instance_id()
	var existing: Variant = damage_totals.get(enemy_id)
	if existing != null and is_instance_valid(existing) and bool(existing.active):
		existing.add_total(amount)
		return
	var number := _acquire_damage_number()
	number.activate_total(anchor, amount)
	damage_totals[enemy_id] = number


## 暴击提示：只显示“暴击”两个字，不显示红色伤害数值；
## 暴击的真实伤害已由 _register_total_damage 计入总伤累计。
func _show_critical_indicator(anchor: Vector2) -> void:
	var side := 16.0 if randf() < 0.5 else -16.0
	var number := _acquire_damage_number()
	number.activate(anchor + Vector2(side, -10.0))


func _acquire_damage_number() -> Node2D:
	var number: Node2D
	if damage_number_pool.is_empty():
		number = DAMAGE_NUMBER_SCENE.instantiate()
		number.finished.connect(_recycle_damage_number.bind(number))
		$DamageNumberPool.add_child(number)
	else:
		number = damage_number_pool.pop_back()
	return number


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


## 弹丸类武器的 SP402 序列帧子特效：发射点完整播放五帧。
## 特效自带计时与自毁，不阻塞武器射速；弹丸本体飞行时保持首帧常驻。
func spawn_bullet_sequence(at_position: Vector2, direction: Vector2) -> void:
	var effect := PROJECTILE_SEQUENCE_SCENE.instantiate()
	effect.global_position = at_position
	effect.setup(direction)
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


## 相机当前可见的世界空间矩形：viewport 尺寸 ÷ zoom，中心取相机屏幕中心。
## 所有生成器共用本函数计算生成禁区（可见矩形 + enemy_spawn_visibility_margin），
## 不使用任何固定像素猜测值。
func get_camera_visible_world_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(640, 360)
	var zoom := camera.zoom if camera != null else Vector2.ONE
	var visible_size := Vector2(viewport_size.x / maxf(absf(zoom.x), 0.001), viewport_size.y / maxf(absf(zoom.y), 0.001))
	var center := camera.get_screen_center_position() if camera != null else player.global_position
	return Rect2(center - visible_size * 0.5, visible_size)


func _spawn_large_correction() -> void:
	var spawn_position: Variant = spawner.request_valid_spawn_position()
	if spawn_position == null:
		# 尚无屏幕外合法点：本帧放弃，下帧重试；绝不回退到场上固定点（可能进视野）。
		return
	elite_spawned = true
	var elite := LARGE_CORRECTION_SCENE.instantiate()
	_configure_enemy(elite, spawn_position, config.base_enemy_health * config.large_correction_health_multiplier, config.base_enemy_damage)
	elite.defeated.connect(_on_elite_defeated)
	enemy_container.add_child(elite)
	_apply_slow_to_enemy(elite)


func _on_tentacle_spawn_requested(spawn_position: Vector2) -> void:
	if phase == RunPhase.ENDING:
		return
	var tentacle := TENTACLE_SCENE.instantiate()
	_configure_enemy(tentacle, spawn_position, config.tentacle_max_hp, config.tentacle_contact_damage)
	tentacle.special_defeated.connect(_on_special_enemy_defeated)
	tentacle.heart_drop_requested.connect(_on_tentacle_heart_drop_requested)
	enemy_container.add_child(tentacle)


func _on_enemy_defeated(at_position: Vector2, drop_count: int = 1) -> void:
	kills += 1
	for drop_index in range(maxi(1, drop_count)):
		var gem := XP_GEM_SCENE.instantiate()
		gem.set_environment_reference(config)
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
	gem.set_environment_reference(config)
	gem.position = at_position
	gem.target = player
	gem.configure(experience_value, rarity)
	gem.collected.connect(_on_experience_collected)
	pickup_container.add_child(gem)
	hud.set_progression(level, experience, get_experience_requirement(level), kills)


func _on_mailbox_split_requested(at_position: Vector2, count: int) -> void:
	# 宝箱怪死亡分裂属于怪物技能：故意在死亡点原地环形生成，
	# 不受屏幕外生成禁区限制。
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


func _on_tentacle_heart_drop_requested(at_position: Vector2) -> void:
	if phase == RunPhase.ENDING:
		return
	var heart := HEART_PICKUP_SCENE.instantiate()
	heart.set_environment_reference(config)
	heart.position = at_position + Vector2(10.0, 0.0)
	heart.heal_amount = config.heart_pickup_heal_amount
	heart.target = player
	heart.collected.connect(_on_heart_collected)
	pickup_container.add_child(heart)


func _on_heart_collected(heal_amount: float) -> void:
	if phase == RunPhase.ENDING:
		return
	# heal 内部已限制不超过最大生命，且真正回血时才播放 Heal 特效。
	player.heal(heal_amount)


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
	hud.set_progression(level, experience, get_experience_requirement(level), kills)


func _on_upgrade_jackpot(options: Array[Dictionary]) -> void:
	if pending_upgrades <= 0:
		return
	# 三格分别尝试结算；每次重新检查当前等级，达到上限后停止，绝不越界。
	for option in options:
		if _can_apply_upgrade(option):
			_apply_upgrade(option, false)
	_commit_story_card_progress()
	pending_upgrades -= 1
	hud.set_progression(level, experience, get_experience_requirement(level), kills)


func _on_upgrade_panel_exited() -> void:
	if pending_upgrades > 0:
		_open_next_upgrade()
	else:
		PauseManager.release_pause(PauseManager.UPGRADE)
		SFX.clear_music_duck(&"UPGRADE_UI", config.upgrade_music_duck_fade_duration)
		_restore_normal_time()
		_set_menu_pointer(false)
		player.set_attacking_enabled(true)
		player.set_dash_enabled(true)


func _can_apply_upgrade(option: Dictionary) -> bool:
	if str(option.get("reward_type", "upgrade")) == "weapon":
		var weapon_id := str(option.get("weapon_id", ""))
		return weapon_id in unlocked_weapon_ids and weapon_id != selected_weapon_id
	var family := str(option.get("family", ""))
	var current := int(skill_levels.get(family, 0))
	var replace_rank := int(option.get("replace_rank", 0))
	if replace_rank > 0:
		return replace_rank > current
	return current < int(option.get("max_level", 1))


func _apply_upgrade(option: Dictionary, commit_story_progress: bool = true) -> void:
	if str(option.get("reward_type", "upgrade")) == "weapon":
		_equip_run_weapon(str(option.get("weapon_id", "")))
		return
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
	if commit_story_progress:
		_commit_story_card_progress()


func configure_story_upgrade_levels(levels: Dictionary) -> void:
	story_upgrade_levels = UpgradeCatalog.normalize_owned_levels(config, levels)


func _commit_story_card_progress() -> void:
	if is_endless_mode:
		return
	story_upgrade_levels = UpgradeCatalog.normalize_owned_levels(config, skill_levels)
	story_card_progress_changed.emit(story_upgrade_levels.duplicate(true))


## 只在新Dream初始化时调用一次；不会复用上一日Player数值，因此不会重复叠加。
func _apply_restored_story_upgrades() -> void:
	var damage_level := int(skill_levels.get("damage_boost", 0))
	for _index in damage_level:
		player.apply_damage_upgrade(config.damage_upgrade_multiplier)
	var speed_level := int(skill_levels.get("attack_speed_boost", 0))
	for _index in speed_level:
		player.apply_attack_speed_upgrade(config.normal_attack_speed_upgrade_multiplier)
	var range_level := int(skill_levels.get("range_boost", 0))
	if range_level > 0:
		player.apply_range_upgrade(config.normal_range_upgrade_pixels * range_level)
	match int(skill_levels.get("sleep_paralysis", 0)):
		1: player.configure_sleep_paralysis(config.sleep_paralysis_blue_still_seconds, config.sleep_paralysis_blue_heal_per_second)
		2: player.configure_sleep_paralysis(config.sleep_paralysis_purple_still_seconds, config.sleep_paralysis_purple_heal_per_second)
		3: player.configure_sleep_paralysis(config.sleep_paralysis_gold_still_seconds, config.sleep_paralysis_gold_heal_per_second)
	match int(skill_levels.get("sleep_spindle", 0)):
		1: player.configure_sleep_spindle(config.sleep_spindle_blue_interval, config.sleep_spindle_max_layers)
		2: player.configure_sleep_spindle(config.sleep_spindle_purple_interval, config.sleep_spindle_max_layers)
		3: player.configure_sleep_spindle(config.sleep_spindle_gold_interval, config.sleep_spindle_max_layers)
	for _index in int(skill_levels.get("hypnic_jerk", 0)):
		player.add_dash_charge_capacity(config)
	var drift_level := int(skill_levels.get("consciousness_drift", 0))
	if drift_level > 0:
		player.configure_consciousness_drift(drift_level, config)
	if int(skill_levels.get("dissociation", 0)) > 0:
		player.enable_dissociation(config)


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
	var slot_weapon_ids: Array[String] = _slot_weapon_ids_for_mode()
	var options := UpgradeCatalog.generate_slot_options(config, skill_levels, random, 9, slot_weapon_ids, _used_weapon_reward_id_list())
	upgrade_panel.open(level - pending_upgrades + 1, options, slot_rerolls_remaining)


func _on_upgrade_reroll_requested() -> void:
	if slot_rerolls_remaining <= 0:
		return
	slot_rerolls_remaining -= 1
	var slot_weapon_ids: Array[String] = _slot_weapon_ids_for_mode()
	var options := UpgradeCatalog.generate_slot_options(config, skill_levels, random, 9, slot_weapon_ids, _used_weapon_reward_id_list())
	upgrade_panel.replace_options(options)


func _equip_run_weapon(weapon_id: String) -> void:
	if weapon_id.is_empty() or weapon_id == selected_weapon_id or not weapon_id in unlocked_weapon_ids:
		return
	player.equip_weapon(weapon_id, config, permanent_upgrades)
	selected_weapon_id = weapon_id
	# 只在武器真正结算并装备后标记；Reel显示和Reroll都不会消耗武器池。
	used_weapon_reward_ids[weapon_id] = true
	weapon_equipped.emit(weapon_id)


func configure_run_weapon_state(weapon_id: String, available_weapon_ids: Array[String], endless: bool) -> void:
	var valid_ids: Array[String] = []
	for candidate in available_weapon_ids:
		if candidate in ["basic", "beam", "shotgun", "katana", "grenade"] and not candidate in valid_ids:
			valid_ids.append(candidate)
	if valid_ids.is_empty():
		valid_ids.append("basic")
	selected_weapon_id = weapon_id if weapon_id in valid_ids else "basic"
	unlocked_weapon_ids = valid_ids
	is_endless_mode = endless


func _used_weapon_reward_id_list() -> Array[String]:
	var result: Array[String] = []
	for weapon_id in used_weapon_reward_ids:
		result.append(str(weapon_id))
	return result


## 显式重建 typed array，避免三元表达式的 `else []` 将运行时类型退化为 Array。
## 剧情模式返回真正的空 Array[String]；无尽模式逐项复制当局可用武器ID。
func _slot_weapon_ids_for_mode() -> Array[String]:
	var result: Array[String] = []
	if not is_endless_mode:
		return result
	for weapon_id: String in unlocked_weapon_ids:
		result.append(weapon_id)
	return result


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


func _update_endless_day_state() -> void:
	var day_duration := maxf(config.endless_day_duration, 0.001)
	completed_endless_days = maxi(0, floori(run_elapsed_seconds / day_duration))
	endless_day = completed_endless_days + 1
	var day_progress := fmod(run_elapsed_seconds, day_duration) / day_duration
	if difficulty_day != endless_day:
		difficulty_day = endless_day
		spawner.set_difficulty_day(difficulty_day)
		tentacle_spawner.running = difficulty_day >= int(config.enemy_unlock_days.get("tentacle", 1))
	hud.set_endless_day_progress(endless_day, day_progress)


func _on_player_health_changed(current: float, maximum: float) -> void:
	hud.set_health(current, maximum)
	if holding_to_wake and current < maximum:
		_cancel_wake_hold()


func _on_player_healed(actual_heal: float) -> void:
	if actual_heal <= 0.0:
		return
	var number := _acquire_damage_number()
	number.activate_heal(player.global_position, roundi(actual_heal))


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
	# 旧StressVision黑色圆孔遮罩不再叠加；高压力只收缩基础PlayerLight。
	player.configure_dream_light(config, run_stress_value)


func _on_player_died() -> void:
	if phase == RunPhase.ENDING:
		return
	phase = RunPhase.ENDING
	spawner.running = false
	tentacle_spawner.running = false
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
	tentacle_spawner.running = false
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
		"late": not is_sunday and RunSettlement.attendance_for_minutes(wake_minutes) != "正常出勤",
		"reason": reason,
		"is_sunday": is_sunday,
		"is_endless_mode": is_endless_mode,
		"survival_seconds": run_elapsed_seconds,
		"endless_day": endless_day,
		"completed_endless_days": completed_endless_days,
		"difficulty_day": difficulty_day
	}


func _draw() -> void:
	# Crawling Depths TileMap 覆盖整个世界；这里只垫底色防止缝隙露白。
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("0d0b12"))
