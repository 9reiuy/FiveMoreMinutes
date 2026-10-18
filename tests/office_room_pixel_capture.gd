extends SceneTree

const WORLD = preload("res://scenes/dream/Dream3D_OfficeSample.tscn")
const ROOM_ART = preload("res://scripts/dream/office_room_low_pixel_art.gd")
const KEYS := ["conference", "manager", "archive", "server", "pantry", "restroom", "lounge", "reception", "lift"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(640, 360)
	var layer := CanvasLayer.new()
	layer.layer = 1000
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://shaders/palette_quantize.gdshader")
	palette.set_shader_parameter("palette_enabled", false)
	overlay.material = palette
	layer.add_child(overlay)
	root.add_child(layer)
	for mode in ["before", "after"]:
		ROOM_ART.enabled = mode == "after"
		var world = WORLD.instantiate()
		world.generate_on_ready = false
		world.persist_profile = false
		root.add_child(world)
		assert(world.regenerate(120))
		world.night_lighting.flashlight.visible = false
		for room in world.rooms:
			var key := String(room.get("sample_key", ""))
			if key not in KEYS:
				continue
			world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
			world.activate_room(room.id)
			for enemy in world.enemy_root.get_children():
				enemy.set_physics_process(false)
			for frame in 25:
				await process_frame
			world.set_process(false)
			world.camera_aim_offset = Vector3.ZERO
			world.call("_update_camera_and_actor_projection", 0.0)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/office_rooms_%s_%s_off.png" % [mode, key]))
			if mode == "after":
				palette.set_shader_parameter("palette_enabled", true)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/office_rooms_after_%s_palette1.png" % key))
				palette.set_shader_parameter("palette_enabled", false)
			world.set_process(true)
		world.queue_free()
		await process_frame
	ROOM_ART.enabled = true
	print("OFFICE ROOM PIXEL CAPTURE PASS")
	quit(0)
