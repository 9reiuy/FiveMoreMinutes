extends SceneTree
const ART := preload("res://scripts/testing/metro_station/train_reference_art.gd")
const ASSET := preload("res://art/Dream/MetroStation/LowerHarbor.scn")
const CONSIST := preload("res://scripts/testing/metro_station/train_chapter_consist.gd")
const CUTOUT := preload("res://scripts/dream/authored_occlusion_cutout.gd")
const CLIP := preload("res://scripts/testing/metro_station/metro_station_clip.gd")
var output: String
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures.append(title); print("FAIL ", title)
func solids(node: Node) -> Array:
	var result: Array = []
	for shape: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
		result.append([str(node.get_path_to(shape)), str(shape.transform), str(shape.shape.get_debug_mesh().get_aabb())])
	return result
func two_d_solids(node: Node) -> Array:
	var result: Array = []
	for body: StaticBody2D in node.find_children("*", "StaticBody2D", true, false):
		var shapes: Array = []
		for shape in body.get_children():
			if shape is CollisionShape2D: shapes.append([str(shape.transform),str(shape.shape.size) if shape.shape is RectangleShape2D else str(shape.shape.get_rect())])
		result.append([str(body.position),body.collision_layer,body.collision_mask,shapes])
	return result
func connector_roof_heights(mesh: Mesh) -> Array[float]:
	var heights: Array[float] = []
	var faces := mesh.get_faces()
	for sample_index in 51:
		var x := lerpf(-.326,.326,float(sample_index)/50.0)
		var height := 0.0
		for index in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(x,3.0,0),Vector3(x,2.57,0),faces[index],faces[index+1],faces[index+2])
			if hit is Vector3: height = maxf(height,hit.y)
		heights.append(height)
	return heights
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		elif arg.begins_with("--artifact-dir="): output = arg.trim_prefix("--artifact-dir=")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://.runtime/train_reference_art_validation")
	DirAccess.make_dir_recursive_absolute(output)
	var original: Node3D = ASSET.instantiate()
	var styled: Node3D = ASSET.instantiate()
	var original_train: Node3D = original.get_node(^"MetroTrain")
	var train: Node3D = styled.get_node(^"MetroTrain")
	var before := solids(train)
	var reference := ART.new()
	reference.apply_train(train)
	check(before == solids(train), "Imported collision, doors and bridges unchanged")
	var triangles := 0
	for i in 6:
		var car: Node3D = train.get_node("Carriage_%02d" % (i + 1))
		var prior: Node3D = original_train.get_node("Carriage_%02d" % (i + 1))
		check(car.get_node(^"Roof/ReferenceRoofEquipment") != null, "Roof equipment on car %d" % i)
		var leaves := 0
		for node in car.get_children():
			if node.has_meta(&"slide") and node.has_node(^"GlazedSlidingLeaf"):
				leaves += 1
				check(node.has_node(^"ReferenceLeafTrim"), "Leaf trim on car %d" % i)
				check(not node.get_node(^"GlazedSlidingLeaf").has_node(^"ReferenceLeafTrim"), "Gangway template remains independent")
		check(leaves == 8, "Eight original sliding leaves per car")
		for mesh: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name).begins_with("Reference"):
				check(mesh.mesh != null, "New trim has geometry")
				for surface in mesh.mesh.get_surface_count():
					var arrays := mesh.mesh.surface_get_arrays(surface)
					check(not arrays[Mesh.ARRAY_INDEX].is_empty(), "Indexed trim supports station slicing")
					if i == 0: triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			else:
				var old: MeshInstance3D = prior.get_node(car.get_path_to(mesh))
				check(mesh.mesh.get_aabb().is_equal_approx(old.mesh.get_aabb()), "Original silhouette is preserved")
				for surface in mesh.mesh.get_surface_count():
					var a := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
					var b := old.mesh.surface_get_material(surface) as BaseMaterial3D
					check(a.resource_name == b.resource_name, "Material identity retained")
					check(a.albedo_texture == b.albedo_texture and a.normal_texture == b.normal_texture and a.roughness_texture == b.roughness_texture, "Existing PBR maps retained")
					if a.resource_name == "SmokedMetroGlass":
						check(is_equal_approx(a.albedo_color.a,b.albedo_color.a) and a.transparency == b.transparency, "Smoke-grey glass keeps original transparency")
		var count := car.find_children("Reference*", "MeshInstance3D", true, false).size()
		reference.apply_car(car, i)
		check(count == car.find_children("Reference*", "MeshInstance3D", true, false).size(), "Art application is idempotent")
		var neutral := true
		for mesh: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material != null and material.resource_name in ["PBR_StainlessMetroBody", "PBR_BrushedStainlessRoof", "PBR_LowerStainlessCarriage", "PBR_InteriorCoatedPanels", "PBR_PaintedStructuralSteel", "SmokedMetroGlass"]:
					neutral = neutral and material.albedo_color.b >= material.albedo_color.g
		check(neutral, "Body and panels use cool neutral base colours")
		var work_neutral := true
		for light: Light3D in car.find_children("*", "Light3D", true, false):
			if not str(light.name).begins_with("ReferenceRedSpill"):
				work_neutral = work_neutral and light.light_color.b >= light.light_color.g
		check(work_neutral, "Interior and work lights carry no green bias")
	report["added_triangles_per_car"] = triangles
	original.free()
	root.add_child(styled)
	var slicer := CLIP.new(train)
	for x: float in [0.0, 1.1, 20.6, 48.8, -31.4]:
		train.position.x = x
		slicer.update(true, -24.0, 24.0)
		var trim_visible := 0
		for entry: Dictionary in slicer.entries:
			var node: MeshInstance3D = entry.node
			check(node.layers == entry.layers, "Station slicing keeps fixed render layers")
			if node.mesh == null: continue
			var bounds: AABB = node.global_transform * node.mesh.get_aabb()
			check(bounds.position.x >= -24.001 and bounds.end.x <= 24.001, "Continuous station-boundary clipping includes trim")
			if str(node.name).begins_with("Reference"): trim_visible += 1
		check(trim_visible > 0, "Trim remains visible inside station")
	slicer.update(false, -24.0, 24.0)
	check(solids(train) == before, "Clipping does not alter source collision")
	styled.free()
	# Both production collision builds must match with and without the art.
	var hosts: Array[Node3D] = []
	var collisions: Array[Node2D] = []
	var consists: Array = []
	for enabled: bool in [false, true]:
		var host := Node3D.new(); root.add_child(host)
		host.set_meta(&"train_reference_art_enabled", enabled)
		var collision := Node2D.new(); root.add_child(collision)
		var cutout := CUTOUT.new()
		var player := CONSIST.new(host, cutout, false)
		player.install_collision(collision, Vector2.ZERO, 32.0, false)
		var rival := CONSIST.new(host, cutout, true)
		rival.install_collision(collision, Vector2.ZERO, 32.0, true)
		hosts.append(host); collisions.append(collision); consists.append([player, rival])
	check(two_d_solids(collisions[0]) == two_d_solids(collisions[1]), "0-6 all player/rival collision remains identical")
	for i in 6:
		var car: Node3D = consists[1][0]._car(i)
		check(car.find_children("ReferenceBulkheadPanels", "MeshInstance3D", true, false).size() == 2, "Both end bulkheads receive pressed metal panels")
		var panels := 0
		for mesh: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
			if mesh.name != &"ReferenceInfillPanels": continue
			panels += 1
			var own := mesh.get_aabb()
			var backing: AABB = mesh.get_parent().mesh.get_aabb()
			check(own.position.x >= backing.position.x and own.end.x <= backing.end.x and own.position.y >= backing.position.y and own.end.y <= backing.end.y and maxf(absf(own.position.z),absf(own.end.z)) <= .073, "Infill trim stays inside cover and leaves firing windows open")
		check(panels == 4, "All four solid infill panels receive shaped cladding")
	for consist in consists[1]:
		for i in 5:
			var connector: Node3D = consist._model.get_node("Gangway_%02d" % (i + 1))
			var shell: MeshInstance3D = connector.get_node(^"ReferenceConnectorShell")
			check(shell.get_aabb().end.y <= 2.721 and shell.get_aabb().position.z >= -.721 and shell.get_aabb().end.z <= .721 and maxf(absf(shell.get_aabb().position.x),absf(shell.get_aabb().end.x)) <= .361, "Rubber connector preserves the original clearance and footprint")
			var matte_rubber := false
			var ends_only := true
			var roof_outside := true
			for surface in shell.mesh.get_surface_count():
				var material := shell.mesh.surface_get_material(surface) as StandardMaterial3D
				var arrays := shell.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				if material.resource_name == "RecessAndRubber":
					matte_rubber = material.metallic == 0.0 and material.roughness >= .95 and material.metallic_specular <= .12 and material.roughness_texture == null and material.normal_texture != null
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					for at in range(0,indices.size(),3):
						if minf(points[indices[at]].y,minf(points[indices[at+1]].y,points[indices[at+2]].y)) > 2.62:
							roof_outside = roof_outside and normals[indices[at]].y > .1
				elif material.resource_name == "Reference_EdgeSteel":
					for point in points: ends_only = ends_only and absf(point.x) >= .322 and absf(point.x) <= .352
				else: ends_only = false
			check(matte_rubber,"Connector span is matte rubber with no metallic reflection")
			check(ends_only,"Rigid metal is confined to the two end flanges")
			check(roof_outside,"Bellows roof normals face outward for real lighting")
			if i == 0:
				var heights := connector_roof_heights(shell.mesh)
				var peaks := 0
				for at in range(1,heights.size()-1):
					if heights[at] > heights[at-1]+.0001 and heights[at] > heights[at+1]+.0001: peaks += 1
				check(peaks == 5 and heights.max()-heights.min() > .06,"Five real roof convolutions replace the flat connector lid")
	# The new shell must inherit the existing bogie-driven connector transforms.
	for advance: float in [0.0,3.0,9.0,15.0]:
		for side in 2:
			consists[0][side].follow_turnout(CONSIST.center(2),advance,0.0)
			consists[1][side].follow_turnout(CONSIST.center(2),advance,0.0)
			for i in 5:
				var before_connector: Node3D = consists[0][side]._model.get_node("Gangway_%02d" % (i+1))
				var after_connector: Node3D = consists[1][side]._model.get_node("Gangway_%02d" % (i+1))
				var shell: Node3D = after_connector.get_node(^"ReferenceConnectorShell")
				check(before_connector.transform.is_equal_approx(after_connector.transform),"Rubber connector retains original turn and stretch motion")
				check(shell.global_transform.is_equal_approx(after_connector.global_transform),"Bellows follows the moving connector without detaching")
	for gate: Dictionary in consists[1][0].car_gates:
		for leaf: Node3D in gate.leaves:
			check(leaf.has_node(^"ReferenceLeafTrim"), "0-6 gangway leaves receive the same door structure")
		var first: Node3D = gate.leaves[0]
		var trim: Node3D = first.get_node(^"ReferenceLeafTrim")
		var before_open := trim.global_position
		check(CONSIST.open_gate(gate, .68), "Styled gangway gate opens through the original controller")
		check(trim.global_position.distance_to(before_open) > .55, "Gangway trim follows the original opening travel")
	await process_frame
	await process_frame
	for consist in consists[1]:
		check(consist.reference_art != null, "Both 0-6 trains receive art")
		consist.set_cutaway(true)
		check(not consist._car(2).get_node(^"Roof/ReferenceRoofEquipment").is_visible_in_tree(), "Roof extras follow combat cutaway")
		consist.set_cutaway(false)
		check(consist._car(2).get_node(^"Roof/ReferenceRoofEquipment").is_visible_in_tree(), "Roof extras restore outside cutaway")
		var leaf: Node3D = consist._car(2).get_node(^"Door_1_58_1")
		var trim: Node3D = leaf.get_node(^"ReferenceLeafTrim")
		var before_trim := trim.global_position
		var expected_slide := leaf.get_parent_node_3d().global_basis.x * .8
		leaf.position.x += .8
		check((trim.global_position - before_trim).is_equal_approx(expected_slide), "Door trim follows real sliding leaf, including a turned carriage")
		var wreck := Node3D.new(); hosts[1].add_child(wreck)
		var detached: Node3D = consist.detach_tail_car(5, wreck)
		check(detached.find_children("ReferenceHullTrim", "MeshInstance3D", true, false).size() == 1, "Trim follows detached wreck")
		for light: Light3D in detached.find_children("*", "Light3D", true, false):
			check(not light.visible, "Detached lamps follow existing light shutdown")
	for i in hosts.size():
		hosts[i].free();collisions[i].free()
	consists.clear()
	await process_frame
	await process_frame
	report.merge({"checks":checks,"failures":failures,"audio":AudioServer.get_driver_name(),"scope":"Six-car asset, continuous clipping, player/rival geometry and collision, door/cutaway/wreck lifecycle"})
	FileAccess.open(output + "/result.json", FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TRAIN_ART_VERIFY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
