extends SceneTree
const SCENE=preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
var out:="user://reception_npc_hint"
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):out=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frames(count:=4) -> void:
	for index in count:await process_frame
func run() -> void:
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(640,360)
	var room=SCENE.instantiate();root.add_child(room);await frames()
	room.set_process(false);room.player.set_physics_process(false)
	var npc: Node=room.waitress_npc;var bubble: Node=room.npc_hint_bubble
	check(npc.character_atlas.resource_path=="res://art/Dream/enemy/npc1.png","Reception uses the requested npc1 atlas")
	var correct_parts:=0
	for part in [npc.head,npc.body,npc.left_foot,npc.right_foot,npc.left_hand,npc.right_hand]:
		if part.texture.atlas==npc.character_atlas:correct_parts+=1
	check(correct_parts==6,"All body parts use npc1 rather than mixing old parts")
	check(npc.head_frame_blink.atlas==npc.character_atlas and npc.head_frame_closed.atlas==npc.character_atlas,"Blink frames use npc1 too")
	check(bubble is DreamDialogueBubble,"Emotion and words use the formal dialogue bubble")
	check(not bubble.face.draw_frame,"Inline face has no separate boxed frame")
	room.player.global_position=Vector2(17,19.1)*32;room.interaction_resolver.update_target()
	room.npc_hint_cycle_seconds=0;room._update_interaction_prompt(0)
	check(bubble.hint_kind==&"emotion" and bubble.face.visible,"Distant idle starts with a pixel emotion")
	room._update_interaction_prompt(2.5)
	check(bubble.hint_kind==&"word" and bubble.hint_text=="交流","The same distant bubble alternates to 交流")
	check(not bubble.face.visible and bubble.dialogue_label.visible,"Emotion and word never stack")
	room._update_interaction_prompt(2.5)
	check(bubble.hint_kind==&"emotion","The idle alternation repeats")
	room.player.global_position=Vector2(7.2,19.1)*32;room.interaction_resolver.update_target();room._update_interaction_prompt(0)
	check(bubble.hint_kind==&"word" and bubble.hint_text=="交谈","Approaching replaces the idle hint with 交谈 only")
	check(not bubble.face.visible and not room.interaction_prompt.visible,"Near hint has no extra face or legacy interaction label")
	room._update_interaction_prompt(3)
	check(bubble.hint_text=="交谈","Nearby hint stays 交谈 instead of cycling")
	npc.request_interaction(room.player);room._update_interaction_prompt(0)
	check(room.dialogue_controller.is_active(),"The original interaction still starts dialogue")
	check(not bubble.visible,"Idle hint disappears while real dialogue speaks")
	check(AudioServer.is_bus_mute(0),"Private audio remains muted")
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"audio":AudioServer.get_driver_name(),"checks":checks,"failures":failures},"\t"))
	room.queue_free();await frames(8);preload("res://scripts/audio/sfx_manager.gd").stop_music(0.0);await frames(3);print("RECEPTION_NPC_HINT checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
