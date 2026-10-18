extends "res://tests/floor_wall_cut_face_texture_delivery.gd"
var comparisons: Array=[]
func _initialize()->void:
	output="res://.runtime/door_outline_20261016/camera"
	super._initialize()

func door_crop(door: Node3D)->Rect2i:
	var low:=Vector2(1920,1080); var high:=Vector2.ZERO
	for visual in [door.left_visual,door.right_visual]:
		if not visual.is_visible_in_tree(): continue
		var box: AABB=visual.mesh.get_aabb()
		for i in 8:
			var pixel: Vector2=world.camera_3d.unproject_position(visual.to_global(box.get_endpoint(i)))*3
			low=low.min(pixel); high=high.max(pixel)
	var start:=Vector2i((low-Vector2(45,45)).floor()).max(Vector2i.ZERO)
	var end:=Vector2i((high+Vector2(45,45)).ceil()).min(Vector2i(1920,1080))
	return Rect2i(start,end-start)

func run()->void:
	if DisplayServer.get_name()=="headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	for i in 3600:
		await process_frame
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Actual Main enters the formal floor")
	if failures.size(): quit(1); return
	world.native_skeleton_type="V3"; world.enable_game_start_cab_exit=false
	check(world.regenerate(120),"Actual V3 floor generates")
	await frames(15)
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	var art: Node=world.office_art_root.get_child(0).walls
	var chosen: Dictionary={}
	for record in art.doors:
		if not chosen.has(record.style): chosen[record.style]=record
	var baseline=load("res://tests/support/door_texture_before_outline.gd")
	var player: Node2D=world.player
	player.set_attacking_enabled(false)
	player.invulnerability_left=0; player.invulnerability_reason=&""; player.hurt_flash_left=0; player.revive_flash_left=0
	for style in ["solid","window","glass"]:
		check(chosen.has(style),"Production contains "+style+" door")
		if not chosen.has(style): continue
		var record: Dictionary=chosen[style]
		var door: Node3D=record.door.get_ref()
		var id: int=door.get_meta("region_a_id",-1)
		if id<0: id=int(door.get_meta("region_b_id",-1))
		check(id>=0,"Door has a real adjacent room")
		if id<0: continue
		var center: Vector3=world.to_local(door.global_position)
		var at:=Vector2(center.x,center.z)
		player.global_position=(at+(Vector2(world.rooms[id].center_cell)-at).normalized()*2.2)*32
		player.velocity=Vector2.ZERO; world.room_visibility.set_current_presentation_room(id)
		await frames(25)
		# Freeze only world camera updates, leaving native output sizing active.
		world.set_process(false); player.set_physics_process(false)
		root.size=Vector2i(1920,1080)
		var box:=door_crop(door)
		var originals: Dictionary={}
		var mesh_ids: Array=[]
		for leaf in record.leaves:
			var visual: MeshInstance3D=leaf.node.get_ref()
			mesh_ids.append(visual.mesh.get_rid())
			originals[visual]=visual.material_override.get_shader_parameter("atlas")
			visual.material_override.set_shader_parameter("atlas",ImageTexture.create_from_image(baseline.door_image(leaf.size,style,leaf.index)))
		var camera_contract: Transform3D=world.camera_3d.global_transform
		var physical_before:=physical_signature(door)
		await frames(3)
		check(root.get_texture().get_image().get_size()==Vector2i(1920,1080),"A/B capture retains full-sized GPU output")
		root.get_texture().get_image().save_png(output+"/"+style+"_before_full.png")
		root.get_texture().get_image().get_region(box).save_png(output+"/"+style+"_before.png")
		for visual in originals: visual.material_override.set_shader_parameter("atlas",originals[visual])
		await frames(3)
		root.get_texture().get_image().save_png(output+"/"+style+"_after_full.png")
		root.get_texture().get_image().get_region(box).save_png(output+"/"+style+"_after.png")
		check(world.camera_3d.global_transform.is_equal_approx(camera_contract),"Texture comparison uses identical actual Camera")
		check(physical_signature(door)==physical_before,"Painting leaves door physics and full-height shadow resources unchanged")
		for i in record.leaves.size():
			var visual: MeshInstance3D=record.leaves[i].node.get_ref()
			check(visual.mesh.get_rid()==mesh_ids[i] and visual.material_override.get_shader_parameter("architecture_cutaway")!=true,"Material contours add no geometry and retain full-height doors")
		comparisons.append({"style":style,"door_id":door.door_id,"room_id":id,"crop":box})
		world.set_process(true); player.set_physics_process(true)
		if style=="solid":
			recording=true; await frames(10)
			check(door.apply_door_impact(&"player_push",door.left_leaf.global_position+Vector3(0,0,.03),Vector3.FORWARD,260,&"",0),"Original physical push still works")
			await frames(60); recording=false
			check(door.get_open_angle()>.05,"Painted door swings with the original hinge")
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"comparisons":comparisons,"samples":samples,"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"scope":"Actual Main V3 seed120. Original room and door meshes, same Camera texture A/B, solid/window/glass doors, ordinary push. Initial placements are fixtures, AI paused. Baseline texture generated from preserved prior code; shader side-face mapping is current in both views. No external outline or geometry enlargement."},"\t")); file.close()
	print("DOOR_MATERIAL_OUTLINE ",JSON.stringify({"checks":checks,"failures":failures}))
	main.free(); quit(1 if failures.size() else 0)
