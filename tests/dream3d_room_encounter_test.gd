extends SceneTree

## Runtime contract for Room Graph visibility and one-shot combat encounters.
## The test intentionally uses formal WorldWeaponPickup/Furniture scenes and
## waits through the sky-drop timers; no substitute 3D gameplay actors are used.

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)


func frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	world.show_debug_markers = false
	world.enable_enemy_population_refill = false
	world.global_enemy_cap = 64
	world.min_enemies_per_room = 1
	world.max_enemies_per_room = 3
	world.enemy_density = 0.02
	world.min_furniture_per_room = 0
	world.max_furniture_per_room = 4
	world.furniture_density = 0.024
	root.add_child(world)
	await frames(3)
	check(world.regenerate(52017), "runtime Room Graph generation")
	await frames(5)

	var initial_enemy_total: int = world.enemy_count
	var unvisited_room_id := -1
	var combat_room_ids: Array[int] = []
	for room_variant in world.rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		var room_type: StringName = room.get("room_type", &"normal")
		var encounter: Dictionary = world.room_encounters.get(room_id, {})
		if room_type not in [&"start", &"boss"]:
			combat_room_ids.append(room_id)
			check(encounter.get("drop_spawns", []).size() >= 3, "room %d descriptor has >=3 drops" % room_id)
			var weapon_count := 0
			var furniture_count := 0
			for drop_variant in encounter.get("drop_spawns", []):
				var drop: Dictionary = drop_variant
				if StringName(drop.get("type", &"")) == &"weapon":
					weapon_count += 1
				elif StringName(drop.get("type", &"")) == &"furniture":
					furniture_count += 1
				check(world._is_valid_room_content_position(drop.get("ground_position", Vector2.INF), room_id), "room %d drop uses room floor cell" % room_id)
			check(weapon_count >= 1, "room %d descriptor has a weapon" % room_id)
			check(furniture_count >= 1, "room %d descriptor has furniture" % room_id)
			if unvisited_room_id < 0 and room_id != world.spawn_room_id:
				unvisited_room_id = room_id
			check(not bool(encounter.get("activated", false)), "room %d encounter starts dormant" % room_id)
			check(world.get_room_state(room_id) == &"UNSEEN", "room %d starts UNSEEN" % room_id)
			check(not bool(world.room_visibility.revealed_rooms.get(room_id, false)), "room %d starts covered" % room_id)
		if room_type in [&"boss", &"start"]:
			check(encounter.get("drop_spawns", []).is_empty(), "special room has no combat drop descriptor")
		else:
			check(not encounter.get("drop_spawns", []).is_empty(), "normal room descriptor present")
	var boss_encounter: Dictionary = world.room_encounters.get(world.boss_room_id, {})
	check(boss_encounter.get("drop_spawns", []).is_empty(), "Boss room does not receive normal combat drops")
	check(world.get_room_state(world.spawn_room_id) == &"ACTIVE", "spawn room is the only initial active room")
	for room_variant in world.rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		if room_id != world.spawn_room_id:
			check(world.get_room_state(room_id) == &"UNSEEN", "non-start room remains UNSEEN before entry")
	check(world._get_alive_employee_count_in_room(unvisited_room_id) == 0, "unseen room has no active enemy instances")
	check(initial_enemy_total >= 1, "persistent boss is present but dormant")
	if world.corridors.size() > 0:
		var corridor_id := int(world.corridors[0].get("id", -1))
		check(world.corridor_states.get(corridor_id, &"UNSEEN") == &"UNSEEN", "corridor starts unrevealed")
		world.reveal_corridor(corridor_id)
		check(world.corridor_states.get(corridor_id, &"UNSEEN") == &"REVEALED", "corridor reveal is explicit")

	var activation_room := combat_room_ids[0] if not combat_room_ids.is_empty() else -1
	check(activation_room >= 0, "at least one combat room exists")
	if activation_room >= 0:
		check(world.activate_room(activation_room), "first room activation succeeds")
		await frames(24)
		var encounter_after: Dictionary = world.room_encounters.get(activation_room, {})
		check(bool(encounter_after.get("activated", false)), "room encounter marked activated once")
		check(world.get_room_state(activation_room) == &"ACTIVE", "room becomes ACTIVE on floor entry")
		var spawned_drop_count := 0
		var spawned_weapon_count := 0
		var spawned_furniture_count := 0
		for root_node in [world.world_weapon_root, world.furniture_root]:
			for child in root_node.get_children():
				if int(child.get_meta(&"dream_room_id", -1)) != activation_room:
					continue
				spawned_drop_count += 1
				check(world._is_valid_room_content_position(child.global_position, activation_room), "activated drop lands on legal room floor")
				if root_node == world.world_weapon_root:
					spawned_weapon_count += 1
				else:
					spawned_furniture_count += 1
		check(spawned_drop_count >= 3, "activated room instantiates at least three drops")
		check(spawned_weapon_count >= 1, "activated room instantiates WorldWeaponPickup")
		check(spawned_furniture_count >= 1, "activated room instantiates formal Furniture")
		var enemy_before_reactivate: int = world.enemy_count
		var drops_before_reactivate := spawned_drop_count
		check(world.activate_room(activation_room), "re-entering an ACTIVE room succeeds")
		await frames(24)
		var drops_after_reactivate := 0
		for root_node in [world.world_weapon_root, world.furniture_root]:
			for child in root_node.get_children():
				if int(child.get_meta(&"dream_room_id", -1)) == activation_room:
					drops_after_reactivate += 1
		check(world.enemy_count == enemy_before_reactivate, "re-enter does not respawn enemies")
		check(drops_after_reactivate == drops_before_reactivate, "re-enter does not respawn drops")
		# Kill the instantiated room enemies and verify the explicit CLEARED state
		# remains terminal even when the player activates the room again.
		for enemy_variant in world.enemy_root.get_children():
			var enemy := enemy_variant as EmployeeEnemy
			if enemy != null and int(enemy.get_meta(&"dream_room_id", -1)) == activation_room and not bool(enemy.get("dead")):
				enemy.take_damage(100000.0, enemy.global_position - Vector2.RIGHT * 16.0, 0.0, &"test")
		await frames(8)
		world.mark_room_cleared(activation_room)
		check(world.get_room_state(activation_room) == &"CLEARED", "room transitions to CLEARED after enemies die")
		var enemy_before_clear_reactivate: int = world.enemy_count
		world.activate_room(activation_room)
		await frames(10)
		check(world.enemy_count == enemy_before_clear_reactivate, "CLEARED room never respawns")

	var enemy_before_wait: int = world.enemy_count
	await frames(180)
	check(world.enemy_count == enemy_before_wait, "continuous refill remains disabled")

	print("ROOM ENCOUNTER checks=", checks, " failures=", failures.size(), " combat_rooms=", combat_room_ids.size())
	world.free()
	await frames(3)
	if failures.is_empty():
		print("PASS: Room Graph runtime encounter lifecycle")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
