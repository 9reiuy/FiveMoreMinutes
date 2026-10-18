extends RefCounted
## Diagnostics only. Engine shader TIME advances using scaled_step in the
## installed engine's Main::iteration; pause alone does not freeze it.
static func _collect(node: Node, nodes: Array[Node]) -> void:
	nodes.append(node)
	for child in node.get_children():
		_collect(child, nodes)
static func freeze(tree: SceneTree) -> Dictionary:
	var state := {"paused": tree.paused, "time_scale": Engine.time_scale, "nodes": [], "modes": [], "particles": [], "speeds": []}
	var nodes: Array[Node] = []
	_collect(tree.root, nodes)
	for node in nodes:
		state.nodes.append(weakref(node))
		state.modes.append(node.process_mode)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is CPUParticles3D or node is CPUParticles2D or node is GPUParticles3D or node is GPUParticles2D:
			state.particles.append(weakref(node))
			state.speeds.append(node.speed_scale)
			node.speed_scale = 0.0
	tree.paused = true
	Engine.time_scale = 0.0
	return state
static func restore(tree: SceneTree, state: Dictionary) -> void:
	for index in state.particles.size():
		var particle: Node = state.particles[index].get_ref()
		if is_instance_valid(particle):
			particle.speed_scale = state.speeds[index]
	for index in state.nodes.size():
		var node: Node = state.nodes[index].get_ref()
		if is_instance_valid(node):
			node.process_mode = state.modes[index]
	Engine.time_scale = state.time_scale
	tree.paused = state.paused
static func difference(a: Image, b: Image) -> Dictionary:
	if a.get_size() != b.get_size() or a.get_format() != b.get_format():
		return {"exact": false, "format_or_size_mismatch": true}
	var left := a.get_data()
	var right := b.get_data()
	var pixels := a.get_width() * a.get_height()
	var stride := left.size() / pixels
	var changed_bytes := 0
	var changed_pixels := 0
	var low := Vector2i(a.get_width(), a.get_height())
	var high := Vector2i(-1, -1)
	for pixel in pixels:
		var changed := false
		for channel in stride:
			var offset: int = pixel * stride + channel
			if left[offset] != right[offset]:
				changed_bytes += 1
				changed = true
		if changed:
			changed_pixels += 1
			var point := Vector2i(pixel % a.get_width(), pixel / a.get_width())
			low = Vector2i(mini(low.x, point.x), mini(low.y, point.y))
			high = Vector2i(maxi(high.x, point.x), maxi(high.y, point.y))
	return {"exact": changed_bytes == 0, "changed_bytes": changed_bytes, "changed_pixels": changed_pixels, "bbox": [low.x, low.y, high.x - low.x + 1, high.y - low.y + 1] if changed_pixels else []}
static func save(images: Dictionary, prefix: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(prefix.get_base_dir()))
	var paths := {}
	for label in images:
		var path: String = prefix + "_" + label + ".png"
		var saved: int = images[label].save_png(path)
		paths[label] = path if saved == OK else "SAVE_ERROR_%d" % saved
	return paths
