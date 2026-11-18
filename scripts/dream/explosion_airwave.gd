extends Node
## One bounded pressure-wave sampler per actual Camera. The existing world
## finish consumes its uniforms; this creates no canvas, viewport or light.
const HOST_NAME := &"_ExplosionAirwave"
const PUBLISHER := &"explosion_airwave_publisher"
const LIMIT := 8
const LIFETIME := .65
var owners: Dictionary = {}
var enabled := true
var shapes := PackedVector4Array()
var motions := PackedVector4Array()
var count := 0
var material_ref: WeakRef

static func request(camera: Camera3D, source: Node3D, active: bool) -> Node:
	if not is_instance_valid(camera): return null
	var host := camera.get_node_or_null(NodePath(String(HOST_NAME)))
	if host == null:
		if not active: return null
		host = load("res://scripts/dream/explosion_airwave.gd").new()
		host.name = HOST_NAME
		camera.add_child(host)
	if active: host.owners[source.get_instance_id()] = weakref(source)
	else: host.owners.erase(source.get_instance_id())
	var material: ShaderMaterial = host.material_ref.get_ref() if host.material_ref != null else null
	if material != null: host.publish(material)
	return host

func _ready() -> void:
	shapes.resize(LIMIT)
	motions.resize(LIMIT)
	set_process(false)

func publish(material: ShaderMaterial) -> void:
	var camera := get_parent() as Camera3D
	var previous_count := count
	var previous_material: ShaderMaterial = material_ref.get_ref() if material_ref != null else null
	if previous_material != material: material_ref = weakref(material)
	count = 0
	shapes.fill(Vector4.ZERO)
	motions.fill(Vector4.ZERO)
	var waves: Array[Dictionary] = []
	for id: int in owners.keys():
		var source := owners[id].get_ref() as Node3D
		if not is_instance_valid(source) or not source.is_inside_tree():
			owners.erase(id)
			continue
		if not enabled or not source.is_visible_in_tree() or not is_instance_valid(camera) or not camera.is_current(): continue
		for burst: Dictionary in source.bursts:
			var age: float = burst.age
			if age < .015 or age >= LIFETIME: continue
			waves.append({"age":age,"source":source,"burst":burst})
	# More than one pool can feed a Camera. Favor fresh fronts within the same
	# eight-wave budget rather than rendering an extra pass for every pool.
	waves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.age) < float(b.age))
	for wave: Dictionary in waves:
		if count >= LIMIT: break
		var source: Node3D = wave.source
		var burst: Dictionary = wave.burst
		var age: float = wave.age
		var at := source.to_global(Vector3(burst.at) + Vector3.UP * .6)
		if camera.is_position_behind(at): continue
		var scale_factor := float(burst.strength) * .75
		var t := clampf((age - .015) / (LIFETIME - .015), 0.0, 1.0)
		var radius := (.12 + 7.1 * pow(t, .65)) * scale_factor
		var center := camera.unproject_position(at)
		var radius_px := center.distance_to(camera.unproject_position(at + camera.global_basis.x * radius))
		if not is_finite(radius_px) or radius_px <= .01: continue
		var width := clampf(radius_px * .13 + 3.5, 5.0, 18.0)
		var margin := radius_px + width * 3.1 + 8.0
		var screen := camera.get_viewport().get_visible_rect().size
		if not Rect2(-Vector2.ONE * margin, screen + Vector2.ONE * margin * 2.0).has_point(center): continue
		var gain := smoothstep(.015, .06, age) * (1.0 - smoothstep(.09, LIFETIME, age))
		shapes[count] = Vector4(center.x, center.y, radius_px, width)
		motions[count] = Vector4(5.8 * sqrt(scale_factor) * gain, t, 0, 0)
		count += 1
	var publisher: Variant = material.get_meta(PUBLISHER) if material.has_meta(PUBLISHER) else null
	var was_publisher: bool = publisher is WeakRef and publisher.get_ref() == self
	if not is_instance_valid(camera) or not camera.is_current():
		if was_publisher: material.set_shader_parameter("air_count", 0)
		return
	if not was_publisher: material.set_meta(PUBLISHER, weakref(self))
	if count == 0 and previous_count == 0 and previous_material == material and was_publisher: return
	material.set_shader_parameter("air_count", count)
	material.set_shader_parameter("air_shape", shapes)
	material.set_shader_parameter("air_motion", motions)

func _exit_tree() -> void:
	var material: ShaderMaterial = material_ref.get_ref() if material_ref != null else null
	if material != null:
		var publisher: Variant = material.get_meta(PUBLISHER) if material.has_meta(PUBLISHER) else null
		if publisher is WeakRef and publisher.get_ref() == self:
			material.set_shader_parameter("air_count", 0)
			material.remove_meta(PUBLISHER)
