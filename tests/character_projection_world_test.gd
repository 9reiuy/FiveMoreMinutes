extends SceneTree

var OUTPUT: String="res://.runtime/character_projection/"
var checks := 0
var failures := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): OUTPUT=argument.trim_prefix("--artifact-dir=").replace("\\","/").path_join("character_projection_world")+"/"
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func bridge_for(source: Node) -> Node:
	var ref: Variant = source.get_meta(&"depth_visual_bridge", null)
	var bridge: Node = ref.get_ref() if ref is WeakRef else null
	if bridge != null:
		bridge.set_meta(&"disable_character_capture_cache", "--uncached-characters" in OS.get_cmdline_user_args())
	return bridge

func run() -> void:
	if "--background-gpu" in OS.get_cmdline_user_args(): preload("res://tests/support/background_gpu.gd").start(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	check(world.regenerate(41001), "world generated")
	var player: Node2D = world.player
	player.set_physics_process(false)
	player.invulnerability_left = 1000.0
	for enemy in world.enemy_root.get_children():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(10)
	var actor_bridge := bridge_for(player)
	check(actor_bridge != null and actor_bridge.character_projection, "production player uses separated bridge")
	var camera: Camera3D = world.camera_3d
	var muzzle: Vector2 = player.get_projectile_origin()
	var snapshot: Dictionary = actor_bridge.get_weapon_visual_snapshot(muzzle)
	for i in 8:
		var direction := Vector2.from_angle(i * TAU / 8.0)
		var bullet = preload("res://scenes/entities/basic_projectile.tscn").instantiate()
		bullet.process_mode = Node.PROCESS_MODE_DISABLED
		bullet.position = muzzle
		bullet.setup(direction, 1.0)
		world.add_projectile(bullet, player)
		var bullet_bridge := bridge_for(bullet)
		check(bullet.has_meta(&"shot_visual_origin"), "world snapshots shot %d" % i)
		check(bullet_bridge.actor_sprite.global_position.distance_to(snapshot.world_origin) < 0.001, "world first frame muzzle %d" % i)
		var tracer_copy := bullet_bridge.clone_roots[0] as Sprite2D
		var capture_center := Vector2(bullet_bridge.render_viewport.size) * 0.5
		# Current office tracer is a dynamic history image, not the retired 56x10 strip.
		var head_uv: Vector2=(tracer_copy.material as ShaderMaterial).get_shader_parameter("head_uv")
		var head_pixel: Vector2=head_uv*tracer_copy.texture.get_size()-Vector2(0.5,0.5)
		var head_capture := tracer_copy.to_global(head_pixel)
		var tail_capture := tracer_copy.to_global(head_pixel-Vector2(1.0,0.0))
		var head_world: Vector3 = bullet_bridge.actor_sprite.global_transform * Vector3(
			(head_capture.x - capture_center.x) / world.CELL_PIXELS,
			-(head_capture.y - capture_center.y) / world.CELL_PIXELS,
			0.0
		)
		var tail_world: Vector3 = bullet_bridge.actor_sprite.global_transform * Vector3(
			(tail_capture.x - capture_center.x) / world.CELL_PIXELS,
			-(tail_capture.y - capture_center.y) / world.CELL_PIXELS,
			0.0
		)
		var muzzle_screen := camera.unproject_position(snapshot.world_origin)
		var head_screen := camera.unproject_position(head_world)
		var tail_screen := camera.unproject_position(tail_world)
		var next_world: Vector3 = snapshot.world_origin + world.global_basis * Vector3(direction.x, 0.0, direction.y) * 12.0 / world.CELL_PIXELS
		var shot_screen_direction := (camera.unproject_position(next_world) - muzzle_screen).normalized()
		check(head_screen.distance_to(muzzle_screen) < 0.1, "world tracer head starts at muzzle screen point %d" % i)
		check((head_screen - tail_screen).normalized().dot(shot_screen_direction) > 0.998, "world tracer capture basis aligns with projectile screen travel %d" % i)
		var saved: Vector2 = player.position
		player.position += Vector2(8, 6)
		bullet.position += direction * 12
		await frames()
		var expected: Vector3 = snapshot.world_origin + world.global_basis * Vector3(direction.x, 0, direction.y) * 12.0 / world.CELL_PIXELS
		check(bullet_bridge.actor_sprite.global_position.distance_to(expected) < 0.001, "world bullet independent of shooter movement %d" % i)
		player.position = saved
		bullet.queue_free()
		await frames()
	for i in 8:
		var direction := Vector2.from_angle(i * TAU / 8.0)
		world.spawn_weapon_muzzle(muzzle, direction, &"assault_rifle", player)
		var flash: Node2D = world.world_effects_root.get_child(world.world_effects_root.get_child_count() - 1)
		check(flash.has_meta(&"shot_visual_origin") and flash.has_meta(&"shot_gameplay_direction"), "muzzle flash uses shot snapshot and direction %d" % i)
		var flash_bridge := bridge_for(flash)
		check(flash_bridge != null and flash_bridge.actor_sprite.global_position.distance_to(snapshot.world_origin) < 0.001, "muzzle flash and bullet same origin %d" % i)
		var flash_copy := flash_bridge.clone_roots[0] as Node2D
		var flash_center := Vector2(flash_bridge.render_viewport.size) * 0.5
		var flash_origin := flash_copy.to_global(Vector2.ZERO)
		var flash_tip := flash_copy.to_global(Vector2(12.0, 0.0))
		var flash_origin_world: Vector3 = flash_bridge.actor_sprite.global_transform * Vector3(
			(flash_origin.x - flash_center.x) / world.CELL_PIXELS,
			-(flash_origin.y - flash_center.y) / world.CELL_PIXELS,
			0.0
		)
		var flash_tip_world: Vector3 = flash_bridge.actor_sprite.global_transform * Vector3(
			(flash_tip.x - flash_center.x) / world.CELL_PIXELS,
			-(flash_tip.y - flash_center.y) / world.CELL_PIXELS,
			0.0
		)
		var expected_tip: Vector3 = snapshot.world_origin + world.global_basis * Vector3(direction.x, 0.0, direction.y) * 12.0 / world.CELL_PIXELS
		var flash_screen_direction := (camera.unproject_position(flash_tip_world) - camera.unproject_position(flash_origin_world)).normalized()
		var expected_screen_direction := (camera.unproject_position(expected_tip) - camera.unproject_position(snapshot.world_origin)).normalized()
		check(camera.unproject_position(flash_origin_world).distance_to(camera.unproject_position(snapshot.world_origin)) < 0.1, "muzzle flame starts at shot screen point %d" % i)
		check(flash_screen_direction.dot(expected_screen_direction) > 0.998, "muzzle flame aligns with bullet screen travel %d" % i)
		var last_light: int = (world.night_lighting.next_flash - 1 + world.night_lighting.muzzle_lights.size()) % world.night_lighting.muzzle_lights.size()
		check(world.night_lighting.muzzle_lights[last_light].global_position.distance_to(snapshot.world_origin) < 0.001, "pooled muzzle light shares shot origin %d" % i)
		flash.queue_free()
		await frames()
	await frames()
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(OUTPUT + "random_dream.png")
	world.queue_free()
	await frames(8)
	print("CHARACTER WORLD checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

