extends SceneTree
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	check(world.regenerate(42001), "Generate formal floor")
	var origin: Vector2 = world.player.global_position
	var before: Array = world.world_effects_root.get_children()
	check(world.spawn_corpse_drag_trail(origin, origin + Vector2(4, 0), world.current_room_id, 1, 4), "Formal API accepts physical short movement")
	var mark: BlackBloodEffect
	for effect in world.world_effects_root.get_children():
		if effect is BlackBloodEffect and not before.has(effect):
			mark = effect
	check(is_instance_valid(mark), "API creates one shared-authority blood effect")
	if is_instance_valid(mark):
		check(mark.airborne_pixels.is_empty() and mark.is_visual_settled(), "Formal mark stays floor-only and immediately settled")
		check(int(mark.get_meta(&"blood_floor_token")) == world.get_current_floor_token(), "Formal mark owns current floor token")
		var bridge_ref: WeakRef = mark.get_meta(&"depth_visual_bridge")
		check(bridge_ref != null and is_instance_valid(bridge_ref.get_ref()), "Formal passive capture is bound")
		check(mark.ground_pixels.all(func(pixel: Vector2) -> bool: return world._is_blood_ground_allowed(mark.to_global(pixel))), "Formal floor validator clips every pixel")
	var mark_count: int = world.world_effects_root.get_child_count()
	check(not world.spawn_corpse_drag_trail(origin, origin + Vector2(100, 0), world.current_room_id, 1, 4), "Formal API rejects teleport")
	check(not world.spawn_corpse_drag_trail(Vector2(500000, 500000), Vector2(500004, 500000), world.current_room_id, 1, 4), "Formal API rejects outside floor")
	check(world.world_effects_root.get_child_count() == mark_count, "Invalid API calls consume no effect nodes")
	var reference: WeakRef = weakref(mark)
	check(world.regenerate(42002), "Next formal floor generation")
	for index in 4: await process_frame
	check(reference.get_ref() == null, "Floor regeneration clears prior drag mark")
	world.free()
	for index in 3: await process_frame
	print("Corpse drag world: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
