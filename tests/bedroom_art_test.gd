extends SceneTree

const BEDROOM := preload("res://scenes/bedroom/bedroom.tscn")
const CONFIG := preload("res://resources/demo_config.tres")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bedroom := BEDROOM.instantiate()
	bedroom.persistent_state = {
		"balance": 1325,
		"ram": 0,
		"weekday_index": 0,
		"permanent_upgrades": {},
		"online_messages": [],
		"melatonin_inventory": 3,
		"melatonin_bottle_present": true,
		"food_eaten_today": true,
		"stress_value": 100
	}
	root.add_child(bedroom)
	await process_frame
	var dialogue_config: DemoConfig = CONFIG.duplicate(true)
	dialogue_config.dialog_animation_seconds = 0.01
	bedroom.confirmation_dialog.config = dialogue_config
	var art_root: Node2D = bedroom.get_node("Layout/ArtRoot")
	_assert(art_root.scale == Vector2(0.25, 0.25), "Bedroom art root is not uniformly scaled to 640x360")
	var background_color := bedroom.get_node("Layout/BackgroundColor") as ColorRect
	_assert(background_color != null and background_color.color == Color("517b98") and background_color.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Bedroom background color or input mode is incorrect")
	var expected := {
		"BedroomBackground": "bedroom_background.png",
		"BedroomBed": "bedroom_bed.png",
		"BedroomDesk": "bedroom_desk.png",
		"MelatoninBottle": "melatonin_bottle.png"
	}
	for node_name in expected:
		var sprite := art_root.get_node(node_name) as Sprite2D
		_assert(sprite != null and sprite.texture != null, "Missing art sprite: " + node_name)
		if sprite != null and sprite.texture != null:
			_assert(sprite.texture.get_size() == Vector2(2560, 1440), "Unexpected image size for " + node_name)
			_assert(sprite.texture.resource_path.ends_with(expected[node_name]), "Wrong texture bound to " + node_name)
	_assert(bedroom.bottle_sprite.visible, "Owned melatonin bottle art is hidden")
	_assert(bedroom._is_opaque_at(bedroom.bed_sprite, bedroom.bed_image, Vector2(424, 257)), "Visible bed pixel is not clickable")
	_assert(bedroom._is_opaque_at(bedroom.bottle_sprite, bedroom.bottle_image, Vector2(171, 179)), "Visible bottle pixel is not clickable")
	_assert(not bedroom.BED_CLICK_RECT.has_point(Vector2(80, 220)) and not bedroom._bottle_click_rect().has_point(Vector2(80, 220)), "Desk area overlaps an interaction region")
	bedroom._set_highlighted("bed")
	_assert(float(bedroom.bed_outline_material.get_shader_parameter("outline_enabled")) == 1.0, "Bed alpha outline did not enable")
	_assert(float(bedroom.bottle_outline_material.get_shader_parameter("outline_enabled")) == 0.0, "Bottle outline enabled behind the bed")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	bedroom._unhandled_input(click)
	await create_timer(0.03).timeout
	_assert(bedroom.confirmation_dialog.visible and bedroom.confirmation_dialog.prompt_label.text == "要睡觉了吗？", "Bed click no longer opens the sleep confirmation")
	_assert(bedroom.confirmation_dialog.portrait.position == Vector2(16, 90) and bedroom.confirmation_dialog.portrait.size == Vector2(210, 270), "Dialogue portrait is not the large left-side layout")
	_assert(bedroom.confirmation_dialog.dialogue_panel.position == Vector2(235, 188) and bedroom.confirmation_dialog.dialogue_panel.size == Vector2(385, 154), "Dialogue panel layout is incorrect")
	_assert(bedroom.confirmation_dialog.confirm_button.focus_mode == Control.FOCUS_NONE and bedroom.confirmation_dialog.cancel_button.focus_mode == Control.FOCUS_NONE, "Dialogue choices still accept keyboard focus")
	bedroom.confirmation_dialog.close_without_signal()
	bedroom.input_locked = false
	bedroom._set_highlighted("bottle")
	_assert(float(bedroom.bottle_outline_material.get_shader_parameter("outline_enabled")) == 1.0, "Bottle alpha outline did not enable")
	bedroom._unhandled_input(click)
	_assert(bedroom.confirmation_dialog.visible and bedroom.confirmation_dialog.prompt_label.text == "要吃药吗？", "Bottle click no longer opens the melatonin confirmation")
	var character_art := bedroom.confirmation_dialog.get_node("Portrait/CharacterArt") as TextureRect
	var character_atlas: AtlasTexture
	if character_art != null:
		character_atlas = character_art.texture as AtlasTexture
	_assert(character_atlas != null and character_atlas.atlas.resource_path.ends_with("chr.png"), "Dialogue portrait does not use chr.png")
	var phone_source := FileAccess.get_file_as_string("res://scripts/ui/bedroom_phone.gd")
	_assert(not phone_source.contains("config.bedroom_interaction_outline_color"), "Phone body hover rectangle is still drawn")
	_assert(phone_source.contains("phone_app_hover_brightness"), "Phone app hover feedback was removed")
	var bedroom_source := FileAccess.get_file_as_string("res://scripts/bedroom/bedroom.gd")
	_assert(not bedroom_source.contains("draw_rect(BED_CLICK_RECT") and not bedroom_source.contains("draw_rect(_bottle_click_rect"), "Bedroom interaction still draws rectangular highlights")
	bedroom.confirmation_dialog.close_without_signal()
	var phone = bedroom.phone
	var fast_config = CONFIG.duplicate(true)
	fast_config.phone_animation_seconds = 0.01
	phone.config = fast_config
	phone._animate_phone(true)
	await create_timer(0.05).timeout
	_assert(phone.state == phone.PhoneState.EXPANDED, "Phone did not expand above the bedroom art")
	phone._animate_phone(false)
	await create_timer(0.05).timeout
	_assert(phone.state == phone.PhoneState.COLLAPSED, "Phone did not collapse after the art change")
	bedroom.queue_free()
	await process_frame
	if failures.is_empty():
		print("BEDROOM ART TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
