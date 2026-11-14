extends "res://scripts/dream/preview/selective_pixel_preview.gd"

func _ready() -> void:
	preview_mode = false
	muted = false
	world = preload("res://scenes/testing/LinkedMaintenanceGarage.tscn").instantiate()
	super._ready()
	world.run_interface.hud.hide()
	get_window().title = "0-1 → 0-2 → 0-3 → 0-4 → 0-5 → 0-6 · 连通试玩"
	world.linked_level_finished.connect(func(): get_window().title = "0-5 · 下港站台（F5 重来）")
	world.train_chapter_started.connect(func(): get_window().title = "0-6 · 末班列车（F5 重来）")
	world.train_chapter_completed.connect(func(): get_window().title = "0-6 · 已完成（F5 重来）")
	if OS.get_cmdline_user_args().has("--train-only"):
		world.begin_train_chapter.call_deferred(true)
