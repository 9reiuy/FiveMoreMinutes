extends "res://tests/dream3d_combat_parity_test.gd"

## Windowed A/B check for the door aim outline: with the highlight forced on,
## the door silhouette must gain a white rim on its sides and bottom too —
## the old shader compiled to nothing (invalid ## comments) and showed nothing.
## Run WITHOUT --headless.

const WHITE_MIN := 0.6

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "door outline generation")
	player = world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)

	var door: Node = null
	for child in world.door_root.get_children():
		if child.is_in_group(&"physical_door_3d"):
			door = child
			break
	check(door != null, "a physical door exists")
	if door == null:
		quit(1)
		return
	var door_position: Vector3 = (door as Node3D).global_position
	player.global_position = Vector2(door_position.x, door_position.z) * 32.0 + Vector2(0, 64)
	await frames(120)

	# 正式 World Camera 做 unproject 判断；截图取最终窗口分辨率。
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var baseline := _count_white(image)
	await capture("door_outline_before")
	door.call("set_target_highlight", true)
	await frames(6)
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	var armed := _count_white(image)
	await capture("door_outline_after")
	check(armed >= baseline + 40, "forced outline paints a new white rim (baseline=%d armed=%d)" % [baseline, armed])
	print("DOOR OUTLINE baseline=", baseline, " armed=", armed)
	print("DOOR OUTLINE checks=", checks, " failures=", failures.size())
	world.free()
	await frames(25)
	quit(1 if failures.size() else 0)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + label + ".png")

func _count_white(image: Image) -> int:
	var count := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var color := image.get_pixel(x, y)
			if minf(color.r, minf(color.g, color.b)) > WHITE_MIN:
				count += 1
	return count
