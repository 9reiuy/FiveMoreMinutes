extends SceneTree

## 20-seed 3D 可视回归（批准书 §14）：逐 seed 截图 WallRoot/DoorRoot/
## PhysicalDoor 实际渲染，供人工核对门-墙-碰撞对齐。

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

const SEEDS := [41002, 41004, 41005, 41007, 41012, 41016, 41019, 41026, 41030, 41033,
	41039, 41042, 41044, 41046, 41051, 41055, 41060, 41064, 41070, 41080]


func _init() -> void:
	call_deferred("_run")


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var index := 0
	for seed_value in SEEDS:
		var world: Node3D = SCENE.instantiate()
		world.generate_on_ready = false
		world.spawn_content = false
		world.persist_profile = false
		world.show_debug_markers = true
		root.add_child(world)
		await frames(2)
		world.regenerate(seed_value)
		var player: Node2D = world.player
		player.set_physics_process(false)
		# 传送到第一扇内部门旁：让截图覆盖 门叶/墙洞/两侧房间 对齐。
		var door_side := Vector2.ZERO
		for edge in world.door_edges.values():
			var door_a: Variant = edge.get("door_a", {})
			if String(edge.get("kind", "")) == "internal" and door_a is Dictionary and door_a.has("inside_cell"):
				var inside: Vector2i = door_a["inside_cell"]
				door_side = Vector2(inside) * 32.0 + Vector2(16, 16)
				break
		player.global_position = door_side if door_side != Vector2.ZERO else Vector2(world.rooms[int(world.spawn_room_id)]["center_cell"]) * 32.0
		await frames(60)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/door_visual_seed_%d.png" % seed_value)
		print("VISUAL seed=%d doors=%d" % [seed_value, world.door_edges.size()])
		world.free()
		await frames(10)
		index += 1
	print("VISUAL COMPLETE ", index)
	quit(0)
