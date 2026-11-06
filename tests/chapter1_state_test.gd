extends SceneTree
const RULES=preload("res://scripts/story/chapter_one_state.gd")
var checks:=0
var failures:=0
class SaveHost extends Node:
	var persistent_day_state: Dictionary={}
	var day_start_snapshot:=DayStartSnapshot.new()
	var fail_save:=false
	func _save_progress() -> bool: return not fail_save
	func _reset_daily_state() -> void: persistent_day_state.food_eaten_today=false
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
	print("PASS " if value else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state: Dictionary=RULES.create()
	check(not RULES.enabled({}),"old saves do not automatically opt in")
	check(RULES.enabled({"chapter_one":state}),"versioned new profile opts in")
	check(not RULES.submit(state,"boss"),"early Boss event rejected")
	check(state.stage=="TUTORIAL" and state.flow_revision==2,"new game starts with tutorial")
	check(not RULES.submit(state,"sleep"),"cannot sleep before training completion")
	check(RULES.submit(state,"tutorial") and state.stage=="EVENING","tutorial exit returns to illustrated bedroom")
	check(RULES.submit(state,"sleep") and state.stage=="RECEPTION","sleep after training enters reception")
	check(not RULES.submit(state,"sleep"),"sleep is idempotent")
	check(not RULES.submit(state,"depart"),"cannot skip daily card")
	check(RULES.submit(state,"tarot",{"id":"fool"}),"actual card can commit")
	check(not RULES.submit(state,"tarot",{"id":"moon"}),"cannot reroll by repeating selection event")
	check(RULES.submit(state,"depart"),"depart after card")
	check(not RULES.submit(state,"floor",{"index":3}),"cannot skip floors")
	check(RULES.submit(state,"floor",{"index":1}),"second combat floor")
	check(not RULES.submit(state,"build",{"id":"damage"}),"no build on combat floor")
	check(RULES.submit(state,"floor",{"index":2}),"rest stop follows two combat floors")
	check(RULES.submit(state,"build",{"id":"damage"}),"real upgrade choice commits once")
	check(not RULES.submit(state,"build",{"id":"tempo"}),"duplicate build rejected")
	check(RULES.submit(state,"floor",{"index":3}),"Boss floor follows rest")
	check(RULES.submit(state,"boss"),"target Boss completes combat portion")
	check(not RULES.submit(state,"boss"),"duplicate Boss cannot double advance")
	check(RULES.submit(state,"returned") and state.stage=="WAKE","Boss return enters topdown self-wake room")
	check(RULES.submit(state,"wake") and state.stage=="COAST" and not state.complete,"bedside F enters coast before day completion")
	check(not RULES.submit(state,"coast_exit"),"cannot leave without reading signal")
	check(not RULES.submit(state,"signal",{"id":"ch3_key"}),"wrong chapter fragment rejected")
	check(RULES.submit(state,"signal",{"id":"ch1_S"}) and state.clues.size()==1,"one observed fragment")
	check(state.observations.size()==1 and state.observations[0].symbols=="..." and state.observations[0].translation=="","record raw spatial signal without solving it")
	var legacy: Dictionary={"clues":["ch1_S"]}; RULES.ensure_observations(legacy); RULES.ensure_observations(legacy)
	check(legacy.observations.size()==1 and legacy.observations[0].encoding=="spatial","legacy clue migration is idempotent")
	legacy.observations[0].translation="my guess"; RULES.ensure_observations(legacy)
	check(legacy.observations[0].translation=="my guess","migration preserves player transcription")
	check(not RULES.submit(state,"signal",{"id":"ch1_S"}),"repeat reading cannot duplicate clue")
	check(RULES.submit(state,"coast_exit") and state.complete,"wake completes first chapter")
	check(not RULES.submit(state,"wake") and state.complete,"repeated F cannot advance again")
	var flow_legacy: Dictionary=RULES.create(); flow_legacy.erase("flow_revision"); flow_legacy.stage="TUTORIAL"
	check(RULES.migrate_flow(flow_legacy) and RULES.submit(flow_legacy,"tutorial") and flow_legacy.stage=="EVENING","old tutorial checkpoint now exits to illustrated bedroom")
	flow_legacy.stage="BED"; flow_legacy.erase("flow_revision")
	check(RULES.migrate_flow(flow_legacy) and flow_legacy.stage=="WAKE","old Boss bedroom checkpoint now awaits bedside F")
	flow_legacy.stage="WAKE"; flow_legacy.erase("flow_revision")
	check(not RULES.migrate_flow(flow_legacy) and RULES.submit(flow_legacy,"wake") and flow_legacy.complete,"old post-coast wake checkpoint completes without replay")
	for path in ["chapter_one","chapter_run","chapter_tutorial","chapter_coast","chapter_wake_room","chapter_archive","chapter_panel","surveillance_camera"]:
		check(load("res://scripts/story/"+path+".gd")!=null,"load "+path)
	check(load("res://scenes/app/main.tscn")!=null,"formal Main scene resources")
	var host:=SaveHost.new(); root.add_child(host)
	host.persistent_day_state={"chapter_one":RULES.create(),"calendar_day_id":1,"weekday_index":1,"food_eaten_today":true}
	host.day_start_snapshot.capture(host.persistent_day_state)
	var controller: Node=load("res://scripts/story/chapter_one.gd").new(); controller.main=host; host.add_child(controller)
	host.fail_save=true
	check(not controller.commit("tutorial") and controller.state.stage=="TUTORIAL","failed disk commit restores chapter state")
	check(host.day_start_snapshot.state.chapter_one.stage=="TUTORIAL","failed commit cannot advance recovery snapshot")
	host.fail_save=false; controller.state.stage="COAST_READ"
	check(controller.commit("coast_exit") and host.persistent_day_state.calendar_day_id==2 and not host.persistent_day_state.food_eaten_today,"wake and calendar advance in one saved transaction")
	check(not controller.commit("coast_exit") and host.persistent_day_state.calendar_day_id==2,"duplicate wake cannot advance calendar twice")
	host.free()
	print("CHAPTER1_STATE checks=",checks," failures=",failures); quit(failures)
