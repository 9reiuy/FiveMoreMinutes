extends SceneTree
const OUT:="res://.runtime/extinguisher_cloud_20261117"
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func frames(count:int)->void:
	for i in count:await process_frame
func settle(main:Node)->void:
	while main.transition_running:await process_frame
	await frames(12)
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	create_timer(150,true,false,true).timeout.connect(func():quit(2))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var last:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf(float(now-last[0])/1000000.0,0.0,.05))
		last[0]=now)
	root.size=Vector2i(1280,720)
	var settings:Node=root.get_node("SettingsManager")
	settings.set_volume(&"music_volume",70)
	settings.set_setting(&"pixelation_enabled",true)
	var main:Node=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await settle(main)
	main.persistent_day_state=main._create_initial_state()
	main.persistent_day_state.tutorial_completed=true
	main._show_tutorial("basic")
	await settle(main)
	check(not main.current_screen.selective_enabled and main.current_screen.world_viewport.size==Vector2i(1280,720),"actual app tutorial renders natively after an obsolete enable request")
	seed(42001)
	main._show_dream("basic")
	await settle(main)
	var world:Node3D=main._supported_dream_world
	while world.floor_transition_in_progress:await process_frame
	check(is_instance_valid(world) and not main.current_screen.selective_enabled and world.get_viewport().size==Vector2i(1280,720),"actual current campaign entry uses native world rendering")
	check(not settings.is_music_suppressed() and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")),"normal game music remains available outside the whitebox")
	var smoke:Node3D=world.floor_root.get_node("FireExtinguisherSystem")
	check(smoke.get_script().resource_path.ends_with("stylized_extinguisher_system.gd"),"formal entry installs the promoted extinguisher effect by default")
	var tank:Node2D
	for candidate in get_nodes_in_group(&"fire_extinguishers"):
		if world.is_ancestor_of(candidate) and not candidate.broken:tank=candidate;break
	check(is_instance_valid(tank),"formal floor contains an actual wall-mounted extinguisher")
	if not is_instance_valid(tank):
		main.free()
		quit(1)
		return
	world.player.set_physics_process(false)
	world.player.global_position=tank.global_position+tank.inward*64.0
	world.player.velocity=Vector2.ZERO
	world._update_camera_and_actor_projection(10.0)
	for enemy in world.enemy_root.get_children():enemy.set_physics_process(false)
	for i in 2:
		var bullet:Node2D=load("res://scenes/entities/basic_projectile.tscn").instantiate()
		bullet.damage=10
		bullet.direction=tank.inward
		bullet.set_meta(&"shot_height_pixels",40.0)
		world.gameplay_world.add_child(bullet)
		bullet.set_physics_process(false)
		bullet.global_position=tank.global_position
		bullet._handle_collision(tank)
		bullet.queue_free()
	check(tank.broken and smoke.sources.size()>0,"actual campaign bullet-hit path releases the new extinguisher cloud")
	await create_timer(1.0,true,false,true).timeout
	tank.stop_flight()
	check(smoke.cloud_renderer.live_count>0 and smoke.cloud_renderer.lighting.key.is_visible_in_tree(),"campaign cloud and its calibrated style light are active")
	check(smoke.contains(world.player.global_position) and world.player_depth_bridge.smoke_silhouette,"original player-in-smoke silhouette rule remains active")
	var renderer:Node3D=smoke.cloud_renderer
	var bridge:Node3D=world.player_depth_bridge
	renderer.set_process(false)
	renderer.particles.speed_scale=0.0
	renderer.shadow_particles.speed_scale=0.0
	smoke.set_physics_process(false)
	bridge.set_process(false)
	await frames(5)
	await RenderingServer.frame_post_draw
	var with_silhouette:Image=root.get_texture().get_image()
	var overlays:Dictionary={}
	for sprite in [bridge.actor_sprite,bridge.weapon_sprite,bridge.attachment_sprite]:
		if is_instance_valid(sprite):overlays[sprite]=sprite.material_overlay;sprite.material_overlay=null
	await frames(5)
	await RenderingServer.frame_post_draw
	var without_silhouette:Image=root.get_texture().get_image()
	var revealed:=0
	for y in with_silhouette.get_height():
		for x in with_silhouette.get_width():
			var a:=with_silhouette.get_pixel(x,y)
			var b:=without_silhouette.get_pixel(x,y)
			if maxf(a.r,maxf(a.g,a.b))<.08 and minf(b.r,minf(b.g,b.b))>.2:revealed+=1
	check(revealed>40,"actual Camera shows the player's black silhouette through cloud geometry")
	for sprite in overlays:
		if is_instance_valid(sprite):sprite.material_overlay=overlays[sprite]
	bridge.set_process(true)
	smoke.set_physics_process(true)
	renderer.set_process(true)
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/formal_campaign.png")
	paused=true
	await frames(6)
	check(smoke.cloud_renderer.particles.speed_scale==0.0 and smoke.cloud_renderer.shadow_particles.speed_scale==0.0,"game pause freezes both cloud geometry and its shadow state")
	paused=false
	await frames(6)
	check(smoke.cloud_renderer.particles.speed_scale==1.0,"game resume restores cloud motion")
	var old_renderer:WeakRef=weakref(smoke.cloud_renderer)
	var old_floor:int=world.floor_index
	var source_age:float=smoke.sources[0].age
	world.floor_transition_in_progress=true
	world._stash_current_floor_for_rollback()
	await frames(3)
	check(old_renderer.get_ref()!=null and smoke.cloud_renderer.particles.speed_scale==0.0,"stashing a floor preserves and suspends its existing particle pool")
	world._reset_layout_data()
	world._rollback_failed_transition(world.transition_generation_token,old_floor)
	world.floor_transition_in_progress=false
	await frames(6)
	check(old_renderer.get_ref()==smoke.cloud_renderer and smoke.cloud_renderer.lighting.key.is_visible_in_tree() and smoke.sources[0].age>=source_age,"failed transition restores the same cloud and lighting lease")
	check(world.regenerate(42002),"formal floor can be regenerated with the promoted effect")
	await frames(8)
	check(old_renderer.get_ref()==null and world.floor_root.get_node("FireExtinguisherSystem").cloud_renderer.live_count==0,"successful transition releases old particles and starts an empty new floor")
	var report:Dictionary={"checks":checks,"failures":failures,"pid":OS.get_process_id(),"scope":"actual app tutorial and current campaign entry plus rollback/reset; not whole-game performance certification","master_muted":AudioServer.is_bus_mute(0)}
	FileAccess.open(OUT+"/formal_result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	main.free()
	await frames(12)
	print("EXTINGUISHER_FORMAL checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
