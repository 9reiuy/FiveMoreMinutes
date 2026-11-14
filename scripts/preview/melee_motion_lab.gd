extends "res://scripts/testing/game_test_lab.gd"

const MELEE_WEAPON := preload("res://scripts/dream/lucille_weapon.gd")
const TARGET_WORLD := preload("res://scenes/preview/MeleeTargetSampleWorld.tscn")
const STAGE_NAMES := ["待机", "横挥", "回扫", "低位扫尾"]
var motion_label: Label
var sample_weapon_id := "lucille"

func _build_ui() -> void:
	super._build_ui()
	mode.select(1)
	enemies.value = 0
	weapon.select(4)
	checks.uncapped.button_pressed = false
	panel.hide()
	compact_status.hide()

	var bar := PanelContainer.new()
	bar.position = Vector2(8, 7)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("101620e8")
	surface.content_margin_left = 8.0
	surface.content_margin_right = 8.0
	surface.content_margin_top = 5.0
	surface.content_margin_bottom = 5.0
	bar.add_theme_stylebox_override("panel", surface)
	hud.add_child(bar)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(rows)
	motion_label = _label(rows, "近战目标小样", 15)
	var instructions := _label(rows, "左键连击  ·  1 露西尔  ·  2 Books  ·  F10 重置", 11)
	var cue := _label(rows, "亮白是主目标，蓝白是同扇区内可击中的敌人", 11)
	motion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instructions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _instantiate_world() -> Node3D:
	return TARGET_WORLD.instantiate() as Node3D

func rebuild() -> void:
	if busy:
		return
	await super.rebuild()
	if ready_world and is_instance_valid(world):
		world.player.equip_weapon(sample_weapon_id, world.config)
		world.prepare_melee_sample()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and ready_world and not busy:
		if event.physical_keycode in [KEY_1, KEY_2]:
			sample_weapon_id = "lucille" if event.physical_keycode == KEY_1 else "books"
			world.player.equip_weapon(sample_weapon_id, world.config)
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if not ready_world or not is_instance_valid(world):
		return
	var melee := world.player.get_active_weapon() as MELEE_WEAPON
	var stage := melee.combo_stage if melee != null else 0
	var phase := "第%d击 %s" % [stage, STAGE_NAMES[stage]] if stage > 0 else "待机"
	motion_label.text = "%s  ·  %s" % [DreamGunAtlas.get_display_name(world.player.selected_weapon_id), phase]
