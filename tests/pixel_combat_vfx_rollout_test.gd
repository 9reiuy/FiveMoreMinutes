extends SceneTree
const INSTALL=preload("res://scripts/dream/combat_vfx.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	AudioServer.set_bus_mute(0,true)
	var world:=preload("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	root.add_child(world)
	var previous: WeakRef
	for kind in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=kind
		check(world.regenerate(42001),"Formal generation "+kind)
		for i in 3: await process_frame
		check(previous==null or previous.get_ref()==null,"Previous floor releases its smoke manager "+kind)
		var smoke: Node=world.floor_root.get_node_or_null("FootstepSmoke")
		check(smoke!=null and smoke.get_child_count()==72,"Automatic bounded smoke pool "+kind)
		check(INSTALL.install(world)==smoke,"Installer is idempotent "+kind)
		check(world.uses_pixel_combat_vfx(),"Formal gun/hit style enabled by default "+kind)
		previous=weakref(smoke)
	var smoke: Node=previous.get_ref()
	smoke.emit_puff(world.player.global_position,Vector2.LEFT)
	world.floor_transition_in_progress=true
	world._stash_current_floor_for_rollback()
	check(smoke.puffs.is_empty() and smoke.tracked.is_empty(),"Stashing clears trails before rollback or reveal")
	world._rollback_failed_transition(world.transition_generation_token,world.floor_index)
	for i in 3: await process_frame
	check(world.floor_root.get_node("FootstepSmoke")==smoke,"Rollback restores exactly the original manager")
	world.floor_transition_in_progress=true; world.transition_generation_token+=1
	check(await world._regenerate_staged(42002,world.floor_index+1,world.transition_generation_token),"Staged floor generation succeeds")
	for i in 3: await process_frame
	check(previous.get_ref()==null and world.floor_root.get_node_or_null("FootstepSmoke")!=null,"Staged generation installs new manager and disposes old owner")
	world.free()
	var hall:=preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate()
	root.add_child(hall)
	check(hall.floor_root.get_node_or_null("FootstepSmoke")!=null,"Reception automatically owns player smoke")
	hall.free()
	print("PIXEL_COMBAT_VFX_ROLLOUT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
