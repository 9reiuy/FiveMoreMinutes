extends SceneTree
const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
func _init() -> void: call_deferred("_run")
func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func _run() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await _frames(2)
	print("regen=", world.regenerate(41005))
	await _frames(5)
	print("player=", world.player.global_position, "room=", world.get_current_room_id(), "spawn_room=", world.spawn_room_id)
	print("lights total=", world.ceiling_light_root.get_child_count())
	for h in world.ceiling_light_root.get_children():
		var lit: Array = []
		for c in h.get_children():
			if c is Light3D:
				lit.append({"name": c.name, "visible": c.visible, "energy": c.light_energy, "mask": c.light_cull_mask, "pos": c.global_position})
		print("holder ", h.name, "visible=", h.visible, "room=", h.get_meta("dream_room_id", -1), "corr=", h.get_meta("dream_corridor_id", -1), "lights=", lit)
	var cover_root := world.find_child("RoomFogRoot", true, false)
	if cover_root != null:
		var vis := []
		for c in cover_root.get_children():
			vis.append([c.name, c.visible])
		print("covers=", vis)
	print("flash=", world.night_lighting.flashlight.visible, "enabled=", world.night_lighting.is_flashlight_enabled(), "mask=", world.night_lighting.flashlight.light_cull_mask, "pos=", world.night_lighting.flashlight.global_position, "dir=", -world.night_lighting.flashlight.global_basis.z)
	quit(0)
