extends RefCounted
## The six-car Lower Harbor train, with 2D collision for the playable aisle.

const ASSETS := preload("res://art/Dream/MetroStation/LowerHarbor.scn")
const D := preload("res://scripts/testing/metro_station/metro_dimensions.gd")
const GLASS := preload("res://scripts/dream/breakable_glass_window_3d.gd")
const SLICE := preload("res://scripts/testing/metro_station/metro_station_clip.gd")
const SURFACE_WEAR := preload("res://scripts/testing/metro_station/train_surface_wear.gd")
const REFERENCE_ART := preload("res://scripts/testing/metro_station/train_reference_art.gd")
const CAR_COUNT := D.CAR_COUNT
const FIRST_CENTER := 8.5
const CABIN_EDGE := 1.40
const TRACK_GAP := 4.40
const ACTOR_EDGE := 1 << 6
const PROJECTED_BALLISTIC_WALL := 1 << 9
const WALL := 4
const DECK_OFFSET := -.12
const WINDOW_POSTS := [-8.94, -6.56, -5.04, -3.3, 0.0, 3.3, 5.04, 6.56, 8.94]
const WINDOW_SPANS := [Vector2(-8.88, -6.62), Vector2(-4.98, -3.36),
	Vector2(-3.24, -.06), Vector2(.06, 3.24), Vector2(3.36, 4.98), Vector2(6.62, 8.88)]
const MIDDLE_BODY_HALF := 3.30
const MIDDLE_WINDOW_HALF := MIDDLE_BODY_HALF * .5
const WINDOW_FRAME_HALF := .06
const MIDDLE_BODY_SPANS := [Vector2(-MIDDLE_BODY_HALF + WINDOW_FRAME_HALF, -MIDDLE_WINDOW_HALF - WINDOW_FRAME_HALF),
	Vector2(MIDDLE_WINDOW_HALF + WINDOW_FRAME_HALF, MIDDLE_BODY_HALF - WINDOW_FRAME_HALF)]
const DOOR_WIDTH := 1.40
const DOOR_DEPTH := 1.465
const BOGIE_OFFSET := 6.70
const TURN_RADIUS := 28.0
const TURN_ANGLE := .72
const TURN_ARC := TURN_RADIUS * TURN_ANGLE

var root: Node3D
var car_gates: Array[Dictionary] = []
var platform_doors: Array[Dictionary] = []
var firing_panes: Array[BreakableGlassWindow3D] = []
var _model: AnimatableBody3D
var _solids: Node2D
var _cutout: RefCounted
var _pixel_scale: float
var _collision_origin := Vector2.ZERO
var _building_car_index := 0
var _roofs: Array[Node3D] = []
var _overhead_strips: Array[Node3D] = []
var surface_wear: SURFACE_WEAR
var reference_art: REFERENCE_ART
static var _trimmed_meshes: Dictionary = {}


func _init(parent: Node3D, cutout: RefCounted, rival: bool) -> void:
	_cutout = cutout
	if parent.get_meta(&"train_reference_art_enabled", false):
		reference_art = REFERENCE_ART.new()
	root = Node3D.new()
	root.name = "RivalConsist" if rival else "PlayerConsist"
	root.position.z = TRACK_GAP if rival else 0.0
	parent.add_child(root)

	var source := ASSETS.instantiate()
	_model = source.get_node(^"MetroTrain") as AnimatableBody3D
	source.remove_child(_model)
	_model.set_script(null)
	source.free()
	_model.position = Vector3(FIRST_CENTER - D.carriage_center(0), DECK_OFFSET, 0.0)
	for collider in _model.find_children("*", "CollisionShape3D", true, false):
		collider.free()
	for animation in _model.find_children("*", "AnimationPlayer", true, false):
		animation.free()
	_model.sync_to_physics = false
	for body: AnimatableBody3D in _model.find_children("*", "AnimatableBody3D", true, false):
		body.sync_to_physics = false
	root.add_child(_model)
	for index in CAR_COUNT:
		var car := _car(index)
		_roofs.append(car.get_node(^"Roof"))
		_overhead_strips.append(car.get_node(^"Interior/InteriorLightDiffusers"))
		# In the high-angle combat view these ceiling-level window/end headers
		# cross directly over heads, even after the actual tubes are hidden.
		for path: String in ["Body/WindowWall","NearWall/WindowWall","Body/EndCapsAndDriverCab"]:
			_trim_upper_mesh(car.get_node(path),2.55)
		if not rival:
			car.get_node(^"Interior/SeatsHandrailsAndLights").free()
			if index in [0, CAR_COUNT - 1]:
				_remove_driver_seat(car.get_node(^"Body/EndCapsAndDriverCab"))
		else:
			_remove_overhead_handrails(car.get_node(^"Interior/SeatsHandrailsAndLights"))
		for part in car.get_children():
			if part.get_meta(&"bridge", false):
				part.hide()
			if part is OmniLight3D:
				# This imported train already carries source bounds from its closed
				# interior. Rebuild them after cutting the rails and ceiling away.
				if part.has_meta(&"fixture_optics_sources"): part.remove_meta(&"fixture_optics_sources")
				# The packed lights were authored for a closed train viewed from the station.
				part.position.y -= .20
				part.light_energy = 2.20
				part.omni_range = 4.30
				part.light_cull_mask = 15
		preload("res://scripts/dream/packed_fixture_sources.gd").mark_tree(car)
		# Small marker lamps use native bloom and their own local spill. Keep them
		# out of the existing ceiling-fixture optics binding above.
		if reference_art != null: reference_art.apply_car(car, index)
	set_cutaway(not rival)


func set_cutaway(enabled: bool) -> void:
	for roof in _roofs:
		roof.visible = not enabled
	for strip in _overhead_strips:
		strip.visible = not enabled


func _remove_overhead_handrails(fittings: MeshInstance3D) -> void:
	_trim_upper_mesh(fittings,1.60)


func _trim_upper_mesh(visual: MeshInstance3D, height: float) -> void:
	var source := visual.mesh
	var variants: Dictionary = _trimmed_meshes.get(source,{})
	if variants.has(height):
		visual.mesh = variants[height]
		return
	var replacement := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := SLICE.SliceSurface.new(source.surface_get_arrays(surface),Vector3.UP,-10.0,height).build()
		if arrays.is_empty(): continue
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		replacement.surface_set_material(replacement.get_surface_count()-1,source.surface_get_material(surface))
	variants[height] = replacement
	_trimmed_meshes[source] = variants
	visual.mesh = replacement


func install_collision(parent: Node2D, origin: Vector2, pixel_scale: float, rival: bool) -> void:
	_pixel_scale = pixel_scale
	_collision_origin = origin
	_solids = Node2D.new()
	_solids.name = "RivalTrainCollision" if rival else "PlayerTrainCollision"
	_solids.position = origin + Vector2(root.position.x,root.position.z) * pixel_scale
	parent.add_child(_solids)
	for index in CAR_COUNT:
		_building_car_index = index
		_configure_car(index, rival)
		if reference_art != null:
			reference_art.dress_interior(_car(index))
			reference_art.bind_cutout(_car(index), _cutout)
		if index < CAR_COUNT - 1:
			_install_gangway(index, not rival)
	if not rival:
		surface_wear = SURFACE_WEAR.new(_cutout)
		for index in CAR_COUNT:
			surface_wear.apply_car(_car(index), index)


func release_collision() -> void:
	if is_instance_valid(_solids): _solids.queue_free()


func set_relative_x(value: float) -> void:
	root.position.x = value
	if is_instance_valid(_solids):
		_solids.position = _collision_origin+Vector2(value,root.position.z)*_pixel_scale


func detach_tail_car(index: int, wreck_parent: Node3D) -> Node3D:
	var car := _car(index)
	var detached := Node3D.new()
	detached.name = "DerailedCar%d" % (index+1)
	wreck_parent.add_child(detached)
	detached.global_transform = car.global_transform
	car.reparent(detached)
	for light: Light3D in car.find_children("*","Light3D",true,false): light.hide()
	for joint_index in [index-1,index]:
		var gangway := _model.get_node_or_null("Gangway_%02d" % (joint_index+1)) as Node3D
		if gangway != null: gangway.hide()
	for body: Node2D in _solids.get_children():
		if int(body.get_meta(&"train_car_index",-1)) == index:
			body.set_deferred("collision_layer",0)
			body.queue_free()
	platform_doors = platform_doors.filter(func(gate: Dictionary) -> bool: return int(gate.car) != index)
	if index < CAR_COUNT-1:
		_building_car_index = index+1
		_solid("DerailedTailBoundary",Vector2(joint(index)+.12,0),Vector2(.18,CABIN_EDGE*2.0),ACTOR_EDGE)
	return detached


func carriage_at(x: float) -> Node3D:
	return _car(clampi(roundi((x - FIRST_CENTER) / D.CAR_SPACING), 0, CAR_COUNT - 1))


func follow_turnout(turn_x: float, advance: float, player_advance: float) -> void:
	for index in CAR_COUNT:
		var car := _car(index)
		var distance := center(index) + root.position.x + advance - turn_x
		# A rigid carriage rides on two bogies. Sampling both keeps the wheels
		# on the same track as the cars ahead and behind it.
		var rear := turnout_point(distance - BOGIE_OFFSET)
		var front := turnout_point(distance + BOGIE_OFFSET)
		var middle := (rear + front) * .5
		car.position = Vector3(turn_x + middle.x - player_advance - _model.position.x-root.position.x, 0.0, middle.y)
		car.rotation.y = -(front - rear).angle()
	for index in CAR_COUNT - 1:
		var left := _car(index)
		var right := _car(index + 1)
		var rear_end := left.position + left.basis.x * D.HALF_CAR
		var front_end := right.position - right.basis.x * D.HALF_CAR
		var gap := front_end - rear_end
		var gangway: Node3D = _model.get_node("Gangway_%02d" % (index + 1))
		gangway.position = (rear_end + front_end) * .5
		gangway.rotation.y = -Vector2(gap.x, gap.z).angle()
		gangway.scale.x = clampf(gap.length() / (D.CAR_SPACING - D.CAR_LENGTH), .5, 2.4)


static func turnout_point(distance: float) -> Vector2:
	if distance <= 0.0:
		return Vector2(distance, 0.0)
	var angle := minf(distance, TURN_ARC) / TURN_RADIUS
	var arc := Vector2(sin(angle), 1.0 - cos(angle)) * TURN_RADIUS
	return arc + Vector2.from_angle(angle) * maxf(distance - TURN_ARC, 0.0)


func _configure_car(index: int, rival: bool) -> void:
	var car := _car(index)
	var x := center(index)
	var end_caps: MeshInstance3D = car.get_node(^"Body/EndCapsAndDriverCab")
	_cutout.register_mesh(end_caps, rival, true)
	for side: float in [-1.0, 1.0]:
		var z := side * CABIN_EDGE
		var wall: MeshInstance3D = car.get_node(^"NearWall/WindowWall" if side > 0.0 else ^"Body/WindowWall")
		if not rival:
			_shape_middle_windows(wall, z)
			for span: Vector2 in MIDDLE_BODY_SPANS:
				_solid("MiddleBody_%02d_%d_%d" % [index, int(side), int(signf(span.x))],
					Vector2(x + (span.x + span.y) * .5, z), Vector2(span.y - span.x, .14), WALL)
			for post: float in [-MIDDLE_WINDOW_HALF, MIDDLE_WINDOW_HALF]:
				_solid("MiddleWindowPost", Vector2(x + post, z), Vector2(.12, .13), WALL)
		# The two inward-facing sides are the only sides with a facing target.
		if (side > 0.0) != rival:
			_separate_window_panes(wall, x, z, not rival)
		_cutout.register_mesh(wall, rival, true)
		for post: float in WINDOW_POSTS:
			_solid("WindowPost", Vector2(x + post, z), Vector2(.12, .13), WALL)
		for pane: Vector2 in [Vector2(-9.0, -6.5), Vector2(-5.1, 5.1), Vector2(6.5, 9.0)]:
			_solid("WindowSill", Vector2(x + (pane.x + pane.y) * .5, z),
				Vector2(pane.y - pane.x, .14), ACTOR_EDGE)
		for door_x: float in D.DOOR_CENTERS:
			var leaves: Array[Node3D] = []
			for leaf_sign: int in [-1, 1]:
				var leaf: Node3D = car.get_node("Door_%d_%d_%d" % [int(side), int(door_x * 10), leaf_sign])
				leaves.append(leaf)
				_cutout.register_mesh(leaf.get_node(^"GlazedSlidingLeaf"), rival or side < 0.0, true)
			var at := Vector2(x + door_x, side * DOOR_DEPTH)
			var gate := _gate(leaves, _solid("PassengerDoor", at, Vector2(DOOR_WIDTH, .15), WALL))
			if not rival and side < 0.0:
				gate["at"] = at
				gate["car"] = index
				for part in car.get_children():
					if part.get_meta(&"bridge", false) and is_equal_approx(part.position.x, door_x) and part.position.z < 0.0:
						gate["bridge"] = part
				platform_doors.append(gate)
		if rival:
			for seat: Vector2 in [Vector2(-2.65, 4.8), Vector2(2.65, 4.8)]:
				_add_seat(x, side, seat)
			if index > 0:
				_add_seat(x, side, Vector2(-7.65, 2.0))
			if index < CAR_COUNT - 1:
				_add_seat(x, side, Vector2(7.65, 2.0))
		for end_sign: float in [-1.0, 1.0]:
			_solid("VestibuleWing", Vector2(x + end_sign * D.HALF_CAR, side * .99),
				Vector2(.14, .80), WALL | PROJECTED_BALLISTIC_WALL)
	if index in [0, CAR_COUNT - 1]:
		var direction := -1.0 if index == 0 else 1.0
		_solid("DriverPartition", Vector2(x + direction * 7.88, 0.0), Vector2(.12, 2.82), WALL)


func _add_seat(car_x: float, side: float, seat: Vector2) -> void:
	_solid("Bench", Vector2(car_x + seat.x, side * 1.03), Vector2(seat.y, .58), ACTOR_EDGE)


func _remove_driver_seat(caps: MeshInstance3D) -> void:
	var source := caps.mesh
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		if material.resource_name == "PBR_UsedStainlessSeats":
			continue
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
		result.surface_set_material(result.get_surface_count() - 1, material)
	caps.mesh = result


func _shape_middle_windows(wall: MeshInstance3D, z: float) -> void:
	# Edit this consist instance, preserving the source train and its PBR surfaces.
	var source := wall.mesh
	var result := ArrayMesh.new()
	var steel: Material
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		var arrays := source.surface_get_arrays(surface)
		if material.resource_name == "PBR_StainlessMetroBody":
			steel = material
		if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			for span: Vector2 in [Vector2(-9.0, -MIDDLE_BODY_HALF),
				Vector2(-MIDDLE_WINDOW_HALF + WINDOW_FRAME_HALF, MIDDLE_WINDOW_HALF - WINDOW_FRAME_HALF),
				Vector2(MIDDLE_BODY_HALF, 9.0)]:
				var remaining := SLICE.SliceSurface.new(arrays, Vector3.RIGHT, span.x, span.y).build()
				if not remaining.is_empty():
					result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, remaining)
					result.surface_set_material(result.get_surface_count() - 1, material)
		else:
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			result.surface_set_material(result.get_surface_count() - 1, material)
	wall.mesh = result
	for span: Vector2 in MIDDLE_BODY_SPANS:
		var panel := MeshInstance3D.new()
		panel.name = "SolidMiddleBody_Rear" if span.y < 0.0 else "SolidMiddleBody_Front"
		panel.layers = wall.layers
		panel.position = Vector3((span.x + span.y) * .5, 1.785, z)
		panel.mesh = _body_panel_mesh(Vector3(span.y - span.x, 1.61, .10), panel.position, steel)
		wall.add_child(panel)
		_cutout.register_mesh(panel, false, true)
	for post: float in [-MIDDLE_WINDOW_HALF, MIDDLE_WINDOW_HALF]:
		var frame := MeshInstance3D.new()
		frame.name = "MiddleWindowFrame_Rear" if post < 0.0 else "MiddleWindowFrame_Front"
		frame.layers = wall.layers
		frame.position = Vector3(post, 1.79, z)
		frame.mesh = _body_panel_mesh(Vector3(.12, 1.70, .12), frame.position, steel)
		wall.add_child(frame)
		_cutout.register_mesh(frame, false, true)


func _body_panel_mesh(size: Vector3, at: Vector3, material: Material) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for index in vertices.size():
		var point := vertices[index] + at
		var normal := normals[index]
		# Match the imported train's physical UV scale, including its wear maps.
		uvs[index] = Vector2(point.x, point.z) * .5 if absf(normal.y) > .7 else (
			Vector2(point.z, point.y) * .5 if absf(normal.x) > .7 else Vector2(point.x, point.y) * .5)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool := SurfaceTool.new()
	tool.create_from(mesh, 0)
	tool.generate_tangents()
	var result := tool.commit()
	result.surface_set_material(0, material)
	return result


func _install_gangway(index: int, gated: bool) -> void:
	var x := joint(index)
	var gangway: Node3D = _model.get_node("Gangway_%02d" % (index + 1))
	if reference_art != null: reference_art.dress_connector(gangway, _cutout)
	_cutout.register_mesh(gangway.get_node(^"ArticulatedGangway"), not gated, true)
	for side: float in [-1.0, 1.0]:
		_solid("GangwaySide", Vector2(x, side * .63), Vector2(.74, .18), WALL | PROJECTED_BALLISTIC_WALL)
	if not gated:
		return
	var frame := Node3D.new()
	frame.name = "GangwayDoor"
	frame.rotation.y = PI * .5
	gangway.add_child(frame)
	var template: Node3D = _car(index).get_node(^"Door_-1_58_1/GlazedSlidingLeaf")
	var leaves: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.position.x = side * .27
		frame.add_child(leaf)
		var visual := template.duplicate() as MeshInstance3D
		visual.scale.x = .77
		leaf.add_child(visual)
		_cutout.register_mesh(visual, true, true)
		leaves.append(leaf)
	if reference_art != null: reference_art.apply_gangway(frame, leaves, _cutout)
	# The shut gate seals the entire junction in the ordinary gameplay plane.
	car_gates.append(_gate(leaves, _solid("GangwayDoor", Vector2(x, 0.0), Vector2(.14, CABIN_EDGE * 2.0), WALL), .56))


func _separate_window_panes(wall: MeshInstance3D, car_x: float, z: float, half_middle := false) -> void:
	# Keep the exact imported material and UVs when making each pane independently breakable.
	var spans := WINDOW_SPANS.duplicate()
	if half_middle:
		spans[2] = Vector2(-MIDDLE_WINDOW_HALF + WINDOW_FRAME_HALF, -WINDOW_FRAME_HALF)
		spans[3] = Vector2(WINDOW_FRAME_HALF, MIDDLE_WINDOW_HALF - WINDOW_FRAME_HALF)
	var source := wall.mesh
	var opaque := ArrayMesh.new()
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		var arrays := source.surface_get_arrays(surface)
		if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			for span: Vector2 in spans:
				var pane_arrays := SLICE.SliceSurface.new(arrays, Vector3.RIGHT, span.x, span.y).build()
				if not pane_arrays.is_empty():
					_add_pane(wall, pane_arrays, material, car_x, z, span)
		else:
			opaque.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			opaque.surface_set_material(opaque.get_surface_count() - 1, material)
	wall.mesh = opaque


func _add_pane(wall: MeshInstance3D, arrays: Array, material: Material, car_x: float, z: float, span: Vector2) -> void:
	var center_x := (span.x + span.y) * .5
	var window := GLASS.new()
	window.name = "FiringPane"
	window.position = Vector3(center_x, 1.785, z)
	wall.add_child(window)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	for index in vertices.size():
		vertices[index] -= window.position
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var pane_mesh := ArrayMesh.new()
	pane_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	pane_mesh.surface_set_material(0, material)
	var pane := MeshInstance3D.new()
	# The office fracture pipeline uses this source role for diagonal pieces,
	# reflective edges and the impact crumbs. Keep the original train pane mesh.
	pane.name = "GlassPane"
	pane.mesh = pane_mesh
	pane.layers = wall.layers
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	window.add_child(pane)
	window.glass_pane = pane
	window.structural_height = 1.61
	window.structural_thickness = .06
	window.edge_data = {"x":car_x + center_x, "y":z + .5}
	window.edge_key = str(car_x + center_x)
	window._build_2d_collision(_solids, false)
	window.collision_body_2d.set_meta(&"train_car_index",_building_car_index)
	window.collision_body_2d.collision_layer = 8
	(window.collision_shape_2d.shape as RectangleShape2D).size.x = (span.y - span.x) * _pixel_scale
	firing_panes.append(window)


func _car(index: int) -> Node3D:
	return _model.get_node("Carriage_%02d" % (index + 1))


func _solid(title: String, at: Vector2, size: Vector2, layer: int) -> CollisionShape2D:
	var body := StaticBody2D.new()
	body.name = title
	body.position = at * _pixel_scale
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta(&"train_car_index",_building_car_index)
	var shape := RectangleShape2D.new()
	shape.size = size * _pixel_scale
	var node := CollisionShape2D.new()
	node.shape = shape
	body.add_child(node)
	_solids.add_child(body)
	return node


static func _gate(leaves: Array[Node3D], collision: CollisionShape2D, travel := .73) -> Dictionary:
	return {"leaves":leaves, "start":[leaves[0].position.x, leaves[1].position.x],
		"collision":collision, "travel":travel, "fraction":0.0}


static func open_gate(gate: Dictionary, delta: float) -> bool:
	if gate.fraction >= 1.0:
		return true
	gate.fraction = minf(gate.fraction + delta / .68, 1.0)
	var travel := smoothstep(0.0, 1.0, gate.fraction) * float(gate.travel)
	gate.leaves[0].position.x = gate.start[0] - travel
	gate.leaves[1].position.x = gate.start[1] + travel
	if gate.fraction >= 1.0:
		gate.collision.set_deferred("disabled", true)
		if gate.has("bridge"):
			gate.bridge.show()
	return gate.fraction >= 1.0


static func center(index: int) -> float:
	return FIRST_CENTER + index * D.CAR_SPACING


static func joint(index: int) -> float:
	return center(index) + D.CAR_CENTER


static func cell_limit(index: int) -> int:
	return floori(joint(index)) + 1
