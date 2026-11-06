extends Node
## Main owns all scene changes; scene adapters report validated events here.
const RULES=preload("res://scripts/story/chapter_one_state.gd")
const UI=preload("res://scripts/story/chapter_panel.gd")
var main: Node
var state: Dictionary:
	get: return main.persistent_day_state.get("chapter_one",{})
func enabled() -> bool: return RULES.enabled(main.persistent_day_state)
func start_new() -> void:
	main.persistent_day_state.chapter_one=RULES.create()
	state.seed=randi_range(1000,900000)
	main.persistent_day_state.melatonin_inventory=1
	main.persistent_day_state.melatonin_bottle_present=true
func commit(event: String,payload: Dictionary={}) -> bool:
	var previous: Dictionary=main.persistent_day_state.duplicate(true)
	if not enabled() or not RULES.submit(state,event,payload): return false
	if event=="tutorial": main.persistent_day_state.tutorial_completed=true
	if event in ["wake","coast_exit"] and bool(state.get("complete",false)):
		main.persistent_day_state.calendar_day_id+=1
		main.persistent_day_state.weekday_index=int(main.persistent_day_state.calendar_day_id)%7
		main._reset_daily_state()
	if not main._save_progress():
		main.persistent_day_state.clear(); main.persistent_day_state.merge(previous)
		push_error("Chapter checkpoint could not be saved; state restored.")
		return false
	main.day_start_snapshot.set_persistent_value(&"chapter_one",state.duplicate(true))
	return true
func sleep() -> void:
	if not commit("sleep"):
		if state.get("complete",false): message("第一章已完成","第一段信号已保留。后续章节尚未开放。")
		return
	resume()
func show_evening() -> void:
	main._show_bedroom(false)
func resume() -> void:
	var before: Dictionary=state.duplicate(true)
	if RULES.migrate_flow(state):
		if main._save_progress(): main.day_start_snapshot.set_persistent_value(&"chapter_one",state.duplicate(true))
		else:
			state.clear(); state.merge(before)
	match str(state.get("stage","EVENING")):
		"EVENING","COMPLETE": main._show_bedroom(false)
		"TUTORIAL": main._show_tutorial("basic")
		"RECEPTION": main._show_reception(main._validated_story_weapon_id())
		"ASCENT","RETURN": main._show_dream(main._validated_story_weapon_id())
		"BED": show_room(false)
		"COAST","COAST_READ": show_coast()
		"WAKE": show_room(true)
func tutorial_finished() -> void:
	if commit("tutorial"):
		resume()
func prepare_world(world: Node3D) -> void:
	world.floor_index=int(state.floor)
	world.base_floor_seed=int(state.seed)
	world.seed=world._derive_floor_seed(int(state.floor))
	world.set_meta(&"chapter_one",true)
	var adapter:=preload("res://scripts/story/chapter_run.gd").new()
	adapter.coordinator=self; adapter.name="ChapterOneRun"; world.add_child(adapter)
	if not str(state.tarot_id).is_empty():
		world.set_meta("has_tarot_card",true); world.set_meta("selected_tarot_card_id",StringName(state.tarot_id)); world.set_meta("selected_tarot_reversed",bool(state.tarot_reversed))
func prepare_tutorial(world: Node3D) -> void:
	if world.has_node("ChapterTraining"): return
	var training:=preload("res://scripts/story/chapter_tutorial.gd").new(); training.name="ChapterTraining"; world.add_child(training)
func prepare_reception(room: Node3D) -> void:
	room.set_meta(&"chapter_one",true)
	room.set_meta(&"chapter_tarot_taken",not str(state.tarot_id).is_empty())
	if not str(state.tarot_id).is_empty():
		room.tarot_visit_state.selected=true
		main.night_state.has_tarot_card=true
		main.night_state.selected_tarot_card_id=state.tarot_id
		main.night_state.selected_tarot_reversed=state.tarot_reversed
	room.ready.connect(func():
		room.tarot_overlay.selection_finished.connect(func(result):
			commit("tarot",{"id":str(result.get_id()),"reversed":result.is_reversed})))
func depart() -> bool:
	if str(state.tarot_id).is_empty():
		main._supported_dream_world.rollback_elevator_entry()
		message("占卜台","她似乎还有话要说。先去前台完成今晚的占卜。")
		return false
	# A failed staged generation restores the live lobby. Retrying that same
	# departure must not require committing the already-saved event again.
	if state.stage=="ASCENT" and int(state.floor)==0: return true
	return commit("depart")
func show_room(wake: bool) -> void:
	var room:=preload("res://scenes/story/chapter_bedroom.tscn").instantiate(); room.wake_mode=wake
	room.profile_state=main.persistent_day_state; room.save_requested.connect(main._save_progress)
	room.phone_open_requested.connect(main._open_game_phone_from_bedroom)
	room.completed.connect(func():
		if wake:
			if commit("wake"):
				if state.stage=="COAST": show_coast()
				else: _show_completion()
			else: room.restore_after_failed_finish()
		else:
			if commit("lie_down"): show_coast()
			else: room.restore_after_failed_finish())
	main._transition_to(room)
func show_coast() -> void:
	var coast:=preload("res://scripts/story/chapter_coast.gd").new(); coast.already_observed=state.stage=="COAST_READ"
	coast.fragment_observed.connect(func():
		if not commit("signal",{"id":"ch1_S"}): coast.already_observed=false; coast.readable_seconds=0.)
	coast.completed.connect(func():
		if commit("coast_exit"):
			if state.complete: _show_completion()
			else: show_room(true)
		else: coast.leaving=false)
	main._transition_to(coast)
func returned() -> void:
	if commit("returned"): resume()
func message(title: String,text: String) -> void:
	var panel:=UI.new(); main.add_child(panel)
	panel.offer(title,text,[["close","继续"]]); panel.choice_selected.connect(func(_id): panel.queue_free())

func _show_completion() -> void:
	main._show_bedroom(false)
	await get_tree().create_timer(.7).timeout
	message("第一章 · 盲目执行","清理已结束。海边的三个光点留在记忆里。\n第一章完成，后续章节尚未开放。")
