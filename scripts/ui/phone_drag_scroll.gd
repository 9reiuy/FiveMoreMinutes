class_name PhoneDragScroll
extends ScrollContainer

@export var drag_threshold := 6.0

var drag_candidate := false
var drag_active := false
var drag_start_y := 0.0
var last_y := 0.0
var suppress_click_until_msec := 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_candidate = true
			drag_active = false
			drag_start_y = event.position.y
			last_y = event.position.y
		else:
			if drag_active:
				suppress_click_until_msec = Time.get_ticks_msec() + 120
				accept_event()
			drag_candidate = false
			drag_active = false
	elif event is InputEventMouseMotion and drag_candidate and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if not drag_active and absf(event.position.y - drag_start_y) >= drag_threshold:
			drag_active = true
		if drag_active:
			scroll_vertical += int(last_y - event.position.y)
			last_y = event.position.y
			accept_event()
	elif event is InputEventPanGesture:
		scroll_vertical += int(event.delta.y * 36.0)
		accept_event()


func should_suppress_click() -> bool:
	return drag_active or Time.get_ticks_msec() <= suppress_click_until_msec
