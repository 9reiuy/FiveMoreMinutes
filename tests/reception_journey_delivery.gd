extends SceneTree
const OUT := "res://.runtime/reception_journey_20261027"
var main: Node
var checks := 0
var failures: Array[String] = []
var recording := false
var captures: Array[Dictionary] = []
var next_capture := 0
var last_stage := ""
var walk_positions: Array[Vector2] = []
var cab_positions: Array[Vector2] = []
var walk_animation_seen := false
var loading_overlay_seen := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func frames(n: int = 4) -> void:
	for i in n: await process_frame
func settle() -> void:
	var deadline := Time.get_ticks_msec() + 90000
	while main.transition_running and Time.get_ticks_msec() < deadline: await process_frame
	check(not main.transition_running, "Main transition completes within watchdog")
	await frames()
func _process(_delta: float) -> bool:
	if not recording or Time.get_ticks_msec() < next_capture: return false
	next_capture = Time.get_ticks_msec() + 66
	if captures.size() >= 700: return false
	var file := "frame_%04d.png" % captures.size()
	root.get_texture().get_image().save_png(OUT + "/" + file)
	var world: Node = main._supported_dream_world
	loading_overlay_seen = loading_overlay_seen or main.loading_overlay.visible
	var phase := "floor" if world == null or not world.has_method("rollback_elevator_entry") else "cab" if world.entry_ride_started_usec > 0 else "walking"
	captures.append({"file":file,"milliseconds":Time.get_ticks_msec(),"phase":phase})
	if is_instance_valid(world) and phase == "walking":
		walk_positions.append(world.player.global_position)
		walk_animation_seen = walk_animation_seen or (world.player.scripted_locomotion_active and world.player.velocity.length() > 10.0)
	if is_instance_valid(world) and phase == "cab":
		world.player.set_meta(&"aim_direction_override", Vector2.DOWN)
		cab_positions.append(world.player.global_position)
		if cab_positions.size() == 4: Input.action_press("move_right")
		if cab_positions.size() == 8: Input.action_release("move_right")
	return false
func enter(source: Node) -> void:
	source.player.global_position = source.elevator_floor_door.get_corridor_approach_position_2d()
	source.player.set_meta(&"aim_direction_override", Vector2.UP)
	await frames(8)
	source._update_camera_and_projection(0.0)
	# Exercise the existing E action rather than emitting elevator_entered directly.
	Input.action_press("pickup_weapon")
	await frames(2)
	Input.action_release("pickup_weapon")
	var deadline := Time.get_ticks_msec() + 120000
	while is_instance_valid(source) and (source.elevator_transition_in_progress or main.transition_running) and Time.get_ticks_msec() < deadline:
		await process_frame
func run() -> void:
	create_timer(240, true, false, true).timeout.connect(func(): quit(2))
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"): quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0, true); root.size = Vector2i(1280,720); Engine.max_fps = 60
	main = load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state = main._create_initial_state()
	main._show_reception("basic"); await settle()
	var source: Node = main._supported_dream_world
	check(source.player.left_hand_part.visible and source.player.right_hand_part.visible, "Actual reception preserves stowed-weapon hands")
	main.set_meta(&"test_fail_reception_generation", true)
	await enter(source)
	check(main._supported_dream_world == source and source.player.movement_enabled and not source.elevator_transition_in_progress, "Preparation failure restores actual reception input and permits retry")
	check(source.entry_cab == null and not paused, "Failed journey removes cab boundaries and leaves no global pause")
	main.remove_meta(&"test_fail_reception_generation")
	recording = true
	await enter(source)
	await settle()
	var world: Node = main._supported_dream_world
	check(world != source and world.has_method("_perform_game_start_cab_exit"), "Retry reaches the actual formal floor through Main")
	while world.floor_transition_in_progress: await process_frame
	recording = false
	check(main.get_meta(&"last_reception_journey", {}).get("success", false), "Visible cab preparation successfully committed")
	check(main.get_meta(&"last_reception_journey", {}).get("visible_ride_seconds", 0.0) >= 3.0, "Cab offers at least three seconds of unpaused controllable time after preparation")
	check(cab_positions.size() > 8 and cab_positions[3].distance_to(cab_positions[7]) > 3.0, "Real movement input moves the passenger inside the visible cab")
	check(world.floor_root.visible and world.wall_root.visible, "Prepared floor geometry is revealed at arrival")
	check(is_instance_valid(world.room_visibility) and world.room_visibility.world == world and world.player.get_meta(&"dream_room_id", -1) == world.spawn_room_id, "Fresh staged run initializes formal room visibility and player room identity")
	check(world.get_world_3d() != root.world_3d, "Prepared floor keeps a private 3D world rather than leaking duplicate actors into lobby camera")
	check(world.player.movement_enabled and world.player.attacking_enabled and world.player_has_left_elevator_cab, "Arrival restores movement, attacks and floor progression")
	check(walk_positions.size() > 3 and walk_positions[0].distance_to(walk_positions[-1]) > 20.0, "Actual E entry moves player through doorway over multiple walking frames")
	check(walk_animation_seen, "Entry uses authoritative locomotion velocity and walking animation rather than a position tween")
	check(not loading_overlay_seen, "No fullscreen loading page appears at any recorded journey frame")
	check(not main.loading_overlay.visible and main.transition_director.current_state == 0, "Journey leaves no fullscreen loading overlay")
	world.player.set_physics_process(false)
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false)
	world._show_weapon_name_popup("assault_rifle")
	var word: Control = world.weapon_name_popup
	var anchor: Vector3 = word.anchor
	world.player.global_position += Vector2(80,0)
	world._update_camera_and_actor_projection(0)
	world._update_weapon_name_popup(.1)
	check(word.anchor == anchor and word.visible, "Weapon name retains event world position when player moves")
	check(word.COMIC == preload("res://scripts/ui/comic_pixel_text.gd") and word.shadow.material.shader == word.COMIC.HALFTONE, "Status uses production hurt comic lettering and halftone shadow")
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/weapon_word.png")
	world._update_weapon_name_popup(2.0)
	check(not word.visible, "Weapon name keeps its original lifetime")
	world.player.ammo_states[world.player.selected_weapon_id]["reload_left"] = 5.0
	world._on_player_ammo_changed_for_popup(0,12,true)
	anchor = word.anchor
	world.player.global_position += Vector2(55,0)
	for i in 5: world._update_weapon_name_popup(.5)
	check(word.visible and word.anchor == anchor and word.text == "正在换弹", "Reload remains at original anchor through prolonged reload")
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/reload_word.png")
	world.player.ammo_states[world.player.selected_weapon_id]["reload_left"] = 0.0
	world._on_player_ammo_changed_for_popup(12,12,false)
	check(not word.visible, "Reload completion dismisses its anchored status")
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED, "Actual Camera recorded minimized without focus")
	var file := FileAccess.open(OUT + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"journey":main.get_meta(&"last_reception_journey",{}),"scope":"Actual Main E interaction; injected generation failure and retry; normal-time captures", "gpu":RenderingServer.get_video_adapter_name()}, "\t")); file.close()
	print("RECEPTION_JOURNEY checks=", checks, " failures=", failures.size())
	main.free(); quit(0 if failures.is_empty() else 1)
