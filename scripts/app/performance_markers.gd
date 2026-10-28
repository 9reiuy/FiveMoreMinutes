extends RefCounted
## Opt-in plain-data diagnostics; no strong reference to gameplay or the monitor.
static var _reference: WeakRef
static var _scopes:Array=[]

static func scope_begin(owner:Node,stage:String)->int:
	var monitor:=current(owner)
	if monitor==null:return 0
	var started:=Time.get_ticks_usec()
	_scopes.append([stage,started,0,"physics" if Engine.is_in_physics_frame() else "process"])
	monitor.record_stage("scope_overhead",(Time.get_ticks_usec()-started)/1000.0)
	return _scopes.size()

static func scope_end(owner:Node,token:int)->void:
	if token<=0:return
	var marker_started:=Time.get_ticks_usec()
	if token!=_scopes.size():
		event(owner,"diagnostic_scope_mismatch",{"expected":token,"actual":_scopes.size()})
		return
	var item:Array=_scopes.pop_back()
	var inclusive:int=marker_started-int(item[1])
	if not _scopes.is_empty():_scopes.back()[2]+=inclusive
	var monitor:=current(owner)
	if monitor==null:return
	var same_family_parent:=false
	for parent:Array in _scopes:
		if parent[0]==item[0] and parent[3]==item[3]:same_family_parent=true;break
	# Same-category recursive helpers must not count their inclusive interval
	# twice. Self intervals remain exclusive, including recursive helpers.
	if not same_family_parent:monitor.record_stage(String(item[0])+"_"+String(item[3]),inclusive/1000.0)
	monitor.record_stage(String(item[0])+"_self_"+String(item[3]),maxi(0,inclusive-int(item[2]))/1000.0)
	monitor.record_stage("scope_overhead",(Time.get_ticks_usec()-marker_started)/1000.0)

static func current(owner: Node) -> Node:
	var monitor: Node = _reference.get_ref() if _reference != null else null
	if not is_instance_valid(monitor):
		if not is_instance_valid(owner) or not owner.is_inside_tree(): return null
		monitor = owner.get_node_or_null("/root/PerformanceMonitor")
		if not is_instance_valid(monitor) or not monitor.has_method("is_recording"): return null
		_reference = weakref(monitor)
	return monitor if monitor.is_recording() else null

static func event(owner: Node, kind: String, data: Dictionary = {}) -> void:
	var monitor := current(owner)
	if monitor != null: monitor.record_event(kind, data)

static func capture_request(owner:Node,kind:String,target:Node)->void:
	var monitor:=current(owner)
	if monitor!=null and is_instance_valid(target):monitor.record_render_request(kind,target.get_instance_id())

static func begin(owner: Node) -> int:
	return Time.get_ticks_usec() if current(owner) != null else 0

static func end(owner: Node, stage: String, started: int) -> void:
	if started <= 0: return
	var elapsed := Time.get_ticks_usec() - started
	var monitor := current(owner)
	if monitor != null: monitor.record_stage(stage, elapsed / 1000.0)

static func lighting_event(world:Variant,phase:String)->void:
	if not is_instance_valid(world) or not world is Node or not world.is_inside_tree():return
	var monitor:=current(world)
	if monitor==null:return
	var manager:Variant=world.get("shadow_manager")
	if not is_instance_valid(manager):return
	var lights:Array=[]
	for light in manager.active:
		if not is_instance_valid(light):continue
		lights.append({"node_id":light.get_instance_id(),"name":String(light.name),"type":light.get_class(),"shadow":light.shadow_enabled,"opacity":light.shadow_opacity,"caster_mask":light.shadow_caster_mask})
	monitor.record_event("lighting_state",{"phase":phase,"quality":String(manager.quality),"active":lights})
