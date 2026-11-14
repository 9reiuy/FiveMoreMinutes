extends Control
## Stage the pause presentation inside the real application in a private lab.
@export_file("*.tscn") var pause_scene := "res://scenes/preview/screen_wall_pause_menu_candidate.tscn"
@export var open_on_boot := true
var main: Node
var booted := false
var boot_error := ""
func _ready() -> void:
	boot.call_deferred()
func settle() -> void:
	var deadline:=Time.get_ticks_msec()+18000
	while main.transition_running and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
func boot() -> void:
	main=load("res://scenes/app/main.tscn").instantiate()
	var old:=main.get_node("PauseMenu")
	main.remove_child(old)
	old.free()
	var replacement: CanvasLayer=load(pause_scene).instantiate()
	replacement.name="PauseMenu"
	main.add_child(replacement)
	add_child(main)
	main._start_new_game()
	await settle()
	main._continue_game()
	await settle()
	for index in 12: await get_tree().process_frame
	if open_on_boot: main._open_pause_menu()
	booted=true
func _exit_tree() -> void:
	get_node("/root/PauseManager").clear_all()
