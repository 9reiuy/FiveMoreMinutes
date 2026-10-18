extends SceneTree
const GENERATOR = preload("res://scripts/dream/preview/office_flank_generator.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/dream/preview/OfficeFlankPreview.tscn")
	var world = scene.instantiate()
	world.generate_on_ready = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	root.size = Vector2i(1600, 1000)
	world.get_node("PreviewControls").hide()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/flank_preview"))
	var reports: Array = []
	for value in GENERATOR.SEEDS:
		var success: bool = world.regenerate(value)
		for frame in 15:
			await process_frame
		for label in root.find_children("*", "Label", true, false):
			label.hide()
		for layer in root.find_children("*", "CanvasLayer", true, false):
			if layer != world.gameplay_canvas:
				layer.hide()
		var plans: Array = []
		for room in world.rooms:
			var plan: Dictionary = world._plan_otxo_room_layout(int(room.id))
			plans.append({"id": room.id, "role": room.archetype, "success": plan.get("success", false), "furniture": plan.get("furniture_placements", []).size(), "reason": plan.get("failure_reason", "")})
		reports.append({"seed": value, "generated": success, "validation": world._validate_layout(), "bounds": str(world.building_rect), "enemies": world.enemy_root.get_child_count(), "rooms": plans})
		print("FLANK RUNTIME ", JSON.stringify(reports.back()))
		# Keep camera authority and its dependents synchronized for the overview.
		world.set_process(false)
		var camera: Camera3D = world.camera_3d
		var rectangle: Rect2i = world.building_rect
		var center: Vector3 = world.to_global(Vector3(rectangle.get_center().x, 0, rectangle.get_center().y))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(rectangle.size.x + rectangle.size.y) * 0.85
		camera.global_position = center + Vector3(0, 80, 42)
		camera.look_at(center)
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://.runtime/flank_preview/map_%d.png" % value)
		print("FLANK PNG ", path, " result=", root.get_texture().get_image().save_png(path))
		world.set_process(true)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = world.authoritative_camera_fov
	var file := FileAccess.open("res://.runtime/flank_preview/runtime_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports, "\t"))
	world.queue_free()
	for frame in 5:
		await process_frame
	quit()
