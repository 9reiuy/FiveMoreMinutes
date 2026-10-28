extends SceneTree
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(960,540)
	var world:Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false;world.spawn_content=false;world.persist_profile=false;world.enable_game_start_cab_exit=false
	root.add_child(world);expect(world.regenerate(42001),"formal floor for loading path")
	for i in 4:await physics_frame
	paused=true
	# This no-content seed has facade windows but need not contain an interior
	# standard pane. Add one real finalized factory representative under WallRoot.
	var standard:=preload("res://scripts/dream/continuous_office_glass.gd").new()
	world.wall_root.add_child(standard)
	standard.configure_window({"axis":"V","x":4,"y":20,"preview_run_width":1.0},"V:4:20",world.wall_height,world.wall_thickness,null)
	var rng_state:int=world._content_rng.state
	var floor_count:int=world.floor_cells.size()
	var windows:Array=[]
	for glass in get_nodes_in_group(&"breakable_glass_windows"):
		if world.generated_root.is_ancestor_of(glass):windows.append([weakref(glass),glass.current_health,glass.is_shattered,glass.transform,glass.glass_pane.mesh.get_aabb()])
	expect(not windows.is_empty(),"real windows tracked under generated building root, not floor-only sibling")
	var report:Dictionary=await preload("res://scripts/dream/destruction_render_preparation.gd").run(self,world)
	expect(not report.get("cancelled",false) and report.get("viewport_released",false),"existing real loading render preparation completes and releases private viewport")
	expect(report.geometry_prefill.specs>0 and report.geometry_prefill.specs<=32,"only bounded actual finalized glass specs prepared")
	expect(report.geometry_prefill.outline_misses>0,"loading actually precomputes standard pane cut outlines, not only facade frame bars")
	expect(report.has("death_audio_prefill_ms"),"death waveform preparation included while covered")
	expect(world._content_rng.state==rng_state and world.floor_cells.size()==floor_count,"preparation preserves content RNG and floor topology")
	for state in windows:
		var glass:Node=state[0].get_ref()
		expect(glass!=null and glass.current_health==state[1] and glass.is_shattered==state[2] and glass.transform==state[3] and glass.glass_pane.mesh.get_aabb()==state[4],"loading prefill never mutates source glass")
	var second:=preload("res://scripts/dream/continuous_office_glass.gd").new();world.wall_root.add_child(second)
	second.configure_window({"axis":"H","x":5,"y":20,"preview_run_width":1.0},"H:5:20",world.wall_height,world.wall_thickness,null)
	var burst:=preload("res://scripts/dream/destruction_floor_debris.gd").new();world.floor_root.add_child(burst);burst.world=world
	burst.build_from_source(second,Vector2.RIGHT,true)
	expect(burst.audit_geometry_misses==0 and burst.audit_outline_misses==0,"new independent actual-window instance has no geometry/outline cold work after loading")
	print("STAGE8_LOADING_REPORT ",JSON.stringify(report))
	paused=false;world.free();await process_frame
	print("STAGE8_LOADING checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
