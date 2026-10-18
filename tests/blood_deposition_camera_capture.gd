extends SceneTree
## Actual Main, configured enemy, natural death updates and floor presentation.
## Capture every rendered frame around landing; no manual pool/corpse stepping.
var output := "res://.runtime/blood_touchdown_timing_20261014/camera"
var radial := false
var world: Node
var main: Node
var samples: Array[Dictionary] = []
var checks := 0
var failures := 0
var drag_capture := false
var drag_direction := Vector2(-1,0.3).normalized()
var drag_origin := Vector2.ZERO
var contact_impulses := 0
var launch_start := Vector2.ZERO
var launch_speed := 0.0
var launch_displacement := 0.0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output=argument.trim_prefix("--artifact-dir=").replace("\\", "/")
	radial = "--radial-before" in OS.get_cmdline_user_args()
	drag_capture = "--drag-capture" in OS.get_cmdline_user_args()
	node_added.connect(func(node: Node) -> void:
		if node is BlackBloodEffect: node.set_meta(&"test_radial_pool_reveal",radial)
		if node is BlackBloodEffect and radial: restore_radial_duration.call_deferred(node)
		if node.get_script()!=null and node.get_script().resource_path=="res://scripts/dream/dream_3d_random_dungeon.gd": node.persist_profile=false
	)
	call_deferred("run")
func restore_radial_duration(blood: BlackBloodEffect) -> void:
	if is_instance_valid(blood) and blood.office_pool_core: blood.pool_growth_duration=1.2
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int) -> void:
	for index in count: await RenderingServer.frame_post_draw
func save_frame(enemy: EmployeeEnemy, index: int) -> void:
	var filename := "frame_%03d.png" % index
	var image := root.get_texture().get_image()
	image.save_png(output+"/"+filename)
	var cells := 0
	var pool_elapsed := -1.0
	var airborne := 0
	var landed_drops := 0
	var max_height := 0.0
	var visible_instances := 0
	var captured_ground_cells := 0
	var drag_segments := 0
	var floor_capture_cells := 0
	var attachment_error := -1.0
	var attachment_offset := 0.0
	var actor_ref: Variant = enemy.get_meta(&"depth_visual_bridge", null)
	var actor_bridge: Node = actor_ref.get_ref() if actor_ref is WeakRef else null
	if enemy.death_landed and is_instance_valid(actor_bridge):
		var contact: Vector2 = enemy.get_corpse_blood_ground_position()
		attachment_offset = contact.distance_to(enemy.global_position)
		var camera: Camera3D = actor_bridge._active_world_camera()
		var torso: Sprite2D = enemy.get_node(^"CharacterVisual/BodyPivot/Body")
		var local_point: Vector2 = enemy.to_local(torso.to_global(actor_bridge._opaque_rect(torso).get_center())) + actor_bridge.viewport_offset - Vector2(actor_bridge.render_viewport.size)*0.5
		var colour: Vector3 = actor_bridge.actor_sprite.global_transform * (Vector3(local_point.x,-local_point.y,0)/32.0)
		var floor_world: Vector3 = actor_bridge.get_parent_node_3d().to_global(Vector3(contact.x/32.0,0,contact.y/32.0))
		attachment_error = camera.unproject_position(colour).distance_to(camera.unproject_position(floor_world))
	for emitter in get_nodes_in_group(&"corpse_blood_emitters"):
		drag_segments += int(emitter.get("_drag_segments"))
	for effect in world.world_effects_root.get_children():
		if effect is BlackBloodEffect:
			var floor_ref: Variant = effect.get_meta(&"depth_visual_bridge", null)
			var floor_bridge: Node = floor_ref.get_ref() if floor_ref is WeakRef else null
			if is_instance_valid(floor_bridge) and not floor_bridge.clone_roots.is_empty():
				floor_capture_cells += floor_bridge.clone_roots[0].ground_pixels.size()
		if effect is BlackBloodEffect and effect.office_pool_core:
			cells+=effect.ground_pixels.size()
			pool_elapsed=maxf(pool_elapsed,effect.pool_growth_elapsed)
		if effect is BlackBloodEffect and effect.ballistic_death_spray:
			airborne+=effect.airborne_pixels.size(); landed_drops+=effect.landed_death_droplets
			for particle in effect.airborne_pixels: max_height=maxf(max_height,float(particle.height))
			var reference: Variant=effect.get_meta(&"blood_airborne_carrier",null)
			var carrier: Node=reference.get_ref() if reference is WeakRef else null
			if is_instance_valid(carrier) and carrier.multi_mesh!=null: visible_instances+=carrier.multi_mesh.visible_instance_count
			var bridge_ref: Variant=effect.get_meta(&"depth_visual_bridge",null)
			var bridge: Node=bridge_ref.get_ref() if bridge_ref is WeakRef else null
			if is_instance_valid(bridge) and not bridge.clone_roots.is_empty(): captured_ground_cells+=bridge.clone_roots[0].ground_pixels.size()
	if contact_impulses==0: launch_displacement=maxf(launch_displacement,enemy.global_position.distance_to(launch_start))
	samples.append({"file":filename,"game_seconds":enemy.corpse_elapsed_time,"landed":enemy.death_landed,"pool_elapsed":pool_elapsed,"cells":cells,"airborne":airborne,"landed_droplets":landed_drops,"max_height_pixels":max_height,"gpu_instances":visible_instances,"ground_capture_cells":captured_ground_cells,"player_visible":world.player.visual.visible,"player_alpha":world.player.visual.modulate.a,"corpse_position":enemy.global_position,"contact_impulses":contact_impulses,"death_launch_displacement":launch_displacement,"drag_segments":drag_segments,"floor_capture_cells":floor_capture_cells,"attachment_screen_error":attachment_error,"attachment_offset_pixels":attachment_offset})
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Real GPU required"); quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Main entry completes")
	if failures>0: quit(1); return
	var origin: Vector2=world.player.global_position
	var room_id: int=world.current_room_id
	var found := false
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point := Vector2(cell)*32.0
			if world._content_position_is_clear(point,65.0) and world._content_position_is_clear(point+Vector2(0,80),12.0):
				if drag_capture:
					var clear_direction := Vector2.ZERO
					for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
						if world._content_position_is_clear(point+direction*60,18.0) and world._content_position_is_clear(point+direction*120,18.0): clear_direction=direction; break
					if clear_direction==Vector2.ZERO: continue
					drag_direction=clear_direction
				origin=point; room_id=int(room.id); found=true; break
		if found: break
	check(found,"Natural open office capture location")
	world.player.global_position=origin+Vector2(0,80)
	# Other enemies are disabled below; do not misuse hurt invulnerability as
	# fixture protection, since its visual contract intentionally blinks.
	world.player.invulnerability_left=0.0; world.player.invulnerability_reason=&""
	world.player.hurt_flash_left=0.0; world.player.revive_flash_left=0.0
	world.player.movement_enabled=false; world.player.set_attacking_enabled(false)
	world.activate_room(room_id)
	var enemy: EmployeeEnemy
	for actor in world.enemy_root.get_children():
		actor.process_mode=Node.PROCESS_MODE_DISABLED
		if enemy==null and actor is EmployeeEnemy and int(actor.get_meta(&"dream_room_id",-1))==room_id: enemy=actor
	check(enemy!=null,"Configured production enemy exists")
	if failures>0: main.free(); quit(1); return
	enemy.global_position=origin
	await frames(25)
	root.get_texture().get_image().save_png(output+"/clean.png")
	world._content_rng.seed=73013; enemy.random.seed=23940
	enemy.process_mode=Node.PROCESS_MODE_INHERIT
	await physics_frame; await physics_frame
	var shot_origin: Vector2=world.player.get_aim_origin()
	var aim_point: Vector2=enemy.hurtbox_collision.global_position
	var projectile=load("res://scenes/entities/basic_projectile.tscn").instantiate()
	projectile.setup((aim_point-shot_origin).normalized(),enemy.current_health+1.0,270.0,1500.0,&"player",world.player,&"assault_rifle")
	world.add_projectile(projectile,world.player)
	projectile.global_position=shot_origin
	for frame in 12:
		await frames(1)
		if enemy.dead: break
	print("PROJECTILE_DEATH_PROBE ",JSON.stringify({"dead":enemy.dead,"source":enemy.death_burst_source,"health":enemy.current_health,"room_active":enemy.room_runtime_active,"hurtbox_disabled":enemy.hurtbox_collision.disabled,"shot_origin":shot_origin,"aim_point":aim_point}))
	check(enemy.dead and enemy.death_burst_source==&"player_projectile_assault_rifle","Real projectile collision starts gun death presentation")
	if failures>0: main.free(); quit(1); return
	launch_start=enemy.death_origin_gameplay_position
	launch_speed=enemy.death_ground_velocity.length()
	# Keep normal enemy, emitter and blood _process updates throughout.
	for index in (420 if drag_capture else 180):
		await frames(1)
		if index<75 or index%3==0: save_frame(enemy,index)
		if drag_capture and enemy.corpse_elapsed_time>=2.6:
			if contact_impulses==0: drag_origin=enemy.global_position
			# Controlled contact input; movement, collision, emitter and ragdoll
			# remain the production simulation. Never assign the corpse position.
			if contact_impulses<3 and enemy.corpse_elapsed_time>=2.6+float(contact_impulses)*0.8:
				enemy.receive_corpse_contact(drag_direction*220.0); contact_impulses+=1
		if enemy.corpse_elapsed_time>=(6.3 if drag_capture else 2.6): break
	check(enemy.death_pool_spawned and enemy.corpse_bleed_spawned,"Natural landing produces pool and follow bleed")
	check(samples.any(func(sample: Dictionary) -> bool: return sample.cells>0),"Rendered sequence includes real death pool")
	check(samples.any(func(sample: Dictionary) -> bool: return sample.airborne>0 and sample.gpu_instances>0 and sample.max_height_pixels>8.0),"Camera sequence includes uploaded airborne death droplets")
	check(samples.any(func(sample: Dictionary) -> bool: return sample.landed_droplets>0 and sample.airborne>0),"Camera sequence includes staggered touchdown")
	check(samples.any(func(sample: Dictionary) -> bool: return sample.game_seconds<.15 and sample.landed_droplets>0 and sample.ground_capture_cells>0),"Early touchdown reaches actual ground capture while other droplets fly")
	check(samples.all(func(sample: Dictionary) -> bool: return sample.player_visible and is_equal_approx(sample.player_alpha,1.0)),"Player remains opaque and visible throughout the visual fixture")
	check(launch_displacement>40,"Actual lethal projectile displaces entire corpse before any later contact input")
	var landing_frames := samples.filter(func(sample: Dictionary) -> bool: return sample.landed)
	var drag_frames := samples.filter(func(sample: Dictionary) -> bool: return sample.drag_segments>0)
	check(not drag_frames.is_empty() and not landing_frames.is_empty() and float(drag_frames[0].game_seconds)-float(landing_frames[0].game_seconds)<=2.0/60.0+0.0001,"First real sliding stroke is generated within two frames of landing")
	check(samples.all(func(sample: Dictionary) -> bool: return sample.landed or sample.drag_segments==0),"Airborne corpse never creates a ground rubbing trail")
	check(landing_frames.all(func(sample: Dictionary) -> bool: return sample.attachment_screen_error>=0 and sample.attachment_screen_error<4.0),"Projected torso contact stays within one simulation frame of rendered body")
	check(landing_frames.any(func(sample: Dictionary) -> bool: return sample.attachment_offset_pixels>12.0),"Prone torso attachment corrects the visibly separated collision-root anchor")
	if drag_capture: check(enemy.global_position.distance_to(drag_origin)>70.0,"Production corpse contact simulation moves far enough to show a drag band")
	root.get_texture().get_image().save_png(output+"/final.png")
	var report := {"radial_before":radial,"main_entry":true,"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"resolution":[1920,1080],"real_projectile_collision":true,"fixture_projectile_damage":"enemy health + 1","damage_source":enemy.death_burst_source,"natural_death_updates":true,"manual_pool_or_corpse_steps":false,"controlled_contact_impulses":contact_impulses,"drag_direction":drag_direction,"fixed_timestep_visual_capture":true,"origin":origin,"samples":samples,"checks":checks,"failures":failures,"performance_claim":false}
	report["initial_launch_speed"]=launch_speed; report["death_launch_displacement"]=launch_displacement
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("BLOOD_DEPOSITION_CAMERA_CHECKS=",checks," FAILURES=",failures," samples=",samples.size())
	main.free(); quit(0 if failures==0 else 1)
