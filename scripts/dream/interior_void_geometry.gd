extends RefCounted
## Visual backing only: never contributes floor cells, navigation or collision.
const TOPOLOGY = preload("res://scripts/dream/preview/sample_neon_city.gd")
const DEPTH := -0.08

static func enclosed_cells(floor_cells: Dictionary, rect: Rect2i) -> Dictionary:
	var external: Dictionary = TOPOLOGY.classify_void(floor_cells, rect).external
	var result: Dictionary = {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if not floor_cells.has(cell) and not external.has(cell): result[cell] = true
	return result

static func build(floor_cells: Dictionary, rect: Rect2i) -> MeshInstance3D:
	var cells := enclosed_cells(floor_cells, rect)
	var backing := MeshInstance3D.new()
	backing.name = "InteriorVoidBacking"
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backing.set_meta(&"void_cell_count", cells.size())
	if cells.is_empty(): return backing
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Merge horizontal runs. One mesh/material for the whole floor, not one node per tile.
	for y in range(rect.position.y, rect.end.y):
		var x := rect.position.x
		while x < rect.end.x:
			if not cells.has(Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while x < rect.end.x and cells.has(Vector2i(x, y)): x += 1
			quad(surface, Vector3(start - .5, DEPTH, y - .5), Vector3(x - .5, DEPTH, y - .5), Vector3(x - .5, DEPTH, y + .5), Vector3(start - .5, DEPTH, y + .5))
	# A shallow dark rim closes grazing-angle cracks without covering wall faces.
	for cell: Vector2i in cells:
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if cells.has(cell + step): continue
			var center := Vector3(cell.x + step.x * .5, 0.0, cell.y + step.y * .5)
			var tangent := Vector3(-step.y, 0, step.x) * .5
			quad(surface, center - tangent, center + tangent, center + tangent + Vector3.DOWN * (.6 - DEPTH), center - tangent + Vector3.DOWN * (.6 - DEPTH))
	backing.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	backing.material_override = material
	return backing

static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a, c, b, a, d, c]: surface.add_vertex(point)
