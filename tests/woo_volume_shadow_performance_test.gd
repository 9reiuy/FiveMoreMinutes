extends "res://tests/woo_polygon_performance_test.gd"
## Identical native route, doors and mixed-combat load; a separate output folder.
func _fresh() -> void:
	_release_input()
	if is_instance_valid(lab):
		await lab.retire_drawing()
		lab.free()
		await frames(4)
	lab = load("res://scenes/preview/visibility_light_sample.tscn").instantiate()
	lab.use_volume_visibility = true
	lab.style_index = 3
	root.add_child(lab)
	while not lab.sample_ready or lab.busy: await process_frame
	lab.apply_style(3)
	lab.toggle_lamps()
	lab.sample_ui.hide(); lab.hud.hide(); lab.panel.hide()
	await frames(90)

func run() -> void:
	output_path = "res://.runtime/hellkind_purple_sample_20261103/volume_shadow_revision/performance"
	DirAccess.make_dir_recursive_absolute(output_path)
	await super.run()
