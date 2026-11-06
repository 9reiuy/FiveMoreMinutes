extends SceneTree
const PROMPT = preload("res://scripts/ui/compact_interaction_prompt.gd")
var checks := 0
var failures := 0
class EmptyInventory extends Node:
	func get_weapon_in_category(_category: StringName) -> String: return ""
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame

func close_color(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) < 0.012 and absf(actual.g - expected.g) < 0.012 and absf(actual.b - expected.b) < 0.012

func check_rendered_center(image: Image, prompt: Label, word: String, pixelated: bool) -> void:
	# Compare the actual light glyph pixels with the two fully opaque frame
	# edges. Font line-height alignment alone can leave the ink visibly high.
	var transform := root.get_final_transform()
	var scale := transform.get_scale()
	var font := prompt.get_theme_font(&"font")
	var width := ceilf(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, prompt.get_theme_font_size(&"font_size")).x) + 12.0
	var box_left := floorf((prompt.size.x - width) * 0.5)
	var first := transform * (prompt.position + Vector2(box_left - 3.0, -6.0))
	var last := transform * (prompt.position + Vector2(box_left + width + 3.0, prompt.size.y + 6.0))
	var x0 := clampi(floori(first.x), 0, image.get_width() - 1)
	var x1 := clampi(ceili(last.x), 0, image.get_width())
	var y0 := clampi(floori(first.y), 0, image.get_height() - 1)
	var y1 := clampi(ceili(last.y), 0, image.get_height())
	var rows: Dictionary = {}
	var ink_top := image.get_height()
	var ink_bottom := -1
	var frame_color: Color = PROMPT.FRAME_COLOR if word in PROMPT.SHORT_ACTIONS else PROMPT.SECONDARY_FRAME_COLOR
	for y in range(y0, y1):
		for x in range(x0, x1):
			var color := image.get_pixel(x, y)
			if close_color(color, frame_color):
				rows[y] = int(rows.get(y, 0)) + 1
			elif close_color(color, PROMPT.TEXT_COLOR):
				ink_top = mini(ink_top, y)
				ink_bottom = maxi(ink_bottom, y)
	var max_row := 0
	for count in rows.values():
		max_row = maxi(max_row, int(count))
	var frame_top := image.get_height()
	var frame_bottom := -1
	for row in rows:
		if int(rows[row]) >= maxi(1, ceili(float(max_row) * 0.75)):
			frame_top = mini(frame_top, int(row))
			frame_bottom = maxi(frame_bottom, int(row))
	var valid := max_row > 0 and ink_bottom >= ink_top and frame_bottom > frame_top
	var error := absf(float(ink_top + ink_bottom - frame_top - frame_bottom) * 0.5) if valid else INF
	print("VISIBLE_CENTER ", word, " pixel=", pixelated, " ink=", ink_top, "..", ink_bottom, " frame=", frame_top, "..", frame_bottom, " error_px=", error)
	check(valid and error <= maxf(1.0, absf(scale.y) * 0.75), "visible glyph pixels are centered within frame for " + word)

func run() -> void:
	print("COMPACT_PROMPT_TEST PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")):
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
		push_error("Private muted settings were not active before scene entry")
		quit(2)
		return
	var prompt = PROMPT.new()
	root.add_child(prompt)
	prompt.size = Vector2(128,18)
	var original_frame := Color("396FE2")
	check(absf(PROMPT.FRAME_COLOR.s - original_frame.s * 0.5) < 0.0001 and is_equal_approx(PROMPT.FRAME_COLOR.v, original_frame.v), "frame saturation is halved without changing brightness")
	check(prompt.get_theme_font(&"font").resource_path.ends_with("BoutiqueBitmap9x9_Bold_1.9.ttf"), "interaction prompt uses bold pixel font")
	check(prompt.get_theme_font_size(&"font_size") == 14 and prompt.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "larger text is vertically centered")
	var font: Font = prompt.get_theme_font(&"font")
	print("PROMPT_METRICS size=",prompt.size," minimum=",prompt.get_combined_minimum_size()," height=",font.get_height(PROMPT.FONT_SIZE)," ascent=",font.get_ascent(PROMPT.FONT_SIZE)," descent=",font.get_descent(PROMPT.FONT_SIZE))
	for character in "进入替换交流断电送电":
		check(prompt.get_theme_font(&"font").has_char(character.unicode_at(0)), "bold pixel font supports " + character)
	prompt.present("进入", Vector2(200,200), 1)
	check(prompt.visible and prompt.modulate.a == 0.0, "Entry begins transparent")
	prompt._process(PROMPT.DURATION*.5)
	check(is_equal_approx(prompt.reveal,0.5) and absf(prompt.position.y-202.5)<=.5, "Half entry eases upward and fades without scaling glyphs")
	prompt.present("进入", Vector2(220,210), 1)
	check(is_equal_approx(prompt.reveal,0.5), "Following same target does not restart")
	prompt._process(PROMPT.DURATION*.5)
	check(prompt.position == Vector2(220,210) and prompt.modulate.a == 1.0, "Entry completes in configured snappy duration")
	prompt.dismiss()
	prompt._process(PROMPT.DURATION*.5)
	check(prompt.visible and is_equal_approx(prompt.reveal,0.5), "Exit remains visible while fading")
	prompt.present("替换", Vector2(220,210), 2)
	prompt._process(PROMPT.DURATION)
	check(prompt.visible and prompt.text == "替换", "Reentry interrupts exit without stale callback")
	prompt.dismiss()
	prompt._process(PROMPT.DURATION)
	check(not prompt.visible, "Exit finishes without stale callbacks")
	prompt.present("进入", Vector2.ZERO, 3)
	prompt._process(PROMPT.DURATION)
	prompt.present("", Vector2.ZERO, 4)
	check(not prompt.visible and not prompt.wanted and prompt.text.is_empty(), "empty pickup message immediately removes the previous prompt")
	prompt.present("进入", Vector2.ZERO, 3)
	paused = true
	prompt._process(0.01)
	check(not prompt.visible and not prompt.wanted, "Pause clears prompt")
	paused = false
	prompt.free()
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.enable_game_start_cab_exit = false
	world.persist_profile = false
	world.approved_sample_art_enabled = false
	root.add_child(world)
	world.transition_phase = &"IDLE"
	world.player.movement_enabled = true
	var pickup = load("res://scenes/dream/world_weapon_pickup.tscn").instantiate()
	world.world_weapon_root.add_child(pickup)
	pickup.set_weapon_id("basic",0)
	pickup.global_position = world.player.global_position + Vector2(16,0)
	pickup.set_interaction_targeted(true)
	pickup.linear_velocity = Vector2.ZERO
	world.current_world_weapon_target = pickup
	world._update_interaction_prompt()
	check(world.interaction_prompt.text == "替换", "Occupied category uses replace")
	check(world.interaction_prompt.get_parent() == world.ui_layer, "Prompt stays in clear HUD")
	var empty_inventory := EmptyInventory.new()
	check(PROMPT.pickup_verb(pickup,empty_inventory).is_empty(), "Empty category has no pickup label")
	empty_inventory.free()
	var saved_ranged: String = world.player.ranged_weapon_id
	world.player.ranged_weapon_id = ""
	world._update_interaction_prompt()
	check(not world.interaction_prompt.visible and world.interaction_prompt.text.is_empty(), "actual world hides pickup label for empty weapon slot")
	world.player.selected_weapon_id = ""
	world.interaction_resolver.set_target(pickup)
	world._update_world_weapon_interaction()
	check(world.player.ranged_weapon_id == saved_ranged and pickup.is_queued_for_deletion(), "unlabelled weapon still picks up through the normal resolver")
	var badge = load("res://scripts/dream/boss_key_pickup.gd").new()
	root.add_child(badge)
	badge.configure(world, -1)
	# This isolated fixture has no 3D bridge; supply a valid inert reference for
	# the badge's normal highlight callback.
	badge.set_meta(&"depth_visual_bridge", weakref(world))
	badge.global_position = world.player.global_position + Vector2(16,0)
	badge.interaction_targeted = true
	world.floor_badge_pickup = badge
	world.current_world_weapon_target = badge
	check(PROMPT.pickup_verb(badge,world.player).is_empty(), "Badge has no pickup label")
	world._update_interaction_prompt()
	check(not world.interaction_prompt.visible and world.interaction_prompt.text.is_empty(), "actual world hides badge pickup label")
	world.interaction_resolver.clear_target()
	world.interaction_resolver.set_target(badge)
	Input.action_press("pickup_weapon")
	await process_frame
	world._update_world_weapon_interaction()
	Input.action_release("pickup_weapon")
	await process_frame
	check(world.has_floor_badge, "unlabelled badge still collects through the normal interaction")
	world.current_world_weapon_target = null
	world.elevator_prompt_active = true
	world._update_interaction_prompt()
	check(world.interaction_prompt.text == "进入", "Elevator uses enter only")
	world.floor_transition_in_progress = true
	world._update_interaction_prompt()
	check(not world.interaction_prompt.visible, "Transition clears prompt immediately")
	world.floor_transition_in_progress = false
	world.elevator_prompt_active = false
	if "--capture" in OS.get_cmdline_user_args():
		preload("res://tests/support/background_gpu.gd").start(self)
		Engine.max_fps = 60
		world.queue_free()
		await frames(4)
		var main = load("res://scenes/app/main.tscn").instantiate()
		root.add_child(main)
		await frames(4)
		world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
		world.generate_on_ready = false
		world.enable_game_start_cab_exit = false
		world.persist_profile = false
		main._set_screen(world)
		var display = main.current_screen
		root.size = Vector2i(1280,720)
		await frames(4)
		world.regenerate(42001)
		world.transition_phase = &"IDLE"
		world.player.movement_enabled = true
		await frames(20)
		world.player.set_physics_process(false)
		world.set_process(false)
		world.set_physics_process(false)
		display.set_selective_enabled(true)
		display.set_palette_enabled(true)
		await frames(20)
		var output := "res://.runtime/interaction_ui_20261106"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		for pixelated in [true, false]:
			display.set_selective_enabled(pixelated)
			await frames(4)
			var point: Vector2 = world.player.get_presentation_hud_position(world.camera_3d.unproject_position(world.to_global(world._map_gameplay_to_world(world.player.global_position + Vector2(32,0))))) + world.INTERACTION_PROMPT_OFFSET
			print("CAPTURE_LAYOUT pixel=",pixelated," camera_size=",world.camera_3d.get_viewport().get_visible_rect().size," display_rect=",display.content_rect," point=",point)
			check(display.content_rect.has_point(point + world.INTERACTION_PROMPT_SIZE * 0.5), "prompt anchor maps inside the active display")
			for word in ["替换","进入","交流","断电","送电"]:
				world.interaction_prompt.dismiss(true)
				world.interaction_prompt.present(word,point,word.hash())
				world.interaction_prompt._process(PROMPT.DURATION)
				world.interaction_prompt.set_process(false)
				await frames(4)
				check(world.interaction_prompt.visible and world.interaction_prompt.text == word, "actual game camera shows " + word)
				await RenderingServer.frame_post_draw
				var image_path: String = output + "/" + word + ("_pixel.png" if pixelated else "_native.png")
				var screenshot := root.get_texture().get_image()
				check_rendered_center(screenshot, world.interaction_prompt, word, pixelated)
				check(screenshot.save_png(image_path) == OK, "saved " + image_path)
		main.queue_free()
	else:
		world.queue_free()
	await frames(4)
	var tutorial = load("res://scenes/dream/Dream3D_TutorialRoom.tscn").instantiate()
	tutorial.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(tutorial)
	await frames(2)
	check(tutorial.interaction_prompt.get_theme_font(&"font").resource_path.ends_with("BoutiqueBitmap9x9_Bold_1.9.ttf"), "tutorial interaction uses bold pixel font")
	check(tutorial.interaction_prompt.get_theme_font_size(&"font_size") == 14 and tutorial.interaction_prompt.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "tutorial text is enlarged and centered")
	tutorial.queue_free()
	await frames(4)
	print("COMPACT_PROMPT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
