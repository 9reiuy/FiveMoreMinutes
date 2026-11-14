extends "res://scripts/ui/dialogue/growing_dialogue_bubble.gd"
## One formal dialogue bubble, showing either a pixel emotion or a short word.
const EMOTION_PIXELS=preload("res://scripts/ui/npc_emotion_hint.gd")
var face: Control
var hint_kind: StringName=&"hidden"
var hint_text:=""

func _ready() -> void:
	super._ready()
	face=EMOTION_PIXELS.new();face.name="EmotionPixels";face.draw_frame=false
	add_child(face);face.set_process(false);face.modulate=Color.WHITE;face.hide()

func present_emotion(speaker: Vector2, feeling: StringName) -> void:
	if not get_viewport_rect().grow(16).has_point(speaker):dismiss(0);return
	super.present_hint(speaker,"")
	hint_kind=&"emotion";hint_text=""
	dialogue_label.hide();face.emotion=feeling;face.show();face.queue_redraw()
	_align_face();_use_presentation_time()

func present_word(speaker: Vector2, word: String) -> void:
	if not get_viewport_rect().grow(16).has_point(speaker):dismiss(0);return
	super.present_hint(speaker,word)
	hint_kind=&"word";hint_text=word
	face.hide();dialogue_label.show();_use_presentation_time()

func _process(delta: float) -> void:
	super._process(delta)
	_align_face()

func _align_face() -> void:
	if is_instance_valid(face):face.position=((size-Vector2(32,25))*.5).round()

func _use_presentation_time() -> void:
	if _fade!=null and _fade.is_valid():_fade.set_ignore_time_scale(true)

func dismiss(fade_time: float=.18) -> void:
	hint_kind=&"hidden";hint_text=""
	super.dismiss(fade_time);_use_presentation_time()

func prompt_anchor(prompt_size: Vector2) -> Vector2:
	return (position+Vector2((size.x-prompt_size.x)*.5,-prompt_size.y-8)).round()
