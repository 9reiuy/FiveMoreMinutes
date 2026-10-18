extends SceneTree

const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const LOGIC = preload("res://scenes/dream/props/desk.tscn")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for kind in ["coffee_table", "sorting_table", "shelf", "cabinet", "fridge", "server", "workstation"]:
		var source = LOGIC.instantiate()
		CATALOG.configure(source, kind)
		root.add_child(source)
		source.freeze = true
		var bullet = preload("res://scenes/entities/basic_projectile.tscn").instantiate()
		bullet.set_meta(&"shot_height_pixels", 32.0)
		root.add_child(bullet)
		bullet.set_physics_process(false)
		await physics_frame
		await physics_frame
		var physics_hit: Dictionary = bullet._cast_movement_segment(Vector2(-100, 0), Vector2(100, 0))
		check(physics_hit.is_empty() == (kind in ["coffee_table", "sorting_table", "workstation"]), "real projectile sweep " + kind)
		bullet.free()
		var hit := CATALOG.shot_hit(source, Vector2(-100, 0), Vector2(100, 0), 32.0)
		check(hit.is_empty() == (kind in ["coffee_table", "sorting_table", "workstation"]), "height crossing " + kind)
		if kind == "workstation":
			check(not CATALOG.shot_hit(source, Vector2(0, -100), Vector2(0, 100), 32.0).is_empty(), "monitor local blocker")
		if kind == "coffee_table":
			source.sky_drop_height = 28.0
			check(not CATALOG.shot_hit(source, Vector2(-100, 0), Vector2(100, 0), 32.0).is_empty(), "airborne furniture follows height")
		source.destroyed = true
		check(CATALOG.shot_hit(source, Vector2(-100, 0), Vector2(100, 0), 32.0).is_empty(), "destroyed removed")
		source.free()
	for kind in CATALOG.DEFINITIONS:
		var visual := CATALOG.make_visual(kind)
		var meshes: Array[MeshInstance3D] = []
		CATALOG._collect_meshes(visual, meshes)
		var triangles := 0
		for mesh in meshes:
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var indices: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
				triangles += (indices if indices > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		print("MODEL ", kind, " triangles=", triangles)
		check(triangles <= 5000, "model triangle budget " + kind)
		visual.free()
	print("HEIGHT / MODEL failures=", failures)
	quit(1 if failures else 0)
