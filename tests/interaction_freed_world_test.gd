extends SceneTree
var checks := 0
var failures := 0
var world: Node

func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func frames(count: int) -> void:
	for i in count: await process_frame
func pickup(id: String) -> Node2D:
	var item: Node2D = load("res://scenes/dream/world_weapon_pickup.tscn").instantiate()
	world.world_weapon_root.add_child(item)
	item.set_weapon_id(id,0)
	item.global_position = world.player.global_position
	item.set_physics_process(false)
	return item
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.approved_sample_art_enabled = false
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for seed_value in [42001,42002,42003]:
		check(world.regenerate(seed_value),"Formal floor generates")
		await frames(2)
		check(world.current_world_weapon_target==null and world.interaction_resolver._group_cache.is_empty(),"Floor rebuild clears interaction references and group cache")
		var item := pickup("basic")
		world.interaction_resolver.clear_target()
		world.current_world_weapon_target = world.interaction_resolver.update_target()
		check(world.current_world_weapon_target==item,"Real pickup selected in formal resolver")
		item.free()
		# Exercise the caller's alternate-frame cache as well as resolver cache.
		world._update_world_weapon_interaction()
		check(world.current_world_weapon_target==null,"Deleted real pickup clears caller cache without casting freed Node2D")
		var swap := pickup("assault_rifle")
		world._swap_world_weapon(swap)
		check(world.player.selected_weapon_id=="assault_rifle","Normal weapon swap remains available")
		swap.queue_free()
		await frames(2)
		# Restore a nonempty ranged slot, leave melee empty for real auto-storage.
		if not String(world.player.melee_weapon_id).is_empty():
			world.player.switch_weapon_slot()
			world.player.take_active_weapon_for_throw()
			world.player.equip_weapon("assault_rifle",world.config,{})
		var book := pickup("books")
		world.interaction_resolver.clear_target()
		world.current_world_weapon_target = null
		world.current_world_weapon_target = world.interaction_resolver.update_target()
		world._update_world_weapon_interaction()
		check(world.player.melee_weapon_id=="books","Empty-category automatic pickup still stores melee weapon")
		check(book.is_queued_for_deletion(),"Stored pickup queued for deletion")
		await frames(2)
		world._update_world_weapon_interaction()
		check(world.current_world_weapon_target==null,"Auto-pickup leaves no stale interaction target")
	var rollback_item := pickup("basic")
	world.interaction_resolver.clear_target()
	world.current_world_weapon_target = world.interaction_resolver.update_target()
	check(world.current_world_weapon_target==rollback_item,"Rollback fixture initially selected")
	var index: int = world.floor_index
	world._stash_current_floor_for_rollback()
	check(world.current_world_weapon_target==null and world.interaction_resolver._group_cache.is_empty(),"Stash clears both target caches")
	check(world.interaction_resolver.update_target()==null,"Stashed pickups cannot be selected")
	world._rollback_failed_transition(world.transition_generation_token,index)
	check(is_instance_valid(rollback_item),"Failed transition preserves original pickup")
	check(world.interaction_resolver.update_target()==rollback_item,"Rollback restores interaction with original pickup")
	world.free()
	await frames(3)
	print("INTERACTION_FREED_WORLD checks=",checks," failures=",failures)
	quit(1 if failures else 0)
