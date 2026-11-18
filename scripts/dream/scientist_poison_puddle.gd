extends MeshInstance3D
## The floor mesh and contact query use the same clipped outline and pixel mask.
const MATERIAL := preload("res://art/Effects/scientist_poison.tres")
## Baked directly from the original sheet's alpha, so a first spill never reads back the GPU.
const MASK: BitMap = preload("res://art/Effects/scientist_poison_mask.res")
const SIDES := 32
const LIFETIME := 6.0
const TILE_SIZE := 80
static var flat_tile: ArrayMesh

var center: Vector2
var radius: float
var floor_y: float
var age := 0.0
var spread := .22
var tile: Vector2i
var grid: int
var outline := PackedVector2Array()

func configure(world: Node3D, at: Vector2, large: bool, variant: int) -> void:
	scale = Vector3.ONE
	age = 0.0
	spread = .22
	outline.clear()
	center = at
	radius = 43.0 if large else 24.0
	grid = TILE_SIZE if large else TILE_SIZE / 2
	tile = Vector2i(variant % 2, variant / 2)
	var ground: Vector3 = world.get_gameplay_world_position(at, .022)
	global_position = ground
	floor_y = ground.y - .022
	set_instance_shader_parameter("tile", Vector2(tile))
	set_instance_shader_parameter("grid", float(grid))
	set_instance_shader_parameter("spread", spread)
	if _can_use_flat_tile(world):
		mesh = flat_mesh()
		scale = Vector3(radius / 32.0,1,radius / 32.0)
		return
	_build_clipped_mesh(world, at)

static func flat_mesh() -> ArrayMesh:
	if flat_tile == null:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
		flat_tile = ArrayMesh.new()
		flat_tile.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return flat_tile

func _can_use_flat_tile(world: Node3D) -> bool:
	var first: Vector2i = world._cell_for_gameplay_position(center - Vector2.ONE * radius)
	var last: Vector2i = world._cell_for_gameplay_position(center + Vector2.ONE * radius)
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var cell := Vector2i(x,y)
			if not world.floor_cells.has(cell) or absf(world.get_gameplay_world_position(Vector2(cell)*32.0,0.0).y-floor_y) > .01:
				return false
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	query.shape = circle
	query.transform.origin = center
	query.collision_mask = world.WORLD_WALL_LAYER
	return world.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _build_clipped_mesh(world: Node3D, at: Vector2) -> void:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var uvs := PackedVector2Array([Vector2(.5,.5)])
	var triangles := PackedInt32Array()
	var space: PhysicsDirectSpaceState2D = world.player.get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(at, at, world.WORLD_WALL_LAYER)
	for i in SIDES:
		var direction := Vector2.RIGHT.rotated(TAU * i / SIDES)
		var reach := radius
		ray.to = at + direction * reach
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			reach = maxf(0.0, at.distance_to(hit.position) - 1.0)
		for step in range(4, ceili(reach) + 4, 4):
			var distance := minf(step, reach)
			var point := at + direction * distance
			if not world.floor_cells.has(world._cell_for_gameplay_position(point)) or absf(world.get_gameplay_world_position(point,0).y - floor_y) > .42:
				reach = maxf(0.0, distance - 4.0)
				break
		var offset := direction * reach
		outline.append(offset)
		vertices.append(to_local(world.get_gameplay_world_position(at + offset, .022)))
		uvs.append(Vector2(.5,.5) + offset / (2.0 * radius))
		triangles.append_array(PackedInt32Array([0, 1+i, 1+((i+1)%SIDES)]))
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = triangles
	var floor_mesh := ArrayMesh.new()
	floor_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = floor_mesh

func advance(delta: float) -> void:
	age += delta
	var size_now := lerpf(.22, 1.0, smoothstep(0.0, .24, age)) * smoothstep(0.0, .70, LIFETIME - age)
	if not is_equal_approx(spread, size_now):
		spread = size_now
		set_instance_shader_parameter("spread", spread)

func contains(point: Vector2) -> bool:
	var offset := point - center
	if spread <= .01 or offset.length_squared() > radius * radius:
		return false
	if not outline.is_empty() and not Geometry2D.is_point_in_polygon(offset, outline):
		return false
	var uv := offset / (2.0 * radius * spread) + Vector2(.5,.5)
	if not Rect2(0,0,1,1).has_point(uv):
		return false
	var pixel := Vector2i((((uv * grid).floor() + Vector2(.5,.5)) / grid * TILE_SIZE).floor())
	return MASK.get_bitv(tile * TILE_SIZE + pixel)
