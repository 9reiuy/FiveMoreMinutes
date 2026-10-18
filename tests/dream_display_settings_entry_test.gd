extends SceneTree
var checks := 0
var failures := 0
var settings: Node

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	settings = root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	root.size = Vector2i(1280, 720)
	for entry in ["res://scenes/dream/Dream3D_RandomDungeon.tscn", "res://scenes/dream/Dream3D_TutorialRoom.tscn", "res://scenes/dream/Dream3D_ReceptionRoom.tscn", "res://scenes/dream/preview/PixelShadowPreview.tscn", "res://scenes/dream/preview/SelectivePixelPreview.tscn"]:
		var node: Node = load(entry).instantiate()
		if entry.ends_with("Dream3D_RandomDungeon.tscn"):
			node.generate_on_ready = false
			node.persist_profile = false
		root.add_child(node)
		for frame in 5:
			await process_frame
		var displays := get_nodes_in_group(&"dream_display")
		check(displays.size() == 1, "Missing / duplicated display: " + entry)
		if displays.size() != 1:
			quit(1)
			return
		var display: Node = displays[0]
		check(display.world.get_viewport() == display.world_viewport, "Camera world not in display viewport")
		check(display.world.get("camera_3d").get_viewport() == display.world_viewport, "Wrong camera viewport")
		if entry.contains("PixelShadowPreview"):
			check(display.world.furniture_root.get_child_count() > 0, "Furniture missing after presentation move")
			var visuals := 0
			for item in display.world.find_children("*", "Node3D", true, false):
				if item.get_script() != null and item.get_script().resource_path == "res://scripts/dream/furniture_3d_visual.gd" and not item.is_queued_for_deletion():
					visuals += 1
			check(visuals > 0, "Furniture visuals destroyed by display migration")
		for pixels in [false, true]:
			for palette in [false, true]:
				settings.values["pixelation_enabled"] = pixels
				settings.values["palette_enabled"] = palette
				settings.setting_changed.emit(&"pixelation_enabled", pixels)
				settings.setting_changed.emit(&"palette_enabled", palette)
				await process_frame
				check(display.selective_enabled == pixels, "Pixel settings unsynchronized")
				check(display.palette_material.get_shader_parameter("palette_enabled") == palette, "Palette settings unsynchronized")
				check(display.world_viewport.size == Vector2i(640,360) if pixels else display.world_viewport.size.x > 640, "Wrong render resolution")
				check(display.palette_material.get_shader_parameter("palette_enabled") == palette, "Palette must work without pixelation")
		node.queue_free()
		for frame in 4:
			await process_frame
		check(get_nodes_in_group(&"dream_display").is_empty(), "Display leaked after world teardown")
	settings.values = saved
	print("DREAM_DISPLAY_ENTRY_RESULTS checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
