extends RefCounted
## Bind the original emissive geometry to its existing lights; no duplicate lamp meshes.
const OPTICS := preload("res://scripts/dream/office_light_optics.gd")


static func mark_tree(root: Node3D) -> void:
	var lights: Array[Light3D] = []
	for light: Light3D in root.find_children("*", "Light3D", true, false):
		if light is OmniLight3D or light is SpotLight3D: lights.append(light)
	if lights.is_empty(): return
	var bindings: Dictionary = {}
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for piece: Dictionary in emissive_parts(mesh):
			var bounds: AABB = piece.bounds
			var axis := bounds.size.max_axis_index()
			var count := maxi(1, ceili(bounds.size[axis] / 2.4))
			for index in count:
				var section := bounds
				section.size[axis] /= count
				section.position[axis] += section.size[axis] * index
				var at := mesh.global_transform * section.get_center()
				var nearest: Light3D
				var distance := INF
				for light in lights:
					var squared := light.global_position.distance_squared_to(at)
					if squared < distance:
						distance = squared
						nearest = light
				if distance > 25.0: continue
				if not bindings.has(nearest): bindings[nearest] = []
				bindings[nearest].append({"mesh": weakref(mesh), "bounds": section, "material": piece.material, "distance": distance})
	for light: Light3D in bindings:
		var sources: Array = bindings[light]
		sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
		var selected: Array[Dictionary] = []
		for index in mini(2, sources.size()): selected.append(sources[index])
		OPTICS.mark_sources(light.get_parent(), light, selected)


static func emissive_parts(mesh: MeshInstance3D) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface) as BaseMaterial3D
		if material == null or not material.emission_enabled: continue
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size(): indices.append(index)
		var parents: Array[int] = []
		var positions: Dictionary = {}
		for index in vertices.size():
			parents.append(index)
			var position := vertices[index].snapped(Vector3.ONE * .00001)
			if positions.has(position): _join(parents, index, positions[position])
			else: positions[position] = index
		for index in range(0, indices.size(), 3):
			_join(parents, indices[index], indices[index + 1])
			_join(parents, indices[index], indices[index + 2])
		var parts: Dictionary = {}
		for index in indices:
			var group := _find(parents, index)
			if not parts.has(group): parts[group] = {"bounds": AABB(vertices[index], Vector3.ZERO), "indices": PackedInt32Array()}
			parts[group].bounds = parts[group].bounds.expand(vertices[index])
			parts[group].indices.append(index)
		for group in parts:
			parts[group].surface = surface
			parts[group].material = material
			output.append(parts[group])
	return output


static func keep_side_diffusers(mesh: MeshInstance3D) -> void:
	# The cutaway hides ceiling panels but keeps the original two wall-edge tubes.
	var replacement := ArrayMesh.new()
	for part: Dictionary in emissive_parts(mesh):
		if absf(part.bounds.get_center().z) < .70: continue
		var arrays := mesh.mesh.surface_get_arrays(part.surface)
		arrays[Mesh.ARRAY_INDEX] = part.indices
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		replacement.surface_set_material(replacement.get_surface_count() - 1, part.material)
	mesh.mesh = replacement


static func _find(parents: Array[int], value: int) -> int:
	while parents[value] != value:
		parents[value] = parents[parents[value]]
		value = parents[value]
	return value


static func _join(parents: Array[int], a: int, b: int) -> void:
	var left := _find(parents, a)
	var right := _find(parents, b)
	if left != right: parents[right] = left
