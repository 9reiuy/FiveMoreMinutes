extends Node3D
## Reuse only passive ground carriers, never the blood simulation or wall/door
## stains. Two exact existing capture sizes avoid resizing on ordinary hits.
const BRIDGE = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const BLOOD = preload("res://scripts/entities/black_blood_effect.gd")
const SMALL_PREWARM := 18
const LARGE_PREWARM := 6
const SMALL_LIMIT := 48
const LARGE_LIMIT := 16
var small_idle: Array[Node3D] = []
var large_idle: Array[Node3D] = []
var created := 0
func prewarm(camera: Camera3D, height: float,max_new: int=0) -> bool:
	var added:=0
	for extent in [64,112]:
		var slots: Array[Node3D] = large_idle if extent==112 else small_idle
		var count := LARGE_PREWARM if extent==112 else SMALL_PREWARM
		while slots.size()<count:
			if max_new>0 and added>=max_new: return false
			var bridge := _create(camera,height,extent)
			bridge.suspend_projectile(); slots.append(bridge)
			added+=1
	return true
func _create(camera: Camera3D,height: float,extent: int) -> Node3D:
	var bridge: Node3D = BRIDGE.instantiate(); get_parent().add_child(bridge)
	bridge.set_meta(&"blood_ground_capture_pool_slot",true)
	var dummy: Node2D = BLOOD.new(); dummy.process_mode=Node.PROCESS_MODE_DISABLED
	add_child(dummy); dummy.add_to_group(&"black_blood_stains")
	var viewport: SubViewport = bridge.get_node("ActorDepthViewport")
	viewport.size = Vector2i(extent*2,extent*2)
	bridge.set_world_camera(camera)
	bridge.configure(dummy,viewport,bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"),null,[^"."],height,0.0,Vector2(extent,extent),BaseMaterial3D.BILLBOARD_DISABLED,Vector3(-PI*.5,0,0),false,true)
	dummy.tree_exiting.disconnect(bridge._on_source_tree_exiting); dummy.free()
	bridge.projectile_pool_release=Callable(self,"release"); created+=1
	return bridge
func acquire(source: Node2D,camera: Camera3D,height: float) -> Node3D:
	var extent := 112 if bool(source.get("office_pool_core")) or int(source.get_meta(&"blood_ground_capture_extent",64))>=96 else 64
	var slots: Array[Node3D] = large_idle if extent==112 else small_idle
	var bridge: Node3D
	while not slots.is_empty():
		var candidate: Node3D = slots.pop_front()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion(): bridge=candidate; break
	if bridge==null: bridge=_create(camera,height,extent)
	preload("res://scripts/app/performance_markers.gd").event(self,"blood_capture_acquired",{"source_id":source.get_instance_id(),"bridge_id":bridge.get_instance_id(),"extent":extent})
	bridge.rebind_blood_ground(source,camera,height)
	source.set_meta(&"depth_visual_bridge",weakref(bridge))
	bridge.set_meta(&"dream_room_id",int(source.get_meta(&"dream_room_id",-1)))
	return bridge
func acquire_surface(source: Node2D, camera: Camera3D, height: float, plane_rotation: Vector3, follow_source_rotation: bool = false) -> Node3D:
	var bridge: Node3D
	while not small_idle.is_empty():
		var candidate: Node3D = small_idle.pop_front()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion(): bridge = candidate; break
	if bridge == null: bridge = _create(camera, height, 64)
	bridge.rebind_blood_surface(source, camera, height, plane_rotation, follow_source_rotation)
	source.set_meta(&"depth_visual_bridge", weakref(bridge))
	bridge.set_meta(&"dream_room_id", int(source.get_meta(&"dream_room_id", -1)))
	return bridge
func release(bridge: Node3D) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	bridge.plane_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	bridge.follow_source_rotation = false
	if bridge.actor_sprite != null: bridge.actor_sprite.rotation = bridge.plane_rotation
	# Consolidation promotes small captures to 224; return to the matching bin.
	var large: bool = bridge.render_viewport.size.x==224
	var slots: Array[Node3D] = large_idle if large else small_idle
	if slots.has(bridge): return
	if slots.size()>=(LARGE_LIMIT if large else SMALL_LIMIT):
		bridge.projectile_pool_release=Callable(); bridge.queue_free()
	else: slots.append(bridge)
func restore_binding(source: Node2D,camera: Camera3D,height: float) -> void:
	if source.get_script()!=BLOOD: return
	if source.has_meta(&"blood_surface_height"):
		var s_height := float(source.get_meta(&"blood_surface_height", height))
		var s_rot: Vector3 = source.get_meta(&"blood_surface_rotation", Vector3.ZERO)
		var s_follow := bool(source.get_meta(&"blood_surface_follow", false))
		var s_ref: Variant = source.get_meta(&"depth_visual_bridge", null)
		var s_bridge: Node3D = s_ref.get_ref() if s_ref is WeakRef else null
		if not is_instance_valid(s_bridge) or s_bridge.is_queued_for_deletion():
			acquire_surface(source, camera, s_height, s_rot, s_follow); return
		if not bool(s_bridge.get_meta(&"blood_ground_capture_pool_slot", false)): return
		if s_bridge.configured and s_bridge.source_actor == source: return
		small_idle.erase(s_bridge); large_idle.erase(s_bridge)
		s_bridge.rebind_blood_surface(source, camera, s_height, s_rot, s_follow)
		return
	if not bool(source.get_meta(&"blood_floor_visual",false)): return
	var reference: Variant = source.get_meta(&"depth_visual_bridge",null)
	var bridge: Node3D = reference.get_ref() if reference is WeakRef else null
	if not is_instance_valid(bridge) or bridge.is_queued_for_deletion(): acquire(source,camera,height); return
	if not bool(bridge.get_meta(&"blood_ground_capture_pool_slot",false)): return
	if bridge.configured and bridge.source_actor==source: return
	small_idle.erase(bridge); large_idle.erase(bridge)
	bridge.rebind_blood_ground(source,camera,height)
