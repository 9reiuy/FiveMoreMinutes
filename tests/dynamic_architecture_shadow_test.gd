extends SceneTree

const SOLID := preload("res://scripts/dream/solid_shadow_caster_3d.gd")
const WALL := preload("res://scenes/dream/3d/WallStraight3D.tscn")
const DOOR := preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const GLASS := preload("res://scripts/dream/breakable_glass_window_3d.gd")
const ELEVATOR := preload("res://scripts/dream/elevator_floor_door_3d.gd")
const SFX_API := preload("res://scripts/audio/sfx_manager.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	stage.rotation.y = -PI * 0.25
	var wall = WALL.instantiate()
	stage.add_child(wall)
	wall.configure_wall(2.6, 1.0)
	wall.set_meta(&"shadow_outward_local_sign", -1.0)
	wall.set_cutaway_mode(true)
	check(wall.shadow_mesh.transform == Transform3D.IDENTITY, "wall blocker must not shift by half thickness")
	check(is_equal_approx(wall.shadow_mesh.mesh.get_aabb().size.y, 2.6), "cutaway must retain full-height blocker")
	check(wall.wall_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "wall has a single blocker")
	wall.set_window_variant(true)
	wall.set_window_inward_normal(Vector2(-1, 0))
	check(wall.window_light != null and wall.window_light.visible, "standalone window light remains available")
	wall.set_floor_shadow_lighting_enabled(true)
	check(not wall.window_light.visible, "floor sunlight disables per-window spots")
	wall.set_wall_visual_visible(false)
	wall.set_wall_visual_visible(true)
	check(not wall.window_light.visible, "presentation updates cannot reactivate local window spot")
	check(wall.window_pane.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "glass must pass sunlight")
	wall.set_floor_shadow_lighting_enabled(false)
	check(wall.window_light.visible, "standalone lighting can be restored")

	var door = DOOR.instantiate()
	door.configure(2.0, 2.2, .5, "left", 0, &"single")
	stage.add_child(door)
	door.set_architectural_cutaway(true, 2.6)
	var caster := door.left_visual.get_node(SOLID.NODE_NAME) as MeshInstance3D
	check(caster.mesh == door.left_visual.mesh, "door blocker uses actual panel mesh")
	check(caster.global_transform.is_equal_approx(door.left_visual.global_transform), "door blocker exactly follows hinge geometry")
	check(not door.right_visual.get_node(SOLID.NODE_NAME).is_visible_in_tree(), "single door must not cast a phantom second leaf")
	door.left_leaf.rotation.y = .7
	check(caster.global_transform.is_equal_approx(door.left_visual.global_transform), "turning a leaf moves its blocker without resync")
	door.shatter()
	check(not caster.is_visible_in_tree(), "destroyed door no longer blocks light")

	var glass = GLASS.new()
	stage.add_child(glass)
	glass.configure_window({"axis":"H", "x":0, "y":0}, "H:0:0", 2.6, 1.0, null)
	glass.set_cutaway_mode(true)
	var header := glass.get_node("WindowFrame/WindowHeader") as MeshInstance3D
	check(header.get_node_or_null(SOLID.NODE_NAME) != null, "cut window header retains a full blocker")
	glass.shatter()
	check(header.get_node(SOLID.NODE_NAME).is_visible_in_tree(), "glass break leaves the physical frame blocker intact")
	check(not glass.glass_pane.visible, "shattered pane removed")

	var furniture := preload("res://scripts/dream/office_furniture_catalog.gd").make_visual("workstation", true, true)
	stage.add_child(furniture)
	SOLID.protect_shader_meshes(furniture)
	var surface := furniture.get_node("AuthoredSurfaceMesh") as MeshInstance3D
	var furniture_caster := surface.get_node(SOLID.NODE_NAME) as MeshInstance3D
	furniture.position.y = 1.5
	furniture.rotation.y = 1.2
	check(furniture_caster.global_transform.is_equal_approx(surface.global_transform), "furniture blocker inherits rotation and Fake Height")
	SOLID.protect_shader_meshes(furniture)
	check(surface.get_child_count() == 1, "repeated protection cannot duplicate casters")
	furniture.visible = false
	check(not furniture_caster.is_visible_in_tree(), "hidden/destroyed furniture cannot leave a stale shadow")

	var elevator = ELEVATOR.new()
	stage.add_child(elevator)
	elevator.configure_opening(4.0, 1.0)
	var lift_caster := elevator.left_door_mesh.get_node(SOLID.NODE_NAME) as MeshInstance3D
	check(lift_caster.mesh == elevator.left_door_mesh.mesh, "resized elevator shares actual door geometry")
	check(elevator.frame_root.get_node_or_null("FramePostLeft/" + SOLID.NODE_NAME) != null, "elevator structural jamb casts")
	check(elevator.indicator_leds[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "indicator lights remain non-casters")
	elevator.left_door_mesh.position.x -= 1.0
	check(lift_caster.global_transform.is_equal_approx(elevator.left_door_mesh.global_transform), "sliding elevator panel moves its shadow")
	# Decorative transparent surfaces must never acquire opaque duplicate casters.
	var ornament := MeshInstance3D.new()
	ornament.mesh = BoxMesh.new()
	ornament.material_override = ShaderMaterial.new()
	ornament.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(ornament)
	SOLID.protect_shader_meshes(ornament)
	check(ornament.get_node_or_null(SOLID.NODE_NAME) == null, "deliberately noncasting decoration remains excluded")
	var caster_id := furniture_caster.get_instance_id()
	var lift_caster_id := lift_caster.get_instance_id()
	SFX_API.stop_event(&"glass_shatter")
	SFX_API.stop_event(&"wood_shatter")
	stage.free()
	await process_frame
	await process_frame
	# AudioServer drains stopped playback commands on its own thread.
	await create_timer(0.1).timeout
	check(not is_instance_id_valid(caster_id) and not is_instance_id_valid(lift_caster_id), "unloading geometry frees all child casters")
	if failures.is_empty():
		print("DYNAMIC ARCHITECTURE SHADOW TEST PASSED: ", checks, " checks")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
