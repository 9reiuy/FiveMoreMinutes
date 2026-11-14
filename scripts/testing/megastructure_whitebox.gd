extends "res://scripts/dream/office_skeleton_world_base.gd"
## Authored level, production runtime. No replacement player, AI or combat rules.
const WHITEBOX_LAYOUT = preload("res://scripts/testing/megastructure_whitebox_layout.gd")
const WHITEBOX_GEOMETRY = preload("res://scripts/testing/megastructure_whitebox_geometry.gd")
const MAINTENANCE = preload("res://scripts/testing/maintenance_environment.gd")
const MAINTENANCE_PROP = preload("res://scenes/testing/MaintenanceProp.tscn")
const OPENING_SLOW_SECONDS := 3.0
var level_cleared := false
var opening_complete := false
var opening_gun_collected := false
var opening_throw_cue_shown := false
var opening_elapsed_real := 0.0
var _opening_last_usec := 0
var _opening_frame_ready := false
var _opening_waiting_for_frame := false
var _opening_clock_ready := false
var opening_enemy: EmployeeEnemy
var exit_guard: EmployeeEnemy
var opening_projectile: Node2D

func _ready() -> void:
	# Concrete uses its real roughness/specular plus Forward+ SSR. The separate
	# office mirror viewport assumes OfficeSparseLighting, absent in this level.
	set_meta(&"test_floor_reflections_disabled",true)
	configured_weapon_id = "books"
	process_physics_priority = 100
	player.configure_weapon("",config,{})
	super._ready()
	if is_instance_valid(night_lighting):night_lighting.set_flashlight_enabled(false)
	player_has_left_elevator_cab = true
	if is_instance_valid(objective_guidance):
		objective_guidance.queue_free()
		objective_guidance = null
	_apply_opening_time()
	var pause_manager := get_node_or_null("/root/PauseManager")
	if pause_manager != null and not pause_manager.pause_state_changed.is_connected(_on_opening_pause_changed):
		pause_manager.pause_state_changed.connect(_on_opening_pause_changed)

func _get_skeleton_source() -> Dictionary:
	return WHITEBOX_LAYOUT.build()

func uses_office_night_lighting() -> bool:
	# Keep the production linear-lit actor carrier, with basement-owned lights.
	return RenderingServer.get_current_rendering_method()=="forward_plus"

func _build_ceiling_lights() -> void:
	MAINTENANCE.build_lighting(self)
	$Lighting/WorldEnvironment.environment.background_color = Color.BLACK
	preload("res://scripts/dream/office_light_optics.gd").install(self, true)

func _choose_elevator_anchor() -> bool:
	spawn_cell = Vector2i(2,6)
	main_entrance = {"start_cell":spawn_cell}
	elevator_room_id = 0
	elevator_anchor_cell = spawn_cell
	return true

func _validate_layout() -> Dictionary:
	# The production generator's eight-room minimum does not apply to this
	# original three-part whitebox. Keep its real floor and graph checks.
	var report := _validate_floor_connectivity()
	report["graph_connected"] = _room_graph_is_connected()
	report["valid"] = rooms.size()==3 and building_rect == Rect2i(WHITEBOX_LAYOUT.EASTER_EGG.MIN_X,0,38-WHITEBOX_LAYOUT.EASTER_EGG.MIN_X,12) and bool(report.graph_connected) and bool(report.all_floor_reachable) and bool(report.all_room_centers_reachable) and floor_cells.has(spawn_cell)
	return report

func _validate_rendered_edge_nodes() -> void:
	# Continuous original contours replace the procedural one-mesh-per-cell walls.
	rendered_edge_failures = 0

func uses_office_wall_cutaway() -> bool:
	return false

func _build_walls() -> void:
	authored_cutout = AUTHORED_CUTOUT.new()
	WHITEBOX_GEOMETRY.build_boundaries(self)

func _build_doors() -> void:
	pass # Two open funnels; no added room doors or entry elevator.

func _spawn_elevator() -> bool:
	WHITEBOX_GEOMETRY.build_exit(self)
	return true

func _clear_generated_building() -> void:
	level_cleared = false
	opening_complete = false
	opening_gun_collected = false
	opening_throw_cue_shown = false
	opening_elapsed_real = 0.0
	_opening_last_usec = 0
	_opening_frame_ready = false
	_opening_waiting_for_frame = false
	_opening_clock_ready = false
	super._clear_generated_building()

func _spawn_random_content() -> void:
	super._spawn_random_content()
	opening_enemy = _spawn_regular_employee(0,Vector2(6,5.5)*32.0,&"employee",false,"basic")
	# Per-instance firearm data: neither the world nor other actors share this
	# copy. Setup derives flight lifetime from the reduced speed and same range.
	var opening_firearms := opening_enemy.feedback_config.duplicate(true) as DemoConfig
	opening_firearms.basic_projectile_speed*=.2
	opening_firearms.assault_rifle_projectile_speed*=.2
	opening_firearms.shotgun_projectile_speed*=.2
	opening_enemy.feedback_config=opening_firearms
	opening_enemy.set_room_runtime_active(true)
	opening_enemy.last_facing_direction=Vector2.LEFT
	opening_enemy.hostile=true
	opening_enemy._remember_target_position(player.global_position,0)
	opening_enemy.can_see_target=true
	opening_enemy.state=EmployeeEnemy.State.ATTACK_PLAYER
	opening_enemy._apply_live_facing(Vector2.LEFT)
	opening_enemy.defeated.connect(_on_opening_enemy_defeated)
	# The first frame starts after a genuine native shot has left the barrel.
	opening_enemy._fire_held_weapon()
	for projectile in get_tree().get_nodes_in_group(&"dream_projectiles"):
		if int(projectile.shooter_instance_id)==opening_enemy.get_instance_id():
			opening_projectile=projectile
			var emitted_from: Vector2=projectile.global_position
			projectile.global_position=emitted_from+Vector2(projectile.direction)*30.0
			projectile.traveled=30.0
			projectile.set_meta(&"whitebox_prefired",true)
			break
	for enemy in enemy_root.get_children():
		if int(enemy.get_meta(&"dream_room_id",-1))==1:
			enemy.hostile=true
			enemy._remember_target_position(player.global_position,0)
			enemy.state=EmployeeEnemy.State.ATTACK_PLAYER
			enemy.reaction_left=0.0
		elif int(enemy.get_meta(&"dream_room_id",-1))==2:
			exit_guard=enemy
			exit_guard.set_meta(&"whitebox_exit_guard",true)
			exit_guard.set_room_runtime_active(true)
			exit_guard.hostile=true
			exit_guard._remember_target_position(player.global_position,0)
			exit_guard.state=EmployeeEnemy.State.ATTACK_PLAYER
			exit_guard.last_facing_direction=Vector2.LEFT
			exit_guard._apply_live_facing(Vector2.LEFT)

func are_rooms_openly_connected(a: int, b: int) -> bool:
	# These are phases along one continuous path, with no intervening doors.
	return a>=0 and a<3 and b>=0 and b<3

func get_employee_navigation_target(employee: EmployeeEnemy, destination: Vector2) -> Vector2:
	var target := super.get_employee_navigation_target(employee,destination)
	if bool(employee.get_meta(&"whitebox_exit_guard",false)):
		target.x=clampf(target.x,30.75*32.0,36.7*32.0)
		target.y=clampf(target.y,.8*32.0,10.8*32.0)
	return target

func _physics_process(_delta: float) -> void:
	# Stage direction only: the guard keeps the real perception/fire/hit AI.
	if is_instance_valid(exit_guard) and not exit_guard.dead:
		if exit_guard.global_position.x<30.75*32.0:
			exit_guard.global_position.x=30.75*32.0
			exit_guard.velocity.x=maxf(0,exit_guard.velocity.x)

func _apply_opening_time() -> void:
	if opening_complete: return
	if is_instance_valid(opening_enemy) and opening_enemy.dead:
		_finish_opening_time()
		return
	var controller := _get_dream_time_controller()
	if controller!=null and not controller.is_tactical_planning_active(): controller.begin_tactical_planning(.05)
	if not _opening_frame_ready and not _opening_waiting_for_frame:
		_opening_waiting_for_frame = true
		_prepare_opening_frame.call_deferred(_layout_generation)


func _prepare_opening_frame(generation: int) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if generation != _layout_generation or opening_complete:
		return
	_opening_frame_ready = true
	_opening_waiting_for_frame = false


func _on_opening_cue_presented(message: String) -> void:
	if message != "扔出去" or opening_complete:
		return
	_opening_clock_ready = true
	_opening_last_usec = Time.get_ticks_usec()


func _on_opening_cue_finished(message: String, _completed: bool) -> void:
	if message == "扔出去" and not opening_complete and not _opening_clock_ready:
		# A pause/loading transition cancelled the card before its first draw.
		opening_throw_cue_shown = false


func _on_opening_pause_changed(_paused: bool) -> void:
	_opening_last_usec = 0

func _on_opening_enemy_defeated(_at: Vector2, _count: int=0) -> void:
	_finish_opening_time()

func _finish_opening_time() -> void:
	if opening_complete:return
	opening_complete=true
	if is_instance_valid(run_interface) and is_instance_valid(run_interface.player_cue) and run_interface.player_cue.current_message == "扔出去":
		run_interface.cancel_player_cue()
	var controller := _get_dream_time_controller()
	controller.clear_reaction_time()
	controller.end_tactical_planning()
	controller.set_slow_time_enabled(false)
	controller.reset_hit_stop()
	_settle_opening_speed.call_deferred()

func _settle_opening_speed() -> void:
	# Death or a near miss may request combat slow time in the same physics
	# callback. Clear that opening feedback before committing normal time.
	var controller := _get_dream_time_controller()
	controller.clear_reaction_time()
	controller.end_tactical_planning()
	controller.set_slow_time_enabled(false)
	controller.reset_hit_stop()

func _swap_world_weapon(pickup: Node2D) -> void:
	var opening_gun := bool(pickup.get_meta(&"whitebox_opening_gun",false))
	super._swap_world_weapon(pickup)
	if opening_gun and player.selected_weapon_id=="basic":opening_gun_collected=true

func _commit_employee_weapon_drop(request: Dictionary) -> void:
	super._commit_employee_weapon_drop(request)
	if int(request.get("room_id",-1))==0 and String(request.get("weapon_id",""))=="basic":
		for pickup in world_weapon_root.get_children():
			if String(pickup.weapon_id)=="basic": pickup.set_meta(&"whitebox_opening_gun",true)

func _update_world_weapon_interaction() -> void:
	# During the opening, walking over the disarmed gun commits its real pickup.
	# Afterward all weapon interactions retain the normal production E behavior.
	if not opening_gun_collected and player.is_empty_handed():
		for pickup in world_weapon_root.get_children():
			if String(pickup.weapon_id)=="basic" and pickup.global_position.distance_to(player.global_position)<=config.world_weapon_interaction_radius:
				_swap_world_weapon(pickup)
				break
	super._update_world_weapon_interaction()

func restart_current_floor_after_death() -> bool:
	# Restart this short authored encounter directly; there is no campaign lift ride.
	if not is_instance_valid(player): return false
	if is_instance_valid(run_interface):
		run_interface._clear_death_presentation()
		run_interface.kills=0
		run_interface.seconds=0.0
	player.revive_for_floor_restart("books",config,permanent_upgrades)
	player.configure_weapon("",config,permanent_upgrades)
	player.configure_weapon("books",config,permanent_upgrades)
	run_finished=false
	var success := regenerate(seed)
	player_has_left_elevator_cab=true
	_apply_opening_time()
	return success

func _build_room_encounter_plans() -> void:
	# Keep the formal encounter lifecycle and spawn function; author only slots.
	super._build_room_encounter_plans()
	badge_carrier_room_id = -1
	badge_carrier_spawn_index = -1
	for room in rooms:
		var id := int(room.id)
		var entries: Array = WHITEBOX_LAYOUT.encounter(String(room.sample_key))
		var encounter: Dictionary = room_encounters[id]
		encounter.merge({"planned_enemy_count": entries.size(), "planned_drop_count": 0,
			"enemy_spawns": entries, "drop_spawns": [], "resolved": true,
			"resolution_state": &"RESOLVED"}, true)
		room_encounters[id] = encounter
		room_layout_plans[id] = skeleton_plans[id]

func _spawn_special_units() -> void:
	# This enclosed floor has authored human encounters, no exterior drone route.
	pass

func _spawn_ambient_debris() -> void:
	pass

func _spawn_room_furniture(room_filter: int=-1) -> void:
	for spec in MAINTENANCE.prop_specs():
		if room_filter>=0 and int(spec.room)!=room_filter:continue
		var prop: RigidBody2D=MAINTENANCE_PROP.instantiate()
		prop.name="Maintenance_"+String(spec.kind)
		prop.position=Vector2(spec.at)*32.0
		prop.set_meta(&"maintenance_kind",String(spec.kind))
		prop.set_meta(&"maintenance_size",Vector3(spec.size))
		prop.set_meta(&"dream_room_id",int(spec.room));prop.set_meta(&"content_kind",&"furniture")
		var shape := RectangleShape2D.new();shape.size=Vector2(spec.size.x,spec.size.z)*32.0
		prop.get_node("CollisionShape2D").shape=shape
		prop.get_node("Hurtbox/CollisionShape2D").shape=shape
		furniture_root.add_child(prop);furniture_count+=1
		_spawn_furniture_presentation(prop)

func _spawn_furniture_presentation(prop: Node2D) -> Node3D:
	if not prop.has_meta(&"maintenance_kind"):return super._spawn_furniture_presentation(prop)
	var visual: Furniture3DVisual=FURNITURE_3D_VISUAL_SCRIPT.new()
	actor_depth_bridges_root.add_child(visual)
	visual.set_meta(&"dream_room_id",prop.get_meta(&"dream_room_id"));visual.set_meta(&"source_actor",prop)
	visual.configure(prop,null,null)
	visual.visual_instance=MAINTENANCE.prop_visual(String(prop.get_meta(&"maintenance_kind")),Vector3(prop.get_meta(&"maintenance_size")))
	visual.add_child(visual.visual_instance)
	if authored_cutout != null:
		authored_cutout.register_tree(visual.visual_instance, true)
	_register_furniture_cutout_bridge(visual)
	return visual

func _build_floor() -> void:
	_build_maintenance_floor(rooms.size(), WHITEBOX_GEOMETRY.END_FADE)

func _build_maintenance_floor(room_count: int, fade: Vector4) -> void:
	# One slab per authored room. Geometry and collision share the compiled cells.
	for index in room_count:
		var room: Dictionary = rooms[index]
		var rect: Rect2i = room.grid_rect
		var slab := MeshInstance3D.new()
		slab.name = "WhiteboxFloor_%s" % String(room.sample_key)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rect.size.x, .12, rect.size.y)
		slab.mesh = mesh
		slab.position = Vector3(rect.get_center().x - .5, -.06, rect.get_center().y - .5)
		slab.set_meta(&"dream_room_id", int(room.id))
		var concrete := MAINTENANCE.concrete(true)
		concrete.set_shader_parameter("passage_end_fade", fade)
		slab.material_override = concrete
		floor_root.add_child(slab)
	MAINTENANCE.build_services(self)
	var egg := preload("res://scripts/testing/level01_easter_egg.gd").new(self)
	floor_root.add_child(egg)
	egg.build()

func _prepare_approved_office_art() -> void:
	# Retain production defense and power. Continuous contours use a low front
	# cutaway; surfaces have no production texture dressing or city backdrop.
	get_combat_defense()
	office_wall_cutaway = null

func _paint_whitebox_walls(node: Node, material: Material) -> void:
	# Glass retains its own transparency, impact and shatter presentation.
	if node.has_method("shatter"): return
	if node is MeshInstance3D: node.material_override = material
	for child in node.get_children(): _paint_whitebox_walls(child, material)

func _whitebox_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	material.metallic_specular = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _add_room_grid(rect: Rect2i) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _whitebox_material(Color("596b76")))
	for x in range(rect.position.x, rect.end.x + 1):
		mesh.surface_add_vertex(Vector3(x - .5, .006, rect.position.y - .5))
		mesh.surface_add_vertex(Vector3(x - .5, .006, rect.end.y - .5))
	for z in range(rect.position.y, rect.end.y + 1):
		mesh.surface_add_vertex(Vector3(rect.position.x - .5, .006, z - .5))
		mesh.surface_add_vertex(Vector3(rect.end.x - .5, .006, z - .5))
	mesh.surface_end()
	var grid := MeshInstance3D.new()
	grid.name = "MetreGrid"
	grid.mesh = mesh
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_root.add_child(grid)

func _add_room_label(room: Dictionary) -> void:
	var rect: Rect2i = room.grid_rect
	var label := Label3D.new()
	label.name = "Zone_%s" % String(room.sample_key)
	label.text = String(room.name)
	label.font = preload("res://scripts/ui/crisp_interaction_font.gd").get_font()
	label.font_size = 24
	label.pixel_size = .018
	label.outline_size = 4
	label.modulate = Color("c5e4ed")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(rect.get_center().x - .5, .10, 5.5 if String(room.sample_key)=="corridor" else 2.0)
	floor_root.add_child(label)

func _process(delta: float) -> void:
	if not opening_complete and _opening_clock_ready:
		var now := Time.get_ticks_usec()
		if _opening_last_usec > 0: opening_elapsed_real += (now-_opening_last_usec)/1000000.0
		_opening_last_usec = now
		if opening_elapsed_real >= OPENING_SLOW_SECONDS: _finish_opening_time()
	_apply_opening_time()
	super._process(delta)
	_try_opening_throw_cue()
	if player.global_position.x>35.0*32.0:
		_begin_elevator_entry_transition()

func _begin_elevator_entry_transition() -> void:
	# A finite playable whitebox ends here; it never generates campaign floors.
	if level_cleared or player.global_position.x<35.0*32.0: return
	level_cleared = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		get_tree().reload_current_scene()


func _try_opening_throw_cue() -> void:
	# Wait for the real incoming opening shot and the promoted root HUD.
	# A rejected request stays pending; only a visible cue consumes this entry.
	if opening_throw_cue_shown or opening_complete or not _opening_frame_ready or not is_instance_valid(player):
		return
	if not is_instance_valid(opening_projectile) or opening_projectile.is_queued_for_deletion() or opening_projectile.consumed:
		_opening_clock_ready = true
		return
	if not bool(opening_projectile.get_meta(&"whitebox_prefired",false)):
		_opening_clock_ready = true
		return
	var toward_player := opening_projectile.global_position.direction_to(player.global_position)
	if Vector2(opening_projectile.direction).dot(toward_player) < 0.8:
		_opening_clock_ready = true
		return
	if is_instance_valid(run_interface) and run_interface.play_player_cue("扔出去"):
		opening_throw_cue_shown = true
		var cue: CanvasLayer = run_interface.player_cue
		if not cue.cue_presented.is_connected(_on_opening_cue_presented):
			cue.cue_presented.connect(_on_opening_cue_presented)
		if not cue.cue_finished.is_connected(_on_opening_cue_finished):
			cue.cue_finished.connect(_on_opening_cue_finished)
