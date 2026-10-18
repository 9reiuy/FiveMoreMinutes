extends "res://tests/nyangeon_vfx_sample_delivery.gd"
const PROJECTION=preload("res://scripts/dream/character_visual_projection.gd")
const FEEDBACK=preload("res://scripts/entities/combat_feedback_effect.gd")
func bridge_of(source:Node)->Node:
	var reference: WeakRef=source.get_meta(&"depth_visual_bridge")
	return reference.get_ref()
func run()->void:
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		await RenderingServer.frame_post_draw
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Formal Main entry ready")
	if not is_instance_valid(world): quit(1); return
	var time:Node=root.get_node_or_null("DreamTimeController")
	if time!=null: time.set_process(false)
	Engine.time_scale=1
	var origin:=Vector2.ZERO; var room_id:=-1
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point:=Vector2(cell)*32
			if world._content_position_is_clear(point,75): origin=point; room_id=room.id; break
		if room_id>=0: break
	check(room_id>=0,"Natural office used")
	if room_id<0: main.free(); quit(1); return
	world.activate_room(room_id)
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	var enemy:Node=world._spawn_regular_employee(room_id,origin+Vector2(45,20),&"employee",false,"basic")
	enemy.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE; enemy.hurtbox.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.process_mode=Node.PROCESS_MODE_DISABLED; enemy.sky_drop_active=false; enemy.sky_drop_height=0; enemy.knockdown_height=0
	enemy.set_room_runtime_active(true); enemy.set_player_vision_visible(true); enemy.current_health=1000
	actors=[enemy]; walkers=Walkers.new(); walkers.actors=actors; world.add_child(walkers)
	world.player.global_position=origin+Vector2(-50,20); world.player.set_attacking_enabled(false)
	await wait(.8)
	for corrected in [false,true]:
		begin("after" if corrected else "before")
		for heading in [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN]:
			enemy.take_damage(1,enemy.global_position-heading*20,0,&"player_projectile_basic")
			var effects: Array=world.world_effects_root.get_children().filter(func(n:Node)->bool:return n.get_script()==FEEDBACK)
			var source:Node=effects.back(); var bridge:Node=bridge_of(source)
			if not corrected:
				# Reproduce the pre-fix pool's material and billboard policy only.
				bridge.projectile_material=null; bridge.actor_sprite.material_override=null
				bridge.camera_plane_visual=false; bridge.actor_sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			else:
				var normal:Vector3=source.get_meta(&"hit_reference_plane_normal")
				var plane:Vector3=source.get_meta(&"hit_reference_plane_origin")
				var body:Node=bridge_of(enemy)
				check(bridge.projectile_material==bridge.feedback_material and bridge.camera_plane_visual,"Pooled hit switches material and camera policy")
				check(bridge.projectile_material.get_shader_parameter("reference_plane_normal").is_equal_approx(normal),"GPU material uses body-parallel depth plane")
				for y in [-18,0,18]:
					var colour:Vector3=source.get_meta(&"shot_visual_origin")+world.camera_3d.global_basis.y*y/32.0
					var hit:Vector3=PROJECTION.intersect_reference_plane(world.camera_3d,colour,plane,normal)
					var torso:Vector3=PROJECTION.intersect_reference_plane(world.camera_3d,colour,body.body_reference_origin,body.body_reference_normal)
					check(world.camera_3d.global_position.distance_to(hit)<world.camera_3d.global_position.distance_to(torso),"Upper/center/lower hit pixels remain in front of body")
			await wait(.5)
		finish()
	# Exercise a reused slot across hit -> melee -> hit, without new capture slots.
	var pool:Node=world._get_feedback_capture_pool()
	var allocated:int=pool.created
	var reused:Node
	for projected in [true,false,true]:
		if is_instance_valid(reused): pool.idle.erase(reused); pool.idle.push_front(reused)
		world.spawn_combat_feedback(enemy.global_position,Vector2.RIGHT,false,projected,enemy)
		var source:Node=world.world_effects_root.get_children().filter(func(n:Node)->bool:return n.get_script()==FEEDBACK).back()
		var bridge:Node=bridge_of(source)
		check(reused==null or bridge==reused,"Same capture slot is actually reused across hit and melee")
		reused=bridge
		check((bridge.projectile_material!=null)==projected,"Pool resets reference material for legacy feedback")
		source.queue_free(); await wait(.03)
	check(pool.created==allocated,"Alternating hit and melee keeps capture allocation bounded")
	world.spawn_combat_feedback(enemy.global_position,Vector2.RIGHT,false,true,enemy)
	var effect:Node=world.world_effects_root.get_children().filter(func(n:Node)->bool:return n.get_script()==FEEDBACK).back()
	var carrier:Node=bridge_of(effect)
	paused=true
	var wall:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(2.5,2.5,.04); wall.mesh=box
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(.1,.6,.2); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; wall.material_override=material
	world.add_child(wall); wall.global_basis=world.camera_3d.global_basis
	wall.global_position=effect.get_meta(&"shot_visual_origin")+world.camera_3d.global_basis.z*1.5
	await wait(.08)
	var with_effect:Image=root.get_texture().get_image()
	with_effect.save_png(output+"/wall_occlusion.png")
	carrier.actor_sprite.visible=false; await wait(.08)
	var without_effect:Image=root.get_texture().get_image()
	check(with_effect.get_data()==without_effect.get_data(),"Foreground wall occludes the hit; effect is not an always-on-top overlay")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"Delivery remains minimized")
	var report:={"checks":checks,"failures":failures,"clips":clips,"metrics":{},"scope":"Actual Main Camera, real enemy gun-damage entry, three incoming directions; only legacy carrier policy is simulated for before. No gameplay values changed."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("HIT_FEEDBACK_DEPTH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	paused=false; main.free(); quit(1 if failures.size() else 0)
