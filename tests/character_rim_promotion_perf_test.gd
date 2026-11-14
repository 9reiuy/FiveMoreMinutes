extends SceneTree
const RECORDER := preload("res://scripts/testing/lab_recorder.gd")
var lab: Control
var sample: Control
var out := "res://.runtime/character_rim_promotion_20261113/perf"
var blocks: Array = []
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	create_timer(150.0,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps=0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var controller := root.get_node("DreamTimeController")
	controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false)
	lab=load("res://scenes/testing/CharacterRimLab.tscn").instantiate(); root.add_child(lab)
	await frames(2); sample=lab.presentation
	for i in 900:
		if sample.ready_world: break
		await frames(1)
	if not sample.ready_world: quit(2); return
	controller.set_process(false); controller.set_physics_process(false); Engine.time_scale=1.0
	sample.set_frozen(true); sample.world.set_process(false)
	# Production has no per-frame A/B material discovery. Omit the preview's
	# discovery in BOTH states, retaining its lights, geometry and other systems.
	sample.set_process(false); sample.set_light(1)
	var world: Node3D=sample.world
	for count in [12,24]:
		var current: int=world.enemy_root.get_child_count()+1
		for i in range(current,count):
			var actor: EmployeeEnemy=world._spawn_regular_employee(1,Vector2(3.5+(i%6)*1.4,3.0+(i/6)*1.6)*32,&"employee",false,"assault_rifle")
			actor.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
			actor.set_room_runtime_active(true); actor.set_player_vision_visible(true); actor.process_mode=Node.PROCESS_MODE_DISABLED
			var bridge: Node=actor.get_meta(&"depth_visual_bridge").get_ref()
			sample.role_bridges.append(bridge); sample.effect.bind_bridge(bridge)
		await frames(90)
		var visible_origins:=0
		for bridge in sample.role_bridges:
			if world.camera_3d.is_position_in_frustum(bridge.actor_sprite.global_position): visible_origins+=1
		for active in [false,true,true,false]:
			sample.set_enabled(active); await frames(100)
			var rows: Array=[]; var values: Array=[]
			var begin:=Time.get_ticks_usec(); var previous:=begin; var step:=1.0/60.0
			while Time.get_ticks_usec()-begin<4000000:
				for actor in world.enemy_root.get_children():
					actor.velocity=Vector2(90,0); actor._update_human_animation(step)
				await process_frame
				var now:=Time.get_ticks_usec(); var ms: float=(now-previous)/1000.0; previous=now
				step=clampf(ms/1000.0,0.0,0.05); values.append(ms)
				var vp: Viewport=world.get_viewport()
				rows.append([(now-begin)/1000000.0,ms,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())])
			var name:="%d_%d_%s"%[count,blocks.size(),"enabled" if active else "legacy"]
			var csv:=FileAccess.open(out.path_join(name+".csv"),FileAccess.WRITE)
			csv.store_csv_line(PackedStringArray(["elapsed_s","wall_frame_ms","process_ms_delayed","draw_calls_delayed","viewport_cpu_ms_delayed","viewport_gpu_ms_delayed"]))
			for row in rows:
				var fields:=PackedStringArray()
				for value in row: fields.append(str(value))
				csv.store_csv_line(fields)
			csv.close()
			var stats: Dictionary=RECORDER.stats(values)
			stats.merge({"actors":count,"enabled":active,"csv":name+".csv","visible_origins":visible_origins,"focused":DisplayServer.window_is_focused()})
			blocks.append(stats); print("PROMOTED_RIM_PERF ",JSON.stringify(stats))
	var result:={"blocks":blocks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"audio_master_muted":AudioServer.is_bus_mute(0),"scope":"4s ABBA, native 640x360, original carrier Shader with feature removed versus integrated carrier; no per-frame preview material scanning in either state; actual lights/shadows/production art retained; gait update, no combat AI; all peaks retained"}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	lab.free(); await frames(10); quit(0)
