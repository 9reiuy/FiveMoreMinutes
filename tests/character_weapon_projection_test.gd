extends SceneTree

const BRIDGE = preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
const PROJECTION = preload("res://scripts/dream/character_visual_projection.gd")
var OUTPUT: String="res://.runtime/character_projection/"

class ProbeActor extends Node2D:
	var knockback_height := 0.0
	var dead := false
	var room_runtime_active := true

var failures: Array[String] = []
var checks := 0
var stage: Node3D
var camera: Camera3D
var viewport: SubViewport
var actor: ProbeActor
var bridge: Node3D
var gun_root: Node2D
var wall: MeshInstance3D

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): OUTPUT=argument.trim_prefix("--artifact-dir=").replace("\\","/").path_join("character_weapon_projection")+"/"
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL: ", message)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func texture(size: Vector2i, color: Color) -> ImageTexture:
	var pixels := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	pixels.fill(color)
	return ImageTexture.create_from_image(pixels)

func sprite(parent: Node, node_name: String, size: Vector2i, color: Color, at: Vector2) -> Sprite2D:
	var node := Sprite2D.new()
	node.name = node_name
	node.texture = texture(size, color)
	node.position = at
	parent.add_child(node)
	return node

func make_bridge(source: Node2D, paths: Array, capture_offset := Vector2(64, 96)) -> Node3D:
	var node := BRIDGE.new()
	node.set_meta(&"test_legacy_pending_refresh", "--legacy-pending-refresh" in OS.get_cmdline_user_args())
	node.set_meta(&"disable_character_capture_cache", "--uncached-characters" in OS.get_cmdline_user_args())
	stage.add_child(node)
	var capture := SubViewport.new()
	capture.size = Vector2i(128, 128)
	capture.transparent_bg = true
	capture.disable_3d = true
	node.add_child(capture)
	var capture_root := Node2D.new()
	capture.add_child(capture_root)
	node.set_world_camera(camera)
	node.configure(source, capture, capture_root, null, paths, 0.70710678, -0.70710678, capture_offset)
	return node

func count_body(image: Image) -> int:
	var total := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.b > 0.4 and c.b > c.r * 1.8 and c.b > c.g * 1.5:
				total += 1
	return total

func run() -> void:
	if "--background-gpu" in OS.get_cmdline_user_args(): preload("res://tests/support/background_gpu.gd").start(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(480, 360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 8, 8)
	camera.look_at(Vector3.ZERO)
	camera.fov = 40
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.04, 0.04, 0.04)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.5
	stage.add_child(environment)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = PlaneMesh.new()
	(floor_node.mesh as PlaneMesh).size = Vector2(12, 12)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.18, 0.18)
	floor_node.material_override = floor_mat
	stage.add_child(floor_node)
	actor = ProbeActor.new()
	actor.add_to_group(&"dream_player")
	root.add_child(actor)
	var collider := Node2D.new()
	collider.name = "CollisionShape2D"
	collider.position.y = -13
	actor.add_child(collider)
	var body := Node2D.new()
	body.name = "CharacterVisual"
	actor.add_child(body)
	sprite(body, "Body", Vector2i(12, 28), Color(0.05, 0.12, 1), Vector2(0, -18))
	sprite(body, "LeftFoot", Vector2i(4, 4), Color(0.05, 0.12, 1), Vector2(-3, -2))
	sprite(body, "RightFoot", Vector2i(4, 4), Color(0.05, 0.12, 1), Vector2(3, -2))
	gun_root = Node2D.new()
	gun_root.name = "WeaponRoot"
	gun_root.position.y = -18
	actor.add_child(gun_root)
	sprite(gun_root, "Gun", Vector2i(64, 5), Color.WHITE, Vector2(30, 0))
	var hp := Node2D.new()
	hp.name = "PlayerHPBar"
	actor.add_child(hp)
	sprite(hp, "Bar", Vector2i(16, 2), Color.GREEN, Vector2(0, -45))
	bridge = make_bridge(actor, [^"CharacterVisual", ^"WeaponRoot", ^"PlayerHPBar"])
	bridge.lit_material.set_shader_parameter("character_emission_strength", 0.7)
	bridge.weapon_material.set_shader_parameter("character_emission_strength", 0.7)
	await frames()
	var fixed_y: float = bridge.actor_sprite.global_position.y
	var fixed_grip: float = bridge.weapon_reference_height
	check(bridge.render_root.get_node_or_null("WeaponRoot") == null, "body capture excludes weapon")
	check(bridge.weapon_capture_root.has_node("WeaponRoot"), "weapon captured separately")
	check(bridge.attachment_capture_root.has_node("PlayerHPBar"), "UI captured separately")
	var grid := Image.create(480 * 4, 360 * 2, false, Image.FORMAT_RGBA8)
	for i in 8:
		gun_root.rotation = i * TAU / 8.0
		await frames()
		check(absf(bridge.actor_sprite.global_position.y - fixed_y) < 0.00001, "body fixed at aim %d" % i)
		check(absf(bridge.weapon_reference_height - fixed_grip) < 0.00001, "grip fixed at aim %d" % i)
		var muzzle := gun_root.to_global(Vector2(62, 0))
		var shot: Dictionary = bridge.get_weapon_visual_snapshot(muzzle)
		var world_point: Vector3 = shot.world_origin
		check(absf(world_point.y - fixed_grip) < 0.00001 and world_point.y > 0.05, "muzzle above floor at aim %d" % i)
		var local_pixel: Vector2 = muzzle - actor.global_position + bridge.viewport_offset - Vector2(64, 64)
		# Production rotates passive weapon pixels about the authored grip.
		var grip_pixel: Vector2=gun_root.global_position-actor.global_position+bridge.viewport_offset-Vector2(64,64)
		local_pixel=grip_pixel+(local_pixel-grip_pixel).rotated(bridge.weapon_capture_rotation_delta)
		var colour: Vector3 = bridge.actor_sprite.global_transform * (Vector3(local_pixel.x, -local_pixel.y, 0) / 32.0)
		check(camera.unproject_position(colour).distance_to(camera.unproject_position(world_point)) < 0.01, "muzzle projection continuity %d" % i)
		if DisplayServer.get_name() != "headless":
			var rendered := viewport.get_texture().get_image()
			grid.blit_rect(rendered, Rect2i(0, 0, 480, 360), Vector2i((i % 4) * 480, (i / 4) * 360))
			var muzzle_screen := Vector2i(camera.unproject_position(world_point))
			var white := false
			for y in range(muzzle_screen.y - 3, muzzle_screen.y + 4):
				for x in range(muzzle_screen.x - 3, muzzle_screen.x + 4):
					if x >= 0 and y >= 0 and x < 480 and y < 360:
						var pixel := rendered.get_pixel(x, y)
						white = white or (pixel.r > 0.65 and pixel.g > 0.65 and pixel.b > 0.65)
			check(white, "GPU gun tip visible over floor %d" % i)
		print("AIM ", i, " body_y=", bridge.actor_sprite.global_position.y, " grip_y=", fixed_grip, " muzzle=", world_point)
	if DisplayServer.get_name() != "headless":
		grid.save_png(OUTPUT + "eight_directions.png")
		gun_root.visible = false
		await frames()
		var unobstructed := count_body(viewport.get_texture().get_image())
		check(unobstructed > 50, "body actually rendered")
		wall = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4, 3, 0.08)
		wall.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.15, 0.08)
		wall.material_override = mat
		stage.add_child(wall)
		wall.position = Vector3(0, 1.5, -0.20)
		await frames()
		var front_image := viewport.get_texture().get_image()
		check(count_body(front_image) == 0, "front wall blocks entire body, no tilted head protrusion")
		front_image.save_png(OUTPUT + "wall_front.png")
		wall.position.z = -0.65
		await frames()
		var back_image := viewport.get_texture().get_image()
		check(count_body(back_image) >= unobstructed - 8, "wall behind body does not cut its silhouette")
		back_image.save_png(OUTPUT + "wall_back.png")
		wall.queue_free()
	gun_root.visible = true
	actor.knockback_height = 16.0
	body.position.y = -16.0
	gun_root.position.y -= 16.0
	await frames()
	check(absf(bridge.actor_sprite.global_position.y - fixed_y - 0.5) < 0.00001, "fake height affects body once")
	check(absf(bridge.weapon_reference_height - fixed_grip - 0.5) < 0.00001, "fake height affects grip once")
	var airborne_muzzle := gun_root.to_global(Vector2(62, 0))
	var airborne_shot: Dictionary = bridge.get_weapon_visual_snapshot(airborne_muzzle)
	var airborne_pixel: Vector2 = airborne_muzzle - actor.global_position + Vector2(0, 16) + bridge.viewport_offset - Vector2(64, 64)
	var airborne_grip: Vector2=gun_root.global_position-actor.global_position+Vector2(0,16)+bridge.viewport_offset-Vector2(64,64)
	airborne_pixel=airborne_grip+(airborne_pixel-airborne_grip).rotated(bridge.weapon_capture_rotation_delta)
	var airborne_colour: Vector3 = bridge.actor_sprite.global_transform * (Vector3(airborne_pixel.x, -airborne_pixel.y, 0) / bridge.PIXELS_PER_WORLD_CELL)
	check(camera.unproject_position(airborne_colour).distance_to(camera.unproject_position(airborne_shot.world_origin)) < 0.01, "airborne muzzle uses capture fake-height compensation")
	actor.knockback_height = 0.0
	body.position.y = 0.0
	gun_root.position.y += 16.0
	await frames()
	bridge.set_room_presentation_active(false)
	check(not bridge.weapon_sprite.visible and not bridge.attachment_sprite.visible, "dormant layers hidden")
	bridge.set_room_presentation_active(true)
	await frames()
	check(bridge.weapon_sprite.visible, "reactivated weapon visible")
	actor.queue_free()
	await frames()
	check(not is_instance_valid(bridge), "source release frees all character layers")
	await real_actors()
	viewport.queue_free()
	await frames()
	print("CHARACTER PROJECTION checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func real_actors() -> void:
	var config = preload("res://resources/demo_config.tres")
	var pose_solver = preload("res://scripts/dream/dream_weapon_pose.gd")
	for kind in ["dream_player", "employee_enemy"]:
		var source = load("res://scenes/entities/%s.tscn" % kind).instantiate()
		source.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(source)
		if kind == "dream_player":
			source.configure_weapon("assault_rifle", config)
		else:
			source.equip_weapon("assault_rifle")
		var visual := make_bridge(source, [^"CharacterVisual", ^"WeaponRoot"])
		await frames()
		check(visual.character_projection, "%s uses separated presentation" % kind)
		var body_y: float = visual.actor_sprite.global_position.y
		var grip_y: float = visual.weapon_reference_height
		var sheet := Image.create(1920, 720, false, Image.FORMAT_RGBA8)
		for i in 8:
			var direction := Vector2.from_angle(i * TAU / 8.0)
			var distance: float = config.held_weapon_distance
			var pose: Dictionary = pose_solver.solve(direction, maxf(distance + 3, 12), maxf(distance * 0.82, 8), distance)
			var weapon: Node2D = source.get_node("WeaponRoot")
			var muzzle: Node2D = source.projectile_origin
			if kind == "dream_player":
				weapon.get_node("HandAnchor").position = pose.orbit_offset
				weapon.get_node("HandAnchor").rotation = direction.angle()
				muzzle.position = pose.orbit_offset + (pose.muzzle_local as Vector2).rotated(direction.angle())
			else:
				weapon.position = source.weapon_root_base_position + pose.orbit_offset
				weapon.rotation = direction.angle()
				muzzle.position = pose.muzzle_local
			await frames()
			check(is_equal_approx(visual.actor_sprite.global_position.y, body_y), "%s fixed body %d" % [kind, i])
			check(is_equal_approx(visual.weapon_reference_height, grip_y), "%s fixed grip %d" % [kind, i])
			var shot: Dictionary = visual.get_weapon_visual_snapshot(muzzle.global_position)
			var bullet = preload("res://scenes/entities/basic_projectile.tscn").instantiate()
			bullet.process_mode = Node.PROCESS_MODE_DISABLED
			root.add_child(bullet)
			bullet.global_position = muzzle.global_position
			bullet.setup(direction, 1.0)
			bullet.set_meta(&"shot_visual_origin", shot.world_origin)
			bullet.set_meta(&"shot_gameplay_origin", shot.gameplay_origin)
			var bullet_visual := make_bridge(bullet, [^"BulletSprite"], Vector2(64, 64))
			await frames()
			check(bullet_visual.actor_sprite.global_position.distance_to(shot.world_origin) < 0.0001, "%s first bullet at muzzle %d" % [kind, i])
			if DisplayServer.get_name() != "headless":
				sheet.blit_rect(viewport.get_texture().get_image(), Rect2i(0, 0, 480, 360), Vector2i((i % 4) * 480, (i / 4) * 360))
			weapon.rotation += 0.4
			bullet.global_position += direction * 20.0
			await frames()
			var expected: Vector3 = shot.world_origin + Vector3(direction.x, 0, direction.y) * 20.0 / visual.PIXELS_PER_WORLD_CELL
			check(bullet_visual.actor_sprite.global_position.distance_to(expected) < 0.0001, "%s fired bullet independent of gun %d" % [kind, i])
			weapon.rotation -= 0.4
			bullet.queue_free()
			await frames()
		if DisplayServer.get_name() != "headless":
			sheet.save_png(OUTPUT + kind + "_eight_directions.png")
		print("REAL ACTOR ", kind, " body_y=", body_y, " grip_y=", grip_y)
		source.queue_free()
		await frames()

