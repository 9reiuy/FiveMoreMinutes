extends SceneTree
const KIT := preload("res://scripts/preview/screen_wall_builder.gd")
const OUT := "res://art/preview/screen_wall/pause/"
func _initialize() -> void:
	run.call_deferred()
func own_tree(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		child.scene_file_path = ""
		own_tree(child,scene_root)
func run() -> void:
	print("PAUSE_BUILD_PID=",OS.get_process_id())
	var model := Node3D.new()
	model.name = "PauseTelevisions"
	var screens := Node3D.new()
	screens.name = "Televisions"
	model.add_child(screens)
	var terminal: Node3D = KIT._television(5,Vector2(5.8,4.3),"",Color("62b6c9"))
	terminal.name="SettingsTerminal"
	terminal.position=Vector3(0,3.65,2)
	terminal.set_meta("action_id","")
	terminal.set_meta("option_text","")
	terminal.set_meta("screen_tint",Color("62b6c9"))
	terminal.visible=true
	model.add_child(terminal)
	root.add_child(model)
	own_tree(model,model)
	var packed:=PackedScene.new()
	packed.pack(model)
	DirAccess.make_dir_recursive_absolute(OUT)
	var error:=ResourceSaver.save(packed,OUT+"screen_wall_pause_model.tscn")
	print("PAUSE_BUILD_RESULT error=",error)
	model.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
