extends Node3D
## Floor-owned passive display pool; never simulates or retains a projectile.
const BRIDGE = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const PREWARM_COUNT := 32
const RETAIN_LIMIT := 64
var idle: Array[Node3D] = []
var created := 0
var acquired := 0
var reused := 0

func prewarm(camera: Camera3D,max_new: int=0) -> bool:
	var added:=0
	while idle.size() < PREWARM_COUNT:
		if max_new>0 and added>=max_new: return false
		var bridge := _create(camera)
		bridge.suspend_projectile()
		idle.append(bridge)
		added+=1
	return true

func _create(camera: Camera3D) -> Node3D:
	var bridge := BRIDGE.instantiate() as Node3D
	# Keep the original map parent and transform path for the display carrier.
	get_parent().add_child(bridge)
	bridge.set_meta(&"projectile_capture_pool_slot", true)
	var viewport := bridge.get_node("ActorDepthViewport") as SubViewport
	viewport.size = Vector2i(512, 512)
	var dummy := Node2D.new()
	dummy.process_mode = Node.PROCESS_MODE_DISABLED
	dummy.set_meta(&"projectile_self_emission", true)
	var sprite := Sprite2D.new(); sprite.name = "BulletSprite"
	dummy.add_child(sprite); add_child(dummy)
	bridge.set_world_camera(camera)
	bridge.configure(dummy, viewport, bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"), null, [^"BulletSprite"], 0.8, 0.0, Vector2(256,256))
	# The temporary owner is never gameplay and must not destroy this carrier.
	dummy.tree_exiting.disconnect(bridge._on_source_tree_exiting)
	dummy.free()
	bridge.projectile_pool_release = Callable(self, "release")
	created += 1
	return bridge

func acquire(source: Node2D, camera: Camera3D, height: float, depth: float) -> Node3D:
	var bridge: Node3D
	while not idle.is_empty():
		var candidate: Node3D = idle.pop_back()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			bridge = candidate; reused += 1; break
	# Overflow grows rather than dropping shots or changing their gameplay.
	if bridge == null: bridge = _create(camera)
	acquired += 1
	bridge.rebind_projectile(source, camera, height, depth)
	source.set_meta(&"depth_visual_bridge", weakref(bridge))
	return bridge

func release(bridge: Node3D) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if idle.has(bridge): return
	if idle.size() >= RETAIN_LIMIT:
		bridge.projectile_pool_release = Callable()
		bridge.queue_free()
	else:
		idle.append(bridge)

func restore_binding(source: Node2D, camera: Camera3D) -> void:
	var reference: Variant = source.get_meta(&"depth_visual_bridge", null)
	var bridge: Node3D = reference.get_ref() if reference is WeakRef else null
	if not is_instance_valid(bridge) or bridge.is_queued_for_deletion(): return
	if not bool(bridge.get_meta(&"projectile_capture_pool_slot", false)): return
	if bridge.configured and bridge.source_actor == source: return
	idle.erase(bridge)
	# Retain the original shot snapshot/history and display plane. Do not run
	# add_projectile again: it would take a new muzzle snapshot mid-flight.
	bridge.rebind_projectile(source, camera, bridge.actor_center_height, bridge.actor_center_depth_offset)
