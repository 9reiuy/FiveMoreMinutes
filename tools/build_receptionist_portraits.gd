extends SceneTree
## Build aligned full portraits while retaining all untouched source layers.

const ROOT := "res://art/characters/receptionist/portraits/"
const CROP := Rect2i(196, 15, 1109, 3592)
const GAME_SIZE := Vector2i(555, 1796)


func _initialize() -> void:
	var base := Image.load_from_file(ROOT + "source/receptionist_base.png")
	if base == null or base.get_size() != Vector2i(1603, 3667):
		push_error("Missing or unexpected receptionist body source")
		quit(1)
		return
	base.convert(Image.FORMAT_RGBA8)
	for expression: String in ["normal", "talking", "nervous"]:
		var path := ROOT + "source/expressions/receptionist_" + expression + ".png"
		var face := Image.load_from_file(path)
		if face == null or face.get_size() != base.get_size():
			push_error("Mismatched receptionist facial layer: " + path)
			quit(1)
			return
		face.convert(Image.FORMAT_RGBA8)
		var combined := base.get_region(CROP)
		combined.blend_rect(face, CROP, Vector2i.ZERO)
		# Keep enough detail for the 340 px on-screen portrait without loading
		# the full source canvases into the main scene's texture dependencies.
		combined.resize(GAME_SIZE.x, GAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var target := ROOT + "receptionist_" + expression + ".png"
		if combined.save_png(target) != OK:
			push_error("Could not save receptionist portrait: " + target)
			quit(1)
			return
		print("Built ", target, " ", combined.get_size())
	quit(0)
