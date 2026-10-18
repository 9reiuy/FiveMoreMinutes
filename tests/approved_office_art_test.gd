extends SceneTree
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const STYLE = preload("res://scripts/dream/office_art_room_style.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	for pair in [["open_office","office"],["conference_large","conference"],["manager","manager"],["archive","archive"],["pantry","pantry"],["restroom","restroom"],["reception","reception"],["corridor","corridor"]]:
		check(STYLE.key({"archetype":pair[0],"sample_key":"unrelated"})==pair[1],"Formal archetype maps independently of skeleton identity")
	var world = WORLD.instantiate()
	world.generate_on_ready=false
	world.enable_game_start_cab_exit=false
	world.persist_profile=false
	root.add_child(world)
	var previous: WeakRef
	for type in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=type
		check(world.regenerate(42001),"Formal skeleton generation "+type)
		await frames(3)
		check(previous==null or previous.get_ref()==null,"Old art bundle released")
		var art = world.office_art_root.get_node("ApprovedOfficeArt")
		previous=weakref(art)
		check(world.office_art_root.get_child_count()==1,"One bundle per floor")
		check(art.furniture.label==null,"No sample UI")
		check(world.rooms.all(func(r: Dictionary)->bool: return not bool(r.get("authored_sample",false))),"No forged sample rooms")
		check(art.furniture.records.size()>0 and art.walls.walls.size()>0 and art.floors.records.size()>0,"Furniture wall floor materials applied")
		check(art.city.window_lights.size()==4 and art.city.scene_root.get_parent()==art,"Bounded city lights owned by floor")
		check(art.city.topology.external.size()>0 and art.city.buildings>0,"Exterior city built from actual outline")
		var expected:=0
		for plan in world.room_layout_plans.values(): expected+=plan.get("furniture_placements",[]).size()
		var added:=0
		for item in world.furniture_root.get_children():
			if item.has_meta(&"approved_art_addition"): added+=1
		check(world.furniture_root.get_child_count()==expected+added,"Core furniture retained; added plants explicit")
		check(world.rendered_edge_failures==0,"Door wall and glass authority unchanged")
		var counts := Vector3i(art.walls.walls.size(),art.walls.windows.size(),art.walls.doors.size())
		art.furniture.refresh_assets(); art.walls.refresh_assets(); art.floors.refresh_assets()
		check(counts==Vector3i(art.walls.walls.size(),art.walls.windows.size(),art.walls.doors.size()),"Refresh does not duplicate records")
		check(art.city.window_lights.all(func(light: Light3D)->bool: return not light.shadow_enabled),"Exterior lights do not take shadow slots")
		var rng_state: int=world._rng.state
		art.furniture.refresh_assets(); art.walls.refresh_assets()
		check(world._rng.state==rng_state,"Art variation does not consume gameplay RNG")
	# Exercise existing transaction rollback with the old art bundle and proxies.
	var old_art = world.office_art_root.get_node("ApprovedOfficeArt")
	var old_id: int=old_art.get_instance_id()
	var old_count: int=world.furniture_root.get_child_count()
	var old_seed: int=world.active_seed
	world.transition_generation_token+=1
	var token: int=world.transition_generation_token
	world._stash_current_floor_for_rollback()
	check(not old_art.is_processing() or old_art.can_process()==false,"Stashed art cannot update")
	var empty_floor_count: int=world.floor_root.get_child_count()
	old_art.furniture.refresh_assets(); old_art.floors.refresh_assets(); old_art.walls.refresh_assets(); old_art.refresh_assets()
	check(world.floor_root.get_child_count()==empty_floor_count,"Delayed old-floor refresh cannot write to new roots")
	world.active_seed+=999
	world._rollback_failed_transition(token,world.floor_index)
	await frames(3)
	check(world.office_art_root.get_node("ApprovedOfficeArt").get_instance_id()==old_id,"Rollback restores exact bundle")
	check(world.furniture_root.get_child_count()==old_count,"Rollback preserves furniture and plants")
	check(world.active_seed==old_seed,"Rollback restores art and gameplay floor seed")
	check(RenderingServer.frame_pre_draw.is_connected(old_art.city._sync_render_snapshot),"Restored city reconnects render synchronization")
	world.queue_free(); await frames(3)
	var sample = load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	sample.generate_on_ready=false; sample.enable_game_start_cab_exit=false; sample.persist_profile=false
	root.add_child(sample)
	check(sample.regenerate(120),"Sample still generates")
	check(sample.office_art_root.get_child_count()==0,"Fixed sample not double-dressed")
	sample.queue_free(); await frames(3)
	print("APPROVED_ART_RESULT checks=",checks," failures=",failures)
	quit(1 if failures>0 else 0)
