extends SceneTree
const BRIDGE = preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
class Counter extends Node2D:
	var transform_notifications := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			transform_notifications += 1
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func state(node: Node2D) -> Array:
	var result: Array = [node.transform, node.visible, node.modulate, node.self_modulate, node.z_index, node.z_as_relative, node.material, node.texture_filter]
	if node is Sprite2D:
		result.append_array([node.texture, node.frame, node.hframes, node.vframes, node.offset, node.centered, node.region_rect, node.flip_h, node.flip_v])
	for child in node.get_children():
		result.append([child.name, state(child)])
	return result
func run() -> void:
	var bridge := BRIDGE.new()
	root.add_child(bridge)
	var source := Counter.new()
	var baseline := Counter.new()
	var candidate := Counter.new()
	for node in [source, baseline, candidate]:
		node.name = "Visual"
		root.add_child(node)
		for index in 8:
			var child := Counter.new()
			child.name = "Part%d" % index
			child.set_notify_local_transform(true)
			node.add_child(child)
			var sprite := Sprite2D.new()
			sprite.name = "Sprite"
			child.add_child(sprite)
	for pose in 96:
		source.position = Vector2(pose, -pose)
		source.get_node("Part0").position = Vector2(float(pose % 5), -.125 * pose)
		source.get_node("Part1").rotation = pose * .035
		source.get_node("Part2").scale = Vector2(-.8, 1.1)
		source.get_node("Part3").visible = pose % 3 != 0
		source.get_node("Part4/Sprite").flip_h = pose % 2 == 0
		source.get_node("Part5").modulate = Color(.5, .6, .7, .8)
		bridge._sync_node(source, baseline)
		bridge._sync_node(source, candidate, false, true)
		check(state(baseline) == state(candidate), "Exact recursive pose state %d" % pose)
	var counter: Counter = candidate.get_node("Part0")
	var count_before := counter.transform_notifications
	bridge._sync_node(source, candidate, false, true)
	check(counter.transform_notifications == count_before, "Equal transform emits no additional local notification")
	source.get_node("Part0").position += Vector2(.00001, 0)
	bridge._sync_node(source, candidate, false, true)
	check(counter.transform == source.get_node("Part0").transform, "Tiny distinct transform is copied exactly")
	# Root formal capture is authoritative; descendants still synchronize.
	var final_capture := Transform2D(.42, Vector2(128, 96))
	bridge._sync_node(source, baseline)
	baseline.transform = final_capture
	bridge._sync_node(source, candidate, true, true)
	candidate.transform = final_capture
	check(state(baseline) == state(candidate), "Skipping temporary root transform preserves final capture hierarchy")
	var added := Sprite2D.new()
	added.name = "LateEquipment"
	source.add_child(added)
	bridge._sync_node(source, baseline)
	bridge._sync_node(source, candidate, false, true)
	check(state(baseline) == state(candidate), "New visual child is copied")
	added.free()
	source.get_node("Part6").free()
	bridge._sync_node(source, baseline)
	bridge._sync_node(source, candidate, false, true)
	check(state(baseline) == state(candidate), "Removed child is pruned identically")
	for group in 3:
		var optimized := group == 1
		var target := candidate if optimized else baseline
		var started := Time.get_ticks_usec()
		for iteration in 4096:
			bridge._sync_node(source, target, false, optimized)
		print("BRIDGE_TRANSFORM_CPU optimized=", optimized, " elapsed_us=", Time.get_ticks_usec() - started)
	source.free()
	baseline.free()
	candidate.free()
	bridge.free()
	print("Bridge transform sync: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
