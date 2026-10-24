extends SceneTree
const DUST=preload("res://scripts/dream/preview/sample_indoor_dust.gd")
var world: Node
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=2) -> void:
	for i in n: await process_frame
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world)
	var prior: WeakRef
	for kind in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=kind
		for seed_value in [42001,42002,42003]:
			check(world.regenerate(seed_value),"Formal skeleton generates: "+kind)
			world.player.set_physics_process(false); await frames()
			var dust: Node=world.floor_root.get_node("IndoorDust"); dust.set_process(false)
			check(prior==null or prior.get_ref()==null,"Prior floor dust controller is destroyed")
			prior=weakref(dust)
			check(dust.production_mode and dust.get_parent()==world.floor_root and dust.pool.get_parent()==world.floor_root,"Controller and all geometry belong to current formal floor")
			check(dust.records.size()>0 and dust.records.size()<=DUST.LIMIT,"Formal mote count stays inside approved limit")
			check(DUST.install(world)==dust,"Repeated install never duplicates formal manager")
			var covered: Dictionary={}; var valid:=true
			for record in dust.records:
				covered[record.room]=true
				valid=valid and dust.path_inside_room(record.room,record.start,record.finish,record.bend)
				valid=valid and world.rooms[record.room].get("archetype","")!="elevator_lobby"
			check(valid,"Complete curved routes stay inside actual room cells, never the exterior/holes/cab")
			var corridors:=0
			for room in world.rooms:
				if room.get("room_type","")=="corridor":
					corridors+=1; check(covered.has(int(room.id)),"Formal corridor has a dust budget")
			check(corridors>0 and covered.size()>2,"Rooms and corridors both receive the accepted art")
			check(dust.pool.find_children("*","CollisionObject2D",true,false).is_empty() and dust.pool.find_children("*","SubViewport",true,false).is_empty(),"Formal dust adds no physics or extra capture viewport")
			var enabled: bool=dust.enabled
			var key:=InputEventKey.new(); key.keycode=KEY_F8; key.pressed=true; dust._unhandled_key_input(key)
			check(dust.enabled==enabled,"Preview hotkey is disabled in formal gameplay")
	var dust: Node=world.floor_root.get_node("IndoorDust"); dust.set_process(false)
	var state: int=world._rng.state; var topology: Dictionary=world.floor_cells.duplicate()
	dust.rebuild(true)
	check(world._rng.state==state and world.floor_cells==topology,"Prewarming leaves layout RNG and topology unchanged")
	await frames()
	dust._process(.7); var elapsed: float=dust.elapsed; var pool: Node=dust.pool
	var old_index: int=world.floor_index
	world.floor_transition_in_progress=true; world._stash_current_floor_for_rollback(); await frames()
	dust._process(.3)
	check(is_instance_valid(pool) and not pool.visible and dust.elapsed==elapsed,"Stash retains the same hidden frozen dust geometry and clock")
	world._reset_layout_data(); world._rollback_failed_transition(world.transition_generation_token,old_index); await frames()
	world.floor_transition_in_progress=false; world.transition_phase=&"IDLE"; dust._process(0)
	check(world.floor_root.get_node("IndoorDust")==dust and dust.pool==pool and pool.visible and dust.elapsed==elapsed,"Failed transition restores original dust, no lost state or double objects")
	dust.free(); await frames()
	world.transition_phase=&"CAB_RIDE"; world.floor_transition_in_progress=true
	dust=DUST.install(world); dust.set_process(false)
	check(dust.records.size()>0 and not dust.pool.visible,"Cab loading prebuilds the whole pool while it stays invisible")
	var prewarmed_pool: Node=dust.pool
	world.floor_transition_in_progress=false; world.transition_phase=&"EXITING"; dust._process(.2)
	check(not dust.pool.visible and dust.elapsed==0,"Cab exit still hides/freeze dust until gameplay resumes")
	world.transition_phase=&"IDLE"; dust._process(.1)
	check(dust.pool==prewarmed_pool and dust.pool.visible and dust.elapsed==.1,"Control return uses prewarmed pool instead of allocating a new one")
	world.free(); await frames()
	var reception: Node=load("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate()
	check(DUST.install(reception)==null,"Standalone reception does not opt in through shared VFX hook")
	reception.free()
	print("INDOOR_DUST_FORMAL checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
