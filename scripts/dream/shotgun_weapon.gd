extends Node
const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal weapon_fired(recoil_multiplier: float)

const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")

@export var firing_sound: AudioStream

var damage := 3.0
var attack_interval := 0.8
var attack_range := 270.0
var pellet_count := 9
var spread_degrees := 30.0
var projectile_speed := 310.0
var active := false
var cooldown_left := 0.25
var recoil_multiplier := 1.8
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08
var firing_audio: AudioStreamPlayer


func _ready() -> void:
	firing_audio = AudioStreamPlayer.new()
	firing_audio.bus = &"Weapons"
	firing_audio.stream = firing_sound
	add_child(firing_audio)


func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	damage = config.shotgun_pellet_damage
	pellet_count = maxi(1, config.shotgun_pellet_count)
	spread_degrees = maxf(0.0, config.shotgun_spread_degrees)
	projectile_speed = maxf(1.0, config.shotgun_projectile_speed)
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	attack_interval = config.shotgun_attack_interval / maxf(attack_speed, 0.01)
	attack_range = config.shotgun_max_distance + int(permanent_upgrades.get("visual_cortex", 0)) * config.visual_cortex_range_per_level
	recoil_multiplier = config.shotgun_recoil_multiplier


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	cooldown_left = attack_interval
	_fire_full_volley(get_parent().get_aim_direction(), true)
	weapon_fired.emit(recoil_multiplier)


func _fire_full_volley(direction: Vector2, allow_extra: bool) -> void:
	var world := get_tree().get_first_node_in_group("dream_world")
	if world != null:
		var center := direction.normalized()
		var sector_width := spread_degrees / float(pellet_count)
		var half_spread := spread_degrees * 0.5
		for pellet_index in range(pellet_count):
			# One randomized trajectory per sector preserves a readable spread and prevents stacking.
			var minimum_angle := -half_spread + sector_width * pellet_index
			var maximum_angle := minimum_angle + sector_width
			var pellet_direction := center.rotated(deg_to_rad(randf_range(minimum_angle, maximum_angle)))
			var projectile := PROJECTILE_SCENE.instantiate()
			projectile.global_position = get_parent().global_position
			projectile.setup(pellet_direction, damage, attack_range, projectile_speed)
			world.add_projectile(projectile)
		if world.has_method("spawn_weapon_muzzle"):
			world.spawn_weapon_muzzle(get_parent().global_position, direction, &"shotgun")
	if firing_audio != null and firing_audio.stream != null:
		firing_audio.stop()
		firing_audio.play()
	else:
		SFX.play_event(&"shotgun_fire")
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			_fire_full_volley(direction, false)


func set_extra_attack(chance: float, delay: float) -> void:
	extra_attack_chance = clampf(chance, 0.0, 1.0)
	extra_attack_delay = maxf(0.0, delay)


func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval, 0.001), 0.0, 1.0)


func apply_damage_upgrade(multiplier: float) -> void:
	damage *= multiplier


func apply_attack_speed_upgrade(multiplier: float) -> void:
	attack_interval /= maxf(multiplier, 0.01)


func apply_range_upgrade(pixels: float) -> void:
	attack_range += pixels
