extends SceneTree
func _init() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	var display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	seed(41001)
	if not world.regenerate(41001):
		push_error("regen failed")
		quit(1)
		return
	for i in 40:
		await process_frame
	for room_id in range(world.rooms.size()):
		world.activate_room(room_id)
	for i in 90:
		await process_frame
	var by_script: Dictionary = {}
	var processing := 0
	var furn_proc := 0
	var chair_proc := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n.is_processing() or n.is_physics_processing()):
			continue
		processing += 1
		var s = n.get_script()
		var key: String
		if s != null and s is Script:
			key = (s as Script).resource_path.get_file()
			if key.is_empty():
				key = n.get_class()
		else:
			key = n.get_class()
		by_script[key] = int(by_script.get(key, 0)) + 1
		if key == "furniture_3d_visual.gd":
			furn_proc += 1
		elif key == "chair_01.gd":
			chair_proc += 1
	var items: Array = []
	for k in by_script.keys():
		items.append([by_script[k], k])
	items.sort_custom(func(a, b): return a[0] > b[0])
	print("PROCESS_CENSUS total=", processing, " furniture_3d=", furn_proc, " chair_01=", chair_proc)
	for i in mini(20, items.size()):
		print("  ", items[i][0], " ", items[i][1])
	quit(0)
