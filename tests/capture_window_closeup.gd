extends SceneTree

const DUNGEON_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PALETTE_SHADER: Shader = preload("res://shaders/palette_quantize.gdshader")
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9/"

func _initialize() -> void:
	call_deferred("_run_capture")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run_capture() -> void:
	var dungeon: Node = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	root.add_child(dungeon)

	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 1000
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE_SHADER
	mat.set_shader_parameter("palette_enabled", true)
	overlay.material = mat
	canvas_layer.add_child(overlay)
	root.add_child(canvas_layer)

	dungeon.regenerate(41001)
	await frames(10)

	# Locate the glass window at (10.5, 0, -1.0)
	var target_win: Node3D = null
	var windows = root.get_tree().get_nodes_in_group(&"breakable_glass_windows")
	for w in windows:
		if is_equal_approx(w.position.x, 10.5) and is_equal_approx(w.position.z, -1.0):
			target_win = w
			break

	if target_win == null and not windows.is_empty():
		target_win = windows[0]

	print("Target window: ", target_win.name, " at ", target_win.position)

	# Enable cutaway mode explicitly on target window to observe cutaway presentation
	target_win.call("set_cutaway_mode", true)

	# Position player near the window
	var player_pos_2d := Vector2(target_win.position.x - 1.5, target_win.position.z + 1.0) * 32.0
	if dungeon.player != null:
		dungeon.player.position = player_pos_2d
		dungeon.player.global_position = player_pos_2d
	dungeon._update_camera_and_actor_projection()
	await frames(10)
	await RenderingServer.frame_post_draw

	var tex := root.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png(ARTIFACT_DIR + "shot_glass_cutaway_intact.png")
			print("Saved shot_glass_cutaway_intact.png")

	# Now shatter the target window
	target_win.call("shatter", Vector2(1, 0))
	await frames(5)
	await RenderingServer.frame_post_draw

	tex = root.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png(ARTIFACT_DIR + "shot_glass_cutaway_shattered.png")
			print("Saved shot_glass_cutaway_shattered.png")

	dungeon.queue_free()
	canvas_layer.queue_free()
	quit(0)
