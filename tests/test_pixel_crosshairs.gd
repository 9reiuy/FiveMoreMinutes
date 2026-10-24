extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")
var checks := 0
var failures: Array[String] = []
var draw_events := 0

class PointerWorld extends Node:
	func get_gameplay_aim_position() -> Vector2:
		return Vector2.ZERO

class MockPlayer extends Node:
	signal confirmed_projectile_fired
	signal weapon_fired(multiplier: float)
	signal active_weapon_changed(weapon_id: String)
	
	var selected_weapon_id := "basic"
	var pointer := Vector2(160, 90)
	var ammo := {"uses_ammo": true, "current": 8, "capacity": 8, "reloading": false, "reload_left": 0.0}
	var cooldown_progress := 1.0

	func get_weapon_cooldown_progress() -> float:
		return cooldown_progress

	func get_constrained_aim_position() -> Vector2:
		return pointer

	func get_presentation_pointer_position() -> Vector2:
		return pointer

	func get_presentation_hud_position(pos: Vector2) -> Vector2:
		return pos

	func get_ammo_status() -> Dictionary:
		return ammo


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FAILURE: " + label)
	else:
		print("  [PASS] " + label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("=== RUNNING PIXEL CROSSHAIRS UNIT TEST SUITE ===")

	var crosshair_script = load("res://scripts/ui/crosshair.gd")
	var CrosshairClass = crosshair_script

	# Test 1: Weapon ID to CrosshairShape mapping
	print("\n--- Test 1: Weapon ID Mapping ---")
	check(CrosshairClass.get_shape_for_weapon_id("basic") == CrosshairClass.CrosshairShape.CIRCLE, "Basic Luger maps to CIRCLE")
	check(CrosshairClass.get_shape_for_weapon_id("pistol") == CrosshairClass.CrosshairShape.CIRCLE, "Pistol maps to CIRCLE")
	check(CrosshairClass.get_shape_for_weapon_id("sniper") == CrosshairClass.CrosshairShape.CIRCLE, "Sniper maps to CIRCLE")

	check(CrosshairClass.get_shape_for_weapon_id("assault_rifle") == CrosshairClass.CrosshairShape.T_SHAPE, "Assault Rifle maps to T_SHAPE")
	check(CrosshairClass.get_shape_for_weapon_id("smg") == CrosshairClass.CrosshairShape.T_SHAPE, "SMG maps to T_SHAPE")
	check(CrosshairClass.get_shape_for_weapon_id("machine_gun") == CrosshairClass.CrosshairShape.T_SHAPE, "Machine gun maps to T_SHAPE")

	check(CrosshairClass.get_shape_for_weapon_id("shotgun") == CrosshairClass.CrosshairShape.BRACKET, "Shotgun maps to BRACKET")
	check(CrosshairClass.get_shape_for_weapon_id("sawed_off") == CrosshairClass.CrosshairShape.BRACKET, "Sawed-off shotgun maps to BRACKET")

	check(CrosshairClass.get_shape_for_weapon_id("lucille") == CrosshairClass.CrosshairShape.SQUARE, "Lucille bat maps to SQUARE")
	check(CrosshairClass.get_shape_for_weapon_id("books") == CrosshairClass.CrosshairShape.SQUARE, "Books maps to SQUARE")
	check(CrosshairClass.get_shape_for_weapon_id("") == CrosshairClass.CrosshairShape.SQUARE, "Unarmed / fist maps to SQUARE")

	# Test 2: Geometry Generation & Symmetry
	print("\n--- Test 2: Geometry Generation & Symmetry ---")
	var crosshair_dummy: Control = crosshair_script.new()
	crosshair_dummy.config = CONFIG.duplicate(true)

	var center := Vector2i(100, 100)
	for shape_idx in range(4):
		var shape: int = shape_idx
		var rects_idle: Array[Rect2i] = crosshair_dummy._get_shape_pixel_rects(shape, center, 0.0)
		check(not rects_idle.is_empty(), "Shape %d produces non-empty rects" % shape)

		# Check all rects have positive dimensions
		var all_positive := true
		for r in rects_idle:
			if r.size.x <= 0 or r.size.y <= 0:
				all_positive = false
		check(all_positive, "Shape %d all rects have positive size" % shape)

		# Check center pip is present
		var has_center_pip := false
		for r in rects_idle:
			if r.has_point(center):
				has_center_pip = true
				break
		check(has_center_pip, "Shape %d has center aim pip" % shape)

		# Test recoil expansion
		var rects_recoil: Array[Rect2i] = crosshair_dummy._get_shape_pixel_rects(shape, center, 4.0)
		check(rects_recoil.size() == rects_idle.size(), "Shape %d maintains element count during recoil" % shape)

		# Find bounding box of idle vs recoil
		var bbox_idle := _calc_bbox(rects_idle)
		var bbox_recoil := _calc_bbox(rects_recoil)
		check(bbox_recoil.size.x >= bbox_idle.size.x and bbox_recoil.size.y >= bbox_idle.size.y, "Shape %d expands during recoil kick" % shape)
	crosshair_dummy.free()

	# Test 3: Dynamic Weapon Switching
	print("\n--- Test 3: Dynamic Weapon Switching & Redraw Integration ---")
	var world := PointerWorld.new()
	root.add_child(world)
	world.add_to_group(&"dream_world")

	var player := MockPlayer.new()
	world.add_child(player)

	var crosshair: Control = crosshair_script.new()
	crosshair.config = CONFIG.duplicate(true)
	crosshair.current_color = crosshair.config.crosshair_ready_color
	crosshair.size = Vector2(640, 360)
	crosshair.draw.connect(func(): draw_events += 1)
	root.add_child(crosshair)
	crosshair.set_process(false)
	crosshair.configure(player)

	crosshair._process(0.0)
	for i in 3: await process_frame
	check(draw_events > 0, "Initial crosshair redraw completed")

	player.selected_weapon_id = "basic"
	check(crosshair.get_current_crosshair_shape() == CrosshairClass.CrosshairShape.CIRCLE, "Crosshair queries CIRCLE for basic")

	player.selected_weapon_id = "assault_rifle"
	check(crosshair.get_current_crosshair_shape() == CrosshairClass.CrosshairShape.T_SHAPE, "Crosshair queries T_SHAPE for assault_rifle")

	player.selected_weapon_id = "shotgun"
	check(crosshair.get_current_crosshair_shape() == CrosshairClass.CrosshairShape.BRACKET, "Crosshair queries BRACKET for shotgun")

	player.selected_weapon_id = "lucille"
	check(crosshair.get_current_crosshair_shape() == CrosshairClass.CrosshairShape.SQUARE, "Crosshair queries SQUARE for lucille")

	player.selected_weapon_id = ""
	check(crosshair.get_current_crosshair_shape() == CrosshairClass.CrosshairShape.SQUARE, "Crosshair queries SQUARE for unarmed")

	# Test Pointer Move and Weapon Switching Redraw
	var prev_draws := draw_events
	player.pointer += Vector2(10, 10)
	crosshair._process(0.0)
	for i in 3: await process_frame
	check(draw_events > prev_draws, "Pointer move triggers redraw")
	prev_draws = draw_events

	player.selected_weapon_id = "shotgun"
	player.active_weapon_changed.emit("shotgun")
	crosshair._process(0.0)
	for i in 3: await process_frame
	check(draw_events > prev_draws, "Active weapon change triggers crosshair redraw")

	crosshair.free()
	world.free()

	print("\n========================================================")
	print("PIXEL CROSSHAIR TEST COMPLETED: %d checks, %d failures" % [checks, failures.size()])
	print("========================================================")
	quit(0 if failures.is_empty() else 1)


func _calc_bbox(rects: Array[Rect2i]) -> Rect2i:
	if rects.is_empty():
		return Rect2i()
	var min_p := rects[0].position
	var max_p := rects[0].position + rects[0].size
	for r in rects:
		min_p.x = mini(min_p.x, r.position.x)
		min_p.y = mini(min_p.y, r.position.y)
		max_p.x = maxi(max_p.x, r.position.x + r.size.x)
		max_p.y = maxi(max_p.y, r.position.y + r.size.y)
	return Rect2i(min_p, max_p - min_p)
