extends SceneTree

const WORLD = preload("res://scenes/dream/Dream3D_OfficeSample.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var key := OS.get_environment("OFFICE_METRIC_ROOM")
	if key not in ["server", "archive"]:
		push_error("Set OFFICE_METRIC_ROOM to server or archive")
		quit(1)
		return
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	if not world.regenerate(120):
		quit(1)
		return
	var selected: Dictionary = {}
	for room in world.rooms:
		if String(room.get("sample_key", "")) == key:
			selected = room
			break
	if selected.is_empty():
		quit(1)
		return
	world.player.global_position = Vector2(selected.center_cell) * world.CELL_PIXELS
	world.activate_room(int(selected.id))
	var samples: Array[float] = []
	for frame in 240:
		await process_frame
		if frame >= 120:
			samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	var local_lights := 0
	var all_visible_lights := 0
	for light in world.find_children("*", "Light3D", true, false):
		if light.is_visible_in_tree():
			all_visible_lights += 1
			if int(light.get_parent().get_meta(&"dream_room_id", -1)) == int(selected.id):
				local_lights += 1
	print("SAMPLE METRICS room=", key, " seed=120 process_ms_avg=", snappedf(total / samples.size(), .001), " p95=", snappedf(samples[114], .001), " local_lights=", local_lights, " all_visible_lights=", all_visible_lights)
	world.queue_free()
	await process_frame
	quit()
