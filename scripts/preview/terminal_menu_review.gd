extends Node
## Isolated review entry: the production Main and menu scenes remain unchanged.

const MAIN_SCENE := preload("res://scenes/app/main.tscn")
const SAMPLE := preload("res://scripts/ui/terminal_menu_sample.gd")
var game: Node
var jumping_to_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = MAIN_SCENE.instantiate()
	game.get_node("SceneContainer").child_entered_tree.connect(_on_screen_added)
	add_child(game)
	SAMPLE.install_pause(game.pause_menu)


func _on_screen_added(screen: Node) -> void:
	if screen.scene_file_path == "res://scenes/ui/main_menu.tscn":
		_attach_main.call_deferred(screen)


func _attach_main(screen: Node) -> void:
	if is_instance_valid(screen) and screen.is_inside_tree() and not screen.has_node("TerminalMainSample"):
		SAMPLE.install_main(screen)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		if not jumping_to_pause:
			_jump_to_pause()
		get_viewport().set_input_as_handled()


func _jump_to_pause() -> void:
	if game.pause_menu.is_open():
		game._resume_from_pause()
		return
	jumping_to_pause = true
	if not game.pause_allowed:
		game._show_reception("basic")
		for _frame in 900:
			await get_tree().process_frame
			if is_instance_valid(game._supported_dream_world) and not game.transition_running:
				break
	if game.pause_allowed and not game.transition_running:
		game._open_pause_menu()
	jumping_to_pause = false
