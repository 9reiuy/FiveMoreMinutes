extends SceneTree

const GENERATOR = preload("res://scripts/dream/office_level_pack_generator.gd")
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var selected: Dictionary = {}
	for seed in range(1, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var layout: Dictionary = GENERATOR.generate(rng)
		if not layout.is_empty() and not selected.has(layout.floor_shape):
			selected[layout.floor_shape] = seed
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	for shape in GENERATOR.SHAPES:
		if not selected.has(shape) or not world.regenerate(int(selected[shape])):
			push_error("Cannot capture %s" % shape)
			continue
		for _frame in range(6):
			await process_frame
		var shot: Image = root.get_texture().get_image()
		if shot == null or shot.is_empty():
			push_error("Empty capture %s" % shape)
			continue
		var target := "res://.runtime/office_pack_%s.png" % String(shape)
		var error := shot.save_png(ProjectSettings.globalize_path(target))
		print("OFFICE CAPTURE ", shape, " result=", error, " size=", shot.get_size())
		var overview := Camera3D.new()
		overview.fov = 55.0
		overview.position = Vector3(0.0, 32.0, 18.0)
		root.add_child(overview)
		overview.look_at(Vector3.ZERO)
		overview.current = true
		for _frame in range(5):
			await process_frame
		var overview_image: Image = root.get_texture().get_image()
		var overview_target := "res://.runtime/office_pack_%s_overview.png" % String(shape)
		print("OFFICE OVERVIEW CAPTURE ", shape, " result=", overview_image.save_png(ProjectSettings.globalize_path(overview_target)))
		overview.queue_free()
		world.camera_3d.current = true
		for room in world.rooms:
			if room.archetype == "open_office":
				world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
				world.activate_room(int(room.id))
				break
		for _frame in range(12):
			await process_frame
		var room_image: Image = root.get_texture().get_image()
		var room_target := "res://.runtime/office_pack_%s_room.png" % String(shape)
		print("OFFICE ROOM CAPTURE ", shape, " result=", room_image.save_png(ProjectSettings.globalize_path(room_target)))
	world.queue_free()
	await process_frame
	quit()
