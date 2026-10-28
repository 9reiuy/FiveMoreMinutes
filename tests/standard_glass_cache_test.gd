extends SceneTree
const FIXTURE=preload("res://tests/fire_extinguisher_test.gd")
const GLASS=preload("res://scripts/dream/continuous_office_glass.gd")
const DEBRIS=preload("res://scripts/dream/destruction_floor_debris.gd")
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func make_window(world:Node,width:float)->Node3D:
	var glass:=GLASS.new();world.floor_root.add_child(glass)
	glass.configure_window({"axis":"V","x":4,"y":20,"preview_run_width":width},"V:4:20",2.6,.25,null)
	return glass
func run()->void:
	var world:=FIXTURE.World.new();root.add_child(world)
	var first:=make_window(world,1.0)
	var bounds:AABB=first.glass_pane.mesh.get_aabb()
	var warm:Dictionary=DEBRIS.prefill_standard_glass(world)
	expect(warm.specs>0 and warm.outline_misses>0,"actual finalized pane and frame specs are warmed")
	var second:=make_window(world,1.0)
	expect(first.glass_pane.mesh!=second.glass_pane.mesh,"generation-time meshes remain independent")
	var burst:=DEBRIS.new();world.floor_root.add_child(burst);burst.world=world
	burst.build_from_source(second,Vector2.RIGHT,true)
	expect(burst.audit_geometry_misses==0 and burst.audit_geometry_hits==16,"fresh window instance reuses all sixteen geometric cuts")
	expect(burst.audit_outline_misses==0 and burst.audit_outline_hits==12,"all twelve cut edges reuse pure geometry cache")
	expect(first.glass_pane.mesh.get_aabb()==bounds and not first.is_shattered and not second.is_shattered,"prefill/build does not mutate source dimensions or health")
	var wider:=make_window(world,2.0)
	expect(first.glass_pane.mesh.get_aabb()==bounds,"later continuous-window resize cannot contaminate another instance")
	var low:=Vector2(-.5,0);var high:=Vector2(.5,1)
	var key:String=DEBRIS._geometry_key(wider.glass_pane,low,high,1)
	expect(key!=DEBRIS._geometry_key(first.glass_pane,low,high,1),"different final widths do not alias")
	expect(key!=DEBRIS._geometry_key(wider.glass_pane,low,high,-1),"diagonal clipping side is part of geometry identity")
	wider.glass_pane.mesh.flip_faces=true
	expect(key!=DEBRIS._geometry_key(wider.glass_pane,low,high,1),"normal/winding mutation invalidates specification")
	var foreign:=MeshInstance3D.new();foreign.mesh=BoxMesh.new();world.floor_root.add_child(foreign)
	expect(DEBRIS._standard_glass_spec(foreign).is_empty(),"uncontrolled meshes retain identity fallback")
	world.free();await process_frame
	print("STANDARD_GLASS_CACHE checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
