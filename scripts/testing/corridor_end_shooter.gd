extends "res://scripts/entities/employee_enemy.gd"

## CorridorEndShooter
## Dedicated armed tactical shooter stationed behind Cover_Shooter_Barricade in Zone 3.
## Never leaves cover to enter the corridor; maintains rhythm of aim-telegraphing,
## 3-round burst corridor denial, and reload cooldown, forcing the player to use
## the 3 beveled alcoves for cover or flank via the 5m side avenues.

signal burst_fired()

const AIM_TELEGRAPH_DURATION := 1.25
const BURST_SHOT_COUNT := 3
const BURST_SHOT_INTERVAL := 0.12
const RELOAD_COOLDOWN := 2.2

var laser_beam_3d: CSGBox3D = null
var barricade_locked_y := 150.0

var _combat_clock := 0.0
var _is_aiming := false
var _is_bursting := false
var _bursts_remaining := 0
var _burst_interval_timer := 0.0
var _aim_direction := Vector2.DOWN

func _ready() -> void:
	super._ready()
	# Ensure the end shooter is configured with an assault rifle or basic handgun
	if held_weapon_id.is_empty():
		equip_weapon("basic")
	hostile = true
	_combat_clock = 0.5 # Initial small delay before first aim cycle

func set_laser_beam_node(beam: CSGBox3D) -> void:
	laser_beam_3d = beam
	if laser_beam_3d != null:
		laser_beam_3d.visible = false

func _physics_process_profiled(delta: float) -> void:
	if dead or state in [State.KNOCKED_DOWN, State.GETTING_UP]:
		_hide_laser()
		super._physics_process_profiled(delta)
		return

	# Strictly lock shooter behind barricade (never step south into corridor)
	if global_position.y > barricade_locked_y + 12.0:
		global_position.y = barricade_locked_y + 12.0
		velocity.y = minf(velocity.y, 0.0)

	var world: Node = _get_world()
	if not is_instance_valid(target) or target.get("dead") == true:
		_hide_laser()
		return

	var target_pos: Vector2 = target.global_position
	var is_player_in_corridor: bool = target_pos.y > 280.0

	if is_player_in_corridor:
		# Tactical Corridor Suppression Routine
		_update_corridor_suppression(delta, world, target_pos)
	else:
		# Close Quarters / Flanking Defense Routine
		_update_arena_flank_defense(delta, world, target_pos)

func _update_corridor_suppression(delta: float, world: Node, target_pos: Vector2) -> void:
	# Face south down the corridor
	last_facing_direction = Vector2.DOWN
	if character_visual != null:
		_apply_live_facing(Vector2.DOWN)

	# Aim directly down the central corridor line
	_aim_direction = Vector2(clampf((target_pos.x - global_position.x) * 0.05, -0.05, 0.05), 1.0).normalized()

	if _is_bursting:
		_burst_interval_timer -= delta
		if _burst_interval_timer <= 0.0:
			_burst_interval_timer = BURST_SHOT_INTERVAL
			_fire_suppression_bullet(world, _aim_direction)
			_bursts_remaining -= 1
			if _bursts_remaining <= 0:
				_is_bursting = false
				_hide_laser()
				_combat_clock = RELOAD_COOLDOWN
		return

	_combat_clock -= delta

	if _combat_clock <= AIM_TELEGRAPH_DURATION and _combat_clock > 0.0:
		# Aim telegraph active
		_is_aiming = true
		_show_laser(_aim_direction)
	elif _combat_clock <= 0.0:
		# Commit burst firing
		_is_aiming = false
		_is_bursting = true
		_bursts_remaining = BURST_SHOT_COUNT
		_burst_interval_timer = 0.0

func _update_arena_flank_defense(delta: float, world: Node, target_pos: Vector2) -> void:
	_hide_laser()
	var dir_to_player := (target_pos - global_position).normalized()
	last_facing_direction = dir_to_player
	if character_visual != null:
		_apply_live_facing(dir_to_player)

	# Steer slightly to maintain line of sight behind barricade
	var flank_offset := target_pos.x - 192.0
	var ideal_x := 192.0 + clampf(flank_offset * 0.35, -32.0, 32.0)
	global_position.x = move_toward(global_position.x, ideal_x, 60.0 * delta)

	_combat_clock -= delta
	if _combat_clock <= 0.0:
		_combat_clock = 0.8 # Faster close-range firing
		_fire_suppression_bullet(world, dir_to_player)

func _fire_suppression_bullet(world: Node, direction: Vector2) -> void:
	if world == null or not world.has_method("add_projectile"):
		return

	var proj_scene: PackedScene = preload("res://scenes/entities/basic_projectile.tscn")
	var proj := proj_scene.instantiate() as Node2D
	if proj == null:
		return

	var spawn_pos: Vector2 = global_position + direction * 16.0
	proj.global_position = spawn_pos

	var firearm_rules = preload("res://scripts/dream/dream_firearm_rules.gd")
	firearm_rules.setup_projectile(
		proj,
		direction,
		15.0,     # damage
		1000.0,   # distance (travels full 30m corridor length)
		480.0,    # speed
		&"enemy",
		self,
		&"basic"
	)

	world.call("add_projectile", proj, self)
	if world.has_method("spawn_weapon_muzzle"):
		world.call("spawn_weapon_muzzle", spawn_pos, direction, &"basic", self)

	SFX.play_weapon_fire()
	burst_fired.emit()

func _show_laser(direction: Vector2) -> void:
	if laser_beam_3d == null:
		return
	laser_beam_3d.visible = true
	# Beam position in 3D: starts from shooter barricade (Z: 6.0) and stretches down the corridor
	var start_z := 6.0
	var length := 24.0 # reaches Z: 30.0 (Zone 1 entrance)
	laser_beam_3d.transform.origin = Vector3(
		(global_position.x + direction.x * 200.0) / 32.0,
		0.85,
		start_z + length * 0.5
	)
	laser_beam_3d.size = Vector3(0.08, 0.08, length)

func _hide_laser() -> void:
	if laser_beam_3d != null:
		laser_beam_3d.visible = false

func take_damage(damage: float, hit_position: Vector2 = Vector2.INF, force: float = 1.0, damage_source: StringName = &"player_projectile") -> void:
	_hide_laser()
	_is_aiming = false
	_is_bursting = false
	_combat_clock = 1.0 # Stagger delay when hit
	super.take_damage(damage, hit_position, force, damage_source)

func start_knockdown(direction: Vector2, source: StringName = &"impact", force_override: float = -1.0, launch_velocity_override: float = -1.0) -> void:
	_hide_laser()
	_is_aiming = false
	_is_bursting = false
	super.start_knockdown(direction, source, force_override, launch_velocity_override)

func _exit_tree() -> void:
	_hide_laser()
