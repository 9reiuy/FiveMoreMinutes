extends "res://tests/h06_forklift_ram_blood_comparison.gd"
## Same real lethal ram and painted data, original projection versus fitted blood.

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	initial_comparison_mode = 1
	ram_surface_meshes = true
	comparison_caption = "1-2 叉车血迹修复 — F6 对照 — 独立静音测试"
	print("BLOOD_MESH_COMPARISON_PID ", OS.get_process_id())
	call_deferred("run")

func kill_by_ramming() -> void:
	begin_trace()
	await super.kill_by_ramming()
	end_trace("first-real-ram-surface-blood")

func check_comparison_mode(mode: int) -> bool:
	var surface: Node = world.office_art_root.get_node("SurfaceBlood")
	return ram_done and surface.faces.size() > 0 and surface.faces.all(func(face: Dictionary) -> bool:
		var mark: Node3D = face.ref.get_ref()
		return mark is MeshInstance3D if mode != 0 else mark is Decal)

func apply_comparison() -> void:
	var surface: Node = world.office_art_root.get_node("SurfaceBlood")
	var started := Time.get_ticks_usec()
	surface.set_surface_meshes(comparison_mode != 0)
	comparison_trace.append({"mode":comparison_mode,"time_usec":started,"switch_ms":(Time.get_ticks_usec()-started)*0.001,"faces":surface.faces.size()})
	comparison_label.text = "F6 切换　·　" + ("B 修复血迹（保留血迹和投影）" if comparison_mode != 0 else "A 原来的血迹投射") + "　·　请移动视角"
	FileAccess.open(evidence.path_join("switches.json"),FileAccess.WRITE).store_string(JSON.stringify(comparison_trace,"\t"))

func align_comparison_camera() -> void:
	pass

func prepare_comparison() -> void:
	var surface: Node = world.office_art_root.get_node("SurfaceBlood")
	check(world.find_children("AttachedOrangeBlood", "Decal", true, false).is_empty(), "candidate retains all blood without any projected blood decals")
	var covered := true
	var triangles := 0
	for face: Dictionary in surface.faces:
		var mark: MeshInstance3D = face.ref.get_ref()
		covered = covered and mark.mesh.get_surface_count() > 0
		triangles += mark.mesh.get_faces().size() / 3
	check(covered, "every settled blood atlas has receiving surface geometry")
	var stains: Array[Dictionary] = []
	for face: Dictionary in surface.faces:
		var mark: Node3D = face.ref.get_ref()
		stains.append({"mark":weakref(mark),"parent":weakref(mark.get_parent()),"local":mark.transform})
	place_feet(lift._seat_position() / 32.0 + Vector2(0, 1.5))
	await frames(3)
	check(lift.board(world.player), "board the blood-stained forklift again")
	await frames(4)
	check(surface.faces.all(func(face: Dictionary) -> bool: return face.ref.get_ref().material_override != null), "reboarding preserves all blood materials")
	check(lift.try_exit(), "dismount again after blood is deposited")
	await frames(4)
	var ownership := true
	for stain in stains:
		var mark: Node3D = stain.mark.get_ref()
		ownership = ownership and is_instance_valid(mark) and mark.get_parent() == stain.parent.get_ref() and mark.transform.is_equal_approx(stain.local)
	check(ownership, "boarding cycle keeps stains attached to their original surfaces")
	if OS.get_environment("FLICKER_CHECK_AUTO") == "1":
		FileAccess.open(evidence.path_join("mesh-validation.json"),FileAccess.WRITE).store_string(JSON.stringify({"triangles":triangles,"blood":surface.stats(),"checks":checks,"failures":failures,"default_fitted_blood":surface.use_surface_meshes},"\t"))
		return
	var processing: bool = world.is_processing()
	var physics: bool = world.player.is_physics_processing()
	var rig: Transform3D = world.camera_rig.transform
	world.set_process(false)
	world.player.set_physics_process(false)
	var previous_fps := Engine.max_fps
	Engine.max_fps = 0
	for mode in [0, 1, 1, 0]:
		comparison_mode = mode
		apply_comparison()
		await frames(20)
		begin_trace()
		for i in 240:
			world.camera_rig.transform = rig
			world.camera_rig.position += Vector3(sin(i * TAU / 240.0) * 2.0, 0, cos(i * TAU / 240.0) * 1.2)
			await process_frame
		end_trace("projected-blood" if mode == 0 else "surface-fitted-blood")
	comparison_mode = 1
	apply_comparison()
	Engine.max_fps = previous_fps
	world.camera_rig.transform = rig
	world.set_process(processing)
	world.player.set_physics_process(physics)
	FileAccess.open(evidence.path_join("mesh-validation.json"),FileAccess.WRITE).store_string(JSON.stringify({"triangles":triangles,"blood":surface.stats(),"checks":checks,"failures":failures},"\t"))
	FileAccess.open(evidence.path_join("matched-frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0),"samples":metrics,"switches":comparison_trace,"scope":"Matched 240-frame moving actual Camera samples with settled ram blood; excludes readback and switching. Not whole-game performance certification."},"\t"))
