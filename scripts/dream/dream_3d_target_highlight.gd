extends Node
## Enemy cues share melee collision. The aim ray still selects interactable props.
const MELEE_WEAPON := preload("res://scripts/dream/lucille_weapon.gd")
const RETAIN_TARGET_ANGLE := 0.06
const DISTANCE_WEIGHT := 0.04
var world: Node3D
var current_target: Node
var current_carrier: Node
var last_range := 0.0
var primary_melee_target: Node2D
const TARGET_NONE := 0
const TARGET_WHITE := 1
const TARGET_GRAY := 2
var current_state := TARGET_NONE
var _aim_ray_query: PhysicsRayQueryParameters2D
var _aim_exclude_rids: Array[RID] = []
var _melee_carriers: Dictionary = {}
var _use_aim_ray := true

func configure(owner_world: Node3D, use_aim_ray := true) -> void:
	world = owner_world
	_use_aim_ray = use_aim_ray

func _physics_process(_delta: float) -> void:
	_update_melee_highlights()
	if not _use_aim_ray:
		return
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
	if player.selected_weapon_id.is_empty() or player.get_active_weapon() is MELEE_WEAPON:
		_select(null, TARGET_NONE)
		return
	var origin: Vector2 = player.call("get_aim_origin")
	if player.has_method("get_projectile_origin") and preload("res://scripts/data/dream_gun_atlas.gd").has_firearm(String(player.get("selected_weapon_id"))):
		origin = player.call("get_projectile_origin")
	var direction := origin.direction_to(world.get_gameplay_aim_position())
	var target := find_target(origin, direction, last_range, player.get_rid())
	_select(target, TARGET_WHITE)

func _update_melee_highlights() -> void:
	var next: Dictionary = {}
	var chosen: Node2D
	var chosen_id := 0
	var player: Node2D = world.player if is_instance_valid(world) else null
	if (is_instance_valid(player) and not player.dead and player.movement_enabled and player.attacking_enabled
		and not player.is_throw_aim_active() and world.get("floor_transition_in_progress") != true):
		var melee := player.get_active_weapon() as MELEE_WEAPON
		var direction := Vector2.ZERO
		if melee != null:
			direction = melee.get_attack_preview_direction()
		elif player.selected_weapon_id.is_empty():
			direction = player.punch_direction if player.punch_active else player.get_aim_direction()
		if not direction.is_zero_approx():
			var reach: float = maxf(player.get_effective_attack_range(), 1.0)
			var origin := player.global_position
			var best := INF
			for candidate in world.get_dream_enemies_snapshot():
				if not is_instance_valid(candidate) or not candidate is Node2D:
					continue
				var enemy: Node2D = candidate
				if not _can_highlight(enemy):
					continue
				var reference: Variant = enemy.get_meta(&"depth_visual_bridge", null)
				var carrier: Node = reference.get_ref() if reference is WeakRef else null
				if not is_instance_valid(carrier) or not carrier.has_method("set_combat_range_highlight"):
					continue
				var reachable: bool = (melee.is_target_in_attack_preview(enemy, direction) if melee != null
					else player.is_enemy_in_melee_preview(enemy, direction))
				if not reachable:
					continue
				var offset := enemy.global_position - origin
				var angle := absf(direction.angle_to(offset)) if not offset.is_zero_approx() else 0.0
				var score := angle + DISTANCE_WEIGHT * offset.length() / reach
				if enemy == primary_melee_target:
					score -= RETAIN_TARGET_ANGLE
				var id := carrier.get_instance_id()
				if score < best:
					best = score
					chosen = enemy
					chosen_id = id
				next[id] = {"carrier": reference, "primary": false}
	primary_melee_target = chosen
	if chosen_id != 0:
		next[chosen_id].primary = true
	for id in _melee_carriers:
		if not next.has(id):
			_set_melee_carrier(_melee_carriers[id], false)
	for id in next:
		if not _melee_carriers.has(id) or _melee_carriers[id].primary != next[id].primary:
			_set_melee_carrier(next[id], true)
	_melee_carriers = next

func _can_highlight(enemy: Node2D) -> bool:
	# The 2D source canvas can be hidden while its 3D actor carrier is visible.
	return (enemy.is_inside_tree() and not enemy.is_queued_for_deletion()
		and enemy.visible and enemy.get("dead") != true and enemy.has_method("take_damage")
		and not enemy.get_meta(&"smoke_hidden_from_player", false) and not enemy.get_meta(&"extinguisher_smoke", false)
		and (not enemy.has_method("is_damage_runtime_active") or enemy.is_damage_runtime_active()))

func _set_melee_carrier(entry: Dictionary, active: bool) -> void:
	var carrier: Node = entry.carrier.get_ref()
	if is_instance_valid(carrier):
		carrier.set_combat_range_highlight(active, active and entry.primary)

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
	if not is_instance_valid(target) or target.is_in_group(&"dream_enemies"):
		return
	# Enemy visuals come exclusively from the melee query above.
	# Furniture still uses the same 3D carrier as the visible sprite.
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
