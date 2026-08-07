extends Node
const SFX := preload("res://scripts/audio/sfx_manager.gd")
signal weapon_fired(recoil_multiplier: float)

const BEAM_EFFECT_SCENE := preload("res://scenes/entities/beam_effect.tscn")

var damage := 20.0
var attack_interval := 2.0
var attack_range := 150.0
var beam_width := 12.0
var display_seconds := 0.15
var active := false
var cooldown_left := 0.25
var recoil_multiplier := 1.5
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08
var charge_seconds := 0.18
var charge_preview_started := false


func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	damage = config.beam_damage
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	attack_interval = config.beam_attack_interval / maxf(attack_speed, 0.01)
	attack_range = config.beam_range + int(permanent_upgrades.get("visual_cortex", 0)) * config.visual_cortex_range_per_level
	beam_width = config.beam_width
	display_seconds = config.beam_display_seconds
	charge_seconds = config.beam_charge_seconds
	recoil_multiplier = config.beam_weapon_recoil_multiplier


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	if cooldown_left > 0.0 and cooldown_left <= charge_seconds and not charge_preview_started:
		charge_preview_started = true
		var world := get_tree().get_first_node_in_group("dream_world")
		if world != null and world.has_method("spawn_weapon_muzzle"):
			world.spawn_weapon_muzzle(get_parent().global_position, get_parent().get_aim_direction(), &"beam_charge")
	if cooldown_left > 0.0:
		return
	cooldown_left = attack_interval
	charge_preview_started = false
	_fire_with_drift(get_parent().get_aim_direction(), true)
	weapon_fired.emit(recoil_multiplier)


func _fire_with_drift(direction: Vector2, allow_extra: bool) -> void:
	_fire_beam(direction)
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			_fire_with_drift(direction, false)


func set_extra_attack(chance: float, delay: float) -> void:
	extra_attack_chance = clampf(chance, 0.0, 1.0)
	extra_attack_delay = maxf(0.0, delay)


func _find_nearest_target() -> Node2D:
	var nearest: Node2D
	var nearest_distance := attack_range
	for candidate in get_tree().get_nodes_in_group("dream_enemies"):
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		var distance: float = get_parent().global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _fire_beam(direction: Vector2) -> void:
	# This function is reached only after cooldown validation (or a real drift shot).
	SFX.play_event(&"laser")
	var origin: Vector2 = get_parent().global_position
	var endpoint := origin + direction.normalized() * attack_range
	# Damage is resolved once at emission, so a visible multi-frame beam cannot multi-hit.
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, origin, endpoint)
		if enemy.global_position.distance_to(closest) <= beam_width * 0.5 + 13.0:
			var hit_world := get_tree().get_first_node_in_group("dream_world")
			if hit_world != null:
				hit_world.resolve_player_hit(enemy, damage, origin)
	var world := get_tree().get_first_node_in_group("dream_world")
	if world != null:
		var effect := BEAM_EFFECT_SCENE.instantiate()
		effect.position = origin
		effect.setup(direction.normalized(), attack_range, beam_width, display_seconds)
		world.add_beam(effect)


func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval,0.001),0.0,1.0)
