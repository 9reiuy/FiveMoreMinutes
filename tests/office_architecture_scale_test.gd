extends SceneTree

const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const WALL = preload("res://scripts/dream/wall_segment_3d.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	check(world.regenerate(120), "runtime generates with thick walls")
	check(is_equal_approx(world.wall_thickness, world._cell_world_size() * 0.5), "wall width equals half floor cell")
	var count := 0
	for body in world.collision_root.get_children():
		if body.has_meta(&"generated_wall_edge"):
			var shape: RectangleShape2D = body.get_child(0).shape
			check(shape.size == Vector2(32, 16) or shape.size == Vector2(16, 32), "wall visual/physics thickness")
			count += 1
	check(count > 0, "tested real generated walls")
	for door in world.door_root.get_children():
		check(is_equal_approx(door.wall_thickness, .25), "door leaf quarter-cell thickness")
		for child in door.get_children():
			check(not child is MeshInstance3D, "no upper wall mesh above door")
	var wall := WALL.new()
	var mesh: ArrayMesh = wall._build_window_mesh(2.6, 0.5, 0)
	var upper_max_z := 0.0
	var lower_max_z := 0.0
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.y > 0.901:
				upper_max_z = maxf(upper_max_z, absf(vertex.z))
			elif vertex.y < 0.899:
				lower_max_z = maxf(lower_max_z, absf(vertex.z))
	check(is_equal_approx(upper_max_z, .125), "external window half thickness centred")
	check(is_equal_approx(lower_max_z, .25), "external sill full thickness")
	wall.free()
	world.queue_free()
	await process_frame
	print("ARCHITECTURE SCALE walls=", count, " failures=", failures)
	quit(1 if failures else 0)
