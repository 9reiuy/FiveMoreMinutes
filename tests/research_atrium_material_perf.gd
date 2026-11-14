extends SceneTree
const STATS:=preload("res://scripts/testing/lab_recorder.gd")
const LIB:=preload("res://scripts/testing/research_atrium/cc0_architecture.gd")
var output:=""
var shots:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps=60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):output=arg.trim_prefix("--artifact-dir=")
	var lab: Control=load("res://scenes/testing/ResearchAtriumTestLab.tscn").instantiate()
	root.add_child(lab);current_scene=lab
	await frames(120)
	var world: Node3D=lab.presentation.world
	var player: Node2D=world.player
	player.global_position=Vector2(7,0)*32-player.body_collision.position
	player.velocity=Vector2.ZERO
	world._update_camera_and_actor_projection(0.0)
	player.confirmed_projectile_fired.connect(func():shots+=1)
	var bindings: Array=[]
	for mesh in LIB.meshes(world.atrium.root):
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_active_material(surface)
			if material is ShaderMaterial and material.resource_name.begins_with("Level11Shared_"):
				bindings.append({"mesh":mesh,"surface":surface,"material":material})
	var neutral:=StandardMaterial3D.new()
	neutral.albedo_color=Color("888888");neutral.roughness=.7
	var neutral_cutout: Material=world.atrium.cutout.material_for(neutral)
	var report: Array=[]
	for label: String in ["A1_shared_style","B_neutral_materials","A2_shared_style"]:
		for binding: Dictionary in bindings:
			binding.mesh.set_surface_override_material(binding.surface,neutral_cutout if label.begins_with("B_") else binding.material)
		await frames(120)
		var start_shots:=shots
		var previous:=Time.get_ticks_usec()
		var rows: Array=[]
		var intervals: Array=[]
		for i in 360:
			player.set_meta(&"force_weapon_attack",i<180)
			await process_frame
			var now:=Time.get_ticks_usec()
			var interval:=float(now-previous)/1000.0
			previous=now
			intervals.append(interval)
			rows.append([i,interval,world.get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)])
		player.remove_meta(&"force_weapon_attack")
		var stats:=STATS.stats(intervals)
		stats.merge({"case":label,"shots":shots-start_shots,"shared_material_bindings":bindings.size()})
		report.append(stats)
		var file:=FileAccess.open(output.path_join(label+".csv"),FileAccess.WRITE)
		file.store_csv_line(PackedStringArray(["frame","frame_wall_ms","draw_calls_delayed"]))
		for row: Array in rows:file.store_csv_line(PackedStringArray([str(row[0]),str(row[1]),str(row[2])]))
		file.close()
		print("ATRIUM_PERF ",JSON.stringify(stats))
	var file:=FileAccess.open(output.path_join("material_perf.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"gpu":RenderingServer.get_video_adapter_name(),"audio":"private muted WASAPI","fps_cap":60,"scope":"Same geometry, camera, seed, lights and H06. A/B/A material-only ablation; 2s+120-frame warmup before each 6s sample, first formal shot retained. Adjacent frame wall intervals, not GPU times or whole-game certification.","samples":report},"  "))
	lab.free();await frames(4);quit()
