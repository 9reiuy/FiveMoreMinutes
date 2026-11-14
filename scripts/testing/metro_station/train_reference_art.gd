extends RefCounted
## Instance-only industrial trim shared by the station and playable consist.
## Roof parts inherit the existing cutaway; leaf trim inherits the sliding doors.

const D := preload("res://scripts/testing/metro_station/metro_dimensions.gd")
const BODY_PIECE := &"train_reference_body_piece"
var _finishes: Dictionary = {}
var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _detail_maps_loaded := false
var _dark := _metal("Reference_DarkSteel", Color("282c34"), .91, .08)
var _edge := _metal("Reference_EdgeSteel", Color("7b818b"), .79, .18)
var _bronze := _metal("Reference_BronzeRib", Color("71665b"), .88, .20)
var _door_steel := _metal("Reference_DoorBrushedSteel", Color("727b88"), .78, .28)
var _sheet := _metal("PBR_InteriorCoatedPanels", Color("707985"), .88, .10)
var _rubber := _matte_rubber()
var _red := _lamp("Reference_RedSignal", Color("f70819"), 3.0)
var _white := _lamp("Reference_WorkLamp", Color("e1e6ed"), 2.0)


func apply_train(train: Node3D) -> void:
	for index in D.CAR_COUNT:
		apply_car(train.get_node("Carriage_%02d" % (index + 1)), index)
	for index in D.CAR_COUNT - 1:
		dress_connector(train.get_node("Gangway_%02d" % (index + 1)))


func apply_car(car: Node3D, index: int) -> void:
	if car.has_meta(&"train_reference_art"): return
	car.set_meta(&"train_reference_art", true)
	_detail_maps(car)
	for visual: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		var is_door := visual.name == &"GlazedSlidingLeaf"
		_tint_mesh(visual, is_door)
	_hull(car)
	_end_bulkheads(car)
	_roof(car.get_node(^"Roof"))
	for child in car.get_children():
		if child.has_meta(&"slide") and child.has_node(^"GlazedSlidingLeaf"):
			_door(child)
		if child is OmniLight3D:
			child.light_color = Color("d7dce5")
	for x: float in [-6.72, 6.72]:
		var light := OmniLight3D.new()
		light.name = "ReferenceRedSpill_%s" % ("Rear" if x < 0.0 else "Front")
		light.position = Vector3(x, 1.12, 0.0)
		light.light_color = Color("ed3343")
		light.light_energy = .48
		light.omni_range = 2.25
		light.omni_attenuation = 1.6
		light.light_specular = .15
		light.light_volumetric_fog_energy = 0.0
		light.light_cull_mask = 2 | 8
		light.shadow_enabled = false
		car.add_child(light)
		for side: float in [-1.0, 1.0]:
			var work := OmniLight3D.new()
			work.name = "ReferenceDoorWork_%d_%d" % [int(x), int(side)]
			work.position = Vector3(x, 1.62, side * 1.62)
			work.light_color = Color("dce1e8")
			work.light_energy = .85
			work.omni_range = 2.0
			work.omni_attenuation = 1.6
			work.light_specular = .22
			work.light_volumetric_fog_energy = 0.0
			work.light_cull_mask = 2 | 8
			work.shadow_enabled = false
			car.add_child(work)
	car.set_meta(&"train_reference_index", index)


func bind_cutout(car: Node3D, cutout: RefCounted) -> void:
	for mesh: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_meta(BODY_PIECE, false):
			cutout.register_mesh(mesh, true, true)


func dress_interior(car: Node3D) -> void:
	for path: NodePath in [^"Body/WindowWall", ^"NearWall/WindowWall"]:
		var wall: Node3D = car.get_node(path)
		for panel: Node in wall.get_children():
			if not panel is MeshInstance3D or not str(panel.name).begins_with("SolidMiddleBody_"): continue
			if panel.has_node(^"ReferenceInfillPanels"): continue
			var bounds: AABB = panel.mesh.get_aabb()
			var side := -signf(panel.position.z)
			var width := bounds.size.x - .10
			_begin()
			# Two pressed sections and a recessed horizontal joint replace the flat read.
			_panel_ring(Vector2(0.0, .265), Vector2(width, .86), Vector2(width - .11, .75),
				.070, .052, side, _edge, _sheet, .050)
			_panel_ring(Vector2(0.0, -.455), Vector2(width, .49), Vector2(width - .11, .38),
				.070, .052, side, _edge, _sheet, .050)
			_box(Vector3(width, .026, .018), Vector3(0.0, -.19, side * .060), _dark)
			for x: float in [-1.0, 1.0]:
				for y: float in [-.64, .635]:
					_disc(Vector3(x * (width * .5 - .035), y, side * .072), .017, side, _dark, 6)
			_commit(panel, "ReferenceInfillPanels", true)


func dress_connector(gangway: Node3D, cutout: RefCounted = null) -> void:
	if gangway.get_meta(&"train_reference_connector", false): return
	gangway.set_meta(&"train_reference_connector", true)
	var visual: MeshInstance3D = gangway.get_node(^"ArticulatedGangway")
	var original := visual.mesh
	var replacement := ArrayMesh.new()
	for surface in original.get_surface_count():
		var material := original.surface_get_material(surface)
		# Replace the flat rubber walls/roof together, keeping the original floor.
		if material.resource_name == "RecessAndRubber": continue
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, original.surface_get_arrays(surface))
		replacement.surface_set_material(replacement.get_surface_count() - 1, material)
	visual.mesh = replacement
	_begin()
	_connector_bellows()
	# Only the two attachment flanges are rigid metal; the span is flexible rubber.
	for x: float in [-.337, .337]:
		_connector_flange(x)
	_commit(gangway, "ReferenceConnectorShell", true)
	if cutout != null: cutout.register_mesh(gangway.get_node(^"ReferenceConnectorShell"), true, true)


func _connector_profile(amount: float) -> PackedVector2Array:
	# Cross-section coordinates are (z, y), open at the floor. The inside
	# retains the original 1.08 m passage and 2.58 m central head clearance.
	var width := .640 + amount * .075
	var shoulder := 2.510 + amount * .060
	var top := 2.630 + amount * .085
	return PackedVector2Array([Vector2(-width, .12), Vector2(-width, shoulder),
		Vector2(-.54, top), Vector2(.54, top), Vector2(width, shoulder), Vector2(width, .12)])


func _connector_inside() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-.54, .12), Vector2(-.54, 2.50),
		Vector2(-.46, 2.58), Vector2(.46, 2.58), Vector2(.54, 2.50), Vector2(.54, .12)])


func _connector_point(x: float, point: Vector2) -> Vector3:
	return Vector3(x, point.y, point.x)


func _connector_bellows() -> void:
	var rings: Array[Dictionary] = []
	# Five broad convolutions run along the train axis, wrapping across the roof
	# and down both sides. Rounded shoulders soften the low-poly fold peaks.
	for fold in 5:
		for section: Vector2 in [Vector2(0.0, 0.0), Vector2(.32, .92), Vector2(.5, 1.0), Vector2(.68, .92)]:
			rings.append({"x":lerpf(-.326, .326, (float(fold) + section.x) / 5.0), "profile":_connector_profile(section.y)})
	rings.append({"x":.326, "profile":_connector_profile(0.0)})
	var inside := _connector_inside()
	for index in rings.size() - 1:
		var a: Dictionary = rings[index]
		var b: Dictionary = rings[index + 1]
		for part in 5:
			_quad(_connector_point(a.x, a.profile[part + 1]), _connector_point(b.x, b.profile[part + 1]),
				_connector_point(b.x, b.profile[part]), _connector_point(a.x, a.profile[part]), _rubber)
		for edge in [0, 5]:
			var p0 := _connector_point(a.x, a.profile[edge])
			var p1 := _connector_point(b.x, b.profile[edge])
			var p2 := _connector_point(b.x, inside[edge])
			var p3 := _connector_point(a.x, inside[edge])
			if edge == 0: _quad(p0, p1, p2, p3, _rubber)
			else: _quad(p3, p2, p1, p0, _rubber)
	for part in 5:
		_quad(_connector_point(-.326, inside[part]), _connector_point(.326, inside[part]),
			_connector_point(.326, inside[part + 1]), _connector_point(-.326, inside[part + 1]), _rubber)
	for index in [0, rings.size() - 1]:
		var ring: Dictionary = rings[index]
		for part in 5:
			var a := _connector_point(ring.x, ring.profile[part])
			var b := _connector_point(ring.x, ring.profile[part + 1])
			var c := _connector_point(ring.x, inside[part + 1])
			var d := _connector_point(ring.x, inside[part])
			if index == 0: _quad(d, c, b, a, _rubber)
			else: _quad(a, b, c, d, _rubber)


func _connector_flange(x: float) -> void:
	var outside := _connector_profile(1.0)
	var inside := _connector_inside()
	var low := x - .014
	var high := x + .014
	for part in 5:
		_quad(_connector_point(low, outside[part + 1]), _connector_point(high, outside[part + 1]),
			_connector_point(high, outside[part]), _connector_point(low, outside[part]), _edge)
		_quad(_connector_point(low, inside[part]), _connector_point(high, inside[part]),
			_connector_point(high, inside[part + 1]), _connector_point(low, inside[part + 1]), _edge)
		_quad(_connector_point(low, inside[part]), _connector_point(low, inside[part + 1]),
			_connector_point(low, outside[part + 1]), _connector_point(low, outside[part]), _edge)
		_quad(_connector_point(high, outside[part]), _connector_point(high, outside[part + 1]),
			_connector_point(high, inside[part + 1]), _connector_point(high, inside[part]), _edge)
	for edge in [0, 5]:
		var a := _connector_point(low, outside[edge])
		var b := _connector_point(high, outside[edge])
		var c := _connector_point(high, inside[edge])
		var d := _connector_point(low, inside[edge])
		if edge == 0: _quad(a, b, c, d, _edge)
		else: _quad(d, c, b, a, _edge)


func _end_bulkheads(car: Node3D) -> void:
	for end: float in [-1.0, 1.0]:
		var frame := Node3D.new()
		frame.name = "ReferenceEndBulkhead_Rear" if end < 0.0 else "ReferenceEndBulkhead_Front"
		frame.position.x = end * 8.94
		frame.rotation.y = -end * PI * .5
		car.add_child(frame)
		_begin()
		for side: float in [-1.0, 1.0]:
			_panel_ring(Vector2(side * 1.005, 1.37), Vector2(.59, 1.91), Vector2(.49, 1.80),
				.045, .014, 1.0, _edge, _sheet, .002)
			_box(Vector3(.70, .028, .025), Vector3(side * 1.015, .87, .042), _dark)
			_box(Vector3(.025, 1.98, .035), Vector3(side * .675, 1.37, .025), _dark)
		_commit(frame, "ReferenceBulkheadPanels", true)


func apply_gangway(frame: Node3D, leaves: Array[Node3D], cutout: RefCounted) -> void:
	for leaf in leaves:
		_door(leaf, signf(leaf.position.x))
		var trim: MeshInstance3D = leaf.get_node(^"ReferenceLeafTrim")
		trim.scale.x = (leaf.get_node(^"GlazedSlidingLeaf") as MeshInstance3D).scale.x
		cutout.register_mesh(trim, true, true)
	_begin()
	for side: float in [-1.0, 1.0]:
		_panel_ring(Vector2(0.0, 1.325), Vector2(1.30, 2.41), Vector2(1.11, 2.29),
			.11, .042, side, _dark, null, .015)
	_commit(frame, "ReferenceGangwaySurround", true)
	cutout.register_mesh(frame.get_node(^"ReferenceGangwaySurround"), true, true)


func _tint_mesh(visual: MeshInstance3D, door: bool) -> void:
	var original := visual.mesh
	if original == null: return
	var key := "%d_%s" % [original.get_instance_id(), door]
	if _meshes.has(key):
		visual.mesh = _meshes[key]
		return
	var replacement := original.duplicate() as ArrayMesh
	if replacement == null: return
	for surface in replacement.get_surface_count():
		var source := original.surface_get_material(surface) as StandardMaterial3D
		if source != null: replacement.surface_set_material(surface, _finish(source, door))
	_meshes[key] = replacement
	visual.mesh = replacement


func _finish(source: StandardMaterial3D, door: bool) -> Material:
	var name: String = source.resource_name
	var color: Color
	var metal := .10
	var rough := .91
	match name:
		"PBR_StainlessMetroBody": color = Color("59616e")
		"PBR_BrushedStainlessRoof": color = Color("58616c"); metal = .14
		"PBR_LowerStainlessCarriage": color = Color("444b57"); metal = .18
		"PBR_InteriorCoatedPanels": color = Color("626d7c") if door else Color("787f8b")
		"PBR_PaintedStructuralSteel": color = Color("353d48")
		"SmokedMetroGlass":
			color = Color("353b47"); color.a = source.albedo_color.a
			metal = source.metallic; rough = source.roughness
		"PBR_BrushedRailSteel":
			if not door: return source
			color = Color("7b828d"); metal = .18; rough = .84
		_: return source
	var key := "%d_%s" % [source.get_instance_id(), door]
	if _finishes.has(key): return _finishes[key]
	var material := source.duplicate() as StandardMaterial3D
	# Keep the original material identity and UV/maps for window shaping and wear.
	material.resource_name = name
	material.albedo_color = color
	material.metallic = metal
	material.metallic_specular = .24
	material.roughness = rough
	_finishes[key] = material
	return material


func _detail_maps(car: Node3D) -> void:
	if _detail_maps_loaded: return
	var roof: MeshInstance3D = car.get_node(^"Roof/RoofAndCeiling")
	for surface in roof.mesh.get_surface_count():
		var source := roof.mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null or source.resource_name != "PBR_BrushedStainlessRoof": continue
		for material: StandardMaterial3D in [_dark, _edge, _bronze, _sheet]:
			material.albedo_texture = source.albedo_texture
			material.normal_texture = source.normal_texture
			material.normal_enabled = source.normal_enabled
			material.normal_scale = source.normal_scale * .65
			material.roughness_texture = source.roughness_texture
			material.roughness_texture_channel = source.roughness_texture_channel
	var door: MeshInstance3D = car.get_node(^"Door_1_58_1/GlazedSlidingLeaf")
	for surface in door.mesh.get_surface_count():
		var source := door.mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null or source.resource_name != "PBR_BrushedRailSteel": continue
		_door_steel.albedo_texture = source.albedo_texture
		_door_steel.normal_texture = source.normal_texture
		_door_steel.normal_enabled = source.normal_enabled
		_door_steel.normal_scale = source.normal_scale * 1.15
		_door_steel.roughness_texture = source.roughness_texture
		_door_steel.roughness_texture_channel = source.roughness_texture_channel
	for visual: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		for surface in visual.mesh.get_surface_count():
			var source := visual.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null or source.resource_name != "PBR_DarkMechanicalRubber": continue
			# The wheel's baked-dark colour map hides the folds. Use neutral rubber
			# albedo with the original low-strength micro-normal, without metal gloss.
			_rubber.normal_texture = source.normal_texture
			_rubber.normal_enabled = source.normal_enabled
			_rubber.normal_scale = source.normal_scale * .35
	_detail_maps_loaded = true


func _hull(car: Node3D) -> void:
	_begin()
	for side: float in [-1.0, 1.0]:
		var z := side * 1.493
		# Stop each belt at the door openings rather than drawing across moving leaves.
		for span: Vector2 in [Vector2(-8.86, -6.55), Vector2(-5.05, 5.05), Vector2(6.55, 8.86)]:
			for y: float in [.31, .43, .55]:
				_box(Vector3(span.y - span.x, .035, .034), Vector3((span.x + span.y) * .5, y, z), _bronze)
			_box(Vector3(span.y - span.x, .045, .035), Vector3((span.x + span.y) * .5, .94, z), _edge)
		for x: float in [-3.88, 3.88]:
			_box(Vector3(.82, .28, .040), Vector3(x, .75, z), _dark)
			_box(Vector3(.65, .018, .047), Vector3(x, .865, z + side * .007), _edge)
			for offset: float in [-.34, .34]:
				_disc(Vector3(x + offset, .75, z + side * .025), .022, side, _edge, 6)
		# Slatted lower intake, kept below the existing firing windows.
		for y: float in [.66, .72, .78, .84]:
			_box(Vector3(1.9, .027, .045), Vector3(0.0, y, z), _dark)
		for x: float in [-6.72, 6.72]:
			_box(Vector3(.235, .61, .047), Vector3(x, 1.13, z), _dark)
			for y: float in [1.02, 1.25]:
				_disc(Vector3(x, y, z + side * .029), .083, side, _edge, 8)
				_disc(Vector3(x, y, z + side * .035), .061, side, _red, 8)
			_box(Vector3(.28, .105, .082), Vector3(x, 1.62, z), _dark)
			_box(Vector3(.20, .035, .087), Vector3(x, 1.62, z + side * .006), _white)
		for x: float in D.DOOR_CENTERS:
			# Fixed jamb and overhead running track leave the original opening free.
			_panel_ring(Vector2(x, 1.325), Vector2(1.62, 2.41), Vector2(1.41, 2.29),
				1.55, 1.493, side, _dark, null, 1.47)
			_box(Vector3(1.54, .06, .095), Vector3(x, 2.495, side * 1.51), _edge)
			_box(Vector3(1.32, .025, .10), Vector3(x, 2.46, side * 1.512), _dark)
		# Low running-gear housings add silhouette without adding collision.
		for x: float in [-6.70, 6.70]:
			_box(Vector3(1.30, .19, .07), Vector3(x, -.26, side * 1.20), _dark)
	_commit(car, "ReferenceHullTrim", true)


func _door(leaf: Node3D, slide_direction := 0.0) -> void:
	_begin()
	# Siblings of GlazedSlidingLeaf: gangway templates do not duplicate this trim.
	var slide := float(leaf.get_meta(&"slide", 1.0)) if is_zero_approx(slide_direction) else slide_direction
	var closing_edge := -signf(slide)
	# Folded stiles give the leaf real thickness from the high gameplay camera.
	for x: float in [-.322, .322]:
		_box(Vector3(.033, 2.32, .104), Vector3(x, 1.325, 0.0), _door_steel)
	_box(Vector3(.024, 2.33, .113), Vector3(closing_edge * .344, 1.325, 0.0), _dark)
	for side: float in [-1.0, 1.0]:
		# Metal bevel, then a dark gasket around the original recessed glass.
		_panel_ring(Vector2(0.0, 1.57), Vector2(.644, 1.17), Vector2(.572, 1.086), .083, .048, side, _door_steel, null, .035)
		_panel_ring(Vector2(0.0, 1.57), Vector2(.572, 1.086), Vector2(.56, 1.06), .049, .039, side, _dark)
		# Pressed lower service panel: the broad face sits behind its chamfered rim.
		_panel_ring(Vector2(0.0, .635), Vector2(.582, .67), Vector2(.49, .565), .078, .044, side, _door_steel, _door_steel, .035)
		_panel_ring(Vector2(0.0, 2.30), Vector2(.565, .205), Vector2(.49, .135), .071, .043, side, _door_steel, _dark, .035)
		_box(Vector3(.59, .12, .025), Vector3(0.0, .215, side * .0475), _door_steel)
		var handle_x := closing_edge * .205
		for y: float in [.70, .91]:
			_box(Vector3(.065, .045, .068), Vector3(handle_x, y, side * .083), _dark)
		_box(Vector3(.035, .25, .028), Vector3(handle_x, .805, side * .127), _door_steel)
		for x: float in [-.265, .265]:
			for y: float in [.33, .94]:
				_disc(Vector3(x, y, side * .065), .016, side, _dark, 6)
	_commit(leaf, "ReferenceLeafTrim", true)


func _roof(roof: Node3D) -> void:
	_begin()
	var source := roof.get_node(^"RoofAndCeiling") as MeshInstance3D
	for x: float in [-4.15, 0.0, 4.15]:
		var y := _roof_y(source, x, 0.0)
		_beveled(Vector3(2.75, .10, 1.18), Vector3(x, y + .035, 0.0), .09, _dark)
		_box(Vector3(2.40, .018, .025), Vector3(x, y + .092, -.47), _edge)
		for end: float in [-1.0, 1.0]:
			_box(Vector3(.13, .028, .045), Vector3(x + end * 1.12, y + .095, .45), _bronze)
	for x: float in [-6.65, 6.65]:
		var y := _roof_y(source, x, 0.0)
		_beveled(Vector3(1.35, .15, .95), Vector3(x, y + .06, 0.0), .08, _dark)
		for offset: float in [-.36, -.12, .12, .36]:
			_box(Vector3(.035, .018, .71), Vector3(x + offset, y + .146, 0.0), _edge)
	for side: float in [-1.0, 1.0]:
		var z := side * .96
		_box(Vector3(15.9, .065, .075), Vector3(0.0, _roof_y(source, 0.0, z) + .045, z), _dark)
	_commit(roof, "ReferenceRoofEquipment", false)


func _roof_y(source: MeshInstance3D, x: float, z: float) -> float:
	var faces := source.mesh.get_faces()
	var top := 2.85
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(x, 4.2, z), Vector3(x, 2.8, z),
			faces[index], faces[index + 1], faces[index + 2])
		if hit is Vector3: top = maxf(top, hit.y)
	return top


static func _metal(name: String, color: Color, roughness: float, metal: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metal
	material.metallic_specular = .24
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	return material


static func _matte_rubber() -> StandardMaterial3D:
	var material := _metal("RecessAndRubber", Color("3c3f46"), .98, 0.0)
	material.metallic_specular = .08
	return material


static func _lamp(name: String, color: Color, energy: float) -> StandardMaterial3D:
	var material := _metal(name, color, .78, .05)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _begin() -> void:
	_batches = {}


func _triangle(a: Vector3, b: Vector3, c: Vector3, material: Material) -> void:
	if not _batches.has(material):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		_batches[material] = surface
	var surface: SurfaceTool = _batches[material]
	var normal := (b - a).cross(c - a).normalized()
	# Godot front faces wind clockwise when seen from outside.
	for vertex: Vector3 in [a, c, b]:
		surface.set_normal(normal)
		var uv := Vector2(vertex.x, vertex.y) if absf(normal.z) > .5 else Vector2(vertex.x, vertex.z)
		if absf(normal.x) > .5: uv = Vector2(vertex.z, vertex.y)
		surface.set_uv(uv * .5)
		surface.add_vertex(vertex)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, material: Material) -> void:
	_triangle(a, b, c, material)
	_triangle(a, c, d, material)


func _box(size: Vector3, at: Vector3, material: Material) -> void:
	var h := size * .5
	for axis in 3:
		var u := Vector3.ZERO; u[(axis + 1) % 3] = h[(axis + 1) % 3]
		var v := Vector3.ZERO; v[(axis + 2) % 3] = h[(axis + 2) % 3]
		for sign_: float in [-1.0, 1.0]:
			var center := at; center[axis] += sign_ * h[axis]
			_quad(center - u - v * sign_, center + u - v * sign_,
				center + u + v * sign_, center - u + v * sign_, material)


func _disc(at: Vector3, radius: float, side: float, material: Material, count: int) -> void:
	for index in count:
		var a := float(index) * TAU / count
		var b := float(index + 1) * TAU / count
		_triangle(at, at + Vector3(cos(a), sin(a) * side, 0.0) * radius,
			at + Vector3(cos(b), sin(b) * side, 0.0) * radius, material)


func _panel_ring(at: Vector2, outer: Vector2, inner: Vector2, outside_depth: float,
		inside_depth: float, side: float, material: Material, cap: Material = null, back_depth := -1.0) -> void:
	var outside: Array[Vector3] = []
	var inside: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		var a := at + corner * outer * .5
		var b := at + corner * inner * .5
		outside.append(Vector3(a.x, a.y, outside_depth * side))
		inside.append(Vector3(b.x, b.y, inside_depth * side))
	for index in 4:
		var next := (index + 1) % 4
		if side > 0.0: _quad(outside[index], outside[next], inside[next], inside[index], material)
		else: _quad(outside[next], outside[index], inside[index], inside[next], material)
		if back_depth >= 0.0:
			var a := outside[index]; a.z = back_depth * side
			var b := outside[next]; b.z = back_depth * side
			if side > 0.0: _quad(a, b, outside[next], outside[index], material)
			else: _quad(b, a, outside[index], outside[next], material)
	if cap != null:
		if side > 0.0: _quad(inside[0], inside[1], inside[2], inside[3], cap)
		else: _quad(inside[1], inside[0], inside[3], inside[2], cap)


func _beveled(size: Vector3, at: Vector3, bevel: float, material: Material) -> void:
	var h := size * .5
	var ring: Array[Vector2] = [Vector2(-h.x + bevel, -h.z), Vector2(h.x - bevel, -h.z),
		Vector2(h.x, -h.z + bevel), Vector2(h.x, h.z - bevel), Vector2(h.x - bevel, h.z),
		Vector2(-h.x + bevel, h.z), Vector2(-h.x, h.z - bevel), Vector2(-h.x, -h.z + bevel)]
	for index in ring.size():
		var a := at + Vector3(ring[index].x, -h.y, ring[index].y)
		var b := at + Vector3(ring[(index + 1) % ring.size()].x, -h.y, ring[(index + 1) % ring.size()].y)
		var c := b + Vector3.UP * size.y
		var d := a + Vector3.UP * size.y
		_quad(a, d, c, b, material)
		_triangle(at + Vector3.UP * h.y, c, d, material)


func _commit(parent: Node3D, name: String, cutout: bool) -> void:
	var mesh := ArrayMesh.new()
	for material: Material in _batches:
		var surface: SurfaceTool = _batches[material]
		surface.index()
		surface.generate_tangents()
		surface.commit(mesh)
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = mesh
	visual.layers = 2 | 8
	visual.set_meta(BODY_PIECE, cutout)
	visual.set_meta(&"fixture_optics_decorative", true)
	parent.add_child(visual)
	_batches = {}
