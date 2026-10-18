extends "res://tests/floor_wall_cut_face_texture_delivery.gd"
## A separate acceptance target: original wall instances change shape, not a
## material-only end face and not the discarded joined-top sample.
var root_chain: Array[Dictionary]=[]
var composition_box := Rect2i()

func _initialize() -> void:
	output="res://.runtime/wall_root_cutaway_20261015/camera"
	room_key="archive"
	super._initialize()

func snapshot(label: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(output+"/"+label+".png")
	if composition_box.has_area(): image.get_region(composition_box).save_png(output+"/"+label+"_composition.png")
	if not root_chain.is_empty():
		for index in 2:
			var point: Vector3=root_chain[0].near if index==0 else root_chain[-1].far
			point.y=float(world.wall_height)
			var center: Vector2i=Vector2i(world.camera_3d.unproject_position(world.to_global(point))*3)
			var start: Vector2i=(center-Vector2i(100,100)).clamp(Vector2i.ZERO,image.get_size()-Vector2i(200,200))
			image.get_region(Rect2i(start,Vector2i(200,200))).save_png(output+"/"+label+"_corner_%s.png"%index)

func wall_instance_ids() -> Array:
	var ids: Array=[]
	for visual in world.wall_root.find_children("*","MeshInstance3D",true,false): ids.append(visual.get_instance_id())
	return ids

func full_junction_between(a: Dictionary,b: Dictionary)->bool:
	var point: Vector3=(a.wall.global_position+b.wall.global_position)*.5
	for wall in world.wall_root.get_children():
		if wall.get_node_or_null("WallMesh")==null or bool(wall.cutaway_mode): continue
		if absf(wall.global_basis.x.normalized().dot(a.wall.global_basis.x.normalized()))>.1: continue
		for side in [-.5,.5]:
			if wall.to_global(Vector3(side,0,0)).distance_to(point)<.01: return true
	return false

func find_root_chain() -> Array[Dictionary]:
	var chain: Array[Dictionary]=[]
	var groups: Dictionary={}
	for wall in world.wall_root.get_children():
		if wall.get_node_or_null("WallMesh")==null or wall.get("cutaway_mode")!=true: continue
		var belongs:=false
		for cell in world._edge_side_cells(wall.get_meta("edge",{})):
			if int(world.room_cells.get(cell,-1))==int(selected_room.id): belongs=true
		if not belongs: continue
		var edge: Dictionary=wall.get_meta("edge")
		var horizontal: bool=edge.axis=="H"
		var key:="%s:%s"%[edge.axis,edge.y if horizontal else edge.x]
		if not groups.has(key): groups[key]=[]
		groups[key].append({"wall":wall,"edge":edge,"order":int(edge.x if horizontal else edge.y),"near":world.to_local(wall.to_global(Vector3(-.5,0,0))),"far":world.to_local(wall.to_global(Vector3(.5,0,0)))})
	for group: Array in groups.values():
		group.sort_custom(func(a,b): return a.order<b.order)
		var run: Array[Dictionary]=[]
		for link: Dictionary in group:
			if not run.is_empty() and (link.order!=run[-1].order+1 or full_junction_between(run[-1],link)):
				if run.size()>=3 and (chain.is_empty() or run.size()<chain.size()): chain=run.duplicate()
				run.clear()
			run.append(link)
		if run.size()>=3 and (chain.is_empty() or run.size()<chain.size()): chain=run.duplicate()
	print("U_RUN_SELECTION ",chain.map(func(link): return link.edge))
	return chain

func composition_crop(camera: Camera3D) -> Rect2i:
	var low:=Vector2(1920,1080)
	var high:=Vector2.ZERO
	var points: Array[Vector3]=[]
	for link in root_chain:
		for p in [link.near,link.far]:
			for offset in [Vector3(-.25,0,-.25),Vector3(.25,float(world.wall_height),.25)]: points.append(world.to_global(p+offset))
	for point in points:
		var pixel: Vector2=camera.unproject_position(point)*3
		low=low.min(pixel); high=high.max(pixel)
	var a:=Vector2i((low-Vector2(36,36)).floor()).max(Vector2i.ZERO)
	var b:=Vector2i((high+Vector2(36,36)).ceil()).min(Vector2i(1920,1080))
	return Rect2i(a,b-a)

func mesh_ids() -> Dictionary:
	var ids: Dictionary={}
	for wall in world.wall_root.get_children():
		var visual := wall.get_node_or_null("WallMesh") as MeshInstance3D
		if visual!=null: ids[wall.get_instance_id()]=visual.mesh.get_rid()
	return ids

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
	check(is_instance_valid(world) and not main.transition_running,"Actual Main enters production game floor")
	if failures.size(): quit(1); return
	world.native_skeleton_type="V3"; world.enable_game_start_cab_exit=false
	check(world.regenerate(120),"Production V3 seed 120 floor generates")
	for room in world.rooms:
		if String(room.get("sample_key",""))==room_key: selected_room=room; break
	check(not selected_room.is_empty(),"Original generated enclosed room is available")
	if failures.size(): quit(1); return
	var player: Node2D=world.player
	player.invulnerability_left=0.0; player.invulnerability_reason=&""; player.hurt_flash_left=0.0; player.revive_flash_left=0.0
	player.set_attacking_enabled(false); player.movement_enabled=true
	player.global_position=Vector2(selected_room.center_cell)*32; player.velocity=Vector2.ZERO
	world.activate_room(int(selected_room.id))
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	await frames(35)
	root_chain=find_root_chain()
	check(root_chain.size()>=3,"An entire straight cut run is selected, including both ends")
	if root_chain.size()<3: quit(1); return
	cut_face={"wall":root_chain[0].wall,"edge":root_chain[0].edge,"side":-1.0}
	var end_point: Vector3=Vector3.ZERO
	for link in root_chain: end_point+=world.to_local(link.wall.global_position)
	end_point/=root_chain.size()
	var end_2d:=Vector2(end_point.x,end_point.z)
	player.global_position=(end_2d+(Vector2(selected_room.center_cell)-end_2d).normalized()*2.0)*32; player.velocity=Vector2.ZERO
	await frames(35)
	var camera: Camera3D=world.camera_3d
	var camera_contract := [camera.projection,camera.fov,camera.size,camera.global_transform,camera.get_viewport().size]
	composition_box=composition_crop(camera)
	var composition_points: Array=[]
	for link in root_chain:
		var screen: Vector2=camera.unproject_position(world.to_global(link.far))
		composition_points.append(screen)
		check(Rect2(Vector2.ZERO,Vector2(640,360)).has_point(screen),"Consecutive wall root endpoint remains inside original Camera")
	var physical_before:=physical_signature(world)
	var fog_before:=fog_signature()
	var original_instances:=wall_instance_ids()
	var original_meshes:=mesh_ids()
	var original_total_meshes: int=world.find_children("*","MeshInstance3D",true,false).size()
	world.set_process(false)
	snapshot("before")
	var script := load("res://scripts/dream/preview/wall_root_cutaway_sample.gd")
	check(script!=null,"New isolated wall-root shape component is available")
	if script==null: quit(1); return
	var sample: Node=script.new(); world.add_child(sample); sample.apply(world,int(selected_room.id))
	await frames(12); snapshot("after")
	if "--diagnostic" in OS.get_cmdline_user_args():
		# Temporary probes only; restore all presentation before recording.
		sample.set_process(false)
		var saved_caps: Dictionary={}
		var white:=StandardMaterial3D.new(); white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; white.albedo_color=Color.WHITE
		for link in root_chain:
			var visual: MeshInstance3D=link.wall.wall_mesh
			saved_caps[visual]=visual.get_surface_override_material(2)
			visual.set_surface_override_material(2,white)
		await frames(3); snapshot("diagnostic_root_white")
		for visual in saved_caps: visual.set_surface_override_material(2,saved_caps[visual])
		var mask: Control=world.room_visibility.outside_black_gradient
		var mask_visible:=mask.visible
		world.room_visibility.set_process(false); mask.hide()
		await frames(3); snapshot("diagnostic_no_outside_mask")
		mask.visible=mask_visible; world.room_visibility.set_process(true)
		var facades: Array=world.find_children("CurrentBuildingFacade","MeshInstance3D",true,false)
		var facade_states: Array=[]
		for facade in facades: facade_states.append(facade.visible); facade.hide()
		await frames(3); snapshot("diagnostic_no_facade")
		for index in facades.size(): facades[index].visible=facade_states[index]
		sample.set_process(true); sample._process(0)
		await frames(3)
	check(wall_instance_ids()==original_instances,"Original wall MeshInstance identities are preserved")
	check(world.find_children("*","MeshInstance3D",true,false).size()==original_total_meshes,"Sample adds zero wall or scene MeshInstances")
	check(physical_signature(world)==physical_before,"Original collider resources, layers and full-height shadow meshes are preserved")
	check(fog_signature()==fog_before,"Original exploration fog visibility is preserved")
	check([camera.projection,camera.fov,camera.size,camera.global_transform,camera.get_viewport().size]==camera_contract,"Before and after use identical actual Camera projection, transform and pixel viewport")
	var changed_meshes := 0
	for wall in world.wall_root.get_children():
		if original_meshes.has(wall.get_instance_id()) and wall.get_node("WallMesh").mesh.get_rid()!=original_meshes[wall.get_instance_id()]: changed_meshes+=1
	check(changed_meshes>0,"New shape replaces visible wall mesh resources inside existing instances")
	var root_geometry: Array=[]
	var full_visible_mesh: Mesh=cut_face.wall.get_node("WallMesh").mesh
	check(absf(full_visible_mesh.get_aabb().end.y-float(world.wall_height))<.01,"Vertical cut remains full height above the short foot")
	for index in root_chain.size():
		var link: Dictionary=root_chain[index]
		var mesh: Mesh=link.wall.get_node("WallMesh").mesh
		root_geometry.append({"edge":link.edge,"height_max":mesh.get_aabb().end.y,"near":link.near,"far":link.far})
		if index==0:
			var arrays: Array=mesh.surface_get_arrays(2)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var slope_min := INF
			var slope_max := -INF
			for vertex_index in vertices.size():
				if absf(normals[vertex_index].x)>.1 and normals[vertex_index].y>.1:
					slope_min=minf(slope_min,vertices[vertex_index].x); slope_max=maxf(slope_max,vertices[vertex_index].x)
			var slope_length: float=slope_max-slope_min
			check(is_finite(slope_length) and slope_length>.05 and slope_length<=.35,"Transition slope occupies only a short foot, not a full wall segment")
			root_geometry[index]["measured_slope_length"]=slope_length
		if index>0 and index<root_chain.size()-1: check(mesh.get_aabb().end.y<=.30,"Middle of the same straight run stays near the floor")
		if index==root_chain.size()-1: check(absf(mesh.get_aabb().end.y-float(world.wall_height))<.01,"Opposite end retains full height, completing a U on the same straight wall")
	world.set_process(true); recording=true; await frames(30)
	var origin: Vector2=player.global_position
	var moved := false
	for offset in [Vector2(32,0),Vector2(32,32),Vector2(0,32),Vector2.ZERO]:
		var start: Vector2=player.global_position
		await walk_to(origin+offset)
		moved=moved or player.global_position.distance_to(start)>10
		await frames(10)
	await frames(30); recording=false; snapshot("after_walk")
	check(moved,"Ordinary camera-relative input moves the player in the original room")
	check(player.visual.visible,"Player remains visible without invulnerability flashing")
	check(int(world.current_room_id)==int(selected_room.id),"Sample walking remains in the original room")
	var corner_detail: Dictionary={}
	if "--corner-detail" in OS.get_cmdline_user_args():
		var candidates: Array=[]
		for wall in sample.selected_walls:
			for key: String in sample.joined_meshes:
				if wall.wall_mesh.mesh!=sample.joined_meshes[key]: continue
				var source: Mesh=instance_from_id(int(key.get_slice(":",0)))
				var original: PackedVector3Array=source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var joined: PackedVector3Array=wall.wall_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex_index in original.size():
					if absf(original[vertex_index].x-joined[vertex_index].x)<.001: continue
					var side: float=signf(original[vertex_index].x)
					var point: Vector3=world.to_local(wall.to_global(Vector3(side*.5,0,0)))
					candidates.append({"wall":wall,"source":source,"point":point,"distance":Vector2(point.x,point.z).distance_squared_to(player.global_position/32)})
					break
		check(not candidates.is_empty(),"Actual generated room contains an original L corner with a miter join")
		if not candidates.is_empty():
			candidates.sort_custom(func(a,b): return a.distance<b.distance)
			var target: Dictionary=candidates[0]
			var point_2d:=Vector2(target.point.x,target.point.z)
			player.global_position=(point_2d+(Vector2(selected_room.center_cell)-point_2d).normalized()*2)*32
			player.velocity=Vector2.ZERO; await frames(35)
			world.set_process(false); sample.set_process(false)
			var visual: MeshInstance3D=target.wall.wall_mesh
			var joined_mesh: Mesh=visual.mesh
			var pixel:=Vector2i(camera.unproject_position(world.to_global(target.point+Vector3(0,float(world.wall_height),0)))*3)
			var corner_box:=Rect2i((pixel-Vector2i(120,120)).clamp(Vector2i.ZERO,Vector2i(1680,840)),Vector2i(240,240))
			visual.mesh=target.source; await frames(3)
			root.get_texture().get_image().save_png(output+"/corner_before_full.png")
			root.get_texture().get_image().get_region(corner_box).save_png(output+"/corner_before.png")
			visual.mesh=joined_mesh; await frames(3)
			root.get_texture().get_image().save_png(output+"/corner_after_full.png")
			root.get_texture().get_image().get_region(corner_box).save_png(output+"/corner_after.png")
			corner_detail={"edge":target.wall.get_meta("edge"),"point":target.point,"crop":corner_box,"comparison":"Same actual Camera and cut shape; only this wall endpoint switches between square butt and miter. Player initially placed near original room corner for visibility."}
			sample.set_process(true)
	var sample_stats: Dictionary={"root_wall_count":sample.root_wall_count,"foot_count":sample.foot_count,"root_height":sample.root_height,"knee_height":sample.knee_height,"bevel_length":sample.bevel_length,"visual_thickness":sample.visual_thickness}
	player.movement_enabled=false; player.velocity=Vector2.ZERO; await frames(3)
	var physical_before_restore:=physical_signature(world)
	sample.restore(); await frames(3)
	check(physical_signature(world)==physical_before_restore,"Restoring sample also leaves collision and shadow resources intact")
	var report: Dictionary={"checks":checks,"failures":failures,"main_entry":true,"seed":120,"skeleton":"V3","room_id":selected_room.id,"room_key":selected_room.sample_key,"target_full_wall_edge":cut_face.edge,"target_full_wall_side":cut_face.side,"root_chain":root_geometry,"changed_existing_mesh_resources":changed_meshes,"added_mesh_instances":0,"composition_crop_pixels":[composition_box.position.x,composition_box.position.y,composition_box.end.x,composition_box.end.y],"root_chain_screen_endpoints":composition_points,"camera_contract":camera_contract,"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"samples":samples,"scope":"Actual Main production archive floor. AI processing paused; initial player placement is a fixture, subsequent motion uses ordinary input. Camera unchanged. Full-height end, short foot and at least two root segments must be read together. No global deployment, four-skeleton, combat or performance acceptance claim."}
	report["sample_stats"]=sample_stats
	report["corner_detail"]=corner_detail
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FLOOR_WALL_ROOT_CUTAWAY ",JSON.stringify({"checks":checks,"failures":failures,"root_segments":root_chain.size()}))
	main.free(); quit(1 if failures.size() else 0)
