extends Node
## Explicit 3D Dream scope, also for F6 / standalone tests. Never wraps app UI.
const SCENES := ["res://scenes/dream/Dream3D_RandomDungeon.tscn", "res://scenes/dream/Dream3D_TutorialRoom.tscn", "res://scenes/dream/Dream3D_ReceptionRoom.tscn"]
const DISPLAY := "res://scenes/dream/preview/SelectivePixelPreview.tscn"

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Node3D and node.scene_file_path in SCENES:
		_install.call_deferred(weakref(node))

func _install(reference: WeakRef) -> void:
	var world: Node = reference.get_ref()
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion():
		return
	var ancestor := world.get_parent()
	while ancestor != null:
		if ancestor.is_in_group(&"dream_display"):
			_ensure_dither(world)
			return
		ancestor = ancestor.get_parent()
	var parent := world.get_parent()
	var index := world.get_index()
	var display: Node = load(DISPLAY).instantiate()
	display.name = "DreamSettingsDisplay"
	display.preview_mode = false
	display.muted = false
	display.world = world
	# Moving an initialized world is presentation-only, not leaving Dream.
	var suspended: Array = []
	_suspend_exit(world, suspended)
	parent.remove_child(world)
	parent.add_child(display)
	parent.move_child(display, mini(index, parent.get_child_count() - 1))
	for state in suspended:
		var node: Node = state[0]
		if is_instance_valid(node):
			node.remove_meta(&"display_reparenting")
			for connection in state[1]:
				if not node.tree_exiting.is_connected(connection.callable):
					node.tree_exiting.connect(connection.callable, connection.flags)
	var camera: Camera3D = world.get("camera_3d")
	if is_instance_valid(camera):
		camera.make_current()
	world.tree_exiting.connect(_world_exiting.bind(weakref(world), weakref(display)))
	_ensure_dither(world)

func _ensure_dither(world: Node) -> void:
	var ancestor := world.get_parent()
	while ancestor != null:
		# Keep the independent comparison's 1/2/3 controls meaningful.
		if ancestor.get_script() != null and ancestor.get_script().resource_path == "res://scripts/dream/preview/pixel_shadow_preview.gd":
			return
		ancestor = ancestor.get_parent()
	if world.get_node_or_null("OfficeDitherLighting") == null:
		var component: Node = load("res://scripts/dream/office_dither_lighting.gd").new()
		component.name = "OfficeDitherLighting"
		world.add_child(component)

func _suspend_exit(node: Node, saved: Array) -> void:
	# Source-to-visual lifetime signals must not confuse presentation reparenting
	# with actual deletion. Restore even one-shot callbacks after the tree move.
	var connections: Array = []
	for connection in node.tree_exiting.get_connections():
		var target: Object = connection.callable.get_object()
		# Engine joints must receive exit/enter to rebuild native physics links.
		# Suspend only gameplay cleanup callbacks, including proxy.queue_free.
		if target is Node and (target.get_script() != null or connection.callable.get_method() == &"queue_free"):
			node.tree_exiting.disconnect(connection.callable)
			connections.append(connection)
	node.set_meta(&"display_reparenting", true)
	saved.append([node, connections])
	for child in node.get_children():
		_suspend_exit(child, saved)

func _world_exiting(world_ref: WeakRef, display_ref: WeakRef) -> void:
	var world: Node = world_ref.get_ref()
	var display: Node = display_ref.get_ref()
	if is_instance_valid(display) and not display.is_queued_for_deletion() and is_instance_valid(world) and not world.has_meta(&"display_reparenting"):
		display.queue_free()
