extends RefCounted
## Full authored poses are retained; dialogue only crops their upper bodies.
## Complete PNGs are built offline, never composited or resized each frame.

const NORMAL := preload("res://art/characters/player/portraits/player_normal.png")
const DIALOGUE_REGION := Rect2(0.0, 0.0, 1099.0, 1752.0)
const EXPRESSION_PATHS := {
	&"mouth_open": "res://art/characters/player/portraits/player_mouth_open.png",
	&"eyes_closed": "res://art/characters/player/portraits/player_eyes_closed.png",
	&"cat_eyes": "res://art/characters/player/portraits/player_cat_eyes.png",
	&"disbelief": "res://art/characters/player/portraits/player_disbelief.png",
	&"injured": "res://art/characters/player/portraits/player_injured.png",
}

static var _expressions: Dictionary = {}
static var _dialogue_crops: Dictionary = {}


static func normalize_expression(expression: StringName) -> StringName:
	match expression:
		&"mouth_closed", &"player_normal", &"player_mouth_closed": return &"normal"
		&"player_mouth_open": return &"mouth_open"
		&"closed_eyes", &"player_eyes_closed": return &"eyes_closed"
		&"player_cat_eyes": return &"cat_eyes"
		&"fear", &"panic", &"player_disbelief": return &"disbelief"
		&"hurt", &"pain", &"player_injured": return &"injured"
	if expression in [&"normal", &"mouth_open"] or EXPRESSION_PATHS.has(expression):
		return expression
	return &"normal"


static func texture_for(expression: StringName = &"normal") -> Texture2D:
	expression = normalize_expression(expression)
	if expression == &"normal": return NORMAL
	# Each expression is a fixed authored state, independent of typing progress.
	if not _expressions.has(expression):
		_expressions[expression] = load(EXPRESSION_PATHS[expression])
	return _expressions[expression]


static func dialogue_texture(expression: StringName = &"normal") -> Texture2D:
	var source := texture_for(expression)
	if not _dialogue_crops.has(source):
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = DIALOGUE_REGION
		atlas.filter_clip = true
		_dialogue_crops[source] = atlas
	return _dialogue_crops[source]
