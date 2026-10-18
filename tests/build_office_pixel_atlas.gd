extends SceneTree

func _initialize() -> void:
	var atlas := preload("res://scripts/dream/office_pixel_atlas_art.gd").build()
	var output := ProjectSettings.globalize_path("res://art/Dream/office_pixel_sample/office_atlas.png")
	var error := atlas.save_png(output)
	print("OFFICE_ATLAS ", output, " error=", error, " size=", atlas.get_size())
	quit(0 if error == OK else 1)
