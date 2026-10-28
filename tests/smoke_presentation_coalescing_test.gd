extends SceneTree
const TEST=preload("res://tests/fire_extinguisher_test.gd")
class World extends TEST.World:
	var camera_3d:Camera3D
class Probe extends "res://scripts/dream/fire_extinguisher_system.gd":
	var uploads:=0
	func upload_puffs()->void:
		uploads+=1;super.upload_puffs()
var smoke:Probe
var checks:=0
var failures:Array[String]=[]
func expect(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func flush()->void:
	if DisplayServer.get_name()=="headless":
		smoke._flush_before_draw();await process_frame
	else:
		for frame in 2:await RenderingServer.frame_post_draw
func run()->void:
	create_timer(30,true,false,true).timeout.connect(func()->void:quit(2))
	var world:=World.new();root.add_child(world)
	world.camera_3d=Camera3D.new();world.add_child(world.camera_3d)
	for y in 4:
		for x in 4:world.floor_cells[Vector2i(x,y)]="room";world.room_cells[Vector2i(x,y)]=0
	smoke=Probe.new();smoke.name="FireExtinguisherSystem";world.floor_root.add_child(smoke);smoke.configure(world);smoke.set_physics_process(false)
	for tank in world.key_root.get_children():tank.set_physics_process(false)
	smoke.discharge(Vector2(32,32))
	var bank_rid:=smoke.banks[0].get_rid()
	var final_basis:=Basis.IDENTITY
	for index in 8:
		final_basis=world.camera_3d.global_basis
		smoke.advance(1.0/60.0,false)
		world.camera_3d.rotate_y(.1)
	expect(smoke.uploads==0 and smoke._presentation_pending,"eight ticks defer upload")
	expect(smoke._camera_basis.is_equal_approx(final_basis),"camera basis captured at last physics step")
	await flush()
	expect(smoke.uploads==1,"eight catch-up ticks upload once")
	expect(smoke.banks[0].visible_instance_count>0,"presentation becomes visible")
	if DisplayServer.get_name()!="headless":
		var basis:Basis=smoke.banks[0].get_instance_transform(0).basis
		expect(basis.x.normalized().is_equal_approx(final_basis.x.normalized()),"upload uses snapshot instead of later camera rotation")
	else:print("SKIP native MultiMesh transform readback on dummy backend; GPU test covers this assertion")
	paused=true;smoke.advance(.1,false);await flush()
	expect(smoke._presentation_pending,"paused pending state retained")
	smoke.advance(.1);expect(not smoke._presentation_pending,"manual prewarm stays immediate while paused")
	paused=false;smoke.process_mode=Node.PROCESS_MODE_DISABLED;smoke.advance(.1,false);await flush()
	expect(smoke._presentation_pending,"disabled stashed floor does not flush")
	smoke.process_mode=Node.PROCESS_MODE_INHERIT;await flush()
	expect(not smoke._presentation_pending,"restored floor resumes upload")
	var floor:Node=world.floor_root
	world.remove_child(floor);root.add_child(floor);root.remove_child(floor);world.add_child(floor)
	smoke.advance(.1,false);await flush()
	expect(not smoke._presentation_pending and RenderingServer.frame_pre_draw.is_connected(smoke._flush_before_draw),"re-entry reconnects native callback")
	world.floor_transition_in_progress=true
	var clock:float=smoke.clock;smoke._physics_process(1.0)
	expect(smoke.clock==clock,"transition does not advance simulation")
	smoke._presentation_pending=true;await flush();expect(smoke._presentation_pending,"transition does not upload into inactive floor")
	world.floor_transition_in_progress=false;await flush();expect(not smoke._presentation_pending,"transition end resumes upload")
	smoke.advance(13,false);await flush()
	expect(smoke.sources.is_empty() and smoke.banks[0].visible_instance_count==0,"expiry clears presentation")
	expect(smoke.banks[0].instance_count==smoke.MAX_PUFFS and smoke.banks[0].get_rid()==bank_rid,"expiry retains allocated render capacity and RID")
	var connections:=RenderingServer.frame_pre_draw.get_connections().size()
	smoke.discharge(Vector2(32,32));smoke.advance(.1,false)
	world.free();await process_frame
	expect(RenderingServer.frame_pre_draw.get_connections().size()==connections-1,"free disconnects callback without freed-object access")
	print("SMOKE_PRESENTATION checks=",checks," failures=",failures," scope=",DisplayServer.get_name())
	quit(0 if failures.is_empty() else 1)
