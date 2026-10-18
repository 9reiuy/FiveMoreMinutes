extends Node3D
## Only passive captures are pooled; the real effect owns its 180ms lifetime.
const BRIDGE = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const EFFECT = preload("res://scenes/entities/weapon_muzzle_effect.tscn")
const PREWARM_COUNT := 12
const RETAIN_LIMIT := 32
var idle: Array[Node3D] = []
var created := 0

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
	get_parent().add_child(bridge)
	bridge.set_meta(&"muzzle_capture_pool_slot", true)
	var dummy := EFFECT.instantiate() as Node2D
	dummy.process_mode = Node.PROCESS_MODE_DISABLED
	dummy.set_meta(&"depth_visual_camera_plane", true)
	dummy.set_meta(&"shot_visual_origin", Vector3.ZERO)
	dummy.set_meta(&"shot_gameplay_origin", Vector2.ZERO)
	dummy.set_meta(&"shot_gameplay_direction", Vector2.RIGHT)
	add_child(dummy)
	var viewport := bridge.get_node("ActorDepthViewport") as SubViewport
	viewport.size = Vector2i(128,128)
	bridge.set_world_camera(camera)
	bridge.configure(dummy,viewport,bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"),null,[^"."],0.16,0.0,Vector2(64,64))
	dummy.tree_exiting.disconnect(bridge._on_source_tree_exiting)
	dummy.free()
	bridge.projectile_pool_release = Callable(self,"release")
	created += 1
	return bridge

func acquire(source: Node2D, camera: Camera3D, height: float, depth: float) -> Node3D:
	var bridge: Node3D
	while not idle.is_empty():
		var candidate: Node3D = idle.pop_front()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			bridge = candidate
			break
	if bridge == null: bridge = _create(camera)
	bridge.rebind_muzzle(source,camera,height,depth)
	source.set_meta(&"depth_visual_bridge",weakref(bridge))
	return bridge

func release(bridge: Node3D) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or idle.has(bridge): return
	if idle.size() >= RETAIN_LIMIT:
		bridge.projectile_pool_release = Callable()
		bridge.queue_free()
	else: idle.append(bridge)

func restore_binding(source: Node2D, camera: Camera3D) -> void:
	if not source.has_meta(&"depth_visual_bridge"): return
	var reference: Variant = source.get_meta(&"depth_visual_bridge",null)
	var bridge: Node3D = reference.get_ref() if reference is WeakRef else null
	if not is_instance_valid(bridge) or bridge.is_queued_for_deletion(): return
	if not bool(bridge.get_meta(&"muzzle_capture_pool_slot",false)): return
	if bridge.configured and bridge.source_actor == source: return
	idle.erase(bridge)
	bridge.rebind_muzzle(source,camera,bridge.actor_center_height,bridge.actor_center_depth_offset)
