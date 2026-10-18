extends "res://scripts/dream/dream_3d_actor_depth_bridge.gd"
## Test-only aggregate bridge CPU callbacks; no scheduling changes.
static var timing_active := false
static var timing_frames: Dictionary = {}
static func timing_begin() -> void:
	timing_frames.clear(); timing_active=true
static func timing_finish() -> Dictionary:
	timing_active=false
	var values: Dictionary={}
	for frame in timing_frames:
		for key in timing_frames[frame]:
			if not values.has(key): values[key]=[]
			values[key].append(timing_frames[frame][key])
	var result: Dictionary={}
	for key in values:
		var rows: Array=values[key]; rows.sort()
		result[key]={"active_frames":rows.size(),"median_ms":rows[rows.size()/2],"p95_ms":rows[floori(rows.size()*.95)],"total_ms":rows.reduce(func(a,b): return a+b,0.0)}
	return result
func _process(delta: float) -> void:
	if not timing_active:
		super._process(delta); return
	var category := "other"
	if is_instance_valid(source_actor):
		if character_projection: category="character_dead" if source_actor.get("dead")==true else "character_alive"
		elif source_actor.is_in_group(&"dream_projectiles"): category="projectile"
		elif source_actor is DreamShellEffect: category="shell"
		elif source_actor is BlackBloodEffect: category="blood"
		elif source_actor.is_in_group(&"environment_debris"): category="floor_debris"
	var start:=Time.get_ticks_usec()
	super._process(delta)
	var elapsed := (Time.get_ticks_usec()-start)/1000.0
	var frame:=Engine.get_process_frames()
	if not timing_frames.has(frame): timing_frames[frame]={}
	var rows: Dictionary=timing_frames[frame]
	rows[category]=float(rows.get(category,0.0))+elapsed
