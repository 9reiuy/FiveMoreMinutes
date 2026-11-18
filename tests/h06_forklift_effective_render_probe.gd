extends "res://tests/h06_forklift_route_flash_probe.gd"
## Compare the effective Camera environment after the full boarding/driving/shooting route.

var envs: Array[Environment] = []
var env_states: Array[Dictionary] = []
var lamp_states: Array[Dictionary] = []
var frozen_camera := Transform3D.IDENTITY
var frozen_rig := Transform3D.IDENTITY
const FLOOR_PATCH := Rect2(-26.2, -30.8, 1.6, 1.15)


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	print("EFFECTIVE_RENDER_PROBE_PID ", OS.get_process_id())
	create_timer(240.0).timeout.connect(func() -> void: push_error("effective render probe timed out"); quit(1))
	call_deferred("run")


func trace_case(label: String, count: int, fire := false, pointer_pan := false) -> void:
	await super.trace_case(label, count, fire, pointer_pan)
	if label == "after_shooting_pan": await compare_effective_render()


func actual_environment() -> Environment:
	return world.camera_3d.environment if world.camera_3d.environment != null else world.get_world_3d().environment


func configure_comparison(label: String) -> void:
	for i in envs.size():
		var e: Environment = envs[i]
		var saved: Dictionary = env_states[i]
		e.ssr_enabled = saved.ssr and label != "no_ssr"
		e.ssao_enabled = saved.ssao and label != "no_ssao"
		e.glow_enabled = saved.glow and label != "no_glow"
	for saved in lamp_states:
		var light: Light3D = saved.light
		light.shadow_enabled = saved.shadow and label != "no_shadows"
		light.light_specular = 0.0 if label == "no_specular" else saved.specular
	var finish: Node = world.get_node_or_null("WorldCameraFinish")
	if finish != null: finish.set_enabled(label != "no_finish")
	world.get_viewport().use_taa = label == "taa"


func compare_effective_render() -> void:
	world.restart_queued = true
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false)
	for projectile in get_nodes_in_group(&"dream_projectiles"): projectile.queue_free()
	await frames(60)
	world.set_process(false)
	frozen_camera = world.camera_3d.global_transform
	frozen_rig = world.camera_rig.transform
	var optics: Node = world.get_node_or_null("OfficeLightOptics")
	var fog: Environment = optics.get("_fog_environment") if optics != null else null
	for e: Environment in [world.get_world_3d().environment, world.camera_3d.environment, fog]:
		if e != null and e not in envs:
			envs.append(e)
			env_states.append({"id": e.get_instance_id(), "ssr": e.ssr_enabled, "ssao": e.ssao_enabled, "glow": e.glow_enabled})
	for light: Light3D in world.find_children("*", "Light3D", true, false):
		lamp_states.append({"light": light, "shadow": light.shadow_enabled, "specular": light.light_specular})
	print("EFFECTIVE_ENVS ", JSON.stringify(env_states), " effective=", actual_environment().get_instance_id())
	for label: String in ["render_original_a", "no_ssr", "no_ssao", "no_shadows", "no_specular", "no_glow", "no_finish", "taa", "render_original_b"]:
		configure_comparison(label)
		await frames(10)
		var folder := evidence.path_join(label)
		DirAccess.make_dir_recursive_absolute(folder)
		for i in 64:
			await physics_frame
			await process_frame
			world.camera_rig.transform = frozen_rig
			world.camera_3d.global_transform = frozen_camera
			world.camera_rig.position += Vector3(float(i) * .014, 0, float(i) * -.0035)
			await RenderingServer.frame_post_draw
			var corners: Array[Vector2] = []
			for p: Vector2 in [FLOOR_PATCH.position, FLOOR_PATCH.position + Vector2(FLOOR_PATCH.size.x, 0), FLOOR_PATCH.end, FLOOR_PATCH.position + Vector2(0, FLOOR_PATCH.size.y)]:
				corners.append(world.camera_3d.unproject_position(Vector3(p.x, 3.04, p.y)))
			var e := actual_environment()
			records.append({"label": label, "frame": i, "corners": corners, "camera": world.camera_3d.global_transform,
				"effective_env": e.get_instance_id(), "ssr": e.ssr_enabled, "ssao": e.ssao_enabled,
				"glow": e.glow_enabled, "taa": world.get_viewport().use_taa,
				"bullets": get_nodes_in_group(&"dream_projectiles").size()})
			root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
		check(not actual_environment().ssr_enabled if label == "no_ssr" else true, label + " actual Camera environment is used")
		print("RENDER_COMPARISON ", label)
	configure_comparison("render_original_b")
