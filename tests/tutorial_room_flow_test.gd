extends Node
## Save-routing and one-shot exit contract; real-input lessons run separately.
const MAIN=preload("res://scripts/app/main.gd")
const ROOM=preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")
var failures: Array[String]=[]
var checks:=0
func _ready() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var master:=AudioServer.get_bus_index(&"Master")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0:AudioServer.set_bus_mute(master,true)
		get_tree().quit(1);return
	check(not MAIN.should_enter_tutorial({"calendar_day_id":0,"tutorial_completed":false}),"Normal campaign still skips the standalone tutorial")
	check(not MAIN.should_enter_tutorial({"calendar_day_id":1,"tutorial_completed":false}),"Later days do not enter the tutorial")
	var main: Node=MAIN.new();var state: Dictionary=main._create_initial_state()
	check(not bool(state.get("tutorial_completed",true)),"New saves retain the tutorial completion field")
	var legacy: Dictionary=state.duplicate(true);legacy.erase("tutorial_completed");legacy.calendar_day_id=3;legacy.weekday_index=3
	check(bool(main._merge_with_defaults(legacy).get("tutorial_completed",false)),"Existing later-day saves retain completed tutorial migration")
	main.free()
	var room: Node3D=ROOM.instantiate();get_tree().root.add_child(room)
	for frame in 8:await get_tree().process_frame
	var training: Node=room.get_node("ChapterTraining")
	check(room.floor_cells.size()==251 and room.floor_root.get_child_count()==7,"Three connected classrooms and the gallery provide the authored walkable footprint")
	check(room.get_node_or_null("GeneratedBuildingRoot")==null,"Tutorial does not instantiate the random dungeon")
	check(not room.has_node("GameplayCanvas/GameplayWorld/TutorialGuide"),"First room has no guide actor")
	room._begin_exit_sequence()
	check(not room.exit_sequence_started,"Terminal exit rejects unfinished lessons")
	var finished: Array[int]=[0]
	room.tutorial_finished.connect(func():finished[0]+=1)
	training.stage=training.Stage.DONE;training._sync_progression(true)
	room._begin_exit_sequence();room._begin_exit_sequence()
	check(room.exit_sequence_started and not room.player.movement_enabled,"Completed exit locks control exactly once")
	await get_tree().create_timer(.4,true,false,true).timeout
	check(finished[0]==1,"Completed exit emits one tutorial-finished signal")
	room.queue_free()
	for frame in 8:await get_tree().process_frame
	print("TUTORIAL_ROOM_FLOW checks=",checks," failures=",failures.size()," pid=",OS.get_process_id())
	get_tree().quit(1 if not failures.is_empty() else 0)
