extends SceneTree

const WINDOW = preload("res://scripts/dream/breakable_glass_window_3d.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var collision_root := Node2D.new()
	root.add_child(collision_root)
	var window := WINDOW.new()
	root.add_child(window)
	window.configure_window({"axis": "H", "x": 0, "y": 0}, "test", 2.6, 1.0, collision_root)
	var body := window.collision_body_2d
	check(window.collision_shape_2d.shape.size == Vector2(32, 32), "sill collision one tile deep")
	check(window.get_node("WindowFrame/PermanentSill").mesh.size.z == 1.0, "sill visual one tile deep")
	check(window.glass_pane.mesh.size.z == 0.5 and window.glass_pane.position.z == 0.0, "upper glass half tile centred")
	check(body.get_projectile_blocking_rect(1.0).size.y == 16, "high projectile uses half-depth glass")
	check(body.get_projectile_blocking_rect(0.5).size.y == 32, "low projectile uses full-depth sill")
	var a := Vector2(0, -60)
	var b := Vector2(0, 30)
	check(not CATALOG.shot_hit(body, a, b, 32).is_empty(), "intact glass blocks bullets above desk height")
	check(body.is_window_vault_target(), "explicit architectural vault capability")
	check(not window.is_shattered, "query does not break glass")
	body.commit_vault_contact(a, Vector2(0, -20))
	check(not window.is_shattered, "approaching does not break glass")
	body.commit_vault_contact(Vector2(0, -20), Vector2(0, -12))
	check(window.is_shattered, "actual crossing breaks glass")
	check(body.collision_layer != 0 and not window.collision_shape_2d.disabled, "sill remains solid after breaking")
	check(CATALOG.shot_hit(body, a, b, 32).is_empty(), "high bullet clears broken window sill")
	check(not CATALOG.shot_hit(body, a, b, 20).is_empty(), "low bullet hits permanent sill")
	window.free()
	collision_root.free()
	print("WINDOW SILL failures=", failures)
	quit(1 if failures else 0)
