extends RefCounted
## Toggle only transform-write scheduling on a frozen actual game state.
const BRIDGE = preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
const FREEZE = preload("res://tests/support/frozen_render_comparison.gd")
static func _collect(node: Node, results: Array[Node3D]) -> void:
	if node.get_script() == BRIDGE and node.get("configured") == true:
		results.append(node)
	for child in node.get_children():
		_collect(child, results)
static func _capture(tree: SceneTree, bridges: Array[Node3D], active_before_freeze: Array[bool], optimized: bool, stats: Dictionary) -> Image:
	for index in bridges.size():
		var bridge := bridges[index]
		bridge.set_meta(&"test_capture_transform_optimization", optimized)
		if active_before_freeze[index] and is_instance_valid(bridge.source_actor) and not bridge.source_actor.is_queued_for_deletion():
			bridge._process(0)
			stats.manual_sync_count += 1
	for frame in 8:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()
static func run(tree: SceneTree, world: Node3D) -> Dictionary:
	var bridges: Array[Node3D] = []
	_collect(world, bridges)
	var active_before_freeze: Array[bool] = []
	var prior_flags: Array[bool] = []
	var prior_flag_present: Array[bool] = []
	for bridge in bridges:
		active_before_freeze.append(bridge.is_processing() and bridge.process_mode != Node.PROCESS_MODE_DISABLED and bridge.room_presentation_active)
		prior_flags.append(bool(bridge.get_meta(&"test_capture_transform_optimization", false)))
		prior_flag_present.append(bridge.has_meta(&"test_capture_transform_optimization"))
	var freeze_state := FREEZE.freeze(tree)
	var stats := {"manual_sync_count": 0}
	# Let queued setup and render commands settle before the exact old-old gate.
	await _capture(tree, bridges, active_before_freeze, false, stats)
	var baseline := await _capture(tree, bridges, active_before_freeze, false, stats)
	var control := await _capture(tree, bridges, active_before_freeze, false, stats)
	var candidate := await _capture(tree, bridges, active_before_freeze, true, stats)
	var restored := await _capture(tree, bridges, active_before_freeze, false, stats)
	for index in bridges.size():
		if prior_flag_present[index]:
			bridges[index].set_meta(&"test_capture_transform_optimization", prior_flags[index])
		else:
			bridges[index].remove_meta(&"test_capture_transform_optimization")
	var control_diff: Dictionary = FREEZE.difference(baseline, control)
	var candidate_diff: Dictionary = FREEZE.difference(control, candidate)
	var restore_diff: Dictionary = FREEZE.difference(control, restored)
	var prefix := "res://.runtime/perf_delivery_20261013/diagnostics/bridge_transform_%d_%d" % [int(world.active_seed), Time.get_ticks_msec()]
	var paths: Dictionary = FREEZE.save({"baseline": baseline, "old_old_control": control, "candidate": candidate, "restored": restored}, prefix)
	FREEZE.restore(tree, freeze_state)
	var result := {"scope": "Frozen formal Camera pixel parity; no live performance claim", "bridges": bridges.size(), "active_before_freeze": active_before_freeze.count(true), "manual_sync_count": stats.manual_sync_count, "size": str(baseline.get_size()), "comparison_valid": control_diff.exact and restore_diff.exact, "old_old_control": control_diff, "candidate_difference": candidate_diff, "restore_difference": restore_diff, "candidate_exact": candidate_diff.exact if control_diff.exact and restore_diff.exact else null, "restore_exact": restore_diff.exact, "images": paths}
	print("BRIDGE_TRANSFORM_CAMERA_PARITY ", JSON.stringify(result))
	return result
