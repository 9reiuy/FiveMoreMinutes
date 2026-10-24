extends Node
## One shared gameplay ray decides all target types; carriers only draw.
var world: Node3D
var current_target: Node
var current_carrier: Node
var last_range := 0.0
const TARGET_NONE := 0
const TARGET_WHITE := 1
const TARGET_GRAY := 2
var current_state := TARGET_NONE
var _aim_ray_query: PhysicsRayQueryParameters2D
var _aim_exclude_rids: Array[RID] = []
var _melee_carriers: Dictionary={}

func configure(owner_world: Node3D) -> void:
	world = owner_world

func _physics_process(_delta: float) -> void:
	_update_melee_highlights()
	if not is_instance_valid(world) or not is_instance_valid(world.player):
		_select(null)
		return
	var player: Node2D = world.player
	if bool(player.get("dead")):
		_select(null, TARGET_NONE)
		return
	# Throw aim uses the same predictive collision query as the committed
	# WorldWeaponPickup. The first valid target can be an Enemy or Furniture;
	# the trajectory itself already stops at the first formal blocker.
	if player.has_method("is_throw_aim_active") and bool(player.call("is_throw_aim_active")):
		if world.has_method("get_throw_aim_prediction"):
			var prediction: Dictionary = world.call("get_throw_aim_prediction")
			var predicted_target: Node = prediction.get("target") as Node
			if predicted_target == null:
				# Compatibility with a cache from an older world script.
				predicted_target = prediction.get("enemy_target") as Node
			_select(predicted_target, TARGET_WHITE if predicted_target != null else TARGET_NONE)
		else:
			_select(null, TARGET_NONE)
		return
	last_range = player.call("get_effective_attack_range")
	var origin: Vector2 = player.call("get_aim_origin")
	if player.has_method("get_projectile_origin") and preload("res://scripts/data/dream_gun_atlas.gd").has_firearm(String(player.get("selected_weapon_id"))):
		origin = player.call("get_projectile_origin")
	var direction := origin.direction_to(world.get_gameplay_aim_position())
	var target := find_target(origin, direction, last_range, player.get_rid())
	_select(target, TARGET_WHITE)

func _update_melee_highlights() -> void:
	var next: Dictionary={}
	if is_instance_valid(world) and is_instance_valid(world.player) and is_instance_valid(world.get("enemy_root")) and not world.player.dead:
		var player: Node2D=world.player
		if String(player.get("selected_weapon_id")) in ["","lucille","books"]:
			var max_distance: float=player.get_effective_attack_range()+32.0
			for enemy in world.enemy_root.get_children():
				if enemy.get_meta(&"smoke_hidden_from_player",false):continue
				if not enemy is Node2D or enemy.global_position.distance_squared_to(player.global_position)>max_distance*max_distance: continue
				if not player.is_enemy_in_melee_preview(enemy): continue
				var reference: Variant=enemy.get_meta(&"depth_visual_bridge",null)
				var carrier: Node=reference.get_ref() if reference is WeakRef else null
				if is_instance_valid(carrier) and carrier.has_method("set_combat_range_highlight"):
					carrier.set_combat_range_highlight(true)
					next[carrier.get_instance_id()]=weakref(carrier)
	for id in _melee_carriers:
		if next.has(id): continue
		var carrier: Node=_melee_carriers[id].get_ref()
		if is_instance_valid(carrier): carrier.set_combat_range_highlight(false)
	_melee_carriers=next

func find_target(origin: Vector2, direction: Vector2, attack_range: float, excluded: RID) -> Node:
	if _aim_ray_query == null:
		_aim_ray_query = PhysicsRayQueryParameters2D.new()
		_aim_ray_query.collision_mask = 1 | 2 | 4 | 8 | 16
		_aim_ray_query.collide_with_areas = true
		_aim_ray_query.collide_with_bodies = true
		_aim_ray_query.hit_from_inside = true
	_aim_ray_query.from = origin
	_aim_ray_query.to = origin + direction.normalized() * maxf(attack_range, 0.0)
	_aim_exclude_rids.clear()
	_aim_exclude_rids.append(excluded)
	_aim_ray_query.exclude = _aim_exclude_rids
	for _attempt in 12:
		var hit: Dictionary = world.player.get_world_2d().direct_space_state.intersect_ray(_aim_ray_query)
		if hit.is_empty():
			return null
		var collider: Node = hit.collider
		var owner: Node = collider.get_damage_owner() if collider.has_method("get_damage_owner") else collider
		if owner.is_in_group(&"world_weapon_pickups") or owner.is_in_group(&"employee_badge_pickup") or owner == world.player:
			_aim_exclude_rids.append(collider.get_rid())
			_aim_ray_query.exclude = _aim_exclude_rids
			continue
		return _resolve(collider)
	return null

func _resolve(node: Node) -> Node:
	if not is_instance_valid(node):
		return null
	if node.has_meta(&"physical_door_instance_id"):
		# Doors remain interactive gameplay objects, but the current targeting
		# presentation deliberately has no Door outline (including the Boss door).
		return null
	var cursor := node
	while cursor != null:
		if cursor.is_in_group(&"dream_enemies"):
			return null if bool(cursor.get("dead")) or not cursor.visible or cursor.get_meta(&"smoke_hidden_from_player",false) else cursor
		if cursor.is_in_group(&"damageable_props"):
			return cursor
		cursor = cursor.get_parent()
	return null

func _select(target: Node, state: int = TARGET_WHITE) -> void:
	if is_instance_valid(target) and target.get_meta(&"smoke_hidden_from_player",false):target=null
	state = clampi(state, TARGET_NONE, TARGET_GRAY)
	if is_instance_valid(target) and current_target == target and current_state == state:
		return
	if is_instance_valid(current_carrier):
		_apply_carrier_state(current_carrier, TARGET_NONE)
	current_target = target
	current_carrier = null
	current_state = state if is_instance_valid(target) else TARGET_NONE
	if not is_instance_valid(target):
		return
	# Prefer a target's depth bridge so Enemy/Furniture outlines are drawn by the
	# same 3D carrier as the visible sprite. Doors expose the state API directly.
	if target.has_meta(&"depth_visual_bridge"):
		var reference: WeakRef = target.get_meta(&"depth_visual_bridge")
		var bridge: Variant = reference.get_ref() if reference != null else null
		if is_instance_valid(bridge):
			current_carrier = bridge
	if current_carrier == null and target.has_method("set_target_highlight_state"):
		current_carrier = target
	elif current_carrier == null and target.has_method("set_target_highlight"):
		current_carrier = target
	if is_instance_valid(current_carrier):
		_apply_carrier_state(current_carrier, current_state)


func _apply_carrier_state(carrier: Node, state: int) -> void:
	if not is_instance_valid(carrier):
		return
	if carrier.has_method("set_target_highlight_state"):
		carrier.call("set_target_highlight_state", state)
	elif carrier.has_method("set_target_highlight"):
		carrier.call("set_target_highlight", state != TARGET_NONE)


func get_target_state() -> int:
	return current_state
