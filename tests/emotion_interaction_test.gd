extends SceneTree
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(640,360)
	var prompt:=preload("res://scripts/ui/compact_interaction_prompt.gd").new()
	root.add_child(prompt); prompt.size=Vector2(128,18)
	check(prompt.FRAME_COLOR==Color("396FE2"),"Requested frame color is exact")
	for word in ["拾取","替换","进入","交流"]:
		prompt.present(word,Vector2(80,80),word.hash()); prompt._process(prompt.DURATION*.75)
		check(prompt.frame_expansion()>1,"Frame overshoots slightly for "+word)
		check(prompt.scale==Vector2.ONE and prompt.position==prompt.position.round(),"Glyphs stay unscaled on integer pixels")
		prompt.dismiss(); prompt._process(prompt.DURATION)
		check(not prompt.visible,"Frame retires for "+word)
	var face:=preload("res://scripts/ui/npc_emotion_hint.gd").new()
	root.add_child(face)
	for mood in face.EMOTIONS:
		face.present_hint(Vector2(320,180),mood); face._process(.12)
		check(face.emotion==mood and face.visible,"Authored pixel emotion available: "+str(mood))
		check(face.prompt_anchor(prompt.size).y+prompt.size.y<face.position.y,"Talk frame remains above emotion bubble")
	face.present_hint(Vector2(105,170)); face._process(.12)
	check(is_equal_approx(face.position.x+face.size.x*.5,105.0),"Face follows updated NPC head rather than screen edge")
	face.present_hint(Vector2(-100,-100)); face._process(.2)
	check(not face.visible,"Offscreen face is hidden, not pinned misleadingly to screen edge")
	face.present_hint(Vector2(320,180)); paused=true; face._process(.01)
	check(not face.visible,"Pause hides emotion hint")
	paused=false; face.free(); prompt.free()
	var room: Node=load("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate()
	root.add_child(room); await process_frame; await process_frame
	room.player.set_physics_process(false)
	room.player.global_position=room.RECEPTION_DESK_POS_2D+Vector2(0,45)
	room.interaction_resolver.update_target(); room._update_camera_and_projection(0); room._update_interaction_prompt()
	check(room.interaction_prompt.text=="交流" and room.interaction_prompt.wanted,"Real reception exposes talk action without key glyph")
	check(not room.dialogue_controller.is_active(),"Proximity still does not auto-start passive conversation")
	for mood in room.npc_hint_bubble.EMOTIONS:
		room.waitress_npc.hint_emotion=str(mood); room._update_interaction_prompt()
		check(room.npc_hint_bubble.emotion==mood,"NPC authored state drives displayed emotion: "+str(mood))
	room._on_waitress_emotion_line(1,{})
	check(room.waitress_npc.hint_emotion=="sad","Existing story's sad beat drives sad state")
	room._on_waitress_emotion_line(3,{})
	check(room.waitress_npc.hint_emotion=="surprised","Existing story's surprise drives surprised state")
	room.player.global_position=room.waitress_npc.global_position+Vector2(150,100)
	room.interaction_resolver.update_target(); room._update_interaction_prompt()
	check(not room.interaction_prompt.wanted,"Out of interaction range hides talk action")
	check(not room.npc_hint_bubble.wanted,"Out of range hides emotion bubble as well")
	room.dialogue_bubble.show_dialogue("正文不修改",Vector2(320,180),[])
	room._update_interaction_prompt()
	check(not room.interaction_prompt.visible and not room.npc_hint_bubble.wanted,"Actual dialogue hides both proximity widgets")
	check(room.dialogue_bubble.get_script().resource_path.ends_with("growing_dialogue_bubble.gd"),"Original dialogue body still uses its original implementation")
	room.free(); await process_frame
	print("EMOTION_INTERACTION checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
