extends SceneTree

const OUT := "res://.runtime/dialogue_gradient_20261106"
const SHADER := preload("res://shaders/dialogue_gradient_halftone.gdshader")
var checks := 0
var failures := 0
var main: Node
var room: Node


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
	print("PASS " if value else "FAIL ", label)


func frames(count: int) -> void:
	for _i in count:
		await process_frame


func tap(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "/" + label + ".png") == OK, "saved " + label)


func check_gradient_pixels() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(220, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sample := ColorRect.new()
	sample.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"panel_size", Vector2(viewport.size))
	sample.material = material
	viewport.add_child(sample)
	await frames(6)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	check(image.get_pixel(110,32).a > 0.7, "panel center darkens the background")
	check(image.get_pixel(0,32).a < 0.08 and image.get_pixel(219,32).a < 0.08, "left and right edges fade out")
	check(image.get_pixel(110,0).a < 0.08 and image.get_pixel(110,63).a < 0.08, "top and bottom edges fade out")
	var darkest := 1.0
	var lightest := 0.0
	for x in range(95, 125):
		var color := image.get_pixel(x, 52)
		darkest = minf(darkest, color.r)
		lightest = maxf(lightest, color.r)
	check(lightest - darkest > 0.08, "lower panel contains a visible circular dot pattern")
	image.save_png(OUT + "/gradient_alpha.png")
	viewport.queue_free()


func run() -> void:
	print("DIALOGUE_CAMERA PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")):
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
		push_error("Private muted settings were not active before scene entry")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("This test requires the real renderer")
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	create_timer(180.0, true, false, true).timeout.connect(func(): quit(2))
	await check_gradient_pixels()
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await frames(4)
	main.persistent_day_state = main._create_initial_state()
	main._show_reception("basic")
	for _i in range(600):
		await frames(1)
		if main._supported_dream_world is Dream3DReceptionRoom and not main.transition_running:
			room = main._supported_dream_world
			break
	check(is_instance_valid(room), "formal Main opens the reception")
	if not is_instance_valid(room):
		quit(1)
		return
	room.player.set_physics_process(false)
	room.player.global_position = room.RECEPTION_DESK_POS_2D + Vector2(0,45)
	await frames(20)
	check(room.interaction_resolver.current_target == room.waitress_npc, "real NPC is selected")
	await tap("pickup_weapon")
	check(room.dialogue_controller.is_active(), "real interaction starts the dialogue")
	var bubble: Node = room.dialogue_bubble
	for _i in range(120):
		if room.dialogue_controller.typed_chars >= 3:
			break
		await frames(1)
	var early_width: float = bubble.size.x
	await shot("dialogue_early")
	for _i in range(300):
		if room.dialogue_controller.typed_chars >= 15:
			break
		await frames(1)
	check(bubble.size.x > early_width, "dialogue widens as more characters appear")
	await shot("dialogue_growing")
	for _i in range(400):
		if room.dialogue_controller.typed_chars >= room.dialogue_controller.total_chars:
			break
		await frames(1)
	await frames(5)
	check(bubble.dialogue_label.text == room.dialogue_controller.current_text, "full line is visible")
	check(bubble.dialogue_label.get_minimum_size().y <= bubble.text_clip.size.y + 0.1, "wrapped text fits its panel")
	check(not bubble.background.visible and bubble.gradient_panel.visible, "gradient replaces the old frame")
	await shot("dialogue_wrapped")
	var display: Node = main.current_screen
	display.set_selective_enabled(false)
	await frames(8)
	check(bubble.visible and bubble.dialogue_label.text == room.dialogue_controller.current_text, "dialogue survives switching to native display")
	await shot("dialogue_wrapped_native")
	display.set_selective_enabled(true)
	await frames(6)
	await tap("pickup_weapon")
	await frames(12)
	check(room.dialogue_controller._sequence_index == 1, "interaction advances the existing dialogue")
	await tap("ui_cancel")
	await frames(20)
	check(not room.dialogue_controller.is_active() and not bubble.visible, "cancel closes dialogue")
	main._show_tutorial("basic")
	var tutorial: Node
	for _i in range(600):
		await frames(1)
		if is_instance_valid(main._supported_dream_world) and main._supported_dream_world.scene_file_path == "res://scenes/dream/Dream3D_TutorialRoom.tscn" and not main.transition_running:
			tutorial = main._supported_dream_world
			break
	check(is_instance_valid(tutorial), "formal Main opens the tutorial scene")
	if is_instance_valid(tutorial):
		tutorial._spawn_guide_once()
		await frames(25)
		tutorial.player.set_physics_process(false)
		tutorial.player.global_position = tutorial.guide.global_position + Vector2(24,0)
		await frames(20)
		check(tutorial.interaction_resolver.current_target == tutorial.guide, "tutorial guide is selected")
		await tap("pickup_weapon")
		check(tutorial.dialogue_controller.is_active(), "tutorial guide dialogue starts through interaction")
		for _i in range(240):
			if tutorial.dialogue_controller.typed_chars >= 10:
				break
			await frames(1)
		check(tutorial.dialogue_bubble.gradient_panel.visible, "tutorial uses the same gradient and halftone")
		await shot("tutorial_dialogue")
		tutorial.dialogue_controller.dismiss_if_active()
	main.queue_free()
	await frames(5)
	print("DIALOGUE_CAMERA checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
