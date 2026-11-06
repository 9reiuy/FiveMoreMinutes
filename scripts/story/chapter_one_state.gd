extends RefCounted
## Versioned story state. Existing profiles opt in only through New Game.
const VERSION := 1
const FLOOR_ROLES := ["combat", "combat", "rest", "boss"]
static func create() -> Dictionary:
	return {"version":VERSION,"stage":"TUTORIAL","flow_revision":2,"floor":0,"seed":42001,"tutorial":false,
		"tarot_id":"","tarot_reversed":false,"build":"","clues":[],"complete":false,
		"observation_version":1,"observations":[]}
static func migrate_flow(state: Dictionary) -> bool:
	if int(state.get("flow_revision",1))>=2: return false
	# An old post-coast wake checkpoint must finish in place, without replaying
	# its already-observed dream or losing the pending calendar transaction.
	if state.get("stage","")=="WAKE": return false
	if state.get("stage","")=="BED": state.stage="WAKE"
	elif state.get("stage","")=="EVENING" and not state.get("tutorial",false): state.stage="TUTORIAL"
	state.flow_revision=2
	return true
static func ensure_observations(state: Dictionary) -> void:
	if not state.get("observations") is Array: state.observations=[]
	state.observation_version=1
	if "ch1_S" in state.get("clues",[]) and state.observations.is_empty():
		state.observations.append({"id":"ch1_S","chapter":1,"encoding":"spatial","symbols":"...","translation":""})
static func enabled(profile: Dictionary) -> bool:
	return profile.get("chapter_one") is Dictionary and int(profile.chapter_one.get("version",0))==VERSION
static func submit(state: Dictionary,event: String,payload: Dictionary={}) -> bool:
	var stage: String=state.get("stage","")
	match event:
		"sleep":
			if stage!="EVENING": return false
			state.stage="RECEPTION" if state.get("tutorial",false) or int(state.get("flow_revision",1))>=2 else "TUTORIAL"
		"tutorial":
			if stage!="TUTORIAL": return false
			state.tutorial=true; state.stage="EVENING" if int(state.get("flow_revision",1))>=2 else "RECEPTION"
		"tarot":
			if stage!="RECEPTION" or not str(state.tarot_id).is_empty() or str(payload.get("id","")).is_empty(): return false
			state.tarot_id=str(payload.id); state.tarot_reversed=bool(payload.get("reversed",false))
		"depart":
			if stage!="RECEPTION" or str(state.tarot_id).is_empty(): return false
			state.stage="ASCENT"
		"floor":
			var next: int=int(payload.get("index",-1))
			if stage!="ASCENT" or next!=int(state.floor)+1 or next>=FLOOR_ROLES.size(): return false
			state.floor=next
		"build":
			if stage!="ASCENT" or int(state.floor)!=2 or not str(state.build).is_empty() or payload.get("id","") not in ["damage","tempo","range"]: return false
			state.build=payload.id
		"boss":
			if stage!="ASCENT" or int(state.floor)!=3 or str(state.build).is_empty(): return false
			state.stage="RETURN"
		"returned":
			if stage!="RETURN": return false
			state.stage="WAKE" if int(state.get("flow_revision",1))>=2 else "BED"
		"lie_down":
			if stage!="BED": return false
			state.stage="COAST"
		"signal":
			if stage!="COAST" or payload.get("id","")!="ch1_S": return false
			if not "ch1_S" in state.clues: state.clues.append("ch1_S")
			ensure_observations(state)
			state.stage="COAST_READ"
		"coast_exit":
			if stage!="COAST_READ": return false
			state.stage="COMPLETE" if int(state.get("flow_revision",1))>=2 else "WAKE"
			state.complete=state.stage=="COMPLETE"
		"wake":
			if stage!="WAKE": return false
			state.stage="COAST" if int(state.get("flow_revision",1))>=2 else "COMPLETE"; state.complete=state.stage=="COMPLETE"
		_: return false
	return true
