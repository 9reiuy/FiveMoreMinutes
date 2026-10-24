extends Control
## Small pixel faces, separate from the unmodified dialogue text bubble.
const EMOTIONS: Array[StringName]=[&"neutral",&"happy",&"joy",&"angry",&"sad",&"surprised",&"nervous"]
const BLUE:=Color("396FE2")
const INK:=Color("edece3")
var emotion: StringName=&"happy"
var reveal:=0.0
var wanted:=false
var anchor:=Vector2.ZERO
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(32,25); modulate.a=0; hide(); set_process(false)
func present_hint(speaker: Vector2, feeling: StringName=&"happy") -> void:
	if not get_viewport_rect().grow(16).has_point(speaker): dismiss(); return
	anchor=speaker.round()
	emotion=feeling if feeling in EMOTIONS else &"neutral"
	wanted=true; show(); set_process(true); _layout(); queue_redraw()
func dismiss() -> void:
	wanted=false
func _process(delta: float) -> void:
	if get_tree().paused:
		wanted=false; reveal=0; hide(); set_process(false); return
	reveal=move_toward(reveal,1.0 if wanted else 0.0,delta/.12)
	modulate.a=reveal
	_layout()
	if not wanted and reveal<=0: hide(); set_process(false)
func _layout() -> void:
	# Keep the tail attached to the NPC rather than pinning its bubble to an edge.
	position=(anchor-Vector2(size.x*.5,size.y+10)+Vector2(0,roundf((1-reveal)*4))).round()
func prompt_anchor(prompt_size: Vector2) -> Vector2:
	return (position+Vector2((size.x-prompt_size.x)*.5,-prompt_size.y-8)).round()
func _draw() -> void:
	var outline:=PackedVector2Array([Vector2(3,0),Vector2(29,0),Vector2(31,2),Vector2(31,20),Vector2(29,22),Vector2(18,22),Vector2(15,25),Vector2(15,22),Vector2(3,22),Vector2(1,20),Vector2(1,2),Vector2(3,0)])
	draw_colored_polygon(outline,Color("101823")); draw_polyline(outline,BLUE,1,false)
	draw_line(Vector2(4,2),Vector2(27,2),Color(BLUE,.45),1)
	# All features use integer pixel rectangles, not font-dependent Unicode.
	match emotion:
		&"happy":
			pixels([[11,7,2,2],[20,7,2,2],[11,12,2,2],[13,14,7,2],[20,12,2,2]])
		&"joy":
			pixels([[10,8,2,2],[12,6,2,2],[14,8,2,2],[19,8,2,2],[21,6,2,2],[23,8,2,2],[12,12,11,2],[14,14,7,2]])
		&"angry":
			pixels([[10,5,2,2],[12,6,3,2],[20,6,3,2],[23,5,2,2],[12,9,2,2],[21,9,2,2],[14,14,7,2],[12,16,2,1],[21,16,2,1]])
		&"sad":
			pixels([[10,7,3,1],[13,5,2,2],[20,5,2,2],[22,7,3,1],[12,9,2,2],[21,9,2,2],[14,14,7,1],[12,15,2,2],[21,15,2,2],[11,11,1,4],[24,11,1,4]])
		&"surprised":
			pixels([[11,7,2,3],[21,7,2,3],[15,12,5,1],[14,13,1,4],[20,13,1,4],[15,17,5,1]])
		&"nervous":
			pixels([[9,8,5,1],[19,8,4,1],[11,10,2,2],[20,10,2,2],[12,15,3,1],[15,14,3,1],[18,15,3,1]])
			pixels([[26,4,1,2],[25,6,3,3],[26,9,1,1]],BLUE)
		_:
			pixels([[11,7,2,2],[21,7,2,2],[13,14,9,1]])
func pixels(rectangles: Array,color: Color=INK) -> void:
	for rect in rectangles: draw_rect(Rect2(rect[0],rect[1],rect[2],rect[3]),color)
