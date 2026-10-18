extends SceneTree

const WORLD = preload("res://scenes/dream/Dream3D_OfficeSample.tscn")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var output_prefix := "sample_layered" if "layered" in OS.get_cmdline_user_args() else "sample_pixel"
	root.size = Vector2i(1152, 720)
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	if not world.regenerate(120):
		quit(1)
		return
	var atlas_material: ShaderMaterial = preload("res://scripts/dream/office_detail_art.gd").material()
	var atlas_texture: Texture2D = atlas_material.get_shader_parameter("detail_atlas")
	atlas_texture.get_image().save_png(ProjectSettings.globalize_path("res://.runtime/office_detail_atlas.png"))
	world.player.invulnerability_left = 0
	world.night_lighting.flashlight.visible = false
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
	for room in world.rooms:
		if String(room.get("archetype", "")) == "corridor":
			continue
		world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
		world.activate_room(room.id)
		for enemy in world.enemy_root.get_children():
			enemy.set_physics_process(false)
		world.player.invulnerability_left = 0
		for frame in 35:
			await process_frame
		# Capture the same authored camera at neutral look-ahead for every room.
		# Freeze only the diagnostic frame, never the production camera behavior.
		world.set_process(false)
		world.camera_aim_offset = Vector3.ZERO
		world.call("_update_camera_and_actor_projection", 0.0)
		var details: Array[Node] = []
		for node in world.find_children("OfficeDetailAttachments", "MeshInstance3D", true, false):
			details.append(node)
		for node in world.find_children("AuthoredOfficeDecorations_*", "MeshInstance3D", true, false):
			details.append(node)
		if output_prefix == "sample_pixel" and String(room.sample_key) in ["office", "conference", "pantry", "restroom"]:
			for node in details:
				node.visible = false
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/zero_before_%s.png" % room.sample_key))
			for node in details:
				node.visible = true
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/%s_%s.png" % [output_prefix, room.sample_key]))
		print("SAMPLE ART CAPTURE ", room.sample_key)
		palette.set_shader_parameter("palette_enabled", true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/%s_%s_palette1.png" % [output_prefix, room.sample_key]))
		palette.set_shader_parameter("palette_enabled", false)
		world.set_process(true)
	world.queue_free()
	await process_frame
	quit()
