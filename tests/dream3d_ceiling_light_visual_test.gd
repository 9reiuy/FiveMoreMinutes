extends "res://tests/dream3d_combat_parity_test.gd"

## Windowed visual check for the ceiling-light rule: a small room shows one
## dark translucent panel (never the old blown-out white board) while the
## SpotLight3D still lights the room. Run WITHOUT --headless.

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "ceiling light visual generation")
	player = world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)

	var selected: Dictionary = {}
	for room in world.rooms:
		if not bool(room.get("is_large", false)):
			selected = room
			break
	check(not selected.is_empty(), "a small room exists for the visual check")
	var cell := Vector2i(selected.get("center_cell", Vector2i.ZERO))
	player.position = Vector2(cell) * 32.0
	var holder: Node3D = null
	for child in world.ceiling_light_root.get_children():
		if int(child.get_meta("dream_room_id", -1)) == int(selected.get("id", -1)):
			holder = child
			break
	check(holder != null, "the selected small room owns its ceiling light")
	await frames(120)

	var screen_point: Vector2 = world.camera_3d.unproject_position(holder.global_position)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var patch_mean := _sample_mean(image, screen_point)
	check(patch_mean < 0.35, "fixture region is no white board (mean=%.3f)" % patch_mean)
	print("CEILING LIGHT PATCH MEAN=%.3f at %s holder=%s" % [patch_mean, screen_point, holder.global_position])
	await capture("ceiling_light_visual")
	print("CEILING LIGHT VISUAL checks=", checks, " failures=", failures.size())
	world.free()
	await frames(25)
	quit(1 if failures.size() else 0)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + label + ".png")

func _sample_mean(image: Image, center: Vector2) -> float:
	var total := 0.0
	var samples := 0
	for offset_y in range(-6, 7, 2):
		for offset_x in range(-6, 7, 2):
			var point := Vector2i(center + Vector2(offset_x, offset_y))
			if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
				continue
			var color := image.get_pixelv(point)
			total += (color.r + color.g + color.b) / 3.0
			samples += 1
	return total / float(maxi(samples, 1))
