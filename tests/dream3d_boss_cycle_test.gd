extends "res://tests/dream3d_combat_parity_test.gd"

var completion_summary: Dictionary = {}


func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "boss-cycle generation")
	await frames(4)
	player = world.player
	world.run_interface.auto_open_upgrades = false
	world.target_highlight.set_physics_process(false)

	var report: Dictionary = world.get_validation_report()
	check(int(report.get("main_door_count", -1)) == 0, "start has zero Main Entrance doors")
	check(bool(report.get("start_outer_wall_sealed", false)), "start exterior opening restored to wall")
	check(int(report.get("boss_entry_count", 0)) == 1, "boss has exactly one graph entrance")
	check(world.boss_enemy is EmployeeEnemy, "formal EmployeeEnemy boss spawned")
	check(bool(world.boss_enemy.get("boss_variant")), "existing configure_boss variant active")
	check(int(world.boss_enemy.get_meta("dream_room_id", -1)) == world.boss_room_id, "boss assigned to Boss Room")
	check(world.wake_exit_trigger != null and not world.wake_exit_trigger.monitoring, "Wake Exit disabled before boss defeat")

	var lights_per_room: Dictionary = {}
	for holder in world.ceiling_light_root.get_children():
		var cell := Vector2i(roundi(holder.position.x), roundi(holder.position.z))
		var room_id := int(holder.get_meta("dream_room_id", -1))
		var lit_room: Dictionary = world.rooms[room_id]
		lights_per_room[room_id] = int(lights_per_room.get(room_id, 0)) + 1
		check(not bool(lit_room.get("is_large", false)), "ceiling lights only spawn in small rooms")
		check(cell == Vector2i(lit_room.get("center_cell", Vector2i.ZERO)), "small room light sits on its center cell")
		check(world.floor_cells.has(cell), "ceiling light above real floor")
		check(int(world.room_cells.get(cell, -1)) == room_id, "ceiling light belongs to its usable room")
	for room in world.rooms:
		var room_id := int(room.get("id", -1))
		var expected := 0 if bool(room.get("is_large", false)) else 1
		check(int(lights_per_room.get(room_id, 0)) == expected, "room %d gets exactly its rule-based light count" % room_id)
	var sample: Node = world.ceiling_light_root.get_child(0) if world.ceiling_light_root.get_child_count() > 0 else null
	check(sample != null, "ceiling lights exist for the visual rule check")
	if sample != null:
		var fixture := sample.get_node_or_null("FixtureMesh") as MeshInstance3D
		check(fixture != null, "fixture mesh exists")
		if fixture != null:
			var material := fixture.material_override as StandardMaterial3D
			check(material != null, "fixture overrides a StandardMaterial3D")
			if material != null:
				check(material.albedo_color.is_equal_approx(Color(0.0, 0.0, 0.0, 0.3)), "fixture is black at 30% opacity")
				check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "fixture uses alpha blending")
				check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "fixture is unshaded")
				check(not material.emission_enabled, "fixture has no white emission")
			check(fixture.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "fixture casts no shadow")
		var lamp := sample.get_node_or_null("RoomLight") as SpotLight3D
		check(lamp != null and lamp.shadow_enabled, "room light stays a shadow-casting SpotLight3D")

	world._on_boss_defeated(world.boss_enemy.global_position, 1)
	check(world.boss_defeated, "boss defeat state latched once")
	check(world.wake_exit_trigger.monitoring and world.wake_exit_visual.visible, "Wake Exit activated after boss defeat")
	world.dream_finished.connect(func(summary: Dictionary) -> void: completion_summary = summary)
	world._on_wake_exit_body_entered(player)
	check(not completion_summary.is_empty(), "Wake Exit emits formal dream_finished summary")
	check(bool(completion_summary.get("boss_defeated", false)), "completion summary records boss")
	check(int(world.run_interface.profile.get("current_dream_layer", 1)) == 2, "boss completion advances persistent layer interface")

	check(is_equal_approx(CONFIG.player_movement_speed, 204.0), "base movement is old 136 x1.5")
	check(is_equal_approx(CONFIG.dash_distance, 168.0), "roll distance is old 84 x2")
	check((int(player.collision_mask) & 2) != 0, "Player body collides symmetrically with Enemy layer")

	world.free()
	await frames(12)

	# A campaign death must return through Main's existing settlement signal;
	# standalone prototype runs intentionally retain their local retry prompt.
	var death_world = SCENE.instantiate()
	death_world.generate_on_ready = false
	death_world.spawn_content = false
	death_world.persist_profile = false
	var available_ids: Array[String] = [&"basic"]
	death_world.configure_campaign_run(
		&"basic",
		available_ids,
		CONFIG,
		{"current_dream_layer": 1, "dream_layer_reached": 1},
		1,
		false,
		false,
		0
	)
	root.add_child(death_world)
	await frames(2)
	var death_summary: Dictionary = {}
	death_world.dream_finished.connect(func(summary: Dictionary) -> void: death_summary.merge(summary, true))
	check(death_world.complete_death_run(), "campaign death completes through formal dream_finished signal")
	check(String(death_summary.get("reason", "")) == "梦中倒下", "campaign death summary has death reason")
	check(float(death_summary.get("wake_minutes", 0.0)) > float(death_summary.get("dream_end_minutes", 0.0)), "campaign death applies wake delay")
	death_world.free()
	await frames(8)
	var light_total := 0
	for counted in lights_per_room.values():
		light_total += int(counted)
	print("BOSS CYCLE checks=", checks, " lights=", light_total, " failures=", failures.size())
	quit(1 if failures.size() else 0)
