extends "res://tests/formal_performance_acceptance.gd"
## Existing Main-entry ten-minute / three-transition acceptance workload.
var reflected_views:Array[WeakRef]=[]
func _initialize()->void:
	process_frame.connect(func()->void:
		if DisplayServer.get_name()!="headless" and DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	super._initialize()
func exited(report:Dictionary)->void:
	super.exited(report)
	var component:Node=world.get_node_or_null("FloorReflections")
	check(component!=null and not component.restored,"Arrival restores production reflection component")
	if component==null: return
	check(component.renders>0,"Arrival cover prepares reflected scene before door opens")
	check(component.viewport.world_3d==world.get_world_3d(),"Arrival reflection shares actual current floor world")
	check(reflected_views.all(func(r:WeakRef)->bool:return r.get_ref()==null),"Previous floor reflection viewports released")
	reflected_views.append(weakref(component.viewport))
