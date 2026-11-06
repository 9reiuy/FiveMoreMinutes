extends "res://scripts/dream/fire_extinguisher_system.gd"
## Same smoke simulation/shape/coverage. Memoize repeated cell-edge decisions
## within the native topology snapshot instead of rebuilding edge keys per cloud.
var _edge_results: Dictionary = {}
var _memoizing := false
var cache_hits := 0
var cache_misses := 0
var validate_edges := false
var validated_edges := 0
var edge_mismatches := 0

static func adopt(controller: Node3D) -> void:
	var state: Dictionary = {}
	# Rebind the native draw hook to this script instance; retaining the old
	# script-method callable would keep the replaced script alive on shutdown.
	var draw_flags := 0
	var had_draw_hook := false
	for connection in RenderingServer.get_signal_connection_list(&"frame_pre_draw"):
		var callback: Callable = connection.callable
		if callback.get_object() == controller and callback.get_method() == &"_flush_before_draw":
			draw_flags = connection.flags
			had_draw_hook = true
			RenderingServer.frame_pre_draw.disconnect(callback)
	for property in controller.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			state[property.name] = controller.get(property.name)
	controller.set_script(load("res://scripts/preview/woo_smoke_controller.gd"))
	for key in state: controller.set(key, state[key])
	if had_draw_hook: RenderingServer.frame_pre_draw.connect(Callable(controller, &"_flush_before_draw"), draw_flags)

func _capture_fusion_connectivity(rendered: Array[Dictionary]) -> Dictionary:
	# This native call is synchronous. Cache only inside that one immutable
	# snapshot, so even a breach later in this physics tick sees fresh rules.
	_edge_results.clear()
	_memoizing = true
	var result := super._capture_fusion_connectivity(rendered)
	_memoizing = false
	_edge_results.clear()
	return result

func refresh_doors() -> void:
	_edge_results.clear()
	super.refresh_doors()

func invalidate_topology(floor_layout_changed := false) -> void:
	_edge_results.clear()
	super.invalidate_topology(floor_layout_changed)

func can_cross(from: Vector2i, to: Vector2i) -> bool:
	var key := Vector4i(from.x, from.y, to.x, to.y)
	var result: bool
	if not _memoizing:
		result = super.can_cross(from, to)
	elif _edge_results.has(key):
		cache_hits += 1
		result = _edge_results[key]
	else:
		cache_misses += 1
		result = super.can_cross(from, to)
		_edge_results[key] = result
	if validate_edges:
		validated_edges += 1
		if result != super.can_cross(from, to): edge_mismatches += 1
	return result
