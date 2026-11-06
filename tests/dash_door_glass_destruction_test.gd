extends SceneTree
## Production generated doors/glass, real 2D mirrors and the real Space controller.
const DOORS := preload("res://scripts/dream/dash_door_break.gd")
const GLASS := preload("res://scripts/dream/dash_glass_break.gd")
const EFFECT := preload("res://scripts/dream/shared_wall_break_effect.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func live_bursts(world: Node) -> Array:
	return get_nodes_in_group(&"persistent_destruction_debris").filter(func(node: Node) -> bool: return node.get_parent() == world.floor_root)
func path_for(body: StaticBody2D) -> Array[Vector2]:
	var normal := Vector2.DOWN.rotated(body.global_rotation)
	return [body.global_position-normal*28,body.global_position+normal*28]
func run() -> void:
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.set_meta(&"test_floor_reflections_disabled",true)
	root.add_child(world)
	await process_frame
	check(world.regenerate(90210),"production office generates")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var door: Node3D
	for candidate in world.door_root.get_children():
		if candidate.has_method("shatter_from_dash") and not candidate.is_boss_door and not candidate.locked: door = candidate; break
	check(door != null,"production generation has a physical ordinary door")
	if door == null: world.free(); quit(1); return
	var path := path_for(door._collision_bodies[0])
	var before_health: float = door.current_health
	var before_bursts := live_bursts(world).size()
	var before_dust := get_nodes_in_group(&"door_break_dust").size()
	var targets := DOORS.query(world,path[0],path[1],7.071068)
	check(targets.has(door) and not door.is_destroyed and door.current_health == before_health and live_bursts(world).size() == before_bursts,"real body sweep query finds door without damage or visuals")
	check(DOORS.query(world,path[0],path[0],7.071068).is_empty(),"zero travelled path does not request a door break")
	door.locked = true
	check(DOORS.query(world,path[0],path[1],7.071068).has(door) and not door.is_destroyed,"actual path query includes a locked physical door without side effects")
	door.locked = false
	door.is_boss_door = true
	check(DOORS.query(world,path[0],path[1],7.071068).has(door),"actual path includes a boss-marked PhysicalDoor leaf")
	door.is_boss_door = false
	check(DOORS.commit(world,targets,world.get_current_floor_token()-1,Vector2.DOWN) == 0 and not door.is_destroyed,"stale floor cannot destroy a door")
	var signals := {"count":0}
	door.door_shattered.connect(func(_door): signals.count += 1)
	door.locked = true
	door.is_boss_door = true
	check(DOORS.commit(world,[door,door],world.get_current_floor_token(),Vector2.DOWN) == 1 and signals.count == 1,"duplicate leaves produce one existing door destruction callback")
	check(not door.locked and door.is_destroyed,"dash breaks locked boss-marked physical leaves and clears the obsolete lock")
	check(DOORS.commit(world,[door],world.get_current_floor_token(),Vector2.DOWN) == 0 and signals.count == 1,"door destruction is idempotent")
	check(live_bursts(world).size() == before_bursts+1 and live_bursts(world).back().pieces.size() > 0,"visible production panels become textured source-mesh fragments")
	var dust_nodes := get_nodes_in_group(&"door_break_dust")
	check(dust_nodes.size() == before_dust+1 and dust_nodes.back().dust.size() == 11,"door impact adds one bounded directional dust batch")
	check(dust_nodes.back().dust_render.material_override == EFFECT._dust_material and dust_nodes.back().dust_render.multimesh.mesh == EFFECT._dust_shape,"door dust reuses the wall loading-prepared material and mesh")
	var clear := true
	for visual in door._visuals:
		clear = clear and not visual.visible
		var caster := visual.get_node_or_null("SolidShadowCaster") as MeshInstance3D
		if caster != null: clear = clear and not caster.is_visible_in_tree()
	for leaf in door._leaves: clear = clear and leaf.collision_layer == 0 and leaf.collision_mask == 0
	for body in door._collision_bodies: clear = clear and body.collision_layer == 0
	check(clear,"destroyed panels, copied shadows and real 2D/3D leaf blockers all disappear")
	await process_frame
	check(door._collision_shapes.all(func(shape: CollisionShape2D) -> bool: return shape.disabled),"all destroyed mirrored leaf shapes are disabled")
	# Single-door source filtering must not manufacture the dormant second panel.
	var single = load("res://scenes/dream/3d/PhysicalDoor3D.tscn").instantiate()
	single.configure(2,3,.25,"left",99991,&"single")
	world.door_root.add_child(single)
	single.configure_gameplay_collision(world.collision_root)
	check(not single.right_visual.visible,"single-door production scene keeps second panel dormant")
	check(single.shatter_from_dash(Vector2.RIGHT),"single-door production shatter succeeds")
	var single_burst: Node = live_bursts(world).back()
	check(single_burst.audit_nodes == single_burst.audit_unique_nodes and single_burst.audit_nodes <= 3,"single-door fragments contain one panel and present hardware only")
	# Real native continuous pane: its own frame and shadow hierarchy must vanish.
	var pane: Node3D
	for candidate in get_nodes_in_group(&"breakable_glass_windows"):
		if world.wall_root.is_ancestor_of(candidate) and candidate.get_script().resource_path == "res://scripts/dream/continuous_office_glass.gd": pane = candidate; break
	check(pane != null,"production native glass cell exists")
	if pane != null:
		check(pane.frame_root.get_node_or_null("WindowHeader") != null,"inspected native frame includes the reported overhead header")
		check(GLASS.commit(world,[pane],world.get_current_floor_token(),Vector2.RIGHT) == 1,"existing glass shatter authority handles a real native pane")
		check(not pane.frame_root.visible and not pane.frame_root.get_node("WindowHeader").is_visible_in_tree(),"broken native glass hides the whole top-frame hierarchy")
		pane.set_cutaway_mode(true)
		pane.set_cutaway_mode(false)
		check(not pane.frame_root.visible and pane.cutaway_caps.all(func(cap: MeshInstance3D) -> bool: return not cap.visible),"later cutaway refresh cannot restore broken glass frames")
		await process_frame
		check(pane.collision_body_2d.collision_layer == 0 and pane.collision_shape_2d.disabled,"broken native glass leaves no invisible movement blocker")
	# Exercise actual Space, not just the helper, against another generated door.
	var player: CharacterBody2D = world.player
	var phase_door: Node3D
	var heading := Vector2.ZERO
	for candidate in world.door_root.get_children():
		if not candidate.has_method("shatter_from_dash") or candidate.is_destroyed or candidate.locked or candidate.is_boss_door: continue
		var body: StaticBody2D = candidate._collision_bodies[0]
		var candidate_path := path_for(body)
		var offset: Vector2 = player.body_collision.global_position-player.global_position
		player.global_position = candidate_path[0]-offset
		var probe := preload("res://scripts/entities/player_phase_dash.gd").new()
		probe.configure(player)
		probe.world = world
		var direction := (candidate_path[1]-candidate_path[0]).normalized()
		var supported: float = probe._supported_travel_distance(player.global_position,direction,player.dash_distance)
		probe.free()
		if supported > 40:
			phase_door = candidate
			heading = direction
			break
	check(phase_door != null,"another real generated door has a supported Space route")
	if phase_door != null:
		player.max_dash_charges = 1
		player.dash_charges = 1
		player.dash_cooldown_left = 0
		check(player.try_start_phase_dash(heading) and not phase_door.is_destroyed,"Space start does not destroy the future door before contact")
		for i in 16:
			if not player.is_phase_dash_active(): break
			player._update_dash(player.dash_duration/14.0)
			await process_frame
		check(phase_door.is_destroyed,"actual travelled Space segments break the contacted generated door")
		check(player.dash_charges == 0 and player.collision_mask != 0 and not player.dashing,"door break preserves normal dash charge and collision lifecycle")
	world.free()
	await process_frame
	print("DASH_DOOR_GLASS_DESTRUCTION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
