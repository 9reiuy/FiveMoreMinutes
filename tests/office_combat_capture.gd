extends SceneTree

const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	var palette_layer := CanvasLayer.new()
	palette_layer.layer = 1000
	var palette_rect := ColorRect.new()
	palette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	palette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette_material := ShaderMaterial.new()
	palette_material.shader = preload("res://shaders/palette_quantize.gdshader")
	palette_material.set_shader_parameter("palette_enabled", false)
	palette_rect.material = palette_material
	palette_layer.add_child(palette_rect)
	root.add_child(palette_layer)
	var captured: Dictionary = {}
	for seed in range(1, 30):
		if captured.size() >= 14:
			break
		if not world.regenerate(seed):
			continue
		world.player.invulnerability_left = 10000.0
		for room in world.rooms:
			var kind: String = room.archetype
			if captured.has(kind) or kind == "corridor":
				continue
			world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
			world.activate_room(int(room.id))
			for enemy in world.enemy_root.get_children():
				enemy.set_physics_process(false)
			for frame in range(40):
				await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			image.save_png(ProjectSettings.globalize_path("res://.runtime/combat_%s.png" % kind))
			captured[kind] = true
			print("COMBAT CAPTURE ", kind, " furniture=", world.furniture_root.get_child_count())
			if kind in ["open_office", "conference_large", "pantry", "archive"]:
				var lights := 0
				for light in world.find_children("*", "Light3D", true, false):
					if light.is_visible_in_tree():
						lights += 1
				print("ROOM METRICS ", kind, " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, " visible_lights=", lights)
				palette_material.set_shader_parameter("palette_enabled", true)
				for frame in range(3):
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/combat_%s_palette1.png" % kind))
				palette_material.set_shader_parameter("palette_enabled", false)
	world.queue_free()
	await process_frame
	quit()
