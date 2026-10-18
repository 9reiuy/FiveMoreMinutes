extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const FLOOR_TILE_SCENE := preload("res://scenes/dream/3d/Floortile3D.tscn")

func _init() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	var world: Node3D = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	world.regenerate(41005)
	var player: Node2D = world.player
	player.set_physics_process(false)
	var anchor := Vector2(world.rooms[int(world.spawn_room_id)]["center_cell"]) * 32.0
	player.global_position = anchor
	var aim := anchor + Vector2(220, 0)
	world.night_lighting.set_process(false)
	world.night_lighting.aim_flashlight(player.global_position, aim)
	await frames(45)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/floor_ab_multimesh.png")

	# 重建逐格地板（Pre-2A 表现路径）
	for child in world.get("floor_root").get_children():
		child.free()
	for cell_variant in world.floor_cells.keys():
		var cell: Vector2i = cell_variant
		var floor_tile := FLOOR_TILE_SCENE.instantiate() as Node3D
		floor_tile.position = Vector3(cell.x, 0.0, cell.y)
		world.get("floor_root").add_child(floor_tile)
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/floor_ab_percell.png")
	print("FLOOR AB DONE")
	quit(0)
