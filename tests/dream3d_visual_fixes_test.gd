extends "res://tests/dream3d_combat_parity_test.gd"
## Regression coverage for the night-visual fix batch:
## camera aim look-ahead, flashlight self-shadow exception, faded-wall shadow
## proxy, lit blood/casing carriers, unified blood spray wall hits, door blood
## and top-wall head-clearance air walls.

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "generation")
	player = world.player
	player.set_physics_process(false)
	player.invulnerability_left = 10000
	world.run_interface.auto_open_upgrades = false
	world.target_highlight.set_physics_process(false)
	anchor = Vector2(world.rooms[world.spawn_room_id].center_cell) * 32
	player.global_position = anchor

	# ------------------------------------------------------------------
	# 1. Flashlight self-shadow exception (player never blocks own light).
	# ------------------------------------------------------------------
	var lights: Node3D = world.night_lighting
	var flashlight: SpotLight3D = lights.flashlight
	check(flashlight.light_cull_mask & lights.PLAYER_VISUAL_LAYER != 0, "flashlight lights player visual layer")
	check(flashlight.light_cull_mask & lights.PLAYER_SHADOW_LAYER == 0, "flashlight excludes player shadow layer")
	check(flashlight.light_cull_mask & 1 != 0, "flashlight still lights world layer")
	var player_bridge: Node3D = world.player_depth_bridge
	var player_sprite: Sprite3D = player_bridge.get("actor_sprite")
	check(player_sprite.layers == lights.PLAYER_VISUAL_LAYER, "player carrier on player layer")
	check(player_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "player carrier casts no shadow")
	# The visible carrier is lit but never casts.  A separate shadow-only twin keeps
	# the player's silhouette in world shadows while the flashlight excludes it.
	var player_shadow_proxy: Sprite3D = player_bridge.get("shadow_proxy")
	check(player_shadow_proxy != null, "player keeps a shadow caster twin")
	if player_shadow_proxy != null:
		check(player_shadow_proxy.layers == lights.PLAYER_SHADOW_LAYER, "player shadow twin uses dedicated layer")
		check(player_shadow_proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "player shadow twin casts shadows")
	var sample_enemy: Node2D = enemy_at(anchor + Vector2(60, 0))
	await frames(2)
	var enemy_bridge: Node3D = sample_enemy.get_meta("depth_visual_bridge").get_ref()
	check(enemy_bridge.actor_sprite.layers == 1, "enemy carrier stays on world layer")
	# 正式单投影架构：可见 carrier 只受光、不进 shadow pass（切断掠射手电下的
	# 像素 alpha 自阴影条纹/摩尔纹）；Enemy / Furniture / Boss 的真实投影由
	# SHADOWS_ONLY 孪生代理承担，因此这些对象必须继续正常投影 —— 断言不放宽，
	# 改为直接验证代理本身存在且仍在投影。
	check(enemy_bridge.actor_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "enemy carrier stays out of the shadow pass")
	var enemy_shadow_proxy: Sprite3D = enemy_bridge.get("shadow_proxy")
	check(enemy_shadow_proxy != null, "enemy keeps a shadow caster twin")
	if enemy_shadow_proxy != null:
		check(enemy_shadow_proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "enemy shadow twin still casts shadows")
		check(enemy_shadow_proxy.texture == enemy_bridge.actor_sprite.texture, "enemy shadow twin shares the pixel capture")
	sample_enemy.queue_free()

	# ------------------------------------------------------------------
	# 2. Camera mouse look-ahead: restored on the fixed 3D camera.
	# (Input.warp_mouse is a no-op headless, so drive the pure math path and
	# verify the rig consumes the offset via one live frame.)
	# ------------------------------------------------------------------
	var camera_rotation: Vector3 = world.camera_3d.rotation
	var camera_size: float = world.camera_3d.size
	var step := 1.0 / 60.0
	world.camera_aim_offset = Vector3.ZERO
	for iteration in 600:
		world.camera_aim_offset = world.compute_camera_aim_offset(anchor, anchor + Vector2(200, 0), step)
	var east_offset: Vector3 = world.camera_aim_offset
	check(east_offset.x > 1.2, "look-ahead pulls camera toward east aim")
	check(absf(east_offset.z) < 0.01, "east aim does not pull camera in Z")
	check(east_offset.x <= world.EMPLOYEE_CONFIG.camera_aim_max_offset_x / 32.0 + 0.01, "look-ahead respects max offset")
	check(east_offset.x >= world.EMPLOYEE_CONFIG.camera_aim_max_offset_x / 32.0 * (200.0 / world.EMPLOYEE_CONFIG.camera_aim_distance_for_max_offset) - 0.02, "look-ahead ramps with aim distance")
	check(world.camera_3d.rotation == camera_rotation and world.camera_3d.size == camera_size, "camera rotation/size untouched by look-ahead")
	for iteration in 600:
		world.camera_aim_offset = world.compute_camera_aim_offset(anchor, anchor, step)
	check(world.camera_aim_offset.length() < 0.01, "mouse back on player smoothly recenters camera")
	# The live pipeline consumes the offset: rig = ground + aim + impulse.
	var ground_expected := Vector3(player.global_position.x / 32.0, 0.0, player.global_position.y / 32.0)
	var impulse_before: Vector3 = world.camera_impulse_offset
	world.camera_aim_offset = Vector3(0.5, 0.0, 0.25)
	world._update_camera_and_actor_projection(0.0)
	check(world.camera_rig.position.distance_to(ground_expected + Vector3(0.5, 0.0, 0.25) + impulse_before) < 0.001, "rig applies aim offset")
	world.camera_aim_offset = Vector3.ZERO
	world.camera_aim_offset = Vector3.ZERO
	check(lights.flashlight.global_position.x == player.global_position.x / 32.0, "flashlight stays body centered during look-ahead")

	# ------------------------------------------------------------------
	# 3. Faded wall keeps a shadow-only caster proxy.
	# ------------------------------------------------------------------
	var sample_wall: Node3D = null
	for wall in world.wall_root.get_children():
		sample_wall = wall
		break
	check(sample_wall != null, "wall visuals exist")
	var proxy: MeshInstance3D = sample_wall.get_node_or_null("ShadowCasterMesh")
	check(proxy != null, "shadow caster proxy exists")
	if proxy != null:
		check(proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "proxy is shadows-only")
		check(proxy.mesh != null and proxy.mesh == sample_wall.get_node("WallMesh").mesh, "proxy shares wall geometry")
		check(proxy.position == Vector3.ZERO, "proxy coincides with wall")
	sample_wall.set_wall_opacity(0.30)
	check(sample_wall.get_node("WallMesh").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "faded wall stops double shadow casting")
	if proxy != null:
		check(proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "faded wall proxy still active")
	sample_wall.set_wall_opacity(1.0)
	# 正式架构：可见墙在两种透明度下都恒为 OFF，ShadowCasterMesh 是唯一投影者。
	# 旧断言期望 ON 与"共面双投影"已过期——那正是掠射手电自阴影条纹的来源。
	check(sample_wall.get_node("WallMesh").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "opaque wall keeps the single shadow source")
	if proxy != null:
		check(proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "opaque wall proxy remains the only caster")

	# ------------------------------------------------------------------
	# 4. Blood and spent casings are lit world visuals.
	# ------------------------------------------------------------------
	await frames(1)
	var effects_before: int = world.world_effects_root.get_child_count()
	world.spawn_black_blood(anchor, Vector2.RIGHT, false, world.spawn_room_id, 1.0)
	check(world.world_effects_root.get_child_count() == effects_before + 1, "ground blood spawned")
	var blood_stain: Node2D = world.world_effects_root.get_child(world.world_effects_root.get_child_count() - 1)
	var blood_bridge: Node3D = blood_stain.get_meta("depth_visual_bridge").get_ref()
	check(blood_bridge.actor_sprite.shaded, "ground blood is lit")
	check(blood_bridge.actor_sprite.material_override != null, "ground blood uses lit carrier material")
	check(blood_bridge.actor_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "blood never blocks light")
	world.spawn_shell_ejection(anchor + Vector2(10, 0), Vector2.RIGHT, "basic")
	var shell_found := false
	for bridge in world.actor_depth_bridges_root.get_children():
		if is_instance_valid(bridge.source_actor) and bridge.source_actor.get_script() == load("res://scripts/entities/shell_effect.gd"):
			shell_found = true
			check(bridge.actor_sprite.shaded, "spent casing is lit")
			check(bridge.actor_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "casing never blocks light")
	check(shell_found, "shell bridge exists")

	# ------------------------------------------------------------------
	# 5. Unified spray: a droplet flying at a wall dies ON that wall.
	# ------------------------------------------------------------------
	var top_wall: Node3D = null
	var top_normal := Vector2.ZERO
	for wall in world.wall_root.get_children():
		var edge: Dictionary = wall.get_meta("edge")
		if String(edge.get("axis", "")) != "H":
			continue
		var sides: Array = world._edge_side_cells(edge)
		# H edge side cells: [north cell, south cell]. The spawn room's top
		# wall has the room on the SOUTH side and its inward normal points
		# down-screen (+Y).
		if world.room_cells.get(sides[1], -1) == world.spawn_room_id and world.room_cells.get(sides[0], -1) != world.spawn_room_id:
			top_wall = wall
			top_normal = Vector2(sides[1] - sides[0])
	check(top_wall != null, "found spawn-room top wall")
	if top_wall != null:
		var wall_line: float = top_wall.position.z * 32.0
		# Spray directly beneath the found wall segment (not the room centre,
		# which can be a doorway): the droplet must strike THIS wall segment.
		var spray := BlackBloodEffect.new()
		spray.global_position = Vector2(top_wall.position.x * 32.0, wall_line + 40.0)
		world.world_effects_root.add_child(spray)
		spray.set_surface_context(world, world.spawn_room_id)
		spray.wall_collision_mask = world.WORLD_WALL_LAYER
		spray.airborne_pixels.append({"position": Vector2.ZERO, "velocity": Vector2(0, -190), "height": 5.0, "vertical": 20.0})
		for frame in 40:
			await frames(1)
		check(spray.airborne_pixels.is_empty(), "wall-bound droplet ends at the wall")
		check(spray.ground_pixels.is_empty(), "wall-bound droplet never lands as floor blood")
		var wall_stains := 0
		for stain in get_nodes_in_group("black_blood_stains"):
			if stain.has_meta("blood_wall_edge_key"):
				wall_stains += 1
		check(wall_stains > 0, "droplet hitting wall spawns wall blood")
		spray.queue_free()

	# ------------------------------------------------------------------
	# 6. Same-wall accumulation + impact speed scaling.
	# ------------------------------------------------------------------
	var source_effect := BlackBloodEffect.new()
	world.world_effects_root.add_child(source_effect)
	var accumulate_normal := Vector2.UP
	var centre_px: Vector2 = Vector2(top_wall.position.x, top_wall.position.z) * 32.0
	# Both hits stay inside ONE wall segment (segments are one cell wide).
	var first_stain: Node2D = world.spawn_wall_blood_from_hit(centre_px + accumulate_normal * 10.0, accumulate_normal, world.spawn_room_id, source_effect, 300.0)
	check(first_stain != null, "speed-scaled wall stain created")
	var pixels_after_first: int = first_stain.ground_pixels.size() if first_stain != null else 0
	var second_stain: Node2D = world.spawn_wall_blood_from_hit(centre_px + Vector2(12.0, 0.0) + accumulate_normal * 10.0, accumulate_normal, world.spawn_room_id, source_effect, 120.0)
	check(second_stain == first_stain, "same wall accumulates into one stain")
	var pixels_after_second: int = second_stain.ground_pixels.size() if second_stain != null else 0
	check(pixels_after_second > pixels_after_first, "impact appends splash pixels")
	var slow_stain := BlackBloodEffect.new()
	var fast_stain := BlackBloodEffect.new()
	var stain_rng := RandomNumberGenerator.new()
	stain_rng.seed = 7
	slow_stain.setup_wall_stain(Vector2.UP, stain_rng, 40.0)
	fast_stain.setup_wall_stain(Vector2.UP, stain_rng, 300.0)
	check(fast_stain.ground_pixels.size() > slow_stain.ground_pixels.size() * 2, "impact speed scales splat size")
	source_effect.queue_free()
	slow_stain.free()
	fast_stain.free()

	# ------------------------------------------------------------------
	# 7. Door blood rides the leaf.
	# ------------------------------------------------------------------
	var door: Node3D = world.door_root.get_child(0)
	var door_body: StaticBody2D = null
	for body in world.collision_root.get_children():
		if body is StaticBody2D and body.has_meta("physical_door"):
			door_body = body
			break
	check(door_body != null, "door synced 2D body found")
	check(world.is_blood_door_collider(door_body), "door collider recognized as blood surface")
	if door_body != null:
		var door_hit: Vector2 = door_body.global_position
		var door_normal := Vector2.UP
		var door_stain: Node2D = world.spawn_door_blood_from_hit(door_hit, door_normal, door_body, null, 220.0)
		check(door_stain != null, "door blood stain created")
		if door_stain != null:
			check(door_stain.get_parent() == door_body, "door stain rides the leaf body")
			check(door_stain.is_in_group("black_blood_stains"), "door stain counts toward blood budget")
			var door_bridge: Node3D = door_stain.get_meta("depth_visual_bridge").get_ref()
			check(door_bridge.follow_source_rotation, "door stain bridge follows leaf rotation")
			var yaw_before: float = door_bridge.actor_sprite.global_basis.get_euler().y
			door_body.global_rotation += 0.5
			door_bridge._process(0.0)
			var yaw_after: float = door_bridge.actor_sprite.global_basis.get_euler().y
			check(absf(wrapf(yaw_after - yaw_before, -PI, PI) + 0.5) < 0.01, "door stain plane follows leaf yaw")
			door_stain.queue_free()

	# ------------------------------------------------------------------
	# 8. Top-wall air walls stop actors, never projectiles or blood.
	# ------------------------------------------------------------------
	var air_walls: Array[Node] = []
	for body in world.collision_root.get_children():
		if body.name.begins_with("AirWall_"):
			air_walls.append(body)
	check(air_walls.size() > 0, "top-wall air walls generated")
	if air_walls.size() > 0:
		var air_wall: StaticBody2D = air_walls[0]
		check(air_wall.collision_layer == 32, "air wall on actor-only layer")
		var air_shape: RectangleShape2D = air_wall.get_child(0).shape
		var depth: float = world.EMPLOYEE_CONFIG.top_wall_air_wall_depth_px
		check(is_equal_approx(air_shape.size.y, depth) and air_shape.size.x >= 32.0, "air wall depth from config")
		# All air walls are H edges (side walls never face away from camera).
		# The band spans [line, line + depth]; its body sits at line + depth/2.
		var band_face: float = air_wall.global_position.y + depth * 0.5
		var band_back: float = air_wall.global_position.y - depth * 0.5
		var space := player.get_world_2d().direct_space_state
		var through := PhysicsRayQueryParameters2D.create(Vector2(air_wall.global_position.x, band_face + 20.0), Vector2(air_wall.global_position.x, band_back - 40.0), 1 | 4 | 8 | 16)
		var through_hit := space.intersect_ray(through)
		check(not through_hit.is_empty(), "projectile ray still finds real wall")
		if not through_hit.is_empty():
			# The real wall collision slab is 16 px thick centered on the line:
			# a north-bound ray must stop at its south face (~line + 8).
			var distance_from_line: float = through_hit.position.y - band_back
			check(distance_from_line < 12.0, "projectile passes the air wall to the real wall")
		var blocked := PhysicsRayQueryParameters2D.create(Vector2(air_wall.global_position.x, band_face + 20.0), Vector2(air_wall.global_position.x, band_back - 40.0), 32)
		var blocked_hit := space.intersect_ray(blocked)
		check(not blocked_hit.is_empty() and absf(blocked_hit.position.y - band_face) < 0.5, "actor layer stopped at the air wall face")
	# Live walk: the player cannot reach the head-crossing zone.
	player.set_physics_process(true)
	var top_air: StaticBody2D = null
	for body in world.collision_root.get_children():
		if body.name.begins_with("AirWall_") and int(body.get_meta("generated_air_wall_room")) == world.spawn_room_id:
			top_air = body
			break
	if top_air != null:
		var depth: float = world.EMPLOYEE_CONFIG.top_wall_air_wall_depth_px
		var band_face: float = top_air.global_position.y + depth * 0.5
		player.global_position = Vector2(anchor.x, band_face + 60.0)
		Input.action_press("move_up")
		for frame in 90:
			await frames(1)
			if player.global_position.y <= band_face + 16.0:
				break
		Input.action_release("move_up")
		check(player.global_position.y >= band_face + 10.0, "player stops before head-clearance zone")
	player.set_physics_process(false)

	print("VISUAL FIXES checks=", checks, " failures=", failures.size())
	world.free()
	await frames(25)
	quit(1 if failures.size() else 0)
