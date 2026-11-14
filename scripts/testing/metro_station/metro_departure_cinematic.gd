extends Node
## A presentation-only speaker on the far platform, owned by the station.

const EMPLOYEE := preload("res://scenes/entities/employee_enemy.tscn")
const BOSS_ART := preload("res://scripts/testing/metro_station/metro_boss_art.gd")
const SPEAKER_ATLAS: Texture2D = BOSS_ART.ATLAS
const BUBBLE := preload("res://scenes/ui/dialogue/growing_dialogue_bubble.tscn")
const LINE := "别让她回到公司"
const SPEECH_SECONDS := 1.45
const BOARD_SECONDS := .72
const RETURN_SECONDS := .30

enum Beat { IDLE, PAN, SPEAK, BOARD, RETURN, DONE }

var beat := Beat.IDLE
var _world: Node3D
var _speaker: EmployeeEnemy
var _visual: Node3D
var _bubble_layer: CanvasLayer
var _bubble_canvas: Node2D
var _bubble: DreamDialogueBubble
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _elapsed := 0.0
var _saved_pose: Transform3D
var _shot_pose: Transform3D
var _saved_zoom := 1.0
var _saved_enter_time := .45
var _saved_movement := true
var _saved_attack := true
var _saved_dash := true


func play(world: Node3D, bridge: Node3D, doorway_lane: float) -> void:
	if beat != Beat.IDLE:
		return
	if bridge == null:
		beat = Beat.DONE
		return
	_world = world
	var at := Vector2(bridge.global_position.x + doorway_lane, bridge.global_position.z)
	_from = (at - Vector2(0.0, 2.22)) * world.CELL_PIXELS
	_to = (at + Vector2(0.0, .67)) * world.CELL_PIXELS
	_speaker = EMPLOYEE.instantiate() as EmployeeEnemy
	_speaker.name = "FarPlatformSpeaker"
	_speaker.position = _from
	_speaker.remove_from_group(&"dream_enemies")
	_speaker.remove_from_group(&"employee_enemies")
	add_child(_speaker)
	_speaker.set_room_runtime_active(false)
	_speaker.set_room_preview_visible(true)
	_speaker.hurtbox.set_deferred("monitorable", false)
	BOSS_ART.apply(_speaker)
	_visual = world._spawn_depth_bridge(_speaker, [^"CharacterVisual"])

	var player: Node2D = world.player
	_saved_movement = player.movement_enabled
	_saved_attack = player.attacking_enabled
	_saved_dash = player.dash_enabled
	player.movement_enabled = false
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	player.velocity = Vector2.ZERO

	_saved_pose = world.camera_3d.transform
	# A steeper view clears the train roof when looking onto the far platform.
	var offset := _saved_pose.origin.rotated(Vector3.RIGHT, -deg_to_rad(16.0))
	_shot_pose = Transform3D(Basis.looking_at(-offset, Vector3.UP), offset)
	_saved_zoom = world.dialogue_camera.dialogue_zoom_factor
	_saved_enter_time = world.dialogue_camera.dialogue_enter_duration
	world.dialogue_camera.dialogue_zoom_factor = .86
	world.dialogue_camera.dialogue_enter_duration = .64
	world.begin_dialogue_focus(_speaker, Dream3DDialogueCamera.FocusMode.SPEAKER_FOCUS)
	beat = Beat.PAN


func apply_camera_pose() -> void:
	if beat > Beat.IDLE and beat < Beat.DONE:
		var weight: float = _world.dialogue_camera.get_dialogue_weight()
		_world.camera_3d.transform = _saved_pose.interpolate_with(_shot_pose, weight)


func boarding_progress() -> float:
	if beat >= Beat.RETURN:
		return 1.0
	return minf(_elapsed / BOARD_SECONDS, 1.0) if beat == Beat.BOARD else 0.0


func advance(delta: float) -> void:
	_elapsed += delta
	match beat:
		Beat.PAN:
			if _world.dialogue_camera.state == Dream3DDialogueCamera.FocusState.ACTIVE:
				_show_line()
				_elapsed = 0.0
				beat = Beat.SPEAK
		Beat.SPEAK:
			if _elapsed >= SPEECH_SECONDS:
				_bubble.dismiss(.14)
				_speaker.velocity = (_to - _from) / BOARD_SECONDS
				_elapsed = 0.0
				beat = Beat.BOARD
		Beat.BOARD:
			var fraction := boarding_progress()
			_speaker.position = _from.lerp(_to, fraction)
			_speaker._update_human_animation(delta)
			if fraction >= 1.0:
				_speaker.hide()
				if is_instance_valid(_visual):
					_visual.hide()
				_world.dialogue_camera.end_dialogue_focus(RETURN_SECONDS)
				beat = Beat.RETURN
		Beat.RETURN:
			if _world.dialogue_camera.state == Dream3DDialogueCamera.FocusState.INACTIVE:
				_finish()


func cancel() -> void:
	if beat > Beat.IDLE and beat < Beat.DONE:
		if is_instance_valid(_world) and is_instance_valid(_world.dialogue_camera):
			_world.clear_dialogue_focus()
		_finish()


func _exit_tree() -> void:
	cancel()


func _show_line() -> void:
	_bubble_layer = CanvasLayer.new()
	_bubble_layer.name = "MetroSpeech"
	_bubble_layer.layer = 24
	# Keep the 640x360 speaker coordinates and the bubble in the game viewport.
	_bubble_layer.set_meta(&"world_post_effect", true)
	add_child(_bubble_layer)
	_bubble_canvas = Node2D.new()
	_bubble_canvas.name = "SpeakerCanvas"
	_bubble_canvas.scale = _speech_canvas_scale()
	_bubble_layer.add_child(_bubble_canvas)
	_bubble = BUBBLE.instantiate() as DreamDialogueBubble
	_bubble_canvas.add_child(_bubble)
	_bubble.background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bubble.margin_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bubble.call("present_hint", _speaker_hud_position(), LINE)
	_bubble.pivot_offset = Vector2(_bubble.size.x * .5, _bubble.size.y)
	_bubble.scale = Vector2.ONE * 1.8


func _speaker_hud_position() -> Vector2:
	return _world.camera_3d.unproject_position(_world.get_gameplay_world_position(_speaker.global_position, 1.04)) / _speech_canvas_scale()


func _speech_canvas_scale() -> Vector2:
	return _world.camera_3d.get_viewport().get_visible_rect().size / DreamDialogueBubble.SCREEN_SIZE


func update_speech_anchor() -> void:
	# Called after the world's final camera update, in either viewport mode.
	if beat not in [Beat.SPEAK, Beat.BOARD] or not is_instance_valid(_bubble) or not is_instance_valid(_speaker):
		return
	_bubble_canvas.scale = _speech_canvas_scale()
	_bubble.set_speaker_hud_position(_speaker_hud_position())


func _finish() -> void:
	beat = Beat.DONE
	if is_instance_valid(_world):
		if is_instance_valid(_world.camera_3d):
			_world.camera_3d.transform = _saved_pose
		if is_instance_valid(_world.dialogue_camera):
			_world.dialogue_camera.dialogue_zoom_factor = _saved_zoom
			_world.dialogue_camera.dialogue_enter_duration = _saved_enter_time
		var player: Node2D = _world.player
		if is_instance_valid(player) and not player.dead:
			player.movement_enabled = _saved_movement
			player.set_attacking_enabled(_saved_attack)
			player.set_dash_enabled(_saved_dash)
	for node in [_bubble_layer, _visual, _speaker]:
		if is_instance_valid(node):
			node.queue_free()
