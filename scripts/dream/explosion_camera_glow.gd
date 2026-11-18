extends Node
## One temporary environment owner per actual Camera, shared by burst pools.
## Existing scene glow is retained; an otherwise unlit HDR glow pass is borrowed
## only while explosions exist, and all non-glow environment values stay live.
const HOST_NAME := &"_ExplosionCameraGlow"
var owners: Dictionary = {}
var original_override: Environment
var owned: Environment
var property_names: Array[StringName] = []
var elapsed := 0.0

static func request(camera: Camera3D, owner: Node, enabled: bool) -> Node:
	if not is_instance_valid(camera): return null
	var host := camera.get_node_or_null(NodePath(String(HOST_NAME)))
	if host == null:
		if not enabled: return null
		host = load("res://scripts/dream/explosion_camera_glow.gd").new()
		host.name = HOST_NAME
		camera.add_child(host)
	host.set_owner_requested(owner, enabled)
	return host

static func scene_environment(camera: Camera3D) -> Environment:
	# Scene optics must see their own override beneath our temporary glow copy.
	var host := camera.get_node_or_null(NodePath(String(HOST_NAME)))
	if host != null and host.owned != null and camera.environment == host.owned:
		return host.original_override
	return camera.environment

static func set_scene_environment(camera: Camera3D, environment: Environment) -> void:
	var host := camera.get_node_or_null(NodePath(String(HOST_NAME)))
	if host != null and host.owned != null and camera.environment == host.owned:
		host.original_override = environment
		host._synchronize()
	else:
		camera.environment = environment

func _ready() -> void:
	set_process(false)

func set_owner_requested(owner: Node, enabled: bool) -> void:
	if enabled:
		owners[owner.get_instance_id()] = weakref(owner)
		_synchronize()
		set_process(true)
	else:
		owners.erase(owner.get_instance_id())
		if owners.is_empty(): _restore()

func _base_environment(camera: Camera3D) -> Environment:
	if owned != null and camera.environment != owned:
		# An external presentation change owns the new override, not our copy.
		owned = null
		original_override = camera.environment
	if owned == null: original_override = camera.environment
	if original_override != null: return original_override
	var world := camera.get_world_3d()
	return world.environment if world.environment != null else world.fallback_environment

func _synchronize() -> void:
	var camera := get_parent() as Camera3D
	if not is_instance_valid(camera): return
	var source := _base_environment(camera)
	if source == null: return
	if source.glow_enabled:
		# Do not strengthen or retune a scene which already supplies its glow.
		if owned != null and camera.environment == owned: camera.environment = original_override
		owned = null
		return
	if owned == null:
		owned = source.duplicate(false)
		camera.environment = owned
	if property_names.is_empty():
		for field: Dictionary in source.get_property_list():
			var key := StringName(field.name)
			if (int(field.usage) & PROPERTY_USAGE_STORAGE) == 0: continue
			if String(key).begins_with("resource_") or key == &"script": continue
			if key in [&"glow_enabled", &"glow_intensity", &"glow_bloom", &"glow_hdr_threshold"]: continue
			property_names.append(key)
	for key: StringName in property_names:
		var value: Variant = source.get(key)
		if owned.get(key) != value: owned.set(key, value)
	owned.glow_enabled = true
	owned.glow_intensity = .6
	owned.glow_bloom = 0.0
	owned.glow_hdr_threshold = 4.0

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < .10: return
	elapsed = 0.0
	for id: int in owners.keys():
		if owners[id].get_ref() == null: owners.erase(id)
	if owners.is_empty(): _restore()
	else: _synchronize()

func _restore() -> void:
	var camera := get_parent() as Camera3D
	if is_instance_valid(camera) and owned != null and camera.environment == owned:
		camera.environment = original_override
	owned = null
	original_override = null
	set_process(false)

func _exit_tree() -> void:
	_restore()
