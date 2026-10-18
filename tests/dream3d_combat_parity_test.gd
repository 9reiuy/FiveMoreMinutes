extends SceneTree
const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY = preload("res://scenes/entities/employee_enemy.tscn")
const PROP = preload("res://scenes/dream/props/trash_can_01.tscn")
const BULLET = preload("res://scenes/entities/basic_projectile.tscn")
const DOOR = preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const CONFIG = preload("res://resources/demo_config.tres")
var world: Node3D
var failures: Array[String] = []
var checks := 0
var anchor := Vector2.ZERO
var player: Node2D
var damage_signals := 0
var gunshot_events := 0

func _init() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func enemy_at(point: Vector2, health: float = 100, dismember: float = 0.3) -> EmployeeEnemy:
	var e := ENEMY.instantiate() as EmployeeEnemy
	world.enemy_root.add_child(e)
	e.global_position = point
	e.set_meta("dream_room_id", world.spawn_room_id)
	var cfg: DemoConfig = CONFIG.duplicate()
	cfg.employee_dismember_chance = dismember
	# Exercise corpse lifecycle without the production 15-second linger per case.
	cfg.corpse_linger_duration = 1.0
	e.configure(player, health, 0, world._room_bounds_pixels(world.spawn_room_id, 2), CONFIG.enemy_separation_strength, CONFIG.enemy_separation_radius, cfg)
	e.set_room_bounds(world._room_bounds_pixels(world.spawn_room_id, 2))
	e.defeated.connect(world._on_enemy_defeated)
	e.weapon_drop_requested.connect(world._on_employee_weapon_drop_requested.bind(e))
	e.set_physics_process(false)
	e.set_player_vision_visible(true)
	world.register_depth_visual(e, [^"Shadow", ^"CharacterVisual", ^"WeaponRoot"])
	return e

func prop_at(point: Vector2) -> Node2D:
	var p: Node2D = PROP.instantiate()
	world.furniture_root.add_child(p)
	p.global_position = point
	p.set_meta("dream_room_id", world.spawn_room_id)
	world.register_depth_visual(p, [^"Shadow", ^"Sprite2D"])
	return p

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41002), "generation")
	player = world.player
	world.run_interface.auto_open_upgrades = false
	check(world.night_lighting != null and world.find_child("RandomBuildingPlayerVision", true, false) == null, "night light replaces old player reveal")
	world.target_highlight.set_physics_process(false)
	player.set_physics_process(false)
	player.invulnerability_left = 100
	anchor = Vector2(world.rooms[world.spawn_room_id].center_cell) * 32
	player.global_position = anchor + Vector2(-130, 0)
	await frames(4)
	var audio_manager: Node = root.get_node("SFXManager")
	audio_manager.sfx_played.connect(func(event: StringName) -> void:
		if event == &"gunshot": gunshot_events += 1)
	# Real firearm scenes create the real projectile(s); no test bullet substitute.
	for weapon_id in ["basic","shotgun","assault_rifle"]:
		player.equip_weapon(weapon_id, CONFIG, {})
		var weapon: Node = player.get("_active_weapon") if player.get("_active_weapon") is Node else null
		for child in player.get_children():
			if child.get("projectile_speed") != null and child.get("active") == true:
				weapon = child
		# Formal weapons are children of Player; use existing named fields.
		match weapon_id:
			"basic": weapon = player.auto_weapon
			"shotgun": weapon = player.shotgun_weapon
			"assault_rifle": weapon = player.assault_rifle_weapon
		var e := enemy_at(anchor, 500)
		await frames(2)
		var before := e.current_health
		var origin: Vector2 = player.get_projectile_origin()
		var direction := origin.direction_to(e.global_position + Vector2(0,-12))
		var sfx_before := gunshot_events
		var previous_projectile_ids: Dictionary = {}
		for projectile in get_nodes_in_group("active_basic_projectiles"):
			previous_projectile_ids[projectile.get_instance_id()] = true
		if weapon_id == "shotgun":
			weapon._fire_full_volley(direction, false)
		else:
			weapon._fire(direction, false)
		var shot_count := 0
		for projectile in get_nodes_in_group("active_basic_projectiles"):
			if not previous_projectile_ids.has(projectile.get_instance_id()):
				shot_count += 1
		check(gunshot_events == sfx_before + 1, weapon_id+" one gunshot per trigger, not per pellet")
		check(shot_count == (CONFIG.shotgun_pellet_count if weapon_id == "shotgun" else 1), weapon_id+" formal projectile count")
		await frames(22)
		check(e.current_health < before, weapon_id+" actual enemy damage")
		check(not get_nodes_in_group("black_blood_stains").is_empty(), weapon_id+" actual blood")
		e.free()
		for projectile in get_nodes_in_group("active_basic_projectiles"):
			projectile.queue_free()
		await frames(8)
	# Explicit lethal sources, intact + detached death, once-only reward and release.
	for source in [&"player_projectile", &"shotgun", &"lucille", &"kick", &"furniture_impact", &"thrown_weapon"]:
		var e := enemy_at(anchor, 1, 1.0 if source == &"shotgun" else 0.0)
		e.equip_weapon("basic")
		await frames(2)
		var bridge: Node3D = e.get_meta("depth_visual_bridge").get_ref()
		var kills: int = world.run_interface.kills
		e.take_damage(100, anchor-Vector2(15,0), 700, source)
		check(e.dead and e.death_presentation_left > 0, str(source)+" death presentation")
		check(is_equal_approx(e.death_presentation_left, 1.0), str(source)+" configured corpse lifetime")
		check(e.enemy_head_frame_index == 2, str(source)+" death locks the closed-eye frame")
		check(world.run_interface.kills == kills+1, str(source)+" reward once")
		e.take_damage(100, anchor-Vector2(15,0), 700, source)
		check(world.run_interface.kills == kills+1, str(source)+" duplicate death rejected")
		await frames(12)
		if is_instance_valid(e):
			check(e.enemy_head_frame_index == 2, str(source)+" corpse keeps closed eyes during presentation")
		check(e.visible or e.death_dismember, str(source)+" corpse not frozen/hidden prematurely")
		await frames(100)
		check(not is_instance_valid(e) and not is_instance_valid(bridge), str(source)+" death visual cleanup")
	# Furniture shared damage / debris / complete destruction.
	var prop := prop_at(anchor)
	await frames(3)
	var hp: float = prop.hp
	prop.take_damage(2, Vector2.RIGHT, 0.0)
	check(prop.hp < hp, "furniture formal damage")
	var before_parts: int = world.ground_debris_root.get_child_count()
	prop.take_damage(1000, Vector2.RIGHT, 1.0)
	await frames(3)
	check(world.ground_debris_root.get_child_count() >= before_parts+2, "furniture shatter visible")
	await frames(100)
	check(not is_instance_valid(prop), "furniture destruction cleanup")
	var debris_before: int = world.ground_debris_root.get_child_count()
	world.spawn_environment_debris(anchor, world.spawn_room_id, 1)
	check(world.ground_debris_root.get_child_count() == debris_before+1, "ambient debris spawn")
	var debris: Node = world.ground_debris_root.get_child(world.ground_debris_root.get_child_count()-1)
	check(debris.settled and not debris.is_physics_processing(), "settled debris idle cost")
	check(debris.sprite.hframes == 7 and debris.sprite.vframes == 6, "42 icon atlas")
	debris._on_body_entered(player)
	await frames(20)
	check(not is_instance_valid(debris), "player step releases debris")
	# One real first-hit ray controls every target, range and blockers.
	player.global_position = anchor - Vector2(140,0)
	var e := enemy_at(anchor, 100)
	await frames(3)
	var origin := anchor - Vector2(110,12)
	var aim: Node = world.target_highlight
	check(aim.find_target(origin, Vector2.RIGHT, 180, player.get_rid()) == e, "enemy aim ray")
	check(aim.find_target(origin, Vector2.RIGHT, 40, player.get_rid()) == null, "range rejects")
	check(aim.find_target(origin, Vector2.UP, 180, player.get_rid()) == null, "off-axis rejects")
	var blocker := StaticBody2D.new()
	blocker.collision_layer = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4,90)
	shape.shape = rect
	blocker.add_child(shape)
	world.gameplay_world.add_child(blocker)
	blocker.position = anchor - Vector2(40,0)
	await frames(3)
	check(aim.find_target(origin, Vector2.RIGHT, 180, player.get_rid()) == null, "wall blocks outline")
	blocker.free()
	await frames(2)
	aim._select(e)
	check(e.get_meta("depth_visual_bridge").get_ref().actor_sprite.material_overlay != null, "entire enemy white outline carrier")
	if "--render" in OS.get_cmdline_user_args():
		await frames(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/parity_combat_outline.png")
		print("COMBAT FPS ", Engine.get_frames_per_second())
	aim._select(null)
	e.free()
	await frames(3)
	# Hinge swing physically sweeps into a real furniture body at its tip.
	var door: Node3D = DOOR.instantiate()
	door.configure(1.84,3,0.1,"left",999)
	door.position = Vector3(anchor.x/32,0,anchor.y/32)
	world.add_child(door)
	door.configure_gameplay_collision(world.collision_root,32,4)
	var p := prop_at(anchor + Vector2(20,19))
	await frames(3)
	check(door.apply_door_impact(&"kick", door.door_leaf.global_position, Vector3.BACK, CONFIG.get_kick_knockback_force()), "F impact accepted")
	await frames(24)
	check(door.has_meta("last_swing_target") and int(door.get_meta("last_swing_target")) == p.get_instance_id(), "fast door hits furniture")
	check(p.linear_velocity.length() > 0 or p.global_position.distance_to(anchor+Vector2(20,19)) > 4, "door pushes real furniture")
	door.free()
	p.free()
	check(world.run_interface.upgrade_panel == null, "3D Dream does not create the upgrade slot panel")
	world.collect_boss_key(null)
	check(not world.is_boss_door_locked(), "key unlocks boss")
	print("COMBAT CHECKS ", checks, " failures ", failures.size())
	world.free()
	# Let the real music-owner fade complete before disposing the SceneTree.
	await frames(25)
	quit(0 if failures.is_empty() else 1)
