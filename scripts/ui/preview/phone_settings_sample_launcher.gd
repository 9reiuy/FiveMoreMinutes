extends Node
## Manually launched review scene only; not referenced by any production entrypoint.
const HOST=preload("res://scripts/ui/preview/phone_settings_sample.gd")
const FONT=preload("res://scripts/ui/pixel_font.gd")
var main:Node
var host:CanvasLayer
var busy:=false
var buttons:Array[Button]=[]
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	main=load("res://scenes/app/main.tscn").instantiate();add_child(main)
	host=HOST.new();add_child(host)
	host.action_requested.connect(_on_phone_action)
	var review:=CanvasLayer.new();review.layer=1200;add_child(review)
	var menu:=VBoxContainer.new();menu.position=Vector2(520,12);menu.add_theme_constant_override("separation",5);review.add_child(menu)
	for pair in [["主菜单设置",&"settings"],["卧室手机",&"bedroom"],["游戏暂停",&"pause"],["重新打开手机",&"reopen"]]:
		var button:=Button.new();button.text=pair[0];button.custom_minimum_size=Vector2(100,22)
		button.focus_mode=Control.FOCUS_NONE;button.add_theme_font_override("font",FONT.get_font());button.add_theme_font_size_override("font_size",9)
		menu.add_child(button);buttons.append(button);button.pressed.connect(_choose.bind(pair[1]))
	var hint:=Label.new();hint.text="独立预览 · 右侧切换\n↑↓选择  ←→调节\nE / Enter 确认  Esc 返回";hint.add_theme_font_override("font",FONT.get_font());hint.add_theme_font_size_override("font_size",9);menu.add_child(hint)
	await _ready_main();await _choose(&"bedroom")
var _context:StringName=&"bedroom"
func _ready_main()->void:
	await get_tree().process_frame
	while main.transition_running:await get_tree().create_timer(.05,true).timeout
func _choose(context:StringName)->void:
	if busy:return
	busy=true
	for button in buttons:button.disabled=true
	if host.active or host.shell.is_animating:
		host.close_sample();await get_tree().create_timer(.55,true).timeout
	if context==&"reopen":context=_context
	else:
		_context=context
		match context:
			&"settings":main._show_main_menu()
			&"bedroom":
				if main.persistent_day_state.is_empty():main.persistent_day_state=main._create_initial_state()
				main._show_bedroom(false)
			&"pause":main._show_reception("basic")
		await _ready_main()
	host.show_sample(context,main.current_screen.phone if context==&"bedroom" else null)
	await get_tree().create_timer(.45,true).timeout
	for button in buttons:button.disabled=false
	busy=false
func _on_phone_action(action:StringName)->void:
	if action==&"exit_to_menu":
		await get_tree().create_timer(.55,true).timeout
		main._exit_to_main_menu_from_pause()
	elif action==&"resume":
		# The sample owns its own pause reason; its close animation releases it.
		pass
