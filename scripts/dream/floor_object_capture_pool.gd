extends Node3D
## Passive presentation only. Source bodies, IDs, shine phases and debris
## simulation are always fresh, and remain owned by their original floor roots.
const BRIDGE = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const DEBRIS = preload("res://scenes/entities/environment_debris.tscn")
const PICKUP = preload("res://scenes/dream/world_weapon_pickup.tscn")
const PREWARM := {&"debris":64,&"weapon":8,&"shadow":8}
const RETAIN := {&"debris":96,&"weapon":24,&"shadow":24}
var idle := {&"debris":[],&"weapon":[],&"shadow":[]}
var created := 0
func prewarm(camera: Camera3D, volume_shadows: bool,max_new: int=0) -> bool:
	var added:=0
	for kind in PREWARM:
		while idle[kind].size()<PREWARM[kind]:
			if max_new>0 and added>=max_new: return false
			var unshaded: bool = kind!=&"debris" and bool(preload("res://resources/demo_config.tres").world_weapon_shine_enabled)
			var bridge := _create(kind,camera,volume_shadows,unshaded)
			bridge.suspend_projectile(); idle[kind].append(bridge)
			added+=1
	return true
func _create(kind: StringName,camera: Camera3D,volume_shadows: bool,unshaded: bool) -> Node3D:
	var bridge: Node3D=BRIDGE.instantiate()
	get_parent().add_child(bridge)
	bridge.set_meta(&"floor_object_capture_kind",kind)
	bridge.set_meta(&"floor_object_capture_unshaded",unshaded)
	bridge.volume_shadow_enabled=volume_shadows
	var dummy: Node2D=(DEBRIS if kind==&"debris" else PICKUP).instantiate()
	dummy.process_mode=Node.PROCESS_MODE_DISABLED
	dummy.collision_layer=0; dummy.collision_mask=0
	add_child(dummy)
	dummy.set_meta(&"depth_visual_unshaded",unshaded)
	var path: NodePath=^"Sprite2D" if kind==&"debris" else ^"WeaponSprite" if kind==&"weapon" else ^"Shadow"
	var flat := kind!=&"weapon"
	var height := 0.02 if kind==&"debris" else 0.015 if flat else 0.70710678
	var viewport: SubViewport=bridge.get_node("ActorDepthViewport")
	bridge.set_world_camera(camera)
	bridge.configure(dummy,viewport,bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"),null,[path],height,0.0 if flat else -0.70710678,Vector2(64,64) if flat else Vector2(64,96),BaseMaterial3D.BILLBOARD_DISABLED if flat else BaseMaterial3D.BILLBOARD_ENABLED,Vector3(-PI/2,0,0) if flat else Vector3.ZERO,true)
	dummy.tree_exiting.disconnect(bridge._on_source_tree_exiting); dummy.free()
	bridge.projectile_pool_release=Callable(self,"release")
	created+=1
	return bridge
func acquire(source: Node2D,kind: StringName,camera: Camera3D,volume_shadows: bool,register_meta: bool=true) -> Node3D:
	var unshaded := bool(source.get_meta(&"depth_visual_unshaded",false))
	var bridge: Node3D
	while not idle[kind].is_empty():
		var candidate: Node3D=idle[kind].pop_front()
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion(): continue
		if candidate.volume_shadow_enabled!=volume_shadows or bool(candidate.get_meta(&"floor_object_capture_unshaded"))!=unshaded:
			candidate.projectile_pool_release=Callable(); candidate.queue_free(); continue
		bridge=candidate; break
	if bridge==null: bridge=_create(kind,camera,volume_shadows,unshaded)
	var path: NodePath=^"Sprite2D" if kind==&"debris" else ^"WeaponSprite" if kind==&"weapon" else ^"Shadow"
	bridge.rebind_floor_object(source,camera,path)
	if source.has_meta(&"dream_room_id"): bridge.set_meta(&"dream_room_id",source.get_meta(&"dream_room_id"))
	else: bridge.remove_meta(&"dream_room_id")
	if source.has_meta(&"content_kind"): bridge.set_meta(&"content_kind",source.get_meta(&"content_kind"))
	else: bridge.remove_meta(&"content_kind")
	if kind==&"shadow": source.set_meta(&"floor_object_shadow_bridge",weakref(bridge))
	elif register_meta: source.set_meta(&"depth_visual_bridge",weakref(bridge))
	return bridge
func release(bridge: Node3D) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	var kind: StringName=bridge.get_meta(&"floor_object_capture_kind")
	if idle[kind].has(bridge): return
	if idle[kind].size()>=RETAIN[kind]:
		bridge.projectile_pool_release=Callable(); bridge.queue_free()
	else: idle[kind].append(bridge)
func restore_binding(source: Node2D,camera: Camera3D,volume_shadows: bool) -> void:
	var kinds: Array=[]
	if source.get_script()==preload("res://scripts/entities/environment_debris.gd"): kinds=[&"debris"]
	elif source.get_script()==preload("res://scripts/dream/world_weapon_pickup.gd"): kinds=[&"weapon",&"shadow"]
	for kind in kinds:
		var key: StringName=&"floor_object_shadow_bridge" if kind==&"shadow" else &"depth_visual_bridge"
		if not source.has_meta(key): continue # Do not invent an absent companion.
		var reference: Variant=source.get_meta(key)
		var bridge: Node3D=reference.get_ref() if reference is WeakRef else null
		if not is_instance_valid(bridge) or bridge.is_queued_for_deletion():
			acquire(source,kind,camera,volume_shadows); continue
		if not bridge.has_meta(&"floor_object_capture_kind"): continue
		if bridge.configured and bridge.source_actor==source: continue
		idle[kind].erase(bridge)
		var path: NodePath=^"Sprite2D" if kind==&"debris" else ^"WeaponSprite" if kind==&"weapon" else ^"Shadow"
		bridge.rebind_floor_object(source,camera,path)
