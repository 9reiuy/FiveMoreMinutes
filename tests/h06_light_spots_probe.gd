extends "res://tests/forklift_combat_test.gd"
## Read-only scene diagnosis: matched actual Camera paths with reversible optical exclusions.

var records: Array[Dictionary] = []
var lamp_state: Array[Dictionary] = []
const PROBE_START := Vector2(-26.0, -16.2)


func run_path(label: String, hide_specular: bool, hide_optics: bool, hide_transients: bool) -> void:
	var optics: Node3D = world.get_node_or_null("OfficeLightOptics")
	if is_instance_valid(optics): optics.enabled = not hide_optics
	for saved in lamp_state:
		var lamp: Light3D = saved.node.get_ref()
		if is_instance_valid(lamp): lamp.light_specular = 0.0 if hide_specular else saved.specular
	if is_instance_valid(world.night_lighting):
		world.night_lighting.set_shadow_transition_paused(hide_transients)
	for lamp: OmniLight3D in world.projectile_local_light_pool:
		lamp.light_energy = 0.0 if hide_transients else 0.08
	place_feet(PROBE_START)
	world.camera_aim_offset = Vector3.ZERO
	world._clear_camera_shake()
	world._update_camera_and_actor_projection(0.0)
	await frames(24)
	var folder := evidence.path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 96:
		var direction := Vector2.RIGHT if i < 48 else Vector2.LEFT
		world.player.set_scripted_locomotion(direction, 2.2 * 32.0)
		await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var visible_lights: Array[Dictionary] = []
		for saved in lamp_state:
			var lamp: Light3D = saved.node.get_ref()
			if is_instance_valid(lamp) and lamp.is_visible_in_tree() and lamp.light_energy > 0.0:
				visible_lights.append({"name": lamp.name, "energy": lamp.light_energy,
					"specular": lamp.light_specular, "position": lamp.global_position})
		var row := {"label": label, "frame": i, "camera": world.camera_3d.global_position,
			"fov": world.camera_3d.fov, "feet": world.player.body_collision.global_position / 32.0,
			"lights": visible_lights, "projectiles": get_nodes_in_group(&"dream_projectiles").size(),
			"optics_fixtures": optics._fixtures.size() if is_instance_valid(optics) else 0}
		records.append(row)
		if i % 4 == 0:
			root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
	world.player.clear_scripted_locomotion()
	print("PROBE_PATH ", label)


func run() -> void:
	evidence = OS.get_environment("FLICKER_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter_chapter(CHAPTER.Save.PUMP)
	world.restart_queued = true
	for enemy in world.enemy_root.get_children():
		enemy.queue_free()
	await frames(4)
	for lamp: Light3D in world.find_children("*", "Light3D", true, false):
		lamp_state.append({"node": weakref(lamp), "specular": lamp.light_specular})
	await run_path("original_a", false, false, false)
	await run_path("without_specular", true, false, false)
	await run_path("without_optics", false, true, false)
	await run_path("without_temporary_lights", false, false, true)
	await run_path("original_b", false, false, false)
	var file := FileAccess.open(evidence.path_join("trace.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"records": records, "checks": checks, "failures": failures,
		"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(),
		"audio": AudioServer.get_driver_name(), "scope": "Actual pump-room Camera, no AI firing, same reversible camera paths. Frame readbacks are diagnostic and not performance samples."}, "\t"))
	verify_audio()
	current_scene.queue_free()
	await frames(4)
	print("LIGHT_SPOTS_PROBE frames=", records.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
