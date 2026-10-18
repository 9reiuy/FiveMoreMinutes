class_name TransitionDirector
extends Control

## TransitionDirector (TASK-020-B)
## Shared pixel-block cover, scene readiness, cancellation and reveal.

enum State {
	IDLE,
	COVERING,
	WAITING_FOR_SCENE,
	REVEALING
}

signal transition_covered
signal transition_finished

const SHARD_SHADER := preload("res://shaders/transitions/dream_shard_transition.gdshader")

const MASKS := {
	"edge_fracture": preload("res://assets/transitions/masks/mask_edge_fracture.png"),
	"shattered_memory": preload("res://assets/transitions/masks/mask_shattered_memory.png"),
	"diagonal_tear": preload("res://assets/transitions/masks/mask_diagonal_tear.png"),
}

const PIXEL=preload("res://scripts/ui/pixel_transition.gd")
const DEFAULT_COVER_DURATION := 0.25
const DEFAULT_REVEAL_DURATION := 0.30


var color_rect: ColorRect = null

var current_state: State = State.IDLE
var material_instance: ShaderMaterial = null

var current_token: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	if has_node("OverlayRect"):
		color_rect = get_node("OverlayRect") as ColorRect
	else:
		color_rect = ColorRect.new()
		color_rect.name = "OverlayRect"
		add_child(color_rect)

	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.visible = false
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	color_rect.grow_vertical = Control.GROW_DIRECTION_BOTH

	_sync_viewport_size()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_sync_viewport_size)

	# Setup shader material
	material_instance = ShaderMaterial.new()
	material_instance.shader = PIXEL.SHADER
	material_instance.set_shader_parameter("progress", 0.0)
	material_instance.set_shader_parameter("transition_mode", 0)
	color_rect.material = material_instance


func _sync_viewport_size() -> void:
	var vp_size := Vector2(640, 360)
	if get_viewport() != null:
		var actual := get_viewport_rect().size
		if actual.x > 0 and actual.y > 0:
			vp_size = actual
	set_deferred("size", vp_size)
	if is_instance_valid(color_rect):
		color_rect.set_deferred("size", vp_size)



func is_transition_running() -> bool:
	return current_state != State.IDLE


func cover(mask_id: String = "edge_fracture", duration: float = DEFAULT_COVER_DURATION) -> bool:
	if current_state != State.IDLE:
		push_warning("TransitionDirector: Transition already running; request rejected.")
		return false

	current_token += 1
	var token := current_token
	current_state = State.COVERING

	# Setup transition mode on shader
	var mode := 0
	if mask_id == "shattered_memory" or mask_id == "diagonal":
		mode = 1
	elif mask_id == "radial" or mask_id == "centripetal":
		mode = 2
	elif mask_id == "diagonal_tear" or mask_id == "horizontal":
		mode = 3
	else:
		mode = 0

	material_instance.set_shader_parameter("transition_mode", mode)
	material_instance.set_shader_parameter("progress", 0.0)
	material_instance.set_shader_parameter("invert", false)

	# Block input
	color_rect.visible = true
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_filter = Control.MOUSE_FILTER_STOP

	if not await PIXEL.animate(color_rect,0.0,1.0,duration,_is_current.bind(token)): return false

	material_instance.set_shader_parameter("progress", 1.0)
	# CPU coverage is not a submitted black frame. Heavy scene _ready work
	# must only begin after the actual output has received this endpoint.
	await PIXEL.present(get_tree())
	if not _is_current(token): return false
	current_state = State.WAITING_FOR_SCENE
	transition_covered.emit()
	return true


func reveal(duration: float = DEFAULT_REVEAL_DURATION) -> bool:
	if current_state != State.WAITING_FOR_SCENE: return false
	var token:=current_token
	current_state=State.REVEALING
	# Remain opaque at entry; reverse coverage instead of flipping inversion
	# while progress still describes the previous endpoint.
	material_instance.set_shader_parameter("invert",false)
	material_instance.set_shader_parameter("progress",1.0)
	if not await PIXEL.animate(color_rect,1.0,0.0,duration,_is_current.bind(token)): return false
	_reset_to_idle()
	transition_finished.emit()
	return true

func _is_current(token: int)->bool:
	return token==current_token and is_inside_tree()

func cancel_transition()->void:
	current_token+=1
	_reset_to_idle()
	transition_finished.emit()

func _input(_event: InputEvent)->void:
	if is_transition_running(): get_viewport().set_input_as_handled()


func play_transition(
	mask_id: String = "edge_fracture",
	scene_callback: Callable = Callable(),
	cover_duration: float = DEFAULT_COVER_DURATION,
	reveal_duration: float = DEFAULT_REVEAL_DURATION
) -> bool:
	var covered := await cover(mask_id, cover_duration)
	if not covered:
		return false
	var token:=current_token

	# Execute scene callback
	if scene_callback.is_valid():
		var cb_result = scene_callback.call()
		if cb_result is Signal:
			await cb_result
		elif cb_result is Dictionary and cb_result.has("wait"):
			await cb_result["wait"]

	await PIXEL.present(get_tree(),2)
	if not _is_current(token): return false

	return await reveal(reveal_duration)


func _reset_to_idle() -> void:
	current_state = State.IDLE
	if is_instance_valid(material_instance):
		material_instance.set_shader_parameter("progress", 0.0)
		material_instance.set_shader_parameter("invert", false)
	if is_instance_valid(color_rect):
		color_rect.visible = false
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
