extends SceneTree
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const OUT := "res://.runtime/progression_fixes"
var world: Node3D
var main: Node
var display: Node
func _initialize() -> void:
	_run.call_deferred()
func frames(count: int) -> void:
	for i in count:
		await process_frame
func shot(label: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")
func matrix(label: String) -> void:
	for pixel in [false, true]:
		display.set_selective_enabled(pixel)
		for palette in [false, true]:
			main._apply_palette_enabled(palette)
			await shot(label + ("_pixel" if pixel else "_native") + ("_palette1" if palette else "_off"))
func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(OUT + "/clip")
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await frames(4)
	world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	main._set_screen(world)
	display = main.current_screen
	await frames(4)
	world.regenerate(6)
	world.night_lighting.set_flashlight_enabled(false)
	world.player.invulnerability_left = 10000
	for enemy in world.enemy_root.get_children():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(24)
	world.player.set_physics_process(false)
	world.player.get_node("CharacterVisual").modulate = Color.WHITE
	world.player.get_node("CharacterVisual").visible = true
	await matrix("entry_reception")
	world.objective_guidance.elapsed = 30
	await matrix("enemy_arrows")
	if world.enemy_root.get_child_count() > 0:
		var enemy: Node2D = world.enemy_root.get_child(0)
		enemy.global_position = world.player.global_position + Vector2(-96, -64)
		await matrix("enemy_head_arrow")
	root.size = Vector2i(1366, 768)
	await shot("enemy_arrows_resized")
	var display_rect: Rect2 = world.objective_guidance._display_rect(world.camera_3d, world.player)
	for state in world.objective_guidance.states:
		if not display_rect.has_point(state.position):
			push_error("Arrow outside actual resized display region")
	root.size = Vector2i(1920, 1080)
	world.player.configure_weapon("basic", world.config, {})
	world.player.get_ammo_status()
	world.player.ammo_states[world.player.selected_weapon_id]["reload_left"] = 100
	world._on_player_ammo_changed_for_popup(0, 12, true)
	await matrix("reloading")
	world.player.ammo_states[world.player.selected_weapon_id]["reload_left"] = 0
	world._on_player_ammo_changed_for_popup(12, 12, false)
	world._spawn_employee_badge(world.player.global_position + Vector2(96, 0), world.current_room_id)
	await matrix("badge_arrow")
	world.has_floor_badge = true
	await matrix("elevator_arrow")
	world.player.configure_weapon("", world.config, {})
	world.player.invulnerability_left = 0
	world.player.set_physics_process(true)
	display.set_selective_enabled(true)
	main._apply_palette_enabled(false)
	world._begin_elevator_entry_transition()
	var cab_shot := false
	for frame in range(600):
		await frames(1)
		await RenderingServer.frame_post_draw
		if frame % 3 == 0:
			root.get_texture().get_image().save_png(OUT + "/clip/frame_%03d.png" % (frame / 3))
		if world.transition_phase == &"CAB_RIDE" and is_instance_valid(world.active_transition_cab):
			root.get_texture().get_image().save_png(OUT + "/cab_empty_hands.png")
			cab_shot = true
	print("PROGRESSION_CAPTURE cab=", cab_shot, " floor=", world.floor_index)
	main.queue_free()
	await frames(4)
	quit()
