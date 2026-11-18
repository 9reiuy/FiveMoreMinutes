extends "res://tests/forklift_driving_test.gd"
const HELMET := preload("res://scripts/entities/safety_helmet.gd")
const ENGINEER := preload("res://scenes/entities/engineer_enemy.tscn")
const WORKER := preload("res://scripts/entities/engineer_enemy.gd")
const CHAPTER := preload("res://scripts/testing/h06_chapter/chapter_world.gd")
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const PROJECTILE := preload("res://scenes/entities/basic_projectile.tscn")


func stage_engineer(at: Vector2) -> WORKER:
	var enemy := world._spawn_regular_employee(0, at * 32.0, &"engineer", false, "lucille") as WORKER
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func set_healthy_player(health := 80.0) -> void:
	world.player.current_health = health
	world.player.invulnerability_left = 0.0
	world.player.dash_invulnerability_left = 0.0
	world.player.has_shield = false
	world.player.dissociation_ready = false


func drop_seed(success: bool) -> int:
	var generator := RandomNumberGenerator.new()
	for seed_value in 10000:
		generator.seed = seed_value
		if (generator.randf() < 0.02) == success:
			return seed_value
	return -1


func validate_enemy(label: String) -> void:
	var enemy := stage_engineer(Vector2(8.5, 19.0))
	check(enemy.enemy_archetype == &"engineer" and enemy.helmet_equipped
		and enemy.safety_helmet.sprite.get_parent() == enemy.head,
		label + " new Engineer uses an independently equipped helmet")
	for index in 3:
		enemy._set_enemy_head_frame(index)
		check(enemy.head.texture.get_image().get_data() == HELMET.ART.get_image().get_region(Rect2i(32, index * 32, 32, 32)).get_data(),
			label + " authored front/blink upper-body pixels %d" % index)
	enemy._set_back_facing(true)
	check(enemy.head.texture.get_image().get_data() == HELMET.ART.get_image().get_region(Rect2i(64, 0, 32, 32)).get_data(),
		label + " authored rear pixels preserved")
	enemy._set_back_facing(false)
	enemy._set_enemy_head_frame(0)
	check(enemy.safety_helmet.sprite.texture.get_image().get_data()
		== HELMET.ART.get_image().get_region(Rect2i(96, 0, 32, 32)).get_data(), label + " helmet uses the exact separate art cell")
	await capture(label + "-engineer-helmet-front")
	enemy.current_health = 100.0
	enemy.maximum_health = 100.0
	enemy.take_damage(20.0, Vector2.LEFT, 1.0, &"player_projectile")
	check(enemy.current_health == 80.0 and enemy.helmet_equipped, label + " nonlethal damage leaves helmet intact")
	enemy.loot_random.seed = drop_seed(true)
	var loot_before: int = enemy.loot_random.state
	enemy.take_damage(1000.0, Vector2.LEFT, 1.0, &"player_projectile")
	check(not enemy.dead and enemy.current_health == 1.0 and not enemy.helmet_equipped
		and not enemy.safety_helmet.sprite.visible, label + " lethal hit consumes helmet and leaves 1 HP")
	check(enemy.loot_random.state == loot_before and not enemy.helmet_drop_checked,
		label + " blocking lethal damage neither defeats nor rolls loot")
	await capture(label + "-engineer-after-protection")
	var drops_before: int = world.pickup_root.get_child_count()
	enemy.take_damage(1.0, Vector2.LEFT, 1.0, &"player_projectile")
	await frames(3)
	check(enemy.dead and enemy.helmet_drop_checked and world.pickup_root.get_child_count() == drops_before + 1,
		label + " actual defeat performs the successful rare-drop roll")
	var loot_after: int = enemy.loot_random.state
	enemy._die()
	enemy.take_damage(100.0)
	await frames(2)
	check(enemy.loot_random.state == loot_after and world.pickup_root.get_child_count() == drops_before + 1,
		label + " corpse callbacks cannot roll or drop a second helmet")
	var no_drop := stage_engineer(Vector2(9.5, 20.0))
	no_drop.loot_random.seed = drop_seed(false)
	no_drop.take_damage(10000.0)
	no_drop.take_damage(10000.0)
	await frames(2)
	check(no_drop.dead and world.pickup_root.get_child_count() == drops_before + 1, label + " failed roll produces no helmet")
	for source: StringName in [&"lucille", &"scientist_poison", &"player_vehicle_impact"]:
		var guarded := stage_engineer(Vector2(10.5, 20.0))
		guarded.take_damage(10000.0, Vector2.LEFT, 1.0, source)
		check(not guarded.dead and guarded.current_health == 1.0 and not guarded.helmet_equipped,
			label + " protects accepted combat damage: " + str(source))
		guarded.queue_free()
	var parried := stage_engineer(Vector2(10.5, 20.0))
	parried.defeat_by_parry(Vector2.LEFT)
	check(not parried.dead and parried.current_health == 1.0 and not parried.helmet_equipped,
		label + " parry cannot bypass the one lethal protection")
	parried.queue_free()
	var collided := stage_engineer(Vector2(10.5, 20.0))
	collided._apply_secondary_collision_damage(10000.0, Vector2.RIGHT)
	check(not collided.dead and collided.current_health == 1.0 and not collided.helmet_equipped,
		label + " secondary collision damage uses the same one lethal guard")
	collided.queue_free()
	var shot := stage_engineer(Vector2(10.5, 20.0))
	var bullet = PROJECTILE.instantiate()
	bullet.position = shot.global_position + Vector2(-60.0, 0.0)
	bullet.setup(Vector2.RIGHT, 10000.0, 200.0, 500.0, &"player", world.player, &"basic")
	world.add_projectile(bullet, world.player)
	for i in 120:
		if not shot.helmet_equipped:
			break
		await physics_frame
	check(not shot.dead and shot.current_health == 1.0 and not shot.helmet_equipped,
		label + " a real swept projectile reaches the Engineer and consumes the helmet")
	shot.queue_free()
	var pit := stage_engineer(Vector2(10.5, 20.0))
	pit.force_pit_death()
	check(pit.dead, label + " equipment does not strand actors alive in a pit")
	for node in world.enemy_root.get_children():
		node.queue_free()
	await frames(3)


func validate_pickup(label: String) -> void:
	var pickup: Node2D = world.pickup_root.get_children().filter(func(item: Node) -> bool:
		return item.is_in_group(&"world_equipment_pickups"))[0]
	place_feet(Vector2(7.0, 19.0))
	# Put the existing rare drop at the player's normal interaction anchor for this fixture.
	pickup.global_position = world.player.global_position + Vector2(25.0, 0.0)
	world._clear_world_interaction_target()
	for i in 24:
		await process_frame
		if pickup.interaction_targeted:
			break
	if not pickup.interaction_targeted:
		print("PICKUP_PROBE available=", pickup.is_available_for(world.player), " distance=", pickup.global_position.distance_to(world.player.global_position),
			" target=", world.current_world_weapon_target, " player=", world.player.global_position, " pickup=", pickup.global_position)
	check(pickup.interaction_targeted and not world.player.helmet_equipped,
		label + " proximity highlights the helmet without auto collecting")
	check(pickup.get_interaction_prompt_state().is_empty(), label + " pickup keeps white outline without a proximity label")
	await capture(label + "-helmet-drop-highlight")
	var old_pickup: WeakRef = weakref(pickup)
	await key(KEY_E)
	await key(KEY_E, false)
	await frames(3)
	check(world.player.helmet_equipped and world.player.safety_helmet.sprite.visible
		and not is_instance_valid(old_pickup.get_ref()), label + " E picks up and equips the independent helmet")
	var spare: Node2D = world.spawn_safety_helmet_pickup(world.player.global_position, 0)
	await frames(3)
	check(not spare.is_available_for(world.player), label + " equipped helmet cannot be stacked or replaced")
	for index in 8:
		world.player.set_meta(&"aim_direction_override", Vector2.from_angle(index * PI * 0.25))
		await frames(3)
		check(world.player.safety_helmet.sprite.visible
			and world.player.safety_helmet.sprite.get_parent() == world.player.head_part,
			label + " helmet follows the painted player facing %d" % index)
		if index in [0, 2, 6]:
			await capture(label + "-player-wearing-%d" % index)
	world.player.remove_meta(&"aim_direction_override")
	set_healthy_player()
	world.player.receive_damage(20.0)
	check(world.player.current_health == 60.0 and world.player.helmet_equipped, label + " player nonlethal hit preserves equipment")
	set_healthy_player(60.0)
	world.player.dissociation_ready = true
	world.player.receive_damage(1000.0)
	check(world.player.current_health == 1.0 and not world.player.dead and not world.player.helmet_equipped
		and world.player.dissociation_ready and not world.player.safety_helmet.sprite.visible,
		label + " player helmet blocks lethal damage before consuming dissociation")
	await frames(3)
	await capture(label + "-player-after-protection")
	check(spare.is_available_for(world.player), label + " a consumed helmet frees the equipment slot")
	world.player.invulnerability_left = 0.0
	world.player.dash_invulnerability_left = 0.0
	world.player.receive_damage(1000.0)
	check(not world.player.dead and not world.player.dissociation_ready,
		label + " the next lethal hit reaches the existing revival ability")
	spare.queue_free()


func chapter_camera() -> void:
	lab = load(LAB).instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 1200:
		await process_frame
		if lab.ready_world:
			break
	verify_audio()
	for menu: OptionButton in lab.find_children("*", "OptionButton", true, false):
		for index in menu.item_count:
			if menu.get_item_text(index) == "工程师":
				menu.select(index)
				menu.item_selected.emit(index)
	lab.enemies.value = 1
	lab.checks.ai.button_pressed = true
	await lab.rebuild()
	verify_audio()
	var selected: Array = lab.world.enemy_root.get_children().filter(func(actor: Node) -> bool: return actor is WORKER)
	check(selected.size() == 1 and selected[0].helmet_equipped and selected[0].can_process(),
		"test-lab selector exposes one live helmeted Engineer")
	lab.queue_free()
	await frames(4)
	set_meta(CHAPTER.RETRY_KEY, {"checkpoint": CHAPTER.Save.GUARD})
	check(change_scene_to_file("res://scenes/testing/H06ChapterWhiteboxLab.tscn") == OK, "chapter camera entry loads")
	await scene_changed
	await frames(8)
	verify_audio()
	world = current_scene.presentation.world
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	for actor in world.members:
		actor.set_physics_process(false)
	world._place_feet(Vector2(-24.5, -28.3))
	world.player.set_meta(&"aim_direction_override", Vector2.DOWN)
	var hat: Node2D = world.spawn_safety_helmet_pickup(world.player.global_position + Vector2(25.0, 0.0), 0)
	await frames(15)
	check(hat.interaction_targeted, "actual chapter drop uses the shared white highlight")
	var bridge: Node3D = hat.get_meta(&"depth_visual_bridge").get_ref()
	check(bridge.viewport_offset == Vector2(bridge.render_viewport.size) * 0.5,
		"ground equipment capture is centered on its actual gameplay anchor")
	var rendered: Vector3 = world.to_local(bridge.actor_sprite.global_position)
	check(Vector2(rendered.x, rendered.z).distance_to(hat.global_position / 32.0) < 0.002,
		"ground helmet rendering and interaction use the same floor location")
	await capture("chapter-01-engineer-and-drop")
	await key(KEY_E)
	await key(KEY_E, false)
	await frames(5)
	check(world.player.helmet_equipped, "actual chapter E equips the dropped helmet")
	await capture("chapter-02-player-equipped")
	set_healthy_player()
	world.player.receive_damage(1000.0)
	world.members[0].take_damage(1000.0, world.player.global_position)
	await frames(30)
	check(not world.player.dead and world.player.current_health == 1.0 and not world.player.helmet_equipped
		and not world.members[0].dead and not world.members[0].helmet_equipped,
		"actual chapter characters both survive the consumed helmet")
	await capture("chapter-03-protection-spent")
	current_scene.queue_free()
	await frames(4)
	var record := FileAccess.open(evidence.path_join("camera_result.json"), FileAccess.WRITE)
	record.store_string(JSON.stringify({"checks": checks, "failures": failures, "pid": OS.get_process_id()}, "\t"))
	print("ENGINEER_CAMERA checks=", checks.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func run() -> void:
	evidence = OS.get_environment("ENGINEER_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native:
		preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	if "--chapter-camera" in OS.get_cmdline_user_args():
		await chapter_camera()
		return
	check(is_equal_approx(HELMET.DROP_CHANCE, 0.02), "helmet drop chance is exactly two percent")
	lab = load(LAB).instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 1200:
		await process_frame
		if lab.ready_world:
			break
	check(lab.ready_world, "independent equipment lab loads")
	verify_audio()
	lab.enemies.value = 0
	lab.checks.furniture.button_pressed = false
	lab.checks.ai.button_pressed = false
	lab.checks.invincible.button_pressed = false
	for mode in [0, 1]:
		lab.mode.select(mode)
		await lab.rebuild()
		verify_audio()
		lab.panel.hide()
		lab.set_process(false)
		world = lab.world
		root.get_node("DreamTimeController").slow_time_enabled = false
		Engine.time_scale = 1.0
		var label := "whitebox" if mode == 0 else "production-art"
		place_feet(Vector2(7.0, 19.0))
		await validate_enemy(label)
		await validate_pickup(label)
		set_healthy_player()
		var crowd: Array[EmployeeEnemy] = []
		for i in 8:
			crowd.append(stage_engineer(Vector2(4.0 + i % 4 * 1.6, 18.0 + floori(i / 4.0) * 2.0)))
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for phase in ["without-before", "equipped", "without-after"]:
			for actor in crowd:
				actor.helmet_equipped = phase == "equipped"
			await sample(label + "-eight-engineers-" + phase)
		world.player.helmet_equipped = true
		process_frame.connect(func() -> void:
			world.player.invulnerability_left = 0.0
			world.player.receive_damage(1000.0), CONNECT_ONE_SHOT)
		await sample(label + "-player-lethal-protection")
		var old_player: WeakRef = weakref(world.player)
		await lab.rebuild()
		verify_audio()
		check(not is_instance_valid(old_player.get_ref()), label + " reset frees the equipped actor and visuals")
	lab.queue_free()
	await frames(4)
	set_meta(CHAPTER.RETRY_KEY, {"checkpoint": CHAPTER.Save.GUARD})
	check(change_scene_to_file("res://scenes/testing/H06ChapterWhiteboxLab.tscn") == OK, "normal chapter entry loads")
	await scene_changed
	await frames(6)
	verify_audio()
	world = current_scene.presentation.world
	check(PLAN.WAVES.guard[0][2] == &"engineer" and PLAN.WAVES.pump[1][2] == &"engineer",
		"two existing 1-2 enemy slots use the Engineer without adding enemy count")
	var worker: EmployeeEnemy = world.members[0]
	check(worker.enemy_archetype == &"engineer" and worker.helmet_equipped, "normal chapter wave creates a helmeted Engineer")
	world.resolve_player_hit(world.members[1], 10000.0, world.player.global_position)
	world.resolve_player_hit(worker, 10000.0, world.player.global_position)
	await frames(3)
	check(not worker.dead and worker.current_health == 1.0 and world.wave == "guard",
		"a protected last Engineer keeps the encounter active")
	world.resolve_player_hit(worker, 10000.0, world.player.global_position)
	await frames(3)
	check(worker.dead and world.warehouse_cleared.has("guard"), "only the actual Engineer defeat clears the encounter")
	world.player.equip_safety_helmet()
	world.player.force_hazard_death(&"equipment_retry")
	check(world.restart_current_floor_after_death(), "normal checkpoint retry accepts the equipped player")
	await scene_changed
	await frames(6)
	verify_audio()
	world = current_scene.presentation.world
	check(world.player.helmet_equipped and world.player.safety_helmet.sprite.visible, "chapter retry restores helmet equipment")
	current_scene.queue_free()
	await frames(4)
	var file := FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "metrics": metrics,
		"renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(),
		"pid": OS.get_process_id(), "scope": "Whitebox and production-art equipment tests plus normal chapter creation/retry. Eight identical actors and camera in A/B/A helmet samples, first lethal protection retained; bounded uncapped frames, not whole-game certification."}, "\t"))
	print("ENGINEER_HELMET checks=", checks.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
