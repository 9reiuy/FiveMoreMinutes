extends Node
## Read-only diagnostic. Never modifies lights, selection or scheduling.
var world: Node3D
var phase_probe: Node
var previous_enabled: Array=[]
var previous_visible: Array=[]
var enabled_frame: int=-1
var visible_frame: int=-1
var changes:=0
func _ready() -> void: process_priority=2147483646
func _process(_delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(phase_probe) or not phase_probe.active: return
	var enabled: Array=[]; var visible: Array=[]
	for light in world.shadow_manager.active:
		if not is_instance_valid(light) or not light.shadow_enabled: continue
		enabled.append(light.get_instance_id())
		if light.shadow_opacity>0.0: visible.append(light.get_instance_id())
	enabled.sort(); visible.sort()
	if enabled!=previous_enabled:
		enabled_frame=Engine.get_process_frames(); changes+=1
		phase_probe.frame_events["shadow_enabled_set_changed"]=1
	if visible!=previous_visible:
		visible_frame=Engine.get_process_frames()
		phase_probe.frame_events["shadow_nonzero_set_changed"]=1
	previous_enabled=enabled; previous_visible=visible
func context() -> Dictionary:
	var frame:=Engine.get_process_frames()
	return {"frames_since_enabled_change":frame-enabled_frame if enabled_frame>=0 else -1,
		"frames_since_nonzero_change":frame-visible_frame if visible_frame>=0 else -1,"enabled_set_changes":changes}
