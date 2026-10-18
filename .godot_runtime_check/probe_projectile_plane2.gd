extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const CONFIG := preload("res://resources/demo_config.tres")
var world: Node3D

func _init() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await _frames(2)
	world.regenerate(41002)
	var player: Node2D = world.player
	player.set_physics_process(false)
	player.set_process(false)
	player.equip_weapon("basic", CONFIG, {})
	await _frames(2)
	var origin: Vector2 = player.get_projectile_origin()
	var bridge: Node3D = world.player_depth_bridge
	var camera: Camera3D = world.camera_3d
	var actor_pos: Vector3 = bridge.actor_sprite.global_position
	var basis: Basis = bridge.actor_sprite.global_basis
	var delta_2d := origin - player.global_position
	var muzzle_visual_world := actor_pos + basis * Vector3(delta_2d.x / 32.0, -delta_2d.y / 32.0, 0.0)
	print("PLAYER2D=", player.global_position, " ORIGIN=", origin, " DELTA=", delta_2d)
	print("ACTOR3D=", actor_pos, " BASIS=", basis)
	print("MUZZLE_VISUAL3D=", muzzle_visual_world, " SCREEN=", camera.unproject_position(muzzle_visual_world))
	print("FLAT_0120=", camera.unproject_position(Vector3(origin.x / 32.0, 0.12, origin.y / 32.0)))
	print("ACTOR_ANCHOR=", camera.unproject_position(Vector3(origin.x / 32.0, 0.70710678, origin.y / 32.0 - 0.70710678)))
	var best := Vector3(INF, INF, INF)
	var best_error := INF
	for yi in range(-20, 41):
		var y := float(yi) * 0.05
		for di in range(-40, 41):
			var d := float(di) * 0.05
			var point := Vector3(origin.x / 32.0, y, origin.y / 32.0 + d)
			var error := camera.unproject_position(point).distance_to(camera.unproject_position(muzzle_visual_world))
			if error < best_error:
				best_error = error
				best = point
	print("BEST_ANCHOR=", best, " ERROR_PX=", best_error, " SCREEN=", camera.unproject_position(best))
	var held_sprite: Node2D = player.get_node_or_null("WeaponRoot/HandAnchor/WeaponMotion/ReloadVisualPivot/HeldWeaponSprite") as Node2D
	if held_sprite != null:
		var held_delta := held_sprite.global_position - player.global_position
		var held_world := actor_pos + basis * Vector3(held_delta.x / 32.0, -held_delta.y / 32.0, 0.0)
		print("HELD2D=", held_sprite.global_position, " HELD_VISUAL3D=", held_world, " SCREEN=", camera.unproject_position(held_world))
		
	world.free()
	await _frames(2)
	quit()
