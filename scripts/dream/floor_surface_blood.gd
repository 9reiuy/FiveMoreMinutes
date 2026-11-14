extends "res://scripts/dream/surface_blood_system.gd"
## One floor-owned host. Rollback stashes it with the original receiver meshes.
## Gameplay collision/damage and the separate corpse pool/drag lifetime stay intact.
var world: Node3D
var accepted_blood_events := 0
var _dirty := true
var _sync_pending := false
var _watched: Dictionary = {}

static func install(target: Node3D, restore_layers := false) -> Node3D:
	if not target.surface_blood_enabled or not is_instance_valid(target.office_art_root): return null
	var existing := target.office_art_root.get_node_or_null("SurfaceBlood") as Node3D
	if is_instance_valid(existing):
		if restore_layers: existing.restore_receiver_layers()
		return existing
	var system: Node3D = load("res://scripts/dream/floor_surface_blood.gd").new()
	system.name = "SurfaceBlood"; system.world = target; system.camera = target.camera_3d
	target.office_art_root.add_child(system)
	system.sync_scene()
	return system

func _changed(_child: Node) -> void:
	_dirty = true
	if not _sync_pending:
		_sync_pending = true
		call_deferred("sync_scene")

func sync_scene() -> void:
	_sync_pending = false
	if not is_instance_valid(world) or not is_inside_tree(): return
	# Do not accidentally bind a staged floor to geometry in the rollback stash.
	if get_parent() != world.office_art_root: return
	for source in [world.floor_root,world.wall_root,world.door_root,world.actor_depth_bridges_root]:
		if not is_instance_valid(source): continue
		if not _watched.has(source.get_instance_id()):
			source.child_entered_tree.connect(_changed)
			source.child_exiting_tree.connect(_changed)
			_watched[source.get_instance_id()] = true
		for child in source.get_children():
			if child == self: continue
			var label := "地面" if source==world.floor_root else "墙壁"
			if source==world.door_root: label = "门"
			if source==world.actor_depth_bridges_root:
				if not child is Furniture3DVisual: continue
				label = "家具"
			# Each actual mesh is an owner: hinged door leaves, chair seats and
			# movable furniture carry the stain without a frozen combined shape.
			var meshes: Array[Node] = child.find_children("*","MeshInstance3D",true,false)
			if child is MeshInstance3D: meshes.push_front(child)
			for mesh in meshes:
				if not _eligible(mesh): continue
				register_receiver(mesh,label,true)
	_dirty = false

func _eligible(mesh: MeshInstance3D) -> bool:
	if mesh.mesh == null: return false
	var n := String(mesh.name).to_lower()
	if "shadow" in n or "reflection" in n or "glow" in n or "glass" in n or "window" in n or "exterior" in n: return false
	if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: return false
	return true

func emit_at(at_position: Vector2, direction: Vector2, lethal: bool, strength: float) -> bool:
	if not is_inside_tree() or get_parent()!=world.office_art_root: return false
	if _dirty: sync_scene()
	var wound: Vector3 = world.get_gameplay_world_position(at_position,.88)
	var nearest := 28.0
	for bridge in world.actor_depth_bridges_root.get_children():
		if not bridge.has_method("get_hit_feedback_world_position"): continue
		var actor: Variant = bridge.get("source_actor")
		if not actor is EmployeeEnemy: continue
		var distance: float = actor.global_position.distance_to(at_position)
		if distance <= nearest:
			nearest = distance; wound = bridge.get_hit_feedback_world_position()
	emit_spray(wound,world.global_basis*Vector3(direction.x,0,direction.y),lethal,maxf(strength,.85))
	accepted_blood_events += 1
	return true
