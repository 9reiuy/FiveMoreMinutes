extends Node

const MAIN_SCENE := preload("res://scenes/app/main.tscn")
const OUTPUT_DIR := "res://.runtime/ballistics_review"


func _ready() -> void:
	call_deferred("_run")


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name)))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Firearm capture requires a rendered display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state["tutorial_completed"] = true
	seed(120)
	main._show_dream("basic")
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if is_instance_valid(main._supported_dream_world) and main._supported_dream_world.scene_file_path == "res://scenes/dream/Dream3D_RandomDungeon.tscn" and not main.transition_running:
			break
	var world: Node = main._supported_dream_world
	if not is_instance_valid(world) or world.scene_file_path != "res://scenes/dream/Dream3D_RandomDungeon.tscn":
		print("Firearm capture: normal entry failed")
		main.queue_free()
		get_tree().quit(1)
		return
	main._apply_palette_enabled(false)
	world.persist_profile = false
	# Wait for the real floor's initial elevator exit before moving the camera.
	while world.floor_transition_in_progress:
		await get_tree().process_frame
	var player: Node2D = world.player
	for room_variant in world.rooms:
		var room: Dictionary = room_variant
		if String(room.get("archetype", "")) == "open_office":
			var office_id := int(room.get("id", -1))
			player.global_position = Vector2(room.get("center_cell", Vector2i.ZERO)) * world.CELL_PIXELS
			player.set_meta(&"dream_room_id", office_id)
			world.set_current_room_id(office_id)
			world.activate_room(office_id)
			break
	player.set_physics_process(false)
	player.auto_weapon.set_process(false)
	for enemy in get_tree().get_nodes_in_group(&"dream_enemies"):
		enemy.set_process(false)
		enemy.set_physics_process(false)
	player.set_meta(&"aim_direction_override", Vector2.RIGHT)
	player.call("_update_held_weapon_aim")
	for frame in 60:
		await get_tree().process_frame
	await _capture("01_before.png")
	player.auto_weapon._fire(Vector2.RIGHT, false)
	await _capture("02_first_frame.png")
	await get_tree().process_frame
	await _capture("03_flame.png")
	for frame in 8:
		await get_tree().process_frame
	await _capture("04_tracer.png")
	player.equip_weapon("shotgun", world.config, {})
	player.call("_update_held_weapon_aim")
	player.shotgun_weapon._fire_full_volley(Vector2.RIGHT, false)
	await _capture("05_shotgun.png")
	for frame in 18:
		await get_tree().process_frame
	player.equip_weapon("assault_rifle", world.config, {})
	player.call("_update_held_weapon_aim")
	player.assault_rifle_weapon._fire(Vector2.RIGHT, false)
	await _capture("06_rifle.png")
	for frame in 18:
		await get_tree().process_frame
	main._apply_palette_enabled(true)
	player.equip_weapon("basic", world.config, {})
	player.call("_update_held_weapon_aim")
	player.auto_weapon._fire(Vector2.RIGHT, false)
	await _capture("07_palette1_pistol.png")
	print("Muzzle light pool size: ", world.night_lighting.muzzle_lights.size())
	print("Firearm capture complete: ", ProjectSettings.globalize_path(OUTPUT_DIR))
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
