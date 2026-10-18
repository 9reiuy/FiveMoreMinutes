class_name OfficeFurnitureCatalog
extends RefCounted

## One footprint/height contract shared by layout, 2D collision and 3D presentation.
const SCALE := 32.0
const PIXEL_MATERIALS = preload("res://scripts/dream/office_pixel_materials.gd")
const MODEL_ROOT := "res://art/Dream/office_lowpoly/kenney/"
const DEFINITIONS := {
	"desk": ["desk", Vector3(2.2, 0.74, 1.1), 2],
	"workstation": ["desk", Vector3(2.2, 0.74, 1.1), 2],
	"chair": ["chairDesk", Vector3(0.62, 0.9, 0.65), 1],
	"table": ["table", Vector3(4.5, 0.76, 1.3), 2],
	"dining_table": ["table", Vector3(1.5, 0.76, 1.3), 2],
	"coffee_table": ["tableCoffee", Vector3(1.3, 0.42, 0.75), 2],
	"sofa": ["loungeSofa", Vector3(2.1, 0.85, 0.9), 2],
	"cabinet": ["bookcaseClosed", Vector3(1.3, 1.85, 0.65), 3],
	"cabinet_open": ["bookcaseClosed", Vector3(1.3, 1.85, 1.5), 3],
	"shelf": ["bookcaseOpen", Vector3(1.5, 1.9, 0.7), 3],
	"sorting_table": ["", Vector3(1.5, 0.76, 0.75), 2],
	"fridge": ["kitchenFridge", Vector3(0.9, 1.85, 0.8), 3],
	"counter": ["kitchenCabinet", Vector3(1.5, 0.88, 0.7), 2],
	"appliance_counter": ["", Vector3(1.5, 0.88, 0.7), 2],
	"sink": ["kitchenSink", Vector3(1.2, 0.88, 0.7), 2],
	"washbasin": ["bathroomSink", Vector3(0.8, 0.85, 0.6), 2],
	"toilet": ["toilet", Vector3(0.65, 0.8, 0.85), 2],
	"bin": ["trashcan", Vector3(0.45, 0.55, 0.45), 1],
	"water_dispenser": ["", Vector3(.55,1.4,.55), 3],
	"box": ["cardboardBoxClosed", Vector3(0.7, 0.65, 0.7), 1],
	"plant": ["pottedPlant", Vector3(0.65, 1.3, 0.65), 1],
	"server": ["", Vector3(1.0, 1.95, 0.85), 3],
	"copier": ["", Vector3(1.3, 1.15, 0.9), 3],
	"partition": ["", Vector3(0.08, 1.8, 1.65), 3],
	"stall_door": ["", Vector3(0.82, 1.55, 0.08), 3],
	"whiteboard": ["", Vector3(2.0, 1.65, 0.15), 3],
	"reception": ["", Vector3(2.8, 1.05, 0.9), 3],
}
static var scenes: Dictionary = {}
static var materials: Dictionary = {}

static func size_of(kind: String) -> Vector3:
	return DEFINITIONS.get(kind, DEFINITIONS["desk"])[1]

static func footprint(kind: String) -> Rect2:
	var size := size_of(kind)
	return Rect2(Vector2(-size.x, -size.z) * SCALE * 0.5, Vector2(size.x, size.z) * SCALE)

static func configure(source: Node2D, kind: String) -> void:
	source.set_meta(&"office_furniture_kind", kind)
	# Built-in counters and plumbing are fixtures, even when their 2D source
	# comes from a reusable breakable furniture scene.
	if kind in ["counter", "appliance_counter", "reception", "sink", "washbasin", "toilet"] and source is RigidBody2D:
		var fixture := source as RigidBody2D
		fixture.set_meta(&"fixed_furniture_fixture", true)
		fixture.lock_rotation = true
		fixture.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		fixture.freeze = true
		fixture.remove_from_group(&"pushable_prop")
	var bounds := footprint(kind)
	for path in ["CollisionShape2D", "Hurtbox/CollisionShape2D"]:
		var collider := source.get_node_or_null(path) as CollisionShape2D
		if collider != null:
			var shape := RectangleShape2D.new()
			shape.size = bounds.size
			collider.shape = shape
			collider.position = Vector2.ZERO
			collider.scale = Vector2.ONE
	var hurtbox := source.get_node_or_null("Hurtbox") as Node2D
	if hurtbox != null:
		hurtbox.scale = Vector2.ONE
		hurtbox.position = Vector2.ZERO
	source.set("furniture_size_category", int(DEFINITIONS[kind][2]))
	source.set("vaultable", size_of(kind).y < 1.1)
	if kind in ["chair", "office_chair"]:
		source.set("is_swivel_chair", true)
		if source is RigidBody2D:
			source.mass = 1.25
			source.linear_damp = 1.2
			source.angular_damp = 9.0
			source.set("bullet_knockback", 120.0)

static func resolved_kind(source: Node2D) -> String:
	if source.has_meta(&"office_furniture_kind"):
		return String(source.get_meta(&"office_furniture_kind"))
	var name := source.scene_file_path.get_file().to_lower()
	for pair in [["filing", "cabinet"], ["storage", "cabinet"], ["wardrobe", "cabinet"], ["fridge", "fridge"], ["chair", "chair"], ["table", "coffee_table"], ["bed", "sofa"], ["box", "box"], ["trash", "bin"]]:
		if name.contains(pair[0]):
			return pair[1]
	return "desk"

static func height_offset(source: Node2D) -> float:
	var result := 0.0
	for property in ["fake_height", "sky_drop_height"]:
		var value: Variant = source.get(property)
		if value is float or value is int:
			result = maxf(result, float(value))
	return result

static func shot_hit(source: Node2D, start: Vector2, end: Vector2, height_pixels: float) -> Dictionary:
	# Architectural glass/sills must never inherit the fallback desk profile.
	if source.has_method("get_projectile_blocking_height"):
		if height_pixels < 0.0 or height_pixels > float(source.call("get_projectile_blocking_height")) * SCALE:
			return {}
		var shape_node := source.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			return {}
		var rect: Rect2 = source.call("get_projectile_blocking_rect", height_pixels / SCALE) if source.has_method("get_projectile_blocking_rect") else shape_node.shape.get_rect()
		var t := _segment_rect(shape_node.to_local(start), shape_node.to_local(end), rect)
		return {"position": start.lerp(end, t)} if t >= 0.0 else {}
	if source.get("destroyed") == true:
		return {}
	var kind := resolved_kind(source)
	var local_height := (height_pixels - height_offset(source)) / SCALE
	if local_height < 0.0:
		return {}
	var regions: Array[Rect2] = []
	var body_rect := footprint(kind)
	if not source.has_meta(&"office_furniture_kind"):
		var collision := source.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null and collision.shape != null:
			body_rect = Rect2(collision.position - collision.shape.get_rect().size * collision.scale * 0.5, collision.shape.get_rect().size * collision.scale)
	if local_height <= size_of(kind).y:
		regions.append(body_rect)
	if kind == "workstation" and local_height >= 0.74 and local_height <= 1.3:
		regions.append(Rect2(Vector2(-0.32, -0.35) * SCALE, Vector2(0.64, 0.24) * SCALE))
	var local_start := source.to_local(start)
	var local_end := source.to_local(end)
	var best := 2.0
	for rect in regions:
		var t := _segment_rect(local_start, local_end, rect)
		if t >= 0.0:
			best = minf(best, t)
	return {"position": start.lerp(end, best)} if best <= 1.0 else {}

static func _segment_rect(start: Vector2, end: Vector2, rect: Rect2) -> float:
	var direction := end - start
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if absf(direction[axis]) < 0.00001:
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]:
				return -1.0
		else:
			var a := (rect.position[axis] - start[axis]) / direction[axis]
			var b := (rect.end[axis] - start[axis]) / direction[axis]
			enter = maxf(enter, minf(a, b))
			leave = minf(leave, maxf(a, b))
			if leave < enter:
				return -1.0
	return enter

static func material(color: Color, glow: bool = false) -> Material:
	return PIXEL_MATERIALS.make(color, "metal", true, glow)

static func make_visual_for_style(kind: String, style: String, legacy_authored := false, legacy_pixel := false) -> Node3D:
	match style:
		"approved_office":
			return make_visual(kind, true, true)
		"approved_room":
			return make_visual(kind, true, false)
		_:
			return make_visual(kind, legacy_authored, legacy_pixel)

static func make_visual(kind: String, authored_details := false, pixel_sample := false) -> Node3D:
	var low_pixel = preload("res://scripts/dream/office_low_pixel_art.gd")
	if kind=="water_dispenser":
		return preload("res://scripts/dream/office_room_low_pixel_art.gd").make_visual(kind)
	if pixel_sample and low_pixel.enabled and low_pixel.supports(kind):
		return low_pixel.make_visual(kind)
	if authored_details and not pixel_sample:
		var room_art = preload("res://scripts/dream/office_room_low_pixel_art.gd")
		if room_art.enabled and (room_art.supports(kind) or kind in ["workstation", "chair"]):
			return room_art.make_visual(kind)
	if kind in ["chair", "office_chair"]:
		return low_pixel.make_visual("chair")
	var root := Node3D.new()
	var def: Array = DEFINITIONS[kind]
	var size: Vector3 = def[1]
	if not String(def[0]).is_empty():
		_add_model(root, String(def[0]), Vector3(size.x, size.y, .65) if kind == "cabinet_open" else size, Vector3.ZERO)
	else:
		var base := (Color(.54, .58, .58) if authored_details else Color(.40, .43, .43)) if kind == "server" else Color(.66, .66, .61)
		_box(root, size, Vector3(0, size.y * 0.5, 0), base)
		match kind:
			"stall_door":
				_box(root, Vector3(.08, 1.55, .12), Vector3(-.38, .775, 0), Color(.25, .29, .29))
				_box(root, Vector3(.07, .045, .05), Vector3(.23, .82, .07), Color(.19, .22, .21))
			"server":
				for row in 7:
					_box(root, Vector3(0.84, 0.15, 0.035), Vector3(0, 0.25 + row * 0.23, 0.445), Color(.26, .30, .31) if authored_details else Color(.16, .19, .20))
					_box(root, Vector3(0.05, 0.03, 0.04), Vector3(0.3, 0.27 + row * 0.23, 0.47), Color(0.4, 0.7, 0.62), true)
			"copier":
				_box(root, Vector3(1.1, 0.16, 0.68), Vector3(0, 1.13, -0.08), Color(0.25, 0.29, 0.29))
				_box(root, Vector3(0.95, 0.09, 0.03), Vector3(0, 0.45, 0.46), Color(0.24, 0.26, 0.27))
			"whiteboard":
				_box(root, Vector3(1.86, 1.0, 0.025), Vector3(0, 1.05, 0.09), Color(0.88, 0.9, 0.85))
			"reception":
				_box(root, Vector3(size.x + 0.08, 0.07, size.z + 0.1), Vector3(0, size.y, 0), Color(0.25, 0.19, 0.15))
	if kind == "workstation":
		_add_model(root, "computerScreen", Vector3(0.64, 0.56, 0.24), Vector3(0, 0.74, -0.23))
	if kind == "cabinet_open":
		# One deliberately disturbed cabinet. Its extended footprint is used by
		# the same physics/shot-height definition as every other furniture item.
		_box(root, Vector3(1.12, 0.16, 0.31), Vector3(0, 0.55, 0.54), Color(0.58, 0.60, 0.54))
		_box(root, Vector3(0.18, 0.03, 0.035), Vector3(0, 0.55, 0.71), Color(0.16, 0.18, 0.18))
	if authored_details:
		var details := preload("res://scripts/dream/office_detail_art.gd").furniture(kind)
		if details != null:
			root.add_child(details)
		_apply_sample_surface(root)
	return root

static func _apply_sample_surface(root: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	for mesh in meshes:
		if mesh.material_override is ShaderMaterial:
			mesh.material_override = PIXEL_MATERIALS.sample_furniture_variant(mesh.material_override)
		else:
			for surface in mesh.mesh.get_surface_count():
				var active := mesh.get_active_material(surface)
				if active is ShaderMaterial:
					mesh.set_surface_override_material(surface, PIXEL_MATERIALS.sample_furniture_variant(active))

static func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color, glow: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color, glow)
	instance.position = position
	parent.add_child(instance)

static func _add_model(parent: Node3D, model: String, target_size: Vector3, origin: Vector3) -> void:
	if not scenes.has(model):
		scenes[model] = load(MODEL_ROOT + model + ".glb")
	var node := (scenes[model] as PackedScene).instantiate() as Node3D
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(node, meshes)
	var bounds := AABB()
	var first := true
	for mesh in meshes:
		var transform := _relative_transform(mesh, node)
		var local_bounds: AABB = transform * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(surface) as StandardMaterial3D
			if mat != null:
				var key := str(mat.get_instance_id()) + ":office:" + model
				if not materials.has(key):
					var style := "wood"
					if model.begins_with("kitchen") or model == "trashcan": style = "metal"
					elif model.begins_with("bathroom") or model == "toilet": style = "tile"
					elif model.begins_with("lounge") or model == "chairDesk": style = "fabric"
					var copy := PIXEL_MATERIALS.make(mat.albedo_color * Color(.78, .79, .77), style, true)
					materials[key] = copy
				mesh.set_surface_override_material(surface, materials[key])
	var ratio := target_size / bounds.size.max(Vector3.ONE * 0.001)
	node.scale = ratio
	node.position = origin - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * ratio
	parent.add_child(node)

static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current != root and current != null:
		result = current.transform * result
		current = current.get_parent() as Node3D
	return result

static func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node)
	for child in node.get_children():
		_collect_meshes(child, output)
