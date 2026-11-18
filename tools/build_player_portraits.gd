extends SceneTree
## Rebuild complete, aligned portraits from the untouched body and facial layers.
## Run in the editor project with --headless --script; source/ is not exported.

const ROOT := "res://art/characters/player/portraits/"
const CROP := Rect2i(531, 53, 1099, 3335)
const EXPRESSIONS := {
	"normal": "mouth_closed",
	"mouth_open": "mouth_open",
	"eyes_closed": "eyes_closed",
	"cat_eyes": "cat_eyes",
	"disbelief": "disbelief",
	"injured": "injured",
}


func _initialize() -> void:
	var base := Image.load_from_file(ROOT + "source/player_base.png")
	if base == null or base.get_size() != Vector2i(2296, 3477):
		push_error("Missing or unexpected player body source")
		quit(1)
		return
	base.convert(Image.FORMAT_RGBA8)
	for expression in EXPRESSIONS:
		var source := ROOT + "source/expressions/player_" + str(EXPRESSIONS[expression]) + ".png"
		var face := Image.load_from_file(source)
		if face == null or face.get_size() != base.get_size():
			push_error("Mismatched player facial layer: " + source)
			quit(1)
			return
		face.convert(Image.FORMAT_RGBA8)
		var combined := base.get_region(CROP)
		combined.blend_rect(face, CROP, Vector2i.ZERO)
		var target := ROOT + "player_" + str(expression) + ".png"
		if combined.save_png(target) != OK:
			push_error("Could not save player portrait: " + target)
			quit(1)
			return
		print("Built ", target, " ", combined.get_size())
	quit(0)
