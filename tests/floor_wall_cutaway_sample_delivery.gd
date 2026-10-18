extends SceneTree
## Opt-in presentation sample, entered through production Main. Never installed by Main.
var output := "res://.runtime/wall_cutaway_sample_20261015/camera"
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

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output=argument.trim_prefix("--artifact-dir=")
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
	root.get_texture().get_image().save_png(output+"/"+label+".png")

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
		if child is CollisionObject2D: result.append([child.get_instance_id(),child.collision_layer,child.collision_mask,child.global_position])
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
		if String(room.get("sample_key",""))=="meeting": selected_room=room; break
	check(not selected_room.is_empty(),"Production meeting room selected without adding any walls")
	if failures.size(): quit(1); return
	var player: Node2D=world.player
	player.invulnerability_left=0.0; player.invulnerability_reason=&""; player.hurt_flash_left=0.0; player.revive_flash_left=0.0
	player.set_attacking_enabled(false); player.movement_enabled=true
	player.global_position=Vector2(selected_room.center_cell)*32.0; player.velocity=Vector2.ZERO
	world.activate_room(int(selected_room.id))
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	await frames(35)
	var camera: Camera3D=world.camera_3d
	var camera_contract := [camera.projection,camera.fov,camera.size,camera.rotation,camera.get_viewport().size]
	var physical_before := physical_signature(world)
	var fog_before := fog_signature()
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
		var script := load("res://scripts/dream/preview/wall_cutaway_style_sample.gd")
		check(script!=null,"Preview-only style component exists")
		if script==null: quit(1); return
		var fixed_camera_transform: Transform3D=camera.global_transform
		world.set_process(false)
		var sample: Node=script.new(); world.add_child(sample); sample.apply(world,int(selected_room.id))
		await frames(12); snapshot("after")
		check(sample.cap_vertex_count>0 and sample.cap_batch_count>0,"Selected-room continuous wall tops contain actual mesh geometry")
		sample_geometry={"vertices":sample.cap_vertex_count,"batches":sample.cap_batch_count,"raster_cells":sample.cap_raster_cells,"selected_walls":sample.selected_walls.size(),"selected_actors":sample.selected_actors.size()}
		check(camera.global_transform==fixed_camera_transform,"Before and after screenshots preserve identical Camera transform")
		# Extra diagnostic only: distinguish pre-existing outer darkness from the
		# selected wall/cap. Never use this frame as the approved after image.
		var wall_visibility: Dictionary={}
		for wall in sample.selected_walls:
			var mesh: MeshInstance3D=wall.get_node("WallMesh")
			wall_visibility[mesh]=mesh.visible; mesh.hide()
		sample._surface_root.hide(); await frames(2); snapshot("diagnostic_hidden_selected_walls")
		for mesh in wall_visibility: mesh.visible=wall_visibility[mesh]
		sample._surface_root.show(); await frames(3)
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
		var physical_before_restore := physical_signature(world)
		sample.restore(); await frames(3)
		check(sample.cap_vertex_count==0 and sample.selected_walls.is_empty(),"Preview instance can restore its original presentation")
		check(physical_signature(world)==physical_before_restore,"Restore also retains current collision shapes and shadow caster resources")
	var report := {"checks":checks,"failures":failures,"sample_geometry":sample_geometry,"main_entry":true,"production_floor":"V3","seed":120,"room_id":selected_room.id,"room_key":selected_room.sample_key,"window_edges":window_count,"interior_glass_panes":interior_glass_count,"physical_doors":physical_door_count,"boundary_edges":selected_edges.size(),"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"camera_contract":camera_contract,"samples":samples,"before_only":before_only,"test_scope":"Actual Main floor and game Camera. AI processing disabled to isolate architectural presentation. Player placed in generated room; subsequent motion uses ordinary input. No combat, room-to-corridor transition, four-skeleton or performance acceptance claim."}
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FLOOR_WALL_CUTAWAY_SAMPLE ",JSON.stringify({"checks":checks,"failures":failures,"room":selected_room.sample_key}))
	main.free(); quit(1 if failures.size() else 0)
