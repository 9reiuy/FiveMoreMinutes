extends SceneTree
const VOID = preload("res://scripts/dream/interior_void_geometry.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func ring() -> Dictionary:
	var cells: Dictionary = {}
	for y in range(9):
		for x in range(9):
			if x < 2 or x > 6 or y < 2 or y > 6: cells[Vector2i(x, y)] = true
	return cells
func run() -> void:
	create_timer(90,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag := root.get_node_or_null("_DroneGameDiag")
	if diag != null: diag.free()
	var cells := ring()
	var original := cells.duplicate(true)
	var rect := Rect2i(-2,-2,13,13)
	var enclosed := VOID.enclosed_cells(cells,rect)
	check(enclosed.size()==25,"Only enclosed 5x5 courtyard is filled")
	check(not enclosed.has(Vector2i(-1,4)),"Exterior background remains uncovered")
	var backing := VOID.build(cells,rect)
	check(backing.mesh!=null and backing.mesh.get_surface_count()==1,"Single batched opaque mesh")
	check(backing.get_child_count()==0,"No collision or per-cell nodes")
	check(backing.material_override.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"Light-independent black material")
	check(backing.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"Opaque depth-tested backing")
	var vertices: PackedVector3Array=backing.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var below := true
	for vertex in vertices: below=below and vertex.y <= 0
	check(below,"All geometry remains at or below floor and wall silhouettes")
	check(cells==original,"Visual build never mutates gameplay floor")
	backing.free()
	for y in range(5): cells.erase(Vector2i(4,y))
	check(VOID.enclosed_cells(cells,rect).is_empty(),"Open courtyard connected to exterior is not plugged")
	var world: Node=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false
	world.enable_game_start_cab_exit=false
	root.add_child(world)
	for test_seed in [42001,42002,42003]:
		check(world.regenerate(test_seed),"Formal floor generates %d" % test_seed)
		var visibility: Node=world.room_visibility
		check(visibility.outside_mask_layer==null and visibility.outside_black_gradient==null,"Formal floor has no screen overlay")
		check(visibility.interior_void_backing.get_parent()==visibility.cover_root,"Backing belongs to current floor")
		check(not visibility.view_snapshot.is_empty(),"City receives camera snapshot without mask material")
		var previous: Node=visibility.interior_void_backing
		visibility.configure(world)
		await process_frame
		check(not is_instance_valid(previous),"Rebuild retires previous backing")
		check(world.generated_root.find_children("InteriorVoidBacking","",true,false).size()==1,"Only one backing remains after rebuild")
	world.free()
	var sample: Node=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	sample.generate_on_ready=false; sample.spawn_content=false; sample.persist_profile=false
	root.add_child(sample)
	check(sample.regenerate(120),"Approved sample generates")
	await process_frame
	check(sample.room_visibility.outside_black_gradient==null,"Approved sample also has no screen overlay")
	check(is_instance_valid(sample.room_visibility.interior_void_backing),"Approved sample uses the same backing implementation")
	sample.free()
	print("INTERIOR_VOID checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
