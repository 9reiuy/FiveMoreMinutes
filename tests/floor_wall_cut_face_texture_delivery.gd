extends SceneTree
## Opt-in presentation sample, entered through production Main. Never installed by Main.
var output := "res://.runtime/wall_cut_face_texture_20261015/camera"
var before_only := false
var main: Node
var world: Node
var selected_room: Dictionary
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var clock := 0.0
var recording := false
var tick := 0
var sample_geometry: Dictionary = {}
var cut_face: Dictionary = {}
var room_key := "archive"
var face_crop := Rect2i()
var face_polygon := PackedVector2Array()
var allow_door_free_end := false
var corner_scan: Array[Dictionary] = []

func projected_face_crop(camera: Camera3D) -> Rect2i:
	var wall: Node3D=cut_face.wall
	var side: float=cut_face.side
	var height: float=cut_face.height
	var depth: float=wall.get_node("WallMesh").mesh.get_aabb().size.z
	var min_point:=Vector2(640,360)
	var max_point:=Vector2.ZERO
	var lower: float=0.0 if height<1 or int(cut_face.endpoint_neighbors)==1 else .85
	face_polygon.clear()
	for local in [Vector3(side*.5,lower,-depth*.5),Vector3(side*.5,lower,depth*.5),Vector3(side*.5,height,depth*.5),Vector3(side*.5,height,-depth*.5)]:
		face_polygon.append(camera.unproject_position(wall.to_global(local))*3.0)
	for y in [0.0 if height<1 or int(cut_face.endpoint_neighbors)==1 else .85,height]:
		for z in [-depth*.5,depth*.5]:
			var p: Vector2=camera.unproject_position(wall.to_global(Vector3(side*.5,y,z)))
			min_point=min_point.min(p); max_point=max_point.max(p)
	var start: Vector2i=Vector2i((min_point*3).floor())-Vector2i(30,30)
	var end: Vector2i=Vector2i((max_point*3).ceil())+Vector2i(30,30)
	start=start.max(Vector2i.ZERO); end=end.min(Vector2i(1920,1080))
	return Rect2i(start,end-start)

func wall_geometry_signature() -> Array:
	var result: Array=[]
	for visual in world.wall_root.find_children("*","MeshInstance3D",true,false):
		result.append([visual.get_instance_id(),visual.mesh.get_rid(),visual.mesh.get_surface_count()])
	return result

func choose_existing_cut_face() -> Dictionary:
	var walls: Array=[]
	var endpoints: Dictionary={}
	for wall in world.wall_root.get_children():
		if wall.get_node_or_null("WallMesh")==null or not wall.has_meta("edge"): continue
		walls.append(wall)
		for side in [-1.0,1.0]:
			var point: Vector3=world.to_local(wall.to_global(Vector3(side*.5,0,0)))
			var key:=Vector2i(roundi(point.x*32),roundi(point.z*32))
			if not endpoints.has(key): endpoints[key]=[]
			endpoints[key].append(wall)
	var best: Dictionary={}
	var score := -INF
	for wall in walls:
		var belongs := false
		for cell in world._edge_side_cells(wall.get_meta("edge")):
			if int(world.room_cells.get(cell,-1))==int(selected_room.id): belongs=true
		if not belongs: continue
		for side in [-1.0,1.0]:
			if bool(wall.get_meta("window_variant",false)):
				if side<0 and not bool(wall.get_meta("window_left_post",false)): continue
				if side>0 and not bool(wall.get_meta("window_right_post",false)): continue
			var point: Vector3=world.to_local(wall.to_global(Vector3(side*.5,0,0)))
			var key:=Vector2i(roundi(point.x*32),roundi(point.z*32))
			var exposed: bool=allow_door_free_end and endpoints[key].size()==1
			var full_to_cut := false
			var parallel_full_blocker := false
			var parallel_cut := false
			for other in endpoints[key]:
				if other==wall: continue
				var parallel: bool=absf(wall.global_basis.x.normalized().dot(other.global_basis.x.normalized()))>.99
				if parallel and not other.cutaway_mode: parallel_full_blocker=true
				if parallel and other.cutaway_mode: parallel_cut=true
				if other!=wall and not wall.cutaway_mode and other.cutaway_mode: exposed=true; full_to_cut=true
			if not exposed or parallel_full_blocker: continue
			var shown_height: float=world.wall_height*(.3 if wall.cutaway_mode else 1.0)
			var face_world: Vector3=wall.to_global(Vector3(side*.5,shown_height*.65,0))
			var normal: Vector3=wall.global_basis.x*side
			var facing := normal.dot(world.camera_3d.global_basis.z.normalized())
			if facing<.10: continue
			var candidate_score: float=facing+shown_height+(30.0 if parallel_cut else (10.0 if full_to_cut else 0.0))-Vector2(point.x,point.z).distance_to(Vector2(selected_room.center_cell))*.015
			if candidate_score>score:
				score=candidate_score
				best={"wall":wall,"edge":wall.get_meta("edge"),"side":side,"point_local":point,"face_world":face_world,"normal":normal,"facing":facing,"endpoint_neighbors":endpoints[key].size(),"height":shown_height}
	return best

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output=argument.trim_prefix("--artifact-dir=")
		if argument.begins_with("--room-key="): room_key=argument.trim_prefix("--room-key=")
	before_only="--before-only" in OS.get_cmdline_user_args()
	node_added.connect(func(node: Node) -> void:
		if node.get_script()!=null and node.get_script().resource_path=="res://scripts/dream/office_skeleton_world_base.gd":
			node.persist_profile=false; node.native_skeleton_type="V3"
	)
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)

func frames(count: int=1) -> void:
	for index in count:
		await RenderingServer.frame_post_draw
		if recording:
			clock+=1.0/60.0; tick+=1
			if tick%6==0:
				var file := "frame_%03d.png"%samples.size()
				root.get_texture().get_image().save_png(output+"/"+file)
				samples.append({"file":file,"game_seconds":clock,"player":world.player.global_position})

func snapshot(label: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(output+"/"+label+".png")
	if face_crop.has_area() and label in ["before","after","diagnostic_highlight_end"]:
		image.get_region(face_crop).save_png(output+"/"+label+"_end_detail.png")

func release_input() -> void:
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)

func walk_to(point: Vector2) -> bool:
	for index in 220:
		var delta: Vector2=point-world.player.global_position
		if delta.length()<7: release_input(); return true
		var best := Vector2.ZERO
		var score := -INF
		for candidate in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var mapped: Vector2=world.player._camera_relative_movement_input(candidate.normalized())
			var alignment := mapped.normalized().dot(delta.normalized())
			if alignment>score: score=alignment; best=candidate
		release_input()
		if best.x!=0: Input.action_press("move_right" if best.x>0 else "move_left")
		if best.y!=0: Input.action_press("move_down" if best.y>0 else "move_up")
		await frames()
	release_input(); return false

func physical_signature(node: Node) -> Array:
	var result: Array=[]
	for child in node.get_children():
		if child is CollisionObject2D: result.append([child.get_instance_id(),child.collision_layer,child.collision_mask])
		if child is CollisionShape2D: result.append([child.get_instance_id(),child.shape.get_rid(),child.disabled])
		if child is MeshInstance3D and "Shadow" in child.name: result.append([child.get_instance_id(),child.mesh.get_rid(),child.visible,child.cast_shadow])
		result.append_array(physical_signature(child))
	return result

func fog_signature() -> Array:
	var result: Array=[]
	if is_instance_valid(world.room_visibility) and is_instance_valid(world.room_visibility.cover_root):
		for child in world.room_visibility.cover_root.get_children():
			result.append([child.get_instance_id(),child.visible])
	return result

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	for index in 3600:
		await process_frame
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Actual Main enters formal floor")
	if failures.size(): quit(1); return
	world.native_skeleton_type="V3"; world.enable_game_start_cab_exit=false
	check(world.regenerate(120),"Actual V3 seed 120 floor generates")
	for room in world.rooms:
		if String(room.get("sample_key",""))==room_key: selected_room=room; break
	check(not selected_room.is_empty(),"Production meeting room selected without adding any walls")
	if failures.size(): quit(1); return
	var player: Node2D=world.player
	player.invulnerability_left=0.0; player.invulnerability_reason=&""; player.hurt_flash_left=0.0; player.revive_flash_left=0.0
	player.set_attacking_enabled(false); player.movement_enabled=true
	player.global_position=Vector2(selected_room.center_cell)*32.0; player.velocity=Vector2.ZERO
	world.activate_room(int(selected_room.id))
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	await frames(35)
	cut_face=choose_existing_cut_face()
	corner_scan.append({"room":selected_room.sample_key,"found":not cut_face.is_empty()})
	if cut_face.is_empty():
		for candidate_room in world.rooms:
			if candidate_room.id==selected_room.id or String(candidate_room.get("room_type",""))!="normal" or String(candidate_room.get("archetype",""))=="open_office": continue
			selected_room=candidate_room
			player.global_position=Vector2(selected_room.center_cell)*32.0; player.velocity=Vector2.ZERO
			world.activate_room(int(selected_room.id)); await frames(5)
			for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
			cut_face=choose_existing_cut_face()
			corner_scan.append({"room":selected_room.sample_key,"found":not cut_face.is_empty()})
			if not cut_face.is_empty(): break
	check(not cut_face.is_empty(),"Existing camera-facing vertical cut end selected without adding geometry")
	if cut_face.is_empty():
		var scan_file := FileAccess.open(output+"/corner_scan.json",FileAccess.WRITE); scan_file.store_string(JSON.stringify(corner_scan,"\t")); scan_file.close()
		quit(1); return
	var end_point: Vector3=cut_face.point_local
	var end_2d:=Vector2(end_point.x,end_point.z)
	var inward: Vector2=(Vector2(selected_room.center_cell)-end_2d).normalized()
	player.global_position=(end_2d+inward*2.3)*32.0; player.velocity=Vector2.ZERO
	await frames(35)
	var camera: Camera3D=world.camera_3d
	var camera_contract := [camera.projection,camera.fov,camera.size,camera.rotation,camera.get_viewport().size]
	var physical_before := physical_signature(world)
	var fog_before := fog_signature()
	var original_wall_geometry := wall_geometry_signature()
	var original_mesh_count := world.find_children("*","MeshInstance3D",true,false).size()
	var face_screen: Vector2=camera.unproject_position(cut_face.face_world)
	check(Rect2(Vector2.ZERO,Vector2(640,360)).has_point(face_screen),"Vertical cut end is inside actual gameplay Camera frame")
	face_crop=projected_face_crop(camera)
	sample_geometry={"cut_face_edge":cut_face.edge,"cut_face_side":cut_face.side,"cut_face_screen":face_screen,"cut_face_world":cut_face.face_world,"face_normal":cut_face.normal,"endpoint_neighbors":cut_face.endpoint_neighbors}
	var selected_edges: Array=[]
	var window_count := 0
	var interior_glass_count := 0
	var physical_door_count := 0
	for wall in world.wall_root.get_children():
		if wall.get("edge_data") is Dictionary:
			for cell in world._edge_side_cells(wall.edge_data):
				if int(world.room_cells.get(cell,-1))==int(selected_room.id): interior_glass_count+=1; break
		var edge: Dictionary=wall.get_meta("edge",{})
		if edge.is_empty(): continue
		var touches := false
		for cell in world._edge_side_cells(edge):
			if int(world.room_cells.get(cell,-1))==int(selected_room.id): touches=true
		if touches:
			selected_edges.append(edge)
			if bool(wall.get_meta("window_variant",false)): window_count+=1
	for door in world.door_root.get_children():
		if door.has_meta("door_edge") and (int(door.get_meta("region_a_id",-1))==int(selected_room.id) or int(door.get_meta("region_b_id",-1))==int(selected_room.id)):
			physical_door_count+=1
	check(physical_door_count>0,"Selected production room includes existing physical door")
	check(window_count+interior_glass_count>0,"Selected production room includes existing window or observation glass")
	snapshot("before")
	var source := FileAccess.open(output+"/selected_room.json",FileAccess.WRITE)
	source.store_string(JSON.stringify({"room":selected_room,"boundary_edges":selected_edges,"exterior_window_edges":window_count,"interior_glass_panes":interior_glass_count,"physical_doors":physical_door_count,"source":world.skeleton_source},"\t")); source.close()
	if not before_only:
		var script := load("res://scripts/dream/preview/wall_cut_face_texture_sample.gd")
		check(script!=null,"Preview-only style component exists")
		if script==null: quit(1); return
		var fixed_camera_transform: Transform3D=camera.global_transform
		world.set_process(false)
		var sample: Node=script.new(); world.add_child(sample); sample.apply(world,int(selected_room.id))
		var selected_mesh: MeshInstance3D=cut_face.wall.get_node("WallMesh")
		var selected_material: ShaderMaterial=selected_mesh.get_active_material(0)
		var applied_section: ImageTexture=selected_material.get_shader_parameter("section_pixels")
		check(applied_section!=null,"Selected vertical end material binds the new section texture")
		if applied_section==null: quit(1); return
		applied_section.get_image().save_png(output+"/section_texture.png")
		await frames(12); snapshot("after")
		check(wall_geometry_signature()==original_wall_geometry,"Wall mesh RID and original surface counts are unchanged")
		check(world.find_children("*","MeshInstance3D",true,false).size()==original_mesh_count,"Texture sample adds zero geometry or wall meshes")
		sample_geometry={"added_meshes":0,"added_vertices":0,"texture_size":applied_section.get_size(),"selected_walls":sample.selected_walls.size(),"selected_actors":sample.selected_actors.size(),"cut_face_edge":cut_face.edge,"cut_face_side":cut_face.side,"cut_face_screen":face_screen,"cut_face_world":cut_face.face_world,"face_normal":cut_face.normal,"endpoint_neighbors":cut_face.endpoint_neighbors}
		check(camera.global_transform==fixed_camera_transform,"Before and after screenshots preserve identical Camera transform")
		# Diagnostic tint changes only the new section texture, proving its pixels
		# reach the actual vertical end region. Restore before all final frames.
		var actual_section: Image=applied_section.get_image()
		var actual_frame: Image=root.get_texture().get_image()
		var diagnostic_section: Image=actual_section.duplicate()
		diagnostic_section.fill(Color(1,0,0))
		applied_section.update(diagnostic_section)
		await frames(2); snapshot("diagnostic_highlight_end")
		var diagnostic_frame: Image=root.get_texture().get_image()
		var changed_vertical := 0
		for y in range(face_crop.position.y+face_crop.size.y/2,face_crop.end.y):
			for x in range(face_crop.position.x,face_crop.end.x):
				if not Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),face_polygon): continue
				var a := actual_frame.get_pixel(x,y)
				var b := diagnostic_frame.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.03: changed_vertical+=1
		check(changed_vertical>3,"GPU diagnostic changes pixels inside lower vertical end face, excluding top")
		sample_geometry["diagnostic_lower_vertical_pixels_changed"]=changed_vertical
		applied_section.update(actual_section); await frames(3)
		# Outside-mask shader writes COLOR.a explicitly, so Canvas modulate.a
		# cannot disable it. Pause its updater for the diagnostic hide instead.
		var visibility_processing: bool=world.room_visibility.is_processing()
		world.room_visibility.set_process(false)
		var outside_mask: Control=world.room_visibility.outside_black_gradient
		var outside_visible := outside_mask.visible
		outside_mask.hide(); await frames(2); snapshot("diagnostic_no_outside_mask")
		outside_mask.visible=outside_visible
		world.room_visibility.set_process(visibility_processing); await frames(2)
		check(physical_signature(world)==physical_before,"Collision shapes, layers and shadow meshes remain identical after styling")
		check(fog_signature()==fog_before,"Existing unexplored-room fog covers retain their visibility")
		check([camera.projection,camera.fov,camera.size,camera.rotation,camera.get_viewport().size]==camera_contract,"Actual gameplay Camera projection angle FOV and pixel viewport unchanged")
		world.set_process(true)
		recording=true
		await frames(30)
		# Capture ordinary input motion; stop if furniture prevents reaching a point.
		var origin: Vector2=player.global_position
		var moved := false
		for offset in [Vector2(0,48),Vector2(-48,0),Vector2(0,-48),Vector2(48,0)]:
			var start: Vector2=player.global_position
			await walk_to(origin+offset)
			moved=moved or player.global_position.distance_to(start)>12
			await frames(8)
		await frames(30)
		recording=false; snapshot("after_walk")
		check(moved,"Real camera-relative player input moves inside the production room")
		check(player.visual.visible,"Player remains visible without invulnerability flashing")
		check(int(world.current_room_id)==int(selected_room.id),"Walking sample stays in selected room")
		player.movement_enabled=false; player.velocity=Vector2.ZERO
		await frames(3)
		var physical_before_restore := physical_signature(world)
		sample.restore(); await frames(3)
		check(sample.selected_walls.is_empty(),"Preview instance can restore its original presentation")
		check(physical_signature(world)==physical_before_restore,"Restore also retains current collision shapes and shadow caster resources")
	sample_geometry["face_crop_pixels"]=[face_crop.position.x,face_crop.position.y,face_crop.end.x,face_crop.end.y]
	sample_geometry["face_polygon_pixels"]=Array(face_polygon)
	sample_geometry["corner_scan"]=corner_scan
	var report := {"checks":checks,"failures":failures,"sample_geometry":sample_geometry,"main_entry":true,"production_floor":"V3","seed":120,"room_id":selected_room.id,"room_key":selected_room.sample_key,"window_edges":window_count,"interior_glass_panes":interior_glass_count,"physical_doors":physical_door_count,"boundary_edges":selected_edges.size(),"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"camera_contract":camera_contract,"samples":samples,"before_only":before_only,"test_scope":"Actual Main floor and game Camera. AI processing disabled to isolate architectural presentation. Player placed in generated room; subsequent motion uses ordinary input. No combat, room-to-corridor transition, four-skeleton or performance acceptance claim."}
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FLOOR_WALL_CUT_FACE_TEXTURE ",JSON.stringify({"checks":checks,"failures":failures,"room":selected_room.sample_key}))
	main.free(); quit(1 if failures.size() else 0)
