extends Node
## Share the actual game Camera's finished output; no second world render.
const FRAME_CACHE=preload("res://scripts/story/tutorial_camera_frame_cache.gd")
var source_camera: Camera3D
var source_viewport: Viewport
var player: Node2D
var room_rects: Array
var stations: Array[Node3D]=[]
var frame_cache: RefCounted
var active_room := -1

func configure(game_camera: Camera3D,actor: Node2D,rooms: Array,televisions: Array[Node3D]) -> void:
	source_camera=game_camera;player=actor;room_rects=rooms;stations=televisions
	frame_cache=FRAME_CACHE.new()
	for station in stations:station.set_camera_feed(frame_cache.output)
	RenderingServer.frame_post_draw.connect(_capture_finished_frame)
	update_frame()

func update_frame() -> void:
	if not is_instance_valid(source_camera) or not is_instance_valid(player):return
	source_viewport=source_camera.get_viewport()
	active_room=-1
	var cell:=player.global_position/32.0
	for index in room_rects.size():
		var room: Rect2i=room_rects[index]
		if Rect2(Vector2(room.position)-Vector2.ONE*.5,Vector2(room.size)).has_point(cell):active_room=index;break
	for index in stations.size():stations[index].set_screen_active(index==active_room)

func _capture_finished_frame() -> void:
	if active_room>=0 and is_instance_valid(source_viewport) and frame_cache!=null:
		frame_cache.capture(source_viewport)

func _exit_tree() -> void:
	var ancestor: Node=self
	while ancestor!=null:
		if ancestor.has_meta(&"display_reparenting"):return
		ancestor=ancestor.get_parent()
	if RenderingServer.frame_post_draw.is_connected(_capture_finished_frame):
		RenderingServer.frame_post_draw.disconnect(_capture_finished_frame)
	for station in stations:
		if is_instance_valid(station):station.set_camera_feed(null)
	if frame_cache!=null:frame_cache.stop()
