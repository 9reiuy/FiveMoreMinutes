class_name DreamRoomDoor
extends Area2D

signal entered(destination_room_id: int, travel_direction: StringName, final_wake: bool)

const WORLD_WALL_LAYER := 4
const WORLD_WALL_MASK := 1 | 2 | 8

var destination_room_id := -1
var destination_type: StringName = &"combat"
var door_direction: StringName = &"top"
var final_wake := false
var door_open := true
var opening_width := 32.0
var transition_requested := false
var transition_collision: CollisionShape2D
var blocking_collision: CollisionShape2D
var spawn_point: Marker2D
var transition_candidates: Array[Node2D] = []
var transition_line_depth := 8.0


func configure(destination_id: int, room_type: StringName, direction: StringName, is_final_wake: bool, wall_opening_width: float) -> void:
	destination_room_id = destination_id
	destination_type = room_type
	door_direction = direction
	final_wake = is_final_wake
	opening_width = maxf(32.0, wall_opening_width)
	rotation = {&"top": 0.0, &"right": PI * 0.5, &"bottom": PI, &"left": -PI * 0.5}.get(direction, 0.0)
	collision_layer = 0
	collision_mask = 1
	# configure由RoomManager在add_child前调用；离树状态下先保持关闭，再Deferred启用。
	monitoring = false
	monitorable = false
	transition_collision = CollisionShape2D.new()
	transition_collision.disabled = true
	var shape := RectangleShape2D.new()
	# Door根位于室内门槛Socket；本地-Y经四向rotation后始终指向门深处。
	# Trigger覆盖门槛内外两侧，但横向严格收进门洞；擦墙/黑边不会触发过门。
	shape.size = Vector2(maxf(8.0, opening_width - 8.0), 40.0)
	transition_collision.shape = shape
	transition_collision.position = Vector2(0, -8.0)
	add_child(transition_collision)
	spawn_point = Marker2D.new()
	spawn_point.name = "SpawnPoint"
	add_child(spawn_point)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 普通连接门与最终出口都保留一个可禁用的阻挡体：
	# 开门时关闭它，关门时重新阻挡Player和Vision Ray。
	var blocker := StaticBody2D.new()
	blocker.name = "DoorBlocker"
	blocker.collision_layer = WORLD_WALL_LAYER
	blocker.collision_mask = WORLD_WALL_MASK
	blocking_collision = CollisionShape2D.new()
	blocking_collision.name = "CollisionShape2D"
	var blocking_shape := RectangleShape2D.new()
	blocking_shape.size = Vector2(opening_width - 2.0, 24)
	blocking_collision.shape = blocking_shape
	blocking_collision.position = Vector2(0, 3)
	blocker.add_child(blocking_collision)
	add_child(blocker)
	queue_redraw()


func set_spawn_world_position(world_position: Vector2) -> void:
	if spawn_point != null:
		spawn_point.global_position = world_position


func activate_deferred() -> void:
	transition_requested = false
	transition_candidates.clear()
	set_deferred("monitorable", false)
	set_deferred("monitoring", true)
	if transition_collision != null:
		transition_collision.set_deferred("disabled", false)


func set_open(value: bool) -> void:
	door_open = value
	if blocking_collision != null:
		blocking_collision.set_deferred("disabled", door_open)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not door_open or transition_requested or not body.is_in_group("dream_player") or not body is Node2D:
		return
	if not transition_candidates.has(body):
		transition_candidates.append(body as Node2D)


func _on_body_exited(body: Node) -> void:
	transition_candidates.erase(body)


func _physics_process(_delta: float) -> void:
	if not door_open or transition_requested:
		return
	for candidate in transition_candidates.duplicate():
		if not is_instance_valid(candidate):
			transition_candidates.erase(candidate)
			continue
		if to_local(candidate.global_position).y <= -transition_line_depth:
			_request_player_transition()
			return


func _request_player_transition() -> void:
	transition_requested = true
	transition_candidates.clear()
	set_deferred("monitoring", false)
	if transition_collision != null:
		transition_collision.set_deferred("disabled", true)
	# 这里只提出请求；RoomManager会在Physics Query结束后Deferred派发并重建房间。
	entered.emit(destination_room_id, door_direction, final_wake)


func _draw() -> void:
	# 普通连接门完全由DoorLayer绘制；最终醒来出口保持独立的黑幕表现。
	if not final_wake:
		return
	var half_width := opening_width * 0.5
	draw_rect(Rect2(-half_width, -15, opening_width, 30), Color(0.005, 0.008, 0.014, 1.0))
	draw_rect(Rect2(-half_width + 3.0, -11, opening_width - 6.0, 26), Color(0.012, 0.018, 0.03, 1.0))
	if door_open:
		draw_line(Vector2(-half_width + 4.0, 13), Vector2(half_width - 4.0, 13), Color(0.12, 0.2, 0.27, 0.72), 1.0)
	else:
		# Final Wake入口在Boss存活时仅显示更深的封闭黑幕，仍保持通道视觉。
		draw_rect(Rect2(-half_width + 3.0, -11, opening_width - 6.0, 26), Color(0.025, 0.018, 0.04, 0.96))
