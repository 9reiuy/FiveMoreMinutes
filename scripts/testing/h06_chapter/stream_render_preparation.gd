extends RefCounted
## Loading-only real-render warmup. No live combat, input, room switch or RNG use.
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const VIEWS := {
	PLAN.Visit.WEST:[Vector3(-5.5,3.04,-28),Vector3(-21,3.04,-29),Vector3(-37,3.04,-30),Vector3(-37,3.04,-12),Vector3(-20,3.04,-12),Vector3(-33,0,3)],
	PLAN.Visit.EMPTY_HANGAR:[Vector3(5.3,1.28,0.7),Vector3(-8.8,0,7.5),Vector3(0,0,10.5)],
	PLAN.Visit.FREIGHT:[Vector3(0,0,18),Vector3(-5,0,41),Vector3(40,0,90),Vector3(58,0,32)]}

static func _compiles() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))

static func _settle(tree: SceneTree) -> void:
	var prior:=_compiles()
	var quiet:=0
	for i in 90:
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var current:=_compiles()
		quiet=quiet+1 if current==prior else 0
		prior=current
		if quiet>=8:break

static func _valid(world:Variant, generation:int) -> bool:
	return is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and world.get_current_floor_token()==generation

static func run(world: Node3D, progress: Callable=Callable()) -> Dictionary:
	var tree:=world.get_tree()
	if DisplayServer.get_name()=="headless":return {"skipped":"headless"}
	if world.can_process() and not tree.paused:return {"skipped":"gameplay_not_frozen"}
	var generation:int=world.get_current_floor_token()
	var saved_rig:Transform3D=world.camera_rig.global_transform
	var player_ground:Vector3=world._player_ground_anchor_position_3d() if world.has_method("_player_ground_anchor_position_3d") else Vector3(world._feet().x,world._floor_height_at(world._feet()),world._feet().y)
	var rig_offset:Vector3=saved_rig.origin-world.to_global(player_ground)
	var current=world.blockout
	if current.visit>PLAN.Visit.FREIGHT:return {"ready":true,"ms":0.0,"visits":[]}
	var content_rng:int=world._content_rng.state
	var layout_rng:int=world._rng.state
	var player_bridge_visible:bool=world.player_depth_bridge.visible
	world.player_depth_bridge.hide()
	current.set_live(false)
	var sources:=Node2D.new()
	sources.name="ChapterLoadingPoses"
	sources.process_mode=Node.PROCESS_MODE_DISABLED
	world.collision_root.add_child(sources)
	var actors:Array[Node2D]=[]
	var bridges:Array[Node3D]=[]
	for spec:Array in [["employee","basic"],["employee","lucille"],["engineer","lucille"],["scientist",""]]:
		var kind:String=spec[0]
		var packed:PackedScene=world.EMPLOYEE_SCENE if kind=="employee" else (world.ENGINEER_SCENE if kind=="engineer" else world.SCIENTIST_SCENE)
		var actor:=packed.instantiate() as EmployeeEnemy
		actor._cached_dream_world=world
		sources.add_child(actor)
		actor.configure(world.player,world.config.base_enemy_health,0.0,Rect2(-2000,-2000,4000,4000),world.config.enemy_separation_strength,world.config.enemy_separation_radius,world.config)
		actor._disable_damage_and_collision()
		actor.target=null
		actor.hostile=false
		if kind!="scientist":actor.equip_weapon(spec[1],0)
		var bridge:Node3D=world._spawn_depth_bridge(actor,[^"Shadow",^"CharacterVisual",^"WeaponRoot"])
		actors.append(actor)
		bridges.append(bridge)
	var started:=Time.get_ticks_usec()
	var receipts:Array[Dictionary]=[]
	var index:=0
	for visit: int in [PLAN.Visit.WEST,PLAN.Visit.EMPTY_HANGAR,PLAN.Visit.FREIGHT]:
		if visit<current.visit:continue
		if progress.is_valid():progress.call(float(index)/3.0,"正在准备第一章场景...")
		var area=world._plan_region(visit) if visit!=current.visit else current
		while not area.build_steps.is_empty():
			area.prepare_budget(4000)
			await tree.process_frame
			if not _valid(world,generation):return {"cancelled":true}
		if visit==PLAN.Visit.WEST and current.visit<PLAN.Visit.WEST:world.stage_warehouse_people(area)
		area.set_lower(visit!=PLAN.Visit.WEST)
		area.set_live(true)
		if visit==PLAN.Visit.EMPTY_HANGAR:
			area.play_spotlight_reveal(true)
			if is_instance_valid(area.hangar_crew) and is_instance_valid(area.hangar_crew.blood_scenery):area.hangar_crew.blood_scenery.show()
		var before:=_compiles()
		var view_index:=0
		for view:Vector3 in VIEWS[visit]:
			world.camera_rig.global_position=world.to_global(view)+rig_offset
			for i in actors.size():
				actors[i].position=Vector2(view.x+(i-1)*0.8,view.z)*32
				bridges[i].ground_surface_height=view.y
				bridges[i]._process(0.0)
			var squads:Dictionary=area.staged_warehouse_squads if not area.staged_warehouse_squads.is_empty() else (world.warehouse_squads if visit==PLAN.Visit.WEST else {})
			for squad:Array in squads.values():
				for actor:EmployeeEnemy in squad:
					var reference:WeakRef=actor.get_meta(&"depth_visual_bridge")
					if is_instance_valid(reference.get_ref()):reference.get_ref()._process(0.0)
			await _settle(tree)
			if not _valid(world,generation):return {"cancelled":true}
			var capture_path:String=world.get_meta(&"h06_warm_capture","")
			if not capture_path.is_empty() and view_index==0:
				DirAccess.make_dir_recursive_absolute(capture_path)
				world.camera_3d.get_viewport().get_texture().get_image().save_png(capture_path.path_join("visit-%d.png"%visit))
			view_index+=1
		receipts.append({"visit":visit,"pipelines":_compiles()-before})
		area.set_live(false)
		# Warmup shows the prepared blood mesh once, but must not leave it
		# visible in a surviving crew's current or future return scene.
		if is_instance_valid(area.hangar_crew):area.hangar_crew.sync_visibility()
		for squad:Array in area.staged_warehouse_squads.values():
			for actor:EmployeeEnemy in squad:
				actor.room_preview_visible=false
				actor._apply_player_vision_visibility()
				# OTXO sources normally stay visible even in dormant rooms. These
				# future-room actors have not entered gameplay or its source canvas.
				actor.hide()
				actor.remove_from_group(&"dream_enemies")
				actor.remove_from_group(&"employee_enemies")
				var reference:WeakRef=actor.get_meta(&"depth_visual_bridge")
				if is_instance_valid(reference.get_ref()):reference.get_ref().set_room_presentation_active(false)
		if visit>current.visit:world.chapter_staged_regions[visit]=area
		elif area!=current:
			for root:Node in [area.floor_root,area.wall_root,area.lights_root,area.physics_root]:root.queue_free()
		await tree.process_frame
		await tree.process_frame
		if not _valid(world,generation):return {"cancelled":true}
		index+=1
	sources.queue_free()
	await tree.process_frame
	await tree.process_frame
	if not _valid(world,generation):return {"cancelled":true}
	world._content_rng.state=content_rng
	world._rng.state=layout_rng
	current.set_live(true)
	world.player_depth_bridge.visible=player_bridge_visible
	world._sync_height_immediate()
	world.camera_rig.global_transform=saved_rig
	for frame in 3:await tree.process_frame
	if progress.is_valid():progress.call(1.0,"场景准备完成")
	return {"ready":true,"ms":(Time.get_ticks_usec()-started)*0.001,"visits":receipts}
