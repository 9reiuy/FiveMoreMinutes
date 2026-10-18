extends SceneTree

const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9"

func _init() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func run() -> void:
	seed(14092026)
	var app = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(app)
	await frames(5)
	
	seed(7777)
	app.call("_show_dream", "basic")
	await frames(5)
	
	while app.get("transition_running"):
		await process_frame
		
	var world = app.get("current_screen")
	if not is_instance_valid(world):
		push_error("Failed to enter Dream screen")
		quit(1)
		return
		
	# Let the elevator open and player exit
	for i in range(60):
		await process_frame
		
	var player = world.get("player")
	var night_lighting = world.get("night_lighting")
	if night_lighting != null:
		night_lighting.call("set_flashlight_enabled", true)
		if player != null:
			var player_pos: Vector2 = player.global_position
			night_lighting.call("aim_flashlight", player_pos, player_pos + Vector2(160.0, 50.0))
			
	await frames(15)
	
	# 1. Capture with contour noise ENABLED
	RenderingServer.global_shader_parameter_set(&"light_noise_contour_enabled", true)
	await frames(5)
	await RenderingServer.frame_post_draw
	var img_on := root.get_texture().get_image()
	if img_on != null:
		var path_on := "%s/light_contour_noise_gameplay_enabled.png" % ARTIFACT_DIR
		img_on.save_png(path_on)
		print("Saved gameplay contour noise enabled screenshot: ", path_on)
		
	# 2. Capture with contour noise DISABLED
	RenderingServer.global_shader_parameter_set(&"light_noise_contour_enabled", false)
	await frames(5)
	await RenderingServer.frame_post_draw
	var img_off := root.get_texture().get_image()
	if img_off != null:
		var path_off := "%s/light_contour_noise_gameplay_disabled.png" % ARTIFACT_DIR
		img_off.save_png(path_off)
		print("Saved gameplay contour noise disabled screenshot: ", path_off)
		
	# Restore enabled
	RenderingServer.global_shader_parameter_set(&"light_noise_contour_enabled", true)
	
	app.queue_free()
	await frames(3)
	print("GAMEPLAY LIGHT CONTOUR VISUAL CAPTURE COMPLETED SUCCESSFULLY!")
	quit(0)
