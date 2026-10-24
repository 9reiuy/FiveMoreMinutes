extends SceneTree
const TEST=preload("res://tests/fire_extinguisher_test.gd")
const SYSTEM=preload("res://scripts/dream/fire_extinguisher_system.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	# MultiMesh readback is a dummy default in headless mode, not real evidence.
	if DisplayServer.get_name()=="headless":quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	var world=TEST.World.new();root.add_child(world);world.rooms=[{"type":"office"}]
	for y in range(-3,4):
		for x in range(-3,4):world.floor_cells[Vector2i(x,y)]="room";world.room_cells[Vector2i(x,y)]=0
	var smoke=SYSTEM.install(world);smoke.set_physics_process(false)
	var id: int=smoke.discharge(Vector2.ZERO);smoke.advance(1.0)
	var count: int=smoke.clouds.size()
	check(count==98,"Centre concentration keeps the same fixed release count")
	var foundation_cells: Dictionary={}
	for cloud in smoke.clouds:
		if int(cloud.layer)==0:foundation_cells[cloud.cell]=true
	check(foundation_cells.size()==smoke.cells.size(),"Every silhouette cell has a persistent dense foundation")
	for fringe in smoke.fringe_clouds:
		check(not smoke.cells.has(fringe.cell) and world.floor_cells.has(fringe.cell),"Only outside silhouette coverage has decorative sparse wisps")
	for cloud in smoke.clouds:
		check(float(cloud.life)>=4.0 and float(cloud.life)<=6.0,"Slow body renewal stays within 4-6 seconds")
		check(float(cloud.opacity)>=.8,"Fringe does not become a faint half-transparent ring")
	var dense_samples:=0;var samples:=0
	var size_sum:=0.0
	for frame in 60:
		smoke.clock=float(frame)*.1;smoke.upload_puffs()
		for index in smoke.banks[0].visible_instance_count:
			var bank: MultiMesh=smoke.banks[0]
			samples+=1
			if bank.get_instance_color(index).a>=.6:dense_samples+=1
			size_sum+=bank.get_instance_transform(index).basis.x.length()
	check(float(dense_samples)/samples>.75,"Smoke stays visibly dense through most of staggered cycles")
	check(is_equal_approx(float(smoke.materials[0].get_shader_parameter("smoke_clock")),smoke.clock*.5),"Shader shape motion runs at half speed without slowing source expiry")
	print("SMOKE_DENSITY opaque_sample_fraction=",float(dense_samples)/samples," average_rendered_size=",size_sum/samples)
	var core_cells:=0;var edge_cells:=0
	for cell: Vector2i in smoke.cells:
		var distance:=Vector2(cell).length()
		if distance<=1.5:core_cells+=1
		if distance>=2.7:edge_cells+=1
	var core_count:=0;var edge_count:=0
	var core_size:=0.0;var edge_size:=0.0;var core_opacity:=0.0;var edge_opacity:=0.0
	for cloud in smoke.clouds:
		var distance:=Vector2(cloud.cell).length()
		if distance<=1.5:
			core_count+=1;core_size+=float(cloud.size);core_opacity+=float(cloud.opacity)
		if distance>=2.7:
			edge_count+=1;edge_size+=float(cloud.size);edge_opacity+=float(cloud.opacity)
	var core_density:=float(core_count)/maxi(1,core_cells)
	var edge_density:=float(edge_count)/maxi(1,edge_cells)
	check(core_count>0 and edge_count>0,"Both the concentration core and small outer wisps are represented")
	check(core_density>edge_density*1.5,"Fixed budget allocates more groups per cell near the actual trigger")
	check(core_size/maxi(1,core_count)>edge_size/maxi(1,edge_count)*1.5,"Core groups are larger on average than edge groups")
	check(core_opacity/maxi(1,core_count)>edge_opacity/maxi(1,edge_count),"Core has greater opacity rather than equal-strength scatter")
	for x in 3:
		check(float(smoke.visual_strengths[Vector2i(x,0)])>float(smoke.visual_strengths[Vector2i(x+1,0)]),"Core falloff decreases smoothly outwards")
	var old_core: float=smoke.visual_strengths[Vector2i(3,0)]
	smoke.emit_trail(Vector2(96,0),Vector2(96,0),id);smoke.advance(.1)
	check(float(smoke.visual_strengths[Vector2i(3,0)])>old_core,"Flight spray creates a new local concentration")
	check(float(smoke.visual_strengths[Vector2i(3,0)])<float(smoke.visual_strengths[Vector2i.ZERO]),"Trail concentration remains smaller than the initial release core")
	check(smoke.clouds.size()==count,"Trail redistribution does not add extra cloud groups")
	smoke.disperse_segment(Vector2(0,-16),Vector2(0,48));smoke.advance(.01)
	check(not smoke.cells.has(Vector2i.ZERO),"Concentration does not refill a bullet-cleared source cell")
	for cloud in smoke.clouds:check(smoke.cells.has(cloud.cell),"Concentrated groups remain inside non-cleared valid coverage")
	print("CENTER_PROFILE core_groups_per_cell=",core_density," edge_groups_per_cell=",edge_density," core_size=",core_size/maxi(1,core_count)," edge_size=",edge_size/maxi(1,edge_count)," fixed_count=",count)
	world.free();await process_frame
	print("EXTINGUISHER_CENTER checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
