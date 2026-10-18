extends SceneTree

## Deterministic review in the formal 3D world and its live Camera3D. Only the
## test harness controls tick size; bullets retain their real swept collision.
const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const OUTPUT := "res://.runtime/firearm_revision_visual"
var world: Node3D
var player: Node2D

func _init() -> void:
	call_deferred("_run")

func _capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT.path_join(file_name)))

func _bullets() -> Array[Node]:
	var shots: Array[Node] = []
	for child in world.world_effects_root.get_children():
		if child.get_script() == preload("res://scripts/entities/basic_projectile.gd") and not child.is_queued_for_deletion():
			shots.append(child)
	return shots

func _step_shots(delta: float) -> void:
	for bullet in _bullets():
		bullet.set_physics_process(false)
		bullet.call("_physics_process", delta)

func _clear_shots() -> void:
	for bullet in world.world_effects_root.get_children():
		if bullet.get_script() == preload("res://scripts/entities/basic_projectile.gd"):
			bullet.queue_free()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Firearm revision visual review requires a rendered display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	if not world.regenerate(41001):
		quit(1)
		return
	player = world.player
	player.invulnerability_left = 10000.0
	for room in world.rooms:
		if String(room.archetype) == "corridor":
			player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
			player.set_meta(&"dream_room_id", int(room.id))
			world.set_current_room_id(int(room.id))
			world.activate_room(int(room.id))
			break
	player.set_physics_process(false)
	for weapon in [player.auto_weapon, player.assault_rifle_weapon, player.shotgun_weapon]:
		weapon.set_process(false)
	for enemy in get_nodes_in_group(&"dream_enemies"):
		enemy.set_process(false)
		enemy.set_physics_process(false)
	for frame in 30:
		await process_frame
	await _capture("01_corridor.png")
	for entry in [["basic", Vector2.RIGHT], ["shotgun", Vector2.RIGHT], ["assault_rifle", Vector2.RIGHT]]:
		_clear_shots()
		await process_frame
		player.equip_weapon(entry[0], world.config, {})
		player.set_meta(&"aim_direction_override", entry[1])
		player.call("_update_held_weapon_aim")
		if entry[0] == "shotgun":
			player.shotgun_weapon._fire_full_volley(entry[1], false)
		elif entry[0] == "assault_rifle":
			player.assault_rifle_weapon._fire(entry[1], false)
		else:
			player.auto_weapon._fire(entry[1], false)
		_step_shots(.02)
		_step_shots(.02)
		_step_shots(.02)
		await _capture("02_%s_history.png" % entry[0])
		# The same 0.06 game-second history remains visible with smaller slow-time
		# steps; no extra collision or different speed authority is introduced.
		for frame in 12:
			_step_shots(1.0 / 300.0)
		await _capture("03_%s_slow_steps.png" % entry[0])
	_clear_shots()
	await process_frame
	player.equip_weapon("assault_rifle", world.config, {})
	player.set_meta(&"aim_direction_override", Vector2(1, 1).normalized())
	player.call("_update_held_weapon_aim")
	player.assault_rifle_weapon._fire(Vector2(1, 1).normalized(), false)
	_step_shots(.02)
	_step_shots(.02)
	await _capture("04_diagonal.png")
	_clear_shots()
	await process_frame
	player.equip_weapon("basic", world.config, {})
	player.set_meta(&"aim_direction_override", Vector2.UP)
	player.call("_update_held_weapon_aim")
	player.auto_weapon._fire(Vector2.UP, false)
	_step_shots(.02)
	_step_shots(.02)
	await _capture("05_wall_contact.png")
	_step_shots(.02)
	await _capture("06_terminal_fade.png")
	_step_shots(.025)
	await _capture("07_terminal_expired.png")
	print("Firearm revision Camera3D capture complete: ", ProjectSettings.globalize_path(OUTPUT))
	world.queue_free()
	await process_frame
	quit(0)
