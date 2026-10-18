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
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var prompt = PROMPT.new()
	root.add_child(prompt)
	prompt.size = Vector2(128,18)
	prompt.present("拾取", Vector2(200,200), 1)
	check(prompt.visible and prompt.modulate.a == 0.0, "Entry begins transparent")
	prompt._process(0.05)
	check(is_equal_approx(prompt.reveal,0.5) and prompt.position.y == 205.0, "Half entry slides and fades")
	prompt.present("拾取", Vector2(220,210), 1)
	check(is_equal_approx(prompt.reveal,0.5), "Following same target does not restart")
	prompt._process(0.05)
	check(prompt.position == Vector2(220,210) and prompt.modulate.a == 1.0, "Entry completes in 100ms")
	prompt.dismiss()
	prompt._process(0.05)
	check(prompt.visible and is_equal_approx(prompt.reveal,0.5), "Exit remains visible while fading")
	prompt.present("替换", Vector2(220,210), 2)
	prompt._process(0.10)
	check(prompt.visible and prompt.text == "替换", "Reentry interrupts exit without stale callback")
	prompt.dismiss()
	prompt._process(0.10)
	check(not prompt.visible, "Exit completes in 100ms")
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
	check(PROMPT.pickup_verb(pickup,empty_inventory) == "拾取", "Empty category uses pickup")
	empty_inventory.free()
	var badge = load("res://scripts/dream/boss_key_pickup.gd").new()
	root.add_child(badge)
	check(PROMPT.pickup_verb(badge,world.player) == "拾取", "Badge uses pickup")
	badge.free()
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
		world.generate_on_ready = false
		world.regenerate(42001)
		world.transition_phase = &"IDLE"
		world.player.movement_enabled = true
		await frames(20)
		world.set_process(false)
		world.set_physics_process(false)
		var display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
		world.get_parent().remove_child(world)
		display.world = world
		display.preview_mode = false
		root.add_child(display)
		root.size = Vector2i(1280,720)
		display.set_selective_enabled(true)
		display.set_palette_enabled(true)
		await frames(20)
		var point: Vector2 = world.player.get_presentation_hud_position(world.camera_3d.unproject_position(world.to_global(world._map_gameplay_to_world(world.player.global_position + Vector2(32,0))))) + world.INTERACTION_PROMPT_OFFSET
		for word in ["拾取","替换","进入"]:
			world.interaction_prompt.present(word,point,100)
			await create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/compact_prompt_%s.png" % word)
		display.queue_free()
	else:
		world.queue_free()
	await frames(4)
	print("COMPACT_PROMPT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
