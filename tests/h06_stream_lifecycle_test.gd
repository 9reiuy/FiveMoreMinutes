extends "res://tests/h06_hangar_crew_test.gd"
const PREPARATION := preload("res://scripts/testing/h06_chapter/stream_render_preparation.gd")
const MATERIALS := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
var receipts:Array[Dictionary]=[]

func open_frozen(save:int, optimized:bool) -> void:
	# This regression retains the original dead-crew branch; the surviving
	# branch has separate choice/entry coverage.
	set_meta(CHAPTER.RETRY_KEY,{"checkpoint":save,"staff_story":{"scientist_killed":true}})
	world=load(WORLD).instantiate()
	world.generate_on_ready=false
	world.process_mode=Node.PROCESS_MODE_DISABLED
	for key in [&"h06_resource_reuse",&"h06_streaming_budget",&"h06_render_warmup"]:world.set_meta(key,optimized)
	display=load(PREVIEW).instantiate()
	display.preview_mode=false
	display.world=world
	root.add_child(display)
	await frames(1)
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	check(world.regenerate(11011),"frozen chapter generates")
	world._setup_chapter_session()

func squad_snapshot(squads:Dictionary) -> Dictionary:
	var result:Dictionary={}
	for key:String in squads:
		var units:Array=[]
		for actor:EmployeeEnemy in squads[key]:
			var bridge:Node3D=actor.get_meta(&"depth_visual_bridge").get_ref()
			units.append({"position":actor.position,"kind":actor.get_meta(&"enemy_type"),"weapon":actor.held_weapon_id,"health":actor.maximum_health,"height":bridge.ground_surface_height})
		result[key]=units
	return result

func dispose() -> void:
	display.queue_free()
	await frames(8)

func cross(id:int) -> void:
	var gate:Dictionary=PLAN.PASSAGES[id]
	world.previous_feet=gate.at-gate.forward
	var feet:Vector2=gate.at+gate.forward*(PLAN.ENTRY_DEPTH+0.4)
	world._place_feet(feet)
	world._update_passage(feet)

func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func():quit(3))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	MATERIALS.procedural_cache_enabled=true
	await open_frozen(CHAPTER.Save.GUARD,false)
	var reference_squads:=squad_snapshot(world.warehouse_squads)
	var reference_count:int=world.enemy_count
	var original_actor:WeakRef=weakref(world.warehouse_squads.guard[0])
	await dispose()
	check(original_actor.get_ref()==null,"original actors release on scene unload")
	await open_frozen(CHAPTER.Save.ENTRANCE,true)
	var rng_state:int=world._content_rng.state
	var layout_rng:int=world._rng.state
	var health:float=world.player.current_health
	var ammo:Dictionary=world.player.ammo_states.duplicate(true)
	var feet:Vector2=world._feet()
	var camera:Transform3D=world.camera_rig.global_transform
	var old_floor:WeakRef=weakref(world.blockout.floor_root)
	var old_crew:WeakRef=weakref(world.blockout.hangar_crew)
	var receipt:Dictionary=await world.prepare_chapter_streaming()
	receipts.append(receipt)
	check(receipt.get("ready",false) and world.chapter_stream_ready,"native loading preparation completes")
	check(world._content_rng.state==rng_state and world._rng.state==layout_rng,"loading preserves both gameplay RNG streams")
	check(world.player.current_health==health and world.player.ammo_states==ammo and world._feet()==feet,"loading preserves player health ammo and position")
	check(world.camera_rig.global_transform.is_equal_approx(camera) and world.blockout.visit==PLAN.Visit.GALLERY,"loading restores the actual Camera and current visit")
	check(world.enemy_count==0 and world.warehouse_squads.is_empty(),"future enemies do not affect the current encounter count")
	check(world.chapter_staged_regions.size()==3,"only the next three reported-path visits are retained")
	var west=world.chapter_staged_regions[PLAN.Visit.WEST]
	check(squad_snapshot(west.staged_warehouse_squads)==reference_squads,"all original squads retain exact positions weapons health and floor heights")
	var ids:Array=[]
	for key:String in west.staged_warehouse_squads:
		for actor:EmployeeEnemy in west.staged_warehouse_squads[key]:
			ids.append(actor.get_instance_id())
			var bridge:Node3D=actor.get_meta(&"depth_visual_bridge").get_ref()
			check(not actor.room_runtime_active and not actor.hostile and not actor.visible and actor.collision_layer==0 and not actor.is_in_group(&"dream_enemies") and not actor.is_in_group(&"employee_enemies") and not bridge.room_presentation_active and not bridge.actor_sprite.visible,"future "+key+" actor stays hidden dormant and outside combat groups")
	for area in world.chapter_staged_regions.values():
		check(not area.live and not area.floor_root.visible and not area.wall_root.visible and not area.lights_root.visible,"future area "+str(area.visit)+" stays hidden")
	var cached_count:int=world.get_child_count()
	var repeated:Dictionary=await world.prepare_chapter_streaming()
	check(repeated==receipt and cached_count==world.get_child_count(),"repeated preparation does not duplicate future scenes")
	world.wake_room_enemies(0,world.player.position)
	world._set_room_content_active(0,true)
	for squad:Array in west.staged_warehouse_squads.values():
		for actor:EmployeeEnemy in squad:world.notify_gunshot(actor.position,0)
	world.process_mode=Node.PROCESS_MODE_INHERIT
	await frames(90)
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var dormant:=true
	for squad:Array in west.staged_warehouse_squads.values():
		for actor:EmployeeEnemy in squad:
			var bridge:Node3D=actor.get_meta(&"depth_visual_bridge").get_ref()
			dormant=dormant and not actor.room_runtime_active and not actor.hostile and not actor.visible and actor.state==EmployeeEnemy.State.NEUTRAL_WANDER and not bridge.room_presentation_active and not bridge.actor_sprite.visible
	check(dormant and squad_snapshot(west.staged_warehouse_squads)==reference_squads,"live first room gunshots discovery and room wake cannot activate or move future enemies")
	world.checkpoint=CHAPTER.Save.OBSERVATION
	cross(PLAN.Visit.GALLERY)
	check(world.blockout==west and not world.chapter_staged_regions.has(PLAN.Visit.WEST),"actual first passage consumes the prepared region exactly once")
	check(world.enemy_count==reference_count and squad_snapshot(world.warehouse_squads)==reference_squads,"first passage restores exact original encounter count without respawning")
	for key:String in world.warehouse_squads:
		for actor:EmployeeEnemy in world.warehouse_squads[key]:
			check(ids.has(actor.get_instance_id()) and actor.is_in_group(&"dream_enemies") and actor.is_in_group(&"employee_enemies") and not actor.has_meta(&"h06_staged_visit") and actor.get_meta(&"dream_room_id")==0,"claimed "+key+" actor reuses its original prepared identity and combat registration")
	world._activate_warehouse_squad("guard",Rect2(-49.2,-37,36.7,34),true)
	var unit:EmployeeEnemy=world.warehouse_squads.guard[0]
	check(unit.room_runtime_active and unit.hostile and world.members.has(unit),"original trigger activates AI and encounter membership")
	var hp:float=unit.current_health
	unit.take_damage(1.0,unit.global_position+Vector2(32,0),0.0)
	check(unit.current_health<hp,"activated prepared enemy receives actual projectile damage")
	for squad:Array in world.warehouse_squads.values():
		for actor:EmployeeEnemy in squad:actor.set_room_runtime_active(false)
	var retired_unit:WeakRef=weakref(unit)
	var west_floor:WeakRef=weakref(west.floor_root)
	world.stage=CHAPTER.Stage.RETURN
	world._set_lower(true)
	world.blockout.set_gate("pump",false)
	cross(PLAN.Visit.WEST)
	check(world.blockout.visit==PLAN.Visit.EMPTY_HANGAR and world.blockout.hangar_crew.aftermath,"actual 1-2 exit activates the prepared return aftermath")
	var drains:=0
	while not world.unload_queue.is_empty() and drains<2400:
		world._drain_retired_region()
		await process_frame
		drains+=1
	await frames(8)
	check(world.unload_queue.is_empty() and old_floor.get_ref()==null and old_crew.get_ref()==null and west_floor.get_ref()==null and retired_unit.get_ref()==null,"bounded retirement releases old geometry workers and actual enemy actors")
	world.gate_state.cargo_access=false
	world.blockout.set_gate("cargo_access",false)
	cross(PLAN.Visit.EMPTY_HANGAR)
	check(world.blockout.visit==PLAN.Visit.FREIGHT and world.chapter_staged_regions.is_empty(),"actual 1-3 passage consumes the final prepared region")
	var final_floor:WeakRef=weakref(world.blockout.floor_root)
	var old_world:WeakRef=weakref(world)
	await dispose()
	check(final_floor.get_ref()==null and old_world.get_ref()==null,"chapter exit releases retained future areas")
	await open_frozen(CHAPTER.Save.RETURN_BAY,true)
	receipt=await world.prepare_chapter_streaming()
	check(receipt.get("ready",false) and receipt.visits.size()==2 and world.chapter_staged_regions.keys()==[PLAN.Visit.FREIGHT],"return checkpoint prepares only current and future visits")
	await dispose()
	await open_frozen(CHAPTER.Save.ENTRANCE,true)
	var interrupted_world:WeakRef=weakref(world)
	create_timer(0.05,true,false,true).timeout.connect(display.queue_free)
	receipt=await PREPARATION.run(world)
	await frames(8)
	check(receipt.get("cancelled",false) and interrupted_world.get_ref()==null,"leaving during preparation cancels safely and releases temporary scenes")
	var failures:Array=checks.filter(func(row:Dictionary)->bool:return not row.pass)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"warm_receipts":receipts,"retirement_frames":drains,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)},"\t"))
	print("H06_STREAM_LIFECYCLE checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
