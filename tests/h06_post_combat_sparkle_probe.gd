extends "res://tests/forklift_combat_test.gd"
## Explicitly replay the same real Camera transforms, before/after settled combat.
const BLOOD := preload("res://scripts/dream/floor_surface_blood.gd")
const BURNING := preload("res://scripts/dream/burning_effects.gd")
var rows: Array[Dictionary] = []
var env: Environment
var has_ssr := false
var has_glow := false
var focus := Vector3.ZERO
var surface: Node3D
var gun_fx: Node3D
var burning: Node3D
var saved_lights: Array[Dictionary] = []


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	print("POST_COMBAT_PROBE_PID ", OS.get_process_id())
	create_timer(160.0).timeout.connect(func() -> void: push_error("incomplete post-combat probe"); quit(1))
	call_deferred("run")


func set_blood_visible(shown: bool) -> void:
	if not is_instance_valid(surface): return
	surface.visible = shown
	for face: Dictionary in surface.faces:
		var decal: Node3D = face.ref.get_ref()
		if is_instance_valid(decal): decal.visible = shown


func path(label: String, ssr: bool, blood: bool, fx: bool, glow: bool) -> void:
	env.ssr_enabled = ssr
	env.glow_enabled = glow
	set_blood_visible(blood)
	if is_instance_valid(gun_fx): gun_fx.visible = fx
	if is_instance_valid(burning): burning.visible = fx
	var folder := evidence.path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 120:
		await physics_frame
		var phase := i * TAU / 120.0
		world.camera_rig.position = focus + Vector3(4.0 * sin(phase), 0, 2.4 * cos(phase))
		var gp: Vector2 = world._player_ground_anchor_position()
		var ground: Vector3 = world.to_global(Vector3(gp.x / 32.0, world._floor_height_at(gp / 32.0), gp.y / 32.0))
		var camera: Camera3D = world.camera_3d
		world.gameplay_canvas.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, camera.unproject_position(ground) - gp)
		await process_frame
		await RenderingServer.frame_post_draw
		var alive := 0
		for actor in world.enemy_root.get_children(): alive += int(not bool(actor.get("dead")))
		var hot_count := 0
		if is_instance_valid(gun_fx): hot_count = gun_fx._hot_particles.size()
		rows.append({"case": label, "frame": i, "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
			"alive_enemies": alive, "bullets": get_nodes_in_group(&"dream_projectiles").size(), "hot_particles": hot_count,
			"ssr": env.ssr_enabled, "glow": env.glow_enabled,
			"blood_faces": surface.faces.size() if is_instance_valid(surface) else 0})
		if i % 2 == 0: root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
	check(rows[-1].alive_enemies == 0 and rows[-1].bullets == 0 and rows[-1].hot_particles == 0,
		label + " contains no firing, live enemies or active muzzle particles")
	print("POST_COMBAT_PATH ", label)


func populate_settled_combat() -> void:
	var targets := [Vector2(-22, -17.5), Vector2(-19.8, -12.1)]
	for target: Vector2 in targets:
		var actor: EmployeeEnemy = world._spawn_regular_employee(int(world.get_current_room_id()),
			target * 32.0, &"employee", false, "basic")
		actor.set_room_runtime_active(true)
		actor.set_physics_process(false)
		await frames(3)
		world.spawn_weapon_muzzle(actor.get_projectile_origin(), Vector2.LEFT, &"basic", actor)
		actor.take_damage(1000.0, actor.global_position + Vector2(-32, 0), 160.0, &"player_projectile_pistol")
	surface = BLOOD.install(world)
	gun_fx = world.floor_root.get_node_or_null("FirearmFlashFX")
	burning = BURNING.install(world)
	burning.explosion(world.get_gameplay_world_position(Vector2(-21.6, -17.0), 0.65))
	await frames(300)
	for projectile in get_nodes_in_group(&"dream_projectiles"): projectile.queue_free()
	await frames(4)
	check(gun_fx._hot_particles.is_empty(), "old muzzle and impact particles finished before Camera replay")
	print("SETTLED_COMBAT blood_faces=", surface.faces.size(), " actors=", world.enemy_root.get_child_count())


func run() -> void:
	evidence = OS.get_environment("FLICKER_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter_chapter(CHAPTER.Save.PUMP)
	world.restart_queued = true
	for actor in world.enemy_root.get_children(): actor.queue_free()
	await frames(4)
	place_feet(Vector2(-25.5, -18.7))
	world.player.movement_enabled = false
	world.player.set_attacking_enabled(false, true)
	world.set_process(false)
	env = world.camera_3d.environment
	if env == null: env = world.get_node("Lighting/WorldEnvironment").environment
	has_ssr = env.ssr_enabled
	has_glow = env.glow_enabled
	focus = Vector3(world.player.global_position.x / 32.0, world._floor_height_at(world.player.global_position / 32.0),
		world.player.global_position.y / 32.0)
	await path("clean_a", has_ssr, true, true, has_glow)
	await populate_settled_combat()
	await path("post_combat_a", has_ssr, true, true, has_glow)
	await path("without_ssr", false, true, true, has_glow)
	await path("without_blood", has_ssr, false, true, has_glow)
	await path("without_fx", has_ssr, true, false, has_glow)
	await path("without_glow", has_ssr, true, true, false)
	await path("post_combat_b", has_ssr, true, true, has_glow)
	check(rows.size() == 840, "all seven exact Camera paths completed")
	var file := FileAccess.open(evidence.path_join("trace.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "records": rows,
		"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(),
		"audio": AudioServer.get_driver_name(), "scope": "Same real Camera matrices; no live enemies or firing during sample; settled combat compared against clean scene. Diagnostic readbacks are not performance samples."}, "\t"))
	verify_audio()
	current_scene.queue_free()
	await frames(4)
	print("POST_COMBAT_PROBE frames=", rows.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
