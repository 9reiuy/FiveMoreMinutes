extends Node
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const CONFIG := preload("res://resources/demo_config.tres")
## One controller per floor; its history and animations follow rollback/stash.
var world: Node
var openings: Dictionary = {}
var previous: Dictionary = {}
var falling: Dictionary = {}

static func ensure(owner_world: Node) -> Node:
	var existing: Node = owner_world.floor_root.get_node_or_null("ExteriorFalls")
	if existing != null: return existing
	var controller: Node = load("res://scripts/dream/exterior_fall_controller.gd").new()
	controller.name = "ExteriorFalls"
	controller.world = owner_world
	controller.process_physics_priority = 100
	owner_world.floor_root.add_child(controller)
	return controller

func add_opening(edge: Dictionary, key: String) -> void:
	var inward: Vector2 = world._window_inward_normal(edge)
	openings[key] = {"center":world._edge_gameplay_position(edge),"outward":-inward}
	for actor in candidates():
		if is_instance_valid(actor) and actor is Node2D and not previous.has(actor.get_instance_id()):
			previous[actor.get_instance_id()] = actor.global_position

func candidates() -> Array:
	var result: Array = [world.player]
	for parent in [world.enemy_root,world.furniture_root,world.world_weapon_root,world.pickup_root,world.key_root,world.ground_debris_root]:
		if is_instance_valid(parent): result.append_array(parent.get_children())
	return result

func crossed_opening(start: Vector2, end: Vector2) -> bool:
	for opening in openings.values():
		var outward: Vector2 = opening.outward
		var center: Vector2 = opening.center
		var before := (start-center).dot(outward)
		var after := (end-center).dot(outward)
		if before > 0 or after <= 0: continue
		var contact := start.lerp(end,-before/(after-before))
		if absf((contact-center).dot(outward.orthogonal())) < 16.0: return true
	return false

func _physics_process(delta: float) -> void:
	if world.floor_transition_in_progress or world.transition_phase == &"CAB_RIDE": return
	if openings.is_empty() and falling.is_empty(): return
	var seen := {}
	if not openings.is_empty():
		for raw in candidates():
			if not is_instance_valid(raw) or not raw is Node2D or raw.is_queued_for_deletion(): continue
			# Flying enemies and their muzzle anchors are not falling ground objects.
			if raw.get_meta(&"exterior_flying",false): continue
			var actor: Node2D = raw
			var id := actor.get_instance_id()
			seen[id] = true
			if falling.has(id): continue
			var position := actor.global_position
			var prior: Vector2 = previous.get(id,position)
			if not previous.has(id):
				# Loot emitted by an already falling enemy can be born over the void.
				prior = world._nearest_safe_floor_world_position(world._cell_for_gameplay_position(position))
			previous[id] = position
			var cell: Vector2i = world._cell_for_gameplay_position(position)
			if world.floor_cells.has(cell): continue
			var protected_item: bool = actor.get_meta(&"employee_badge",false) or actor.get_meta(&"content_kind",&"") == &"boss_key"
			if protected_item:
				actor.global_position = world._nearest_safe_floor_world_position(cell)
				previous[id] = actor.global_position
				continue
			if actor == world.player and (world.player.dead or world.player.is_phase_dash_active()): continue
			if crossed_opening(prior,position): begin_fall(actor)
		for id in previous.keys():
			if not seen.has(id): previous.erase(id)
	for id in falling.keys():
		var item: Dictionary = falling[id]
		var actor: Node2D = item.actor.get_ref()
		if not is_instance_valid(actor): falling.erase(id); continue
		item.elapsed += delta
		actor.set_meta(&"exterior_fall_offset",-8.0*pow(float(item.elapsed)/.5,2))
		if float(item.elapsed) >= .5:
			actor.hide()
			if actor == world.player: actor.force_exterior_fall_death()
			else: actor.queue_free()
			falling.erase(id)

func begin_fall(actor: Node2D) -> void:
	var id := actor.get_instance_id()
	if falling.has(id): return
	var point := actor.global_position
	actor.set_meta(&"exterior_falling",true)
	if actor == world.player:
		actor.set_meta(&"exterior_fall_restore",{"layer":actor.collision_layer,"mask":actor.collision_mask,"physics":actor.is_physics_processing(),"process":actor.is_processing()})
		actor.cancel_dash()
		actor.movement_enabled = false
		actor.attacking_enabled = false
		var easter_egg_chance := 0.02
		if world != null and world.config != null and "wilhelm_scream_easter_egg_chance" in world.config:
			easter_egg_chance = float(world.config.wilhelm_scream_easter_egg_chance)
		elif CONFIG != null and "wilhelm_scream_easter_egg_chance" in CONFIG:
			easter_egg_chance = float(CONFIG.wilhelm_scream_easter_egg_chance)
		if randf() < easter_egg_chance:
			var time_controller := get_node_or_null("/root/DreamTimeController")
			if time_controller != null:
				time_controller.set("slow_time_enabled", false)
				time_controller.set("tactical_planning_active", false)
				time_controller.set("dive_bullet_time_active", false)
				time_controller.set("hitstop_active", false)
			Engine.time_scale = 1.0
			actor.set_meta(&"wilhelm_scream_start_msec", Time.get_ticks_msec())
			actor.set_meta(&"exterior_fall_wilhelm", true)
			SFX.play_wilhelm_scream()
	elif actor.has_method("force_pit_death") and not actor.get("dead"):
		actor.force_pit_death(point)
		actor.global_position = point
	if actor is CollisionObject2D:
		actor.set_deferred("collision_layer",0)
		actor.set_deferred("collision_mask",0)
	if actor is RigidBody2D: actor.set_deferred("freeze",true)
	actor.set_physics_process(false)
	actor.set_process(false)
	var visual_ref: Variant = actor.get_meta(&"depth_visual_bridge") if actor.has_meta(&"depth_visual_bridge") else null
	if visual_ref is WeakRef:
		var visual: Node = visual_ref.get_ref()
		if is_instance_valid(visual):
			if visual.has_method("wake_visual_process"): visual.wake_visual_process()
			else: visual.set_process(true)
	falling[id] = {"actor":weakref(actor),"elapsed":0.0}
