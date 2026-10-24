extends "res://tests/phone_tab_delivery.gd"
## Read-only production audit: shader substitutions exist only in this test process.
var pairs: Array[Dictionary] = []
var measurements: Array[Dictionary] = []
func stats(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2], "p95":values[mini(values.size()-1, floori(values.size()*0.95))]}
func sample(label: String, viewport: Viewport) -> Dictionary:
	for frame in 45: await process_frame
	var frames: Array = []
	var gpu: Array = []
	var cpu: Array = []
	var draws: Array = []
	var stamp := Time.get_ticks_usec()
	for frame in 150:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-stamp)/1000.0)
		stamp=now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
		draws.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	return {"label":label,"frame_ms":stats(frames),"world_gpu_ms":stats(gpu),"world_cpu_ms":stats(cpu),"draw_calls":stats(draws)}
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"): quit(2); return
	output="res://.runtime/depth_policy_audit_20261023"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	root.size=Vector2i(1280,720)
	main=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state=main._create_initial_state()
	main.persistent_day_state.tutorial_completed=true
	main._show_dream("basic")
	await ready_main()
	world=main._supported_dream_world
	var deadline:=Time.get_ticks_msec()+60000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await wait(0.05)
	if world.floor_transition_in_progress: quit(2); return
	await wait(0.3)
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var seen: Dictionary={}
	for node in world.floor_root.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null: continue
		for index in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(index)
			if not material is ShaderMaterial or seen.has(material.get_instance_id()): continue
			if material.shader==null or not material.shader.code.contains("depth_draw_opaque") or material.shader.code.contains("ALPHA"): continue
			if not material.shader.code.contains("review_bevel") and not material.shader.code.contains("world_surface"): continue
			seen[material.get_instance_id()]=true
			var legacy:=Shader.new()
			legacy.code=material.shader.code.replace("depth_draw_opaque","depth_draw_always").replace("ROUGHNESS = 1.0;","ALPHA = 1.0;\nROUGHNESS = 1.0;")
			pairs.append({"material":material,"current":material.shader,"legacy":legacy})
	var viewport: Viewport=world.get_viewport()
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	for round_index in 3:
		for label in (["current_opaque","legacy_transparent"] if round_index%2==0 else ["legacy_transparent","current_opaque"]):
			for pair in pairs: pair.material.shader=pair.current if label=="current_opaque" else pair.legacy
			var result:=await sample(label,viewport)
			result["round"]=round_index
			measurements.append(result)
			print("DEPTH_AUDIT_SAMPLE ",JSON.stringify(result))
	for pair in pairs: pair.material.shader=pair.current
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"materials":pairs.size(),"output":str(root.size),"world_viewport":str(viewport.size),"scope":"Frozen actual Main camera; isolated floor queue A/B, not combat peak or whole-game 60 FPS acceptance; minimized force_draw; no readback within timed samples", "samples":measurements},"\t"))
	file.close()
	print("DEPTH_AUDIT_DONE materials=",pairs.size())
	main.free()
	quit()
