extends SceneTree

const CEILING = preload("res://scripts/dream/dream_3d_ceiling_lighting.gd")
const NIGHT = preload("res://scripts/dream/dream_night_lighting.gd")
const CAB = preload("res://scripts/dream/independent_elevator_cab_3d.gd")
const LAYOUT_TEST = preload("res://tests/test_ordered_room_lighting.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world := LAYOUT_TEST.WorldStub.new()
	var cells: Array[Vector2i] = []
	for y in 12:
		for x in 14:
			var cell := Vector2i(x, y)
			cells.append(cell)
			world.floor_cells[cell] = true
			world.room_cells[cell] = 0
	for x in 14:
		for y in [0, 12]:
			world.wall_edges["H:%d:%d" % [x, y]] = {"axis": "H", "x": x, "y": y}
	for y in 12:
		for x in [0, 14]:
			world.wall_edges["V:%d:%d" % [x, y]] = {"axis": "V", "x": x, "y": y}
	world.rooms = [{"id": 0, "size_class": "large", "archetype": "lounge", "usable_cells": cells}]
	root.add_child(world)
	var ceiling := CEILING.new()
	root.add_child(ceiling)
	ceiling.managed_shadows = true
	ceiling.build_for_world(world)
	check(ceiling.get_shadow_candidates().size() == 4, "Managed candidate budget changed")
	check(ceiling.get_child_count() == 5, "Managed fixtures added extra lights")
	for light in ceiling.get_shadow_candidates():
		check(not light.shadow_enabled, "Candidates bypass manager selection")
		check(light.get_meta("shadow_room_id", -1) == 0, "Candidate missing room metadata")
		check(light.get_meta("shadow_scope_radius", 0.0) > 0.0, "Candidate missing range metadata")
		if light.name == &"RoomLight":
			check(is_equal_approx(light.global_position.y, world.wall_height - 0.10), "Top emitter above roof")
		else:
			check(is_equal_approx(light.get_parent().position.y, world.wall_height * 0.65), "Managed mode moved wall fixture")
	ceiling.build_for_world(world)
	check(ceiling.get_shadow_candidates().size() == 4, "Rebuild duplicated candidates")
	ceiling.clear_lights()
	check(ceiling.get_shadow_candidates().is_empty(), "Clear retained dead light references")
	ceiling.queue_free()
	world.queue_free()
	await process_frame

	var owner := Node3D.new()
	root.add_child(owner)
	var night := NIGHT.new()
	owner.add_child(night)
	night.configure(owner)
	night.set_process(false)
	check(night.muzzle_lights.size() == 6, "Muzzle pool size changed")
	night.flash_muzzle_world(Vector3.ZERO, &"rifle")
	check(_shadow_count(night) == 0, "Legacy run gained shadow flash")
	night.set_managed_shadows(true)
	night.muzzle_duration = 1.0
	night.flash_muzzle_world(Vector3(1, 1, 1), &"pistol")
	night.flash_muzzle_world(Vector3(2, 1, 1), &"shotgun")
	check(_shadow_count(night) == 1, "Concurrent muzzle flashes exceeded one shadow")
	var locked_slot: int = night._muzzle_shadow_slot
	check(night.muzzle_lights[locked_slot].light_energy == 4.0, "Highest contribution shot did not win frame")
	var locked_position: Vector3 = night.muzzle_lights[locked_slot].global_position
	for index in 20:
		night.flash_muzzle_world(Vector3(index, 2, 0), &"pistol")
		check(_shadow_count(night) == 1, "Pool wrap exceeded shadow budget")
	check(night.muzzle_lights[locked_slot].global_position == locked_position, "Pool moved immutable shot origin")
	check(night.remaining[locked_slot] <= 0.080, "Flash exceeds 80ms duration")
	check((night.flashlight.light_cull_mask & 4) == 0, "Flashlight includes own player shadow")
	# Real-clock expiry must work even with delta zero (slow motion / pause).
	var expiry_wait_started := Time.get_ticks_usec()
	while Time.get_ticks_usec() - expiry_wait_started < 90000:
		await process_frame
	# Avoid actor lookup after the expiry-only section.
	night.shadow_transition_paused = true
	night._process(0.0)
	check(_shadow_count(night) == 0, "Paused time extended muzzle shadow beyond 80ms")
	night.set_shadow_transition_paused(false)
	night.flash_muzzle_world(Vector3.ZERO, &"rifle")
	night.set_shadow_transition_paused(true)
	check(_shadow_count(night) == 0, "Cab transition retained flash shadow")
	for light in night.muzzle_lights:
		check(not light.visible, "Cab transition retained muzzle light")
	check(not night.flashlight.visible, "Cab transition retained torch")
	night.flash_muzzle_world(Vector3.ZERO, &"shotgun")
	check(_shadow_count(night) == 0, "Paused transition accepted new pulse")
	owner.queue_free()
	await process_frame

	var cab := CAB.new()
	root.add_child(cab)
	check(not cab.cab_light.shadow_enabled, "Legacy cab gained shadows")
	cab.set_managed_shadows(true)
	check(cab.cab_light.shadow_enabled, "Managed cab light lacks shadow")
	check(cab.find_children("*", "Light3D", true, false).size() == 1, "Cab added extra light")
	var caster_count: int = cab._shadow_boundaries.size()
	check(caster_count == 9, "Cab missing complete enclosure shadows")
	cab.set_managed_shadows(true)
	check(cab._shadow_boundaries.size() == caster_count, "Cab duplicated shadow boundaries")
	var leaf_caster: MeshInstance3D = cab.inner_left_door.get_child(0)
	var previous := leaf_caster.global_position
	cab.inner_left_door.position.x -= 0.5
	check(is_equal_approx(leaf_caster.global_position.x, previous.x - 0.5), "Cab door shadow did not follow leaf")
	cab.set_managed_shadows(false)
	check(not cab.cab_light.shadow_enabled, "Cab disable retained shadow light")
	for caster in cab._shadow_boundaries:
		check(not caster.visible, "Cab disable retained boundary caster")
	cab.queue_free()
	await process_frame
	print("MANAGED_LIGHT_SHADOW_CHECKS=", checks, " FAILURES=", failures)
	quit(1 if failures else 0)

func _shadow_count(night: Node) -> int:
	var count := 0
	for light in night.muzzle_lights:
		if light.shadow_enabled: count += 1
	return count
