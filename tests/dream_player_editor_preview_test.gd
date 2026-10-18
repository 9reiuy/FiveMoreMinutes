extends SceneTree

const PLAYER_SCENE := preload("res://scenes/entities/dream_player.tscn")


func _init() -> void:
	var player := PLAYER_SCENE.instantiate()
	var visual := player.get_node("CharacterVisual") as Node2D
	var expected_positions := {
		"LeftLeg": Vector2(-7, -14),
		"RightLeg": Vector2(1, -14),
		"Head": Vector2(-17, -62),
		"Body": Vector2(-10, -30),
	}
	for part_name in expected_positions:
		var part := visual.get_node(part_name) as Sprite2D
		if part.texture == null:
			_fail("%s texture is empty before _ready()" % part_name)
			player.free()
			return
		if part.position != expected_positions[part_name]:
			_fail("%s position mismatch: %s" % [part_name, part.position])
			player.free()
			return
	var head := visual.get_node("Head") as Sprite2D
	var body := visual.get_node("Body") as Sprite2D
	if head.z_index != body.z_index or head.get_index() >= body.get_index():
		_fail("Head must share the Body world Z and render earlier in scene order")
		player.free()
		return
	# 加入场景树后只验证既有方向切换/动画仍以序列化坐标为基准；测试不依赖主流程动态创建纹理。
	for action_name in [&"move_left", &"move_right", &"move_up", &"move_down", &"dash"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.call("_update_direction_animation", Vector2.UP, 0.1)
	var active_head_texture := head.texture as AtlasTexture
	if active_head_texture == null or active_head_texture.region != Rect2(82, 4, 35, 33):
		_fail("up direction did not switch to the serialized back head texture: type=%s region=%s" % [type_string(typeof(head.texture)), active_head_texture.region if active_head_texture != null else Rect2()])
		player.free()
		return
	player.call("_update_direction_animation", Vector2.DOWN, 0.1)
	active_head_texture = head.texture as AtlasTexture
	if active_head_texture == null or active_head_texture.region != Rect2(17, 3, 35, 34):
		_fail("down direction did not restore the serialized front head texture")
		player.free()
		return
	player.call("_update_direction_animation", Vector2.RIGHT, 0.1)
	player.call("_update_direction_animation", Vector2.ZERO, 0.0)
	for part_name in expected_positions:
		var part := visual.get_node(part_name) as Sprite2D
		if part.position != expected_positions[part_name]:
			_fail("%s did not return to its scene position: %s" % [part_name, part.position])
			player.free()
			return
	print("DREAM PLAYER EDITOR PREVIEW TEST PASSED")
	player.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
