extends CharacterBody2D

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const HEAL_EFFECT_SCENE := preload("res://scenes/entities/heal_effect.tscn")
const DASH_EFFECT_SCENE := preload("res://scenes/entities/dash_effect.tscn")
const OUTLINE_SHADER := preload("res://shaders/sprite_alpha_outline.gdshader")
const CONFIG := preload("res://resources/demo_config.tres")

signal health_changed(current: float, maximum: float)
signal died
signal dash_state_changed(remaining: float, total: float, active: bool, charges: int, maximum_charges: int)
signal weapon_fired(recoil_multiplier: float)
signal skill_state_changed(shielded: bool, dissociation_ready: bool)
signal effective_damage_taken(amount: float)
signal healed(amount: float)
signal revived

@export var movement_speed := 112.0
@export var maximum_health := 100.0

@onready var auto_weapon: Node = $AutoWeapon
@onready var beam_weapon: Node = $BeamWeapon
@onready var shotgun_weapon: Node = $ShotgunWeapon
@onready var katana_weapon: Node = $KatanaWeapon
@onready var grenade_weapon: Node = get_node_or_null("GrenadeWeapon")
@onready var visual: AnimatedSprite2D = $Visual
@onready var heal_overlay: AnimatedSprite2D = $HealOverlay
@onready var shield_visual: ElectricShieldVisual = $ElectricShieldVisual
@onready var player_light: PointLight2D = $PlayerLight
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var weapon_root: Node2D = $WeaponRoot
@onready var weapon_origin: Marker2D = $WeaponRoot/WeaponOrigin
@onready var projectile_origin: Marker2D = $WeaponRoot/ProjectileOrigin
@onready var aim_origin: Marker2D = $WeaponRoot/AimOrigin
@onready var grenade_origin: Marker2D = $WeaponRoot/GrenadeOrigin
@onready var katana_origin: Marker2D = $WeaponRoot/KatanaOrigin
@onready var player_hp_bar: PlayerWorldHealthBar = $PlayerHPBar

var current_health := 100.0
var movement_enabled := true
var arena_bounds := Rect2(32, 52, 576, 266)
var invulnerability_left := 0.0
var invulnerability_reason: StringName = &""
var dash_invulnerability_left := 0.0
var dead := false
var selected_weapon_id := "basic"
var dash_enabled := true
var dash_distance := 100.0
var dash_duration := 0.18
var dash_cooldown := 2.0
var dash_invulnerability_seconds := 0.18
var dash_cooldown_left := 0.0
var max_dash_charges := 1
var dash_charges := 1
var dashing := false
var dash_elapsed := 0.0
var active_dash_duration := 0.18
var dash_start := Vector2.ZERO
var dash_end := Vector2.ZERO
var last_move_direction := Vector2.RIGHT
var last_aim_direction := Vector2.RIGHT
var sleepwalk_mode := false
var auto_aim_search_radius := 900.0
var auto_aim_refresh_interval := 0.08
var auto_aim_refresh_left := 0.0
var auto_aim_target: Node2D
var hurt_invulnerability_seconds := 0.55
var hurt_flash_frequency := 12.0
var hurt_flash_seconds := 0.18
var hurt_shake_pixels := 2.0
var hurt_flash_left := 0.0
var shield_break_left := 0.0
var revive_flash_left := 0.0
var heal_overlay_tween: Tween

var sleep_paralysis_still_seconds := 0.0
var sleep_paralysis_heal_per_second := 0.0
var still_elapsed := 0.0
var heal_tick_accumulator := 0.0
var sleep_spindle_interval := 0.0
var sleep_spindle_left := 0.0
var sleep_spindle_max_layers := 1
var has_shield := false
var dissociation_ready := false
var dissociation_revive_health := 30.0
var dissociation_invulnerability_seconds := 3.0
var feedback_audio: AudioStreamPlayer
var visual_home_position := Vector2(0, -18.25)
var run_damage_multiplier := 1.0
var acquired_damage_multiplier := 1.0
var acquired_attack_speed_multiplier := 1.0
var acquired_range_pixels := 0.0
var dash_disabled_by_hunger := false
var critical_chance := 0.10
var critical_damage_multiplier := 1.50
var last_heal_effect_msec := 0
const HEAL_EFFECT_THROTTLE_MSEC := 700


func configure_weapon(weapon_id: String, config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	selected_weapon_id = weapon_id
	movement_speed = config.player_movement_speed
	auto_weapon.configure_weapon(config, permanent_upgrades)
	beam_weapon.configure_weapon(config, permanent_upgrades)
	shotgun_weapon.configure_weapon(config, permanent_upgrades)
	katana_weapon.configure_weapon(config, permanent_upgrades)
	if grenade_weapon != null:
		grenade_weapon.configure_weapon(config, permanent_upgrades)
	critical_chance = clampf(config.player_base_critical_chance, 0.0, 1.0)
	critical_damage_multiplier = maxf(config.player_critical_damage_multiplier, 1.0)
	_set_weapon_activity(true)
	dash_distance = config.dash_distance
	dash_duration = config.dash_duration
	dash_cooldown = config.dash_cooldown
	dash_invulnerability_seconds = config.dash_invulnerability_seconds
	hurt_invulnerability_seconds = config.hurt_invulnerability_seconds
	hurt_flash_frequency = config.hurt_flash_frequency
	hurt_flash_seconds = config.hurt_flash_seconds
	hurt_shake_pixels = config.hurt_shake_pixels
	maximum_health = config.player_base_maximum_health + int(permanent_upgrades.get("hippocampus", 0)) * config.hippocampus_health_per_level
	current_health = maximum_health
	# 使用绝对配置值，禁止每次进场scale *= 0.75造成累计缩小。
	visual.scale = Vector2.ONE * config.player_visual_scale
	heal_overlay.scale = visual.scale
	shield_visual.configure(config.electric_shield_animation_fps, config.electric_shield_visual_scale)
	visual_home_position = config.player_visual_offset
	visual.position = visual_home_position
	heal_overlay.position = visual_home_position
	body_collision.position = config.player_collision_offset
	var body_shape := body_collision.shape as CircleShape2D
	if body_shape != null:
		body_shape.radius = config.player_collision_radius
	weapon_root.position = config.player_weapon_root_offset
	for animation_name in [&"walk_down", &"walk_left", &"walk_right", &"walk_up"]:
		visual.sprite_frames.set_animation_speed(animation_name, config.player_walk_animation_fps)
	for animation_name in [&"idle_down", &"idle_left", &"idle_right", &"idle_up"]:
		visual.sprite_frames.set_animation_speed(animation_name, config.player_idle_animation_fps)
	dissociation_revive_health = config.dissociation_revive_health
	dissociation_invulnerability_seconds = config.dissociation_invulnerability_seconds
	health_changed.emit(current_health, maximum_health)
	player_hp_bar.configure(config, current_health, maximum_health)


## 剧情局内换武器：只改变未来攻击源，世界中已发射的Projectile保持独立生命周期。
func equip_weapon(weapon_id: String, config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	_set_weapon_activity(false)
	selected_weapon_id = weapon_id
	auto_weapon.configure_weapon(config, permanent_upgrades)
	beam_weapon.configure_weapon(config, permanent_upgrades)
	shotgun_weapon.configure_weapon(config, permanent_upgrades)
	katana_weapon.configure_weapon(config, permanent_upgrades)
	if grenade_weapon != null:
		grenade_weapon.configure_weapon(config, permanent_upgrades)
	var weapon := get_active_weapon()
	if acquired_damage_multiplier > 1.0:
		if weapon.has_method("apply_damage_upgrade"): weapon.apply_damage_upgrade(acquired_damage_multiplier)
		else: weapon.damage *= acquired_damage_multiplier
	if acquired_attack_speed_multiplier > 1.0:
		if weapon.has_method("apply_attack_speed_upgrade"): weapon.apply_attack_speed_upgrade(acquired_attack_speed_multiplier)
		else: weapon.attack_interval /= acquired_attack_speed_multiplier
	if acquired_range_pixels > 0.0:
		if weapon.has_method("apply_range_upgrade"): weapon.apply_range_upgrade(acquired_range_pixels)
		else: weapon.attack_range += acquired_range_pixels
	weapon.set("cooldown_left", minf(float(weapon.get("cooldown_left")), 0.25))
	_set_weapon_activity(not dead)


func configure_aim(use_sleepwalk_mode: bool, config: DemoConfig) -> void:
	sleepwalk_mode = use_sleepwalk_mode
	auto_aim_search_radius = maxf(0.0, config.auto_aim_search_radius)
	auto_aim_refresh_interval = maxf(0.02, config.auto_aim_refresh_interval)
	auto_aim_refresh_left = 0.0
	auto_aim_target = null


func configure_run_modifiers(is_hungry_run: bool, config: DemoConfig) -> void:
	run_damage_multiplier = config.hungry_damage_multiplier if is_hungry_run else 1.0
	dash_disabled_by_hunger = is_hungry_run
	set_dash_enabled(not dash_disabled_by_hunger)


func configure_dream_light(config: DemoConfig, stress_value: int) -> void:
	# 单个256px程序化径向纹理；不创建巨大PNG，也不给敌人、子弹或掉落物增加实时光源。
	if player_light.texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, clampf(config.player_light_falloff, 0.05, 0.8), 1.0])
		gradient.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 0.78),
			Color(1.0, 1.0, 1.0, 0.0),
		])
		var light_texture := GradientTexture2D.new()
		light_texture.width = 256
		light_texture.height = 256
		light_texture.fill = GradientTexture2D.FILL_RADIAL
		light_texture.fill_from = Vector2(0.5, 0.5)
		light_texture.fill_to = Vector2(1.0, 0.5)
		light_texture.gradient = gradient
		player_light.texture = light_texture
	player_light.color = config.player_light_color
	player_light.energy = config.player_light_energy
	var radius_multiplier := config.stress_light_radius_multiplier if stress_value > config.stress_threshold_vision else 1.0
	player_light.texture_scale = maxf(config.player_light_radius * radius_multiplier, 1.0) / 128.0


func calculate_player_damage(base_damage: float) -> Dictionary:
	var modified_damage := maxf(1.0, base_damage * run_damage_multiplier)
	var is_critical := randf() < critical_chance
	if is_critical:
		modified_damage *= critical_damage_multiplier
	return {"damage": maxi(1, roundi(modified_damage)), "is_critical": is_critical}


func get_effective_attack_range() -> float:
	var weapon := get_active_weapon()
	if selected_weapon_id == "katana":
		return maxf(float(weapon.attack_range), float(weapon.wave_distance))
	return float(weapon.attack_range)


func is_dash_hunger_disabled() -> bool:
	return dash_disabled_by_hunger


func _ready() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)
	auto_weapon.weapon_fired.connect(func(multiplier: float): weapon_fired.emit(multiplier))
	beam_weapon.weapon_fired.connect(func(multiplier: float): weapon_fired.emit(multiplier))
	shotgun_weapon.weapon_fired.connect(func(multiplier: float): weapon_fired.emit(multiplier))
	katana_weapon.weapon_fired.connect(func(multiplier: float): weapon_fired.emit(multiplier))
	if grenade_weapon != null:
		grenade_weapon.weapon_fired.connect(func(multiplier: float): weapon_fired.emit(multiplier))
	feedback_audio = AudioStreamPlayer.new()
	feedback_audio.bus = &"Characters"
	add_child(feedback_audio)
	# 玩家 1px Alpha 描边：复用敌人同款 shader，宽度基于 TEXTURE_PIXEL_SIZE，
	# 玩家 1:1 显示时 1 源像素 ≈ 1 视觉像素；图集每帧四周预留 1px 透明 padding 防裁切。
	var outline_material := ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_enabled", 1.0)
	outline_material.set_shader_parameter("outline_width_source_pixels", CONFIG.player_outline_width_px)
	outline_material.set_shader_parameter("outline_color", Color.WHITE)
	visual.material = outline_material
	queue_redraw()


func configure_feedback_audio(config: DemoConfig) -> void:
	feedback_audio.stream = TextBlipFactory.create(config)
	feedback_audio.volume_db = -14.0


func _physics_process(delta: float) -> void:
	invulnerability_left = maxf(0.0, invulnerability_left - delta)
	if invulnerability_left <= 0.0:
		invulnerability_reason = &""
	dash_invulnerability_left = maxf(0.0, dash_invulnerability_left - delta)
	hurt_flash_left = maxf(0.0, hurt_flash_left - delta)
	shield_break_left = maxf(0.0, shield_break_left - delta)
	revive_flash_left = maxf(0.0, revive_flash_left - delta)
	_update_dash_recharge(delta)
	_update_auto_aim(delta)
	queue_redraw()
	_update_visual_feedback()
	if dead:
		velocity = Vector2.ZERO
		_update_direction_animation(Vector2.ZERO)
		return
	if dashing:
		_reset_stillness()
		_update_direction_animation(dash_end - dash_start)
		_update_dash(delta)
		_emit_dash_state()
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down") if movement_enabled else Vector2.ZERO
	_update_direction_animation(input_vector)
	_update_sleep_spindle(delta)
	if input_vector.length_squared() > 0.0:
		last_move_direction = input_vector.normalized()
	if dash_enabled and movement_enabled and dash_charges > 0 and Input.is_action_just_pressed("dash"):
		_start_dash(input_vector.normalized() if input_vector.length_squared() > 0.0 else last_move_direction)
		_emit_dash_state()
		return
	var position_before := global_position
	velocity = input_vector.normalized() * movement_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_bounds.position.x, arena_bounds.end.x)
	global_position.y = clampf(global_position.y, arena_bounds.position.y, arena_bounds.end.y)
	_update_sleep_paralysis(delta, global_position - position_before)
	_emit_dash_state()


func _update_direction_animation(motion: Vector2) -> void:
	if visual == null:
		return
	var direction := motion.normalized() if motion.length_squared() > 0.0001 else last_move_direction
	var suffix := "down"
	if absf(direction.x) > absf(direction.y):
		suffix = "right" if direction.x > 0.0 else "left"
	else:
		suffix = "down" if direction.y >= 0.0 else "up"
	var prefix := "walk" if motion.length_squared() > 0.0001 else "idle"
	var animation_name := StringName(prefix + "_" + suffix)
	# Pix_chr 图集自带独立右向行（row3），不再用 flip_h 镜像左向帧，
	# 彻底避免镜像翻转带来的朝向/缩放异常。
	visual.flip_h = false
	if visual.animation != animation_name or not visual.is_playing():
		visual.play(animation_name)
	if heal_overlay.animation != animation_name:
		heal_overlay.animation = animation_name
	heal_overlay.frame = visual.frame
	heal_overlay.frame_progress = visual.frame_progress


func _update_visual_feedback() -> void:
	if visual == null:
		return
	var visible_invulnerability := maxf(invulnerability_left, dash_invulnerability_left)
	var flash_frequency := 3.0 if invulnerability_reason == &"dream_spawn" else hurt_flash_frequency
	visual.visible = visible_invulnerability <= 0.0 or fmod(visible_invulnerability * flash_frequency, 2.0) < 1.0
	visual.modulate = Color("e66f6b") if hurt_flash_left > 0.0 else Color.WHITE
	if revive_flash_left > 0.0:
		visual.modulate = Color("e2c56e")
	visual.modulate.a = 0.72 if visible_invulnerability > 0.0 else 1.0
	var shake := Vector2(sin(hurt_flash_left * 90.0), cos(hurt_flash_left * 73.0)) * hurt_shake_pixels if hurt_flash_left > 0.0 else Vector2.ZERO
	visual.position = visual_home_position + shake
	heal_overlay.position = visual.position
	heal_overlay.visible = visual.visible


func _update_dash_recharge(delta: float) -> void:
	if dash_charges >= max_dash_charges:
		dash_cooldown_left = 0.0
		return
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	if dash_cooldown_left <= 0.0:
		dash_charges += 1
		if dash_charges < max_dash_charges:
			dash_cooldown_left = dash_cooldown


func _start_dash(direction: Vector2) -> void:
	var normalized_direction := direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	dash_start = global_position
	var requested_end := dash_start + normalized_direction * dash_distance
	dash_end = Vector2(clampf(requested_end.x, arena_bounds.position.x, arena_bounds.end.x), clampf(requested_end.y, arena_bounds.position.y, arena_bounds.end.y))
	var actual_distance := dash_start.distance_to(dash_end)
	if actual_distance < 0.01:
		return
	active_dash_duration = maxf(0.02, dash_duration * actual_distance / maxf(dash_distance, 0.001))
	dash_elapsed = 0.0
	dash_charges -= 1
	if dash_cooldown_left <= 0.0:
		dash_cooldown_left = dash_cooldown
	dashing = true
	dash_invulnerability_left = maxf(active_dash_duration, dash_invulnerability_seconds)
	SFX.play_event(&"dash")
	_spawn_dash_effect(dash_end - dash_start)
	_reset_stillness()


## 空格瞬移的 Thunder 序列帧特效：独立节点，跟随玩家位置与位移过程，
## 不影响 Dash 距离/冷却/无敌逻辑；父节点缺失时仅告警，不阻断 dash。
func _spawn_dash_effect(direction: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		push_error("dream_player: dash 特效生成失败，缺少父节点")
		return
	var effect := DASH_EFFECT_SCENE.instantiate()
	parent.add_child(effect)
	effect.setup(self, direction, active_dash_duration, dash_start.distance_to(dash_end))


func _update_dash(delta: float) -> void:
	dash_elapsed += delta
	var progress := clampf(dash_elapsed / active_dash_duration, 0.0, 1.0)
	global_position = dash_start.lerp(dash_end, progress)
	velocity = Vector2.ZERO
	if progress >= 1.0:
		dashing = false
		global_position = dash_end


func cancel_dash() -> void:
	if dashing:
		global_position.x = clampf(global_position.x, arena_bounds.position.x, arena_bounds.end.x)
		global_position.y = clampf(global_position.y, arena_bounds.position.y, arena_bounds.end.y)
	dashing = false
	dash_invulnerability_left = 0.0
	velocity = Vector2.ZERO


func set_dash_enabled(enabled: bool) -> void:
	dash_enabled = enabled and not dead and not dash_disabled_by_hunger
	if not dash_enabled:
		cancel_dash()


func add_dash_charge_capacity(config: DemoConfig) -> void:
	if max_dash_charges >= config.dash_max_charges:
		return
	max_dash_charges += 1
	dash_charges = mini(max_dash_charges, dash_charges + 1)
	_emit_dash_state()


func _emit_dash_state() -> void:
	dash_state_changed.emit(dash_cooldown_left, dash_cooldown, dashing, dash_charges, max_dash_charges)


func receive_damage(amount: float) -> void:
	if dead or dashing or dash_invulnerability_left > 0.0 or invulnerability_left > 0.0:
		return
	if has_shield:
		has_shield = false
		shield_visual.set_shield_active(false)
		shield_break_left = 0.45
		_play_feedback()
		skill_state_changed.emit(has_shield, dissociation_ready)
		queue_redraw()
		return
	var health_before := current_health
	var next_health := maxf(0.0, current_health - amount)
	if next_health <= 0.0 and dissociation_ready:
		dissociation_ready = false
		current_health = minf(maximum_health, dissociation_revive_health)
		var actual_damage := maxf(0.0, health_before - current_health)
		invulnerability_left = maxf(invulnerability_left, dissociation_invulnerability_seconds)
		invulnerability_reason = &"dissociation"
		revive_flash_left = 0.9
		_apply_heal_feedback()
		_play_feedback()
		health_changed.emit(current_health, maximum_health)
		effective_damage_taken.emit(actual_damage)
		player_hp_bar.show_after_damage(current_health, maximum_health, CONFIG.player_hp_bar_visible_duration)
		skill_state_changed.emit(has_shield, dissociation_ready)
		revived.emit()
		SFX.play_event(&"player_hurt")
		queue_redraw()
		return
	current_health = next_health
	var actual_damage := maxf(0.0, health_before - current_health)
	invulnerability_left = hurt_invulnerability_seconds
	invulnerability_reason = &"hurt"
	hurt_flash_left = hurt_flash_seconds
	health_changed.emit(current_health, maximum_health)
	effective_damage_taken.emit(actual_damage)
	player_hp_bar.show_after_damage(current_health, maximum_health, CONFIG.player_hp_bar_visible_duration)
	queue_redraw()
	if current_health <= 0.0:
		dead = true
		cancel_dash()
		invulnerability_left = 0.0
		_set_weapon_activity(false)
		SFX.play_event(&"death")
		died.emit()
	else:
		SFX.play_event(&"player_hurt")


func start_invulnerability(duration: float, reason: StringName = &"external") -> void:
	var safe_duration := maxf(duration, 0.0)
	if safe_duration <= 0.0:
		return
	if safe_duration >= invulnerability_left:
		invulnerability_reason = reason
	invulnerability_left = maxf(invulnerability_left, safe_duration)
	_update_visual_feedback()


func heal(amount: float) -> void:
	if dead or amount <= 0.0 or current_health >= maximum_health:
		return
	var health_before := current_health
	current_health = minf(maximum_health, current_health + amount)
	var actual_heal := maxf(0.0, current_health - health_before)
	if actual_heal <= 0.0:
		return
	health_changed.emit(current_health, maximum_health)
	player_hp_bar.update_health(current_health, maximum_health)
	healed.emit(actual_heal)
	_apply_heal_feedback()
	_play_heal_effect()


## 统一恢复反馈入口：任何真实回血（actual_heal > 0）播放一次恢复 SFX，
## 并在角色身体上叠加同帧绿色 Sprite。Overlay 不替换主 Sprite 的描边材质，
## 因此能与 1px 描边、受伤闪红、无敌闪烁和现有 Heal 动画共存。
func _apply_heal_feedback() -> void:
	SFX.play_event(&"heal")
	if heal_overlay_tween != null and heal_overlay_tween.is_valid():
		heal_overlay_tween.kill()
	heal_overlay.modulate = Color(0.36, 1.0, 0.45, 0.72)
	heal_overlay_tween = create_tween()
	heal_overlay_tween.tween_property(heal_overlay, "modulate:a", 0.0, CONFIG.heal_feedback_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 真正发生回血时在角色身体中心播放一次 Heal 动画；节流避免连续回血时叠播。
func _play_heal_effect() -> void:
	var now_msec := Time.get_ticks_msec()
	if last_heal_effect_msec > 0 and now_msec - last_heal_effect_msec < HEAL_EFFECT_THROTTLE_MSEC:
		return
	last_heal_effect_msec = now_msec
	var effect := HEAL_EFFECT_SCENE.instantiate()
	effect.position = visual_home_position
	add_child(effect)


func configure_sleep_paralysis(still_seconds: float, heal_per_second: float) -> void:
	sleep_paralysis_still_seconds = still_seconds
	sleep_paralysis_heal_per_second = heal_per_second
	_reset_stillness()


func _update_sleep_paralysis(delta: float, effective_motion: Vector2) -> void:
	if sleep_paralysis_still_seconds <= 0.0:
		return
	if effective_motion.length_squared() > 0.0001:
		_reset_stillness()
		return
	still_elapsed += delta
	if still_elapsed < sleep_paralysis_still_seconds:
		return
	heal_tick_accumulator += delta
	while heal_tick_accumulator >= 1.0:
		heal_tick_accumulator -= 1.0
		heal(sleep_paralysis_heal_per_second)


func _reset_stillness() -> void:
	still_elapsed = 0.0
	heal_tick_accumulator = 0.0


func configure_sleep_spindle(interval: float, maximum_layers: int = 1) -> void:
	sleep_spindle_interval = interval
	sleep_spindle_left = interval
	sleep_spindle_max_layers = maxi(1, maximum_layers)


func _update_sleep_spindle(delta: float) -> void:
	if sleep_spindle_interval <= 0.0:
		return
	sleep_spindle_left -= delta
	if sleep_spindle_left <= 0.0:
		sleep_spindle_left = sleep_spindle_interval
		if sleep_spindle_max_layers > 0 and not has_shield:
			has_shield = true
			shield_visual.set_shield_active(true)
			skill_state_changed.emit(has_shield, dissociation_ready)


func configure_consciousness_drift(level: int, config: DemoConfig) -> void:
	var chance := clampf(level * config.consciousness_drift_chance_per_level, 0.0, 1.0)
	auto_weapon.set_extra_attack(chance, config.consciousness_drift_extra_delay)
	beam_weapon.set_extra_attack(chance, config.consciousness_drift_extra_delay)
	shotgun_weapon.set_extra_attack(chance, config.consciousness_drift_extra_delay)
	katana_weapon.set_extra_attack(chance, config.consciousness_drift_extra_delay)
	if grenade_weapon != null:
		grenade_weapon.set_extra_attack(chance, config.consciousness_drift_extra_delay)


func enable_dissociation(config: DemoConfig) -> void:
	dissociation_ready = true
	dissociation_revive_health = config.dissociation_revive_health
	dissociation_invulnerability_seconds = config.dissociation_invulnerability_seconds
	skill_state_changed.emit(has_shield, dissociation_ready)


func _play_feedback() -> void:
	if feedback_audio.stream != null:
		feedback_audio.stop()
		feedback_audio.play()


func set_attacking_enabled(enabled: bool) -> void:
	_set_weapon_activity(enabled and not dead)


func _set_weapon_activity(enabled: bool) -> void:
	auto_weapon.active = enabled and selected_weapon_id == "basic"
	beam_weapon.active = enabled and selected_weapon_id == "beam"
	shotgun_weapon.active = enabled and selected_weapon_id == "shotgun"
	katana_weapon.active = enabled and selected_weapon_id == "katana"
	if grenade_weapon != null:
		grenade_weapon.active = enabled and selected_weapon_id == "grenade"


func get_active_weapon() -> Node:
	match selected_weapon_id:
		"beam": return beam_weapon
		"shotgun": return shotgun_weapon
		"katana": return katana_weapon
		"grenade": return grenade_weapon
		_: return auto_weapon


## 武器挂点固定在 Player 本地坐标，不挂到 AnimatedSprite2D，
## 因此换帧和四方向动画不会让发射点抖动。
func get_weapon_origin() -> Vector2:
	return weapon_origin.global_position


func get_projectile_origin() -> Vector2:
	return projectile_origin.global_position


func get_aim_origin() -> Vector2:
	return aim_origin.global_position


func get_grenade_origin() -> Vector2:
	return grenade_origin.global_position


func get_katana_origin() -> Vector2:
	return katana_origin.global_position


func get_aim_direction() -> Vector2:
	if sleepwalk_mode:
		if not _is_valid_auto_aim_target(auto_aim_target):
			_refresh_auto_aim_target()
		if _is_valid_auto_aim_target(auto_aim_target):
			var auto_direction := get_aim_origin().direction_to(auto_aim_target.global_position)
			if auto_direction.length_squared() > 0.0001:
				last_aim_direction = auto_direction
		return last_aim_direction
	var direction := get_aim_origin().direction_to(get_global_mouse_position())
	if direction.length_squared() > 0.0001:
		last_aim_direction = direction
	return last_aim_direction


func get_auto_aim_target() -> Node2D:
	return auto_aim_target if _is_valid_auto_aim_target(auto_aim_target) else null


func get_constrained_aim_position() -> Vector2:
	var attack_range := maxf(get_effective_attack_range(), 1.0)
	if not sleepwalk_mode:
		return get_global_mouse_position()
	var origin := get_aim_origin()
	var direction := get_aim_direction()
	var target_node := get_auto_aim_target()
	if target_node != null:
		var distance := origin.distance_to(target_node.global_position)
		return target_node.global_position if distance <= attack_range else origin + direction * attack_range
	return origin + direction * attack_range


func _update_auto_aim(delta: float) -> void:
	if not sleepwalk_mode or dead or get_tree().paused:
		return
	auto_aim_refresh_left -= delta
	if auto_aim_refresh_left <= 0.0 or not _is_valid_auto_aim_target(auto_aim_target):
		auto_aim_refresh_left = auto_aim_refresh_interval
		_refresh_auto_aim_target()


func _refresh_auto_aim_target() -> void:
	var previous_target := auto_aim_target
	var nearest: Node2D
	var nearest_distance := INF if auto_aim_search_radius <= 0.0 else auto_aim_search_radius
	for candidate in get_tree().get_nodes_in_group("dream_enemies"):
		if not _is_valid_auto_aim_target(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	auto_aim_target = nearest
	if is_instance_valid(previous_target) and previous_target != auto_aim_target and previous_target.has_method("set_auto_aim_locked"):
		previous_target.set_auto_aim_locked(false)
	if is_instance_valid(auto_aim_target) and auto_aim_target.has_method("set_auto_aim_locked"):
		auto_aim_target.set_auto_aim_locked(true)
	if is_instance_valid(auto_aim_target):
		var direction := global_position.direction_to(auto_aim_target.global_position)
		if direction.length_squared() > 0.0001:
			last_aim_direction = direction


func _is_valid_auto_aim_target(candidate: Variant) -> bool:
	return is_instance_valid(candidate) and candidate.is_inside_tree() and candidate.is_in_group("dream_enemies") and not bool(candidate.get("dead")) and candidate.has_method("take_damage")


func clear_auto_aim_lock() -> void:
	if is_instance_valid(auto_aim_target) and auto_aim_target.has_method("set_auto_aim_locked"):
		auto_aim_target.set_auto_aim_locked(false)
	auto_aim_target = null


func _exit_tree() -> void:
	clear_auto_aim_lock()


func get_weapon_cooldown_progress() -> float:
	return get_active_weapon().get_cooldown_progress()


func apply_damage_upgrade(multiplier: float) -> void:
	acquired_damage_multiplier *= multiplier
	var weapon := get_active_weapon()
	if weapon.has_method("apply_damage_upgrade"):
		weapon.apply_damage_upgrade(multiplier)
	else:
		weapon.damage *= multiplier


func apply_attack_speed_upgrade(multiplier: float) -> void:
	acquired_attack_speed_multiplier *= multiplier
	var weapon := get_active_weapon()
	if weapon.has_method("apply_attack_speed_upgrade"):
		weapon.apply_attack_speed_upgrade(multiplier)
	else:
		weapon.attack_interval /= maxf(multiplier, 0.01)


func apply_range_upgrade(pixels: float) -> void:
	acquired_range_pixels += pixels
	var weapon := get_active_weapon()
	if weapon.has_method("apply_range_upgrade"):
		weapon.apply_range_upgrade(pixels)
	else:
		weapon.attack_range += pixels


func _draw() -> void:
	if shield_break_left > 0.0:
		for angle in range(0, 360, 45):
			draw_line(Vector2.RIGHT.rotated(deg_to_rad(angle)) * 15, Vector2.RIGHT.rotated(deg_to_rad(angle)) * 27, Color("b4d5e6"), 2)
	if revive_flash_left > 0.0:
		draw_circle(Vector2.ZERO, 28 + sin(revive_flash_left * 20.0) * 4, Color("e8c969"), false, 3)
