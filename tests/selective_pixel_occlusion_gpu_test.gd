extends SceneTree
## GPU regression for the unified world viewport. Sample actual rendered pixels
## rather than the retired character-visibility mask.
const PREVIEW_PATH = "res://scenes/dream/preview/SelectivePixelPreview.tscn"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func frames(count: int) -> void:
	for _i in count:
		await process_frame


func world_image(preview: Node) -> Image:
	await frames(6)
	await RenderingServer.frame_post_draw
	return preview.world_viewport.get_texture().get_image()


func region_difference(first: Image, second: Image, center: Vector2i, radius: int) -> float:
	var total := 0.0
	var samples := 0
	for y in range(maxi(0, center.y - radius), mini(first.get_height(), center.y + radius + 1)):
		for x in range(maxi(0, center.x - radius), mini(first.get_width(), center.x + radius + 1)):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			samples += 1
	return total / maxf(float(samples), 1.0)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Load after autoloads exist: the display adapter references SettingsManager.
	var preview: Control = load(PREVIEW_PATH).instantiate()
	root.add_child(preview)
	await frames(35)
	var world: Node3D = preview.world
	world.set_process(false)
	world.player.set_physics_process(false)
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
		var bridge: Variant = enemy.get_meta(&"depth_visual_bridge", null)
		if bridge is WeakRef and is_instance_valid(bridge.get_ref()):
			bridge.get_ref().hide()
	await frames(12)
	var sprite: Sprite3D = world.player_depth_bridge.actor_sprite
	var center_world: Vector3 = sprite.global_position
	var center := Vector2i(world.camera_3d.unproject_position(center_world).round())
	var baseline: Image = await world_image(preview)
	check(sprite.is_visible_in_tree(), "Player sprite is visible in the world viewport")
	check(Rect2i(Vector2i.ZERO, preview.world_viewport.size).has_point(center), "Player projects inside world viewport")
	if not Rect2i(Vector2i.ZERO, preview.world_viewport.size).has_point(center):
		preview.queue_free()
		await frames(3)
		quit(1)
		return
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3, 4, 2)
	box.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.35, 0.4)
	box.material_override = material
	world.add_child(box)
	var toward_camera: Vector3 = (world.camera_3d.global_position - center_world).normalized()
	box.global_position = center_world + toward_camera * 4.0
	var front: Image = await world_image(preview)
	var front_delta := region_difference(baseline, front, center, 10)
	check(front_delta > 0.1, "Opaque foreground occludes player in the same depth buffer")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.2
	var glass: Image = await world_image(preview)
	var glass_delta := region_difference(baseline, glass, center, 10)
	check(glass_delta < front_delta * 0.8, "Transparent foreground keeps the player visible")
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color.a = 1.0
	box.global_position = center_world - toward_camera * 4.0
	var back: Image = await world_image(preview)
	var back_delta := region_difference(baseline, back, center, 10)
	check(back_delta < front_delta * 0.8, "Player remains visible ahead of background geometry")
	box.queue_free()
	await frames(4)
	var removed: Image = await world_image(preview)
	var removed_delta := region_difference(baseline, removed, center, 10)
	check(removed_delta < front_delta * 0.3, "Removing occluder restores the original world image")
	print("UNIFIED_OCCLUSION checks=", checks, " failures=", failures.size(), " deltas=", [front_delta, glass_delta, back_delta, removed_delta])
	preview.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
