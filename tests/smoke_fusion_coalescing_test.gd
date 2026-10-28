extends SceneTree
const FIXTURE=preload("res://tests/fire_extinguisher_test.gd")
const SYSTEM=preload("res://scripts/dream/fire_extinguisher_system.gd")
class World extends FIXTURE.World:
	var camera_3d:Camera3D
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func make_world()->Node3D:
	var world:=World.new();root.add_child(world)
	for y in 10:
		for x in 12:
			world.floor_cells[Vector2i(x,y)]="room"
			world.room_cells[Vector2i(x,y)]=1 if x<8 and y<6 else 0
	world.camera_3d=Camera3D.new();world.add_child(world.camera_3d)
	world.camera_3d.position=Vector3(5,10,12);world.camera_3d.look_at(Vector3(5,0,5))
	return world
func run()->void:
	for steps in [1,2,5,8]:
		for phase in [0.0,.071]:
			var wa:=make_world();var wb:=make_world()
			var a:Node=SYSTEM.install(wa);var b:Node=SYSTEM.install(wb)
			for world in [wa,wb]:
				for tank in world.key_root.get_children():tank.set_physics_process(false)
			a.set_physics_process(false);b.set_physics_process(false)
			a.coalesce_fusion_calculation_enabled=false
			a.rng.seed=70;b.rng.seed=70
			a.discharge(Vector2(160,160));b.discharge(Vector2(160,160))
			if steps>=5:
				for point in [Vector2(192,128),Vector2(128,192)]:a.discharge(point);b.discharge(point)
			a.advance(.3);b.advance(.3)
			a.clock+=phase;b.clock+=phase
			var before_a:int=a.fusion_calculations;var before_b:int=b.fusion_calculations
			for tick in steps:
				if tick%2==0:
					a.emit_jet(Vector2(160+tick*3,160),Vector2.RIGHT);b.emit_jet(Vector2(160+tick*3,160),Vector2.RIGHT)
				if tick%3==1:
					a.disperse_segment(Vector2(160,128),Vector2(160,192));b.disperse_segment(Vector2(160,128),Vector2(160,192))
				a.emit_trail(Vector2(160+tick*2,160),Vector2(176+tick*2,160),1)
				b.emit_trail(Vector2(160+tick*2,160),Vector2(176+tick*2,160),1)
				a.advance(1.0/60.0,false);b.advance(1.0/60.0,false)
				expect(a.field_updated_at==b.field_updated_at and a.field_layout==b.field_layout,"gate phase preserved")
				expect(a.cells==b.cells and a.sources==b.sources,"per-tick authority preserved")
			var gate_clock:float=b.field_updated_at
			a.advance(.00001,false);b.advance(.00001,false)
			expect(b.clock>b.field_updated_at and b.field_updated_at==gate_clock,"last presentation tick differs from final gate tick")
			# Change the topology AFTER the final gate. A partial snapshot of only
			# cells/doors would incorrectly read these later walls during the math.
			for world in [wa,wb]:world.wall_edges["V:5:5"]={"axis":"V","x":5,"y":5}
			wa.camera_3d.rotation.y+=.7;wb.camera_3d.rotation.y+=.7
			a.flush_presentation(true);b.flush_presentation(true)
			expect(a.fusion_field_image.get_data()==b.fusion_field_image.get_data(),"gate snapshot retains old wall/camera state")
			expect(a.fusion_pairs==b.fusion_pairs,"fusion pair count equal after presentation")
			expect(a.fusion_gate_passes==b.fusion_gate_passes,"same number of gate passes")
			expect(b.fusion_calculations-before_b<=1,"at most one heavy calculation for catch-up frame")
			if steps>=5:expect(a.fusion_calculations-before_a>1,"reference really performs multiple heavy calculations")
			# Explicit/manual prewarm is still immediate, even with queued data.
			a.advance(.016,false);b.advance(.016,false)
			a.advance(.016,true);b.advance(.016,true)
			expect(a.fusion_field_image.get_data()==b.fusion_field_image.get_data(),"manual immediate path consumes correct pending state")
			wa.free();wb.free()
	var worlds:Array=[];var systems:Array=[]
	for index in 3:
		var world:=make_world();worlds.append(world)
		var smoke:Node=SYSTEM.install(world);systems.append(smoke)
		smoke.set_physics_process(false);smoke.coalesce_fusion_calculation_enabled=index==1;smoke.rng.seed=29
		for tank in world.key_root.get_children():tank.set_physics_process(false)
		smoke.discharge(Vector2(160,160));smoke.advance(.3)
	var samples:Array=[]
	for trial in 12:
		var times:Array=[]
		for smoke in systems:
			var started:=Time.get_ticks_usec()
			for tick in 8:
				smoke.emit_jet(Vector2(160,160),Vector2.RIGHT)
				var x:=160.0+fmod(float(trial*8+tick)*5.0,64.0)
				smoke.emit_trail(Vector2(x,160),Vector2(x+5,160),1)
				smoke.advance(1.0/60.0,false)
			smoke.flush_presentation(true)
			times.append((Time.get_ticks_usec()-started)/1000.0)
		expect(systems[0].fusion_field_image.get_data()==systems[1].fusion_field_image.get_data() and systems[1].fusion_field_image.get_data()==systems[2].fusion_field_image.get_data(),"A/B/A catch-up bench field bytes identical")
		samples.append(times)
	print("STAGE7_FUSION_BENCH ",JSON.stringify({"scope":"8 catch-up steps + final calculation/upload; A/B/A CPU fixture, not gameplay FPS","times_ms":samples}))
	for world in worlds:world.free()
	print("STAGE7_FUSION checks=%d failures=%s"%[checks,failures])
	await process_frame;quit(0 if failures.is_empty() else 1)
