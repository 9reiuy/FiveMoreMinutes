extends SceneTree

const FIELD := preload("res://scripts/dream/scientist_potions.gd")
const SCIENTIST := preload("res://scripts/entities/scientist_enemy.gd")
const OUT := "res://.runtime/scientist_20261116"
const STEP := 1.0 / 60.0
var lab: Control
var world: Node3D
var scientist: SCIENTIST
var failures: Array[String] = []
var checks := 0
var native := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures.append(title)
		push_error(title)
	else:
		print("PASS ", title)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func snapshot(label: String) -> void:
	if not native: return
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")

func reset_target() -> void:
	world.player.current_health = 100
	world.player.maximum_health = 100
	world.player.has_shield = false
	world.player.dash_invulnerability_left = 0
	world.player.invulnerability_left = 0

func prepare_throw(large: bool) -> void:
	var roll := RandomNumberGenerator.new()
	for seed_value in range(1, 80):
		roll.seed = seed_value
		if (roll.randi_range(0,1) == 0) == large:
			scientist.random.seed = seed_value
			break
	scientist.reaction_left = 0
	scientist.attack_cooldown_left = 0
	scientist.hostile = true
	scientist.state = EmployeeEnemy.State.ATTACK_PLAYER
	scientist.weapon_root.rotation = scientist.global_position.direction_to(world.player.global_position).angle()
	scientist._update_visual_target_perception()
	scientist._update_attack_player(STEP)

func exercise(mode: int) -> void:
	world = lab.world
	world.activate_room(1)
	world.player.global_position = Vector2(257,214)
	world.player.set_physics_process(false)
	world._update_camera_and_actor_projection(10)
	# Two ordinary spawn points in the same seeded room exercise both appearances.
	var spawn := Vector2(164 + mode, 213)
	var expected_sheet: Texture2D = FIELD.ATLAS if mode == 0 else SCIENTIST.SECOND_ATLAS
	scientist = world._spawn_regular_employee(1,spawn,&"scientist",false,"basic")
	scientist.set_physics_process(false)
	scientist.set_process(false)
	var field: Node3D = FIELD.ensure(world)
	field.set_physics_process(false)
	reset_target()
	await physics_frame
	await frames(4)
	while is_instance_valid(world.weapon_name_popup) and world.weapon_name_popup.visible:
		await process_frame
	check(scientist._character_atlas() == expected_sheet and scientist.enemy_head_frames.size() == 3, "seeded spawn selects the expected scientist sheet")
	for i in 3:
		var face: AtlasTexture = scientist.enemy_head_frames[i]
		check(face.atlas == expected_sheet and face.region == Rect2(32,32*i,32,32), "authored eye frame from the selected appearance " + str(i))
	scientist._set_back_facing(true)
	check(scientist.head.texture.region == Rect2(64,0,32,32) and scientist.left_leg.texture.region == Rect2(108,44,4,9) and scientist.right_hand.texture.region == Rect2(117,79,5,4), "back and separate limbs use the scientist sheet")
	for part: Sprite2D in [scientist.head, scientist.body, scientist.left_hand, scientist.right_hand, scientist.left_leg, scientist.right_leg]:
		check(part.texture.atlas == expected_sheet, "selected appearance supplies " + part.name)
	scientist._set_back_facing(false)
	check_foot_registration(expected_sheet)
	for large: bool in [true, false]:
		prepare_throw(large)
		check(scientist.throw_age >= 0.0 and scientist.large_flask == large and scientist.flask.visible, "real AI selects and draws bottle, large=" + str(large))
		if scientist.throw_age < 0.0: return
		scientist._update_attack_player(scientist._release_time() * .60)
		scientist._update_human_animation(STEP)
		scientist._update_enemy_blink(1.0)
		scientist._update_hand_presentation()
		var windup := scientist.body_pivot.transform
		check(scientist.enemy_head_frame_index == 1 and absf(windup.get_rotation()) > deg_to_rad(5.0), "draw narrows the eyes and shifts weight back")
		scientist._update_hand_presentation()
		check(scientist.body_pivot.transform.is_equal_approx(windup), "rendering the same throw twice cannot accumulate a lean")
		if mode == 1:
			await snapshot("big_windup" if large else "small_windup")
		scientist._update_attack_player(scientist._release_time() * .42)
		check(field.flights.size() == 1 and scientist.released and not scientist.flask.visible, "one release from the hand")
		if field.flights.is_empty(): return
		field.set_physics_process(false)
		var first = field.flights[0]
		check(first.sprite.texture == scientist.flask.texture and first.sprite.region_rect == scientist.flask.region_rect, "wrist and projectile share the same bottle art")
		var release_tilt := scientist.body_pivot.rotation
		check(release_tilt * windup.get_rotation() < 0.0, "release transfers weight forward")
		check(scientist.enemy_head_frame_index == (2 if large else 0) and scientist.exhale_mouth.visible == large, "lob strains and exhales, straight vial tracks the target at release")
		var bridge: Node3D = scientist.get_meta(&"depth_visual_bridge").get_ref()
		check(first.visual_start.is_equal_approx(bridge.get_attached_part_world_position(scientist.flask)), "projectile leaves the wrist of the leaned pose")
		for i in (17 if large else 8):
			field._physics_process(STEP)
		check(first.sprite.global_position.y > first.visual_start.y + .3 if large else absf(first.sprite.global_position.y - first.visual_start.y) < .3, "ballistic height differs from straight flight")
		if mode == 1:
			await snapshot("big_flight" if large else "small_flight")
		for i in 90:
			if field.flights.is_empty(): break
			field._physics_process(STEP)
		check(field.puddles.size() == 1, "bottle lands and leaves one puddle")
		if field.puddles.is_empty(): return
		var pool = field.puddles[0]
		check(pool.center.distance_to(world.player.body_collision.global_position)<4.0, "puddle lands at target feet")
		check(world.player.current_health == (100.0 if large else 95.0), "only the small bottle deals five direct damage")
		scientist._update_attack_player(.18)
		scientist._update_hand_presentation()
		check(scientist.enemy_head_frame_index == 0 and not scientist.exhale_mouth.visible and absf(scientist.body_pivot.rotation) < absf(release_tilt), "eyes reopen as the torso settles")
		scientist._update_attack_player(.13)
		check(scientist.body_pivot.transform.is_equal_approx(Transform2D(0, scientist.body_pivot_base_position)), "finished throw restores the neutral body")
		pool.advance(.28)
		check(pool.contains(pool.center) and not pool.contains(pool.center+Vector2.RIGHT*pool.radius), "visible pixel mask separates liquid from floor")
		if mode == 1 and large: await snapshot("big_puddle")
		pool.free()
		field.puddles.clear()
		field.exposure.clear()
		reset_target()
	check_throw_directions()
	check_rear_throw_highlight()
	prepare_throw(true)
	scientist._apply_throw_presentation(scientist._release_time())
	var bridge: Node3D = scientist.get_meta(&"depth_visual_bridge").get_ref()
	var wrist_at_release: Vector3 = bridge.get_attached_part_world_position(scientist.flask)
	scientist._update_attack_player(scientist._release_time() + .20)
	check(field.flights.size() == 1 and field.flights[0].visual_start.is_equal_approx(wrist_at_release), "a late physics tick still launches from the release pose")
	scientist._cancel_throw()
	field.clear_region()
	var at: Vector2 = world.player.body_collision.global_position
	field.spill(at,true)
	field.spill(at,false)
	field.set_physics_process(false)
	var bystander: EmployeeEnemy = world._spawn_regular_employee(1,at,&"employee",false,"basic")
	bystander.set_physics_process(false)
	bystander.set_process(false)
	bystander.maximum_health = 100
	bystander.current_health = 100
	world._spawn_hotel_robot(1, at, world.floor_root)
	var robot: CharacterBody2D = world.enemy_root.get_child(-1)
	robot.set_physics_process(false)
	var robot_health: float = robot.hp
	scientist.global_position += at - scientist.body_collision.global_position
	scientist.current_health = 100
	scientist.maximum_health = 100
	var direction := scientist._avoid_ground_hazards(Vector2.ZERO)
	for i in 59: field._physics_process(STEP)
	check(world.player.current_health == 100 and bystander.current_health == 100, "no premature contact damage")
	field._physics_process(STEP)
	check(world.player.current_health == 95 and bystander.current_health == 95 and scientist.current_health == 95, "one second costs five for player, other employee and the thrower, even in overlapping liquid")
	check(robot.hp == robot_health - 5.0, "a grounded delivery robot is also poisoned")
	robot.global_position += Vector2(85, 0)
	check(direction.length() > 0.0, "scientist chooses an escape route when forced into poison")
	bystander.global_position += Vector2(85,0)
	world.player.global_position += Vector2(85,0)
	for i in 61: field._physics_process(STEP)
	check(bystander.current_health==95 and world.player.current_health==95 and scientist.current_health==90, "leaving stops damage while a stationary scientist is still vulnerable")
	for i in 270: field._physics_process(STEP)
	check(field.puddles.is_empty() and field.exposure.is_empty(), "puddles evaporate and discard contact timers")
	await check_evasion(field)
	await check_blocker(field)
	var start := Vector2(160,180)
	field.launch(false,start,world.get_gameplay_world_position(start,.7),start+Vector2(0,100))
	field.set_physics_process(false)
	for i in 65: field._physics_process(STEP)
	check(field.flights.is_empty() and not field.puddles.is_empty() and world.player.current_health==95, "missed vial breaks at its endpoint or first obstacle")
	scientist._cancel_throw()
	scientist.global_position = Vector2(164,213)
	world.player.global_position = Vector2(257,214)
	prepare_throw(true)
	scientist.take_damage(5000, world.player.global_position, 1.0, &"player_punch")
	check(scientist.dead and not scientist.flask.visible and field.flights.is_empty(), "death cancels an unreleased bottle without a gun drop")
	check(not scientist.exhale_mouth.visible and scientist.enemy_head_frame_index == 2, "ragdoll owns the closed expression after interruption")
	check(scientist.head.texture.atlas == expected_sheet and scientist.body.texture.atlas == expected_sheet, "ragdoll keeps the chosen scientist appearance")
	var retry: SCIENTIST = world._spawn_regular_employee(1,spawn,&"scientist",false,"")
	check(retry._character_atlas() == expected_sheet, "recreating the same spawn preserves appearance")
	retry._apply_live_facing(Vector2.UP)
	var live_hem := retry.head.position + retry.head.get_rect().position + Vector2(17, 28)
	retry.take_damage(5000, retry.global_position + Vector2.DOWN * 30, 1.0, &"player_punch")
	var corpse_row := 28.0 - float(retry.body.texture.region.position.y)
	var split_hem := retry.body_base_position + retry.body.get_rect().position + Vector2(17, corpse_row)
	check(retry.dead and retry.facing_back and live_hem.is_equal_approx(split_hem), "splitting the back into ragdoll parts preserves the coat registration")

func check_foot_registration(sheet: Texture2D) -> void:
	var pixels := Image.new()
	if pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(sheet.resource_path)) != OK:
		check(false, "read the painted coat hem from " + sheet.resource_path)
		return
	var previous_aim := scientist.weapon_root.rotation
	var previous_facing := scientist.last_facing_direction
	var previous_phase := scientist.walk_phase
	var previous_velocity := scientist.velocity
	for direction: Vector2 in [Vector2.DOWN, Vector2(-1,-1), Vector2(1,-1), Vector2.UP, Vector2.DOWN]:
		scientist.weapon_root.rotation = direction.angle()
		for phase: float in [0.0, PI * .5, PI * 1.5]:
			var walking := phase > 0
			scientist.velocity = direction.normalized() * 96.0 if walking else Vector2.ZERO
			scientist.walk_phase = phase
			scientist._update_human_animation(0.0)
			var cell := Rect2i(scientist.head.texture.region)
			var hem_row := pixels.get_region(Rect2i(cell.position + Vector2i(0,28), Vector2i(32,1)))
			var hem_mid_x := Rect2(hem_row.get_used_rect()).get_center().x
			var hem := scientist.head.to_global(scientist.head.get_rect().position + Vector2(hem_mid_x,28))
			var left := scientist.left_leg.to_global(scientist.left_leg.get_rect().get_center())
			var right := scientist.right_leg.to_global(scientist.right_leg.get_rect().get_center())
			var pose := "%s phase=%.2f" % [direction, phase]
			check(scientist.facing_back == (direction.y < 0) and absf(hem.x - (left.x + right.x) * .5) < .01, "painted coat hem is centered between both feet " + pose)
			check(is_equal_approx(absf(left.x-right.x), 5.0 * absf(scientist.character_visual.global_scale.x)) and (not is_equal_approx(left.y,right.y)) == walking, "foot spacing and alternating stride " + pose)
			var coat_bottom := scientist.head.to_global(scientist.head.get_rect().position + Vector2(hem_mid_x,31)).y
			for foot: Sprite2D in [scientist.left_leg, scientist.right_leg]:
				var bounds := foot.get_rect()
				check(foot.to_global(bounds.position).y < coat_bottom and foot.to_global(bounds.end).y > coat_bottom, "leg overlaps the coat and its boot remains visible " + pose)
	scientist.velocity = previous_velocity
	scientist.walk_phase = previous_phase
	scientist.weapon_root.rotation = previous_aim
	scientist._update_human_animation(0.0)
	scientist._apply_live_facing(previous_facing)

func gameplay_screen_axes() -> Transform2D:
	var camera: Camera3D = world.camera_3d
	var base := scientist.global_position
	var origin := camera.unproject_position(world.get_gameplay_world_position(base, .65))
	var axis_x := camera.unproject_position(world.get_gameplay_world_position(base + Vector2.RIGHT * 32.0, .65)) - origin
	var axis_y := camera.unproject_position(world.get_gameplay_world_position(base + Vector2.DOWN * 32.0, .65)) - origin
	return Transform2D(axis_x, axis_y, Vector2.ZERO)

func check_throw_directions() -> void:
	var projection := gameplay_screen_axes()
	var belt := scientist.body_pivot_base_position + SCIENTIST.THROW_HIP
	var crown := Vector2(-2, -15)
	for screen: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		scientist.large_flask = true
		scientist.throw_direction = (projection.affine_inverse() * screen).normalized()
		scientist._cancel_throw()
		scientist._apply_live_facing(scientist.throw_direction)
		scientist.throw_age = scientist._release_time()
		scientist._update_weapon_aim()
		scientist._update_human_animation(STEP)
		scientist._update_hand_presentation()
		var delta := scientist.body_pivot.transform * crown - (scientist.body_pivot_base_position + crown)
		delta.x *= signf(scientist.character_visual.scale.x)
		check(delta.dot(screen) > 1.0, "head follows the screen-space throw direction " + str(screen))
		check((scientist.body_pivot.transform * SCIENTIST.THROW_HIP).is_equal_approx(belt) and scientist.left_leg.position == scientist.left_leg_base_position and scientist.right_leg.position == scientist.right_leg_base_position, "belt stays attached to the planted feet " + str(screen))
		var painted_hip := Vector2(17 if scientist.facing_back else 14, 27)
		var hip_position := scientist.character_visual.to_local(scientist.head.to_global(scientist.head.get_rect().position + painted_hip))
		check(hip_position.distance_to(belt) < .5, "painted hip stays planted through the throw " + str(screen))
		check(scientist.exhale_mouth.visible == (not scientist.facing_back) and (not scientist.facing_back or scientist.head.texture == scientist.employee_back_frame), "expression respects the authored front or rear " + str(screen))
	scientist.set_room_runtime_active(false)
	check(scientist.throw_age < 0.0 and not scientist.flask.visible and not scientist.exhale_mouth.visible and scientist.enemy_head_frame_index == 0, "leaving an active room clears the throw pose")
	scientist.set_room_runtime_active(true)
	scientist.set_physics_process(false)
	scientist.set_process(false)
	scientist._set_back_facing(false)
	scientist.enemy_blink_time_left = 0.0
	scientist._update_enemy_blink(STEP)
	check(scientist.enemy_head_frame_index == 1, "normal blinking resumes outside the throw")

func check_rear_throw_highlight() -> void:
	var bridge: Node3D = scientist.get_meta(&"depth_visual_bridge").get_ref()
	var rig: Node2D = bridge.clone_roots[bridge.source_roots.find(scientist.character_visual)]
	var hair: Sprite2D = rig.get_node("BodyPivot/Head")
	var flask_copy: Sprite2D = rig.get_node("BodyPivot/CarriedFlask")
	var to_gameplay := gameplay_screen_axes().affine_inverse()
	var previous_target := scientist._get_known_target_position()
	bridge.set_meta(&"test_legacy_character_sync_every_frame", true)
	# A still target's center and feet can straddle screen vertical in the isometric view.
	for side: float in [-1.0, 1.0]:
		var watched := (to_gameplay * Vector2(side * .10, -1.0)).normalized()
		var ballistic := (to_gameplay * Vector2(-side * .10, -1.0)).normalized()
		scientist._remember_target_position(scientist.global_position + watched * 74.0, 1)
		scientist._update_weapon_aim()
		bridge._process(0.0)
		var resting_side := signf(rig.transform.determinant())
		check(scientist.facing_back and resting_side == -side, "standing rear pose follows the target on either side")
		for large: bool in [true, false]:
			scientist.large_flask = large
			scientist.throw_direction = ballistic
			var release := scientist._release_time()
			for age: float in [0.0, release * .5, release, release + .2]:
				scientist.throw_age = age
				scientist._update_weapon_aim()
				scientist._update_human_animation(STEP)
				scientist._update_hand_presentation()
				bridge._process(0.0)
				# The larger of the two painted hair glints is at (22,8) on both back cells.
				var glint_side := signf(hair.to_global(Vector2(22,8)).x - hair.to_global(Vector2(16,8)).x)
				check(hair.texture == scientist.employee_back_frame and glint_side == resting_side, "rear hair stays on its resting side through the bottle animation")
				var displayed_hand := (rig.get_parent() as Node2D).to_local(flask_copy.global_position) - Vector2(bridge.viewport_offset)
				check(displayed_hand.distance_to(scientist.to_local(scientist.flask.global_position)) < .01, "drawn flask and gameplay release share the same wrist")
			scientist._cancel_throw()
			scientist._update_human_animation(STEP)
			bridge._process(0.0)
			check(signf(rig.transform.determinant()) == resting_side, "the first recovery frame preserves the rear hair")
	bridge.remove_meta(&"test_legacy_character_sync_every_frame")
	scientist._remember_target_position(previous_target, 1)
	scientist._update_weapon_aim()

func check_evasion(field: Node3D) -> void:
	var start := Vector2(160,195)
	scientist.global_position += start - scientist.body_collision.global_position
	field.spill(start,true)
	var pool = field.puddles.back()
	pool.advance(.3)
	field.set_physics_process(false)
	scientist.state = EmployeeEnemy.State.ATTACK_PLAYER
	scientist.attack_cooldown_left = 10
	scientist.set_physics_process(true)
	for i in 180:
		await physics_frame
		if not pool.contains(scientist.body_collision.global_position): break
	check(not pool.contains(scientist.body_collision.global_position) and start.distance_to(scientist.body_collision.global_position) > 5.0, "live AI walks out of a spill under its feet")
	scientist.set_physics_process(false)
	pool.free()
	field.puddles.clear()

func check_blocker(field: Node3D) -> void:
	var start := Vector2(173,202)
	var wall := StaticBody2D.new()
	wall.collision_layer = world.WORLD_WALL_LAYER
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(5,85)
	wall.add_child(shape)
	world.gameplay_world.add_child(wall)
	wall.global_position = start + Vector2(29, 0)
	world.player.global_position += start + Vector2(39,0) - world.player.body_collision.global_position
	await physics_frame
	await physics_frame
	var before: float = world.player.current_health
	for large in [false,true]:
		field.launch(large,start,world.get_gameplay_world_position(start,.7),world.player.body_collision.global_position)
		field.set_physics_process(false)
		for i in 80: field._physics_process(STEP)
		var pool = field.puddles.back()
		check(pool.center.x < wall.global_position.x and not pool.contains(world.player.body_collision.global_position) and world.player.current_health == before, "solid wall stops flight and clips the puddle, large="+str(large))
		pool.free()
		field.puddles.clear()
	field.spill(Vector2(-32000,-32000),true)
	check(field.puddles.is_empty(), "a void landing cannot create toxic floor")
	wall.free()
	world.player.global_position = Vector2(342,214)
	var gap_start := Vector2(168,191)
	var gap_cell: Vector2i = world._cell_for_gameplay_position(gap_start) + Vector2i.RIGHT
	var old_floor: Variant = world.floor_cells.get(gap_cell)
	world.floor_cells.erase(gap_cell)
	field.launch(false, gap_start, world.get_gameplay_world_position(gap_start,.7),gap_start+Vector2(100,0))
	field.set_physics_process(false)
	for i in 60: field._physics_process(STEP)
	check(field.puddles.size() == 1 and field.puddles[0].center.x < float(gap_cell.x)*32.0-16.0, "a missed straight vial breaks at the lip of a walkway")
	if old_floor != null: world.floor_cells[gap_cell] = old_floor
	field.clear_region()
	check(field.puddles.is_empty() and field.flights.is_empty() and field.exposure.is_empty(), "district change clears transient hazards and exposure")

func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	create_timer(150,true,false,true).timeout.connect(func(): quit(2))
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	lab.enemies.value = 0
	lab.checks.ai.button_pressed = false
	lab.checks.invincible.button_pressed = false
	while not lab.ready_world: await process_frame
	for mode in [0,1]:
		if mode == 1:
			var previous: WeakRef = weakref(world.floor_root.get_node("ScientistPotions"))
			lab.mode.select(1)
			await lab.rebuild()
			await frames(2)
			check(previous.get_ref() == null, "floor reset releases the potion field")
		lab.hud.hide()
		lab.panel.hide()
		await exercise(mode)
	lab.mode.select(0)
	for menu in lab.panel.find_children("*","OptionButton",true,false):
		if menu.item_count >= 2 and menu.get_item_text(1) == "药剂科学家":
			menu.select(1)
			menu.item_selected.emit(1)
			break
	lab.enemies.value = 1
	lab.checks.ai.button_pressed = true
	await lab.rebuild()
	var units: Array = lab.world.enemy_root.get_children().filter(func(unit): return unit is SCIENTIST)
	check(units.size() == 1 and units[0].process_mode != Node.PROCESS_MODE_DISABLED, "playable selector spawns one live scientist")
	if not units.is_empty():
		var selected_field: Node3D = units[0].pool_field
		var test_spot: Vector2 = units[0].body_collision.global_position
		selected_field.spill(test_spot, true)
		check(not selected_field.puddles.is_empty() and selected_field.puddles[0].material_override == FIELD.PUDDLE.MATERIAL, "whitebox preserves the visible toxic pixel mask on a prewarmed pool")
	lab.free()
	await frames(2)
	print("SCIENTIST checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
