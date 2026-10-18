extends "res://tests/floor_wall_cut_face_texture_delivery.gd"
const ART=preload("res://scripts/dream/preview/sample_wall_and_desktop_review.gd")
const STYLE=preload("res://scripts/dream/office_art_room_style.gd")
var captures: Array=[]
var measurements: Array=[]
var texture_checks: Dictionary={}

func _initialize()->void:
	output="res://.runtime/office_wall_cutaway_20261015/camera"
	super._initialize()

func validate_materials()->void:
	var faces_ok:=true
	var textures_ok:=true
	var profiles_ok:=true
	for wall in world.office_wall_cutaway.walls:
		profiles_ok=profiles_ok and wall.office_full_mesh!=null and wall.office_cut_mesh!=null
		var cells: Array=world._edge_side_cells(wall.get_meta("edge"))
		for surface in 2:
			var source: Material=wall.wall_material_front if surface==0 else wall.wall_material_back
			faces_ok=faces_ok and wall.wall_mesh.get_active_material(surface)==source
			if not source is ShaderMaterial: textures_ok=false; continue
			var room_id: int=world.room_cells.get(cells[1 if surface==0 else 0],-1)
			var key: String=STYLE.key(world.rooms[room_id]) if room_id>=0 else "outside"
			if room_id>=0 and String(world.rooms[room_id].get("room_type",""))=="corridor": key="corridor"
			if wall.window_variant: key="window_frame"
			var texture: Texture2D=source.get_shader_parameter("atlas")
			if texture==null: textures_ok=false; continue
			var cache_key:="%d:%s"%[texture.get_instance_id(),key]
			if not texture_checks.has(cache_key):
				var expected: Image=ART.window_frame_image(world.wall_height) if key=="window_frame" else ART.wall_image(key,world.wall_height)
				texture_checks[cache_key]=texture.get_image().get_data()==expected.get_data()
			textures_ok=textures_ok and texture_checks[cache_key]
	check(faces_ok,"Every front and back face retains its own original room material resource")
	check(textures_ok,"Every wall atlas matches the existing room-specific approved pixels")
	check(profiles_ok,"Production geometry is installed on all original straight wall instances")
	var full_doors:=true
	var door_count:=0
	for door in world.door_root.get_children():
		if not door.has_method("set_architectural_cutaway"): continue
		door_count+=1
		for visual in door.find_children("*","MeshInstance3D",true,false):
			if visual.name=="ArchitecturalCutSurface": full_doors=full_doors and not visual.visible
			if visual.material_override is ShaderMaterial:
				full_doors=full_doors and visual.material_override.get_shader_parameter("architecture_cutaway")!=true
	for frame in world.floor_root.get_children():
		if not frame.has_method("set_architectural_cutaway") or not frame.has_meta("door_edge"): continue
		full_doors=full_doors and frame.visual.material_override.get_shader_parameter("architecture_cutaway")!=true
		for cap in frame.caps: full_doors=full_doors and not cap.visible
	check(door_count>0 and full_doors,"Office doors, attached glass and door frames stay full height after every room/floor change")

func run()->void:
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
	check(is_instance_valid(world) and world.office_wall_cutaway!=null,"Actual Main automatically installs production cutaway without a preview component")
	if failures.size(): quit(1); return
	world.enable_game_start_cab_exit=false
	var player: Node2D=world.player
	player.set_attacking_enabled(false)
	for type in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=type
		check(world.regenerate(120),type+" production floor regenerates with geometry installed")
		await frames(15)
		for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
		var styles: Dictionary={}
		for room in world.rooms:
			player.global_position=Vector2(room.center_cell)*32; player.velocity=Vector2.ZERO
			player.invulnerability_left=0; player.invulnerability_reason=&""; player.hurt_flash_left=0; player.revive_flash_left=0
			world.room_visibility.set_current_presentation_room(int(room.id))
			await frames(5)
			validate_materials()
			var style: String=STYLE.key(room); styles[style]=true
			var file:="%s_%02d_%s.png"%[type,int(room.id),room.sample_key]
			root.get_texture().get_image().save_png(output+"/"+file)
			captures.append({"file":file,"type":type,"room_id":room.id,"room_key":room.sample_key,"style":style})
			measurements.append({"type":type,"room":room.id,"refresh_usec":world.office_wall_cutaway.last_refresh_usec})
		check(styles.size()>=4,type+" keeps multiple original room styles")
		var physics_before:=physical_signature(world.collision_root)
		var shadows_before:=physical_signature(world.wall_root)
		world.office_wall_cutaway.refresh()
		check(physical_signature(world.collision_root)==physics_before and physical_signature(world.wall_root)==shadows_before,type+" geometry refresh leaves collider and full-height shadow resources unchanged")
		var refreshes: int=world.office_wall_cutaway.refresh_count
		await frames(10)
		check(world.office_wall_cutaway.refresh_count==refreshes,type+" geometry has no per-frame wall rebuild")
	# Use the actual rendered elevator transition, including staged generation.
	var previous_controller: RefCounted=world.office_wall_cutaway
	var previous_floor: int=world.floor_index
	world.collect_employee_badge(); world._begin_elevator_entry_transition()
	var deadline: int=Time.get_ticks_msec()+60000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	check(world.floor_index==previous_floor+1 and not world.floor_transition_in_progress,"Actual elevator completes staged loading and arrival")
	check(world.office_wall_cutaway!=previous_controller and world.office_wall_cutaway.walls[0].get_parent()==world.wall_root,"Staged elevator generation installs a new floor-owned geometry controller")
	await frames(10); validate_materials()
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	root.get_texture().get_image().save_png(output+"/after_real_elevator.png")
	# Walk with the actual Camera in one representative final-floor archive.
	for room in world.rooms:
		if room.sample_key=="archive": selected_room=room; break
	player.global_position=Vector2(selected_room.center_cell)*32
	player.invulnerability_left=0; player.invulnerability_reason=&""; player.hurt_flash_left=0; player.revive_flash_left=0
	world.activate_room(int(selected_room.id)); await frames(15)
	var origin: Vector2=player.global_position
	recording=true
	await frames(20)
	await walk_to(origin+Vector2(32,0)); await frames(15)
	await walk_to(origin); await frames(20)
	recording=false
	check(player.visual.visible,"Recorded player is visible without flashing")
	validate_materials()
	# Exercise the actual floor transaction and its original art/controller restoration.
	var old_controller: RefCounted=world.office_wall_cutaway
	var old_art: Node=world.office_art_root.get_child(0)
	var old_index: int=world.floor_index
	paused=true
	check(await world._regenerate_staged(121,old_index+1,world.transition_generation_token,true),"Replacement floor builds through the staged generator inside existing rollback transaction")
	world._rollback_failed_transition(world.transition_generation_token,old_index)
	paused=false
	await frames(15)
	check(world.office_wall_cutaway==old_controller and is_instance_valid(old_art) and old_art.get_parent()==world.office_art_root,"Rollback restores original per-room art and matching geometry controller")
	world.room_visibility.set_current_presentation_room(int(selected_room.id)); await frames(5)
	validate_materials()
	var report: Dictionary={"checks":checks,"failures":failures,"captures":captures,"samples":samples,"measurements":measurements,"texture_bindings_checked":texture_checks.size(),"main_entry":true,"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"scope":"Actual Main plus all four native skeletons, every generated room at seed120, original front/back atlas pixels and identities, room switching, regeneration and rollback. Room capture positions are fixtures; one sequence uses ordinary movement. AI paused to isolate architecture; no combat FPS claim."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("OFFICE_WALL_CUTAWAY ",JSON.stringify({"checks":checks,"failures":failures,"captures":captures.size()}))
	main.free(); quit(1 if failures.size() else 0)
