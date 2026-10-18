extends SceneTree

const BRIDGE = preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var bridge = BRIDGE.new()
	root.add_child(bridge)
	bridge.character_projection = true
	bridge.weapon_sprite = Sprite3D.new()
	bridge.attachment_sprite = Sprite3D.new()
	bridge.add_child(bridge.weapon_sprite)
	bridge.add_child(bridge.attachment_sprite)
	var viewport := SubViewport.new()
	bridge.add_child(viewport)
	bridge.layer_viewports.append(viewport)
	var capture := Node2D.new()
	viewport.add_child(capture)
	var sprite := Sprite2D.new()
	capture.add_child(sprite)
	var label := Label.new()
	capture.add_child(label)
	bridge._set_character_layer_activity(true)
	check(viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "First capture must render")
	bridge._set_character_layer_activity(true)
	check(viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "Repeated same-frame synchronization must not cancel pending capture")
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	bridge._set_character_layer_activity(true)
	check(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Unchanged layer should retain captured texture")
	for change in [func(): sprite.rotation = .5, func(): sprite.flip_h = true, func(): label.text = "正在换弹", func(): label.visible = false]:
		change.call()
		bridge._set_character_layer_activity(true)
		check(viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "Visual mutation must refresh capture")
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	bridge._set_character_layer_activity(false)
	bridge._set_character_layer_activity(true)
	check(viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "Returning on screen must refresh capture")
	var custom := Node2D.new()
	custom.set_script(load("res://scripts/ui/player_world_health_bar.gd"))
	capture.add_child(custom)
	custom.visible = true
	bridge._set_character_layer_activity(true)
	check(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Unversioned custom drawing must not freeze")
	print("CHARACTER CAPTURE CACHE checks=%d failures=%d" % [checks, failures])
	bridge.queue_free()
	quit(0 if failures == 0 else 1)
