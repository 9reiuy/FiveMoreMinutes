extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)
	root.size = Vector2i(1920, 1080)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	if not world.regenerate(42001):
		quit(2)
		return
	var room_id := -1
	var origin := Vector2.ZERO
	for room in world.rooms:
		if String(room.get("archetype", "")) == "open_office":
			room_id = int(room.id)
			origin = Vector2(room.center_cell) * world.CELL_PIXELS
			break
	if room_id < 0:
		quit(3)
		return
	world.player.global_position = origin
	world.activate_room(room_id)
	world.player.movement_enabled = false
	world.player.set_attacking_enabled(false)
	for actor in world.enemy_root.get_children():
		if actor is EmployeeEnemy:
			actor.set_physics_process(false)
	world.night_lighting.set_flashlight_enabled(false)
	# Match the game's displayed palette for every captured stage.
	var layer := CanvasLayer.new()
	layer.layer = 1000
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette_material := ShaderMaterial.new()
	palette_material.shader = preload("res://shaders/palette_quantize.gdshader")
	palette_material.set_shader_parameter("palette_enabled", true)
	overlay.material = palette_material
	layer.add_child(overlay)
	root.add_child(layer)
	for frame in 12:
		await process_frame
	var impact_position := origin + Vector2(80.0, 32.0)
	world.spawn_black_blood(impact_position, Vector2.RIGHT, true, room_id, 1.5)
	await _capture("impact")
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 135:
		await process_frame
	await _capture("landed")
	var pool_setup_start := Time.get_ticks_usec()
	world.spawn_death_blood_pool(impact_position, room_id, 1.0)
	print("POOL_SETUP_USEC=", Time.get_ticks_usec() - pool_setup_start)
	await _capture("pool_initial")
	start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 400:
		await process_frame
	await _capture("pool_mid")
	while Time.get_ticks_msec() - start < 1650:
		await process_frame
	await _capture("pool_final")
	pool_setup_start = Time.get_ticks_usec()
	world.spawn_death_blood_pool(impact_position + Vector2(8, 4), room_id, 1.0)
	print("POOL_SETUP_USEC=", Time.get_ticks_usec() - pool_setup_start)
	await _capture("merge_initial")
	start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 450:
		await process_frame
	await _capture("merge_mid")
	while Time.get_ticks_msec() - start < 1700:
		await process_frame
	await _capture("merge_final")
	var count := 0
	for child in world.world_effects_root.get_children():
		if child is BlackBloodEffect and bool(child.get_meta(&"blood_floor_visual", false)):
			count += 1
	print("BLOOD_REVISION_CAPTURE_FLOOR_AUTHORITIES=", count)
	pool_setup_start = Time.get_ticks_usec()
	world.spawn_death_blood_pool(impact_position + Vector2(-8, -4), room_id, 1.0)
	print("POOL_SETUP_USEC=", Time.get_ticks_usec() - pool_setup_start)
	layer.free()
	world.free()
	quit()

func _capture(label: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png("res://.runtime/blood_revision_" + label + ".png")
