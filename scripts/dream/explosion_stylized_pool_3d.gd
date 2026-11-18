extends Node3D
## Stable visual API. Gameplay hazards/audio remain in their existing owners.
const BURST := preload("res://scripts/dream/explosion_stylized_burst_3d.gd")
const GLOW := preload("res://scripts/dream/explosion_camera_glow.gd")
const AIR := preload("res://scripts/dream/explosion_airwave.gd")
const LIMIT := 8
const DURATION := 2.8
var bursts: Array[Dictionary] = []
var pool: Array[Node3D] = []
var rejected := 0
var serial := 0
var clock := 0.0
var explicit_surface := false
var surface_y := 0.0
var ground_marks := true
var glow_camera: WeakRef

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	for i in LIMIT:
		var node := BURST.new()
		node.name = "StylizedBurst_%d" % i
		add_child(node)
		pool.append(node)

func set_surface_context(height: float, marks: bool = true) -> void:
	if not is_finite(height): return
	explicit_surface = true
	surface_y = height
	ground_marks = marks

func _surface_at(at: Vector3) -> Dictionary:
	if explicit_surface: return {"height": surface_y, "marks": ground_marks}
	var global_at := to_global(at)
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Node3D and (ancestor.has_method("get_gameplay_world_position") or ancestor.has_method("_floor_height_at")):
			var local_at: Vector3 = ancestor.to_local(global_at)
			var height := 0.0
			if ancestor.has_method("_floor_height_at"):
				var result: Variant = ancestor.call("_floor_height_at", Vector2(local_at.x, local_at.z))
				if (result is float or result is int) and is_finite(float(result)): height = float(result)
			var global_floor: Vector3 = ancestor.to_global(Vector3(local_at.x, height, local_at.z))
			var marks := absf(global_at.y - global_floor.y) <= 1.75
			if ancestor.has_method("get_gameplay_world_position") and ancestor.has_method("_room_id_at_position"):
				var zero: Vector3 = ancestor.call("get_gameplay_world_position", Vector2.ZERO, 0.0)
				var right: Vector3 = ancestor.call("get_gameplay_world_position", Vector2.RIGHT, 0.0)
				var down: Vector3 = ancestor.call("get_gameplay_world_position", Vector2.DOWN, 0.0)
				var mapping := Transform2D(Vector2(right.x - zero.x, right.z - zero.z), Vector2(down.x - zero.x, down.z - zero.z), Vector2(zero.x, zero.z))
				if absf(mapping.determinant()) > .00000001:
					var pixels := mapping.affine_inverse() * Vector2(global_at.x, global_at.z)
					marks = marks and int(ancestor.call("_room_id_at_position", pixels)) >= 0
			return {"height": to_local(global_floor).y, "marks": marks}
		ancestor = ancestor.get_parent()
	var floor_at := Vector3(global_at.x, 0, global_at.z)
	return {"height": to_local(floor_at).y, "marks": absf(global_at.y) <= 1.75}

func emit(at: Vector3, strength: float, seed_value: int = 0) -> bool:
	if not at.is_finite() or not is_finite(strength): return false
	if bursts.size() >= LIMIT:
		rejected += 1
		return false
	var slot := 0
	while bursts.any(func(burst: Dictionary) -> bool: return int(burst.slot) == slot): slot += 1
	serial += 1
	strength = clampf(strength, .25, 3.0)
	var seed_id := seed_value if seed_value != 0 else serial * 73856093
	bursts.append({"id": serial, "slot": slot, "at": at, "strength": strength, "age": 0.0, "drift": Vector3.ZERO})
	if not pool.is_empty():
		var ground := _surface_at(at)
		pool[slot].set_surface_context(float(ground.height), bool(ground.marks))
		pool[slot].activate(at, strength, seed_id)
	_sync_glow(true)
	return true

func advance(delta: float, wind: Vector3) -> void:
	if delta <= 0.0 or not is_finite(delta): return
	clock += delta
	for i in range(bursts.size() - 1, -1, -1):
		var burst: Dictionary = bursts[i]
		burst.age += delta
		if float(burst.age) >= DURATION:
			if not pool.is_empty(): pool[int(burst.slot)].retire()
			bursts.remove_at(i)
			continue
		if wind.is_finite(): burst.drift += wind * delta * float(burst.age) * .20
		if not pool.is_empty():
			var node: Node3D = pool[int(burst.slot)]
			node.position = Vector3(burst.at) + Vector3(burst.drift)
			node.set_age(float(burst.age))
	_sync_glow(not bursts.is_empty())

func upload() -> void:
	for burst in bursts:
		if not pool.is_empty(): pool[int(burst.slot)].sync_transform()
	_sync_glow(not bursts.is_empty())

func flash_energy(burst: Dictionary) -> float:
	var age: float = burst.age
	return 3.6 * exp(-age * 8.0) * (1.0 - smoothstep(.35, .60, age))

func _sync_glow(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	var old: Camera3D = glow_camera.get_ref() if glow_camera != null else null
	var camera: Camera3D = get_viewport().get_camera_3d() if enabled and is_inside_tree() else null
	if old != null and old != camera:
		GLOW.request(old, self, false)
		AIR.request(old, self, false)
	if camera != null and camera != old:
		GLOW.request(camera, self, true)
		AIR.request(camera, self, true)
		glow_camera = weakref(camera)
	elif camera == null:
		glow_camera = null

func clear() -> void:
	for node in pool: node.retire()
	bursts.clear()
	serial = 0
	clock = 0.0
	_sync_glow(false)

func _exit_tree() -> void:
	_sync_glow(false)
