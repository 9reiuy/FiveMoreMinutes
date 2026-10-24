extends SceneTree
const SAMPLE=preload("res://scenes/dream/preview/ElementalParticlesSample.tscn")
var output:="res://.runtime/elemental_particles_20261023"
func _initialize() -> void: call_deferred("run")
func draw() -> Image:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var lab:=SAMPLE.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.effects.set_process(false)
	for side in [0,-1,1]:
		lab.effects.clear()
		lab.effects.rng.seed=887
		lab.effects.clock=0.0
		lab.wind_mode=side
		lab.effects.set_wind(Vector3(side*1.8,0,0))
		lab._update_status()
		lab.effects.emit_fire(Vector3(-3,.12,0))
		for i in 100: lab.effects.step(1.0/60.0)
		lab.effects.emit_smoke(Vector3(3,.12,0),16)
		lab.effects.explode(Vector3(0,.25,0),.85)
		for i in 10: lab.effects.step(1.0/60.0)
		var frame:=await draw()
		frame.save_png(output+"/wind_%d.png" % side)
	# A short actual Camera animation, not a montage of authored sprites.
	for index in 24:
		for i in 3: lab.effects.step(1.0/60.0)
		var frame:=await draw()
		frame.save_png(output+"/motion_%02d.png" % index)
	lab.effects.clear()
	for i in 8: lab.effects.emit_fire(Vector3((i%4)*1.5-2.25,.12,float(i/4)-.5))
	for i in 120: lab.effects.step(1.0/60.0)
	lab.effects.explode(Vector3(0,.2,0))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var cpu: Array=[]
	var gpu: Array=[]
	for i in 180:
		var stamp:=Time.get_ticks_usec()
		lab.effects.step(1.0/60.0)
		var elapsed:=float(Time.get_ticks_usec()-stamp)/1000.0
		await process_frame
		if i>=30:
			cpu.append(elapsed)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	cpu.sort();gpu.sort()
	var file:=FileAccess.open(output+"/camera_report.json",FileAccess.WRITE)
	var report:={"gpu":RenderingServer.get_video_adapter_name(),"output":str(root.get_texture().get_image().get_size()),"cpu_step_median_ms":cpu[cpu.size()/2],"cpu_step_p95_ms":cpu[floori(cpu.size()*.95)],"whole_lab_gpu_median_ms":gpu[gpu.size()/2],"whole_lab_gpu_p95_ms":gpu[floori(gpu.size()*.95)],"particles_at_end":lab.effects.particles.size(),"dropped":lab.effects.dropped,"scope":"8 fires and explosion; isolated Camera lab, 640x360 rendering scaled to window, minimized force_draw, not formal combat peak or incremental GPU cost"}
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ELEMENTAL_CAMERA ",JSON.stringify(report))
	lab.free()
	quit()
