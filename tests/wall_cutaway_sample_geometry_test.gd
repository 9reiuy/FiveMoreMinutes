extends SceneTree
const STYLE = preload("res://scripts/dream/preview/wall_cutaway_style_sample.gd")
const WALL = preload("res://scenes/dream/3d/WallStraight3D.tscn")
var checks:=0
var failures:=0

class SampleWorld extends Node3D:
	var wall_root:=Node3D.new()
	var door_root:=Node3D.new()
	var floor_root:=Node3D.new()
	var wall_height:=2.6
	var room_cells: Dictionary={Vector2i.ZERO:0}
	func _edge_side_cells(_edge: Dictionary) -> Array:
		return [Vector2i.ZERO]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)

func make_case(angle: float, arms: int) -> Dictionary:
	var world:=SampleWorld.new()
	world.rotation.y=angle
	root.add_child(world)
	for child in [world.wall_root,world.door_root,world.floor_root]: world.add_child(child)
	var originals: Array=[]
	for i in arms:
		var wall=WALL.instantiate()
		wall.position=Vector3(.5,0,0).rotated(Vector3.UP,PI*.5*i)
		wall.rotation.y=PI*.5*i
		wall.set_meta("edge",{"axis":"H","x":i,"y":0})
		world.wall_root.add_child(wall)
		wall.configure_wall(2.6,.5)
		wall.set_cutaway_mode(true)
		originals.append(wall.wall_mesh.get_surface_override_material(2))
	var style:=STYLE.new(); world.add_child(style); style.apply(world,0)
	var area:=0.0
	var aligned:=true
	var height_ok:=true
	for visual in style._surface_root.get_children():
		var vertices: PackedVector3Array=visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0,vertices.size(),3):
			var a: Vector3=world.to_local(visual.to_global(vertices[i]))
			var b: Vector3=world.to_local(visual.to_global(vertices[i+1]))
			var c: Vector3=world.to_local(visual.to_global(vertices[i+2]))
			area+=(b-a).cross(c-a).length()*.5
		for vertex in vertices:
			var p: Vector3=world.to_local(visual.to_global(vertex))
			aligned=aligned and absf(p.x*32-roundf(p.x*32))<.002 and absf(p.z*32-roundf(p.z*32))<.002
			height_ok=height_ok and absf(p.y-(2.6*.3+.002))<.002
	check(aligned,"Wall union follows building texel grid despite root rotation")
	check(height_ok,"Cut cap remains on the authoritative thirty-percent plane")
	check(style.cap_batch_count==1,"One continuous cap batch for the connected equal-height junction")
	check(area>0,"Connected junction has a nonempty closed top")
	var count: int=style.cap_vertex_count
	world.wall_root.get_child(0).set_cutaway_mode(false)
	style._process(0)
	check(style.cap_batch_count==2,"Mixed full-height and cut walls receive distinct cap planes")
	for wall in world.wall_root.get_children(): wall.set_cutaway_mode(false)
	style._process(0)
	check(style.cap_batch_count==1,"Returning to full height removes the old cut-height batch")
	var full_height_ok:=true
	for visual in style._surface_root.get_children():
		for vertex in visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			full_height_ok=full_height_ok and absf(world.to_local(visual.to_global(vertex)).y-2.602)<.002
	check(full_height_ok,"Full caps follow the retained original wall height")
	style.restore()
	for i in arms:
		check(world.wall_root.get_child(i).wall_mesh.get_surface_override_material(2)==originals[i],"Restore returns original shared cap without mutating it")
	check(style._surface_root.get_child_count()==0,"Restore removes opt-in sample geometry")
	world.free()
	return {"area":area,"vertices":count}

func run() -> void:
	for arms in [2,3,4]:
		var identity:=make_case(0,arms)
		var rotated:=make_case(-PI*.25,arms)
		check(is_equal_approx(identity.area,rotated.area),"L/T/cross cap footprint is invariant under production root rotation")
		check(identity.vertices==rotated.vertices,"Root rotation cannot inflate cap geometry")
	print("WALL_CUTAWAY_SAMPLE_GEOMETRY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
