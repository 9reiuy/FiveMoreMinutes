extends Node3D
## Only the passive lit display is reused. Each shell retains its original
## fresh source, RNG consumption, motion and lifetime.
const BRIDGE = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const PREWARM_COUNT := 32
const RETAIN_LIMIT := 96
const ATLAS = preload("res://scripts/dream/shell_capture_atlas.gd")
var atlas: Node3D
var use_atlas := true
var idle: Array[Node3D]=[]
var created:=0
var acquired:=0
var reused:=0
func prewarm(camera: Camera3D,max_new: int=0) -> bool:
	var added:=0
	use_atlas=not bool(get_parent().get_parent().get_meta(&"test_legacy_shell_atlas",false))
	while idle.size()<PREWARM_COUNT:
		if max_new>0 and added>=max_new: return false
		var bridge:=_create(camera)
		bridge.suspend_projectile()
		idle.append(bridge)
		added+=1
	return true
func _create(camera: Camera3D) -> Node3D:
	var bridge:=BRIDGE.instantiate() as Node3D
	get_parent().add_child(bridge)
	bridge.set_meta(&"shell_capture_pool_slot",true)
	var dummy:=Node2D.new()
	dummy.process_mode=Node.PROCESS_MODE_DISABLED
	var sprite:=Sprite2D.new(); sprite.name="ShellSprite"
	dummy.add_child(sprite); add_child(dummy)
	var viewport:=bridge.get_node("ActorDepthViewport") as SubViewport
	bridge.set_world_camera(camera)
	bridge.configure(dummy,viewport,bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"),null,[^"ShellSprite"],0.1,0.0,Vector2(64,64),BaseMaterial3D.BILLBOARD_ENABLED,Vector3.ZERO,true,true)
	dummy.tree_exiting.disconnect(bridge._on_source_tree_exiting)
	dummy.free()
	bridge.projectile_pool_release=Callable(self,"release")
	if use_atlas:
		if atlas==null:
			atlas=ATLAS.new(); atlas.name="SharedShellCaptures"; add_child(atlas)
		atlas.register(bridge)
	created+=1
	return bridge
func acquire(source: Node2D,camera: Camera3D) -> Node3D:
	var bridge: Node3D
	while not idle.is_empty():
		var candidate: Node3D=idle.pop_back()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			bridge=candidate; reused+=1; break
	if bridge==null: bridge=_create(camera)
	for tag in [&"dream_room_id",&"content_kind"]:
		if source.has_meta(tag): bridge.set_meta(tag,source.get_meta(tag))
		elif bridge.has_meta(tag): bridge.remove_meta(tag)
	bridge.rebind_shell(source,camera)
	if atlas!=null: atlas.set_active(bridge,true)
	source.set_meta(&"depth_visual_bridge",weakref(bridge))
	source.set_meta(&"shell_capture_pool_managed",true)
	acquired+=1
	return bridge
func release(bridge: Node3D) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or idle.has(bridge): return
	if atlas!=null: atlas.set_active(bridge,false)
	if idle.size()>=RETAIN_LIMIT:
		bridge.projectile_pool_release=Callable()
		bridge.queue_free()
	else: idle.append(bridge)
func restore_binding(source: Node2D,camera: Camera3D) -> void:
	if not bool(source.get_meta(&"shell_capture_pool_managed",false)): return
	var reference: Variant=source.get_meta(&"depth_visual_bridge",null) if source.has_meta(&"depth_visual_bridge") else null
	var bridge: Node3D=reference.get_ref() if reference is WeakRef else null
	# Stash may exceed idle retention. A missing/released slot is replaced,
	# never stolen from another live shell.
	if not is_instance_valid(bridge) or bridge.is_queued_for_deletion() or not bool(bridge.get_meta(&"shell_capture_pool_slot",false)) or (bridge.configured and bridge.source_actor!=source):
		acquire(source,camera); return
	if bridge.configured and bridge.source_actor==source: return
	idle.erase(bridge)
	bridge.rebind_shell(source,camera)
	if atlas!=null: atlas.set_active(bridge,true)
