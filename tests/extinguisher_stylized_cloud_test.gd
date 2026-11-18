extends SceneTree
const OUT:="res://.runtime/extinguisher_cloud_20261117"
const TANK:=preload("res://scripts/dream/fire_extinguisher.gd")
const BULLET:=preload("res://scenes/entities/basic_projectile.tscn")
class Lab:
	extends "res://scripts/testing/game_test_lab.gd"
	var candidate:=true
	var art:=false
	func _ready()->void:
		super._ready()
		enemies.value=8 if art else 2
		checks.ai.button_pressed=false
		checks.furniture.button_pressed=art
		mode.select(1 if art else 0)
	func _instantiate_world()->Node3D:
		var instance:Node3D=super._instantiate_world()
		instance.set_meta(&"test_stylized_extinguisher",candidate)
		return instance
var settings:Node
var lab:Control
var smoke:Node3D
var checks:=0
var failures:Array[String]=[]
var result:Dictionary={}
var metrics:FileAccess
var aim:=Vector2.ZERO

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func frames(count:int)->void:
	for i in count:await process_frame
func capture(name:String)->void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+name+".png")
func open_lab(candidate:bool,art:bool)->void:
	if is_instance_valid(lab):
		lab.free()
		await frames(5)
	lab=Lab.new()
	lab.candidate=candidate
	lab.art=art
	root.add_child(lab)
	while not lab.ready_world or lab.busy:await process_frame
	lab.panel.hide()
	lab.hud.hide()
	smoke=lab.world.floor_root.get_node("FireExtinguisherSystem")
	await frames(50)
func break_tank(at:Vector2,moving:=false)->Node2D:
	var tank:Node2D=TANK.new()
	tank.world=lab.world
	tank.controller=smoke
	tank.position=at
	lab.world.key_root.add_child(tank)
	for i in 2:
		var bullet:Node2D=BULLET.instantiate()
		bullet.damage=10
		bullet.direction=Vector2.RIGHT
		bullet.set_meta(&"shot_height_pixels",40.0)
		lab.world.gameplay_world.add_child(bullet)
		bullet.set_physics_process(false)
		bullet.global_position=at
		bullet._handle_collision(tank)
		bullet.queue_free()
	if not moving:tank.stop_flight()
	tank._sync_visual()
	return tank
func record_clip(folder:String,seconds:float)->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"/"+folder))
	var times:Array[int]=[]
	for index in ceili(seconds*12):
		await create_timer(1.0/12,true,false,true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"/"+folder+"/%03d.png"%index)
		times.append(Time.get_ticks_msec())
	FileAccess.open(OUT+"/"+folder+"/timestamps.json",FileAccess.WRITE).store_string(JSON.stringify(times))
func measure(pass_id:int,candidate:bool,stage:String,count:int)->void:
	var last:=Time.get_ticks_usec()
	for frame in count:
		if stage=="first" and frame==0:break_tank(lab.world.player.global_position+Vector2(0,-64))
		if stage=="repeat" and frame in [0,45,90]:break_tank(lab.world.player.global_position+Vector2(-48+frame, -48))
		await process_frame
		var now:=Time.get_ticks_usec()
		metrics.store_line("%d,%s,%s,%d,%.3f"%[pass_id,candidate,stage,frame,(now-last)/1000.0])
		last=now

func verify_native_and_music()->void:
	check(not lab.checks.has("pixels") and lab.display.world_viewport.size==Vector2i(1280,720),"whitebox has native resolution and no pixelation control")
	lab.display.set_selective_enabled(true)
	settings.set_setting(&"pixelation_enabled",true)
	await frames(4)
	check(not lab.display.selective_enabled and lab.display.world_viewport.size==Vector2i(1280,720) and not settings.get_setting(&"pixelation_enabled",true),"retired API calls and old settings cannot enable pixelation")
	var cfg:=ConfigFile.new()
	cfg.set_value("audio","master_volume",0)
	cfg.set_value("audio","music_volume",70)
	cfg.set_value("audio","sfx_volume",80)
	cfg.set_value("graphics","pixelation_enabled",true)
	cfg.set_value("graphics","native_resolution_default_applied",true)
	cfg.save(OUT+"/legacy_settings.cfg")
	settings._load_settings(OUT+"/legacy_settings.cfg")
	settings._apply_all_audio()
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	check(not settings.get_setting(&"pixelation_enabled",true),"loading a legacy enabled profile retains native rendering")
	var saved:=ConfigFile.new()
	saved.load(OUT+"/legacy_settings.cfg")
	check(not saved.has_section_key("graphics","pixelation_enabled"),"obsolete pixelation key is removed when migrating the profile")
	settings.set_volume(&"music_volume",100)
	preload("res://scripts/audio/sfx_manager.gd").play_battle_music()
	await frames(4)
	var sfx:Node=root.get_node("SFXManager")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")) and not sfx.music_player.playing,"whitebox blocks background music even after changing music volume")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),"music suppression preserves the sound-effects bus")
	var panel:Control=load("res://scenes/ui/settings_panel.tscn").instantiate()
	root.add_child(panel)
	check(not panel.has_node("Rows/Pixelation"),"main settings menu no longer contains pixelation")
	panel.free()
	var phone:Control=load("res://scripts/ui/phone_settings_screen.gd").new()
	phone._page=&"graphics"
	var rows:Array=phone._rows()
	check(rows.size()==1 and rows[0][0]==&"shadow_quality","phone graphics settings retain shadow quality without pixelation")
	phone.free()

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	create_timer(210,true,false,true).timeout.connect(func():quit(2))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var last:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf(float(now-last[0])/1000000.0,0.0,.05))
		last[0]=now)
	root.size=Vector2i(1280,720)
	settings=root.get_node("SettingsManager")
	await open_lab(true,false)
	await verify_native_and_music()
	check(smoke.get_script().resource_path.ends_with("stylized_extinguisher_system.gd"),"candidate uses the original rules with the new cloud presentation")
	var tank:=break_tank(lab.world.player.global_position+Vector2(0,-64),true)
	check(tank.broken and tank.flying and smoke.sources.size()==1,"two real bullet hits break the extinguisher and start its original flight")
	await record_clip("break",1.6)
	tank.stop_flight()
	await create_timer(.4,true,false,true).timeout
	check(smoke.cloud_renderer.live_count>0 and smoke.cloud_renderer.live_count<=280,"one bounded native particle pool represents the live release")
	check(smoke.cloud_renderer.lighting.key.is_visible_in_tree(),"sparse lighting preserves the cloud-only style key")
	check(smoke.cloud_renderer.shadow_particles.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and smoke.cloud_renderer.shadow_particles.process_material==smoke.cloud_renderer.particles.process_material,"synchronized shadow mesh keeps real light projection without changing the visible cloud mesh")
	check(smoke.banks.is_empty() and smoke.outer_banks.is_empty(),"old smoke cards and outer-outline passes are absent")
	check(smoke.cells.size()<=smoke.smallest_room_cells,"existing room-area coverage budget remains unchanged")
	var stable:Dictionary=smoke.cloud_renderer.slots.duplicate(true)
	await record_clip("idle",1.5)
	check(stable==smoke.cloud_renderer.slots,"settled parcels keep their identities instead of cycling their emission")
	var before:int=smoke.cloud_renderer.serial
	smoke.disperse_segment(lab.world.player.global_position,lab.world.player.global_position+Vector2(0,-128))
	check(smoke.cloud_renderer.serial>before,"live projectile segments feed native parcel impulses")
	await capture("whitebox")
	var player:Node2D=lab.world.player
	var walk_start:=player.global_position
	var best:=INF
	for cell:Vector2i in smoke.cells:
		var point:=Vector2(cell)*32.0
		if not smoke.cells.has(cell+Vector2i.UP) or not lab.world._content_position_is_clear(point,18.0,false):continue
		var distance:=point.distance_squared_to(player.global_position)
		if distance<best:best=distance;walk_start=point
	player.global_position=walk_start
	player.velocity=Vector2.ZERO
	smoke.cloud_renderer.last_positions.clear()
	lab.world._update_camera_and_actor_projection(10.0)
	await frames(3)
	var walk_serial:int=smoke.cloud_renderer.serial
	player.set_scripted_locomotion(Vector2.UP,player.movement_speed)
	await record_clip("walk",.6)
	player.clear_scripted_locomotion()
	check(player.global_position.distance_to(walk_start)>30 and smoke.cloud_renderer.serial>walk_serial,"real character movement contributes parcel disturbances")
	player.dash_charges=player.max_dash_charges
	player.dash_cooldown_left=0.0
	var rolled:bool=player.try_start_phase_dash(Vector2.RIGHT,true)
	await record_clip("roll",1.0)
	check(rolled and not player.dashing,"the existing dive roll finishes while interacting with the cloud")
	for source:Dictionary in smoke.sources:source.age=smoke.DURATION-.1
	smoke.advance(.2)
	smoke.upload_puffs()
	await frames(5)
	check(smoke.sources.is_empty() and smoke.cells.is_empty() and smoke.cloud_renderer.live_count==0,"twelve-second expiry clears gameplay coverage and native parcels together")
	var old:WeakRef=weakref(smoke.cloud_renderer)
	await lab.rebuild()
	check(old.get_ref()==null and lab.world.floor_root.get_node("FireExtinguisherSystem").cloud_renderer.live_count==0,"reset frees the old particle pool and leaves the new floor empty")
	# Paired native-resolution production-art windows: baseline, cold event,
	# repeated event, then actual gunfire. No Camera readbacks in timing windows.
	metrics=FileAccess.open(OUT+"/frame_times.csv",FileAccess.WRITE)
	metrics.store_line("pass,candidate,stage,frame,wall_ms")
	for pass_id in 2:
		for candidate:bool in ([false,true] if pass_id==0 else [true,false]):
			await open_lab(candidate,true)
			lab.world.player.set_physics_process(false)
			await measure(pass_id,candidate,"baseline",120)
			await measure(pass_id,candidate,"first",180)
			await measure(pass_id,candidate,"repeat",180)
			lab.world.player.set_physics_process(true)
			aim=lab.world.player.global_position+Vector2(0,-160)
			lab.world.player.set_meta(&"presentation_pointer_position",func()->Vector2:return lab.world.camera_3d.unproject_position(lab.world.get_gameplay_world_position(aim,.65)))
			lab.world.player.set_meta(&"force_weapon_attack",true)
			await measure(pass_id,candidate,"gunfire",180)
			lab.world.player.remove_meta(&"force_weapon_attack")
			check(lab.shot_count>0,"combined production-art workload includes real firearm shots")
			if candidate:
				await capture("production_art_pass%d"%pass_id)
				check(smoke.cloud_renderer.live_count<=280 and smoke.sources.size()<=8,"repeated releases share the same bounded pool")
	metrics.close()
	result={"checks":checks,"failures":failures,"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"audio":AudioServer.get_driver_name(),"private_master_muted":AudioServer.is_bus_mute(0),"world_viewport":str(lab.display.world_viewport.size),"scope":"candidate test-lab admission, native resolution, whitebox plus fixed production-art layout; not whole-game certification"}
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	lab.free()
	await frames(10)
	check(not settings.is_music_suppressed(),"leaving the whitebox releases its music-suppression scope")
	result.checks=checks
	result.failures=failures
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("EXTINGUISHER_CLOUD_GATE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
