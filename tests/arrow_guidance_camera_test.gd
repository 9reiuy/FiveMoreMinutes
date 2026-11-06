extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const OUT := "res://.runtime/arrow_guidance_20261106"
var checks := 0
var failures := 0
var world: Node3D
var display: Node
var main: Node


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
	print("PASS " if value else "FAIL ", label)


func frames(count: int) -> void:
	for _i in count:
		await process_frame


func gameplay_at_screen(screen: Vector2, height: float) -> Vector2:
	var camera: Camera3D = world.camera_3d
	var origin := world.to_local(camera.project_ray_origin(screen))
	var ray := world.global_transform.basis.inverse() * camera.project_ray_normal(screen)
	var point := origin + ray * ((height - origin.y) / ray.y)
	return Vector2(point.x, point.z) * 32.0


func update_guidance() -> Array[Dictionary]:
	return world.objective_guidance.update(0.0)


func has_arrow(id: int) -> bool:
	for state in world.objective_guidance.states:
		if int(state.id) == id:
			return true
	return false


func shot(label: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + "/" + label + ".png")
	check(result == OK, label + " screenshot saved")


func run() -> void:
	print("CAMERA_TEST PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")):
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
		push_error("Private muted settings were not active before scene entry")
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	create_timer(180.0, true, false, true).timeout.connect(func(): quit(2))
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await frames(4)
	world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	main._set_screen(world)
	display = main.current_screen
	await frames(4)
	world.regenerate(6)
	await frames(20)
	world.player.invulnerability_left = 10000.0
	world.player.set_physics_process(false)
	world.set_process(false)
	world.set_physics_process(false)
	var enemies: Array[Node2D] = []
	for child in world.enemy_root.get_children():
		child.set_process(false)
		child.set_physics_process(false)
		if child is Node2D and child.is_in_group(&"dream_enemies"):
			if enemies.size() < 3 and child.has_meta(&"depth_visual_bridge"):
				if child.has_method("set_room_runtime_active"):
					child.set_room_runtime_active(true)
					child.set_process(false)
					child.set_physics_process(false)
				child.visible = true
				var bridge: Node = child.get_meta(&"depth_visual_bridge").get_ref()
				if is_instance_valid(bridge):
					bridge.set_room_presentation_active(true)
				enemies.append(child)
			else:
				child.remove_from_group(&"dream_enemies")
	check(enemies.size() == 3, "formal floor supplied three living enemies")
	if enemies.size() < 3:
		quit(1)
		return
	world.objective_guidance.elapsed = 30.0
	var view: Vector2 = world.camera_3d.get_viewport().get_visible_rect().size
	enemies[0].global_position = gameplay_at_screen(Vector2(view.x + 95, view.y * 0.40), 0.9)
	enemies[1].global_position = gameplay_at_screen(Vector2(view.x + 700, view.y * 0.67), 0.9)
	enemies[2].global_position = gameplay_at_screen(view * Vector2(0.35, 0.5), 0.9)
	await frames(8)
	var visible_bridge: Node = enemies[2].get_meta(&"depth_visual_bridge").get_ref()
	check(is_instance_valid(visible_bridge) and visible_bridge.actor_sprite.is_visible_in_tree(), "onscreen enemy has its actual 3D visual enabled")
	var state := update_guidance()
	check(state.size() == 2 and not has_arrow(enemies[2].get_instance_id()), "visible enemy hidden while both offscreen enemies are shown")
	if state.size() == 2:
		check(state[0].size > state[1].size and state[0].distance < state[1].distance, "real camera shows near enemy larger than far enemy")
	await shot("enemy_pixel")
	display.set_selective_enabled(false)
	await frames(5)
	update_guidance()
	await shot("enemy_native")
	var visible_after_entry := false
	for i in range(21):
		view = world.camera_3d.get_viewport().get_visible_rect().size
		var x := lerpf(view.x + 95.0, view.x * 0.74, float(i) / 20.0)
		enemies[0].global_position = gameplay_at_screen(Vector2(x, view.y * 0.40), 0.9)
		update_guidance()
		if not has_arrow(enemies[0].get_instance_id()):
			if not visible_after_entry:
				await shot("enemy_first_entry")
				var moving_bridge: Node = enemies[0].get_meta(&"depth_visual_bridge").get_ref()
				var capture: Image = moving_bridge.render_viewport.get_texture().get_image()
				var used: Rect2i = capture.get_used_rect()
				var sprite: Sprite3D = moving_bridge.actor_sprite
				var sprite_point := Vector2(used.position) + Vector2(0, float(used.size.y) * 0.5) - Vector2(capture.get_size()) * 0.5
				var projected: Vector2 = world.camera_3d.unproject_position(sprite.to_global(Vector3(sprite_point.x, -sprite_point.y, 0) * sprite.pixel_size))
				print("FIRST_ENTRY camera_x=", x, " opaque_capture=", used, " projected_left=", projected, " viewport=", view)
				check(used.has_area() and projected.x < view.x and projected.y >= 0.0 and projected.y < view.y, "enemy body reaches the camera when its arrow disappears")
			visible_after_entry = true
		elif visible_after_entry:
			check(false, "enemy marker stays hidden after entering camera")
		await frames(1)
	check(visible_after_entry and not has_arrow(enemies[0].get_instance_id()), "enemy marker disappears during movement into camera")
	await shot("enemy_entered")
	view = world.camera_3d.get_viewport().get_visible_rect().size
	var badge_point := gameplay_at_screen(Vector2(-140, view.y * 0.48), 0.3)
	world._spawn_employee_badge(badge_point, world.current_room_id)
	await frames(2)
	state = update_guidance()
	check(state.size() == 1 and state[0].kind == &"badge", "offscreen badge replaces enemy arrows")
	await shot("badge_native")
	world.floor_badge_pickup.global_position = gameplay_at_screen(view * 0.5, 0.3)
	update_guidance()
	check(world.objective_guidance.states.is_empty(), "badge arrow disappears on entering camera")
	await shot("badge_entered")
	world.has_floor_badge = true
	world.elevator_door_pos_2d = gameplay_at_screen(Vector2(view.x + 250, view.y * 0.6), 1.3)
	state = update_guidance()
	check(state.size() == 1 and state[0].kind == &"elevator", "offscreen elevator uses objective guidance")
	await shot("elevator_native")
	root.size = Vector2i(1366, 768)
	await frames(5)
	update_guidance()
	var display_rect: Rect2 = world.objective_guidance._display_rect(world.camera_3d, world.player)
	for arrow in world.objective_guidance.states:
		check(display_rect.has_point(arrow.position), "resized window keeps arrow inside the actual display")
	await shot("elevator_resized")
	print("ARROW_CAMERA checks=", checks, " failures=", failures)
	main.queue_free()
	await frames(4)
	quit(1 if failures else 0)
