extends SceneTree
const WALK:=preload("res://tests/support/world_walk_input.gd")
const L:=preload("res://scripts/testing/research_atrium/atrium_layout.gd")
const LIB:=preload("res://scripts/testing/research_atrium/cc0_architecture.gd")
var output:=""
var failed: Array[String]=[]
var checks: Array[Dictionary]=[]
var lab: Control
var world: Node3D
var shots:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label})
	print("PASS " if ok else "FAIL ",label)
	if not ok:failed.append(label)
func frames(count: int) -> void:
	for i in count:await process_frame
func teleport(point: Vector2) -> void:
	world.player.global_position=point*32-world.player.body_collision.position
	world.player.velocity=Vector2.ZERO
	world._update_camera_and_actor_projection(0.0)
func walk(point: Vector2) -> bool:
	for frame in 900:
		var delta: Vector2=point*32-world.player.body_collision.global_position
		if delta.length()<6:
			WALK.release();return true
		WALK.hold(world.player,delta)
		await physics_frame
	WALK.release()
	return false
func nodes_named(prefix: String) -> Array[Node3D]:
	var found: Array[Node3D]=[]
	for node: Node3D in world.atrium.library.placements:
		if str(node.get_meta(&"atrium_role","")).begins_with(prefix):found.append(node)
	return found
func top(node: Node3D) -> float:
	var highest:=-INF
	for mesh in LIB.meshes(node):
		var bounds: AABB=world.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		highest=maxf(highest,bounds.end.y)
	return highest
func mesh_floor(node: Node3D,at: Vector2) -> float:
	var result:=-INF
	for mesh in LIB.meshes(node):
		var inv:=mesh.global_transform.affine_inverse()
		var a: Vector3=inv*world.to_global(Vector3(at.x,12,at.y))
		var b: Vector3=inv*world.to_global(Vector3(at.x,-1,at.y))
		var faces:=mesh.mesh.get_faces()
		for j in range(0,faces.size(),3):
			var hit: Variant=Geometry3D.segment_intersects_triangle(a,b,faces[j],faces[j+1],faces[j+2])
			if hit is Vector3:result=maxf(result,world.to_local(mesh.to_global(hit)).y)
	return result
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	Engine.max_fps=60
	preload("res://tests/support/background_gpu.gd").start(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):output=arg.trim_prefix("--artifact-dir=")
	lab=load("res://scenes/testing/ResearchAtriumTestLab.tscn").instantiate()
	root.add_child(lab);current_scene=lab
	await frames(90)
	world=lab.presentation.world
	check(RenderingServer.get_current_rendering_method()=="forward_plus","Actual Forward+ renderer")
	check(world.player.get_script().resource_path=="res://scripts/entities/dream_player.gd","Formal player and controls retained")
	check(lab.presentation.world_viewport.size==Vector2i(1280,720),"Native 1280x720 presentation")
	check(is_equal_approx(world.atrium.mech.position.y,0.0),"H06 stands on the first floor without a display pedestal")
	check(nodes_named("SquareRaisedDisplayTop").is_empty() and nodes_named("ContinuousDisplayWall").is_empty(),"No raised mech platform remains")
	check(nodes_named("WalkwaySupportToBase").size()==4,"Only four structural supports remain")
	check(nodes_named("ContinuousOuterLaboratoryWall").size()==2,"Each main wall is one continuous imported module")
	var aligned:=true
	for node in nodes_named("ContinuousOuterLaboratoryWall")+nodes_named("EntranceSideWall")+nodes_named("LeftAtriumGlass"):
		if absf(top(node)-world.atrium.WALL_TOP)>.025:aligned=false
	check(aligned,"Solid walls and left glass share one top elevation")
	check(nodes_named("CorridorProtectiveGlassRoof").is_empty() and nodes_named("LeftAtriumGlass").size()==3,"Left-side glass looks into the open ground-floor bay")
	check(world.atrium.root.find_children("*","Label3D",true,false).is_empty() and not world.run_interface.hud.visible,"No added wall labels or HUD")
	var sourced:=true
	for module: Node3D in world.atrium.library.placements:
		if not module.has_meta(&"cc0_source_scene"):sourced=false
		for mesh in LIB.meshes(module):
			if mesh.mesh is PrimitiveMesh:sourced=false
	check(sourced,"Architecture uses existing CC0 geometry, without primitive modeling")
	var finishes: Dictionary=world.atrium.library.finishes
	var shared_ok: bool=finishes.size()>=3
	for material: ShaderMaterial in finishes.values():
		if material.get_meta(&"shared_style_source","") not in ["res://shaders/dream3d/maintenance_concrete.gdshader","res://shaders/dream3d/transit_surfaces.gdshader"]:shared_ok=false
	check(shared_ok,"Uses the existing 0-1 and 0-4/0-5 surface shaders at 32 texels/m")
	var ramps:=nodes_named("DescendingCC0Ramp")
	for i in ramps.size():
		var segment: int=L.FLIGHT_SEGMENTS[i]
		var a: Vector2=L.PATH[segment];var b: Vector2=L.PATH[segment+1]
		var start: float=(a.distance_to(b)-L.FLIGHT_LENGTH)*.5
		for fraction: float in [.2,.5,.8]:
			var point:=a+(b-a).normalized()*(start+fraction*L.FLIGHT_LENGTH)
			check(absf(mesh_floor(ramps[i],point)-L.height_at(point))<.06,"Actual imported ramp matches the player floor at "+str(point))
	var bridge_ok:=true
	for point: Vector2 in [Vector2(7,6),Vector2(7,0),Vector2(7,-7),Vector2(-1,-7),L.EXIT]:
		check(await walk(point),"Real movement reaches "+str(point))
		world._sync_elevated_actors()
		var expected: float=L.height_at(world.player.body_collision.global_position/32)
		if absf(world.player_depth_bridge.ground_surface_height-expected)>.025:bridge_ok=false
	check(bridge_ok,"Character follows the elevated route and both slopes")
	check(world.completed,"Walking to the upper-left end emits completion")
	teleport(Vector2(7,0));await frames(2)
	for frame in 80:
		WALK.hold(world.player,Vector2.LEFT);await physics_frame
	WALK.release()
	check(world.player.body_collision.global_position.x/32>=5.65,"Glass-side collision prevents falling into the atrium")
	teleport(Vector2(7,0));await frames(2)
	world.player.confirmed_projectile_fired.connect(func():shots+=1)
	world.player.set_meta(&"force_weapon_attack",true)
	await frames(100)
	world.player.remove_meta(&"force_weapon_attack")
	check(shots>0,"Formal weapon fires from the elevated walk")
	world.player.force_hazard_death(&"atrium_validation")
	await frames(3)
	check(world.player.dead,"Formal player death remains functional")
	var old_id:=lab.get_instance_id()
	var event:=InputEventKey.new();event.physical_keycode=KEY_F5;event.pressed=true
	Input.parse_input_event(event)
	await frames(20)
	lab=current_scene
	world=lab.presentation.world
	check(lab.get_instance_id()!=old_id and not world.player.dead,"F5 reloads the actual independent entry after death")
	check(world.atrium._support_count==4 and world.atrium.mech!=null,"Reload has one mech and four supports without duplicate geometry")
	check(AudioServer.is_bus_mute(0) or AudioServer.get_bus_volume_db(0)<=-60,"Private validation remains muted after reload")
	var file:=FileAccess.open(output.path_join("runtime.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failed,"shots":shots,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("ATRIUM_RUNTIME checks=",checks.size()," failures=",failed," shots=",shots)
	lab.free();await frames(3);quit(0 if failed.is_empty() else 1)
