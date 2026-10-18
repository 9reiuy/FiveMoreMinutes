extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const GENERATOR = preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const OTXO_GEN = preload("res://scripts/dream/dream_otxo_mansion_generator.gd")

var failures: Array[String] = []
var log_lines: Array[String] = []

func log_msg(msg: String) -> void:
	log_lines.append(msg)
	print(msg)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		log_msg("FAIL: " + message)
	else:
		log_msg("PASS: " + message)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	log_msg("=== STARTING ELEVATOR AND WEAPON PARITY TEST ===")
	
	# --- Part 1: 20 Fixed Seeds Layout & Weapon Parity ---
	log_msg("--- Part 1: 20 Fixed Seeds (41001-41020) ---")
	var dungeon_gen: Node = GENERATOR.new()
	for s in range(41001, 41021):
		var ok: bool = dungeon_gen.generate_layout_only(s)
		check(ok, "Seed %d layout generation success" % s)
		
		# The current hand-authored sample has four circulation segments and ten
		# functional rooms; the optional procedural pack retains its own counts.
		var elevator_lobbies := 0
		var corridors := 0
		var normal_rooms := 0
		var elevator_room_id := -1
		var corridor_room_ids: Array[int] = []
		for r in dungeon_gen.rooms:
			var r_type: StringName = StringName(r.get("room_type", &""))
			var arch: String = String(r.get("archetype", ""))
			if r_type == &"elevator_lobby" or arch == "elevator_lobby":
				elevator_lobbies += 1
				elevator_room_id = int(r.get("id", -1))
			elif r_type == &"corridor" or arch == "corridor":
				corridors += 1
				corridor_room_ids.append(int(r.get("id", -1)))
			else:
				normal_rooms += 1
		check(elevator_lobbies == 1, "Seed %d has exactly 1 elevator lobby (got %d)" % [s, elevator_lobbies])
		check(corridors == (4 if dungeon_gen.use_authored_office_sample else 1), "Seed %d has planned safe corridor count (got %d)" % [s, corridors])
		check((dungeon_gen.rooms.size() == 14) if dungeon_gen.use_authored_office_sample else (dungeon_gen.rooms.size() >= 9 and dungeon_gen.rooms.size() <= 13), "Seed %d space count matches active pack (got %d)" % [s, dungeon_gen.rooms.size()])
		check(elevator_room_id == dungeon_gen.spawn_room_id, "Seed %d spawn_room_id is elevator_lobby" % s)
		
		# 2. Badge carrier is outside elevator lobby and corridor
		dungeon_gen._build_room_encounter_plans()
		check(dungeon_gen.badge_carrier_room_id != elevator_room_id, "Seed %d badge carrier outside elevator lobby" % s)
		check(dungeon_gen.badge_carrier_room_id not in corridor_room_ids, "Seed %d badge carrier outside corridors" % s)
		check(dungeon_gen.badge_carrier_room_id >= 0, "Seed %d valid badge carrier room" % s)

		for corridor_room_id in corridor_room_ids:
			var corridor_enc: Dictionary = dungeon_gen.room_encounters.get(corridor_room_id, {})
			var corridor_enemies := int(corridor_enc.get("planned_enemy_count", 0))
			check(corridor_enemies == (0 if dungeon_gen.use_authored_office_sample else 1), "Seed %d corridor enemy count follows active pack (got %d)" % [s, corridor_enemies])
		
		# 3. Ground weapon drop count is 0 in otxo mansion
		var total_ground_weapons := 0
		var total_employees := 0
		var unarmed_employees := 0
		var waitress_count := 0
		for r in dungeon_gen.rooms:
			var rid := int(r.get("id", -1))
			dungeon_gen._resolve_room_encounter_descriptor(rid)
			var enc: Dictionary = dungeon_gen.room_encounters.get(rid, {})
			for dr in enc.get("drop_spawns", []):
				if dr.get("type") == &"weapon":
					total_ground_weapons += 1
			for en in enc.get("enemy_spawns", []):
				total_employees += 1
				var etype: StringName = StringName(en.get("type", &"employee"))
				var wid: String = String(en.get("weapon_id", ""))
				if etype == &"waitress":
					waitress_count += 1
					if wid != "books":
						unarmed_employees += 1
				else:
					if wid.is_empty():
						unarmed_employees += 1
		check(total_ground_weapons == 0, "Seed %d initial ground weapon drops == 0 (got %d)" % [s, total_ground_weapons])
		check(total_employees > 0, "Seed %d planned employees > 0 (got %d)" % [s, total_employees])
		check(unarmed_employees == 0, "Seed %d all employees armed properly (unarmed=%d)" % [s, unarmed_employees])
	dungeon_gen.free()

	# --- Part 2: Runtime 5-Floor Progression Cycle ---
	log_msg("--- Part 2: Runtime 5-Floor Progression Cycle ---")
	var world: Node = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.elevator_transition_animated = false
	root.add_child(world)
	check(world.regenerate(41001), "Runtime instantiate and regenerate seed 41001")
	await frames(4)
	
	# Freeze enemies from attacking during test
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	
	var initial_player_id: int = world.player.get_instance_id()
	world.player.current_health = 80.0
	var expected_hp: float = 80.0

	for floor_idx in range(5):
		log_msg("Testing Floor %d -> %d transition" % [floor_idx, floor_idx + 1])
		check(world.floor_index == floor_idx, "Current floor index is %d" % floor_idx)
		check(not world.player_has_left_elevator_cab, "Floor %d starts with player_has_left_elevator_cab == false" % floor_idx)
		check(world.elevator_doors_open, "Floor %d starts with elevator sliding doors OPEN" % floor_idx)
		check(world.elevator_state == &"LOCKED", "Floor %d starts with elevator LOCKED" % floor_idx)
		
		# Test: Player in cab cannot trigger elevator transition
		world._on_elevator_body_entered(world.player)
		check(not world.floor_transition_in_progress, "Cab exit protection: cannot transition before exiting cab")

		# Test: Moving backward inside cab does NOT close doors (Bugfix verification)
		var cab_door_pos: Vector2 = world.elevator_door_pos_2d
		var cab_inward: Vector2 = world.elevator_cab_inward_2d
		world.player.global_position = cab_door_pos + cab_inward * 40.0
		world._on_elevator_body_exited(world.player)
		await frames(2)
		check(world.elevator_doors_open, "Stepping backward inside cab does NOT close elevator doors")
		check(not world.player_has_left_elevator_cab, "Player still considered inside cab after stepping back")

		# Move the player out of the cabin, regardless of door orientation.
		world.player.global_position = cab_door_pos - cab_inward * 30.0
		world._on_elevator_approach_entered(world.player)
		await frames(4)
		check(world.player_has_left_elevator_cab, "Player exited cab into corridor")
		check(not world.elevator_doors_open, "Elevator doors slide CLOSED after entering corridor")
		if world.elevator_door_collider != null:
			var col_shape := world.elevator_door_collider.get_node_or_null("CollisionShape2D") as CollisionShape2D
			check(col_shape != null and not col_shape.disabled, "Door collider active when closed")
		
		# Test: Returning/Approaching without badge keeps doors closed
		world._on_elevator_approach_entered(world.player)
		await frames(2)
		check(not world.elevator_doors_open, "Approaching without badge keeps doors CLOSED")
		world._on_elevator_body_entered(world.player)
		check(not world.floor_transition_in_progress, "Returning without badge does not transition")
		check(world.elevator_state == &"LOCKED", "Elevator remains LOCKED without badge")
		
		# The carrier can live in a lazy room and must be activated first.
		world.activate_room(world.badge_carrier_room_id)
		await frames(4)
		# Find badge carrier and defeat
		var carrier: Node = null
		for enemy in world.enemy_root.get_children():
			if enemy.get_meta(&"employee_badge_carrier", false):
				carrier = enemy
				break
		check(carrier != null, "Floor %d has valid badge carrier enemy" % floor_idx)
		if carrier != null:
			var death_pos: Vector2 = carrier.global_position
			carrier._die()
			world._on_badge_carrier_defeated(death_pos, 0, carrier)
			await frames(4)
			var badge: Node = world.floor_badge_pickup
			check(badge != null and is_instance_valid(badge), "Badge dropped on carrier death")
			if badge != null and is_instance_valid(badge):
				badge.collect()
				await frames(4)
				check(world.has_floor_badge, "Badge collected by player")
				check(world.elevator_state == &"UNLOCKED", "Elevator UNLOCKED with badge")
				
				# Approaching door with badge causes doors to slide OPEN
				world._on_elevator_approach_entered(world.player)
				await frames(4)
				check(world.elevator_doors_open, "Approaching door with badge slides doors OPEN")
				if world.elevator_door_collider != null:
					var col_shape := world.elevator_door_collider.get_node_or_null("CollisionShape2D") as CollisionShape2D
					check(col_shape != null and col_shape.disabled, "Door collider disabled when open")
				
				# Advance floor by stepping into elevator room
				world.player.global_position = Vector2(world.elevator_anchor_cell) * world.CELL_PIXELS
				world._on_elevator_body_entered(world.player)
				await frames(6)
				
				check(world.floor_index == floor_idx + 1, "Floor successfully advanced to %d" % [floor_idx + 1])
				check(world.player.get_instance_id() == initial_player_id, "Player instance preserved across floors")
				check(is_equal_approx(world.player.current_health, expected_hp), "Player HP preserved across floors")
				check(not world.has_floor_badge, "Badge consumed on new floor")
				check(not world.player_has_left_elevator_cab, "New floor resets player_has_left_elevator_cab")
				check(world.elevator_doors_open, "New floor starts with elevator doors OPEN")

	# --- Part 3: Cutaway Geometry & Ceiling Fixtures ---
	log_msg("--- Part 3: Cutaway Geometry & Ceiling Fixtures ---")
	var target_norm_id := -1
	for r in world.rooms:
		if StringName(r.get("room_type", &"")) == &"normal":
			target_norm_id = int(r.get("id", -1))
			break
	if target_norm_id >= 0:
		world.player.global_position = Vector2(world.rooms[target_norm_id].center_cell) * world.CELL_PIXELS
		world.activate_room(target_norm_id)
		await frames(5)

	var walls: Array = world.wall_root.get_children()
	check(walls.size() > 0, "Walls exist in dungeon")
	var cutaway_walls := 0
	var baseboard_verified := false
	var cut_surface_verified := false
	for wall in walls:
		if wall.has_method("set_cutaway_mode") and wall.cutaway_mode:
			cutaway_walls += 1
			var wall_mesh := wall.get_node_or_null("WallMesh") as MeshInstance3D
			if wall_mesh == null:
				# Glass windows own a permanent sill and a separate thin pane;
				# they do not expose the solid wall adapter's mesh fields.
				check(wall.get_node_or_null("ArchitecturalCutSurface") != null, "Cutaway window has black section cap")
				continue
			check(wall_mesh.mesh != null, "Cutaway wall has lower section mesh")
			var shadow_mesh := wall.get_node_or_null("ShadowCasterMesh") as MeshInstance3D
			check(shadow_mesh != null and shadow_mesh.visible, "Cutaway wall retains solid shadow mesh")
			# The approved architecture keeps the lower 30%, not the old top beam.
			var m: ArrayMesh = wall_mesh.mesh as ArrayMesh
			if m != null and m.get_surface_count() > 0:
				var arrays := m.surface_get_arrays(0)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in verts:
					if v.y <= 0.23:
						baseboard_verified = true
					if v.y >= 0.70 and v.y <= 1.0:
						cut_surface_verified = true
	log_msg("Current room near walls in cutaway mode: %d" % cutaway_walls)
	check(cutaway_walls > 0, "Foreground walls in current room have cutaway mode enabled")
	check(baseboard_verified, "Cutaway wall mesh contains bottom baseboard vertices (y <= 0.23)")
	check(cut_surface_verified, "Cutaway wall mesh ends near the lower 30% section")
	
	# Check ceiling lights fixture visibility
	var ceiling_lights: Array = world.ceiling_light_root.get_children()
	var total_fixtures := 0
	var hidden_fixtures := 0
	var active_lights := 0
	for holder in ceiling_lights:
		var fix := holder.get_node_or_null("FixtureMesh") as MeshInstance3D
		if fix != null:
			total_fixtures += 1
			if not fix.visible:
				hidden_fixtures += 1
		var light := holder.get_node_or_null("RoomLight") as SpotLight3D
		if light != null:
			active_lights += 1
	log_msg("Ceiling lights: hidden_fixtures=%d/%d, active_lights=%d" % [hidden_fixtures, total_fixtures, active_lights])
	check(total_fixtures > 0 and hidden_fixtures == total_fixtures, "All ceiling fixture meshes hidden")
	check(active_lights > 0, "Ceiling lights remain active")

	world.free()
	
	log_msg("=== TEST SUMMARY ===")
	log_msg("Total failures: %d" % failures.size())
	for f in failures:
		log_msg("  - " + f)
	
	var file := FileAccess.open("user://test_results.txt", FileAccess.WRITE)
	if file != null:
		for l in log_lines:
			file.store_line(l)
		file.close()
	
	quit(0 if failures.is_empty() else 1)
