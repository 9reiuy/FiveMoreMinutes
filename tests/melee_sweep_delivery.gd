extends "res://tests/phone_tab_delivery.gd"
var aim := Vector2.RIGHT
var melee: Node
var impact_events := 0
var poses: Array = []
var cpu_samples: Array[float] = []
var visible_pixel_counts := {}

func verify_arc_pixels(label: String) -> void:
	# Inspect actual output pixels, not only Node.visible or shader uniforms.
	# Keep the same action/camera snapshot and hide only this passive mesh.
	var with_arc := root.get_texture().get_image()
	var rect := Rect2()
	var first := true
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			var point: Vector3 = melee._visual.global_transform * Vector3(x*melee.attack_range/32,0,z*melee.attack_range/32)
			var projected: Vector2 = world.camera_3d.unproject_position(point)
			projected = root.get_final_transform() * world.player.get_presentation_hud_position(projected)
			if first:
				rect = Rect2(projected,Vector2.ZERO)
				first = false
			else: rect = rect.expand(projected)
	var region := Rect2i(rect.grow(4)).intersection(Rect2i(Vector2i.ZERO,with_arc.get_size()))
	melee._visual.mesh.hide()
	await view_frames(2)
	var without_arc := root.get_texture().get_image()
	melee._visual.mesh.show()
	await view_frames(2)
	with_arc.save_png(output + "/visible_" + label + ".png")
	without_arc.save_png(output + "/hidden_" + label + ".png")
	var a := with_arc.get_region(region)
	var b := without_arc.get_region(region)
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var aa := a.get_data()
	var bb := b.get_data()
	var changed := 0
	for i in range(0,aa.size(),4):
		if absi(int(aa[i])-int(bb[i]))+absi(int(aa[i+1])-int(bb[i+1]))+absi(int(aa[i+2])-int(bb[i+2])) > 60:
			changed += 1
	visible_pixel_counts[label] = changed
	check(changed > 20,"Arc produces visible output pixels, not just an enabled node: " + label)

func view_frames(count := 3) -> void:
	for index in count:
		world.player._update_direction_animation(world.player.velocity, 0.0)
		world.player._update_visual_feedback()
		world._update_camera_and_actor_projection(0.0)
		world.player_depth_bridge._process(0.0)
		for actor in actors:
			if is_instance_valid(actor) and actor.has_meta(&"depth_visual_bridge"):
				var bridge: Node = actor.get_meta(&"depth_visual_bridge").get_ref()
				if is_instance_valid(bridge): bridge._process(0.0)
		await process_frame
	await RenderingServer.frame_post_draw

func still(label: String) -> void:
	await view_frames()
	root.get_texture().get_image().save_png(output + "/" + label + ".png")

func equip(kind: String) -> void:
	world.player.equip_weapon(kind, world.config, {})
	world.player.set_attacking_enabled(true)
	melee = world.player.get_active_weapon()
	melee.set_process(false)
	melee.set_physics_process(false)
	melee.melee_impact.connect(func(_hit: bool) -> void: impact_events += 1, CONNECT_ONE_SHOT)

func record_swing(label: String, moving := false, frame_count := 24) -> void:
	var start: Vector2 = world.player.global_position
	var peak_hair := 0.0
	var step := 1.0 / 60.0
	# Keep initial spring state identical across display-mode A/B captures.
	for settle in 300:
		world.player.get_node("CharacterVisual/BodyPivot/Head/SideBangs").step_actor(step)
	melee._perform_swing(false)
	clips[label] = []
	for index in frame_count:
		if moving and index < 15:
			world.player.global_position += Vector2(0, .65)
		var began := Time.get_ticks_usec()
		melee._physics_process(step)
		cpu_samples.append(float(Time.get_ticks_usec() - began) / 1000.0)
		world.player.get_node("CharacterVisual/BodyPivot/Head/SideBangs").step_actor(step)
		peak_hair = maxf(peak_hair,absf(world.player.get_node("CharacterVisual/BodyPivot/Head/SideBangs").segment_angles.z))
		for actor in actors:
			if is_instance_valid(actor): actor._process(step)
		await view_frames(1)
		var file := "%s_%03d.png" % [label, index]
		root.get_texture().get_image().save_png(output + "/" + file)
		clips[label].append({"file": file, "seconds": index * step})
		if index == 6 and (label.begins_with("bat_pixel_") or label == "books_moving"):
			await verify_arc_pixels(label)
		poses.append({"clip": label, "index": index, "sweep": melee.sweep_progress,
			"direction": melee.swing_direction, "position": world.player.global_position,
			"hair_bend": world.player.get_node("CharacterVisual/BodyPivot/Head/SideBangs").bend,
			"hair_tip": world.player.get_node("CharacterVisual/BodyPivot/Head/SideBangs").segment_angles.z,
			"arc_height": melee._visual.position.y if is_instance_valid(melee._visual) else -1.0,
			"grip_height": world.player_depth_bridge.weapon_reference_height,
			"visible": is_instance_valid(melee._visual) and melee._visual.visible})
	check(not melee.melee_action_active and not melee._visual.visible, "Completed attack releases pose and arc: " + label)
	check(peak_hair > .10,"Formal stationary/moving swing drives curved bangs: " + label)
	check(absf(melee._visual.position.y - world.player_depth_bridge.weapon_reference_height + .012) < .005,"Arc and held weapon share a reference plane: " + label)
	world.player.global_position = start

func cover_fixture(origin: Vector2, room_id: int, kind: String) -> void:
	var prop: Node2D = load("res://scenes/dream/props/trash_can_01.tscn").instantiate()
	prop.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	# Cover the full authored hurtbox (center is 28px above the feet), not
	# only its ground point. The longer reach can now reach exposed upper
	# samples that the previous short-range fixture never tested.
	prop.position = origin + Vector2(32, -14)
	prop.rotation = PI / 2.0
	prop.set_meta(&"dream_room_id", room_id)
	preload("res://scripts/dream/office_furniture_catalog.gd").configure(prop, kind)
	# Match the formal generator: configure categories before _ready caches them.
	world.furniture_root.add_child(prop)
	prop.hp = 1000.0
	prop.freeze = true
	world._spawn_furniture_presentation(prop)
	actors[1].global_position = origin + Vector2(60, 0)
	var before: float = actors[1].current_health
	equip("lucille")
	aim = Vector2.RIGHT
	for index in 2: await physics_frame
	var reach: float = melee._trace_reach(world.player, origin, origin + Vector2(melee.attack_range,0))
	if kind == "cabinet":
		var fully_shielded := true
		for point in melee._target_samples(actors[1],origin):
			fully_shielded = fully_shielded and melee._trace_reach(world.player,origin,point,actors[1]) + .75 < origin.distance_to(point)
		check(fully_shielded,"Cabinet fixture actually shields the full enemy hurtbox, not just feet")
	await record_swing("cover_" + kind)
	check(reach < 30.0 if kind == "cabinet" else reach > 55.0, "Real furniture footprint clips cabinet but passes low desk: " + kind)
	check(actors[1].current_health == before if kind == "cabinet" else actors[1].current_health < before, "Real enemy behind furniture obeys melee obstruction: " + kind)
	prop.queue_free()
	for index in 3: await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"):
		quit(2)
		return
	output = "res://.runtime/melee_sweep_20261021/camera_range80_visible"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://tests/support/background_gpu.gd").start(self)
	process_frame.connect(func() -> void:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920, 1080)
	Engine.max_fps = 60
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state.tutorial_completed = true
	seed(120)
	main._show_dream("basic")
	await ready_main()
	world = main._supported_dream_world
	var deadline := Time.get_ticks_msec() + 90000
	while world.floor_transition_in_progress and Time.get_ticks_msec() < deadline:
		await wait(.05)
	check(not world.floor_transition_in_progress, "Actual Main entrance ready")
	root.get_node("DreamTimeController").set_process(false)
	Engine.time_scale = 1.0
	var origin := Vector2.ZERO
	var room_id := -1
	for room in world.rooms:
		if String(room.get("archetype", "")) != "open_office": continue
		for cell in room.get("usable_cells", []):
			var point := Vector2(cell) * 32.0
			if world._content_position_is_clear(point, 85.0):
				origin = point
				room_id = int(room.id)
				break
		if room_id >= 0: break
	check(room_id >= 0, "Naturally generated office has a clear staged combat area")
	if room_id < 0:
		main.free()
		quit(1)
		return
	world.activate_room(room_id)
	for enemy in world.enemy_root.get_children():
		enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.hurtbox.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.global_position = origin
	world.player.invulnerability_left = 0.0
	world.player.invulnerability_reason = &""
	world.player.hurt_flash_left = 0.0
	world.player.revive_flash_left = 0.0
	# Test-only provider still feeds the real Camera ray / floor-plane mapping.
	world.player.set_meta(&"presentation_pointer_position", func() -> Vector2:
		return world.camera_3d.unproject_position(world.get_gameplay_world_position(world.player.global_position + aim * 180.0, 0.0)))
	for angle in [-55.0, 0.0, 55.0]:
		var enemy: Node = world._spawn_regular_employee(room_id, origin + Vector2(46,0).rotated(deg_to_rad(angle)), &"employee", false, "basic")
		enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.hurtbox.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.sky_drop_active = false
		enemy.sky_drop_height = 0.0
		enemy.current_health = 1000.0
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.set_room_runtime_active(true)
		enemy.set_player_vision_visible(true)
		actors.append(enemy)
	world.player.set_physics_process(false)
	await wait(.25)
	world._update_camera_and_actor_projection(0.0)
	world.room_visibility._update_outside_mask()
	for body in world.find_children("*", "CollisionObject2D", true, false):
		body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	world.process_mode = Node.PROCESS_MODE_DISABLED
	# The scene's actual display coordinator, not a substitute Camera.
	var display: Node = main._active_pixelation_screen()
	check(display != null and display.has_method("set_selective_enabled"), "Formal pixelation coordinator found")
	var display_modes: Array = []
	for pixel in [false, true]:
		for palette in [false, true]:
			if display.has_method("set_selective_enabled"): display.set_selective_enabled(pixel)
			if display.has_method("set_palette_enabled"): display.set_palette_enabled(palette)
			check(display.selective_enabled == pixel and display.palette_enabled == palette, "Actual world display toggles pixel=%s palette=%s" % [pixel,palette])
			equip("lucille")
			aim = Vector2.RIGHT
			await record_swing("bat_pixel_%d_palette_%d" % [int(pixel), int(palette)])
			display_modes.append({"pixel": pixel, "palette": palette, "coordinator": String(display.get_path())})
	check(actors.all(func(enemy: Node) -> bool: return enemy.current_health < 1000.0), "Formal bat damages all three real enemies")
	check(impact_events == 4, "Each multi-target bat attack emits only one aggregate impact")
	equip("books")
	aim = Vector2.DOWN
	await record_swing("books_moving", true)
	equip("lucille")
	aim = Vector2.DOWN
	await record_swing("hair_stationary", false, 72)
	var torso_screen: Vector2 = world.camera_3d.unproject_position(world.player_depth_bridge.get_hit_feedback_world_position())
	torso_screen = root.get_final_transform() * world.player.get_presentation_hud_position(torso_screen)
	for index in 8:
		equip("lucille")
		aim = Vector2.RIGHT.rotated(index * PI / 4.0)
		melee._perform_swing(false)
		melee._physics_process(.11)
		await still("direction_%d" % index)
		check(melee.direction_locked and melee.swing_direction.dot(aim) > .99, "Formal Camera aim agrees with locked slice %d" % index)
		check(melee._visual.mesh.mesh.size.x > melee.attack_range * 2.0 / 32.0, "World carrier cannot crop arc %d" % index)
		melee.cancel_swing()
		check(not melee._visual.visible and world.player.weapon_motion.rotation == 0.0, "Cancellation resets actual held pose and carrier %d" % index)
	check(not world.player.lucille_trail.visible, "Old billboard Line2D is not doubled over new arc")
	check(world.find_children("PlayerMeleeSweep_*", "Node3D", true, false).size() == 2, "Repeated attacks reuse at most one carrier per melee weapon")
	await cover_fixture(origin, room_id, "cabinet")
	await cover_fixture(origin, room_id, "desk")
	cpu_samples.sort()
	var report := {"checks": checks, "failures": failures, "clips": clips, "poses": poses,
		"arc_visible_pixel_counts": visible_pixel_counts,
		"bat_reach": world.config.player_lucille_attack_range, "books_reach": world.config.player_books_attack_range,
		"player_torso_screen": [torso_screen.x,torso_screen.y],
		"gpu": RenderingServer.get_video_adapter_name(), "origin": origin, "room_id": room_id,
		"modes": display_modes, "cpu_step_median_ms": cpu_samples[cpu_samples.size()/2],
		"cpu_step_p95_ms": cpu_samples[int(cpu_samples.size()*.95)],
		"scope": "Actual Main, natural random office, formal Camera/Player/three real enemies. Controlled 60Hz action snapshots; original AI paused, world clock fixed, PNG readback excluded from CPU timing. Not live combat FPS."}
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("MELEE_SWEEP_GPU checks=", checks, " failures=", failures.size())
	main.free()
	quit(0 if failures.is_empty() else 1)
