extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func frames(count:=2) -> void:
	for i in count:await process_frame
func run() -> void:
	var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false;world.persist_profile=false;world.spawn_content=false
	root.add_child(world)
	check(world.regenerate(42001),"Real floor loads")
	world.player.set_physics_process(false)
	var system: Node=world.floor_root.get_node("FireExtinguisherSystem")
	system.set_physics_process(false)
	var tanks:=get_nodes_in_group(&"fire_extinguishers")
	check(tanks.size()>0,"Real floor generates wall cylinders")
	if tanks.is_empty():world.free();quit(1);return
	var tank: Node=tanks[0]
	tank.set_physics_process(false)
	tank.take_damage(20,Vector2.RIGHT)
	system.advance(.5)
	var visual: Node=tank.visual
	world.floor_transition_in_progress=true
	var old_floor: int=world.floor_index
	world._stash_current_floor_for_rollback()
	await frames()
	check(is_instance_valid(tank) and is_instance_valid(visual) and not visual.is_queued_for_deletion(),"Stash reparent preserves the same cylinder and model")
	check(not system.can_process() and not tank.can_process(),"Stash suspends gas and cylinder simulation")
	world._reset_layout_data()
	world._rollback_failed_transition(world.transition_generation_token,old_floor)
	await frames()
	check(is_instance_valid(visual) and system.can_process(),"Failed transition restores smoke and model")
	check(system==world.floor_root.get_node("FireExtinguisherSystem"),"Rollback does not duplicate the controller")
	world.floor_transition_in_progress=false
	system.advance(.1)
	check(not system.cells.is_empty(),"Restored smoke resumes on its original floor")
	check(world.regenerate(42002),"Next floor generates")
	await frames()
	check(not is_instance_valid(system) and not is_instance_valid(visual),"Successful replacement removes old gas and cylinder models")
	check(is_instance_valid(world.floor_root.get_node("FireExtinguisherSystem")),"New floor owns a fresh smoke controller")
	world.free();await frames()
	print("FIRE_EXTINGUISHER_FLOOR checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
