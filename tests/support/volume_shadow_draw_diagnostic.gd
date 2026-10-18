extends RefCounted
## Read-only rendering diagnosis on a frozen real game state. Hiding shadows
## intentionally changes presentation and is never an accepted performance run.
const VOLUME = preload("res://scripts/dream/actor_volume_shadow.gd")
const FREEZE = preload("res://tests/support/frozen_render_comparison.gd")
static func _collect(node: Node, results: Array[Node3D]) -> void:
	if node.get_script() == VOLUME:
		results.append(node)
	for child in node.get_children():
		_collect(child, results)
static func _sample(tree: SceneTree, viewport: Viewport) -> Dictionary:
	var calls: Array[int] = []
	var cpu: Array[float] = []
	for frame in 240:
		await tree.process_frame
		if frame < 60:
			continue
		calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
	calls.sort()
	cpu.sort()
	return {"draw_calls_median": calls[calls.size() / 2], "world_render_cpu_median_ms": cpu[cpu.size() / 2], "samples": calls.size()}
static func run(tree: SceneTree, world: Node3D, viewport: Viewport) -> Dictionary:
	var freeze_state := FREEZE.freeze(tree)
	var volumes: Array[Node3D] = []
	_collect(world, volumes)
	var prior_visibility: Array[bool] = []
	var active_count := 0
	for volume in volumes:
		prior_visibility.append(volume.visible)
		if volume.is_visible_in_tree():
			active_count += 1
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	var baseline := await _sample(tree, viewport)
	await RenderingServer.frame_post_draw
	var before: Image = tree.root.get_texture().get_image()
	var control_sample := await _sample(tree, viewport)
	await RenderingServer.frame_post_draw
	var control: Image = tree.root.get_texture().get_image()
	for volume in volumes:
		volume.hide()
	var hidden := await _sample(tree, viewport)
	await RenderingServer.frame_post_draw
	var hidden_image: Image = tree.root.get_texture().get_image()
	for index in volumes.size():
		volumes[index].visible = prior_visibility[index]
	var restored := await _sample(tree, viewport)
	await RenderingServer.frame_post_draw
	var after: Image = tree.root.get_texture().get_image()
	var control_diff: Dictionary = FREEZE.difference(before, control)
	var restore_diff: Dictionary = FREEZE.difference(control, after)
	var prefix := "res://.runtime/perf_delivery_20261013/diagnostics/volume_shadow_%d_%d" % [int(world.active_seed), Time.get_ticks_msec()]
	var paths: Dictionary = FREEZE.save({"baseline": before, "old_old_control": control, "hidden": hidden_image, "restored": after}, prefix)
	FREEZE.restore(tree, freeze_state)
	var result := {"scope": "Frozen real state shadow hiding diagnostic only; not gameplay or FPS acceptance", "volume_count": volumes.size(), "active_volume_count": active_count, "comparison_valid": control_diff.exact and restore_diff.exact, "baseline": baseline, "old_old_control_sample": control_sample, "old_old_control": control_diff, "hidden": hidden, "restored": restored, "restore_difference": restore_diff, "restore_image_exact": restore_diff.exact, "images": paths}
	print("VOLUME_DRAW_DIAGNOSTIC ", JSON.stringify(result))
	return result
