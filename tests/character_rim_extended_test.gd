extends SceneTree
## Real Camera evidence and bounded ABBA wall-frame sampling. No campaign edits.
const RECORDER := preload("res://scripts/testing/lab_recorder.gd")
const ATLAS := preload("res://scripts/data/player_character_atlas.gd")
var lab: Control
var sample: Control
var out := "res://.runtime/character_rim_20261113/extended"
var failures: Array[String] = []
var checks := 0
var events: Array = []
var perf: Array = []
var hair_records: Array = []

func _init() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL ",label)
func shot(path: String) -> Image:
	await frames(2); await RenderingServer.frame_post_draw
	var result: Image = sample.display.world_viewport.get_texture().get_image()
	result.save_png(out.path_join(path+".png")); return result
func sync() -> void:
	for bridge in sample.role_bridges:
		if is_instance_valid(bridge): bridge._process(0.0)
func freeze_world() -> void:
	sample.set_frozen(true); sample.world.set_process(false)
	for actor in sample.world.enemy_root.get_children(): actor.process_mode = Node.PROCESS_MODE_DISABLED
func screen_map(direction: Vector2) -> Vector2:
	var flat_back: Vector3 = Vector3(sample.camera_back.x,0,sample.camera_back.z).normalized()
	var d: Vector3 = sample.world.global_basis.inverse()*(sample.camera_right*direction.x+flat_back*direction.y)
	return Vector2(d.x,d.z).normalized()
func pose(t: float, facing: Vector2) -> void:
	var player: Node2D = sample.world.player
	player.set_meta(&"aim_direction_override",facing)
	player.global_position = Vector2(6,7)*32+Vector2(sin(t*1.4)*21,cos(t*1.4)*12)
	player.velocity = Vector2(90,0)
	player._update_direction_animation(player.velocity,0.05)
	player._update_held_weapon_aim(); player._update_visual_feedback()
	# Freezing the player also freezes its child physics callbacks. Advancing
	# only the body leaves the fringe on the previous view's root/layer.
	# Run the existing production hair updater on the SAME pose timestamp.
	player.get_node("CharacterVisual/BodyPivot/Head/SideBangs").step_actor(0.05)
	sample.enemy.weapon_root.rotation = facing.angle()
	sample.enemy.velocity = Vector2(90,0)
	sample.enemy._update_human_animation(0.05)
	sync()

func run() -> void:
	create_timer(240.0,true,false,true).timeout.connect(func(): push_error("Rim extended test timeout"); quit(2))
	if "--promotion" in OS.get_cmdline_user_args(): out="res://.runtime/character_rim_promotion_20261113/animation"
	DirAccess.make_dir_recursive_absolute(out.path_join("motion"))
	Engine.max_fps = 0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var controller := root.get_node_or_null("DreamTimeController")
	if controller != null:
		controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false)
		controller.set_process(false); controller.set_physics_process(false)
	Engine.time_scale = 1.0
	lab = load("res://scenes/testing/CharacterRimLab.tscn").instantiate(); root.add_child(lab)
	await frames(2); sample = lab.presentation
	for i in 900:
		if sample.ready_world: break
		await frames(1)
	check(sample.ready_world,"production art sample ready")
	if not sample.ready_world: quit(2); return
	freeze_world(); await frames(80)
	check(sample.world.furniture_root.get_child_count()>0,"approved production furniture and real collision are present")
	sample.set_enabled(false); await shot("overall_before")
	sample.set_enabled(true); await shot("overall_after")
	# Each timestamp advances the existing walk animation by exactly 1/20 s.
	# Paired images use an unchanged pose and original actual Camera.
	for frame in 120:
		var direction := Vector2.DOWN.rotated(float((frame/10)%8)*TAU/8)
		pose(frame*0.05,screen_map(direction))
		sample.set_light(1 if frame<80 else (2 if frame<100 else 3))
		sample.set_enabled(false)
		var original := await shot("motion/before_%03d"%frame)
		var source: Image = sample.world.player_depth_bridge.render_viewport.get_texture().get_image()
		sample.set_enabled(true); await shot("motion/after_%03d"%frame)
		var source_after: Image = sample.world.player_depth_bridge.render_viewport.get_texture().get_image()
		if frame%10 == 0:
			check(source.get_data()==source_after.get_data(),"source pose/alpha unchanged at direction step %d"%(frame/10))
			check(original.get_width()==640 and original.get_height()==360,"native Camera resolution step %d"%(frame/10))
			var actor: Node = sample.world.player
			var hair: Node2D = actor.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
			var copy: Node2D = sample.world.player_depth_bridge.render_root.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
			var facing: int = actor.character_facing_index
			check(hair.position==ATLAS.bangs_root(facing),"recorded hair uses current authored facing anchor %d"%facing)
			check(hair.z_index==ATLAS.bangs_layer(facing),"recorded hair uses current facing front/back layer %d"%facing)
			check(hair.scale==Vector2(-1 if ATLAS.bangs_mirrored(facing) else 1,1),"recorded hair uses current facing mirror %d"%facing)
			check(copy.transform==hair.transform and copy.z_index==hair.z_index,"GPU capture has synchronized source fringe %d"%facing)
			hair_records.append({"frame":frame,"facing":facing,"root":str(hair.position),"layer":hair.z_index,"mirrored":hair.scale.x<0,"capture_matches":copy.transform==hair.transform and copy.z_index==hair.z_index})
	events.append({"kind":"walk_eight_directions","timestamps":120,"simulation_delta":0.05,"playback_fps":20,"paired_same_pose":true})
	if "--visual-only" in OS.get_cmdline_user_args():
		var corrected := {"checks":checks,"failures":failures,"events":events,"hair":hair_records,"renderer":RenderingServer.get_current_rendering_method(),"scope":"capture synchronization only; original player hair updater, atlas roots, art and lit shaders unchanged"}
		FileAccess.open("res://.runtime/character_rim_20261113/bangs_correction/result.json",FileAccess.WRITE).store_string(JSON.stringify(corrected,"\t"))
		print("RIM_BANGS_CORRECTION ",JSON.stringify({"checks":checks,"failures":failures,"poses":hair_records.size()}))
		lab.free(); await frames(10); quit(0 if failures.is_empty() else 1); return
	# Exercise the original roll and melee pose callbacks, including recovery.
	var player: Node = sample.world.player
	player.equip_weapon("lucille",sample.world.config,{})
	for i in 21:
		player.apply_melee_swing_snapshot({"weapon_id":"lucille","direction":Vector2.RIGHT,"elapsed":i/20.0*0.5,"duration":0.5})
		sync(); await frames(2)
	player.finish_melee_swing_snapshot()
	player.dash_roll_direction = Vector2.RIGHT
	for i in 21:
		player._update_dash_roll_visual(i/20.0); sync(); await frames(2)
	player._finish_dash_roll_visual(); player._update_direction_animation(Vector2.ZERO,0.0)
	sync(); await shot("action_recovery")
	check(player.visual.scale.is_finite(),"existing melee/roll pose callbacks and recovery remain finite")
	for bridge in sample.role_bridges:
		check(bridge.actor_sprite.material_override==bridge.lit_material,"live carrier material identity is retained")
		check(bridge.volume_shadow!=null,"existing real body/weapon shadow proxy retained")
		check(bridge.weapon_material.get_shader_parameter("actor_pixel_rim_has_other_capture")==true,"body/weapon union suppresses internal joint edges")
	# Restore then rebuild to cover independent world ownership and cleanup.
	var old_material: ShaderMaterial = sample.world.player_depth_bridge.lit_material
	var old_original: Shader
	for binding in sample.effect.bindings:
		if binding.material.get_ref()==old_material: old_original=binding.original
	sample.effect.clear()
	check(old_material.shader==old_original,"clear restores the exact original Shader resource")
	sample.whitebox = true; await sample.rebuild(); freeze_world(); await frames(35)
	check(sample.ready_world and sample.whitebox,"whitebox reload completes")
	check(sample.effect.bindings.size()==4,"whitebox has exactly current player/enemy body and weapon bindings")
	await shot("whitebox")
	sample.whitebox = false; await sample.rebuild(); freeze_world(); await frames(50)
	check(sample.ready_world and not sample.whitebox,"production art reload completes")
	check(sample.effect.bindings.size()==4,"rebuild releases previous-world bindings")
	if "--actions-only" in OS.get_cmdline_user_args():
		FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"hair":hair_records,"events":events,"scope":"promoted carrier, eight directions, original hair sync, melee/roll callbacks, whitebox/production reset and exact shader restoration"},"\t"))
		print("RIM_PROMOTION_ACTIONS ",JSON.stringify({"checks":checks,"failures":failures}))
		lab.free(); await frames(10); quit(0 if failures.is_empty() else 1); return
	# Bounded matched ABBA, 12/24 actors, standing gun poses with animated gait.
	for count in [12,24]:
		await crowd(count)
		sample.set_light(1)
		for active in [false,true,true,false]:
			sample.set_enabled(active); await frames(70)
			var rows: Array = []; var values: Array = []
			var begin := Time.get_ticks_usec(); var previous := begin
			while Time.get_ticks_usec()-begin<4000000:
				var t := (Time.get_ticks_usec()-begin)/1000000.0
				for actor in sample.world.enemy_root.get_children():
					actor.velocity = Vector2(90,0); actor._update_human_animation(1.0/60.0)
				await process_frame
				var now := Time.get_ticks_usec(); var ms := (now-previous)/1000.0; previous=now
				values.append(ms)
				var vp: Viewport = sample.world.get_viewport()
				rows.append([t,ms,vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())])
			var key := "%d_%d_%s"%[count,perf.size(),"candidate" if active else "original"]
			var csv := FileAccess.open(out.path_join(key+".csv"),FileAccess.WRITE)
			csv.store_csv_line(PackedStringArray(["elapsed_s","wall_frame_ms","draw_calls_delayed","viewport_cpu_ms_delayed","viewport_gpu_ms_delayed"]))
			for row in rows:
				var strings := PackedStringArray()
				for value in row: strings.append(str(value))
				csv.store_csv_line(strings)
			csv.close()
			var stats: Dictionary = RECORDER.stats(values)
			stats.merge({"actors":count,"candidate":active,"file":key+".csv","sample_seconds":4.0,"window_focused":DisplayServer.window_is_focused(),"bindings":sample.effect.bindings.size()})
			perf.append(stats); print("RIM_PERF ",JSON.stringify(stats))
	check(sample.effect.bindings.size()==48,"24 actor materials include body and weapon")
	var report := {"checks":checks,"failures":failures,"events":events,"perf":perf,"renderer":RenderingServer.get_current_rendering_method(),"resolution":"640x360","scope":"ABBA four-second blocks; CPU wall-frame intervals, not GPU root-cause attribution; existing actual lights/shadows/reflections/materials retained in controlled fixture; no AI/combat stress certification","audio_master_muted":AudioServer.is_bus_mute(0)}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CHARACTER_RIM_EXTENDED ",JSON.stringify({"checks":checks,"failures":failures,"perf_blocks":perf.size()}))
	lab.free(); await frames(10); quit(0 if failures.is_empty() else 1)

func crowd(count: int) -> void:
	var world: Node3D = sample.world
	var current: int = world.enemy_root.get_child_count()+1
	for i in range(current,count):
		var p := Vector2(3.5+(i%6)*1.4,3.0+(i/6)*1.6)*32
		var actor: EmployeeEnemy = world._spawn_regular_employee(1,p,&"employee",false,"assault_rifle")
		actor.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		actor.set_room_runtime_active(true); actor.set_player_vision_visible(true); actor.process_mode=Node.PROCESS_MODE_DISABLED
		var bridge: Node = actor.get_meta(&"depth_visual_bridge").get_ref()
		sample.role_bridges.append(bridge); sample.effect.bind_bridge(bridge)
	await frames(40)
