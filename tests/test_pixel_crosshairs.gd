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
	check(CrosshairClass.get_shape_for_weapon_id("mp5") == CrosshairClass.CrosshairShape.T_SHAPE, "MP5 maps to T_SHAPE")
	check(CrosshairClass.get_shape_for_weapon_id("smg") == CrosshairClass.CrosshairShape.T_SHAPE, "SMG maps to T_SHAPE")
	check(CrosshairClass.get_shape_for_weapon_id("machine_gun") == CrosshairClass.CrosshairShape.T_SHAPE, "Machine gun maps to T_SHAPE")

	check(CrosshairClass.get_shape_for_weapon_id("shotgun") == CrosshairClass.CrosshairShape.BRACKET, "Shotgun maps to BRACKET")
	check(CrosshairClass.get_shape_for_weapon_id("sawed_off") == CrosshairClass.CrosshairShape.BRACKET, "Sawed-off shotgun maps to BRACKET")

	check(CrosshairClass.get_shape_for_weapon_id("lucille") == CrosshairClass.CrosshairShape.SQUARE, "Lucille bat maps to SQUARE")
	check(CrosshairClass.get_shape_for_weapon_id("books") == CrosshairClass.CrosshairShape.SQUARE, "Books maps to SQUARE")
	check(CrosshairClass.get_shape_for_weapon_id("") == CrosshairClass.CrosshairShape.SQUARE, "Unarmed / fist maps to SQUARE")

	# Test 2: Solid Vector Shader & Recoil / Reload Uniforms
	print("\n--- Test 2: Solid Vector Surface & Uniforms ---")
	var dummy_world := PointerWorld.new()
	root.add_child(dummy_world)
	dummy_world.add_to_group(&"dream_world")
	var dummy_player := MockPlayer.new()
	dummy_world.add_child(dummy_player)

	var crosshair_dummy: Control = crosshair_script.new()
	crosshair_dummy.config = CONFIG.duplicate(true)
	crosshair_dummy.size = Vector2(640, 360)
	root.add_child(crosshair_dummy)
	crosshair_dummy.set_process(false)
	crosshair_dummy.configure(dummy_player)

	check(crosshair_dummy.style_variant == CrosshairClass.StyleVariant.HAIRLINE_WHITE, "Default crosshair style is HAIRLINE_WHITE (Variant A)")
	var surface := crosshair_dummy.get_node_or_null("ReticleSurface") as ColorRect
	check(surface != null and surface.material is ShaderMaterial, "ReticleSurface and ShaderMaterial are created")
	var mat := surface.material as ShaderMaterial
	check(is_equal_approx(float(mat.get_shader_parameter(&"outline_width")), 0.50), "Variant A uses subtle 0.50 hairline backing")

	for weapon_pair in [["basic", CrosshairClass.CrosshairShape.CIRCLE], ["assault_rifle", CrosshairClass.CrosshairShape.T_SHAPE], ["shotgun", CrosshairClass.CrosshairShape.BRACKET], ["lucille", CrosshairClass.CrosshairShape.SQUARE]]:
		dummy_player.selected_weapon_id = weapon_pair[0]
		crosshair_dummy._process(0.0)
		check(int(mat.get_shader_parameter(&"shape_type")) == int(weapon_pair[1]), "Shader shape_type matches weapon %s" % weapon_pair[0])

	dummy_player.selected_weapon_id = "basic"
	dummy_player.cooldown_progress = 1.0
	crosshair_dummy._process(0.0)
	var idle_recoil := float(mat.get_shader_parameter(&"recoil_px"))
	crosshair_dummy._trigger_recoil(1.0)
	dummy_player.cooldown_progress = 0.25
	crosshair_dummy._process(0.0)
	var kicked_recoil := float(mat.get_shader_parameter(&"recoil_px"))
	check(kicked_recoil > idle_recoil, "Firing increases shader recoil_px expansion")

	dummy_player.ammo = {"uses_ammo": true, "current": 4, "capacity": 12, "reloading": true, "reload_left": crosshair_dummy.config.weapon_reload_duration * 0.5}
	crosshair_dummy._process(0.0)
	check(float(mat.get_shader_parameter(&"reloading")) > 0.5 and is_equal_approx(float(mat.get_shader_parameter(&"reload_progress")), 0.5), "Reload updates radial sweep progress shader uniform")

	crosshair_dummy.free()
	dummy_world.free()

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
