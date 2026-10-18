extends SceneTree
## Formal display evidence. Run graphically with captures, clip, or benchmark.
const MAIN_PATH := "res://scenes/app/main.tscn"
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PACK = preload("res://scripts/dream/office_level_pack_generator.gd")
const OUT := "res://.runtime/random_office"
var main: Node
var world: Node3D
var display: Node
var manifest: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for _frame in count:
		await process_frame

func _shape_seeds() -> Dictionary:
	var result := {}
	for fixed_seed in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = fixed_seed
		var roll := rng.randi_range(0, 99)
		var sum := 0
		for index in PACK.SHAPES.size():
			sum += PACK.WEIGHTS[index]
			if roll < sum:
				if not result.has(PACK.SHAPES[index]):
					result[PACK.SHAPES[index]] = fixed_seed
				break
		if result.size() == 5:
			break
	return result

func _build(fixed_seed: int) -> bool:
	world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	main._set_screen(world)
	display = main.current_screen
	await _frames(4)
	if not world.regenerate(fixed_seed):
		return false
	world.night_lighting.set_flashlight_enabled(false)
	world.player.invulnerability_left = 10000.0
	await _frames(24)
	return true

func _freeze_actors() -> void:
	for actor in world.enemy_root.get_children():
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		if actor.get("auto_weapon") != null:
			actor.auto_weapon.active = false

func _position_camera(room: Dictionary) -> void:
	var best: Vector2i = room.center_cell
	var best_distance := INF
	for cell in room.get("usable_cells", []):
		var point: Vector2 = Vector2(cell) * world.CELL_PIXELS
		var blocked := false
		for collision in world.furniture_root.find_children("*", "CollisionShape2D", true, false):
			if collision.shape != null and not collision.disabled and collision.shape.get_rect().grow(14.0).has_point(collision.to_local(point)):
				blocked = true
				break
		var distance := Vector2(cell).distance_squared_to(Vector2(room.center_cell))
		if not blocked and distance < best_distance:
			best = cell
			best_distance = distance
	world.player.global_position = world.get_player_root_position_for_cell(best)
	world.activate_room(int(room.id))
	world.camera_aim_offset = Vector3.ZERO
	world.camera_impulse_offset = Vector3.ZERO
	world.camera_shake_amplitude = 0.0
	world.call("_update_camera_and_actor_projection", 0.0)

func _capture(label: String, room: Dictionary) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var filename := OUT + "/" + label + ".png"
	root.get_texture().get_image().save_png(filename)
	manifest.append({"file": filename, "seed": world.active_seed,
		"shape": String(world.floor_shape), "room": room.get("archetype", ""),
		"room_id": room.id, "pixelation": display.selective_enabled,
		"palette": display.palette_enabled, "stats": display.get_stats()})

func _captures(seeds: Dictionary) -> void:
	var seen := {}
	var requests: Array[Dictionary] = []
	var append_only := OS.get_cmdline_user_args().has("append")
	if append_only and FileAccess.file_exists(OUT + "/capture_manifest.json"):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT + "/capture_manifest.json"))
		if previous is Array:
			for entry in previous:
				manifest.append(entry)
				var room_type := String(entry.get("room", ""))
				var seen_key := String(entry.get("shape", "")) + "_corridor" if room_type == "corridor" else room_type
				seen[seen_key] = true
	else:
		for shape in PACK.SHAPES:
			requests.append({"shape": shape, "seed": int(seeds[shape])})
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("extra_seed="):
			requests.append({"shape": "extra", "seed": argument.trim_prefix("extra_seed=").to_int()})
	for request in requests:
		if not await _build(int(request.seed)):
			var shape := String(request.shape)
			push_error("Capture generation failed: " + String(shape))
			continue
		var shape := String(world.floor_shape)
		_freeze_actors()
		world.set_process(false)
		for room in world.rooms:
			var archetype := String(room.get("archetype", "unknown"))
			# One full matrix per distinct function, plus one corridor per shape.
			var key := String(shape) + "_corridor" if archetype == "corridor" else archetype
			if seen.has(key):
				continue
			seen[key] = true
			world.set_process(true)
			world.player.set_physics_process(true)
			_position_camera(room)
			_freeze_actors()
			# Allow source character visual anchors and clipping receivers to settle
			# after teleporting, before freezing the gameplay view for comparison.
			await _frames(12)
			world.player.set_physics_process(false)
			# Test invulnerability must not freeze a spawn-flash invisible frame.
			world.player.visual.visible = true
			world.player.visual.modulate = Color.WHITE
			world.set_process(false)
			_position_camera(room)
			for pixel in [false, true]:
				display.set_selective_enabled(pixel)
				for palette in [false, true]:
					main._apply_palette_enabled(palette)
					await _capture("%s_%s_%s_%s" % [shape, archetype, "pixel" if pixel else "native", "palette1" if palette else "off"], room)
		print("RANDOM_CAPTURE shape=", shape, " seed=", request.seed, " files=", manifest.size())
		main._set_screen(Node.new())
		await _frames(8)
	_save_json("capture_manifest.json", manifest)

func _route(seconds: float, shoot := false) -> void:
	for action in [&"move_right", &"move_down", &"move_left", &"move_up", &"attack"]:
		Input.action_release(action)
	var moves: Array[StringName] = [&"move_right", &"move_down", &"move_left", &"move_up"]
	Input.action_press(moves[int(seconds / 0.6) % 4])
	var angle := floorf(seconds / 0.75) * TAU / 8.0
	var event := InputEventMouseMotion.new()
	var pointer: Vector2 = display.world_to_hud(Vector2(display.world_viewport.size) * 0.5 + Vector2.RIGHT.rotated(angle) * float(display.world_viewport.size.y) * 0.3)
	event.position = root.get_final_transform() * pointer
	Input.parse_input_event(event)
	if shoot:
		Input.action_press("attack")

func _release_input() -> void:
	for action in [&"move_right", &"move_down", &"move_left", &"move_up", &"attack"]:
		Input.action_release(action)

func _office_room() -> Dictionary:
	for room in world.rooms:
		if String(room.get("archetype", "")) == "open_office":
			return room
	return world.rooms[0]

func _clip(fixed_seed: int) -> void:
	if not await _build(fixed_seed):
		return
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	display.set_selective_enabled(true)
	main._apply_palette_enabled(false)
	_position_camera(_office_room())
	world.player.equip_weapon("basic", world.config, {})
	var clip_dir := OUT + "/clip"
	DirAccess.make_dir_recursive_absolute(clip_dir)
	var start := Time.get_ticks_msec()
	for index in 120:
		var seconds := float(index) / 15.0
		_route(seconds, index >= 15)
		while Time.get_ticks_msec() - start < index * 1000 / 15:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(clip_dir + "/frame_%03d.png" % index)
	_release_input()
	print("RANDOM_CAPTURE_CLIP frames=120 fps=15 silent=true")

func _benchmark(fixed_seed: int) -> void:
	var results: Array[Dictionary] = []
	for pixel in [false, true]:
		if not await _build(fixed_seed):
			return
		display.set_selective_enabled(pixel)
		main._apply_palette_enabled(false)
		_position_camera(_office_room())
		# Real AI stays active for this measurement. No screenshots in timed run.
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < 10000000:
			_route(float(Time.get_ticks_usec() - start) / 1000000.0)
			await process_frame
		var samples: Array[float] = []
		var draws: Array[float] = []
		start = Time.get_ticks_usec()
		var previous := start
		while Time.get_ticks_usec() - start < 60000000:
			_route(float(Time.get_ticks_usec() - start) / 1000000.0)
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			previous = now
		_release_input()
		samples.sort()
		var sum := 0.0
		for draw in draws:
			sum += draw
		results.append({"seed": fixed_seed, "pixelation": pixel, "palette": false,
			"warmup_seconds": 10, "sample_seconds": 60, "samples": samples.size(),
			"median_ms": samples[samples.size() / 2], "p95_ms": samples[int(samples.size() * 0.95)],
			"mean_draw_calls": sum / draws.size(), "stats": display.get_stats(),
			"route": "0.6 second screen-relative square, live AI, no player shooting"})
		print("RANDOM_BENCHMARK ", results.back())
		main._set_screen(Node.new())
		await _frames(8)
	_save_json("performance.json", results)

func _save_json(filename: String, data: Variant) -> void:
	var file := FileAccess.open(OUT + "/" + filename, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Random office evidence requires graphical rendering")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load(MAIN_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await _frames(4)
	var seeds := _shape_seeds()
	_save_json("shape_seeds.json", seeds)
	var args := OS.get_cmdline_user_args()
	if args.has("benchmark"):
		await _benchmark(int(seeds[&"rectangle"]))
	elif args.has("clip"):
		await _clip(int(seeds[&"rectangle"]))
	else:
		await _captures(seeds)
	main.queue_free()
	await _frames(8)
	quit(0)
