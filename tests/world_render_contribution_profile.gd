extends SceneTree
## Diagnostic isolation only. Never installs any disabled display feature.
var world: Node3D
var display: Control
var overlays: Dictionary = {}
var lights: Dictionary = {}
var casters: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func stats(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[floori(values.size()*.95)]}
func restore() -> void:
	for mesh in overlays: mesh.material_overlay=overlays[mesh]
	for light in lights: light.shadow_enabled=lights[light]
	for mesh in casters: mesh.cast_shadow=casters[mesh]
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings: Node=root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	display=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(41001): quit(2); return
	for index in 30: await process_frame
	world.player.invulnerability_left=999
	world.player.global_position=world.enemy_root.get_child(0).global_position+Vector2(96,0)
	world.transition_phase=&"IDLE"; world.camera_aim_offset=Vector3.ZERO
	world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true); display._process(0.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var start: int=Time.get_ticks_usec()
	while Time.get_ticks_usec()-start<10000000: await RenderingServer.frame_post_draw
	paused=true
	for node in world.find_children("*","MeshInstance3D",true,false):
		if node.material_overlay is ShaderMaterial and node.material_overlay.shader.resource_path.ends_with("furniture_pixel_outline.gdshader"):
			overlays[node]=node.material_overlay
		if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: casters[node]=node.cast_shadow
	for node in world.find_children("*","Light3D",true,false): lights[node]=node.shadow_enabled
	RenderingServer.viewport_set_measure_render_time(display.world_viewport.get_viewport_rid(),true)
	print("WORLD_RENDER_ISOLATION_COUNTS ",JSON.stringify({"outline_meshes":overlays.size(),"lights":lights.size(),"casters":casters.size()}))
	for mode in ["original","no_outline","no_shadows","no_mesh_casting","original_repeat"]:
		restore()
		if mode=="no_outline":
			for mesh in overlays: mesh.material_overlay=null
		if mode=="no_shadows":
			for light in lights: light.shadow_enabled=false
		if mode=="no_mesh_casting":
			for mesh in casters: mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		start=Time.get_ticks_usec()
		while Time.get_ticks_usec()-start<2000000: await RenderingServer.frame_post_draw
		var frame: Array=[]; var cpu: Array=[]; var gpu: Array=[]; var draws: Array=[]
		start=Time.get_ticks_usec(); var previous: int=start
		while Time.get_ticks_usec()-start<8000000:
			await RenderingServer.frame_post_draw
			var now: int=Time.get_ticks_usec(); frame.append(float(now-previous)/1000.0); previous=now
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(display.world_viewport.get_viewport_rid()))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(display.world_viewport.get_viewport_rid()))
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("WORLD_RENDER_ISOLATION ",JSON.stringify({"mode":mode,"frame_ms":stats(frame),"world_cpu_ms":stats(cpu),"world_gpu_ms":stats(gpu),"draws":stats(draws),"frozen_gameplay":true,"diagnostic_only":true,"gpu":RenderingServer.get_video_adapter_name()}))
	restore(); overlays.clear(); lights.clear(); casters.clear()
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	quit(0)
