extends SceneTree
const SAMPLE=preload("res://scripts/dream/preview/wall_root_cutaway_sample.gd")
const WALL=preload("res://scenes/dream/3d/WallStraight3D.tscn")
var checks:=0
var failures:=0
class MockWorld extends Node3D:
	var wall_root:=Node3D.new()
	var door_root:=Node3D.new()
	var floor_root:=Node3D.new()
	var wall_height:=2.6
	var wall_thickness:=.5
	var room_cells: Dictionary={Vector2i.ZERO:0}
	func _edge_side_cells(_edge: Dictionary) -> Array: return [Vector2i.ZERO]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func top_at(mesh: Mesh,x: float) -> float:
	var result: float=-INF
	for surface in mesh.get_surface_count():
		for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if absf(vertex.x-x)<.001: result=maxf(result,vertex.y)
	return result

func corner_covered(world: Node3D,p: Vector3)->bool:
	var ray_start: Vector3=world.to_global(p+Vector3(0,3,0))
	var ray_end: Vector3=world.to_global(p+Vector3(0,2.5,0))
	for wall in world.wall_root.get_children():
		var visual: MeshInstance3D=wall.wall_mesh
		for surface in visual.mesh.get_surface_count():
			var arrays: Array=visual.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for triangle in range(0,indices.size() if not indices.is_empty() else points.size(),3):
				var a: int=indices[triangle] if not indices.is_empty() else triangle
				var b: int=indices[triangle+1] if not indices.is_empty() else triangle+1
				var c: int=indices[triangle+2] if not indices.is_empty() else triangle+2
				if Geometry3D.segment_intersects_triangle(ray_start,ray_end,visual.to_global(points[a]),visual.to_global(points[b]),visual.to_global(points[c]))!=null: return true
	return false

func check_corners()->void:
	for rotation_angle in [0.0,-PI*.25]:
		for turn in [-1.0,1.0]:
			for cut_mask in 4:
				var world:=MockWorld.new(); root.add_child(world); world.rotation.y=rotation_angle
				for child in [world.wall_root,world.door_root,world.floor_root]: world.add_child(child)
				for i in 2:
					var wall=WALL.instantiate(); wall.set_meta("edge",{})
					wall.position=Vector3(.5,0,0) if i==0 else Vector3(1,0,turn*.5)
					if i==1: wall.rotation.y=-turn*PI*.5
					world.wall_root.add_child(wall); wall.configure_wall(2.6,.5); wall.set_cutaway_mode((cut_mask & (1<<i))!=0)
				var sample:=SAMPLE.new(); world.add_child(sample); sample.apply(world,0)
				var closed:=true
				for x in [-.115,-.055,.055,.115]:
					for z in [-.115,-.055,.055,.115]:
						closed=closed and corner_covered(world,Vector3(1+x,0,z))
				check(closed,"Both turns and full/cut combinations cover the entire corner without the missing outer quadrant")
				check(not corner_covered(world,Vector3(1.14,0,-turn*.14)),"Joined outer corner remains square within the original visible thickness")
				check(not corner_covered(world,Vector3(1.14,0,-turn*.10)) and not corner_covered(world,Vector3(1.10,0,-turn*.14)),"Both outside edges stop at the same right-angle corner without thickness expansion")
				sample.restore(); world.free()
func run() -> void:
	for rotation_angle in [0.0,-PI*.25]:
		var world:=MockWorld.new(); root.add_child(world); world.rotation.y=rotation_angle
		for child in [world.wall_root,world.door_root,world.floor_root]: world.add_child(child)
		var original_meshes: Array=[]
		var whole_material:=ShaderMaterial.new()
		var whole_shader:=Shader.new(); whole_shader.code="shader_type spatial; void fragment(){ALBEDO=vec3(0.1);}"
		whole_material.shader=whole_shader
		var shadow_meshes: Array=[]
		var wall_ids: Array=[]
		for index in 4:
			var wall=WALL.instantiate()
			wall.position=Vector3(index+.5,0,0); wall.set_meta("edge",{"axis":"H","x":index,"y":0})
			world.wall_root.add_child(wall); wall.configure_wall(2.6,.5); wall.set_cutaway_mode(index>0)
			wall.wall_mesh.material_override=whole_material
			original_meshes.append(wall.wall_mesh.mesh); shadow_meshes.append(wall.shadow_mesh.mesh); wall_ids.append(wall.wall_mesh.get_instance_id())
		var count_before: int=world.find_children("*","MeshInstance3D",true,false).size()
		var sample:=SAMPLE.new(); world.add_child(sample); sample.apply(world,0)
		check(world.find_children("*","MeshInstance3D",true,false).size()==count_before,"No overlay caps or additional wall MeshInstances")
		check(sample.root_wall_count==3 and sample.foot_count==2,"A straight cut run retains two tall ends with two short inner feet")
		for index in 4:
			var wall=world.wall_root.get_child(index)
			check(wall.wall_mesh.get_instance_id()==wall_ids[index],"Existing wall renderer is reused")
			check(wall.shadow_mesh.mesh==shadow_meshes[index],"Full-height shadow mesh remains the original resource")
			check(is_equal_approx(wall.wall_thickness,.5),"Authoritative configured wall thickness is unchanged")
			check(is_equal_approx(wall.wall_mesh.mesh.get_aabb().size.z,.25),"Sample visible wall thickness is slimmer without changing its collider")
			check(wall.wall_mesh.material_override==null and wall.wall_mesh.get_active_material(2).shader==SAMPLE.ROOT_SECTION,"Whole-wall override cannot hide the cut-section texture")
		var full: Mesh=world.wall_root.get_child(0).wall_mesh.mesh
		var first: Mesh=world.wall_root.get_child(1).wall_mesh.mesh
		var middle: Mesh=world.wall_root.get_child(2).wall_mesh.mesh
		check(is_equal_approx(full.get_aabb().size.y,2.6),"Retained wall stays full height and has a vertical end")
		check(is_equal_approx(top_at(first,-.5),2.6),"Left end of the cut run retains a full-height wall post")
		check(is_equal_approx(top_at(first,-.05),.12),"Short inner foot lands on the low root after the vertical cut")
		check(is_equal_approx(top_at(first,.5),.12),"Remaining wall segment stays at root height instead of becoming a long ramp")
		check(is_equal_approx(middle.get_aabb().size.y,.12),"Following segments keep a continuous near-ground root")
		var last: Mesh=world.wall_root.get_child(3).wall_mesh.mesh
		check(is_equal_approx(top_at(last,.5),2.6) and is_equal_approx(top_at(last,.05),.12),"Right end mirrors the left end to complete the same straight U profile")
		check(first.get_surface_count()==3,"Existing front, back and section surface contract is retained")
		# A true sloping face, rather than a stepped texture, must exist.
		var slope_found:=false
		for normal in first.surface_get_arrays(2)[Mesh.ARRAY_NORMAL]:
			if normal.y>.1 and absf(normal.x)>.1: slope_found=true
		check(slope_found,"Wall foot has a real short sloped surface")
		var isolated: Mesh=sample._make_root_mesh(2.6,.25,true,true,0)
		check(is_equal_approx(top_at(isolated,-.5),2.6) and is_equal_approx(top_at(isolated,.5),2.6),"Even an isolated segment retains both end posts")
		for candidate: Mesh in [last,isolated]:
			var valid:=true
			for surface in candidate.get_surface_count():
				var data: Array=candidate.surface_get_arrays(surface)
				var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
				for triangle in range(0,points.size(),3):
					valid=valid and (points[triangle+1]-points[triangle]).cross(points[triangle+2]-points[triangle]).dot(normals[triangle])<-.000001
			check(valid,"Mirrored end and two-post segment have no degenerate or reversed triangles")
		for surface in first.get_surface_count():
			var data: Array=first.surface_get_arrays(surface)
			var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
			var front_faces_ok:=true
			for index in range(0,points.size(),3):
				front_faces_ok=front_faces_ok and (points[index+1]-points[index]).cross(points[index+2]-points[index]).dot(normals[index])<-.000001
			check(front_faces_ok,"Foot and root triangles face outward under Godot clockwise culling")
		var junction=WALL.instantiate()
		junction.position=Vector3(2,0,.5); junction.rotation.y=PI*.5
		world.wall_root.add_child(junction); junction.configure_wall(2.6,.5)
		sample._process(0)
		check(sample.foot_count==4,"A full perpendicular junction splits the low cut into separate U runs")
		check(is_equal_approx(top_at(world.wall_root.get_child(1).wall_mesh.mesh,.5),2.6) and is_equal_approx(top_at(world.wall_root.get_child(2).wall_mesh.mesh,-.5),2.6),"Both sides of a full wall junction retain an end post")
		sample.restore()
		for index in 4:
			check(world.wall_root.get_child(index).wall_mesh.mesh==original_meshes[index],"Restore returns the exact original wall mesh")
			check(world.wall_root.get_child(index).wall_mesh.material_override==whole_material,"Restore returns the original whole-wall material override")
		world.free()
	check_corners()
	print("WALL_ROOT_CUTAWAY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
