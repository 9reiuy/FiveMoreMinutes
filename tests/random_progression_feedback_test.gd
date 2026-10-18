extends SceneTree
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var failures := 0
var checks := 0
class Target extends Node2D:
	var dead := false
	var accepted := 0.0
	func take_damage(amount: float, _origin: Vector2, _scale: float, _source: StringName) -> void:
		accepted += amount
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _run() -> void:
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.spawn_content = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	check(world.regenerate(6), "world builds")
	var player = world.player
	player.configure_weapon("basic", world.config, {})
	player.get_ammo_status()
	player.ammo_states[player.selected_weapon_id]["reload_left"] = 4.0
	world._on_player_ammo_changed_for_popup(0, 12, true)
	world._update_weapon_name_popup(3.0)
	check(world.weapon_name_popup.visible and world.weapon_name_popup.text == "正在换弹", "reload persists, not weapon name")
	world._on_player_active_weapon_changed_for_popup(player.selected_weapon_id)
	check(world.weapon_name_popup.text == "正在换弹", "reload has priority over equip signal")
	player.ammo_states[player.selected_weapon_id]["reload_left"] = 0.0
	world._on_player_ammo_changed_for_popup(12, 12, false)
	check(not world.weapon_name_popup.visible, "finished/cancelled reload clears")
	world._on_player_active_weapon_changed_for_popup(player.selected_weapon_id)
	check(world.weapon_name_popup.visible and world.weapon_name_popup.text != "正在换弹", "equip still shows name")
	var target := Target.new()
	root.add_child(target)
	var result: Dictionary = world.resolve_player_hit(target, 3.0, Vector2.ZERO)
	check(is_equal_approx(target.accepted, float(result.damage)), "damage remains authoritative")
	world._show_damage_feedback(target, {"damage": 300, "is_critical": true}, Vector2.ZERO)
	check(world.native_damage_numbers_root.get_child_count() == 0 and world.damage_totals.is_empty(), "ordinary and critical hits have no text")
	var reception: Dictionary = world.rooms[world.elevator_room_id]
	var exit_point: Vector2 = world.elevator_door_pos_2d - world.elevator_cab_inward_2d * 48
	check(world._room_id_at_position(exit_point) == world.elevator_room_id and reception.archetype == "reception", "real animation landing is reception")
	check(world.elevator_cab_inward_2d == Vector2.DOWN, "virtual cab exterior direction")
	var props: Array = world.room_layout_plans[world.elevator_room_id].furniture_placements
	check(props.any(func(item: Dictionary): return item.office_kind == "reception"), "entry plan includes desk")
	var entry_floor_visible := false
	var entry_rect: Rect2 = Rect2(reception.grid_rect)
	for batch in world.floor_root.get_children():
		if batch is MeshInstance3D and batch.name.begins_with("FloorBatch"):
			for surface in batch.mesh.get_surface_count():
				for vertex in batch.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var point: Vector3 = batch.position + vertex
					if entry_rect.grow(-0.75).has_point(Vector2(point.x, point.z)):
						entry_floor_visible = true
	check(entry_floor_visible, "reception keeps rendered floor, not legacy hidden elevator footprint")
	target.free()
	world.queue_free()
	await process_frame
	print("PROGRESSION FEEDBACK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
