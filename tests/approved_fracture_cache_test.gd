extends SceneTree
const SYSTEM=preload("res://scripts/dream/destruction_floor_debris.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var world:Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false;world.spawn_content=false;world.persist_profile=false;world.enable_game_start_cab_exit=false
	root.add_child(world);check(world.regenerate(2824175271),"live seed regenerates")
	for i in 4:await physics_frame
	var quads:Array=[]
	for glass in get_nodes_in_group(&"breakable_glass_windows"):
		if world.generated_root.is_ancestor_of(glass) and String(glass.name).begins_with("GlassCell_") and glass.glass_pane.mesh is QuadMesh:quads.append(glass)
	check(quads.size()>0,"natural approved-art interior QuadMesh panes exist")
	var rng_state:int=world._content_rng.state
	var report:Dictionary=SYSTEM.prefill_standard_glass(world)
	check(report.specs>0 and report.specs<=32 and report.outline_misses>0,"final geometry and cut rims prepared within bound")
	check(rng_state==world._content_rng.state,"prefill consumes no gameplay RNG")
	var trials:Array=quads.slice(0,mini(4,quads.size()))
	for door in world.door_root.get_children():
		if door is PhysicalDoor3D and trials.size()<8:trials.append(door)
	for source in trials:
		var before:Transform3D=source.transform
		var burst:=SYSTEM.new();world.floor_root.add_child(burst);burst.world=world;burst.build_from_source(source,Vector2.RIGHT,not source is PhysicalDoor3D)
		check(burst.audit_geometry_misses==0 and burst.audit_outline_misses==0,"actual final window/door has no cold geometry work: "+String(source.name))
		check(source.transform==before and burst.pieces.size()>0,"fracture build preserves source placement and has pieces")
		burst.free()
	world.free();await process_frame
	print("APPROVED_FRACTURE_CACHE checks=%d failures=%s"%[checks,failures]);quit(0 if failures.is_empty() else 1)
