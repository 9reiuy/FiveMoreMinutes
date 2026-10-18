extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	var manager: Node3D = world.shadow_manager
	_check(manager != null, "Office creates its own shadow manager")
	if manager == null:
		quit(1)
		return
	for floor_number in 3:
		_check(world.regenerate(42001 + floor_number), "Floor %d generation" % floor_number)
		_check(is_instance_valid(manager.sun), "Floor %d has one exterior sun" % floor_number)
		_check(is_instance_valid(manager.roof) and manager.roof_cell_count > 0, "Floor %d has a footprint roof" % floor_number)
		_check(manager.get_child_count() == 2, "Floor %d has no previous roof or sun" % floor_number)
		_check(manager.get_debug_stats().interior_candidates > 0, "Floor %d registers room lamps" % floor_number)
		_check(world.player_depth_bridge.volume_shadow != null, "Floor %d keeps player volume" % floor_number)
		_check(world.player_depth_bridge.volume_shadow.weapon == null, "Player never creates a detached gun-shadow box")
		_check(world.player_depth_bridge.lit_material.shader.code.contains("render_mode shadows_disabled"), "Character does not receive volume self shadows")
		var outlined_furniture := 0
		var eligible_furniture_meshes := 0
		for furniture_visual in world.actor_depth_bridges_root.get_children():
			if furniture_visual is Furniture3DVisual and furniture_visual.visual_instance != null:
				var meshes: Array[Node] = furniture_visual.visual_instance.find_children("*", "MeshInstance3D", true, false)
				for mesh in meshes:
					if mesh.mesh != null and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
						eligible_furniture_meshes += 1
						if mesh.material_overlay is ShaderMaterial and mesh.material_overlay.shader == preload("res://shaders/dream3d/furniture_pixel_outline.gdshader"):
							outlined_furniture += 1
		_check(eligible_furniture_meshes > 0 and outlined_furniture == eligible_furniture_meshes, "Floor %d all furniture meshes receive shared black outline (%d/%d)" % [floor_number, outlined_furniture, eligible_furniture_meshes])
		var character_contacts := 0
		for bridge in world.actor_depth_bridges_root.get_children():
			if bridge.get("ground_only") == true and (bridge.get("source_actor") == world.player or bridge.get("source_actor") is EmployeeEnemy):
				character_contacts += 1
		_check(character_contacts == 0, "Floor %d has no baked character foot shadow" % floor_number)
		for quality in ["low", "standard", "high"]:
			manager.set_quality(quality)
			for frame in 10:
				await process_frame
			_check(int(manager.get_debug_stats().interior_shadow_lights) <= int({"low": 2, "standard": 4, "high": 6}[quality]), "%s hard shadow budget" % quality)
		manager.set_suspended(true)
		_check(manager.active.is_empty() and not manager.sun.visible and not manager.roof.visible, "Cab transition suspends floor shadows")
		manager.set_suspended(false)
		_check(manager.sun.visible and manager.roof.visible, "Return resumes floor shadows")
	world.free()
	await process_frame
	_check(not is_instance_valid(manager), "Manager and floor casters free with world")
	print("OFFICE_SHADOW_INTEGRATION_CHECKS=", checks, " FAILURES=", failures.size())
	quit(1 if not failures.is_empty() else 0)
