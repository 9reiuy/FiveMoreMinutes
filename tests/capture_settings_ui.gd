extends SceneTree

const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_panel.tscn")
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9/"

func _init() -> void:
	call_deferred("_capture_ui")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func _capture_ui() -> void:
	var canvas := CanvasLayer.new()
	var panel := SETTINGS_SCENE.instantiate()
	canvas.add_child(panel)
	root.add_child(canvas)
	
	await frames(5)
	
	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		var path := ARTIFACT_DIR + "settings_panel_palette.png"
		img.save_png(path)
		print("Saved settings panel screenshot to: ", path)
		
	quit(0)
