extends Node

## Runtime-only Player/flashlight caster probe.
## This deliberately changes cast_shadow only in memory, restores every value,
## and exits without changing the scene or any source resource.

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PIXELS_PER_UNIT := 32.0
var directions: Array[Vector2] = [
	Vector2.RIGHT,
	Vector2(1.0, 1.0).normalized(),
	Vector2.DOWN,
	Vector2(-1.0, 1.0).normalized(),
	Vector2.LEFT,
	Vector2(-1.0, -1.0).normalized(),
	Vector2.UP,
	Vector2(1.0, -1.0).normalized(),
]

var world: Node3D
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame
	if not world.regenerate(41004):
		_failures("layout generation failed")
		_finish()
		return

	var player: Node2D = world.player
	player.set_physics_process(false)
	if world.target_highlight != null:
		world.target_highlight.set_physics_process(false)
	if world.night_lighting != null:
		world.night_lighting.set_process(false)
	# Freeze all camera/interaction updates so each A/B image differs only by
	# the in-memory shadow toggle under test.
	world.set_process(false)
	var anchor: Vector2 = Vector2(world.rooms[world.spawn_room_id].center_cell) * PIXELS_PER_UNIT
	player.global_position = anchor
	world._update_camera_and_actor_projection(0.0)
	await _render_frame()

	var candidates := _collect_runtime_casters(player)
	print("PLAYER CASTER PROBE candidates=", candidates.size())
	for entry in candidates:
		var instance := entry["node"] as GeometryInstance3D
		print(
			"CASTER path=", entry["path"],
			" class=", instance.get_class(),
			" layers=", instance.layers,
			" cast_shadow=", instance.cast_shadow,
			" material=", _material_description(instance),
			" visible=", instance.visible,
			" global=", instance.global_position
		)

	# Isolate the flashlight for the A/B.  The Player shadow proxy is expected
	# to cast for ceiling/key lights, so those lights must be disabled temporarily
	# or their legitimate shadows would look like a flashlight regression.
	var disabled_lights := _disable_non_flashlight_lights(world.night_lighting.flashlight)
	var baseline_by_direction: Array[Image] = []
	for direction in directions:
		var aim: Vector2 = anchor + direction * 240.0
		world.night_lighting.aim_flashlight(anchor, aim)
		await _render_frame()
		baseline_by_direction.append(_capture_image())

	for entry in candidates:
		var caster := entry["node"] as GeometryInstance3D
		var original := caster.cast_shadow
		var total_diff := 0.0
		var max_roi_diff := 0.0
		for direction_index in directions.size():
			var direction: Vector2 = directions[direction_index]
			var aim: Vector2 = anchor + direction * 240.0
			world.night_lighting.aim_flashlight(anchor, aim)
			caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			await _render_frame()
			var ab_image := _capture_image()
			var baseline: Image = baseline_by_direction[direction_index]
			var whole := _image_difference(baseline, ab_image, Rect2i(Vector2i.ZERO, Vector2i(baseline.get_width(), baseline.get_height())))
			var player_screen: Vector2 = world.camera_3d.unproject_position(Vector3(anchor.x / PIXELS_PER_UNIT, 0.0, anchor.y / PIXELS_PER_UNIT))
			var roi := Rect2i(Vector2i(player_screen - Vector2(70, 70)), Vector2i(140, 140))
			roi = roi.intersection(Rect2i(Vector2i.ZERO, Vector2i(baseline.get_width(), baseline.get_height())))
			var player_roi: float = _image_difference(baseline, ab_image, roi)
			total_diff += whole
			max_roi_diff = maxf(max_roi_diff, player_roi)
			caster.cast_shadow = original
		print(
			"AB path=", entry["path"],
			" total_mean_abs_diff=", total_diff / float(directions.size()),
			" max_player_roi_diff=", max_roi_diff
		)

	# Explicitly test the visible carrier's prohibited state only in memory.  It
	# is restored immediately; this verifies the A/B harness can see a change if
	# a visible carrier ever becomes a shadow caster at runtime.
	var visible_carrier := world.player_depth_bridge.get("actor_sprite") as Sprite3D
	if visible_carrier != null:
		var visible_original := visible_carrier.cast_shadow
		var forced_diff := 0.0
		for direction_index in directions.size():
			var direction: Vector2 = directions[direction_index]
			world.night_lighting.aim_flashlight(anchor, anchor + direction * 240.0)
			visible_carrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
			await _render_frame()
			var baseline_size: Vector2i = baseline_by_direction[direction_index].get_size()
			forced_diff += _image_difference(baseline_by_direction[direction_index], _capture_image(), Rect2i(Vector2i.ZERO, baseline_size))
			visible_carrier.cast_shadow = visible_original
		print("AB forced visible-carrier caster mean_abs_diff=", forced_diff / float(directions.size()))
	_restore_lights(disabled_lights)

	print("PLAYER CASTER PROBE complete")
	_finish()


func _collect_runtime_casters(player: Node2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var player_world := Vector3(player.global_position.x / PIXELS_PER_UNIT, 0.0, player.global_position.y / PIXELS_PER_UNIT)
	var seen: Dictionary = {}
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
			var caster := child as GeometryInstance3D
			if caster == null or not caster.visible or caster.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			var player_family := _is_player_family(caster, player)
			var distance: float = caster.global_position.distance_to(player_world)
			if not player_family and distance > 4.0:
				continue
			var id := caster.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			result.append({"node": caster, "path": str(caster.get_path()), "player_family": player_family})
	return result


func _is_player_family(node: Node, player: Node2D) -> bool:
	if node == world.player_depth_bridge or world.player_depth_bridge.is_ancestor_of(node):
		return true
	var bridge := node.get_parent()
	while bridge != null:
		if bridge.has_method("get") and bridge.get("source_actor") == player:
			return true
		bridge = bridge.get_parent()
	return String(node.name).contains("Player") or String(node.name).contains("ShadowProxy")


func _material_description(instance: GeometryInstance3D) -> String:
	var material := instance.material_override
	if material == null and instance is MeshInstance3D:
		material = (instance as MeshInstance3D).get_active_material(0)
	return "none" if material == null else material.get_class()


func _disable_non_flashlight_lights(flashlight: Light3D) -> Array[Dictionary]:
	var saved: Array[Dictionary] = []
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
			var light := child as Light3D
			if light == null or light == flashlight:
				continue
			saved.append({"node": light, "visible": light.visible, "energy": light.light_energy})
			light.visible = false
	return saved


func _restore_lights(saved: Array[Dictionary]) -> void:
	for entry in saved:
		var light := entry["node"] as Light3D
		if not is_instance_valid(light):
			continue
		light.visible = bool(entry["visible"])
		light.light_energy = float(entry["energy"])


func _render_frame() -> void:
	await get_tree().process_frame
	# Headless runs do not always emit frame_post_draw. Two process frames are
	# enough for the light/bridge transforms to reach the rendering server.
	await get_tree().process_frame


func _capture_image() -> Image:
	var texture := get_tree().root.get_texture()
	if texture == null:
		return Image.create_empty(0, 0, false, Image.FORMAT_RGBA8)
	return texture.get_image()


func _image_difference(a: Image, b: Image, rect: Rect2i) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	if rect.size.x <= 0 or rect.size.y <= 0:
		return 0.0
	var total := 0.0
	var samples := 0
	for y in range(rect.position.y, rect.end.y, 4):
		for x in range(rect.position.x, rect.end.x, 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			samples += 1
	return total / float(maxi(samples * 3, 1))


func _failures(message: String) -> void:
	failures.append(message)
	print("FAIL ", message)


func _finish() -> void:
	if is_instance_valid(world):
		world.free()
	await get_tree().process_frame
	get_tree().quit(1 if not failures.is_empty() else 0)
