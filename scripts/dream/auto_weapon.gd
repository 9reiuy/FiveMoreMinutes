extends Node
const SFX := preload("res://scripts/audio/sfx_manager.gd")
signal weapon_fired(recoil_multiplier: float)

const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")

@export var firing_sound: AudioStream
@export var damage := 10.0
@export var attack_interval := 0.62
@export var attack_range := 270.0

var active := true
var cooldown_left := 0.25
var recoil_multiplier := 1.0
var projectile_speed := 310.0
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08
var firing_audio: AudioStreamPlayer


func _ready() -> void:
	firing_audio = AudioStreamPlayer.new()
	firing_audio.bus = &"Weapons"
	firing_audio.stream = firing_sound
	add_child(firing_audio)


func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	damage = config.basic_weapon_damage
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	attack_interval = config.basic_weapon_attack_interval / maxf(attack_speed, 0.01)
	attack_range = config.basic_weapon_range + int(permanent_upgrades.get("visual_cortex", 0)) * config.visual_cortex_range_per_level
	projectile_speed = config.basic_projectile_speed
	recoil_multiplier = config.basic_weapon_recoil_multiplier


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	cooldown_left = attack_interval
	_fire(get_parent().get_aim_direction(), true)
	weapon_fired.emit(recoil_multiplier)


func _fire(direction: Vector2, allow_extra: bool) -> void:
	var world := get_tree().get_first_node_in_group("dream_world")
	if world != null:
		# 发射点对齐恢复原尺寸后的躯干挂点（仅视觉出生位置，射程不变）。
		var origin: Vector2 = get_parent().get_projectile_origin()
		var projectile := PROJECTILE_SCENE.instantiate()
		projectile.global_position = origin
		projectile.setup(direction, damage, attack_range, projectile_speed)
		world.add_projectile(projectile)
		if world.has_method("spawn_weapon_muzzle"):
			world.spawn_weapon_muzzle(origin, direction, &"pistol")
		if world.has_method("spawn_bullet_sequence"):
			world.spawn_bullet_sequence(origin, direction)
	if firing_audio != null and firing_audio.stream != null:
		# One reusable player caps high-rate pistol audio at a single concurrent voice.
		firing_audio.stop()
		firing_audio.play()
	else:
		SFX.play_event(&"pistol_fire")
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			_fire(direction, false)


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


func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval,0.001),0.0,1.0)
