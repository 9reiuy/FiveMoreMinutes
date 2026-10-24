extends Node

const MAIN_SCENE := preload("res://scenes/app/main.tscn")
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9/"

func _ready() -> void:
	call_deferred("_run")

func _save_shot(filename: String) -> void:
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ARTIFACT_DIR + filename)

func _run() -> void:
	preload("res://tests/support/background_gpu.gd").start(get_tree())
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)

	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	
	for i in range(10):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	seed(54321)
	main.debug_console._execute_command("gotodream")
	
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		if is_instance_valid(main._supported_dream_world) and not main.transition_running:
			break
			
	var world: Node3D = main._supported_dream_world as Node3D
	while is_instance_valid(world) and bool(world.get("floor_transition_in_progress")):
		await get_tree().process_frame
		RenderingServer.force_draw(false)

	world.regenerate(54321)

	# Enable PerformanceMonitor MINI mode and clear startup generation spikes so live gameplay metrics are clean
	var pm: Node = get_node_or_null("/root/PerformanceMonitor")
	if pm != null:
		pm.set("current_mode", 1)
		if pm.get("spike_history") is Array:
			pm.get("spike_history").clear()
		pm.set("_total_spike_count", 0)
		pm.set("_worst_spike_ms", 0.0)
		pm.call("_refresh_hud_text")

	# Wait ~70 frames (~1.1s) for Godot's 1-second FPS counter to settle at 60 FPS
	for i in range(70):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	if pm != null:
		pm.call("_refresh_hud_text")
	await get_tree().process_frame
	await _save_shot("capture_perf_after_spawn_60fps.png")

	var gif_idx := 0
	for f in range(4):
		await get_tree().process_frame
		await _save_shot("gif_opt_%02d.png" % gif_idx)
		gif_idx += 1

	# Move player into interior office room
	for room in world.rooms:
		if int(room.id) != int(world.elevator_room_id) and int(room.id) != int(world.spawn_room_id):
			world.player.global_position = Vector2(room.center_cell) * 32.0
			world.activate_room(int(room.id))
			break

	for i in range(20):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	if pm != null:
		pm.call("_refresh_hud_text")
	await _save_shot("capture_perf_after_office_room.png")

	# Perform dash & combat sequence while recording GIF frames
	var player: Node2D = world.player
	if player != null and player.has_method("_start_dash"):
		player.call("_start_dash", Vector2(1.0, 0.35).normalized())
	for f in range(8):
		for sub in range(2):
			await get_tree().process_frame
			RenderingServer.force_draw(false)
		if pm != null:
			pm.call("_refresh_hud_text")
		await _save_shot("gif_opt_%02d.png" % gif_idx)
		gif_idx += 1

	# Switch PerformanceMonitor to DETAILED mode (mode 2) for detailed verification shot
	if pm != null:
		pm.set("current_mode", 2)
		pm.call("_refresh_hud_text")
	if player != null and player.has_method("_start_dash"):
		player.call("_start_dash", Vector2(-0.8, 0.5).normalized())
	for f in range(6):
		for sub in range(2):
			await get_tree().process_frame
			RenderingServer.force_draw(false)
		if pm != null:
			pm.call("_refresh_hud_text")
		await _save_shot("gif_opt_%02d.png" % gif_idx)
		if f == 2:
			await _save_shot("capture_perf_after_office_combat.png")
		gif_idx += 1

	get_tree().quit(0)
