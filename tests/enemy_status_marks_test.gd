extends SceneTree
## Exercise hearing, sight, damage and teardown in the shared combat world.
const OUTPUT := "res://.runtime/enemy_status_marks_20261116"
var failures: Array[String] = []
var lab: Control
var world: Node3D
var hud: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
	else:
		print("PASS ", message)

func frames(count: int) -> void:
	for index in count:
		await process_frame

func stage(at: Vector2, kind: StringName) -> EmployeeEnemy:
	var actor: EmployeeEnemy = world._spawn_regular_employee(1, at, kind, false, "basic")
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.maximum_health = 100
	actor.current_health = 100
	return actor

func look_at_player(actor: EmployeeEnemy) -> void:
	actor.weapon_root.rotation = actor.global_position.direction_to(world.player.global_position).angle()
	actor._update_visual_target_perception()
	actor._update_status_mark()

func mark_for(actor: EmployeeEnemy) -> Dictionary:
	return hud.status_marks.get(actor.get_instance_id(), {})

func compare_ink(frame: Image, without_marks: Image, point: Vector2, ink: Color) -> int:
	if not point.is_finite(): return 0
	var scale := Vector2(frame.get_size()) / root.get_visible_rect().size
	var area := Rect2i((point - Vector2(28, 28)) * scale, Vector2(56, 38) * scale)
	area = area.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
	var found := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var color := frame.get_pixel(x, y)
			if color.is_equal_approx(without_marks.get_pixel(x, y)): continue
			if maxf(absf(color.r - ink.r), maxf(absf(color.g - ink.g), absf(color.b - ink.b))) < .07:
				found += 1
	return found

func capture(question: EmployeeEnemy, alert: EmployeeEnemy) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	check(frame.save_png(OUTPUT + "/enemy_status_marks.png") == OK, "save production-art Camera with clear HUD")
	hud.layer.hide()
	await frames(2)
	await RenderingServer.frame_post_draw
	var without_marks := root.get_texture().get_image()
	hud.layer.show()
	var light_pixels := compare_ink(frame, without_marks, mark_for(question).position, hud.COMIC.INK)
	var red_pixels := compare_ink(frame, without_marks, mark_for(alert).position, hud.ALERT_INK)
	check(light_pixels > 12 and red_pixels > 20, "Camera contains pale question and red alert ink: %d / %d pixels" % [light_pixels, red_pixels])

func check_door_occlusion(actor: EmployeeEnemy) -> void:
	var bridge: Node3D = actor.get_meta(&"depth_visual_bridge").get_ref()
	var top: Vector3 = bridge.get_status_mark_world_position()
	var camera: Camera3D = world.camera_3d
	var eye := camera.project_ray_origin(camera.unproject_position(top))
	var door := MeshInstance3D.new()
	var panel := BoxMesh.new()
	panel.size = Vector3(.8, .8, .25)
	door.mesh = panel
	world.door_root.add_child(door)
	door.global_position = eye.lerp(top, .94)
	hud._process(0)
	check(not mark_for(actor).position.is_finite(), "solid door between the camera and the head hides the mark")
	door.global_position.y -= 4.0
	hud._process(0)
	check(mark_for(actor).position.is_finite(), "a door below the camera ray leaves the mark visible")
	door.free()

func exercise(mode: int) -> void:
	world = lab.world
	hud = world.floor_root.get_node("EnemyCombatText")
	hud.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(224, 257)
	world.activate_room(1)
	world._update_camera_and_actor_projection(10.0)
	var question := stage(Vector2(174, 207), &"employee")
	var alert := stage(Vector2(266, 204), &"waitress")
	await physics_frame
	await frames(4)
	while is_instance_valid(world.weapon_name_popup) and world.weapon_name_popup.visible:
		await process_frame
	hud.clear()
	question._update_status_mark()
	check(hud.status_marks.is_empty(), "idle patrol has no mark")
	question.on_room_gunshot(question.global_position, -1)
	check(hud.status_marks.is_empty(), "unheard gunfire shows nothing")
	question.on_room_gunshot(question.global_position, 1)
	look_at_player(alert)
	hud._process(.25)
	check(not question.hostile and question.state == EmployeeEnemy.State.INVESTIGATE_GUNSHOT
		and mark_for(question).get("mark") == EmployeeEnemy.StatusMark.QUESTION, "hearing without sight shows a question")
	check(alert.hostile and alert.can_see_target and mark_for(alert).get("mark") == EmployeeEnemy.StatusMark.ALERT,
		"confirmed sight shows an alert on the second enemy")
	if not mark_for(question).has("position") or not mark_for(alert).has("position"): return
	check(mark_for(question).position.is_finite() and mark_for(alert).position.is_finite(), "both marks project above visible actors")
	check(hud.records.is_empty() and hud.kill_streak_count == 0, "status events are independent of kill feedback")
	if mode == 1 and DisplayServer.get_name() != "headless":
		await capture(question, alert)
	check_door_occlusion(question)
	var previous: Vector2 = mark_for(question).position
	question.global_position.x += 22
	question.on_room_gunshot(question.global_position, 1)
	hud._process(.10)
	check(mark_for(question).position.is_finite() and previous.distance_to(mark_for(question).position) > 2
		and mark_for(question).age > .3, "text follows movement without restarting on repeated sound")
	look_at_player(question)
	check(mark_for(question).mark == EmployeeEnemy.StatusMark.ALERT and hud.status_marks.size() == 2,
		"seeing the player replaces the question on the same enemy")
	question.set_player_vision_visible(false)
	hud._process(.02)
	check(not mark_for(question).position.is_finite(), "a hidden enemy has no visible HUD mark")
	question.set_player_vision_visible(true)
	hud._process(hud.LIFETIME)
	check(hud.status_marks.is_empty() and not hud.layer.visible, "expired marks leave no overlay")
	world.resolve_player_hit(alert, 1, world.player.global_position, &"player_punch")
	check(mark_for(alert).get("mark") == EmployeeEnemy.StatusMark.ALERT, "a surviving hit raises an alert")
	world.resolve_player_hit(alert, 1000, world.player.global_position, &"player_punch")
	hud._process(.01)
	check(alert.dead and mark_for(alert).is_empty(), "death clears the live status")
	question._choose_hostile_action()
	question._lose_target_in_smoke()
	question._update_status_mark()
	check(mark_for(question).get("mark") == EmployeeEnemy.StatusMark.QUESTION, "losing sight while searching the last known position shows a question")
	question.free()
	hud._process(.01)
	check(hud.status_marks.is_empty(), "removing an enemy clears its unexpired mark")

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"):
		push_error("Use an isolated test profile"); quit(2); return
	create_timer(150, true, false, true).timeout.connect(func() -> void: quit(2))
	AudioServer.set_bus_mute(0, true)
	if DisplayServer.get_name() != "headless": preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	lab.enemies.value = 0
	lab.checks.ai.button_pressed = false
	lab.checks.special.button_pressed = false
	await frames(2)
	while not lab.ready_world: await process_frame
	for mode in [0, 1]:
		if mode == 1:
			var old_layer: WeakRef = weakref(hud.layer)
			lab.mode.select(mode)
			await lab.rebuild()
			await frames(2)
			check(old_layer.get_ref() == null, "reset frees the previous HUD")
		lab.panel.hide()
		lab.hud.hide()
		await exercise(mode)
	lab.free()
	await frames(2)
	print("ENEMY_STATUS_MARKS failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
