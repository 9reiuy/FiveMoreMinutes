extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")
const RIGHT_HAND_OPEN := preload("res://assets/art/first_person/melatonin/female_right_hand_open.png")
const RIGHT_HAND_GRAB := preload("res://assets/art/first_person/melatonin/female_right_hand_grab.png")
const RIGHT_HAND_SHAKE := preload("res://assets/art/first_person/melatonin/female_right_hand_shake.png")
const RIGHT_HAND_THROW := preload("res://assets/art/first_person/melatonin/female_right_hand_throw.png")
const LEFT_PALM_OPEN := preload("res://assets/art/first_person/melatonin/female_left_palm_open.png")

signal completed
signal cancelled

@export var config: DemoConfig

@onready var right_hand: Node2D = $RightHand
@onready var hand_sprite: Sprite2D = $RightHand/HandSprite
@onready var bottle_sprite: Sprite2D = $RightHand/BottleSprite
@onready var bottle_mouth_marker: Marker2D = $RightHand/BottleMouthMarker
@onready var bottle_grab_marker: Marker2D = $BottleGrabMarker
@onready var table_bottle_sprite: Sprite2D = $TableBottleSprite
@onready var pill_sprite: Sprite2D = $PillSprite

const BOTTLE_GRAB_RADIUS := 80.0

var persistent_state: Dictionary
var held := false
var effective_shakes := 0
var segment_distance := 0.0
var last_direction := 0
var consumed := false
var dispensing := false
var bottle_offset := Vector2.ZERO
var interaction_token := 0
var pill_progress := 0.0
var total_shake_distance := 0.0
var shake_window_left := 0.0
var status_text := "按住药瓶，左右摇晃"
var swallow_audio: AudioStreamPlayer
var consume_progress := 0.0
var hand_reach_progress := 0.0
var hand_ready := false
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var hidden_pointer_nodes: Dictionary = {}
var left_enter_progress := 0.0
var bottle_flip_progress := 0.0
var right_exit_progress := 0.0
var left_exit_progress := 0.0
var table_bottle_taken := false
var animation_state := &"RIGHT_ENTER"
var right_hand_position := Vector2.ZERO
var last_motion_msec := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand_sprite.texture = RIGHT_HAND_OPEN
	bottle_sprite.visible = false
	table_bottle_sprite.position = bottle_grab_marker.position
	table_bottle_sprite.visible = false
	if pill_sprite.texture == null:
		pill_sprite.texture = _create_pill_texture()
	swallow_audio = AudioStreamPlayer.new()
	swallow_audio.bus = &"Environment"
	swallow_audio.stream = TextBlipFactory.create(config)
	swallow_audio.volume_db = config.melatonin_swallow_sound_volume_db
	add_child(swallow_audio)


func open(state: Dictionary) -> void:
	persistent_state = state
	held = false
	effective_shakes = 0
	segment_distance = 0.0
	last_direction = 0
	consumed = false
	dispensing = false
	bottle_offset = Vector2.ZERO
	pill_progress = 0.0
	consume_progress = 0.0
	left_enter_progress = 0.0
	bottle_flip_progress = 0.0
	right_exit_progress = 0.0
	left_exit_progress = 0.0
	table_bottle_taken = false
	animation_state = &"RIGHT_ENTER"
	hand_reach_progress = 0.0
	hand_ready = false
	total_shake_distance = 0.0
	shake_window_left = config.melatonin_shake_window_seconds
	right_hand_position = _clamped_mouse_position()
	last_motion_msec = Time.get_ticks_msec()
	interaction_token += 1
	status_text = "空瓶" if int(state.get("melatonin_inventory", 0)) <= 0 else "按住药瓶，左右摇晃"
	previous_mouse_mode = Input.mouse_mode
	_hide_all_pointers()
	visible = true
	_update_right_hand_visual()
	_update_table_bottle_visual()
	queue_redraw()
	var token := interaction_token
	var reach := create_tween()
	reach.tween_method(func(value: float): hand_reach_progress = value; queue_redraw(), 0.0, 1.0, config.melatonin_hand_reach_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reach.finished
	if token == interaction_token and visible:
		hand_ready = true
		queue_redraw()


func force_cancel() -> void:
	if not visible:
		return
	interaction_token += 1
	visible = false
	held = false
	right_hand.visible = false
	if is_instance_valid(table_bottle_sprite):
		table_bottle_sprite.visible = false
	if is_instance_valid(pill_sprite):
		pill_sprite.visible = false
	_restore_all_pointers()
	SFX.stop_event(&"bottle_shake")
	swallow_audio.stop()
	if not consumed:
		cancelled.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	if not dispensing:
		# The right hand fully replaces the cursor throughout the interactive phase.
		right_hand_position = _clamped_mouse_position()
	_update_right_hand_visual()
	_update_table_bottle_visual()
	_update_pill_visual()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	accept_event()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and hand_ready and not dispensing and (table_bottle_taken or _is_over_grab_marker(event.position)):
			held = true
			table_bottle_taken = true
			_update_right_hand_visual()
			_update_table_bottle_visual()
			last_motion_msec = Time.get_ticks_msec()
		elif not event.pressed:
			_release_bottle()
	elif event is InputEventMouseMotion and held and not dispensing:
		_update_held_bottle(event)


func _release_bottle() -> void:
	held = false
	# Resetting the offset keeps the hand upright once the shaking motion ends,
	# so the bottle no longer tilts while idle or during the subsequent flip.
	bottle_offset = Vector2.ZERO
	SFX.stop_event(&"bottle_shake")
	# Releasing pauses the operation but deliberately preserves the bottle and progress.
	_update_right_hand_visual()
	queue_redraw()


func _is_over_grab_marker(point: Vector2) -> bool:
	if not is_instance_valid(bottle_grab_marker):
		return false
	return point.distance_to(bottle_grab_marker.position) <= BOTTLE_GRAB_RADIUS


func _update_held_bottle(event: InputEventMouseMotion) -> void:
	right_hand_position = _clamp_hand_position(event.position)
	bottle_offset = Vector2(clampf(event.relative.x, -34.0, 34.0), clampf(event.relative.y, -18.0, 18.0))
	var now := Time.get_ticks_msec()
	var elapsed_seconds := maxf(float(now - last_motion_msec) / 1000.0, 0.001)
	last_motion_msec = now
	var velocity := event.relative.length() / elapsed_seconds
	if velocity < config.melatonin_shake_velocity_threshold:
		return
	var direction := signi(int(event.relative.x))
	total_shake_distance += event.relative.length()
	if direction == 0:
		return
	if last_direction == 0 or direction == last_direction:
		segment_distance += absf(event.relative.x)
	else:
		# A reversal counts only when the preceding horizontal stroke was deliberate.
		if segment_distance >= config.melatonin_shake_segment_min_distance:
			effective_shakes += 1
			_play_shake_sound_if_available()
		segment_distance = absf(event.relative.x)
	last_direction = direction
	if effective_shakes >= config.melatonin_shake_direction_changes_required and total_shake_distance >= config.melatonin_shake_distance_required:
		_begin_pill_drop()


func _clamped_mouse_position() -> Vector2:
	return _clamp_hand_position(get_viewport().get_mouse_position())


func _clamp_hand_position(point: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(clampf(point.x, 64.0, viewport_size.x - 64.0), clampf(point.y, 64.0, viewport_size.y - 64.0))


func _play_shake_sound_if_available() -> void:
	if not held or dispensing or int(persistent_state.get("melatonin_inventory", 0)) <= 0:
		return
	SFX.play_event(&"bottle_shake")


func _begin_pill_drop() -> void:
	if dispensing:
		return
	if int(persistent_state.get("melatonin_inventory", 0)) <= 0:
		status_text = "空瓶"
		return
	dispensing = true
	held = false
	# Clear the shake offset so the hand is upright when dispensing begins.
	bottle_offset = Vector2.ZERO
	table_bottle_taken = true
	_update_right_hand_visual()
	_update_table_bottle_visual()
	SFX.stop_event(&"bottle_shake")
	status_text = ""
	var token := interaction_token
	animation_state = &"LEFT_ENTER"
	var left_enter := create_tween()
	left_enter.tween_method(func(value: float): left_enter_progress = value; queue_redraw(), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await left_enter.finished
	if token != interaction_token or not visible: return
	animation_state = &"BOTTLE_FLIP"
	var flip := create_tween()
	flip.tween_method(func(value: float): bottle_flip_progress = value; queue_redraw(), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await flip.finished
	if token != interaction_token or not visible: return
	animation_state = &"PILL_ARC"
	var pill_tween := create_tween()
	pill_tween.tween_method(func(value: float): pill_progress = value; queue_redraw(), 0.0, 1.0, config.melatonin_pill_throw_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await pill_tween.finished
	if token != interaction_token or not visible or consumed:
		return
	# Recheck stock at the hand before beginning the non-interactive consume motion.
	if int(persistent_state.get("melatonin_inventory", 0)) <= 0:
		status_text = "空瓶"
		dispensing = false
		return
	await get_tree().create_timer(config.melatonin_consume_pre_swallow_pause, false).timeout
	if token != interaction_token or not visible:
		return
	animation_state = &"RIGHT_EXIT"
	var right_exit := create_tween()
	right_exit.tween_method(func(value: float): right_exit_progress = value; queue_redraw(), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await right_exit.finished
	if token != interaction_token or not visible: return
	animation_state = &"LEFT_TO_CAMERA"
	var consume_tween := create_tween()
	consume_tween.tween_method(func(value: float): consume_progress = value; queue_redraw(), 0.0, 1.0, config.melatonin_consume_hand_approach_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await consume_tween.finished
	if token != interaction_token or not visible:
		return
	if int(persistent_state.get("melatonin_inventory", 0)) <= 0:
		status_text = "空瓶"
		dispensing = false
		return
	swallow_audio.stop()
	swallow_audio.play()
	status_text = "咽下去了"
	queue_redraw()
	await get_tree().create_timer(config.melatonin_consume_end_pause, false).timeout
	if token == interaction_token and visible:
		if int(persistent_state.get("melatonin_inventory", 0)) <= 0:
			status_text = "空瓶"
			dispensing = false
			return
		# 库存、当晚片数信号与压力只在完整演出结束后一次性提交。
		persistent_state.melatonin_inventory = int(persistent_state.melatonin_inventory) - 1
		STATE_RULES.change_stress(persistent_state, -config.stress_melatonin_reduction, &"melatonin", config)
		consumed = true
		animation_state = &"LEFT_EXIT"
		var left_exit := create_tween()
		left_exit.tween_method(func(value: float): left_exit_progress = value; queue_redraw(), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await left_exit.finished
		if token != interaction_token: return
		visible = false
		_restore_all_pointers()
		completed.emit()


func is_table_bottle_taken() -> bool:
	return table_bottle_taken


func _hide_all_pointers() -> void:
	hidden_pointer_nodes.clear()
	for node in get_tree().get_nodes_in_group("custom_crosshairs"):
		if node is CanvasItem:
			hidden_pointer_nodes[node.get_instance_id()] = {"node": node, "visible": node.visible}
			node.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _restore_all_pointers() -> void:
	Input.mouse_mode = previous_mouse_mode
	for saved in hidden_pointer_nodes.values():
		var node: Variant = saved.get("node")
		if is_instance_valid(node):
			node.visible = bool(saved.get("visible", false))
	hidden_pointer_nodes.clear()


func _update_right_hand_visual() -> void:
	if not is_instance_valid(right_hand):
		return
	right_hand.visible = visible
	if not visible:
		return
	var hand_position := Vector2(size.x + 80.0, size.y - 40.0).lerp(right_hand_position, hand_reach_progress)
	var hand_scale := lerpf(0.68, 0.82, hand_reach_progress)
	var progress := clampf(float(effective_shakes) / maxf(config.melatonin_shake_direction_changes_required, 1), 0.0, 1.0)
	var angle := clampf(bottle_offset.x / 34.0, -1.0, 1.0) * deg_to_rad(config.melatonin_bottle_rotation_degrees) * (0.35 + progress * 0.65)
	if dispensing:
		# The hand stays upright throughout the dispense sequence; the BOTTLE_FLIP
		# tween below only paces the beat before the pill arc, it no longer rotates.
		hand_position += Vector2(220.0 * right_exit_progress, -40.0 * right_exit_progress)
	right_hand.position = hand_position
	right_hand.rotation = angle
	right_hand.scale = Vector2.ONE * hand_scale
	# The existing grip/shake/throw art is a hand+bottle composite. Keeping it on the
	# dedicated BottleSprite prevents a one-frame gap and preserves the drawn fingers.
	hand_sprite.visible = not table_bottle_taken
	hand_sprite.texture = RIGHT_HAND_OPEN
	bottle_sprite.visible = table_bottle_taken
	if dispensing:
		bottle_sprite.texture = RIGHT_HAND_THROW
	elif effective_shakes > 0:
		bottle_sprite.texture = RIGHT_HAND_SHAKE
	else:
		bottle_sprite.texture = RIGHT_HAND_GRAB


func _update_table_bottle_visual() -> void:
	if not is_instance_valid(table_bottle_sprite):
		return
	table_bottle_sprite.position = bottle_grab_marker.position
	table_bottle_sprite.visible = visible and not table_bottle_taken


func _create_pill_texture() -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var center := Vector2(8, 8)
	for x in 16:
		for y in 16:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf(6.5 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.85, 0.83, 0.76, alpha))
	return ImageTexture.create_from_image(image)


func _current_left_position() -> Vector2:
	var left_position := Vector2(145, 395).lerp(Vector2(245, 230), left_enter_progress)
	if consume_progress > 0.0:
		left_position = Vector2(245, 230).lerp(Vector2(320, 205), consume_progress)
	left_position += Vector2(-180.0 * left_exit_progress, 80.0 * left_exit_progress)
	return left_position


func _update_pill_visual() -> void:
	if not is_instance_valid(pill_sprite):
		return
	var show := visible and pill_progress > 0.0 and consume_progress < 0.85 and not consumed
	pill_sprite.visible = show
	if not show:
		return
	var left_position := _current_left_position()
	var left_scale := lerpf(0.72, config.melatonin_consume_hand_max_scale, consume_progress)
	var pill_start := get_global_transform().affine_inverse() * bottle_mouth_marker.global_position
	var pill_end := left_position + Vector2(0, -18) * left_scale
	if pill_progress >= 1.0:
		pill_sprite.position = pill_end
		return
	var pill_control := (pill_start + pill_end) * 0.5 + Vector2(-18, -32)
	var first := pill_start.lerp(pill_control, pill_progress)
	var second := pill_control.lerp(pill_end, pill_progress)
	pill_sprite.position = first.lerp(second, pill_progress)


func _exit_tree() -> void:
	if visible or not hidden_pointer_nodes.is_empty():
		_restore_all_pointers()


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("161720"))
	var font := PixelFont.get_font()
	var left_position := _current_left_position()
	var left_scale := lerpf(0.72, config.melatonin_consume_hand_max_scale, consume_progress)
	if left_enter_progress > 0.0:
		draw_texture_rect(LEFT_PALM_OPEN, Rect2(left_position - Vector2(128,128) * left_scale, Vector2(256,256) * left_scale), false)
	if consume_progress > 0.0:
		var vignette_alpha := consume_progress * config.melatonin_consume_vignette_alpha
		var edge := lerpf(18.0, 92.0, consume_progress)
		draw_rect(Rect2(0, 0, size.x, edge), Color(0.01, 0.01, 0.015, vignette_alpha))
		draw_rect(Rect2(0, size.y - edge, size.x, edge), Color(0.01, 0.01, 0.015, vignette_alpha))
		draw_rect(Rect2(0, 0, edge, size.y), Color(0.01, 0.01, 0.015, vignette_alpha * 0.75))
		draw_rect(Rect2(size.x - edge, 0, edge, size.y), Color(0.01, 0.01, 0.015, vignette_alpha * 0.75))
	draw_string(font, Vector2(0, 72), status_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 18, Color("c4c1c6"))
	draw_string(font, Vector2(0, 348), "Esc 取消", HORIZONTAL_ALIGNMENT_CENTER, 640, 12, Color("696c76"))
