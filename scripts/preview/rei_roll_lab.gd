extends "res://scripts/testing/game_test_lab.gd"

var roll_pose: Node

func _build_ui() -> void:
	super._build_ui()
	mode.select(1)
	enemies.value = 0
	weapon.select(0)
	checks.uncapped.button_pressed = false
	panel.hide()
	compact_status.hide()
	var bar := PanelContainer.new()
	bar.position = Vector2(12, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111722e8")
	style.set_content_margin_all(8)
	bar.add_theme_stylebox_override("panel", style)
	hud.add_child(bar)
	var roll_label := _label(bar, "Rei   ·   方向键／WASD   ·   空格 飞扑翻滚   ·   Shift 快速冲刺   ·   F10 重置", 15)
	roll_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func rebuild() -> void:
	if busy:
		return
	await super.rebuild()
	if not ready_world:
		return
	roll_pose = world.player.dive_roll_pose
	station.select(0)
	teleport(0)
