extends Node3D
## Floor-owned presentation only. Geometry/materials are snapshotted synchronously:
## the caller may remove the wall as soon as spawn() returns.
const DEBRIS := preload("res://scripts/dream/destruction_floor_debris.gd")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const MAX_BURSTS := 10
const LIFETIME := 2.1
const DUST_LIFETIME := .62
const GROUP := &"shared_wall_break_effects"
static var _closed_meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _nearest_shaders: Dictionary = {}
static var _core_material: StandardMaterial3D
static var _dust_material: StandardMaterial3D
static var _crumb_material: StandardMaterial3D
static var _dust_shape: SphereMesh
static var _crumb_shape: BoxMesh
var pieces: Array[Dictionary] = []
var dust: Array[Dictionary] = []
var crumbs: Array[Dictionary] = []
var dust_render: MultiMeshInstance3D
var crumb_render: MultiMeshInstance3D
var floor_cells: Dictionary = {}
var pit_cells: Dictionary = {}
var age := 0.0
var floor_y := .025
var random := RandomNumberGenerator.new()

static func spawn(world: Node3D, wall: Node3D, direction: Vector2) -> void:
	if not is_instance_valid(world) or not is_instance_valid(wall): return
	var floor_root: Node3D = world.get("floor_root")
	var source: MeshInstance3D = wall.get("wall_mesh")
	if not is_instance_valid(floor_root) or not is_instance_valid(source): return
	# A cutaway wall may currently be only a 12 cm root beam. Never fracture it
	# as the whole wall: take the immutable full-height office/base geometry.
	var full: Mesh = wall.get("office_full_mesh")
	if full == null: full = wall.get("_base_wall_mesh")
	if full == null: full = source.mesh
	if full == null: return
	var burst: Node3D = load("res://scripts/dream/shared_wall_break_effect.gd").new()
	burst.name = "SharedWallBreakEffect"
	floor_root.add_child(burst)
	burst.global_transform = world.global_transform
	burst.add_to_group(GROUP)
	# One immutable membership snapshot per floor. A later generation may clear
	# the world's live dictionaries while this root is kept in the rollback stash.
	var generation: Variant = world.get("_layout_generation")
	var membership: Dictionary = floor_root.get_meta(&"wall_break_floor_snapshot", {})
	if membership.is_empty() or membership.get("generation") != generation:
		var floors: Dictionary = world.get("floor_cells") if world.get("floor_cells") is Dictionary else {}
		var pits: Dictionary = world.get("pit_cells") if world.get("pit_cells") is Dictionary else {}
		membership = {"generation":generation, "floor":floors.duplicate(), "pits":pits.duplicate()}
		floor_root.set_meta(&"wall_break_floor_snapshot", membership)
	burst.floor_cells = membership.floor
	burst.pit_cells = membership.pits
	burst._build(wall, source, full, direction)
	var live: Array = world.get_tree().get_nodes_in_group(GROUP).filter(func(node: Node) -> bool: return node.get_parent() == floor_root and not node.is_queued_for_deletion())
	if live.size() > MAX_BURSTS: live[0].queue_free()
	SFX.play_event(&"wall_impact")

func _build(wall: Node3D, source: MeshInstance3D, full: Mesh, direction: Vector2) -> void:
	random.seed = get_instance_id()
	var snapshot := MeshInstance3D.new()
	snapshot.mesh = full
	# Original room face materials, rather than the current cutaway/capture copy.
	for surface in full.get_surface_count():
		var material: Material = wall.get("wall_material_front") if surface == 0 else wall.get("wall_material_back")
		if surface >= 2: material = source.get_active_material(mini(surface, source.mesh.get_surface_count() - 1)) if source.mesh != null else null
		if material == null: material = full.surface_get_material(surface)
		snapshot.set_surface_override_material(surface, _face_material(material))
	var worker := DEBRIS.new()
	var bounds := full.get_aabb()
	var source_pose := global_transform.affine_inverse() * source.global_transform
	floor_y = (source_pose * Vector3(0, bounds.position.y, 0)).y + .025
	var heading := direction.normalized() if direction.length_squared() > .0001 else Vector2.RIGHT
	var forward := Vector3(heading.x, 0, heading.y)
	var side := Vector3(-heading.y, 0, heading.x)
	for row in 3:
		for column in 2:
			var low := Vector2(bounds.position.x + bounds.size.x * column / 2.0, bounds.position.y + bounds.size.y * row / 3.0)
			var high := low + Vector2(bounds.size.x / 2.0, bounds.size.y / 3.0)
			for diagonal in [-1, 1]:
				var sliced: ArrayMesh = worker._cached_slice(snapshot, low, high, diagonal)
				if sliced.get_surface_count() == 0: continue
				var mesh := _close_slice(sliced, bounds)
				var pivot := mesh.get_aabb().get_center()
				var visual := MeshInstance3D.new()
				visual.mesh = mesh
				visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(visual)
				var point := source_pose * pivot
				pieces.append({"node":visual, "pivot":pivot, "point":point, "basis":source_pose.basis, "rotation":Vector3.ZERO, "velocity":forward * random.randf_range(2.5, 4.5) + side * random.randf_range(-1.1, 1.1) + Vector3.UP * random.randf_range(.8, 2.2), "spin":Vector3(random.randf_range(-7, 7), random.randf_range(-4, 4), random.randf_range(-8, 8)), "settled":false, "radius":mesh.get_aabb().size.length() * .32, "rest_height":mesh.get_aabb().size.z * source_pose.basis.z.length() * .5})
				visual.transform = source_pose
	worker.free()
	snapshot.free()
	var front: Material = wall.get("wall_material_front")
	var back: Material = wall.get("wall_material_back")
	var tint := _material_color(front).lerp(_material_color(back), .5)
	var center := source_pose * bounds.get_center()
	_make_dust(center, source_pose.basis.x.normalized(), forward, tint)
	_make_crumbs(Vector3(center.x, floor_y + .05, center.z), forward, side, tint)

static func _face_material(source: Material) -> Material:
	if source == null: return _interior_material()
	if _materials.has(source): return _materials[source]
	if _materials.size() >= 256: _materials.clear()
	var material: Material = source.duplicate()
	if material is BaseMaterial3D:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	elif material is ShaderMaterial and material.shader != null:
		# Reuse one program per source shader; never allocate a Shader per wall.
		var shader: Shader = material.shader
		if not _nearest_shaders.has(shader):
			var code := shader.code.replace("filter_linear_mipmap_anisotropic", "filter_nearest").replace("filter_linear_mipmap", "filter_nearest").replace("filter_linear", "filter_nearest")
			if code == shader.code: _nearest_shaders[shader] = shader
			else:
				var nearest := Shader.new()
				nearest.code = code
				_nearest_shaders[shader] = nearest
		material.shader = _nearest_shaders[shader]
		material.set_shader_parameter("architecture_cutaway", false)
		material.set_shader_parameter("occlusion_cutout_enabled", false)
		material.set_shader_parameter("object_space", true)
	_materials[source] = material
	return material

static func _material_color(material: Material) -> Color:
	if material is BaseMaterial3D: return material.albedo_color
	if material is ShaderMaterial:
		for parameter in [&"base_color", &"surface_tint", &"albedo_color"]:
			var value: Variant = material.get_shader_parameter(parameter)
			if value is Color: return value
	return Color(.64, .65, .61)

static func _interior_material() -> StandardMaterial3D:
	if _core_material == null:
		_core_material = StandardMaterial3D.new()
		_core_material.albedo_color = Color(.56, .56, .50)
		_core_material.roughness = 1.0
		_core_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _core_material

static func _close_slice(slice: ArrayMesh, original_bounds: AABB) -> ArrayMesh:
	if _closed_meshes.has(slice): return _closed_meshes[slice]
	if _closed_meshes.size() >= 512: _closed_meshes.clear()
	var output := ArrayMesh.new()
	var points := PackedVector2Array()
	for surface in slice.get_surface_count():
		var arrays := slice.surface_get_arrays(surface)
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		output.surface_set_material(output.get_surface_count() - 1, slice.surface_get_material(surface))
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: points.append(Vector2(point.x, point.y))
	var hull := Geometry2D.convex_hull(points)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var bounds := slice.get_aabb()
	for i in range(hull.size() - 1):
		var a := hull[i]
		var b := hull[i + 1]
		# Exterior side/top caps already exist in the intact source geometry.
		if is_equal_approx(a.x, b.x) and (is_equal_approx(a.x, original_bounds.position.x) or is_equal_approx(a.x, original_bounds.end.x)): continue
		if is_equal_approx(a.y, b.y) and is_equal_approx(a.y, original_bounds.end.y): continue
		var edge := b - a
		var normal := Vector3(edge.y, -edge.x, 0).normalized()
		var z0 := bounds.position.z + .001
		var z1 := bounds.end.z - .001
		var quad := [Vector3(a.x,a.y,z0), Vector3(b.x,b.y,z0), Vector3(b.x,b.y,z1), Vector3(a.x,a.y,z1)]
		for vertex in [0, 2, 1, 0, 3, 2]:
			builder.set_normal(normal)
			builder.set_uv(Vector2.ZERO)
			builder.add_vertex(quad[vertex])
			count += 1
	if count > 0:
		builder.set_material(_interior_material())
		builder.commit(output)
	_closed_meshes[slice] = output
	return output

static func _batch(shape: Mesh, material: Material, count: int, colors: bool) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colors
	multi.mesh = shape
	multi.instance_count = count
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func _ensure_particle_resources() -> void:
	if _dust_material == null:
		_dust_material = StandardMaterial3D.new()
		_dust_material.vertex_color_use_as_albedo = true
		_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_material.roughness = 1.0
		_dust_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if _dust_shape == null:
		_dust_shape = SphereMesh.new()
		_dust_shape.radius = .5
		_dust_shape.height = 1.0
		_dust_shape.radial_segments = 5
		_dust_shape.rings = 2
	if _crumb_material == null:
		_crumb_material = StandardMaterial3D.new()
		_crumb_material.vertex_color_use_as_albedo = true
		_crumb_material.roughness = 1.0
		_crumb_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if _crumb_shape == null:
		_crumb_shape = BoxMesh.new()
		_crumb_shape.size = Vector3.ONE

static func prepare_render_parts(parent: Node3D, position: Vector3, layer: int) -> int:
	if not is_instance_valid(parent): return 0
	_ensure_particle_resources()
	# These are real visible draw representatives. The loading caller owns their
	# camera, lighting states and lifetime; no effect, RNG or audio is simulated.
	var dust_part := _batch(_dust_shape, _dust_material, 1, true)
	dust_part.name = "SharedWallDustRenderPreparation"
	dust_part.layers = layer
	dust_part.position = position + Vector3(-.24, .12, 0)
	dust_part.multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(.4, .35, .4)), Vector3.ZERO))
	dust_part.multimesh.set_instance_color(0, Color(.72, .72, .67, .42))
	parent.add_child(dust_part)
	var crumb_part := _batch(_crumb_shape, _crumb_material, 1, true)
	crumb_part.name = "SharedWallCrumbRenderPreparation"
	crumb_part.layers = layer
	crumb_part.position = position + Vector3(.08, .08, 0)
	crumb_part.multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(.16, .08, .13)), Vector3.ZERO))
	crumb_part.multimesh.set_instance_color(0, Color(.58, .57, .50))
	parent.add_child(crumb_part)
	var core_part := MeshInstance3D.new()
	core_part.name = "SharedWallCoreRenderPreparation"
	core_part.mesh = _crumb_shape
	core_part.material_override = _interior_material()
	core_part.layers = layer
	core_part.position = position + Vector3(.32, .12, 0)
	core_part.scale = Vector3(.18, .18, .18)
	core_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(core_part)
	return 3

func _make_dust(center: Vector3, along: Vector3, forward: Vector3, tint: Color) -> void:
	_ensure_particle_resources()
	dust_render = _batch(_dust_shape, _dust_material, 11, true)
	add_child(dust_render)
	var color := Color(.72, .72, .67).lerp(tint, .22)
	for i in 11:
		var point := center + along * random.randf_range(-.5, .5) + Vector3.UP * random.randf_range(-.7, .35)
		point.y = maxf(floor_y + .12, point.y)
		var size := Vector3(random.randf_range(.35, .72), random.randf_range(.28, .65), random.randf_range(.3, .58))
		dust.append({"point":point, "velocity":forward * random.randf_range(.7, 1.8) + along * random.randf_range(-.5, .5) + Vector3.UP * random.randf_range(.2, .7), "size":size, "rotation":Vector3(random.randf(), random.randf(), random.randf()) * PI, "color":color, "delay":random.randf_range(0, .06)})
	_update_dust()

func _make_crumbs(center: Vector3, forward: Vector3, side: Vector3, tint: Color) -> void:
	_ensure_particle_resources()
	crumb_render = _batch(_crumb_shape, _crumb_material, 18, true)
	add_child(crumb_render)
	for i in 18:
		var point := center + side * random.randf_range(-.5, .5)
		var size := Vector3(random.randf_range(.035, .11), random.randf_range(.025, .06), random.randf_range(.04, .12))
		crumbs.append({"point":point, "velocity":forward * random.randf_range(.4, 2.2) + side * random.randf_range(-.7, .7) + Vector3.UP * random.randf_range(.3, 1.3), "size":size, "rotation":Vector3(0, random.randf_range(-PI, PI), 0)})
		crumb_render.multimesh.set_instance_color(i, tint.lerp(Color(.58, .57, .50), random.randf_range(.2, .6)))
	_update_crumbs(0)

func _has_floor(point: Vector3) -> bool:
	var cell := Vector2i(roundi(point.x), roundi(point.z))
	return floor_cells.has(cell) and not pit_cells.has(cell)

func _process(delta: float) -> void:
	age += maxf(0, delta)
	if age >= LIFETIME:
		queue_free()
		return
	for item in pieces:
		if not bool(item.settled):
			item.velocity.y -= 13.0 * delta
			item.point += Vector3(item.velocity) * delta
			item.rotation += Vector3(item.spin) * delta
			if item.point.y <= floor_y + float(item.radius) and item.velocity.y < 0 and _has_floor(item.point):
				item.point.y = floor_y + float(item.rest_height)
				item.rotation.x = PI * .5
				item.rotation.z = 0.0
				item.settled = true
		var shrink := 1.0 - smoothstep(1.0, LIFETIME, age)
		# Shrinking avoids a new transparent wall-material variant for fading.
		var basis := Basis(item.basis) * Basis.from_euler(item.rotation).scaled(Vector3.ONE * shrink)
		var position: Vector3 = item.point
		item.node.transform = Transform3D(basis, position - basis * Vector3(item.pivot))
	_update_dust()
	_update_crumbs(delta)

func _update_dust() -> void:
	if not is_instance_valid(dust_render): return
	if age > DUST_LIFETIME:
		dust_render.visible = false
		return
	for i in dust.size():
		var item: Dictionary = dust[i]
		var time := maxf(0, age - float(item.delay))
		var growth := lerpf(.24, 1.45, smoothstep(0, DUST_LIFETIME, time))
		var color: Color = item.color
		color.a = .42 * (1.0 - smoothstep(.08, DUST_LIFETIME - float(item.delay), time))
		dust_render.multimesh.set_instance_color(i, color)
		dust_render.multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(item.rotation).scaled(Vector3(item.size) * growth), Vector3(item.point) + Vector3(item.velocity) * time))

func _update_crumbs(delta: float) -> void:
	if not is_instance_valid(crumb_render): return
	var shrink := 1.0 - smoothstep(1.25, LIFETIME, age)
	for i in crumbs.size():
		var item: Dictionary = crumbs[i]
		if item.point.y > floor_y or item.velocity.y > 0:
			item.velocity.y -= 10.0 * delta
			item.point += Vector3(item.velocity) * delta
			if item.point.y < floor_y and _has_floor(item.point):
				item.point.y = floor_y
				item.velocity = Vector3.ZERO
		var basis := Basis.from_euler(item.rotation).scaled(Vector3(item.size) * shrink)
		crumb_render.multimesh.set_instance_transform(i, Transform3D(basis, item.point))
