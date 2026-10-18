extends SceneTree
const FONT = preload("res://scripts/ui/crisp_interaction_font.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var font := FONT.get_font()
	check(FONT.SOURCE.resource_path.contains("fusion-pixel-12px"),"Native 12px face used for clear HUD")
	check(font.oversampling==1.0,"Rasterized at native pixel density")
	check(font.antialiasing==TextServer.FONT_ANTIALIASING_NONE,"No font blur")
	for character in "拾取替换进入欢迎来到办公室选择继续退出":
		check(font.has_char(character.unicode_at(0)),"Chinese glyph present: "+character)
	var bubble = load("res://scenes/ui/dialogue/dream_dialogue_bubble.tscn").instantiate()
	root.add_child(bubble)
	bubble.show_dialogue("欢迎来到办公室。需要帮助吗？",Vector2(320,160),["继续","退出"])
	check(bubble.dialogue_label.get_theme_font("font")==font,"Dialogue uses corrected font")
	check(bubble.dialogue_label.get_theme_font_size("font_size")==12,"Dialogue stays at native 12px")
	bubble.queue_free()
	for i in 4: await process_frame
	print("FONT_READABILITY_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
