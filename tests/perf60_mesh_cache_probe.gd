extends SceneTree
func _init(): call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	var display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	seed(41001)
	if not world.regenerate(41001):
		print("FAIL regen"); quit(1); return
	for i in 40:
		await process_frame
	world._cutout_furniture_meshes_dirty = true
	world._update_occlusion_cutouts()
	var meshes: Array = world._furniture_meshes()
	var whole := 0
	for n in world.find_children("*", "MeshInstance3D", true, false):
		if world._mesh_belongs_to_furniture(n):
			whole += 1
	print("MESH_CACHE scoped=%d whole=%d art_children=%d" % [
		meshes.size(), whole,
		world.office_art_root.get_child_count() if world.office_art_root else -1
	])
	quit(0 if meshes.size() >= maxi(whole / 2, 1) else 2)
